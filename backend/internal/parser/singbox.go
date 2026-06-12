package parser

import (
	"encoding/json"
	"strings"
	"subforge/internal/core"
)

type SingBoxParser struct{}

func (p *SingBoxParser) Name() string { return "singbox" }

func (p *SingBoxParser) Detect(content string) bool {
	return strings.Contains(content, "\"outbounds\"") &&
		strings.Contains(content, "\"type\"")
}

func (p *SingBoxParser) Parse(content string) ([]core.ProxyNode, error) {
	var cfg struct {
		Outbounds []json.RawMessage `json:"outbounds"`
	}
	if err := json.Unmarshal([]byte(content), &cfg); err != nil {
		return nil, err
	}
	var nodes []core.ProxyNode
	for _, raw := range cfg.Outbounds {
		var base struct {
			Type   string `json:"type"`
			Tag    string `json:"tag"`
			Server string `json:"server"`
			ServerPort int `json:"server_port"`
		}
		if err := json.Unmarshal(raw, &base); err != nil {
			continue
		}
		if base.Server == "" || base.ServerPort == 0 {
			continue
		}

		node := core.ProxyNode{
			Name:   base.Tag,
			Type:   base.Type,
			Server: base.Server,
			Port:   base.ServerPort,
			Extra:  make(map[string]interface{}),
		}

		// Parse protocol-specific fields
		switch base.Type {
		case "vmess":
			var v struct {
				UUID        string `json:"uuid"`
				Transport   map[string]interface{} `json:"transport"`
				TLS         map[string]interface{} `json:"tls"`
			}
			json.Unmarshal(raw, &v)
			node.UUID = v.UUID
			if v.Transport != nil {
				if t, ok := v.Transport["type"].(string); ok {
					node.Transport = t
				}
			}
			if v.TLS != nil {
				if enabled, ok := v.TLS["enabled"].(bool); ok {
					node.TLS = enabled
				}
				if sni, ok := v.TLS["server_name"].(string); ok {
					node.SNI = sni
				}
			}

		case "vless":
			var v struct {
				UUID      string `json:"uuid"`
				Flow      string `json:"flow"`
				Transport map[string]interface{} `json:"transport"`
				TLS       map[string]interface{} `json:"tls"`
			}
			json.Unmarshal(raw, &v)
			node.UUID = v.UUID
			node.Extra["flow"] = v.Flow
			if v.Transport != nil {
				if t, ok := v.Transport["type"].(string); ok {
					node.Transport = t
				}
			}
			if v.TLS != nil {
				if enabled, ok := v.TLS["enabled"].(bool); ok {
					node.TLS = enabled
				}
				if sni, ok := v.TLS["server_name"].(string); ok {
					node.SNI = sni
				}
			}

		case "trojan":
			var v struct {
				Password  string `json:"password"`
				Transport map[string]interface{} `json:"transport"`
				TLS       map[string]interface{} `json:"tls"`
			}
			json.Unmarshal(raw, &v)
			node.Password = v.Password
			node.TLS = true
			if v.TLS != nil {
				if sni, ok := v.TLS["server_name"].(string); ok {
					node.SNI = sni
				}
			}
		}

		nodes = append(nodes, node)
	}
	return nodes, nil
}
