package graph

import "fmt"

// clipboard holds a local copy of nodes/edges (not the OS clipboard).
type clipboard struct {
	nodes []Node
	edges []Edge
}

// CopySelection stores selected nodes and edges between them for Paste.
func (b *Board) CopySelection() bool {
	nodes := b.selectedNodes()
	if len(nodes) == 0 {
		// Also allow copying a single selected edge-only selection? skip.
		return false
	}
	ids := map[string]bool{}
	copied := make([]Node, len(nodes))
	for i, n := range nodes {
		cp := *n
		if len(n.Ports) > 0 {
			cp.Ports = append([]Port(nil), n.Ports...)
		}
		// Content shared intentionally.
		copied[i] = cp
		ids[n.ID] = true
	}
	var edges []Edge
	for _, e := range b.Edges {
		if ids[e.Source] && ids[e.Target] {
			edges = append(edges, e)
		}
	}
	b.clip = clipboard{nodes: copied, edges: edges}
	return true
}

// PasteClipboard pastes the last CopySelection, offset by (24,24).
func (b *Board) PasteClipboard() bool {
	if len(b.clip.nodes) == 0 {
		return false
	}
	b.pushUndo()
	idMap := map[string]string{}
	var newIDs []string
	for _, n := range b.clip.nodes {
		old := n.ID
		b.ensureNodeSeq()
		b.nodeSeq++
		n.ID = fmt.Sprintf("n%d", b.nodeSeq)
		n.X += 24
		n.Y += 24
		b.snapNode(&n)
		if len(n.Ports) > 0 {
			n.Ports = append([]Port(nil), n.Ports...)
		}
		b.Nodes = append(b.Nodes, n)
		idMap[old] = n.ID
		newIDs = append(newIDs, n.ID)
	}
	for _, e := range b.clip.edges {
		s, sok := idMap[e.Source]
		t, tok := idMap[e.Target]
		if !sok || !tok {
			continue
		}
		b.edgeSeq++
		e.ID = fmt.Sprintf("e%d", b.edgeSeq)
		e.Source, e.Target = s, t
		b.Edges = append(b.Edges, e)
	}
	b.setSelection(newIDs)
	return true
}
