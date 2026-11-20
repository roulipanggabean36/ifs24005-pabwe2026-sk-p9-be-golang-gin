package config

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
)

var envKeys = []string{
	"APP_PORT", "APP_ENV", "APP_KEY", "ADMIN_USERNAME", "ADMIN_PASSWORD",
	"DB_CONNECTION", "DB_HOST", "DB_PORT", "DB_DATABASE", "DB_USERNAME", "DB_PASSWORD", "DB_SSLMODE",
	"SEARCH_ENGINE_ENDPOINT", "OPENAI_ENDPOINT", "OPENAI_KEY", "OPENAI_MODEL",
}

func clearEnv(t *testing.T) {
	for _, k := range envKeys {
		t.Setenv(k, "")
	}
}

func TestLoadConfigDefaults(t *testing.T) {
	clearEnv(t)
	cfg := LoadConfig(filepath.Join(t.TempDir(), "tidak-ada.env"))

	assert.Equal(t, "8081", cfg.AppPort)
	assert.Equal(t, "development", cfg.AppEnv)
	assert.Equal(t, "delcom_blog_secret_key_super_secure_2026_random_string_32chars", cfg.AppKey)
	assert.Equal(t, "admin", cfg.AdminUsername)
	assert.Equal(t, "admin", cfg.AdminPassword)
	assert.Equal(t, "pgsql", cfg.DBConnection)
	assert.Equal(t, "127.0.0.1", cfg.DBHost)
	assert.Equal(t, "5432", cfg.DBPort)
	assert.Equal(t, "pabwe_p9_blog", cfg.DBDatabase)
	assert.Equal(t, "postgres", cfg.DBUsername)
	assert.Equal(t, "postgres", cfg.DBPassword)
	assert.Equal(t, "disable", cfg.DBSSLMode)
	assert.Equal(t, "https://delcom.org/api/v1/search", cfg.SearchEngineEndpoint)
	assert.Equal(t, "https://delcom.org/api/v1", cfg.OpenAIEndpoint)
	assert.Equal(t, "key", cfg.OpenAIKey)
	assert.Equal(t, "nama-model", cfg.OpenAIModel)
}

func TestLoadConfigFromEnvironment(t *testing.T) {
	clearEnv(t)
	t.Setenv("APP_PORT", "9000")
	t.Setenv("DB_DATABASE", "lain")
	t.Setenv("OPENAI_MODEL", "model-x")

	cfg := LoadConfig("")
	assert.Equal(t, "9000", cfg.AppPort)
	assert.Equal(t, "lain", cfg.DBDatabase)
	assert.Equal(t, "model-x", cfg.OpenAIModel)
}

func TestLoadConfigFromEnvFile(t *testing.T) {
	clearEnv(t)
	path := filepath.Join(t.TempDir(), ".env")
	assert.NoError(t, os.WriteFile(path, []byte("APP_PORT=7777\nSEARCH_ENGINE_ENDPOINT=http://cari.test\n"), 0o600))
	// godotenv tidak menimpa variabel yang sudah ada, jadi hapus dulu (t.Setenv memulihkan nilai awal).
	for _, k := range []string{"APP_PORT", "SEARCH_ENGINE_ENDPOINT"} {
		assert.NoError(t, os.Unsetenv(k))
	}
	t.Cleanup(func() {
		for _, k := range []string{"APP_PORT", "SEARCH_ENGINE_ENDPOINT"} {
			_ = os.Unsetenv(k)
		}
	})

	cfg := LoadConfig(path)
	assert.Equal(t, "7777", cfg.AppPort)
	assert.Equal(t, "http://cari.test", cfg.SearchEngineEndpoint)
}

func TestDSN(t *testing.T) {
	cfg := &Config{DBHost: "h", DBUsername: "u", DBPassword: "p", DBDatabase: "d", DBPort: "1", DBSSLMode: "disable"}
	assert.Equal(t, "host=h user=u password=p dbname=d port=1 sslmode=disable TimeZone=Asia/Jakarta", cfg.DSN())
}
