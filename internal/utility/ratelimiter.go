package utility

import (
	"context"
	"fmt"
	"sync"
	"time"
)

type RateLimiter struct {
	tokens          float64
	maxTokens       float64
	refillRate      float64       // tokens per nanosecond
	refillInterval  time.Duration // time to add one token
	lastRefill      time.Time
	mu              sync.Mutex
}
 

func NewRateLimiter(maxRequests int, interval time.Duration) *RateLimiter {
	refillInterval := interval / time.Duration(maxRequests)
	return &RateLimiter{
		tokens:         0.0, // Start empty - no initial burst
		maxTokens:      float64(maxRequests),
		refillRate:     1.0 / float64(refillInterval),
		refillInterval: refillInterval,
		lastRefill:     time.Now(),
	}
}

func (rl *RateLimiter) Wait(ctx context.Context) error {
	rl.mu.Lock()

	for {
		now := time.Now()
		elapsed := now.Sub(rl.lastRefill)

		// Gradually refill tokens based on elapsed time
		if elapsed > 0 {
			tokensToAdd := float64(elapsed) * rl.refillRate
			rl.tokens += tokensToAdd
			if rl.tokens > rl.maxTokens {
				rl.tokens = rl.maxTokens
			}
			rl.lastRefill = now
		}

		if rl.tokens >= 1.0 {
			rl.tokens -= 1.0
			rl.mu.Unlock()
			fmt.Printf("Token after Unlock %v \n", rl.tokens)
			return nil
		}

		// Calculate how long until we have at least one token
		tokensNeeded := 1.0 - rl.tokens
		waitTime := time.Duration(tokensNeeded / rl.refillRate)
		
		rl.mu.Unlock()
		fmt.Printf("Token before wait %v , need to wait %v \n", rl.tokens, waitTime)
		
		timer := time.NewTimer(waitTime)
		select {
		case <-ctx.Done():
			if !timer.Stop() {
				<-timer.C
			}
			return ctx.Err()
		case <-timer.C:
		}
		
		rl.mu.Lock()
	}

}
