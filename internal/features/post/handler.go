package post

import (
	"errors"
	"log"
	"net/http"
	"strconv"

	"app/internal/middleware"
	"app/internal/response"

	"github.com/gin-gonic/gin"
)

// Handler menangani /api/public/*, /api/posts/*, dan /api/admin/*.
type Handler struct{ svc Service }

// NewHandler membuat Handler.
func NewHandler(svc Service) *Handler { return &Handler{svc: svc} }

func handleError(c *gin.Context, err error) {
	var validation *ValidationError
	switch {
	case errors.As(err, &validation):
		response.Fail(c, http.StatusBadRequest, validation.Message)
	case errors.Is(err, ErrPostNotFound):
		response.Fail(c, http.StatusNotFound, "Artikel tidak ditemukan")
	case errors.Is(err, ErrUserNotFound):
		response.Fail(c, http.StatusNotFound, "Pengguna tidak ditemukan")
	default:
		log.Printf("post: kesalahan internal: %v", err)
		response.Error(c, http.StatusInternalServerError, "Terjadi kesalahan pada server")
	}
}

func parseID(c *gin.Context) (uint, bool) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil || id == 0 {
		response.Fail(c, http.StatusBadRequest, "ID tidak valid")
		return 0, false
	}
	return uint(id), true
}

func currentUser(c *gin.Context) uint { return c.GetUint(middleware.CtxUserID) }

// PublicCategories: GET /api/public/categories
func (h *Handler) PublicCategories(c *gin.Context) {
	response.Success(c, http.StatusOK, "Kategori berhasil diambil", h.svc.Categories())
}

// PublicList: GET /api/public/posts?q=&category=
func (h *Handler) PublicList(c *gin.Context) {
	posts, err := h.svc.ListPublic(c.Query("q"), c.Query("category"))
	if err != nil {
		handleError(c, err)
		return
	}
	response.Success(c, http.StatusOK, "Artikel berhasil diambil", posts)
}

// PublicDetail: GET /api/public/posts/:slug
func (h *Handler) PublicDetail(c *gin.Context) {
	p, err := h.svc.GetPublic(c.Param("slug"))
	if err != nil {
		handleError(c, err)
		return
	}
	response.Success(c, http.StatusOK, "Artikel berhasil diambil", p)
}

// List: GET /api/posts
func (h *Handler) List(c *gin.Context) {
	posts, err := h.svc.ListMine(currentUser(c))
	if err != nil {
		handleError(c, err)
		return
	}
	response.Success(c, http.StatusOK, "Artikel berhasil diambil", posts)
}

// Create: POST /api/posts
func (h *Handler) Create(c *gin.Context) {
	var req PostRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Fail(c, http.StatusBadRequest, "Format permintaan tidak valid")
		return
	}
	p, err := h.svc.Create(currentUser(c), req)
	if err != nil {
		handleError(c, err)
		return
	}
	response.Success(c, http.StatusCreated, "Artikel berhasil dibuat", p)
}

// Stats: GET /api/posts/stats
func (h *Handler) Stats(c *gin.Context) {
	stats, err := h.svc.Stats(currentUser(c))
	if err != nil {
		handleError(c, err)
		return
	}
	response.Success(c, http.StatusOK, "Statistik berhasil diambil", stats)
}

// Get: GET /api/posts/:id
func (h *Handler) Get(c *gin.Context) {
	id, ok := parseID(c)
	if !ok {
		return
	}
	p, err := h.svc.Get(currentUser(c), id)
	if err != nil {
		handleError(c, err)
		return
	}
	response.Success(c, http.StatusOK, "Artikel berhasil diambil", p)
}

// Update: PUT /api/posts/:id
func (h *Handler) Update(c *gin.Context) {
	id, ok := parseID(c)
	if !ok {
		return
	}
	var req PostRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Fail(c, http.StatusBadRequest, "Format permintaan tidak valid")
		return
	}
	p, err := h.svc.Update(currentUser(c), id, req)
	if err != nil {
		handleError(c, err)
		return
	}
	response.Success(c, http.StatusOK, "Artikel berhasil diperbarui", p)
}

// TogglePublish: PATCH /api/posts/:id/toggle-publish
func (h *Handler) TogglePublish(c *gin.Context) {
	id, ok := parseID(c)
	if !ok {
		return
	}
	p, err := h.svc.TogglePublish(currentUser(c), id)
	if err != nil {
		handleError(c, err)
		return
	}
	message := "Artikel dikembalikan ke draf"
	if p.IsPublished {
		message = "Artikel berhasil diterbitkan"
	}
	response.Success(c, http.StatusOK, message, p)
}

// Delete: DELETE /api/posts/:id
func (h *Handler) Delete(c *gin.Context) {
	id, ok := parseID(c)
	if !ok {
		return
	}
	if err := h.svc.Delete(currentUser(c), id); err != nil {
		handleError(c, err)
		return
	}
	response.Success(c, http.StatusOK, "Artikel berhasil dihapus")
}

// AdminUsers: GET /api/admin/users
func (h *Handler) AdminUsers(c *gin.Context) {
	users, err := h.svc.AdminUsers()
	if err != nil {
		handleError(c, err)
		return
	}
	response.Success(c, http.StatusOK, "Pengguna berhasil diambil", users)
}

// AdminPosts: GET /api/admin/posts
func (h *Handler) AdminPosts(c *gin.Context) {
	posts, err := h.svc.AdminPosts()
	if err != nil {
		handleError(c, err)
		return
	}
	response.Success(c, http.StatusOK, "Arsip artikel berhasil diambil", posts)
}

// AdminUserPosts: GET /api/admin/users/:id/posts
func (h *Handler) AdminUserPosts(c *gin.Context) {
	id, ok := parseID(c)
	if !ok {
		return
	}
	posts, err := h.svc.AdminUserPosts(id)
	if err != nil {
		handleError(c, err)
		return
	}
	response.Success(c, http.StatusOK, "Artikel pengguna berhasil diambil", posts)
}
