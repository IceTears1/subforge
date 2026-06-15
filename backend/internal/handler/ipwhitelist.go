package handler

import (
	"strings"
	"subforge/internal/config"
	"subforge/internal/pkg/response"

	"github.com/gin-gonic/gin"
)

// IPWhitelistMiddleware restricts admin access to whitelisted IPs.
func IPWhitelistMiddleware(cfg *config.Config) gin.HandlerFunc {
	return func(c *gin.Context) {
		// Skip if no whitelist configured
		if cfg.AdminIPWhitelist == "" {
			c.Next()
			return
		}

		// Only apply to admin endpoints
		if !strings.HasPrefix(c.Request.URL.Path, "/api/users") &&
			!strings.HasPrefix(c.Request.URL.Path, "/api/audit") {
			c.Next()
			return
		}

		clientIP := c.ClientIP()
		allowed := false
		for _, ip := range strings.Split(cfg.AdminIPWhitelist, ",") {
			ip = strings.TrimSpace(ip)
			if ip == clientIP || ip == "*" {
				allowed = true
				break
			}
		}

		if !allowed {
			response.Forbidden(c)
			c.Abort()
			return
		}

		c.Next()
	}
}
