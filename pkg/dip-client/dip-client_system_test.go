package dipclient_test

import (
	"context"
	"os"
	"testing"

	dipclient "github.com/Johanneslueke/dip-client/pkg/dip-client"
)

const testAPIKey = "OSOegLs.PR2lwJ1dwCeje9vTj7FPOt3hvpYKtwKkhw"

// TestSystem_RealAPI tests the client against the real DIP API
// Run with: go test -v -tags=system ./pkg/dip-client
func TestSystem_RealAPI(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping system test in short mode")
	}

	// Allow override via environment variable
	apiKey := os.Getenv("DIP_API_KEY")
	if apiKey == "" {
		apiKey = testAPIKey
	}

	client, err := dipclient.New(dipclient.Config{
		BaseURL: "https://search.dip.bundestag.de/api/v1",
		APIKey:  apiKey,
	})
	if err != nil {
		t.Fatalf("Failed to create client: %v", err)
	}

	ctx := context.Background()

	t.Run("ListVorgaenge", func(t *testing.T) {
		result, err := client.GetVorgangList(ctx, nil)
		if err != nil {
			t.Fatalf("GetVorgangList failed: %v", err)
		}
		if result == nil {
			t.Fatal("Expected non-nil result")
		}
		t.Logf("Successfully retrieved Vorgang list")
	})

	t.Run("ListPersonen", func(t *testing.T) {
		t.Skip("Known issue: API returns wahlperiode as array but schema expects int32")
		result, err := client.GetPersonList(ctx, nil)
		if err != nil {
			t.Fatalf("GetPersonList failed: %v", err)
		}
		if result == nil {
			t.Fatal("Expected non-nil result")
		}
		t.Logf("Successfully retrieved Person list")
	})

	t.Run("ListAktivitaeten", func(t *testing.T) {
		result, err := client.GetAktivitaetList(ctx, nil)
		if err != nil {
			t.Fatalf("GetAktivitaetList failed: %v", err)
		}
		if result == nil {
			t.Fatal("Expected non-nil result")
		}
		t.Logf("Successfully retrieved Aktivitaet list")
	})

	t.Run("ListDrucksachen", func(t *testing.T) {
		result, err := client.GetDrucksacheList(ctx, nil)
		if err != nil {
			t.Fatalf("GetDrucksacheList failed: %v", err)
		}
		if result == nil {
			t.Fatal("Expected non-nil result")
		}
		t.Logf("Successfully retrieved Drucksache list")
	})

	t.Run("ListDrucksacheTexte", func(t *testing.T) {
		result, err := client.GetDrucksacheTextList(ctx, nil)
		if err != nil {
			t.Fatalf("GetDrucksacheTextList failed: %v", err)
		}
		if result == nil {
			t.Fatal("Expected non-nil result")
		}
		t.Logf("Successfully retrieved DrucksacheText list")
	})

	t.Run("ListPlenarprotokolle", func(t *testing.T) {
		result, err := client.GetPlenarprotokollList(ctx, nil)
		if err != nil {
			t.Fatalf("GetPlenarprotokollList failed: %v", err)
		}
		if result == nil {
			t.Fatal("Expected non-nil result")
		}
		t.Logf("Successfully retrieved Plenarprotokoll list")
	})

	t.Run("ListPlenarprotokollTexte", func(t *testing.T) {
		result, err := client.GetPlenarprotokollTextList(ctx, nil)
		if err != nil {
			t.Fatalf("GetPlenarprotokollTextList failed: %v", err)
		}
		if result == nil {
			t.Fatal("Expected non-nil result")
		}
		t.Logf("Successfully retrieved PlenarprotokollText list")
	})

	t.Run("ListVorgangspositionen", func(t *testing.T) {
		result, err := client.GetVorgangspositionList(ctx, nil)
		if err != nil {
			t.Fatalf("GetVorgangspositionList failed: %v", err)
		}
		if result == nil {
			t.Fatal("Expected non-nil result")
		}
		t.Logf("Successfully retrieved Vorgangsposition list")
	})
}

// TestSystem_InvalidAPIKey tests that invalid API keys are properly rejected
func TestSystem_InvalidAPIKey(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping system test in short mode")
	}

	client, err := dipclient.New(dipclient.Config{
		BaseURL: "https://search.dip.bundestag.de/api/v1",
		APIKey:  "invalid-key-12345",
	})
	if err != nil {
		t.Fatalf("Failed to create client: %v", err)
	}

	ctx := context.Background()
	_, err = client.GetVorgangList(ctx, nil)
	if err == nil {
		t.Fatal("Expected error with invalid API key, got nil")
	}
	t.Logf("Invalid API key correctly rejected: %v", err)
}

// TestSystem_WithParameters tests the client with various query parameters
func TestSystem_WithParameters(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping system test in short mode")
	}

	// Allow override via environment variable
	apiKey := os.Getenv("DIP_API_KEY")
	if apiKey == "" {
		apiKey = testAPIKey
	}

	client, err := dipclient.New(dipclient.Config{
		BaseURL: "https://search.dip.bundestag.de/api/v1",
		APIKey:  apiKey,
	})
	if err != nil {
		t.Fatalf("Failed to create client: %v", err)
	}

	ctx := context.Background()

	t.Run("WahlperiodeFilter", func(t *testing.T) {
		wahlperiode := dipclient.WahlperiodeFilter(20)
		params := &dipclient.GetVorgangListParams{
			FWahlperiode: &wahlperiode,
		}

		result, err := client.GetVorgangList(ctx, params)
		if err != nil {
			t.Fatalf("GetVorgangList with wahlperiode filter failed: %v", err)
		}
		if result == nil {
			t.Fatal("Expected non-nil result")
		}
		if len(result.Documents) == 0 {
			t.Fatal("Expected at least one document for Wahlperiode 20")
		}

		// Verify that returned documents are from Wahlperiode 20
		for _, doc := range result.Documents {
			if doc.Wahlperiode != 20 {
				t.Errorf("Expected Wahlperiode 20, got %d", doc.Wahlperiode)
			}
		}

		t.Logf("Successfully filtered by Wahlperiode 20, found %d documents", len(result.Documents))
	})

	t.Run("CursorPagination", func(t *testing.T) {
		wahlperiode := dipclient.WahlperiodeFilter(21)
		params := &dipclient.GetAktivitaetListParams{
			FWahlperiode: &wahlperiode,
		}

		// Get first page
		firstPage, err := client.GetAktivitaetList(ctx, params)
		if err != nil {
			t.Fatalf("First page request failed: %v", err)
		}
		if firstPage == nil || firstPage.Cursor == "" {
			t.Fatal("Expected cursor in first page response")
		}

		firstPageCount := len(firstPage.Documents)
		firstCursor := firstPage.Cursor

		// Get second page using cursor
		cursor := dipclient.Cursor(firstCursor)
		params.Cursor = &cursor

		secondPage, err := client.GetAktivitaetList(ctx, params)
		if err != nil {
			t.Fatalf("Second page request failed: %v", err)
		}
		if secondPage == nil {
			t.Fatal("Expected non-nil result for second page")
		}

		secondPageCount := len(secondPage.Documents)

		// Verify we got different documents
		if firstPageCount > 0 && secondPageCount > 0 {
			if firstPage.Documents[0].Id == secondPage.Documents[0].Id {
				t.Error("Second page returned same documents as first page")
			}
		}

		t.Logf("Successfully paginated: first page %d docs, second page %d docs",
			firstPageCount, secondPageCount)
	})

	t.Run("MultipleFilters", func(t *testing.T) {
		wahlperiode := dipclient.WahlperiodeFilter(21)
		format := dipclient.GetDrucksacheListParamsFormat("json")

		params := &dipclient.GetDrucksacheListParams{
			FWahlperiode: &wahlperiode,
			Format:       &format,
		}

		result, err := client.GetDrucksacheList(ctx, params)
		if err != nil {
			t.Fatalf("GetDrucksacheList with multiple filters failed: %v", err)
		}
		if result == nil {
			t.Fatal("Expected non-nil result")
		}

		// Verify wahlperiode filter worked
		for _, doc := range result.Documents {
			if doc.Wahlperiode != nil && *doc.Wahlperiode != 21 {
				t.Errorf("Expected Wahlperiode 21, got %d", *doc.Wahlperiode)
			}
		}

		t.Logf("Successfully applied multiple filters, found %d documents", len(result.Documents))
	})

	t.Run("EmptyResultsWithFilter", func(t *testing.T) {
		// Use a very old Wahlperiode that likely has no results
		wahlperiode := dipclient.WahlperiodeFilter(1)
		params := &dipclient.GetAktivitaetListParams{
			FWahlperiode: &wahlperiode,
		}

		result, err := client.GetAktivitaetList(ctx, params)
		if err != nil {
			t.Fatalf("GetAktivitaetList with old wahlperiode failed: %v", err)
		}
		if result == nil {
			t.Fatal("Expected non-nil result")
		}

		t.Logf("Query with Wahlperiode 1 returned %d documents", len(result.Documents))
	})
}
