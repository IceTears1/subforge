package service

import (
	"fmt"
	"log"
	"os/exec"
	"strings"
	"time"
)

// UpdateService handles version checking and updating.
type UpdateService struct {
	installDir string
}

func NewUpdateService(installDir string) *UpdateService {
	if installDir == "" {
		installDir = "/opt/subforge"
	}
	return &UpdateService{installDir: installDir}
}

type VersionInfo struct {
	Current     string    `json:"current"`
	Latest      string    `json:"latest"`
	HasUpdate   bool      `json:"has_update"`
	Changelog   string    `json:"changelog"`
	LastCheck   time.Time `json:"last_check"`
	UpdateLog   []UpdateLogEntry `json:"update_log,omitempty"`
}

type UpdateLogEntry struct {
	From      string    `json:"from"`
	To        string    `json:"to"`
	Timestamp time.Time `json:"timestamp"`
	Success   bool      `json:"success"`
	Message   string    `json:"message"`
}

// GetVersion returns current and latest version info.
func (s *UpdateService) GetVersion() (*VersionInfo, error) {
	// Get current version
	current, err := s.runGit("rev-parse", "--short", "HEAD")
	if err != nil {
		return nil, fmt.Errorf("get current version: %w", err)
	}

	// Fetch latest
	s.runGit("fetch", "origin", "main")

	// Get latest version
	latest, err := s.runGit("rev-parse", "--short", "origin/main")
	if err != nil {
		return nil, fmt.Errorf("get latest version: %w", err)
	}

	// Get changelog (commits between current and latest)
	changelog := ""
	if current != latest {
		log, err := s.runGit("log", "--oneline", fmt.Sprintf("%s..%s", current, latest))
		if err == nil {
			changelog = log
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

// GetChangelog returns the full changelog.
func (s *UpdateService) GetChangelog() (string, error) {
	return s.runGit("log", "--oneline", "-20")
}

// Update performs the update.
func (s *UpdateService) Update() (*UpdateLogEntry, error) {
	// Get current version before update
	oldVersion, _ := s.runGit("rev-parse", "--short", "HEAD")

	// Pull latest
	output, err := s.runGit("pull", "origin", "main")
	if err != nil {
		return &UpdateLogEntry{
			From:      oldVersion,
			To:        oldVersion,
			Timestamp: time.Now(),
			Success:   false,
			Message:   fmt.Sprintf("git pull failed: %v", err),
		}, err
	}

	// Get new version
	newVersion, _ := s.runGit("rev-parse", "--short", "HEAD")

	// Rebuild containers
	log.Println("Rebuilding containers...")
	buildOutput, err := s.runCommand("docker", "compose", "build", "--no-cache")
	if err != nil {
		return &UpdateLogEntry{
			From:      oldVersion,
			To:        newVersion,
			Timestamp: time.Now(),
			Success:   false,
			Message:   fmt.Sprintf("build failed: %v\n%s", err, buildOutput),
		}, err
	}

	// Restart services
	log.Println("Restarting services...")
	restartOutput, err := s.runCommand("docker", "compose", "down")
	if err != nil {
		return &UpdateLogEntry{
			From:      oldVersion,
			To:        newVersion,
			Timestamp: time.Now(),
			Success:   false,
			Message:   fmt.Sprintf("restart failed: %v\n%s", err, restartOutput),
		}, err
	}

	_, err = s.runCommand("docker", "compose", "up", "-d")
	if err != nil {
		return &UpdateLogEntry{
			From:      oldVersion,
			To:        newVersion,
			Timestamp: time.Now(),
			Success:   false,
			Message:   fmt.Sprintf("start failed: %v", err),
		}, err
	}

	return &UpdateLogEntry{
		From:      oldVersion,
		To:        newVersion,
		Timestamp: time.Now(),
		Success:   true,
		Message:   fmt.Sprintf("Updated successfully\n%s", output),
	}, nil
}

// Rollback rolls back to a specific version.
func (s *UpdateService) Rollback(targetVersion string) (*UpdateLogEntry, error) {
	currentVersion, _ := s.runGit("rev-parse", "--short", "HEAD")

	// Checkout target version
	_, err := s.runGit("checkout", targetVersion)
	if err != nil {
		return &UpdateLogEntry{
			From:      currentVersion,
			To:        currentVersion,
			Timestamp: time.Now(),
			Success:   false,
			Message:   fmt.Sprintf("checkout failed: %v", err),
		}, err
	}

	// Rebuild
	_, err = s.runCommand("docker", "compose", "down")
	if err != nil {
		return &UpdateLogEntry{
			From:      currentVersion,
			To:        targetVersion,
			Timestamp: time.Now(),
			Success:   false,
			Message:   fmt.Sprintf("stop failed: %v", err),
		}, err
	}

	_, err = s.runCommand("docker", "compose", "up", "-d", "--build")
	if err != nil {
		return &UpdateLogEntry{
			From:      currentVersion,
			To:        targetVersion,
			Timestamp: time.Now(),
			Success:   false,
			Message:   fmt.Sprintf("build failed: %v", err),
		}, err
	}

	return &UpdateLogEntry{
		From:      currentVersion,
		To:        targetVersion,
		Timestamp: time.Now(),
		Success:   true,
		Message:   "Rollback successful",
	}, nil
}

// GetRecentVersions returns recent git commits.
func (s *UpdateService) GetRecentVersions(count int) ([]map[string]string, error) {
	if count <= 0 {
		count = 10
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
