package handler

import (
	"strings"

	"subforge/internal/pkg/response"
	"subforge/internal/service"

	"github.com/gin-gonic/gin"
)

func AuthMiddleware(authSvc *service.AuthService) gin.HandlerFunc {
	return func(c *gin.Context) {
		auth := c.GetHeader("Authorization")
		if auth == "" {
			response.Unauthorized(c)
			c.Abort()
			return
		}
		token := strings.TrimPrefix(auth, "Bearer ")

		// Check blacklist
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
