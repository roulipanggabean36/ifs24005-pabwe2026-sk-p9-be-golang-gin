package post

import (
	"errors"
	"strings"

	"app/internal/database"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

// Galat domain pada lapisan data/service.
var (
	ErrPostNotFound = errors.New("artikel tidak ditemukan")
	ErrUserNotFound = errors.New("pengguna tidak ditemukan")
	ErrForbidden    = errors.New("artikel milik pengguna lain")
)

// UserCount adalah agregat jumlah artikel per pengguna.
type UserCount struct {
	UserID    uint
	Total     int64
	Published int64
}

// Repository mengabstraksi akses data artikel.
type Repository interface {
	Create(p *database.Post) error
	Update(p *database.Post) error
	Delete(p *database.Post) error
	FindByIDAndUser(id, userID uint) (*database.Post, error)
	FindPublishedBySlug(slug string) (*database.Post, error)
	SlugExists(slug string, excludeID uint) (bool, error)
	ListPublished(query, category string) ([]database.Post, error)
	ListByUser(userID uint) ([]database.Post, error)
	ListAll() ([]database.Post, error)
	CountByUser(userID uint) (total, published int64, err error)
	ListUsers() ([]database.User, error)
	FindUser(id uint) (*database.User, error)
	CountsPerUser() (map[uint]UserCount, error)
}

type repository struct{ db *gorm.DB }

// NewRepository membuat Repository berbasis GORM.
func NewRepository(db *gorm.DB) Repository { return &repository{db: db} }

func (r *repository) Create(p *database.Post) error {
	return r.db.Omit(clause.Associations).Create(p).Error
}

func (r *repository) Update(p *database.Post) error {
	return r.db.Omit(clause.Associations).Save(p).Error
}

func (r *repository) Delete(p *database.Post) error {
	return r.db.Delete(p).Error
}

func (r *repository) findOne(query string, args ...any) (*database.Post, error) {
	var p database.Post
	if err := r.db.Preload("User").Where(query, args...).First(&p).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrPostNotFound
		}
		return nil, err
	}
	return &p, nil
}

// FindByIDAndUser mengambil artikel berdasarkan ID. ErrPostNotFound bila tidak ada,
// ErrForbidden bila artikel ada tetapi dimiliki pengguna lain.
func (r *repository) FindByIDAndUser(id, userID uint) (*database.Post, error) {
	p, err := r.findOne("id = ?", id)
	if err != nil {
		return nil, err
	}
	if p.UserID != userID {
		return nil, ErrForbidden
	}
	return p, nil
}

func (r *repository) FindPublishedBySlug(slug string) (*database.Post, error) {
	return r.findOne("slug = ? AND is_published = ?", slug, true)
}

func (r *repository) SlugExists(slug string, excludeID uint) (bool, error) {
	var count int64
	err := r.db.Model(&database.Post{}).Where("slug = ? AND id <> ?", slug, excludeID).Count(&count).Error
	return count > 0, err
}

// escapeLike meloloskan karakter khusus LIKE agar kata kunci dicari apa adanya.
func escapeLike(s string) string {
	return strings.NewReplacer(`\`, `\\`, `%`, `\%`, `_`, `\_`).Replace(s)
}

func (r *repository) ListPublished(query, category string) ([]database.Post, error) {
	tx := r.db.Preload("User").Where("is_published = ?", true)
	if category != "" {
		tx = tx.Where("category = ?", category)
	}
	if query != "" {
		like := "%" + escapeLike(strings.ToLower(query)) + "%"
		tx = tx.Where(`(LOWER(title) LIKE ? ESCAPE '\' OR LOWER(excerpt) LIKE ? ESCAPE '\' OR LOWER(content) LIKE ? ESCAPE '\')`, like, like, like)
	}
	var posts []database.Post
	err := tx.Order("published_at DESC, id DESC").Find(&posts).Error
	return posts, err
}

func (r *repository) ListByUser(userID uint) ([]database.Post, error) {
	var posts []database.Post
	err := r.db.Preload("User").Where("user_id = ?", userID).Order("created_at DESC, id DESC").Find(&posts).Error
	return posts, err
}

func (r *repository) ListAll() ([]database.Post, error) {
	var posts []database.Post
	err := r.db.Preload("User").Order("created_at DESC, id DESC").Find(&posts).Error
	return posts, err
}

func (r *repository) CountByUser(userID uint) (int64, int64, error) {
	var total, published int64
	if err := r.db.Model(&database.Post{}).Where("user_id = ?", userID).Count(&total).Error; err != nil {
		return 0, 0, err
	}
	err := r.db.Model(&database.Post{}).Where("user_id = ? AND is_published = ?", userID, true).Count(&published).Error
	return total, published, err
}

func (r *repository) ListUsers() ([]database.User, error) {
	var users []database.User
	err := r.db.Order("id ASC").Find(&users).Error
	return users, err
}

func (r *repository) FindUser(id uint) (*database.User, error) {
	var u database.User
	if err := r.db.First(&u, id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrUserNotFound
		}
		return nil, err
	}
	return &u, nil
}

func (r *repository) CountsPerUser() (map[uint]UserCount, error) {
	var rows []UserCount
	err := r.db.Model(&database.Post{}).
		Select("user_id, COUNT(*) AS total, COALESCE(SUM(CASE WHEN is_published = ? THEN 1 ELSE 0 END), 0) AS published", true).
		Group("user_id").Scan(&rows).Error
	if err != nil {
		return nil, err
	}
	counts := make(map[uint]UserCount, len(rows))
	for _, row := range rows {
		counts[row.UserID] = row
	}
	return counts, nil
}