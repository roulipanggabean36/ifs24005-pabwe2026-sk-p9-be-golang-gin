package post

import (
	"strings"
	"time"

	"app/internal/database"
)

// DefaultCategory dipakai bila kategori kosong.
const DefaultCategory = "Umum"

var categories = []string{"Teknologi", "Pendidikan", "Gaya Hidup", "Bisnis", "Opini", "Umum"}

// Categories mengembalikan salinan daftar kategori yang sah.
func Categories() []string { return append([]string(nil), categories...) }

// NormalizeCategory mencocokkan input (tanpa membedakan huruf besar/kecil) ke kategori
// kanonik. Hasil kedua false bila input tidak cocok dengan kategori mana pun.
func NormalizeCategory(raw string) (string, bool) {
	raw = strings.TrimSpace(raw)
	for _, c := range categories {
		if strings.EqualFold(c, raw) {
			return c, true
		}
	}
	return "", false
}

// PostRequest adalah payload pembuatan/pembaruan artikel. IsPublished bersifat opsional.
type PostRequest struct {
	Title          string `json:"title"`
	Category       string `json:"category"`
	Excerpt        string `json:"excerpt"`
	Content        string `json:"content"`
	CoverImagePath string `json:"cover_image_path"`
	IsPublished    *bool  `json:"is_published"`
}

// AuthorResponse adalah data ringkas penulis (tanpa email).
type AuthorResponse struct {
	ID       uint   `json:"id"`
	Username string `json:"username"`
}

// PostResponse adalah representasi artikel pada seluruh respons.
type PostResponse struct {
	ID             uint            `json:"id"`
	UserID         uint            `json:"user_id"`
	Title          string          `json:"title"`
	Slug           string          `json:"slug"`
	Category       string          `json:"category"`
	Excerpt        string          `json:"excerpt"`
	Content        string          `json:"content"`
	CoverImagePath string          `json:"cover_image_path"`
	IsPublished    bool            `json:"is_published"`
	PublishedAt    *time.Time      `json:"published_at"`
	ReadingTime    int             `json:"reading_time"`
	Author         *AuthorResponse `json:"author,omitempty"`
	CreatedAt      time.Time       `json:"created_at"`
	UpdatedAt      time.Time       `json:"updated_at"`
}

// StatsResponse berisi tiga kartu statistik penulis beserta alias istilah skrip.
type StatsResponse struct {
	Total        int64 `json:"total"`
	TotalTerbit  int64 `json:"total_terbit"`
	TotalDraf    int64 `json:"total_draf"`
	TotalSelesai int64 `json:"total_selesai"`
	BelumSelesai int64 `json:"belum_selesai"`
}

// AdminUserResponse adalah baris direktori pengguna untuk admin.
type AdminUserResponse struct {
	ID             uint      `json:"id"`
	Username       string    `json:"username"`
	Email          string    `json:"email"`
	Role           string    `json:"role"`
	TotalPosts     int64     `json:"total_posts"`
	TotalPublished int64     `json:"total_published"`
	CreatedAt      time.Time `json:"created_at"`
}

// ToPostResponse memetakan model ke DTO dan menghitung reading_time.
func ToPostResponse(p *database.Post) PostResponse {
	res := PostResponse{
		ID: p.ID, UserID: p.UserID, Title: p.Title, Slug: p.Slug, Category: p.Category,
		Excerpt: p.Excerpt, Content: p.Content, CoverImagePath: p.CoverImagePath,
		IsPublished: p.IsPublished, PublishedAt: p.PublishedAt, ReadingTime: ReadingTime(p.Content),
		CreatedAt: p.CreatedAt, UpdatedAt: p.UpdatedAt,
	}
	if p.User.ID != 0 {
		res.Author = &AuthorResponse{ID: p.User.ID, Username: p.User.Username}
	}
	return res
}
