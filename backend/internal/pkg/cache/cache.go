package cache

import (
	"crypto/md5"
	"fmt"
	"sync"
	"time"
)

// Cache is a simple in-memory cache with TTL.
type Cache struct {
	mu      sync.RWMutex
	items   map[string]*item
	maxSize int
}

type item struct {
	value     string
	etag      string
	expiresAt time.Time
}

func New(maxSize int) *Cache {
	c := &Cache{
		items:   make(map[string]*item),
		maxSize: maxSize,
	}
	go c.cleanup()
	return c
}

func (c *Cache) Get(key string) (string, string, bool) {
	c.mu.RLock()
	defer c.mu.RUnlock()

	item, exists := c.items[key]
	if !exists || time.Now().After(item.expiresAt) {
		return "", "", false
	}
	return item.value, item.etag, true
}

func (c *Cache) Set(key, value string, ttl time.Duration) {
	c.mu.Lock()
	defer c.mu.Unlock()

	// Evict if at capacity
	if len(c.items) >= c.maxSize {
		c.evictOldest()
	}

	etag := fmt.Sprintf("%x", md5.Sum([]byte(value)))
	c.items[key] = &item{
		value:     value,
		etag:      etag,
		expiresAt: time.Now().Add(ttl),
	}
}

func (c *Cache) Delete(key string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	delete(c.items, key)
}

func (c *Cache) evictOldest() {
	var oldestKey string
	var oldestTime time.Time
	for k, v := range c.items {
		if oldestKey == "" || v.expiresAt.Before(oldestTime) {
			oldestKey = k
			oldestTime = v.expiresAt
		}
	}
	if oldestKey != "" {
		delete(c.items, oldestKey)
	}
}

func (c *Cache) cleanup() {
	ticker := time.NewTicker(time.Minute)
	defer ticker.Stop()
	for range ticker.C {
		c.mu.Lock()
		now := time.Now()
		for k, v := range c.items {
			if now.After(v.expiresAt) {
				delete(c.items, k)
			}
		}
		c.mu.Unlock()
	}
}

// Global cache instance
var SubscriptionCache = New(1000)
