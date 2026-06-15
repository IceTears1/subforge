package handler

import (
	"strconv"
	"subforge/internal/pkg/response"
	"subforge/internal/service"

	"github.com/gin-gonic/gin"
)

type FavoriteHandler struct {
	svc *service.FavoriteService
}

func NewFavoriteHandler(svc *service.FavoriteService) *FavoriteHandler {
	return &FavoriteHandler{svc: svc}
}

// Add adds a node to favorites.
func (h *FavoriteHandler) Add(c *gin.Context) {
	userID := getUserID(c)
	var req struct {
		NodeID uint   `json:"node_id" binding:"required"`
		Note   string `json:"note"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}

	if err := h.svc.Add(userID, req.NodeID, req.Note); err != nil {
		response.BadRequest(c, err.Error())
		return
	}
	response.OK(c, nil)
}

// Remove removes a node from favorites.
func (h *FavoriteHandler) Remove(c *gin.Context) {
	userID := getUserID(c)
	nodeID, _ := strconv.ParseUint(c.Param("nodeId"), 10, 32)

	if err := h.svc.Remove(userID, uint(nodeID)); err != nil {
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, nil)
}

// List returns all favorite nodes.
func (h *FavoriteHandler) List(c *gin.Context) {
	userID := getUserID(c)
	nodes, err := h.svc.List(userID)
	if err != nil {
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, nodes)
}

// IsFavorite checks if a node is in favorites.
func (h *FavoriteHandler) IsFavorite(c *gin.Context) {
	userID := getUserID(c)
	nodeID, _ := strconv.ParseUint(c.Param("nodeId"), 10, 32)

	isFav := h.svc.IsFavorite(userID, uint(nodeID))
	response.OK(c, gin.H{"is_favorite": isFav})
}
