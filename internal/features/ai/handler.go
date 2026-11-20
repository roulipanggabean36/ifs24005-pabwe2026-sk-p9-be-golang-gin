package ai

import (
	"errors"
	"log"
	"net/http"

	"app/internal/response"

	"github.com/gin-gonic/gin"
)

// Handler menangani POST /api/posts/ai-generate.
type Handler struct{ svc Service }

// NewHandler membuat Handler.
func NewHandler(svc Service) *Handler { return &Handler{svc: svc} }

// Generate godoc: POST /api/posts/ai-generate
func (h *Handler) Generate(c *gin.Context) {
	var req GenerateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Fail(c, http.StatusBadRequest, "Format permintaan tidak valid")
		return
	}

	res, err := h.svc.Generate(c.Request.Context(), req)
	if err != nil {
		var validation *ValidationError
		var upstream *ServiceError
		switch {
		case errors.As(err, &validation):
			response.Fail(c, http.StatusBadRequest, validation.Message)
		case errors.As(err, &upstream):
			log.Printf("ai: layanan hulu gagal: %v", upstream.Err)
			response.Error(c, upstream.Status, upstream.Message)
		default:
			log.Printf("ai: kesalahan internal: %v", err)
			response.Error(c, http.StatusInternalServerError, "Terjadi kesalahan pada server")
		}
		return
	}
	response.Success(c, http.StatusOK, "Draf artikel berhasil dibuat", res)
}
