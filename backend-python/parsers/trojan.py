import re
import logging
from urllib.parse import unquote
from .common import detect_region

logger = logging.getLogger(__name__)


def parse_trojan(line: str) -> dict:
    """Parse trojan:// link"""
    try:
        # trojan://password@server:port?params#name
        match = re.match(r'trojan://([^@]+)@([^:]+):(\d+)\?(.+)#(.+)', line)
        if match:
            password, server, port, params, name = match.groups()
            name = unquote(name)
            region = detect_region(server)
            return {
                'name': name,
                'type': 'trojan',
                'server': server,
                'port': int(port),
                'region': region,
                'password': password,
                'params': params
            }
    except Exception as e:
        logger.warning(f"trojan parse error: {e}")
    return None
