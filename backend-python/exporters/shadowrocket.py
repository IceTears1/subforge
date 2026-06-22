import json
import base64
import logging
from typing import List, Dict, Any

logger = logging.getLogger(__name__)


def generate_shadowrocket_config(nodes: List[Dict[str, Any]]) -> str:
    """
    生成 Shadowrocket 配置格式

    Shadowrocket 使用 base64 编码的 URI 列表
    格式: 每行一个 URI (ss://, vmess://, vless://, trojan://)
    """
    lines = []

    for node in nodes:
        node_type = node.get("type", node.get("node_type", "")).lower()
        name = node.get("name", "Unknown")
        server = node.get("server", "")
        port = node.get("port", 0)
        config = node.get("data", node.get("config_json", {}))

        if not server or not port:
            continue

        try:
            uri = _generate_uri(node_type, name, server, port, config)
            if uri:
                lines.append(uri)
        except Exception as e:
            logger.warning(f"Failed to generate Shadowrocket config for {name}: {e}")

    # Shadowrocket 使用 base64 编码
    content = "\n".join(lines)
    return base64.b64encode(content.encode()).decode()


def _generate_uri(node_type: str, name: str, server: str, port: int, config: Dict[str, Any]) -> str:
    """生成单个 URI"""

    if node_type == "ss":
        method = config.get("cipher", config.get("method", "aes-256-gcm"))
        password = config.get("password", "")
        # ss://base64(method:password)@server:port#name
        encoded = base64.b64encode(f"{method}:{password}".encode()).decode()
        return f"ss://{encoded}@{server}:{port}#{_url_encode(name)}"

    elif node_type == "vmess":
        uuid = config.get("id", config.get("uuid", ""))
        alter_id = config.get("aid", 0)
        cipher = config.get("scy", "auto")
        tls = config.get("tls", False)
        transport = config.get("net", "tcp")

        vmess_config = {
            "v": "2",
            "ps": name,
            "add": server,
            "port": str(port),
            "id": uuid,
            "aid": str(alter_id),
            "net": transport,
            "type": config.get("type", "none"),
            "host": config.get("host", ""),
            "path": config.get("path", ""),
            "tls": "tls" if tls else "",
            "sni": config.get("sni", ""),
            "alpn": config.get("alpn", ""),
            "fp": config.get("fp", ""),
        }
        vmess_json = json.dumps(vmess_config, separators=(',', ':'))
        return f"vmess://{base64.b64encode(vmess_json.encode()).decode()}"

    elif node_type == "vless":
        uuid = config.get("uuid", config.get("id", ""))
        tls = config.get("tls", False)
        flow = config.get("flow", "")

        params = []
        if tls:
            params.append("security=tls")
            if config.get("sni"):
                params.append(f"sni={config['sni']}")
        if config.get("net"):
            params.append(f"type={config['net']}")
        if config.get("path"):
            params.append(f"path={config['path']}")
        if config.get("host"):
            params.append(f"host={config['host']}")
        if flow:
            params.append(f"flow={flow}")

        query = "&".join(params)
        return f"vless://{uuid}@{server}:{port}?{query}#{_url_encode(name)}"

    elif node_type == "trojan":
        password = config.get("password", "")
        sni = config.get("sni", "")

        params = []
        if sni:
            params.append(f"sni={sni}")

        query = "&".join(params)
        return f"trojan://{password}@{server}:{port}?{query}#{_url_encode(name)}"

    elif node_type == "hysteria2":
        password = config.get("password", "")
        sni = config.get("sni", "")

        params = []
        if sni:
            params.append(f"sni={sni}")

        query = "&".join(params)
        return f"hysteria2://{password}@{server}:{port}?{query}#{_url_encode(name)}"

    return None


def _url_encode(text: str) -> str:
    """URL 编码"""
    from urllib.parse import quote
    return quote(text, safe='')
