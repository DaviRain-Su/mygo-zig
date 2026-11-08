//go:build !js

// Package graph registers `ui/graph` (the node canvas) into `zig/host`.
//
// Import with `_ "github.com/egoist/mygo/zig/host/graph"` in Zig apps that
// show boards of nodes, ports and edges.
package graph

import (
	"encoding/json"
	"sync"
	"unsafe"

	mygoui "github.com/egoist/mygo/ui"
	"github.com/egoist/mygo/ui/graph"
	"github.com/egoist/mygo/zig/host"
	zigui "github.com/egoist/mygo/zig/host/ui"
)

func init() {
	host.GraphDispatch = dispatchGraph
}

// Sub-ops of host.HostOpGraph.
const (
	opCreate     uintptr = 1 // a1=*CGraphSpec → board id
	opLoad       uintptr = 2 // a1=id a2=json a3=len
	opExport     uintptr = 3 // a1=id a2=*COut → len
	opAddNode    uintptr = 4 // a1=id a2=*CGraphAdd → id in Out
	opSelection  uintptr = 5 // a1=id a2=*COut → count
	opAction     uintptr = 6 // a1=id a2=kind → 0/1
	opView       uintptr = 7 // a1=frame a2=id a3=*CGraphView
	opSetContent uintptr = 8 // a1=id a2=cb
	opDestroy    uintptr = 9 // a1=id
	opOnSelect   uintptr = 10
	opOnConnect  uintptr = 11
	opOnMove     uintptr = 12
	opOnDelete   uintptr = 13
	opOnViewport uintptr = 14
)

// Board actions.
const (
	actDelete    uintptr = 1
	actGroup     uintptr = 2
	actUngroup   uintptr = 3
	actLayout    uintptr = 4
	actFit       uintptr = 5
	actUndo      uintptr = 6
	actRedo      uintptr = 7
	actCopy      uintptr = 8
	actPaste     uintptr = 9
	actLock      uintptr = 10
	actSelectAll uintptr = 11
)

// CGraphSpec is a board's JSON document and its look.
type CGraphSpec struct {
	JSONPtr, JSONLen uintptr
	// Flags: 1 minimap, 2 orthogonal edges.
	Flags    uint32
	Tool     uint8
	_        [3]byte
	SnapGrid float32
}

// CGraphView is the per-frame view state.
type CGraphView struct {
	// Flags: 1 minimap, 2 orthogonal edges.
	Flags    uint32
	Tool     uint8
	_        [3]byte
	SnapGrid float32
}

// COut is a caller buffer for text.
type COut struct {
	Ptr, Cap uintptr
}

// CGraphAdd adds a node from JSON and writes its id into Out.
type CGraphAdd struct {
	JSONPtr, JSONLen uintptr
	OutPtr, OutCap   uintptr
}

// CGraphNodeInfo tells Zig which node's body to build, and the frame info
// its context needs.
type CGraphNodeInfo struct {
	IDPtr, IDLen uintptr
	Info         *zigui.CFrameInfo
}

type boardHost struct {
	b  *graph.Board
	cb struct {
		sel, connect, move, del, viewport, content uintptr
	}
}

var (
	boardsMu sync.Mutex
	boards   = map[uintptr]*boardHost{}
	boardSeq uintptr
)

func boardByID(id uintptr) *boardHost {
	boardsMu.Lock()
	defer boardsMu.Unlock()
	return boards[id]
}

func newBoard(b *graph.Board) uintptr {
	boardsMu.Lock()
	boardSeq++
	id := boardSeq
	boards[id] = &boardHost{b: b}
	boardsMu.Unlock()
	return id
}

func jsonOf(v any) []byte {
	raw, err := json.Marshal(v)
	if err != nil {
		return []byte("null")
	}
	return raw
}

func (h *boardHost) wire() {
	h.b.OnSelection = func(ids []string) {
		if h.cb.sel != 0 {
			host.CallZigPayload(host.ZigEventGraphSelect, h.cb.sel, jsonOf(ids))
		}
	}
	h.b.OnConnect = func(e graph.Edge) {
		if h.cb.connect != 0 {
			host.CallZigPayload(host.ZigEventGraphConnect, h.cb.connect, jsonOf(e))
		}
	}
	h.b.OnMove = func(id string, x, y float32) {
		if h.cb.move != 0 {
			host.CallZigPayload(host.ZigEventGraphMove, h.cb.move, jsonOf(struct {
				ID string  `json:"id"`
				X  float32 `json:"x"`
				Y  float32 `json:"y"`
			}{id, x, y}))
		}
	}
	h.b.OnDelete = func(edgeIDs, nodeIDs []string) {
		if h.cb.del != 0 {
			host.CallZigPayload(host.ZigEventGraphDelete, h.cb.del, jsonOf(struct {
				Edges []string `json:"edges"`
				Nodes []string `json:"nodes"`
			}{edgeIDs, nodeIDs}))
		}
	}
	h.b.OnViewport = func(cam graph.Camera) {
		if h.cb.viewport != 0 {
			host.CallZigPayload(host.ZigEventGraphViewport, h.cb.viewport, jsonOf(cam))
		}
	}
}

// setContent gives every node's body to Zig.
func (h *boardHost) setContent(cb uintptr) {
	h.cb.content = cb
	if cb == 0 {
		return
	}
	for i := range h.b.Nodes {
		id := h.b.Nodes[i].ID
		h.b.Nodes[i].Content = func(c *mygoui.Context) {
			handle, ok := zigui.CurrentFrame()
			if !ok {
				return
			}
			idBytes := []byte(id)
			finfo, okInfo := zigui.SubframeInfo(handle)
			if !okInfo {
				return
			}
			info := CGraphNodeInfo{
				IDPtr: uintptr(unsafe.Pointer(unsafe.SliceData(idBytes))),
				IDLen: uintptr(len(idBytes)),
				Info:  &finfo,
			}
			zigui.BindSubframe(handle, func(_ *mygoui.Context, sub uintptr) {
				host.CallZig(host.ZigEventGraphNode, cb, sub, uintptr(unsafe.Pointer(&info)), 0)
			})
			_ = c
		}
	}
}

func dispatchGraph(op, a0, a1, a2, a3 uintptr) uintptr {
	if op != host.HostOpGraph {
		return ^uintptr(0)
	}
	switch a0 {
	case opCreate:
		spec := host.PtrTo[CGraphSpec](a1)
		if spec == nil {
			return ^uintptr(0)
		}
		var b graph.Board
		raw := host.CopyBytes(spec.JSONPtr, spec.JSONLen)
		if len(raw) > 1 {
			var doc graph.Document
			if err := json.Unmarshal(raw, &doc); err != nil {
				host.SetError(err)
				return ^uintptr(0)
			}
			b.Load(doc)
		}
		applyView(&b, spec.Flags, spec.Tool, spec.SnapGrid)
		id := newBoard(&b)
		boardByID(id).wire()
		return id

	case opLoad:
		h := boardByID(a1)
		if h == nil {
			return ^uintptr(0)
		}
		var doc graph.Document
		if err := json.Unmarshal(host.CopyBytes(a2, a3), &doc); err != nil {
			host.SetError(err)
			return ^uintptr(0)
		}
		h.b.Load(doc)
		content := h.cb.content
		h.setContent(content)
		return 0

	case opExport:
		h := boardByID(a1)
		out := host.PtrTo[COut](a2)
		if h == nil || out == nil {
			return ^uintptr(0)
		}
		raw, err := h.b.MarshalJSON()
		if err != nil {
			host.SetError(err)
			return ^uintptr(0)
		}
		return host.WriteToOut(raw, out.Ptr, out.Cap)

	case opAddNode:
		h := boardByID(a1)
		spec := host.PtrTo[CGraphAdd](a2)
		if h == nil || spec == nil {
			return ^uintptr(0)
		}
		var n graph.Node
		if err := json.Unmarshal(host.CopyBytes(spec.JSONPtr, spec.JSONLen), &n); err != nil {
			host.SetError(err)
			return ^uintptr(0)
		}
		id := h.b.AddNode(n)
		h.setContent(h.cb.content)
		host.WriteToOut([]byte(id), spec.OutPtr, spec.OutCap)
		return uintptr(len(id))

	case opSelection:
		h := boardByID(a1)
		out := host.PtrTo[COut](a2)
		if h == nil || out == nil {
			return 0
		}
		return uintptr(host.WriteStrListOut(h.b.Selection, out.Ptr, out.Cap))

	case opAction:
		h := boardByID(a1)
		if h == nil {
			return 0
		}
		n := graphAction(h.b, a2)
		h.setContent(h.cb.content)
		return n

	case opView:
		h := boardByID(a2)
		if h == nil {
			return ^uintptr(0)
		}
		view := host.PtrTo[CGraphView](a3)
		ok := zigui.BindFrameElement(a1, func(c *mygoui.Context, winID int32) mygoui.Element {
			_ = winID
			if view != nil {
				applyView(h.b, view.Flags, view.Tool, view.SnapGrid)
			}
			h.setContent(h.cb.content)
			return graph.View(c, h.b)
		})
		if !ok {
			return ^uintptr(0)
		}
		return 0

	case opSetContent:
		h := boardByID(a1)
		if h == nil {
			return ^uintptr(0)
		}
		h.setContent(a2)
		return 0

	case opDestroy:
		boardsMu.Lock()
		delete(boards, a1)
		boardsMu.Unlock()
		return 0

	case opOnSelect, opOnConnect, opOnMove, opOnDelete, opOnViewport:
		h := boardByID(a1)
		if h == nil {
			return ^uintptr(0)
		}
		switch a0 {
		case opOnSelect:
			h.cb.sel = a2
		case opOnConnect:
			h.cb.connect = a2
		case opOnMove:
			h.cb.move = a2
		case opOnDelete:
			h.cb.del = a2
		case opOnViewport:
			h.cb.viewport = a2
		}
		h.wire()
		return 0
	}
	return ^uintptr(0)
}

func applyView(b *graph.Board, flags uint32, tool uint8, snap float32) {
	b.Minimap = flags&1 != 0
	if flags&2 != 0 {
		b.EdgeStyle = graph.EdgeOrthogonal
	} else {
		b.EdgeStyle = graph.EdgeBezier
	}
	switch tool {
	case 1:
		b.Tool = graph.ToolPan
	case 2:
		b.Tool = graph.ToolConnect
	default:
		b.Tool = graph.ToolSelect
	}
	b.SnapGrid = snap
}

func graphAction(b *graph.Board, kind uintptr) uintptr {
	switch kind {
	case actDelete:
		if b.RemoveSelection() {
			return 1
		}
	case actGroup:
		if b.GroupSelection() != "" {
			return 1
		}
	case actUngroup:
		if b.UngroupSelection() {
			return 1
		}
	case actLayout:
		b.AutoLayout(graph.LayoutOptions{})
		return 1
	case actFit:
		b.FitContent()
		return 1
	case actUndo:
		if b.Undo() {
			return 1
		}
	case actRedo:
		if b.Redo() {
			return 1
		}
	case actCopy:
		if b.CopySelection() {
			return 1
		}
	case actPaste:
		if b.PasteClipboard() {
			return 1
		}
	case actLock:
		if b.ToggleLockSelection() {
			return 1
		}
	case actSelectAll:
		b.SelectAll()
		return 1
	}
	return 0
}
