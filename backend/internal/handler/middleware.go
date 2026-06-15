package handler

import (
	"strings"

	"subforge/internal/pkg/response"
	"subforge/internal/service"

	"github.com/gin-gonic/gin"
)

func AuthMiddleware(authSvc *service.AuthService, apiKeySvc *service.APIKeyService) gin.HandlerFunc {
	return func(c *gin.Context) {
		auth := c.GetHeader("Authorization")
		if auth == "" {
			response.Unauthorized(c)
			c.Abort()
			return
		}

		token := strings.TrimPrefix(auth, "Bearer ")

		// Try API key first (starts with sf_)
		if strings.HasPrefix(token, "sf_") {
			apiKey, err := apiKeySvc.Validate(token)
			if err != nil {
				response.Unauthorized(c)
				c.Abort()
				return
			}
			c.Set("user_id", apiKey.UserID)
			c.Set("role", "user") // API keys are user-level
			c.Set("api_key_id", apiKey.ID)
			c.Next()
			return
		}

		// JWT token
		if service.TokenBlacklistInstance.IsRevoked(token) {
			response.Unauthorized(c)
			c.Abort()
			return
		}

		claims, err := authSvc.ValidateToken(token)
		if err != nil {
			response.Unauthorized(c)
			c.Abort()
			return
		}
		c.Set("user_id", claims.UserID)
		c.Set("role", claims.Role)
		c.Set("token", token)
		c.Next()
	}
}

func AdminRequired() gin.HandlerFunc {
	return func(c *gin.Context) {
		role, _ := c.Get("role")
		if role != "admin" {
			response.Forbidden(c)
			c.Abort()
			return
		}
		c.Next()
	}
}

func getUserID(c *gin.Context) uint {
	id, _ := c.Get("user_id")
	return id.(uint)
}
