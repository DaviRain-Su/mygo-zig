package graph

import "testing"

func TestCopyPaste(t *testing.T) {
	b := &Board{
		Nodes: []Node{
			{ID: "a", X: 0, Y: 0, W: 40, H: 40, Ports: []Port{{ID: "out", Side: Right}}},
			{ID: "b", X: 80, Y: 0, W: 40, H: 40, Ports: []Port{{ID: "in", Side: Left}}},
		},
		Edges:     []Edge{{ID: "e1", Source: "a", SourcePort: "out", Target: "b", TargetPort: "in", Label: "x"}},
		Selection: []string{"a", "b"},
	}
	if !b.CopySelection() {
		t.Fatal("copy")
	}
	if !b.PasteClipboard() {
		t.Fatal("paste")
	}
	if len(b.Nodes) != 4 {
		t.Fatalf("nodes=%d", len(b.Nodes))
	}
	if len(b.Edges) != 2 {
		t.Fatalf("edges=%d", len(b.Edges))
	}
}
