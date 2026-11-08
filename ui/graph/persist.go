package graph

import (
	"encoding/json"
	"fmt"

	"github.com/egoist/mygo/ui"
)

// Document is the JSON-serializable board state. Node.Content callbacks
// are not persisted; rebind them after Load with BindNodeContent.
type Document struct {
	Camera    Camera    `json:"camera"`
	EdgeStyle EdgeStyle `json:"edgeStyle"`
	Nodes     []NodeDoc `json:"nodes"`
	Edges     []Edge    `json:"edges"`
	Groups    []Group   `json:"groups,omitempty"`
}

// NodeDoc is a Node without its Content callback.
type NodeDoc struct {
	ID    string  `json:"id"`
	Title string  `json:"title"`
	X     float32 `json:"x"`
	Y     float32 `json:"y"`
	W     float32 `json:"w"`
	H     float32 `json:"h"`
	Ports []Port  `json:"ports,omitempty"`
}

// Export returns the board as a Document (no Content funcs).
func (b *Board) Export() Document {
	nodes := make([]NodeDoc, len(b.Nodes))
	for i, n := range b.Nodes {
		nodes[i] = NodeDoc{
			ID: n.ID, Title: n.Title,
			X: n.X, Y: n.Y, W: n.W, H: n.H,
			Ports: append([]Port(nil), n.Ports...),
		}
	}
	groups := make([]Group, len(b.Groups))
	for i, g := range b.Groups {
		groups[i] = Group{
			ID: g.ID, Title: g.Title,
			Members: append([]string(nil), g.Members...),
		}
	}
	return Document{
		Camera:    b.Camera,
		EdgeStyle: b.EdgeStyle,
		Nodes:     nodes,
		Edges:     append([]Edge(nil), b.Edges...),
		Groups:    groups,
	}
}

// MarshalJSON encodes the board document as JSON.
func (b *Board) MarshalJSON() ([]byte, error) {
	return json.MarshalIndent(b.Export(), "", "  ")
}

// Load replaces document state from d. Content callbacks are cleared;
// call BindNodeContent afterwards. Records undo of the previous state.
func (b *Board) Load(d Document) {
	b.pushUndo()
	nodes := make([]Node, len(d.Nodes))
	for i, n := range d.Nodes {
		nodes[i] = Node{
			ID: n.ID, Title: n.Title,
			X: n.X, Y: n.Y, W: n.W, H: n.H,
			Ports: append([]Port(nil), n.Ports...),
		}
	}
	groups := make([]Group, len(d.Groups))
	for i, g := range d.Groups {
		groups[i] = Group{
			ID: g.ID, Title: g.Title,
			Members: append([]string(nil), g.Members...),
		}
	}
	b.Nodes = nodes
	b.Edges = append([]Edge(nil), d.Edges...)
	b.Groups = groups
	b.Camera = d.Camera
	if b.Camera.Zoom == 0 {
		b.Camera.Zoom = 1
	}
	b.EdgeStyle = d.EdgeStyle
	b.Selection = nil
	b.ensureEdgeSeq()
	b.ensureNodeSeq()
	b.ensureGroupSeq()
	if b.OnSelection != nil {
		b.OnSelection(nil)
	}
	if b.OnViewport != nil {
		b.OnViewport(b.Camera)
	}
}

// UnmarshalJSON loads a Document from JSON onto the board.
func (b *Board) UnmarshalJSON(data []byte) error {
	var d Document
	if err := json.Unmarshal(data, &d); err != nil {
		return fmt.Errorf("graph: load: %w", err)
	}
	b.Load(d)
	return nil
}

// BindNodeContent sets Content callbacks keyed by node id after Load.
func (b *Board) BindNodeContent(byID map[string]func(*ui.Context)) {
	for i := range b.Nodes {
		if fn, ok := byID[b.Nodes[i].ID]; ok {
			b.Nodes[i].Content = fn
		}
	}
}
