package parser

import (
	"testing"
	"subforge/internal/core"
)

func TestParseVMess(t *testing.T) {
	// VMess base64 encoded JSON
	uri := `vmess://eyJ2IjoiMiIsInBzIjoiVVMtMDEiLCJhZGQiOiIxLjIuMy40IiwicG9ydCI6NDQzLCJpZCI6IjEyMzQ1Njc4LWFiY2QtMTIzNC01Njc4LTEyMzQ1Njc4OWFiYyIsImFpZCI6MCwibmV0Ijoid3MiLCJ0eXBlIjoiIiwiaG9zdCI6ImV4YW1wbGUuY29tIiwicGF0aCI6Ii93cyIsInRscyI6InRscyJ9`

	p := &URIParser{}
	if !p.Detect(uri) {
		t.Fatal("should detect vmess")
	}

	nodes, err := p.Parse(uri)
	if err != nil {
		t.Fatalf("parse error: %v", err)
	}
	if len(nodes) != 1 {
		t.Fatalf("expected 1 node, got %d", len(nodes))
	}

	n := nodes[0]
	if n.Type != core.TypeVMess {
		t.Errorf("type = %s, want vmess", n.Type)
	}
	if n.Server != "1.2.3.4" {
		t.Errorf("server = %s, want 1.2.3.4", n.Server)
	}
	if n.Port != 443 {
		t.Errorf("port = %d, want 443", n.Port)
	}
	if !n.TLS {
		t.Error("tls should be true")
	}
	if n.Transport != "ws" {
		t.Errorf("transport = %s, want ws", n.Transport)
	}
}

func TestParseVLESS(t *testing.T) {
	uri := `vless://12345678-abcd-1234-5678-123456789abc@1.2.3.4:443?type=ws&security=tls&sni=example.com#US-01`

	p := &URIParser{}
	if !p.Detect(uri) {
		t.Fatal("should detect vless")
	}

	nodes, err := p.Parse(uri)
	if err != nil {
		t.Fatalf("parse error: %v", err)
	}
	if len(nodes) != 1 {
		t.Fatalf("expected 1 node, got %d", len(nodes))
	}

	n := nodes[0]
	if n.Type != core.TypeVLESS {
		t.Errorf("type = %s, want vless", n.Type)
	}
	if n.UUID != "12345678-abcd-1234-5678-123456789abc" {
		t.Errorf("uuid = %s", n.UUID)
	}
	if n.SNI != "example.com" {
		t.Errorf("sni = %s, want example.com", n.SNI)
	}
	if n.Name != "US-01" {
		t.Errorf("name = %s, want US-01", n.Name)
	}
}

func TestParseTrojan(t *testing.T) {
	uri := `trojan://password123@1.2.3.4:443?security=tls&type=ws&sni=example.com#JP-01`

	p := &URIParser{}
	if !p.Detect(uri) {
		t.Fatal("should detect trojan")
	}

	nodes, err := p.Parse(uri)
	if err != nil {
		t.Fatalf("parse error: %v", err)
	}
	if len(nodes) != 1 {
		t.Fatalf("expected 1 node, got %d", len(nodes))
	}

	n := nodes[0]
	if n.Type != core.TypeTrojan {
		t.Errorf("type = %s, want trojan", n.Type)
	}
	if n.Password != "password123" {
		t.Errorf("password = %s", n.Password)
	}
	if n.Name != "JP-01" {
		t.Errorf("name = %s, want JP-01", n.Name)
	}
}

func TestParseSS(t *testing.T) {
	uri := `ss://Y2hhY2hhMjA6cGFzc3dvcmQxMjNA@1.2.3.4:8388#SG-01`

	p := &URIParser{}
	if !p.Detect(uri) {
		t.Fatal("should detect ss")
	}

	nodes, err := p.Parse(uri)
	if err != nil {
		t.Fatalf("parse error: %v", err)
	}
	if len(nodes) != 1 {
		t.Fatalf("expected 1 node, got %d", len(nodes))
	}

	n := nodes[0]
	if n.Type != core.TypeSS {
		t.Errorf("type = %s, want ss", n.Type)
	}
	if n.Name != "SG-01" {
		t.Errorf("name = %s, want SG-01", n.Name)
	}
}

func TestParseMultipleURIs(t *testing.T) {
	content := `vmess://eyJ2IjoiMiIsInBzIjoiSEstMDEiLCJhZGQiOiIxLjIuMy40IiwicG9ydCI6NDQzLCJpZCI6IjEyMzQ1Njc4LWFiY2QtMTIzNC01Njc4LTEyMzQ1Njc4OWFiYyIsImFpZCI6MCwibmV0Ijoid3MiLCJ0eXBlIjoiIiwiaG9zdCI6IiIsInBhdGgiOiIiLCJ0bHMiOiJ0bHMifQ==
vless://uuid@5.6.7.8:443?type=tcp&security=tls#JP-01`

	p := &Base64Parser{}
	if !p.Detect(content) {
		t.Fatal("should detect base64")
	}

	nodes, err := p.Parse(content)
	if err != nil {
		t.Fatalf("parse error: %v", err)
	}
	if len(nodes) < 1 {
		t.Fatalf("expected at least 1 node, got %d", len(nodes))
	}
}

func TestDetectFormat(t *testing.T) {
	tests := []struct {
		name    string
		content string
		want    string
	}{
		{"base64", "dm1lc3M6Ly8=", "base64"},
		{"uri", "vmess://abc", "uri"},
		{"unknown", "random text", "unknown"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := DetectFormat(tt.content)
			if got != tt.want {
				t.Errorf("DetectFormat() = %s, want %s", got, tt.want)
			}
		})
	}
}
