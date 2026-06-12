package renderer

import (
	"fmt"
	"subforge/internal/core"
)

type LoonRenderer struct{}

func (r *LoonRenderer) Name() string { return core.FormatLoon }

func (r *LoonRenderer) Render(nodes []core.ProxyNode) (string, error) {
	out := "[Proxy]\n"
	for _, n := range nodes {
		out += renderLoonProxy(n) + "\n"
	}
	return out, nil
}

func renderLoonProxy(n core.ProxyNode) string {
	switch n.Type {
	case core.TypeVMess:
		line := fmt.Sprintf("%s = vmess, %s, %d, \"%s\"",
			n.Name, n.Server, n.Port, n.UUID)
		if n.Transport != "" {
			line += fmt.Sprintf(", transport=%s", n.Transport)
		}
		if n.TLS {
			line += ", tls=true"
			if n.SNI != "" {
				line += fmt.Sprintf(", sni=%s", n.SNI)
			}
		}
		return line

	case core.TypeTrojan:
		line := fmt.Sprintf("%s = trojan, %s, %d, \"%s\"",
			n.Name, n.Server, n.Port, n.Password)
		if n.SNI != "" {
			line += fmt.Sprintf(", sni=%s", n.SNI)
		}
		return line

	case core.TypeSS:
		return fmt.Sprintf("%s = shadowsocks, %s, %d, \"%s\", \"%s\"",
			n.Name, n.Server, n.Port, getStr(n.Extra, "cipher"), getStr(n.Extra, "password"))

	default:
		return fmt.Sprintf("# unsupported: %s = %s", n.Name, n.Type)
	}
}
