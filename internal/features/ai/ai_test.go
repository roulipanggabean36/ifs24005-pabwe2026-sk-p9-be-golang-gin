package ai

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

var errBoom = errors.New("boom")

func init() { gin.SetMode(gin.TestMode) }

// serve membuat httptest.Server yang menjawab body tertentu.
func serve(t *testing.T, status int, body string) *httptest.Server {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(status)
		_, _ = io.WriteString(w, body)
	}))
	t.Cleanup(srv.Close)
	return srv
}

// truncated menjanjikan 100 byte tetapi hanya mengirim sebagian, sehingga pembacaan body gagal.
func truncated(t *testing.T) *httptest.Server {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Length", "100")
		_, _ = io.WriteString(w, "pendek")
	}))
	t.Cleanup(srv.Close)
	return srv
}

func closedURL(t *testing.T) string {
	srv := httptest.NewServer(http.NotFoundHandler())
	u := srv.URL
	srv.Close()
	return u
}

var ctx = context.Background()

// ---------- search ----------

func TestSearchVariantsOfJSON(t *testing.T) {
	cases := map[string]struct {
		body string
		want []SearchSource
	}{
		"results": {`{"results":[{"title":"A","snippet":"sa","url":"https://a.id"}]}`,
			[]SearchSource{{"A", "https://a.id", "sa"}}},
		"data.results": {`{"data":{"results":[{"title":"B","content":"sb","link":"https://b.id"}]}}`,
			[]SearchSource{{"B", "https://b.id", "sb"}}},
		"data array": {`{"data":[{"name":"C","description":"sc","href":"http://c.id/x"}]}`,
			[]SearchSource{{"C", "http://c.id/x", "sc"}}},
		"items": {`{"items":[{"title":"D","text":"sd","url":"https://d.id"}]}`,
			[]SearchSource{{"D", "https://d.id", "sd"}}},
		"organic_results": {`{"organic_results":[{"title":"E","body":"se","url":"https://e.id"}]}`,
			[]SearchSource{{"E", "https://e.id", "se"}}},
		"top-level array": {`[{"title":"F","summary":"sf","url":"https://f.id"},"bukan objek"]`,
			[]SearchSource{{"F", "https://f.id", "sf"}}},
		"opensearch": {`["topik",["G","H"],["sg"],["https://g.id","https://h.id"]]`,
			[]SearchSource{{"G", "https://g.id", "sg"}, {"H", "https://h.id", ""}}},
		"wikipedia": {`{"query":{"search":[{"title":"Danau Toba","snippet":"<span class=\"x\">danau</span> &amp; kaldera"},"abaikan"]}}`,
			[]SearchSource{{"Danau Toba", "https://id.wikipedia.org/wiki/Danau_Toba", "danau & kaldera"}}},
		"title kosong memakai url": {`{"results":[{"url":"https://z.id","snippet":"s"}]}`,
			[]SearchSource{{"https://z.id", "https://z.id", "s"}}},
		"url berbahaya dibuang": {`{"results":[{"title":"X","url":"javascript:alert(1)","snippet":"s"},{"title":"Y","url":"ftp://y.id"},{"title":"Z","url":"https:///tanpa-host"},{"title":"W","url":"http://[::1"}]}`,
			[]SearchSource{{"X", "", "s"}, {"Y", "", ""}, {"Z", "", ""}, {"W", "", ""}}},
		"item kosong dilewati": {`{"results":[{"foo":"bar"},{"title":"  "},{"title":"Ada","url":"https://ada.id"}]}`,
			[]SearchSource{{"Ada", "https://ada.id", ""}}},
		"results kosong lalu data": {`{"results":[],"data":[{"title":"H2","url":"https://h2.id"}]}`,
			[]SearchSource{{"H2", "https://h2.id", ""}}},
		"bentuk tak dikenal":      {`{"hasil":"nihil"}`, []SearchSource{}},
		"skalar":                  {`"teks"`, []SearchSource{}},
		"terlalu dalam":           {`{"data":{"data":{"data":{"data":[{"title":"Dalam","url":"https://d.id"}]}}}}`, []SearchSource{}},
		"opensearch tak lengkap":  {`["q","bukan-array",[],[]]`, []SearchSource{}},
		"array pendek":            {`["q",["a"]]`, []SearchSource{}},
		"query tanpa search":      {`{"query":{"lain":1}}`, []SearchSource{}},
		"query search bukan list": {`{"query":{"search":"x"}}`, []SearchSource{}},
	}
	for name, tc := range cases {
		t.Run(name, func(t *testing.T) {
			var gotQuery string
			srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				gotQuery = r.URL.Query().Get("q")
				_, _ = io.WriteString(w, tc.body)
			}))
			defer srv.Close()

			got, err := NewSearchClient(srv.URL+"/api/v1/search?lang=id", srv.Client()).Search(ctx, "danau toba & kaldera")
			require.NoError(t, err)
			assert.Equal(t, "danau toba & kaldera", gotQuery)
			assert.Equal(t, tc.want, got)
		})
	}
}

func TestSearchCleansAndLimits(t *testing.T) {
	var items []string
	for i := 1; i <= 8; i++ {
		items = append(items, fmt.Sprintf(`{"title":"<b>Judul %d</b>","url":"https://s%d.id","snippet":"  banyak   spasi\n<i>miring</i> &lt;ok&gt; "}`, i, i))
	}
	long := strings.Repeat("kata ", 100)
	items[0] = fmt.Sprintf(`{"title":"Panjang","url":"https://p.id","snippet":%q}`, long)
	srv := serve(t, 200, `{"results":[`+strings.Join(items, ",")+`]}`)

	got, err := NewSearchClient(srv.URL, nil).Search(ctx, "x")
	require.NoError(t, err)
	require.Len(t, got, maxSources)
	assert.Equal(t, maxSnippetRunes+1, len([]rune(got[0].Snippet)))
	assert.True(t, strings.HasSuffix(got[0].Snippet, "…"))
	assert.Equal(t, "Judul 2", got[1].Title)
	assert.Equal(t, "banyak spasi miring <ok>", got[1].Snippet)
}

func TestSearchErrors(t *testing.T) {
	_, err := NewSearchClient("  ", nil).Search(ctx, "x")
	assert.ErrorContains(t, err, "belum dikonfigurasi")

	_, err = NewSearchClient("http://[::1", nil).Search(ctx, "x")
	assert.ErrorContains(t, err, "tidak valid")

	_, err = NewSearchClient(closedURL(t), nil).Search(ctx, "x")
	assert.ErrorContains(t, err, "gagal menghubungi")

	_, err = NewSearchClient(serve(t, 500, `{}`).URL, nil).Search(ctx, "x")
	assert.ErrorContains(t, err, "status 500")

	_, err = NewSearchClient(serve(t, 200, `bukan json`).URL, nil).Search(ctx, "x")
	assert.ErrorContains(t, err, "bukan JSON valid")

	_, err = NewSearchClient(truncated(t).URL, nil).Search(ctx, "x")
	assert.ErrorContains(t, err, "gagal membaca")
}

func TestSearchTimeout(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		time.Sleep(300 * time.Millisecond)
	}))
	defer srv.Close()
	c := NewSearchClient(srv.URL, &http.Client{Timeout: 50 * time.Millisecond})
	_, err := c.Search(ctx, "x")
	assert.ErrorContains(t, err, "gagal menghubungi")
}

// ---------- client OpenAI ----------

func chatBody(content string) string {
	b, _ := json.Marshal(map[string]any{"choices": []any{map[string]any{"message": map[string]any{"content": content}}}})
	return string(b)
}

const articleJSON = `{"title":" Judul AI ","category":"Teknologi","excerpt":" ringkas ","content":"## Isi\n\nTeks."}`

func TestCheckAccess(t *testing.T) {
	var path, auth string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		path, auth = r.URL.Path, r.Header.Get("Authorization")
		_, _ = io.WriteString(w, `{"data":[]}`)
	}))
	defer srv.Close()

	require.NoError(t, NewOpenAIClient(srv.URL+"/v1/", "rahasia", "m", srv.Client()).CheckAccess(ctx))
	assert.Equal(t, "/v1/models", path)
	assert.Equal(t, "Bearer rahasia", auth)

	assert.ErrorContains(t, NewOpenAIClient(srv.URL, "  ", "m", nil).CheckAccess(ctx), "OPENAI_KEY")
	assert.ErrorContains(t, NewOpenAIClient("http://a b", "k", "m", nil).CheckAccess(ctx), "tidak valid")
	assert.ErrorContains(t, NewOpenAIClient(closedURL(t), "k", "m", nil).CheckAccess(ctx), "gagal menghubungi")
	assert.ErrorContains(t, NewOpenAIClient(serve(t, 401, `{}`).URL, "k", "m", nil).CheckAccess(ctx), "status 401")
}

func TestGenerateArticleSuccessAndRequestShape(t *testing.T) {
	var captured chatRequest
	var auth, contentType, path string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		path, auth, contentType = r.URL.Path, r.Header.Get("Authorization"), r.Header.Get("Content-Type")
		_ = json.NewDecoder(r.Body).Decode(&captured)
		_, _ = io.WriteString(w, chatBody(articleJSON))
	}))
	defer srv.Close()

	c := NewOpenAIClient(srv.URL, "kunci", "model-x", srv.Client())
	article, err := c.GenerateArticle(ctx, "Danau Toba", "Umum", []SearchSource{{"Toba", "https://toba.id", "kaldera"}})
	require.NoError(t, err)
	assert.Equal(t, &GeneratedArticle{Title: "Judul AI", Category: "Teknologi", Excerpt: "ringkas", Content: "## Isi\n\nTeks."}, article)

	assert.Equal(t, "/chat/completions", path)
	assert.Equal(t, "Bearer kunci", auth)
	assert.Equal(t, "application/json", contentType)
	assert.Equal(t, "model-x", captured.Model)
	require.Len(t, captured.Messages, 2)
	assert.Contains(t, captured.Messages[0].Content, "JSON")
	assert.Contains(t, captured.Messages[0].Content, "## Referensi")
	assert.Contains(t, captured.Messages[1].Content, "Danau Toba")
	assert.Contains(t, captured.Messages[1].Content, "Kategori yang diinginkan: Umum")
	assert.Contains(t, captured.Messages[1].Content, "1. Toba (https://toba.id): kaldera")

	// Tanpa konteks web: prompt tidak meminta referensi dan tidak menyebut konteks.
	_, err = c.GenerateArticle(ctx, "Topik", "", nil)
	require.NoError(t, err)
	assert.NotContains(t, captured.Messages[0].Content, "## Referensi")
	assert.NotContains(t, captured.Messages[1].Content, "Konteks hasil penelusuran")
	assert.NotContains(t, captured.Messages[1].Content, "Kategori yang diinginkan")
}

func TestGenerateArticleToleratesWrappers(t *testing.T) {
	wrappers := map[string]string{
		"fence json": "```json\n" + articleJSON + "\n```",
		"fence":      "```\n" + articleJSON + "\n```",
		"pengantar":  "Tentu, ini artikelnya:\n" + articleJSON + "\nSemoga membantu!",
	}
	for name, content := range wrappers {
		srv := serve(t, 200, chatBody(content))
		article, err := NewOpenAIClient(srv.URL, "k", "m", nil).GenerateArticle(ctx, "t", "", nil)
		require.NoError(t, err, name)
		assert.Equal(t, "Judul AI", article.Title, name)
	}
}

func TestGenerateArticleErrors(t *testing.T) {
	gen := func(url string) error {
		_, err := NewOpenAIClient(url, "k", "m", nil).GenerateArticle(ctx, "t", "", nil)
		return err
	}
	assert.ErrorContains(t, gen("http://a b"), "tidak valid")
	assert.ErrorContains(t, gen(closedURL(t)), "gagal menghubungi")
	assert.ErrorContains(t, gen(truncated(t).URL), "gagal membaca")
	assert.ErrorContains(t, gen(serve(t, 429, `{}`).URL), "status 429")
	assert.ErrorContains(t, gen(serve(t, 200, `bukan json`).URL), "bukan JSON valid")
	assert.ErrorContains(t, gen(serve(t, 200, `{"choices":[]}`).URL), "kosong")
	assert.ErrorContains(t, gen(serve(t, 200, chatBody("   ")).URL), "kosong")
	assert.ErrorContains(t, gen(serve(t, 200, chatBody("tanpa kurung kurawal")).URL), "tidak berisi objek JSON")
	assert.ErrorContains(t, gen(serve(t, 200, chatBody("} terbalik {")).URL), "tidak berisi objek JSON")
	assert.ErrorContains(t, gen(serve(t, 200, chatBody(`{"title": "rusak",}`)).URL), "rusak")
	assert.ErrorContains(t, gen(serve(t, 200, chatBody(`{"title":"","content":"x"}`)).URL), "tidak lengkap")
	assert.ErrorContains(t, gen(serve(t, 200, chatBody(`{"title":"x","content":" "}`)).URL), "tidak lengkap")
}

func TestGenerateArticleMarshalError(t *testing.T) {
	old := jsonMarshal
	jsonMarshal = func(any) ([]byte, error) { return nil, errBoom }
	t.Cleanup(func() { jsonMarshal = old })
	_, err := NewOpenAIClient("http://x", "k", "m", nil).GenerateArticle(ctx, "t", "", nil)
	assert.ErrorIs(t, err, errBoom)
}

// ---------- service ----------

type stubChat struct {
	accessErr, genErr error
	article           *GeneratedArticle
	gotCategory       string
	gotSources        []SearchSource
}

func (s *stubChat) CheckAccess(context.Context) error { return s.accessErr }
func (s *stubChat) GenerateArticle(_ context.Context, _ string, category string, sources []SearchSource) (*GeneratedArticle, error) {
	s.gotCategory, s.gotSources = category, sources
	return s.article, s.genErr
}

type stubSearch struct {
	res    []SearchSource
	err    error
	mu     sync.Mutex
	called int
}

func (s *stubSearch) Search(context.Context, string) ([]SearchSource, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.called++
	return s.res, s.err
}

func okArticle() *GeneratedArticle {
	return &GeneratedArticle{Title: "T", Category: "bisnis", Excerpt: "E", Content: "C"}
}

func TestServiceValidation(t *testing.T) {
	svc := NewService(&stubChat{}, &stubSearch{})
	for _, topic := range []string{"", "   ", strings.Repeat("é", 301)} {
		_, err := svc.Generate(ctx, GenerateRequest{Topic: topic})
		var ve *ValidationError
		require.ErrorAs(t, err, &ve)
	}
	_, err := svc.Generate(ctx, GenerateRequest{Topic: ""})
	assert.EqualError(t, err, "Topik wajib diisi")
	_, err = svc.Generate(ctx, GenerateRequest{Topic: strings.Repeat("a", 301)})
	assert.EqualError(t, err, "Topik maksimal 300 karakter")
}

func TestServiceUpstreamErrors(t *testing.T) {
	var se *ServiceError

	_, err := NewService(&stubChat{accessErr: errBoom}, &stubSearch{}).Generate(ctx, GenerateRequest{Topic: "x"})
	require.ErrorAs(t, err, &se)
	assert.Equal(t, 502, se.Status)
	assert.ErrorIs(t, err, errBoom)
	assert.Equal(t, "Layanan AI sedang tidak tersedia. Silakan coba lagi nanti.", se.Error())

	_, err = NewService(&stubChat{genErr: errBoom}, &stubSearch{}).Generate(ctx, GenerateRequest{Topic: "x"})
	require.ErrorAs(t, err, &se)
	assert.Equal(t, "Gagal menghasilkan artikel dengan AI. Silakan coba lagi.", se.Error())
}

func TestServiceSearchFlow(t *testing.T) {
	src := []SearchSource{{"A", "https://a.id", "s"}}

	// Tanpa web search: search tidak dipanggil, sumber kosong (bukan null).
	chat, search := &stubChat{article: okArticle()}, &stubSearch{res: src}
	res, err := NewService(chat, search).Generate(ctx, GenerateRequest{Topic: " x "})
	require.NoError(t, err)
	assert.Zero(t, search.called)
	assert.NotNil(t, res.SearchSources)
	assert.Empty(t, res.SearchSources)
	b, _ := json.Marshal(res)
	assert.Contains(t, string(b), `"search_sources":[]`)

	// Dengan web search: sumber diteruskan ke OpenAI dan dikembalikan.
	chat, search = &stubChat{article: okArticle()}, &stubSearch{res: src}
	res, err = NewService(chat, search).Generate(ctx, GenerateRequest{Topic: "x", IncludeWebSearch: true})
	require.NoError(t, err)
	assert.Equal(t, 1, search.called)
	assert.Equal(t, src, chat.gotSources)
	assert.Equal(t, src, res.SearchSources)

	// Search gagal atau nil: request tetap sukses tanpa konteks web.
	for _, s := range []*stubSearch{{err: errBoom}, {res: nil}} {
		chat = &stubChat{article: okArticle()}
		res, err = NewService(chat, s).Generate(ctx, GenerateRequest{Topic: "x", IncludeWebSearch: true})
		require.NoError(t, err)
		assert.NotNil(t, res.SearchSources)
		assert.Empty(t, res.SearchSources)
		assert.Empty(t, chat.gotSources)
	}
}

func TestServiceCategoryNormalization(t *testing.T) {
	cases := []struct{ input, ai, want, sentToAI string }{
		{"", "bisnis", "Bisnis", ""},
		{"Opini", "Teknologi", "Teknologi", "Opini"},
		{"opini", "Ngawur", "Opini", "Opini"},
		{"Ngawur", "Ngawur", "Umum", ""},
		{"", "", "Umum", ""},
	}
	for _, tc := range cases {
		chat := &stubChat{article: &GeneratedArticle{Title: "T", Category: tc.ai, Content: "C"}}
		res, err := NewService(chat, &stubSearch{}).Generate(ctx, GenerateRequest{Topic: "x", Category: tc.input})
		require.NoError(t, err)
		assert.Equal(t, tc.want, res.Category, "%+v", tc)
		assert.Equal(t, tc.sentToAI, chat.gotCategory, "%+v", tc)
	}
}

// ---------- handler ----------

type stubService struct {
	res *GenerateResponse
	err error
}

func (s stubService) Generate(context.Context, GenerateRequest) (*GenerateResponse, error) {
	return s.res, s.err
}

func doPost(svc Service, body string) (int, map[string]any) {
	r := gin.New()
	r.POST("/ai", NewHandler(svc).Generate)
	req := httptest.NewRequest("POST", "/ai", bytes.NewBufferString(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	var out map[string]any
	_ = json.Unmarshal(w.Body.Bytes(), &out)
	return w.Code, out
}

func TestHandler(t *testing.T) {
	code, out := doPost(stubService{}, "{rusak")
	assert.Equal(t, 400, code)
	assert.Equal(t, "fail", out["status"])

	code, out = doPost(stubService{err: &ValidationError{"Topik wajib diisi"}}, `{}`)
	assert.Equal(t, 400, code)
	assert.Equal(t, "Topik wajib diisi", out["message"])

	code, out = doPost(stubService{err: &ServiceError{Status: 502, Message: "AI mati", Err: errBoom}}, `{"topic":"x"}`)
	assert.Equal(t, 502, code)
	assert.Equal(t, "error", out["status"])
	assert.Equal(t, "AI mati", out["message"])

	code, out = doPost(stubService{err: errBoom}, `{"topic":"x"}`)
	assert.Equal(t, 500, code)
	assert.Equal(t, "Terjadi kesalahan pada server", out["message"])

	code, out = doPost(stubService{res: &GenerateResponse{Title: "T", Category: "Umum", Content: "C", SearchSources: []SearchSource{}}}, `{"topic":"x"}`)
	assert.Equal(t, 200, code)
	data := out["data"].(map[string]any)
	assert.Equal(t, "T", data["title"])
	assert.Equal(t, []any{}, data["search_sources"])
}

func TestEndToEndWithMockServers(t *testing.T) {
	search := serve(t, 200, `{"results":[{"title":"Toba","url":"https://toba.id","snippet":"kaldera"}]}`)
	mux := http.NewServeMux()
	mux.HandleFunc("/models", func(w http.ResponseWriter, r *http.Request) { _, _ = io.WriteString(w, `{}`) })
	mux.HandleFunc("/chat/completions", func(w http.ResponseWriter, r *http.Request) {
		_, _ = io.WriteString(w, chatBody("```json\n"+articleJSON+"\n```"))
	})
	oa := httptest.NewServer(mux)
	defer oa.Close()

	svc := NewService(NewOpenAIClient(oa.URL, "k", "m", nil), NewSearchClient(search.URL, nil))
	code, out := doPost(svc, `{"topic":"Toba","category":"Opini","include_web_search":true}`)
	require.Equal(t, 200, code)
	data := out["data"].(map[string]any)
	assert.Equal(t, "Judul AI", data["title"])
	assert.Equal(t, "Teknologi", data["category"])
	assert.Len(t, data["search_sources"], 1)
}
