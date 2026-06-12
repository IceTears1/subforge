package renderer

import (
	"fmt"
	"subforge/internal/core"
)

type ClashRenderer struct{}

func (r *ClashRenderer) Name() string { return core.FormatClash }

func (r *ClashRenderer) Render(nodes []core.ProxyNode) (string, error) {
	out := "mixed-port: 7890\nallow-lan: false\nmode: rule\nproxies:\n"
	for _, n := range nodes {
		out += renderClashProxy(n) + "\n"
	}
	return out, nil
}

func renderClashProxy(n core.ProxyNode) string {
	base := fmt.Sprintf("  - {name: '%s', type: %s, server: %s, port: %d",
		escapeYAML(n.Name), n.Type, n.Server, n.Port)

	switch n.Type {
	case core.TypeVMess:
		base += fmt.Sprintf(", uuid: %s, alterId: %d, cipher: auto", n.UUID, getInt(n.Extra, "alter_id"))
		if n.Transport != "" && n.Transport != "tcp" {
			base += fmt.Sprintf(", network: %s", n.Transport)
		}
		if host := getStr(n.Extra, "host"); host != "" {
			base += fmt.Sprintf(", ws-headers: {Host: '%s'}", escapeYAML(host))
		}
		if path := getStr(n.Extra, "path"); path != "" {
			base += fmt.Sprintf(", ws-path: '%s'", escapeYAML(path))
		}

	case core.TypeVLESS:
		base += fmt.Sprintf(", uuid: %s", n.UUID)
		if n.Transport != "" && n.Transport != "tcp" {
			base += fmt.Sprintf(", network: %s", n.Transport)
		}
		if flow := getStr(n.Extra, "flow"); flow != "" {
			base += fmt.Sprintf(", flow: %s", flow)
		}

	case core.TypeTrojan:
		base += fmt.Sprintf(", password: '%s'", escapeYAML(n.Password))
		if n.Transport != "" && n.Transport != "tcp" {
			base += fmt.Sprintf(", network: %s", n.Transport)
		}

	case core.TypeSS:
		base += fmt.Sprintf(", cipher: %s, password: '%s'",
			getStr(n.Extra, "cipher"), escapeYAML(getStr(n.Extra, "password")))

	case core.TypeHysteria2:
		base += fmt.Sprintf(", password: '%s'", escapeYAML(n.Password))
		if obfs := getStr(n.Extra, "obfs"); obfs != "" {
			base += fmt.Sprintf(", obfs: %s, obfs-password: '%s'", obfs, escapeYAML(getStr(n.Extra, "obfs_pwd")))
		}
	}

	if n.TLS {
		base += ", tls: true"
		if n.SNI != "" {
			base += fmt.Sprintf(", servername: '%s'", escapeYAML(n.SNI))
		}
	}

	base += "}"
	return base
}

func escapeYAML(s string) string {
	r := ""
	for _, c := range s {
		if c == '\'' {
			r += "''"
		} else {
			r += string(c)
		}
	}
	return r
}

func getStr(m map[string]interface{}, key string) string {
	if m == nil {
		return ""
	}
	if v, ok := m[key]; ok {
		return fmt.Sprintf("%v", v)
	}
	return ""
}

func getInt(m map[string]interface{}, key string) int {
	if m == nil {
		return 0
	}
	if v, ok := m[key]; ok {
		switch val := v.(type) {
		case int:
			return val
		case float64:
			return int(val)
		}
	}
	return 0
}
