import logging
from typing import List, Dict, Any, Optional
from .filters import BaseFilter
from .operators import BaseOperator

logger = logging.getLogger(__name__)


class SubscriptionPipeline:
    """订阅处理管道 - 组合过滤器和操作符"""

    def __init__(self):
        self.filters: List[BaseFilter] = []
        self.operators: List[BaseOperator] = []

    def add_filter(self, filter_obj: BaseFilter) -> "SubscriptionPipeline":
        """添加过滤器"""
        self.filters.append(filter_obj)
        return self

    def add_operator(self, operator: BaseOperator) -> "SubscriptionPipeline":
        """添加操作符"""
        self.operators.append(operator)
        return self

    def process(self, nodes: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """处理节点列表"""
        result = list(nodes)

        # 应用过滤器
        for filter_obj in self.filters:
            before_count = len(result)
            result = filter_obj.filter(result)
            after_count = len(result)
            logger.debug(f"{filter_obj}: {before_count} -> {after_count} nodes")

        # 应用操作符
        for operator in self.operators:
            before_count = len(result)
            result = operator.operate(result)
            after_count = len(result)
            logger.debug(f"{operator}: {before_count} -> {after_count} nodes")

        return result

    def clear(self):
        """清空管道"""
        self.filters.clear()
        self.operators.clear()

    def __repr__(self):
        return f"<SubscriptionPipeline(filters={len(self.filters)}, operators={len(self.operators)})>"

    @classmethod
    def from_config(cls, config: Dict[str, Any]) -> "SubscriptionPipeline":
        """从配置创建管道"""
        from .filters import (
            RegexFilter,
            DiscardRegexFilter,
            RegionFilter,
            TypeFilter,
            UselessProxyFilter,
        )
        from .operators import (
            SetPropertyOperator,
            FlagOperator,
            SortOperator,
            RegexSortOperator,
            RegexRenameOperator,
            RegexDeleteOperator,
            ScriptOperator,
            DomainResolveOperator,
        )

        pipeline = cls()

        # 解析过滤器
        for filter_config in config.get("filters", []):
            filter_type = filter_config.get("type")
            if filter_type == "regex":
                pipeline.add_filter(RegexFilter(
                    pattern=filter_config["pattern"],
                    field=filter_config.get("field", "name"),
                ))
            elif filter_type == "discard_regex":
                pipeline.add_filter(DiscardRegexFilter(
                    pattern=filter_config["pattern"],
                    field=filter_config.get("field", "name"),
                ))
            elif filter_type == "region":
                pipeline.add_filter(RegionFilter(
                    regions=filter_config["regions"],
                    mode=filter_config.get("mode", "include"),
                ))
            elif filter_type == "type":
                pipeline.add_filter(TypeFilter(
                    types=filter_config["types"],
                    mode=filter_config.get("mode", "include"),
                ))
            elif filter_type == "useless_proxy":
                pipeline.add_filter(UselessProxyFilter(
                    extra_patterns=filter_config.get("patterns", []),
                ))

        # 解析操作符
        for op_config in config.get("operators", []):
            op_type = op_config.get("type")
            if op_type == "set_property":
                pipeline.add_operator(SetPropertyOperator(
                    property_name=op_config["property"],
                    value=op_config["value"],
                ))
            elif op_type == "flag":
                pipeline.add_operator(FlagOperator(
                    flags=op_config["flags"],
                    mode=op_config.get("mode", "add"),
                ))
            elif op_type == "sort":
                pipeline.add_operator(SortOperator(
                    descending=op_config.get("descending", False),
                ))
            elif op_type == "regex_sort":
                pipeline.add_operator(RegexSortOperator(
                    keywords=op_config["keywords"],
                ))
            elif op_type == "regex_rename":
                pipeline.add_operator(RegexRenameOperator(
                    pattern=op_config["pattern"],
                    replacement=op_config["replacement"],
                ))
            elif op_type == "regex_delete":
                pipeline.add_operator(RegexDeleteOperator(
                    pattern=op_config["pattern"],
                ))
            elif op_type == "script":
                pipeline.add_operator(ScriptOperator(
                    script=op_config["script"],
                ))
            elif op_type == "domain_resolve":
                pipeline.add_operator(DomainResolveOperator(
                    prefer_ipv6=op_config.get("prefer_ipv6", False),
                ))

        return pipeline
