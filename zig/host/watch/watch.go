//go:build !js

// Package watch registers core `mygo.WatchFiles` into `zig/host`.
//
// Import with `_ "github.com/egoist/mygo/zig/host/watch"`. Events are pushed
// to Zig as JSON batches (FileEvent); Ignore callbacks are not exposed
// across FFI in this minimal binding.
package watch

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"sync"
	"sync/atomic"
	"time"

	"github.com/egoist/mygo"
	"github.com/egoist/mygo/zig/host"
)

func init() {
	host.WatchDispatch = dispatch
}

var (
	watchesMu sync.Mutex
	watches   = map[uintptr]*mygo.FileWatcher{}
	nextID    atomic.Uintptr
	callZig   host.CallZigFn
)

func dispatch(call host.CallZigFn, op, a0, a1, a2, a3 uintptr) uintptr {
	_ = a2
	_ = a3
	callZig = call
	if op != host.HostOpWatch {
		host.SetError(errors.New("zighost: unknown watch op"))
		return ^uintptr(0)
	}
	switch a0 {
	case host.WatchStart:
		return start(a1)
	case host.WatchClose:
		return closeWatch(a1)
	default:
		host.SetError(errors.New("zighost: unknown watch subop"))
		return ^uintptr(0)
	}
}

func start(specPtr uintptr) uintptr {
	spec := host.PtrTo[host.CWatchStartSpec](specPtr)
	if spec == nil {
		host.SetError(errors.New("zighost: watch.start needs spec"))
		return ^uintptr(0)
	}
	path := host.CopyString(spec.PathPtr, spec.PathLen)
	opts := mygo.FileWatchOptions{
		Recursive:  spec.Recursive != 0,
		HintsOnly:  spec.HintsOnly != 0,
		MaxEntries: int(spec.MaxEntries),
	}
	if spec.DebounceMS < 0 {
		opts.Debounce = -1
	} else if spec.DebounceMS > 0 {
		opts.Debounce = time.Duration(spec.DebounceMS) * time.Millisecond
	}
	if spec.MaxDelayMS < 0 {
		opts.MaxDelay = -1
	} else if spec.MaxDelayMS > 0 {
		opts.MaxDelay = time.Duration(spec.MaxDelayMS) * time.Millisecond
	}
	w, err := mygo.WatchFiles(context.Background(), path, opts)
	if err != nil {
		host.SetError(err)
		return ^uintptr(0)
	}
	host.SetError(nil)
	id := nextID.Add(1)
	watchesMu.Lock()
	watches[id] = w
	watchesMu.Unlock()
	cb := spec.EventCb
	go pump(id, w, cb)
	return id
}

func pump(id uintptr, w *mygo.FileWatcher, cb uintptr) {
	defer func() {
		watchesMu.Lock()
		delete(watches, id)
		watchesMu.Unlock()
		_ = w.Close()
	}()
	for {
		ev, err := w.Next(context.Background())
		if len(ev) > 0 && cb != 0 {
			raw, _ := json.Marshal(ev)
			cs := host.CStr{}
			cs.Data, cs.Len = host.SliceAddr(raw)
			callZig(host.ZigEventWatch, cb, id, host.WatchEvBatch, host.PtrOf(&cs))
		}
		if err != nil {
			if cb != 0 {
				msg := ""
				if !errors.Is(err, io.EOF) {
					msg = err.Error()
				}
				b := []byte(msg)
				cs := host.CStr{}
				cs.Data, cs.Len = host.SliceAddr(b)
				callZig(host.ZigEventWatch, cb, id, host.WatchEvDone, host.PtrOf(&cs))
			}
			return
		}
	}
}

func closeWatch(id uintptr) uintptr {
	watchesMu.Lock()
	w := watches[id]
	delete(watches, id)
	watchesMu.Unlock()
	if w != nil {
		_ = w.Close()
	}
	return 0
}
