package smart

import (
	"testing"
	"subforge/internal/core"
)

func TestRenameByRegion(t *testing.T) {
	nodes := []core.ProxyNode{
		{Name: "Hong Kong 01", Type: core.TypeVMess, Server: "1.2.3.4", Port: 443},
		{Name: "Japan Tokyo", Type: core.TypeVLESS, Server: "5.6.7.8", Port: 443},
		{Name: "Singapore", Type: core.TypeTrojan, Server: "9.10.11.12", Port: 443},
		{Name: "Random Node", Type: core.TypeSS, Server: "1.2.3.4", Port: 8388},
	}

	result := RenameByRegion(nodes)

	if len(result) != 4 {
		t.Fatalf("expected 4 nodes, got %d", len(result))
	}

	// Check HK node
	if result[0].Name == "" {
		t.Error("HK node name should not be empty")
	}

	// Check region detection
	tests := []struct {
		index  int
		region string
	}{
		{0, "HK"},
		{1, "JP"},
		{2, "SG"},
		{3, "OTHER"},
	}

	for _, tt := range tests {
		region, ok := result[tt.index].Extra["region"].(string)
		if !ok {
			t.Errorf("node %d: missing region in Extra", tt.index)
			continue
		}
		if region != tt.region {
			t.Errorf("node %d: region = %s, want %s", tt.index, region, tt.region)
		}
	}
}

func TestDeduplicate(t *testing.T) {
	nodes := []core.ProxyNode{
		{Name: "Node 1", Type: core.TypeVMess, Server: "1.2.3.4", Port: 443},
		{Name: "Node 2", Type: core.TypeVMess, Server: "1.2.3.4", Port: 443}, // duplicate
		{Name: "Node 3", Type: core.TypeTrojan, Server: "1.2.3.4", Port: 443}, // different type
		{Name: "Node 4", Type: core.TypeVMess, Server: "5.6.7.8", Port: 443},  // different server
	}

	result := Deduplicate(nodes)

	if len(result) != 3 {
		t.Errorf("expected 3 nodes after dedup, got %d", len(result))
	}
}

func TestFilterByRegion(t *testing.T) {
	nodes := []core.ProxyNode{
		{Name: "HK-01", Type: core.TypeVMess, Server: "1.2.3.4", Port: 443, Extra: map[string]interface{}{"region": "HK"}},
		{Name: "JP-01", Type: core.TypeVMess, Server: "5.6.7.8", Port: 443, Extra: map[string]interface{}{"region": "JP"}},
		{Name: "SG-01", Type: core.TypeVMess, Server: "9.10.11.12", Port: 443, Extra: map[string]interface{}{"region": "SG"}},
	}

	result := FilterByRegion(nodes, []string{"HK", "JP"})

	if len(result) != 2 {
		t.Errorf("expected 2 nodes, got %d", len(result))
	}
}

func TestFilterByKeyword(t *testing.T) {
	nodes := []core.ProxyNode{
		{Name: "HK-01 Premium", Type: core.TypeVMess, Server: "1.2.3.4", Port: 443},
		{Name: "JP-01 过期", Type: core.TypeVMess, Server: "5.6.7.8", Port: 443},
		{Name: "SG-01 到期", Type: core.TypeVMess, Server: "9.10.11.12", Port: 443},
		{Name: "US-01 Free", Type: core.TypeVMess, Server: "13.14.15.16", Port: 443},
	}

	result := FilterByKeyword(nodes, []string{`过期|到期`})

	if len(result) != 2 {
		t.Errorf("expected 2 nodes after filter, got %d", len(result))
	}
}
