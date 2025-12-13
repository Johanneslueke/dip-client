# DIP API Client

Go client library and command-line tools for the German Bundestag's DIP (Dokumentations- und Informationssystem für Parlamentsmaterialien) API.

## Table of Contents

- [Quick Start](#quick-start)
- [Installation](#installation)
- [Library Usage](#library-usage)
- [Command-Line Tools](#command-line-tools)
  - [Unified CLI Tool](#unified-cli-tool)
  - [Individual Endpoint Tools](#individual-endpoint-tools)
- [Testing](#testing)
- [Project Structure](#project-structure)
- [Code Generation](#code-generation)
- [Additional Documentation](#additional-documentation)
- [Features](#features)

## Quick Start

```bash
# Install the package
go get github.com/Johanneslueke/dip-client

# Build the unified CLI tool
cd $GOPATH/src/github.com/Johanneslueke/dip-client
go build -o dip ./cmd/dip

# Set your API key (get one from https://dip.bundestag.de)
export DIP_API_KEY="your-api-key"

# List Vorgänge from Wahlperiode 20
./dip -endpoint vorgang -list -wahlperiode 20

# Get a specific Drucksache
./dip -endpoint drucksache -id 283847
```

## Installation

```bash
go get github.com/Johanneslueke/dip-client
```

## Library Usage

```go
package main

import (
    "context"
    "fmt"
    "log"

    dipclient "github.com/Johanneslueke/dip-client/pkg/dip-client"
)

func main() {
    // Create client
    client, err := dipclient.New(dipclient.Config{
        BaseURL: "https://search.dip.bundestag.de/api/v1",
        APIKey:  "your-api-key",
    })
    if err != nil {
        log.Fatal(err)
    }

    // Get a Vorgang by ID
    ctx := context.Background()
    vorgang, err := client.GetVorgang(ctx, dipclient.Id(12345), nil)
    if err != nil {
        log.Fatal(err)
    }

    fmt.Printf("Vorgang: %+v\n", vorgang)
}
```

## Command-Line Tools

### Unified CLI Tool

The `dip` command provides a single interface to all API endpoints.

#### Build

```bash
go build -o dip ./cmd/dip
```

#### Usage

```bash
# List resources
./dip -key YOUR_KEY -endpoint aktivitaet -list
./dip -key YOUR_KEY -endpoint person -list
./dip -key YOUR_KEY -endpoint vorgang -list

# Get single resource by ID
./dip -key YOUR_KEY -endpoint person -id 123
./dip -key YOUR_KEY -endpoint vorgang -id 456
./dip -key YOUR_KEY -endpoint drucksache -id 789

# Filter by Wahlperiode
./dip -key YOUR_KEY -endpoint vorgang -list -wahlperiode 20
./dip -key YOUR_KEY -endpoint aktivitaet -list -wahlperiode 21

# Pagination with cursor
./dip -key YOUR_KEY -endpoint vorgang -list -cursor "AoJw-IOX3JUDLlZvcmdhbmctMzIxMjc1"

# Combine multiple filters
./dip -key YOUR_KEY -endpoint vorgang -list -wahlperiode 20 -f.drucksachetyp "Antrag"

# Filter by ID
./dip -key YOUR_KEY -endpoint aktivitaet -list -f.id 318274

# Filter by Dokumentnummer
./dip -key YOUR_KEY -endpoint drucksache -list -f.dokumentnummer "19/24359"

# Filter by GESTA (Vorgang only)
./dip -key YOUR_KEY -endpoint vorgang -list -f.gesta "N001"

# Filter by Dokumentart (enum)
./dip -key YOUR_KEY -endpoint aktivitaet -list -f.dokumentart "Drucksache" -wahlperiode 20
```

#### Flags

**Required:**

- `-endpoint`: Resource type (required)
- `-key`: API key (can also be set via `DIP_API_KEY` environment variable)

**Resource Selection:**

- `-id`: Resource ID (required for single-resource queries)
- `-list`: List resources instead of getting a single one

**Query Parameters (for list operations):**

Common filters:

- `-wahlperiode`: Filter by Wahlperiode number (e.g., 20, 21)
- `-cursor`: Cursor for pagination (get from previous response)
- `-format`: Response format: `json` (default) or `xml`

Advanced filters (support varies by endpoint):

- `-f.id`: Filter by entity ID (integer)
- `-f.drucksache`: Filter by Drucksache ID (integer)
- `-f.plenarprotokoll`: Filter by Plenarprotokoll ID (integer)
- `-f.dokumentnummer`: Filter by document number (string, e.g., "19/24359")
- `-f.dokumentart`: Filter by document type - "Drucksache" or "Plenarprotokoll" (enum)
- `-f.drucksachetyp`: Filter by Drucksache type (string, e.g., "Antrag")
- `-f.frage_nummer`: Filter by question number (string)
- `-f.zuordnung`: Filter by assignment (BT/BR/BV/EK)
- `-f.gesta`: Filter by GESTA number (string, Vorgang only)

**Connection:**

- `-url`: API base URL (default: `https://search.dip.bundestag.de/api/v1`)

**Filter Support by Endpoint:**

| Filter          | aktivitaet | drucksache | drucksache-text | person | plenarprotokoll | plenarprotokoll-text | vorgang | vorgangsposition |
| --------------- | ---------- | ---------- | --------------- | ------ | --------------- | -------------------- | ------- | ---------------- |
| wahlperiode     | ✓          | ✓          | ✓               | ✓      | ✓               | ✓                    | ✓       | ✓                |
| id              | ✓          | ✓          | ✓               | ✓      | ✓               | ✓                    | ✓       | ✓                |
| drucksache      | ✓          | -          | -               | -      | -               | -                    | ✓       | ✓                |
| plenarprotokoll | ✓          | -          | -               | -      | -               | -                    | ✓       | ✓                |
| dokumentnummer  | ✓          | ✓          | ✓               | -      | ✓               | ✓                    | ✓       | ✓                |
| dokumentart     | ✓          | -          | -               | -      | -               | -                    | ✓       | ✓                |
| drucksachetyp   | ✓          | ✓          | ✓               | -      | -               | -                    | ✓       | ✓                |
| frage_nummer    | ✓          | -          | -               | -      | -               | -                    | ✓       | ✓                |
| zuordnung       | ✓          | ✓          | ✓               | -      | ✓               | ✓                    | -       | ✓                |
| gesta           | -          | -          | -               | -      | -               | -                    | ✓       | -                |

#### Supported Endpoints

- `aktivitaet` - Parliamentary activities
- `drucksache` - Printed documents
- `drucksache-text` - Document texts
- `person` - Persons (MPs, etc.)
- `plenarprotokoll` - Plenary protocols
- `plenarprotokoll-text` - Protocol texts
- `vorgang` - Legislative processes
- `vorgangsposition` - Process positions

#### Using Environment Variables

Set your API key as an environment variable:

```bash
export DIP_API_KEY="your-api-key"
./dip -endpoint vorgang -id 123
./dip -endpoint person -list
```

### Individual Endpoint Tools

Individual command-line tools are available for each endpoint. Each tool provides focused functionality for a specific resource type.

#### Available Tools

**Get Operations** (retrieve single resource by ID):
- `get-aktivitaet` - Get a single Aktivität
- `get-drucksache` - Get a single Drucksache
- `get-drucksache-text` - Get a single Drucksache text
- `get-person` - Get a single Person
- `get-plenarprotokoll` - Get a single Plenarprotokoll
- `get-plenarprotokoll-text` - Get a single Plenarprotokoll text
- `get-vorgang` - Get a single Vorgang
- `get-vorgangsposition` - Get a single Vorgangsposition

**List Operations** (retrieve multiple resources):
- `list-aktivitaeten` - List all Aktivitäten
- `list-drucksachen` - List all Drucksachen
- `list-drucksache-texte` - List all Drucksache texts
- `list-personen` - List all Personen
- `list-plenarprotokolle` - List all Plenarprotokolle
- `list-plenarprotokoll-texte` - List all Plenarprotokoll texts
- `list-vorgaenge` - List all Vorgänge
- `list-vorgangspositionen` - List all Vorgangspositionen

#### Usage Examples

```bash
# Get single resources by ID
go run ./cmd/get-aktivitaet -key YOUR_KEY -id 318274
go run ./cmd/get-drucksache -key YOUR_KEY -id 283847
go run ./cmd/get-person -key YOUR_KEY -id 456
go run ./cmd/get-vorgang -key YOUR_KEY -id 123

# List resources
go run ./cmd/list-vorgaenge -key YOUR_KEY
go run ./cmd/list-aktivitaeten -key YOUR_KEY
go run ./cmd/list-drucksachen -key YOUR_KEY

# Using environment variable for API key
export DIP_API_KEY="your-api-key"
go run ./cmd/list-plenarprotokolle
go run ./cmd/get-vorgangsposition -id 789

# Build individual tools
go build -o get-vorgang ./cmd/get-vorgang
./get-vorgang -key YOUR_KEY -id 123
```

#### Common Flags (Individual Tools)

- `-key`: API key (or use `DIP_API_KEY` environment variable)
- `-url`: API base URL (default: `https://search.dip.bundestag.de/api/v1`)
- `-id`: Resource ID (required for get-* tools)

**Note:** Individual tools provide basic functionality. For advanced filtering and pagination, use the unified `dip` CLI tool.

## Testing

### Unit Tests

Run unit tests with:

```bash
go test ./pkg/dip-client -run Test_
```

Run with coverage:

```bash
go test ./pkg/dip-client -cover
```

### System Tests

System tests run against the real DIP API and verify end-to-end functionality:

```bash
# Run all tests including system tests
go test -v ./pkg/dip-client

# Run only system tests
go test -v ./pkg/dip-client -run TestSystem

# Skip system tests (for faster testing)
go test -short ./pkg/dip-client
```

**Note:** System tests use a provided API key by default but can be overridden with the `DIP_API_KEY` environment variable.

## Project Structure

```
.
├── cmd/                           # Command-line tools
│   ├── dip/                       # Unified CLI tool
│   ├── get-aktivitaet/            # Individual endpoint tools
│   ├── list-aktivitaeten/
│   ├── get-drucksache/
│   ├── list-drucksachen/
│   ├── get-drucksache-text/
│   ├── list-drucksache-texte/
│   ├── get-person/
│   ├── list-personen/
│   ├── get-plenarprotokoll/
│   ├── list-plenarprotokolle/
│   ├── get-plenarprotokoll-text/
│   ├── list-plenarprotokoll-texte/
│   ├── get-vorgang/
│   ├── list-vorgaenge/
│   ├── get-vorgangsposition/
│   └── list-vorgangspositionen/
├── internal/gen/                  # Generated OpenAPI client code
│   ├── client.gen.go
│   └── models.gen.go
├── pkg/dip-client/                # Public client library
│   ├── dip-client.go              # Main client with re-exported types
│   └── dip-client_test.go         # Tests (70.6% coverage)
├── openapi.yaml                   # OpenAPI specification
├── cfg_client.yaml                # Client generation config
├── cfg_models.yaml                # Models generation config
└── generate.go                    # Code generation script
```

## Code Generation

To regenerate the client from the OpenAPI spec:

```bash
go generate ./...
```

The generation uses `oapi-codegen` with configuration files:
- `cfg_client.yaml` - Client generation settings
- `cfg_models.yaml` - Model generation settings

## Additional Documentation

- **[CLI Quick Reference](CLI_QUICK_REFERENCE.md)** - Common use cases, examples, and tips for the CLI tool
- **[Filter Implementation](FILTER_IMPLEMENTATION.md)** - Technical details about filter support and implementation

## API Reference

For complete API documentation, see the [official DIP API documentation](https://dip.bundestag.de/%C3%BCber-dip/hilfe/api/).

## Features

- ✅ Full API coverage for all 8 endpoints
- ✅ Comprehensive filter support (10+ filter types)
- ✅ Type-safe client with re-exported types
- ✅ Both unified CLI and individual endpoint tools
- ✅ Pagination support with cursor
- ✅ JSON and XML output formats
- ✅ Environment variable support for API key
- ✅ Extensive test coverage (70.6%)
- ✅ Real API integration tests

## License

MIT License - See LICENSE file for details
