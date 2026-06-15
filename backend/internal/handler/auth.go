package handler

import (
	"strings"
	"time"

	"subforge/internal/pkg/response"
	"subforge/internal/service"

	"github.com/gin-gonic/gin"
)

type AuthHandler struct {
	svc   *service.AuthService
	audit *service.AuditService
}

func NewAuthHandler(svc *service.AuthService, audit *service.AuditService) *AuthHandler {
	return &AuthHandler{svc: svc, audit: audit}
}

func (h *AuthHandler) Login(c *gin.Context) {
	var req service.LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}

	ip := c.ClientIP()
	result, err := h.svc.Login(req)
	if err != nil {
		h.audit.Log(0, req.Username, "login", "auth", "login failed", ip, false)
		response.Error(c, 401, err.Error())
		return
	}

	h.audit.Log(result.User.ID, result.User.Username, "login", "auth", "login success", ip, true)
	response.OK(c, result)
}

// Logout revokes the current token.
func (h *AuthHandler) Logout(c *gin.Context) {
	token := c.GetString("token")
	if token != "" {
		// Revoke token (add to blacklist with 24h expiry)
		service.TokenBlacklistInstance.Revoke(token, time.Now().Add(24*time.Hour))
	}

	userID := getUserID(c)
	ip := c.ClientIP()
	h.audit.Log(userID, "", "logout", "auth", "logout", ip, true)

	response.OK(c, gin.H{"message": "logged out"})
}
