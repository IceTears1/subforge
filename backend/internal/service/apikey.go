package service

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"time"

	"subforge/internal/model"

	"gorm.io/gorm"
)

type APIKeyService struct {
	db *gorm.DB
}

func NewAPIKeyService(db *gorm.DB) *APIKeyService {
	return &APIKeyService{db: db}
}

func (s *APIKeyService) Create(userID uint, name string) (*model.APIKey, error) {
	key := generateAPIKey()
	apiKey := &model.APIKey{
		UserID: userID,
		Name:   name,
		Key:    key,
		Status: 1,
	}
	if err := s.db.Create(apiKey).Error; err != nil {
		return nil, fmt.Errorf("create api key failed: %w", err)
	}
	return apiKey, nil
}

func (s *APIKeyService) List(userID uint) ([]model.APIKey, error) {
	var keys []model.APIKey
	err := s.db.Where("user_id = ?", userID).Order("id DESC").Find(&keys).Error
	return keys, err
}

func (s *APIKeyService) Delete(id, userID uint) error {
	return s.db.Where("id = ? AND user_id = ?", id, userID).Delete(&model.APIKey{}).Error
}

func (s *APIKeyService) Validate(key string) (*model.APIKey, error) {
	var apiKey model.APIKey
	err := s.db.Where("key = ? AND status = 1", key).First(&apiKey).Error
	if err != nil {
		return nil, err
	}
	// Update last used
	now := time.Now()
	s.db.Model(&apiKey).Update("last_used", &now)
	return &apiKey, nil
}

func generateAPIKey() string {
	b := make([]byte, 32)
	rand.Read(b)
	return "sf_" + hex.EncodeToString(b)
}
