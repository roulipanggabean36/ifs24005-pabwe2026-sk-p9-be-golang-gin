package middleware

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/stretchr/testify/assert"
)

const secret = "rahasia-test"

func init() { gin.SetMode(gin.TestMode) }

func token(t *testing.T, role string, exp time.Duration, method jwt.SigningMethod, key any) string {
	claims := &Claims{
		UserID: 7, Username: "budi", Role: role,
		RegisteredClaims: jwt.RegisteredClaims{ExpiresAt: jwt.NewNumericDate(time.Now().Add(exp))},
	}
	s, err := jwt.NewWithClaims(method, claims).SignedString(key)
	assert.NoError(t, err)
	return s
}

func do(r *gin.Engine, method, path, auth string) *httptest.ResponseRecorder {
	req := httptest.NewRequest(method, path, nil)
	if auth != "" {
		req.Header.Set("Authorization", auth)
	}
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	return w
}

func TestCORS(t *testing.T) {
	r := gin.New()
	r.Use(CORS())
	r.GET("/x", func(c *gin.Context) { c.String(200, "ok") })

	w := do(r, http.MethodGet, "/x", "")
	assert.Equal(t, 200, w.Code)
	assert.Equal(t, "*", w.Header().Get("Access-Control-Allow-Origin"))

	w = do(r, http.MethodOptions, "/x", "")
	assert.Equal(t, http.StatusNoContent, w.Code)
	assert.Contains(t, w.Header().Get("Access-Control-Allow-Methods"), "PATCH")
}

func TestAuth(t *testing.T) {
	r := gin.New()
	r.Use(Auth(secret))
	r.GET("/me", func(c *gin.Context) {
		c.JSON(200, gin.H{"id": c.GetUint(CtxUserID), "u": c.GetString(CtxUsername), "r": c.GetString(CtxUserRole)})
	})

	assert.Equal(t, 401, do(r, "GET", "/me", "").Code)
	assert.Equal(t, 401, do(r, "GET", "/me", "Token abc").Code)
	assert.Equal(t, 401, do(r, "GET", "/me", "Bearer").Code)
	assert.Equal(t, 401, do(r, "GET", "/me", "Bearer sampah").Code)
	assert.Equal(t, 401, do(r, "GET", "/me", "Bearer "+token(t, "member", time.Hour, jwt.SigningMethodHS256, []byte("salah"))).Code)
	assert.Equal(t, 401, do(r, "GET", "/me", "Bearer "+token(t, "member", -time.Hour, jwt.SigningMethodHS256, []byte(secret))).Code)
	assert.Equal(t, 401, do(r, "GET", "/me", "Bearer "+token(t, "member", time.Hour, jwt.SigningMethodHS512, []byte(secret))).Code)

	w := do(r, "GET", "/me", "bearer "+token(t, "member", time.Hour, jwt.SigningMethodHS256, []byte(secret)))
	assert.Equal(t, 200, w.Code)
	assert.JSONEq(t, `{"id":7,"u":"budi","r":"member"}`, w.Body.String())
}

func TestRequireRole(t *testing.T) {
	r := gin.New()
	r.GET("/anon", RequireRole("admin"), func(c *gin.Context) { c.String(200, "ok") })
	r.Use(Auth(secret))
	r.GET("/admin", RequireRole("admin"), func(c *gin.Context) { c.String(200, "ok") })

	assert.Equal(t, 403, do(r, "GET", "/anon", "").Code)
	assert.Equal(t, 401, do(r, "GET", "/admin", "").Code)
	assert.Equal(t, 403, do(r, "GET", "/admin", "Bearer "+token(t, "member", time.Hour, jwt.SigningMethodHS256, []byte(secret))).Code)
	assert.Equal(t, 200, do(r, "GET", "/admin", "Bearer "+token(t, "admin", time.Hour, jwt.SigningMethodHS256, []byte(secret))).Code)
}

func TestRateLimiter(t *testing.T) {
	r := gin.New()
	r.Use(RateLimiter(2, 80*time.Millisecond))
	r.GET("/x", func(c *gin.Context) { c.String(200, "ok") })

	assert.Equal(t, 200, do(r, "GET", "/x", "").Code)
	assert.Equal(t, 200, do(r, "GET", "/x", "").Code)
	assert.Equal(t, 429, do(r, "GET", "/x", "").Code)

	time.Sleep(120 * time.Millisecond)
	assert.Equal(t, 200, do(r, "GET", "/x", "").Code)
}

func TestRateLimiterPurgesExpiredBuckets(t *testing.T) {
	r := gin.New()
	r.Use(RateLimiter(5, 300*time.Millisecond))
	r.GET("/x", func(c *gin.Context) { c.String(200, "ok") })

	hit := func(ip string) int {
		req := httptest.NewRequest("GET", "/x", nil)
		req.RemoteAddr = ip + ":1234"
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)
		return w.Code
	}
	// Bucket "lama" dibuat lebih dulu dan kedaluwarsa sebelum pembersihan terjadi.
	assert.Equal(t, 200, hit("172.16.0.1"))
	time.Sleep(350 * time.Millisecond)
	// Bucket "segar" tidak boleh ikut terhapus saat pembersihan.
	for i := 0; i < purgeThreshold-1; i++ {
		assert.Equal(t, 200, hit(fmt.Sprintf("10.%d.%d.1", i/250, i%250)))
	}
	// Jumlah bucket kini mencapai ambang: request ini memicu pembersihan.
	assert.Equal(t, 200, hit("192.168.0.1"))
}
