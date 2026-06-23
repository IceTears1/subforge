import logging
from sqlalchemy import create_engine, text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from typing import Generator

from config import DATABASE_URL

logger = logging.getLogger(__name__)

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

def migrate_database():
    """Auto-migrate database schema - add missing columns"""
    try:
        from sqlalchemy import inspect

        inspector = inspect(engine)

        # Check nodes table
        if 'nodes' in inspector.get_table_names():
            columns = [col['name'] for col in inspector.get_columns('nodes')]

            with engine.connect() as conn:
                if 'download_speed' not in columns:
                    conn.execute(text("ALTER TABLE nodes ADD COLUMN download_speed DOUBLE PRECISION DEFAULT 0"))
                    conn.commit()
                    logger.info("Migration: Added nodes.download_speed column")

                if 'download_speed_type' not in columns:
                    conn.execute(text("ALTER TABLE nodes ADD COLUMN download_speed_type VARCHAR(20) DEFAULT ''"))
                    conn.commit()
                    logger.info("Migration: Added nodes.download_speed_type column")

        logger.info("Database migration completed")
    except Exception as e:
        logger.warning(f"Migration warning: {e}")
