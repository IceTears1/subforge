import json
import base64
import logging
from typing import List, Dict, Any

logger = logging.getLogger(__name__)


def generate_qx_config(nodes: List[Dict[str, Any]]) -> str:
    """
    生成 Quantumult X 配置格式

    格式: [server_local]
    type, server, port, username, password, tls=1, tls-verification=1, over-tls=true, ...
    """
    lines = ["[server_local]"]

    for node in nodes:
        node_type = node.get("type", node.get("node_type", "")).lower()
        name = node.get("name", "Unknown")
        server = node.get("server", "")
        port = node.get("port", 0)
        config = node.get("data", node.get("config_json", {}))

        if not server or not port:
            continue

        try:
            line = _generate_proxy_line(node_type, name, server, port, config)
            if line:
                lines.append(line)
        except Exception as e:
            logger.warning(f"Failed to generate QX config for {name}: {e}")

    return "\n".join(lines)


def _generate_proxy_line(node_type: str, name: str, server: str, port: int, config: Dict[str, Any]) -> str:
    """生成单个代理配置行"""

    if node_type == "ss":
        method = config.get("cipher", config.get("method", "aes-256-gcm"))
        password = config.get("password", "")
        return f"shadowsocks, {server}, {port}, {method}, {password}, rekey-interval=300, fast-open=false, udp-relay=false, tag={name}"

    elif node_type == "vmess":
        uuid = config.get("id", config.get("uuid", ""))
        alter_id = config.get("aid", 0)
        cipher = config.get("scy", "auto")
        tls = config.get("tls", False)
        transport = config.get("net", "tcp")
        line = f"vmess, {server}, {port}, username={uuid}, alterId={alterId}, tls={1 if tls else 0}"
        if tls:
            if config.get("sni"):
                line += f", sni={config['sni']}"
        if transport == "ws":
            line += ", tls-verification=false, over-tls=true, ws=true"
            if config.get("path"):
                line += f", ws-path={config['path']}"
        line += f", tag={name}"
        return line

    elif node_type == "vless":
        uuid = config.get("uuid", config.get("id", ""))
        tls = config.get("tls", False)
        flow = config.get("flow", "")
        line = f"vless, {server}, {port}, username={uuid}, tls={1 if tls else 0}"
        if tls:
            if config.get("sni"):
                line += f", sni={config['sni']}"
        if flow:
            line += f", vless-opts={flow}"
        line += f", tag={name}"
        return line

    elif node_type == "trojan":
        password = config.get("password", "")
        sni = config.get("sni", "")
        line = f"trojan, {server}, {port}, password={password}, tls=1"
        if sni:
            line += f", sni={sni}"
        line += f", tag={name}"
        return line

    elif node_type == "hysteria2":
        password = config.get("password", "")
        line = f"hysteria2, {server}, {port}, password={password}"
        if config.get("sni"):
            line += f", sni={config['sni']}"
        line += f", tag={name}"
        return line

    return None
