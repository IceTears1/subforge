import os
import logging

logger = logging.getLogger(__name__)

# ─── Config ───────────────────────────────────────────────────────────────────
DATABASE_URL = f"postgresql://{os.getenv('DB_USER', 'subforge')}:{os.getenv('DB_PASSWORD', 'subforge123')}@{os.getenv('DB_HOST', 'localhost')}:{os.getenv('DB_PORT', '5432')}/{os.getenv('DB_NAME', 'subforge')}"
JWT_SECRET = os.getenv('JWT_SECRET', 'change-me-in-production')
JWT_EXPIRY = os.getenv('JWT_EXPIRY', '24h')
ADMIN_PASSWORD = os.getenv('ADMIN_PASSWORD', 'admin123')
ADMIN_USERNAME = os.getenv('ADMIN_USERNAME', 'admin')
CORS_ORIGINS = os.getenv('CORS_ORIGINS', '*').split(',')

# 安全检查：启动时验证关键环境变量
if JWT_SECRET == 'change-me-in-production':
    logger.warning("⚠️  JWT_SECRET 使用默认值，请设置环境变量 JWT_SECRET")
if ADMIN_PASSWORD == 'admin123':
    logger.warning("⚠️  ADMIN_PASSWORD 使用默认值，请设置环境变量 ADMIN_PASSWORD")
