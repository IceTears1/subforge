package parser

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/url"
	"strconv"
	"strings"
	"subforge/internal/core"
)

type URIParser struct{}

func (p *URIParser) Name() string { return "uri" }

func (p *URIParser) Detect(content string) bool {
	s := strings.TrimSpace(content)
	return strings.HasPrefix(s, "vmess://") ||
		strings.HasPrefix(s, "vless://") ||
		strings.HasPrefix(s, "trojan://") ||
		strings.HasPrefix(s, "ss://") ||
		strings.HasPrefix(s, "ssr://") ||
		strings.HasPrefix(s, "hy2://")
}

func (p *URIParser) Parse(content string) ([]core.ProxyNode, error) {
	content = strings.TrimSpace(content)
	lines := strings.Split(content, "\n")
	var nodes []core.ProxyNode
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		node, err := parseURI(line)
		if err != nil {
			continue
		}
		nodes = append(nodes, *node)
	}
	return nodes, nil
}

func parseURI(uri string) (*core.ProxyNode, error) {
	switch {
	case strings.HasPrefix(uri, "vmess://"):
		return parseVMess(uri)
	case strings.HasPrefix(uri, "vless://"):
		return parseVLESS(uri)
	case strings.HasPrefix(uri, "trojan://"):
		return parseTrojan(uri)
	case strings.HasPrefix(uri, "ss://"):
		return parseSS(uri)
	case strings.HasPrefix(uri, "ssr://"):
		return parseSSR(uri)
	case strings.HasPrefix(uri, "hy2://"):
		return parseHysteria2(uri)
	}
	return nil, fmt.Errorf("unsupported protocol")
}

func parseVMess(uri string) (*core.ProxyNode, error) {
	raw := strings.TrimPrefix(uri, "vmess://")
	decoded, err := base64.StdEncoding.DecodeString(raw)
	if err != nil {
		decoded, err = base64.URLEncoding.DecodeString(raw)
		if err != nil {
			return nil, err
		}
	}
	var cfg struct {
		PS   string `json:"ps"`
		Add  string `json:"add"`
		Port int    `json:"port"`
		ID   string `json:"id"`
		AID  int    `json:"aid"`
		Net  string `json:"net"`
		Type string `json:"type"`
		Host string `json:"host"`
		Path string `json:"path"`
		TLS  string `json:"tls"`
		SNI  string `json:"sni"`
	}
	if err := json.Unmarshal(decoded, &cfg); err != nil {
		return nil, err
	}
	if cfg.Net == "" {
		cfg.Net = "tcp"
	}
	name := cfg.PS
	if name == "" {
		name = fmt.Sprintf("%s:%d", cfg.Add, cfg.Port)
	}
	return &core.ProxyNode{
		Name:      name,
		Type:      core.TypeVMess,
		Server:    cfg.Add,
		Port:      cfg.Port,
		Transport: cfg.Net,
		TLS:       cfg.TLS == "tls",
		SNI:       cfg.SNI,
		UUID:      cfg.ID,
		Extra: map[string]interface{}{
			"alter_id": cfg.AID,
			"host":     cfg.Host,
			"path":     cfg.Path,
		},
	}, nil
}

func parseVLESS(uri string) (*core.ProxyNode, error) {
	raw := strings.TrimPrefix(uri, "vless://")
	parts := strings.SplitN(raw, "@", 2)
	if len(parts) != 2 {
		return nil, fmt.Errorf("invalid vless uri")
	}
	uuid := parts[0]
	rest := parts[1]

	hashIdx := strings.Index(rest, "#")
	name := ""
	if hashIdx >= 0 {
		name, _ = url.PathUnescape(rest[hashIdx+1:])
		rest = rest[:hashIdx]
	}

	qIdx := strings.Index(rest, "?")
	query := ""
	if qIdx >= 0 {
		query = rest[qIdx+1:]
		rest = rest[:qIdx]
	}

	hostPort := strings.SplitN(rest, ":", 2)
	server := hostPort[0]
	port := 443
	if len(hostPort) == 2 {
		port, _ = strconv.Atoi(hostPort[1])
	}

	params, _ := url.ParseQuery(query)
	security := params.Get("security")
	typ := params.Get("type")

	if name == "" {
		name = fmt.Sprintf("%s:%d", server, port)
	}
	return &core.ProxyNode{
		Name:      name,
		Type:      core.TypeVLESS,
		Server:    server,
		Port:      port,
		Transport: typ,
		TLS:       security == "tls" || security == "reality",
		SNI:       params.Get("sni"),
		UUID:      uuid,
		Extra: map[string]interface{}{
			"flow":     params.Get("flow"),
			"host":     params.Get("host"),
			"path":     params.Get("path"),
			"fp":       params.Get("fp"),
			"pbk":      params.Get("pbk"),
			"sid":      params.Get("sid"),
		},
	}, nil
}

func parseTrojan(uri string) (*core.ProxyNode, error) {
	raw := strings.TrimPrefix(uri, "trojan://")
	hashIdx := strings.Index(raw, "#")
	name := ""
	if hashIdx >= 0 {
		name, _ = url.PathUnescape(raw[hashIdx+1:])
		raw = raw[:hashIdx]
	}

	u, err := url.Parse("trojan://" + raw)
	if err != nil {
		return nil, err
	}
	port, _ := strconv.Atoi(u.Port())
	if port == 0 {
		port = 443
	}
	if name == "" {
		name = fmt.Sprintf("%s:%d", u.Hostname(), port)
	}
	q := u.Query()
	return &core.ProxyNode{
		Name:      name,
		Type:      core.TypeTrojan,
		Server:    u.Hostname(),
		Port:      port,
		Transport: q.Get("type"),
		TLS:       true,
		SNI:       q.Get("sni"),
		Password:  u.User.Username(),
		Extra: map[string]interface{}{
			"host": q.Get("host"),
			"path": q.Get("path"),
		},
	}, nil
}

func parseSS(uri string) (*core.ProxyNode, error) {
	raw := strings.TrimPrefix(uri, "ss://")
	hashIdx := strings.Index(raw, "#")
	name := ""
	if hashIdx >= 0 {
		name, _ = url.PathUnescape(raw[hashIdx+1:])
		raw = raw[:hashIdx]
	}

	atIdx := strings.LastIndex(raw, "@")
	if atIdx < 0 {
		// SIP002 format: base64(method:password)@server:port
		decoded, err := base64.URLEncoding.DecodeString(raw)
		if err != nil {
			decoded, err = base64.StdEncoding.DecodeString(raw)
			if err != nil {
				return nil, err
			}
		}
		parts := strings.SplitN(string(decoded), "@", 2)
		if len(parts) != 2 {
			return nil, fmt.Errorf("invalid ss uri")
		}
		method := strings.SplitN(parts[0], ":", 2)
		hostPort := strings.SplitN(parts[1], ":", 2)
		port, _ := strconv.Atoi(strings.Split(hostPort[1], "#")[0])
		if name == "" {
			name = fmt.Sprintf("%s:%s", hostPort[0], strconv.Itoa(port))
		}
		password := method[1]
		if len(method) > 1 {
			password = method[1]
		}
		return &core.ProxyNode{
			Name:   name,
			Type:   core.TypeSS,
			Server: hostPort[0],
			Port:   port,
			TLS:    false,
			Extra: map[string]interface{}{
				"cipher":   method[0],
				"password": password,
			},
		}, nil
	}

	userInfo := raw[:atIdx]
	hostInfo := raw[atIdx+1:]
	decoded, err := base64.URLEncoding.DecodeString(userInfo)
	if err != nil {
		decoded, err = base64.StdEncoding.DecodeString(userInfo)
		if err != nil {
			return nil, err
		}
	}
	methodPass := strings.SplitN(string(decoded), ":", 2)
	hostPort := strings.SplitN(hostInfo, ":", 2)
	port, _ := strconv.Atoi(strings.Split(hostPort[1], "#")[0])

	if name == "" {
		name = fmt.Sprintf("%s:%s", hostPort[0], strconv.Itoa(port))
	}
	return &core.ProxyNode{
		Name:   name,
		Type:   core.TypeSS,
		Server: hostPort[0],
		Port:   port,
		Extra: map[string]interface{}{
			"cipher":   methodPass[0],
			"password": methodPass[1],
		},
	}, nil
}

func parseSSR(uri string) (*core.ProxyNode, error) {
	raw := strings.TrimPrefix(uri, "ssr://")
	decoded, err := base64.URLEncoding.DecodeString(raw)
	if err != nil {
		decoded, err = base64.StdEncoding.DecodeString(raw)
		if err != nil {
			return nil, err
		}
	}
	s := string(decoded)
	parts := strings.Split(s, ":")
	if len(parts) < 6 {
		return nil, fmt.Errorf("invalid ssr uri")
	}
	port, _ := strconv.Atoi(parts[1])
	name := fmt.Sprintf("%s:%s", parts[0], parts[1])
	return &core.ProxyNode{
		Name:   name,
		Type:   core.TypeSSR,
		Server: parts[0],
		Port:   port,
		Extra: map[string]interface{}{
			"protocol":     parts[2],
			"method":       parts[3],
			"obfs":         parts[4],
			"password_raw": parts[5],
		},
	}, nil
}

func parseHysteria2(uri string) (*core.ProxyNode, error) {
	raw := strings.TrimPrefix(uri, "hy2://")
	hashIdx := strings.Index(raw, "#")
	name := ""
	if hashIdx >= 0 {
		name, _ = url.PathUnescape(raw[hashIdx+1:])
		raw = raw[:hashIdx]
	}

	u, err := url.Parse("hy2://" + raw)
	if err != nil {
		return nil, err
	}
	port, _ := strconv.Atoi(u.Port())
	if port == 0 {
		port = 443
	}
	if name == "" {
		name = fmt.Sprintf("%s:%d", u.Hostname(), port)
	}
	q := u.Query()
	password := ""
	if u.User != nil {
		password = u.User.Username()
	}
	return &core.ProxyNode{
		Name:   name,
		Type:   core.TypeHysteria2,
		Server: u.Hostname(),
		Port:   port,
		TLS:    true,
		SNI:    q.Get("sni"),
		Password: password,
		Extra: map[string]interface{}{
			"obfs":     q.Get("obfs"),
			"obfs_pwd": q.Get("obfs-password"),
		},
	}, nil
}
