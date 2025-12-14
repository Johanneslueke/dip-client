package main

import (
	"database/sql"
	"flag"
	"fmt"
	"log"
	"os"
	"os/exec"
	"strings"
	"time"

	"github.com/Johanneslueke/dip-client/internal/utility"
	_ "modernc.org/sqlite"
)

type SyncCommand struct {
	Name        string
	Description string
	BinaryPath  string
	Enabled     bool
}

var syncCommands = []SyncCommand{
	{Name: "personen", Description: "Sync persons (Personen)", BinaryPath: "./bin/sync-personen", Enabled: true},
	{Name: "vorgaenge", Description: "Sync procedures (Vorgänge)", BinaryPath: "./bin/sync-vorgaenge", Enabled: true},
	{Name: "vorgangspositionen", Description: "Sync procedure positions (Vorgangspositionen)", BinaryPath: "./bin/sync-vorgangspositionen", Enabled: true},
	{Name: "aktivitaeten", Description: "Sync activities (Aktivitäten)", BinaryPath: "./bin/sync-aktivitaeten", Enabled: true},
	{Name: "drucksachen", Description: "Sync printed documents (Drucksachen)", BinaryPath: "./bin/sync-drucksachen", Enabled: true},
	{Name: "drucksache-texte", Description: "Sync printed document texts (Drucksache-Texte)", BinaryPath: "./bin/sync-drucksache-texte", Enabled: true},
	{Name: "plenarprotokolle", Description: "Sync plenary protocols (Plenarprotokolle)", BinaryPath: "./bin/sync-plenarprotokolle", Enabled: true},
	{Name: "plenarprotokoll-texte", Description: "Sync plenary protocol texts (Plenarprotokoll-Texte)", BinaryPath: "./bin/sync-plenarprotokoll-texte", Enabled: true},
}

func main() {
	var (
		apiKey          = flag.String("key", "", "API key")
		dbPath          = flag.String("db", "dip.db", "SQLite database path")
		limit           = flag.Int("limit", 0, "Maximum number of records per sync (0 = all)")
		skipList        = flag.String("skip", "", "Comma-separated list of syncs to skip")
		onlyList        = flag.String("only", "", "Comma-separated list of syncs to run")
		dryRun          = flag.Bool("dry-run", false, "Show plan without running")
		continueOnError = flag.Bool("continue", false, "Continue if sync fails")
	)
	flag.Parse()

	if *apiKey == "" {
		*apiKey = os.Getenv("DIP_API_KEY")
	}
	if *apiKey == "" {
		log.Fatal("API key required")
	}

	sqlDB, err := sql.Open("sqlite", *dbPath)
	if err != nil {
		log.Fatalf("Failed to open database: %v", err)
	}
	defer sqlDB.Close()

	if err := utility.RunMigrations(sqlDB); err != nil {
		log.Fatalf("Failed to run migrations: %v", err)
	}

	skipMap := make(map[string]bool)
	if *skipList != "" {
		for _, name := range strings.Split(*skipList, ",") {
			skipMap[strings.TrimSpace(name)] = true
		}
	}

	onlyMap := make(map[string]bool)
	if *onlyList != "" {
		for _, name := range strings.Split(*onlyList, ",") {
			onlyMap[strings.TrimSpace(name)] = true
		}
	}

	var commandsToRun []SyncCommand
	for _, cmd := range syncCommands {
		if !cmd.Enabled || skipMap[cmd.Name] {
			continue
		}
		if len(onlyMap) > 0 && !onlyMap[cmd.Name] {
			continue
		}
		commandsToRun = append(commandsToRun, cmd)
	}

	if len(commandsToRun) == 0 {
		log.Fatal("No sync commands to run")
	}

	fmt.Println("═══════════════════════════════════════════════════════════════════════")
	fmt.Println("DIP Sync All - Comprehensive Data Synchronization")
	fmt.Println("═══════════════════════════════════════════════════════════════════════")
	fmt.Printf("Database: %s\n", *dbPath)
	fmt.Printf("Limit per sync: %d (0 = all)\n", *limit)
	fmt.Println("\nPlanned sync operations:")
	for i, cmd := range commandsToRun {
		fmt.Printf("  [%d] %s - %s\n", i+1, cmd.Name, cmd.Description)
	}
	fmt.Println("═══════════════════════════════════════════════════════════════════════")

	if *dryRun {
		fmt.Println("\nDry run mode - no syncs performed")
		return
	}

	fmt.Println()

	// Setup signal handling for Ctrl-C
	signalHandler := utility.NewSignalHandler(nil, nil)
	defer signalHandler.Stop()

	startTime := time.Now()
	var successCount, failCount int
	var failedCommands []string

	for i, cmd := range commandsToRun {
		// Check if interrupted before starting next sync
		if signalHandler.IsInterrupted() {
			fmt.Println("\n⚠️  Skipping remaining syncs due to interrupt")
			failCount = len(commandsToRun) - i
			for j := i; j < len(commandsToRun); j++ {
				failedCommands = append(failedCommands, commandsToRun[j].Name)
			}
			break
		}
		fmt.Printf("\n[%d/%d] Running: %s\n", i+1, len(commandsToRun), cmd.Description)
		fmt.Println("───────────────────────────────────────────────────────────────────────")

		cmdStart := time.Now()

		args := []string{"--key", *apiKey, "--db", *dbPath}
		if *limit > 0 {
			args = append(args, "--limit", fmt.Sprintf("%d", *limit))
		}

		execCmd := exec.Command(cmd.BinaryPath, args...)
		execCmd.Stdout = os.Stdout
		execCmd.Stderr = os.Stderr

		// Register command with signal handler
		signalHandler.SetCurrentCommand(execCmd)

		err := execCmd.Run()
		signalHandler.ClearCurrentCommand()
		cmdDuration := time.Since(cmdStart)

		if err != nil {
			failCount++
			failedCommands = append(failedCommands, cmd.Name)
			fmt.Printf("❌ FAILED: %s (took %s)\n", cmd.Name, cmdDuration)
			fmt.Printf("   Error: %v\n", err)

			if !*continueOnError {
				fmt.Println("\n❌ Stopping due to error. Use --continue to continue on errors.")
				os.Exit(1)
			}
		} else {
			successCount++
			fmt.Printf("✅ COMPLETED: %s (took %s)\n", cmd.Name, cmdDuration)
		}
	}

	totalDuration := time.Since(startTime)

	fmt.Println("\n═══════════════════════════════════════════════════════════════════════")
	fmt.Println("Sync All - Summary")
	fmt.Println("═══════════════════════════════════════════════════════════════════════")
	fmt.Printf("Total time: %s\n", totalDuration)
	fmt.Printf("Successful: %d/%d\n", successCount, len(commandsToRun))
	fmt.Printf("Failed: %d/%d\n", failCount, len(commandsToRun))

	if len(failedCommands) > 0 {
		fmt.Println("\nFailed commands:")
		for _, name := range failedCommands {
			fmt.Printf("  - %s\n", name)
		}
		fmt.Println("═══════════════════════════════════════════════════════════════════════")
		os.Exit(1)
	}

	fmt.Println("\n✅ All syncs completed successfully!")
	fmt.Println("═══════════════════════════════════════════════════════════════════════")
}
