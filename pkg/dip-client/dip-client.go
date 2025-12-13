package dipclient

import (
	"context"
	"fmt"
	"net/http"

	client "github.com/Johanneslueke/dip-client/internal/gen"
)

// Re-exported types from the generated client
// This allows users to only import the dipclient package without needing to import the internal client package
type (
	// Core types
	Id       = client.Id
	IdFilter = client.IdFilter

	// Aktivitaet types
	Aktivitaet              = client.Aktivitaet
	AktivitaetAnzeige       = client.AktivitaetAnzeige
	AktivitaetListResponse  = client.AktivitaetListResponse
	GetAktivitaetParams     = client.GetAktivitaetParams
	GetAktivitaetListParams = client.GetAktivitaetListParams

	// Drucksache types
	Drucksache              = client.Drucksache
	DrucksacheListResponse  = client.DrucksacheListResponse
	GetDrucksacheParams     = client.GetDrucksacheParams
	GetDrucksacheListParams = client.GetDrucksacheListParams

	// DrucksacheText types
	DrucksacheText              = client.DrucksacheText
	DrucksacheTextListResponse  = client.DrucksacheTextListResponse
	GetDrucksacheTextParams     = client.GetDrucksacheTextParams
	GetDrucksacheTextListParams = client.GetDrucksacheTextListParams

	// Person types
	Person              = client.Person
	PersonListResponse  = client.PersonListResponse
	PersonRole          = client.PersonRole
	GetPersonParams     = client.GetPersonParams
	GetPersonListParams = client.GetPersonListParams

	// Plenarprotokoll types
	Plenarprotokoll              = client.Plenarprotokoll
	PlenarprotokollListResponse  = client.PlenarprotokollListResponse
	GetPlenarprotokollParams     = client.GetPlenarprotokollParams
	GetPlenarprotokollListParams = client.GetPlenarprotokollListParams

	// PlenarprotokollText types
	PlenarprotokollText              = client.PlenarprotokollText
	PlenarprotokollTextListResponse  = client.PlenarprotokollTextListResponse
	GetPlenarprotokollTextParams     = client.GetPlenarprotokollTextParams
	GetPlenarprotokollTextListParams = client.GetPlenarprotokollTextListParams

	// Vorgang types
	Vorgang              = client.Vorgang
	VorgangListResponse  = client.VorgangListResponse
	VorgangFilter        = client.VorgangFilter
	GetVorgangParams     = client.GetVorgangParams
	GetVorgangListParams = client.GetVorgangListParams

	// Vorgangsposition types
	Vorgangsposition              = client.Vorgangsposition
	VorgangspositionListResponse  = client.VorgangspositionListResponse
	GetVorgangspositionParams     = client.GetVorgangspositionParams
	GetVorgangspositionListParams = client.GetVorgangspositionListParams

	// Supporting types
	Beschlussfassung      = client.Beschlussfassung
	Deskriptor            = client.Deskriptor
	Fundstelle            = client.Fundstelle
	Inkrafttreten         = client.Inkrafttreten
	Urheber               = client.Urheber
	VorgangDeskriptor     = client.VorgangDeskriptor
	VorgangVerlinkung     = client.VorgangVerlinkung
	Vorgangsbezug         = client.Vorgangsbezug
	Vorgangspositionbezug = client.Vorgangspositionbezug

	// Filter types for query parameters
	Cursor                  = client.Cursor
	WahlperiodeFilter       = client.WahlperiodeFilter
	DatumStartFilter        = client.DatumStartFilter
	DatumEndFilter          = client.DatumEndFilter
	AktualisiertStartFilter = client.AktualisiertStartFilter
	AktualisiertEndFilter   = client.AktualisiertEndFilter
	DrucksacheFilter        = client.DrucksacheFilter
	PlenarprotokollFilter   = client.PlenarprotokollFilter
	DokumentnummerFilter    = client.DokumentnummerFilter
	DrucksachtypFilter      = client.DrucksachtypFilter
	FrageNummerFilter       = client.FrageNummerFilter
	ZuordnungFilter         = client.ZuordnungFilter
	GestaFilter             = client.GestaFilter

	// Dokumentart filter types
	GetAktivitaetListParamsFDokumentart       = client.GetAktivitaetListParamsFDokumentart
	GetVorgangListParamsFDokumentart          = client.GetVorgangListParamsFDokumentart
	GetVorgangspositionListParamsFDokumentart = client.GetVorgangspositionListParamsFDokumentart

	// Format types
	GetAktivitaetListParamsFormat          = client.GetAktivitaetListParamsFormat
	GetDrucksacheListParamsFormat          = client.GetDrucksacheListParamsFormat
	GetDrucksacheTextListParamsFormat      = client.GetDrucksacheTextListParamsFormat
	GetPersonListParamsFormat              = client.GetPersonListParamsFormat
	GetPlenarprotokollListParamsFormat     = client.GetPlenarprotokollListParamsFormat
	GetPlenarprotokollTextListParamsFormat = client.GetPlenarprotokollTextListParamsFormat
	GetVorgangListParamsFormat             = client.GetVorgangListParamsFormat
	GetVorgangspositionListParamsFormat    = client.GetVorgangspositionListParamsFormat
)

// Client wraps the generated API client with a more ergonomic interface
type Client struct {
	client client.ClientWithResponsesInterface
	apiKey string
}

// Config holds configuration for the DIP client
type Config struct {
	BaseURL string
	APIKey  string
}

// New creates a new DIP API client
func New(cfg Config) (*Client, error) {
	c, err := client.NewClientWithResponses(
		cfg.BaseURL,
		client.WithRequestEditorFn(func(ctx context.Context, req *http.Request) error {
			req.Header.Set("Authorization", fmt.Sprintf("ApiKey %s", cfg.APIKey))
			return nil
		}),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create client: %w", err)
	}

	return &Client{
		client: c,
		apiKey: cfg.APIKey,
	}, nil
}

// GetAktivitaet retrieves a single Aktivitaet by ID
func (c *Client) GetAktivitaet(ctx context.Context, id client.Id, params *client.GetAktivitaetParams) (*client.Aktivitaet, error) {
	resp, err := c.client.GetAktivitaetWithResponse(ctx, id, params)
	if err != nil {
		return nil, err
	}
	if resp.JSON200 != nil {
		return resp.JSON200, nil
	}
	return nil, fmt.Errorf("unexpected status code: %d", resp.StatusCode())
}

// GetAktivitaetList retrieves a list of Aktivitaeten
func (c *Client) GetAktivitaetList(ctx context.Context, params *client.GetAktivitaetListParams) (*client.AktivitaetListResponse, error) {
	resp, err := c.client.GetAktivitaetListWithResponse(ctx, params)
	if err != nil {
		return nil, err
	}
	if resp.JSON200 != nil {
		return resp.JSON200, nil
	}
	return nil, fmt.Errorf("unexpected status code: %d", resp.StatusCode())
}

// GetDrucksache retrieves a single Drucksache by ID
func (c *Client) GetDrucksache(ctx context.Context, id client.Id, params *client.GetDrucksacheParams) (*client.Drucksache, error) {
	resp, err := c.client.GetDrucksacheWithResponse(ctx, id, params)
	if err != nil {
		return nil, err
	}
	if resp.JSON200 != nil {
		return resp.JSON200, nil
	}
	return nil, fmt.Errorf("unexpected status code: %d", resp.StatusCode())
}

// GetDrucksacheList retrieves a list of Drucksachen
func (c *Client) GetDrucksacheList(ctx context.Context, params *client.GetDrucksacheListParams) (*client.DrucksacheListResponse, error) {
	resp, err := c.client.GetDrucksacheListWithResponse(ctx, params)
	if err != nil {
		return nil, err
	}
	if resp.JSON200 != nil {
		return resp.JSON200, nil
	}
	return nil, fmt.Errorf("unexpected status code: %d", resp.StatusCode())
}

// GetDrucksacheText retrieves a single DrucksacheText by ID
func (c *Client) GetDrucksacheText(ctx context.Context, id client.Id, params *client.GetDrucksacheTextParams) (*client.DrucksacheText, error) {
	resp, err := c.client.GetDrucksacheTextWithResponse(ctx, id, params)
	if err != nil {
		return nil, err
	}
	if resp.JSON200 != nil {
		return resp.JSON200, nil
	}
	return nil, fmt.Errorf("unexpected status code: %d", resp.StatusCode())
}

// GetDrucksacheTextList retrieves a list of DrucksacheTexte
func (c *Client) GetDrucksacheTextList(ctx context.Context, params *client.GetDrucksacheTextListParams) (*client.DrucksacheTextListResponse, error) {
	resp, err := c.client.GetDrucksacheTextListWithResponse(ctx, params)
	if err != nil {
		return nil, err
	}
	if resp.JSON200 != nil {
		return resp.JSON200, nil
	}
	return nil, fmt.Errorf("unexpected status code: %d", resp.StatusCode())
}

// GetPerson retrieves a single Person by ID
func (c *Client) GetPerson(ctx context.Context, id client.Id, params *client.GetPersonParams) (*client.Person, error) {
	resp, err := c.client.GetPersonWithResponse(ctx, id, params)
	if err != nil {
		return nil, err
	}
	if resp.JSON200 != nil {
		return resp.JSON200, nil
	}
	return nil, fmt.Errorf("unexpected status code: %d", resp.StatusCode())
}

// GetPersonList retrieves a list of Personen
func (c *Client) GetPersonList(ctx context.Context, params *client.GetPersonListParams) (*client.PersonListResponse, error) {
	resp, err := c.client.GetPersonListWithResponse(ctx, params)
	if err != nil {
		return nil, err
	}
	if resp.JSON200 != nil {
		return resp.JSON200, nil
	}
	return nil, fmt.Errorf("unexpected status code: %d", resp.StatusCode())
}

// GetPlenarprotokoll retrieves a single Plenarprotokoll by ID
func (c *Client) GetPlenarprotokoll(ctx context.Context, id client.Id, params *client.GetPlenarprotokollParams) (*client.Plenarprotokoll, error) {
	resp, err := c.client.GetPlenarprotokollWithResponse(ctx, id, params)
	if err != nil {
		return nil, err
	}
	if resp.JSON200 != nil {
		return resp.JSON200, nil
	}
	return nil, fmt.Errorf("unexpected status code: %d", resp.StatusCode())
}

// GetPlenarprotokollList retrieves a list of Plenarprotokolle
func (c *Client) GetPlenarprotokollList(ctx context.Context, params *client.GetPlenarprotokollListParams) (*client.PlenarprotokollListResponse, error) {
	resp, err := c.client.GetPlenarprotokollListWithResponse(ctx, params)
	if err != nil {
		return nil, err
	}
	if resp.JSON200 != nil {
		return resp.JSON200, nil
	}
	return nil, fmt.Errorf("unexpected status code: %d", resp.StatusCode())
}

// GetPlenarprotokollText retrieves a single PlenarprotokollText by ID
func (c *Client) GetPlenarprotokollText(ctx context.Context, id client.Id, params *client.GetPlenarprotokollTextParams) (*client.PlenarprotokollText, error) {
	resp, err := c.client.GetPlenarprotokollTextWithResponse(ctx, id, params)
	if err != nil {
		return nil, err
	}
	if resp.JSON200 != nil {
		return resp.JSON200, nil
	}
	return nil, fmt.Errorf("unexpected status code: %d", resp.StatusCode())
}

// GetPlenarprotokollTextList retrieves a list of PlenarprotokollTexte
func (c *Client) GetPlenarprotokollTextList(ctx context.Context, params *client.GetPlenarprotokollTextListParams) (*client.PlenarprotokollTextListResponse, error) {
	resp, err := c.client.GetPlenarprotokollTextListWithResponse(ctx, params)
	if err != nil {
		return nil, err
	}
	if resp.JSON200 != nil {
		return resp.JSON200, nil
	}
	return nil, fmt.Errorf("unexpected status code: %d", resp.StatusCode())
}

// GetVorgang retrieves a single Vorgang by ID
func (c *Client) GetVorgang(ctx context.Context, id client.Id, params *client.GetVorgangParams) (*client.Vorgang, error) {
	resp, err := c.client.GetVorgangWithResponse(ctx, id, params)
	if err != nil {
		return nil, err
	}
	if resp.JSON200 != nil {
		return resp.JSON200, nil
	}
	return nil, fmt.Errorf("unexpected status code: %d", resp.StatusCode())
}

// GetVorgangList retrieves a list of Vorgänge
func (c *Client) GetVorgangList(ctx context.Context, params *client.GetVorgangListParams) (*client.VorgangListResponse, error) {
	resp, err := c.client.GetVorgangListWithResponse(ctx, params)
	if err != nil {
		return nil, err
	}
	if resp.JSON200 != nil {
		return resp.JSON200, nil
	}
	return nil, fmt.Errorf("unexpected status code: %d", resp.StatusCode())
}

// GetVorgangsposition retrieves a single Vorgangsposition by ID
func (c *Client) GetVorgangsposition(ctx context.Context, id client.Id, params *client.GetVorgangspositionParams) (*client.Vorgangsposition, error) {
	resp, err := c.client.GetVorgangspositionWithResponse(ctx, id, params)
	if err != nil {
		return nil, err
	}
	if resp.JSON200 != nil {
		return resp.JSON200, nil
	}
	return nil, fmt.Errorf("unexpected status code: %d", resp.StatusCode())
}

// GetVorgangspositionList retrieves a list of Vorgangspositionen
func (c *Client) GetVorgangspositionList(ctx context.Context, params *client.GetVorgangspositionListParams) (*client.VorgangspositionListResponse, error) {
	resp, err := c.client.GetVorgangspositionListWithResponse(ctx, params)
	if err != nil {
		return nil, err
	}
	if resp.JSON200 != nil {
		return resp.JSON200, nil
	}
	return nil, fmt.Errorf("unexpected status code: %d", resp.StatusCode())
}
