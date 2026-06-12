package renderer

import (
	"fmt"
	"subforge/internal/core"
)

type SurgeRenderer struct{}

func (r *SurgeRenderer) Name() string { return core.FormatSurge }

func (r *SurgeRenderer) Render(nodes []core.ProxyNode) (string, error) {
	out := "[Proxy]\n"
	for i, n := range nodes {
		out += renderSurgeProxy(n, i) + "\n"
	}
	return out, nil
}

func renderSurgeProxy(n core.ProxyNode, idx int) string {
	switch n.Type {
	case core.TypeVMess:
		line := fmt.Sprintf("%s = vmess, %s, %d, username=%s",
			n.Name, n.Server, n.Port, n.UUID)
		if n.TLS {
			line += ", tls=true"
			if n.SNI != "" {
				line += fmt.Sprintf(", sni=%s", n.SNI)
			}
		}
		return line

	case core.TypeTrojan:
		line := fmt.Sprintf("%s = trojan, %s, %d, password=%s",
			n.Name, n.Server, n.Port, n.Password)
		if n.SNI != "" {
			line += fmt.Sprintf(", sni=%s", n.SNI)
		}
		return line

	case core.TypeSS:
		return fmt.Sprintf("%s = ss, %s, %d, encrypt-method=%s, password=%s",
			n.Name, n.Server, n.Port, getStr(n.Extra, "cipher"), getStr(n.Extra, "password"))

	default:
		return fmt.Sprintf("# unsupported: %s = %s, %s, %d", n.Name, n.Type, n.Server, n.Port)
	}
}
