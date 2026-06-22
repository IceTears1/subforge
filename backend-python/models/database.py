import os
import logging
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from typing import Generator

logger = logging.getLogger(__name__)

# ─── Config ───────────────────────────────────────────────────────────────────
DATABASE_URL = f"postgresql://{os.getenv('DB_USER', 'subforge')}:{os.getenv('DB_PASSWORD', 'subforge123')}@{os.getenv('DB_HOST', 'localhost')}:{os.getenv('DB_PORT', '5432')}/{os.getenv('DB_NAME', 'subforge')}"

# ─── Database ─────────────────────────────────────────────────────────────────
engine = create_engine(DATABASE_URL, pool_pre_ping=True, pool_size=10, max_overflow=20)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

def get_db() -> Generator[Session, None, None]:
    """获取数据库会话"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def init_db():
    """初始化数据库表"""
    Base.metadata.create_all(bind=engine)
    logger.info("Database tables created/verified")
