package parser

import (
	"strings"
	"subforge/internal/core"
)

// Parser defines the interface for subscription format parsers.
type Parser interface {
	Name() string
	Detect(content string) bool
	Parse(content string) ([]core.ProxyNode, error)
}

var registry []Parser

func Register(p Parser) {
	registry = append(registry, p)
}

func GetAll() []Parser {
	return registry
}

// DetectFormat auto-detects the subscription format.
func DetectFormat(content string) string {
	content = strings.TrimSpace(content)
	for _, p := range registry {
		if p.Detect(content) {
			return p.Name()
		}
	}
	return "unknown"
}

// ParseWithAutoDetect parses content with automatic format detection.
func ParseWithAutoDetect(content string) ([]core.ProxyNode, string, error) {
	content = strings.TrimSpace(content)
	for _, p := range registry {
		if p.Detect(content) {
			nodes, err := p.Parse(content)
			return nodes, p.Name(), err
		}
	}
	// Fallback to base64
	nodes, err := (&Base64Parser{}).Parse(content)
	return nodes, "base64", err
}

func init() {
	Register(&Base64Parser{})
	Register(&URIParser{})
	Register(&ClashParser{})
	Register(&SingBoxParser{})
}
