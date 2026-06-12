package handler

import (
	"strconv"
	"subforge/internal/pkg/response"
	"subforge/internal/service"

	"github.com/gin-gonic/gin"
)

type SubscriptionHandler struct {
	svc *service.SubscriptionService
}

func NewSubscriptionHandler(svc *service.SubscriptionService) *SubscriptionHandler {
	return &SubscriptionHandler{svc: svc}
}

func (h *SubscriptionHandler) List(c *gin.Context) {
	userID := getUserID(c)
	subs, err := h.svc.List(userID)
	if err != nil {
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, subs)
}

func (h *SubscriptionHandler) Get(c *gin.Context) {
	id, _ := strconv.ParseUint(c.Param("id"), 10, 32)
	userID := getUserID(c)
	sub, err := h.svc.Get(uint(id), userID)
	if err != nil {
		response.NotFound(c)
		return
	}
	response.OK(c, sub)
}

func (h *SubscriptionHandler) Create(c *gin.Context) {
	var req service.CreateSubRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request: "+err.Error())
		return
	}
	userID := getUserID(c)
	sub, err := h.svc.Create(userID, req)
	if err != nil {
		response.InternalError(c, err.Error())
		return
	}
	response.Created(c, sub)
}

func (h *SubscriptionHandler) Update(c *gin.Context) {
	id, _ := strconv.ParseUint(c.Param("id"), 10, 32)
	var req service.CreateSubRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request: "+err.Error())
		return
	}
	userID := getUserID(c)
	if err := h.svc.Update(uint(id), userID, req); err != nil {
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, nil)
}

func (h *SubscriptionHandler) Delete(c *gin.Context) {
	id, _ := strconv.ParseUint(c.Param("id"), 10, 32)
	userID := getUserID(c)
	if err := h.svc.Delete(uint(id), userID); err != nil {
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, nil)
}

func (h *SubscriptionHandler) Refresh(c *gin.Context) {
	id, _ := strconv.ParseUint(c.Param("id"), 10, 32)
	userID := getUserID(c)
	if err := h.svc.Refresh(uint(id), userID); err != nil {
		response.InternalError(c, "refresh failed: "+err.Error())
		return
	}
	response.OK(c, gin.H{"message": "refreshed"})
}

func (h *SubscriptionHandler) GetNodes(c *gin.Context) {
	id, _ := strconv.ParseUint(c.Param("id"), 10, 32)
	userID := getUserID(c)
	region := c.Query("region")
	nodes, err := h.svc.GetNodes(uint(id), userID, region)
	if err != nil {
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, nodes)
}
