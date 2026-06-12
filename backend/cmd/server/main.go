package main

import (
	"log"
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

	// Auto migrate
	if err := model.AutoMigrate(db); err != nil {
		log.Fatalf("Failed to migrate database: %v", err)
	}

	// Seed admin user
	if err := service.SeedAdmin(db, cfg); err != nil {
		log.Fatalf("Failed to seed admin: %v", err)
	}

	// Init services
	authSvc := service.NewAuthService(db, cfg)
	userSvc := service.NewUserService(db)
	subSvc := service.NewSubscriptionService(db)
	convertSvc := service.NewConvertService(db)

	// Start scheduler for auto-refresh
	scheduler := service.NewScheduler(db, subSvc)
	scheduler.Start()

	// Init handlers
	authH := handler.NewAuthHandler(authSvc)
	userH := handler.NewUserHandler(userSvc)
	subH := handler.NewSubscriptionHandler(subSvc)
	convertH := handler.NewConvertHandler(convertSvc)

	// Setup router
	r := router.Setup(authH, userH, subH, convertH, authSvc, cfg)

	log.Printf("SubForge starting on :%s", cfg.Port)
	if err := r.Run(":" + cfg.Port); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
