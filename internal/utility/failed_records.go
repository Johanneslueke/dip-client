package utility

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

// FailedRecord represents a record that failed to be inserted
type FailedRecord struct {
	ID        string    `json:"id"`
	Reason    string    `json:"reason"`
	Timestamp time.Time `json:"timestamp"`
}

// FailedRecordsTracker tracks records that failed to be inserted
type FailedRecordsTracker struct {
	mu       sync.Mutex
	records  []FailedRecord
	filePath string
	syncName string
}

// NewFailedRecordsTracker creates a new tracker for failed records
func NewFailedRecordsTracker(failedDir, syncName string) *FailedRecordsTracker {
	return &FailedRecordsTracker{
		records:  make([]FailedRecord, 0),
		filePath: filepath.Join(failedDir, fmt.Sprintf("%s.failed.json", syncName)),
		syncName: syncName,
	}
}

// RecordFailure adds a failed record to the tracker
func (t *FailedRecordsTracker) RecordFailure(id, reason string) {
	t.mu.Lock()
	defer t.mu.Unlock()
	
	t.records = append(t.records, FailedRecord{
		ID:        id,
		Reason:    reason,
		Timestamp: time.Now(),
	})
}

// IsDBLocked checks if the error is due to database being locked
func IsDBLocked(err error) bool {
	if err == nil {
		return false
	}
	errStr := strings.ToLower(err.Error())
	return strings.Contains(errStr, "database is locked") || 
	       strings.Contains(errStr, "database locked")
}

// RecordIfDBLocked records the failure if the error is due to database lock
func (t *FailedRecordsTracker) RecordIfDBLocked(id string, operation string, err error) {
	if err != nil && IsDBLocked(err) {
		t.RecordFailure(id, operation+": "+err.Error())
	}
}

// Save persists the failed records to a file
func (t *FailedRecordsTracker) Save() error {
	t.mu.Lock()
	defer t.mu.Unlock()
	
	if len(t.records) == 0 {
		return nil // Nothing to save
	}
	
	// Ensure directory exists
	dir := filepath.Dir(t.filePath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return fmt.Errorf("failed to create failed records directory: %w", err)
	}
	
	// Load existing records if file exists
	existingRecords := make([]FailedRecord, 0)
	if data, err := os.ReadFile(t.filePath); err == nil {
		json.Unmarshal(data, &existingRecords)
	}
	
	// Append new records
	allRecords := append(existingRecords, t.records...)
	
	// Save to file
	data, err := json.MarshalIndent(allRecords, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal failed records: %w", err)
	}
	
	if err := os.WriteFile(t.filePath, data, 0644); err != nil {
		return fmt.Errorf("failed to write failed records file: %w", err)
	}
	
	return nil
}

// Count returns the number of failed records
func (t *FailedRecordsTracker) Count() int {
	t.mu.Lock()
	defer t.mu.Unlock()
	return len(t.records)
}

// Clear clears the failed records
func (t *FailedRecordsTracker) Clear() {
	t.mu.Lock()
	defer t.mu.Unlock()
	t.records = make([]FailedRecord, 0)
}

// LoadFailedRecords loads failed records from a file
func LoadFailedRecords(failedDir, syncName string) ([]FailedRecord, error) {
	filePath := filepath.Join(failedDir, fmt.Sprintf("%s.failed.json", syncName))
	
	data, err := os.ReadFile(filePath)
	if err != nil {
		if os.IsNotExist(err) {
			return []FailedRecord{}, nil // No failed records file exists
		}
		return nil, fmt.Errorf("failed to read failed records file: %w", err)
	}
	
	var records []FailedRecord
	if err := json.Unmarshal(data, &records); err != nil {
		return nil, fmt.Errorf("failed to unmarshal failed records: %w", err)
	}
	
	return records, nil
}

// DeleteFailedRecords removes the failed records file
func DeleteFailedRecords(failedDir, syncName string) error {
	filePath := filepath.Join(failedDir, fmt.Sprintf("%s.failed.json", syncName))
	err := os.Remove(filePath)
	if err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("failed to delete failed records file: %w", err)
	}
	return nil
}
