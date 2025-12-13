package utility

import (
	"fmt"
	"time"
)

type ProgressTracker struct {
	startTime time.Time
	Total     int
	limit     int
}

func NewProgressTracker(limit int) *ProgressTracker {
	return &ProgressTracker{
		startTime: time.Now(),
		limit:     limit,
	}
}

func (p *ProgressTracker) formatDuration(d time.Duration) string {
	if d.Hours() >= 1 {
		hours := int(d.Hours())
		minutes := int(d.Minutes()) % 60
		return fmt.Sprintf("%dh%dm", hours, minutes)
	}
	return fmt.Sprintf("%.0fm", d.Minutes())
}

func (p *ProgressTracker) PrintProgress(current, totalAvailable int) {
	elapsed := time.Since(p.startTime)
	rate := float64(p.Total) / elapsed.Seconds()

	timeStr := p.formatDuration(elapsed)

	// Calculate estimated remaining time
	var etaStr string
	if rate > 0 && current > 0 {
		remaining := totalAvailable - current
		if p.limit > 0 && p.limit < totalAvailable {
			remaining = p.limit - current
		}
		if remaining > 0 {
			etaSeconds := float64(remaining) / rate
			etaDuration := time.Duration(etaSeconds) * time.Second
			etaStr = fmt.Sprintf(", ETA %s", p.formatDuration(etaDuration))
		}
	}

	fmt.Printf("\rFetched %d vorgänge (%.1f/sec, %.1f%% of %d total, %s%s)    ",
		current,
		rate,
		float64(current)/float64(totalAvailable)*100,
		totalAvailable,
		timeStr,
		etaStr)
}

func (p *ProgressTracker) Increment() {
	p.Total++
}

func (p *ProgressTracker) GetStats() (elapsed time.Duration, rate float64) {
	elapsed = time.Since(p.startTime)
	rate = float64(p.Total) / elapsed.Seconds()
	return
}
