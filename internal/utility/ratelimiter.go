package utility

import (
	"context"
	"sync"
	"time"
)

type rateLimiter struct {
	tokens     int
	maxTokens  int
	interval   time.Duration
	lastRefill time.Time
	mu         sync.Mutex
}

func NewRateLimiter(maxRequests int, interval time.Duration) *rateLimiter {
	return &rateLimiter{
		tokens:     maxRequests,
		maxTokens:  maxRequests,
		interval:   interval,
		lastRefill: time.Now(),
	}
}

func (rl *rateLimiter) Wait(ctx context.Context) error {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	for {
		now := time.Now()
		elapsed := now.Sub(rl.lastRefill)

		if elapsed >= rl.interval {
			rl.tokens = rl.maxTokens
			rl.lastRefill = now
		}

		if rl.tokens > 0 {
			rl.tokens--
			return nil
		}

		waitTime := rl.interval - elapsed
		rl.mu.Unlock()

		select {
		case <-ctx.Done():
			rl.mu.Lock()
			return ctx.Err()
		case <-time.After(waitTime):
			rl.mu.Lock()
		}
	}
}
