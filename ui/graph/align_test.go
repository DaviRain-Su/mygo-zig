package graph

import "testing"

func TestAlignLeft(t *testing.T) {
	b := &Board{
		Nodes: []Node{
			{ID: "a", X: 40, Y: 0, W: 20, H: 20},
			{ID: "b", X: 10, Y: 40, W: 20, H: 20},
		},
		Selection: []string{"a", "b"},
	}
	if !b.AlignSelection(AlignLeft) {
		t.Fatal("align")
	}
	if b.NodeByID("a").X != 10 || b.NodeByID("b").X != 10 {
		t.Fatalf("a=%v b=%v", b.NodeByID("a").X, b.NodeByID("b").X)
	}
}

func TestSnapOnNudge(t *testing.T) {
	b := &Board{
		SnapGrid:  16,
		Nodes:     []Node{{ID: "a", X: 0, Y: 0, W: 10, H: 10}},
		Selection: []string{"a"},
	}
	b.nudgeSelection(10, 0)
	if b.NodeByID("a").X != 16 {
		t.Fatalf("x=%v", b.NodeByID("a").X)
	}
}

func TestNestedGroupBounds(t *testing.T) {
	b := &Board{
		Nodes: []Node{
			{ID: "a", X: 0, Y: 0, W: 40, H: 40},
			{ID: "b", X: 100, Y: 0, W: 40, H: 40},
			{ID: "c", X: 200, Y: 0, W: 40, H: 40},
		},
		Groups: []Group{
			{ID: "g1", Members: []string{"a", "b"}},
			{ID: "g2", Members: []string{"c"}, Parent: "g1"},
		},
	}
	r, ok := b.groupBounds(*b.GroupByID("g1"))
	if !ok || r.W < 200 {
		t.Fatalf("bounds=%+v ok=%v", r, ok)
	}
}

func TestRouteAvoidsObstacle(t *testing.T) {
	// Default mid path through obstacle should detour.
	obs := []obstacle{{x0: 40, y0: -10, x1: 60, y1: 10}}
	pts := orthogonalPointsAvoid(0, 0, 100, 0, Right, Left, obs)
	if pathHits(pts, obs) {
		t.Fatalf("still hits: %v", pts)
	}
}

func TestDistributeH(t *testing.T) {
	b := &Board{
		Nodes: []Node{
			{ID: "a", X: 0, Y: 0, W: 10, H: 10},
			{ID: "b", X: 20, Y: 0, W: 10, H: 10},
			{ID: "c", X: 90, Y: 0, W: 10, H: 10},
		},
		Selection: []string{"a", "b", "c"},
	}
	if !b.DistributeSelection(true) {
		t.Fatal("dist")
	}
	if b.NodeByID("b").X != 45 {
		t.Fatalf("b.x=%v want 45", b.NodeByID("b").X)
	}
}

func TestPolylineMidpoint(t *testing.T) {
	pts := [][2]float32{{0, 0}, {10, 0}, {10, 10}}
	x, y := polylineMidpoint(pts)
	// total len 20, midpoint at (10,0)
	if x != 10 || y != 0 {
		t.Fatalf("mid=%v,%v", x, y)
	}
}
