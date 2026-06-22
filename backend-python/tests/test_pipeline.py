import pytest
import sys
import os

# 添加项目根目录到路径
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from pipeline import (
    SubscriptionPipeline,
    RegexFilter,
    DiscardRegexFilter,
    RegionFilter,
    TypeFilter,
    UselessProxyFilter,
    SetPropertyOperator,
    FlagOperator,
    SortOperator,
    RegexSortOperator,
    RegexRenameOperator,
    RegexDeleteOperator,
    DomainResolveOperator,
)


# 测试数据工厂函数
def create_test_nodes():
    return [
        {"name": "HK Node 1", "node_type": "vless", "server": "hk.example.com", "port": 443, "region": "HK"},
        {"name": "HK Node 2", "node_type": "vmess", "server": "hk2.example.com", "port": 443, "region": "HK"},
        {"name": "JP Node 1", "node_type": "trojan", "server": "jp.example.com", "port": 443, "region": "JP"},
        {"name": "SG Node 1", "node_type": "ss", "server": "sg.example.com", "port": 8388, "region": "SG"},
        {"name": "过期节点", "node_type": "vless", "server": "expired.example.com", "port": 443, "region": "OTHER"},
    ]


class TestFilters:
    def test_regex_filter(self):
        f = RegexFilter("HK")
        result = f.filter(create_test_nodes())
        assert len(result) == 2
        assert all("HK" in n["name"] for n in result)

    def test_discard_regex_filter(self):
        f = DiscardRegexFilter("HK")
        result = f.filter(create_test_nodes())
        assert len(result) == 3
        assert all("HK" not in n["name"] for n in result)

    def test_region_filter_include(self):
        f = RegionFilter(["HK", "JP"], mode="include")
        result = f.filter(create_test_nodes())
        assert len(result) == 3

    def test_region_filter_exclude(self):
        f = RegionFilter(["HK"], mode="exclude")
        result = f.filter(create_test_nodes())
        assert len(result) == 3
        assert all(n["region"] != "HK" for n in result)

    def test_type_filter(self):
        f = TypeFilter(["vless", "vmess"])
        result = f.filter(create_test_nodes())
        assert len(result) == 3

    def test_useless_proxy_filter(self):
        f = UselessProxyFilter()
        result = f.filter(create_test_nodes())
        assert len(result) == 4
        assert not any("过期" in n["name"] for n in result)


class TestOperators:
    def test_set_property_operator(self):
        op = SetPropertyOperator("tags", ["test"])
        nodes = create_test_nodes()[:2]
        result = op.operate(nodes)
        assert all("tags" in n for n in result)
        assert all(n["tags"] == ["test"] for n in result)

    def test_flag_operator_add(self):
        op = FlagOperator(["flag1", "flag2"], mode="add")
        nodes = [{"name": "test", "tags": ["existing"]}]
        result = op.operate(nodes)
        assert "flag1" in result[0]["tags"]
        assert "flag2" in result[0]["tags"]
        assert "existing" in result[0]["tags"]

    def test_flag_operator_remove(self):
        op = FlagOperator(["existing"], mode="remove")
        nodes = [{"name": "test", "tags": ["existing", "other"]}]
        result = op.operate(nodes)
        assert "existing" not in result[0]["tags"]
        assert "other" in result[0]["tags"]

    def test_sort_operator(self):
        op = SortOperator()
        nodes = create_test_nodes()
        result = op.operate(nodes)
        assert result[0]["name"] == "HK Node 1"
        assert result[-1]["name"] == "过期节点"

    def test_sort_operator_descending(self):
        op = SortOperator(descending=True)
        nodes = create_test_nodes()
        result = op.operate(nodes)
        assert result[0]["name"] == "过期节点"

    def test_regex_rename_operator(self):
        op = RegexRenameOperator("Node", "Proxy")
        nodes = create_test_nodes()[:2]
        result = op.operate(nodes)
        assert "Proxy" in result[0]["name"]
        assert "Proxy" in result[1]["name"]

    def test_regex_delete_operator(self):
        op = RegexDeleteOperator("HK")
        nodes = create_test_nodes()
        result = op.operate(nodes)
        assert len(result) == 3
        assert not any("HK" in n["name"] for n in result)


class TestPipeline:
    def test_pipeline_with_filter(self):
        pipeline = SubscriptionPipeline()
        pipeline.add_filter(RegionFilter(["HK"]))
        result = pipeline.process(create_test_nodes())
        assert len(result) == 2

    def test_pipeline_with_operator(self):
        pipeline = SubscriptionPipeline()
        pipeline.add_operator(SortOperator())
        nodes = create_test_nodes()
        result = pipeline.process(nodes)
        assert result[0]["name"] == "HK Node 1"

    def test_pipeline_combined(self):
        pipeline = SubscriptionPipeline()
        pipeline.add_filter(RegionFilter(["HK", "JP"]))
        pipeline.add_operator(SortOperator())
        nodes = create_test_nodes()
        result = pipeline.process(nodes)
        assert len(result) == 3
        assert result[0]["name"] == "HK Node 1"

    def test_pipeline_clear(self):
        pipeline = SubscriptionPipeline()
        pipeline.add_filter(RegionFilter(["HK"]))
        pipeline.add_operator(SortOperator())
        pipeline.clear()
        result = pipeline.process(create_test_nodes())
        assert len(result) == 5
