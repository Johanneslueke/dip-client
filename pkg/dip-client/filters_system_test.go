package dipclient_test

import (
	"context"
	"os"
	"testing"

	dipclient "github.com/Johanneslueke/dip-client/pkg/dip-client"
)

// TestSystem_AllFilters verifies that all filter types work correctly with the API
func TestSystem_AllFilters(t *testing.T) {
	apiKey := os.Getenv("DIP_API_KEY")
	if apiKey == "" {
		apiKey = "OSOegLs.PR2lwJ1dwCeje9vTj7FPOt3hvpYKtwKkhw"
	}

	client, err := dipclient.New(dipclient.Config{
		BaseURL: "https://search.dip.bundestag.de/api/v1",
		APIKey:  apiKey,
	})
	if err != nil {
		t.Fatalf("Failed to create client: %v", err)
	}

	ctx := context.Background()

	t.Run("IntegerFilters", func(t *testing.T) {
		// Test FId filter (int type)
		filter := make(dipclient.IDFilter, 1)
		filter[0] = 318274
		result, err := client.GetAktivitaetList(ctx, &dipclient.GetAktivitaetListParams{
			FId: &filter,
		})
		if err != nil {
			t.Fatalf("FId filter failed: %v", err)
		}
		if result == nil {
			t.Fatal("Expected non-nil result")
		}
		if len(result.Documents) == 0 {
			t.Error("Expected at least one document with FId=318274")
		}
		t.Logf("Found %d aktivitaet(s) with FId=318274", len(result.Documents))
	})

	t.Run("StringFilters", func(t *testing.T) {
		// Test FDokumentnummer filter (string type)
		filter := make(dipclient.DokumentnummerFilter, 1)
		filter[0] = "19/24359"
		result, err := client.GetDrucksacheList(ctx, &dipclient.GetDrucksacheListParams{
			FDokumentnummer: &filter,
		})
		if err != nil {
			t.Fatalf("FDokumentnummer filter failed: %v", err)
		}
		if result == nil {
			t.Fatal("Expected non-nil result")
		}
		t.Logf("Found %d drucksache(n) with dokumentnummer 19/24359", len(result.Documents))
	})

	t.Run("MultipleFilters", func(t *testing.T) {
		// Test combining multiple filters
		
		wpFilter := make(dipclient.WahlperiodeFilter, 1)
		wpFilter[0] = 20
		drucksachetyp := dipclient.DrucksachtypFilter("Antrag")

		result, err := client.GetVorgangList(ctx, &dipclient.GetVorgangListParams{
			FWahlperiode:   &wpFilter,
			FDrucksachetyp: &drucksachetyp,
		})
		if err != nil {
			t.Fatalf("Multiple filters failed: %v", err)
		}
		if result == nil {
			t.Fatal("Expected non-nil result")
		}
		t.Logf("Found %d vorgaenge with wahlperiode=20 and drucksachetyp=Antrag", len(result.Documents))
	})

	t.Run("GestaFilter", func(t *testing.T) {
		// Test GESTA filter (unique to Vorgang)
		filter := make(dipclient.GestaFilter, 1)
		filter[0] = "N001"
		result, err := client.GetVorgangList(ctx, &dipclient.GetVorgangListParams{
			FGesta: &filter,
		})
		if err != nil {
			t.Fatalf("FGesta filter failed: %v", err)
		}
		if result == nil {
			t.Fatal("Expected non-nil result")
		}
		t.Logf("Found %d vorgaenge with GESTA=N001", len(result.Documents))
	})

	t.Run("DokumentartEnumFilter", func(t *testing.T) {
		// Test Dokumentart enum filter (unique to certain endpoints)
		dokumentart := dipclient.GetAktivitaetListParamsFDokumentart("Drucksache")
		filter := make(dipclient.WahlperiodeFilter, 1)
		filter[0] = 20

		result, err := client.GetAktivitaetList(ctx, &dipclient.GetAktivitaetListParams{
			FDokumentart: &dokumentart,
			FWahlperiode: &filter,
		})
		if err != nil {
			t.Fatalf("FDokumentart filter failed: %v", err)
		}
		if result == nil {
			t.Fatal("Expected non-nil result")
		}
		t.Logf("Found %d aktivitaeten with dokumentart=Drucksache in WP20", len(result.Documents))
	})

	t.Run("EndpointSpecificFilters", func(t *testing.T) {
		// Verify that DrucksacheText doesn't accept FDrucksache (should use FId instead)
		
		idfilter := make(dipclient.IDFilter, 1)
		idfilter[0] = 306952

		wpFilter := make(dipclient.WahlperiodeFilter, 1)
		wpFilter[0] = 20 

		result, err := client.GetDrucksacheTextList(ctx, &dipclient.GetDrucksacheTextListParams{
			FId:          &idfilter,
			FWahlperiode: &wpFilter,
		})
		if err != nil {
			t.Fatalf("DrucksacheText with FId failed: %v", err)
		}
		if result == nil {
			t.Fatal("Expected non-nil result")
		}
		t.Logf("Found %d drucksache text(s) with FId=%d", len(result.Documents), idfilter[0])
	})
}
