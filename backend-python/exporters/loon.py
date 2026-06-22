import json
import logging
from typing import List, Dict, Any

logger = logging.getLogger(__name__)


def generate_loon_config(nodes: List[Dict[str, Any]]) -> str:
    """
    生成 Loon 配置格式

    格式: [Proxy]
    NodeName = protocol, server, port, password, opt1, opt2, ...
    """
    lines = ["[Proxy]"]

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
            logger.warning(f"Failed to generate Loon config for {name}: {e}")

    return "\n".join(lines)


def _generate_proxy_line(node_type: str, name: str, server: str, port: int, config: Dict[str, Any]) -> str:
    """生成单个代理配置行"""

    if node_type == "ss":
        method = config.get("cipher", config.get("method", "aes-256-gcm"))
        password = config.get("password", "")
        return f"{name} = Shadowsocks, {server}, {port}, {method}, {password}"

    elif node_type == "vmess":
        uuid = config.get("id", config.get("uuid", ""))
        alter_id = config.get("aid", 0)
        cipher = config.get("scy", "auto")
        tls = config.get("tls", False)
        transport = config.get("net", "tcp")
        line = f"{name} = VMess, {server}, {port}, {uuid}, alterId={alterId}, cipher={cipher}"
        if tls:
            line += ", tls=true"
            if config.get("sni"):
                line += f", sni={config['sni']}"
        if transport == "ws":
            line += ", transport=ws"
            if config.get("path"):
                line += f", ws-path={config['path']}"
        elif transport == "grpc":
            line += ", transport=grpc"
        return line

    elif node_type == "vless":
        uuid = config.get("uuid", config.get("id", ""))
        tls = config.get("tls", False)
        flow = config.get("flow", "")
        line = f"{name} = VLESS, {server}, {port}, {uuid}"
        if tls:
            line += ", tls=true"
            if config.get("sni"):
                line += f", sni={config['sni']}"
        if flow:
            line += f", flow={flow}"
        return line

    elif node_type == "trojan":
        password = config.get("password", "")
        sni = config.get("sni", "")
        line = f"{name} = Trojan, {server}, {port}, {password}"
        if sni:
            line += f", sni={sni}"
        return line

    elif node_type == "hysteria2":
        password = config.get("password", "")
        line = f"{name} = Hysteria2, {server}, {port}, {password}"
        if config.get("sni"):
            line += f", sni={config['sni']}"
        return line

    return None
