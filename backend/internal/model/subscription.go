package model

import (
	"time"

	"gorm.io/datatypes"
)

type Subscription struct {
	ID          uint           `json:"id" gorm:"primaryKey"`
	UserID      uint           `json:"user_id" gorm:"index"`
	Token       string         `json:"token" gorm:"uniqueIndex;size:32"` // public access token
	Name        string         `json:"name" gorm:"size:128;not null"`
	URL         string         `json:"url" gorm:"not null"`
	AutoRefresh int            `json:"auto_refresh" gorm:"default:3600"`
	Tags        datatypes.JSON `json:"tags" gorm:"type:jsonb;default:'[]'"`
	LastFetch   *time.Time     `json:"last_fetch,omitempty"`
	NodeCount   int            `json:"node_count" gorm:"default:0"`
	Status      int8           `json:"status" gorm:"default:1"`
	CreatedAt   time.Time      `json:"created_at"`
	UpdatedAt   time.Time      `json:"updated_at"`
	Nodes       []Node         `json:"nodes,omitempty" gorm:"foreignKey:SubscriptionID"`
}
