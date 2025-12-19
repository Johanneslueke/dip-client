package utility

import (
	"flag"
	"os"
)

// SyncConfig holds common configuration for all sync commands
type SyncConfig struct {
	BaseURL       string
	APIKey        string
	DBPath        string
	Limit         int
	CheckpointDir string
	FailedDir     string
	Resume        bool
	End           string
	ResourceName  string // e.g., "vorgaenge", "drucksachen", etc.
	Wahlperiode   string
	VorgangID     int
}

// ParseSyncFlags parses command-line flags common to all sync commands
func ParseSyncFlags(resourceName string) *SyncConfig {
	config := &SyncConfig{
		ResourceName: resourceName,
	}

	flag.StringVar(&config.BaseURL, "url", "https://search.dip.bundestag.de/api/v1", "API base URL")
	flag.StringVar(&config.APIKey, "key", "", "API key")
	flag.StringVar(&config.DBPath, "db", "dip.db", "SQLite database path")
	flag.IntVar(&config.Limit, "limit", 0, "Maximum number of items to fetch (0 = all)")
	flag.StringVar(&config.CheckpointDir, "checkpoint-dir", ".checkpoints", "Directory to store checkpoints")
	flag.StringVar(&config.FailedDir, "failed-dir", ".failed", "Directory to store failed record IDs")
	flag.BoolVar(&config.Resume, "resume", false, "Resume from last checkpoint")
	flag.StringVar(&config.End, "end", "", "End date for sync (YYYY-MM-DD)")
	flag.StringVar(&config.Wahlperiode, "wahlperiode", "", "Filter by Wahlperiode numbers (comma-separated, e.g. '19,20' or empty = no filter)")
	flag.IntVar(&config.VorgangID, "vorgang-id", 0, "Filter by specific Vorgang ID (0 = no filter)")
	
	flag.Parse()

	// Try environment variable if API key not provided
	if config.APIKey == "" {
		config.APIKey = os.Getenv("DIP_API_KEY")
	}

	return config
}

// Validate checks if required configuration is present
func (c *SyncConfig) Validate() error {
	if c.APIKey == "" {
		return &ConfigError{Field: "APIKey", Message: "API key required (use -key flag or DIP_API_KEY environment variable)"}
	}
	if c.ResourceName == "" {
		return &ConfigError{Field: "ResourceName", Message: "ResourceName must be set"}
	}
	return nil
}

// ConfigError represents a configuration validation error
type ConfigError struct {
	Field   string
	Message string
}

func (e *ConfigError) Error() string {
	return e.Message
}
