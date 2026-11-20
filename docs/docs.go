// Package docs memuat spesifikasi OpenAPI Delcom Blog (di-embed dari api.json).
package docs

import (
	_ "embed"
	"encoding/json"

	"github.com/swaggo/swag"
)

// ApiJSON adalah spesifikasi OpenAPI 2.0 yang di-embed saat kompilasi.
//
//go:embed api.json
var ApiJSON []byte

// SwaggerInfo menampung informasi Swagger yang dapat diubah klien.
var SwaggerInfo = &swag.Spec{
	Version:          "1.0.0",
	Host:             "",
	BasePath:         "/",
	Schemes:          []string{},
	Title:            "Delcom Blog REST API",
	Description:      "Dokumentasi RESTful API Delcom Blog (Golang Gin, Feature-First) dengan AI Blog Generator terintegrasi Search Engine.",
	InfoInstanceName: "swagger",
	SwaggerTemplate:  string(ApiJSON),
	LeftDelim:        "{{",
	RightDelim:       "}}",
}

// GetSwaggerJSON mengembalikan api.json dengan host dan scheme disesuaikan dengan URL request saat ini.
func GetSwaggerJSON(host, scheme string) []byte {
	var doc map[string]any
	if err := json.Unmarshal(ApiJSON, &doc); err != nil {
		return ApiJSON
	}
	if host != "" {
		doc["host"] = host
	}
	if scheme != "" {
		doc["schemes"] = []string{scheme}
	}
	updated, err := json.MarshalIndent(doc, "", "  ")
	if err != nil {
		return ApiJSON
	}
	return updated
}

func init() {
	swag.Register(SwaggerInfo.InstanceName(), SwaggerInfo)
}
