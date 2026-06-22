from datetime import datetime
from sqlalchemy import Column, Integer, String, Text, DateTime, ForeignKey, JSON
from sqlalchemy.orm import relationship
from .database import Base
from ..utils.time import get_current_time


class Subscription(Base):
    __tablename__ = "subscriptions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), index=True)
    token = Column(String(32), unique=True, index=True)
    name = Column(String(128), nullable=False)
    url = Column(Text, nullable=False)
    auto_refresh = Column(Integer, default=3600)
    tags = Column(JSON, default=list)
    last_fetch = Column(DateTime)
    node_count = Column(Integer, default=0)
    status = Column(Integer, default=1)
    created_at = Column(DateTime, default=get_current_time)
    updated_at = Column(DateTime, default=get_current_time, onupdate=get_current_time)

    nodes = relationship("Node", back_populates="subscription", cascade="all, delete-orphan")

    def __repr__(self):
        return f"<Subscription(id={self.id}, name={self.name})>"
