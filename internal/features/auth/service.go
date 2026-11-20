package auth

import (
	"errors"
	"regexp"
	"strings"
	"time"
	"unicode/utf8"

	"app/internal/database"
	"app/internal/middleware"

	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
)

// ValidationError menandakan input tidak valid (HTTP 400).
type ValidationError struct{ Message string }

func (e *ValidationError) Error() string { return e.Message }

// ConflictError menandakan data sudah dipakai (HTTP 409).
type ConflictError struct{ Message string }

func (e *ConflictError) Error() string { return e.Message }

// InvalidCredentialsError menandakan login gagal (HTTP 401). Pesannya sengaja
// tidak membedakan "pengguna tidak ada" dan "password salah".
type InvalidCredentialsError struct{}

func (InvalidCredentialsError) Error() string { return "Username/email atau password salah" }

// tokenTTL adalah masa berlaku JWT.
const tokenTTL = 24 * time.Hour

// Dapat diganti saat pengujian untuk menjangkau cabang error.
var (
	hashPassword = bcrypt.GenerateFromPassword
	signToken    = func(claims jwt.Claims, secret []byte) (string, error) {
		return jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString(secret)
	}
	nowFunc = time.Now
)

var (
	usernameRe = regexp.MustCompile(`^[A-Za-z0-9_.-]+$`)
	emailRe    = regexp.MustCompile(`^[^@\s]+@[^@\s]+\.[^@\s]+$`)
)

// Service memuat logika bisnis autentikasi.
type Service interface {
	Register(req RegisterRequest) (*UserResponse, error)
	Login(req LoginRequest) (*LoginResponse, error)
	GetProfile(userID uint) (*UserResponse, error)
	UpdateProfile(userID uint, req UpdateProfileRequest) (*UserResponse, error)
}

type service struct {
	repo   Repository
	secret string
}

// NewService membuat Service dengan kunci penandatangan JWT.
func NewService(repo Repository, secret string) Service {
	return &service{repo: repo, secret: secret}
}

func validateIdentity(username, email string) (string, string, error) {
	username = strings.TrimSpace(username)
	email = strings.ToLower(strings.TrimSpace(email))

	if username == "" {
		return "", "", &ValidationError{"Username wajib diisi"}
	}
	if n := utf8.RuneCountInString(username); n < 3 || n > 50 {
		return "", "", &ValidationError{"Username harus 3-50 karakter"}
	}
	if !usernameRe.MatchString(username) {
		return "", "", &ValidationError{"Username hanya boleh berisi huruf, angka, titik, garis bawah, dan strip"}
	}
	if email == "" {
		return "", "", &ValidationError{"Email wajib diisi"}
	}
	if len(email) > 255 || !emailRe.MatchString(email) {
		return "", "", &ValidationError{"Format email tidak valid"}
	}
	return username, email, nil
}

func validatePassword(password string) error {
	if utf8.RuneCountInString(password) < 6 {
		return &ValidationError{"Password minimal 6 karakter"}
	}
	if len(password) > 72 {
		return &ValidationError{"Password maksimal 72 byte"}
	}
	return nil
}

func (s *service) ensureUnique(username, email string, excludeID uint) error {
	taken, err := s.repo.ExistsByUsername(username, excludeID)
	if err != nil {
		return err
	}
	if taken {
		return &ConflictError{"Username sudah digunakan"}
	}
	taken, err = s.repo.ExistsByEmail(email, excludeID)
	if err != nil {
		return err
	}
	if taken {
		return &ConflictError{"Email sudah terdaftar"}
	}
	return nil
}

func (s *service) Register(req RegisterRequest) (*UserResponse, error) {
	username, email, err := validateIdentity(req.Username, req.Email)
	if err != nil {
		return nil, err
	}
	if err := validatePassword(req.Password); err != nil {
		return nil, err
	}
	if err := s.ensureUnique(username, email, 0); err != nil {
		return nil, err
	}
	hash, err := hashPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, err
	}

	user := &database.User{Username: username, Email: email, Password: string(hash), Role: database.RoleMember}
	if err := s.repo.Create(user); err != nil {
		return nil, err
	}
	res := ToUserResponse(user)
	return &res, nil
}

func (s *service) Login(req LoginRequest) (*LoginResponse, error) {
	identifier := strings.TrimSpace(req.Username)
	if identifier == "" || req.Password == "" {
		return nil, &ValidationError{"Username/email dan password wajib diisi"}
	}

	find := s.repo.FindByUsername
	if strings.Contains(identifier, "@") {
		find = s.repo.FindByEmail
	}
	user, err := find(identifier)
	if errors.Is(err, ErrUserNotFound) {
		return nil, InvalidCredentialsError{}
	}
	if err != nil {
		return nil, err
	}
	if bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(req.Password)) != nil {
		return nil, InvalidCredentialsError{}
	}

	claims := &middleware.Claims{
		UserID: user.ID, Username: user.Username, Role: user.Role,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(nowFunc().Add(tokenTTL)),
			IssuedAt:  jwt.NewNumericDate(nowFunc()),
		},
	}
	token, err := signToken(claims, []byte(s.secret))
	if err != nil {
		return nil, err
	}
	return &LoginResponse{Token: token, User: ToUserResponse(user)}, nil
}

func (s *service) GetProfile(userID uint) (*UserResponse, error) {
	user, err := s.repo.FindByID(userID)
	if err != nil {
		return nil, err
	}
	res := ToUserResponse(user)
	return &res, nil
}

func (s *service) UpdateProfile(userID uint, req UpdateProfileRequest) (*UserResponse, error) {
	user, err := s.repo.FindByID(userID)
	if err != nil {
		return nil, err
	}
	username, email, err := validateIdentity(req.Username, req.Email)
	if err != nil {
		return nil, err
	}
	if req.Password != "" {
		if err := validatePassword(req.Password); err != nil {
			return nil, err
		}
	}
	if err := s.ensureUnique(username, email, userID); err != nil {
		return nil, err
	}

	user.Username, user.Email = username, email
	if req.Password != "" {
		hash, err := hashPassword([]byte(req.Password), bcrypt.DefaultCost)
		if err != nil {
			return nil, err
		}
		user.Password = string(hash)
	}
	if err := s.repo.Update(user); err != nil {
		return nil, err
	}
	res := ToUserResponse(user)
	return &res, nil
}
