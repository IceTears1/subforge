package handler

import (
	"fmt"
	"subforge/internal/pkg/response"
	"subforge/internal/service"

	"github.com/gin-gonic/gin"
)

type WebhookHandler struct {
	svc *service.WebhookService
}

func NewWebhookHandler(svc *service.WebhookService) *WebhookHandler {
	return &WebhookHandler{svc: svc}
}

func (h *WebhookHandler) List(c *gin.Context) {
	userID := getUserID(c)
	configs, err := h.svc.List(userID)
	if err != nil {
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, configs)
}

func (h *WebhookHandler) Create(c *gin.Context) {
	userID := getUserID(c)
	var req struct {
		URL    string `json:"url" binding:"required,url"`
		Events string `json:"events" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request: "+err.Error())
		return
	}
	cfg, err := h.svc.Create(userID, req.URL, req.Events)
	if err != nil {
		response.InternalError(c, err.Error())
		return
	}
	response.Created(c, cfg)
}

func (h *WebhookHandler) Delete(c *gin.Context) {
	userID := getUserID(c)
	id := c.Param("id")
	var idUint uint
	if _, err := fmt.Sscanf(id, "%d", &idUint); err != nil {
		response.BadRequest(c, "invalid id")
		return
	}
	if err := h.svc.Delete(idUint, userID); err != nil {
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, nil)
}
