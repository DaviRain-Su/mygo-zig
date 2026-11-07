//go:build !js

// Package ui registers the GPU-accelerated Native UI (`package ui`) CommandBuffer,
// virtualized `List`, and custom `Painter` support into `zig/host`.
//
// Import with `_ "github.com/egoist/mygo/zig/host/ui"` in apps that show Native UI.
package ui

//go:generate go run ../../cmd/uigen

import (
	"encoding/binary"
	"errors"
	"fmt"
	"math"
	"unsafe"

	"github.com/egoist/mygo"
	mygoui "github.com/egoist/mygo/ui"
	"github.com/egoist/mygo/zig/host"
)

func init() {
	host.UIDispatch = uiDispatch
}

// Core 16-bit opcodes (< 100; >= 100 are AST-generated Element modifiers).
const (
	opColumn        uint16 = 1
	opRow           uint16 = 2
	opBox           uint16 = 3
	opScroll        uint16 = 4
	opSpacer        uint16 = 5
	opDivider       uint16 = 6
	opText          uint16 = 7
	opButton        uint16 = 8
	opPrimaryButton uint16 = 9
	opCheckbox      uint16 = 10
	opToggle        uint16 = 11
	opSwitch        uint16 = 12
	opSlider        uint16 = 13
	opTextInput     uint16 = 14
	opList          uint16 = 15

	opPushParent        uint16 = 20
	opPopParent         uint16 = 21
	opDraw              uint16 = 22
	opNumericTransition uint16 = 23

	opQueryClicked   uint16 = 80
	opQueryHovered   uint16 = 81
	opQueryPressed   uint16 = 82
	opQueryChanged   uint16 = 83
	opQuerySubmitted uint16 = 84
	opQueryShortcut  uint16 = 85
)

// PaintBuffer opcodes decoded by HostOpUIPaintFlush.
const (
	paintFillRect       uint8 = 1
	paintStrokeRect     uint8 = 2
	paintLine           uint8 = 3
	paintText           uint8 = 4
	paintShadow         uint8 = 5
	paintAnimationFrame uint8 = 6
)

type cUITheme struct {
	Dark           uint8
	_              [3]byte
	Background     uint32
	Surface        uint32
	SurfaceHover   uint32
	SurfacePressed uint32
	Border         uint32
	Text           uint32
	TextMuted      uint32
	Accent         uint32
	AccentText     uint32
	Danger         uint32
	Warning        uint32
	Success        uint32
	Radius         float32
	Spacing        float32
	FontSize       float32
}

type cUIFrameInfo struct {
	WindowID     int32
	Width        float32
	Height       float32
	WindowActive uint8
	_            [3]byte
	Theme        cUITheme
}

type cUIListRowInfo struct {
	WindowID int32
	Index    int32
	Selected uint8
	Hovered  uint8
	Pressed  uint8
	_        uint8
	Theme    cUITheme
}

type cUIRect struct {
	X, Y, W, H float32
	NowMillis  int64
}

type cUIQuery struct {
	BoolVal    uint8
	_          [7]byte
	NumVal     float64
	IntVal     int64
	TextBufPtr uintptr
	TextBufCap uintptr
	TextLen    uintptr
}

type zigList struct {
	state    mygoui.ListState
	selected int
}

type uiWindowHost struct {
	winID    int32
	callZig  host.CallZigFn
	viewCbID uintptr
	userdata uintptr
	lists    map[string]*zigList
}

type uiFrame struct {
	ctx    *mygoui.Context
	cur    mygoui.Element
	scopes []mygoui.FFIScope
	host   *uiWindowHost
	theme  cUITheme
}

var (
	activeFrames   []*uiFrame
	activePainters []*mygoui.Painter
)

func packColor(c mygoui.Color) uint32 {
	return uint32(c.R)<<24 | uint32(c.G)<<16 | uint32(c.B)<<8 | uint32(c.A)
}

func unpackColor(v uint32) mygoui.Color {
	return mygoui.Color{
		R: uint8(v >> 24),
		G: uint8(v >> 16),
		B: uint8(v >> 8),
		A: uint8(v),
	}
}

func buildTheme(t *mygoui.Theme) cUITheme {
	var dark uint8
	if t.Dark {
		dark = 1
	}
	return cUITheme{
		Dark:           dark,
		Background:     packColor(t.Background),
		Surface:        packColor(t.Surface),
		SurfaceHover:   packColor(t.SurfaceHover),
		SurfacePressed: packColor(t.SurfacePressed),
		Border:         packColor(t.Border),
		Text:           packColor(t.Text),
		TextMuted:      packColor(t.TextMuted),
		Accent:         packColor(t.Accent),
		AccentText:     packColor(t.AccentText),
		Danger:         packColor(t.Danger),
		Warning:        packColor(t.Warning),
		Success:        packColor(t.Success),
		Radius:         t.Radius,
		Spacing:        t.Spacing,
		FontSize:       t.FontSize,
	}
}

func uiDispatch(callZig host.CallZigFn, op, a0, a1, a2, a3 uintptr) uintptr {
	switch op {
	case host.HostOpWindowNewUI:
		return newUIWindow(callZig, host.PtrTo[host.CWindowOptions](a0), a1, a2)
	case host.HostOpUIFlush:
		flushUI(a0, a1, a2, host.PtrTo[cUIQuery](a3))
		return 0
	case host.HostOpUIPaintFlush:
		flushPaint(a0, a1, a2)
		return 0
	}
	return ^uintptr(0)
}

func newUIWindow(callZig host.CallZigFn, rawOpts *host.CWindowOptions, viewCbID, userdata uintptr) (winID uintptr) {
	defer func() {
		if r := recover(); r != nil {
			host.SetError(fmt.Errorf("%v", r))
			winID = 0
		}
	}()

	wh := &uiWindowHost{
		callZig:  callZig,
		viewCbID: viewCbID,
		userdata: userdata,
		lists:    map[string]*zigList{},
	}

	opts := host.ParseWindowOptions(rawOpts)
	opts.URL = ""
	opts.Content = mygoui.View(func(c *mygoui.Context) {
		w, h := c.Size()
		th := buildTheme(c.Theme())
		var active uint8
		if c.WindowActive() {
			active = 1
		}
		info := cUIFrameInfo{
			WindowID:     wh.winID,
			Width:        w,
			Height:       h,
			WindowActive: active,
			Theme:        th,
		}
		runFrame(c, wh, th, func(handle uintptr) {
			wh.callZig(host.ZigEventUIView, wh.viewCbID, handle, uintptr(unsafe.Pointer(&info)), wh.userdata)
		})
	})

	w := mygo.NewWindow(opts)
	if w == nil {
		host.SetError(errors.New("mygo: failed to create UI window"))
		return 0
	}
	wh.winID = int32(w.ID())
	w.OnClosed(func() {
		clear(wh.lists)
	})
	host.SetError(nil)
	return uintptr(wh.winID)
}

func runFrame(c *mygoui.Context, wh *uiWindowHost, th cUITheme, fn func(handle uintptr)) {
	f := &uiFrame{ctx: c, host: wh, theme: th}
	activeFrames = append(activeFrames, f)
	handle := uintptr(len(activeFrames))

	fn(handle)

	for i := len(f.scopes) - 1; i >= 0; i-- {
		mygoui.FFIPopParent(c, f.scopes[i])
	}
	activeFrames[len(activeFrames)-1] = nil
	activeFrames = activeFrames[:len(activeFrames)-1]
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

func (r *tapeReader) i32() (int32, bool) {
	v, ok := r.u32()
	return int32(v), ok
}

func (r *tapeReader) u64() (uint64, bool) {
	if r.i+8 > len(r.b) {
		return 0, false
	}
	v := binary.LittleEndian.Uint64(r.b[r.i : r.i+8])
	r.i += 8
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
	bits, ok := r.u64()
	if !ok {
		return 0, false
	}
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

func keyedCtx(c *mygoui.Context, key string) *mygoui.Context {
	if key != "" {
		return c.Key(key)
	}
	return c
}

func u8Bool(b bool) uint8 {
	if b {
		return 1
	}
	return 0
}

func flushUI(frameHandle, cmdPtr, cmdLen uintptr, out *cUIQuery) {
	idx := int(frameHandle) - 1
	if idx < 0 || idx >= len(activeFrames) {
		return
	}
	f := activeFrames[idx]
	if f == nil || cmdPtr == 0 || cmdLen == 0 {
		return
	}
	var savedBufPtr, savedBufCap uintptr
	if out != nil {
		savedBufPtr, savedBufCap = out.TextBufPtr, out.TextBufCap
		*out = cUIQuery{TextBufPtr: savedBufPtr, TextBufCap: savedBufCap}
	}

	c := f.ctx
	r := tapeReader{b: host.BytesView(cmdPtr, cmdLen)}

	for {
		op, ok := r.u16()
		if !ok {
			break
		}
		if op >= 100 {
			next, ok := execGeneratedModifier(op, f.cur, &r)
			if !ok {
				return
			}
			f.cur = next
			continue
		}

		switch op {
		case opColumn:
			key, ok := r.str()
			if !ok {
				return
			}
			f.cur = mygoui.Column(keyedCtx(c, key))
		case opRow:
			key, ok := r.str()
			if !ok {
				return
			}
			f.cur = mygoui.Row(keyedCtx(c, key))
		case opBox:
			key, ok := r.str()
			if !ok {
				return
			}
			f.cur = mygoui.Box(keyedCtx(c, key))
		case opScroll:
			key, ok := r.str()
			if !ok {
				return
			}
			f.cur = mygoui.Scroll(keyedCtx(c, key))
		case opSpacer:
			f.cur = mygoui.Spacer(c)
		case opDivider:
			f.cur = mygoui.Divider(c)
		case opText:
			s, ok := r.str()
			if !ok {
				return
			}
			f.cur = mygoui.Text(c, s)
		case opButton:
			key, ok1 := r.str()
			label, ok2 := r.str()
			if !ok1 || !ok2 {
				return
			}
			f.cur = mygoui.Button(keyedCtx(c, key), label)
		case opPrimaryButton:
			key, ok1 := r.str()
			label, ok2 := r.str()
			if !ok1 || !ok2 {
				return
			}
			f.cur = mygoui.PrimaryButton(keyedCtx(c, key), label)
		case opCheckbox:
			key, ok1 := r.str()
			checkedByte, ok2 := r.u8()
			label, ok3 := r.str()
			if !ok1 || !ok2 || !ok3 {
				return
			}
			val := checkedByte != 0
			f.cur = mygoui.Checkbox(keyedCtx(c, key), &val, label)
			if out != nil {
				out.BoolVal = u8Bool(val)
			}
		case opToggle:
			key, ok1 := r.str()
			onByte, ok2 := r.u8()
			label, ok3 := r.str()
			if !ok1 || !ok2 || !ok3 {
				return
			}
			val := onByte != 0
			f.cur = mygoui.Toggle(keyedCtx(c, key), &val, label)
			if out != nil {
				out.BoolVal = u8Bool(val)
			}
		case opSwitch:
			key, ok1 := r.str()
			onByte, ok2 := r.u8()
			if !ok1 || !ok2 {
				return
			}
			val := onByte != 0
			f.cur = mygoui.Switch(keyedCtx(c, key), &val)
			if out != nil {
				out.BoolVal = u8Bool(val)
			}
		case opSlider:
			key, ok1 := r.str()
			val, ok2 := r.f64()
			lo, ok3 := r.f64()
			hi, ok4 := r.f64()
			if !ok1 || !ok2 || !ok3 || !ok4 {
				return
			}
			f.cur = mygoui.Slider(keyedCtx(c, key), &val, lo, hi)
			if out != nil {
				out.NumVal = val
				out.BoolVal = u8Bool(f.cur.Changed())
			}
		case opTextInput:
			key, ok1 := r.str()
			val, ok2 := r.str()
			if !ok1 || !ok2 {
				return
			}
			curText := val
			f.cur = mygoui.TextInput(keyedCtx(c, key), &curText)
			if out != nil && (curText != val || f.cur.Changed()) {
				out.BoolVal = 1
				if savedBufPtr != 0 && savedBufCap > 0 {
					n := min(len(curText), int(savedBufCap))
					if n > 0 {
						copy(host.BytesView(savedBufPtr, uintptr(n)), curText[:n])
					}
					out.TextLen = uintptr(n)
				}
			}

		case opList:
			key, ok1 := r.str()
			count, ok2 := r.i32()
			selectedIn, ok3 := r.i32()
			rowCbID, ok4 := r.u64()
			rowUD, ok5 := r.u64()
			if !ok1 || !ok2 || !ok3 || !ok4 || !ok5 {
				return
			}
			zl := f.host.lists[key]
			if zl == nil {
				zl = &zigList{selected: int(selectedIn)}
				f.host.lists[key] = zl
			} else {
				zl.selected = int(selectedIn)
			}
			zl.state.Selected = &zl.selected
			wh := f.host
			th := f.theme
			f.cur = mygoui.List(keyedCtx(c, key), &zl.state, int(count)).Rows(func(row mygoui.ListRow) {
				rowInfo := cUIListRowInfo{
					WindowID: wh.winID,
					Index:    int32(row.Index),
					Selected: u8Bool(row.Selected()),
					Hovered:  u8Bool(row.Hovered()),
					Pressed:  u8Bool(row.Pressed()),
					Theme:    th,
				}
				runFrame(row.Context, wh, th, func(rowHandle uintptr) {
					wh.callZig(host.ZigEventUIListRow, uintptr(rowCbID), rowHandle, uintptr(unsafe.Pointer(&rowInfo)), uintptr(rowUD))
				})
			})
			if out != nil {
				out.IntVal = int64(zl.selected)
				out.BoolVal = u8Bool(f.cur.Changed())
			}

		case opPushParent:
			if sc, ok := mygoui.FFIPushParent(c, f.cur); ok {
				f.scopes = append(f.scopes, sc)
			}
		case opPopParent:
			if n := len(f.scopes); n > 0 {
				sc := f.scopes[n-1]
				f.scopes = f.scopes[:n-1]
				mygoui.FFIPopParent(c, sc)
			}

		case opDraw:
			paintCbID, ok1 := r.u64()
			paintUD, ok2 := r.u64()
			if !ok1 || !ok2 {
				return
			}
			wh := f.host
			f.cur = f.cur.Draw(func(p *mygoui.Painter, rect mygoui.Rect) {
				activePainters = append(activePainters, p)
				pHandle := uintptr(len(activePainters))
				cr := cUIRect{
					X:         rect.X,
					Y:         rect.Y,
					W:         rect.W,
					H:         rect.H,
					NowMillis: p.Now().UnixMilli(),
				}
				wh.callZig(host.ZigEventUIPaint, uintptr(paintCbID), pHandle, uintptr(unsafe.Pointer(&cr)), uintptr(paintUD))
				activePainters[len(activePainters)-1] = nil
				activePainters = activePainters[:len(activePainters)-1]
			})

		case opNumericTransition:
			down, ok := r.u8()
			if !ok {
				return
			}
			f.cur = f.cur.ContentTransition(mygoui.ContentTransition{Numeric: true, Down: down != 0})

		case opQueryClicked:
			if out != nil {
				out.BoolVal = u8Bool(f.cur.Clicked())
			}
		case opQueryHovered:
			if out != nil {
				out.BoolVal = u8Bool(f.cur.Hovered())
			}
		case opQueryPressed:
			if out != nil {
				out.BoolVal = u8Bool(f.cur.Pressed())
			}
		case opQueryChanged:
			if out != nil {
				out.BoolVal = u8Bool(f.cur.Changed())
			}
		case opQuerySubmitted:
			if out != nil {
				out.BoolVal = u8Bool(f.cur.Submitted())
			}
		case opQueryShortcut:
			mods, ok1 := r.u8()
			key, ok2 := r.u16()
			if !ok1 || !ok2 {
				return
			}
			if out != nil {
				out.BoolVal = u8Bool(c.Shortcut(mygoui.Modifiers(mods), mygoui.Key(key)))
			}
		default:
			return
		}
	}
}

func flushPaint(painterHandle, cmdPtr, cmdLen uintptr) {
	idx := int(painterHandle) - 1
	if idx < 0 || idx >= len(activePainters) {
		return
	}
	p := activePainters[idx]
	if p == nil || cmdPtr == 0 || cmdLen == 0 {
		return
	}
	r := tapeReader{b: host.BytesView(cmdPtr, cmdLen)}
	for {
		op, ok := r.u8()
		if !ok {
			break
		}
		switch op {
		case paintFillRect:
			x, ok1 := r.f32()
			y, ok2 := r.f32()
			w, ok3 := r.f32()
			h, ok4 := r.f32()
			rgba, ok5 := r.u32()
			rad, ok6 := r.f32()
			if !ok1 || !ok2 || !ok3 || !ok4 || !ok5 || !ok6 {
				return
			}
			p.Fill(mygoui.Rect{X: x, Y: y, W: w, H: h}, unpackColor(rgba), rad)
		case paintStrokeRect:
			x, ok1 := r.f32()
			y, ok2 := r.f32()
			w, ok3 := r.f32()
			h, ok4 := r.f32()
			rgba, ok5 := r.u32()
			rad, ok6 := r.f32()
			sw, ok7 := r.f32()
			if !ok1 || !ok2 || !ok3 || !ok4 || !ok5 || !ok6 || !ok7 {
				return
			}
			p.Stroke(mygoui.Rect{X: x, Y: y, W: w, H: h}, unpackColor(rgba), rad, sw)
		case paintLine:
			x0, ok1 := r.f32()
			y0, ok2 := r.f32()
			x1, ok3 := r.f32()
			y1, ok4 := r.f32()
			sw, ok5 := r.f32()
			rgba, ok6 := r.u32()
			if !ok1 || !ok2 || !ok3 || !ok4 || !ok5 || !ok6 {
				return
			}
			p.Line(x0, y0, x1, y1, sw, unpackColor(rgba))
		case paintText:
			x, ok1 := r.f32()
			y, ok2 := r.f32()
			s, ok3 := r.str()
			size, ok4 := r.f32()
			rgba, ok5 := r.u32()
			if !ok1 || !ok2 || !ok3 || !ok4 || !ok5 {
				return
			}
			p.Text(x, y, s, size, unpackColor(rgba))
		case paintShadow:
			x, ok1 := r.f32()
			y, ok2 := r.f32()
			w, ok3 := r.f32()
			h, ok4 := r.f32()
			rad, ok5 := r.f32()
			dx, ok6 := r.f32()
			dy, ok7 := r.f32()
			blur, ok8 := r.f32()
			spread, ok9 := r.f32()
			rgba, ok10 := r.u32()
			if !ok1 || !ok2 || !ok3 || !ok4 || !ok5 || !ok6 || !ok7 || !ok8 || !ok9 || !ok10 {
				return
			}
			p.Shadow(mygoui.Rect{X: x, Y: y, W: w, H: h}, rad, dx, dy, blur, spread, unpackColor(rgba))
		case paintAnimationFrame:
			p.AnimationFrame()
		default:
			return
		}
	}
}
