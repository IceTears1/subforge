package service

import (
	"io"
	"time"

	"subforge/internal/core"
	"subforge/internal/parser"
	"subforge/internal/renderer"
	"subforge/internal/smart"

	"subforge/internal/pkg/httputil"

	"gorm.io/gorm"
)

type ConvertService struct {
	db *gorm.DB
}

func NewConvertService(db *gorm.DB) *ConvertService {
	return &ConvertService{db: db}
}

type ConvertRequest struct {
	SourceURL   string   `json:"source_url"`
	Content     string   `json:"content"`
	Target      string   `json:"target" binding:"required"`
	Rename      bool     `json:"rename"`
	Dedup       bool     `json:"dedup"`
	Regions     []string `json:"regions"`
	Exclude     []string `json:"exclude"`
}

func (s *ConvertService) Convert(req ConvertRequest) (string, error) {
	var content string

	if req.SourceURL != "" {
		resp, err := httputil.SafeGet(req.SourceURL, 30*time.Second)
		if err != nil {
			return "", err
		}
		defer resp.Body.Close()
		body, err := io.ReadAll(resp.Body)
		if err != nil {
			return "", err
		}
		content = string(body)
	} else {
		content = req.Content
	}

	// Parse
	nodes, _, err := parser.ParseWithAutoDetect(content)
	if err != nil {
		return "", err
	}

	// Smart processing
	if req.Dedup {
		nodes = smart.Deduplicate(nodes)
	}
	if len(req.Exclude) > 0 {
		nodes = smart.FilterByKeyword(nodes, req.Exclude)
	}
	if req.Rename {
		nodes = smart.RenameByRegion(nodes)
	}
	if len(req.Regions) > 0 {
		nodes = smart.FilterByRegion(nodes, req.Regions)
	}

	// Render
	r, err := renderer.Get(req.Target)
	if err != nil {
		return "", err
	}
	return r.Render(nodes)
}

// DetectFormat detects the format of content or URL.
func (s *ConvertService) DetectFormat(source string) (string, int, error) {
	var content string
	if len(source) >= 4 && source[:4] == "http" {
		resp, err := httputil.SafeGet(source, 15*time.Second)
		if err != nil {
			return "", 0, err
		}
		defer resp.Body.Close()
		body, err := io.ReadAll(resp.Body)
		if err != nil {
			return "", 0, err
		}
		content = string(body)
	} else {
		content = source
	}

	nodes, format, err := parser.ParseWithAutoDetect(content)
	if err != nil {
		return "", 0, err
	}
	return format, len(nodes), nil
}
