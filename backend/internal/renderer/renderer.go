package renderer

import (
	"fmt"
	"sort"
	"subforge/internal/core"
)

// Renderer defines the interface for output format renderers.
type Renderer interface {
	Name() string
	Render(nodes []core.ProxyNode) (string, error)
}

var registry map[string]Renderer

func init() {
	registry = make(map[string]Renderer)
	Register(&ClashRenderer{})
	Register(&SingBoxRenderer{})
	Register(&SurgeRenderer{})
	Register(&LoonRenderer{})
	Register(&QXRenderer{})
	Register(&Base64Renderer{})
}

func Register(r Renderer) {
	registry[r.Name()] = r
}

func Get(format string) (Renderer, error) {
	r, ok := registry[format]
	if !ok {
		return nil, fmt.Errorf("unsupported format: %s", format)
	}
	return r, nil
}

func ListFormats() []string {
	var formats []string
	for k := range registry {
		formats = append(formats, k)
	}
	sort.Strings(formats)
	return formats
}
