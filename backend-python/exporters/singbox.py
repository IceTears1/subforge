import json
import logging
from typing import List, Dict, Any

logger = logging.getLogger(__name__)


def generate_singbox_json(nodes: List[Dict[str, Any]]) -> str:
    """Generate sing-box JSON format from node dicts"""
    outbounds = []

    for node in nodes:
        config_data = node.get("config_json", node.get("data", {}))
        if isinstance(config_data, str):
            try:
                config_data = json.loads(config_data)
            except Exception:
                config_data = {}

        node_type = node.get("node_type", node.get("type", ""))
        server = node.get("server", "")
        port = node.get("port", 0)

        outbound = {
            "type": node_type,
            "tag": node.get("name", "Unknown"),
            "server": server,
            "server_port": port,
        }

        if node_type == "vless":
            outbound["uuid"] = config_data.get("uuid", config_data.get("id", ""))
            outbound["flow"] = config_data.get("flow", "")

            # TLS settings
            tls_enabled = config_data.get("tls", False)
            params_str = config_data.get("params", "")
            params = {}
            if params_str:
                for param in params_str.split("&"):
                    if "=" in param:
                        key, value = param.split("=", 1)
                        params[key] = value
            if params.get("security") in ("tls", "reality"):
                tls_enabled = True

            if tls_enabled:
                servername = config_data.get("servername", params.get("sni", params.get("host", server)))
                outbound["tls"] = {"enabled": True, "server_name": servername}

            # Network settings
            network = config_data.get("net", params.get("type", "tcp"))
            if network == "ws":
                outbound["transport"] = {"type": "ws", "path": params.get("path", "/")}
            elif network == "grpc":
                outbound["transport"] = {"type": "grpc", "service_name": params.get("serviceName", "")}
            elif network == "h2":
                outbound["transport"] = {"type": "http", "host": [params.get("host", server)], "path": params.get("path", "/")}

            # Reality
            if params.get("security") == "reality":
                outbound["flow"] = params.get("flow", "xtls-rprx-vision")
                outbound["tls"]["reality"] = {
                    "enabled": True,
                    "public_key": params.get("pbk", ""),
                    "short_id": params.get("sid", "")
                }
                if params.get("fp"):
                    outbound["tls"]["utls"] = {"enabled": True, "fingerprint": params.get("fp", "chrome")}

        elif node_type == "vmess":
            outbound["uuid"] = config_data.get("id", "")
            outbound["alter_id"] = config_data.get("aid", 0)
            outbound["security"] = config_data.get("scy", "auto")

            if config_data.get("tls") == "tls":
                outbound["tls"] = {"enabled": True, "server_name": config_data.get("sni", server)}

            net = config_data.get("net", "tcp")
            if net == "ws":
                outbound["transport"] = {"type": "ws", "path": config_data.get("path", "/")}
            elif net == "grpc":
                outbound["transport"] = {"type": "grpc", "service_name": config_data.get("serviceName", "")}

        elif node_type == "trojan":
            outbound["password"] = config_data.get("password", "")
            if config_data.get("sni"):
                outbound["tls"] = {"enabled": True, "server_name": config_data["sni"]}

        elif node_type == "ss":
            outbound["method"] = config_data.get("cipher", config_data.get("method", "aes-256-gcm"))
            outbound["password"] = config_data.get("password", "")

        elif node_type == "hysteria2":
            outbound["password"] = config_data.get("password", "")
            if config_data.get("sni"):
                outbound["tls"] = {"enabled": True, "server_name": config_data["sni"]}

        outbounds.append(outbound)

    config = {
        "outbounds": [
            {"type": "selector", "tag": "节点选择", "outbounds": ["自动选择"] + [n.get("name", "Unknown") for n in nodes]},
            {"type": "urltest", "tag": "自动选择", "outbounds": [n.get("name", "Unknown") for n in nodes], "url": "http://www.gstatic.com/generate_204", "interval": "5m"}
        ] + outbounds
    }

    return json.dumps(config, ensure_ascii=False, indent=2)
