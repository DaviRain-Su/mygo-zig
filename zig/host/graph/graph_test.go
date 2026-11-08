//go:build !js

package graph

import (
	"encoding/json"
	"testing"
	"unsafe"

	"github.com/egoist/mygo/zig/host"
)

func newSpec(doc string, flags uint32) *CGraphSpec {
	raw := []byte(doc)
	ptr, n := host.SliceAddr(raw)
	return &CGraphSpec{JSONPtr: ptr, JSONLen: n, Flags: flags, SnapGrid: 16}
}

func createBoard(t *testing.T, doc string) uintptr {
	t.Helper()
	spec := newSpec(doc, 1)
	id := dispatchGraph(host.HostOpGraph, opCreate, uintptr(unsafe.Pointer(spec)), 0, 0)
	if id == 0 || id == ^uintptr(0) {
		t.Fatalf("create failed: %d", id)
	}
	return id
}

func export(t *testing.T, id uintptr) map[string]any {
	t.Helper()
	buf := make([]byte, 64<<10)
	out := &COut{Ptr: uintptr(unsafe.Pointer(&buf[0])), Cap: uintptr(len(buf))}
	n := dispatchGraph(host.HostOpGraph, opExport, id, uintptr(unsafe.Pointer(out)), 0)
	if n == ^uintptr(0) || n == 0 {
		t.Fatalf("export failed: %d", n)
	}
	var doc map[string]any
	if err := json.Unmarshal(buf[:n], &doc); err != nil {
		t.Fatal(err)
	}
	return doc
}

func TestGraphCreateExport(t *testing.T) {
	doc := `{"nodes":[{"id":"a","title":"A","x":0,"y":0,"w":100,"h":50}],"edges":[]}`
	id := createBoard(t, doc)
	defer dispatchGraph(host.HostOpGraph, opDestroy, id, 0, 0)

	out := export(t, id)
	nodes, _ := out["nodes"].([]any)
	if len(nodes) != 1 {
		t.Fatalf("nodes=%v", out["nodes"])
	}
	if nodes[0].(map[string]any)["title"] != "A" {
		t.Fatalf("node=%v", nodes[0])
	}
}

func TestGraphAddNodeAndSelection(t *testing.T) {
	id := createBoard(t, `{"nodes":[],"edges":[]}`)
	defer dispatchGraph(host.HostOpGraph, opDestroy, id, 0, 0)

	raw := []byte(`{"title":"New","x":10,"y":20,"w":120,"h":80,"ports":[{"id":"in","side":0,"at":0.5}]}`)
	idBuf := make([]byte, 32)
	tptr, tn := host.SliceAddr(raw)
	add := &CGraphAdd{
		JSONPtr: tptr, JSONLen: tn,
		OutPtr: uintptr(unsafe.Pointer(&idBuf[0])), OutCap: uintptr(len(idBuf)),
	}
	if got := dispatchGraph(host.HostOpGraph, opAddNode, id, uintptr(unsafe.Pointer(add)), 0); got == ^uintptr(0) {
		t.Fatal("add failed")
	}
	out := export(t, id)
	if nodes, _ := out["nodes"].([]any); len(nodes) != 1 {
		t.Fatalf("nodes=%v", out["nodes"])
	}

	// Select all, then read the selection back.
	if got := dispatchGraph(host.HostOpGraph, opAction, id, actSelectAll, 0); got != 1 {
		t.Fatalf("select all = %d", got)
	}
	selBuf := make([]byte, 256)
	selOut := &COut{Ptr: uintptr(unsafe.Pointer(&selBuf[0])), Cap: uintptr(len(selBuf))}
	if got := dispatchGraph(host.HostOpGraph, opSelection, id, uintptr(unsafe.Pointer(selOut)), 0); got != 1 {
		t.Fatalf("selection count = %d", got)
	}
}

func TestGraphLoadReplacesDocument(t *testing.T) {
	id := createBoard(t, `{"nodes":[{"id":"a","title":"A","x":0,"y":0,"w":10,"h":10}],"edges":[]}`)
	defer dispatchGraph(host.HostOpGraph, opDestroy, id, 0, 0)

	raw := []byte(`{"nodes":[{"id":"b","title":"B","x":0,"y":0,"w":10,"h":10},{"id":"c","title":"C","x":20,"y":0,"w":10,"h":10}],"edges":[]}`)
	ptr, n := host.SliceAddr(raw)
	if got := dispatchGraph(host.HostOpGraph, opLoad, id, ptr, n); got != 0 {
		t.Fatalf("load = %d", got)
	}
	out := export(t, id)
	if nodes, _ := out["nodes"].([]any); len(nodes) != 2 {
		t.Fatalf("nodes=%v", out["nodes"])
	}
}

func TestGraphActionsUndoRedo(t *testing.T) {
	id := createBoard(t, `{"nodes":[{"id":"a","title":"A","x":40,"y":0,"w":40,"h":40},{"id":"b","title":"B","x":0,"y":0,"w":40,"h":40}],"edges":[]}`)
	defer dispatchGraph(host.HostOpGraph, opDestroy, id, 0, 0)

	dispatchGraph(host.HostOpGraph, opAction, id, actSelectAll, 0)
	dispatchGraph(host.HostOpGraph, opAction, id, actLayout, 0)
	if got := dispatchGraph(host.HostOpGraph, opAction, id, actUndo, 0); got != 1 {
		t.Fatalf("undo = %d", got)
	}
	if got := dispatchGraph(host.HostOpGraph, opAction, id, actRedo, 0); got != 1 {
		t.Fatalf("redo = %d", got)
	}
}
