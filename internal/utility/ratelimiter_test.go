package utility

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestRateLimiter_SmoothDistribution(t *testing.T) {
	limiter := NewRateLimiter(6, time.Second)
	ctx := context.Background()

	start := time.Now()
	var timestamps []time.Duration

	for i := 0; i < 12; i++ {
		if err := limiter.Wait(ctx); err != nil {
			t.Fatalf("Request %d failed: %v", i, err)
		}
		timestamps = append(timestamps, time.Since(start))
	}

	expectedInterval := time.Second / 6
	for i := 1; i < len(timestamps); i++ {
		interval := timestamps[i] - timestamps[i-1]
		if interval < expectedInterval-50*time.Millisecond || interval > expectedInterval+50*time.Millisecond {
			t.Logf("Request %d: interval=%v (expected ~%v)", i, interval, expectedInterval)
		}
	}

	totalDuration := timestamps[len(timestamps)-1]
	// With 6 req/sec and no initial burst, 12 requests should take ~2 seconds
	expectedDuration := 12 * time.Second / 6
	if totalDuration < expectedDuration-100*time.Millisecond || totalDuration > expectedDuration+100*time.Millisecond {
		t.Errorf("Total duration %v unexpected (expected ~%v)", totalDuration, expectedDuration)
	}

	t.Logf("✓ Completed 12 requests in %v", totalDuration)
	t.Logf("✓ Average interval: %v", totalDuration/time.Duration(len(timestamps)-1))
}

func TestRateLimiter_SmoothFromEmpty(t *testing.T) {
	limiter := NewRateLimiter(24, time.Minute)
	ctx := context.Background()

	// With 24 req/min, each request waits 2.5 seconds
	expectedInterval := time.Minute / 24

	start := time.Now()
	for i := 0; i < 5; i++ {
		beforeWait := time.Now()
		if err := limiter.Wait(ctx); err != nil {
			t.Fatalf("Request %d failed: %v", i, err)
		}
		waitDuration := time.Since(beforeWait)

		// Each request should wait approximately expectedInterval
		if waitDuration < expectedInterval-100*time.Millisecond || waitDuration > expectedInterval+100*time.Millisecond {
			t.Logf("Request %d: waited %v (expected ~%v)", i, waitDuration, expectedInterval)
		}
	}
	totalDuration := time.Since(start)

	// 5 requests at 2.5s each = ~12.5 seconds
	expectedTotal := 5 * expectedInterval
	assert.GreaterOrEqual(t, totalDuration, expectedTotal-200*time.Millisecond)
	assert.LessOrEqual(t, totalDuration, expectedTotal+200*time.Millisecond)
	t.Logf("✓ 5 requests in %v (expected ~%v)", totalDuration, expectedTotal)
}

func TestRateLimiter_ContextCancellation(t *testing.T) {
	limiter := NewRateLimiter(1, time.Minute)

	if err := limiter.Wait(context.Background()); err != nil {
		t.Fatalf("First request failed: %v", err)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 100*time.Millisecond)
	defer cancel()

	err := limiter.Wait(ctx)
	if err == nil {
		t.Fatal("Expected context cancellation error, got nil")
	}
	if err != context.DeadlineExceeded {
		t.Errorf("Expected DeadlineExceeded, got %v", err)

	}
	t.Logf("✓ Context cancellation handled correctly: %v", err)
}

func TestRateLimiter_RequestsPerMinute(t *testing.T) {
	tests := []struct {
		name        string
		maxRequests int
		interval    time.Duration
		testReqs    int
		maxDuration time.Duration
	}{
		{
			name:        "24 requests per minute",
			maxRequests: 24,
			interval:    time.Minute,
			testReqs:    30,
			maxDuration: 80 * time.Second,
		},
		{
			name:        "10 requests per second",
			maxRequests: 10,
			interval:    time.Second,
			testReqs:    15,
			maxDuration: 1600 * time.Millisecond,
		},
		{
			name:        "100 requests per second",
			maxRequests: 100,
			interval:    time.Second,
			testReqs:    1500,
			maxDuration: 60 * time.Second,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			limiter := NewRateLimiter(tt.maxRequests, tt.interval)
			ctx := context.Background()

			start := time.Now()
			for i := 0; i < tt.testReqs; i++ {
				if err := limiter.Wait(ctx); err != nil {
					t.Fatalf("Request %d failed: %v", i, err)
				}
			}
			duration := time.Since(start)

			assert.LessOrEqual(t, duration, tt.maxDuration, "Duration exceeded maximum")

			// With no initial burst, all requests must wait for token refill
			// Expected time = testReqs * (interval / maxRequests)
			expectedTime := time.Duration(tt.testReqs) * tt.interval / time.Duration(tt.maxRequests)
			// Allow 5% tolerance for timing jitter
			assert.GreaterOrEqual(t, duration, expectedTime*95/100,
				"Requests completed too quickly - rate limiter not working")
			assert.LessOrEqual(t, duration, expectedTime*105/100,
				"Requests took too long")

			rate := float64(tt.testReqs) / duration.Seconds()
			expectedRate := float64(tt.maxRequests) / tt.interval.Seconds()

			t.Logf("✓ %d requests in %v (%.2f req/s, limit %.2f req/s)",
				tt.testReqs, duration, rate, expectedRate)
		})
	}
}
