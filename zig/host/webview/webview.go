//go:build !js

// Package webview registers first-class mygo.WebView handles for Zig.
//
// Import with `_ "github.com/egoist/mygo/zig/host/webview"`.
// Place with `ui.webViewHandle(id)` (also registered here via UI opcode extension).
package webview

import (
	"encoding/json"
	"errors"
	"sync"
	"sync/atomic"

	"github.com/egoist/mygo"
	"github.com/egoist/mygo/zig/host"
	zigui "github.com/egoist/mygo/zig/host/ui"
)

func init() {
	host.WebViewDispatch = dispatch
	zigui.RegisterWebViewResolver(resolve)
}

var (
	nextID atomic.Int64
	mu     sync.Mutex
	views  = map[int64]*mygo.WebView{}
)

const (
	wvCreate             = 1 // a1=parent_win_id a2=*cWebViewSpec → id
	wvDestroy            = 2 // a1=id
	wvFocus              = 3
	wvIsDestroyed        = 4 // → 1/0
	wvSetBackgroundColor = 5 // a1=id a2=color_ptr a3=color_len
	wvCapturePage        = 6 // a1=id a2=out a3=cap → n
	wvPageWindowID       = 7 // → internal page window id for WinCtl/page ops
	wvParentWindowID     = 8 // → host window id
)

type cWebViewSpec struct {
	URLPtr, URLLen                 uintptr
	BackgroundPtr, BackgroundLen   uintptr
	Transparent                    uint8
	ScrollToContainer              uint8
	DevTools                       int8 // -1 default, 0 off, 1 on
	Untrusted                      uint8
	PreloadAllFrames               uint8
	SafariTabFocus                 uint8
	PictureInPicture               uint8
	SwipeNavigation                uint8
	PinchZoom                      uint8
	_pad                           uint8
	ZoomFactor                     float64 // 0 = default
	SessionNamePtr, SessionNameLen uintptr
	PreloadPtr, PreloadLen         uintptr
	UserAgentPtr, UserAgentLen     uintptr
	UASuffixPtr, UASuffixLen       uintptr
	TrustedPtr, TrustedLen         uintptr // JSON []string
}

func resolve(id int64) *mygo.WebView {
	mu.Lock()
	defer mu.Unlock()
	return views[id]
}

func dispatch(op, a0, a1, a2, a3 uintptr) uintptr {
	if op != host.HostOpWebView {
		host.SetError(errors.New("zighost: unknown webview op"))
		return ^uintptr(0)
	}
	switch a0 {
	case wvCreate:
		parent := mygo.WindowByID(int(a1))
		if parent == nil {
			host.SetError(errors.New("zighost: webview parent window not found"))
			return ^uintptr(0)
		}
		spec := host.PtrTo[cWebViewSpec](a2)
		if spec == nil {
			host.SetError(errors.New("zighost: webview needs spec"))
			return ^uintptr(0)
		}
		opts := mygo.WebViewOptions{
			URL:               host.CopyString(spec.URLPtr, spec.URLLen),
			BackgroundColor:   host.CopyString(spec.BackgroundPtr, spec.BackgroundLen),
			Transparent:       spec.Transparent != 0,
			ScrollToContainer: spec.ScrollToContainer != 0,
			Page: mygo.PageOptions{
				DevTools:          mygo.DevTools(spec.DevTools),
				Untrusted:         spec.Untrusted != 0,
				PreloadScript:     host.CopyString(spec.PreloadPtr, spec.PreloadLen),
				PreloadAllFrames:  spec.PreloadAllFrames != 0,
				UserAgent:         host.CopyString(spec.UserAgentPtr, spec.UserAgentLen),
				UserAgentSuffix:   host.CopyString(spec.UASuffixPtr, spec.UASuffixLen),
				SafariTabFocus:    spec.SafariTabFocus != 0,
				PictureInPicture:  spec.PictureInPicture != 0,
				SwipeNavigation:   spec.SwipeNavigation != 0,
				PinchZoom:         spec.PinchZoom != 0,
				ZoomFactor:        spec.ZoomFactor,
			},
		}
		if name := host.CopyString(spec.SessionNamePtr, spec.SessionNameLen); name != "" {
			opts.Page.Session = mygo.NewSession(name)
		}
		if raw := host.CopyBytes(spec.TrustedPtr, spec.TrustedLen); len(raw) > 0 {
			var origins []string
			if err := json.Unmarshal(raw, &origins); err != nil {
				host.SetError(err)
				return ^uintptr(0)
			}
			opts.Page.TrustedOrigins = origins
		}
		v, err := parent.NewWebView(opts)
		if err != nil {
			host.SetError(err)
			return ^uintptr(0)
		}
		id := nextID.Add(1)
		if id == 0 {
			id = nextID.Add(1)
		}
		mu.Lock()
		views[id] = v
		mu.Unlock()
		host.SetError(nil)
		return uintptr(id)
	case wvDestroy:
		mu.Lock()
		v := views[int64(a1)]
		delete(views, int64(a1))
		mu.Unlock()
		if v != nil {
			v.Destroy()
		}
		return 0
	case wvFocus:
		if v := resolve(int64(a1)); v != nil {
			v.Focus()
		}
		return 0
	case wvIsDestroyed:
		v := resolve(int64(a1))
		if v == nil || v.IsDestroyed() {
			return 1
		}
		return 0
	case wvSetBackgroundColor:
		v := resolve(int64(a1))
		if v == nil {
			host.SetError(errors.New("zighost: webview not found"))
			return ^uintptr(0)
		}
		if err := v.SetBackgroundColor(host.CopyString(a2, a3)); err != nil {
			host.SetError(err)
			return ^uintptr(0)
		}
		host.SetError(nil)
		return 0
	case wvCapturePage:
		v := resolve(int64(a1))
		if v == nil {
			host.SetError(errors.New("zighost: webview not found"))
			return ^uintptr(0)
		}
		png, err := v.CapturePage()
		if err != nil {
			host.SetError(err)
			return ^uintptr(0)
		}
		host.SetError(nil)
		return host.WriteBytesToOut(png, a2, a3)
	case wvPageWindowID:
		v := resolve(int64(a1))
		if v == nil {
			return 0
		}
		return uintptr(v.ID())
	case wvParentWindowID:
		v := resolve(int64(a1))
		if v == nil || v.Window() == nil {
			return 0
		}
		return uintptr(v.Window().ID())
	default:
		host.SetError(errors.New("zighost: unknown webview subop"))
		return ^uintptr(0)
	}
}
