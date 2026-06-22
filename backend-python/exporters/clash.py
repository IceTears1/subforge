import json
import uuid
import logging
from typing import List, Dict, Any

logger = logging.getLogger(__name__)


def generate_clash_yaml(nodes: List[Dict[str, Any]]) -> str:
    """Generate Clash/Mihomo YAML format"""
    import yaml

    proxies = []
    name_count = {}

    for node in nodes:
        config = node.get("config_json", node.get("data", {}))
        if isinstance(config, str):
            try:
                config = json.loads(config)
            except Exception:
                config = {}

        # Handle duplicate names
        name = node.get("name", "Unknown")
        if name in name_count:
            name_count[name] += 1
            name = f"{name}_{name_count[name]}"
        else:
            name_count[name] = 1

        proxy = {
            "name": name,
            "type": node.get("node_type", node.get("type", "")),
            "server": node.get("server", ""),
            "port": node.get("port", 0),
        }

        node_type = proxy["type"]

        if node_type == "vless":
            proxy["uuid"] = config.get("uuid", config.get("id", str(uuid.uuid4())))
            proxy["udp"] = True

            # Parse params
            params_str = config.get("params", "")
            params = {}
            if params_str:
                for param in params_str.split("&"):
                    if "=" in param:
                        key, value = param.split("=", 1)
                        params[key] = value

            # TLS settings
            proxy["tls"] = config.get("tls", False)
            if params.get("security") == "tls" or params.get("security") == "reality":
                proxy["tls"] = True

            if proxy["tls"]:
                proxy["servername"] = params.get("sni", params.get("host", proxy["server"]))

            # Network settings
            network = config.get("net", params.get("type", "tcp"))
            if network == "ws":
                proxy["network"] = "ws"
                proxy["ws-opts"] = {"path": params.get("path", "/")}
            elif network == "grpc":
                proxy["network"] = "grpc"
                proxy["grpc-opts"] = {"grpc-service-name": params.get("serviceName", "")}

            # Reality settings
            if params.get("security") == "reality":
                proxy["flow"] = params.get("flow", "xtls-rprx-vision")
                proxy["client-fingerprint"] = params.get("fp", "chrome")
                proxy["reality-opts"] = {
                    "public-key": params.get("pbk", ""),
                    "short-id": params.get("sid", "")
                }

            # Client fingerprint
            fp = config.get("fp", params.get("fp", ""))
            if fp:
                proxy["client-fingerprint"] = fp

        elif node_type == "vmess":
            proxy["uuid"] = config.get("id", str(uuid.uuid4()))
            proxy["alterId"] = config.get("aid", 0)
            proxy["cipher"] = config.get("scy", "auto")
            proxy["udp"] = True

            net = config.get("net", "tcp")
            if net == "ws":
                proxy["network"] = "ws"
                proxy["ws-opts"] = {"path": config.get("path", "/")}
            elif net == "grpc":
                proxy["network"] = "grpc"
                proxy["grpc-opts"] = {"grpc-service-name": config.get("serviceName", "")}

            if config.get("tls") == "tls":
                proxy["tls"] = True
                proxy["servername"] = config.get("sni", proxy["server"])

        elif node_type == "trojan":
            proxy["password"] = config.get("password", "")
            if config.get("sni"):
                proxy["sni"] = config["sni"]

        elif node_type == "ss":
            proxy["cipher"] = config.get("cipher", config.get("method", "aes-256-gcm"))
            proxy["password"] = config.get("password", "")

        elif node_type == "hysteria2":
            proxy["password"] = config.get("password", "")
            if config.get("sni"):
                proxy["sni"] = config["sni"]

        proxies.append(proxy)

    config = {
        "proxies": proxies,
        "proxy-groups": [
            {"name": "PROXY", "type": "select", "proxies": [p["name"] for p in proxies]}
        ],
        "rules": ["MATCH,PROXY"]
    }

    return yaml.dump(config, allow_unicode=True, default_flow_style=False)
