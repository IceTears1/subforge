package core

// ProxyNode is the unified internal representation for all proxy protocols.
type ProxyNode struct {
	Name      string                 `json:"name"`
	Type      string                 `json:"type"`      // vmess|vless|trojan|ss|ssr|hysteria2|tuic
	Server    string                 `json:"server"`
	Port      int                    `json:"port"`
	Transport string                 `json:"transport"`  // tcp|ws|grpc|h2|quic|httpupgrade
	TLS       bool                   `json:"tls"`
	SNI       string                 `json:"sni,omitempty"`
	UUID      string                 `json:"uuid,omitempty"`
	Password  string                 `json:"password,omitempty"`
	Extra     map[string]interface{} `json:"extra,omitempty"`
}

// Region constants
const (
	RegionHK = "HK"
	RegionJP = "JP"
	RegionSG = "SG"
	RegionUS = "US"
	RegionTW = "TW"
	RegionKR = "KR"
	RegionUK = "UK"
	RegionDE = "DE"
	RegionFR = "FR"
	RegionAU = "AU"
	RegionUnknown = "OTHER"
)

// Protocol types
const (
	TypeVMess      = "vmess"
	TypeVLESS      = "vless"
	TypeTrojan     = "trojan"
	TypeSS         = "ss"
	TypeSSR        = "ssr"
	TypeHysteria2  = "hysteria2"
	TypeTUIC       = "tuic"
)

// Output formats
const (
	FormatClash    = "clash"
	FormatSingBox  = "singbox"
	FormatSurge    = "surge"
	FormatLoon     = "loon"
	FormatQX       = "quanx"
	FormatBase64   = "base64"
)

// RegionEmoji maps region codes to flag emojis.
var RegionEmoji = map[string]string{
	RegionHK: "🇭🇰", RegionJP: "🇯🇵", RegionSG: "🇸🇬",
	RegionUS: "🇺🇸", RegionTW: "🇨🇳", RegionKR: "🇰🇷",
	RegionUK: "🇬🇧", RegionDE: "🇩🇪", RegionFR: "🇫🇷",
	RegionAU: "🇦🇺", RegionUnknown: "🌐",
}
