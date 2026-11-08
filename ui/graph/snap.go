package graph

import "math"

// SnapGrid, when > 0, snaps node positions to that world-unit grid while
// dragging and after align/layout. 0 disables snapping.
func (b *Board) snapEnabled() bool {
	return b.SnapGrid > 0
}

func (b *Board) snap(v float32) float32 {
	g := b.SnapGrid
	if g <= 0 {
		return v
	}
	return float32(math.Round(float64(v/g))) * g
}

func (b *Board) snapNode(n *Node) {
	if !b.snapEnabled() || n == nil {
		return
	}
	n.X = b.snap(n.X)
	n.Y = b.snap(n.Y)
}

func (b *Board) snapSelection() {
	if !b.snapEnabled() {
		return
	}
	for _, id := range b.dragNodeIDs() {
		if n := b.NodeByID(id); n != nil {
			b.snapNode(n)
			if b.OnMove != nil {
				b.OnMove(n.ID, n.X, n.Y)
			}
		}
	}
}

// nudgeSelection moves selected nodes by dx,dy (world), with optional snap.
func (b *Board) nudgeSelection(dx, dy float32) bool {
	ids := b.dragNodeIDs()
	var movable []*Node
	for _, id := range ids {
		if n := b.NodeByID(id); n != nil && !n.Locked {
			movable = append(movable, n)
		}
	}
	if len(movable) == 0 {
		return false
	}
	b.pushUndo()
	for _, n := range movable {
		n.X += dx
		n.Y += dy
		b.snapNode(n)
		if b.OnMove != nil {
			b.OnMove(n.ID, n.X, n.Y)
		}
	}
	return true
}
