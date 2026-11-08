package graph

import (
	"encoding/json"
	"testing"

	"github.com/egoist/mygo/ui"
)

func TestExportImportRoundTrip(t *testing.T) {
	b := &Board{
		Camera:    Camera{X: 1, Y: 2, Zoom: 1.5},
		EdgeStyle: EdgeOrthogonal,
		Nodes: []Node{
			{ID: "a", Title: "A", X: 10, Y: 20, W: 100, H: 80, Ports: []Port{{ID: "out", Side: Right}}},
			{ID: "b", Title: "B", X: 200, Y: 20, W: 100, H: 80, Ports: []Port{{ID: "in", Side: Left}}},
		},
		Edges:  []Edge{{ID: "e1", Source: "a", SourcePort: "out", Target: "b", TargetPort: "in", Label: "link"}},
		Groups: []Group{{ID: "g1", Title: "G", Members: []string{"a", "b"}}},
	}
	raw, err := b.MarshalJSON()
	if err != nil {
		t.Fatal(err)
	}
	var doc Document
	if err := json.Unmarshal(raw, &doc); err != nil {
		t.Fatal(err)
	}
	if doc.Nodes[0].Title != "A" || doc.Edges[0].Label != "link" || len(doc.Groups) != 1 {
		t.Fatalf("doc=%+v", doc)
	}
	b2 := &Board{}
	b2.Load(doc)
	if len(b2.Nodes) != 2 || b2.Edges[0].Label != "link" || b2.Groups[0].Title != "G" {
		t.Fatalf("loaded=%+v", b2)
	}
	if b2.Camera.Zoom != 1.5 {
		t.Fatalf("zoom=%v", b2.Camera.Zoom)
	}
}

func TestGroupSelectionAndUngroup(t *testing.T) {
	b := &Board{
		Nodes: []Node{
			{ID: "a", X: 0, Y: 0, W: 40, H: 40},
			{ID: "b", X: 60, Y: 0, W: 40, H: 40},
		},
		Selection: []string{"a", "b"},
	}
	id := b.GroupSelection()
	if id == "" || len(b.Groups) != 1 {
		t.Fatalf("group id=%q groups=%v", id, b.Groups)
	}
	if !b.UngroupSelection() {
		t.Fatal("ungroup")
	}
	if len(b.Groups) != 0 {
		t.Fatalf("groups left %v", b.Groups)
	}
}

func TestAutoLayoutOrdersByEdges(t *testing.T) {
	b := &Board{
		Nodes: []Node{
			{ID: "c", W: 50, H: 40},
			{ID: "a", W: 50, H: 40},
			{ID: "b", W: 50, H: 40},
		},
		Edges: []Edge{
			{Source: "a", Target: "b"},
			{Source: "b", Target: "c"},
		},
	}
	b.AutoLayout(LayoutOptions{RankSep: 20, NodeSep: 10})
	a, bb, c := b.NodeByID("a"), b.NodeByID("b"), b.NodeByID("c")
	if !(a.X < bb.X && bb.X < c.X) {
		t.Fatalf("order a=%v b=%v c=%v", a.X, bb.X, c.X)
	}
}

func TestNestedGroupPersistAndFlags(t *testing.T) {
	b := &Board{
		SnapGrid: 24,
		Nodes: []Node{
			{ID: "a", Title: "A", X: 0, Y: 0, W: 40, H: 40, Locked: true, Color: ui.Color{R: 10, G: 20, B: 30, A: 255}},
			{ID: "b", Title: "B", X: 80, Y: 0, W: 40, H: 40},
			{ID: "c", Title: "C", X: 160, Y: 0, W: 40, H: 40},
		},
		Groups: []Group{
			{ID: "g1", Title: "Outer", Members: []string{"a", "b"}},
			{ID: "g2", Title: "Inner", Members: []string{"c"}, Parent: "g1"},
		},
	}
	raw, err := b.MarshalJSON()
	if err != nil {
		t.Fatal(err)
	}
	b2 := &Board{}
	if err := b2.UnmarshalJSON(raw); err != nil {
		t.Fatal(err)
	}
	if b2.SnapGrid != 24 {
		t.Fatalf("snap=%v", b2.SnapGrid)
	}
	if !b2.NodeByID("a").Locked || b2.NodeByID("a").Color.R != 10 {
		t.Fatalf("a=%+v", b2.NodeByID("a"))
	}
	g2 := b2.GroupByID("g2")
	if g2 == nil || g2.Parent != "g1" {
		t.Fatalf("g2=%+v", g2)
	}
}
