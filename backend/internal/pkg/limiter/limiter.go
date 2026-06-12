package limiter

import (
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
)

// IPRateLimiter is a simple per-IP token bucket rate limiter.
type IPRateLimiter struct {
	mu       sync.Mutex
	visitors map[string]*visitor
	rate     int           // tokens per interval
	interval time.Duration // refill interval
}

type visitor struct {
	tokens    int
	lastSeen  time.Time
}

func New(rate int, interval time.Duration) *IPRateLimiter {
	l := &IPRateLimiter{
		visitors: make(map[string]*visitor),
		rate:     rate,
		interval: interval,
	}
	go l.cleanup()
	return l
}

func (l *IPRateLimiter) getVisitor(ip string) *visitor {
	l.mu.Lock()
	defer l.mu.Unlock()

	v, exists := l.visitors[ip]
	if !exists {
		v = &visitor{tokens: l.rate, lastSeen: time.Now()}
		l.visitors[ip] = v
	}

	elapsed := time.Since(v.lastSeen)
	tokensToAdd := int(elapsed / l.interval) * l.rate
	if tokensToAdd > 0 {
		v.tokens += tokensToAdd
		if v.tokens > l.rate {
			v.tokens = l.rate
		}
		v.lastSeen = time.Now()
	}
	return v
}

func (l *IPRateLimiter) Allow(ip string) bool {
	v := l.getVisitor(ip)
	if v.tokens > 0 {
		v.tokens--
		return true
	}
	return false
}

func (l *IPRateLimiter) cleanup() {
	for {
		time.Sleep(5 * time.Minute)
		l.mu.Lock()
		for ip, v := range l.visitors {
			if time.Since(v.lastSeen) > 10*time.Minute {
				delete(l.visitors, ip)
			}
		}
		l.mu.Unlock()
	}
}

// Middleware returns a Gin middleware that limits requests per IP.
func Middleware(rate int, interval time.Duration) gin.HandlerFunc {
	limiter := New(rate, interval)
	return func(c *gin.Context) {
		ip := c.ClientIP()
		if !limiter.Allow(ip) {
			c.JSON(http.StatusTooManyRequests, gin.H{
				"code":    -1,
				"message": "rate limit exceeded, try again later",
			})
			c.Abort()
			return
		}
		c.Next()
	}
}
