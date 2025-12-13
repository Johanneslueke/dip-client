package dipclient

import (
	"context"
	"errors"
	"net/http"
	"testing"

	client "dpi/internal/gen"
)

// mockClientWithResponses is a mock implementation for testing
type mockClientWithResponses struct {
	getAktivitaetResp              *client.GetAktivitaetResponse
	getAktivitaetListResp          *client.GetAktivitaetListResponse
	getDrucksacheResp              *client.GetDrucksacheResponse
	getDrucksacheListResp          *client.GetDrucksacheListResponse
	getDrucksacheTextResp          *client.GetDrucksacheTextResponse
	getDrucksacheTextListResp      *client.GetDrucksacheTextListResponse
	getPersonResp                  *client.GetPersonResponse
	getPersonListResp              *client.GetPersonListResponse
	getPlenarprotokollResp         *client.GetPlenarprotokollResponse
	getPlenarprotokollListResp     *client.GetPlenarprotokollListResponse
	getPlenarprotokollTextResp     *client.GetPlenarprotokollTextResponse
	getPlenarprotokollTextListResp *client.GetPlenarprotokollTextListResponse
	getVorgangResp                 *client.GetVorgangResponse
	getVorgangListResp             *client.GetVorgangListResponse
	getVorgangspositionResp        *client.GetVorgangspositionResponse
	getVorgangspositionListResp    *client.GetVorgangspositionListResponse
	err                            error
}

func (m *mockClientWithResponses) GetAktivitaetWithResponse(ctx context.Context, id client.Id, params *client.GetAktivitaetParams, reqEditors ...client.RequestEditorFn) (*client.GetAktivitaetResponse, error) {
	return m.getAktivitaetResp, m.err
}

func (m *mockClientWithResponses) GetAktivitaetListWithResponse(ctx context.Context, params *client.GetAktivitaetListParams, reqEditors ...client.RequestEditorFn) (*client.GetAktivitaetListResponse, error) {
	return m.getAktivitaetListResp, m.err
}

func (m *mockClientWithResponses) GetDrucksacheWithResponse(ctx context.Context, id client.Id, params *client.GetDrucksacheParams, reqEditors ...client.RequestEditorFn) (*client.GetDrucksacheResponse, error) {
	return m.getDrucksacheResp, m.err
}

func (m *mockClientWithResponses) GetDrucksacheListWithResponse(ctx context.Context, params *client.GetDrucksacheListParams, reqEditors ...client.RequestEditorFn) (*client.GetDrucksacheListResponse, error) {
	return m.getDrucksacheListResp, m.err
}

func (m *mockClientWithResponses) GetDrucksacheTextWithResponse(ctx context.Context, id client.Id, params *client.GetDrucksacheTextParams, reqEditors ...client.RequestEditorFn) (*client.GetDrucksacheTextResponse, error) {
	return m.getDrucksacheTextResp, m.err
}

func (m *mockClientWithResponses) GetDrucksacheTextListWithResponse(ctx context.Context, params *client.GetDrucksacheTextListParams, reqEditors ...client.RequestEditorFn) (*client.GetDrucksacheTextListResponse, error) {
	return m.getDrucksacheTextListResp, m.err
}

func (m *mockClientWithResponses) GetPersonWithResponse(ctx context.Context, id client.Id, params *client.GetPersonParams, reqEditors ...client.RequestEditorFn) (*client.GetPersonResponse, error) {
	return m.getPersonResp, m.err
}

func (m *mockClientWithResponses) GetPersonListWithResponse(ctx context.Context, params *client.GetPersonListParams, reqEditors ...client.RequestEditorFn) (*client.GetPersonListResponse, error) {
	return m.getPersonListResp, m.err
}

func (m *mockClientWithResponses) GetPlenarprotokollWithResponse(ctx context.Context, id client.Id, params *client.GetPlenarprotokollParams, reqEditors ...client.RequestEditorFn) (*client.GetPlenarprotokollResponse, error) {
	return m.getPlenarprotokollResp, m.err
}

func (m *mockClientWithResponses) GetPlenarprotokollListWithResponse(ctx context.Context, params *client.GetPlenarprotokollListParams, reqEditors ...client.RequestEditorFn) (*client.GetPlenarprotokollListResponse, error) {
	return m.getPlenarprotokollListResp, m.err
}

func (m *mockClientWithResponses) GetPlenarprotokollTextWithResponse(ctx context.Context, id client.Id, params *client.GetPlenarprotokollTextParams, reqEditors ...client.RequestEditorFn) (*client.GetPlenarprotokollTextResponse, error) {
	return m.getPlenarprotokollTextResp, m.err
}

func (m *mockClientWithResponses) GetPlenarprotokollTextListWithResponse(ctx context.Context, params *client.GetPlenarprotokollTextListParams, reqEditors ...client.RequestEditorFn) (*client.GetPlenarprotokollTextListResponse, error) {
	return m.getPlenarprotokollTextListResp, m.err
}

func (m *mockClientWithResponses) GetVorgangWithResponse(ctx context.Context, id client.Id, params *client.GetVorgangParams, reqEditors ...client.RequestEditorFn) (*client.GetVorgangResponse, error) {
	return m.getVorgangResp, m.err
}

func (m *mockClientWithResponses) GetVorgangListWithResponse(ctx context.Context, params *client.GetVorgangListParams, reqEditors ...client.RequestEditorFn) (*client.GetVorgangListResponse, error) {
	return m.getVorgangListResp, m.err
}

func (m *mockClientWithResponses) GetVorgangspositionWithResponse(ctx context.Context, id client.Id, params *client.GetVorgangspositionParams, reqEditors ...client.RequestEditorFn) (*client.GetVorgangspositionResponse, error) {
	return m.getVorgangspositionResp, m.err
}

func (m *mockClientWithResponses) GetVorgangspositionListWithResponse(ctx context.Context, params *client.GetVorgangspositionListParams, reqEditors ...client.RequestEditorFn) (*client.GetVorgangspositionListResponse, error) {
	return m.getVorgangspositionListResp, m.err
}

func TestNew(t *testing.T) {
	tests := []struct {
		name    string
		cfg     Config
		wantErr bool
	}{
		{
			name: "valid config",
			cfg: Config{
				BaseURL: "https://api.example.com",
				APIKey:  "test-key",
			},
			wantErr: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := New(tt.cfg)
			if (err != nil) != tt.wantErr {
				t.Errorf("New() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
			if !tt.wantErr && got == nil {
				t.Error("New() returned nil client")
			}
			if !tt.wantErr && got.apiKey != tt.cfg.APIKey {
				t.Errorf("New() apiKey = %v, want %v", got.apiKey, tt.cfg.APIKey)
			}
		})
	}
}

func TestClient_GetAktivitaet(t *testing.T) {
	ctx := context.Background()
	testID := Id(123)

	tests := []struct {
		name    string
		mock    *mockClientWithResponses
		wantErr bool
	}{
		{
			name: "success",
			mock: &mockClientWithResponses{
				getAktivitaetResp: &client.GetAktivitaetResponse{
					JSON200: &Aktivitaet{},
				},
			},
			wantErr: false,
		},
		{
			name: "network error",
			mock: &mockClientWithResponses{
				err: errors.New("network error"),
			},
			wantErr: true,
		},
		{
			name: "non-200 status",
			mock: &mockClientWithResponses{
				getAktivitaetResp: &client.GetAktivitaetResponse{
					HTTPResponse: &http.Response{StatusCode: 404},
				},
			},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			c := &Client{client: wrapMock(tt.mock)}
			got, err := c.GetAktivitaet(ctx, testID, nil)
			if (err != nil) != tt.wantErr {
				t.Errorf("GetAktivitaet() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
			if !tt.wantErr && got == nil {
				t.Error("GetAktivitaet() returned nil")
			}
		})
	}
}

func TestClient_GetAktivitaetList(t *testing.T) {
	ctx := context.Background()

	tests := []struct {
		name    string
		mock    *mockClientWithResponses
		wantErr bool
	}{
		{
			name: "success",
			mock: &mockClientWithResponses{
				getAktivitaetListResp: &client.GetAktivitaetListResponse{
					JSON200: &AktivitaetListResponse{},
				},
			},
			wantErr: false,
		},
		{
			name: "network error",
			mock: &mockClientWithResponses{
				err: errors.New("network error"),
			},
			wantErr: true,
		},
		{
			name: "non-200 status",
			mock: &mockClientWithResponses{
				getAktivitaetListResp: &client.GetAktivitaetListResponse{
					HTTPResponse: &http.Response{StatusCode: 500},
				},
			},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			c := &Client{client: wrapMock(tt.mock)}
			got, err := c.GetAktivitaetList(ctx, nil)
			if (err != nil) != tt.wantErr {
				t.Errorf("GetAktivitaetList() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
			if !tt.wantErr && got == nil {
				t.Error("GetAktivitaetList() returned nil")
			}
		})
	}
}

func TestClient_GetDrucksache(t *testing.T) {
	ctx := context.Background()
	testID := Id(456)

	tests := []struct {
		name    string
		mock    *mockClientWithResponses
		wantErr bool
	}{
		{
			name: "success",
			mock: &mockClientWithResponses{
				getDrucksacheResp: &client.GetDrucksacheResponse{
					JSON200: &Drucksache{},
				},
			},
			wantErr: false,
		},
		{
			name: "error",
			mock: &mockClientWithResponses{
				err: errors.New("error"),
			},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			c := &Client{client: wrapMock(tt.mock)}
			got, err := c.GetDrucksache(ctx, testID, nil)
			if (err != nil) != tt.wantErr {
				t.Errorf("GetDrucksache() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
			if !tt.wantErr && got == nil {
				t.Error("GetDrucksache() returned nil")
			}
		})
	}
}

func TestClient_GetDrucksacheList(t *testing.T) {
	ctx := context.Background()

	c := &Client{
		client: wrapMock(&mockClientWithResponses{
			getDrucksacheListResp: &client.GetDrucksacheListResponse{
				JSON200: &DrucksacheListResponse{},
			},
		}),
	}

	got, err := c.GetDrucksacheList(ctx, nil)
	if err != nil {
		t.Errorf("GetDrucksacheList() error = %v", err)
		return
	}
	if got == nil {
		t.Error("GetDrucksacheList() returned nil")
	}
}

func TestClient_GetDrucksacheText(t *testing.T) {
	ctx := context.Background()
	testID := Id(111)

	c := &Client{
		client: wrapMock(&mockClientWithResponses{
			getDrucksacheTextResp: &client.GetDrucksacheTextResponse{
				JSON200: &DrucksacheText{},
			},
		}),
	}

	got, err := c.GetDrucksacheText(ctx, testID, nil)
	if err != nil {
		t.Errorf("GetDrucksacheText() error = %v", err)
		return
	}
	if got == nil {
		t.Error("GetDrucksacheText() returned nil")
	}
}

func TestClient_GetDrucksacheTextList(t *testing.T) {
	ctx := context.Background()

	c := &Client{
		client: wrapMock(&mockClientWithResponses{
			getDrucksacheTextListResp: &client.GetDrucksacheTextListResponse{
				JSON200: &DrucksacheTextListResponse{},
			},
		}),
	}

	got, err := c.GetDrucksacheTextList(ctx, nil)
	if err != nil {
		t.Errorf("GetDrucksacheTextList() error = %v", err)
		return
	}
	if got == nil {
		t.Error("GetDrucksacheTextList() returned nil")
	}
}

func TestClient_GetPerson(t *testing.T) {
	ctx := context.Background()
	testID := Id(789)

	c := &Client{
		client: wrapMock(&mockClientWithResponses{
			getPersonResp: &client.GetPersonResponse{
				JSON200: &Person{},
			},
		}),
	}

	got, err := c.GetPerson(ctx, testID, nil)
	if err != nil {
		t.Errorf("GetPerson() error = %v", err)
		return
	}
	if got == nil {
		t.Error("GetPerson() returned nil")
	}
}

func TestClient_GetPersonList(t *testing.T) {
	ctx := context.Background()

	c := &Client{
		client: wrapMock(&mockClientWithResponses{
			getPersonListResp: &client.GetPersonListResponse{
				JSON200: &PersonListResponse{},
			},
		}),
	}

	got, err := c.GetPersonList(ctx, nil)
	if err != nil {
		t.Errorf("GetPersonList() error = %v", err)
		return
	}
	if got == nil {
		t.Error("GetPersonList() returned nil")
	}
}

func TestClient_GetPlenarprotokoll(t *testing.T) {
	ctx := context.Background()
	testID := Id(222)

	c := &Client{
		client: wrapMock(&mockClientWithResponses{
			getPlenarprotokollResp: &client.GetPlenarprotokollResponse{
				JSON200: &Plenarprotokoll{},
			},
		}),
	}

	got, err := c.GetPlenarprotokoll(ctx, testID, nil)
	if err != nil {
		t.Errorf("GetPlenarprotokoll() error = %v", err)
		return
	}
	if got == nil {
		t.Error("GetPlenarprotokoll() returned nil")
	}
}

func TestClient_GetPlenarprotokollList(t *testing.T) {
	ctx := context.Background()

	c := &Client{
		client: wrapMock(&mockClientWithResponses{
			getPlenarprotokollListResp: &client.GetPlenarprotokollListResponse{
				JSON200: &PlenarprotokollListResponse{},
			},
		}),
	}

	got, err := c.GetPlenarprotokollList(ctx, nil)
	if err != nil {
		t.Errorf("GetPlenarprotokollList() error = %v", err)
		return
	}
	if got == nil {
		t.Error("GetPlenarprotokollList() returned nil")
	}
}

func TestClient_GetPlenarprotokollText(t *testing.T) {
	ctx := context.Background()
	testID := Id(333)

	c := &Client{
		client: wrapMock(&mockClientWithResponses{
			getPlenarprotokollTextResp: &client.GetPlenarprotokollTextResponse{
				JSON200: &PlenarprotokollText{},
			},
		}),
	}

	got, err := c.GetPlenarprotokollText(ctx, testID, nil)
	if err != nil {
		t.Errorf("GetPlenarprotokollText() error = %v", err)
		return
	}
	if got == nil {
		t.Error("GetPlenarprotokollText() returned nil")
	}
}

func TestClient_GetPlenarprotokollTextList(t *testing.T) {
	ctx := context.Background()

	c := &Client{
		client: wrapMock(&mockClientWithResponses{
			getPlenarprotokollTextListResp: &client.GetPlenarprotokollTextListResponse{
				JSON200: &PlenarprotokollTextListResponse{},
			},
		}),
	}

	got, err := c.GetPlenarprotokollTextList(ctx, nil)
	if err != nil {
		t.Errorf("GetPlenarprotokollTextList() error = %v", err)
		return
	}
	if got == nil {
		t.Error("GetPlenarprotokollTextList() returned nil")
	}
}

func TestClient_GetVorgang(t *testing.T) {
	ctx := context.Background()
	testID := Id(101)

	c := &Client{
		client: wrapMock(&mockClientWithResponses{
			getVorgangResp: &client.GetVorgangResponse{
				JSON200: &Vorgang{},
			},
		}),
	}

	got, err := c.GetVorgang(ctx, testID, nil)
	if err != nil {
		t.Errorf("GetVorgang() error = %v", err)
		return
	}
	if got == nil {
		t.Error("GetVorgang() returned nil")
	}
}

func TestClient_GetVorgangList(t *testing.T) {
	ctx := context.Background()

	c := &Client{
		client: wrapMock(&mockClientWithResponses{
			getVorgangListResp: &client.GetVorgangListResponse{
				JSON200: &VorgangListResponse{},
			},
		}),
	}

	got, err := c.GetVorgangList(ctx, nil)
	if err != nil {
		t.Errorf("GetVorgangList() error = %v", err)
		return
	}
	if got == nil {
		t.Error("GetVorgangList() returned nil")
	}
}

func TestClient_GetVorgangsposition(t *testing.T) {
	ctx := context.Background()
	testID := Id(202)

	c := &Client{
		client: wrapMock(&mockClientWithResponses{
			getVorgangspositionResp: &client.GetVorgangspositionResponse{
				JSON200: &Vorgangsposition{},
			},
		}),
	}

	got, err := c.GetVorgangsposition(ctx, testID, nil)
	if err != nil {
		t.Errorf("GetVorgangsposition() error = %v", err)
		return
	}
	if got == nil {
		t.Error("GetVorgangsposition() returned nil")
	}
}

func TestClient_GetVorgangspositionList(t *testing.T) {
	ctx := context.Background()

	c := &Client{
		client: wrapMock(&mockClientWithResponses{
			getVorgangspositionListResp: &client.GetVorgangspositionListResponse{
				JSON200: &VorgangspositionListResponse{},
			},
		}),
	}

	got, err := c.GetVorgangspositionList(ctx, nil)
	if err != nil {
		t.Errorf("GetVorgangspositionList() error = %v", err)
		return
	}
	if got == nil {
		t.Error("GetVorgangspositionList() returned nil")
	}
}

// wrapMock returns the mock as the interface type
func wrapMock(mock *mockClientWithResponses) client.ClientWithResponsesInterface {
	return mock
}
