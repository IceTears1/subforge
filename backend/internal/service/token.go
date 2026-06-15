package service

import (
	"sync"
	"time"
)

// TokenBlacklist manages revoked JWT tokens.
type TokenBlacklist struct {
	mu       sync.RWMutex
	tokens   map[string]time.Time // token -> expiry time
}

func NewTokenBlacklist() *TokenBlacklist {
	bl := &TokenBlacklist{
		tokens: make(map[string]time.Time),
	}
	go bl.cleanup()
	return bl
}

// Revoke adds a token to the blacklist.
func (bl *TokenBlacklist) Revoke(token string, expiry time.Time) {
	bl.mu.Lock()
	defer bl.mu.Unlock()
	bl.tokens[token] = expiry
}

// IsRevoked checks if a token has been revoked.
func (bl *TokenBlacklist) IsRevoked(token string) bool {
	bl.mu.RLock()
	defer bl.mu.RUnlock()
	_, exists := bl.tokens[token]
	return exists
}

func (bl *TokenBlacklist) cleanup() {
	ticker := time.NewTicker(10 * time.Minute)
	defer ticker.Stop()
	for range ticker.C {
		bl.mu.Lock()
		now := time.Now()
		for token, expiry := range bl.tokens {
			if now.After(expiry) {
				delete(bl.tokens, token)
			}
		}
		bl.mu.Unlock()
	}
}

// Global blacklist instance
var TokenBlacklistInstance = NewTokenBlacklist()
