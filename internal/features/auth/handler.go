package auth

import (
	"errors"
	"log"
	"net/http"

	"app/internal/middleware"
	"app/internal/response"

	"github.com/gin-gonic/gin"
)

// Handler menangani endpoint /api/auth/*.
type Handler struct{ svc Service }

// NewHandler membuat Handler.
func NewHandler(svc Service) *Handler { return &Handler{svc: svc} }

func handleError(c *gin.Context, err error) {
	var validation *ValidationError
	var conflict *ConflictError
	var invalid InvalidCredentialsError
	switch {
	case errors.As(err, &validation):
		response.Fail(c, http.StatusBadRequest, validation.Message)
	case errors.As(err, &conflict):
		response.Fail(c, http.StatusConflict, conflict.Message)
	case errors.As(err, &invalid):
		response.Fail(c, http.StatusUnauthorized, invalid.Error())
	case errors.Is(err, ErrUserNotFound):
		response.Fail(c, http.StatusUnauthorized, "Sesi tidak valid: pengguna tidak ditemukan")
	default:
		log.Printf("auth: kesalahan internal: %v", err)
		response.Error(c, http.StatusInternalServerError, "Terjadi kesalahan pada server")
	}
}

// Register godoc: POST /api/auth/register
func (h *Handler) Register(c *gin.Context) {
	var req RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Fail(c, http.StatusBadRequest, "Format permintaan tidak valid")
		return
	}
	user, err := h.svc.Register(req)
	if err != nil {
		handleError(c, err)
		return
	}
	response.Success(c, http.StatusCreated, "Registrasi berhasil", user)
}

// Login godoc: POST /api/auth/login
func (h *Handler) Login(c *gin.Context) {
	var req LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Fail(c, http.StatusBadRequest, "Format permintaan tidak valid")
		return
	}
	res, err := h.svc.Login(req)
	if err != nil {
		handleError(c, err)
		return
	}
	response.Success(c, http.StatusOK, "Login berhasil", res)
}

// Logout godoc: POST /api/auth/logout. JWT bersifat stateless: klien menghapus tokennya.
func (h *Handler) Logout(c *gin.Context) {
	response.Success(c, http.StatusOK, "Logout berhasil")
}

// GetProfile godoc: GET /api/auth/profile
func (h *Handler) GetProfile(c *gin.Context) {
	user, err := h.svc.GetProfile(c.GetUint(middleware.CtxUserID))
	if err != nil {
		handleError(c, err)
		return
	}
	response.Success(c, http.StatusOK, "Profil berhasil diambil", user)
}

// UpdateProfile godoc: PUT /api/auth/profile
func (h *Handler) UpdateProfile(c *gin.Context) {
	var req UpdateProfileRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Fail(c, http.StatusBadRequest, "Format permintaan tidak valid")
		return
	}
	user, err := h.svc.UpdateProfile(c.GetUint(middleware.CtxUserID), req)
	if err != nil {
		handleError(c, err)
		return
	}
	response.Success(c, http.StatusOK, "Profil berhasil diperbarui", user)
}
