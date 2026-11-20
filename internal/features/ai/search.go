package ai

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"html"
	"io"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"time"
)

const (
	searchTimeout   = 10 * time.Second
	maxSearchBody   = 2 << 20
	maxSources      = 5
	maxSnippetRunes = 300
	maxParseDepth   = 3
)

var tagRe = regexp.MustCompile(`<[^>]*>`)

// SearchClient melakukan penelusuran web untuk sebuah topik.
type SearchClient interface {
	Search(ctx context.Context, query string) ([]SearchSource, error)
}

type searchClient struct {
	endpoint string
	http     *http.Client
}

// NewSearchClient membuat SearchClient. httpClient nil memakai klien dengan timeout 10 detik.
func NewSearchClient(endpoint string, httpClient *http.Client) SearchClient {
	if httpClient == nil {
		httpClient = &http.Client{Timeout: searchTimeout}
	}
	return &searchClient{endpoint: endpoint, http: httpClient}
}

func (c *searchClient) Search(ctx context.Context, query string) ([]SearchSource, error) {
	if strings.TrimSpace(c.endpoint) == "" {
		return nil, errors.New("endpoint search engine belum dikonfigurasi")
	}
	u, err := url.Parse(c.endpoint)
	if err != nil {
		return nil, fmt.Errorf("endpoint search engine tidak valid: %w", err)
	}
	q := u.Query()
	q.Set("q", query)
	u.RawQuery = q.Encode()

	req := (&http.Request{Method: http.MethodGet, URL: u, Header: http.Header{}}).WithContext(ctx)
	req.Header.Set("Accept", "application/json")

	resp, err := c.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("gagal menghubungi search engine: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode > 299 {
		return nil, fmt.Errorf("search engine mengembalikan status %d", resp.StatusCode)
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, maxSearchBody))
	if err != nil {
		return nil, fmt.Errorf("gagal membaca respons search engine: %w", err)
	}
	return parseSearchResults(body)
}

// parseSearchResults toleran terhadap beberapa bentuk JSON:
// {"results":[...]}, {"data":{"results":[...]}}, {"data":[...]}, {"items":[...]},
// OpenSearch ["q",[judul],[deskripsi],[url]], dan {"query":{"search":[...]}} (Wikipedia).
func parseSearchResults(body []byte) ([]SearchSource, error) {
	var v any
	if err := json.Unmarshal(body, &v); err != nil {
		return nil, fmt.Errorf("respons search engine bukan JSON valid: %w", err)
	}
	sources := make([]SearchSource, 0, maxSources)
	for _, item := range extractItems(v, 0) {
		src := toSource(item)
		if src.Title == "" && src.URL == "" {
			continue
		}
		sources = append(sources, src)
		if len(sources) == maxSources {
			break
		}
	}
	return sources, nil
}

func extractItems(v any, depth int) []map[string]any {
	switch t := v.(type) {
	case []any:
		if items := openSearchItems(t); items != nil {
			return items
		}
		items := []map[string]any{}
		for _, el := range t {
			if m, ok := el.(map[string]any); ok {
				items = append(items, m)
			}
		}
		return items
	case map[string]any:
		if depth >= maxParseDepth {
			return nil
		}
		for _, key := range []string{"results", "data", "items", "organic_results"} {
			if child, ok := t[key]; ok {
				if items := extractItems(child, depth+1); len(items) > 0 {
					return items
				}
			}
		}
		if q, ok := t["query"].(map[string]any); ok {
			return wikipediaItems(q["search"])
		}
	}
	return nil
}

func openSearchItems(arr []any) []map[string]any {
	if len(arr) < 4 {
		return nil
	}
	titles, ok1 := arr[1].([]any)
	descs, ok2 := arr[2].([]any)
	urls, ok3 := arr[3].([]any)
	if !ok1 || !ok2 || !ok3 {
		return nil
	}
	at := func(list []any, i int) any {
		if i < len(list) {
			return list[i]
		}
		return nil
	}
	items := []map[string]any{}
	for i, title := range titles {
		items = append(items, map[string]any{"title": title, "snippet": at(descs, i), "url": at(urls, i)})
	}
	return items
}

func wikipediaItems(raw any) []map[string]any {
	list, _ := raw.([]any)
	items := []map[string]any{}
	for _, el := range list {
		m, ok := el.(map[string]any)
		if !ok {
			continue
		}
		title, _ := m["title"].(string)
		items = append(items, map[string]any{
			"title":   title,
			"snippet": m["snippet"],
			"url":     "https://id.wikipedia.org/wiki/" + url.PathEscape(strings.ReplaceAll(title, " ", "_")),
		})
	}
	return items
}

func pickString(m map[string]any, keys ...string) string {
	for _, k := range keys {
		if s, ok := m[k].(string); ok && strings.TrimSpace(s) != "" {
			return s
		}
	}
	return ""
}

// cleanText membuang tag HTML, mengurai entitas, merapikan spasi, dan memotong teks panjang.
func cleanText(s string) string {
	s = html.UnescapeString(tagRe.ReplaceAllString(s, ""))
	s = strings.Join(strings.Fields(s), " ")
	if r := []rune(s); len(r) > maxSnippetRunes {
		s = string(r[:maxSnippetRunes]) + "…"
	}
	return s
}

// safeURL hanya meloloskan URL http/https agar tidak menjadi tautan berbahaya di klien.
func safeURL(raw string) string {
	raw = strings.TrimSpace(raw)
	u, err := url.Parse(raw)
	if err != nil || (u.Scheme != "http" && u.Scheme != "https") || u.Host == "" {
		return ""
	}
	return raw
}

func toSource(item map[string]any) SearchSource {
	src := SearchSource{
		Title:   cleanText(pickString(item, "title", "name")),
		URL:     safeURL(pickString(item, "url", "link", "href")),
		Snippet: cleanText(pickString(item, "snippet", "content", "description", "text", "body", "summary")),
	}
	if src.Title == "" {
		src.Title = src.URL
	}
	return src
}
