package ai

// GenerateRequest adalah payload POST /api/posts/ai-generate.
type GenerateRequest struct {
	Topic            string `json:"topic"`
	Category         string `json:"category"`
	IncludeWebSearch bool   `json:"include_web_search"`
}

// SearchSource adalah satu sumber rujukan hasil penelusuran web.
type SearchSource struct {
	Title   string `json:"title"`
	URL     string `json:"url"`
	Snippet string `json:"snippet"`
}

// GeneratedArticle adalah JSON artikel yang dikembalikan model AI.
type GeneratedArticle struct {
	Title    string `json:"title"`
	Category string `json:"category"`
	Excerpt  string `json:"excerpt"`
	Content  string `json:"content"`
}

// GenerateResponse adalah hasil akhir yang dikirim ke klien. Hasil tidak disimpan otomatis.
type GenerateResponse struct {
	Title         string         `json:"title"`
	Category      string         `json:"category"`
	Excerpt       string         `json:"excerpt"`
	Content       string         `json:"content"`
	SearchSources []SearchSource `json:"search_sources"`
}
