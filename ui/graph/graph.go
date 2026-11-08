// Package graph is an opt-in node canvas for native UI: an infinite 2D
// world with a camera, nodes that host arbitrary ui subtrees, ports and
// edges, plus pluggable tools (select/drag, pan, connect).
//
// It is a simplified React Flow for native MyGo UI — foundation for
// whiteboards, card boards and link diagrams — built on Absolute +
// Transform + Painter rather than a retained scene graph of its own.
//
//	board := &graph.Board{
//		Nodes: []graph.Node{
//			{ID: "a", X: 0, Y: 0, W: 180, H: 100, Title: "Note"},
//		},
//		Tool: graph.ToolSelect,
//	}
//	graph.View(c, board).Fill()
package graph

import (
	"math"
	"slices"

	"github.com/egoist/mygo/ui"
)

// Tool is the active interaction mode of a Board.
type Tool int

const (
	// ToolSelect clicks to select, drags nodes, marquee-selects on empty
	// canvas, and deletes the selection with Backspace/Delete.
	ToolSelect Tool = iota
	// ToolPan drags the camera; wheel still pans/zooms as on other tools.
	ToolPan
	// ToolConnect starts an edge from a port press and finishes on another.
	ToolConnect
)

// Side is where a port sits on its node.
type Side int

const (
	Left Side = iota
	Right
	Top
	Bottom
)

// Port is an anchor on a node for edges.
type Port struct {
	ID   string
	Side Side
	// At is 0..1 along the side (0.5 = middle).
	At float32
}

// Node is a free-positioned card in world space. Content, when set, builds
// the body under the title; otherwise only Title shows.
type Node struct {
	ID, Title string
	X, Y      float32
	W, H      float32
	Ports     []Port
	Content   func(c *ui.Context)
}

// Edge connects two ports. ID may be empty; the board assigns one on connect.
type Edge struct {
	ID                     string
	Source, Target         string // node ids
	SourcePort, TargetPort string
}

// Board is the document the canvas shows and edits.
type Board struct {
	Camera    Camera
	Tool      Tool
	EdgeStyle EdgeStyle
	Nodes     []Node
	Edges     []Edge

	Selection []string // node ids, or "edge:"+id

	// Minimap draws a corner overview when true.
	Minimap bool

	// Events (optional).
	OnSelection func(ids []string)
	OnMove      func(id string, x, y float32)
	OnConnect   func(e Edge)
	OnDelete    func(edgeIDs, nodeIDs []string)
	OnViewport  func(cam Camera)

	// interaction state (frame-local + gesture)
	panning    bool
	lastPanX   float32
	lastPanY   float32
	connecting bool
	connFromN  string
	connFromP  string
	connWX     float32
	connWY     float32
	edgeSeq    int
	nodeSeq    int
	viewR      ui.Rect

	marquee       bool
	marqueeX0     float32
	marqueeY0     float32
	marqueeX1     float32
	marqueeY1     float32
	marqueeAdditive bool

	draggingGroup bool
	dragMoved     bool
	dragOrigins   map[string][2]float32

	lastMods ui.Modifiers

	undo []snapshot
	redo []snapshot
}

// NodeByID returns a pointer into Nodes, or nil.
func (b *Board) NodeByID(id string) *Node {
	for i := range b.Nodes {
		if b.Nodes[i].ID == id {
			return &b.Nodes[i]
		}
	}
	return nil
}

func (b *Board) selected(id string) bool {
	return slices.Contains(b.Selection, id)
}

func (b *Board) setSelection(ids []string) {
	if slices.Equal(b.Selection, ids) {
		return
	}
	b.Selection = append([]string(nil), ids...)
	if b.OnSelection != nil {
		b.OnSelection(b.Selection)
	}
}

func (b *Board) toggleSelection(id string) {
	if b.selected(id) {
		next := slices.DeleteFunc(append([]string(nil), b.Selection...), func(s string) bool { return s == id })
		b.setSelection(next)
		return
	}
	b.setSelection(append(append([]string(nil), b.Selection...), id))
}

func (b *Board) portWorld(n Node, p Port) (x, y float32) {
	at := p.At
	if at == 0 {
		at = 0.5
	}
	switch p.Side {
	case Left:
		return n.X, n.Y + n.H*at
	case Right:
		return n.X + n.W, n.Y + n.H*at
	case Top:
		return n.X + n.W*at, n.Y
	default: // Bottom
		return n.X + n.W*at, n.Y + n.H
	}
}

func (b *Board) findPort(nodeID, portID string) (Node, Port, bool) {
	n := b.NodeByID(nodeID)
	if n == nil {
		return Node{}, Port{}, false
	}
	for _, p := range n.Ports {
		if p.ID == portID {
			return *n, p, true
		}
	}
	return Node{}, Port{}, false
}

func (b *Board) hitNode(wx, wy float32) string {
	for i := len(b.Nodes) - 1; i >= 0; i-- {
		n := b.Nodes[i]
		if wx >= n.X && wy >= n.Y && wx < n.X+n.W && wy < n.Y+n.H {
			return n.ID
		}
	}
	return ""
}

func (b *Board) hitPort(wx, wy float32, zoom float32) (nodeID, portID string) {
	r := float32(8) / zoom
	best := r * r
	for _, n := range b.Nodes {
		for _, p := range n.Ports {
			px, py := b.portWorld(n, p)
			dx, dy := wx-px, wy-py
			d2 := dx*dx + dy*dy
			if d2 <= best {
				best = d2
				nodeID, portID = n.ID, p.ID
			}
		}
	}
	return nodeID, portID
}

func (b *Board) hitEdge(wx, wy float32, zoom float32) string {
	thresh := float32(6) / zoom
	for _, e := range b.Edges {
		sn, sp, ok1 := b.findPort(e.Source, e.SourcePort)
		tn, tp, ok2 := b.findPort(e.Target, e.TargetPort)
		if !ok1 || !ok2 {
			continue
		}
		x0, y0 := b.portWorld(sn, sp)
		x1, y1 := b.portWorld(tn, tp)
		if distToEdge(b.EdgeStyle, wx, wy, x0, y0, x1, y1, sp.Side, tp.Side) <= thresh {
			return e.ID
		}
	}
	return ""
}

// View builds the node canvas into the layout. Fill it to take the parent.
func View(c *ui.Context, b *Board) ui.Element {
	if b.Camera.Zoom == 0 {
		b.Camera.Zoom = 1
	}
	b.ensureEdgeSeq()
	b.ensureNodeSeq()
	t := c.Theme()
	root := ui.Box(c).Clip().Background(t.Background).Cursor(cursorFor(b.Tool)).Focusable()

	root.HandleInput(func(ev ui.InputEvent) bool {
		return b.handleInput(ev)
	})

	root.Draw(func(p *ui.Painter, r ui.Rect) {
		b.viewR = r
		b.paintWorld(p, r, t)
		if b.Minimap {
			b.paintMinimap(p, r, t)
		}
	})

	root.Children(func() {
		host := ui.Box(c).Absolute().Left(0).Top(0).Right(0).Bottom(0).PassThrough()
		host.Children(func() {
			vr := b.viewR
			if vr.W == 0 || vr.H == 0 {
				w, h := c.Size()
				vr = ui.Rect{W: w, H: h}
			}
			worldVis := b.Camera.Visible(vr)
			pad := float32(40) / b.Camera.zoom()
			worldVis.X -= pad
			worldVis.Y -= pad
			worldVis.W += 2 * pad
			worldVis.H += 2 * pad

			for i := range b.Nodes {
				n := &b.Nodes[i]
				if n.W == 0 {
					n.W = 160
				}
				if n.H == 0 {
					n.H = 88
				}
				if !rectsOverlap(worldVis, ui.Rect{X: n.X, Y: n.Y, W: n.W, H: n.H}) {
					continue
				}
				b.buildNode(c, n, vr, t)
			}
		})
	})
	return root
}

func cursorFor(tool Tool) ui.Cursor {
	switch tool {
	case ToolPan:
		return ui.CursorGrab
	default:
		return ui.CursorDefault
	}
}

func rectsOverlap(a, b ui.Rect) bool {
	return a.X < b.X+b.W && a.X+a.W > b.X && a.Y < b.Y+b.H && a.Y+a.H > b.Y
}

func (b *Board) buildNode(c *ui.Context, n *Node, vr ui.Rect, t *ui.Theme) {
	z := b.Camera.zoom()
	vx, vy := b.Camera.ToView(vr, n.X, n.Y)
	card := ui.Column(c).Key(n.ID).Absolute().
		Left(vx).Top(vy).
		Size(n.W, n.H).
		Scale(z, z).
		TransformOrigin(0, 0).
		Background(t.Surface).
		Border(1, t.Border).
		Radius(8).
		Clip()
	if b.selected(n.ID) {
		card.Border(2, t.Accent)
	}
	if b.Tool != ToolSelect {
		card.PassThrough()
	}
	if b.Tool == ToolSelect {
		if card.Clicked() {
			if b.lastMods&ui.Shift != 0 {
				b.toggleSelection(n.ID)
			} else if !b.selected(n.ID) {
				b.setSelection([]string{n.ID})
			}
			b.bringToFront(n.ID)
		}
		if dx, dy, ok := card.Dragged(); ok {
			if !b.draggingGroup {
				b.beginGroupDrag(n.ID)
			}
			if dx != 0 || dy != 0 {
				if !b.dragMoved {
					b.pushUndo()
					b.dragMoved = true
				}
				b.moveSelectionBy(dx, dy)
			}
		} else if b.draggingGroup {
			b.draggingGroup = false
			b.dragMoved = false
			b.dragOrigins = nil
		}
	}
	card.Children(func() {
		ui.Row(c).Height(28).Padding(0, 8).AlignItems(ui.Center).Background(t.Surface).Children(func() {
			ui.Text(c, n.Title).FontSize(12).Bold().Grow(1)
		})
		body := ui.Column(c).Grow(1).Padding(8).Gap(4)
		body.Children(func() {
			if n.Content != nil {
				n.Content(c)
			} else {
				ui.Text(c, n.ID).FontSize(11).TextColor(t.TextMuted)
			}
		})
	})
}

func (b *Board) beginGroupDrag(id string) {
	if !b.selected(id) {
		b.setSelection([]string{id})
	}
	b.draggingGroup = true
	b.dragMoved = false
	b.dragOrigins = make(map[string][2]float32)
	for _, sid := range b.Selection {
		if len(sid) > 5 && sid[:5] == "edge:" {
			continue
		}
		if n := b.NodeByID(sid); n != nil {
			b.dragOrigins[sid] = [2]float32{n.X, n.Y}
		}
	}
}

func (b *Board) moveSelectionBy(dx, dy float32) {
	for id := range b.dragOrigins {
		if n := b.NodeByID(id); n != nil {
			n.X += dx
			n.Y += dy
			if b.OnMove != nil {
				b.OnMove(n.ID, n.X, n.Y)
			}
		}
	}
}

func (b *Board) paintWorld(p *ui.Painter, r ui.Rect, t *ui.Theme) {
	b.Camera.Draw(p, r, func() {
		vis := b.Camera.Visible(r)
		step := float32(32)
		x0 := float32(math.Floor(float64(vis.X)/float64(step))) * step
		y0 := float32(math.Floor(float64(vis.Y)/float64(step))) * step
		dot := t.Border.Alpha(0.3)
		for y := y0; y < vis.Y+vis.H+step; y += step {
			for x := x0; x < vis.X+vis.W+step; x += step {
				p.Fill(ui.Rect{X: x - 0.5, Y: y - 0.5, W: 1, H: 1}, dot, 0)
			}
		}

		for _, e := range b.Edges {
			sn, sp, ok1 := b.findPort(e.Source, e.SourcePort)
			tn, tp, ok2 := b.findPort(e.Target, e.TargetPort)
			if !ok1 || !ok2 {
				continue
			}
			x0, y0 := b.portWorld(sn, sp)
			x1, y1 := b.portWorld(tn, tp)
			col := t.Accent
			if e.ID != "" && slices.Contains(b.Selection, "edge:"+e.ID) {
				col = t.Danger
			}
			strokeEdge(p, b.EdgeStyle, x0, y0, x1, y1, sp.Side, tp.Side, col, 2)
		}

		if b.connecting {
			if sn, sp, ok := b.findPort(b.connFromN, b.connFromP); ok {
				x0, y0 := b.portWorld(sn, sp)
				strokeEdge(p, b.EdgeStyle, x0, y0, b.connWX, b.connWY, sp.Side, Left, t.Accent, 1.5)
			}
		}

		if b.marquee {
			x0, x1 := b.marqueeX0, b.marqueeX1
			y0, y1 := b.marqueeY0, b.marqueeY1
			if x1 < x0 {
				x0, x1 = x1, x0
			}
			if y1 < y0 {
				y0, y1 = y1, y0
			}
			fill := t.Accent.Alpha(0.12)
			p.Fill(ui.Rect{X: x0, Y: y0, W: x1 - x0, H: y1 - y0}, fill, 0)
			p.StrokePath((&ui.Path{}).
				MoveTo(x0, y0).LineTo(x1, y0).LineTo(x1, y1).LineTo(x0, y1).Close(),
				1, t.Accent)
		}

		for _, n := range b.Nodes {
			for _, port := range n.Ports {
				px, py := b.portWorld(n, port)
				path := (&ui.Path{}).Circle(px, py, 5)
				p.FillPath(path, t.Accent)
				p.StrokePath(path, 1.5, t.Background)
			}
		}
	})
}

func (b *Board) paintMinimap(p *ui.Painter, r ui.Rect, t *ui.Theme) {
	const pad = float32(12)
	const mw, mh = float32(160), float32(110)
	mr := ui.Rect{X: r.X + r.W - mw - pad, Y: r.Y + r.H - mh - pad, W: mw, H: mh}
	p.Fill(mr, t.Surface.Alpha(0.92), 8)
	p.StrokePath((&ui.Path{}).
		MoveTo(mr.X, mr.Y).LineTo(mr.X+mr.W, mr.Y).LineTo(mr.X+mr.W, mr.Y+mr.H).LineTo(mr.X, mr.Y+mr.H).Close(),
		1, t.Border)

	bounds := b.contentBounds()
	if bounds.W < 1 {
		bounds.W = 1
	}
	if bounds.H < 1 {
		bounds.H = 1
	}
	scale := min(mr.W/bounds.W, mr.H/bounds.H) * 0.9
	ox := mr.X + (mr.W-bounds.W*scale)/2 - bounds.X*scale
	oy := mr.Y + (mr.H-bounds.H*scale)/2 - bounds.Y*scale
	mapPt := func(x, y float32) (float32, float32) {
		return ox + x*scale, oy + y*scale
	}

	for _, n := range b.Nodes {
		x, y := mapPt(n.X, n.Y)
		col := t.Border
		if b.selected(n.ID) {
			col = t.Accent
		}
		p.Fill(ui.Rect{X: x, Y: y, W: max(2, n.W*scale), H: max(2, n.H*scale)}, col, 2)
	}
	vis := b.Camera.Visible(r)
	vx0, vy0 := mapPt(vis.X, vis.Y)
	vx1, vy1 := mapPt(vis.X+vis.W, vis.Y+vis.H)
	p.StrokePath((&ui.Path{}).
		MoveTo(vx0, vy0).LineTo(vx1, vy0).LineTo(vx1, vy1).LineTo(vx0, vy1).Close(),
		1.5, t.Accent)
}

func (b *Board) contentBounds() ui.Rect {
	if len(b.Nodes) == 0 {
		return ui.Rect{X: -100, Y: -100, W: 200, H: 200}
	}
	minX, minY := b.Nodes[0].X, b.Nodes[0].Y
	maxX, maxY := minX+b.Nodes[0].W, minY+b.Nodes[0].H
	for _, n := range b.Nodes[1:] {
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
	return ui.Rect{X: minX, Y: minY, W: maxX - minX, H: maxY - minY}
}
