package model

import (
	"fmt"
	"subforge/internal/config"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

var additionalModels []interface{}

// RegisterModel registers additional models for auto-migration.
func RegisterModel(model ...interface{}) {
	additionalModels = append(additionalModels, model...)
}

func InitDB(cfg *config.Config) (*gorm.DB, error) {
	dsn := fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
		cfg.DBHost, cfg.DBPort, cfg.DBUser, cfg.DBPassword, cfg.DBName, cfg.DBSSLMode,
	)
	return gorm.Open(postgres.Open(dsn), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Warn),
	})
}

func AutoMigrate(db *gorm.DB) error {
	models := []interface{}{&User{}, &Subscription{}, &Node{}}
	models = append(models, additionalModels...)
	return db.AutoMigrate(models...)
}
