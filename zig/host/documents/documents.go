//go:build !js

// Package documents registers a bytes-content Documents controller for Zig.
//
// Import with `_ "github.com/egoist/mygo/zig/host/documents"` before App.Run.
// Content is always []byte. Zig supplies the Window factory via ZigEventDocuments
// (kind=1 need_window → return win_id).
package documents

import (
	"bytes"
	"encoding/json"
	"errors"
	"io"
	"runtime"
	"sync"
	"sync/atomic"

	"github.com/egoist/mygo"
	"github.com/egoist/mygo/zig/host"
)

func init() {
	host.DocumentsDispatch = dispatch
}

const (
	docConfigure   = 1 // a1=*cDocConfig — call once before App.Run
	docNew         = 2 // → doc_id
	docOpen        = 3 // a1=path → doc_id
	docOpenDialog  = 4 // → JSON [doc_id,...] via out
	docList        = 5 // → JSON ids
	docContent     = 6 // a1=doc_id → bytes via out
	docSetContent  = 7 // a1=doc_id a2=ptr a3=len
	docSave        = 8
	docSaveAs      = 9 // a1=doc_id a2=path
	docSaveAnyway  = 10
	docState       = 11 // → JSON DocumentState
	docWindowID    = 12 // → win_id
	docPath        = 13 // → string out
)

const (
	docEvNeedWindow = 1 // return win_id
	docEvState      = 2 // a3=*CStr JSON state
	docEvReload     = 3
)

type cDocConfig struct {
	TypesPtr, TypesLen uintptr // JSON []DocumentType
	AutosaveOff        uint8
	AskOnQuit          uint8
	NoUntitled         uint8
	_                  byte
	WindowCb           uintptr // ZigEventDocuments cb id
	WindowUD           uintptr
}

var (
	configured atomic.Bool
	ds         *mygo.Documents[[]byte]
	callZig    host.CallZigFn
	windowCb   uintptr
	windowUD   uintptr

	mu   sync.Mutex
	docs = map[int64]*mygo.Document[[]byte]{}
	next atomic.Int64
)

func putDoc(d *mygo.Document[[]byte]) int64 {
	mu.Lock()
	defer mu.Unlock()
	for id, x := range docs {
		if x == d {
			return id
		}
	}
	id := next.Add(1)
	if id == 0 {
		id = next.Add(1)
	}
	docs[id] = d
	return id
}

func getDoc(id int64) *mygo.Document[[]byte] {
	mu.Lock()
	defer mu.Unlock()
	return docs[id]
}

func dispatch(call host.CallZigFn, op, a0, a1, a2, a3 uintptr) uintptr {
	if op != host.HostOpDocuments {
		host.SetError(errors.New("zighost: unknown documents op"))
		return ^uintptr(0)
	}
	switch a0 {
	case docConfigure:
		if configured.Load() {
			host.SetError(errors.New("zighost: documents already configured"))
			return ^uintptr(0)
		}
		spec := host.PtrTo[cDocConfig](a1)
		if spec == nil || spec.WindowCb == 0 {
			host.SetError(errors.New("zighost: documents configure needs types and window callback"))
			return ^uintptr(0)
		}
		var types []mygo.DocumentType
		if err := json.Unmarshal(host.CopyBytes(spec.TypesPtr, spec.TypesLen), &types); err != nil {
			host.SetError(err)
			return ^uintptr(0)
		}
		callZig = call
		windowCb = spec.WindowCb
		windowUD = spec.WindowUD
		opts := mygo.DocumentsOptions[[]byte]{
			Types: types,
			Read:  func(r io.Reader) ([]byte, error) { return io.ReadAll(r) },
			Write: func(w io.Writer, b []byte) error { _, err := w.Write(b); return err },
			Equal: bytes.Equal,
			New:   func() []byte { return nil },
			Window: func(doc *mygo.Document[[]byte]) *mygo.Window {
				id := putDoc(doc)
				doc.OnStateChange(func(st mygo.DocumentState) {
					raw, _ := json.Marshal(st)
					ptr, n := host.SliceAddr(raw)
					cs := host.CStr{Data: ptr, Len: n}
					callZig(host.ZigEventDocuments, windowCb, uintptr(id), docEvState, host.PtrOf(&cs))
					runtime.KeepAlive(raw)
					runtime.KeepAlive(cs)
				})
				doc.OnReload(func() {
					callZig(host.ZigEventDocuments, windowCb, uintptr(id), docEvReload, windowUD)
				})
				winID := callZig(host.ZigEventDocuments, windowCb, uintptr(id), docEvNeedWindow, windowUD)
				w := mygo.WindowByID(int(winID))
				if w == nil {
					panic("zighost: documents window callback must return a window id")
				}
				return w
			},
			AskOnQuit:  spec.AskOnQuit != 0,
			NoUntitled: spec.NoUntitled != 0,
		}
		if spec.AutosaveOff != 0 {
			opts.Autosave = mygo.AutosaveOff
		}
		ds = mygo.NewDocuments(opts)
		configured.Store(true)
		host.SetError(nil)
		return 0
	case docNew:
		if ds == nil {
			return missing()
		}
		return uintptr(putDoc(ds.New()))
	case docOpen:
		if ds == nil {
			return missing()
		}
		d, err := ds.Open(host.CopyString(a1, a2))
		if err != nil {
			host.SetError(err)
			return ^uintptr(0)
		}
		host.SetError(nil)
		return uintptr(putDoc(d))
	case docOpenDialog:
		if ds == nil {
			return missing()
		}
		opened, err := ds.OpenDialog()
		if err != nil {
			host.SetError(err)
			return ^uintptr(0)
		}
		ids := make([]int64, len(opened))
		for i, d := range opened {
			ids[i] = putDoc(d)
		}
		raw, _ := json.Marshal(ids)
		host.SetError(nil)
		return host.WriteBytesToOut(raw, a1, a2)
	case docList:
		if ds == nil {
			return missing()
		}
		var ids []int64
		mu.Lock()
		for id, d := range docs {
			if d.Window() != nil && !d.Window().IsDestroyed() {
				ids = append(ids, id)
			}
		}
		mu.Unlock()
		raw, _ := json.Marshal(ids)
		return host.WriteBytesToOut(raw, a1, a2)
	case docContent:
		d := getDoc(int64(a1))
		if d == nil {
			return notFound()
		}
		return host.WriteBytesToOut(d.Content(), a2, a3)
	case docSetContent:
		d := getDoc(int64(a1))
		if d == nil {
			return notFound()
		}
		d.Set(host.CopyBytes(a2, a3))
		return 0
	case docSave:
		d := getDoc(int64(a1))
		if d == nil {
			return notFound()
		}
		if err := d.Save(); err != nil {
			host.SetError(err)
			return ^uintptr(0)
		}
		host.SetError(nil)
		return 0
	case docSaveAs:
		d := getDoc(int64(a1))
		if d == nil {
			return notFound()
		}
		if err := d.SaveAs(host.CopyString(a2, a3)); err != nil {
			host.SetError(err)
			return ^uintptr(0)
		}
		host.SetError(nil)
		return 0
	case docSaveAnyway:
		d := getDoc(int64(a1))
		if d == nil {
			return notFound()
		}
		if err := d.SaveAnyway(); err != nil {
			host.SetError(err)
			return ^uintptr(0)
		}
		host.SetError(nil)
		return 0
	case docState:
		d := getDoc(int64(a1))
		if d == nil {
			return notFound()
		}
		raw, _ := json.Marshal(d.State())
		return host.WriteBytesToOut(raw, a2, a3)
	case docWindowID:
		d := getDoc(int64(a1))
		if d == nil || d.Window() == nil {
			return 0
		}
		return uintptr(d.Window().ID())
	case docPath:
		d := getDoc(int64(a1))
		if d == nil {
			return notFound()
		}
		return host.WriteStringToOut(d.Path(), a2, a3)
	default:
		host.SetError(errors.New("zighost: unknown documents subop"))
		return ^uintptr(0)
	}
}

func missing() uintptr {
	host.SetError(errors.New("zighost: documents not configured"))
	return ^uintptr(0)
}

func notFound() uintptr {
	host.SetError(errors.New("zighost: document not found"))
	return ^uintptr(0)
}
