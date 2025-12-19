# Checkpoint System for Resumable Syncs

## Overview

The checkpoint system enables all sync commands to be interrupted gracefully and resumed later, making it safe to sync large datasets over unreliable connections or stop long-running syncs without losing progress.

## Architecture

### Components

1. **Checkpoint Utility** (`internal/utility/checkpoint.go`)

   - `SaveCheckpoint(dir, name, date)` - Persists sync state to JSON file
   - `LoadCheckpoint(dir, name)` - Loads existing checkpoint
   - `DeleteCheckpoint(dir, name)` - Removes checkpoint after successful completion

2. **Signal Handler** (`internal/utility/signal.go`)

   - Intercepts SIGINT (Ctrl+C) and SIGTERM signals
   - First signal: Executes callback (saves checkpoint), then graceful exit
   - Second signal: Force kill with immediate exit
   - Thread-safe with mutex protection

3. **Sync Command Integration**
   - All 8 sync commands support checkpoint functionality
   - Commands: `sync-personen`, `sync-vorgaenge`, `sync-vorgangspositionen`, `sync-aktivitaeten`, `sync-drucksachen`, `sync-drucksache-texte`, `sync-plenarprotokolle`, `sync-plenarprotokoll-texte`

## How It Works

### Checkpoint Storage

Checkpoints are stored as JSON files in `.checkpoints/` directory (default):

```json
{
  "last_sync_date": "2024-03-15T14:32:18Z",
  "updated_at": "2024-03-15T14:35:22Z"
}
```

Filename format: `{sync-name}.checkpoint.json`

Examples:

- `.checkpoints/drucksachen.checkpoint.json`
- `.checkpoints/aktivitaeten.checkpoint.json`
- `.checkpoints/personen.checkpoint.json`

### Date Tracking

Each sync command tracks the `Aktualisiert` field (last updated timestamp) of processed records:

```go
// Track the last processed date for checkpoint
if drucksache.Aktualisiert.After(lastProcessedDate) {
    lastProcessedDate = drucksache.Aktualisiert
}
```

This ensures the checkpoint captures the most recent record's timestamp.

### Signal Handling Flow

1. **User presses Ctrl+C (first time)**

   - Signal handler catches SIGINT
   - Executes `onFirstSignal` callback:
     - Sets `interrupted` flag
     - Saves checkpoint with `lastProcessedDate`
     - Logs checkpoint location
   - Main loop checks `interrupted` flag and exits cleanly

2. **User presses Ctrl+C (second time)**

   - Signal handler executes `onSecondSignal` callback (optional)
   - Kills any child process
   - Exits with code 130 immediately

3. **Successful completion**
   - Deletes checkpoint file automatically
   - Next run starts fresh (unless `--resume` is used)

### Resume Logic

When `--resume` flag is used:

```go
if *resume {
    checkpoint, err := utility.LoadCheckpoint(*checkpointDir, "drucksachen")
    if err != nil {
        log.Printf("Warning: Failed to load checkpoint: %v", err)
    } else if checkpoint != nil {
        datumEnd = &openapi_types.Date{Time: checkpoint.LastSyncDate}
        log.Printf("Resuming from checkpoint: %s", checkpoint.LastSyncDate.Format("2006-01-02"))
    }
}
```

The `FDatumEnd` parameter is set to the checkpoint date, filtering API results to only include records updated before that date, effectively continuing from where the sync was interrupted.

## Usage

### Basic Checkpoint Workflow

```bash
# Start syncing
./bin/sync-drucksachen
# Progress: 1500/50000 drucksachen...
# (Press Ctrl+C)
# Checkpoint saved at 2024-03-15

# Resume later
./bin/sync-drucksachen --resume
# Resuming from checkpoint: 2024-03-15
# Progress: 1500/50000 drucksachen...
# (Completes)
# Successfully stored 50000 drucksachen
```

### Command-Line Flags

All sync commands support these flags:

- `--checkpoint-dir string` - Directory to store checkpoints (default: `.checkpoints`)
- `--resume` - Resume from last checkpoint
- `--end string` - End date for sync in YYYY-MM-DD format (overrides checkpoint)

### Examples

```bash
# Custom checkpoint directory
./bin/sync-drucksachen --checkpoint-dir /tmp/checkpoints

# Resume from custom directory
./bin/sync-drucksachen --checkpoint-dir /tmp/checkpoints --resume

# Override checkpoint with explicit end date
./bin/sync-drucksachen --resume --end 2024-01-01
# (Will use 2024-01-01 instead of checkpoint date)

# Sync up to specific date (no checkpoint)
./bin/sync-aktivitaeten --end 2023-12-31
```

## API Filter Integration

The checkpoint system leverages the DIP API's `f.datum.end` filter parameter:

```
GET /api/v1/drucksache?f.datum.end=2024-03-15
```

This filter returns only records with `aktualisiert <= 2024-03-15`, allowing the sync to continue from exactly where it left off without duplicate processing.

## Advantages

1. **Safe Interruption** - Can stop sync at any time without data loss
2. **Network Resilience** - Resume after connection drops
3. **Resource Management** - Sync in smaller batches during off-hours
4. **Progress Visibility** - Always know where you left off
5. **Automatic Cleanup** - Checkpoints deleted on success, no manual maintenance

## Implementation Details

### Tracked Date Fields

Each entity type tracks its `Aktualisiert` field:

| Sync Command               | Tracked Field                        |
| -------------------------- | ------------------------------------ |
| sync-personen              | `person.Aktualisiert`                |
| sync-vorgaenge             | `vorgang.Aktualisiert`               |
| sync-vorgangspositionen    | `vorgangsposition.Aktualisiert`      |
| sync-aktivitaeten          | `aktivitaet.Aktualisiert`            |
| sync-drucksachen           | `drucksache.Datum` (or Aktualisiert) |
| sync-drucksache-texte      | `drucksacheText.Aktualisiert`        |
| sync-plenarprotokolle      | `plenarprotokoll.Aktualisiert`       |
| sync-plenarprotokoll-texte | `plenarprotokollText.Aktualisiert`   |

### Thread Safety

The signal handler uses a mutex to ensure thread-safe access to shared state:

```go
type SignalHandler struct {
    mu             sync.Mutex
    interrupted    bool
    currentCommand *exec.Cmd
    // ...
}
```

This prevents race conditions when checking interrupt status or updating command references.

### Graceful Exit

The main loop checks for interruption on each iteration:

```go
for {
    // Check if interrupted
    if signalHandler.IsInterrupted() || interrupted {
        fmt.Println()
        log.Printf("Interrupted after processing %d records", progress.Total)
        return
    }

    // ... process records
}
```

This ensures the program exits cleanly after saving the checkpoint, allowing database transactions to complete.

## Testing

### Manual Testing

```bash
# 1. Start a sync with limit
./bin/sync-drucksachen --limit 100

# 2. Observe checkpoint is NOT created (completed successfully)
ls .checkpoints/

# 3. Start a long sync
./bin/sync-drucksachen

# 4. After some progress, press Ctrl+C
# Output: Checkpoint saved at YYYY-MM-DD

# 5. Verify checkpoint file exists
cat .checkpoints/drucksachen.checkpoint.json

# 6. Resume sync
./bin/sync-drucksachen --resume

# 7. Let it complete
# Output: Successfully stored N drucksachen

# 8. Verify checkpoint is deleted
ls .checkpoints/drucksachen.checkpoint.json
# Output: No such file or directory
```

### Integration with sync-all

The `sync-all` command does NOT automatically use checkpoints, but individual sync commands can be resumed separately:

```bash
# Start sync-all, interrupt during drucksachen
./bin/sync-all
# (Press Ctrl+C while syncing drucksachen)

# Resume just the drucksachen sync
./bin/sync-drucksachen --resume

# Continue with next syncs manually
./bin/sync-drucksache-texte
./bin/sync-plenarprotokolle
# ... etc
```

Future enhancement: Add `--resume-all` flag to sync-all to resume each command from its checkpoint.

## Troubleshooting

### Checkpoint Not Loading

```bash
# Check if checkpoint exists
ls -la .checkpoints/

# Check checkpoint content
cat .checkpoints/drucksachen.checkpoint.json

# Verify date format is valid
jq '.last_sync_date' .checkpoints/drucksachen.checkpoint.json
```

### Checkpoint Directory Permission Issues

```bash
# Ensure directory is writable
chmod 755 .checkpoints

# Or specify different directory
./bin/sync-drucksachen --checkpoint-dir ~/my-checkpoints
```

### Stale Checkpoint

If you want to start fresh despite existing checkpoint:

```bash
# Option 1: Don't use --resume flag
./bin/sync-drucksachen
# (Ignores existing checkpoint)

# Option 2: Delete checkpoint manually
rm .checkpoints/drucksachen.checkpoint.json

# Option 3: Use --end to override
./bin/sync-drucksachen --resume --end 2024-12-31
```

## Future Enhancements

Potential improvements to consider:

1. **Checkpoint Expiration** - Auto-delete checkpoints older than N days
2. **Progress in Checkpoint** - Store record count in addition to date
3. **Multiple Checkpoints** - Support multiple database paths with separate checkpoints
4. **Checkpoint Metadata** - Include sync parameters (limit, filters) in checkpoint
5. **Resume All** - Add `--resume-all` flag to sync-all command
6. **Checkpoint Validation** - Verify checkpoint date against database state
7. **Compression** - Support gzip-compressed checkpoint files for large metadata

## Related Files

- `internal/utility/checkpoint.go` - Checkpoint persistence functions
- `internal/utility/signal.go` - Signal handling and interruption logic
- `cmd/sync-*/main.go` - All sync command implementations
- `CLI_QUICK_REFERENCE.md` - User-facing documentation
