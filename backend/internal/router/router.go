package router

import (
	"strings"
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
	webhookH *handler.WebhookHandler,
	batchH *handler.BatchHandler,
	healthH *handler.HealthHandler,
	auditH *handler.AuditHandler,
	metricsH *handler.MetricsHandler,
	apiKeyH *handler.APIKeyHandler,
	updateH *handler.UpdateHandler,
	apiKeySvc *service.APIKeyService,
	authSvc *service.AuthService,
	cfg *config.Config,
) *gin.Engine {
	r := gin.Default()

	// Request body size limit (1MB)
	r.MaxMultipartMemory = 1 << 20

	// CORS - strict origin validation
	allowedOrigins := parseAllowedOrigins(cfg.CORSOrigins)
	r.Use(func(c *gin.Context) {
		origin := c.GetHeader("Origin")
		allowed := false
		if origin != "" {
			for _, o := range allowedOrigins {
				if origin == o {
					allowed = true
					break
				}
			}
		}
		if allowed {
			c.Header("Access-Control-Allow-Origin", origin)
			c.Header("Access-Control-Allow-Credentials", "true")
		} else if len(allowedOrigins) == 0 {
			// No origins configured = no CORS (same-origin only)
			c.Header("Access-Control-Allow-Origin", "")
		}
		c.Header("Access-Control-Allow-Methods", "GET,POST,PUT,DELETE,OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Content-Type,Authorization")
		c.Header("Access-Control-Max-Age", "86400")
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

	// Metrics (public)
	r.GET("/api/metrics", metricsH.GetMetrics)

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
	authMW := handler.AuthMiddleware(authSvc, apiKeySvc)
	adminRequired := handler.AdminRequired()
	ipWhitelist := handler.IPWhitelistMiddleware(cfg)

	// Protected routes
	api := r.Group("/api")
	api.Use(authMW)
	api.Use(ipWhitelist)
	{
		// Auth
		api.POST("/auth/logout", authH.Logout)

		// Profile (any user)
		api.GET("/me", profileH.GetMe)
		api.PUT("/me/password", profileH.ChangePassword)

		// API Keys (any user)
		apikeys := api.Group("/apikeys")
		{
			apikeys.GET("", apiKeyH.List)
			apikeys.POST("", apiKeyH.Create)
			apikeys.DELETE("/:id", apiKeyH.Delete)
		}

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

		// Batch operations
		api.POST("/subscriptions/batch/delete", batchH.BatchDelete)
		api.POST("/subscriptions/batch/refresh", batchH.BatchRefresh)
		api.POST("/subscriptions/batch/export", exportH.BatchExport)

		// Export/Import
		api.GET("/export", exportH.Export)
		api.POST("/import", exportH.Import)

		// Webhooks
		webhooks := api.Group("/webhooks")
		{
			webhooks.GET("", webhookH.List)
			webhooks.POST("", webhookH.Create)
			webhooks.DELETE("/:id", webhookH.Delete)
		}

		// Health check
		api.POST("/subscriptions/:id/check", healthH.CheckSubscription)

		// Audit logs (admin only)
		api.GET("/audit", adminRequired, auditH.List)

		// Version update (admin only)
		update := api.Group("/update")
		update.Use(adminRequired)
		{
			update.GET("/version", updateH.GetVersion)
			update.GET("/releases", updateH.GetReleases)
			update.GET("/status", updateH.GetUpdateStatus)
			update.GET("/changelog", updateH.GetChangelog)
			update.POST("/latest", updateH.UpdateToLatest)
			update.POST("/tag", updateH.UpdateToTag)
			update.POST("/rollback", updateH.Rollback)
		}

		// Convert
		api.POST("/convert", convertH.Convert)
		api.POST("/detect", convertH.Detect)
		api.GET("/formats", convertH.ListFormats)
	}

	return r
}

func parseAllowedOrigins(origins string) []string {
	if origins == "" {
		return nil
	}
	var result []string
	for _, o := range strings.Split(origins, ",") {
		o = strings.TrimSpace(o)
		if o != "" {
			result = append(result, o)
		}
	}
	return result
}
