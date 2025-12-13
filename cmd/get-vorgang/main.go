package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"

	dipclient "dpi/pkg/dip-client"
)

func main() {
	var (
		baseURL = flag.String("url", "https://search.dip.bundestag.de/api/v1", "API base URL")
		apiKey  = flag.String("key", "", "API key")
		id      = flag.Int("id", 0, "Vorgang ID")
	)
	flag.Parse()

	if *apiKey == "" {
		*apiKey = os.Getenv("DIP_API_KEY")
	}

	if *apiKey == "" {
		log.Fatal("API key required (use -key flag or DIP_API_KEY environment variable)")
	}

	if *id == 0 {
		log.Fatal("Vorgang ID required (use -id flag)")
	}

	client, err := dipclient.New(dipclient.Config{
		BaseURL: *baseURL,
		APIKey:  *apiKey,
	})
	if err != nil {
		log.Fatalf("Failed to create client: %v", err)
	}

	ctx := context.Background()
	vorgang, err := client.GetVorgang(ctx, dipclient.Id(*id), nil)
	if err != nil {
		log.Fatalf("Failed to get vorgang: %v", err)
	}

	output, err := json.MarshalIndent(vorgang, "", "  ")
	if err != nil {
		log.Fatalf("Failed to marshal response: %v", err)
	}

	fmt.Println(string(output))
}
