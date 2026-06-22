from datetime import datetime
from sqlalchemy import Column, Integer, String, Text, DateTime, ForeignKey, JSON
from sqlalchemy.orm import relationship
from .database import Base
from ..utils.time import get_current_time


class Node(Base):
    __tablename__ = "nodes"

    id = Column(Integer, primary_key=True, index=True)
    subscription_id = Column(Integer, ForeignKey("subscriptions.id"), index=True)
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

    def __repr__(self):
        return f"<Node(id={self.id}, name={self.name}, type={self.node_type})>"
