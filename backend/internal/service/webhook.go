package service

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"

	"subforge/internal/model"

	"gorm.io/gorm"
)

// WebhookService handles sending webhook notifications.
type WebhookService struct {
	db *gorm.DB
}

func NewWebhookService(db *gorm.DB) *WebhookService {
	return &WebhookService{db: db}
}

type WebhookConfig struct {
	ID     uint   `json:"id" gorm:"primaryKey"`
	UserID uint   `json:"user_id" gorm:"index"`
	URL    string `json:"url" gorm:"not null"`
	Secret string `json:"secret,omitempty"`
	Events string `json:"events" gorm:"default:'refresh,fail'"` // comma-separated
	Status int8   `json:"status" gorm:"default:1"`
}

type WebhookPayload struct {
	Event     string      `json:"event"`
	Timestamp int64       `json:"timestamp"`
	SubID     uint        `json:"sub_id"`
	SubName   string      `json:"sub_name"`
	NodeCount int         `json:"node_count,omitempty"`
	Error     string      `json:"error,omitempty"`
	Data      interface{} `json:"data,omitempty"`
}

func (s *WebhookService) Notify(userID uint, event string, payload WebhookPayload) {
	var configs []WebhookConfig
	s.db.Where("user_id = ? AND status = 1", userID).Find(&configs)

	for _, cfg := range configs {
		if !containsEvent(cfg.Events, event) {
			continue
		}
		go s.send(cfg.URL, payload)
	}
}

func (s *WebhookService) send(url string, payload WebhookPayload) {
	payload.Timestamp = time.Now().Unix()
	body, err := json.Marshal(payload)
	if err != nil {
		log.Printf("Webhook marshal error: %v", err)
		return
	}

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Post(url, "application/json", bytes.NewReader(body))
	if err != nil {
		log.Printf("Webhook send failed to %s: %v", url, err)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		log.Printf("Webhook %s returned status %d", url, resp.StatusCode)
	} else {
		log.Printf("Webhook sent to %s: %s", url, payload.Event)
	}
}

func containsEvent(events, event string) bool {
	for _, e := range splitEvents(events) {
		if e == event {
			return true
		}
	}
	return false
}

func splitEvents(events string) []string {
	var result []string
	current := ""
	for _, c := range events {
		if c == ',' {
			if current != "" {
				result = append(result, current)
			}
			current = ""
		} else {
			current += string(c)
		}
	}
	if current != "" {
		result = append(result, current)
	}
	return result
}

// CreateWebhook creates a new webhook config.
func (s *WebhookService) Create(userID uint, url, events string) (*WebhookConfig, error) {
	cfg := &WebhookConfig{
		UserID: userID,
		URL:    url,
		Events: events,
		Status: 1,
	}
	if err := s.db.Create(cfg).Error; err != nil {
		return nil, fmt.Errorf("create webhook failed: %w", err)
	}
	return cfg, nil
}

// ListWebhooks returns webhooks for a user.
func (s *WebhookService) List(userID uint) ([]WebhookConfig, error) {
	var configs []WebhookConfig
	err := s.db.Where("user_id = ?", userID).Find(&configs).Error
	return configs, err
}

// DeleteWebhook deletes a webhook config.
func (s *WebhookService) Delete(id, userID uint) error {
	return s.db.Where("id = ? AND user_id = ?", id, userID).Delete(&WebhookConfig{}).Error
}

// Migrate creates the webhook_configs table.
func (s *WebhookService) Migrate() error {
	return s.db.AutoMigrate(&WebhookConfig{})
}

// GetWebhookModel returns the WebhookConfig model for GORM.
func (s *WebhookService) GetWebhookModel() *WebhookConfig {
	return &WebhookConfig{}
}

func init() {
	// Register webhook model for auto-migration
	model.RegisterModel(&WebhookConfig{})
}

// Add to model package for auto-migration
func (m *WebhookConfig) TableName() string {
	return "webhook_configs"
}
