from datetime import datetime, timedelta, timezone

# 东八区 (UTC+8)
CST = timezone(timedelta(hours=8))


def get_current_time():
    """获取当前东八区时间"""
    return datetime.now(CST)


def get_utc_time():
    """获取 UTC 时间"""
    return datetime.utcnow()
