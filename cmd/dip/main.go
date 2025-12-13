package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"
	"strings"

	dipclient "github.com/Johanneslueke/dip-client/pkg/dip-client"
)

type filterParams struct {
	cursor          *dipclient.Cursor
	wahlperiode     *dipclient.WahlperiodeFilter
	id              *dipclient.IDFilter
	drucksache      *dipclient.DrucksacheFilter
	plenarprotokoll *dipclient.PlenarprotokollFilter
	dokumentnummer  *dipclient.DokumentnummerFilter
	dokumentart     string
	drucksachetyp   *dipclient.DrucksachtypFilter
	frageNummer     *dipclient.FrageNummerFilter
	zuordnung       *dipclient.ZuordnungFilter
	gesta           *dipclient.GestaFilter
	format          string
}

func main() {
	var (
		baseURL  = flag.String("url", "https://search.dip.bundestag.de/api/v1", "API base URL")
		apiKey   = flag.String("key", "", "API key")
		endpoint = flag.String("endpoint", "", "Endpoint to call")
		id       = flag.Int("id", 0, "Resource ID")
		list     = flag.Bool("list", false, "List resources")

		// Common parameters
		format           = flag.String("format", "", "Response format: json or xml")
		cursor           = flag.String("cursor", "", "Cursor for pagination")
		wahlperiode      = flag.Int("wahlperiode", 0, "Wahlperiode filter")
		fID              = flag.Int("f.id", 0, "Filter by ID")
		fDrucksache      = flag.Int("f.drucksache", 0, "Filter by Drucksache ID")
		fPlenarprotokoll = flag.Int("f.plenarprotokoll", 0, "Filter by Plenarprotokoll ID")
		fDokumentnummer  = flag.String("f.dokumentnummer", "", "Filter by Dokumentnummer")
		fDokumentart     = flag.String("f.dokumentart", "", "Filter by Dokumentart (Drucksache or Plenarprotokoll)")
		fDrucksachetyp   = flag.String("f.drucksachetyp", "", "Filter by Drucksachetyp")
		fFrageNummer     = flag.String("f.frage_nummer", "", "Filter by Fragenummer")
		fZuordnung       = flag.String("f.zuordnung", "", "Filter by Zuordnung")
		fGesta           = flag.String("f.gesta", "", "Filter by GESTA-Ordnungsnummer (Vorgang only)")
	)
	flag.Parse()

	if *apiKey == "" {
		*apiKey = os.Getenv("DIP_API_KEY")
	}

	if *apiKey == "" {
		log.Fatal("API key required")
	}

	if *endpoint == "" {
		log.Fatal("Endpoint required: aktivitaet, drucksache, drucksache-text, person, plenarprotokoll, plenarprotokoll-text, vorgang, vorgangsposition")
	}

	client, err := dipclient.New(dipclient.Config{
		BaseURL: *baseURL,
		APIKey:  *apiKey,
	})
	if err != nil {
		log.Fatalf("Failed to create client: %v", err)
	}

	ctx := context.Background()
	var result interface{}

	// Helper functions to convert flags to filter types
	cursorPtr := func() *dipclient.Cursor {
		if *cursor == "" {
			return nil
		}
		c := dipclient.Cursor(*cursor)
		return &c
	}

	wahlperiodePtr := func() *dipclient.WahlperiodeFilter {
		if *wahlperiode == 0 {
			return nil
		}
		w := dipclient.WahlperiodeFilter(*wahlperiode)
		return &w
	}

	idFilterPtr := func() *dipclient.IDFilter {
		if *fID == 0 {
			return nil
		}
		f := dipclient.IDFilter(*fID)
		return &f
	}

	drucksacheFilterPtr := func() *dipclient.DrucksacheFilter {
		if *fDrucksache == 0 {
			return nil
		}
		f := dipclient.DrucksacheFilter(*fDrucksache)
		return &f
	}

	plenarprotokollFilterPtr := func() *dipclient.PlenarprotokollFilter {
		if *fPlenarprotokoll == 0 {
			return nil
		}
		f := dipclient.PlenarprotokollFilter(*fPlenarprotokoll)
		return &f
	}

	dokumentnummerFilterPtr := func() *dipclient.DokumentnummerFilter {
		if *fDokumentnummer == "" {
			return nil
		}
		f := dipclient.DokumentnummerFilter(*fDokumentnummer)
		return &f
	}

	drucksachtypFilterPtr := func() *dipclient.DrucksachtypFilter {
		if *fDrucksachetyp == "" {
			return nil
		}
		f := dipclient.DrucksachtypFilter(*fDrucksachetyp)
		return &f
	}

	frageNummerFilterPtr := func() *dipclient.FrageNummerFilter {
		if *fFrageNummer == "" {
			return nil
		}
		f := dipclient.FrageNummerFilter(*fFrageNummer)
		return &f
	}

	zuordnungFilterPtr := func() *dipclient.ZuordnungFilter {
		if *fZuordnung == "" {
			return nil
		}
		f := dipclient.ZuordnungFilter(*fZuordnung)
		return &f
	}

	gestaFilterPtr := func() *dipclient.GestaFilter {
		if *fGesta == "" {
			return nil
		}
		f := dipclient.GestaFilter(*fGesta)
		return &f
	} // Struct to hold all filter parameters

	filters := filterParams{
		cursor:          cursorPtr(),
		wahlperiode:     wahlperiodePtr(),
		id:              idFilterPtr(),
		drucksache:      drucksacheFilterPtr(),
		plenarprotokoll: plenarprotokollFilterPtr(),
		dokumentnummer:  dokumentnummerFilterPtr(),
		dokumentart:     *fDokumentart,
		drucksachetyp:   drucksachtypFilterPtr(),
		frageNummer:     frageNummerFilterPtr(),
		zuordnung:       zuordnungFilterPtr(),
		gesta:           gestaFilterPtr(),
		format:          *format,
	}

	// Dispatch table for endpoints
	type endpointHandler func(ctx context.Context, listMode bool, resourceId dipclient.ID, f filterParams) (interface{}, error)

	handlers := map[string]endpointHandler{
		"aktivitaet": func(ctx context.Context, listMode bool, resourceId dipclient.ID, f filterParams) (interface{}, error) {
			if listMode {
				params := &dipclient.GetAktivitaetListParams{
					Cursor:           f.cursor,
					FWahlperiode:     f.wahlperiode,
					FId:              f.id,
					FDrucksache:      f.drucksache,
					FPlenarprotokoll: f.plenarprotokoll,
					FDokumentnummer:  f.dokumentnummer,
					FDrucksachetyp:   f.drucksachetyp,
					FFrageNummer:     f.frageNummer,
					FZuordnung:       f.zuordnung,
				}
				if f.format != "" {
					fmt := dipclient.GetAktivitaetListParamsFormat(f.format)
					params.Format = &fmt
				}
				if f.dokumentart != "" {
					da := dipclient.GetAktivitaetListParamsFDokumentart(f.dokumentart)
					params.FDokumentart = &da
				}
				return client.GetAktivitaetList(ctx, params)
			}
			return client.GetAktivitaet(ctx, resourceId, nil)
		},
		"drucksache": func(ctx context.Context, listMode bool, resourceId dipclient.ID, f filterParams) (interface{}, error) {
			if listMode {
				params := &dipclient.GetDrucksacheListParams{
					Cursor:          f.cursor,
					FWahlperiode:    f.wahlperiode,
					FId:             f.id,
					FDokumentnummer: f.dokumentnummer,
					FDrucksachetyp:  f.drucksachetyp,
					FZuordnung:      f.zuordnung,
				}
				if f.format != "" {
					fmt := dipclient.GetDrucksacheListParamsFormat(f.format)
					params.Format = &fmt
				}
				return client.GetDrucksacheList(ctx, params)
			}
			return client.GetDrucksache(ctx, resourceId, nil)
		},
		"drucksache-text": func(ctx context.Context, listMode bool, resourceId dipclient.ID, f filterParams) (interface{}, error) {
			if listMode {
				params := &dipclient.GetDrucksacheTextListParams{
					Cursor:          f.cursor,
					FWahlperiode:    f.wahlperiode,
					FId:             f.id,
					FDokumentnummer: f.dokumentnummer,
					FDrucksachetyp:  f.drucksachetyp,
					FZuordnung:      f.zuordnung,
				}
				if f.format != "" {
					fmt := dipclient.GetDrucksacheTextListParamsFormat(f.format)
					params.Format = &fmt
				}
				return client.GetDrucksacheTextList(ctx, params)
			}
			return client.GetDrucksacheText(ctx, resourceId, nil)
		},
		"person": func(ctx context.Context, listMode bool, resourceId dipclient.ID, f filterParams) (interface{}, error) {
			if listMode {
				params := &dipclient.GetPersonListParams{
					Cursor:       f.cursor,
					FWahlperiode: f.wahlperiode,
					FId:          f.id,
				}
				if f.format != "" {
					fmt := dipclient.GetPersonListParamsFormat(f.format)
					params.Format = &fmt
				}
				return client.GetPersonList(ctx, params)
			}
			return client.GetPerson(ctx, resourceId, nil)
		},
		"plenarprotokoll": func(ctx context.Context, listMode bool, resourceId dipclient.ID, f filterParams) (interface{}, error) {
			if listMode {
				params := &dipclient.GetPlenarprotokollListParams{
					Cursor:          f.cursor,
					FWahlperiode:    f.wahlperiode,
					FId:             f.id,
					FDokumentnummer: f.dokumentnummer,
					FZuordnung:      f.zuordnung,
				}
				if f.format != "" {
					fmt := dipclient.GetPlenarprotokollListParamsFormat(f.format)
					params.Format = &fmt
				}
				return client.GetPlenarprotokollList(ctx, params)
			}
			return client.GetPlenarprotokoll(ctx, resourceId, nil)
		},
		"plenarprotokoll-text": func(ctx context.Context, listMode bool, resourceId dipclient.ID, f filterParams) (interface{}, error) {
			if listMode {
				params := &dipclient.GetPlenarprotokollTextListParams{
					Cursor:          f.cursor,
					FWahlperiode:    f.wahlperiode,
					FId:             f.id,
					FDokumentnummer: f.dokumentnummer,
					FZuordnung:      f.zuordnung,
				}
				if f.format != "" {
					fmt := dipclient.GetPlenarprotokollTextListParamsFormat(f.format)
					params.Format = &fmt
				}
				return client.GetPlenarprotokollTextList(ctx, params)
			}
			return client.GetPlenarprotokollText(ctx, resourceId, nil)
		},
		"vorgang": func(ctx context.Context, listMode bool, resourceId dipclient.ID, f filterParams) (interface{}, error) {
			if listMode {
				params := &dipclient.GetVorgangListParams{
					Cursor:           f.cursor,
					FWahlperiode:     f.wahlperiode,
					FId:              f.id,
					FDrucksache:      f.drucksache,
					FPlenarprotokoll: f.plenarprotokoll,
					FDokumentnummer:  f.dokumentnummer,
					FDrucksachetyp:   f.drucksachetyp,
					FFrageNummer:     f.frageNummer,
					FGesta:           f.gesta,
				}
				if f.format != "" {
					fmt := dipclient.GetVorgangListParamsFormat(f.format)
					params.Format = &fmt
				}
				if f.dokumentart != "" {
					da := dipclient.GetVorgangListParamsFDokumentart(f.dokumentart)
					params.FDokumentart = &da
				}
				return client.GetVorgangList(ctx, params)
			}
			return client.GetVorgang(ctx, resourceId, nil)
		},
		"vorgangsposition": func(ctx context.Context, listMode bool, resourceId dipclient.ID, f filterParams) (interface{}, error) {
			if listMode {
				params := &dipclient.GetVorgangspositionListParams{
					Cursor:           f.cursor,
					FWahlperiode:     f.wahlperiode,
					FId:              f.id,
					FDrucksache:      f.drucksache,
					FPlenarprotokoll: f.plenarprotokoll,
					FDokumentnummer:  f.dokumentnummer,
					FDrucksachetyp:   f.drucksachetyp,
					FFrageNummer:     f.frageNummer,
					FZuordnung:       f.zuordnung,
				}
				if f.format != "" {
					fmt := dipclient.GetVorgangspositionListParamsFormat(f.format)
					params.Format = &fmt
				}
				if f.dokumentart != "" {
					da := dipclient.GetVorgangspositionListParamsFDokumentart(f.dokumentart)
					params.FDokumentart = &da
				}
				return client.GetVorgangspositionList(ctx, params)
			}
			return client.GetVorgangsposition(ctx, resourceId, nil)
		},
	}

	handler, ok := handlers[strings.ToLower(*endpoint)]
	if !ok {
		log.Fatalf("Unknown endpoint: %s", *endpoint)
	}

	result, err = handler(ctx, *list, dipclient.ID(*id), filters)

	if err != nil {
		log.Fatalf("API error: %v", err)
	}

	output, err := json.MarshalIndent(result, "", "  ")
	if err != nil {
		log.Fatalf("Marshal error: %v", err)
	}

	fmt.Println(string(output))
}
