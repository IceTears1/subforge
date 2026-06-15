package handler

import (
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

	data := gin.H{
		"current":     info.Current,
		"current_tag": info.CurrentTag,
		"latest":      info.Latest,
		"latest_tag":  info.LatestTag,
		"has_update":  info.HasUpdate,
		"changelog":   info.Changelog,
		"last_check":  info.LastCheck,
		"update_mode": info.UpdateMode,
		"updating":    h.svc.IsUpdating(),
	}

	if lastResult := h.svc.GetLastResult(); lastResult != nil {
		data["last_update"] = lastResult
	}

	response.OK(c, data)
}

// GetReleases returns all available releases.
func (h *UpdateHandler) GetReleases(c *gin.Context) {
	releases, err := h.svc.GetReleases()
	if err != nil {
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, releases)
}

// GetChangelog returns commits between versions.
func (h *UpdateHandler) GetChangelog(c *gin.Context) {
	from := c.Query("from")
	to := c.Query("to")
	entries, err := h.svc.GetChangelog(from, to, 20)
	if err != nil {
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, entries)
}

// UpdateToLatest updates to the latest version.
func (h *UpdateHandler) UpdateToLatest(c *gin.Context) {
	userID := getUserID(c)
	ip := c.ClientIP()

	if h.svc.IsUpdating() {
		response.BadRequest(c, "update already in progress")
		return
	}

	result, err := h.svc.UpdateToLatest()
	if err != nil {
		h.audit.Log(userID, "", "update", "system", "update failed: "+err.Error(), ip, false)
		response.InternalError(c, err.Error())
		return
	}

	h.audit.Log(userID, "", "update", "system", "updated: "+result.From+" → "+result.To, ip, true)
	response.OK(c, result)
}

// UpdateToTag updates to a specific tag.
func (h *UpdateHandler) UpdateToTag(c *gin.Context) {
	userID := getUserID(c)
	ip := c.ClientIP()

	var req struct {
		Tag string `json:"tag" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}

	if h.svc.IsUpdating() {
		response.BadRequest(c, "update already in progress")
		return
	}

	result, err := h.svc.UpdateToTag(req.Tag)
	if err != nil {
		h.audit.Log(userID, "", "update", "system", "update to "+req.Tag+" failed: "+err.Error(), ip, false)
		response.InternalError(c, err.Error())
		return
	}

	h.audit.Log(userID, "", "update", "system", "updated to "+req.Tag+": "+result.From+" → "+result.To, ip, true)
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
		response.InternalError(c, err.Error())
		return
	}

	h.audit.Log(userID, "", "rollback", "system", "rolled back: "+result.From+" → "+result.To, ip, true)
	response.OK(c, result)
}
