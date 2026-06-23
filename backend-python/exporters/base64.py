import base64
import json
import logging
from typing import List, Dict, Any

logger = logging.getLogger(__name__)


def generate_base64_subscription(nodes: List[Dict[str, Any]]) -> str:
    """Generate base64 encoded subscription for Shadowrocket/V2Ray"""
    lines = []

    for node in nodes:
        config = node.get("config_json", node.get("data", {}))
        if isinstance(config, str):
            try:
                config = json.loads(config)
            except Exception:
                config = {}

        node_type = node.get("node_type", node.get("type", ""))
        name = node.get("name", "Unknown")
        display_name = node.get("display_name", name)
        server = node.get("server", "")
        port = node.get("port", 0)
        raw_uri = node.get("raw_uri", "")

        try:
            if node_type == "vless":
                uuid = config.get("id", config.get("uuid", ""))

                # Check if we have raw params string (from parsed subscription)
                raw_params = config.get("params", "")
                if raw_params:
                    query = raw_params
                else:
                    # Build params from individual fields
                    params = []
                    if config.get("tls") == "tls":
                        params.append("security=tls")
                        if config.get("sni"):
                            params.append(f"sni={config['sni']}")
                    if config.get("net"):
                        params.append(f"type={config['net']}")
                    if config.get("path"):
                        params.append(f"path={config['path']}")
                    if config.get("host"):
                        params.append(f"host={config['host']}")
                    if config.get("fp"):
                        params.append(f"fp={config['fp']}")
                    if config.get("flow"):
                        params.append(f"flow={config['flow']}")
                    query = "&".join(params)

                display = config.get("ps", display_name or name or "Unknown")
                lines.append(f"vless://{uuid}@{server}:{port}?{query}#{display}")

            elif node_type == "vmess":
                vmess_config = {
                    "v": "2",
                    "ps": config.get("ps", display_name or name or "Unknown"),
                    "add": config.get("add", server),
                    "port": str(port),
                    "id": config.get("id", ""),
                    "aid": str(config.get("aid", 0)),
                    "net": config.get("net", "tcp"),
                    "type": config.get("type", "none"),
                    "host": config.get("host", ""),
                    "path": config.get("path", ""),
                    "tls": config.get("tls", ""),
                    "sni": config.get("sni", ""),
                    "alpn": config.get("alpn", ""),
                    "fp": config.get("fp", ""),
                }
                vmess_json = json.dumps(vmess_config, separators=(',', ':'))
                lines.append(f"vmess://{base64.b64encode(vmess_json.encode()).decode()}")

            elif node_type == "trojan":
                password = config.get("password", "")

                raw_params = config.get("params", "")
                if raw_params:
                    query = raw_params
                else:
                    params = []
                    if config.get("sni"):
                        params.append(f"sni={config['sni']}")
                    if config.get("peer"):
                        params.append(f"peer={config['peer']}")
                    query = "&".join(params)

                display = config.get("ps", display_name or name or "Unknown")
                lines.append(f"trojan://{password}@{server}:{port}?{query}#{display}")

            elif node_type == "ss":
                method = config.get("method", config.get("cipher", "aes-256-gcm"))
                password = config.get("password", "")
                display = config.get("ps", display_name or name or "Unknown")
                encoded = base64.b64encode(f"{method}:{password}".encode()).decode()
                lines.append(f"ss://{encoded}@{server}:{port}#{display}")

            elif node_type == "hysteria2":
                password = config.get("password", "")
                params = []
                if config.get("sni"):
                    params.append(f"sni={config['sni']}")
                query = "&".join(params)
                display = config.get("ps", display_name or name or "Unknown")
                lines.append(f"hysteria2://{password}@{server}:{port}?{query}#{display}")

            else:
                # Fallback: use raw_uri if available
                if raw_uri:
                    lines.append(raw_uri)

        except Exception as e:
            logger.warning(f"Failed to generate URI for {name}: {e}")
            continue

    content = "\n".join(lines)
    return base64.b64encode(content.encode()).decode()
