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
	Current     string    `json:"current"`      // 当前 commit hash
	CurrentTag  string    `json:"current_tag"`   // 当前 tag (v1.0.0)
	Latest      string    `json:"latest"`        // 最新 commit hash
	LatestTag   string    `json:"latest_tag"`    // 最新 tag
	HasUpdate   bool      `json:"has_update"`
	Changelog   string    `json:"changelog"`
	LastCheck   time.Time `json:"last_check"`
	UpdateMode  string    `json:"update_mode"`   // tag | branch
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

type Release struct {
	Tag         string `json:"tag"`
	CommitHash  string `json:"commit_hash"`
	Message     string `json:"message"`
	Date        string `json:"date"`
	IsCurrent   bool   `json:"is_current"`
}

// GetVersion returns current and latest version info.
func (s *UpdateService) GetVersion() (*VersionInfo, error) {
	// Fetch all tags and branches
	s.runGit("fetch", "--all", "--tags")

	// Get current version
	current, _ := s.runGit("rev-parse", "--short", "HEAD")
	currentTag, _ := s.runGit("describe", "--tags", "--exact-match", "HEAD")
	if strings.Contains(currentTag, "fatal") {
		currentTag = ""
	}

	// Get latest tag
	latestTag, _ := s.runGit("describe", "--tags", "--abbrev=0", "origin/main")
	if strings.Contains(latestTag, "fatal") {
		latestTag = ""
	}

	// Get latest commit
	latest, _ := s.runGit("rev-parse", "--short", "origin/main")

	// Check if update available
	hasUpdate := false
	changelog := ""

	if latestTag != "" && currentTag != latestTag {
		// Tag-based update available
		hasUpdate = true
		logOutput, _ := s.runGit("log", "--oneline", fmt.Sprintf("%s..%s", currentTag, latestTag))
		changelog = logOutput
	} else if currentTag == "" && current != latest {
		// Branch-based update (no tag)
		hasUpdate = true
		logOutput, _ := s.runGit("log", "--oneline", fmt.Sprintf("%s..%s", current, latest))
		changelog = logOutput
	}

	// Determine update mode
	updateMode := "tag"
	if latestTag == "" {
		updateMode = "branch"
	}

	return &VersionInfo{
		Current:    current,
		CurrentTag: currentTag,
		Latest:     latest,
		LatestTag:  latestTag,
		HasUpdate:  hasUpdate,
		Changelog:  changelog,
		LastCheck:  time.Now(),
		UpdateMode: updateMode,
	}, nil
}

// GetReleases returns all available releases (tags).
func (s *UpdateService) GetReleases() ([]Release, error) {
	s.runGit("fetch", "--all", "--tags")

	// Get all tags
	output, err := s.runGit("tag", "-l", "--sort=-v:refname")
	if err != nil {
		return nil, err
	}

	currentTag, _ := s.runGit("describe", "--tags", "--exact-match", "HEAD")
	if strings.Contains(currentTag, "fatal") {
		currentTag = ""
	}

	var releases []Release
	for _, tag := range strings.Split(output, "\n") {
		tag = strings.TrimSpace(tag)
		if tag == "" {
			continue
		}

		// Get commit info for tag
		hash, _ := s.runGit("rev-parse", "--short", tag)
		message, _ := s.runGit("log", "-1", "--format=%s", tag)
		date, _ := s.runGit("log", "-1", "--format=%ai", tag)

		releases = append(releases, Release{
			Tag:        tag,
			CommitHash: hash,
			Message:    message,
			Date:       date,
			IsCurrent:  tag == currentTag,
		})
	}

	return releases, nil
}

// GetChangelog returns commits between two versions.
func (s *UpdateService) GetChangelog(from, to string, count int) ([]map[string]string, error) {
	if count <= 0 {
		count = 20
	}

	var rangeSpec string
	if from != "" && to != "" {
		rangeSpec = fmt.Sprintf("%s..%s", from, to)
	} else {
		rangeSpec = fmt.Sprintf("-%d", count)
	}

	output, err := s.runGit("log", "--oneline", "--format=%h|%s|%ai", rangeSpec)
	if err != nil {
		return nil, err
	}

	var entries []map[string]string
	for _, line := range strings.Split(output, "\n") {
		parts := strings.SplitN(line, "|", 3)
		if len(parts) == 3 {
			entries = append(entries, map[string]string{
				"hash":    parts[0],
				"message": parts[1],
				"date":    parts[2],
			})
		}
	}

	return entries, nil
}

// UpdateToTag updates to a specific tag version.
func (s *UpdateService) UpdateToTag(tag string) (*UpdateResult, error) {
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
			{Name: "切换版本", Status: "pending"},
			{Name: "检查数据库迁移", Status: "pending"},
			{Name: "构建镜像", Status: "pending"},
			{Name: "重启服务", Status: "pending"},
			{Name: "验证部署", Status: "pending"},
		},
	}

	// Step 1: Backup
	result.Steps[0].Status = "running"
	backupFile := fmt.Sprintf("/tmp/subforge-backup-%s.tar.gz", time.Now().Format("20060102-150405"))
	_, err := s.runCommand("tar", "-czf", backupFile, ".env", "nginx/")
	if err != nil {
		return s.failUpdate(result, 0, fmt.Sprintf("backup failed: %v", err))
	}
	result.Steps[0].Status = "success"
	result.Steps[0].Message = backupFile

	// Step 2: Fetch
	result.Steps[1].Status = "running"
	_, err = s.runGit("fetch", "--all", "--tags")
	if err != nil {
		return s.failUpdate(result, 1, fmt.Sprintf("fetch failed: %v", err))
	}
	result.Steps[1].Status = "success"

	// Step 3: Checkout tag
	result.Steps[2].Status = "running"
	_, err = s.runGit("checkout", tag)
	if err != nil {
		return s.failUpdate(result, 2, fmt.Sprintf("checkout failed: %v", err))
	}
	newVersion, _ := s.runGit("rev-parse", "--short", "HEAD")
	result.To = newVersion
	result.Steps[2].Status = "success"
	result.Steps[2].Message = fmt.Sprintf("Switched to %s", tag)

	// Step 4: Check migrations
	result.Steps[3].Status = "running"
	migrationOutput, _ := s.runGit("diff", "--name-only", currentVersion, newVersion, "--", "backend/migrations/")
	if migrationOutput != "" {
		result.Steps[3].Message = "New migrations: " + migrationOutput
	} else {
		result.Steps[3].Message = "No new migrations"
	}
	result.Steps[3].Status = "success"

	// Step 5: Build
	result.Steps[4].Status = "running"
	_, err = s.runCommand("docker", "compose", "build", "--no-cache")
	if err != nil {
		s.runGit("checkout", currentVersion) // rollback
		return s.failUpdate(result, 4, fmt.Sprintf("build failed: %v", err))
	}
	result.Steps[4].Status = "success"

	// Step 6: Restart
	result.Steps[5].Status = "running"
	s.runCommand("docker", "compose", "down")
	_, err = s.runCommand("docker", "compose", "up", "-d")
	if err != nil {
		return s.failUpdate(result, 5, fmt.Sprintf("restart failed: %v", err))
	}
	result.Steps[5].Status = "success"

	// Step 7: Verify
	result.Steps[6].Status = "running"
	time.Sleep(5 * time.Second)
	health, _ := s.runCommand("curl", "-s", "http://localhost:8080/api/health")
	if !strings.Contains(health, "ok") {
		log.Println("Health check failed, rolling back...")
		s.runGit("checkout", currentVersion)
		s.runCommand("docker", "compose", "down")
		s.runCommand("docker", "compose", "up", "-d", "--build")
		return s.failUpdate(result, 6, "health check failed, rolled back")
	}
	result.Steps[6].Status = "success"
	result.Steps[6].Message = "health check passed"

	result.Success = true
	s.lastResult = result
	return result, nil
}

// UpdateToLatest updates to the latest tag or main branch.
func (s *UpdateService) UpdateToLatest() (*UpdateResult, error) {
	s.runGit("fetch", "--all", "--tags")

	// Try latest tag first
	latestTag, _ := s.runGit("describe", "--tags", "--abbrev=0", "origin/main")
	if !strings.Contains(latestTag, "fatal") && latestTag != "" {
		return s.UpdateToTag(latestTag)
	}

	// Fallback to main branch
	return s.UpdateToBranch("main")
}

// UpdateToBranch updates to the latest commit on a branch.
func (s *UpdateService) UpdateToBranch(branch string) (*UpdateResult, error) {
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

	// Step 1: Backup
	result.Steps[0].Status = "running"
	backupFile := fmt.Sprintf("/tmp/subforge-backup-%s.tar.gz", time.Now().Format("20060102-150405"))
	s.runCommand("tar", "-czf", backupFile, ".env", "nginx/")
	result.Steps[0].Status = "success"
	result.Steps[0].Message = backupFile

	// Step 2: Pull
	result.Steps[1].Status = "running"
	_, err := s.runGit("pull", "origin", branch)
	if err != nil {
		return s.failUpdate(result, 1, fmt.Sprintf("pull failed: %v", err))
	}
	newVersion, _ := s.runGit("rev-parse", "--short", "HEAD")
	result.To = newVersion
	result.Steps[1].Status = "success"

	// Step 3: Check migrations
	result.Steps[2].Status = "running"
	migrationOutput, _ := s.runGit("diff", "--name-only", currentVersion, newVersion, "--", "backend/migrations/")
	if migrationOutput != "" {
		result.Steps[2].Message = "New migrations: " + migrationOutput
	} else {
		result.Steps[2].Message = "No new migrations"
	}
	result.Steps[2].Status = "success"

	// Step 4: Build
	result.Steps[3].Status = "running"
	_, err = s.runCommand("docker", "compose", "build", "--no-cache")
	if err != nil {
		s.runGit("checkout", currentVersion)
		return s.failUpdate(result, 3, fmt.Sprintf("build failed: %v", err))
	}
	result.Steps[3].Status = "success"

	// Step 5: Restart
	result.Steps[4].Status = "running"
	s.runCommand("docker", "compose", "down")
	_, err = s.runCommand("docker", "compose", "up", "-d")
	if err != nil {
		return s.failUpdate(result, 4, fmt.Sprintf("restart failed: %v", err))
	}
	result.Steps[4].Status = "success"

	// Step 6: Verify
	result.Steps[5].Status = "running"
	time.Sleep(5 * time.Second)
	health, _ := s.runCommand("curl", "-s", "http://localhost:8080/api/health")
	if !strings.Contains(health, "ok") {
		s.runGit("checkout", currentVersion)
		s.runCommand("docker", "compose", "down")
		s.runCommand("docker", "compose", "up", "-d", "--build")
		return s.failUpdate(result, 5, "health check failed, rolled back")
	}
	result.Steps[5].Status = "success"
	result.Steps[5].Message = "health check passed"

	result.Success = true
	s.lastResult = result
	return result, nil
}

func (s *UpdateService) failUpdate(result *UpdateResult, step int, msg string) (*UpdateResult, error) {
	result.Steps[step].Status = "failed"
	result.Steps[step].Message = msg
	result.Error = msg
	s.lastResult = result
	return result, fmt.Errorf(msg)
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
func (s *UpdateService) Rollback(target string) (*UpdateResult, error) {
	// Check if target is a tag
	isTag := false
	tags, _ := s.runGit("tag", "-l", target)
	if strings.TrimSpace(tags) == target {
		isTag = true
	}

	if isTag {
		return s.UpdateToTag(target)
	}
	return s.UpdateToBranch(target)
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
