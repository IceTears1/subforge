package handler

import (
	"encoding/json"
	"io"
	"subforge/internal/model"
	"subforge/internal/pkg/response"
	"subforge/internal/service"

	"github.com/gin-gonic/gin"
)

type ExportHandler struct {
	subSvc *service.SubscriptionService
}

func NewExportHandler(subSvc *service.SubscriptionService) *ExportHandler {
	return &ExportHandler{subSvc: subSvc}
}

// Export exports all subscriptions as JSON.
func (h *ExportHandler) Export(c *gin.Context) {
	userID := getUserID(c)
	subs, err := h.subSvc.List(userID)
	if err != nil {
		response.InternalError(c, err.Error())
		return
	}

	// Strip sensitive fields
	type ExportSub struct {
		Name        string   `json:"name"`
		URL         string   `json:"url"`
		AutoRefresh int      `json:"auto_refresh"`
		Tags        []string `json:"tags"`
	}

	var exported []ExportSub
	for _, s := range subs {
		var tags []string
		json.Unmarshal(s.Tags, &tags)
		exported = append(exported, ExportSub{
			Name:        s.Name,
			URL:         s.URL,
			AutoRefresh: s.AutoRefresh,
			Tags:        tags,
		})
	}

	c.Header("Content-Disposition", "attachment; filename=subforge-export.json")
	c.Header("Content-Type", "application/json")
	c.JSON(200, exported)
}

// Import imports subscriptions from JSON.
func (h *ExportHandler) Import(c *gin.Context) {
	userID := getUserID(c)

	body, err := io.ReadAll(c.Request.Body)
	if err != nil {
		response.BadRequest(c, "failed to read body")
		return
	}

	type ImportSub struct {
		Name        string   `json:"name"`
		URL         string   `json:"url"`
		AutoRefresh int      `json:"auto_refresh"`
		Tags        []string `json:"tags"`
	}

	var items []ImportSub
	if err := json.Unmarshal(body, &items); err != nil {
		response.BadRequest(c, "invalid JSON format")
		return
	}

	if len(items) > 50 {
		response.BadRequest(c, "max 50 subscriptions per import")
		return
	}

	imported := 0
	for _, item := range items {
		if item.Name == "" || item.URL == "" {
			continue
		}
		_, err := h.subSvc.Create(userID, service.CreateSubRequest{
			Name:        item.Name,
			URL:         item.URL,
			AutoRefresh: item.AutoRefresh,
			Tags:        item.Tags,
		})
		if err == nil {
			imported++
		}
	}

	response.OK(c, gin.H{
		"imported": imported,
		"total":    len(items),
	})
}
