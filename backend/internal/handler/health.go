package handler

import (
	"strconv"
	"subforge/internal/pkg/response"
	"subforge/internal/service"

	"github.com/gin-gonic/gin"
)

type HealthHandler struct {
	svc *service.HealthService
}

func NewHealthHandler(svc *service.HealthService) *HealthHandler {
	return &HealthHandler{svc: svc}
}

// CheckSubscription tests all nodes of a subscription.
func (h *HealthHandler) CheckSubscription(c *gin.Context) {
	id, _ := strconv.ParseUint(c.Param("id"), 10, 32)
	userID := getUserID(c)

	results, err := h.svc.CheckSubscription(uint(id), userID)
	if err != nil {
		response.InternalError(c, err.Error())
		return
	}

	online := 0
	for _, r := range results {
		if r.Status == "online" {
			online++
		}
	}

	response.OK(c, gin.H{
		"total":   len(results),
		"online":  online,
		"offline": len(results) - online,
		"results": results,
	})
}
