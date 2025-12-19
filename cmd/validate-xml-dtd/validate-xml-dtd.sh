#!/bin/bash
# Wrapper script for validate-xml-dtd that handles common use cases

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VALIDATOR="$PROJECT_ROOT/bin/validate-xml-dtd"

# Default values
XML_FILE=""
DTD_FILE=""
VERBOSE=""
SUMMARY=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -xml|--xml)
            XML_FILE="$2"
            shift 2
            ;;
        -dtd|--dtd)
            DTD_FILE="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE="-v"
            shift
            ;;
        -s|--summary)
            SUMMARY="-s"
            shift
            ;;
        -h|--help)
            echo "Usage: validate-xml-dtd.sh -xml <file> [-dtd <dtd-file>] [-v] [-s]"
            echo ""
            echo "Options:"
            echo "  -xml <file>     Path to XML file (required)"
            echo "  -dtd <file>     Path to DTD file (optional)"
            echo "  -v, --verbose   Verbose output"
            echo "  -s, --summary   Show summary statistics"
            echo "  -h, --help      Show this help"
            echo ""
            echo "Examples:"
            echo "  validate-xml-dtd.sh -xml MdB-Stammdaten/MDB_STAMMDATEN.XML"
            echo "  validate-xml-dtd.sh -xml MdB-Stammdaten/MDB_STAMMDATEN.XML -s"
            echo "  validate-xml-dtd.sh -xml MdB-Stammdaten/MDB_STAMMDATEN.XML -v -s"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Check if XML file is provided
if [ -z "$XML_FILE" ]; then
    echo "Error: XML file is required"
    echo "Use: validate-xml-dtd.sh -xml <file>"
    echo "Use -h or --help for more information"
    exit 1
fi

# Build command
CMD="$VALIDATOR -xml \"$XML_FILE\""

if [ -n "$DTD_FILE" ]; then
    CMD="$CMD -dtd \"$DTD_FILE\""
fi

if [ -n "$VERBOSE" ]; then
    CMD="$CMD $VERBOSE"
fi

if [ -n "$SUMMARY" ]; then
    CMD="$CMD $SUMMARY"
fi

# Execute
eval "$CMD"
