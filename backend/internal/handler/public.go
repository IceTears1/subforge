package handler

import (
	"subforge/internal/service"

	"github.com/gin-gonic/gin"
)

type PublicHandler struct {
	subSvc *service.SubscriptionService
}

func NewPublicHandler(subSvc *service.SubscriptionService) *PublicHandler {
	return &PublicHandler{subSvc: subSvc}
}

// GetSub serves a rendered subscription by token.
// GET /sub/:token?target=clash
func (h *PublicHandler) GetSub(c *gin.Context) {
	token := c.Param("token")
	target := c.DefaultQuery("target", "clash")

	content, err := h.subSvc.GetNodesByToken(token, target)
	if err != nil {
		c.String(404, "subscription not found")
		return
	}

	c.Header("Content-Type", "text/plain; charset=utf-8")
	c.Header("Cache-Control", "max-age=300")
	c.String(200, content)
}

// GetMergedSub serves all subscriptions merged by token.
// GET /sub/:token/merged?target=clash
func (h *PublicHandler) GetMergedSub(c *gin.Context) {
	token := c.Param("token")
	target := c.DefaultQuery("target", "clash")

	content, err := h.subSvc.MergedByToken(token, target)
	if err != nil {
		c.String(404, "subscription not found")
		return
	}

	c.Header("Content-Type", "text/plain; charset=utf-8")
	c.Header("Cache-Control", "max-age=300")
	c.String(200, content)
}
