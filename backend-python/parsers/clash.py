import yaml
import logging
from urllib.parse import unquote
import httpx
from .common import detect_region

logger = logging.getLogger(__name__)


def parse_clash_yaml(content: str) -> list:
    """Parse Clash/Mihomo YAML subscription format"""
    nodes = []
    try:
        data = yaml.safe_load(content)
        if not data:
            return nodes

        # Parse proxies directly
        if 'proxies' in data:
            for proxy in data['proxies']:
                proxy_type = proxy.get('type', '').lower()
                name = unquote(proxy.get('name', 'Unknown'))
                server = proxy.get('server', '')
                port = proxy.get('port', 0)

                if not server or not port:
                    continue

                region = detect_region(server)
                node = {
                    'name': name,
                    'type': proxy_type,
                    'server': server,
                    'port': int(port),
                    'region': region,
                    'data': proxy
                }
                nodes.append(node)

        # Parse proxy-providers (fetch from URL)
        if 'proxy-providers' in data:
            for provider_name, provider in data['proxy-providers'].items():
                provider_url = provider.get('url', '')
                if provider_url:
                    logger.info(f"Fetching proxy-provider: {provider_name} from {provider_url}")
                    try:
                        provider_response = httpx.get(provider_url, timeout=30, follow_redirects=True)
                        if provider_response.status_code == 200:
                            provider_data = yaml.safe_load(provider_response.text)
                            if provider_data and 'proxies' in provider_data:
                                for proxy in provider_data['proxies']:
                                    proxy_type = proxy.get('type', '').lower()
                                    name = unquote(proxy.get('name', 'Unknown'))
                                    server = proxy.get('server', '')
                                    port = proxy.get('port', 0)

                                    if not server or not port:
                                        continue

                                    region = detect_region(server)
                                    node = {
                                        'name': name,
                                        'type': proxy_type,
                                        'server': server,
                                        'port': int(port),
                                        'region': region,
                                        'data': proxy
                                    }
                                    nodes.append(node)
                    except Exception as e:
                        logger.warning(f"Failed to fetch provider {provider_name}: {e}")

    except Exception as e:
        logger.error(f"Clash YAML parse error: {e}")

    return nodes
