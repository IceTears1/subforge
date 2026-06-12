package smart

import (
	"fmt"
	"subforge/internal/core"
)

// Deduplicate removes duplicate nodes by server+port+type.
func Deduplicate(nodes []core.ProxyNode) []core.ProxyNode {
	seen := make(map[string]bool)
	var result []core.ProxyNode
	for _, n := range nodes {
		key := fmt.Sprintf("%s:%d:%s", n.Server, n.Port, n.Type)
		if !seen[key] {
			seen[key] = true
			result = append(result, n)
		}
	}
	return result
}
