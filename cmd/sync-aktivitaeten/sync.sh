#!/bin/bash
# sync-historical-drucksachen.sh

DB="dip.clean.db"
API_KEY="OSOegLs.PR2lwJ1dwCeje9vTj7FPOt3hvpYKtwKkhw"

if [ -z "$API_KEY" ]; then
    echo "Error: DIP_API_KEY environment variable not set"
    exit 1
fi

# Historical wahlperioden to sync (WP7-18)
WAHLPERIODEN=(18)

#for WP in "${WAHLPERIODEN[@]}"; do
    echo "========================================="
    echo "Syncing Drucksachen for Wahlperiode $WP"
    echo "========================================="
    
    go run ./cmd/sync-aktivitaeten \
        -db "$DB" \
        -key "$API_KEY" \
        -wahlperiode "21,20,7,8,9,10,11,12,13" # \
        #-resume
    
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to sync WP $WP"
        exit 1
    fi
    
    echo "Completed WP $WP"
    echo ""
#done

echo "========================================="
echo "Historical drucksachen sync complete!"
echo "========================================="

# Show final statistics
sqlite3 "$DB" << 'EOF'
.mode markdown
.headers on
SELECT 
    'Final Drucksache Coverage' as summary;
    
SELECT
    wahlperiode,
    COUNT(*) as drucksachen_count,
    MIN(datum) as earliest,
    MAX(datum) as latest
FROM drucksache
GROUP BY wahlperiode
ORDER BY wahlperiode;
EOF