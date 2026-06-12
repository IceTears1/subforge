package service

import (
	"log"
	"time"

	"subforge/internal/model"

	"gorm.io/gorm"
)

// Scheduler periodically refreshes subscriptions.
type Scheduler struct {
	db  *gorm.DB
	sub *SubscriptionService
}

func NewScheduler(db *gorm.DB, sub *SubscriptionService) *Scheduler {
	return &Scheduler{db: db, sub: sub}
}

// Start begins the auto-refresh loop.
func (s *Scheduler) Start() {
	go func() {
		ticker := time.NewTicker(5 * time.Minute)
		defer ticker.Stop()
		for range ticker.C {
			s.refreshDue()
		}
	}()
	log.Println("Scheduler started")
}

func (s *Scheduler) refreshDue() {
	var subs []model.Subscription
	now := time.Now()
	s.db.Where("status = 1").Find(&subs)

	for _, sub := range subs {
		// Check if refresh is due
		if sub.LastFetch != nil {
			nextRefresh := sub.LastFetch.Add(time.Duration(sub.AutoRefresh) * time.Second)
			if now.Before(nextRefresh) {
				continue
			}
		}
		// Refresh in background
		go func(subID, userID uint) {
			if err := s.sub.Refresh(subID, userID); err != nil {
				log.Printf("Auto-refresh sub %d failed: %v", subID, err)
			} else {
				log.Printf("Auto-refreshed sub %d", subID)
			}
		}(sub.ID, sub.UserID)
	}
}
