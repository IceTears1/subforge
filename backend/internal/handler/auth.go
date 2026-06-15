package handler

import (
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
