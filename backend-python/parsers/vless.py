import re
import logging
from urllib.parse import unquote
from .common import detect_region

logger = logging.getLogger(__name__)


def parse_vless(line: str) -> dict:
    """Parse vless:// link"""
    try:
        # vless://uuid@server:port?params#name
        match = re.match(r'vless://([^@]+)@([^:]+):(\d+)\?(.+)#(.+)', line)
        if match:
            uuid, server, port, params, name = match.groups()
            name = unquote(name)
            region = detect_region(server)
            return {
                'name': name,
                'type': 'vless',
                'server': server,
                'port': int(port),
                'region': region,
                'uuid': uuid,
                'params': params
            }
    except Exception as e:
        logger.warning(f"vless parse error: {e}")
    return None
