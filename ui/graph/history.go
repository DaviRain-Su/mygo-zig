package graph

import (
	"slices"

	"github.com/egoist/mygo/ui"
)

// snapshot is a deep-enough copy of editable board document state for undo.
type snapshot struct {
	nodes     []Node
	edges     []Edge
	selection []string
	cam       Camera
	edgeSeq   int
}

func (b *Board) capture() snapshot {
	nodes := make([]Node, len(b.Nodes))
	for i, n := range b.Nodes {
		nodes[i] = n
		if len(n.Ports) > 0 {
			nodes[i].Ports = append([]Port(nil), n.Ports...)
		}
		// Content callbacks are shared; undo restores layout/ids only.
	}
	return snapshot{
		nodes:     nodes,
		edges:     append([]Edge(nil), b.Edges...),
		selection: append([]string(nil), b.Selection...),
		cam:       b.Camera,
		edgeSeq:   b.edgeSeq,
	}
}

func (b *Board) restore(s snapshot) {
	oldContent := make(map[string]func(*ui.Context), len(b.Nodes))
	for i := range b.Nodes {
		oldContent[b.Nodes[i].ID] = b.Nodes[i].Content
	}
	b.Nodes = s.nodes
	for i := range b.Nodes {
		if fn, ok := oldContent[b.Nodes[i].ID]; ok {
			b.Nodes[i].Content = fn
		}
	}
	b.Edges = s.edges
	b.Selection = append([]string(nil), s.selection...)
	b.Camera = s.cam
	b.edgeSeq = s.edgeSeq
	if b.OnSelection != nil {
		b.OnSelection(b.Selection)
	}
	if b.OnViewport != nil {
		b.OnViewport(b.Camera)
	}
}

func (b *Board) pushUndo() {
	s := b.capture()
	b.undo = append(b.undo, s)
	if len(b.undo) > 64 {
		b.undo = slices.Clone(b.undo[len(b.undo)-64:])
	}
	b.redo = b.redo[:0]
}

// Undo restores the previous document snapshot. Reports whether anything changed.
func (b *Board) Undo() bool {
	if len(b.undo) == 0 {
		return false
	}
	cur := b.capture()
	b.redo = append(b.redo, cur)
	s := b.undo[len(b.undo)-1]
	b.undo = b.undo[:len(b.undo)-1]
	b.restore(s)
	return true
}

// Redo reapplies a snapshot undone earlier.
func (b *Board) Redo() bool {
	if len(b.redo) == 0 {
		return false
	}
	cur := b.capture()
	b.undo = append(b.undo, cur)
	s := b.redo[len(b.redo)-1]
	b.redo = b.redo[:len(b.redo)-1]
	b.restore(s)
	return true
}

// CanUndo reports whether Undo would change the board.
func (b *Board) CanUndo() bool { return len(b.undo) > 0 }

// CanRedo reports whether Redo would change the board.
func (b *Board) CanRedo() bool { return len(b.redo) > 0 }
