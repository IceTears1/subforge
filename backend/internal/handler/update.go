package handler

import (
	"strconv"
	"subforge/internal/pkg/response"
	"subforge/internal/service"

	"github.com/gin-gonic/gin"
)

type UpdateHandler struct {
	svc   *service.UpdateService
	audit *service.AuditService
}

func NewUpdateHandler(svc *service.UpdateService, audit *service.AuditService) *UpdateHandler {
	return &UpdateHandler{svc: svc, audit: audit}
}

// GetVersion returns current and latest version info.
func (h *UpdateHandler) GetVersion(c *gin.Context) {
	info, err := h.svc.GetVersion()
	if err != nil {
		response.InternalError(c, err.Error())
		return
	}

	// Add update status
	data := gin.H{
		"current":    info.Current,
		"latest":     info.Latest,
		"has_update": info.HasUpdate,
		"changelog":  info.Changelog,
		"last_check": info.LastCheck,
		"updating":   h.svc.IsUpdating(),
	}

	// Add last result if available
	if lastResult := h.svc.GetLastResult(); lastResult != nil {
		data["last_update"] = lastResult
	}

	response.OK(c, data)
}

// GetChangelog returns recent commits.
func (h *UpdateHandler) GetChangelog(c *gin.Context) {
	count, _ := strconv.Atoi(c.DefaultQuery("count", "20"))
	versions, err := h.svc.GetChangelog(count)
	if err != nil {
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, versions)
}

// Update performs the update.
func (h *UpdateHandler) Update(c *gin.Context) {
	userID := getUserID(c)
	ip := c.ClientIP()

	if h.svc.IsUpdating() {
		response.BadRequest(c, "update already in progress")
		return
	}

	result, err := h.svc.Update()
	if err != nil {
		h.audit.Log(userID, "", "update", "system", "update failed: "+err.Error(), ip, false)
		response.InternalError(c, "update failed: "+err.Error())
		return
	}

	h.audit.Log(userID, "", "update", "system", "updated: "+result.From+" → "+result.To, ip, true)
	response.OK(c, result)
}

// GetUpdateStatus returns current update status.
func (h *UpdateHandler) GetUpdateStatus(c *gin.Context) {
	response.OK(c, gin.H{
		"updating":    h.svc.IsUpdating(),
		"last_result": h.svc.GetLastResult(),
	})
}

// Rollback rolls back to a specific version.
func (h *UpdateHandler) Rollback(c *gin.Context) {
	userID := getUserID(c)
	ip := c.ClientIP()

	var req struct {
		Version string `json:"version" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}

	result, err := h.svc.Rollback(req.Version)
	if err != nil {
		h.audit.Log(userID, "", "rollback", "system", "rollback failed: "+err.Error(), ip, false)
		response.InternalError(c, "rollback failed: "+err.Error())
		return
	}

	h.audit.Log(userID, "", "rollback", "system", "rolled back: "+result.From+" → "+result.To, ip, true)
	response.OK(c, result)
}
