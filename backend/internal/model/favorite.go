package model

import "time"

type Favorite struct {
	ID        uint      `json:"id" gorm:"primaryKey"`
	UserID    uint      `json:"user_id" gorm:"index"`
	NodeID    uint      `json:"node_id" gorm:"index"`
	Note      string    `json:"note" gorm:"size:256"`
	CreatedAt time.Time `json:"created_at"`
}

func (Favorite) TableName() string {
	return "favorites"
}
