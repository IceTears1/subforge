package service

import (
	"fmt"
	"log"
	"os/exec"
	"strings"
	"sync"
	"time"
)

// UpdateService handles version checking and updating.
type UpdateService struct {
	installDir string
	mu         sync.Mutex
	updating   bool
	lastResult *UpdateResult
}

func NewUpdateService(installDir string) *UpdateService {
	if installDir == "" {
		installDir = "/opt/subforge"
	}
	return &UpdateService{installDir: installDir}
}

type VersionInfo struct {
	Current   string    `json:"current"`
	Latest    string    `json:"latest"`
	HasUpdate bool      `json:"has_update"`
	Changelog string    `json:"changelog"`
	LastCheck time.Time `json:"last_check"`
}

type UpdateResult struct {
	Success   bool      `json:"success"`
	From      string    `json:"from"`
	To        string    `json:"to"`
	Steps     []Step    `json:"steps"`
	Timestamp time.Time `json:"timestamp"`
	Error     string    `json:"error,omitempty"`
}

type Step struct {
	Name    string `json:"name"`
	Status  string `json:"status"` // pending|running|success|failed
	Message string `json:"message"`
}

// GetVersion returns current and latest version info.
func (s *UpdateService) GetVersion() (*VersionInfo, error) {
	current, err := s.runGit("rev-parse", "--short", "HEAD")
	if err != nil {
		return nil, fmt.Errorf("get current version: %w", err)
	}

	s.runGit("fetch", "origin", "main")

	latest, err := s.runGit("rev-parse", "--short", "origin/main")
	if err != nil {
		return nil, fmt.Errorf("get latest version: %w", err)
	}

	changelog := ""
	if current != latest {
		logOutput, err := s.runGit("log", "--oneline", fmt.Sprintf("%s..%s", current, latest))
		if err == nil {
			changelog = logOutput
		}
	}

	return &VersionInfo{
		Current:   current,
		Latest:    latest,
		HasUpdate: current != latest,
		Changelog: changelog,
		LastCheck: time.Now(),
	}, nil
}

// GetChangelog returns recent commits.
func (s *UpdateService) GetChangelog(count int) ([]map[string]string, error) {
	if count <= 0 {
		count = 20
	}

	output, err := s.runGit("log", "--oneline", "--format=%h|%s|%ai", fmt.Sprintf("-%d", count))
	if err != nil {
		return nil, err
	}

	var versions []map[string]string
	for _, line := range strings.Split(output, "\n") {
		parts := strings.SplitN(line, "|", 3)
		if len(parts) == 3 {
			versions = append(versions, map[string]string{
				"hash":    parts[0],
				"message": parts[1],
				"date":    parts[2],
			})
		}
	}

	return versions, nil
}

// Update performs the update with backup and rollback support.
func (s *UpdateService) Update() (*UpdateResult, error) {
	s.mu.Lock()
	if s.updating {
		s.mu.Unlock()
		return nil, fmt.Errorf("update already in progress")
	}
	s.updating = true
	s.mu.Unlock()

	defer func() {
		s.mu.Lock()
		s.updating = false
		s.mu.Unlock()
	}()

	currentVersion, _ := s.runGit("rev-parse", "--short", "HEAD")

	result := &UpdateResult{
		From:      currentVersion,
		Timestamp: time.Now(),
		Steps: []Step{
			{Name: "备份配置", Status: "pending"},
			{Name: "拉取代码", Status: "pending"},
			{Name: "检查数据库迁移", Status: "pending"},
			{Name: "构建镜像", Status: "pending"},
			{Name: "重启服务", Status: "pending"},
			{Name: "验证部署", Status: "pending"},
		},
	}

	// Step 1: Backup config
	result.Steps[0].Status = "running"
	backupFile := fmt.Sprintf("/tmp/subforge-backup-%s.tar.gz", time.Now().Format("20060102-150405"))
	_, err := s.runCommand("tar", "-czf", backupFile, ".env", "nginx/")
	if err != nil {
		result.Steps[0].Status = "failed"
		result.Steps[0].Message = fmt.Sprintf("backup failed: %v", err)
		result.Error = result.Steps[0].Message
		s.lastResult = result
		return result, fmt.Errorf("backup failed: %w", err)
	}
	result.Steps[0].Status = "success"
	result.Steps[0].Message = backupFile

	// Step 2: Pull latest code
	result.Steps[1].Status = "running"
	output, err := s.runGit("pull", "origin", "main")
	if err != nil {
		result.Steps[1].Status = "failed"
		result.Steps[1].Message = fmt.Sprintf("git pull failed: %v", err)
		result.Error = result.Steps[1].Message
		s.lastResult = result
		return result, fmt.Errorf("git pull failed: %w", err)
	}
	newVersion, _ := s.runGit("rev-parse", "--short", "HEAD")
	result.To = newVersion
	result.Steps[1].Status = "success"
	result.Steps[1].Message = output

	// Step 3: Check database migrations
	result.Steps[2].Status = "running"
	migrationOutput, _ := s.runGit("diff", "--name-only", currentVersion, newVersion, "--", "backend/migrations/")
	if migrationOutput != "" {
		result.Steps[2].Message = "New migrations: " + migrationOutput
	} else {
		result.Steps[2].Message = "No new migrations"
	}
	result.Steps[2].Status = "success"

	// Step 4: Build images
	result.Steps[3].Status = "running"
	buildOutput, err := s.runCommand("docker", "compose", "build", "--no-cache")
	if err != nil {
		result.Steps[3].Status = "failed"
		result.Steps[3].Message = fmt.Sprintf("build failed: %v\n%s", err, buildOutput)
		result.Error = result.Steps[3].Message
		s.runGit("checkout", currentVersion)
		s.lastResult = result
		return result, fmt.Errorf("build failed: %w", err)
	}
	result.Steps[3].Status = "success"

	// Step 5: Restart services
	result.Steps[4].Status = "running"
	_, err = s.runCommand("docker", "compose", "down")
	if err != nil {
		result.Steps[4].Status = "failed"
		result.Steps[4].Message = fmt.Sprintf("stop failed: %v", err)
		result.Error = result.Steps[4].Message
		s.lastResult = result
		return result, fmt.Errorf("stop failed: %w", err)
	}

	_, err = s.runCommand("docker", "compose", "up", "-d")
	if err != nil {
		result.Steps[4].Status = "failed"
		result.Steps[4].Message = fmt.Sprintf("start failed: %v", err)
		result.Error = result.Steps[4].Message
		s.lastResult = result
		return result, fmt.Errorf("start failed: %w", err)
	}
	result.Steps[4].Status = "success"

	// Step 6: Verify deployment
	result.Steps[5].Status = "running"
	time.Sleep(5 * time.Second)
	healthOutput, err := s.runCommand("curl", "-s", "http://localhost:8080/api/health")
	if err != nil || !strings.Contains(healthOutput, "ok") {
		result.Steps[5].Status = "failed"
		result.Steps[5].Message = "health check failed"
		log.Println("Health check failed, rolling back...")
		s.runGit("checkout", currentVersion)
		s.runCommand("docker", "compose", "down")
		s.runCommand("docker", "compose", "up", "-d", "--build")
		result.Error = "update failed, rolled back to " + currentVersion
		s.lastResult = result
		return result, fmt.Errorf("health check failed, rolled back")
	}
	result.Steps[5].Status = "success"
	result.Steps[5].Message = "health check passed"

	result.Success = true
	s.lastResult = result
	return result, nil
}

// IsUpdating returns whether an update is in progress.
func (s *UpdateService) IsUpdating() bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.updating
}

// GetLastResult returns the last update result.
func (s *UpdateService) GetLastResult() *UpdateResult {
	return s.lastResult
}

// Rollback rolls back to a specific version.
func (s *UpdateService) Rollback(targetVersion string) (*UpdateResult, error) {
	s.mu.Lock()
	if s.updating {
		s.mu.Unlock()
		return nil, fmt.Errorf("update in progress")
	}
	s.updating = true
	s.mu.Unlock()

	defer func() {
		s.mu.Lock()
		s.updating = false
		s.mu.Unlock()
	}()

	currentVersion, _ := s.runGit("rev-parse", "--short", "HEAD")

	result := &UpdateResult{
		From:      currentVersion,
		To:        targetVersion,
		Timestamp: time.Now(),
		Steps: []Step{
			{Name: "切换版本", Status: "pending"},
			{Name: "重建服务", Status: "pending"},
			{Name: "验证部署", Status: "pending"},
		},
	}

	// Step 1: Checkout
	result.Steps[0].Status = "running"
	_, err := s.runGit("checkout", targetVersion)
	if err != nil {
		result.Steps[0].Status = "failed"
		result.Steps[0].Message = fmt.Sprintf("checkout failed: %v", err)
		result.Error = result.Steps[0].Message
		return result, err
	}
	result.Steps[0].Status = "success"

	// Step 2: Rebuild
	result.Steps[1].Status = "running"
	_, err = s.runCommand("docker", "compose", "down")
	if err != nil {
		result.Steps[1].Status = "failed"
		result.Steps[1].Message = fmt.Sprintf("stop failed: %v", err)
		result.Error = result.Steps[1].Message
		return result, err
	}

	_, err = s.runCommand("docker", "compose", "up", "-d", "--build")
	if err != nil {
		result.Steps[1].Status = "failed"
		result.Steps[1].Message = fmt.Sprintf("build failed: %v", err)
		result.Error = result.Steps[1].Message
		return result, err
	}
	result.Steps[1].Status = "success"

	// Step 3: Verify
	result.Steps[2].Status = "running"
	time.Sleep(5 * time.Second)
	healthOutput, err := s.runCommand("curl", "-s", "http://localhost:8080/api/health")
	if err != nil || !strings.Contains(healthOutput, "ok") {
		result.Steps[2].Status = "failed"
		result.Steps[2].Message = "health check failed"
		result.Error = "rollback verification failed"
		return result, fmt.Errorf("health check failed")
	}
	result.Steps[2].Status = "success"
	result.Steps[2].Message = "health check passed"

	result.Success = true
	return result, nil
}

func (s *UpdateService) runGit(args ...string) (string, error) {
	cmd := exec.Command("git", args...)
	cmd.Dir = s.installDir
	output, err := cmd.CombinedOutput()
	return strings.TrimSpace(string(output)), err
}

func (s *UpdateService) runCommand(name string, args ...string) (string, error) {
	cmd := exec.Command(name, args...)
	cmd.Dir = s.installDir
	output, err := cmd.CombinedOutput()
	return strings.TrimSpace(string(output)), err
}
