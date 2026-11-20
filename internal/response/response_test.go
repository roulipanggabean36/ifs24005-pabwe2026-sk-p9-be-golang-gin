package response

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
)

func run(t *testing.T, h gin.HandlerFunc) (int, map[string]any) {
	gin.SetMode(gin.TestMode)
	w := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(w)
	c.Request = httptest.NewRequest(http.MethodGet, "/", nil)
	h(c)
	var body map[string]any
	assert.NoError(t, json.Unmarshal(w.Body.Bytes(), &body))
	return w.Code, body
}

func TestSuccessWithData(t *testing.T) {
	code, body := run(t, func(c *gin.Context) { Success(c, http.StatusOK, "ok", gin.H{"a": 1}) })
	assert.Equal(t, 200, code)
	assert.Equal(t, "success", body["status"])
	assert.Equal(t, "ok", body["message"])
	assert.Contains(t, body, "data")
}

func TestSuccessWithoutData(t *testing.T) {
	_, body := run(t, func(c *gin.Context) { Success(c, http.StatusOK, "ok") })
	assert.NotContains(t, body, "data")
	_, body = run(t, func(c *gin.Context) { Success(c, http.StatusOK, "ok", nil) })
	assert.NotContains(t, body, "data")
}

func TestFailAndError(t *testing.T) {
	code, body := run(t, func(c *gin.Context) { Fail(c, http.StatusBadRequest, "gagal") })
	assert.Equal(t, 400, code)
	assert.Equal(t, "fail", body["status"])

	code, body = run(t, func(c *gin.Context) { Error(c, http.StatusInternalServerError, "rusak") })
	assert.Equal(t, 500, code)
	assert.Equal(t, "error", body["status"])
}

func TestAbortVariants(t *testing.T) {
	code, body := run(t, func(c *gin.Context) { AbortFail(c, http.StatusUnauthorized, "tolak") })
	assert.Equal(t, 401, code)
	assert.Equal(t, "fail", body["status"])

	code, body = run(t, func(c *gin.Context) { AbortError(c, http.StatusBadGateway, "hulu") })
	assert.Equal(t, 502, code)
	assert.Equal(t, "error", body["status"])
}
