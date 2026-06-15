package handler

import (
	"fmt"
	"subforge/internal/pkg/response"
	"subforge/internal/service"

	"github.com/gin-gonic/gin"
)

type APIKeyHandler struct {
	svc *service.APIKeyService
}

func NewAPIKeyHandler(svc *service.APIKeyService) *APIKeyHandler {
	return &APIKeyHandler{svc: svc}
}

func (h *APIKeyHandler) List(c *gin.Context) {
	userID := getUserID(c)
	keys, err := h.svc.List(userID)
	if err != nil {
		response.InternalError(c, err.Error())
		return
	}
	// Mask keys for security
	type maskedKey struct {
		ID       uint   `json:"id"`
		Name     string `json:"name"`
		Key      string `json:"key"` // show first 8 chars only
		LastUsed *string `json:"last_used,omitempty"`
		Status   int8   `json:"status"`
	}
	var result []maskedKey
	for _, k := range keys {
		masked := maskedKey{
			ID:     k.ID,
			Name:   k.Name,
			Key:    k.Key[:11] + "...",
			Status: k.Status,
		}
		if k.LastUsed != nil {
			s := k.LastUsed.Format("2006-01-02 15:04:05")
			masked.LastUsed = &s
		}
		result = append(result, masked)
	}
	response.OK(c, result)
}

func (h *APIKeyHandler) Create(c *gin.Context) {
	userID := getUserID(c)
	var req struct {
		Name string `json:"name" binding:"required,max=64"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}
	key, err := h.svc.Create(userID, req.Name)
	if err != nil {
		response.InternalError(c, err.Error())
		return
	}
	response.Created(c, key)
}

func (h *APIKeyHandler) Delete(c *gin.Context) {
	userID := getUserID(c)
	id := c.Param("id")
	var idUint uint
	if _, err := fmt.Sscanf(id, "%d", &idUint); err != nil {
		response.BadRequest(c, "invalid id")
		return
	}
	if err := h.svc.Delete(idUint, userID); err != nil {
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, nil)
}
