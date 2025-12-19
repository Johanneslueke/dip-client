# XML DTD Validator - Quick Reference

## Description

Command-line tool to validate XML files against DTD (Document Type Definition) schemas.

## Installation

```bash
# Build from source
go build -o bin/validate-xml-dtd ./cmd/validate-xml-dtd

# Requires libxml2 development libraries:
# Ubuntu/Debian: sudo apt-get install libxml2-dev
# macOS: brew install libxml2
# Fedora/RHEL: sudo dnf install libxml2-devel
```

## Basic Usage

```bash
# Simple validation
./bin/validate-xml-dtd -xml MdB-Stammdaten/MDB_STAMMDATEN.XML

# With summary statistics
./bin/validate-xml-dtd -xml MdB-Stammdaten/MDB_STAMMDATEN.XML -s

# Verbose output
./bin/validate-xml-dtd -xml MdB-Stammdaten/MDB_STAMMDATEN.XML -v

# Full details (verbose + summary)
./bin/validate-xml-dtd -xml MdB-Stammdaten/MDB_STAMMDATEN.XML -v -s

# Specify DTD explicitly
./bin/validate-xml-dtd -xml file.xml -dtd schema.dtd
```

## Using the Wrapper Script

```bash
# Same as above but cleaner syntax
./bin/validate-xml-dtd.sh -xml MdB-Stammdaten/MDB_STAMMDATEN.XML -s
```

## Options

| Flag          | Description                                         |
| ------------- | --------------------------------------------------- |
| `-xml <path>` | Path to XML file (required)                         |
| `-dtd <path>` | Path to DTD file (optional, auto-detected from XML) |
| `-v`          | Verbose output (show validation details)            |
| `-s`          | Show summary statistics (element counts)            |

## Output Examples

### Success

```
✅ XML is valid according to DTD
```

### With Summary (-s)

```
📊 XML Structure Summary:
==================================================
Root element: DOCUMENT
Total elements: 386484
Unique element types: 46

Top-level element counts:
  MDB                 : 4613
  VERSION             : 1
  WAHLPERIODE         : 13045
  INSTITUTION         : 16653
  NAME                : 4900

Other significant elements:
  BIOGRAFISCHE_ANGABEN     : 4613
  WAHLPERIODEN             : 4613
  INSTITUTIONEN            : 13045
  NACHNAME                 : 4900
  VORNAME                  : 4900
  PARTEI_KURZ              : 4613
  WP                       : 13045
✅ XML is valid according to DTD
```

### With Verbose (-v)

```
Validating XML file: MdB-Stammdaten/MDB_STAMMDATEN.XML
XML parsed successfully
Document encoding: UTF-8
✅ XML is valid according to DTD
```

### Validation Error

```
Validation failed: XML parsing/validation error: Element INVALID content does not follow the DTD
```

## Use Cases

1. **Validate MdB-Stammdaten XML**

   ```bash
   ./bin/validate-xml-dtd -xml MdB-Stammdaten/MDB_STAMMDATEN.XML -s
   ```

2. **Check XML Structure**

   ```bash
   # See element counts and structure
   ./bin/validate-xml-dtd -xml file.xml -s
   ```

3. **Debug XML Issues**

   ```bash
   # Verbose output shows parsing details
   ./bin/validate-xml-dtd -xml file.xml -v
   ```

4. **Automated Testing**
   ```bash
   # Use in CI/CD pipelines
   if ./bin/validate-xml-dtd -xml data.xml; then
       echo "Valid XML"
   else
       echo "Invalid XML"
       exit 1
   fi
   ```

## Technical Details

- **Parser**: Uses `libxml2` with DTD validation enabled
- **Performance**: ~2-3s for 50MB XML with 450K+ elements
- **Memory**: Efficient streaming parser, minimal memory overhead
- **Auto-detection**: Reads DTD path from XML `<!DOCTYPE SYSTEM "...">` declaration

## Troubleshooting

**"libxml2 not found"**

```bash
# Install libxml2 development package
sudo apt-get install libxml2-dev  # Ubuntu/Debian
brew install libxml2               # macOS
```

**"I/O error: failed to load external entity"**

- DTD file not found in same directory as XML
- Use `-dtd` flag to specify full path to DTD file

**"Validation failed: no DTD found"**

- XML doesn't have `<!DOCTYPE>` declaration
- Specify DTD explicitly with `-dtd` flag

## Integration

Part of the DIP database toolkit, complements:

- Person data import from XML
- Database schema validation
- Data quality checks

## MDB_STAMMDATEN.XML Statistics

Based on September 2025 data:

- **File size**: ~50 MB
- **Total elements**: 386,484
- **Unique element types**: 46
- **MdB entries**: 4,613 parliamentarians
- **Wahlperioden**: 13,045 entries
- **Institutions**: 16,653 memberships
- **Validation time**: ~2-3 seconds

## Related Commands

```bash
# List all validators in the project
ls -lh bin/*validate*

# Check XML file size
ls -lh MdB-Stammdaten/MDB_STAMMDATEN.XML

# Count MdB entries
grep -c "<MDB>" MdB-Stammdaten/MDB_STAMMDATEN.XML

# Extract DTD version
grep VERSION MdB-Stammdaten/MDB_STAMMDATEN.XML | head -1
```

## See Also

- `cmd/validate-xml-dtd/README.md` - Detailed documentation
- `MdB-Stammdaten/MDB_STAMMDATEN.DTD` - DTD schema definition
- DIP database documentation
