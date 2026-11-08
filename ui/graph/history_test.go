package graph

import (
	"testing"

	"github.com/egoist/mygo/ui"
)

func TestUndoRestoresLockColorSnapStyleAndParent(t *testing.T) {
	b := &Board{
		SnapGrid:  16,
		EdgeStyle: EdgeBezier,
		Nodes: []Node{
			{ID: "a", X: 0, Y: 0, W: 40, H: 40, Locked: false, Color: ui.Color{R: 1, A: 255}},
			{ID: "b", X: 80, Y: 0, W: 40, H: 40},
			{ID: "c", X: 160, Y: 0, W: 40, H: 40},
		},
		Groups: []Group{
			{ID: "g1", Members: []string{"a", "b"}},
		},
		Edges: []Edge{{ID: "e1", Source: "a", Target: "b", Label: "old"}},
	}
	b.pushUndo()
	b.SnapGrid = 0
	b.EdgeStyle = EdgeOrthogonal
	b.NodeByID("a").Locked = true
	b.NodeByID("a").Color = ui.Color{}
	b.NodeByID("a").X = 99
	b.Edges[0].Label = "new"
	b.Groups = append(b.Groups, Group{ID: "g2", Members: []string{"c"}, Parent: "g1"})
	if !b.Undo() {
		t.Fatal("undo")
	}
	if b.SnapGrid != 16 || b.EdgeStyle != EdgeBezier {
		t.Fatalf("snap/style %v %v", b.SnapGrid, b.EdgeStyle)
	}
	a := b.NodeByID("a")
	if a.Locked || a.X != 0 || a.Color.A != 255 {
		t.Fatalf("node a=%+v", a)
	}
	if b.Edges[0].Label != "old" {
		t.Fatalf("label=%q", b.Edges[0].Label)
	}
	if len(b.Groups) != 1 || b.Groups[0].Parent != "" {
		t.Fatalf("groups=%+v", b.Groups)
	}
}

func TestLockedNodeNotNudged(t *testing.T) {
	b := &Board{
		Nodes:     []Node{{ID: "a", X: 0, Y: 0, W: 10, H: 10, Locked: true}},
		Selection: []string{"a"},
	}
	if b.nudgeSelection(10, 0) {
		t.Fatal("expected no move for locked node")
	}
	if b.NodeByID("a").X != 0 {
		t.Fatalf("locked moved to %v", b.NodeByID("a").X)
	}
}
