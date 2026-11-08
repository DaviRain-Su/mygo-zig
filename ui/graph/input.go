package graph

import (
	"fmt"
	"slices"

	"github.com/egoist/mygo/ui"
)

func (b *Board) handleInput(ev ui.InputEvent) bool {
	r := b.viewR
	if r.W == 0 {
		return false
	}
	b.lastMods = ev.Mods
	wx, wy := b.Camera.ToWorld(r, ev.X, ev.Y)

	switch ev.Kind {
	case ui.InputScroll:
		if ev.Mods&ui.Ctrl != 0 || ev.Mods&ui.Super != 0 {
			factor := float32(1)
			if ev.DY < 0 {
				factor = 1.1
			} else if ev.DY > 0 {
				factor = 1 / 1.1
			}
			b.Camera.ZoomAt(r, ev.X, ev.Y, factor)
			b.emitViewport()
			return true
		}
		b.Camera.PanBy(ev.DX, ev.DY)
		b.emitViewport()
		return true

	case ui.InputZoom:
		b.Camera.ZoomAt(r, ev.X, ev.Y, ev.Scale)
		b.emitViewport()
		return true

	case ui.InputKeyDown:
		return b.handleKey(ev)

	case ui.InputPointerDown:
		if ev.Button == 2 || (ev.Button == 0 && b.Tool == ToolPan) {
			b.panning = true
			b.lastPanX, b.lastPanY = ev.X, ev.Y
			return true
		}
		if ev.Button != 0 {
			return false
		}
		switch b.Tool {
		case ToolConnect:
			nID, pID := b.hitPort(wx, wy, b.Camera.zoom())
			if nID != "" {
				b.connecting = true
				b.connFromN, b.connFromP = nID, pID
				b.connWX, b.connWY = wx, wy
				return true
			}
			return true
		default: // ToolSelect
			if eid := b.hitEdge(wx, wy, b.Camera.zoom()); eid != "" {
				if ev.Clicks >= 2 {
					b.beginEdgeLabelEdit(eid)
					return true
				}
				id := "edge:" + eid
				if ev.Mods&ui.Shift != 0 {
					b.toggleSelection(id)
				} else {
					b.setSelection([]string{id})
				}
				return true
			}
			if id := b.hitNode(wx, wy); id != "" {
				// Card elements handle click/drag; Shift toggle also there.
				return false
			}
			if gid := b.hitGroup(wx, wy); gid != "" {
				id := groupSelID(gid)
				if ev.Mods&ui.Shift != 0 {
					b.toggleSelection(id)
				} else if !b.selected(id) {
					b.setSelection([]string{id})
				}
				b.beginGroupDrag(id)
				b.groupDragging = true
				b.lastPanX, b.lastPanY = wx, wy
				return true
			}
			// Empty canvas: start marquee (Shift keeps previous selection).
			b.marquee = true
			b.marqueeAdditive = ev.Mods&ui.Shift != 0
			b.marqueeX0, b.marqueeY0 = wx, wy
			b.marqueeX1, b.marqueeY1 = wx, wy
			if !b.marqueeAdditive {
				b.setSelection(nil)
			}
			return true
		}

	case ui.InputPointerMove:
		if b.panning {
			b.Camera.PanBy(ev.X-b.lastPanX, ev.Y-b.lastPanY)
			b.lastPanX, b.lastPanY = ev.X, ev.Y
			b.emitViewport()
			return true
		}
		if b.connecting {
			b.connWX, b.connWY = wx, wy
			return true
		}
		if b.groupDragging {
			dx, dy := wx-b.lastPanX, wy-b.lastPanY
			if dx != 0 || dy != 0 {
				if !b.dragMoved {
					b.pushUndo()
					b.dragMoved = true
				}
				b.moveSelectionBy(dx, dy)
				b.lastPanX, b.lastPanY = wx, wy
			}
			return true
		}
		if b.marquee {
			b.marqueeX1, b.marqueeY1 = wx, wy
			return true
		}
		return false

	case ui.InputPointerUp:
		if b.panning {
			b.panning = false
			return true
		}
		if b.connecting {
			nID, pID := b.hitPort(wx, wy, b.Camera.zoom())
			if nID != "" && !(nID == b.connFromN && pID == b.connFromP) {
				b.pushUndo()
				b.edgeSeq++
				e := Edge{
					ID:         fmt.Sprintf("e%d", b.edgeSeq),
					Source:     b.connFromN,
					SourcePort: b.connFromP,
					Target:     nID,
					TargetPort: pID,
				}
				b.Edges = append(b.Edges, e)
				if b.OnConnect != nil {
					b.OnConnect(e)
				}
			}
			b.connecting = false
			return true
		}
		if b.groupDragging {
			if b.dragMoved {
				b.snapSelection()
			}
			b.groupDragging = false
			b.draggingGroup = false
			b.dragMoved = false
			b.dragOrigins = nil
			return true
		}
		if b.marquee {
			b.applyMarquee()
			b.marquee = false
			return true
		}
		return false
	}
	return false
}

func (b *Board) handleKey(ev ui.InputEvent) bool {
	if b.editingEdge != "" {
		if ev.Key == ui.KeyEscape {
			b.cancelEdgeLabelEdit()
			return true
		}
		// Let the text input handle typing.
		return false
	}
	cmd := ev.Mods&ui.Cmd != 0
	if cmd && ev.Key == ui.KeyZ {
		if ev.Mods&ui.Shift != 0 {
			return b.Redo()
		}
		return b.Undo()
	}
	if cmd && ev.Key == ui.KeyA {
		ids := make([]string, 0, len(b.Nodes))
		for _, n := range b.Nodes {
			ids = append(ids, n.ID)
		}
		b.setSelection(ids)
		return true
	}
	if cmd && ev.Key == ui.KeyD {
		return b.duplicateSelection()
	}
	if ev.Key == ui.KeyBackspace || ev.Key == ui.KeyDelete {
		return b.deleteSelection()
	}
	if ev.Key == ui.KeyV && !cmd {
		b.Tool = ToolSelect
		return true
	}
	if ev.Key == ui.KeyH {
		b.Tool = ToolPan
		return true
	}
	if ev.Key == ui.KeyC && !cmd {
		b.Tool = ToolConnect
		return true
	}
	if ev.Key == ui.KeyO && !cmd {
		if b.EdgeStyle == EdgeOrthogonal {
			b.EdgeStyle = EdgeBezier
		} else {
			b.EdgeStyle = EdgeOrthogonal
		}
		return true
	}
	if ev.Key == ui.KeyG && !cmd {
		if ev.Mods&ui.Shift != 0 {
			return b.UngroupSelection()
		}
		return b.GroupSelection() != ""
	}
	if ev.Key == ui.KeyL && !cmd {
		b.AutoLayout(LayoutOptions{})
		if b.viewR.W > 0 {
			b.FitCamera(b.viewR, 48)
		}
		return true
	}
	if ev.Key == ui.KeyF && !cmd && b.viewR.W > 0 {
		if ev.Mods&ui.Shift != 0 {
			b.FitSelection(b.viewR, 48)
		} else {
			b.FitCamera(b.viewR, 48)
		}
		return true
	}
	if ev.Key == ui.KeyK && !cmd {
		return b.ToggleLockSelection()
	}
	if ev.Key == ui.KeyEnter {
		for _, id := range b.Selection {
			if eid, ok := parseEdgeSel(id); ok {
				b.beginEdgeLabelEdit(eid)
				return true
			}
		}
	}
	if cmd {
		switch ev.Key {
		case ui.KeyLeft:
			return b.AlignSelection(AlignLeft)
		case ui.KeyRight:
			return b.AlignSelection(AlignRight)
		case ui.KeyUp:
			return b.AlignSelection(AlignTop)
		case ui.KeyDown:
			return b.AlignSelection(AlignBottom)
		case ui.KeyC:
			return b.CopySelection()
		case ui.KeyV:
			return b.PasteClipboard()
		case ui.KeyX:
			if b.CopySelection() {
				return b.deleteSelection()
			}
			return false
		}
	}
	step := float32(1)
	if b.SnapGrid > 0 {
		step = b.SnapGrid
	}
	if ev.Mods&ui.Shift != 0 {
		step *= 10
	}
	switch ev.Key {
	case ui.KeyLeft:
		return b.nudgeSelection(-step, 0)
	case ui.KeyRight:
		return b.nudgeSelection(step, 0)
	case ui.KeyUp:
		return b.nudgeSelection(0, -step)
	case ui.KeyDown:
		return b.nudgeSelection(0, step)
	}
	return false
}

func (b *Board) applyMarquee() {
	x0, x1 := b.marqueeX0, b.marqueeX1
	y0, y1 := b.marqueeY0, b.marqueeY1
	if x1 < x0 {
		x0, x1 = x1, x0
	}
	if y1 < y0 {
		y0, y1 = y1, y0
	}
	box := ui.Rect{X: x0, Y: y0, W: x1 - x0, H: y1 - y0}
	var ids []string
	if b.marqueeAdditive {
		ids = append(ids, b.Selection...)
	}
	for _, n := range b.Nodes {
		nr := ui.Rect{X: n.X, Y: n.Y, W: n.W, H: n.H}
		if rectsOverlap(box, nr) && !slices.Contains(ids, n.ID) {
			ids = append(ids, n.ID)
		}
	}
	b.setSelection(ids)
}

func (b *Board) emitViewport() {
	if b.OnViewport != nil {
		b.OnViewport(b.Camera)
	}
}

func (b *Board) bringToFront(id string) {
	for i := range b.Nodes {
		if b.Nodes[i].ID == id {
			n := b.Nodes[i]
			b.Nodes = append(append(b.Nodes[:i:i], b.Nodes[i+1:]...), n)
			return
		}
	}
}

func (b *Board) deleteSelection() bool {
	if len(b.Selection) == 0 {
		return false
	}
	b.pushUndo()
	var edgeIDs, nodeIDs, groupIDs []string
	for _, id := range b.Selection {
		if eid, ok := parseEdgeSel(id); ok {
			edgeIDs = append(edgeIDs, eid)
			continue
		}
		if gid, ok := parseGroupSel(id); ok {
			groupIDs = append(groupIDs, gid)
			continue
		}
		nodeIDs = append(nodeIDs, id)
	}
	if len(edgeIDs) > 0 {
		b.Edges = slices.DeleteFunc(b.Edges, func(e Edge) bool {
			return slices.Contains(edgeIDs, e.ID)
		})
	}
	if len(groupIDs) > 0 {
		b.Groups = slices.DeleteFunc(b.Groups, func(g Group) bool {
			return slices.Contains(groupIDs, g.ID)
		})
	}
	if len(nodeIDs) > 0 {
		b.Nodes = slices.DeleteFunc(b.Nodes, func(n Node) bool {
			return slices.Contains(nodeIDs, n.ID)
		})
		b.Edges = slices.DeleteFunc(b.Edges, func(e Edge) bool {
			return slices.Contains(nodeIDs, e.Source) || slices.Contains(nodeIDs, e.Target)
		})
		b.scrubGroupsAfterNodeDelete(nodeIDs)
	}
	b.setSelection(nil)
	if b.OnDelete != nil {
		b.OnDelete(edgeIDs, nodeIDs)
	}
	return true
}

func (b *Board) duplicateSelection() bool {
	var copies []Node
	for _, id := range b.Selection {
		if len(id) > 5 && id[:5] == "edge:" {
			continue
		}
		n := b.NodeByID(id)
		if n == nil {
			continue
		}
		b.nodeSeq++
		cp := *n
		cp.ID = fmt.Sprintf("n%d", b.nodeSeq)
		cp.Title = n.Title + " copy"
		cp.X += 24
		cp.Y += 24
		if len(n.Ports) > 0 {
			cp.Ports = append([]Port(nil), n.Ports...)
		}
		copies = append(copies, cp)
	}
	if len(copies) == 0 {
		return false
	}
	b.pushUndo()
	ids := make([]string, len(copies))
	for i, cp := range copies {
		b.Nodes = append(b.Nodes, cp)
		ids[i] = cp.ID
	}
	b.setSelection(ids)
	return true
}

func (b *Board) ensureEdgeSeq() {
	max := b.edgeSeq
	for _, e := range b.Edges {
		var n int
		if _, err := fmt.Sscanf(e.ID, "e%d", &n); err == nil && n > max {
			max = n
		}
	}
	b.edgeSeq = max
}

func (b *Board) ensureNodeSeq() {
	max := b.nodeSeq
	for _, n := range b.Nodes {
		var v int
		if _, err := fmt.Sscanf(n.ID, "n%d", &v); err == nil && v > max {
			max = v
		}
	}
	b.nodeSeq = max
}

// AddNode appends a node (assigning an id when empty) and records undo.
func (b *Board) AddNode(n Node) string {
	b.pushUndo()
	if n.ID == "" {
		b.ensureNodeSeq()
		b.nodeSeq++
		n.ID = fmt.Sprintf("n%d", b.nodeSeq)
	}
	if n.W == 0 {
		n.W = 160
	}
	if n.H == 0 {
		n.H = 88
	}
	b.Nodes = append(b.Nodes, n)
	b.setSelection([]string{n.ID})
	return n.ID
}

func (b *Board) ToggleLockSelection() bool {
	nodes := b.selectedNodes()
	if len(nodes) == 0 {
		return false
	}
	b.pushUndo()
	lock := false
	for _, n := range nodes {
		if !n.Locked {
			lock = true
			break
		}
	}
	for _, n := range nodes {
		n.Locked = lock
	}
	return true
}
