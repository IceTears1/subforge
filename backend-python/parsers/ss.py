import re
import base64
import logging
from urllib.parse import unquote
from .common import detect_region

logger = logging.getLogger(__name__)


def parse_ss(line: str) -> dict:
    """Parse ss:// link"""
    try:
        # ss://base64(method:password)@server:port#name
        match = re.match(r'ss://([^@]+)@([^:]+):(\d+)#(.+)', line)
        if match:
            encoded, server, port, name = match.groups()
            name = unquote(name)
            region = detect_region(server)

            # Decode the base64 part
            try:
                decoded = base64.b64decode(encoded + '==').decode('utf-8')
                method, password = decoded.split(':', 1)
            except Exception:
                method = "aes-256-gcm"
                password = encoded

            return {
                'name': name,
                'type': 'ss',
                'server': server,
                'port': int(port),
                'region': region,
                'method': method,
                'password': password
            }
        else:
            logger.warning(f"ss regex failed for: {line[:50]}")
    except Exception as e:
        logger.warning(f"ss parse error: {e}")
    return None
