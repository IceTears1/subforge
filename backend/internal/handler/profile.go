package handler

import (
	"subforge/internal/model"
	"subforge/internal/pkg/crypto"
	"subforge/internal/pkg/response"
	"subforge/internal/service"

	"github.com/gin-gonic/gin"
)

type ProfileHandler struct {
	userSvc *service.UserService
}

func NewProfileHandler(userSvc *service.UserService) *ProfileHandler {
	return &ProfileHandler{userSvc: userSvc}
}

// GetMe returns the current user's profile.
func (h *ProfileHandler) GetMe(c *gin.Context) {
	userID := getUserID(c)
	user, err := h.userSvc.GetByID(userID)
	if err != nil {
		response.NotFound(c)
		return
	}
	response.OK(c, user)
}

// ChangePassword allows a user to change their own password.
func (h *ProfileHandler) ChangePassword(c *gin.Context) {
	userID := getUserID(c)
	var req struct {
		OldPassword string `json:"old_password" binding:"required"`
		NewPassword string `json:"new_password" binding:"required,min=6"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}

	user, err := h.userSvc.GetByID(userID)
	if err != nil {
		response.NotFound(c)
		return
	}

	if !crypto.CheckPassword(req.OldPassword, user.Password) {
		response.Error(c, 400, "old password is incorrect")
		return
	}

	if err := h.userSvc.ResetPassword(userID, req.NewPassword); err != nil {
		response.InternalError(c, "failed to change password")
		return
	}

	response.OK(c, gin.H{"message": "password changed"})
}

// GetSubToken returns the current user's subscription token for API access.
func (h *ProfileHandler) GetSubToken(c *gin.Context) {
	userID := getUserID(c)
	var user model.User
	if err := h.userSvc.GetByID(userID); err != nil {
		response.NotFound(c)
		return
	}
	// Return a placeholder - actual token is per-subscription
	response.OK(c, gin.H{
		"user_id":  user.ID,
		"username": user.Username,
		"role":     user.Role,
	})
}
