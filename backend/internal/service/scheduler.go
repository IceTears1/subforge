package service

import (
	"log"
	"sync"
	"time"

	"subforge/internal/model"

	"gorm.io/gorm"
)

// Scheduler periodically refreshes subscriptions with bounded concurrency.
type Scheduler struct {
	db       *gorm.DB
	sub      *SubscriptionService
	webhook  *WebhookService
	sem      chan struct{}
	mu       sync.Mutex
	running  bool
	stats    RefreshStats
}

type RefreshStats struct {
	Total     int       `json:"total"`
	Success   int       `json:"success"`
	Failed    int       `json:"failed"`
	LastRun   time.Time `json:"last_run"`
	Duration  int64     `json:"duration_ms"`
}

func NewScheduler(db *gorm.DB, sub *SubscriptionService) *Scheduler {
	return &Scheduler{
		db:      db,
		sub:     sub,
		webhook: NewWebhookService(db),
		sem:     make(chan struct{}, 5),
	}
}

// Start begins the auto-refresh loop.
func (s *Scheduler) Start() {
	s.mu.Lock()
	s.running = true
	s.mu.Unlock()

	go func() {
		ticker := time.NewTicker(1 * time.Minute)
		defer ticker.Stop()
		for range ticker.C {
			s.refreshDue()
		}
	}()

	log.Println("Scheduler started (check every 1 min, max 5 concurrent)")
}

// Stop stops the scheduler.
func (s *Scheduler) Stop() {
	s.mu.Lock()
	s.running = false
	s.mu.Unlock()
}

// IsRunning returns whether the scheduler is running.
func (s *Scheduler) IsRunning() bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.running
}

// GetStats returns refresh statistics.
func (s *Scheduler) GetStats() RefreshStats {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.stats
}

func (s *Scheduler) refreshDue() {
	var subs []model.Subscription
	now := time.Now()
	s.db.Where("status = 1").Find(&subs)

	var dueSubs []model.Subscription
	for _, sub := range subs {
		if sub.LastFetch != nil {
			nextRefresh := sub.LastFetch.Add(time.Duration(sub.AutoRefresh) * time.Second)
			if now.Before(nextRefresh) {
				continue
			}
		}
		dueSubs = append(dueSubs, sub)
	}

	if len(dueSubs) == 0 {
		return
	}

	log.Printf("Found %d subscriptions due for refresh", len(dueSubs))

	startTime := time.Now()
	success := 0
	failed := 0
	var wg sync.WaitGroup

	for _, sub := range dueSubs {
		s.sem <- struct{}{}
		wg.Add(1)
		go func(sub model.Subscription) {
			defer func() {
				<-s.sem
				wg.Done()
			}()

			if err := s.sub.Refresh(sub.ID, sub.UserID); err != nil {
				log.Printf("Auto-refresh sub %d (%s) failed: %v", sub.ID, sub.Name, err)
				failed++
				s.webhook.Notify(sub.UserID, "fail", WebhookPayload{
					Event:   "fail",
					SubID:   sub.ID,
					SubName: sub.Name,
					Error:   err.Error(),
				})
			} else {
				log.Printf("Auto-refreshed sub %d (%s)", sub.ID, sub.Name)
				success++
			}
		}(sub)
	}

	wg.Wait()

	// Update stats
	s.mu.Lock()
	s.stats = RefreshStats{
		Total:    len(dueSubs),
		Success:  success,
		Failed:   failed,
		LastRun:  startTime,
		Duration: time.Since(startTime).Milliseconds(),
	}
	s.mu.Unlock()

	log.Printf("Refresh completed: %d success, %d failed, %dms",
		success, failed, time.Since(startTime).Milliseconds())
}

// ForceRefresh forces a refresh of all subscriptions.
func (s *Scheduler) ForceRefresh() RefreshStats {
	var subs []model.Subscription
	s.db.Where("status = 1").Find(&subs)

	startTime := time.Now()
	success := 0
	failed := 0
	var wg sync.WaitGroup

	for _, sub := range subs {
		s.sem <- struct{}{}
		wg.Add(1)
		go func(sub model.Subscription) {
			defer func() {
				<-s.sem
				wg.Done()
			}()

			if err := s.sub.Refresh(sub.ID, sub.UserID); err != nil {
				failed++
			} else {
				success++
			}
		}(sub)
	}

	wg.Wait()

	stats := RefreshStats{
		Total:    len(subs),
		Success:  success,
		Failed:   failed,
		LastRun:  startTime,
		Duration: time.Since(startTime).Milliseconds(),
	}

	s.mu.Lock()
	s.stats = stats
	s.mu.Unlock()

	return stats
}
