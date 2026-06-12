package service

import (
	"log"
	"time"

	"subforge/internal/model"

	"gorm.io/gorm"
)

// Scheduler periodically refreshes subscriptions with bounded concurrency.
type Scheduler struct {
	db  *gorm.DB
	sub *SubscriptionService
	sem chan struct{} // concurrency limiter
}

func NewScheduler(db *gorm.DB, sub *SubscriptionService) *Scheduler {
	return &Scheduler{
		db:  db,
		sub: sub,
		sem: make(chan struct{}, 5), // max 5 concurrent refreshes
	}
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
	log.Println("Scheduler started (max 5 concurrent)")
}

func (s *Scheduler) refreshDue() {
	var subs []model.Subscription
	now := time.Now()
	s.db.Where("status = 1").Find(&subs)

	for _, sub := range subs {
		if sub.LastFetch != nil {
			nextRefresh := sub.LastFetch.Add(time.Duration(sub.AutoRefresh) * time.Second)
			if now.Before(nextRefresh) {
				continue
			}
		}
		// Acquire semaphore slot
		s.sem <- struct{}{}
		go func(subID, userID uint) {
			defer func() { <-s.sem }()
			if err := s.sub.Refresh(subID, userID); err != nil {
				log.Printf("Auto-refresh sub %d failed: %v", subID, err)
			} else {
				log.Printf("Auto-refreshed sub %d", subID)
			}
		}(sub.ID, sub.UserID)
	}
}
