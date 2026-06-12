package smart

import (
	"fmt"
	"net"
	"regexp"
	"strings"
	"subforge/internal/core"
)

// Region patterns from node names and domains
var regionPatterns = []struct {
	Region  string
	Pattern string
}{
	{core.RegionHK, `(?i)(香港|HK|Hong\s*Kong)`},
	{core.RegionJP, `(?i)(日本|JP|Japan|Tokyo)`},
	{core.RegionSG, `(?i)(新加坡|SG|Singapore)`},
	{core.RegionUS, `(?i)(美国|US|United\s*States|Los\s*Angeles|San\s*Jose|Silicon)`},
	{core.RegionTW, `(?i)(台湾|TW|Taiwan)`},
	{core.RegionKR, `(?i)(韩国|KR|Korea|Seoul)`},
	{core.RegionUK, `(?i)(英国|UK|United\s*Kingdom|London)`},
	{core.RegionDE, `(?i)(德国|DE|Germany|Frankfurt)`},
	{core.RegionFR, `(?i)(法国|FR|France|Paris)`},
	{core.RegionAU, `(?i)(澳洲|AU|Australia|Sydney)`},
}

// TLD to region mapping
var tldRegion = map[string]string{
	"hk": core.RegionHK, "jp": core.RegionJP, "sg": core.RegionSG,
	"us": core.RegionUS, "tw": core.RegionTW, "kr": core.RegionKR,
	"uk": core.RegionUK, "de": core.RegionDE, "fr": core.RegionFR,
	"au": core.RegionAU,
}

// RenameByRegion renames nodes with emoji + region + index.
func RenameByRegion(nodes []core.ProxyNode) []core.ProxyNode {
	counters := make(map[string]int)
	for i := range nodes {
		region := detectRegion(nodes[i].Server, nodes[i].Name)
		nodes[i].Extra["region"] = region
		counters[region]++
		idx := counters[region]
		emoji := core.RegionEmoji[region]
		nodes[i].Name = fmt.Sprintf("%s %s %02d | %s",
			emoji, region, idx, strings.ToUpper(nodes[i].Type))
	}
	return nodes
}

// DetectRegion detects the region from server domain and node name.
func detectRegion(server, name string) string {
	// Try name first
	for _, rp := range regionPatterns {
		if matched, _ := regexp.MatchString(rp.Pattern, name); matched {
			return rp.Region
		}
	}

	// Try TLD
	host := server
	if ip := net.ParseIP(server); ip != nil {
		return core.RegionUnknown
	}
	parts := strings.Split(host, ".")
	if len(parts) >= 2 {
		tld := strings.ToLower(parts[len(parts)-1])
		if region, ok := tldRegion[tld]; ok {
			return region
		}
	}

	return core.RegionUnknown
}
