package service

import (
	"fmt"
	"subforge/internal/model"

	"gorm.io/gorm"
)

type FavoriteService struct {
	db *gorm.DB
}

func NewFavoriteService(db *gorm.DB) *FavoriteService {
	return &FavoriteService{db: db}
}

// Add adds a node to favorites.
func (s *FavoriteService) Add(userID, nodeID uint, note string) error {
	// Check if already exists
	var count int64
	s.db.Model(&model.Favorite{}).Where("user_id = ? AND node_id = ?", userID, nodeID).Count(&count)
	if count > 0 {
		return fmt.Errorf("already in favorites")
	}

	return s.db.Create(&model.Favorite{
		UserID: userID,
		NodeID: nodeID,
		Note:   note,
	}).Error
}

// Remove removes a node from favorites.
func (s *FavoriteService) Remove(userID, nodeID uint) error {
	return s.db.Where("user_id = ? AND node_id = ?", userID, nodeID).Delete(&model.Favorite{}).Error
}

// List returns all favorite nodes for a user.
func (s *FavoriteService) List(userID uint) ([]model.Node, error) {
	var favorites []model.Favorite
	s.db.Where("user_id = ?", userID).Order("id DESC").Find(&favorites)

	var nodes []model.Node
	for _, fav := range favorites {
		var node model.Node
		if err := s.db.First(&node, fav.NodeID).Error; err == nil {
			nodes = append(nodes, node)
		}
	}
	return nodes, nil
}

// IsFavorite checks if a node is in favorites.
func (s *FavoriteService) IsFavorite(userID, nodeID uint) bool {
	var count int64
	s.db.Model(&model.Favorite{}).Where("user_id = ? AND node_id = ?", userID, nodeID).Count(&count)
	return count > 0
}

// UpdateNote updates the note for a favorite.
func (s *FavoriteService) UpdateNote(userID, nodeID uint, note string) error {
	return s.db.Model(&model.Favorite{}).
		Where("user_id = ? AND node_id = ?", userID, nodeID).
		Update("note", note).Error
}
