package handler

import (
	"subforge/internal/pkg/response"
	"subforge/internal/renderer"
	"subforge/internal/service"

	"github.com/gin-gonic/gin"
)

type ConvertHandler struct {
	svc *service.ConvertService
}

func NewConvertHandler(svc *service.ConvertService) *ConvertHandler {
	return &ConvertHandler{svc: svc}
}

func (h *ConvertHandler) Convert(c *gin.Context) {
	var req service.ConvertRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request: "+err.Error())
		return
	}
	result, err := h.svc.Convert(req)
	if err != nil {
		response.InternalError(c, "convert failed: "+err.Error())
		return
	}
	c.Data(200, "text/plain; charset=utf-8", []byte(result))
}

func (h *ConvertHandler) Detect(c *gin.Context) {
	var req struct {
		Source string `json:"source" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}
	format, count, err := h.svc.DetectFormat(req.Source)
	if err != nil {
		response.InternalError(c, "detect failed: "+err.Error())
		return
	}
	response.OK(c, gin.H{
		"format":    format,
		"node_count": count,
	})
}

func (h *ConvertHandler) ListFormats(c *gin.Context) {
	response.OK(c, gin.H{
		"formats": renderer.ListFormats(),
	})
}
