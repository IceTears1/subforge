package handler

import (
	"io"
	"subforge/internal/pkg/response"
	"subforge/internal/service"

	"github.com/gin-gonic/gin"
)

type BackupHandler struct {
	svc   *service.BackupService
	audit *service.AuditService
}

func NewBackupHandler(svc *service.BackupService, audit *service.AuditService) *BackupHandler {
	return &BackupHandler{svc: svc, audit: audit}
}

// CreateBackup creates a new backup.
func (h *BackupHandler) CreateBackup(c *gin.Context) {
	userID := getUserID(c)
	ip := c.ClientIP()

	info, err := h.svc.CreateBackup()
	if err != nil {
		h.audit.Log(userID, "", "backup", "system", "backup failed: "+err.Error(), ip, false)
		response.InternalError(c, err.Error())
		return
	}

	h.audit.Log(userID, "", "backup", "system", "backup created: "+info.Name, ip, true)
	response.OK(c, info)
}

// ListBackups returns all available backups.
func (h *BackupHandler) ListBackups(c *gin.Context) {
	backups, err := h.svc.ListBackups()
	if err != nil {
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, backups)
}

// RestoreBackup restores from a backup.
func (h *BackupHandler) RestoreBackup(c *gin.Context) {
	userID := getUserID(c)
	ip := c.ClientIP()

	var req struct {
		BackupID string `json:"backup_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}

	if err := h.svc.RestoreBackup(req.BackupID); err != nil {
		h.audit.Log(userID, "", "restore", "system", "restore failed: "+err.Error(), ip, false)
		response.InternalError(c, err.Error())
		return
	}

	h.audit.Log(userID, "", "restore", "system", "restored: "+req.BackupID, ip, true)
	response.OK(c, gin.H{"message": "restore successful"})
}

// DeleteBackup deletes a backup.
func (h *BackupHandler) DeleteBackup(c *gin.Context) {
	userID := getUserID(c)
	ip := c.ClientIP()

	backupID := c.Param("id")
	if err := h.svc.DeleteBackup(backupID); err != nil {
		response.InternalError(c, err.Error())
		return
	}

	h.audit.Log(userID, "", "delete_backup", "system", "deleted backup: "+backupID, ip, true)
	response.OK(c, nil)
}

// ExportBackup exports a backup as downloadable file.
func (h *BackupHandler) ExportBackup(c *gin.Context) {
	backupID := c.Param("id")
	data, err := h.svc.ExportBackup(backupID)
	if err != nil {
		response.InternalError(c, err.Error())
		return
	}

	c.Header("Content-Disposition", "attachment; filename=subforge-backup-"+backupID+".json")
	c.Header("Content-Type", "application/json")
	c.Data(200, "application/json", data)
}

// ImportBackup imports a backup from uploaded file.
func (h *BackupHandler) ImportBackup(c *gin.Context) {
	userID := getUserID(c)
	ip := c.ClientIP()

	body, err := io.ReadAll(c.Request.Body)
	if err != nil {
		response.BadRequest(c, "failed to read body")
		return
	}

	if err := h.svc.ImportBackup(body); err != nil {
		h.audit.Log(userID, "", "import_backup", "system", "import failed: "+err.Error(), ip, false)
		response.InternalError(c, err.Error())
		return
	}

	h.audit.Log(userID, "", "import_backup", "system", "backup imported", ip, true)
	response.OK(c, gin.H{"message": "import successful"})
}
