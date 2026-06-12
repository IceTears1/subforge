package httputil

import (
	"fmt"
	"net"
	"net/http"
	"net/url"
	"time"
)

// SafeGet performs an SSRF-safe HTTP GET. It blocks requests to private,
// link-local, loopback IPs and localhost aliases.
func SafeGet(rawURL string, timeout time.Duration) (*http.Response, error) {
	if err := ValidateURL(rawURL); err != nil {
		return nil, err
	}
	client := &http.Client{Timeout: timeout}
	return client.Get(rawURL)
}

// ValidateURL checks if a URL is safe from SSRF attacks.
func ValidateURL(rawURL string) error {
	u, err := url.Parse(rawURL)
	if err != nil {
		return fmt.Errorf("invalid url: %w", err)
	}

	// Only allow http/https
	scheme := u.Scheme
	if scheme != "http" && scheme != "https" {
		return fmt.Errorf("unsupported scheme: %s", scheme)
	}

	host := u.Hostname()
	if host == "" {
		return fmt.Errorf("empty host")
	}

	// Block localhost aliases
	blocked := []string{
		"localhost", "127.0.0.1", "::1", "0.0.0.0",
		"169.254.169.254", // AWS metadata
		"metadata.google.internal", // GCP metadata
	}
	for _, b := range blocked {
		if host == b {
			return fmt.Errorf("blocked host: %s", host)
		}
	}

	// Resolve and check IP
	ips, err := net.LookupIP(host)
	if err != nil {
		return fmt.Errorf("dns lookup failed: %w", err)
	}
	for _, ip := range ips {
		if isPrivateIP(ip) {
			return fmt.Errorf("blocked private ip: %s (%s)", ip, host)
		}
	}

	return nil
}

func isPrivateIP(ip net.IP) bool {
	// Loopback
	if ip.IsLoopback() {
		return true
	}
	// Private ranges (RFC 1918)
	privateCIDRs := []string{
		"10.0.0.0/8",
		"172.16.0.0/12",
		"192.168.0.0/16",
		"169.254.0.0/16", // link-local
		"fc00::/7",       // IPv6 private
		"::1/128",        // IPv6 loopback
	}
	for _, cidr := range privateCIDRs {
		_, block, _ := net.ParseCIDR(cidr)
		if block != nil && block.Contains(ip) {
			return true
		}
	}
	return false
}
