package parser

import (
	"strconv"
	"strings"
	"subforge/internal/core"

	"github.com/goccy/go-yaml"
)

type ClashParser struct{}

func (p *ClashParser) Name() string { return "clash" }

func (p *ClashParser) Detect(content string) bool {
	return strings.Contains(content, "proxies:") &&
		(strings.Contains(content, "- {") || strings.Contains(content, "- name:"))
}

func (p *ClashParser) Parse(content string) ([]core.ProxyNode, error) {
	var cfg struct {
		Proxies []map[string]interface{} `yaml:"proxies"`
	}
	if err := yaml.Unmarshal([]byte(content), &cfg); err != nil {
		return nil, err
	}
	var nodes []core.ProxyNode
	for _, px := range cfg.Proxies {
		node := parseClashProxy(px)
		if node != nil {
			nodes = append(nodes, *node)
		}
	}
	return nodes, nil
}

func parseClashProxy(m map[string]interface{}) *core.ProxyNode {
	name, _ := m["name"].(string)
	server, _ := m["server"].(string)
	port, _ := toInt(m["port"])
	typ, _ := m["type"].(string)

	if server == "" || port == 0 {
		return nil
	}

	node := &core.ProxyNode{
		Name:   name,
		Type:   strings.ToLower(typ),
		Server: server,
		Port:   port,
		Extra:  make(map[string]interface{}),
	}

	switch node.Type {
	case core.TypeVMess:
		node.UUID, _ = m["uuid"].(string)
		node.Transport, _ = m["network"].(string)
		node.TLS, _ = m["tls"].(bool)
		node.SNI, _ = m["servername"].(string)
		if node.SNI == "" {
			node.SNI, _ = m["sni"].(string)
		}
		node.Extra["alter_id"], _ = toInt(m["alterId"])
		node.Extra["cipher"], _ = m["cipher"].(string)

	case core.TypeVLESS:
		node.UUID, _ = m["uuid"].(string)
		node.Transport, _ = m["network"].(string)
		node.TLS, _ = m["tls"].(bool)
		node.SNI, _ = m["servername"].(string)
		node.Extra["flow"], _ = m["flow"].(string)

	case core.TypeTrojan:
		node.Password, _ = m["password"].(string)
		node.Transport, _ = m["network"].(string)
		node.TLS = true
		node.SNI, _ = m["sni"].(string)

	case core.TypeSS:
		node.Extra["cipher"], _ = m["cipher"].(string)
		node.Extra["password"], _ = m["password"].(string)

	case core.TypeHysteria2:
		node.Password, _ = m["password"].(string)
		node.TLS = true
		node.SNI, _ = m["sni"].(string)
		if node.SNI == "" {
			node.SNI, _ = m["servername"].(string)
		}
	}

	return node
}

func toInt(v interface{}) (int, bool) {
	switch val := v.(type) {
	case int:
		return val, true
	case int64:
		return int(val), true
	case float64:
		return int(val), true
	case string:
		i, err := strconv.Atoi(val)
		return i, err == nil
	}
	return 0, false
}
