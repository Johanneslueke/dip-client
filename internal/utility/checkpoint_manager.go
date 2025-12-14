package utility

import (
	"log"
	"time"

	openapi_types "github.com/oapi-codegen/runtime/types"
)

// CheckpointManager handles checkpoint operations for sync processes
type CheckpointManager struct {
	dir          string
	resourceName string
	lastDate     time.Time
	enabled      bool
}

// NewCheckpointManager creates a new checkpoint manager
func NewCheckpointManager(dir, resourceName string, resume bool) *CheckpointManager {
	return &CheckpointManager{
		dir:          dir,
		resourceName: resourceName,
		enabled:      resume,
	}
}

// LoadIfResume loads a checkpoint if resume is enabled
func (cm *CheckpointManager) LoadIfResume() (*openapi_types.Date, error) {
	if !cm.enabled {
		return nil, nil
	}

	checkpoint, err := LoadCheckpoint(cm.dir, cm.resourceName)
	if err != nil {
		log.Printf("Warning: Failed to load checkpoint: %v", err)
		return nil, err
	}

	if checkpoint != nil {
		cm.lastDate = checkpoint.LastSyncDate
		date := openapi_types.Date{Time: checkpoint.LastSyncDate}
		log.Printf("Resuming from checkpoint: %s", checkpoint.LastSyncDate.Format("2006-01-02"))
		return &date, nil
	}

	return nil, nil
}

// UpdateDate updates the last processed date
func (cm *CheckpointManager) UpdateDate(date time.Time) {
	if date.After(cm.lastDate) {
		cm.lastDate = date
	}
}

// GetLastDate returns the last processed date
func (cm *CheckpointManager) GetLastDate() time.Time {
	return cm.lastDate
}

// SaveCheckpoint saves the current checkpoint
func (cm *CheckpointManager) SaveCheckpoint() error {
	if cm.lastDate.IsZero() {
		return nil
	}

	if err := SaveCheckpoint(cm.dir, cm.resourceName, cm.lastDate); err != nil {
		log.Printf("Error saving checkpoint: %v", err)
		return err
	}

	log.Printf("Checkpoint saved at %s", cm.lastDate.Format("2006-01-02"))
	return nil
}

// DeleteOnSuccess deletes the checkpoint file if sync completed successfully
func (cm *CheckpointManager) DeleteOnSuccess(interrupted bool) error {
	if !interrupted && cm.enabled {
		if err := DeleteCheckpoint(cm.dir, cm.resourceName); err != nil {
			log.Printf("Warning: Failed to delete checkpoint: %v", err)
			return err
		}
	}
	return nil
}
