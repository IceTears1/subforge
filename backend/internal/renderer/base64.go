package renderer

import (
	"encoding/base64"
	"fmt"
	"strings"
	"subforge/internal/core"
)

type Base64Renderer struct{}

func (r *Base64Renderer) Name() string { return core.FormatBase64 }

func (r *Base64Renderer) Render(nodes []core.ProxyNode) (string, error) {
	var lines []string
	for _, n := range nodes {
		lines = append(lines, nodeToURI(n))
	}
	raw := strings.Join(lines, "\n")
	return base64.StdEncoding.EncodeToString([]byte(raw)), nil
}

func nodeToURI(n core.ProxyNode) string {
	switch n.Type {
	case core.TypeVMess:
		// VMess uses JSON + base64
		return fmt.Sprintf("vmess://%s", n.Name)
	case core.TypeVLESS:
		return fmt.Sprintf("vless://%s@%s:%d#%s", n.UUID, n.Server, n.Port, n.Name)
	case core.TypeTrojan:
		return fmt.Sprintf("trojan://%s@%s:%d#%s", n.Password, n.Server, n.Port, n.Name)
	case core.TypeSS:
		return fmt.Sprintf("ss://%s@%s:%d#%s", getStr(n.Extra, "password"), n.Server, n.Port, n.Name)
	case core.TypeHysteria2:
		return fmt.Sprintf("hy2://%s@%s:%d#%s", n.Password, n.Server, n.Port, n.Name)
	default:
		return fmt.Sprintf("# unsupported: %s", n.Name)
	}
}
