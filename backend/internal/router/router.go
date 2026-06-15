package router

import (
	"time"

	"subforge/internal/config"
	"subforge/internal/handler"
	"subforge/internal/pkg/limiter"
	"subforge/internal/service"

	"github.com/gin-gonic/gin"
)

func Setup(
	authH *handler.AuthHandler,
	userH *handler.UserHandler,
	subH *handler.SubscriptionHandler,
	convertH *handler.ConvertHandler,
	publicH *handler.PublicHandler,
	profileH *handler.ProfileHandler,
	exportH *handler.ExportHandler,
	authSvc *service.AuthService,
	cfg *config.Config,
) *gin.Engine {
	r := gin.Default()

	// Request body size limit (1MB)
	r.MaxMultipartMemory = 1 << 20

	// CORS - configurable origin
	r.Use(func(c *gin.Context) {
		origin := c.GetHeader("Origin")
		if origin == "" {
			origin = "*"
		}
		c.Header("Access-Control-Allow-Origin", origin)
		c.Header("Access-Control-Allow-Methods", "GET,POST,PUT,DELETE,OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Content-Type,Authorization")
		c.Header("Access-Control-Allow-Credentials", "true")
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}
		c.Next()
	})

	// Health check
	r.GET("/api/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok"})
	})

	// Public subscription endpoint (no auth needed)
	r.GET("/sub/:token", publicH.GetSub)
	r.GET("/sub/:token/merged", publicH.GetMergedSub)

	// Auth (public, rate-limited)
	loginLimiter := limiter.New(5, time.Minute) // 5 attempts per minute
	auth := r.Group("/api/auth")
	auth.Use(limiter.Middleware(5, time.Minute))
	{
		auth.POST("/login", authH.Login)
	}
	_ = loginLimiter // keep reference

	// Auth middleware
	authMW := handler.AuthMiddleware(authSvc)

	// Protected routes
	api := r.Group("/api")
	api.Use(authMW)
	{
		// Profile (any user)
		api.GET("/me", profileH.GetMe)
		api.PUT("/me/password", profileH.ChangePassword)

		// Users (admin only)
		users := api.Group("/users")
		users.Use(handler.AdminRequired())
		{
			users.GET("", userH.List)
			users.POST("", userH.Create)
			users.PUT("/:id/status", userH.UpdateStatus)
			users.PUT("/:id/password", userH.ResetPassword)
			users.DELETE("/:id", userH.Delete)
		}

		// Subscriptions
		subs := api.Group("/subscriptions")
		{
			subs.GET("", subH.List)
			subs.GET("/:id", subH.Get)
			subs.POST("", subH.Create)
			subs.PUT("/:id", subH.Update)
			subs.DELETE("/:id", subH.Delete)
			subs.POST("/:id/refresh", subH.Refresh)
			subs.GET("/:id/nodes", subH.GetNodes)
			subs.GET("/:id/token", subH.GetToken)
		}

		// Export/Import
		api.GET("/export", exportH.Export)
		api.POST("/import", exportH.Import)

		// Convert
		api.POST("/convert", convertH.Convert)
		api.POST("/detect", convertH.Detect)
		api.GET("/formats", convertH.ListFormats)
	}

	return r
}
