import json
import logging
from typing import List, Dict, Any

logger = logging.getLogger(__name__)


def generate_singbox_json(nodes: List[Dict[str, Any]]) -> str:
    """Generate sing-box JSON format"""
    outbounds = []

    for node in nodes:
        config = node.get("config_json", node.get("data", {}))
        if isinstance(config, str):
            try:
                config = json.loads(config)
            except Exception:
                config = {}

        outbound = {
            "type": node.get("node_type", node.get("type", "")),
            "tag": node.get("name", "Unknown"),
            "server": node.get("server", ""),
            "server_port": node.get("port", 0),
        }

        node_type = outbound["type"]

        if node_type == "vless":
            outbound["uuid"] = config.get("uuid", config.get("id", ""))
            outbound["flow"] = config.get("flow", "")

            # TLS settings
            if config.get("tls"):
                outbound["tls"] = {
                    "enabled": True,
                    "server_name": config.get("sni", config.get("server", ""))
                }

            # Network settings
            network = config.get("net", "tcp")
            if network == "ws":
                outbound["transport"] = {
                    "type": "ws",
                    "path": config.get("path", "/")
                }
            elif network == "grpc":
                outbound["transport"] = {
                    "type": "grpc",
                    "service_name": config.get("serviceName", "")
                }

        elif node_type == "vmess":
            outbound["uuid"] = config.get("id", "")
            outbound["alter_id"] = config.get("aid", 0)
            outbound["security"] = config.get("scy", "auto")

            # TLS settings
            if config.get("tls") == "tls":
                outbound["tls"] = {
                    "enabled": True,
                    "server_name": config.get("sni", config.get("server", ""))
                }

            # Network settings
            net = config.get("net", "tcp")
            if net == "ws":
                outbound["transport"] = {
                    "type": "ws",
                    "path": config.get("path", "/")
                }
            elif net == "grpc":
                outbound["transport"] = {
                    "type": "grpc",
                    "service_name": config.get("serviceName", "")
                }

        elif node_type == "trojan":
            outbound["password"] = config.get("password", "")
            if config.get("sni"):
                outbound["tls"] = {
                    "enabled": True,
                    "server_name": config["sni"]
                }

        elif node_type == "ss":
            outbound["method"] = config.get("cipher", config.get("method", "aes-256-gcm"))
            outbound["password"] = config.get("password", "")

        elif node_type == "hysteria2":
            outbound["password"] = config.get("password", "")
            if config.get("sni"):
                outbound["tls"] = {
                    "enabled": True,
                    "server_name": config["sni"]
                }

        outbounds.append(outbound)

    config = {
        "outbounds": [
            {"type": "selector", "tag": "proxy", "outbounds": [n.get("name", "Unknown") for n in nodes]},
            {"type": "urltest", "tag": "auto", "outbounds": [n.get("name", "Unknown") for n in nodes], "url": "http://www.gstatic.com/generate_204", "interval": "5m"}
        ] + outbounds
    }

    return json.dumps(config, ensure_ascii=False, indent=2)
