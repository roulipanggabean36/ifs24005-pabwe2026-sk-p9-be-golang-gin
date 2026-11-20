package auth

import (
	"time"

	"app/internal/database"
)

// RegisterRequest adalah payload pendaftaran. Field role pada payload diabaikan
// (tidak dideklarasikan) sehingga akun baru selalu berperan member.
type RegisterRequest struct {
	Username string `json:"username"`
	Email    string `json:"email"`
	Password string `json:"password"`
}

// LoginRequest menerima username ATAU email pada field username.
type LoginRequest struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

// UpdateProfileRequest adalah payload pembaruan profil; password bersifat opsional.
type UpdateProfileRequest struct {
	Username string `json:"username"`
	Email    string `json:"email"`
	Password string `json:"password"`
}

// UserResponse adalah representasi pengguna yang aman (tanpa hash password).
type UserResponse struct {
	ID        uint      `json:"id"`
	Username  string    `json:"username"`
	Email     string    `json:"email"`
	Role      string    `json:"role"`
	CreatedAt time.Time `json:"created_at"`
}

// LoginResponse berisi token JWT beserta data pengguna.
type LoginResponse struct {
	Token string       `json:"token"`
	User  UserResponse `json:"user"`
}

// ToUserResponse memetakan model ke DTO.
func ToUserResponse(u *database.User) UserResponse {
	return UserResponse{ID: u.ID, Username: u.Username, Email: u.Email, Role: u.Role, CreatedAt: u.CreatedAt}
}
