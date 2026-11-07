//go:build mygo_ffi && mygo_ffi_ui && cgo && !js

package main

/*
#define MYGO_BUILDING_FFI 1
#include <stdlib.h>
#include "include/mygo.h"

static inline void mygo_call_ui_view(
	mygo_ui_view_fn fn,
	uintptr_t frame_handle,
	const mygo_ui_frame_t* info,
	uintptr_t userdata
) {
	if (fn != NULL) {
		fn(frame_handle, info, (void*)userdata);
	}
}
*/
import "C"

import (
	"encoding/binary"
	"errors"
	"fmt"
	"math"
	"unsafe"

	"github.com/egoist/mygo"
	"github.com/egoist/mygo/ui"
)

type uiHost struct {
	winID    int32
	viewFn   C.mygo_ui_view_fn
	userdata C.uintptr_t
	cTextBuf *C.char
	cTextCap int
}

func (h *uiHost) setCText(s string) (C.mygo_chars_t, C.size_t) {
	n := len(s)
	if n == 0 {
		return nil, 0
	}
	if n > h.cTextCap {
		newCap := max(256, n*2)
		ptr := C.realloc(unsafe.Pointer(h.cTextBuf), C.size_t(newCap))
		if ptr == nil {
			return nil, 0
		}
		h.cTextBuf = (*C.char)(ptr)
		h.cTextCap = newCap
	}
	dst := unsafe.Slice((*byte)(unsafe.Pointer(h.cTextBuf)), n)
	copy(dst, s)
	return C.mygo_chars_t(h.cTextBuf), C.size_t(n)
}

func (h *uiHost) free() {
	if h.cTextBuf != nil {
		C.free(unsafe.Pointer(h.cTextBuf))
		h.cTextBuf = nil
		h.cTextCap = 0
	}
}

type uiFrame struct {
	ctx    *ui.Context
	cur    ui.Element
	scopes []ui.FFIScope
	host   *uiHost
}

// Main-thread stack of active UI frames (supports nested frames if a modal pumps).
var activeFrames []*uiFrame

func packColor(c ui.Color) C.mygo_ui_color_t {
	return C.mygo_ui_color_t(uint32(c.R)<<24 | uint32(c.G)<<16 | uint32(c.B)<<8 | uint32(c.A))
}

func unpackColor(v uint32) ui.Color {
	return ui.Color{
		R: uint8(v >> 24),
		G: uint8(v >> 16),
		B: uint8(v >> 8),
		A: uint8(v),
	}
}

//export mygo_window_new_ui
func mygo_window_new_ui(
	opts C.mygo_window_options_ptr_t,
	view C.mygo_ui_view_fn,
	userdata unsafe.Pointer,
) (winID C.int32_t) {
	if view == nil {
		setError(errors.New("mygo: UI view callback cannot be NULL"))
		return 0
	}
	defer func() {
		if r := recover(); r != nil {
			setError(fmt.Errorf("%v", r))
			winID = 0
		}
	}()

	host := &uiHost{
		viewFn:   view,
		userdata: C.uintptr_t(uintptr(userdata)),
	}

	var o mygo.WindowOptions
	if opts != nil {
		o = mygo.WindowOptions{
			Title:           strFromField(opts.title),
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

	o.Content = ui.View(func(c *ui.Context) {
		w, h := c.Size()
		t := c.Theme()
		var dark, active C.uint8_t
		if t.Dark {
			dark = 1
		}
		if c.WindowActive() {
			active = 1
		}
		info := C.mygo_ui_frame_t{
			window_id:     C.int32_t(host.winID),
			width:         C.float(w),
			height:        C.float(h),
			window_active: active,
			theme: C.mygo_ui_theme_t{
				dark:            dark,
				background:      packColor(t.Background),
				surface:         packColor(t.Surface),
				surface_hover:   packColor(t.SurfaceHover),
				surface_pressed: packColor(t.SurfacePressed),
				border:          packColor(t.Border),
				text:            packColor(t.Text),
				text_muted:      packColor(t.TextMuted),
				accent:          packColor(t.Accent),
				accent_text:     packColor(t.AccentText),
				danger:          packColor(t.Danger),
				warning:         packColor(t.Warning),
				success:         packColor(t.Success),
				radius:          C.float(t.Radius),
				spacing:         C.float(t.Spacing),
				font_size:       C.float(t.FontSize),
			},
		}

		frame := &uiFrame{ctx: c, host: host}
		activeFrames = append(activeFrames, frame)
		handle := C.uintptr_t(len(activeFrames))

		C.mygo_call_ui_view(host.viewFn, handle, &info, host.userdata)

		// Unwind any unpopped scopes safely if host returned early.
		for i := len(frame.scopes) - 1; i >= 0; i-- {
			ui.FFIPopParent(c, frame.scopes[i])
		}
		activeFrames[len(activeFrames)-1] = nil
		activeFrames = activeFrames[:len(activeFrames)-1]
	})

	w := mygo.NewWindow(o)
	if w == nil {
		host.free()
		setError(errors.New("mygo: failed to create UI window"))
		return 0
	}
	host.winID = int32(w.ID())
	w.OnClosed(func() {
		host.free()
	})
	setError(nil)
	return C.int32_t(host.winID)
}

type tapeReader struct {
	b []byte
	i int
}

func (r *tapeReader) u8() (uint8, bool) {
	if r.i >= len(r.b) {
		return 0, false
	}
	v := r.b[r.i]
	r.i++
	return v, true
}

func (r *tapeReader) u16() (uint16, bool) {
	if r.i+2 > len(r.b) {
		return 0, false
	}
	v := binary.LittleEndian.Uint16(r.b[r.i : r.i+2])
	r.i += 2
	return v, true
}

func (r *tapeReader) u32() (uint32, bool) {
	if r.i+4 > len(r.b) {
		return 0, false
	}
	v := binary.LittleEndian.Uint32(r.b[r.i : r.i+4])
	r.i += 4
	return v, true
}

func (r *tapeReader) f32() (float32, bool) {
	bits, ok := r.u32()
	if !ok {
		return 0, false
	}
	return math.Float32frombits(bits), true
}

func (r *tapeReader) f64() (float64, bool) {
	if r.i+8 > len(r.b) {
		return 0, false
	}
	bits := binary.LittleEndian.Uint64(r.b[r.i : r.i+8])
	r.i += 8
	return math.Float64frombits(bits), true
}

func (r *tapeReader) str() (string, bool) {
	n, ok := r.u32()
	if !ok || r.i+int(n) > len(r.b) {
		return "", false
	}
	s := string(r.b[r.i : r.i+int(n)])
	r.i += int(n)
	return s, true
}

func keyedCtx(c *ui.Context, key string) *ui.Context {
	if key != "" {
		return c.Key(key)
	}
	return c
}

func cBool(b bool) C.uint8_t {
	if b {
		return 1
	}
	return 0
}

//export mygo_ui_flush
func mygo_ui_flush(
	frameHandle C.uintptr_t,
	cmdPtr C.mygo_bytes_ptr_t,
	cmdLen C.size_t,
	out *C.mygo_ui_query_t,
) {
	idx := int(frameHandle) - 1
	if idx < 0 || idx >= len(activeFrames) {
		return
	}
	f := activeFrames[idx]
	if f == nil || cmdPtr == nil || cmdLen == 0 {
		return
	}
	if out != nil {
		*out = C.mygo_ui_query_t{}
	}

	c := f.ctx
	r := tapeReader{b: unsafe.Slice((*byte)(unsafe.Pointer(cmdPtr)), int(cmdLen))}

	for {
		op, ok := r.u8()
		if !ok {
			break
		}
		switch op {
		case C.MYGO_UI_OP_COLUMN:
			key, ok := r.str()
			if !ok {
				return
			}
			f.cur = ui.Column(keyedCtx(c, key))
		case C.MYGO_UI_OP_ROW:
			key, ok := r.str()
			if !ok {
				return
			}
			f.cur = ui.Row(keyedCtx(c, key))
		case C.MYGO_UI_OP_SCROLL:
			key, ok := r.str()
			if !ok {
				return
			}
			f.cur = ui.Scroll(keyedCtx(c, key))
		case C.MYGO_UI_OP_SPACER:
			f.cur = ui.Spacer(c)
		case C.MYGO_UI_OP_DIVIDER:
			f.cur = ui.Divider(c)
		case C.MYGO_UI_OP_TEXT:
			s, ok := r.str()
			if !ok {
				return
			}
			f.cur = ui.Text(c, s)
		case C.MYGO_UI_OP_BUTTON:
			key, ok1 := r.str()
			label, ok2 := r.str()
			if !ok1 || !ok2 {
				return
			}
			f.cur = ui.Button(keyedCtx(c, key), label)
		case C.MYGO_UI_OP_PRIMARY_BUTTON:
			key, ok1 := r.str()
			label, ok2 := r.str()
			if !ok1 || !ok2 {
				return
			}
			f.cur = ui.PrimaryButton(keyedCtx(c, key), label)
		case C.MYGO_UI_OP_CHECKBOX:
			key, ok1 := r.str()
			checkedByte, ok2 := r.u8()
			label, ok3 := r.str()
			if !ok1 || !ok2 || !ok3 {
				return
			}
			val := checkedByte != 0
			f.cur = ui.Checkbox(keyedCtx(c, key), &val, label)
			if out != nil {
				out.bool_val = cBool(val)
			}
		case C.MYGO_UI_OP_TOGGLE:
			key, ok1 := r.str()
			onByte, ok2 := r.u8()
			label, ok3 := r.str()
			if !ok1 || !ok2 || !ok3 {
				return
			}
			val := onByte != 0
			f.cur = ui.Toggle(keyedCtx(c, key), &val, label)
			if out != nil {
				out.bool_val = cBool(val)
			}
		case C.MYGO_UI_OP_SWITCH:
			key, ok1 := r.str()
			onByte, ok2 := r.u8()
			if !ok1 || !ok2 {
				return
			}
			val := onByte != 0
			f.cur = ui.Switch(keyedCtx(c, key), &val)
			if out != nil {
				out.bool_val = cBool(val)
			}
		case C.MYGO_UI_OP_SLIDER:
			key, ok1 := r.str()
			val, ok2 := r.f64()
			lo, ok3 := r.f64()
			hi, ok4 := r.f64()
			if !ok1 || !ok2 || !ok3 || !ok4 {
				return
			}
			f.cur = ui.Slider(keyedCtx(c, key), &val, lo, hi)
			if out != nil {
				out.num_val = C.double(val)
				out.bool_val = cBool(f.cur.Changed())
			}
		case C.MYGO_UI_OP_TEXT_INPUT:
			key, ok1 := r.str()
			val, ok2 := r.str()
			if !ok1 || !ok2 {
				return
			}
			curText := val
			f.cur = ui.TextInput(keyedCtx(c, key), &curText)
			if out != nil && (curText != val || f.cur.Changed()) {
				out.bool_val = 1
				out.text_ptr, out.text_len = f.host.setCText(curText)
			}

		case C.MYGO_UI_OP_PUSH_PARENT:
			if sc, ok := ui.FFIPushParent(c, f.cur); ok {
				f.scopes = append(f.scopes, sc)
			}
		case C.MYGO_UI_OP_POP_PARENT:
			if n := len(f.scopes); n > 0 {
				sc := f.scopes[n-1]
				f.scopes = f.scopes[:n-1]
				ui.FFIPopParent(c, sc)
			}

		case C.MYGO_UI_OP_FILL:
			f.cur = f.cur.Fill()
		case C.MYGO_UI_OP_FILL_WIDTH:
			f.cur = f.cur.FillWidth()
		case C.MYGO_UI_OP_FILL_HEIGHT:
			f.cur = f.cur.FillHeight()
		case C.MYGO_UI_OP_GROW:
			v, ok := r.f32()
			if !ok {
				return
			}
			f.cur = f.cur.Grow(v)
		case C.MYGO_UI_OP_CENTER:
			f.cur = f.cur.Center()
		case C.MYGO_UI_OP_GAP:
			v, ok := r.f32()
			if !ok {
				return
			}
			f.cur = f.cur.Gap(v)
		case C.MYGO_UI_OP_PADDING_ALL:
			v, ok := r.f32()
			if !ok {
				return
			}
			f.cur = f.cur.Padding(v)
		case C.MYGO_UI_OP_PADDING_XY:
			x, ok1 := r.f32()
			y, ok2 := r.f32()
			if !ok1 || !ok2 {
				return
			}
			f.cur = f.cur.Padding(y, x)
		case C.MYGO_UI_OP_PADDING_TRBL:
			t, ok1 := r.f32()
			ri, ok2 := r.f32()
			b, ok3 := r.f32()
			l, ok4 := r.f32()
			if !ok1 || !ok2 || !ok3 || !ok4 {
				return
			}
			f.cur = f.cur.Padding(t, ri, b, l)
		case C.MYGO_UI_OP_WIDTH:
			v, ok := r.f32()
			if !ok {
				return
			}
			f.cur = f.cur.Width(v)
		case C.MYGO_UI_OP_HEIGHT:
			v, ok := r.f32()
			if !ok {
				return
			}
			f.cur = f.cur.Height(v)
		case C.MYGO_UI_OP_MIN_WIDTH:
			v, ok := r.f32()
			if !ok {
				return
			}
			f.cur = f.cur.MinWidth(v)
		case C.MYGO_UI_OP_MAX_WIDTH:
			v, ok := r.f32()
			if !ok {
				return
			}
			f.cur = f.cur.MaxWidth(v)
		case C.MYGO_UI_OP_BACKGROUND:
			rgba, ok := r.u32()
			if !ok {
				return
			}
			f.cur = f.cur.Background(unpackColor(rgba))
		case C.MYGO_UI_OP_RADIUS:
			v, ok := r.f32()
			if !ok {
				return
			}
			f.cur = f.cur.Radius(v)
		case C.MYGO_UI_OP_BORDER:
			w, ok1 := r.f32()
			rgba, ok2 := r.u32()
			if !ok1 || !ok2 {
				return
			}
			f.cur = f.cur.Border(w, unpackColor(rgba))
		case C.MYGO_UI_OP_FONT_SIZE:
			v, ok := r.f32()
			if !ok {
				return
			}
			f.cur = f.cur.FontSize(v)
		case C.MYGO_UI_OP_BOLD:
			f.cur = f.cur.Bold()
		case C.MYGO_UI_OP_TEXT_COLOR:
			rgba, ok := r.u32()
			if !ok {
				return
			}
			f.cur = f.cur.TextColor(unpackColor(rgba))
		case C.MYGO_UI_OP_DISABLED:
			d, ok := r.u8()
			if !ok {
				return
			}
			f.cur = f.cur.Disabled(d != 0)
		case C.MYGO_UI_OP_LABEL:
			s, ok := r.str()
			if !ok {
				return
			}
			f.cur = f.cur.Label(s)
		case C.MYGO_UI_OP_PLACEHOLDER:
			s, ok := r.str()
			if !ok {
				return
			}
			f.cur = f.cur.Placeholder(s)
		case C.MYGO_UI_OP_NUMERIC_TRANSITION:
			down, ok := r.u8()
			if !ok {
				return
			}
			f.cur = f.cur.ContentTransition(ui.ContentTransition{Numeric: true, Down: down != 0})

		case C.MYGO_UI_OP_QUERY_CLICKED:
			if out != nil {
				out.bool_val = cBool(f.cur.Clicked())
			}
		case C.MYGO_UI_OP_QUERY_HOVERED:
			if out != nil {
				out.bool_val = cBool(f.cur.Hovered())
			}
		case C.MYGO_UI_OP_QUERY_CHANGED:
			if out != nil {
				out.bool_val = cBool(f.cur.Changed())
			}
		case C.MYGO_UI_OP_QUERY_SUBMITTED:
			if out != nil {
				out.bool_val = cBool(f.cur.Submitted())
			}
		case C.MYGO_UI_OP_QUERY_SHORTCUT:
			mods, ok1 := r.u8()
			key, ok2 := r.u16()
			if !ok1 || !ok2 {
				return
			}
			if out != nil {
				out.bool_val = cBool(c.Shortcut(ui.Modifiers(mods), ui.Key(key)))
			}
		default:
			// Unknown opcode: stop decoding this batch rather than reading out of sync.
			return
		}
	}
}
