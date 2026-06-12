package router

import (
	"subforge/internal/config"
	"subforge/internal/handler"
	"subforge/internal/service"

	"github.com/gin-gonic/gin"
)

func Setup(
	authH *handler.AuthHandler,
	userH *handler.UserHandler,
	subH *handler.SubscriptionHandler,
	convertH *handler.ConvertHandler,
	authSvc *service.AuthService,
	cfg *config.Config,
) *gin.Engine {
	r := gin.Default()

	// CORS
	r.Use(func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET,POST,PUT,DELETE,OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Content-Type,Authorization")
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}
		c.Next()
	})

	r.GET("/api/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok"})
	})

	// Auth (public)
	auth := r.Group("/api/auth")
	{
		auth.POST("/login", authH.Login)
	}

	// Auth middleware
	authMW := handler.AuthMiddleware(authSvc)

	// Protected routes
	api := r.Group("/api")
	api.Use(authMW)
	{
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
		}

		// Convert
		api.POST("/convert", convertH.Convert)
		api.POST("/detect", convertH.Detect)
		api.GET("/formats", convertH.ListFormats)
	}

	return r
}
