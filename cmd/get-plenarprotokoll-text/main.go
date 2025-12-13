package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"

	dipclient "github.com/Johanneslueke/dip-client/pkg/dip-client"
)

func main() {
	var (
		baseURL = flag.String("url", "https://search.dip.bundestag.de/api/v1", "API base URL")
		apiKey  = flag.String("key", "", "API key")
		id      = flag.Int("id", 0, "PlenarprotokollText ID")
	)
	flag.Parse()

	if *apiKey == "" {
		*apiKey = os.Getenv("DIP_API_KEY")
	}

	if *apiKey == "" {
		log.Fatal("API key required (use -key flag or DIP_API_KEY environment variable)")
	}

	if *id == 0 {
		log.Fatal("PlenarprotokollText ID required (use -id flag)")
	}

	client, err := dipclient.New(dipclient.Config{
		BaseURL: *baseURL,
		APIKey:  *apiKey,
	})
	if err != nil {
		log.Fatalf("Failed to create client: %v", err)
	}

	ctx := context.Background()
	plenarprotokollText, err := client.GetPlenarprotokollText(ctx, dipclient.Id(*id), nil)
	if err != nil {
		log.Fatalf("Failed to get plenarprotokoll text: %v", err)
	}

	output, err := json.MarshalIndent(plenarprotokollText, "", "  ")
	if err != nil {
		log.Fatalf("Failed to marshal response: %v", err)
	}

	fmt.Println(string(output))
}
