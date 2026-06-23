import os
import json
import time
import logging
import subprocess
import socket
import concurrent.futures
from datetime import datetime, timedelta, timezone

from fastapi import FastAPI, Depends, HTTPException, Request
from fastapi.responses import PlainTextResponse
from fastapi.middleware.cors import CORSMiddleware
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from pydantic import BaseModel
from sqlalchemy.orm import Session
from sqlalchemy import text
import httpx

# ─── Config ───────────────────────────────────────────────────────────────────
from config import JWT_SECRET, ADMIN_PASSWORD, ADMIN_USERNAME, CORS_ORIGINS, LOG_LEVEL

# ─── Database ─────────────────────────────────────────────────────────────────
from models.database import get_db, engine, SessionLocal, Base, init_db, migrate_database
from models.user import User
from models.subscription import Subscription
from models.node import Node
from models.apikey import APIKey
from models.audit import AuditLog

# ─── Auth ─────────────────────────────────────────────────────────────────────
from utils.auth import (
    verify_password, get_password_hash, create_access_token,
    security, get_current_user, require_admin
)
from utils.time import get_current_time
from utils.security import is_safe_url

# ─── Parsers ──────────────────────────────────────────────────────────────────
from parsers import parse_vless, parse_vmess, parse_trojan, parse_ss, parse_hysteria2, parse_clash_yaml

# ─── Exporters ────────────────────────────────────────────────────────────────
from exporters import (
    generate_clash_yaml,
    generate_singbox_json,
    generate_base64_subscription,
    generate_surge_config,
    generate_loon_config,
    generate_qx_config,
    generate_shadowrocket_config,
)

# ─── Logging ──────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=getattr(logging, LOG_LEVEL, logging.INFO),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

CST = timezone(timedelta(hours=8))

# ─── Simple Cache ─────────────────────────────────────────────────────────────
class SimpleCache:
    """简单的内存缓存"""
    def __init__(self, ttl_seconds=300):
        self.cache = {}
        self.ttl = ttl_seconds

    def get(self, key):
        if key in self.cache:
            value, timestamp = self.cache[key]
            if time.time() - timestamp < self.ttl:
                return value
            del self.cache[key]
        return None

    def set(self, key, value):
        self.cache[key] = (value, time.time())

    def delete(self, key):
        self.cache.pop(key, None)

subscription_cache = SimpleCache(ttl_seconds=300)

# ─── Seed admin ───────────────────────────────────────────────────────────────
def seed_admin():
    db = SessionLocal()
    try:
        admin = db.query(User).filter(User.username == ADMIN_USERNAME).first()
        if not admin:
            admin = User(
                username=ADMIN_USERNAME,
                password=get_password_hash(ADMIN_PASSWORD),
                role="admin",
                status=1
            )
            db.add(admin)
            db.commit()
            logger.info(f"Admin user created: {ADMIN_USERNAME}")
    finally:
        db.close()

# ─── Init DB ──────────────────────────────────────────────────────────────────
init_db()
migrate_database()
seed_admin()

# ─── Record start time ────────────────────────────────────────────────────────
start_time = time.time()

# ─── App ──────────────────────────────────────────────────────────────────────
app = FastAPI(title="SubForge API")

# Rate limiting
limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS if CORS_ORIGINS != ['*'] else ['*'],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Request size limit (1MB)
@app.middleware("http")
async def limit_request_size(request: Request, call_next):
    if request.headers.get("content-length"):
        content_length = int(request.headers["content-length"])
        if content_length > 1024 * 1024:
            from fastapi.responses import JSONResponse
            return JSONResponse(status_code=413, content={"detail": "Request body too large"})
    return await call_next(request)

# Request logging
@app.middleware("http")
async def log_requests(request: Request, call_next):
    start = time.time()
    response = await call_next(request)
    duration = time.time() - start
    if request.url.path != "/api/health":
        logger.info(f"{request.method} {request.url.path} {response.status_code} {duration:.3f}s")
    return response

# ─── Pydantic models ─────────────────────────────────────────────────────────
class LoginRequest(BaseModel):
    username: str
    password: str

class SubscriptionCreate(BaseModel):
    name: str
    url: str
    auto_refresh: int = 3600
    tags: list[str] = []

class ConvertRequest(BaseModel):
    source_url: str | None = None
    source: str | None = None
    target: str = "clash"
    rename: bool = True

class NodeImportRequest(BaseModel):
    uris: str

class UserCreate(BaseModel):
    username: str
    password: str
    role: str = "user"

class APIKeyCreate(BaseModel):
    name: str

# ─── Helper: fetch subscription content ──────────────────────────────────────
def _fetch_subscription_content(url: str) -> str | None:
    """Fetch subscription content with cloudscraper fallback to httpx, with SSRF protection."""
    if not is_safe_url(url):
        raise HTTPException(status_code=400, detail="URL is not safe (SSRF blocked)")

    content = None

    # Method 1: cloudscraper (bypasses Cloudflare)
    try:
        import cloudscraper
        scraper = cloudscraper.create_scraper()
        response = scraper.get(url, timeout=60)
        if response.status_code == 200:
            content = response.text
    except Exception as e:
        logger.warning(f"cloudscraper failed: {e}")

    # Method 2: httpx fallback
    if content is None:
        for attempt in range(3):
            try:
                response = httpx.get(url, timeout=60, follow_redirects=True)
                if response.status_code == 200:
                    content = response.text
                    break
            except Exception as e:
                logger.warning(f"httpx attempt {attempt + 1} failed: {e}")
                if attempt < 2:
                    time.sleep(2)

    return content

def _parse_subscription_content(content: str) -> list[dict]:
    """Parse subscription content into node dicts."""
    # Try base64 decode
    try:
        decoded = __import__('base64').b64decode(content).decode('utf-8')
    except Exception:
        decoded = content

    # Check if it's Clash YAML
    is_clash_yaml = False
    if 'proxies:' in content or 'proxy-providers:' in content:
        is_clash_yaml = True
    elif 'proxies:' in decoded or 'proxy-providers:' in decoded:
        is_clash_yaml = True

    if is_clash_yaml:
        return parse_clash_yaml(content)

    # Parse URI lines
    nodes = []
    for line in decoded.strip().split('\n'):
        line = line.strip()
        if not line:
            continue
        node = None
        if line.startswith('vless://'):
            node = parse_vless(line)
        elif line.startswith('vmess://'):
            node = parse_vmess(line)
        elif line.startswith('trojan://'):
            node = parse_trojan(line)
        elif line.startswith('ss://'):
            node = parse_ss(line)
        elif line.startswith('hysteria2://'):
            node = parse_hysteria2(line)
        if node:
            nodes.append(node)
    return nodes

def _save_nodes(db: Session, sub: Subscription, nodes: list[dict]):
    """Save parsed nodes to database, replacing existing nodes."""
    db.query(Node).filter(Node.subscription_id == sub.id).delete()
    for node_data in nodes:
        node = Node(
            subscription_id=sub.id,
            name=node_data.get('name', 'Unknown'),
            display_name=node_data.get('name', 'Unknown'),
            node_type=node_data.get('type', 'unknown'),
            server=node_data.get('server', ''),
            port=node_data.get('port', 0),
            region=node_data.get('region', 'OTHER'),
            config_json=node_data,
            status=1
        )
        db.add(node)
    sub.node_count = len(nodes)
    sub.last_fetch = get_current_time()
    db.commit()

def _node_to_dict(node: Node) -> dict:
    """Convert ORM Node to dict for exporters."""
    return {
        "name": node.name,
        "display_name": node.display_name,
        "node_type": node.node_type,
        "server": node.server,
        "port": node.port,
        "region": node.region,
        "config_json": node.config_json,
        "raw_uri": node.raw_uri,
        "latency": node.latency,
        "status": node.status,
    }

def _get_export_content(nodes: list[Node], target: str) -> tuple[str, str]:
    """Generate export content for given nodes and target format. Returns (content, media_type)."""
    node_dicts = [_node_to_dict(n) for n in nodes]

    if target in ("clash", "mihomo"):
        return generate_clash_yaml(node_dicts), "text/yaml"
    elif target == "singbox":
        return generate_singbox_json(node_dicts), "application/json"
    elif target == "base64":
        return generate_base64_subscription(node_dicts), "text/plain"
    elif target == "surge":
        return generate_surge_config(node_dicts), "text/plain"
    elif target == "loon":
        return generate_loon_config(node_dicts), "text/plain"
    elif target == "qx":
        return generate_qx_config(node_dicts), "text/plain"
    elif target == "shadowrocket":
        return generate_shadowrocket_config(node_dicts), "text/plain"
    else:
        # Plain text fallback
        lines = []
        for n in nodes:
            if n.node_type == "vless":
                lines.append(f"vless://{n.server}:{n.port}")
            elif n.node_type == "vmess":
                lines.append(f"vmess://{n.server}:{n.port}")
            elif n.node_type == "trojan":
                lines.append(f"trojan://{n.server}:{n.port}")
            elif n.node_type == "ss":
                lines.append(f"ss://{n.server}:{n.port}")
        return "\n".join(lines), "text/plain"

# ─── Routes ───────────────────────────────────────────────────────────────────

@app.get("/api/health")
def health(db: Session = Depends(get_db)):
    checks = {"status": "ok", "version": "unknown", "timestamp": get_current_time().isoformat()}
    try:
        with open('/app/VERSION', 'r') as f:
            checks["version"] = f.read().strip()
    except Exception:
        pass
    try:
        db.execute(text("SELECT 1"))
        checks["database"] = "ok"
    except Exception as e:
        checks["database"] = "error"
        checks["status"] = "degraded"
    return checks

@app.post("/api/auth/login")
@limiter.limit("5/minute")
def login(request: Request, req: LoginRequest, db: Session = Depends(get_db)):
    client_ip = request.headers.get("x-forwarded-for", "").split(",")[0].strip()
    if not client_ip:
        client_ip = request.headers.get("x-real-ip", "")
    if not client_ip:
        client_ip = request.client.host if request.client else "unknown"

    logger.info(f"Login attempt from {client_ip} for user: {req.username}")

    user = db.query(User).filter(User.username == req.username, User.status == 1).first()
    if not user or not verify_password(req.password, user.password):
        audit = AuditLog(user_id=0, username=req.username, action="login", resource="auth", detail="login failed", ip=client_ip, success=0)
        db.add(audit)
        db.commit()
        logger.warning(f"Failed login attempt for user: {req.username} from {client_ip}")
        raise HTTPException(status_code=401, detail="Invalid credentials")

    token = create_access_token({"sub": user.id, "role": user.role})

    audit = AuditLog(user_id=user.id, username=user.username, action="login", resource="auth", detail="login success", ip=client_ip, success=1)
    db.add(audit)
    db.commit()

    return {"token": token, "user": {"id": user.id, "username": user.username, "role": user.role}}

@app.get("/api/me")
def get_me(current_user: User = Depends(get_current_user)):
    return {"id": current_user.id, "username": current_user.username, "role": current_user.role}

@app.get("/api/users")
def list_users(current_user: User = Depends(require_admin), db: Session = Depends(get_db)):
    users = db.query(User).all()
    return [{"id": u.id, "username": u.username, "role": u.role, "status": u.status, "created_at": str(u.created_at)} for u in users]

@app.post("/api/users")
def create_user(req: UserCreate, current_user: User = Depends(require_admin), db: Session = Depends(get_db)):
    existing = db.query(User).filter(User.username == req.username).first()
    if existing:
        raise HTTPException(status_code=400, detail="Username already exists")
    user = User(username=req.username, password=get_password_hash(req.password), role=req.role, status=1)
    db.add(user)
    db.commit()
    db.refresh(user)
    return {"id": user.id, "username": user.username, "role": user.role}

@app.put("/api/users/{user_id}/status")
def update_user_status(user_id: int, status: int = 1, current_user: User = Depends(require_admin), db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.status = status
    db.commit()
    return {"message": "updated"}

@app.put("/api/users/{user_id}/password")
def reset_user_password(user_id: int, password: str = "", current_user: User = Depends(require_admin), db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if not password:
        import secrets
        password = secrets.token_urlsafe(16)
    user.password = get_password_hash(password)
    db.commit()
    return {"message": "updated", "password": password}

@app.delete("/api/users/{user_id}")
def delete_user(user_id: int, current_user: User = Depends(require_admin), db: Session = Depends(get_db)):
    if user_id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot delete yourself")
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    db.delete(user)
    db.commit()
    return {"message": "deleted"}

@app.get("/api/apikeys")
def list_apikeys(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    apikeys = db.query(APIKey).filter(APIKey.user_id == current_user.id).all()
    return [{"id": k.id, "name": k.name, "key": k.key[:8] + "...", "status": k.status, "created_at": str(k.created_at)} for k in apikeys]

@app.post("/api/apikeys")
def create_apikey(req: APIKeyCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    import secrets
    api_key = f"sf_{secrets.token_urlsafe(32)}"
    key = APIKey(user_id=current_user.id, name=req.name, key=api_key, status=1)
    db.add(key)
    db.commit()
    db.refresh(key)
    return {"id": key.id, "name": key.name, "key": api_key}

@app.delete("/api/apikeys/{key_id}")
def delete_apikey(key_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    key = db.query(APIKey).filter(APIKey.id == key_id, APIKey.user_id == current_user.id).first()
    if not key:
        raise HTTPException(status_code=404, detail="API key not found")
    db.delete(key)
    db.commit()
    return {"message": "deleted"}

@app.get("/api/subscriptions")
def list_subscriptions(page: int = 1, page_size: int = 20, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    total = db.query(Subscription).filter(Subscription.user_id == current_user.id).count()
    subs = db.query(Subscription).filter(Subscription.user_id == current_user.id).offset((page-1)*page_size).limit(page_size).all()
    return {
        "items": [{"id": s.id, "name": s.name, "url": s.url, "token": s.token, "node_count": s.node_count, "status": s.status, "last_fetch": s.last_fetch} for s in subs],
        "total": total,
        "page": page,
        "page_size": page_size
    }

@app.post("/api/subscriptions")
def create_subscription(req: SubscriptionCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    import secrets
    sub = Subscription(user_id=current_user.id, token=secrets.token_hex(16), name=req.name, url=req.url, auto_refresh=req.auto_refresh, tags=req.tags, status=1)
    db.add(sub)
    db.commit()
    db.refresh(sub)
    return {"id": sub.id, "name": sub.name, "token": sub.token}

@app.get("/api/subscriptions/export-all")
def export_all_subscriptions(target: str = "clash", current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    sub_ids = db.query(Subscription.id).filter(Subscription.user_id == current_user.id, Subscription.status == 1).subquery()
    all_nodes = db.query(Node).filter(Node.subscription_id.in_(sub_ids)).all()
    content, media_type = _get_export_content(all_nodes, target)
    return PlainTextResponse(content, media_type=media_type)

@app.get("/api/subscriptions/{sub_id}")
def get_subscription(sub_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    sub = db.query(Subscription).filter(Subscription.id == sub_id, Subscription.user_id == current_user.id).first()
    if not sub:
        raise HTTPException(status_code=404, detail="Subscription not found")
    nodes = db.query(Node).filter(Node.subscription_id == sub.id).all()
    return {
        "id": sub.id, "name": sub.name, "url": sub.url, "token": sub.token,
        "node_count": sub.node_count, "status": sub.status,
        "nodes": [{"id": n.id, "name": n.name, "node_type": n.node_type, "server": n.server, "port": n.port, "region": n.region} for n in nodes]
    }

@app.delete("/api/subscriptions/{sub_id}")
def delete_subscription(sub_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    sub = db.query(Subscription).filter(Subscription.id == sub_id, Subscription.user_id == current_user.id).first()
    if not sub:
        raise HTTPException(status_code=404, detail="Subscription not found")
    audit = AuditLog(user_id=current_user.id, username=current_user.username, action="delete", resource="subscription", detail=f"deleted: {sub.name}", ip="unknown", success=1)
    db.add(audit)
    db.delete(sub)
    db.commit()
    return {"message": "deleted"}

@app.put("/api/subscriptions/{sub_id}")
def update_subscription(sub_id: int, req: SubscriptionCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    sub = db.query(Subscription).filter(Subscription.id == sub_id, Subscription.user_id == current_user.id).first()
    if not sub:
        raise HTTPException(status_code=404, detail="Subscription not found")
    sub.name = req.name
    sub.url = req.url
    sub.auto_refresh = req.auto_refresh or 3600
    if req.tags:
        sub.tags = req.tags
    db.commit()
    return {"id": sub.id, "name": sub.name, "url": sub.url}

@app.post("/api/subscriptions/refresh-all")
def refresh_all_subscriptions(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    subs = db.query(Subscription).filter(Subscription.user_id == current_user.id, Subscription.status == 1).all()
    results = []
    for sub in subs:
        try:
            content = _fetch_subscription_content(sub.url)
            if content is None:
                results.append({"id": sub.id, "name": sub.name, "status": "failed", "node_count": 0})
                continue
            nodes = _parse_subscription_content(content)
            _save_nodes(db, sub, nodes)
            results.append({"id": sub.id, "name": sub.name, "status": "success", "node_count": len(nodes)})
        except Exception as e:
            results.append({"id": sub.id, "name": sub.name, "status": "error", "error": str(e)})
    return {"results": results, "total": len(results), "success": sum(1 for r in results if r["status"] == "success")}

@app.post("/api/subscriptions/{sub_id}/refresh")
def refresh_subscription(sub_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    sub = db.query(Subscription).filter(Subscription.id == sub_id, Subscription.user_id == current_user.id).first()
    if not sub:
        raise HTTPException(status_code=404, detail="Subscription not found")

    # Clear cache
    for target in ["clash", "mihomo", "singbox", "base64", "plain"]:
        subscription_cache.delete(f"sub:{sub.token}:{target}")

    audit = AuditLog(user_id=current_user.id, username=current_user.username, action="refresh", resource="subscription", detail=f"refreshing: {sub.name}", ip="unknown", success=1)
    db.add(audit)
    db.commit()

    try:
        content = _fetch_subscription_content(sub.url)
        if content is None:
            raise Exception("Failed to fetch subscription after 3 attempts")

        nodes = _parse_subscription_content(content)
        logger.info(f"Parsed {len(nodes)} nodes")

        _save_nodes(db, sub, nodes)
        return {"message": "refreshed", "node_count": len(nodes)}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Refresh failed: {str(e)}")

@app.get("/api/nodes/all")
def get_all_nodes(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Get all nodes from all subscriptions for the current user"""
    subs = db.query(Subscription).filter(Subscription.user_id == current_user.id, Subscription.status == 1).all()
    sub_ids = [s.id for s in subs]
    if not sub_ids:
        return []

    # Build subscription name lookup dict (O(1) instead of O(n*m))
    sub_name_map = {s.id: s.name for s in subs}
    nodes = db.query(Node).filter(Node.subscription_id.in_(sub_ids)).all()
    return [
        {
            "id": n.id, "name": n.name, "display_name": n.display_name,
            "node_type": n.node_type, "server": n.server, "port": n.port,
            "region": n.region, "latency": n.latency, "status": n.status,
            "subscription_id": n.subscription_id,
            "subscription_name": sub_name_map.get(n.subscription_id, "")
        }
        for n in nodes
    ]

@app.post("/api/nodes/import")
def import_nodes(req: NodeImportRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Import individual node URIs"""
    sub = db.query(Subscription).filter(Subscription.user_id == current_user.id, Subscription.name == "手动导入").first()
    if not sub:
        import secrets
        sub = Subscription(user_id=current_user.id, token=secrets.token_hex(16), name="手动导入", url="manual", status=1)
        db.add(sub)
        db.commit()
        db.refresh(sub)

    lines = [line.strip() for line in req.uris.strip().split('\n') if line.strip()]
    imported = 0
    for line in lines:
        try:
            node_data = None
            if line.startswith("vmess://"):
                node_data = parse_vmess(line)
            elif line.startswith("vless://"):
                node_data = parse_vless(line)
            elif line.startswith("trojan://"):
                node_data = parse_trojan(line)
            elif line.startswith("ss://"):
                node_data = parse_ss(line)
            elif line.startswith("hysteria2://"):
                node_data = parse_hysteria2(line)

            if node_data:
                existing = db.query(Node).filter(
                    Node.subscription_id == sub.id,
                    Node.server == node_data.get("server"),
                    Node.port == node_data.get("port"),
                    Node.node_type == node_data.get("type")
                ).first()
                if not existing:
                    node = Node(
                        subscription_id=sub.id,
                        name=node_data.get("name", "unknown"),
                        display_name=node_data.get("name", "unknown"),
                        node_type=node_data.get("type", "unknown"),
                        server=node_data.get("server", ""),
                        port=node_data.get("port", 0),
                        region=node_data.get("region", "OTHER"),
                        config_json=node_data.get("data", {}),
                        status=1
                    )
                    db.add(node)
                    imported += 1
        except Exception:
            continue

    db.commit()
    if imported > 0:
        sub.node_count = db.query(Node).filter(Node.subscription_id == sub.id).count()
        db.commit()

    return {"imported": imported, "subscription_id": sub.id, "subscription_name": sub.name}

@app.get("/api/subscriptions/{sub_id}/nodes")
def get_nodes(sub_id: int, region: str = None, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    sub = db.query(Subscription).filter(Subscription.id == sub_id, Subscription.user_id == current_user.id).first()
    if not sub:
        raise HTTPException(status_code=404, detail="Subscription not found")
    query = db.query(Node).filter(Node.subscription_id == sub.id)
    if region:
        query = query.filter(Node.region == region.upper())
    nodes = query.all()
    return [{"id": n.id, "name": n.name, "display_name": n.display_name, "node_type": n.node_type, "server": n.server, "port": n.port, "region": n.region, "latency": n.latency, "status": n.status} for n in nodes]

@app.post("/api/subscriptions/{sub_id}/check")
def check_subscription_health(sub_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    sub = db.query(Subscription).filter(Subscription.id == sub_id, Subscription.user_id == current_user.id).first()
    if not sub:
        raise HTTPException(status_code=404, detail="Subscription not found")

    nodes = db.query(Node).filter(Node.subscription_id == sub.id).all()
    total = len(nodes)
    online = 0
    offline = 0

    for node in nodes:
        try:
            def test_connection(port):
                try:
                    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                    sock.settimeout(2)
                    result = sock.connect_ex((node.server, port))
                    sock.close()
                    return result == 0
                except Exception:
                    return False

            test_ports = [node.port, 80, 443, 8080, 8443]
            is_online = False

            with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
                futures = {executor.submit(test_connection, port): port for port in test_ports}
                for future in concurrent.futures.as_completed(futures, timeout=5):
                    try:
                        if future.result():
                            is_online = True
                            break
                    except Exception:
                        pass

            if not is_online:
                try:
                    socket.gethostbyname(node.server)
                    is_online = True
                except Exception:
                    pass

            if is_online:
                online += 1
                node.status = 1
            else:
                offline += 1
                node.status = 0
        except Exception:
            offline += 1
            node.status = 0

    db.commit()
    return {"total": total, "online": online, "offline": offline}

@app.post("/api/subscriptions/{sub_id}/nodes/speedtest")
def speedtest_nodes(sub_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    sub = db.query(Subscription).filter(Subscription.id == sub_id, Subscription.user_id == current_user.id).first()
    if not sub:
        raise HTTPException(status_code=404, detail="Subscription not found")

    nodes = db.query(Node).filter(Node.subscription_id == sub.id).all()
    results = []

    for node in nodes:
        try:
            def test_connection(port):
                try:
                    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                    sock.settimeout(2)
                    start_time = time.time()
                    result = sock.connect_ex((node.server, port))
                    end_time = time.time()
                    sock.close()
                    if result == 0:
                        return int((end_time - start_time) * 1000)
                    return None
                except Exception:
                    return None

            test_ports = [node.port, 80, 443, 8080, 8443]
            latency = None

            with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
                futures = {executor.submit(test_connection, port): port for port in test_ports}
                for future in concurrent.futures.as_completed(futures, timeout=5):
                    try:
                        result = future.result()
                        if result is not None and latency is None:
                            latency = result
                    except Exception:
                        pass

            if latency is not None:
                node.latency = latency
                results.append({"id": node.id, "name": node.name, "latency": latency, "status": "success"})
            else:
                try:
                    socket.gethostbyname(node.server)
                    node.latency = 999
                    results.append({"id": node.id, "name": node.name, "latency": 999, "status": "success"})
                except Exception:
                    node.latency = -1
                    results.append({"id": node.id, "name": node.name, "latency": -1, "status": "failed"})
        except Exception:
            node.latency = -1
            results.append({"id": node.id, "name": node.name, "latency": -1, "status": "error"})

    db.commit()
    return {"results": results, "total": len(results), "success": sum(1 for r in results if r["status"] == "success")}

@app.post("/api/nodes/speedtest-all")
def speedtest_all_nodes(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    subs = db.query(Subscription).filter(Subscription.user_id == current_user.id, Subscription.status == 1).all()
    sub_ids = [s.id for s in subs]
    if not sub_ids:
        return {"results": [], "total": 0, "success": 0}

    nodes = db.query(Node).filter(Node.subscription_id.in_(sub_ids)).all()
    results = []

    def test_node_latency(node):
        def test_connection(port):
            try:
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.settimeout(2)
                start = time.time()
                result = sock.connect_ex((node.server, port))
                end = time.time()
                sock.close()
                if result == 0:
                    return int((end - start) * 1000)
                return None
            except Exception:
                return None

        test_ports = [node.port, 80, 443, 8080, 8443]
        latency = None

        with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
            futures = {executor.submit(test_connection, port): port for port in test_ports}
            for future in concurrent.futures.as_completed(futures, timeout=5):
                try:
                    result = future.result()
                    if result is not None and latency is None:
                        latency = result
                except Exception:
                    pass

        if latency is not None:
            node.latency = latency
            return {"id": node.id, "name": node.name, "latency": latency, "status": "success"}
        else:
            try:
                socket.gethostbyname(node.server)
                node.latency = 999
                return {"id": node.id, "name": node.name, "latency": 999, "status": "success"}
            except Exception:
                node.latency = -1
                return {"id": node.id, "name": node.name, "latency": -1, "status": "failed"}

    with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
        futures = {executor.submit(test_node_latency, node): node for node in nodes}
        for future in concurrent.futures.as_completed(futures, timeout=30):
            try:
                results.append(future.result())
            except Exception:
                node = futures[future]
                node.latency = -1
                results.append({"id": node.id, "name": node.name, "latency": -1, "status": "failed"})

    db.commit()
    return {"results": results, "total": len(results), "success": sum(1 for r in results if r["status"] == "success")}

@app.get("/api/formats")
def list_formats():
    return {"formats": ["clash", "singbox", "surge", "loon", "qx", "shadowrocket", "base64"]}

@app.post("/api/convert")
def convert(req: ConvertRequest):
    import base64 as b64
    if req.source:
        try:
            decoded = b64.b64decode(req.source).decode()
            return {"result": decoded, "format": "detected"}
        except Exception:
            return {"result": req.source, "format": "raw"}
    return {"result": "No source provided", "format": "error"}

@app.get("/sub/{token}")
def get_subscription_public(token: str, target: str = "clash", db: Session = Depends(get_db)):
    sub = db.query(Subscription).filter(Subscription.token == token, Subscription.status == 1).first()
    if not sub:
        raise HTTPException(status_code=404, detail="Subscription not found")
    nodes = db.query(Node).filter(Node.subscription_id == sub.id).all()
    return {"subscription": sub.name, "nodes": len(nodes), "target": target}

@app.get("/sub/{token}/export")
def export_subscription(token: str, target: str = "clash", db: Session = Depends(get_db)):
    cache_key = f"sub:{token}:{target}"
    cached = subscription_cache.get(cache_key)
    if cached:
        media_type = "text/plain" if target == "base64" else "text/yaml" if target in ["clash", "mihomo"] else "application/json"
        return PlainTextResponse(cached, media_type=media_type)

    sub = db.query(Subscription).filter(Subscription.token == token, Subscription.status == 1).first()
    if not sub:
        raise HTTPException(status_code=404, detail="Subscription not found")

    nodes = db.query(Node).filter(Node.subscription_id == sub.id).all()
    content, media_type = _get_export_content(nodes, target)

    subscription_cache.set(cache_key, content)
    return PlainTextResponse(content, media_type=media_type)

@app.get("/sub/{token}/export/group")
def export_subscription_by_group(token: str, target: str = "clash", group_by: str = "region", group_value: str = "", db: Session = Depends(get_db)):
    sub = db.query(Subscription).filter(Subscription.token == token, Subscription.status == 1).first()
    if not sub:
        raise HTTPException(status_code=404, detail="Subscription not found")

    nodes = db.query(Node).filter(Node.subscription_id == sub.id).all()

    if group_by == "region":
        nodes = [n for n in nodes if (n.region or "OTHER") == group_value]
    elif group_by == "type":
        nodes = [n for n in nodes if n.node_type == group_value]
    elif group_by == "status":
        is_online = group_value == "在线"
        nodes = [n for n in nodes if (n.status == 1) == is_online]

    if not nodes:
        raise HTTPException(status_code=404, detail="No nodes found for this group")

    content, media_type = _get_export_content(nodes, target)
    return PlainTextResponse(content, media_type=media_type)

@app.get("/api/metrics")
def get_metrics(current_user: User = Depends(require_admin), db: Session = Depends(get_db)):
    users = db.query(User).count()
    subs = db.query(Subscription).count()
    nodes = db.query(Node).count()

    process_memory_mb = 0
    try:
        with open('/proc/self/status', 'r') as f:
            for line in f:
                if line.startswith('VmRSS:'):
                    process_memory_mb = int(line.split()[1]) / 1024
                    break
    except Exception:
        pass

    system_memory_mb = 0
    try:
        with open('/proc/meminfo', 'r') as f:
            for line in f:
                if line.startswith('MemTotal:'):
                    system_memory_mb = int(line.split()[1]) / 1024
                    break
    except Exception:
        pass

    uptime = int(time.time() - start_time)

    return {
        "users": users, "subscriptions": subs, "nodes": nodes,
        "uptime_seconds": uptime,
        "memory": {"alloc_mb": round(process_memory_mb, 2), "total_mb": round(system_memory_mb, 2)},
        "goroutines": 1, "cpu_percent": 0, "go_version": "Python 3.11",
        "database": {"users": users, "subscriptions": subs, "nodes": nodes}
    }

@app.get("/api/version")
def get_version():
    try:
        with open('/app/VERSION', 'r') as f:
            version = f.read().strip()
    except Exception:
        version = "1.0.0"
    return {"version": version, "name": "SubForge", "description": "VPN 订阅链接统一转换平台", "python_version": "3.11", "fastapi_version": "0.109.0"}

@app.get("/api/update/version")
def get_update_version():
    try:
        with open('/app/VERSION', 'r') as f:
            current_version = f.read().strip()
    except Exception:
        current_version = "1.0.0"

    try:
        with open('/app/COMMIT', 'r') as f:
            current_commit = f.read().strip()
    except Exception:
        current_commit = ""

    latest_version = current_version
    has_update = False
    try:
        result = subprocess.run(
            ["git", "ls-remote", "--tags", "--refs", "https://github.com/IceTears1/subforge.git"],
            capture_output=True, text=True, timeout=10
        )
        if result.returncode == 0:
            tags = []
            for line in result.stdout.strip().split('\n'):
                if line:
                    tag = line.split('refs/tags/')[-1]
                    if tag.startswith('v'):
                        tags.append(tag)
            if tags:
                latest_tag = sorted(tags, key=lambda x: [int(p) for p in x[1:].split('.')], reverse=True)[0]
                latest_version = latest_tag[1:]
                has_update = latest_version != current_version
    except Exception as e:
        logger.warning(f"Failed to check latest version: {e}")

    return {
        "current": current_version, "current_tag": current_version,
        "current_commit": current_commit,
        "latest": latest_version, "latest_tag": latest_version,
        "has_update": has_update, "changelog": "",
        "last_check": get_current_time().isoformat(),
        "update_mode": "tag", "updating": False
    }

@app.get("/api/update/releases")
def get_releases():
    try:
        with open('/app/VERSION', 'r') as f:
            current_version = f.read().strip()
    except Exception:
        current_version = "1.0.0"

    releases = []
    try:
        result = subprocess.run(
            ["git", "ls-remote", "--tags", "--refs", "https://github.com/IceTears1/subforge.git"],
            capture_output=True, text=True, timeout=10
        )
        if result.returncode == 0:
            for line in result.stdout.strip().split('\n'):
                if line:
                    tag = line.split('refs/tags/')[-1]
                    if tag.startswith('v'):
                        version = tag[1:]
                        releases.append({"tag": tag, "commit_hash": "", "message": f"Version {version}", "date": "", "is_current": version == current_version})
    except Exception as e:
        logger.warning(f"Failed to fetch releases: {e}")

    if not releases:
        releases.append({"tag": f"v{current_version}", "commit_hash": "", "message": f"Version {current_version}", "date": "", "is_current": True})
    return releases

@app.get("/api/update/status")
def get_update_status():
    return {"updating": False, "last_result": None}

@app.get("/api/update/changelog")
def get_changelog():
    return [{"hash": "latest", "message": "Initial release", "date": "2026-06-15"}]

@app.post("/api/update/latest")
def update_to_latest(current_user: User = Depends(require_admin)):
    steps = []
    from_version = "unknown"
    try:
        try:
            with open('/app/VERSION', 'r') as f:
                from_version = f.read().strip()
        except Exception:
            pass

        steps.append({"name": "拉取代码", "status": "running", "message": "正在拉取最新代码..."})
        result = subprocess.run(["git", "pull", "origin", "main"], cwd="/opt/subforge", capture_output=True, text=True, timeout=60)
        if result.returncode == 0:
            steps[-1]["status"] = "success"
            steps[-1]["message"] = "代码已更新"
        else:
            steps[-1]["status"] = "failed"
            steps[-1]["message"] = f"拉取失败: {result.stderr}"
            return {"success": False, "from": from_version, "to": from_version, "steps": steps, "timestamp": get_current_time().isoformat()}

        steps.append({"name": "检查版本", "status": "running", "message": "正在检查新版本..."})
        try:
            with open('/opt/subforge/VERSION', 'r') as f:
                to_version = f.read().strip()
        except Exception:
            to_version = from_version
        steps[-1]["status"] = "success"
        steps[-1]["message"] = f"版本: {from_version} → {to_version}"

        steps.append({"name": "重建容器", "status": "running", "message": "正在重建 Docker 容器..."})
        subprocess.run(["docker", "compose", "down"], cwd="/opt/subforge", capture_output=True, text=True, timeout=60)
        result = subprocess.run(["docker", "compose", "up", "-d", "--build"], cwd="/opt/subforge", capture_output=True, text=True, timeout=300)
        if result.returncode == 0:
            steps[-1]["status"] = "success"
            steps[-1]["message"] = "容器已重建并启动"
        else:
            steps[-1]["status"] = "failed"
            steps[-1]["message"] = f"重建失败: {result.stderr}"
            return {"success": False, "from": from_version, "to": to_version, "steps": steps, "timestamp": get_current_time().isoformat()}

        return {"success": True, "from": from_version, "to": to_version, "steps": steps, "timestamp": get_current_time().isoformat()}
    except Exception as e:
        logger.error(f"Update failed: {e}")
        return {"success": False, "from": from_version, "to": from_version, "steps": steps, "error": str(e), "timestamp": get_current_time().isoformat()}

@app.post("/api/update/tag")
def update_to_tag(req: dict, current_user: User = Depends(require_admin)):
    tag = req.get("tag", "")
    if not tag:
        raise HTTPException(status_code=400, detail="Tag is required")

    steps = []
    from_version = "unknown"
    try:
        try:
            with open('/app/VERSION', 'r') as f:
                from_version = f.read().strip()
        except Exception:
            pass

        steps.append({"name": "切换版本", "status": "running", "message": f"正在切换到 {tag}..."})
        subprocess.run(["git", "fetch", "--tags"], cwd="/opt/subforge", capture_output=True, text=True, timeout=30)
        result = subprocess.run(["git", "checkout", tag], cwd="/opt/subforge", capture_output=True, text=True, timeout=30)
        if result.returncode == 0:
            steps[-1]["status"] = "success"
            steps[-1]["message"] = f"已切换到 {tag}"
        else:
            steps[-1]["status"] = "failed"
            steps[-1]["message"] = f"切换失败: {result.stderr}"
            return {"success": False, "from": from_version, "to": tag, "steps": steps, "timestamp": get_current_time().isoformat()}

        steps.append({"name": "重建容器", "status": "running", "message": "正在重建 Docker 容器..."})
        subprocess.run(["docker", "compose", "down"], cwd="/opt/subforge", capture_output=True, text=True, timeout=60)
        result = subprocess.run(["docker", "compose", "up", "-d", "--build"], cwd="/opt/subforge", capture_output=True, text=True, timeout=300)
        if result.returncode == 0:
            steps[-1]["status"] = "success"
            steps[-1]["message"] = "容器已重建并启动"
        else:
            steps[-1]["status"] = "failed"
            steps[-1]["message"] = f"重建失败: {result.stderr}"
            return {"success": False, "from": from_version, "to": tag, "steps": steps, "timestamp": get_current_time().isoformat()}

        return {"success": True, "from": from_version, "to": tag, "steps": steps, "timestamp": get_current_time().isoformat()}
    except Exception as e:
        logger.error(f"Update to tag failed: {e}")
        return {"success": False, "from": from_version, "to": tag, "steps": steps, "error": str(e), "timestamp": get_current_time().isoformat()}

@app.post("/api/update/rollback")
def rollback(req: dict, current_user: User = Depends(require_admin)):
    version = req.get("version", "")
    if not version:
        raise HTTPException(status_code=400, detail="Version is required")
    return update_to_tag({"tag": version}, current_user)

@app.get("/api/audit")
def get_audit(current_user: User = Depends(require_admin), db: Session = Depends(get_db)):
    logs = db.query(AuditLog).order_by(AuditLog.created_at.desc()).limit(100).all()
    result = []
    for l in logs:
        created_at = l.created_at
        if created_at:
            created_at_utc = created_at.replace(tzinfo=timezone.utc)
            created_at_cst = created_at_utc.astimezone(CST)
            created_at_str = created_at_cst.strftime("%Y-%m-%d %H:%M:%S")
        else:
            created_at_str = ""
        result.append({
            "id": l.id, "user_id": l.user_id, "username": l.username,
            "action": l.action, "resource": l.resource, "detail": l.detail,
            "ip": l.ip, "success": l.success, "created_at": created_at_str
        })
    return {"logs": result}

# ─── Run ──────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv('BACKEND_PORT', '3002'))
    uvicorn.run(app, host="0.0.0.0", port=port)
