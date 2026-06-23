from sqlalchemy import Column, Integer, String, DateTime, ForeignKey
from .database import Base
from utils.time import get_current_time


class APIKey(Base):
    __tablename__ = "api_keys"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), index=True)
    name = Column(String(128))
    key = Column(String(64), unique=True, index=True)
    status = Column(Integer, default=1)
    created_at = Column(DateTime, default=get_current_time)

    def __repr__(self):
        return f"<APIKey(id={self.id}, name={self.name})>"
