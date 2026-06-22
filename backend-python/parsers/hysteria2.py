import re
import logging
from urllib.parse import unquote
from .common import detect_region

logger = logging.getLogger(__name__)


def parse_hysteria2(line: str) -> dict:
    """Parse hysteria2:// link"""
    try:
        # hysteria2://password@server:port?params#name
        match = re.match(r'hysteria2://([^@]+)@([^:]+):(\d+)\?(.+)#(.+)', line)
        if match:
            password, server, port, params, name = match.groups()
            name = unquote(name)
            region = detect_region(server)
            return {
                'name': name,
                'type': 'hysteria2',
                'server': server,
                'port': int(port),
                'region': region,
                'password': password,
                'params': params
            }
    except Exception as e:
        logger.warning(f"hysteria2 parse error: {e}")
    return None
