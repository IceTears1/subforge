package handler

import (
	"subforge/internal/pkg/response"
	"subforge/internal/service"

	"github.com/gin-gonic/gin"
)

type SchedulerHandler struct {
	svc *service.Scheduler
}

func NewSchedulerHandler(svc *service.Scheduler) *SchedulerHandler {
	return &SchedulerHandler{svc: svc}
}

// GetStats returns scheduler statistics.
func (h *SchedulerHandler) GetStats(c *gin.Context) {
	stats := h.svc.GetStats()
	response.OK(c, gin.H{
		"running": h.svc.IsRunning(),
		"stats":   stats,
	})
}

// ForceRefresh forces a refresh of all subscriptions.
func (h *SchedulerHandler) ForceRefresh(c *gin.Context) {
	stats := h.svc.ForceRefresh()
	response.OK(c, stats)
}
