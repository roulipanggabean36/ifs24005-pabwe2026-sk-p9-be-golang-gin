package server

import (
	"bytes"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"sort"
	"strings"
	"testing"

	"app/docs"
	"app/internal/config"
	"app/internal/database"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

type fixture struct {
	r      *gin.Engine
	cfg    *config.Config
	search *httptest.Server
	openai *httptest.Server
}

func newFixture(t *testing.T) *fixture {
	gin.SetMode(gin.TestMode)
	search := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = io.WriteString(w, `{"data":{"results":[{"title":"Toba","url":"https://toba.id","snippet":"kaldera"}]}}`)
	}))
	mux := http.NewServeMux()
	mux.HandleFunc("/models", func(w http.ResponseWriter, r *http.Request) { _, _ = io.WriteString(w, `{}`) })
	mux.HandleFunc("/chat/completions", func(w http.ResponseWriter, r *http.Request) {
		content := "```json\n" + `{"title":"Artikel AI","category":"opini","excerpt":"Ringkas","content":"## Isi\n\nTeks\n\n## Referensi\n- Toba"}` + "\n```"
		b, _ := json.Marshal(map[string]any{"choices": []any{map[string]any{"message": map[string]any{"content": content}}}})
		_, _ = w.Write(b)
	})
	openai := httptest.NewServer(mux)
	t.Cleanup(search.Close)
	t.Cleanup(openai.Close)

	cfg := &config.Config{
		AppEnv: "development", AppKey: "kunci-router-uji", AdminUsername: "admin", AdminPassword: "admin",
		SearchEngineEndpoint: search.URL, OpenAIEndpoint: openai.URL, OpenAIKey: "k", OpenAIModel: "m",
	}
	db, err := database.ConnectTest()
	require.NoError(t, err)
	require.NoError(t, database.Seed(db, cfg))
	return &fixture{r: SetupRouter(cfg, db), cfg: cfg, search: search, openai: openai}
}

type result struct {
	Code    int
	Status  string          `json:"status"`
	Message string          `json:"message"`
	Data    json.RawMessage `json:"data"`
	Raw     *httptest.ResponseRecorder
}

func (f *fixture) do(method, path, token string, body any, headers ...string) result {
	var buf bytes.Buffer
	if body != nil {
		_ = json.NewEncoder(&buf).Encode(body)
	}
	req := httptest.NewRequest(method, path, &buf)
	req.Header.Set("Content-Type", "application/json")
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	for i := 0; i+1 < len(headers); i += 2 {
		req.Header.Set(headers[i], headers[i+1])
	}
	w := httptest.NewRecorder()
	f.r.ServeHTTP(w, req)
	res := result{Code: w.Code, Raw: w}
	_ = json.Unmarshal(w.Body.Bytes(), &res)
	return res
}

func (f *fixture) login(t *testing.T, username, password string) string {
	res := f.do("POST", "/api/auth/login", "", gin.H{"username": username, "password": password})
	require.Equal(t, 200, res.Code, res.Message)
	var data struct{ Token string }
	require.NoError(t, json.Unmarshal(res.Data, &data))
	return data.Token
}

func TestRoutesMatchOpenAPIDocument(t *testing.T) {
	f := newFixture(t)

	var spec struct {
		Paths map[string]map[string]json.RawMessage `json:"paths"`
	}
	require.NoError(t, json.Unmarshal(docs.ApiJSON, &spec))
	documented := map[string]bool{}
	for path, methods := range spec.Paths {
		for m := range methods {
			documented[strings.ToUpper(m)+" "+path] = true
		}
	}

	registered := map[string]bool{}
	for _, rt := range f.r.Routes() {
		if rt.Path == "/swagger" { // alias pengalihan ke /swagger/index.html
			continue
		}
		path := rt.Path
		for _, seg := range strings.Split(path, "/") {
			if strings.HasPrefix(seg, ":") || strings.HasPrefix(seg, "*") {
				path = strings.Replace(path, seg, "{"+seg[1:]+"}", 1)
			}
		}
		registered[rt.Method+" "+path] = true
	}

	keys := func(m map[string]bool) []string {
		out := make([]string, 0, len(m))
		for k := range m {
			out = append(out, k)
		}
		sort.Strings(out)
		return out
	}
	assert.Equal(t, keys(registered), keys(documented), "rute router harus identik dengan api.json")
	assert.Len(t, registered, 21)
}

func TestNoRouteAndCORS(t *testing.T) {
	f := newFixture(t)
	res := f.do("GET", "/api/xyz", "", nil)
	assert.Equal(t, 404, res.Code)
	assert.Equal(t, "fail", res.Status)
	assert.Equal(t, "Endpoint not found", res.Message)

	pre := f.do("OPTIONS", "/api/posts", "", nil, "Origin", "https://blog.example", "Access-Control-Request-Method", "POST")
	assert.Equal(t, 204, pre.Code)
	assert.Equal(t, "*", pre.Raw.Header().Get("Access-Control-Allow-Origin"))
}

func TestSwaggerRoutes(t *testing.T) {
	f := newFixture(t)

	for _, p := range []string{"/swagger", "/swagger/"} {
		res := f.do("GET", p, "", nil)
		assert.Equal(t, 301, res.Code, p)
		assert.Equal(t, "/swagger/index.html", res.Raw.Header().Get("Location"), p)
	}

	ui := f.do("GET", "/swagger/index.html", "", nil)
	assert.Equal(t, 200, ui.Code)
	assert.Contains(t, ui.Raw.Body.String(), "swagger-initializer.js")
	init := f.do("GET", "/swagger/swagger-initializer.js", "", nil)
	assert.Equal(t, 200, init.Code)
	assert.Contains(t, init.Raw.Body.String(), "/swagger/api.json")
	assert.Equal(t, 200, f.do("GET", "/swagger/swagger-ui.css", "", nil).Code)

	for _, p := range []string{"/swagger/api.json", "/swagger/doc.json", "/api.json"} {
		res := f.do("GET", p, "", nil)
		assert.Equal(t, 200, res.Code, p)
		assert.Contains(t, res.Raw.Header().Get("Content-Type"), "application/json")
		var doc map[string]any
		require.NoError(t, json.Unmarshal(res.Raw.Body.Bytes(), &doc), p)
		assert.Equal(t, "Delcom Blog REST API", doc["info"].(map[string]any)["title"])
	}
}

func TestAPIJSONIsDynamic(t *testing.T) {
	f := newFixture(t)
	get := func(headers ...string) map[string]any {
		res := f.do("GET", "/api.json", "", nil, headers...)
		var doc map[string]any
		require.NoError(t, json.Unmarshal(res.Raw.Body.Bytes(), &doc))
		return doc
	}

	doc := get()
	assert.Equal(t, "example.com", doc["host"])
	assert.Equal(t, []any{"http"}, doc["schemes"])

	doc = get("X-Forwarded-Host", "blog.delcom.org", "X-Forwarded-Proto", "https")
	assert.Equal(t, "blog.delcom.org", doc["host"])
	assert.Equal(t, []any{"https"}, doc["schemes"])

	req := httptest.NewRequest("GET", "/api.json", nil)
	req.TLS = &tls.ConnectionState{}
	w := httptest.NewRecorder()
	f.r.ServeHTTP(w, req)
	assert.Contains(t, w.Body.String(), `"https"`)
}

func TestProductionModeUsesReleaseMode(t *testing.T) {
	gin.SetMode(gin.TestMode)
	t.Cleanup(func() { gin.SetMode(gin.TestMode) })
	db, err := database.ConnectTest()
	require.NoError(t, err)
	SetupRouter(&config.Config{AppEnv: "production", AppKey: "k"}, db)
	assert.Equal(t, gin.ReleaseMode, gin.Mode())
}

func TestPublicEndpoints(t *testing.T) {
	f := newFixture(t)

	cats := f.do("GET", "/api/public/categories", "", nil)
	assert.Equal(t, 200, cats.Code)
	assert.JSONEq(t, `["Teknologi","Pendidikan","Gaya Hidup","Bisnis","Opini","Umum"]`, string(cats.Data))

	var posts []struct {
		Slug        string `json:"slug"`
		Category    string `json:"category"`
		IsPublished bool   `json:"is_published"`
		ReadingTime int    `json:"reading_time"`
		Author      struct{ Username string }
	}
	list := f.do("GET", "/api/public/posts", "", nil)
	require.Equal(t, 200, list.Code)
	require.NoError(t, json.Unmarshal(list.Data, &posts))
	assert.Len(t, posts, 7, "hanya artikel terbit dari seeder")
	for _, p := range posts {
		assert.True(t, p.IsPublished)
		assert.GreaterOrEqual(t, p.ReadingTime, 1)
		assert.NotEmpty(t, p.Author.Username)
	}

	_ = json.Unmarshal(f.do("GET", "/api/public/posts?q=CLEAN+architecture", "", nil).Data, &posts)
	require.Len(t, posts, 1)
	assert.Equal(t, "mengenal-clean-architecture-pada-aplikasi-go", posts[0].Slug)
	_ = json.Unmarshal(f.do("GET", "/api/public/posts?category=Bisnis", "", nil).Data, &posts)
	assert.Len(t, posts, 1)

	assert.Equal(t, 200, f.do("GET", "/api/public/posts/selamat-datang-di-delcom-blog", "", nil).Code)
	assert.Equal(t, 404, f.do("GET", "/api/public/posts/rencana-belajar-kubernetes-untuk-pemula", "", nil).Code, "draf tidak boleh publik")
}

func TestAuthFlow(t *testing.T) {
	f := newFixture(t)

	reg := f.do("POST", "/api/auth/register", "", gin.H{"username": "budi", "email": "budi@contoh.id", "password": "rahasia1", "role": "admin"})
	require.Equal(t, 201, reg.Code)
	assert.NotContains(t, string(reg.Data), "password")
	assert.Contains(t, string(reg.Data), `"role":"member"`)
	assert.Equal(t, 409, f.do("POST", "/api/auth/register", "", gin.H{"username": "budi", "email": "lain@contoh.id", "password": "rahasia1"}).Code)

	token := f.login(t, "budi@contoh.id", "rahasia1")
	assert.Equal(t, 200, f.do("GET", "/api/auth/profile", token, nil).Code)
	assert.Equal(t, 200, f.do("PUT", "/api/auth/profile", token, gin.H{"username": "budi", "email": "baru@contoh.id"}).Code)
	assert.Equal(t, 200, f.do("POST", "/api/auth/logout", token, nil).Code)

	assert.Equal(t, 401, f.do("GET", "/api/auth/profile", "", nil).Code)
	assert.Equal(t, 401, f.do("POST", "/api/auth/logout", "", nil).Code)
	bad := f.do("POST", "/api/auth/login", "", gin.H{"username": "budi", "password": "salah"})
	assert.Equal(t, 401, bad.Code)
	unknown := f.do("POST", "/api/auth/login", "", gin.H{"username": "hantu", "password": "salah"})
	assert.Equal(t, bad.Message, unknown.Message)
}

func TestAuthorWorkflowAndOwnership(t *testing.T) {
	f := newFixture(t)
	member := f.login(t, "member", "member")
	admin := f.login(t, "admin", "admin")

	assert.Equal(t, 401, f.do("GET", "/api/posts", "", nil).Code)

	var before struct {
		Total       int `json:"total"`
		TotalTerbit int `json:"total_terbit"`
	}
	require.NoError(t, json.Unmarshal(f.do("GET", "/api/posts/stats", member, nil).Data, &before))
	assert.Equal(t, 5, before.Total)

	created := f.do("POST", "/api/posts", member, gin.H{"title": "Catatan Baru", "content": strings.Repeat("kata ", 201), "category": "Opini"})
	require.Equal(t, 201, created.Code)
	var p struct {
		ID          int
		Slug        string
		ReadingTime int  `json:"reading_time"`
		IsPublished bool `json:"is_published"`
	}
	require.NoError(t, json.Unmarshal(created.Data, &p))
	assert.Equal(t, "catatan-baru", p.Slug)
	assert.Equal(t, 2, p.ReadingTime)
	assert.False(t, p.IsPublished)

	path := fmt.Sprintf("/api/posts/%d", p.ID)
	assert.Equal(t, 404, f.do("GET", path, admin, nil).Code, "milik orang lain → 404")
	assert.Equal(t, 404, f.do("PUT", path, admin, gin.H{"title": "x", "content": "x"}).Code)
	assert.Equal(t, 404, f.do("PATCH", path+"/toggle-publish", admin, nil).Code)
	assert.Equal(t, 404, f.do("DELETE", path, admin, nil).Code)

	assert.Equal(t, 404, f.do("GET", "/api/public/posts/catatan-baru", "", nil).Code)
	assert.Equal(t, 200, f.do("PATCH", path+"/toggle-publish", member, nil).Code)
	assert.Equal(t, 200, f.do("GET", "/api/public/posts/catatan-baru", "", nil).Code)

	var after struct {
		Total        int `json:"total"`
		TotalTerbit  int `json:"total_terbit"`
		TotalDraf    int `json:"total_draf"`
		TotalSelesai int `json:"total_selesai"`
		BelumSelesai int `json:"belum_selesai"`
	}
	require.NoError(t, json.Unmarshal(f.do("GET", "/api/posts/stats", member, nil).Data, &after))
	assert.Equal(t, before.Total+1, after.Total)
	assert.Equal(t, before.TotalTerbit+1, after.TotalTerbit)
	assert.Equal(t, after.TotalTerbit, after.TotalSelesai)
	assert.Equal(t, after.TotalDraf, after.BelumSelesai)

	mine := f.do("GET", "/api/posts", member, nil)
	assert.Equal(t, 200, mine.Code)
	assert.Equal(t, 200, f.do("PUT", path, member, gin.H{"title": "Catatan Final", "content": "isi"}).Code)
	assert.Equal(t, 200, f.do("DELETE", path, member, nil).Code)
	assert.Equal(t, 404, f.do("GET", path, member, nil).Code)
}

func TestAdminRBAC(t *testing.T) {
	f := newFixture(t)
	member := f.login(t, "member", "member")
	admin := f.login(t, "admin", "admin")

	for _, p := range []string{"/api/admin/users", "/api/admin/posts", "/api/admin/users/1/posts"} {
		assert.Equal(t, 401, f.do("GET", p, "", nil).Code, p)
		assert.Equal(t, 403, f.do("GET", p, member, nil).Code, p)
		assert.Equal(t, 200, f.do("GET", p, admin, nil).Code, p)
	}
	assert.Equal(t, 404, f.do("GET", "/api/admin/users/9999/posts", admin, nil).Code)

	var users []struct {
		Username       string
		TotalPosts     int `json:"total_posts"`
		TotalPublished int `json:"total_published"`
	}
	require.NoError(t, json.Unmarshal(f.do("GET", "/api/admin/users", admin, nil).Data, &users))
	require.Len(t, users, 2)
	total := 0
	for _, u := range users {
		total += u.TotalPosts
	}
	assert.Equal(t, 10, total)

	var all []struct{ Author struct{ Username string } }
	require.NoError(t, json.Unmarshal(f.do("GET", "/api/admin/posts", admin, nil).Data, &all))
	assert.Len(t, all, 10)
}

func TestAIGenerateThroughRouter(t *testing.T) {
	f := newFixture(t)
	token := f.login(t, "member", "member")

	assert.Equal(t, 401, f.do("POST", "/api/posts/ai-generate", "", gin.H{"topic": "x"}).Code)
	assert.Equal(t, 400, f.do("POST", "/api/posts/ai-generate", token, gin.H{"topic": " "}).Code)

	res := f.do("POST", "/api/posts/ai-generate", token, gin.H{"topic": "Danau Toba", "category": "Umum", "include_web_search": true})
	require.Equal(t, 200, res.Code, res.Message)
	var data struct {
		Title, Category, Excerpt, Content string
		SearchSources                     []struct{ Title, URL, Snippet string } `json:"search_sources"`
	}
	require.NoError(t, json.Unmarshal(res.Data, &data))
	assert.Equal(t, "Artikel AI", data.Title)
	assert.Equal(t, "Opini", data.Category)
	require.Len(t, data.SearchSources, 1)
	assert.Equal(t, "https://toba.id", data.SearchSources[0].URL)

	// Hasil AI tidak otomatis tersimpan.
	var stats struct {
		Total int `json:"total"`
	}
	require.NoError(t, json.Unmarshal(f.do("GET", "/api/posts/stats", token, nil).Data, &stats))
	assert.Equal(t, 5, stats.Total)

	// Tanpa web search: sumber kosong.
	res = f.do("POST", "/api/posts/ai-generate", token, gin.H{"topic": "Danau Toba"})
	require.Equal(t, 200, res.Code)
	assert.Contains(t, string(res.Data), `"search_sources":[]`)

	// OpenAI mati → 502 status error.
	f.openai.Close()
	down := f.do("POST", "/api/posts/ai-generate", token, gin.H{"topic": "Danau Toba"})
	assert.Equal(t, 502, down.Code)
	assert.Equal(t, "error", down.Status)
}

func TestStaticRoutesDoNotClashWithID(t *testing.T) {
	f := newFixture(t)
	token := f.login(t, "member", "member")
	assert.Equal(t, 200, f.do("GET", "/api/posts/stats", token, nil).Code)
	// GET /api/posts/ai-generate jatuh ke /:id (ID bukan angka), sedangkan POST menuju handler AI.
	assert.Equal(t, 400, f.do("GET", "/api/posts/ai-generate", token, nil).Code)
	assert.Equal(t, 400, f.do("POST", "/api/posts/ai-generate", token, gin.H{"topic": ""}).Code)
}
