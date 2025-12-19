package main

import (
	"flag"
	"fmt"
	"io"
	"log"
	"os"
	"path/filepath"
	"strings"

	"github.com/lestrrat-go/libxml2/parser"
	"github.com/lestrrat-go/libxml2/types"
)

func main() {
	var (
		xmlPath = flag.String("xml", "", "Path to XML file to validate (required)")
		dtdPath = flag.String("dtd", "", "Path to DTD file (optional, will try to find from XML DOCTYPE)")
		verbose = flag.Bool("v", false, "Verbose output")
		summary = flag.Bool("s", false, "Show summary statistics")
	)
	flag.Parse()

	if *xmlPath == "" {
		fmt.Println("Usage: validate-xml-dtd -xml <path-to-xml> [-dtd <path-to-dtd>] [-v] [-s]")
		fmt.Println("\nOptions:")
		fmt.Println("  -xml string")
		fmt.Println("        Path to XML file to validate (required)")
		fmt.Println("  -dtd string")
		fmt.Println("        Path to DTD file (optional, will auto-detect from XML DOCTYPE)")
		fmt.Println("  -v    Verbose output (show validation process)")
		fmt.Println("  -s    Show summary statistics about XML structure")
		fmt.Println("\nExample:")
		fmt.Println("  validate-xml-dtd -xml MdB-Stammdaten/MDB_STAMMDATEN.XML -v -s")
		os.Exit(1)
	}

	// Check if XML file exists
	if _, err := os.Stat(*xmlPath); os.IsNotExist(err) {
		log.Fatalf("XML file not found: %s", *xmlPath)
	}

	if *verbose {
		fmt.Printf("Validating XML file: %s\n", *xmlPath)
	}

	// Parse and validate XML
	if err := validateXML(*xmlPath, *dtdPath, *verbose, *summary); err != nil {
		log.Fatalf("Validation failed: %v", err)
	}

	fmt.Println("✅ XML is valid according to DTD")
}

func validateXML(xmlPath, dtdPath string, verbose, showSummary bool) error {
	// Read XML file
	xmlFile, err := os.Open(xmlPath)
	if err != nil {
		return fmt.Errorf("failed to open XML file: %w", err)
	}
	defer xmlFile.Close()

	// Create parser with DTD validation enabled
	p := parser.New(
		parser.XMLParseDTDValid, // Enable DTD validation
		parser.XMLParseDTDLoad,  // Load external DTD
	)

	// If DTD path provided, resolve relative to XML file
	if dtdPath != "" {
		if !filepath.IsAbs(dtdPath) {
			xmlDir := filepath.Dir(xmlPath)
			dtdPath = filepath.Join(xmlDir, dtdPath)
		}
		if verbose {
			fmt.Printf("Using DTD file: %s\n", dtdPath)
		}
	}

	// Parse XML with validation
	doc, err := p.ParseReader(xmlFile)
	if err != nil {
		return fmt.Errorf("XML parsing/validation error: %w", err)
	}
	defer doc.Free()

	if verbose {
		fmt.Println("XML parsed successfully")
		fmt.Printf("Document encoding: %s\n", doc.Encoding())
	}

	// Show summary if requested
	if showSummary {
		if err := showXMLSummary(doc, verbose); err != nil {
			return fmt.Errorf("failed to generate summary: %w", err)
		}
	}

	return nil
}

func showXMLSummary(doc types.Document, verbose bool) error {
	fmt.Println("\n📊 XML Structure Summary:")
	fmt.Println(strings.Repeat("=", 50))

	root, err := doc.DocumentElement()
	if err != nil {
		return fmt.Errorf("failed to get root element: %w", err)
	}

	// Count elements by type
	elementCounts := make(map[string]int)
	totalElements := 0

	var walkTree func(node types.Node, depth int)
	walkTree = func(node types.Node, depth int) {
		nodeName := node.NodeName()
		if nodeName != "" && nodeName != "#text" && nodeName != "#comment" {
			elementCounts[nodeName]++
			totalElements++

			// Show first level details if verbose
			if verbose && depth == 1 {
				fmt.Printf("  - %s\n", nodeName)
			}
		}

		// Walk children
		child, err := node.FirstChild()
		if err == nil && child != nil {
			walkTree(child, depth+1)

			// Walk siblings
			for {
				sibling, err := child.NextSibling()
				if err != nil || sibling == nil {
					break
				}
				walkTree(sibling, depth+1)
				child = sibling
			}
		}
	}

	fmt.Printf("Root element: %s\n", root.NodeName())
	walkTree(root, 0)

	fmt.Printf("\nTotal elements: %d\n", totalElements)
	fmt.Printf("Unique element types: %d\n\n", len(elementCounts))

	// Show top-level element counts
	fmt.Println("Top-level element counts:")
	topElements := []string{"MDB", "VERSION", "WAHLPERIODE", "INSTITUTION", "NAME"}
	for _, elem := range topElements {
		if count, ok := elementCounts[elem]; ok {
			fmt.Printf("  %-20s: %d\n", elem, count)
		}
	}

	// Show other significant elements
	fmt.Println("\nOther significant elements:")
	significantElements := []string{"BIOGRAFISCHE_ANGABEN", "WAHLPERIODEN", "INSTITUTIONEN",
		"NACHNAME", "VORNAME", "PARTEI_KURZ", "WP"}
	for _, elem := range significantElements {
		if count, ok := elementCounts[elem]; ok {
			fmt.Printf("  %-25s: %d\n", elem, count)
		}
	}

	return nil
}

// Helper function to read DOCTYPE declaration (if needed for manual DTD loading)
func extractDTDPath(xmlPath string) (string, error) {
	file, err := os.Open(xmlPath)
	if err != nil {
		return "", err
	}
	defer file.Close()

	// Read first few KB to find DOCTYPE
	buf := make([]byte, 4096)
	n, err := file.Read(buf)
	if err != nil && err != io.EOF {
		return "", err
	}

	content := string(buf[:n])

	// Look for <!DOCTYPE ... SYSTEM "filename.dtd">
	if idx := strings.Index(content, "<!DOCTYPE"); idx >= 0 {
		doctype := content[idx:]
		if endIdx := strings.Index(doctype, ">"); endIdx >= 0 {
			doctype = doctype[:endIdx]

			// Extract DTD filename from SYSTEM declaration
			if sysIdx := strings.Index(doctype, "SYSTEM"); sysIdx >= 0 {
				remaining := doctype[sysIdx+6:]
				if startQuote := strings.IndexAny(remaining, "\"'"); startQuote >= 0 {
					quote := remaining[startQuote]
					remaining = remaining[startQuote+1:]
					if endQuote := strings.IndexByte(remaining, byte(quote)); endQuote >= 0 {
						dtdFile := remaining[:endQuote]
						// Resolve relative to XML file
						xmlDir := filepath.Dir(xmlPath)
						return filepath.Join(xmlDir, dtdFile), nil
					}
				}
			}
		}
	}

	return "", fmt.Errorf("no DTD SYSTEM declaration found in XML")
}
