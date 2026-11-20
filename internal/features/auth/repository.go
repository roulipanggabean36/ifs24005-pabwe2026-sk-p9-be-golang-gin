package auth

import (
	"errors"

	"app/internal/database"

	"gorm.io/gorm"
)

// ErrUserNotFound dikembalikan bila pengguna tidak ditemukan.
var ErrUserNotFound = errors.New("pengguna tidak ditemukan")

// Repository mengabstraksi akses data pengguna.
type Repository interface {
	FindByID(id uint) (*database.User, error)
	FindByUsername(username string) (*database.User, error)
	FindByEmail(email string) (*database.User, error)
	ExistsByUsername(username string, excludeID uint) (bool, error)
	ExistsByEmail(email string, excludeID uint) (bool, error)
	Create(user *database.User) error
	Update(user *database.User) error
}

type repository struct{ db *gorm.DB }

// NewRepository membuat Repository berbasis GORM.
func NewRepository(db *gorm.DB) Repository { return &repository{db: db} }

func (r *repository) first(query string, arg any) (*database.User, error) {
	var user database.User
	if err := r.db.Where(query, arg).First(&user).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrUserNotFound
		}
		return nil, err
	}
	return &user, nil
}

func (r *repository) FindByID(id uint) (*database.User, error) { return r.first("id = ?", id) }

func (r *repository) FindByUsername(username string) (*database.User, error) {
	return r.first("LOWER(username) = LOWER(?)", username)
}

func (r *repository) FindByEmail(email string) (*database.User, error) {
	return r.first("LOWER(email) = LOWER(?)", email)
}

func (r *repository) exists(column, value string, excludeID uint) (bool, error) {
	var count int64
	err := r.db.Model(&database.User{}).
		Where("LOWER("+column+") = LOWER(?) AND id <> ?", value, excludeID).
		Count(&count).Error
	return count > 0, err
}

func (r *repository) ExistsByUsername(username string, excludeID uint) (bool, error) {
	return r.exists("username", username, excludeID)
}

func (r *repository) ExistsByEmail(email string, excludeID uint) (bool, error) {
	return r.exists("email", email, excludeID)
}

func (r *repository) Create(user *database.User) error { return r.db.Create(user).Error }

func (r *repository) Update(user *database.User) error { return r.db.Save(user).Error }
