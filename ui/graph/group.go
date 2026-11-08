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
	var (
		ok                 bool
		minX, minY, maxX, maxY float32
	)
	for _, id := range g.Members {
		n := b.NodeByID(id)
		if n == nil {
			continue
		}
		if !ok {
			minX, minY = n.X, n.Y
			maxX, maxY = n.X+n.W, n.Y+n.H
			ok = true
			continue
		}
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
	for _, id := range b.Selection {
		if _, isEdge := parseEdgeSel(id); isEdge {
			continue
		}
		if _, isGroup := parseGroupSel(id); isGroup {
			continue
		}
		if b.NodeByID(id) != nil {
			members = append(members, id)
		}
	}
	if len(members) < 2 {
		return ""
	}
	b.pushUndo()
	b.ensureGroupSeq()
	b.groupSeq++
	id := fmt.Sprintf("g%d", b.groupSeq)
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
	b.Groups = slices.DeleteFunc(b.Groups, func(g Group) bool {
		return slices.Contains(remove, g.ID)
	})
	b.setSelection(nil)
	return true
}

func (b *Board) paintGroups(p *ui.Painter, t *ui.Theme) {
	for _, g := range b.Groups {
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

func (b *Board) expandSelectionForDrag() {
	// When a group is selected, include its members in drag origins.
	seen := map[string]bool{}
	for _, id := range b.Selection {
		seen[id] = true
	}
	var extra []string
	for _, id := range b.Selection {
		gid, ok := parseGroupSel(id)
		if !ok {
			continue
		}
		g := b.GroupByID(gid)
		if g == nil {
			continue
		}
		for _, mid := range g.Members {
			if !seen[mid] {
				extra = append(extra, mid)
				seen[mid] = true
			}
		}
	}
	if len(extra) > 0 {
		b.Selection = append(b.Selection, extra...)
	}
}

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
