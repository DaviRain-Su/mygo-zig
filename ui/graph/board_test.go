package graph

import "testing"

func TestDeleteSelectionRemovesEdges(t *testing.T) {
	b := &Board{
		Nodes: []Node{
			{ID: "a", X: 0, Y: 0, W: 100, H: 80, Ports: []Port{{ID: "out", Side: Right}}},
			{ID: "b", X: 200, Y: 0, W: 100, H: 80, Ports: []Port{{ID: "in", Side: Left}}},
		},
		Edges: []Edge{
			{ID: "e1", Source: "a", SourcePort: "out", Target: "b", TargetPort: "in"},
		},
		Selection: []string{"a"},
	}
	if !b.deleteSelection() {
		t.Fatal("expected delete")
	}
	if len(b.Nodes) != 1 || b.Nodes[0].ID != "b" {
		t.Fatalf("nodes=%v", b.Nodes)
	}
	if len(b.Edges) != 0 {
		t.Fatalf("edges left: %v", b.Edges)
	}
	if !b.CanUndo() {
		t.Fatal("delete should push undo")
	}
	b.Undo()
	if len(b.Nodes) != 2 || len(b.Edges) != 1 {
		t.Fatalf("undo failed nodes=%d edges=%d", len(b.Nodes), len(b.Edges))
	}
}

func TestHitPort(t *testing.T) {
	b := &Board{
		Nodes: []Node{
			{ID: "a", X: 0, Y: 0, W: 100, H: 80, Ports: []Port{{ID: "out", Side: Right, At: 0.5}}},
		},
		Camera: Camera{Zoom: 1},
	}
	nID, pID := b.hitPort(100, 40, 1)
	if nID != "a" || pID != "out" {
		t.Fatalf("hit %q/%q", nID, pID)
	}
}

func TestMarqueeSelectsIntersecting(t *testing.T) {
	b := &Board{
		Nodes: []Node{
			{ID: "a", X: 0, Y: 0, W: 50, H: 50},
			{ID: "b", X: 100, Y: 100, W: 50, H: 50},
		},
		marquee: true, marqueeX0: -10, marqueeY0: -10, marqueeX1: 40, marqueeY1: 40,
	}
	b.applyMarquee()
	if len(b.Selection) != 1 || b.Selection[0] != "a" {
		t.Fatalf("selection=%v", b.Selection)
	}
}

func TestOrthogonalDistance(t *testing.T) {
	pts := orthogonalPoints(0, 0, 100, 0, Right, Left)
	if len(pts) < 4 {
		t.Fatalf("pts=%v", pts)
	}
	d := distToEdge(EdgeOrthogonal, 50, 0, 0, 0, 100, 0, Right, Left)
	if d > 1 {
		t.Fatalf("expected on-path distance, got %v", d)
	}
}

func TestDuplicateAndUndo(t *testing.T) {
	b := &Board{
		Nodes:     []Node{{ID: "a", Title: "A", X: 0, Y: 0, W: 80, H: 60}},
		Selection: []string{"a"},
	}
	if !b.duplicateSelection() {
		t.Fatal("dup")
	}
	if len(b.Nodes) != 2 {
		t.Fatalf("nodes=%d", len(b.Nodes))
	}
	b.Undo()
	if len(b.Nodes) != 1 {
		t.Fatalf("undo nodes=%d", len(b.Nodes))
	}
	b.Redo()
	if len(b.Nodes) != 2 {
		t.Fatalf("redo nodes=%d", len(b.Nodes))
	}
}
