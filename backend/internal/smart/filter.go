package smart

import (
	"regexp"
	"strings"
	"subforge/internal/core"
)

// FilterByRegion keeps only nodes matching the given regions.
func FilterByRegion(nodes []core.ProxyNode, regions []string) []core.ProxyNode {
	if len(regions) == 0 {
		return nodes
	}
	regionSet := make(map[string]bool)
	for _, r := range regions {
		regionSet[strings.ToUpper(r)] = true
	}
	var result []core.ProxyNode
	for _, n := range nodes {
		region, _ := n.Extra["region"].(string)
		if regionSet[region] {
			result = append(result, n)
		}
	}
	return result
}

// FilterByKeyword removes nodes whose name matches any exclude pattern.
func FilterByKeyword(nodes []core.ProxyNode, excludePatterns []string) []core.ProxyNode {
	if len(excludePatterns) == 0 {
		return nodes
	}
	var patterns []*regexp.Pattern
	for _, p := range excludePatterns {
		if re, err := regexp.Compile(p); err == nil {
			patterns = append(patterns, re)
		}
	}
	var result []core.ProxyNode
	for _, n := range nodes {
		excluded := false
		for _, re := range patterns {
			if re.MatchString(n.Name) {
				excluded = true
				break
			}
		}
		if !excluded {
			result = append(result, n)
		}
	}
	return result
}
