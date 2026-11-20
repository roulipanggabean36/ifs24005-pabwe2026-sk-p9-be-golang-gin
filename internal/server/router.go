package server

import (
	"net/http"
	"time"

	"app/docs"
	"app/internal/config"
	"app/internal/features/ai"
	"app/internal/features/auth"
	"app/internal/features/post"
	"app/internal/middleware"
	"app/internal/response"

	"github.com/gin-gonic/gin"
	swaggerFiles "github.com/swaggo/files"
	ginSwagger "github.com/swaggo/gin-swagger"
	"gorm.io/gorm"
)

// SetupRouter merakit seluruh dependensi dan mendaftarkan rute API serta Swagger UI.
func SetupRouter(cfg *config.Config, db *gorm.DB) *gin.Engine {
	if cfg.AppEnv == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	r := gin.New()
	r.Use(gin.Recovery())
	r.Use(middleware.CORS())
	r.Use(middleware.RateLimiter(1000, time.Second))

	authHandler := auth.NewHandler(auth.NewService(auth.NewRepository(db), cfg.AppKey))
	postHandler := post.NewHandler(post.NewService(post.NewRepository(db)))
	aiHandler := ai.NewHandler(ai.NewService(
		ai.NewOpenAIClient(cfg.OpenAIEndpoint, cfg.OpenAIKey, cfg.OpenAIModel, nil),
		ai.NewSearchClient(cfg.SearchEngineEndpoint, nil),
	))

	// Spesifikasi OpenAPI yang menyesuaikan host/scheme dengan request saat ini.
	swaggerData := func(c *gin.Context) []byte {
		host := c.GetHeader("X-Forwarded-Host")
		if host == "" {
			host = c.Request.Host
		}
		scheme := "http"
		if c.Request.TLS != nil || c.GetHeader("X-Forwarded-Proto") == "https" {
			scheme = "https"
		}
		return docs.GetSwaggerJSON(host, scheme)
	}

	r.GET("/swagger", func(c *gin.Context) {
		c.Redirect(http.StatusMovedPermanently, "/swagger/index.html")
	})
	swaggerHandler := ginSwagger.WrapHandler(swaggerFiles.Handler, ginSwagger.URL("/swagger/api.json"))
	r.GET("/swagger/*any", func(c *gin.Context) {
		switch c.Param("any") {
		case "", "/":
			c.Redirect(http.StatusMovedPermanently, "/swagger/index.html")
		case "/api.json", "/doc.json":
			c.Data(http.StatusOK, "application/json; charset=utf-8", swaggerData(c))
		default:
			swaggerHandler(c)
		}
	})
	r.GET("/api.json", func(c *gin.Context) {
		c.Data(http.StatusOK, "application/json; charset=utf-8", swaggerData(c))
	})

	api := r.Group("/api")

	authGroup := api.Group("/auth")
	authGroup.POST("/register", authHandler.Register)
	authGroup.POST("/login", authHandler.Login)
	authSecured := authGroup.Group("", middleware.Auth(cfg.AppKey))
	authSecured.POST("/logout", authHandler.Logout)
	authSecured.GET("/profile", authHandler.GetProfile)
	authSecured.PUT("/profile", authHandler.UpdateProfile)

	public := api.Group("/public")
	public.GET("/categories", postHandler.PublicCategories)
	public.GET("/posts", postHandler.PublicList)
	public.GET("/posts/:slug", postHandler.PublicDetail)

	author := api.Group("/posts", middleware.Auth(cfg.AppKey))
	author.GET("", postHandler.List)
	author.POST("", postHandler.Create)
	author.GET("/stats", postHandler.Stats)
	author.POST("/ai-generate", aiHandler.Generate)
	author.GET("/:id", postHandler.Get)
	author.PUT("/:id", postHandler.Update)
	author.PATCH("/:id/toggle-publish", postHandler.TogglePublish)
	author.DELETE("/:id", postHandler.Delete)

	admin := api.Group("/admin", middleware.Auth(cfg.AppKey), middleware.RequireRole("admin"))
	admin.GET("/users", postHandler.AdminUsers)
	admin.GET("/posts", postHandler.AdminPosts)
	admin.GET("/users/:id/posts", postHandler.AdminUserPosts)

	r.NoRoute(func(c *gin.Context) {
		response.Fail(c, http.StatusNotFound, "Endpoint not found")
	})

	return r
}
