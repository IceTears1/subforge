package service

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"subforge/internal/core"
	"subforge/internal/model"
	"subforge/internal/parser"
	"subforge/internal/smart"

	"gorm.io/datatypes"
	"gorm.io/gorm"
)

type SubscriptionService struct {
	db *gorm.DB
}

func NewSubscriptionService(db *gorm.DB) *SubscriptionService {
	return &SubscriptionService{db: db}
}

type CreateSubRequest struct {
	Name        string   `json:"name" binding:"required"`
	URL         string   `json:"url" binding:"required,url"`
	AutoRefresh int      `json:"auto_refresh"`
	Tags        []string `json:"tags"`
}

func (s *SubscriptionService) List(userID uint) ([]model.Subscription, error) {
	var subs []model.Subscription
	err := s.db.Where("user_id = ?", userID).Order("id ASC").Find(&subs).Error
	return subs, err
}

func (s *SubscriptionService) Get(id, userID uint) (*model.Subscription, error) {
	var sub model.Subscription
	err := s.db.Where("id = ? AND user_id = ?", id, userID).First(&sub).Error
	if err != nil {
		return nil, err
	}
	// Load nodes
	s.db.Where("subscription_id = ?", sub.ID).Order("region ASC, id ASC").Find(&sub.Nodes)
	return &sub, nil
}

func (s *SubscriptionService) Create(userID uint, req CreateSubRequest) (*model.Subscription, error) {
	tagsJSON, _ := json.Marshal(req.Tags)
	if req.AutoRefresh == 0 {
		req.AutoRefresh = 3600
	}
	sub := &model.Subscription{
		UserID:      userID,
		Name:        req.Name,
		URL:         req.URL,
		AutoRefresh: req.AutoRefresh,
		Tags:        datatypes.JSON(tagsJSON),
		Status:      1,
	}
	if err := s.db.Create(sub).Error; err != nil {
		return nil, err
	}
	// Auto fetch on create
	go s.Refresh(sub.ID, userID)
	return sub, nil
}

func (s *SubscriptionService) Update(id, userID uint, req CreateSubRequest) error {
	tagsJSON, _ := json.Marshal(req.Tags)
	return s.db.Model(&model.Subscription{}).
		Where("id = ? AND user_id = ?", id, userID).
		Updates(map[string]interface{}{
			"name":         req.Name,
			"url":          req.URL,
			"auto_refresh": req.AutoRefresh,
			"tags":         datatypes.JSON(tagsJSON),
		}).Error
}

func (s *SubscriptionService) Delete(id, userID uint) error {
	return s.db.Where("id = ? AND user_id = ?", id, userID).Delete(&model.Subscription{}).Error
}

func (s *SubscriptionService) Refresh(subID, userID uint) error {
	var sub model.Subscription
	if err := s.db.Where("id = ? AND user_id = ?", subID, userID).First(&sub).Error; err != nil {
		return err
	}
	return s.refreshSub(&sub)
}

func (s *SubscriptionService) refreshSub(sub *model.Subscription) error {
	// Fetch content
	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Get(sub.URL)
	if err != nil {
		return fmt.Errorf("fetch failed: %w", err)
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("read body failed: %w", err)
	}
	content := string(body)

	// Parse nodes
	nodes, format, err := parser.ParseWithAutoDetect(content)
	if err != nil {
		return fmt.Errorf("parse failed (format=%s): %w", format, err)
	}

	// Smart processing
	nodes = smart.Deduplicate(nodes)
	nodes = smart.RenameByRegion(nodes)

	// Save nodes to DB
	tx := s.db.Begin()
	// Delete old nodes
	if err := tx.Where("subscription_id = ?", sub.ID).Delete(&model.Node{}).Error; err != nil {
		tx.Rollback()
		return fmt.Errorf("delete old nodes failed: %w", err)
	}
	// Insert new nodes
	for _, n := range nodes {
		configJSON, _ := json.Marshal(n)
		region, _ := n.Extra["region"].(string)
		dbNode := model.Node{
			SubscriptionID: sub.ID,
			Name:           n.Name,
			DisplayName:    n.Name,
			NodeType:       n.Type,
			Server:         n.Server,
			Port:           n.Port,
			Region:         region,
			RawURI:         "",
			ConfigJSON:     datatypes.JSON(configJSON),
			Status:         1,
		}
		if err := tx.Create(&dbNode).Error; err != nil {
			tx.Rollback()
			return fmt.Errorf("insert node failed: %w", err)
		}
	}

	// Update subscription
	now := time.Now()
	if err := tx.Model(sub).Updates(map[string]interface{}{
		"last_fetch": &now,
		"node_count": len(nodes),
	}).Error; err != nil {
		tx.Rollback()
		return fmt.Errorf("update subscription failed: %w", err)
	}

	return tx.Commit().Error
}

// GetNodes returns nodes for a subscription.
func (s *SubscriptionService) GetNodes(subID, userID uint, region string) ([]model.Node, error) {
	var sub model.Subscription
	if err := s.db.Where("id = ? AND user_id = ?", subID, userID).First(&sub).Error; err != nil {
		return nil, err
	}
	var nodes []model.Node
	q := s.db.Where("subscription_id = ?", subID)
	if region != "" {
		q = q.Where("region = ?", strings.ToUpper(region))
	}
	err := q.Order("region ASC, id ASC").Find(&nodes).Error
	return nodes, err
}

// GetNodesAsProxy converts DB nodes back to ProxyNode for rendering.
func (s *SubscriptionService) GetNodesAsProxy(subID, userID uint) ([]core.ProxyNode, error) {
	nodes, err := s.GetNodes(subID, userID, "")
	if err != nil {
		return nil, err
	}
	var proxies []core.ProxyNode
	for _, n := range nodes {
		var pn core.ProxyNode
		if err := json.Unmarshal(n.ConfigJSON, &pn); err == nil {
			proxies = append(proxies, pn)
		}
	}
	return proxies, nil
}

// MergedSub returns all nodes from all subscriptions of a user.
func (s *SubscriptionService) MergedSub(userID uint) ([]core.ProxyNode, error) {
	subs, err := s.List(userID)
	if err != nil {
		return nil, err
	}
	var all []core.ProxyNode
	for _, sub := range subs {
		nodes, err := s.GetNodesAsProxy(sub.ID, userID)
		if err != nil {
			continue
		}
		all = append(all, nodes...)
	}
	return smart.Deduplicate(all), nil
}
