import re
import json
import base64
import logging
from urllib.parse import unquote
from .common import detect_region

logger = logging.getLogger(__name__)


def parse_vmess(line: str) -> dict:
    """Parse vmess:// link"""
    try:
        # vmess://base64encoded
        match = re.match(r'vmess://(.+)', line)
        if match:
            decoded = base64.b64decode(match.group(1)).decode('utf-8')
            data = json.loads(decoded)
            server = data.get('add', '')
            port = int(data.get('port', 0))
            name = data.get('ps', 'Unknown')
            name = unquote(name)
            region = detect_region(server)
            return {
                'name': name,
                'type': 'vmess',
                'server': server,
                'port': port,
                'region': region,
                'data': data
            }
        else:
            logger.warning(f"vmess regex failed for: {line[:50]}")
    except Exception as e:
        logger.warning(f"vmess parse error: {e}")
    return None
