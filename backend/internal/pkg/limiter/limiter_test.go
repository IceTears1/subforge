package limiter

import (
	"testing"
	"time"
)

func TestRateLimiter(t *testing.T) {
	l := New(3, time.Second) // 3 per second

	// Should allow first 3
	for i := 0; i < 3; i++ {
		if !l.Allow("1.2.3.4") {
			t.Errorf("request %d should be allowed", i)
		}
	}

	// 4th should be blocked
	if l.Allow("1.2.3.4") {
		t.Error("4th request should be blocked")
	}

	// Different IP should be allowed
	if !l.Allow("5.6.7.8") {
		t.Error("different IP should be allowed")
	}
}

func TestRateLimiterRefill(t *testing.T) {
	l := New(2, 100*time.Millisecond) // 2 per 100ms

	// Exhaust
	l.Allow("1.2.3.4")
	l.Allow("1.2.3.4")

	if l.Allow("1.2.3.4") {
		t.Error("should be blocked")
	}

	// Wait for refill
	time.Sleep(150 * time.Millisecond)

	if !l.Allow("1.2.3.4") {
		t.Error("should be allowed after refill")
	}
}
