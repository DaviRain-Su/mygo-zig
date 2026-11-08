//go:build !js

// Package terminal registers the official `plugins/terminal` emulator into
// `zig/host` (Ghostty libghostty-vt, no cgo).
//
// Import with `_ "github.com/egoist/mygo/zig/host/terminal"` in Zig apps that
// embed a terminal. `mygo build` / `mygo dev` pick up `mygo-plugin.json` and
// ship libghostty-vt among the app resources.
package terminal

import (
	"errors"
	"strings"
	"sync"
	"sync/atomic"

	plug "github.com/egoist/mygo/plugins/terminal"
	mygoui "github.com/egoist/mygo/ui"
	"github.com/egoist/mygo/zig/host"
	zigui "github.com/egoist/mygo/zig/host/ui"
)

func init() {
	host.TerminalDispatch = dispatch
}

var (
	termsMu sync.Mutex
	terms   = map[uintptr]*plug.Terminal{}
	nextID  atomic.Uintptr
	callZig host.CallZigFn
)

func dispatch(call host.CallZigFn, op, a0, a1, a2, a3 uintptr) uintptr {
	callZig = call
	switch op {
	case host.HostOpTerminalView:
		return view(a0, a1)
	case host.HostOpTerminal:
		return lifecycle(a0, a1, a2, a3)
	default:
		host.SetError(errors.New("zighost: unknown terminal op"))
		return ^uintptr(0)
	}
}

func view(frameHandle, id uintptr) uintptr {
	term := get(id)
	if term == nil {
		host.SetError(errors.New("zighost: unknown terminal id"))
		return ^uintptr(0)
	}
	ok := zigui.BindFrameElement(frameHandle, func(c *mygoui.Context, _ int32) mygoui.Element {
		return plug.View(c, term)
	})
	if !ok {
		return ^uintptr(0)
	}
	return 0
}

func lifecycle(sub, a1, a2, a3 uintptr) uintptr {
	switch sub {
	case host.TermNew:
		return termNew(a1)
	case host.TermClose:
		return termClose(a1)
	case host.TermPaste:
		if t := get(a1); t != nil {
			t.Paste(host.CopyString(a2, a3))
		}
		return 0
	case host.TermSend:
		if t := get(a1); t != nil {
			t.Send(host.CopyBytes(a2, a3))
		}
		return 0
	case host.TermUseTheme:
		return termTheme(a1, a2, a3)
	case host.TermResize:
		if t := get(a1); t != nil {
			t.Resize(int(a2), int(a3))
		}
		return 0
	case host.TermTitle:
		if t := get(a1); t != nil {
			return host.WriteStringToOut(t.Title(), a2, a3)
		}
		return 0
	case host.TermDir:
		if t := get(a1); t != nil {
			return host.WriteStringToOut(t.Dir(), a2, a3)
		}
		return 0
	case host.TermExitCode:
		t := get(a1)
		if t == nil {
			return ^uintptr(0)
		}
		select {
		case <-t.Done():
			return uintptr(t.ExitCode())
		default:
			return ^uintptr(0) // still running
		}
	case host.TermClear:
		if t := get(a1); t != nil {
			_ = t.ClearScreen()
		}
		return 0
	case host.TermSearch:
		t := get(a1)
		if t == nil {
			return 0
		}
		q := host.CopyString(a2, a3)
		if q == "" {
			t.EndSearch()
		} else {
			t.Search(q)
		}
		return 0
	default:
		host.SetError(errors.New("zighost: unknown terminal subop"))
		return ^uintptr(0)
	}
}

func termNew(specPtr uintptr) uintptr {
	spec := host.PtrTo[host.CTerminalNewSpec](specPtr)
	if spec == nil {
		host.SetError(errors.New("zighost: terminal.new needs spec"))
		return ^uintptr(0)
	}
	opts := plug.Options{
		Command:          splitNUL(host.CopyString(spec.CommandPtr, spec.CommandLen)),
		Dir:              host.CopyString(spec.DirPtr, spec.DirLen),
		ShellIntegration: spec.ShellIntegration != 0,
		Transparent:      spec.Transparent != 0,
	}
	id := nextID.Add(1)
	if spec.TitleCb != 0 {
		cb := spec.TitleCb
		opts.OnTitle = func(title string) {
			cs := host.CStr{}
			b := []byte(title)
			cs.Data, cs.Len = host.SliceAddr(b)
			callZig(host.ZigEventTerminal, cb, id, host.TermEvTitle, host.PtrOf(&cs))
		}
	}
	if spec.ExitCb != 0 {
		cb := spec.ExitCb
		opts.OnExit = func(code int) {
			callZig(host.ZigEventTerminal, cb, id, host.TermEvExit, uintptr(code))
		}
	}
	if spec.BellCb != 0 {
		cb := spec.BellCb
		opts.OnBell = func() {
			callZig(host.ZigEventTerminal, cb, id, host.TermEvBell, 0)
		}
	}
	term, err := plug.New(opts)
	if err != nil {
		host.SetError(err)
		return ^uintptr(0)
	}
	host.SetError(nil)
	termsMu.Lock()
	terms[id] = term
	termsMu.Unlock()
	return id
}

func termClose(id uintptr) uintptr {
	termsMu.Lock()
	t := terms[id]
	delete(terms, id)
	termsMu.Unlock()
	if t != nil {
		_ = t.Close()
	}
	return 0
}

func termTheme(id, kind, nameSpec uintptr) uintptr {
	t := get(id)
	if t == nil {
		return 0
	}
	var theme *plug.Theme
	switch kind {
	case 0:
		theme = plug.DarkTheme()
	case 1:
		theme = plug.LightTheme()
	default:
		name := ""
		if cs := host.PtrTo[host.CStr](nameSpec); cs != nil {
			name = host.StrField(*cs)
		}
		var err error
		theme, err = plug.GhosttyTheme(name)
		if err != nil {
			host.SetError(err)
			return ^uintptr(0)
		}
		host.SetError(nil)
	}
	t.UseTheme(theme)
	return 0
}

func get(id uintptr) *plug.Terminal {
	termsMu.Lock()
	defer termsMu.Unlock()
	return terms[id]
}

func splitNUL(s string) []string {
	if s == "" {
		return nil
	}
	parts := strings.Split(s, "\x00")
	out := parts[:0]
	for _, p := range parts {
		if p != "" {
			out = append(out, p)
		}
	}
	if len(out) == 0 {
		return nil
	}
	return out
}
