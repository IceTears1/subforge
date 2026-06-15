package renderer

import (
	"encoding/json"
	"testing"
	"subforge/internal/core"
)

func TestSingBoxRenderer(t *testing.T) {
	nodes := []core.ProxyNode{
		{
			Name:   "HK-01",
			Type:   core.TypeVLESS,
			Server: "1.2.3.4",
			Port:   443,
			UUID:   "test-uuid",
			TLS:    true,
			SNI:    "example.com",
		},
		{
			Name:     "JP-01",
			Type:     core.TypeTrojan,
			Server:   "5.6.7.8",
			Port:     443,
			Password: "password",
			TLS:      true,
		},
	}

	r := &SingBoxRenderer{}
	result, err := r.Render(nodes)
	if err != nil {
		t.Fatalf("render error: %v", err)
	}

	// Parse JSON
	var config map[string]interface{}
	if err := json.Unmarshal([]byte(result), &config); err != nil {
		t.Fatalf("invalid JSON: %v", err)
	}

	// Check outbounds
	outbounds, ok := config["outbounds"].([]interface{})
	if !ok {
		t.Fatal("missing outbounds")
	}
	if len(outbounds) != 2 {
		t.Errorf("expected 2 outbounds, got %d", len(outbounds))
	}

	// Check first outbound
	ob1 := outbounds[0].(map[string]interface{})
	if ob1["tag"] != "HK-01" {
		t.Errorf("tag = %v, want HK-01", ob1["tag"])
	}
	if ob1["type"] != "vless" {
		t.Errorf("type = %v, want vless", ob1["type"])
	}
}

func TestSingBoxRendererEmpty(t *testing.T) {
	r := &SingBoxRenderer{}
	result, err := r.Render(nil)
	if err != nil {
		t.Fatalf("render error: %v", err)
	}

	var config map[string]interface{}
	if err := json.Unmarshal([]byte(result), &config); err != nil {
		t.Fatalf("invalid JSON: %v", err)
	}

	outbounds := config["outbounds"].([]interface{})
	if len(outbounds) != 0 {
		t.Errorf("expected 0 outbounds, got %d", len(outbounds))
	}
}
