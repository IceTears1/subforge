package config

import (
	"log"
	"os"
)

type Config struct {
	Port              string
	DBHost            string
	DBPort            string
	DBName            string
	DBUser            string
	DBPassword        string
	JWTSecret         string
	JWTExpiry         string
	AdminPassword     string
	GinMode           string
	AdminIPWhitelist  string // comma-separated IPs, empty = no restriction
}

func Load() *Config {
	cfg := &Config{
		Port:          getEnv("PORT", "8080"),
		DBHost:        getEnv("DB_HOST", "localhost"),
		DBPort:        getEnv("DB_PORT", "5432"),
		DBName:        getEnv("DB_NAME", "subforge"),
		DBUser:        getEnv("DB_USER", "subforge"),
		DBPassword:    getEnv("DB_PASSWORD", "subforge123"),
		JWTSecret:     getEnv("JWT_SECRET", "change-me-in-production"),
		JWTExpiry:     getEnv("JWT_EXPIRY", "24h"),
		AdminPassword:    getEnv("ADMIN_PASSWORD", "admin123"),
		GinMode:          getEnv("GIN_MODE", "debug"),
		AdminIPWhitelist: getEnv("ADMIN_IP_WHITELIST", ""),
	}
	cfg.validate()
	return cfg
}

func (c *Config) validate() {
	if c.GinMode == "release" {
		defaults := map[string]string{
			"JWT_SECRET":     c.JWTSecret,
			"DB_PASSWORD":    c.DBPassword,
			"ADMIN_PASSWORD": c.AdminPassword,
		}
		for k, v := range defaults {
			if isDefault(v) {
				log.Fatalf("[SECURITY] %s is using a default value. Set it in .env before running in production.", k)
			}
		}
	}
	if len(c.JWTSecret) < 16 {
		log.Println("[WARN] JWT_SECRET is very short. Use at least 32 characters.")
	}
}

func isDefault(val string) bool {
	defaults := []string{
		"change-me-in-production",
		"subforge123",
		"admin123",
	}
	for _, d := range defaults {
		if val == d {
			return true
		}
	}
	return false
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
