package graph

import (
	"math"

	"github.com/egoist/mygo/ui"
)

// LayoutOptions control AutoLayout.
type LayoutOptions struct {
	// RankSep is the horizontal gap between layers (default 80).
	RankSep float32
	// NodeSep is the vertical gap between nodes in a layer (default 24).
	NodeSep          float32
	OriginX, OriginY float32
}

func (o LayoutOptions) withDefaults() LayoutOptions {
	if o.RankSep == 0 {
		o.RankSep = 80
	}
	if o.NodeSep == 0 {
		o.NodeSep = 24
	}
	return o
}

// AutoLayout places nodes in layers left-to-right from edge topology
// (Sugiyama-lite). Records undo.
func (b *Board) AutoLayout(opts LayoutOptions) {
	if len(b.Nodes) == 0 {
		return
	}
	opts = opts.withDefaults()
	b.pushUndo()

	n := len(b.Nodes)
	index := map[string]int{}
	for i, node := range b.Nodes {
		index[node.ID] = i
	}
	inDeg := make([]int, n)
	out := make([][]int, n)
	for _, e := range b.Edges {
		s, sok := index[e.Source]
		t, tok := index[e.Target]
		if !sok || !tok || s == t {
			continue
		}
		out[s] = append(out[s], t)
		inDeg[t]++
	}

	rank := make([]int, n)
	for i := range rank {
		rank[i] = -1
	}
	var queue []int
	for i, d := range inDeg {
		if d == 0 {
			queue = append(queue, i)
			rank[i] = 0
		}
	}
	for head := 0; head < len(queue); head++ {
		u := queue[head]
		for _, v := range out[u] {
			inDeg[v]--
			if inDeg[v] == 0 && rank[v] < 0 {
				rank[v] = rank[u] + 1
				queue = append(queue, v)
			}
		}
	}
	maxRank := 0
	for i, r := range rank {
		if r < 0 {
			// Remaining cycle members: place after known ranks.
			rank[i] = maxRank + 1
		}
		if rank[i] > maxRank {
			maxRank = rank[i]
		}
	}

	layers := make([][]int, maxRank+1)
	for i, r := range rank {
		layers[r] = append(layers[r], i)
	}

	x := opts.OriginX
	for _, layer := range layers {
		var colW float32
		y := opts.OriginY
		for _, i := range layer {
			node := &b.Nodes[i]
			node.X, node.Y = x, y
			if node.W > colW {
				colW = node.W
			}
			y += node.H + opts.NodeSep
		}
		x += colW + opts.RankSep
	}
}

// FitCamera frames all content in the view rectangle.
func (b *Board) FitCamera(view ui.Rect, padding float32) {
	if padding == 0 {
		padding = 40
	}
	bounds := b.contentBounds()
	if bounds.W < 1 {
		bounds.W = 1
	}
	if bounds.H < 1 {
		bounds.H = 1
	}
	zx := (view.W - 2*padding) / bounds.W
	zy := (view.H - 2*padding) / bounds.H
	z := float32(math.Min(float64(zx), float64(zy)))
	if z < 0.1 {
		z = 0.1
	}
	if z > 4 {
		z = 4
	}
	b.Camera.Zoom = z
	b.Camera.X = bounds.X + bounds.W/2
	b.Camera.Y = bounds.Y + bounds.H/2
	b.emitViewport()
}

// FitSelection frames the current selection (or all content if empty).
func (b *Board) FitSelection(view ui.Rect, padding float32) {
	nodes := b.selectedNodes()
	if len(nodes) == 0 {
		b.FitCamera(view, padding)
		return
	}
	if padding == 0 {
		padding = 40
	}
	minX, minY := nodes[0].X, nodes[0].Y
	maxX, maxY := minX+nodes[0].W, minY+nodes[0].H
	for _, n := range nodes[1:] {
		if n.X < minX {
			minX = n.X
		}
		if n.Y < minY {
			minY = n.Y
		}
		if n.X+n.W > maxX {
			maxX = n.X + n.W
		}
		if n.Y+n.H > maxY {
			maxY = n.Y + n.H
		}
	}
	bounds := ui.Rect{X: minX, Y: minY, W: maxX - minX, H: maxY - minY}
	if bounds.W < 1 {
		bounds.W = 1
	}
	if bounds.H < 1 {
		bounds.H = 1
	}
	zx := (view.W - 2*padding) / bounds.W
	zy := (view.H - 2*padding) / bounds.H
	z := float32(math.Min(float64(zx), float64(zy)))
	if z < 0.1 {
		z = 0.1
	}
	if z > 4 {
		z = 4
	}
	b.Camera.Zoom = z
	b.Camera.X = bounds.X + bounds.W/2
	b.Camera.Y = bounds.Y + bounds.H/2
	b.emitViewport()
}

// FitContent frames the whole board in the view built last.
func (b *Board) FitContent() {
	if b.viewR.W > 0 {
		b.FitCamera(b.viewR, 48)
	}
}
