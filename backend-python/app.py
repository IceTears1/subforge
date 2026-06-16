import os
import json
import secrets
import hashlib
import re
import yaml
from datetime import datetime, timedelta
from typing import Optional, List

from fastapi import FastAPI, Depends, HTTPException, status
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
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

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
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
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
    latency = Column(Integer)
    status = Column(Integer, default=1)
    created_at = Column(DateTime, default=datetime.utcnow)
    subscription = relationship("Subscription", back_populates="nodes")

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
    expire = datetime.utcnow() + timedelta(hours=24)
    to_encode.update({"exp": expire})
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
def login(req: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.username == req.username, User.status == 1).first()
    if not user or not verify_password(req.password, user.password):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    token = create_access_token({"sub": user.id, "role": user.role})
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
            sub.last_fetch = datetime.utcnow()
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
        sub.last_fetch = datetime.utcnow()
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
            region = detect_region(server)
            return {
                'name': name,
                'type': 'ss',
                'server': server,
                'port': int(port),
                'region': region
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

@app.post("/api/subscriptions/{sub_id}/nodes/speedtest")
def speedtest_nodes(sub_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    sub = db.query(Subscription).filter(Subscription.id == sub_id, Subscription.user_id == current_user.id).first()
    if not sub:
        raise HTTPException(status_code=404, detail="Subscription not found")

    nodes = db.query(Node).filter(Node.subscription_id == sub.id).all()
    results = []

    for node in nodes:
        try:
            # Test TCP connection latency
            import socket
            import time

            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(3)  # 3 second timeout
            start_time = time.time()
            result = sock.connect_ex((node.server, node.port))
            end_time = time.time()
            sock.close()

            if result == 0:
                latency = int((end_time - start_time) * 1000)  # Convert to ms
                node.latency = latency

                # Test download speed (try HTTP HEAD request)
                download_speed = 0
                try:
                    import httpx
                    # Try common HTTP ports
                    for test_port in [80, 443, 8080, 8443]:
                        try:
                            url = f"http://{node.server}:{test_port}/"
                            response = httpx.head(url, timeout=2, follow_redirects=True)
                            if response.status_code < 500:
                                download_speed = 100  # Mark as reachable
                                break
                        except:
                            pass
                except:
                    pass

                results.append({
                    "id": node.id,
                    "name": node.name,
                    "latency": latency,
                    "download_speed": download_speed,
                    "status": "success"
                })
            else:
                node.latency = -1
                results.append({"id": node.id, "name": node.name, "latency": -1, "download_speed": 0, "status": "failed"})

        except Exception as e:
            node.latency = -1
            results.append({"id": node.id, "name": node.name, "latency": -1, "download_speed": 0, "status": "error"})

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
        # Generate Clash/Mihomo YAML format
        yaml_content = generate_clash_yaml(nodes)
        from fastapi.responses import PlainTextResponse
        return PlainTextResponse(yaml_content, media_type="text/yaml")
    elif target == "singbox":
        # Generate sing-box JSON format
        json_content = generate_singbox_json(nodes)
        from fastapi.responses import PlainTextResponse
        return PlainTextResponse(json_content, media_type="application/json")
    elif target == "base64":
        # Generate base64 encoded subscription
        base64_content = generate_base64_subscription(nodes)
        from fastapi.responses import PlainTextResponse
        return PlainTextResponse(base64_content, media_type="text/plain")
    else:
        # Default: return node list as text
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

def generate_clash_yaml(nodes: list) -> str:
    """Generate Clash/Mihomo YAML format"""
    import yaml

    proxies = []
    proxy_names = []

    for node in nodes:
        proxy = {
            "name": node.name,
            "type": node.node_type,
            "server": node.server,
            "port": node.port,
        }
        if node.node_type == "vless":
            proxy["udp"] = True
        elif node.node_type == "vmess":
            proxy["udp"] = True
            proxy["alterId"] = 0
            proxy["cipher"] = "auto"
        elif node.node_type == "trojan":
            proxy["udp"] = True
        elif node.node_type == "ss":
            proxy["cipher"] = "aes-256-gcm"

        proxies.append(proxy)
        proxy_names.append(node.name)

    config = {
        "proxies": proxies,
        "proxy-groups": [
            {
                "name": "节点选择",
                "type": "select",
                "proxies": ["自动选择", "负载均衡"] + proxy_names
            },
            {
                "name": "自动选择",
                "type": "url-test",
                "proxies": proxy_names,
                "url": "http://www.gstatic.com/generate_204",
                "interval": 300
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
    users = db.query(User).count()
    subs = db.query(Subscription).count()
    nodes = db.query(Node).count()
    return {"users": users, "subscriptions": subs, "nodes": nodes, "uptime_seconds": 0}

@app.get("/api/audit")
def get_audit(current_user: User = Depends(require_admin)):
    return {"logs": []}

# ─── Run ──────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8081)
