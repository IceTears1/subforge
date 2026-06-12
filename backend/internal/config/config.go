package config

import "os"

type Config struct {
	Port          string
	DBHost        string
	DBPort        string
	DBName        string
	DBUser        string
	DBPassword    string
	JWTSecret     string
	JWTExpiry     string
	AdminPassword string
}

func Load() *Config {
	return &Config{
		Port:          getEnv("PORT", "8080"),
		DBHost:        getEnv("DB_HOST", "localhost"),
		DBPort:        getEnv("DB_PORT", "5432"),
		DBName:        getEnv("DB_NAME", "subforge"),
		DBUser:        getEnv("DB_USER", "subforge"),
		DBPassword:    getEnv("DB_PASSWORD", "subforge123"),
		JWTSecret:     getEnv("JWT_SECRET", "change-me-in-production"),
		JWTExpiry:     getEnv("JWT_EXPIRY", "24h"),
		AdminPassword: getEnv("ADMIN_PASSWORD", "admin123"),
	}
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
