// Package client contains code generation directives for the DIP API client.
package client

//go:generate go run github.com/oapi-codegen/oapi-codegen/v2/cmd/oapi-codegen -config cfg_client.yaml openapi_offical.yaml
//go:generate go run github.com/oapi-codegen/oapi-codegen/v2/cmd/oapi-codegen -config cfg_models.yaml openapi_offical.yaml
