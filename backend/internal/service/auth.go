package service

import (
	"errors"
	"time"

	"subforge/internal/config"
	"subforge/internal/model"
	pkgcrypto "subforge/internal/pkg/crypto"
	pkgjwt "subforge/internal/pkg/jwt"

	"gorm.io/gorm"
)

type AuthService struct {
	db  *gorm.DB
	cfg *config.Config
}

func NewAuthService(db *gorm.DB, cfg *config.Config) *AuthService {
	return &AuthService{db: db, cfg: cfg}
}

// SeedAdmin creates the default admin user if not exists.
func SeedAdmin(db *gorm.DB, cfg *config.Config) error {
	var count int64
	db.Model(&model.User{}).Where("role = ?", "admin").Count(&count)
	if count > 0 {
		return nil
	}
	hash, err := pkgcrypto.HashPassword(cfg.AdminPassword)
	if err != nil {
		return err
	}
	return db.Create(&model.User{
		Username: "admin",
		Password: hash,
		Role:     "admin",
		Status:   1,
	}).Error
}

type LoginRequest struct {
	Username string `json:"username" binding:"required"`
	Password string `json:"password" binding:"required"`
}

type LoginResponse struct {
	Token     string      `json:"token"`
	ExpiresIn int         `json:"expires_in"`
	User      model.User  `json:"user"`
}

func (s *AuthService) Login(req LoginRequest) (*LoginResponse, error) {
	var user model.User
	if err := s.db.Where("username = ? AND status = 1", req.Username).First(&user).Error; err != nil {
		return nil, errors.New("invalid credentials")
	}
	if !pkgcrypto.CheckPassword(req.Password, user.Password) {
		return nil, errors.New("invalid credentials")
	}

	expiry := 24 * time.Hour
	token, err := pkgjwt.Generate(s.cfg.JWTSecret, user.ID, user.Role, expiry)
	if err != nil {
		return nil, err
	}

	return &LoginResponse{
		Token:     token,
		ExpiresIn: int(expiry.Seconds()),
		User:      user,
	}, nil
}

func (s *AuthService) ValidateToken(token string) (*pkgjwt.Claims, error) {
	return pkgjwt.Validate(s.cfg.JWTSecret, token)
}
