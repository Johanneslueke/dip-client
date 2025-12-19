# XML DTD Validator

A Go command-line tool to validate XML files against DTD (Document Type Definition) schemas.

## Purpose

This tool validates XML files to ensure they conform to their DTD schema. It's particularly useful for:

- Validating MdB-Stammdaten XML files against `MDB_STAMMDATEN.DTD`
- Checking XML structure and completeness
- Debugging XML parsing issues
- Getting XML statistics and structure summaries

## Usage

```bash
# Basic validation (auto-detects DTD from XML DOCTYPE)
validate-xml-dtd -xml MdB-Stammdaten/MDB_STAMMDATEN.XML

# Validation with verbose output
validate-xml-dtd -xml MdB-Stammdaten/MDB_STAMMDATEN.XML -v

# Validation with summary statistics
validate-xml-dtd -xml MdB-Stammdaten/MDB_STAMMDATEN.XML -s

# Validation with verbose output and summary
validate-xml-dtd -xml MdB-Stammdaten/MDB_STAMMDATEN.XML -v -s

# Specify DTD file explicitly
validate-xml-dtd -xml MdB-Stammdaten/MDB_STAMMDATEN.XML -dtd MdB-Stammdaten/MDB_STAMMDATEN.DTD -v -s
```

## Options

- `-xml <path>` - Path to XML file to validate (required)
- `-dtd <path>` - Path to DTD file (optional, auto-detected from XML DOCTYPE if not provided)
- `-v` - Verbose output (show validation process details)
- `-s` - Show summary statistics about XML structure (element counts, etc.)

## Output

### Successful Validation

```
Validating XML file: MdB-Stammdaten/MDB_STAMMDATEN.XML
XML parsed successfully
✅ XML is valid according to DTD
```

### With Summary (`-s` flag)

```
📊 XML Structure Summary:
==================================================
Root element: DOCUMENT
Total elements: 452583
Unique element types: 35

Top-level element counts:
  MDB                 : 4521
  VERSION             : 1
  WAHLPERIODE         : 12456
  INSTITUTION         : 8934
  NAME                : 4521

Other significant elements:
  BIOGRAFISCHE_ANGABEN    : 4521
  WAHLPERIODEN            : 4521
  INSTITUTIONEN           : 12456
  NACHNAME                : 4521
  VORNAME                 : 4521
  PARTEI_KURZ             : 4521
  WP                      : 12456
```

### Validation Error

```
Validation failed: XML parsing/validation error: Element NACHNAME content does not follow the DTD
```

## Building

```bash
# From project root
go build -o bin/validate-xml-dtd ./cmd/validate-xml-dtd

# Or use go run
go run ./cmd/validate-xml-dtd/main.go -xml MdB-Stammdaten/MDB_STAMMDATEN.XML
```

## Dependencies

This tool uses the `libxml2` library through Go bindings:

- `github.com/lestrrat-go/libxml2` - Go bindings for libxml2

The `libxml2` C library must be installed on your system:

```bash
# Ubuntu/Debian
sudo apt-get install libxml2-dev

# macOS
brew install libxml2

# Fedora/RHEL
sudo dnf install libxml2-devel
```

## Technical Details

The validator:

1. Parses XML with DTD validation enabled (`XMLParseDTDValid`)
2. Loads external DTD files (`XMLParseDTDLoad`)
3. Auto-detects DTD from XML `<!DOCTYPE SYSTEM "...">` declaration
4. Reports validation errors with line numbers (if available)
5. Optionally provides XML structure statistics

## Error Handling

Common errors and solutions:

1. **"XML file not found"** - Check the file path
2. **"Element X content does not follow the DTD"** - Element violates DTD constraints
3. **"No declaration for element X"** - Element not defined in DTD
4. **"No declaration for attribute Y"** - Attribute not allowed by DTD

## Integration with DIP Database

This tool is part of the DIP database toolkit and complements:

- Person data import from MdB-Stammdaten XML
- Database schema validation
- Data quality checks

## Example: MDB_STAMMDATEN.XML

The MdB-Stammdaten XML file contains biographical data for all Bundestag members (MdB):

- **Root**: `<DOCUMENT>` with version and multiple `<MDB>` entries
- **Structure**: Each `<MDB>` has ID, names, biographical data, and Wahlperioden
- **DTD**: `MDB_STAMMDATEN.DTD` defines all allowed elements and attributes
- **Size**: ~450,000+ elements for all parliamentarians from WP1-21

## Performance

- Small files (<1MB): <100ms
- Medium files (1-10MB): <1s
- Large files (>10MB): 1-5s
- MDB_STAMMDATEN.XML (~50MB, 450K elements): ~2-3s

## License

Part of the DIP database project.
