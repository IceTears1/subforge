package service

import (
	"log"
	"time"

	"gorm.io/gorm"
)

// AuditLog represents a security event.
type AuditLog struct {
	ID        uint      `json:"id" gorm:"primaryKey"`
	UserID    uint      `json:"user_id" gorm:"index"`
	Username  string    `json:"username" gorm:"size:64"`
	Action    string    `json:"action" gorm:"size:32;index"` // login|logout|create|delete|refresh|export
	Resource  string    `json:"resource" gorm:"size:64"`     // subscription|user|webhook
	Detail    string    `json:"detail" gorm:"size:256"`
	IP        string    `json:"ip" gorm:"size:45"`
	Success   bool      `json:"success"`
	CreatedAt time.Time `json:"created_at"`
}

// AuditService handles audit logging.
type AuditService struct {
	db *gorm.DB
}

func NewAuditService(db *gorm.DB) *AuditService {
	return &AuditService{db: db}
}

// Log records an audit event.
func (s *AuditService) Log(userID uint, username, action, resource, detail, ip string, success bool) {
	entry := AuditLog{
		UserID:   userID,
		Username: username,
		Action:   action,
		Resource: resource,
		Detail:   detail,
		IP:       ip,
		Success:  success,
	}

	if err := s.db.Create(&entry).Error; err != nil {
		log.Printf("Audit log failed: %v", err)
	}
}

// List returns audit logs with pagination.
func (s *AuditService) List(page, pageSize int, action string) ([]AuditLog, int64, error) {
	var logs []AuditLog
	var total int64
	q := s.db.Model(&AuditLog{})
	if action != "" {
		q = q.Where("action = ?", action)
	}
	q.Count(&total)
	err := q.Order("id DESC").
		Offset((page - 1) * pageSize).
		Limit(pageSize).
		Find(&logs).Error
	return logs, total, err
}

// Migrate creates the audit_logs table.
func (s *AuditService) Migrate() error {
	return s.db.AutoMigrate(&AuditLog{})
}
