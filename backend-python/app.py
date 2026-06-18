import os
import json
import secrets
import hashlib
import re
import yaml
from datetime import datetime, timedelta, timezone

# 东八区 (UTC+8)
CST = timezone(timedelta(hours=8))

def get_current_time():
    """获取当前东八区时间"""
    return datetime.now(CST)

def get_utc_time():
    """获取 UTC 时间"""
    return datetime.utcnow()
from typing import Optional, List

from fastapi import FastAPI, Depends, HTTPException, status, Request, Body
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import create_engine, Column, Integer, String, Text, DateTime, ForeignKey, JSON
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session, relationship
from jose import JWTError, jwt
from passlib.context import CryptContext
from pydantic import BaseModel
import httpx

# ─── Config ───────────────────────────────────────────────────────────────────
DATABASE_URL = f"postgresql://{os.getenv('DB_USER', 'subforge')}:{os.getenv('DB_PASSWORD', 'subforge123')}@{os.getenv('DB_HOST', 'localhost')}:{os.getenv('DB_PORT', '5432')}/{os.getenv('DB_NAME', 'subforge')}"
JWT_SECRET = os.getenv('JWT_SECRET', 'change-me-in-production')
JWT_EXPIRY = os.getenv('JWT_EXPIRY', '24h')
ADMIN_PASSWORD = os.getenv('ADMIN_PASSWORD', 'admin123')

# ─── Database ─────────────────────────────────────────────────────────────────
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# ─── Models ───────────────────────────────────────────────────────────────────
class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(64), unique=True, nullable=False)
    password = Column(String(128), nullable=False)
    role = Column(String(16), default="user")
    status = Column(Integer, default=1)
    created_at = Column(DateTime, default=get_current_time)
    updated_at = Column(DateTime, default=get_current_time, onupdate=get_current_time)

class Subscription(Base):
    __tablename__ = "subscriptions"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    token = Column(String(32), unique=True, index=True)
    name = Column(String(128), nullable=False)
    url = Column(Text, nullable=False)
    auto_refresh = Column(Integer, default=3600)
    tags = Column(JSON, default=[])
    last_fetch = Column(DateTime)
    node_count = Column(Integer, default=0)
    status = Column(Integer, default=1)
    created_at = Column(DateTime, default=get_current_time)
    updated_at = Column(DateTime, default=get_current_time, onupdate=get_current_time)
    nodes = relationship("Node", back_populates="subscription")

class Node(Base):
    __tablename__ = "nodes"
    id = Column(Integer, primary_key=True, index=True)
    subscription_id = Column(Integer, ForeignKey("subscriptions.id"))
    name = Column(String(256))
    display_name = Column(String(256))
    node_type = Column(String(32))
    server = Column(String(256))
    port = Column(Integer)
    region = Column(String(64))
    raw_uri = Column(Text)
    config_json = Column(JSON)
    latency = Column(Integer, default=0)
    status = Column(Integer, default=1)
    created_at = Column(DateTime, default=get_current_time)
    subscription = relationship("Subscription", back_populates="nodes")

class APIKey(Base):
    __tablename__ = "api_keys"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    name = Column(String(128))
    key = Column(String(64), unique=True, index=True)
    status = Column(Integer, default=1)
    created_at = Column(DateTime, default=get_current_time)

class AuditLog(Base):
    __tablename__ = "audit_logs"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer)
    username = Column(String(64))
    action = Column(String(32))
    resource = Column(String(32))
    detail = Column(Text)
    ip = Column(String(64))
    success = Column(Integer, default=1)
    created_at = Column(DateTime, default=get_current_time)

# ─── Create tables ────────────────────────────────────────────────────────────
Base.metadata.create_all(bind=engine)

# ─── Security ─────────────────────────────────────────────────────────────────
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
security = HTTPBearer()

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)

def create_access_token(data: dict) -> str:
    to_encode = data.copy()
    # Convert sub to string for python-jose compatibility
    if "sub" in to_encode:
        to_encode["sub"] = str(to_encode["sub"])
    expire = get_current_time() + timedelta(hours=24)
    to_encode.update({"exp": expire.timestamp()})
    return jwt.encode(to_encode, JWT_SECRET, algorithm="HS256")

def generate_token() -> str:
    return secrets.token_hex(16)

# ─── Database dependency ──────────────────────────────────────────────────────
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# ─── Auth dependency ──────────────────────────────────────────────────────────
async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security), db: Session = Depends(get_db)):
    token = credentials.credentials
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=["HS256"])
        user_id_str = payload.get("sub")
        if user_id_str is None:
            raise HTTPException(status_code=401, detail="Invalid token")
        user_id = int(user_id_str)
    except (JWTError, ValueError):
        raise HTTPException(status_code=401, detail="Invalid token")

    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        raise HTTPException(status_code=401, detail="User not found")
    return user

def require_admin(current_user: User = Depends(get_current_user)):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin required")
    return current_user

# ─── Pydantic models ─────────────────────────────────────────────────────────
class LoginRequest(BaseModel):
    username: str
    password: str

class SubscriptionCreate(BaseModel):
    name: str
    url: str
    auto_refresh: int = 3600
    tags: List[str] = []

class ConvertRequest(BaseModel):
    source_url: Optional[str] = None
    source: Optional[str] = None
    target: str = "clash"
    rename: bool = True

# ─── Seed admin ───────────────────────────────────────────────────────────────
def seed_admin():
    db = SessionLocal()
    try:
        admin = db.query(User).filter(User.username == "admin").first()
        if not admin:
            admin = User(
                username="admin",
                password=get_password_hash(ADMIN_PASSWORD),
                role="admin",
                status=1
            )
            db.add(admin)
            db.commit()
            print(f"Admin user created with password: {ADMIN_PASSWORD}")
    finally:
        db.close()

seed_admin()

# ─── App ──────────────────────────────────────────────────────────────────────
app = FastAPI(title="SubForge API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─── Routes ───────────────────────────────────────────────────────────────────
@app.get("/api/health")
def health():
    return {"status": "ok"}

@app.post("/api/auth/login")
def login(req: LoginRequest, request: Request, db: Session = Depends(get_db)):
    # Get client IP from various headers
    client_ip = request.headers.get("x-forwarded-for", "").split(",")[0].strip()
    if not client_ip:
        client_ip = request.headers.get("x-real-ip", "")
    if not client_ip:
        client_ip = request.headers.get("cf-connecting-ip", "")
    if not client_ip:
        client_ip = request.headers.get("x-forwarded", "")
    if not client_ip:
        client_ip = request.client.host if request.client else "unknown"

    # Debug output
    print(f"Client IP: {client_ip}")
    print(f"Headers: {dict(request.headers)}")

    user = db.query(User).filter(User.username == req.username, User.status == 1).first()
    if not user or not verify_password(req.password, user.password):
        # Log failed login
        audit = AuditLog(user_id=0, username=req.username, action="login", resource="auth", detail="login failed", ip=client_ip, success=0)
        db.add(audit)
        db.commit()
        raise HTTPException(status_code=401, detail="Invalid credentials")

    token = create_access_token({"sub": user.id, "role": user.role})

    # Log successful login
    audit = AuditLog(user_id=user.id, username=user.username, action="login", resource="auth", detail="login success", ip=client_ip, success=1)
    db.add(audit)
    db.commit()

    return {
        "token": token,
        "user": {"id": user.id, "username": user.username, "role": user.role}
    }

@app.get("/api/me")
def get_me(current_user: User = Depends(get_current_user)):
    return {"id": current_user.id, "username": current_user.username, "role": current_user.role}

class UserCreate(BaseModel):
    username: str
    password: str
    role: str = "user"

@app.get("/api/users")
def list_users(current_user: User = Depends(require_admin), db: Session = Depends(get_db)):
    users = db.query(User).all()
    return [{"id": u.id, "username": u.username, "role": u.role, "status": u.status, "created_at": str(u.created_at)} for u in users]

@app.post("/api/users")
def create_user(req: UserCreate, current_user: User = Depends(require_admin), db: Session = Depends(get_db)):
    # Check if username exists
    existing = db.query(User).filter(User.username == req.username).first()
    if existing:
        raise HTTPException(status_code=400, detail="Username already exists")

    user = User(
        username=req.username,
        password=get_password_hash(req.password),
        role=req.role,
        status=1
    )
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

class APIKeyCreate(BaseModel):
    name: str

@app.get("/api/apikeys")
def list_apikeys(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    apikeys = db.query(APIKey).filter(APIKey.user_id == current_user.id).all()
    return [{"id": k.id, "name": k.name, "key": k.key[:8] + "...", "status": k.status, "created_at": str(k.created_at)} for k in apikeys]

@app.post("/api/apikeys")
def create_apikey(req: APIKeyCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    # Generate API key
    import secrets
    api_key = f"sf_{secrets.token_urlsafe(32)}"

    key = APIKey(
        user_id=current_user.id,
        name=req.name,
        key=api_key,
        status=1
    )
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
    sub = Subscription(
        user_id=current_user.id,
        token=generate_token(),
        name=req.name,
        url=req.url,
        auto_refresh=req.auto_refresh,
        tags=req.tags,
        status=1
    )
    db.add(sub)
    db.commit()
    db.refresh(sub)
    return {"id": sub.id, "name": sub.name, "token": sub.token}

@app.get("/api/subscriptions/export-all")
def export_all_subscriptions(target: str = "clash", current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    user_id = current_user.id

    subs = db.query(Subscription).filter(Subscription.user_id == user_id, Subscription.status == 1).all()

    all_nodes = []
    for sub in subs:
        nodes = db.query(Node).filter(Node.subscription_id == sub.id).all()
        all_nodes.extend(nodes)

    if target == "clash" or target == "mihomo":
        yaml_content = generate_clash_yaml(all_nodes)
        from fastapi.responses import PlainTextResponse
        return PlainTextResponse(yaml_content, media_type="text/yaml")
    elif target == "singbox":
        json_content = generate_singbox_json(all_nodes)
        from fastapi.responses import PlainTextResponse
        return PlainTextResponse(json_content, media_type="application/json")
    elif target == "base64":
        base64_content = generate_base64_subscription(all_nodes)
        from fastapi.responses import PlainTextResponse
        return PlainTextResponse(base64_content, media_type="text/plain")
    else:
        lines = []
        for node in all_nodes:
            if node.node_type == "vless":
                lines.append(f"vless://{node.server}:{node.port}")
            elif node.node_type == "vmess":
                lines.append(f"vmess://{node.server}:{node.port}")
            elif node.node_type == "trojan":
                lines.append(f"trojan://{node.server}:{node.port}")
            elif node.node_type == "ss":
                lines.append(f"ss://{node.server}:{node.port}")

        from fastapi.responses import PlainTextResponse
        return PlainTextResponse("\n".join(lines), media_type="text/plain")

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

    # Log
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
        import json as json_mod
        sub.tags = json_mod.dumps(req.tags)

    db.commit()
    return {"id": sub.id, "name": sub.name, "url": sub.url}

@app.post("/api/subscriptions/refresh-all")
def refresh_all_subscriptions(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    subs = db.query(Subscription).filter(Subscription.user_id == current_user.id, Subscription.status == 1).all()

    results = []
    for sub in subs:
        try:
            # Reuse the refresh logic
            import base64
            import re

            # Fetch content
            content = None
            try:
                import cloudscraper
                scraper = cloudscraper.create_scraper()
                response = scraper.get(sub.url, timeout=60)
                if response.status_code == 200:
                    content = response.text
            except:
                pass

            if content is None:
                for attempt in range(3):
                    try:
                        response = httpx.get(sub.url, timeout=60, follow_redirects=True)
                        if response.status_code == 200:
                            content = response.text
                            break
                    except:
                        pass

            if content is None:
                results.append({"id": sub.id, "name": sub.name, "status": "failed", "node_count": 0})
                continue

            # Parse nodes
            try:
                decoded = base64.b64decode(content).decode('utf-8')
            except:
                decoded = content

            # Check format
            is_clash_yaml = 'proxies:' in content or 'proxy-providers:' in content
            if is_clash_yaml:
                nodes = parse_clash_yaml(content)
            else:
                nodes = []
                for line in decoded.strip().split('\n'):
                    line = line.strip()
                    if not line:
                        continue
                    if line.startswith('vless://'):
                        node = parse_vless(line)
                        if node:
                            nodes.append(node)
                    elif line.startswith('vmess://'):
                        node = parse_vmess(line)
                        if node:
                            nodes.append(node)
                    elif line.startswith('trojan://'):
                        node = parse_trojan(line)
                        if node:
                            nodes.append(node)
                    elif line.startswith('ss://'):
                        node = parse_ss(line)
                        if node:
                            nodes.append(node)
                    elif line.startswith('hysteria2://'):
                        node = parse_hysteria2(line)
                        if node:
                            nodes.append(node)

            # Save to database
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

            results.append({"id": sub.id, "name": sub.name, "status": "success", "node_count": len(nodes)})

        except Exception as e:
            results.append({"id": sub.id, "name": sub.name, "status": "error", "error": str(e)})

    return {"results": results, "total": len(results), "success": sum(1 for r in results if r["status"] == "success")}

@app.post("/api/subscriptions/{sub_id}/refresh")
def refresh_subscription(sub_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    sub = db.query(Subscription).filter(Subscription.id == sub_id, Subscription.user_id == current_user.id).first()
    if not sub:
        raise HTTPException(status_code=404, detail="Subscription not found")

    # Log refresh start
    audit = AuditLog(user_id=current_user.id, username=current_user.username, action="refresh", resource="subscription", detail=f"refreshing: {sub.name}", ip="unknown", success=1)
    db.add(audit)
    db.commit()

    try:
        # Fetch subscription content
        import base64
        import re

        # Try multiple times with increasing timeout
        content = None

        # Method 1: Try cloudscraper first (bypasses Cloudflare)
        try:
            import cloudscraper
            print("Attempting cloudscraper...")
            scraper = cloudscraper.create_scraper()
            response = scraper.get(sub.url, timeout=60)
            print(f"cloudscraper status: {response.status_code}")
            if response.status_code == 200:
                content = response.text
                print(f"cloudscraper: Got content ({len(content)} bytes)")
        except Exception as e:
            print(f"cloudscraper failed: {e}")

        # Method 2: Fallback to httpx
        if content is None:
            print("Falling back to httpx...")
            for attempt in range(3):
                try:
                    response = httpx.get(sub.url, timeout=60, follow_redirects=True)
                    print(f"httpx attempt {attempt + 1}: HTTP {response.status_code}")
                    if response.status_code == 200:
                        content = response.text
                        break
                except Exception as e:
                    print(f"httpx attempt {attempt + 1}: {e}")
                    if attempt < 2:
                        import time
                        time.sleep(2)

        if content is None:
            raise Exception("Failed to fetch subscription after 3 attempts")

        print(f"Fetched content length: {len(content)}")

        # Try to decode base64
        try:
            decoded = base64.b64decode(content).decode('utf-8')
        except:
            decoded = content

        # Parse nodes from decoded content
        lines = decoded.strip().split('\n')
        nodes = []

        # Check if it's Clash YAML format (check both original and decoded)
        is_clash_yaml = False
        if 'proxies:' in content or 'proxy-providers:' in content:
            is_clash_yaml = True
            print("Detected Clash YAML format in original content")
        elif 'proxies:' in decoded or 'proxy-providers:' in decoded:
            is_clash_yaml = True
            print("Detected Clash YAML format in decoded content")

        if is_clash_yaml:
            nodes = parse_clash_yaml(content)
        else:
            # Parse vless://, vmess://, trojan://, ss://, hysteria2://
            for line in lines:
                line = line.strip()
                if not line:
                    continue

                if line.startswith('vless://'):
                    node = parse_vless(line)
                    if node:
                        nodes.append(node)
                elif line.startswith('vmess://'):
                    node = parse_vmess(line)
                    if node:
                        nodes.append(node)
                elif line.startswith('trojan://'):
                    node = parse_trojan(line)
                    if node:
                        nodes.append(node)
                elif line.startswith('ss://'):
                    node = parse_ss(line)
                    if node:
                        nodes.append(node)
                elif line.startswith('hysteria2://'):
                    node = parse_hysteria2(line)
                    if node:
                        nodes.append(node)

        print(f"Parsed {len(nodes)} nodes from {len(lines)} lines")

        # Delete old nodes
        db.query(Node).filter(Node.subscription_id == sub.id).delete()

        # Add new nodes
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

        # Update subscription
        sub.node_count = len(nodes)
        sub.last_fetch = get_current_time()
        db.commit()

        return {"message": "refreshed", "node_count": len(nodes)}

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Refresh failed: {str(e)}")

def parse_vless(line: str) -> dict:
    """Parse vless:// link"""
    try:
        # vless://uuid@server:port?params#name
        match = re.match(r'vless://([^@]+)@([^:]+):(\d+)\?(.+)#(.+)', line)
        if match:
            uuid, server, port, params, name = match.groups()
            from urllib.parse import unquote
            name = unquote(name)
            region = detect_region(server)
            return {
                'name': name,
                'type': 'vless',
                'server': server,
                'port': int(port),
                'region': region,
                'uuid': uuid,
                'params': params
            }
    except:
        pass
    return None

def parse_vmess(line: str) -> dict:
    """Parse vmess:// link"""
    try:
        # vmess://base64encoded
        match = re.match(r'vmess://(.+)', line)
        if match:
            decoded = base64.b64decode(match.group(1)).decode('utf-8')
            data = json.loads(decoded)
            server = data.get('add', '')
            port = int(data.get('port', 0))
            name = data.get('ps', 'Unknown')
            from urllib.parse import unquote
            name = unquote(name)
            region = detect_region(server)
            return {
                'name': name,
                'type': 'vmess',
                'server': server,
                'port': port,
                'region': region,
                'data': data
            }
        else:
            print(f"vmess regex failed for: {line[:50]}")
    except Exception as e:
        print(f"vmess parse error: {e}")
    return None

def parse_trojan(line: str) -> dict:
    """Parse trojan:// link"""
    try:
        # trojan://password@server:port?params#name
        match = re.match(r'trojan://([^@]+)@([^:]+):(\d+)\?(.+)#(.+)', line)
        if match:
            password, server, port, params, name = match.groups()
            from urllib.parse import unquote
            name = unquote(name)
            region = detect_region(server)
            return {
                'name': name,
                'type': 'trojan',
                'server': server,
                'port': int(port),
                'region': region,
                'password': password,
                'params': params
            }
    except:
        pass
    return None

def parse_ss(line: str) -> dict:
    """Parse ss:// link"""
    try:
        # ss://base64encoded@server:port#name
        match = re.match(r'ss://([^@]+)@([^:]+):(\d+)#(.+)', line)
        if match:
            encoded, server, port, name = match.groups()
            from urllib.parse import unquote
            name = unquote(name)

            # Decode base64 to get password and cipher
            try:
                decoded = base64.b64decode(encoded + '==').decode('utf-8')
                if ':' in decoded:
                    cipher, password = decoded.split(':', 1)
                else:
                    cipher = 'aes-256-gcm'
                    password = decoded
            except:
                cipher = 'aes-256-gcm'
                password = encoded

            region = detect_region(server)
            return {
                'name': name,
                'type': 'ss',
                'server': server,
                'port': int(port),
                'region': region,
                'password': password,
                'cipher': cipher
            }
        else:
            print(f"ss regex failed for: {line[:50]}")
    except Exception as e:
        print(f"ss parse error: {e}")
    return None

def parse_hysteria2(line: str) -> dict:
    """Parse hysteria2:// link"""
    try:
        # hysteria2://auth@server:port?params#name
        match = re.match(r'hysteria2://([^@]+)@([^:]+):(\d+)\?(.+)#(.+)', line)
        if match:
            auth, server, port, params, name = match.groups()
            from urllib.parse import unquote
            name = unquote(name)
            region = detect_region(server)
            return {
                'name': name,
                'type': 'hysteria2',
                'server': server,
                'port': int(port),
                'region': region,
                'auth': auth,
                'params': params
            }
    except:
        pass
    return None

def detect_region(server: str) -> str:
    """Detect region from server address"""
    server_lower = server.lower()
    if 'hk' in server_lower or 'hongkong' in server_lower or 'hong kong' in server_lower:
        return 'HK'
    elif 'jp' in server_lower or 'japan' in server_lower:
        return 'JP'
    elif 'sg' in server_lower or 'singapore' in server_lower:
        return 'SG'
    elif 'us' in server_lower or 'usa' in server_lower or 'united states' in server_lower:
        return 'US'
    elif 'tw' in server_lower or 'taiwan' in server_lower:
        return 'TW'
    elif 'kr' in server_lower or 'korea' in server_lower:
        return 'KR'
    elif 'uk' in server_lower or 'united kingdom' in server_lower or 'britain' in server_lower:
        return 'UK'
    elif 'de' in server_lower or 'germany' in server_lower:
        return 'DE'
    else:
        return 'OTHER'

def parse_clash_yaml(content: str) -> list:
    """Parse Clash/Mihomo YAML subscription format"""
    nodes = []
    try:
        from urllib.parse import unquote
        data = yaml.safe_load(content)
        if not data:
            return nodes

        # Parse proxies directly
        if 'proxies' in data:
            for proxy in data['proxies']:
                proxy_type = proxy.get('type', '').lower()
                name = unquote(proxy.get('name', 'Unknown'))
                server = proxy.get('server', '')
                port = proxy.get('port', 0)

                if not server or not port:
                    continue

                region = detect_region(server)
                node = {
                    'name': name,
                    'type': proxy_type,
                    'server': server,
                    'port': int(port),
                    'region': region,
                    'data': proxy
                }
                nodes.append(node)

        # Parse proxy-providers (fetch from URL)
        if 'proxy-providers' in data:
            for provider_name, provider in data['proxy-providers'].items():
                provider_url = provider.get('url', '')
                if provider_url:
                    print(f"Fetching proxy-provider: {provider_name} from {provider_url}")
                    try:
                        provider_response = httpx.get(provider_url, timeout=30, follow_redirects=True)
                        if provider_response.status_code == 200:
                            provider_data = yaml.safe_load(provider_response.text)
                            if provider_data and 'proxies' in provider_data:
                                for proxy in provider_data['proxies']:
                                    proxy_type = proxy.get('type', '').lower()
                                    name = unquote(proxy.get('name', 'Unknown'))
                                    server = proxy.get('server', '')
                                    port = proxy.get('port', 0)

                                    if not server or not port:
                                        continue

                                    region = detect_region(server)
                                    node = {
                                        'name': name,
                                        'type': proxy_type,
                                        'server': server,
                                        'port': int(port),
                                        'region': region,
                                        'data': proxy
                                    }
                                    nodes.append(node)
                    except Exception as e:
                        print(f"Failed to fetch provider {provider_name}: {e}")

    except Exception as e:
        print(f"Clash YAML parse error: {e}")

    return nodes

@app.get("/api/nodes/all")
def get_all_nodes(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Get all nodes from all subscriptions for the current user"""
    subs = db.query(Subscription).filter(Subscription.user_id == current_user.id, Subscription.status == 1).all()
    sub_ids = [s.id for s in subs]

    if not sub_ids:
        return []

    nodes = db.query(Node).filter(Node.subscription_id.in_(sub_ids)).all()
    return [
        {
            "id": n.id,
            "name": n.name,
            "display_name": n.display_name,
            "node_type": n.node_type,
            "server": n.server,
            "port": n.port,
            "region": n.region,
            "latency": n.latency,
            "status": n.status,
            "subscription_id": n.subscription_id,
            "subscription_name": next((s.name for s in subs if s.id == n.subscription_id), "")
        }
        for n in nodes
    ]

@app.post("/api/nodes/import")
def import_nodes(uris: str = Body(...), current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Import individual node URIs (vmess://, vless://, trojan://, ss://, hysteria2://)"""
    # Find or create "手动导入" subscription
    sub = db.query(Subscription).filter(
        Subscription.user_id == current_user.id,
        Subscription.name == "手动导入"
    ).first()

    if not sub:
        sub = Subscription(
            user_id=current_user.id,
            token=generate_token(),
            name="手动导入",
            url="manual",
            status=1
        )
        db.add(sub)
        db.commit()
        db.refresh(sub)

    # Parse each line
    lines = [line.strip() for line in uris.strip().split('\n') if line.strip()]
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
                # Check for duplicate server:port
                existing = db.query(Node).filter(
                    Node.subscription_id == sub.id,
                    Node.server == node_data.get("server"),
                    Node.port == node_data.get("port")
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
        except:
            continue

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
    """Check health of nodes in a subscription"""
    sub = db.query(Subscription).filter(Subscription.id == sub_id, Subscription.user_id == current_user.id).first()
    if not sub:
        raise HTTPException(status_code=404, detail="Subscription not found")

    nodes = db.query(Node).filter(Node.subscription_id == sub.id).all()
    total = len(nodes)
    online = 0
    offline = 0

    import socket
    import concurrent.futures

    for node in nodes:
        try:
            def test_connection(port):
                try:
                    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                    sock.settimeout(2)
                    result = sock.connect_ex((node.server, port))
                    sock.close()
                    return result == 0
                except:
                    return False

            # Test common ports
            test_ports = [node.port, 80, 443, 8080, 8443]
            is_online = False

            with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
                futures = {executor.submit(test_connection, port): port for port in test_ports}
                for future in concurrent.futures.as_completed(futures, timeout=5):
                    try:
                        if future.result():
                            is_online = True
                            break
                    except:
                        pass

            # Fallback: DNS resolution
            if not is_online:
                try:
                    socket.gethostbyname(node.server)
                    is_online = True
                except:
                    pass

            if is_online:
                online += 1
                node.status = 1
            else:
                offline += 1
                node.status = 0

        except Exception as e:
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
            import socket
            import time
            import concurrent.futures

            def test_connection(port):
                """Test TCP connection to a port"""
                try:
                    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                    sock.settimeout(2)  # 2 second timeout per port
                    start_time = time.time()
                    result = sock.connect_ex((node.server, port))
                    end_time = time.time()
                    sock.close()
                    if result == 0:
                        return int((end_time - start_time) * 1000)
                    return None
                except:
                    return None

            # Try multiple ports in parallel
            test_ports = [node.port, 80, 443, 8080, 8443]
            latency = None

            with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
                futures = {executor.submit(test_connection, port): port for port in test_ports}
                for future in concurrent.futures.as_completed(futures, timeout=5):
                    try:
                        result = future.result()
                        if result is not None and latency is None:
                            latency = result
                    except:
                        pass

            if latency is not None:
                node.latency = latency
                results.append({
                    "id": node.id,
                    "name": node.name,
                    "latency": latency,
                    "status": "success"
                })
            else:
                # If no port responds, try DNS resolution as a fallback
                try:
                    import socket
                    socket.gethostbyname(node.server)
                    node.latency = 999  # Mark as reachable but slow
                    results.append({
                        "id": node.id,
                        "name": node.name,
                        "latency": 999,
                        "status": "success"
                    })
                except:
                    node.latency = -1
                    results.append({
                        "id": node.id,
                        "name": node.name,
                        "latency": -1,
                        "status": "failed"
                    })

        except Exception as e:
            node.latency = -1
            results.append({"id": node.id, "name": node.name, "latency": -1, "status": "error"})

    # Save latency to database
    db.commit()

    return {"results": results, "total": len(results), "success": sum(1 for r in results if r["status"] == "success")}

@app.post("/api/nodes/speedtest-all")
def speedtest_all_nodes(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Test latency for all nodes across all subscriptions"""
    # Get all subscriptions for the current user
    subs = db.query(Subscription).filter(Subscription.user_id == current_user.id, Subscription.status == 1).all()
    sub_ids = [s.id for s in subs]

    if not sub_ids:
        return {"results": [], "total": 0, "success": 0}

    # Get all nodes
    nodes = db.query(Node).filter(Node.subscription_id.in_(sub_ids)).all()
    results = []

    for node in nodes:
        try:
            import socket
            import time
            import concurrent.futures

            def test_connection(port):
                """Test TCP connection to a port"""
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
                except:
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
                    except:
                        pass

            if latency is not None:
                node.latency = latency
                results.append({
                    "id": node.id,
                    "name": node.name,
                    "latency": latency,
                    "status": "success"
                })
            else:
                try:
                    socket.gethostbyname(node.server)
                    node.latency = 999
                    results.append({
                        "id": node.id,
                        "name": node.name,
                        "latency": 999,
                        "status": "success"
                    })
                except:
                    node.latency = -1
                    results.append({
                        "id": node.id,
                        "name": node.name,
                        "latency": -1,
                        "status": "failed"
                    })

        except Exception as e:
            node.latency = -1
            results.append({"id": node.id, "name": node.name, "latency": -1, "status": "error"})

    # Save latency to database
    db.commit()

    return {"results": results, "total": len(results), "success": sum(1 for r in results if r["status"] == "success")}

@app.get("/api/formats")
def list_formats():
    return {"formats": ["clash", "singbox", "surge", "loon", "quanx", "base64"]}

@app.post("/api/convert")
def convert(req: ConvertRequest):
    # Simple base64 decode
    import base64
    if req.source:
        try:
            decoded = base64.b64decode(req.source).decode()
            return {"result": decoded, "format": "detected"}
        except:
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
    sub = db.query(Subscription).filter(Subscription.token == token, Subscription.status == 1).first()
    if not sub:
        raise HTTPException(status_code=404, detail="Subscription not found")

    nodes = db.query(Node).filter(Node.subscription_id == sub.id).all()

    if target == "clash" or target == "mihomo":
        yaml_content = generate_clash_yaml(nodes)
        from fastapi.responses import PlainTextResponse
        return PlainTextResponse(yaml_content, media_type="text/yaml")
    elif target == "singbox":
        json_content = generate_singbox_json(nodes)
        from fastapi.responses import PlainTextResponse
        return PlainTextResponse(json_content, media_type="application/json")
    elif target == "base64":
        base64_content = generate_base64_subscription(nodes)
        from fastapi.responses import PlainTextResponse
        return PlainTextResponse(base64_content, media_type="text/plain")
    else:
        lines = []
        for node in nodes:
            if node.node_type == "vless":
                lines.append(f"vless://{node.server}:{node.port}")
            elif node.node_type == "vmess":
                lines.append(f"vmess://{node.server}:{node.port}")
            elif node.node_type == "trojan":
                lines.append(f"trojan://{node.server}:{node.port}")
            elif node.node_type == "ss":
                lines.append(f"ss://{node.server}:{node.port}")

        from fastapi.responses import PlainTextResponse
        return PlainTextResponse("\n".join(lines), media_type="text/plain")

@app.get("/sub/{token}/export/group")
def export_subscription_by_group(
    token: str,
    target: str = "clash",
    group_by: str = "region",
    group_value: str = "",
    db: Session = Depends(get_db)
):
    """Export subscription filtered by group (region/type/status)"""
    from fastapi.responses import PlainTextResponse

    sub = db.query(Subscription).filter(Subscription.token == token, Subscription.status == 1).first()
    if not sub:
        raise HTTPException(status_code=404, detail="Subscription not found")

    nodes = db.query(Node).filter(Node.subscription_id == sub.id).all()

    # Filter nodes by group criteria
    if group_by == "region":
        nodes = [n for n in nodes if (n.region or "OTHER") == group_value]
    elif group_by == "type":
        nodes = [n for n in nodes if n.node_type == group_value]
    elif group_by == "status":
        is_online = group_value == "在线"
        nodes = [n for n in nodes if (n.status == 1) == is_online]

    if not nodes:
        raise HTTPException(status_code=404, detail="No nodes found for this group")

    if target == "clash" or target == "mihomo":
        yaml_content = generate_clash_yaml(nodes)
        return PlainTextResponse(yaml_content, media_type="text/yaml")
    elif target == "singbox":
        json_content = generate_singbox_json(nodes)
        return PlainTextResponse(json_content, media_type="application/json")
    elif target == "base64":
        base64_content = generate_base64_subscription(nodes)
        return PlainTextResponse(base64_content, media_type="text/plain")
    else:
        lines = []
        for node in nodes:
            if node.node_type == "vless":
                lines.append(f"vless://{node.server}:{node.port}")
            elif node.node_type == "vmess":
                lines.append(f"vmess://{node.server}:{node.port}")
            elif node.node_type == "trojan":
                lines.append(f"trojan://{node.server}:{node.port}")
            elif node.node_type == "ss":
                lines.append(f"ss://{node.server}:{node.port}")
        return PlainTextResponse("\n".join(lines), media_type="text/plain")

def generate_clash_yaml(nodes: list) -> str:
    """Generate Clash/Mihomo YAML format"""
    import yaml
    import json
    import uuid

    proxies = []
    proxy_names = []
    name_count = {}

    for node in nodes:
        # Get full config from database
        if node.config_json:
            try:
                config_data = json.loads(node.config_json) if isinstance(node.config_json, str) else node.config_json
            except:
                config_data = {}
        else:
            config_data = {}

        # Handle duplicate names by adding suffix
        name = node.name
        if name in name_count:
            name_count[name] += 1
            name = f"{name}_{name_count[name]}"
        else:
            name_count[name] = 1

        proxy = {
            "name": name,
            "type": node.node_type,
            "server": node.server,
            "port": node.port,
        }

        if node.node_type == "vless":
            # Check both direct and nested data field
            proxy["uuid"] = config_data.get("uuid", config_data.get("data", {}).get("uuid", str(uuid.uuid4())))
            proxy["udp"] = True

            # Parse params string if exists
            params_str = config_data.get("params", config_data.get("data", {}).get("params", ""))
            params = {}
            if params_str:
                for param in params_str.split("&"):
                    if "=" in param:
                        key, value = param.split("=", 1)
                        params[key] = value

            # Fix server address - use host or sni if server is placeholder
            server = node.server
            if server in ["127.0.0.1", "0.0.0.0", "localhost"]:
                server = params.get("host", params.get("sni", server))
            proxy["server"] = server

            # TLS settings
            proxy["tls"] = config_data.get("tls", config_data.get("data", {}).get("tls", False))
            if params.get("security") == "tls" or params.get("security") == "reality":
                proxy["tls"] = True

            if proxy["tls"]:
                # Try sni first, then host, then server
                servername = config_data.get("servername", config_data.get("data", {}).get("servername", ""))
                if not servername:
                    servername = params.get("sni", "")
                if not servername:
                    servername = params.get("host", "")
                if not servername:
                    servername = server
                proxy["servername"] = servername

            # Network settings
            network = config_data.get("net", config_data.get("data", {}).get("net", params.get("type", "tcp")))
            if network == "ws":
                proxy["network"] = "ws"
                proxy["ws-opts"] = config_data.get("ws-opts", config_data.get("data", {}).get("ws-opts", {"path": params.get("path", "/")}))
            elif network == "grpc":
                proxy["network"] = "grpc"
                proxy["grpc-opts"] = config_data.get("grpc-opts", config_data.get("data", {}).get("grpc-opts", {"grpc-service-name": params.get("serviceName", "")}))
            elif network == "h2":
                proxy["network"] = "h2"

            # Reality settings
            if params.get("security") == "reality":
                proxy["flow"] = params.get("flow", "xtls-rprx-vision")
                proxy["client-fingerprint"] = params.get("fp", "chrome")
                proxy["reality-opts"] = {
                    "public-key": params.get("pbk", ""),
                    "short-id": params.get("sid", "")
                }
                # Skip cert verify for reality
                if params.get("insecure") == "0":
                    proxy["skip-cert-verify"] = False
                else:
                    proxy["skip-cert-verify"] = True
            else:
                # Regular flow settings
                flow = config_data.get("flow", config_data.get("data", {}).get("flow", params.get("flow", "")))
                if flow:
                    proxy["flow"] = flow

            # Client fingerprint
            fp = config_data.get("fp", config_data.get("data", {}).get("fp", params.get("fp", "")))
            if fp:
                proxy["client-fingerprint"] = fp

        elif node.node_type == "vmess":
            proxy["uuid"] = config_data.get("id", str(uuid.uuid4()))
            proxy["alterId"] = config_data.get("aid", 0)
            proxy["cipher"] = config_data.get("scy", "auto")
            proxy["udp"] = True
            # Network settings
            net = config_data.get("net", "tcp")
            if net == "ws":
                proxy["network"] = "ws"
                proxy["ws-opts"] = config_data.get("ws-opts", {"path": "/"})
            elif net == "grpc":
                proxy["network"] = "grpc"
                proxy["grpc-opts"] = config_data.get("grpc-opts", {"grpc-service-name": ""})
            elif net == "h2":
                proxy["network"] = "h2"
                proxy["h2-opts"] = config_data.get("h2-opts", {})
            # TLS settings
            if config_data.get("tls"):
                proxy["tls"] = True
                proxy["servername"] = config_data.get("host", node.server)

        elif node.node_type == "trojan":
            # Check both direct and nested data field
            password = config_data.get("password", "")
            if not password and "data" in config_data:
                password = config_data["data"].get("password", "")
            proxy["password"] = password
            proxy["udp"] = True
            proxy["sni"] = config_data.get("sni", config_data.get("data", {}).get("sni", node.server))
            if config_data.get("skip-cert-verify") or config_data.get("data", {}).get("skip-cert-verify"):
                proxy["skip-cert-verify"] = True

        elif node.node_type == "ss":
            # Check both direct and nested data field
            password = config_data.get("password", "")
            if not password and "data" in config_data:
                password = config_data["data"].get("password", "")
            proxy["password"] = password or "password"
            proxy["cipher"] = config_data.get("cipher", config_data.get("data", {}).get("cipher", "aes-256-gcm"))
            if config_data.get("udp") or config_data.get("data", {}).get("udp"):
                proxy["udp"] = True

        elif node.node_type == "hysteria2":
            # Check both direct and nested data field
            password = config_data.get("password", "")
            if not password and "data" in config_data:
                password = config_data["data"].get("password", "")
            proxy["password"] = password
            proxy["ports"] = config_data.get("ports", config_data.get("data", {}).get("ports", ""))
            if config_data.get("obfs") or config_data.get("data", {}).get("obfs"):
                proxy["obfs"] = config_data.get("obfs", config_data.get("data", {}).get("obfs", {}))
                proxy["obfs-password"] = config_data.get("obfs-password", config_data.get("data", {}).get("obfs-password", ""))

        elif node.node_type == "tuic":
            # Check both direct and nested data field
            password = config_data.get("password", "")
            if not password and "data" in config_data:
                password = config_data["data"].get("password", "")
            proxy["password"] = password
            proxy["udp-relay"] = True
            if config_data.get("uuid"):
                proxy["uuid"] = config_data["uuid"]
            elif config_data.get("data", {}).get("uuid"):
                proxy["uuid"] = config_data["data"]["uuid"]

        elif node.node_type == "anytls":
            # Check both direct and nested data field
            password = config_data.get("password", "")
            if not password and "data" in config_data:
                password = config_data["data"].get("password", "")
            proxy["password"] = password
            proxy["udp"] = True
            if config_data.get("sni"):
                proxy["sni"] = config_data["sni"]
            elif config_data.get("data", {}).get("sni"):
                proxy["sni"] = config_data["data"]["sni"]

        proxies.append(proxy)
        proxy_names.append(name)

    config = {
        "proxies": proxies,
        "proxy-groups": [
            {
                "name": "节点选择",
                "type": "select",
                "proxies": ["自动选择", "负载均衡", "DIRECT"] + proxy_names
            },
            {
                "name": "自动选择",
                "type": "url-test",
                "proxies": proxy_names,
                "url": "http://www.gstatic.com/generate_204",
                "interval": 300,
                "tolerance": 50
            },
            {
                "name": "负载均衡",
                "type": "load-balance",
                "proxies": proxy_names,
                "url": "http://www.gstatic.com/generate_204",
                "interval": 300
            }
        ],
        "rules": [
            "GEOIP,CN,DIRECT",
            "MATCH,节点选择"
        ]
    }

    return yaml.dump(config, allow_unicode=True, default_flow_style=False)

def generate_singbox_json(nodes: list) -> str:
    """Generate sing-box JSON format"""
    import json

    outbounds = []
    for node in nodes:
        outbound = {
            "type": node.node_type,
            "tag": node.name,
            "server": node.server,
            "server_port": node.port,
        }
        if node.node_type == "vless":
            outbound["flow"] = ""
        elif node.node_type == "vmess":
            outbound["security"] = "auto"
        elif node.node_type == "trojan":
            pass
        elif node.node_type == "ss":
            outbound["method"] = "aes-256-gcm"

        outbounds.append(outbound)

    config = {
        "outbounds": [
            {"type": "selector", "tag": "节点选择", "outbounds": ["自动选择"] + [n.name for n in nodes]},
            {"type": "urltest", "tag": "自动选择", "outbounds": [n.name for n in nodes], "url": "http://www.gstatic.com/generate_204", "interval": "5m"}
        ] + outbounds
    }

    return json.dumps(config, ensure_ascii=False, indent=2)

def generate_base64_subscription(nodes: list) -> str:
    """Generate base64 encoded subscription"""
    import base64

    lines = []
    for node in nodes:
        if node.node_type == "vless":
            lines.append(f"vless://{node.server}:{node.port}")
        elif node.node_type == "vmess":
            lines.append(f"vmess://{node.server}:{node.port}")
        elif node.node_type == "trojan":
            lines.append(f"trojan://{node.server}:{node.port}")
        elif node.node_type == "ss":
            lines.append(f"ss://{node.server}:{node.port}")

    content = "\n".join(lines)
    return base64.b64encode(content.encode()).decode()

@app.get("/api/metrics")
def get_metrics(db: Session = Depends(get_db)):
    import time
    import os

    users = db.query(User).count()
    subs = db.query(Subscription).count()
    nodes = db.query(Node).count()

    # Get process memory
    process_memory_mb = 0
    try:
        with open('/proc/self/status', 'r') as f:
            for line in f:
                if line.startswith('VmRSS:'):
                    memory_kb = int(line.split()[1])
                    process_memory_mb = memory_kb / 1024
                    break
    except:
        pass

    # Get system memory
    system_memory_mb = 0
    try:
        with open('/proc/meminfo', 'r') as f:
            for line in f:
                if line.startswith('MemTotal:'):
                    memory_kb = int(line.split()[1])
                    system_memory_mb = memory_kb / 1024
                    break
    except:
        pass

    # Calculate uptime
    global start_time
    uptime = int(time.time() - start_time) if 'start_time' in globals() else 0

    return {
        "users": users,
        "subscriptions": subs,
        "nodes": nodes,
        "uptime_seconds": uptime,
        "memory": {
            "alloc_mb": round(process_memory_mb, 2),
            "total_mb": round(system_memory_mb, 2)
        },
        "goroutines": 1,
        "cpu_percent": 0,
        "go_version": "Python 3.11",
        "database": {
            "users": users,
            "subscriptions": subs,
            "nodes": nodes
        }
    }

# Record start time
import time
start_time = time.time()

@app.get("/api/version")
def get_version():
    # Read version from VERSION file
    try:
        with open('/app/VERSION', 'r') as f:
            version = f.read().strip()
    except:
        version = "1.0.0"

    return {
        "version": version,
        "name": "SubForge",
        "description": "VPN 订阅链接统一转换平台",
        "python_version": "3.11",
        "fastapi_version": "0.109.0"
    }

@app.get("/api/update/version")
def get_update_version():
    # Read version from VERSION file
    try:
        with open('/app/VERSION', 'r') as f:
            current_version = f.read().strip()
    except:
        current_version = "1.0.0"

    # Read commit hash from COMMIT file
    try:
        with open('/app/COMMIT', 'r') as f:
            current_commit = f.read().strip()
    except:
        current_commit = ""

    return {
        "current": current_version,
        "current_tag": current_version,
        "current_commit": current_commit,
        "latest": current_version,
        "latest_tag": current_version,
        "has_update": False,
        "changelog": "",
        "last_check": "",
        "update_mode": "tag",
        "updating": False
    }

@app.get("/api/update/releases")
def get_releases():
    # Read version from VERSION file
    try:
        with open('/app/VERSION', 'r') as f:
            current_version = f.read().strip()
    except:
        current_version = "1.0.0"

    return [
        {
            "tag": current_version,
            "commit_hash": "",
            "message": f"Version {current_version}",
            "date": "",
            "is_current": True
        }
    ]

@app.get("/api/update/status")
def get_update_status():
    return {"updating": False, "last_result": None}

@app.get("/api/update/changelog")
def get_changelog():
    return [
        {
            "hash": "latest",
            "message": "Initial release",
            "date": "2026-06-15"
        }
    ]

@app.post("/api/update/latest")
def update_to_latest():
    return {"success": True, "from": "1.0.0", "to": "1.0.0", "steps": [], "timestamp": ""}

@app.post("/api/update/tag")
def update_to_tag():
    return {"success": True, "from": "1.0.0", "to": "1.0.0", "steps": [], "timestamp": ""}

@app.post("/api/update/rollback")
def rollback():
    return {"success": True, "from": "1.0.0", "to": "1.0.0", "steps": [], "timestamp": ""}

@app.get("/api/audit")
def get_audit(current_user: User = Depends(require_admin), db: Session = Depends(get_db)):
    logs = db.query(AuditLog).order_by(AuditLog.created_at.desc()).limit(100).all()

    # Convert UTC to CST for display
    result = []
    for l in logs:
        created_at = l.created_at
        if created_at:
            # Add UTC timezone and convert to CST
            created_at_utc = created_at.replace(tzinfo=timezone.utc)
            created_at_cst = created_at_utc.astimezone(CST)
            created_at_str = created_at_cst.strftime("%Y-%m-%d %H:%M:%S")
        else:
            created_at_str = ""

        result.append({
            "id": l.id,
            "user_id": l.user_id,
            "username": l.username,
            "action": l.action,
            "resource": l.resource,
            "detail": l.detail,
            "ip": l.ip,
            "success": l.success,
            "created_at": created_at_str
        })

    return {"logs": result}

# ─── Run ──────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8081)
