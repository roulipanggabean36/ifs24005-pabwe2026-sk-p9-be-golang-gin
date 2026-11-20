package post

import (
	"fmt"
	"strings"
	"time"
	"unicode/utf8"

	"app/internal/database"
)

// ValidationError menandakan input tidak valid (HTTP 400).
type ValidationError struct{ Message string }

func (e *ValidationError) Error() string { return e.Message }

// nowFunc dapat diganti saat pengujian.
var nowFunc = time.Now

const (
	wordsPerMinute = 200
	maxSlugLength  = 200
	fallbackSlug   = "artikel"
)

// Service memuat logika bisnis artikel.
type Service interface {
	Categories() []string
	ListPublic(query, category string) ([]PostResponse, error)
	GetPublic(slug string) (*PostResponse, error)
	ListMine(userID uint) ([]PostResponse, error)
	Create(userID uint, req PostRequest) (*PostResponse, error)
	Get(userID, id uint) (*PostResponse, error)
	Update(userID, id uint, req PostRequest) (*PostResponse, error)
	TogglePublish(userID, id uint) (*PostResponse, error)
	Delete(userID, id uint) error
	Stats(userID uint) (*StatsResponse, error)
	AdminUsers() ([]AdminUserResponse, error)
	AdminPosts() ([]PostResponse, error)
	AdminUserPosts(userID uint) ([]PostResponse, error)
}

type service struct{ repo Repository }

// NewService membuat Service.
func NewService(repo Repository) Service { return &service{repo: repo} }

// ReadingTime menghitung estimasi menit baca: ceil(kata/200), minimal 1 menit.
func ReadingTime(content string) int {
	words := len(strings.Fields(content))
	if words == 0 {
		return 1
	}
	return (words + wordsPerMinute - 1) / wordsPerMinute
}

var accentGroups = []string{
	"aàáâãäåāăą", "cçćč", "eèéêëēěę", "iìíîïī", "nñń", "oòóôõöøō", "sšśß", "uùúûüū", "yýÿ", "zžźż",
}

var accentMap = func() map[rune]rune {
	m := make(map[rune]rune)
	for _, g := range accentGroups {
		runes := []rune(g)
		for _, r := range runes[1:] {
			m[r] = runes[0]
		}
	}
	return m
}()

// slugify mengubah judul menjadi slug URL: huruf kecil, tanpa aksen/simbol, dipisah "-".
func slugify(title string) string {
	var b strings.Builder
	lastDash := true // mencegah tanda hubung di awal
	for _, r := range strings.ToLower(title) {
		if mapped, ok := accentMap[r]; ok {
			r = mapped
		}
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') {
			b.WriteRune(r)
			lastDash = false
			continue
		}
		if !lastDash {
			b.WriteByte('-')
			lastDash = true
		}
	}
	slug := strings.Trim(b.String(), "-")
	if len(slug) > maxSlugLength {
		slug = strings.Trim(slug[:maxSlugLength], "-")
	}
	if slug == "" {
		return fallbackSlug
	}
	return slug
}

// uniqueSlug menghasilkan slug unik; tabrakan diberi sufiks -2, -3, dst.
func (s *service) uniqueSlug(title string, excludeID uint) (string, error) {
	base := slugify(title)
	candidate := base
	for i := 2; ; i++ {
		exists, err := s.repo.SlugExists(candidate, excludeID)
		if err != nil {
			return "", err
		}
		if !exists {
			return candidate, nil
		}
		candidate = fmt.Sprintf("%s-%d", base, i)
	}
}

type cleanInput struct{ title, category, excerpt, content, cover string }

func validate(req PostRequest) (*cleanInput, error) {
	title := strings.TrimSpace(req.Title)
	if title == "" {
		return nil, &ValidationError{"Judul wajib diisi"}
	}
	if utf8.RuneCountInString(title) > 255 {
		return nil, &ValidationError{"Judul maksimal 255 karakter"}
	}
	if strings.TrimSpace(req.Content) == "" {
		return nil, &ValidationError{"Konten wajib diisi"}
	}
	category := DefaultCategory
	if strings.TrimSpace(req.Category) != "" {
		normalized, ok := NormalizeCategory(req.Category)
		if !ok {
			return nil, &ValidationError{"Kategori tidak valid. Pilih salah satu dari: " + strings.Join(categories, ", ")}
		}
		category = normalized
	}
	return &cleanInput{
		title: title, category: category, content: req.Content,
		excerpt: strings.TrimSpace(req.Excerpt), cover: strings.TrimSpace(req.CoverImagePath),
	}, nil
}

// setPublished menjaga konsistensi is_published dan published_at.
func setPublished(p *database.Post, published bool, now time.Time) {
	p.IsPublished = published
	if !published {
		p.PublishedAt = nil
		return
	}
	if p.PublishedAt == nil {
		p.PublishedAt = &now
	}
}

func toResponses(posts []database.Post) []PostResponse {
	res := make([]PostResponse, 0, len(posts))
	for i := range posts {
		res = append(res, ToPostResponse(&posts[i]))
	}
	return res
}

func (s *service) Categories() []string { return Categories() }

func (s *service) ListPublic(query, category string) ([]PostResponse, error) {
	query = strings.TrimSpace(query)
	category = strings.TrimSpace(category)
	if strings.EqualFold(category, "semua") {
		category = ""
	}
	if canonical, ok := NormalizeCategory(category); ok {
		category = canonical
	}
	posts, err := s.repo.ListPublished(query, category)
	if err != nil {
		return nil, err
	}
	return toResponses(posts), nil
}

func (s *service) GetPublic(slug string) (*PostResponse, error) {
	p, err := s.repo.FindPublishedBySlug(slug)
	if err != nil {
		return nil, err
	}
	res := ToPostResponse(p)
	return &res, nil
}

func (s *service) ListMine(userID uint) ([]PostResponse, error) {
	posts, err := s.repo.ListByUser(userID)
	if err != nil {
		return nil, err
	}
	return toResponses(posts), nil
}

func (s *service) Create(userID uint, req PostRequest) (*PostResponse, error) {
	in, err := validate(req)
	if err != nil {
		return nil, err
	}
	slug, err := s.uniqueSlug(in.title, 0)
	if err != nil {
		return nil, err
	}
	p := &database.Post{
		UserID: userID, Title: in.title, Slug: slug, Category: in.category,
		Excerpt: in.excerpt, Content: in.content, CoverImagePath: in.cover,
	}
	if req.IsPublished != nil {
		setPublished(p, *req.IsPublished, nowFunc())
	}
	if err := s.repo.Create(p); err != nil {
		return nil, err
	}
	res := ToPostResponse(p)
	return &res, nil
}

func (s *service) Get(userID, id uint) (*PostResponse, error) {
	p, err := s.repo.FindByIDAndUser(id, userID)
	if err != nil {
		return nil, err
	}
	res := ToPostResponse(p)
	return &res, nil
}

func (s *service) Update(userID, id uint, req PostRequest) (*PostResponse, error) {
	p, err := s.repo.FindByIDAndUser(id, userID)
	if err != nil {
		return nil, err
	}
	in, err := validate(req)
	if err != nil {
		return nil, err
	}
	if in.title != p.Title {
		slug, err := s.uniqueSlug(in.title, p.ID)
		if err != nil {
			return nil, err
		}
		p.Slug = slug
	}
	p.Title, p.Category, p.Excerpt, p.Content, p.CoverImagePath = in.title, in.category, in.excerpt, in.content, in.cover
	if req.IsPublished != nil {
		setPublished(p, *req.IsPublished, nowFunc())
	}
	if err := s.repo.Update(p); err != nil {
		return nil, err
	}
	res := ToPostResponse(p)
	return &res, nil
}

func (s *service) TogglePublish(userID, id uint) (*PostResponse, error) {
	p, err := s.repo.FindByIDAndUser(id, userID)
	if err != nil {
		return nil, err
	}
	setPublished(p, !p.IsPublished, nowFunc())
	if err := s.repo.Update(p); err != nil {
		return nil, err
	}
	res := ToPostResponse(p)
	return &res, nil
}

func (s *service) Delete(userID, id uint) error {
	p, err := s.repo.FindByIDAndUser(id, userID)
	if err != nil {
		return err
	}
	return s.repo.Delete(p)
}

func (s *service) Stats(userID uint) (*StatsResponse, error) {
	total, published, err := s.repo.CountByUser(userID)
	if err != nil {
		return nil, err
	}
	drafts := total - published
	return &StatsResponse{
		Total: total, TotalTerbit: published, TotalDraf: drafts,
		TotalSelesai: published, BelumSelesai: drafts,
	}, nil
}

func (s *service) AdminUsers() ([]AdminUserResponse, error) {
	users, err := s.repo.ListUsers()
	if err != nil {
		return nil, err
	}
	counts, err := s.repo.CountsPerUser()
	if err != nil {
		return nil, err
	}
	res := make([]AdminUserResponse, 0, len(users))
	for _, u := range users {
		c := counts[u.ID]
		res = append(res, AdminUserResponse{
			ID: u.ID, Username: u.Username, Email: u.Email, Role: u.Role,
			TotalPosts: c.Total, TotalPublished: c.Published, CreatedAt: u.CreatedAt,
		})
	}
	return res, nil
}

func (s *service) AdminPosts() ([]PostResponse, error) {
	posts, err := s.repo.ListAll()
	if err != nil {
		return nil, err
	}
	return toResponses(posts), nil
}

// AdminUserPosts mengembalikan artikel milik userID; pengguna yang tidak ada
// menghasilkan daftar kosong (bukan galat).
func (s *service) AdminUserPosts(userID uint) ([]PostResponse, error) {
	posts, err := s.repo.ListByUser(userID)
	if err != nil {
		return nil, err
	}
	return toResponses(posts), nil
}