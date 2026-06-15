import os
import json
import secrets
import hashlib
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
        user_id: int = payload.get("sub")
        if user_id is None:
            raise HTTPException(status_code=401, detail="Invalid token")
    except JWTError:
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

@app.get("/api/subscriptions/{sub_id}/nodes")
def get_nodes(sub_id: int, region: str = None, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    sub = db.query(Subscription).filter(Subscription.id == sub_id, Subscription.user_id == current_user.id).first()
    if not sub:
        raise HTTPException(status_code=404, detail="Subscription not found")
    query = db.query(Node).filter(Node.subscription_id == sub.id)
    if region:
        query = query.filter(Node.region == region.upper())
    nodes = query.all()
    return [{"id": n.id, "name": n.name, "node_type": n.node_type, "server": n.server, "port": n.port, "region": n.region, "latency": n.latency} for n in nodes]

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
