package smart

import (
	"testing"
	"subforge/internal/core"
)

func TestDeduplicateEmpty(t *testing.T) {
	result := Deduplicate(nil)
	if len(result) != 0 {
		t.Errorf("expected 0, got %d", len(result))
	}
}

func TestDeduplicateNoDuplicates(t *testing.T) {
	nodes := []core.ProxyNode{
		{Name: "A", Type: core.TypeVMess, Server: "1.1.1.1", Port: 443},
		{Name: "B", Type: core.TypeTrojan, Server: "2.2.2.2", Port: 443},
	}
	result := Deduplicate(nodes)
	if len(result) != 2 {
		t.Errorf("expected 2, got %d", len(result))
	}
}

func TestDeduplicateDifferentPorts(t *testing.T) {
	nodes := []core.ProxyNode{
		{Name: "A", Type: core.TypeVMess, Server: "1.1.1.1", Port: 443},
		{Name: "B", Type: core.TypeVMess, Server: "1.1.1.1", Port: 8443},
	}
	result := Deduplicate(nodes)
	if len(result) != 2 {
		t.Errorf("expected 2 (different ports), got %d", len(result))
	}
}

func TestDeduplicateDifferentTypes(t *testing.T) {
	nodes := []core.ProxyNode{
		{Name: "A", Type: core.TypeVMess, Server: "1.1.1.1", Port: 443},
		{Name: "B", Type: core.TypeTrojan, Server: "1.1.1.1", Port: 443},
	}
	result := Deduplicate(nodes)
	if len(result) != 2 {
		t.Errorf("expected 2 (different types), got %d", len(result))
	}
}

func TestFilterByRegionEmpty(t *testing.T) {
	nodes := []core.ProxyNode{
		{Name: "A", Extra: map[string]interface{}{"region": "HK"}},
	}
	result := FilterByRegion(nodes, nil)
	if len(result) != 1 {
		t.Errorf("expected 1 (no filter), got %d", len(result))
	}
}

func TestFilterByKeywordEmpty(t *testing.T) {
	nodes := []core.ProxyNode{
		{Name: "A"}, {Name: "B"},
	}
	result := FilterByKeyword(nodes, nil)
	if len(result) != 2 {
		t.Errorf("expected 2 (no filter), got %d", len(result))
	}
}

func TestFilterByKeywordRegex(t *testing.T) {
	nodes := []core.ProxyNode{
		{Name: "HK-01 Premium"},
		{Name: "JP-01 过期"},
		{Name: "SG-01 到期"},
		{Name: "US-01 Free"},
	}
	result := FilterByKeyword(nodes, []string{`过期|到期`})
	if len(result) != 2 {
		t.Errorf("expected 2, got %d", len(result))
	}
}
