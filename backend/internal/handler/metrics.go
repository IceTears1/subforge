package handler

import (
	"runtime"
	"time"

	"subforge/internal/model"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type MetricsHandler struct {
	db      *gorm.DB
	startAt time.Time
}

func NewMetricsHandler(db *gorm.DB) *MetricsHandler {
	return &MetricsHandler{db: db, startAt: time.Now()}
}

// GetMetrics returns system metrics.
func (h *MetricsHandler) GetMetrics(c *gin.Context) {
	var userCount, subCount, nodeCount int64
	h.db.Model(&model.User{}).Count(&userCount)
	h.db.Model(&model.Subscription{}).Count(&subCount)
	h.db.Model(&model.Node{}).Count(&nodeCount)

	var mem runtime.MemStats
	runtime.ReadMemStats(&mem)

	c.JSON(200, gin.H{
		"uptime_seconds": int(time.Since(h.startAt).Seconds()),
		"database": gin.H{
			"users":         userCount,
			"subscriptions": subCount,
			"nodes":         nodeCount,
		},
		"memory": gin.H{
			"alloc_mb":      bToMb(mem.Alloc),
			"total_alloc_mb": bToMb(mem.TotalAlloc),
			"sys_mb":        bToMb(mem.Sys),
			"gc_cycles":     mem.NumGC,
		},
		"goroutines": runtime.NumGoroutine(),
		"go_version": runtime.Version(),
	})
}

func bToMb(b uint64) uint64 {
	return b / 1024 / 1024
}
