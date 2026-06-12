package renderer

import (
	"fmt"
	"subforge/internal/core"
)

type QXRenderer struct{}

func (r *QXRenderer) Name() string { return core.FormatQX }

func (r *QXRenderer) Render(nodes []core.ProxyNode) (string, error) {
	out := ""
	for _, n := range nodes {
		out += renderQXProxy(n) + "\n"
	}
	return out, nil
}

func renderQXProxy(n core.ProxyNode) string {
	switch n.Type {
	case core.TypeVMess:
		return fmt.Sprintf("vmess=%s:%d, method=chacha20-ietf-poly1305, password=%s, tag=%s",
			n.Server, n.Port, n.UUID, n.Name)
	case core.TypeTrojan:
		return fmt.Sprintf("trojan=%s:%d, password=%s, sni=%s, tag=%s",
			n.Server, n.Port, n.Password, n.SNI, n.Name)
	case core.TypeSS:
		return fmt.Sprintf("shadowsocks=%s:%d, method=%s, password=%s, tag=%s",
			n.Server, n.Port, getStr(n.Extra, "cipher"), getStr(n.Extra, "password"), n.Name)
	default:
		return fmt.Sprintf("# unsupported: %s (%s)", n.Name, n.Type)
	}
}
