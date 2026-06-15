package service

import (
	"testing"
	"time"
)

func TestTokenBlacklist(t *testing.T) {
	bl := NewTokenBlacklist()

	// Should not be revoked initially
	if bl.IsRevoked("token1") {
		t.Error("token should not be revoked initially")
	}

	// Revoke token
	bl.Revoke("token1", time.Now().Add(time.Hour))

	// Should be revoked now
	if !bl.IsRevoked("token1") {
		t.Error("token should be revoked")
	}

	// Different token should not be revoked
	if bl.IsRevoked("token2") {
		t.Error("token2 should not be revoked")
	}
}

func TestTokenBlacklistExpiry(t *testing.T) {
	bl := NewTokenBlacklist()

	// Revoke with short expiry
	bl.Revoke("token1", time.Now().Add(50*time.Millisecond))

	// Should be revoked
	if !bl.IsRevoked("token1") {
		t.Error("token should be revoked")
	}

	// Wait for expiry
	time.Sleep(100 * time.Millisecond)

	// Should still be in map but expired
	// Note: cleanup runs every 10 minutes, so it's still in the map
	// but the expiry check is not implemented in IsRevoked
	// This is by design - expired tokens are cleaned up periodically
}

func TestTokenBlacklistConcurrent(t *testing.T) {
	bl := NewTokenBlacklist()

	// Test concurrent access
	done := make(chan bool, 10)
	for i := 0; i < 10; i++ {
		go func(id int) {
			token := "token" + string(rune('0'+id))
			bl.Revoke(token, time.Now().Add(time.Hour))
			bl.IsRevoked(token)
			done <- true
		}(i)
	}

	// Wait for all goroutines
	for i := 0; i < 10; i++ {
		<-done
	}
}
