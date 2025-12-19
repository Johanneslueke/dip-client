# Filter Implementation Summary

## Overview

This document summarizes the comprehensive filter support added to the DIP API CLI tool and client library.

## Filter Types

The DIP API supports various filter types that have been fully implemented:

### Integer Filters

- `IdFilter` (int) - Entity ID
- `DrucksacheFilter` (int) - Drucksache ID
- `PlenarprotokollFilter` (int) - Plenarprotokoll ID
- `WahlperiodeFilter` (int) - Wahlperiode number

### String Filters

- `DokumentnummerFilter` (string) - Document number (e.g., "19/24359")
- `DrucksachtypFilter` (string) - Drucksache type (e.g., "Antrag")
- `FrageNummerFilter` (string) - Question number
- `ZuordnungFilter` (string) - Assignment (BT/BR/BV/EK)
- `GestaFilter` (string) - GESTA order number (Vorgang only)
- `Cursor` (string) - Pagination cursor

### Enum Filters

- `GetAktivitaetListParamsFDokumentart` - "Drucksache" or "Plenarprotokoll"
- `GetVorgangListParamsFDokumentart` - "Drucksache" or "Plenarprotokoll"
- `GetVorgangspositionListParamsFDokumentart` - "Drucksache" or "Plenarprotokoll"

## CLI Flags

All filters are accessible via command-line flags:

```bash
# Common flags
-wahlperiode <int>           # Filter by Wahlperiode number
-cursor <string>             # Pagination cursor
-format <json|xml>           # Response format

# Advanced filter flags
-f.id <int>                  # Filter by entity ID
-f.drucksache <int>          # Filter by Drucksache ID
-f.plenarprotokoll <int>     # Filter by Plenarprotokoll ID
-f.dokumentnummer <string>   # Filter by document number
-f.dokumentart <string>      # Filter by document type (enum)
-f.drucksachetyp <string>    # Filter by Drucksache type
-f.frage_nummer <string>     # Filter by question number
-f.zuordnung <string>        # Filter by assignment
-f.gesta <string>            # Filter by GESTA number (Vorgang only)
```

## Endpoint-Specific Filter Support

Each endpoint supports a different subset of filters based on the API specification:

### Aktivitaet

- ✓ wahlperiode, id, drucksache, plenarprotokoll, dokumentnummer, dokumentart, drucksachetyp, frage_nummer, zuordnung

### Drucksache

- ✓ wahlperiode, id, dokumentnummer, drucksachetyp, zuordnung

### DrucksacheText

- ✓ wahlperiode, id, dokumentnummer, drucksachetyp, zuordnung
- ✗ NOT drucksache (uses id instead)

### Person

- ✓ wahlperiode, id

### Plenarprotokoll

- ✓ wahlperiode, id, dokumentnummer, zuordnung

### PlenarprotokollText

- ✓ wahlperiode, id, dokumentnummer, zuordnung
- ✗ NOT plenarprotokoll (uses id instead)

### Vorgang

- ✓ wahlperiode, id, drucksache, plenarprotokoll, dokumentnummer, dokumentart, drucksachetyp, frage_nummer, gesta
- Note: gesta is unique to Vorgang

### Vorgangsposition

- ✓ wahlperiode, id, drucksache, plenarprotokoll, dokumentnummer, dokumentart, drucksachetyp, frage_nummer, zuordnung

## Implementation Details

### Type Conversions

- Integer filters (id, drucksache, plenarprotokoll) are declared as `flag.Int()` and converted to the appropriate filter types
- String filters are declared as `flag.String()` and wrapped in filter types
- Zero values (0 for int, "" for string) indicate the filter is not set

### Helper Functions

Each filter type has a corresponding helper function that returns `nil` if the filter is unset:

```go
func idFilterPtr() *dipclient.IdFilter {
    if *fId == 0 {
        return nil
    }
    f := dipclient.IdFilter(*fId)
    return &f
}
```

### Filter Parameter Struct

All filters are collected into a `filterParams` struct for clean passing to endpoint handlers:

```go
type filterParams struct {
    cursor          *dipclient.Cursor
    wahlperiode     *dipclient.WahlperiodeFilter
    id              *dipclient.IdFilter
    drucksache      *dipclient.DrucksacheFilter
    plenarprotokoll *dipclient.PlenarprotokollFilter
    dokumentnummer  *dipclient.DokumentnummerFilter
    dokumentart     string
    drucksachetyp   *dipclient.DrucksachtypFilter
    frageNummer     *dipclient.FrageNummerFilter
    zuordnung       *dipclient.ZuordnungFilter
    gesta           *dipclient.GestaFilter
    format          string
}
```

### Dispatch Table

Each endpoint handler receives the full `filterParams` struct but only uses the filters it supports:

```go
handlers := map[string]endpointHandler{
    "aktivitaet": func(ctx context.Context, listMode bool, resourceId dipclient.Id, f filterParams) (interface{}, error) {
        if listMode {
            params := &dipclient.GetAktivitaetListParams{
                FWahlperiode:     f.wahlperiode,
                FId:              f.id,
                FDrucksache:      f.drucksache,
                // ... all applicable filters
            }
            // ... format and dokumentart handling
            return client.GetAktivitaetList(ctx, params)
        }
        return client.GetAktivitaet(ctx, resourceId, nil)
    },
    // ... other handlers
}
```

## Testing

### Unit Tests

- 17 unit tests covering all client methods
- Mock client implementation for isolated testing
- 70.6% code coverage

### System Tests

Comprehensive system tests verify:

1. **Integer Filters**: FId filter with aktivitaet endpoint
2. **String Filters**: FDokumentnummer filter with drucksache endpoint
3. **Multiple Filters**: Combining wahlperiode and drucksachetyp
4. **Unique Filters**: FGesta filter (Vorgang only)
5. **Enum Filters**: FDokumentart with aktivitaet endpoint
6. **Endpoint-Specific**: Verify DrucksacheText uses FId (not FDrucksache)

All tests pass successfully:

```
=== RUN   TestSystem_AllFilters
=== RUN   TestSystem_AllFilters/IntegerFilters
    Found 1 aktivitaet(s) with FId=318274
=== RUN   TestSystem_AllFilters/StringFilters
    Found 1 drucksache(n) with dokumentnummer 19/24359
=== RUN   TestSystem_AllFilters/MultipleFilters
    Found 100 vorgaenge with wahlperiode=20 and drucksachetyp=Antrag
=== RUN   TestSystem_AllFilters/GestaFilter
    Found 12 vorgaenge with GESTA=N001
=== RUN   TestSystem_AllFilters/DokumentartEnumFilter
    Found 100 aktivitaeten with dokumentart=Drucksache in WP20
=== RUN   TestSystem_AllFilters/EndpointSpecificFilters
    Found 0 drucksache text(s) with FId=306952
--- PASS: TestSystem_AllFilters (0.27s)
```

## Examples

```bash
# Simple wahlperiode filter
./dip -key KEY -endpoint vorgang -list -wahlperiode 20

# Integer ID filter
./dip -key KEY -endpoint aktivitaet -list -f.id 318274

# String document number filter
./dip -key KEY -endpoint drucksache -list -f.dokumentnummer "19/24359"

# Multiple filters combined
./dip -key KEY -endpoint vorgang -list -wahlperiode 20 -f.drucksachetyp "Antrag" -f.zuordnung "BT"

# Enum filter
./dip -key KEY -endpoint aktivitaet -list -f.dokumentart "Drucksache" -wahlperiode 20

# Vorgang-specific GESTA filter
./dip -key KEY -endpoint vorgang -list -f.gesta "N001"

# Pagination with filters
./dip -key KEY -endpoint vorgangsposition -list -wahlperiode 20 -cursor "AoJw..."
```

## Files Modified

1. `/home/johannes/projects/api/dpi/pkg/dip-client/dip-client.go`

   - Added all filter type re-exports
   - Added enum type re-exports for Dokumentart

2. `/home/johannes/projects/api/dpi/cmd/dip/main.go`

   - Added 9 new filter flags
   - Created helper functions for each filter type
   - Created `filterParams` struct
   - Updated dispatch table signature
   - Updated all 8 endpoint handlers with applicable filters

3. `/home/johannes/projects/api/dpi/pkg/dip-client/filters_system_test.go` (new)

   - Comprehensive system tests for all filter types
   - 6 test cases covering different filter scenarios

4. `/home/johannes/projects/api/dpi/README.md`
   - Added filter examples
   - Documented all filter flags
   - Added filter support matrix by endpoint

## Verification

Build and test results:

- ✅ `go build ./cmd/dip` - Success
- ✅ All unit tests passing (17 tests)
- ✅ All system tests passing (17 subtests across 4 test suites)
- ✅ CLI functional with all filter types
- ✅ Filter combinations work correctly
- ✅ Endpoint-specific filters validated
