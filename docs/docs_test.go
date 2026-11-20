package docs

import (
	"encoding/json"
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestGetSwaggerJSON(t *testing.T) {
	data := GetSwaggerJSON("api.example.com:8443", "https")
	var doc map[string]any
	require.NoError(t, json.Unmarshal(data, &doc))
	assert.Equal(t, "api.example.com:8443", doc["host"])
	assert.Equal(t, []any{"https"}, doc["schemes"])

	var original map[string]any
	require.NoError(t, json.Unmarshal(GetSwaggerJSON("", ""), &original))
	assert.Equal(t, "localhost:8081", original["host"])
	assert.Equal(t, []any{"http"}, original["schemes"])
}

func TestGetSwaggerJSONInvalidFallback(t *testing.T) {
	orig := ApiJSON
	defer func() { ApiJSON = orig }()
	ApiJSON = []byte("bukan json")
	assert.Equal(t, []byte("bukan json"), GetSwaggerJSON("api.test", "http"))
}

func TestSpecMetadata(t *testing.T) {
	var doc map[string]any
	require.NoError(t, json.Unmarshal(ApiJSON, &doc))
	info := doc["info"].(map[string]any)
	assert.Equal(t, "Delcom Blog REST API", info["title"])
	assert.Equal(t, "Delcom - Labs", info["contact"].(map[string]any)["name"])
	assert.Contains(t, doc["securityDefinitions"], "BearerAuth")
	assert.Equal(t, "Delcom Blog REST API", SwaggerInfo.Title)
}

func TestSwaggerFilesAreConsistent(t *testing.T) {
	apiJSON, err := os.ReadFile("api.json")
	require.NoError(t, err)
	swaggerJSON, err := os.ReadFile("swagger.json")
	require.NoError(t, err)
	assert.JSONEq(t, string(apiJSON), string(swaggerJSON))
	assert.Equal(t, string(apiJSON), string(ApiJSON))

	yamlRaw, err := os.ReadFile("swagger.yaml")
	require.NoError(t, err)
	assert.Contains(t, string(yamlRaw), "title: Delcom Blog REST API")
	assert.Contains(t, string(yamlRaw), "/api/posts/ai-generate:")
}
