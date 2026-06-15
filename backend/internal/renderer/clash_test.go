package renderer

import (
	"strings"
	"testing"
	"subforge/internal/core"
)

func TestClashRenderer(t *testing.T) {
	nodes := []core.ProxyNode{
		{
			Name:      "HK-01",
			Type:      core.TypeVMess,
			Server:    "1.2.3.4",
			Port:      443,
			UUID:      "test-uuid",
			Transport: "ws",
			TLS:       true,
			SNI:       "example.com",
		},
		{
			Name:     "JP-01",
			Type:     core.TypeTrojan,
			Server:   "5.6.7.8",
			Port:     443,
			Password: "password",
			TLS:      true,
			SNI:      "test.com",
		},
	}

	r := &ClashRenderer{}
	result, err := r.Render(nodes)
	if err != nil {
		t.Fatalf("render error: %v", err)
	}

	if !strings.Contains(result, "proxies:") {
		t.Error("should contain 'proxies:'")
	}
	if !strings.Contains(result, "HK-01") {
		t.Error("should contain HK-01")
	}
	if !strings.Contains(result, "JP-01") {
		t.Error("should contain JP-01")
	}
	if !strings.Contains(result, "vmess") {
		t.Error("should contain vmess type")
	}
	if !strings.Contains(result, "trojan") {
		t.Error("should contain trojan type")
	}
}

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
	}

	r := &SingBoxRenderer{}
	result, err := r.Render(nodes)
	if err != nil {
		t.Fatalf("render error: %v", err)
	}

	if !strings.Contains(result, "outbounds") {
		t.Error("should contain 'outbounds'")
	}
	if !strings.Contains(result, "HK-01") {
		t.Error("should contain HK-01")
	}
	if !strings.Contains(result, "vless") {
		t.Error("should contain vless type")
	}
}

func TestBase64Renderer(t *testing.T) {
	nodes := []core.ProxyNode{
		{
			Name:   "HK-01",
			Type:   core.TypeTrojan,
			Server: "1.2.3.4",
			Port:   443,
			Password: "password",
		},
	}

	r := &Base64Renderer{}
	result, err := r.Render(nodes)
	if err != nil {
		t.Fatalf("render error: %v", err)
	}

	if len(result) == 0 {
		t.Error("should return non-empty base64")
	}
}

func TestListFormats(t *testing.T) {
	formats := ListFormats()
	if len(formats) < 5 {
		t.Errorf("expected at least 5 formats, got %d", len(formats))
	}

	// Check sorted
	for i := 1; i < len(formats); i++ {
		if formats[i] < formats[i-1] {
			t.Errorf("formats not sorted: %s < %s", formats[i], formats[i-1])
		}
	}
}
