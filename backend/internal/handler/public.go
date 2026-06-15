package handler

import (
	"crypto/md5"
	"fmt"
	"time"

	"subforge/internal/pkg/cache"
	"subforge/internal/service"

	"github.com/gin-gonic/gin"
)

type PublicHandler struct {
	subSvc *service.SubscriptionService
}

func NewPublicHandler(subSvc *service.SubscriptionService) *PublicHandler {
	return &PublicHandler{subSvc: subSvc}
}

// GetSub serves a rendered subscription by token with caching.
func (h *PublicHandler) GetSub(c *gin.Context) {
	token := c.Param("token")
	target := c.DefaultQuery("target", "clash")
	cacheKey := fmt.Sprintf("sub:%s:%s", token, target)

	// Check cache
	if content, etag, ok := cache.SubscriptionCache.Get(cacheKey); ok {
		// Check ETag
		ifNoneMatch := c.GetHeader("If-None-Match")
		if ifNoneMatch == etag {
			c.Status(304)
			return
		}
		c.Header("ETag", etag)
		c.Header("Cache-Control", "max-age=300")
		c.Header("Content-Type", "text/plain; charset=utf-8")
		c.String(200, content)
		return
	}

	content, err := h.subSvc.GetNodesByToken(token, target)
	if err != nil {
		c.String(404, "subscription not found")
		return
	}

	// Cache for 5 minutes
	cache.SubscriptionCache.Set(cacheKey, content, 5*time.Minute)
	etag := fmt.Sprintf("%x", md5.Sum([]byte(content)))

	c.Header("ETag", etag)
	c.Header("Cache-Control", "max-age=300")
	c.Header("Content-Type", "text/plain; charset=utf-8")
	c.String(200, content)
}

// GetMergedSub serves all subscriptions merged by token.
func (h *PublicHandler) GetMergedSub(c *gin.Context) {
	token := c.Param("token")
	target := c.DefaultQuery("target", "clash")
	cacheKey := fmt.Sprintf("merged:%s:%s", token, target)

	if content, etag, ok := cache.SubscriptionCache.Get(cacheKey); ok {
		ifNoneMatch := c.GetHeader("If-None-Match")
		if ifNoneMatch == etag {
			c.Status(304)
			return
		}
		c.Header("ETag", etag)
		c.Header("Cache-Control", "max-age=300")
		c.Header("Content-Type", "text/plain; charset=utf-8")
		c.String(200, content)
		return
	}

	content, err := h.subSvc.MergedByToken(token, target)
	if err != nil {
		c.String(404, "subscription not found")
		return
	}

	cache.SubscriptionCache.Set(cacheKey, content, 5*time.Minute)
	etag := fmt.Sprintf("%x", md5.Sum([]byte(content)))

	c.Header("ETag", etag)
	c.Header("Cache-Control", "max-age=300")
	c.Header("Content-Type", "text/plain; charset=utf-8")
	c.String(200, content)
}
