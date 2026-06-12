package renderer

import (
	"encoding/json"
	"subforge/internal/core"
)

type SingBoxRenderer struct{}

func (r *SingBoxRenderer) Name() string { return core.FormatSingBox }

func (r *SingBoxRenderer) Render(nodes []core.ProxyNode) (string, error) {
	var outbounds []map[string]interface{}

	for _, n := range nodes {
		ob := map[string]interface{}{
			"type":        n.Type,
			"tag":         n.Name,
			"server":      n.Server,
			"server_port": n.Port,
		}

		switch n.Type {
		case core.TypeVMess, core.TypeVLESS:
			ob["uuid"] = n.UUID
			if n.Transport != "" && n.Transport != "tcp" {
				ob["transport"] = map[string]interface{}{"type": n.Transport}
			}
			if flow := getStr(n.Extra, "flow"); flow != "" && n.Type == core.TypeVLESS {
				ob["flow"] = flow
			}

		case core.TypeTrojan:
			ob["password"] = n.Password

		case core.TypeSS:
			ob["method"] = getStr(n.Extra, "cipher")
			ob["password"] = getStr(n.Extra, "password")

		case core.TypeHysteria2:
			ob["password"] = n.Password
			if obfs := getStr(n.Extra, "obfs"); obfs != "" {
				ob["obfs"] = map[string]interface{}{
					"type":     obfs,
					"password": getStr(n.Extra, "obfs_pwd"),
				}
			}
		}

		if n.TLS {
			tls := map[string]interface{}{"enabled": true}
			if n.SNI != "" {
				tls["server_name"] = n.SNI
			}
			ob["tls"] = tls
		}

		outbounds = append(outbounds, ob)
	}

	result := map[string]interface{}{
		"outbounds": outbounds,
	}
	data, err := json.MarshalIndent(result, "", "  ")
	return string(data), err
}
