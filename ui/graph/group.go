package graph

import (
	"fmt"
	"slices"

	"github.com/egoist/mygo/ui"
)

// Group is a named frame around member nodes. Moving a selected group
// moves every member; deleting the group removes the frame only.
type Group struct {
	ID, Title string
	Members   []string // node ids
	// Parent is an optional parent group id (nested groups).
	Parent string
}

func groupSelID(id string) string { return "group:" + id }

func parseGroupSel(id string) (string, bool) {
	if len(id) > 6 && id[:6] == "group:" {
		return id[6:], true
	}
	return "", false
}

// GroupByID returns a pointer into Groups, or nil.
func (b *Board) GroupByID(id string) *Group {
	for i := range b.Groups {
		if b.Groups[i].ID == id {
			return &b.Groups[i]
		}
	}
	return nil
}

func (b *Board) ensureGroupSeq() {
	max := b.groupSeq
	for _, g := range b.Groups {
		var n int
		if _, err := fmt.Sscanf(g.ID, "g%d", &n); err == nil && n > max {
			max = n
		}
	}
	b.groupSeq = max
}

func (b *Board) groupBounds(g Group) (ui.Rect, bool) {
	return b.groupBoundsDepth(g, 0)
}

func (b *Board) groupBoundsDepth(g Group, depth int) (ui.Rect, bool) {
	if depth > 8 {
		return ui.Rect{}, false
	}
	var (
		ok                    bool
		minX, minY, maxX, maxY float32
	)
	include := func(r ui.Rect) {
		if !ok {
			minX, minY, maxX, maxY = r.X, r.Y, r.X+r.W, r.Y+r.H
			ok = true
			return
		}
		if r.X < minX {
			minX = r.X
		}
		if r.Y < minY {
			minY = r.Y
		}
		if r.X+r.W > maxX {
			maxX = r.X + r.W
		}
		if r.Y+r.H > maxY {
			maxY = r.Y + r.H
		}
	}
	for _, id := range g.Members {
		if n := b.NodeByID(id); n != nil {
			include(ui.Rect{X: n.X, Y: n.Y, W: n.W, H: n.H})
		}
	}
	for _, child := range b.Groups {
		if child.Parent == g.ID {
			if r, okc := b.groupBoundsDepth(child, depth+1); okc {
				include(r)
			}
		}
	}
	if !ok {
		return ui.Rect{}, false
	}
	const pad = float32(16)
	return ui.Rect{X: minX - pad, Y: minY - pad - 18, W: maxX - minX + 2*pad, H: maxY - minY + 2*pad + 18}, true
}

func (b *Board) hitGroup(wx, wy float32) string {
	// Topmost last wins; prefer groups whose chrome (not interior nodes) is hit.
	for i := len(b.Groups) - 1; i >= 0; i-- {
		g := b.Groups[i]
		r, ok := b.groupBounds(g)
		if !ok {
			continue
		}
		if wx >= r.X && wy >= r.Y && wx < r.X+r.W && wy < r.Y+r.H {
			// Title bar strip is always a group hit; body only if no node there.
			if wy < r.Y+22 || b.hitNode(wx, wy) == "" {
				return g.ID
			}
		}
	}
	return ""
}

// GroupSelection creates a group from the currently selected nodes.
func (b *Board) GroupSelection() string {
	var members []string
	var childGroups []string
	for _, id := range b.Selection {
		if _, isEdge := parseEdgeSel(id); isEdge {
			continue
		}
		if gid, isGroup := parseGroupSel(id); isGroup {
			childGroups = append(childGroups, gid)
			continue
		}
		if b.NodeByID(id) != nil {
			members = append(members, id)
		}
	}
	if len(members)+len(childGroups) < 2 {
		return ""
	}
	b.pushUndo()
	b.ensureGroupSeq()
	b.groupSeq++
	id := fmt.Sprintf("g%d", b.groupSeq)
	for _, gid := range childGroups {
		if g := b.GroupByID(gid); g != nil {
			g.Parent = id
		}
	}
	b.Groups = append(b.Groups, Group{
		ID:      id,
		Title:   fmt.Sprintf("Group %d", b.groupSeq),
		Members: members,
	})
	b.setSelection([]string{groupSelID(id)})
	return id
}

// UngroupSelection removes selected groups (nodes stay).
func (b *Board) UngroupSelection() bool {
	var remove []string
	for _, id := range b.Selection {
		if gid, ok := parseGroupSel(id); ok {
			remove = append(remove, gid)
		}
	}
	if len(remove) == 0 {
		return false
	}
	b.pushUndo()
	for i := range b.Groups {
		if slices.Contains(remove, b.Groups[i].Parent) {
			b.Groups[i].Parent = ""
		}
	}
	b.Groups = slices.DeleteFunc(b.Groups, func(g Group) bool {
		return slices.Contains(remove, g.ID)
	})
	b.setSelection(nil)
	return true
}

func (b *Board) paintGroups(p *ui.Painter, t *ui.Theme) {
	order := make([]Group, len(b.Groups))
	copy(order, b.Groups)
	// Parents behind children: lower depth first.
	depthOf := map[string]int{}
	var depth func(id string) int
	depth = func(id string) int {
		if d, ok := depthOf[id]; ok {
			return d
		}
		g := b.GroupByID(id)
		if g == nil || g.Parent == "" {
			depthOf[id] = 0
			return 0
		}
		d := depth(g.Parent) + 1
		depthOf[id] = d
		return d
	}
	for i := 0; i < len(order); i++ {
		for j := i + 1; j < len(order); j++ {
			if depth(order[j].ID) < depth(order[i].ID) {
				order[i], order[j] = order[j], order[i]
			}
		}
	}
	for _, g := range order {
		r, ok := b.groupBounds(g)
		if !ok {
			continue
		}
		selected := b.selected(groupSelID(g.ID))
		fill := t.Accent.Alpha(0.06)
		stroke := t.Border
		if selected {
			fill = t.Accent.Alpha(0.12)
			stroke = t.Accent
		}
		p.Fill(r, fill, 10)
		path := (&ui.Path{}).
			MoveTo(r.X, r.Y).LineTo(r.X+r.W, r.Y).
			LineTo(r.X+r.W, r.Y+r.H).LineTo(r.X, r.Y+r.H).Close()
		path.Dash(0, 4, 3)
		p.StrokePath(path, 1.5, stroke)
		title := g.Title
		if title == "" {
			title = g.ID
		}
		p.Text(r.X+10, r.Y+14, title, 11, t.TextMuted)
	}
}

// dragNodeIDs returns node ids that should move with the current selection
// (selected nodes plus members of selected groups), without mutating Selection.
func (b *Board) dragNodeIDs() []string {
	seen := map[string]bool{}
	var out []string
	add := func(id string) {
		if seen[id] {
			return
		}
		seen[id] = true
		out = append(out, id)
	}
	var walk func(gid string, depth int)
	walk = func(gid string, depth int) {
		if depth > 8 {
			return
		}
		g := b.GroupByID(gid)
		if g == nil {
			return
		}
		for _, mid := range g.Members {
			add(mid)
		}
		for _, child := range b.Groups {
			if child.Parent == gid {
				walk(child.ID, depth+1)
			}
		}
	}
	for _, id := range b.Selection {
		if _, ok := parseEdgeSel(id); ok {
			continue
		}
		if gid, ok := parseGroupSel(id); ok {
			walk(gid, 0)
			continue
		}
		add(id)
	}
	return out
}

// expandSelectionForDrag is kept as a no-op alias for older call sites.
func (b *Board) expandSelectionForDrag() {}

func (b *Board) scrubGroupsAfterNodeDelete(nodeIDs []string) {
	if len(nodeIDs) == 0 {
		return
	}
	for i := range b.Groups {
		b.Groups[i].Members = slices.DeleteFunc(b.Groups[i].Members, func(id string) bool {
			return slices.Contains(nodeIDs, id)
		})
	}
	b.Groups = slices.DeleteFunc(b.Groups, func(g Group) bool {
		return len(g.Members) == 0
	})
}
