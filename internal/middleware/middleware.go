package middleware

import (
	"net/http"
	"strings"
	"sync"
	"time"

	"app/internal/response"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
)

// Kunci konteks Gin yang diisi oleh middleware Auth.
const (
	CtxUserID   = "userID"
	CtxUsername = "username"
	CtxUserRole = "userRole"
)

// Claims adalah isi payload JWT aplikasi.
type Claims struct {
	UserID   uint   `json:"user_id"`
	Username string `json:"username"`
	Role     string `json:"role"`
	jwt.RegisteredClaims
}

// CORS mengizinkan akses lintas-domain dan menjawab preflight OPTIONS dengan 204.
func CORS() gin.HandlerFunc {
	return func(c *gin.Context) {
		h := c.Writer.Header()
		h.Set("Access-Control-Allow-Origin", "*")
		h.Set("Access-Control-Allow-Headers", "Content-Type, Content-Length, Accept-Encoding, Authorization, Accept, Origin, Cache-Control, X-Requested-With")
		h.Set("Access-Control-Allow-Methods", "POST, OPTIONS, GET, PUT, PATCH, DELETE")

		if c.Request.Method == http.MethodOptions {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}
		c.Next()
	}
}

// Auth memverifikasi Bearer JWT (HS256) dan menaruh identitas pengguna di konteks.
func Auth(secret string) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			response.AbortFail(c, http.StatusUnauthorized, "Tidak terautentikasi: header Authorization tidak ditemukan")
			return
		}

		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || !strings.EqualFold(parts[0], "bearer") {
			response.AbortFail(c, http.StatusUnauthorized, "Tidak terautentikasi: format header Authorization tidak valid")
			return
		}

		claims := &Claims{}
		token, err := jwt.ParseWithClaims(parts[1], claims, func(*jwt.Token) (any, error) {
			return []byte(secret), nil
		}, jwt.WithValidMethods([]string{jwt.SigningMethodHS256.Alg()}))
		if err != nil || !token.Valid {
			response.AbortFail(c, http.StatusUnauthorized, "Tidak terautentikasi: token tidak valid atau sudah kedaluwarsa")
			return
		}

		c.Set(CtxUserID, claims.UserID)
		c.Set(CtxUsername, claims.Username)
		c.Set(CtxUserRole, claims.Role)
		c.Next()
	}
}

// RequireRole hanya meneruskan request bila peran pengguna termasuk allowedRoles.
func RequireRole(allowedRoles ...string) gin.HandlerFunc {
	return func(c *gin.Context) {
		role, _ := c.Get(CtxUserRole)
		for _, r := range allowedRoles {
			if r == role {
				c.Next()
				return
			}
		}
		response.AbortFail(c, http.StatusForbidden, "Dilarang: hak akses tidak mencukupi")
	}
}

type rateBucket struct {
	count   int
	resetAt time.Time
}

// purgeThreshold adalah jumlah IP tercatat yang memicu pembersihan bucket kedaluwarsa.
const purgeThreshold = 4096

// RateLimiter membatasi jumlah request per IP dalam satu jendela waktu.
func RateLimiter(maxRequests int, per time.Duration) gin.HandlerFunc {
	var mu sync.Mutex
	buckets := make(map[string]*rateBucket)

	return func(c *gin.Context) {
		ip := c.ClientIP()
		now := time.Now()

		mu.Lock()
		if len(buckets) >= purgeThreshold {
			for k, b := range buckets {
				if now.After(b.resetAt) {
					delete(buckets, k)
				}
			}
		}
		b, ok := buckets[ip]
		if !ok || now.After(b.resetAt) {
			b = &rateBucket{resetAt: now.Add(per)}
			buckets[ip] = b
		}
		b.count++
		allowed := b.count <= maxRequests
		mu.Unlock()

		if !allowed {
			response.AbortFail(c, http.StatusTooManyRequests, "Terlalu banyak permintaan. Silakan coba lagi sebentar lagi.")
			return
		}
		c.Next()
	}
}
