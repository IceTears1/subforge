import re
import logging
from abc import ABC, abstractmethod
from typing import List, Dict, Any

logger = logging.getLogger(__name__)


class BaseFilter(ABC):
    """过滤器基类"""

    @abstractmethod
    def filter(self, nodes: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """过滤节点列表"""
        pass

    def __repr__(self):
        return f"<{self.__class__.__name__}>"


class RegexFilter(BaseFilter):
    """正则过滤器 - 保留匹配的节点"""

    def __init__(self, pattern: str, field: str = "name"):
        self.pattern = re.compile(pattern, re.IGNORECASE)
        self.field = field

    def filter(self, nodes: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        return [n for n in nodes if self.pattern.search(n.get(self.field, ""))]

    def __repr__(self):
        return f"<RegexFilter(pattern={self.pattern.pattern})>"


class DiscardRegexFilter(BaseFilter):
    """丢弃正则过滤器 - 丢弃匹配的节点"""

    def __init__(self, pattern: str, field: str = "name"):
        self.pattern = re.compile(pattern, re.IGNORECASE)
        self.field = field

    def filter(self, nodes: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        return [n for n in nodes if not self.pattern.search(n.get(self.field, ""))]

    def __repr__(self):
        return f"<DiscardRegexFilter(pattern={self.pattern.pattern})>"


class RegionFilter(BaseFilter):
    """区域过滤器 - 按区域筛选节点"""

    def __init__(self, regions: List[str], mode: str = "include"):
        """
        Args:
            regions: 区域列表，如 ["HK", "JP", "SG"]
            mode: "include" 保留指定区域，"exclude" 排除指定区域
        """
        self.regions = [r.upper() for r in regions]
        self.mode = mode

    def filter(self, nodes: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        if self.mode == "include":
            return [n for n in nodes if n.get("region", "OTHER").upper() in self.regions]
        else:
            return [n for n in nodes if n.get("region", "OTHER").upper() not in self.regions]

    def __repr__(self):
        return f"<RegionFilter(regions={self.regions}, mode={self.mode})>"


class TypeFilter(BaseFilter):
    """类型过滤器 - 按协议类型筛选节点"""

    def __init__(self, types: List[str], mode: str = "include"):
        """
        Args:
            types: 协议类型列表，如 ["vless", "vmess", "trojan"]
            mode: "include" 保留指定类型，"exclude" 排除指定类型
        """
        self.types = [t.lower() for t in types]
        self.mode = mode

    def filter(self, nodes: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        if self.mode == "include":
            return [n for n in nodes if n.get("node_type", "").lower() in self.types]
        else:
            return [n for n in nodes if n.get("node_type", "").lower() not in self.types]

    def __repr__(self):
        return f"<TypeFilter(types={self.types}, mode={self.mode})>"


class UselessProxyFilter(BaseFilter):
    """无用代理过滤器 - 过滤掉常见的无用节点"""

    USELESS_PATTERNS = [
        r"过期",
        r"到期",
        r"expire",
        r"disabled",
        r"剩余",
        r"流量",
        r"套餐",
        r"官网",
        r"官网",
        r"频道",
        r"channel",
        r"群组",
        r"group",
    ]

    def __init__(self, extra_patterns: List[str] = None):
        patterns = self.USELESS_PATTERNS + (extra_patterns or [])
        self.patterns = [re.compile(p, re.IGNORECASE) for p in patterns]

    def filter(self, nodes: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        def is_useless(node):
            name = node.get("name", "")
            for pattern in self.patterns:
                if pattern.search(name):
                    return True
            return False

        return [n for n in nodes if not is_useless(n)]

    def __repr__(self):
        return "<UselessProxyFilter>"
