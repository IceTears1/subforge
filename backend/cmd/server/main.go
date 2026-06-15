package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"subforge/internal/config"
	"subforge/internal/handler"
	"subforge/internal/model"
	"subforge/internal/router"
	"subforge/internal/service"
)

func main() {
	cfg := config.Load()

	db, err := model.InitDB(cfg)
	if err != nil {
		log.Fatalf("Failed to connect database: %v", err)
	}

	if err := model.AutoMigrate(db); err != nil {
		log.Fatalf("Failed to migrate database: %v", err)
	}

	if err := service.SeedAdmin(db, cfg); err != nil {
		log.Fatalf("Failed to seed admin: %v", err)
	}

	// Init services
	authSvc := service.NewAuthService(db, cfg)
	userSvc := service.NewUserService(db)
	subSvc := service.NewSubscriptionService(db)
	convertSvc := service.NewConvertService(db)

	// Start scheduler
	scheduler := service.NewScheduler(db, subSvc)
	scheduler.Start()

	// Init handlers
	authH := handler.NewAuthHandler(authSvc)
	userH := handler.NewUserHandler(userSvc)
	subH := handler.NewSubscriptionHandler(subSvc)
	convertH := handler.NewConvertHandler(convertSvc)
	publicH := handler.NewPublicHandler(subSvc)
	profileH := handler.NewProfileHandler(userSvc)
	exportH := handler.NewExportHandler(subSvc)

	// Setup router
	r := router.Setup(authH, userH, subH, convertH, publicH, profileH, exportH, authSvc, cfg)

	// Graceful shutdown
	srv := &http.Server{
		Addr:         ":" + cfg.Port,
		Handler:      r,
		ReadTimeout:  30 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  120 * time.Second,
	}

	go func() {
		log.Printf("SubForge starting on :%s", cfg.Port)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Failed to start server: %v", err)
		}
	}()

	// Wait for interrupt signal
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("Shutting down server...")

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("Server forced to shutdown: %v", err)
	}

	log.Println("Server exited")
}
