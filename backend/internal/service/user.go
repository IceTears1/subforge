package service

import (
	"errors"
	"unicode"
	"subforge/internal/model"
	pkgcrypto "subforge/internal/pkg/crypto"

	"gorm.io/gorm"
)

type UserService struct {
	db *gorm.DB
}

func NewUserService(db *gorm.DB) *UserService {
	return &UserService{db: db}
}

type CreateUserRequest struct {
	Username string `json:"username" binding:"required,min=3,max=64"`
	Password string `json:"password" binding:"required,min=8"`
}

// ValidatePassword checks password complexity.
func ValidatePassword(password string) error {
	if len(password) < 8 {
		return errors.New("password must be at least 8 characters")
	}
	if len(password) > 128 {
		return errors.New("password must be at most 128 characters")
	}
	var hasUpper, hasLower, hasDigit bool
	for _, c := range password {
		switch {
		case unicode.IsUpper(c):
			hasUpper = true
		case unicode.IsLower(c):
			hasLower = true
		case unicode.IsDigit(c):
			hasDigit = true
		}
	}
	if !hasUpper || !hasLower || !hasDigit {
		return errors.New("password must contain uppercase, lowercase, and digit")
	}
	return nil
}

func (s *UserService) List(createdBy *uint) ([]model.User, error) {
	var users []model.User
	q := s.db.Model(&model.User{})
	if createdBy != nil {
		q = q.Where("created_by = ?", *createdBy)
	}
	err := q.Order("id ASC").Find(&users).Error
	return users, err
}

func (s *UserService) ListPaged(page, pageSize int) ([]model.User, int64, error) {
	var users []model.User
	var total int64
	q := s.db.Model(&model.User{})
	q.Count(&total)
	err := q.Order("id ASC").
		Offset((page - 1) * pageSize).
		Limit(pageSize).
		Find(&users).Error
	return users, total, err
}

func (s *UserService) Create(req CreateUserRequest, createdBy uint) (*model.User, error) {
	if err := ValidatePassword(req.Password); err != nil {
		return nil, err
	}
	var count int64
	s.db.Model(&model.User{}).Where("username = ?", req.Username).Count(&count)
	if count > 0 {
		return nil, errors.New("username already exists")
	}
	hash, err := pkgcrypto.HashPassword(req.Password)
	if err != nil {
		return nil, err
	}
	user := &model.User{
		Username:  req.Username,
		Password:  hash,
		Role:      "user",
		CreatedBy: &createdBy,
		Status:    1,
	}
	if err := s.db.Create(user).Error; err != nil {
		return nil, err
	}
	return user, nil
}

func (s *UserService) UpdateStatus(id uint, status int8) error {
	return s.db.Model(&model.User{}).Where("id = ?", id).Update("status", status).Error
}

func (s *UserService) ResetPassword(id uint, newPassword string) error {
	if err := ValidatePassword(newPassword); err != nil {
		return err
	}
	hash, err := pkgcrypto.HashPassword(newPassword)
	if err != nil {
		return err
	}
	return s.db.Model(&model.User{}).Where("id = ?", id).Update("password", hash).Error
}

func (s *UserService) Delete(id uint) error {
	return s.db.Delete(&model.User{}, id).Error
}

func (s *UserService) GetByID(id uint) (*model.User, error) {
	var user model.User
	err := s.db.First(&user, id).Error
	return &user, err
}
