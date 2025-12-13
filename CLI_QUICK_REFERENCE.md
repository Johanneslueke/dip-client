# DIP CLI Quick Reference

## Common Use Cases

### Basic Queries

```bash
# List all Vorgänge
./dip -key YOUR_KEY -endpoint vorgang -list

# Get a specific Vorgang by ID
./dip -key YOUR_KEY -endpoint vorgang -id 123456

# List with custom format
./dip -key YOUR_KEY -endpoint drucksache -list -format xml
```

### Wahlperiode Filtering

```bash
# Filter by Wahlperiode
./dip -key YOUR_KEY -endpoint vorgang -list -wahlperiode 20
./dip -key YOUR_KEY -endpoint aktivitaet -list -wahlperiode 21
```

### Document Filters

```bash
# Filter by document number
./dip -key YOUR_KEY -endpoint drucksache -list -f.dokumentnummer "19/24359"

# Filter by document type
./dip -key YOUR_KEY -endpoint aktivitaet -list -f.dokumentart "Drucksache" -wahlperiode 20

# Filter by Drucksache type
./dip -key YOUR_KEY -endpoint vorgang -list -f.drucksachetyp "Antrag" -wahlperiode 20
```

### Entity ID Filters

```bash
# Filter by entity ID
./dip -key YOUR_KEY -endpoint aktivitaet -list -f.id 318274

# Filter by related Drucksache ID
./dip -key YOUR_KEY -endpoint vorgang -list -f.drucksache 123456

# Filter by related Plenarprotokoll ID
./dip -key YOUR_KEY -endpoint aktivitaet -list -f.plenarprotokoll 789
```

### Advanced Filters

```bash
# Filter by assignment (Bundestag/Bundesrat/etc)
./dip -key YOUR_KEY -endpoint drucksache -list -f.zuordnung "BT" -wahlperiode 20

# Filter by question number
./dip -key YOUR_KEY -endpoint aktivitaet -list -f.frage_nummer "12" -wahlperiode 20

# Filter by GESTA number (Vorgang only)
./dip -key YOUR_KEY -endpoint vorgang -list -f.gesta "N001"
```

### Combining Multiple Filters

```bash
# Wahlperiode + Drucksachetyp
./dip -key YOUR_KEY -endpoint vorgang -list -wahlperiode 20 -f.drucksachetyp "Antrag"

# Multiple filters for precise queries
./dip -key YOUR_KEY -endpoint vorgangsposition -list \
  -wahlperiode 20 \
  -f.drucksachetyp "Antrag" \
  -f.zuordnung "BT" \
  -f.dokumentart "Drucksache"

# Complex filter combination
./dip -key YOUR_KEY -endpoint aktivitaet -list \
  -wahlperiode 20 \
  -f.drucksache 123456 \
  -f.dokumentart "Drucksache" \
  -f.zuordnung "BT"
```

### Pagination

```bash
# First page (no cursor)
./dip -key YOUR_KEY -endpoint vorgang -list -wahlperiode 20 > page1.json

# Extract cursor from response
CURSOR=$(jq -r '.cursor' page1.json)

# Get next page
./dip -key YOUR_KEY -endpoint vorgang -list -wahlperiode 20 -cursor "$CURSOR" > page2.json

# Continue until cursor doesn't change
```

### Piping and Processing

```bash
# Count results
./dip -key YOUR_KEY -endpoint vorgang -list -wahlperiode 20 | jq '.documents | length'

# Extract specific fields
./dip -key YOUR_KEY -endpoint drucksache -list -wahlperiode 20 | \
  jq '.documents[] | {titel: .titel, datum: .datum}'

# Filter results further with jq
./dip -key YOUR_KEY -endpoint vorgang -list -wahlperiode 20 | \
  jq '.documents[] | select(.beratungsstand == "Angenommen")'

# Get first N results
./dip -key YOUR_KEY -endpoint aktivitaet -list | jq '.documents[:10]'
```

### Using Environment Variables

```bash
# Set API key once
export DIP_API_KEY="your-api-key-here"

# Now you can omit -key flag
./dip -endpoint vorgang -list -wahlperiode 20
./dip -endpoint drucksache -id 123456
```

## Filter Support Matrix

| Endpoint             | wahlperiode | id  | drucksache | plenarprotokoll | dokumentnummer | dokumentart | drucksachetyp | frage_nummer | zuordnung | gesta |
| -------------------- | ----------- | --- | ---------- | --------------- | -------------- | ----------- | ------------- | ------------ | --------- | ----- |
| aktivitaet           | ✓           | ✓   | ✓          | ✓               | ✓              | ✓           | ✓             | ✓            | ✓         | -     |
| drucksache           | ✓           | ✓   | -          | -               | ✓              | -           | ✓             | -            | ✓         | -     |
| drucksache-text      | ✓           | ✓   | -          | -               | ✓              | -           | ✓             | -            | ✓         | -     |
| person               | ✓           | ✓   | -          | -               | -              | -           | -             | -            | -         | -     |
| plenarprotokoll      | ✓           | ✓   | -          | -               | ✓              | -           | -             | -            | ✓         | -     |
| plenarprotokoll-text | ✓           | ✓   | -          | -               | ✓              | -           | -             | -            | ✓         | -     |
| vorgang              | ✓           | ✓   | ✓          | ✓               | ✓              | ✓           | ✓             | ✓            | -         | ✓     |
| vorgangsposition     | ✓           | ✓   | ✓          | ✓               | ✓              | ✓           | ✓             | ✓            | ✓         | -     |

## Tips and Tricks

### 1. Save Results for Later

```bash
# Save raw JSON
./dip -key $DIP_API_KEY -endpoint vorgang -list -wahlperiode 20 > vorgaenge_wp20.json

# Save formatted output
./dip -key $DIP_API_KEY -endpoint drucksache -list | jq '.' > drucksachen.json
```

### 2. Bash Script for Pagination

```bash
#!/bin/bash
KEY="your-api-key"
ENDPOINT="vorgang"
CURSOR=""

while true; do
  if [ -z "$CURSOR" ]; then
    RESPONSE=$(./dip -key $KEY -endpoint $ENDPOINT -list -wahlperiode 20)
  else
    RESPONSE=$(./dip -key $KEY -endpoint $ENDPOINT -list -wahlperiode 20 -cursor "$CURSOR")
  fi

  echo "$RESPONSE" | jq '.documents[]' >> all_results.jsonl

  NEW_CURSOR=$(echo "$RESPONSE" | jq -r '.cursor')
  if [ "$NEW_CURSOR" == "$CURSOR" ]; then
    break
  fi
  CURSOR="$NEW_CURSOR"
done
```

### 3. Finding Specific Content

```bash
# Search for specific text in titles
./dip -key $DIP_API_KEY -endpoint drucksache -list -wahlperiode 20 | \
  jq '.documents[] | select(.titel | contains("Klimaschutz"))'

# Find documents by date range (post-processing)
./dip -key $DIP_API_KEY -endpoint drucksache -list -wahlperiode 20 | \
  jq '.documents[] | select(.datum >= "2023-01-01" and .datum <= "2023-12-31")'
```

### 4. Combining with Other Tools

```bash
# Convert to CSV
./dip -key $DIP_API_KEY -endpoint drucksache -list -wahlperiode 20 | \
  jq -r '.documents[] | [.id, .titel, .datum] | @csv' > drucksachen.csv

# Count by type
./dip -key $DIP_API_KEY -endpoint drucksache -list -wahlperiode 20 | \
  jq '.documents | group_by(.drucksachetyp) | map({typ: .[0].drucksachetyp, count: length})'
```

## Error Handling

### Common Errors

```bash
# Invalid API key (401)
./dip -key INVALID -endpoint vorgang -list
# Error: unexpected status code: 401

# Invalid endpoint
./dip -key $DIP_API_KEY -endpoint invalid -list
# Error: unknown endpoint: invalid

# Missing required flag
./dip -key $DIP_API_KEY -id 123
# Error: -endpoint is required
```

### Validation

```bash
# Check if API key is valid
if ./dip -key $DIP_API_KEY -endpoint vorgang -list > /dev/null 2>&1; then
  echo "API key is valid"
else
  echo "API key is invalid or API is down"
fi
```

## Performance Tips

1. **Use specific filters** to reduce result set size
2. **Paginate properly** - don't try to fetch all results at once
3. **Cache results** when possible - the API data doesn't change frequently
4. **Use wahlperiode filter** - it significantly reduces the result set
5. **Combine filters** to narrow down results before post-processing with jq
