package service

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"subforge/internal/model"

	"gorm.io/gorm"
)

// BackupService handles backup and restore operations.
type BackupService struct {
	db         *gorm.DB
	backupDir  string
}

func NewBackupService(db *gorm.DB) *BackupService {
	return &BackupService{
		db:        db,
		backupDir: "/opt/subforge/backups",
	}
}

type BackupInfo struct {
	ID        string    `json:"id"`
	Name      string    `json:"name"`
	Size      int64     `json:"size"`
	CreatedAt time.Time `json:"created_at"`
	Items     BackupItems `json:"items"`
}

type BackupItems struct {
	Users         int `json:"users"`
	Subscriptions int `json:"subscriptions"`
	Nodes         int `json:"nodes"`
	APIKeys       int `json:"api_keys"`
	Webhooks      int `json:"webhooks"`
}

type BackupData struct {
	Version       string                  `json:"version"`
	CreatedAt     time.Time               `json:"created_at"`
	Users         []model.User            `json:"users"`
	Subscriptions []model.Subscription    `json:"subscriptions"`
	Nodes         []model.Node            `json:"nodes"`
}

// CreateBackup creates a full backup.
func (s *BackupService) CreateBackup() (*BackupInfo, error) {
	// Ensure backup directory exists
	if err := os.MkdirAll(s.backupDir, 0755); err != nil {
		return nil, fmt.Errorf("create backup dir: %w", err)
	}

	// Load all data
	var users []model.User
	s.db.Find(&users)

	var subs []model.Subscription
	s.db.Find(&subs)

	var nodes []model.Node
	s.db.Find(&nodes)

	// Create backup data
	backup := BackupData{
		Version:       "1.0.0",
		CreatedAt:     time.Now(),
		Users:         users,
		Subscriptions: subs,
		Nodes:         nodes,
	}

	// Marshal to JSON
	data, err := json.MarshalIndent(backup, "", "  ")
	if err != nil {
		return nil, fmt.Errorf("marshal backup: %w", err)
	}

	// Generate filename
	timestamp := time.Now().Format("20060102-150405")
	filename := fmt.Sprintf("subforge-backup-%s.json", timestamp)
	filepath := filepath.Join(s.backupDir, filename)

	// Write to file
	if err := os.WriteFile(filepath, data, 0644); err != nil {
		return nil, fmt.Errorf("write backup: %w", err)
	}

	// Get file info
	info, _ := os.Stat(filepath)

	log.Printf("Backup created: %s", filepath)

	return &BackupInfo{
		ID:        timestamp,
		Name:      filename,
		Size:      info.Size(),
		CreatedAt: time.Now(),
		Items: BackupItems{
			Users:         len(users),
			Subscriptions: len(subs),
			Nodes:         len(nodes),
		},
	}, nil
}

// ListBackups returns all available backups.
func (s *BackupService) ListBackups() ([]BackupInfo, error) {
	if err := os.MkdirAll(s.backupDir, 0755); err != nil {
		return nil, err
	}

	files, err := os.ReadDir(s.backupDir)
	if err != nil {
		return nil, err
	}

	var backups []BackupInfo
	for _, f := range files {
		if !strings.HasSuffix(f.Name(), ".json") {
			continue
		}
		info, _ := f.Info()
		backups = append(backups, BackupInfo{
			ID:        strings.TrimSuffix(f.Name(), ".json"),
			Name:      f.Name(),
			Size:      info.Size(),
			CreatedAt: info.ModTime(),
		})
	}

	return backups, nil
}

// RestoreBackup restores from a backup file.
func (s *BackupService) RestoreBackup(backupID string) error {
	filename := fmt.Sprintf("subforge-backup-%s.json", backupID)
	filepath := filepath.Join(s.backupDir, filename)

	// Read file
	data, err := os.ReadFile(filepath)
	if err != nil {
		return fmt.Errorf("read backup: %w", err)
	}

	// Parse backup
	var backup BackupData
	if err := json.Unmarshal(data, &backup); err != nil {
		return fmt.Errorf("parse backup: %w", err)
	}

	// Start transaction
	tx := s.db.Begin()

	// Clear existing data
	tx.Exec("DELETE FROM nodes")
	tx.Exec("DELETE FROM subscriptions")
	tx.Exec("DELETE FROM users WHERE role != 'admin'")

	// Restore users (skip admin)
	for _, user := range backup.Users {
		if user.Role == "admin" {
			continue
		}
		tx.Create(&user)
	}

	// Restore subscriptions
	for _, sub := range backup.Subscriptions {
		tx.Create(&sub)
	}

	// Restore nodes
	for _, node := range backup.Nodes {
		tx.Create(&node)
	}

	if err := tx.Commit().Error; err != nil {
		return fmt.Errorf("restore failed: %w", err)
	}

	log.Printf("Backup restored: %s", filename)
	return nil
}

// DeleteBackup deletes a backup file.
func (s *BackupService) DeleteBackup(backupID string) error {
	filename := fmt.Sprintf("subforge-backup-%s.json", backupID)
	filepath := filepath.Join(s.backupDir, filename)
	return os.Remove(filepath)
}

// ExportBackup exports backup as downloadable file.
func (s *BackupService) ExportBackup(backupID string) ([]byte, error) {
	filename := fmt.Sprintf("subforge-backup-%s.json", backupID)
	filepath := filepath.Join(s.backupDir, filename)
	return os.ReadFile(filepath)
}

// ImportBackup imports a backup from uploaded file.
func (s *BackupService) ImportBackup(data []byte) error {
	var backup BackupData
	if err := json.Unmarshal(data, &backup); err != nil {
		return fmt.Errorf("invalid backup format: %w", err)
	}

	// Create backup dir
	os.MkdirAll(s.backupDir, 0755)

	// Save imported file
	timestamp := time.Now().Format("20060102-150405")
	filename := fmt.Sprintf("subforge-backup-imported-%s.json", timestamp)
	filepath := filepath.Join(s.backupDir, filename)

	if err := os.WriteFile(filepath, data, 0644); err != nil {
		return fmt.Errorf("save import: %w", err)
	}

	return nil
}

// CreateSystemBackup creates a full system backup using shell commands.
func (s *BackupService) CreateSystemBackup() (string, error) {
	timestamp := time.Now().Format("20060102-150405")
	backupFile := filepath.Join(s.backupDir, fmt.Sprintf("system-backup-%s.tar.gz", timestamp))

	os.MkdirAll(s.backupDir, 0755)

	// Create tar.gz backup
	cmd := exec.Command("tar", "-czf", backupFile, ".env", "nginx/")
	cmd.Dir = "/opt/subforge"
	output, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("system backup failed: %w\n%s", err, output)
	}

	return backupFile, nil
}
