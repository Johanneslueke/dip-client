package utility

import (
	"database/sql"
	"fmt"
	"log"

	"github.com/pressly/goose/v3"
)

func RunMigrations(sqlDB *sql.DB) error {
	if err := goose.SetDialect("sqlite3"); err != nil {
		return fmt.Errorf("failed to set goose dialect: %w", err)
	}

	migrationsDir := "internal/database/migrations/sqlite"
	if err := goose.Up(sqlDB, migrationsDir); err != nil {
		return fmt.Errorf("failed to run migrations: %w", err)
	}

	log.Printf("Successfully ran all database migrations")
	return nil
}
