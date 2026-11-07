//go:build mygo_ffi && cgo && !js

package main

/*
#define MYGO_BUILDING_FFI 1
#include "include/mygo.h"

static inline void mygo_call_ready(mygo_ready_fn fn, uintptr_t userdata) {
	if (fn != NULL) {
		fn((void*)userdata);
	}
}

static inline void mygo_call_ipc(
	mygo_ipc_fn fn,
	int32_t caller_window_id,
	mygo_chars_t args_json,
	size_t args_len,
	uintptr_t reply,
	uintptr_t userdata
) {
	fn(caller_window_id, args_json, args_len, reply, (void*)userdata);
}
*/
import "C"

import (
	"context"
	"errors"
	"fmt"
	"runtime"
	"sync"
	"sync/atomic"
	"unsafe"

	"github.com/egoist/mygo"
)

var (
	lastErrMu sync.Mutex
	lastErr   string
)

func setError(err error) {
	lastErrMu.Lock()
	if err == nil {
		lastErr = ""
	} else {
		lastErr = err.Error()
	}
	lastErrMu.Unlock()
}

func goString(ptr C.mygo_chars_t, n C.size_t) string {
	if ptr == nil || n == 0 {
		return ""
	}
	return C.GoStringN(ptr, C.int(n))
}

func goBytes(ptr C.mygo_chars_t, n C.size_t) []byte {
	if ptr == nil || n == 0 {
		return nil
	}
	return C.GoBytes(unsafe.Pointer(ptr), C.int(n))
}

func strFromField(s C.mygo_str_t) string {
	return goString(s.data, s.len)
}

//export mygo_last_error
func mygo_last_error(buf *C.char, cap C.size_t) C.size_t {
	lastErrMu.Lock()
	msg := lastErr
	lastErrMu.Unlock()
	if buf != nil && cap > 0 && len(msg) > 0 {
		n := min(len(msg), int(cap))
		dst := unsafe.Slice((*byte)(unsafe.Pointer(buf)), n)
		copy(dst, msg[:n])
	}
	return C.size_t(len(msg))
}

//export mygo_app_set_name
func mygo_app_set_name(namePtr C.mygo_chars_t, nameLen C.size_t) {
	mygo.App.SetName(goString(namePtr, nameLen))
}

//export mygo_app_run
func mygo_app_run(onReady C.mygo_ready_fn, userdata unsafe.Pointer) C.int32_t {
	// Lock the calling OS main thread to this goroutine for Cocoa/GTK/Win32.
	runtime.LockOSThread()
	mygo.FFIClaimMainThread()

	ud := C.uintptr_t(uintptr(userdata))
	if onReady != nil {
		mygo.App.WhenReady(func() {
			C.mygo_call_ready(onReady, ud)
		})
	}
	if err := mygo.App.Run(); err != nil {
		setError(err)
		return -1
	}
	setError(nil)
	return 0
}

//export mygo_app_quit
func mygo_app_quit() {
	mygo.App.Quit()
}

//export mygo_window_new
func mygo_window_new(opts C.mygo_window_options_ptr_t) (winID C.int32_t) {
	defer func() {
		if r := recover(); r != nil {
			setError(fmt.Errorf("%v", r))
			winID = 0
		}
	}()
	var o mygo.WindowOptions
	if opts != nil {
		o = mygo.WindowOptions{
			Title:           strFromField(opts.title),
			URL:             strFromField(opts.url),
			BackgroundColor: strFromField(opts.background_color),
			Width:           int(opts.width),
			Height:          int(opts.height),
			MinWidth:        int(opts.min_width),
			MinHeight:       int(opts.min_height),
			MaxWidth:        int(opts.max_width),
			MaxHeight:       int(opts.max_height),
			UseContentSize:  opts.use_content_size != 0,
			Hidden:          opts.hidden != 0,
			Frameless:       opts.frameless != 0,
			DisableResize:   opts.disable_resize != 0,
			AlwaysOnTop:     opts.always_on_top != 0,
			Transparent:     opts.transparent != 0,
			Page: mygo.PageOptions{
				DevTools: mygo.DevTools(opts.devtools),
			},
		}
	}
	w := mygo.NewWindow(o)
	if w == nil {
		setError(errors.New("mygo: failed to create window"))
		return 0
	}
	setError(nil)
	return C.int32_t(w.ID())
}

//export mygo_window_set_title
func mygo_window_set_title(winID C.int32_t, titlePtr C.mygo_chars_t, titleLen C.size_t) {
	if w := mygo.WindowByID(int(winID)); w != nil {
		w.SetTitle(goString(titlePtr, titleLen))
	}
}

//export mygo_window_show
func mygo_window_show(winID C.int32_t) {
	if w := mygo.WindowByID(int(winID)); w != nil {
		w.Show()
	}
}

//export mygo_window_close
func mygo_window_close(winID C.int32_t) {
	if w := mygo.WindowByID(int(winID)); w != nil {
		w.Close()
	}
}

//export mygo_page_load_url
func mygo_page_load_url(winID C.int32_t, urlPtr C.mygo_chars_t, urlLen C.size_t) C.int32_t {
	w := mygo.WindowByID(int(winID))
	if w == nil || w.Page() == nil {
		setError(errors.New("mygo: window not found or has no page"))
		return -1
	}
	if err := w.Page().LoadURL(goString(urlPtr, urlLen)); err != nil {
		setError(err)
		return -1
	}
	setError(nil)
	return 0
}

//export mygo_page_load_html
func mygo_page_load_html(
	winID C.int32_t,
	htmlPtr C.mygo_chars_t,
	htmlLen C.size_t,
	baseURLPtr C.mygo_chars_t,
	baseURLLen C.size_t,
) {
	w := mygo.WindowByID(int(winID))
	if w == nil || w.Page() == nil {
		return
	}
	w.Page().LoadHTML(goString(htmlPtr, htmlLen), goString(baseURLPtr, baseURLLen))
}

type replyState struct {
	mu       sync.Mutex
	deferred bool
	done     bool
	out      []byte
	err      error
	ch       chan struct{}
}

var (
	nextReplyID atomic.Uintptr
	repliesMu   sync.Mutex
	replies     = map[uintptr]*replyState{}
)

func putReply(st *replyState) uintptr {
	id := nextReplyID.Add(1)
	if id == 0 {
		id = nextReplyID.Add(1)
	}
	repliesMu.Lock()
	replies[id] = st
	repliesMu.Unlock()
	return id
}

func getReply(id uintptr) *replyState {
	repliesMu.Lock()
	st := replies[id]
	repliesMu.Unlock()
	return st
}

func takeReply(id uintptr) *replyState {
	repliesMu.Lock()
	st := replies[id]
	delete(replies, id)
	repliesMu.Unlock()
	return st
}

//export mygo_ipc_defer
func mygo_ipc_defer(reply C.uintptr_t) {
	st := getReply(uintptr(reply))
	if st == nil {
		return
	}
	st.mu.Lock()
	if !st.done && !st.deferred {
		st.deferred = true
		st.ch = make(chan struct{})
	}
	st.mu.Unlock()
}

//export mygo_ipc_resolve
func mygo_ipc_resolve(reply C.uintptr_t, jsonPtr C.mygo_chars_t, jsonLen C.size_t) {
	st := takeReply(uintptr(reply))
	if st == nil {
		return
	}
	data := goBytes(jsonPtr, jsonLen)
	st.mu.Lock()
	if !st.done {
		st.done = true
		st.out = data
		if st.ch != nil {
			close(st.ch)
		}
	}
	st.mu.Unlock()
}

//export mygo_ipc_reject
func mygo_ipc_reject(reply C.uintptr_t, errPtr C.mygo_chars_t, errLen C.size_t) {
	st := takeReply(uintptr(reply))
	if st == nil {
		return
	}
	msg := goString(errPtr, errLen)
	if msg == "" {
		msg = "ipc call rejected"
	}
	st.mu.Lock()
	if !st.done {
		st.done = true
		st.err = errors.New(msg)
		if st.ch != nil {
			close(st.ch)
		}
	}
	st.mu.Unlock()
}

//export mygo_bind_raw
func mygo_bind_raw(
	methodPtr C.mygo_chars_t,
	methodLen C.size_t,
	callback C.mygo_ipc_fn,
	userdata unsafe.Pointer,
) C.int32_t {
	if callback == nil {
		setError(errors.New("mygo: callback cannot be NULL"))
		return -1
	}
	name := goString(methodPtr, methodLen)
	ud := C.uintptr_t(uintptr(userdata))
	err := mygo.FFIBindRaw(name, func(ctx context.Context, argsJSON []byte) ([]byte, error) {
		var winID int32
		if w := mygo.CallerWindow(ctx); w != nil {
			winID = int32(w.ID())
		}
		st := &replyState{}
		id := putReply(st)

		var argsPtr C.mygo_chars_t
		if len(argsJSON) > 0 {
			argsPtr = C.mygo_chars_t(unsafe.Pointer(unsafe.SliceData(argsJSON)))
		}
		C.mygo_call_ipc(callback, C.int32_t(winID), argsPtr, C.size_t(len(argsJSON)), C.uintptr_t(id), ud)

		st.mu.Lock()
		if st.done {
			out, err := st.out, st.err
			st.mu.Unlock()
			return out, err
		}
		if !st.deferred {
			st.done = true
			st.mu.Unlock()
			takeReply(id)
			return []byte("null"), nil
		}
		ch := st.ch
		st.mu.Unlock()

		select {
		case <-ch:
			st.mu.Lock()
			out, err := st.out, st.err
			st.mu.Unlock()
			return out, err
		case <-ctx.Done():
			takeReply(id)
			return nil, ctx.Err()
		}
	})
	if err != nil {
		setError(err)
		return -1
	}
	setError(nil)
	return 0
}

//export mygo_emit_raw
func mygo_emit_raw(
	winID C.int32_t,
	eventPtr C.mygo_chars_t,
	eventLen C.size_t,
	jsonPtr C.mygo_chars_t,
	jsonLen C.size_t,
) C.int32_t {
	var w *mygo.Window
	if winID != 0 {
		w = mygo.WindowByID(int(winID))
		if w == nil {
			setError(errors.New("mygo: window not found"))
			return -1
		}
	}
	err := mygo.FFIEmitRaw(w, goString(eventPtr, eventLen), goBytes(jsonPtr, jsonLen))
	if err != nil {
		setError(err)
		return -1
	}
	setError(nil)
	return 0
}

func main() {}
