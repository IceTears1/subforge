import re
import socket
import logging
from abc import ABC, abstractmethod
from typing import List, Dict, Any, Callable

logger = logging.getLogger(__name__)


class BaseOperator(ABC):
    """操作符基类"""

    @abstractmethod
    def operate(self, nodes: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """操作节点列表"""
        pass

    def __repr__(self):
        return f"<{self.__class__.__name__}>"


class SetPropertyOperator(BaseOperator):
    """设置属性操作符 - 设置节点的某个属性"""

    def __init__(self, property_name: str, value: Any):
        self.property_name = property_name
        self.value = value

    def operate(self, nodes: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        for node in nodes:
            node[self.property_name] = self.value
        return nodes

    def __repr__(self):
        return f"<SetPropertyOperator({self.property_name}={self.value})>"


class FlagOperator(BaseOperator):
    """标志操作符 - 添加或移除节点标志"""

    def __init__(self, flags: List[str], mode: str = "add"):
        """
        Args:
            flags: 标志列表
            mode: "add" 添加标志，"remove" 移除标志
        """
        self.flags = flags
        self.mode = mode

    def operate(self, nodes: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        for node in nodes:
            if "tags" not in node:
                node["tags"] = []
            if self.mode == "add":
                for flag in self.flags:
                    if flag not in node["tags"]:
                        node["tags"].append(flag)
            else:
                node["tags"] = [t for t in node["tags"] if t not in self.flags]
        return nodes

    def __repr__(self):
        return f"<FlagOperator(flags={self.flags}, mode={self.mode})>"


class SortOperator(BaseOperator):
    """排序操作符 - 按名称排序节点"""

    def __init__(self, descending: bool = False):
        self.descending = descending

    def operate(self, nodes: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        return sorted(nodes, key=lambda n: n.get("name", ""), reverse=self.descending)

    def __repr__(self):
        return f"<SortOperator(descending={self.descending})>"


class RegexSortOperator(BaseOperator):
    """正则排序操作符 - 按关键词排序节点"""

    def __init__(self, keywords: List[str]):
        self.keywords = keywords

    def operate(self, nodes: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        def sort_key(node):
            name = node.get("name", "")
            for i, keyword in enumerate(self.keywords):
                if keyword.lower() in name.lower():
                    return i
            return len(self.keywords)

        return sorted(nodes, key=sort_key)

    def __repr__(self):
        return f"<RegexSortOperator(keywords={self.keywords})>"


class RegexRenameOperator(BaseOperator):
    """正则重命名操作符 - 用正则替换节点名称"""

    def __init__(self, pattern: str, replacement: str):
        self.pattern = re.compile(pattern)
        self.replacement = replacement

    def operate(self, nodes: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        for node in nodes:
            node["name"] = self.pattern.sub(self.replacement, node.get("name", ""))
        return nodes

    def __repr__(self):
        return f"<RegexRenameOperator(pattern={self.pattern.pattern})>"


class RegexDeleteOperator(BaseOperator):
    """正则删除操作符 - 删除名称匹配的节点"""

    def __init__(self, pattern: str):
        self.pattern = re.compile(pattern, re.IGNORECASE)

    def operate(self, nodes: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        return [n for n in nodes if not self.pattern.search(n.get("name", ""))]

    def __repr__(self):
        return f"<RegexDeleteOperator(pattern={self.pattern.pattern})>"


class ScriptOperator(BaseOperator):
    """脚本操作符 - 已禁用 (存在安全风险)"""

    def __init__(self, script: str):
        logger.warning("ScriptOperator is disabled for security reasons - ignoring script")
        self.script = script

    def operate(self, nodes: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        # exec() removed due to RCE vulnerability - sandbox is trivially bypassable
        logger.warning("ScriptOperator.operate() called but disabled - returning nodes unchanged")
        return nodes

    def __repr__(self):
        return "<ScriptOperator(disabled)>"


class DomainResolveOperator(BaseOperator):
    """域名解析操作符 - 将节点域名解析为 IP"""

    def __init__(self, prefer_ipv6: bool = False):
        self.prefer_ipv6 = prefer_ipv6

    def _resolve_domain(self, domain: str) -> str:
        """解析域名"""
        try:
            if self.prefer_ipv6:
                # 优先 IPv6
                results = socket.getaddrinfo(domain, None, socket.AF_INET6)
                if results:
                    return results[0][4][0]
            # IPv4
            results = socket.getaddrinfo(domain, None, socket.AF_INET)
            if results:
                return results[0][4][0]
            # 回退到任何
            results = socket.getaddrinfo(domain, None)
            if results:
                return results[0][4][0]
        except Exception as e:
            logger.warning(f"Failed to resolve {domain}: {e}")
        return domain

    def operate(self, nodes: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        for node in nodes:
            server = node.get("server", "")
            if server and not self._is_ip(server):
                node["server"] = self._resolve_domain(server)
        return nodes

    def _is_ip(self, address: str) -> bool:
        """检查是否为 IP 地址"""
        try:
            socket.inet_pton(socket.AF_INET, address)
            return True
        except socket.error:
            pass
        try:
            socket.inet_pton(socket.AF_INET6, address)
            return True
        except socket.error:
            return False

    def __repr__(self):
        return f"<DomainResolveOperator(prefer_ipv6={self.prefer_ipv6})>"
