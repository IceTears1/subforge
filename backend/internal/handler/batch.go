package handler

import (
	"subforge/internal/pkg/response"
	"subforge/internal/service"

	"github.com/gin-gonic/gin"
)

type BatchHandler struct {
	subSvc *service.SubscriptionService
}

func NewBatchHandler(subSvc *service.SubscriptionService) *BatchHandler {
	return &BatchHandler{subSvc: subSvc}
}

// BatchDelete deletes multiple subscriptions.
func (h *BatchHandler) BatchDelete(c *gin.Context) {
	userID := getUserID(c)
	var req struct {
		IDs []uint `json:"ids" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}

	deleted := 0
	for _, id := range req.IDs {
		if err := h.subSvc.Delete(id, userID); err == nil {
			deleted++
		}
	}

	response.OK(c, gin.H{"deleted": deleted})
}

// BatchRefresh refreshes multiple subscriptions.
func (h *BatchHandler) BatchRefresh(c *gin.Context) {
	userID := getUserID(c)
	var req struct {
		IDs []uint `json:"ids" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}

	refreshed := 0
	for _, id := range req.IDs {
		if err := h.subSvc.Refresh(id, userID); err == nil {
			refreshed++
		}
	}

	response.OK(c, gin.H{"refreshed": refreshed})
}
