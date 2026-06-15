package model

import "time"

type APIKey struct {
	ID        uint      `json:"id" gorm:"primaryKey"`
	UserID    uint      `json:"user_id" gorm:"index"`
	Name      string    `json:"name" gorm:"size:64;not null"`
	Key       string    `json:"key" gorm:"uniqueIndex;size:64;not null"`
	LastUsed  *time.Time `json:"last_used,omitempty"`
	Status    int8      `json:"status" gorm:"default:1"`
	CreatedAt time.Time `json:"created_at"`
}
