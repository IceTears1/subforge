import pytest
import sys
import os

# 添加项目根目录到路径
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from exporters import (
    generate_clash_yaml,
    generate_singbox_json,
    generate_base64_subscription,
    generate_surge_config,
    generate_loon_config,
    generate_qx_config,
    generate_shadowrocket_config,
)


# 测试数据
TEST_NODES = [
    {
        "name": "HK Node 1",
        "node_type": "vless",
        "server": "hk.example.com",
        "port": 443,
        "region": "HK",
        "config_json": {"uuid": "test-uuid-1", "tls": True, "sni": "hk.example.com"}
    },
    {
        "name": "JP Node 1",
        "node_type": "vmess",
        "server": "jp.example.com",
        "port": 443,
        "region": "JP",
        "config_json": {"id": "test-uuid-2", "aid": 0, "net": "ws", "path": "/ws"}
    },
    {
        "name": "SG Node 1",
        "node_type": "trojan",
        "server": "sg.example.com",
        "port": 443,
        "region": "SG",
        "config_json": {"password": "test-password", "sni": "sg.example.com"}
    },
    {
        "name": "US Node 1",
        "node_type": "ss",
        "server": "us.example.com",
        "port": 8388,
        "region": "US",
        "config_json": {"cipher": "aes-256-gcm", "password": "ss-password"}
    },
]


class TestClashExporter:
    def test_generate_clash_yaml(self):
        result = generate_clash_yaml(TEST_NODES)
        assert isinstance(result, str)
        assert "proxies:" in result
        assert "HK Node 1" in result
        assert "JP Node 1" in result

    def test_empty_nodes(self):
        result = generate_clash_yaml([])
        assert isinstance(result, str)
        assert "proxies:" in result


class TestSingboxExporter:
    def test_generate_singbox_json(self):
        result = generate_singbox_json(TEST_NODES)
        assert isinstance(result, str)
        assert "outbounds" in result
        assert "HK Node 1" in result

    def test_empty_nodes(self):
        result = generate_singbox_json([])
        assert isinstance(result, str)
        assert "outbounds" in result


class TestBase64Exporter:
    def test_generate_base64_subscription(self):
        result = generate_base64_subscription(TEST_NODES)
        assert isinstance(result, str)
        # 应该是有效的 base64
        import base64
        decoded = base64.b64decode(result).decode()
        assert "vless://" in decoded
        assert "vmess://" in decoded

    def test_empty_nodes(self):
        result = generate_base64_subscription([])
        assert isinstance(result, str)


class TestSurgeExporter:
    def test_generate_surge_config(self):
        result = generate_surge_config(TEST_NODES)
        assert isinstance(result, str)
        assert "[Proxy]" in result
        assert "HK Node 1" in result

    def test_empty_nodes(self):
        result = generate_surge_config([])
        assert isinstance(result, str)
        assert "[Proxy]" in result


class TestLoonExporter:
    def test_generate_loon_config(self):
        result = generate_loon_config(TEST_NODES)
        assert isinstance(result, str)
        assert "[Proxy]" in result
        assert "HK Node 1" in result

    def test_empty_nodes(self):
        result = generate_loon_config([])
        assert isinstance(result, str)
        assert "[Proxy]" in result


class TestQxExporter:
    def test_generate_qx_config(self):
        result = generate_qx_config(TEST_NODES)
        assert isinstance(result, str)
        assert "[server_local]" in result
        assert "HK Node 1" in result

    def test_empty_nodes(self):
        result = generate_qx_config([])
        assert isinstance(result, str)
        assert "[server_local]" in result


class TestShadowrocketExporter:
    def test_generate_shadowrocket_config(self):
        result = generate_shadowrocket_config(TEST_NODES)
        assert isinstance(result, str)
        # 应该是有效的 base64
        import base64
        decoded = base64.b64decode(result).decode()
        assert "vless://" in decoded or "vmess://" in decoded

    def test_empty_nodes(self):
        result = generate_shadowrocket_config([])
        assert isinstance(result, str)
