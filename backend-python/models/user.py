from datetime import datetime
from sqlalchemy import Column, Integer, String, DateTime
from .database import Base
from ..utils.time import get_current_time


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(64), unique=True, nullable=False)
    password = Column(String(128), nullable=False)
    role = Column(String(16), default="user")
    status = Column(Integer, default=1)
    created_at = Column(DateTime, default=get_current_time)
    updated_at = Column(DateTime, default=get_current_time, onupdate=get_current_time)

    def __repr__(self):
        return f"<User(id={self.id}, username={self.username}, role={self.role})>"
