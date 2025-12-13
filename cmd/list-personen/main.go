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
	)
	flag.Parse()

	if *apiKey == "" {
		*apiKey = os.Getenv("DIP_API_KEY")
	}

	if *apiKey == "" {
		log.Fatal("API key required (use -key flag or DIP_API_KEY environment variable)")
	}

	client, err := dipclient.New(dipclient.Config{
		BaseURL: *baseURL,
		APIKey:  *apiKey,
	})
	if err != nil {
		log.Fatalf("Failed to create client: %v", err)
	}

	ctx := context.Background()
	result, err := client.GetPersonList(ctx, nil)
	if err != nil {
		log.Fatalf("Failed to list personen: %v", err)
	}

	output, err := json.MarshalIndent(result, "", "  ")
	if err != nil {
		log.Fatalf("Failed to marshal response: %v", err)
	}

	fmt.Println(string(output))
}
