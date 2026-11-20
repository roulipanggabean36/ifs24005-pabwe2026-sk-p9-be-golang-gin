package ai

import (
	"context"
	"strings"
	"unicode/utf8"

	"app/internal/features/post"
)

const (
	maxTopicRunes    = 300
	statusBadGateway = 502
)

// ValidationError menandakan input tidak valid (HTTP 400).
type ValidationError struct{ Message string }

func (e *ValidationError) Error() string { return e.Message }

// ServiceError menandakan kegagalan layanan hulu (OpenAI) dengan pesan ramah pengguna.
type ServiceError struct {
	Status  int
	Message string
	Err     error
}

func (e *ServiceError) Error() string { return e.Message }
func (e *ServiceError) Unwrap() error { return e.Err }

// Service menyusun draf artikel dengan bantuan search engine dan OpenAI.
type Service interface {
	Generate(ctx context.Context, req GenerateRequest) (*GenerateResponse, error)
}

type service struct {
	chat   ChatClient
	search SearchClient
}

// NewService membuat Service.
func NewService(chat ChatClient, search SearchClient) Service {
	return &service{chat: chat, search: search}
}

func (s *service) Generate(ctx context.Context, req GenerateRequest) (*GenerateResponse, error) {
	topic := strings.TrimSpace(req.Topic)
	if topic == "" {
		return nil, &ValidationError{"Topik wajib diisi"}
	}
	if utf8.RuneCountInString(topic) > maxTopicRunes {
		return nil, &ValidationError{"Topik maksimal 300 karakter"}
	}
	// Kategori input hanyalah petunjuk; nilai yang tidak dikenal diabaikan.
	inputCategory, _ := post.NormalizeCategory(req.Category)

	if err := s.chat.CheckAccess(ctx); err != nil {
		return nil, &ServiceError{Status: statusBadGateway, Message: "Layanan AI sedang tidak tersedia. Silakan coba lagi nanti.", Err: err}
	}

	// Kegagalan penelusuran web tidak menggagalkan request: lanjut tanpa konteks web.
	sources := []SearchSource{}
	if req.IncludeWebSearch {
		if found, err := s.search.Search(ctx, topic); err == nil && found != nil {
			sources = found
		}
	}

	article, err := s.chat.GenerateArticle(ctx, topic, inputCategory, sources)
	if err != nil {
		return nil, &ServiceError{Status: statusBadGateway, Message: "Gagal menghasilkan artikel dengan AI. Silakan coba lagi.", Err: err}
	}

	category := post.DefaultCategory
	if normalized, ok := post.NormalizeCategory(article.Category); ok {
		category = normalized
	} else if inputCategory != "" {
		category = inputCategory
	}
	return &GenerateResponse{
		Title: article.Title, Category: category, Excerpt: article.Excerpt,
		Content: article.Content, SearchSources: sources,
	}, nil
}
