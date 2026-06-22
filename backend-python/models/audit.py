from datetime import datetime
from sqlalchemy import Column, Integer, String, Text, DateTime
from .database import Base
from ..utils.time import get_current_time


class AuditLog(Base):
    __tablename__ = "audit_logs"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, index=True)
    username = Column(String(64))
    action = Column(String(32))
    resource = Column(String(32))
    detail = Column(Text)
    ip = Column(String(64))
    success = Column(Integer, default=1)
    created_at = Column(DateTime, default=get_current_time, index=True)

    def __repr__(self):
        return f"<AuditLog(id={self.id}, action={self.action}, username={self.username})>"
