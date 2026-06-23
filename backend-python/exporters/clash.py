import json
import uuid
import logging
from typing import List, Dict, Any

logger = logging.getLogger(__name__)


def generate_clash_yaml(nodes: List[Dict[str, Any]]) -> str:
    """Generate Clash/Mihomo YAML format from node dicts"""
    import yaml

    proxies = []
    proxy_names = []
    name_count = {}

    for node in nodes:
        config_data = node.get("config_json", node.get("data", {}))
        if isinstance(config_data, str):
            try:
                config_data = json.loads(config_data)
            except Exception:
                config_data = {}

        # Handle duplicate names by adding suffix
        name = node.get("name", "Unknown")
        if name in name_count:
            name_count[name] += 1
            name = f"{name}_{name_count[name]}"
        else:
            name_count[name] = 1

        node_type = node.get("node_type", node.get("type", ""))
        server = node.get("server", "")
        port = node.get("port", 0)

        proxy = {
            "name": name,
            "type": node_type,
            "server": server,
            "port": port,
        }

        if node_type == "vless":
            proxy["uuid"] = config_data.get("uuid", config_data.get("id", str(uuid.uuid4())))
            proxy["udp"] = True

            # Parse params string if exists
            params_str = config_data.get("params", "")
            params = {}
            if params_str:
                for param in params_str.split("&"):
                    if "=" in param:
                        key, value = param.split("=", 1)
                        params[key] = value

            # Fix server address - use host or sni if server is placeholder
            if server in ["127.0.0.1", "0.0.0.0", "localhost"]:
                server = params.get("host", params.get("sni", server))
                proxy["server"] = server

            # TLS settings
            proxy["tls"] = config_data.get("tls", False)
            if params.get("security") == "tls" or params.get("security") == "reality":
                proxy["tls"] = True

            if proxy["tls"]:
                servername = config_data.get("servername", "")
                if not servername:
                    servername = params.get("sni", "")
                if not servername:
                    servername = params.get("host", "")
                if not servername:
                    servername = server
                proxy["servername"] = servername

            # Network settings
            network = config_data.get("net", params.get("type", "tcp"))
            if network == "ws":
                proxy["network"] = "ws"
                proxy["ws-opts"] = config_data.get("ws-opts", {"path": params.get("path", "/")})
            elif network == "grpc":
                proxy["network"] = "grpc"
                proxy["grpc-opts"] = config_data.get("grpc-opts", {"grpc-service-name": params.get("serviceName", "")})
            elif network == "h2":
                proxy["network"] = "h2"

            # Reality settings
            if params.get("security") == "reality":
                proxy["flow"] = params.get("flow", "xtls-rprx-vision")
                proxy["client-fingerprint"] = params.get("fp", "chrome")
                proxy["reality-opts"] = {
                    "public-key": params.get("pbk", ""),
                    "short-id": params.get("sid", "")
                }
                if params.get("insecure") == "0":
                    proxy["skip-cert-verify"] = False
                else:
                    proxy["skip-cert-verify"] = True
            else:
                flow = config_data.get("flow", params.get("flow", ""))
                if flow:
                    proxy["flow"] = flow

            # Client fingerprint
            fp = config_data.get("fp", params.get("fp", ""))
            if fp:
                proxy["client-fingerprint"] = fp

        elif node_type == "vmess":
            proxy["uuid"] = config_data.get("id", str(uuid.uuid4()))
            proxy["alterId"] = config_data.get("aid", 0)
            proxy["cipher"] = config_data.get("scy", "auto")
            proxy["udp"] = True
            net = config_data.get("net", "tcp")
            if net == "ws":
                proxy["network"] = "ws"
                proxy["ws-opts"] = config_data.get("ws-opts", {"path": "/"})
            elif net == "grpc":
                proxy["network"] = "grpc"
                proxy["grpc-opts"] = config_data.get("grpc-opts", {"grpc-service-name": ""})
            elif net == "h2":
                proxy["network"] = "h2"
                proxy["h2-opts"] = config_data.get("h2-opts", {})
            if config_data.get("tls"):
                proxy["tls"] = True
                proxy["servername"] = config_data.get("host", server)

        elif node_type == "trojan":
            password = config_data.get("password", "")
            if not password and "data" in config_data:
                password = config_data["data"].get("password", "")
            proxy["password"] = password
            proxy["udp"] = True
            proxy["sni"] = config_data.get("sni", config_data.get("data", {}).get("sni", server))
            if config_data.get("skip-cert-verify") or config_data.get("data", {}).get("skip-cert-verify"):
                proxy["skip-cert-verify"] = True

        elif node_type == "ss":
            password = config_data.get("password", "")
            if not password and "data" in config_data:
                password = config_data["data"].get("password", "")
            proxy["password"] = password or "password"
            proxy["cipher"] = config_data.get("cipher", config_data.get("data", {}).get("cipher", "aes-256-gcm"))
            if config_data.get("udp") or config_data.get("data", {}).get("udp"):
                proxy["udp"] = True

        elif node_type == "hysteria2":
            password = config_data.get("password", "")
            if not password and "data" in config_data:
                password = config_data["data"].get("password", "")
            proxy["password"] = password
            proxy["ports"] = config_data.get("ports", config_data.get("data", {}).get("ports", ""))
            if config_data.get("obfs") or config_data.get("data", {}).get("obfs"):
                proxy["obfs"] = config_data.get("obfs", config_data.get("data", {}).get("obfs", {}))
                proxy["obfs-password"] = config_data.get("obfs-password", config_data.get("data", {}).get("obfs-password", ""))

        elif node_type == "tuic":
            password = config_data.get("password", "")
            if not password and "data" in config_data:
                password = config_data["data"].get("password", "")
            proxy["password"] = password
            proxy["udp-relay"] = True
            if config_data.get("uuid"):
                proxy["uuid"] = config_data["uuid"]
            elif config_data.get("data", {}).get("uuid"):
                proxy["uuid"] = config_data["data"]["uuid"]

        elif node_type == "anytls":
            password = config_data.get("password", "")
            if not password and "data" in config_data:
                password = config_data["data"].get("password", "")
            proxy["password"] = password
            proxy["udp"] = True
            if config_data.get("sni"):
                proxy["sni"] = config_data["sni"]
            elif config_data.get("data", {}).get("sni"):
                proxy["sni"] = config_data["data"]["sni"]

        proxies.append(proxy)
        proxy_names.append(name)

    config = {
        "proxies": proxies,
        "proxy-groups": [
            {
                "name": "节点选择",
                "type": "select",
                "proxies": ["自动选择", "负载均衡", "DIRECT"] + proxy_names
            },
            {
                "name": "自动选择",
                "type": "url-test",
                "proxies": proxy_names,
                "url": "http://www.gstatic.com/generate_204",
                "interval": 300,
                "tolerance": 50
            },
            {
                "name": "负载均衡",
                "type": "load-balance",
                "proxies": proxy_names,
                "url": "http://www.gstatic.com/generate_204",
                "interval": 300
            }
        ],
        "rules": [
            "GEOIP,CN,DIRECT",
            "MATCH,节点选择"
        ]
    }

    return yaml.dump(config, allow_unicode=True, default_flow_style=False)
