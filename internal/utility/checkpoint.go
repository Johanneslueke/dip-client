package utility

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"time"
)

// SyncCheckpoint stores the state of a sync operation
type SyncCheckpoint struct {
	LastSyncDate time.Time `json:"last_sync_date"`
	UpdatedAt    time.Time `json:"updated_at"`
}

// SaveCheckpoint saves the checkpoint to a file
func SaveCheckpoint(checkpointDir, syncName string, lastDate time.Time) error {
	checkpoint := SyncCheckpoint{
		LastSyncDate: lastDate,
		UpdatedAt:    time.Now(),
	}

	// Ensure checkpoint directory exists
	if err := os.MkdirAll(checkpointDir, 0755); err != nil {
		return fmt.Errorf("failed to create checkpoint directory: %w", err)
	}

	filename := filepath.Join(checkpointDir, fmt.Sprintf("%s.checkpoint.json", syncName))

	data, err := json.MarshalIndent(checkpoint, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal checkpoint: %w", err)
	}

	if err := os.WriteFile(filename, data, 0644); err != nil {
		return fmt.Errorf("failed to write checkpoint file: %w", err)
	}

	return nil
}

// LoadCheckpoint loads the checkpoint from a file
func LoadCheckpoint(checkpointDir, syncName string) (*SyncCheckpoint, error) {
	filename := filepath.Join(checkpointDir, fmt.Sprintf("%s.checkpoint.json", syncName))

	data, err := os.ReadFile(filename)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil // No checkpoint exists
		}
		return nil, fmt.Errorf("failed to read checkpoint file: %w", err)
	}

	var checkpoint SyncCheckpoint
	if err := json.Unmarshal(data, &checkpoint); err != nil {
		return nil, fmt.Errorf("failed to unmarshal checkpoint: %w", err)
	}

	fmt.Println("Checkpoint has been loaded")
	return &checkpoint, nil
}

// DeleteCheckpoint removes the checkpoint file
func DeleteCheckpoint(checkpointDir, syncName string) error {
	filename := filepath.Join(checkpointDir, fmt.Sprintf("%s.checkpoint.json", syncName))
	err := os.Remove(filename)
	if err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("failed to delete checkpoint file: %w", err)
	}
	return nil
}
