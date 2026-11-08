package graph

// Align is a horizontal/vertical alignment of the selected nodes.
type Align int

const (
	AlignLeft Align = iota
	AlignRight
	AlignTop
	AlignBottom
	AlignHCenter
	AlignVCenter
)

func (b *Board) selectedNodes() []*Node {
	var out []*Node
	seen := map[string]bool{}
	add := func(id string) {
		if seen[id] {
			return
		}
		if n := b.NodeByID(id); n != nil {
			out = append(out, n)
			seen[id] = true
		}
	}
	var walkGroup func(gid string, depth int)
	walkGroup = func(gid string, depth int) {
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
				walkGroup(child.ID, depth+1)
			}
		}
	}
	for _, id := range b.Selection {
		if _, ok := parseEdgeSel(id); ok {
			continue
		}
		if gid, ok := parseGroupSel(id); ok {
			walkGroup(gid, 0)
			continue
		}
		add(id)
	}
	return out
}

// AlignSelection lines up selected nodes. Needs at least two nodes.
func (b *Board) AlignSelection(a Align) bool {
	nodes := b.selectedNodes()
	if len(nodes) < 2 {
		return false
	}
	b.pushUndo()
	switch a {
	case AlignLeft:
		x := nodes[0].X
		for _, n := range nodes[1:] {
			if n.X < x {
				x = n.X
			}
		}
		for _, n := range nodes {
			n.X = x
		}
	case AlignRight:
		x := nodes[0].X + nodes[0].W
		for _, n := range nodes[1:] {
			if n.X+n.W > x {
				x = n.X + n.W
			}
		}
		for _, n := range nodes {
			n.X = x - n.W
		}
	case AlignTop:
		y := nodes[0].Y
		for _, n := range nodes[1:] {
			if n.Y < y {
				y = n.Y
			}
		}
		for _, n := range nodes {
			n.Y = y
		}
	case AlignBottom:
		y := nodes[0].Y + nodes[0].H
		for _, n := range nodes[1:] {
			if n.Y+n.H > y {
				y = n.Y + n.H
			}
		}
		for _, n := range nodes {
			n.Y = y - n.H
		}
	case AlignHCenter:
		var sum float32
		for _, n := range nodes {
			sum += n.X + n.W/2
		}
		cx := sum / float32(len(nodes))
		for _, n := range nodes {
			n.X = cx - n.W/2
		}
	case AlignVCenter:
		var sum float32
		for _, n := range nodes {
			sum += n.Y + n.H/2
		}
		cy := sum / float32(len(nodes))
		for _, n := range nodes {
			n.Y = cy - n.H/2
		}
	}
	b.snapSelection()
	return true
}

// DistributeSelection spaces selected nodes evenly horizontally or vertically.
func (b *Board) DistributeSelection(horizontal bool) bool {
	nodes := b.selectedNodes()
	if len(nodes) < 3 {
		return false
	}
	b.pushUndo()
	if horizontal {
		sortNodesBy(nodes, true)
		left := nodes[0].X
		right := nodes[len(nodes)-1].X + nodes[len(nodes)-1].W
		var totalW float32
		for _, n := range nodes {
			totalW += n.W
		}
		gap := (right - left - totalW) / float32(len(nodes)-1)
		x := left
		for _, n := range nodes {
			n.X = x
			x += n.W + gap
		}
	} else {
		sortNodesBy(nodes, false)
		top := nodes[0].Y
		bottom := nodes[len(nodes)-1].Y + nodes[len(nodes)-1].H
		var totalH float32
		for _, n := range nodes {
			totalH += n.H
		}
		gap := (bottom - top - totalH) / float32(len(nodes)-1)
		y := top
		for _, n := range nodes {
			n.Y = y
			y += n.H + gap
		}
	}
	b.snapSelection()
	return true
}

func sortNodesBy(nodes []*Node, byX bool) {
	for i := 0; i < len(nodes); i++ {
		for j := i + 1; j < len(nodes); j++ {
			swap := false
			if byX {
				swap = nodes[j].X < nodes[i].X
			} else {
				swap = nodes[j].Y < nodes[i].Y
			}
			if swap {
				nodes[i], nodes[j] = nodes[j], nodes[i]
			}
		}
	}
}
