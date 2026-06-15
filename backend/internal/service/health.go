package service

import (
	"context"
	"fmt"
	"net"
	"sync"
	"time"

	"subforge/internal/model"

	"gorm.io/gorm"
)

// HealthService handles node health checks.
type HealthService struct {
	db *gorm.DB
}

func NewHealthService(db *gorm.DB) *HealthService {
	return &HealthService{db: db}
}

type HealthResult struct {
	NodeID   uint   `json:"node_id"`
	Name     string `json:"name"`
	Server   string `json:"server"`
	Port     int    `json:"port"`
	Latency  int    `json:"latency"` // ms, -1 if failed
	Status   string `json:"status"` // online|offline|timeout
}

// CheckNodes tests connectivity to nodes.
func (s *HealthService) CheckNodes(nodes []model.Node, concurrency int) []HealthResult {
	if concurrency <= 0 {
		concurrency = 10
	}

	results := make([]HealthResult, len(nodes))
	sem := make(chan struct{}, concurrency)
	var wg sync.WaitGroup

	for i, node := range nodes {
		wg.Add(1)
		sem <- struct{}{}
		go func(idx int, n model.Node) {
			defer wg.Done()
			defer func() { <-sem }()
			results[idx] = s.checkNode(n)
		}(i, node)
	}

	wg.Wait()
	return results
}

func (s *HealthService) checkNode(node model.Node) HealthResult {
	result := HealthResult{
		NodeID: node.ID,
		Name:   node.DisplayName,
		Server: node.Server,
		Port:   node.Port,
	}

	addr := fmt.Sprintf("%s:%d", node.Server, node.Port)
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	start := time.Now()
	var d net.Dialer
	conn, err := d.DialContext(ctx, "tcp", addr)
	latency := time.Since(start).Milliseconds()

	if err != nil {
		result.Latency = -1
		result.Status = "offline"
		return result
	}
	conn.Close()

	result.Latency = int(latency)
	if latency > 3000 {
		result.Status = "timeout"
	} else {
		result.Status = "online"
	}

	// Update DB
	s.db.Model(&model.Node{}).Where("id = ?", node.ID).Updates(map[string]interface{}{
		"latency":    latency,
		"last_check": time.Now(),
	})

	return result
}

// CheckSubscription checks all nodes of a subscription.
func (s *HealthService) CheckSubscription(subID, userID uint) ([]HealthResult, error) {
	var sub model.Subscription
	if err := s.db.Where("id = ? AND user_id = ?", subID, userID).First(&sub).Error; err != nil {
		return nil, err
	}

	var nodes []model.Node
	s.db.Where("subscription_id = ?", subID).Find(&nodes)

	return s.CheckNodes(nodes, 10), nil
}
