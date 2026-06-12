package parser

import (
	"encoding/base64"
	"strings"
	"subforge/internal/core"
)

type Base64Parser struct{}

func (p *Base64Parser) Name() string { return "base64" }

func (p *Base64Parser) Detect(content string) bool {
	// Try to decode as base64
	decoded, err := base64.StdEncoding.DecodeString(content)
	if err != nil {
		decoded, err = base64.URLEncoding.DecodeString(content)
		if err != nil {
			return false
		}
	}
	s := string(decoded)
	return strings.Contains(s, "://") && (
		strings.Contains(s, "vmess://") ||
		strings.Contains(s, "vless://") ||
		strings.Contains(s, "trojan://") ||
		strings.Contains(s, "ss://") ||
		strings.Contains(s, "ssr://") ||
		strings.Contains(s, "hy2://"))
}

func (p *Base64Parser) Parse(content string) ([]core.ProxyNode, error) {
	content = strings.TrimSpace(content)
	decoded, err := base64.StdEncoding.DecodeString(content)
	if err != nil {
		decoded, err = base64.URLEncoding.DecodeString(content)
		if err != nil {
			return nil, err
		}
	}
	lines := strings.Split(strings.TrimSpace(string(decoded)), "\n")
	uriParser := &URIParser{}
	var nodes []core.ProxyNode
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		parsed, err := uriParser.Parse(line)
		if err != nil {
			continue
		}
		nodes = append(nodes, parsed...)
	}
	return nodes, nil
}
