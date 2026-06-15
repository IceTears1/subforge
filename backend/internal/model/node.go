package model

import (
	"time"
)

type Node struct {
	ID             uint           `json:"id" gorm:"primaryKey"`
	SubscriptionID uint           `json:"subscription_id" gorm:"index"`
	Name           string         `json:"name" gorm:"size:256"`
	DisplayName    string         `json:"display_name" gorm:"size:256"`
	NodeType       string         `json:"node_type" gorm:"size:32"`
	Server         string         `json:"server" gorm:"size:256"`
	Port           int            `json:"port"`
	Region         string         `json:"region" gorm:"size:64;index"`
	RawURI         string         `json:"raw_uri" gorm:"type:text"`
	ConfigJSON     JSON           `json:"config_json" gorm:"type:jsonb"`
	Latency        int            `json:"latency"`
	LastCheck      *time.Time     `json:"last_check,omitempty"`
	Status         int8           `json:"status" gorm:"default:1"`
	CreatedAt      time.Time      `json:"created_at"`
}
