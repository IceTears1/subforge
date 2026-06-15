package parser

import (
	"testing"
	"subforge/internal/core"
)

func TestClashParserDetect(t *testing.T) {
	tests := []struct {
		name    string
		content string
		want    bool
	}{
		{"valid clash", "proxies:\n  - {name: test, type: vmess}", true},
		{"clash with name", "proxies:\n  - name: test\n    type: vmess", true},
		{"not clash", "vmess://abc123", false},
		{"empty", "", false},
		{"random text", "hello world", false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			p := &ClashParser{}
			if got := p.Detect(tt.content); got != tt.want {
				t.Errorf("Detect() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestClashParserParse(t *testing.T) {
	content := `
proxies:
  - {name: "HK-01", type: vmess, server: 1.2.3.4, port: 443, uuid: test-uuid, alterId: 0, cipher: auto, tls: true}
  - {name: "JP-01", type: trojan, server: 5.6.7.8, port: 443, password: test-pass, sni: example.com}
`

	p := &ClashParser{}
	nodes, err := p.Parse(content)
	if err != nil {
		t.Fatalf("parse error: %v", err)
	}

	if len(nodes) != 2 {
		t.Fatalf("expected 2 nodes, got %d", len(nodes))
	}

	// Check first node
	n1 := nodes[0]
	if n1.Name != "HK-01" {
		t.Errorf("name = %s, want HK-01", n1.Name)
	}
	if n1.Type != core.TypeVMess {
		t.Errorf("type = %s, want vmess", n1.Type)
	}
	if n1.Server != "1.2.3.4" {
		t.Errorf("server = %s, want 1.2.3.4", n1.Server)
	}
	if n1.Port != 443 {
		t.Errorf("port = %d, want 443", n1.Port)
	}
	if !n1.TLS {
		t.Error("tls should be true")
	}

	// Check second node
	n2 := nodes[1]
	if n2.Name != "JP-01" {
		t.Errorf("name = %s, want JP-01", n2.Name)
	}
	if n2.Type != core.TypeTrojan {
		t.Errorf("type = %s, want trojan", n2.Type)
	}
}

func TestClashParserParseEmpty(t *testing.T) {
	p := &ClashParser{}
	nodes, err := p.Parse("proxies: []")
	if err != nil {
		t.Fatalf("parse error: %v", err)
	}
	if len(nodes) != 0 {
		t.Errorf("expected 0 nodes, got %d", len(nodes))
	}
}
