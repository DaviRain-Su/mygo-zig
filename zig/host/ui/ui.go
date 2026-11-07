//go:build !js

// Package ui registers the GPU-accelerated Native UI (`package ui`) CommandBuffer,
// virtualized `List` & `Table`, interactive `Split`, `Tabs`, `Select`, `Sidebar`,
// `Collapsible`, and custom `Painter` support into `zig/host`.
//
// Import with `_ "github.com/egoist/mygo/zig/host/ui"` in apps that show Native UI.
package ui

//go:generate go run ../../cmd/uigen

import (
	"encoding/binary"
	"errors"
	"fmt"
	"hash/fnv"
	"image"
	"io"
	"math"
	"strconv"
	"sync"
	"time"
	"unsafe"

	"github.com/egoist/mygo"
	"github.com/egoist/mygo/transfer"
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

	opBadge    uint16 = 16
	opLink     uint16 = 17
	opProgress uint16 = 18
	opMeter    uint16 = 19

	opPushParent        uint16 = 20
	opPopParent         uint16 = 21
	opDraw              uint16 = 22
	opNumericTransition uint16 = 23

	opTabs        uint16 = 24
	opSegmented   uint16 = 25
	opSelect      uint16 = 26
	opRadio       uint16 = 27
	opTextArea    uint16 = 28
	opCollapsible uint16 = 29
	opSplit       uint16 = 30
	opSidebar     uint16 = 31
	opTable       uint16 = 32
	opCombobox    uint16 = 33
	opAlertDialog uint16 = 34

	opSpinner          uint16 = 35
	opSearchField      uint16 = 36
	opAutocomplete     uint16 = 37
	opNumberInput      uint16 = 38
	opStepper          uint16 = 39
	opStepSlider       uint16 = 40
	opRangeSlider      uint16 = 41
	opRating           uint16 = 42
	opDateInput        uint16 = 43
	opTimeInput        uint16 = 44
	opColorPicker      uint16 = 45
	opColorWell        uint16 = 46
	opAvatar           uint16 = 47
	opBreadcrumbs      uint16 = 48
	opScrollHorizontal uint16 = 49
	opScrollBoth       uint16 = 50
	opDecimalInput     uint16 = 51
	opCheckboxGroup    uint16 = 52
	opRadioGroup       uint16 = 53
	opToggleGroup      uint16 = 54
	opFieldset         uint16 = 55
	opAccordion        uint16 = 56
	opAccordionItem    uint16 = 57
	opModal            uint16 = 58
	opPopover          uint16 = 59
	opCalendar         uint16 = 60
	opField            uint16 = 61
	opForm             uint16 = 62
	opOverlay          uint16 = 63
	opTokenField       uint16 = 64
	opTree             uint16 = 65
	opTreeItem         uint16 = 66
	opGrid             uint16 = 67
	opEditableText     uint16 = 68
	opFindBar          uint16 = 69
	opToolbar          uint16 = 70
	opThemed           uint16 = 71
	opIcon             uint16 = 72
	opImage            uint16 = 73
	opToast            uint16 = 74
	opToastAction      uint16 = 75
	opMenuButton       uint16 = 76
	opGridView         uint16 = 77
	opContextMenu      uint16 = 78
	opPopoverMenu      uint16 = 79
	opPopoverMenuBtn   uint16 = 86
	opOutline          uint16 = 87
	opRichText         uint16 = 88
	opRouter           uint16 = 89
	opRouterPush       uint16 = 90
	opRouterReplace    uint16 = 91
	opRouterBack       uint16 = 92
	opRouterForward    uint16 = 93
	opBackButton       uint16 = 94
	opForwardButton    uint16 = 95
	opOutlineTable     uint16 = 96
	opDrag             uint16 = 97
	opDrop             uint16 = 98
	opDragOver         uint16 = 99
	// 100..301 are Element modifiers (uigen). New widget ops continue after.
	opDraggable       uint16 = 302
	opWebView         uint16 = 303
	opWebViewDestroy  uint16 = 304
	opDragData        uint16 = 305
	opDropData        uint16 = 306
	opDataDragOver    uint16 = 307
	opVideo           uint16 = 308
	opVideoControl    uint16 = 309
	opRouteView       uint16 = 310
	opRouteMatch      uint16 = 311
	opRouteParam      uint16 = 312
	opDrawObjects     uint16 = 313
	opToastViewport   uint16 = 314
	opToastItem       uint16 = 315
	opToastCloseBtn   uint16 = 316
	opToastActionBtn  uint16 = 317
	opDragMIME        uint16 = 318
	opDropMIME        uint16 = 319
	opDragMIMELazy    uint16 = 320
	opAddToast        uint16 = 321
	opAfter           uint16 = 322
	opAnimationFrame  uint16 = 323
	opDisableAnims    uint16 = 324
	opInvalidate      uint16 = 325
	opCloseToast      uint16 = 326
	opAnimate         uint16 = 327
	opAnimateTo       uint16 = 328
	opArrived         uint16 = 329
	opAnimateColor    uint16 = 330
	opAnimatePose     uint16 = 331
	opSpring          uint16 = 332
	opRole            uint16 = 333
	opLinearGradient  uint16 = 334 // angle, from, to (element fill)
	opBitmap          uint16 = 335 // key → registered bitmap
	opCanvas          uint16 = 336 // key → registered canvas Image
	opLinearGradStops uint16 = 337 // angle, oklab, n, (rgba,at)*
	opConicGradient   uint16 = 338 // angle, cx, cy, oklab, n, stops
	opRadialGradient  uint16 = 339 // radius, cx, cy, oklab, n, stops

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
	paintPathBegin      uint8 = 7 // rule u8, cap u8, join u8, miter f32
	paintPathMove       uint8 = 8
	paintPathLine       uint8 = 9
	paintPathQuad       uint8 = 10
	paintPathCubic      uint8 = 11
	paintPathClose      uint8 = 12
	paintPathFill       uint8 = 13 // rgba u32
	paintPathStroke     uint8 = 14 // width f32, rgba u32
	paintPathSVG        uint8 = 15 // svg str, then fill rgba + stroke width/rgba (0 width = no stroke)
	paintFillGradient   uint8 = 16 // rect + radius + angle + from + to
	paintPathFillGrad   uint8 = 17 // angle + from + to
	paintFillGradStops  uint8 = 18 // rect + radius + angle + oklab + n + stops
	paintFillConic      uint8 = 19
	paintFillRadial     uint8 = 20
	paintCanvasBegin    uint8 = 21 // key
	paintCanvasEnd      uint8 = 22
	paintImage          uint8 = 23 // key, x,y,w,h, fit
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

type cUITableCellInfo struct {
	WindowID int32
	Row      int32
	Col      int32
	Selected uint8
	_        [3]byte
	Theme    cUITheme
}

type cUIGridItemInfo struct {
	WindowID int32
	Index    int32
	Selected uint8
	_        [3]byte
	Theme    cUITheme
}

type cUIOutlineRowInfo struct {
	WindowID int32
	Index    int32
	Depth    int32
	Selected uint8
	Branch   uint8
	Open     uint8
	_        uint8
	Theme    cUITheme
	IDPtr    uintptr
	IDLen    uintptr
}

type cUIRouteInfo struct {
	WindowID int32
	_        [4]byte
	Theme    cUITheme
	PathPtr  uintptr
	PathLen  uintptr
}

type cUIOutlineCellInfo struct {
	WindowID int32
	Row      int32
	Col      int32
	Depth    int32
	Selected uint8
	Branch   uint8
	Open     uint8
	_        uint8
	Theme    cUITheme
	IDPtr    uintptr
	IDLen    uintptr
}

type cUIRect struct {
	X, Y, W, H float32
	NowMillis  int64
	At         int32 // DrawObjects index; unused (0) for Draw
	_          int32
}

type cUIQuery struct {
	BoolVal    uint8
	_          [7]byte
	NumVal     float64
	NumVal2    float64
	IntVal     int64
	TextBufPtr uintptr
	TextBufCap uintptr
	TextLen    uintptr
}

type zigList struct {
	state    mygoui.ListState
	selected int
}

type zigGrid struct {
	state    mygoui.GridState
	selected int
}

type zigOutline struct {
	state    mygoui.OutlineState[string]
	selected int
}

type uiWindowHost struct {
	winID    int32
	win      *mygo.Window
	callZig  host.CallZigFn
	viewCbID uintptr
	userdata uintptr
	lists    map[string]*zigList
	grids    map[string]*zigGrid
	outlines map[string]*zigOutline
	routers  map[string]*mygoui.Router
	webviews map[string]*mygo.WebView
	wvURLs   map[string]string
	videos   map[string]*mygoui.VideoPlayer
}

var assetCache sync.Map // hash key → *SVG | ImageSource

type uiFrame struct {
	ctx        *mygoui.Context
	cur        mygoui.Element
	scopes     []mygoui.FFIScope
	host       *uiWindowHost
	theme      cUITheme
	route      *mygoui.Route // set while a router/route page callback runs
	toasts     []mygoui.Toast
	toastParts mygoui.ToastParts
	hasToast   bool
}

type gifAsset struct {
	data []byte
	loop bool
}

type ZigToastData struct {
	Text string
	User uintptr
}

type framesAsset struct {
	w, h   int
	loop   bool
	frames []frameRGBA
}

type frameRGBA struct {
	pix []byte
	dur time.Duration
}

var (
	gifRegistry    sync.Map // key → gifAsset
	framesRegistry sync.Map // key → framesAsset
	streamRegistry sync.Map // key → *streamAsset
	bitmapRegistry sync.Map // key → *mygoui.Bitmap
	canvasRegistry sync.Map // key → *mygoui.Canvas
)

// rgbaFramesDecoder plays a registered RGBA sequence.
type rgbaFramesDecoder struct {
	w, h   int
	frames []frameRGBA
	i      int
}

func (d *rgbaFramesDecoder) Next() (mygoui.VideoFrame, error) {
	if d.i >= len(d.frames) {
		return mygoui.VideoFrame{}, io.EOF
	}
	f := d.frames[d.i]
	d.i++
	img := image.NewRGBA(image.Rect(0, 0, d.w, d.h))
	copy(img.Pix, f.pix)
	return mygoui.VideoFrame{Image: img, Duration: f.dur}, nil
}

func (d *rgbaFramesDecoder) Rewind() error {
	d.i = 0
	return nil
}

// streamAsset is a push-driven frame queue. Zig (or any producer) pushes
// RGBA frames from any goroutine; VideoPlayer.Next blocks until a frame
// or End arrives. This is the streaming alternative to embedding a full
// GIF / frame table up front.
type streamAsset struct {
	w, h int
	loop bool
	ch   chan frameRGBA
	done chan struct{}
	mu   sync.Mutex
	end  bool
}

type streamDecoder struct {
	a *streamAsset
}

func (d *streamDecoder) Next() (mygoui.VideoFrame, error) {
	select {
	case <-d.a.done:
		return mygoui.VideoFrame{}, io.EOF
	case f, ok := <-d.a.ch:
		if !ok {
			return mygoui.VideoFrame{}, io.EOF
		}
		img := image.NewRGBA(image.Rect(0, 0, d.a.w, d.a.h))
		copy(img.Pix, f.pix)
		return mygoui.VideoFrame{Image: img, Duration: f.dur}, nil
	}
}

func (d *streamDecoder) Rewind() error {
	// Streams are live; looping reuses the same open channel.
	return nil
}

func (d *streamDecoder) Close() error {
	d.a.mu.Lock()
	defer d.a.mu.Unlock()
	if !d.a.end {
		d.a.end = true
		close(d.a.done)
		close(d.a.ch)
	}
	return nil
}

var (
	activeFrames   []*uiFrame
	activePainters []*mygoui.Painter
)

// BindFrameElement builds an element inside the active frame for opt-in sibling
// packages (`zig/host/markdown`, `zig/host/editor`) and sets it as `f.cur` so
// subsequent Element modifier opcodes apply to it.

func colorToU32(c mygoui.Color) uint32 {
	return uint32(c.R)<<24 | uint32(c.G)<<16 | uint32(c.B)<<8 | uint32(c.A)
}

func colorFromU32(v uint32) mygoui.Color {
	return mygoui.Color{R: uint8(v >> 24), G: uint8(v >> 16), B: uint8(v >> 8), A: uint8(v)}
}

func zigAnim(preset uint8, durMS, delayMS int32, bounce float32, nonMotion, oklab bool) mygoui.Animation {
	a := mygoui.Animation{
		Delay:     time.Duration(delayMS) * time.Millisecond,
		NonMotion: nonMotion,
		Oklab:     oklab,
	}
	switch preset {
	case 1:
		a.Spring = mygoui.Smooth.Spring
	case 2:
		a.Spring = mygoui.Snappy.Spring
	case 3:
		a.Spring = mygoui.Bouncy.Spring
	default:
		if durMS > 0 {
			a.Duration = time.Duration(durMS) * time.Millisecond
		} else {
			a.Spring = mygoui.Smooth.Spring
		}
	}
	if bounce != 0 && a.Duration == 0 {
		a.Spring.Bounce = float64(bounce)
	}
	if durMS > 0 && a.Duration == 0 && preset >= 1 {
		a.Spring.Duration = time.Duration(durMS) * time.Millisecond
	}
	return a
}

func BindFrameElement(frameHandle uintptr, build func(c *mygoui.Context, winID int32) mygoui.Element) bool {
	idx := int(frameHandle) - 1
	if idx < 0 || idx >= len(activeFrames) {
		return false
	}
	f := activeFrames[idx]
	if f == nil {
		return false
	}
	f.cur = build(f.ctx, f.host.winID)
	return true
}

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
	case host.HostOpVideoGIF:
		spec := host.PtrTo[host.CVideoGIFSpec](a0)
		if spec == nil || spec.KeyLen == 0 || spec.GIFLen == 0 {
			host.SetError(errors.New("zighost: video GIF registration needs key and bytes"))
			return ^uintptr(0)
		}
		key := host.CopyString(spec.KeyPtr, spec.KeyLen)
		data := host.CopyBytes(spec.GIFPtr, spec.GIFLen)
		gifRegistry.Store(key, gifAsset{data: data, loop: spec.Loop != 0})
		return 0
	case host.HostOpVideoFrames:
		spec := host.PtrTo[host.CVideoFramesSpec](a0)
		if spec == nil || spec.KeyLen == 0 || spec.FrameCount == 0 || spec.Width == 0 || spec.Height == 0 {
			host.SetError(errors.New("zighost: video frames registration needs key, size, and frames"))
			return ^uintptr(0)
		}
		w, h, n := int(spec.Width), int(spec.Height), int(spec.FrameCount)
		frameBytes := w * h * 4
		need := frameBytes * n
		if int(spec.PixelsLen) < need {
			host.SetError(fmt.Errorf("zighost: video frames pixels too short (%d < %d)", spec.PixelsLen, need))
			return ^uintptr(0)
		}
		pix := host.CopyBytes(spec.PixelsPtr, uintptr(need))
		durs := host.Uint32View(spec.DurationsPtr, uintptr(n))
		frames := make([]frameRGBA, n)
		for i := range frames {
			start := i * frameBytes
			chunk := make([]byte, frameBytes)
			copy(chunk, pix[start:start+frameBytes])
			dur := 100 * time.Millisecond
			if i < len(durs) && durs[i] > 0 {
				dur = time.Duration(durs[i]) * time.Millisecond
			}
			frames[i] = frameRGBA{pix: chunk, dur: dur}
		}
		key := host.CopyString(spec.KeyPtr, spec.KeyLen)
		framesRegistry.Store(key, framesAsset{w: w, h: h, loop: spec.Loop != 0, frames: frames})
		return 0
	case host.HostOpVideoStream:
		spec := host.PtrTo[host.CVideoStreamSpec](a0)
		if spec == nil || spec.KeyLen == 0 || spec.Width == 0 || spec.Height == 0 {
			host.SetError(errors.New("zighost: video stream needs key and size"))
			return ^uintptr(0)
		}
		capN := int(spec.Capacity)
		if capN <= 0 {
			capN = 4
		}
		if capN > 64 {
			capN = 64
		}
		key := host.CopyString(spec.KeyPtr, spec.KeyLen)
		if old, ok := streamRegistry.Load(key); ok {
			if s := old.(*streamAsset); s != nil {
				_ = (&streamDecoder{a: s}).Close()
			}
		}
		s := &streamAsset{
			w:    int(spec.Width),
			h:    int(spec.Height),
			loop: spec.Loop != 0,
			ch:   make(chan frameRGBA, capN),
			done: make(chan struct{}),
		}
		// Seed a blank frame so NewVideoPlayer can take its required first frame
		// before Zig pushes real content.
		blank := make([]byte, s.w*s.h*4)
		s.ch <- frameRGBA{pix: blank, dur: 50 * time.Millisecond}
		streamRegistry.Store(key, s)
		return 0
	case host.HostOpVideoPush:
		spec := host.PtrTo[host.CVideoPushSpec](a0)
		if spec == nil || spec.KeyLen == 0 {
			return ^uintptr(0)
		}
		key := host.CopyString(spec.KeyPtr, spec.KeyLen)
		raw, ok := streamRegistry.Load(key)
		if !ok {
			host.SetError(fmt.Errorf("zighost: video stream %q not open", key))
			return ^uintptr(0)
		}
		s := raw.(*streamAsset)
		need := s.w * s.h * 4
		if int(spec.PixelsLen) < need {
			host.SetError(fmt.Errorf("zighost: video push too short (%d < %d)", spec.PixelsLen, need))
			return ^uintptr(0)
		}
		chunk := host.CopyBytes(spec.PixelsPtr, uintptr(need))
		dur := 100 * time.Millisecond
		if spec.DurationMS > 0 {
			dur = time.Duration(spec.DurationMS) * time.Millisecond
		}
		s.mu.Lock()
		ended := s.end
		s.mu.Unlock()
		if ended {
			return ^uintptr(0)
		}
		select {
		case s.ch <- frameRGBA{pix: chunk, dur: dur}:
			return 0
		case <-s.done:
			return ^uintptr(0)
		default:
			// Drop oldest to keep live streams moving.
			select {
			case <-s.ch:
			default:
			}
			select {
			case s.ch <- frameRGBA{pix: chunk, dur: dur}:
				return 0
			default:
				return ^uintptr(0)
			}
		}
	case host.HostOpVideoEnd:
		key := host.CopyString(a0, a1)
		if key == "" {
			return ^uintptr(0)
		}
		if raw, ok := streamRegistry.Load(key); ok {
			_ = (&streamDecoder{a: raw.(*streamAsset)}).Close()
		}
	case host.HostOpRegisterFont:
		spec := host.PtrTo[host.CFontSpec](a0)
		if spec == nil || spec.DataLen == 0 {
			host.SetError(errors.New("zighost: registerFont needs font bytes"))
			return ^uintptr(0)
		}
		family := host.CopyString(spec.FamilyPtr, spec.FamilyLen)
		data := host.CopyBytes(spec.DataPtr, spec.DataLen)
		if err := mygoui.RegisterFont(data, family); err != nil {
			host.SetError(err)
			return ^uintptr(0)
		}
		return 0
	case host.HostOpRegisterBitmap:
		spec := host.PtrTo[host.CBitmapSpec](a0)
		if spec == nil || spec.KeyLen == 0 || spec.DataLen == 0 {
			host.SetError(errors.New("zighost: registerBitmap needs key and bytes"))
			return ^uintptr(0)
		}
		key := host.CopyString(spec.KeyPtr, spec.KeyLen)
		data := host.CopyBytes(spec.DataPtr, spec.DataLen)
		bm, err := mygoui.DecodeBitmap(data)
		if err != nil {
			host.SetError(err)
			return ^uintptr(0)
		}
		bitmapRegistry.Store(key, bm)
		return 0
	case host.HostOpRegisterCanvas:
		spec := host.PtrTo[host.CCanvasSpec](a0)
		if spec == nil || spec.KeyLen == 0 || spec.Width == 0 || spec.Height == 0 {
			host.SetError(errors.New("zighost: registerCanvas needs key and size"))
			return ^uintptr(0)
		}
		key := host.CopyString(spec.KeyPtr, spec.KeyLen)
		w, h := int(spec.Width), int(spec.Height)
		if raw, ok := canvasRegistry.Load(key); ok {
			cv := raw.(*mygoui.Canvas)
			if cw, ch := cv.Size(); cw != w || ch != h {
				canvasRegistry.Store(key, mygoui.NewCanvas(w, h))
			}
			_ = cv
		} else {
			canvasRegistry.Store(key, mygoui.NewCanvas(w, h))
		}
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
		grids:    map[string]*zigGrid{},
		outlines: map[string]*zigOutline{},
		routers:  map[string]*mygoui.Router{},
		webviews: map[string]*mygo.WebView{},
		wvURLs:   map[string]string{},
		videos:   map[string]*mygoui.VideoPlayer{},
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
	wh.win = w
	w.OnClosed(func() {
		for _, wv := range wh.webviews {
			wv.Destroy()
		}
		clear(wh.lists)
		clear(wh.grids)
		clear(wh.outlines)
		clear(wh.routers)
		clear(wh.webviews)
		clear(wh.wvURLs)
		for _, p := range wh.videos {
			p.Close()
		}
		clear(wh.videos)
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

func runSubview(c *mygoui.Context, wh *uiWindowHost, th cUITheme, cbID, ud uintptr) {
	w, h := c.Size()
	info := cUIFrameInfo{
		WindowID:     wh.winID,
		Width:        w,
		Height:       h,
		WindowActive: 1,
		Theme:        th,
	}
	runFrame(c, wh, th, func(subHandle uintptr) {
		wh.callZig(host.ZigEventUISubview, cbID, subHandle, uintptr(unsafe.Pointer(&info)), ud)
	})
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

func (r *tapeReader) strList() ([]string, bool) {
	cnt, ok := r.u16()
	if !ok {
		return nil, false
	}
	out := make([]string, int(cnt))
	for i := range int(cnt) {
		s, ok := r.str()
		if !ok {
			return nil, false
		}
		out[i] = s
	}
	return out, true
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

// writeStrList packs strings as u16 count + length-prefixed UTF-8 into dst.
// Returns bytes written (0 if they do not fit).
func hashBytes(b []byte) string {
	h := fnv.New64a()
	_, _ = h.Write(b)
	return strconv.FormatUint(h.Sum64(), 16)
}

func cachedSVG(data []byte) (*mygoui.SVG, error) {
	key := "svg:" + hashBytes(data)
	if v, ok := assetCache.Load(key); ok {
		return v.(*mygoui.SVG), nil
	}
	s, err := mygoui.ParseSVG(data)
	if err != nil {
		return nil, err
	}
	actual, _ := assetCache.LoadOrStore(key, s)
	return actual.(*mygoui.SVG), nil
}

func cachedImage(data []byte) (mygoui.ImageSource, error) {
	key := "img:" + hashBytes(data)
	if v, ok := assetCache.Load(key); ok {
		return v.(mygoui.ImageSource), nil
	}
	src, err := mygoui.DecodeImage(data)
	if err != nil {
		return nil, err
	}
	actual, _ := assetCache.LoadOrStore(key, src)
	return actual.(mygoui.ImageSource), nil
}

func themeFromC(th cUITheme) *mygoui.Theme {
	return &mygoui.Theme{
		Dark:           th.Dark != 0,
		Background:     unpackColor(th.Background),
		Surface:        unpackColor(th.Surface),
		SurfaceHover:   unpackColor(th.SurfaceHover),
		SurfacePressed: unpackColor(th.SurfacePressed),
		Border:         unpackColor(th.Border),
		Text:           unpackColor(th.Text),
		TextMuted:      unpackColor(th.TextMuted),
		Accent:         unpackColor(th.Accent),
		AccentText:     unpackColor(th.AccentText),
		Danger:         unpackColor(th.Danger),
		Warning:        unpackColor(th.Warning),
		Success:        unpackColor(th.Success),
		Radius:         th.Radius,
		Spacing:        th.Spacing,
		FontSize:       th.FontSize,
	}
}

func writeStrList(dst []byte, items []string) int {
	if len(dst) < 2 {
		return 0
	}
	need := 2
	for _, s := range items {
		need += 4 + len(s)
	}
	if need > len(dst) {
		return 0
	}
	binary.LittleEndian.PutUint16(dst[0:2], uint16(len(items)))
	off := 2
	for _, s := range items {
		binary.LittleEndian.PutUint32(dst[off:off+4], uint32(len(s)))
		off += 4
		copy(dst[off:off+len(s)], s)
		off += len(s)
	}
	return off
}

// zigMenuNode is a menu entry parsed from the Zig tape. build runs again
// after a choice, so the tree must be owned by Go, not the command buffer.
type zigMenuNode struct {
	kind      uint8 // 0=item, 1=separator, 2=submenu
	id, label string
	children  []zigMenuNode
}

// readMenuTree reads:
//
//	u16 count
//	for each: u8 kind (0=item, 1=separator, 2=submenu)
//	  item:     str id, str label
//	  separator: (none)
//	  submenu:  str label, then nested count+entries
func readMenuTree(r *tapeReader) ([]zigMenuNode, bool) {
	n, ok := r.u16()
	if !ok {
		return nil, false
	}
	out := make([]zigMenuNode, 0, int(n))
	for range int(n) {
		kind, okK := r.u8()
		if !okK {
			return nil, false
		}
		switch kind {
		case 0:
			id, ok1 := r.str()
			label, ok2 := r.str()
			if !ok1 || !ok2 {
				return nil, false
			}
			if label == "" {
				label = id
			}
			out = append(out, zigMenuNode{kind: 0, id: id, label: label})
		case 1:
			out = append(out, zigMenuNode{kind: 1})
		case 2:
			label, okL := r.str()
			if !okL {
				return nil, false
			}
			kids, okKids := readMenuTree(r)
			if !okKids {
				return nil, false
			}
			out = append(out, zigMenuNode{kind: 2, label: label, children: kids})
		default:
			return nil, false
		}
	}
	return out, true
}

func applyMenu(m *mygoui.Menu, nodes []zigMenuNode, chosenID *string) {
	for _, n := range nodes {
		switch n.kind {
		case 0:
			if m.Item(n.label).Chosen() {
				*chosenID = n.id
			}
		case 1:
			m.Separator()
		case 2:
			kids := n.children
			m.Submenu(n.label, func(sub *mygoui.Menu) {
				applyMenu(sub, kids, chosenID)
			})
		}
	}
}

func writeChosenID(out *cUIQuery, savedBufPtr, savedBufCap uintptr, chosenID string) {
	if out == nil || chosenID == "" {
		return
	}
	out.BoolVal = 1
	if savedBufPtr != 0 && savedBufCap > 0 {
		n := min(len(chosenID), int(savedBufCap))
		if n > 0 {
			copy(host.BytesView(savedBufPtr, uintptr(n)), chosenID[:n])
		}
		out.TextLen = uintptr(n)
	}
}

// parseMIMETape reads the dragMIME wire format: u16 count, then (str, str)* pairs.
func parseMIMETape(b []byte) ([]transfer.Representation, bool) {
	r := tapeReader{b: b}
	n, ok := r.u16()
	if !ok {
		return nil, false
	}
	reps := make([]transfer.Representation, 0, int(n))
	for range int(n) {
		format, ok1 := r.str()
		payload, ok2 := r.str()
		if !ok1 || !ok2 {
			return nil, false
		}
		reps = append(reps, transfer.Bytes(transfer.Format(format), []byte(payload)))
	}
	return reps, true
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
		case opBadge:
			s, ok := r.str()
			if !ok {
				return
			}
			f.cur = mygoui.Badge(c, s)
		case opLink:
			lbl, ok1 := r.str()
			url, ok2 := r.str()
			if !ok1 || !ok2 {
				return
			}
			f.cur = mygoui.Link(c, lbl, url)
		case opProgress:
			val, ok := r.f64()
			if !ok {
				return
			}
			f.cur = mygoui.Progress(c, val)
		case opMeter:
			val, ok1 := r.f64()
			lo, ok2 := r.f64()
			hi, ok3 := r.f64()
			if !ok1 || !ok2 || !ok3 {
				return
			}
			f.cur = mygoui.Meter(c, val, lo, hi, nil)
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
		case opTextInput, opTextArea:
			key, ok1 := r.str()
			val, ok2 := r.str()
			if !ok1 || !ok2 {
				return
			}
			curText := val
			if op == opTextArea {
				f.cur = mygoui.TextArea(keyedCtx(c, key), &curText)
			} else {
				f.cur = mygoui.TextInput(keyedCtx(c, key), &curText)
			}
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

		case opTabs:
			key, ok1 := r.str()
			selIn, ok2 := r.i32()
			labels, ok3 := r.strList()
			if !ok1 || !ok2 || !ok3 {
				return
			}
			sel := int(selIn)
			f.cur = mygoui.Tabs(keyedCtx(c, key), &sel, labels...)
			if out != nil {
				out.IntVal = int64(sel)
				out.BoolVal = u8Bool(f.cur.Changed())
			}

		case opSegmented:
			key, ok1 := r.str()
			selIn, ok2 := r.i32()
			labels, ok3 := r.strList()
			if !ok1 || !ok2 || !ok3 {
				return
			}
			sel := int(selIn)
			f.cur = mygoui.Segmented(keyedCtx(c, key), &sel, labels...)
			if out != nil {
				out.IntVal = int64(sel)
				out.BoolVal = u8Bool(f.cur.Changed())
			}

		case opSelect:
			key, ok1 := r.str()
			selIn, ok2 := r.i32()
			options, ok3 := r.strList()
			if !ok1 || !ok2 || !ok3 {
				return
			}
			chosen := ""
			if int(selIn) >= 0 && int(selIn) < len(options) {
				chosen = options[selIn]
			}
			f.cur = mygoui.Select(keyedCtx(c, key), &chosen, options)
			nextIdx := -1
			for i, o := range options {
				if o == chosen {
					nextIdx = i
					break
				}
			}
			if out != nil {
				out.IntVal = int64(nextIdx)
				out.BoolVal = u8Bool(nextIdx != int(selIn))
			}

		case opAlertDialog:
			openByte, ok1 := r.u8()
			title, ok2 := r.str()
			msg, ok3 := r.str()
			buttons, ok4 := r.strList()
			if !ok1 || !ok2 || !ok3 || !ok4 {
				return
			}
			open := openByte != 0
			chosen := mygoui.AlertDialog(c, &open, title, msg, buttons...)
			if out != nil {
				out.BoolVal = u8Bool(open)
				out.IntVal = int64(chosen)
			}

		case opCombobox:
			key, ok1 := r.str()
			selIn, ok2 := r.i32()
			curText, ok3 := r.str()
			options, ok4 := r.strList()
			if !ok1 || !ok2 || !ok3 || !ok4 {
				return
			}
			chosen := curText
			if chosen == "" && int(selIn) >= 0 && int(selIn) < len(options) {
				chosen = options[selIn]
			}
			f.cur = mygoui.Combobox(keyedCtx(c, key), &chosen, options)
			nextIdx := -1
			for i, o := range options {
				if o == chosen {
					nextIdx = i
					break
				}
			}
			if out != nil {
				out.IntVal = int64(nextIdx)
				changed := nextIdx != int(selIn) || chosen != curText || f.cur.Changed()
				out.BoolVal = u8Bool(changed)
				if savedBufPtr != 0 && savedBufCap > 0 {
					n := min(len(chosen), int(savedBufCap))
					if n > 0 {
						copy(host.BytesView(savedBufPtr, uintptr(n)), chosen[:n])
					}
					out.TextLen = uintptr(n)
				}
			}

		case opRadio:
			key, ok1 := r.str()
			selIn, ok2 := r.i32()
			valIn, ok3 := r.i32()
			label, ok4 := r.str()
			if !ok1 || !ok2 || !ok3 || !ok4 {
				return
			}
			sel := int(selIn)
			f.cur = mygoui.Radio(keyedCtx(c, key), &sel, int(valIn), label)
			if out != nil {
				out.IntVal = int64(sel)
				out.BoolVal = u8Bool(sel != int(selIn))
			}

		case opCollapsible:
			key, ok1 := r.str()
			label, ok2 := r.str()
			openByte, ok3 := r.u8()
			bodyCbID, ok4 := r.u64()
			bodyUD, ok5 := r.u64()
			if !ok1 || !ok2 || !ok3 || !ok4 || !ok5 {
				return
			}
			open := openByte != 0
			wh, th := f.host, f.theme
			f.cur = mygoui.Collapsible(keyedCtx(c, key), label, &open, func() {
				runSubview(c, wh, th, uintptr(bodyCbID), uintptr(bodyUD))
			})
			if out != nil {
				out.BoolVal = u8Bool(open)
			}

		case opSplit:
			key, ok1 := r.str()
			mode, ok2 := r.u8()
			size, ok3 := r.f32()
			firstCbID, ok4 := r.u64()
			secondCbID, ok5 := r.u64()
			ud, ok6 := r.u64()
			if !ok1 || !ok2 || !ok3 || !ok4 || !ok5 || !ok6 {
				return
			}
			wh, th := f.host, f.theme
			firstFn := func() { runSubview(c, wh, th, uintptr(firstCbID), uintptr(ud)) }
			secondFn := func() { runSubview(c, wh, th, uintptr(secondCbID), uintptr(ud)) }
			vertical := mode&1 != 0
			percent := mode&2 != 0
			switch {
			case vertical && percent:
				f.cur = mygoui.SplitVerticalPercent(keyedCtx(c, key), &size, firstFn, secondFn)
			case percent:
				f.cur = mygoui.SplitPercent(keyedCtx(c, key), &size, firstFn, secondFn)
			case vertical:
				f.cur = mygoui.SplitVertical(keyedCtx(c, key), &size, firstFn, secondFn)
			default:
				f.cur = mygoui.Split(keyedCtx(c, key), &size, firstFn, secondFn)
			}
			if out != nil {
				out.NumVal = float64(size)
			}

		case opSidebar:
			key, ok1 := r.str()
			selIn, ok2 := r.i32()
			items, ok3 := r.strList()
			if !ok1 || !ok2 || !ok3 {
				return
			}
			chosenID := strconv.Itoa(int(selIn))
			f.cur = mygoui.Sidebar(keyedCtx(c, key), &chosenID, func() {
				for i, label := range items {
					mygoui.SidebarItem(c, strconv.Itoa(i), nil, label)
				}
			})
			nextIdx, err := strconv.Atoi(chosenID)
			if err != nil {
				nextIdx = int(selIn)
			}
			if out != nil {
				out.IntVal = int64(nextIdx)
				out.BoolVal = u8Bool(nextIdx != int(selIn))
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
			wh, th := f.host, f.theme
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

		case opTable:
			key, ok1 := r.str()
			colCount, ok2 := r.u16()
			if !ok1 || !ok2 {
				return
			}
			cols := make([]mygoui.TableColumn, int(colCount))
			for i := range int(colCount) {
				title, okT := r.str()
				w, okW := r.f32()
				al, okA := r.u8()
				if !okT || !okW || !okA {
					return
				}
				cols[i] = mygoui.TableColumn{
					Title: title,
					ID:    strconv.Itoa(i) + ":" + title,
					Width: w,
					Align: mygoui.Align(al),
				}
			}
			rowCount, ok3 := r.i32()
			selectedIn, ok4 := r.i32()
			cellCbID, ok5 := r.u64()
			cellUD, ok6 := r.u64()
			if !ok3 || !ok4 || !ok5 || !ok6 {
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
			wh, th := f.host, f.theme
			f.cur = mygoui.Table(keyedCtx(c, key), &zl.state, cols, int(rowCount), func(row, col int) {
				cellInfo := cUITableCellInfo{
					WindowID: wh.winID,
					Row:      int32(row),
					Col:      int32(col),
					Selected: u8Bool(zl.selected == row),
					Theme:    th,
				}
				runFrame(c, wh, th, func(cellHandle uintptr) {
					wh.callZig(host.ZigEventUITableCell, uintptr(cellCbID), cellHandle, uintptr(unsafe.Pointer(&cellInfo)), uintptr(cellUD))
				})
			})
			if out != nil {
				out.IntVal = int64(zl.selected)
				out.BoolVal = u8Bool(f.cur.Changed())
			}

		case opSpinner:
			f.cur = mygoui.Spinner(c)

		case opSearchField:
			key, ok1 := r.str()
			val, ok2 := r.str()
			if !ok1 || !ok2 {
				return
			}
			curText := val
			f.cur = mygoui.SearchField(keyedCtx(c, key), &curText)
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

		case opAutocomplete:
			key, ok1 := r.str()
			val, ok2 := r.str()
			suggestions, ok3 := r.strList()
			if !ok1 || !ok2 || !ok3 {
				return
			}
			curText := val
			f.cur = mygoui.Autocomplete(keyedCtx(c, key), &curText, suggestions)
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

		case opNumberInput, opStepper, opStepSlider:
			key, ok1 := r.str()
			val, ok2 := r.f64()
			lo, ok3 := r.f64()
			hi, ok4 := r.f64()
			step, ok5 := r.f64()
			if !ok1 || !ok2 || !ok3 || !ok4 || !ok5 {
				return
			}
			switch op {
			case opStepper:
				f.cur = mygoui.Stepper(keyedCtx(c, key), &val, lo, hi, step)
			case opStepSlider:
				f.cur = mygoui.StepSlider(keyedCtx(c, key), &val, lo, hi, step)
			default:
				f.cur = mygoui.NumberInput(keyedCtx(c, key), &val, lo, hi, step)
			}
			if out != nil {
				out.NumVal = val
				out.BoolVal = u8Bool(f.cur.Changed())
			}

		case opRangeSlider:
			key, ok1 := r.str()
			low, ok2 := r.f64()
			high, ok3 := r.f64()
			lo, ok4 := r.f64()
			hi, ok5 := r.f64()
			step, ok6 := r.f64()
			if !ok1 || !ok2 || !ok3 || !ok4 || !ok5 || !ok6 {
				return
			}
			f.cur = mygoui.RangeSlider(keyedCtx(c, key), &low, &high, lo, hi, step)
			if out != nil {
				out.NumVal = low
				out.NumVal2 = high
				out.BoolVal = u8Bool(f.cur.Changed())
			}

		case opRating:
			key, ok1 := r.str()
			valIn, ok2 := r.i32()
			maxIn, ok3 := r.i32()
			if !ok1 || !ok2 || !ok3 {
				return
			}
			val := int(valIn)
			f.cur = mygoui.Rating(keyedCtx(c, key), &val, int(maxIn))
			if out != nil {
				out.IntVal = int64(val)
				out.BoolVal = u8Bool(val != int(valIn))
			}

		case opDateInput, opTimeInput, opCalendar:
			key, ok1 := r.str()
			ms, ok2 := r.u64()
			if !ok1 || !ok2 {
				return
			}
			tm := time.UnixMilli(int64(ms)).UTC()
			switch op {
			case opTimeInput:
				f.cur = mygoui.TimeInput(keyedCtx(c, key), &tm)
			case opCalendar:
				f.cur = mygoui.Calendar(keyedCtx(c, key), &tm)
			default:
				f.cur = mygoui.DateInput(keyedCtx(c, key), &tm)
			}
			if out != nil {
				out.IntVal = tm.UnixMilli()
				out.BoolVal = u8Bool(f.cur.Changed())
			}

		case opColorPicker, opColorWell:
			key, ok1 := r.str()
			rgba, ok2 := r.u32()
			if !ok1 || !ok2 {
				return
			}
			col := unpackColor(rgba)
			if op == opColorWell {
				f.cur = mygoui.ColorWell(keyedCtx(c, key), &col)
			} else {
				f.cur = mygoui.ColorPicker(keyedCtx(c, key), &col)
			}
			if out != nil {
				out.IntVal = int64(packColor(col))
				out.BoolVal = u8Bool(f.cur.Changed())
			}

		case opAvatar:
			name, ok := r.str()
			if !ok {
				return
			}
			f.cur = mygoui.Avatar(c, name, nil)

		case opBreadcrumbs:
			key, ok1 := r.str()
			chosenIn, ok2 := r.i32()
			items, ok3 := r.strList()
			if !ok1 || !ok2 || !ok3 {
				return
			}
			chosen := int(chosenIn)
			f.cur = mygoui.Breadcrumbs(keyedCtx(c, key), items, &chosen)
			if out != nil {
				out.IntVal = int64(chosen)
				out.BoolVal = u8Bool(chosen != int(chosenIn))
			}

		case opScrollHorizontal:
			key, ok := r.str()
			if !ok {
				return
			}
			f.cur = mygoui.ScrollHorizontal(keyedCtx(c, key))

		case opScrollBoth:
			key, ok := r.str()
			if !ok {
				return
			}
			f.cur = mygoui.ScrollBoth(keyedCtx(c, key))

		case opDecimalInput:
			key, ok1 := r.str()
			val, ok2 := r.str()
			lo, ok3 := r.str()
			hi, ok4 := r.str()
			step, ok5 := r.str()
			if !ok1 || !ok2 || !ok3 || !ok4 || !ok5 {
				return
			}
			curText := val
			f.cur = mygoui.DecimalInput(keyedCtx(c, key), &curText, lo, hi, step)
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

		case opCheckboxGroup:
			key, ok1 := r.str()
			label, ok2 := r.str()
			bodyCbID, ok3 := r.u64()
			bodyUD, ok4 := r.u64()
			if !ok1 || !ok2 || !ok3 || !ok4 {
				return
			}
			wh, th := f.host, f.theme
			f.cur = mygoui.CheckboxGroup(keyedCtx(c, key), label, func() {
				runSubview(c, wh, th, uintptr(bodyCbID), uintptr(bodyUD))
			})

		case opRadioGroup, opToggleGroup:
			key, ok1 := r.str()
			bodyCbID, ok2 := r.u64()
			bodyUD, ok3 := r.u64()
			if !ok1 || !ok2 || !ok3 {
				return
			}
			wh, th := f.host, f.theme
			body := func() { runSubview(c, wh, th, uintptr(bodyCbID), uintptr(bodyUD)) }
			if op == opToggleGroup {
				f.cur = mygoui.ToggleGroup(keyedCtx(c, key), body)
			} else {
				f.cur = mygoui.RadioGroup(keyedCtx(c, key), body)
			}

		case opFieldset:
			key, ok1 := r.str()
			legend, ok2 := r.str()
			bodyCbID, ok3 := r.u64()
			bodyUD, ok4 := r.u64()
			if !ok1 || !ok2 || !ok3 || !ok4 {
				return
			}
			wh, th := f.host, f.theme
			f.cur = mygoui.Fieldset(keyedCtx(c, key), legend, func() {
				runSubview(c, wh, th, uintptr(bodyCbID), uintptr(bodyUD))
			})

		case opAccordion:
			key, ok1 := r.str()
			bodyCbID, ok2 := r.u64()
			bodyUD, ok3 := r.u64()
			if !ok1 || !ok2 || !ok3 {
				return
			}
			wh, th := f.host, f.theme
			f.cur = mygoui.Accordion(keyedCtx(c, key), func() {
				runSubview(c, wh, th, uintptr(bodyCbID), uintptr(bodyUD))
			})

		case opAccordionItem:
			key, ok1 := r.str()
			title, ok2 := r.str()
			openByte, ok3 := r.u8()
			bodyCbID, ok4 := r.u64()
			bodyUD, ok5 := r.u64()
			if !ok1 || !ok2 || !ok3 || !ok4 || !ok5 {
				return
			}
			open := openByte != 0
			wh, th := f.host, f.theme
			f.cur = mygoui.AccordionItem(keyedCtx(c, key), title, &open, func() {
				runSubview(c, wh, th, uintptr(bodyCbID), uintptr(bodyUD))
			})
			if out != nil {
				out.BoolVal = u8Bool(open)
			}

		case opModal:
			key, ok1 := r.str()
			openByte, ok2 := r.u8()
			bodyCbID, ok3 := r.u64()
			bodyUD, ok4 := r.u64()
			if !ok1 || !ok2 || !ok3 || !ok4 {
				return
			}
			open := openByte != 0
			wh, th := f.host, f.theme
			f.cur = mygoui.Modal(keyedCtx(c, key), &open, func() {
				runSubview(c, wh, th, uintptr(bodyCbID), uintptr(bodyUD))
			})
			if out != nil {
				out.BoolVal = u8Bool(open)
			}

		case opPopover:
			openByte, ok1 := r.u8()
			bodyCbID, ok2 := r.u64()
			bodyUD, ok3 := r.u64()
			if !ok1 || !ok2 || !ok3 {
				return
			}
			open := openByte != 0
			anchor := f.cur
			wh, th := f.host, f.theme
			f.cur = mygoui.Popover(c, anchor, &open, func() {
				runSubview(c, wh, th, uintptr(bodyCbID), uintptr(bodyUD))
			})
			if out != nil {
				out.BoolVal = u8Bool(open)
			}

		case opField:
			key, ok1 := r.str()
			label, ok2 := r.str()
			bodyCbID, ok3 := r.u64()
			bodyUD, ok4 := r.u64()
			if !ok1 || !ok2 || !ok3 || !ok4 {
				return
			}
			wh, th := f.host, f.theme
			f.cur = mygoui.Field(keyedCtx(c, key), label, func() {
				runSubview(c, wh, th, uintptr(bodyCbID), uintptr(bodyUD))
			})

		case opForm:
			key, ok1 := r.str()
			bodyCbID, ok2 := r.u64()
			bodyUD, ok3 := r.u64()
			if !ok1 || !ok2 || !ok3 {
				return
			}
			wh, th := f.host, f.theme
			f.cur = mygoui.Form(keyedCtx(c, key), func() {
				runSubview(c, wh, th, uintptr(bodyCbID), uintptr(bodyUD))
			})

		case opOverlay:
			bodyCbID, ok1 := r.u64()
			bodyUD, ok2 := r.u64()
			if !ok1 || !ok2 {
				return
			}
			wh, th := f.host, f.theme
			mygoui.Overlay(c, func() {
				runSubview(c, wh, th, uintptr(bodyCbID), uintptr(bodyUD))
			})

		case opTokenField:
			key, ok1 := r.str()
			tokens, ok2 := r.strList()
			suggestions, ok3 := r.strList()
			if !ok1 || !ok2 || !ok3 {
				return
			}
			cur := append([]string(nil), tokens...)
			f.cur = mygoui.TokenField(keyedCtx(c, key), &cur, suggestions)
			if out != nil {
				out.BoolVal = u8Bool(f.cur.Changed())
				out.IntVal = int64(len(cur))
				if savedBufPtr != 0 && savedBufCap > 0 {
					n := writeStrList(host.BytesView(savedBufPtr, savedBufCap), cur)
					out.TextLen = uintptr(n)
				}
			}

		case opTree:
			key, ok1 := r.str()
			bodyCbID, ok2 := r.u64()
			bodyUD, ok3 := r.u64()
			if !ok1 || !ok2 || !ok3 {
				return
			}
			wh, th := f.host, f.theme
			f.cur = mygoui.Tree(keyedCtx(c, key), func() {
				runSubview(c, wh, th, uintptr(bodyCbID), uintptr(bodyUD))
			})

		case opTreeItem:
			key, ok1 := r.str()
			label, ok2 := r.str()
			openByte, ok3 := r.u8()
			hasKids, ok4 := r.u8()
			bodyCbID, ok5 := r.u64()
			bodyUD, ok6 := r.u64()
			if !ok1 || !ok2 || !ok3 || !ok4 || !ok5 || !ok6 {
				return
			}
			open := openByte != 0
			var openPtr *bool
			if hasKids != 0 {
				openPtr = &open
			}
			wh, th := f.host, f.theme
			var kids func()
			if hasKids != 0 {
				kids = func() { runSubview(c, wh, th, uintptr(bodyCbID), uintptr(bodyUD)) }
			}
			f.cur = mygoui.TreeItem(keyedCtx(c, key), label, openPtr, kids)
			if out != nil && hasKids != 0 {
				out.BoolVal = u8Bool(open)
			}

		case opGrid:
			key, ok := r.str()
			if !ok {
				return
			}
			f.cur = mygoui.Grid(keyedCtx(c, key))

		case opEditableText:
			key, ok1 := r.str()
			val, ok2 := r.str()
			if !ok1 || !ok2 {
				return
			}
			curText := val
			f.cur = mygoui.EditableText(keyedCtx(c, key), &curText)
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

		case opFindBar:
			key, ok1 := r.str()
			openByte, ok2 := r.u8()
			query, ok3 := r.str()
			matches, ok4 := r.i32()
			currentIn, ok5 := r.i32()
			if !ok1 || !ok2 || !ok3 || !ok4 || !ok5 {
				return
			}
			open := openByte != 0
			curQuery := query
			current := int(currentIn)
			f.cur = mygoui.FindBar(keyedCtx(c, key), &open, &curQuery, int(matches), &current)
			if out != nil {
				out.BoolVal = u8Bool(open)
				out.IntVal = int64(current)
				if savedBufPtr != 0 && savedBufCap > 0 {
					n := min(len(curQuery), int(savedBufCap))
					if n > 0 {
						copy(host.BytesView(savedBufPtr, uintptr(n)), curQuery[:n])
					}
					out.TextLen = uintptr(n)
				}
			}

		case opToolbar:
			key, ok1 := r.str()
			bodyCbID, ok2 := r.u64()
			bodyUD, ok3 := r.u64()
			if !ok1 || !ok2 || !ok3 {
				return
			}
			wh, th := f.host, f.theme
			f.cur = mygoui.Toolbar(keyedCtx(c, key), func() {
				runSubview(c, wh, th, uintptr(bodyCbID), uintptr(bodyUD))
			})

		case opThemed:
			dark, ok0 := r.u8()
			bg, ok1 := r.u32()
			surf, ok2 := r.u32()
			surfH, ok3 := r.u32()
			surfP, ok4 := r.u32()
			border, ok5 := r.u32()
			textC, ok6 := r.u32()
			muted, ok7 := r.u32()
			accent, ok8 := r.u32()
			accentT, ok9 := r.u32()
			danger, ok10 := r.u32()
			warn, ok11 := r.u32()
			succ, ok12 := r.u32()
			radius, ok13 := r.f32()
			spacing, ok14 := r.f32()
			fontSize, ok15 := r.f32()
			if !ok0 || !ok1 || !ok2 || !ok3 || !ok4 || !ok5 || !ok6 || !ok7 || !ok8 || !ok9 || !ok10 || !ok11 || !ok12 || !ok13 || !ok14 || !ok15 {
				return
			}
			f.cur = mygoui.Themed(c, themeFromC(cUITheme{
				Dark:           dark,
				Background:     bg,
				Surface:        surf,
				SurfaceHover:   surfH,
				SurfacePressed: surfP,
				Border:         border,
				Text:           textC,
				TextMuted:      muted,
				Accent:         accent,
				AccentText:     accentT,
				Danger:         danger,
				Warning:        warn,
				Success:        succ,
				Radius:         radius,
				Spacing:        spacing,
				FontSize:       fontSize,
			}))

		case opIcon:
			data, ok := r.str()
			if !ok {
				return
			}
			if svg, err := cachedSVG([]byte(data)); err == nil {
				f.cur = mygoui.Icon(c, svg)
			} else {
				f.cur = mygoui.Box(c)
			}

		case opImage:
			data, ok := r.str()
			if !ok {
				return
			}
			if src, err := cachedImage([]byte(data)); err == nil {
				f.cur = mygoui.Image(c, src)
			} else {
				f.cur = mygoui.Box(c)
			}

		case opToast:
			msg, ok := r.str()
			if !ok {
				return
			}
			c.Toast(msg)

		case opToastAction:
			msg, ok1 := r.str()
			label, ok2 := r.str()
			cbID, ok3 := r.u64()
			ud, ok4 := r.u64()
			if !ok1 || !ok2 || !ok3 || !ok4 {
				return
			}
			wh := f.host
			c.ToastAction(msg, label, func() {
				wh.callZig(host.ZigEventUIAction, uintptr(cbID), 0, 0, uintptr(ud))
			})

		case opContextMenu, opPopoverMenu:
			nodes, ok := readMenuTree(&r)
			if !ok {
				return
			}
			var chosenID string
			build := func(m *mygoui.Menu) { applyMenu(m, nodes, &chosenID) }
			if op == opPopoverMenu {
				f.cur = f.cur.PopoverMenu(build)
			} else {
				f.cur = f.cur.ContextMenu(build)
			}
			writeChosenID(out, savedBufPtr, savedBufCap, chosenID)

		case opPopoverMenuBtn:
			key, ok1 := r.str()
			label, ok2 := r.str()
			nodes, ok3 := readMenuTree(&r)
			if !ok1 || !ok2 || !ok3 {
				return
			}
			var chosenID string
			f.cur = mygoui.PopoverMenuButton(keyedCtx(c, key), label, func(m *mygoui.Menu) {
				applyMenu(m, nodes, &chosenID)
			})
			writeChosenID(out, savedBufPtr, savedBufCap, chosenID)

		case opMenuButton:
			key, ok1 := r.str()
			label, ok2 := r.str()
			nodes, ok3 := readMenuTree(&r)
			if !ok1 || !ok2 || !ok3 {
				return
			}
			var chosenID string
			f.cur = mygoui.MenuButton(keyedCtx(c, key), label, func(m *mygoui.Menu) {
				applyMenu(m, nodes, &chosenID)
			})
			writeChosenID(out, savedBufPtr, savedBufCap, chosenID)

		case opOutline:
			key, ok1 := r.str()
			selectedIn, ok2 := r.i32()
			openIDs, ok3 := r.strList()
			roots, ok4 := r.strList()
			branches, ok5 := r.u16()
			if !ok1 || !ok2 || !ok3 || !ok4 || !ok5 {
				return
			}
			// Only branches are listed. Absent id → leaf (children returns nil).
			// Present with empty kids → empty branch.
			childrenOf := map[string][]string{}
			for range int(branches) {
				id, okID := r.str()
				kids, okKids := r.strList()
				if !okID || !okKids {
					return
				}
				childrenOf[id] = kids
			}
			rowCbID, ok6 := r.u64()
			rowUD, ok7 := r.u64()
			if !ok6 || !ok7 {
				return
			}
			zo := f.host.outlines[key]
			if zo == nil {
				zo = &zigOutline{selected: int(selectedIn)}
				f.host.outlines[key] = zo
			} else {
				zo.selected = int(selectedIn)
			}
			zo.state.List.Selected = &zo.selected
			zo.state.Open = mygoui.Selection[string]{}
			for _, id := range openIDs {
				zo.state.Open.Add(id)
			}
			wh, th := f.host, f.theme
			f.cur = mygoui.Outline(keyedCtx(c, key), &zo.state, roots, func(id string) []string {
				kids, ok := childrenOf[id]
				if !ok {
					return nil
				}
				return kids
			}, func(item string) {
				row := -1
				for i := 0; i < zo.state.Rows(); i++ {
					if zo.state.Item(i) == item {
						row = i
						break
					}
				}
				depth := 0
				if row >= 0 {
					depth = zo.state.Depth(row)
				}
				_, isBranch := childrenOf[item]
				info := cUIOutlineRowInfo{
					WindowID: wh.winID,
					Index:    int32(row),
					Depth:    int32(depth),
					Selected: u8Bool(zo.selected == row),
					Branch:   u8Bool(isBranch),
					Open:     u8Bool(zo.state.Open.Has(item)),
					Theme:    th,
					IDPtr:    uintptr(unsafe.Pointer(unsafe.StringData(item))),
					IDLen:    uintptr(len(item)),
				}
				runFrame(c, wh, th, func(rowHandle uintptr) {
					wh.callZig(host.ZigEventUIOutlineRow, uintptr(rowCbID), rowHandle, uintptr(unsafe.Pointer(&info)), uintptr(rowUD))
				})
			})
			if out != nil {
				out.IntVal = int64(zo.selected)
				out.BoolVal = u8Bool(f.cur.Changed())
				if savedBufPtr != 0 && savedBufCap > 0 {
					opened := make([]string, 0, zo.state.Open.Len())
					for id := range zo.state.Open.All() {
						opened = append(opened, id)
					}
					n := writeStrList(host.BytesView(savedBufPtr, savedBufCap), opened)
					out.TextLen = uintptr(n)
				}
			}

		case opRichText:
			nSpans, ok := r.u16()
			if !ok {
				return
			}
			spans := make([]mygoui.Span, 0, int(nSpans))
			for range int(nSpans) {
				text, ok1 := r.str()
				flags, ok2 := r.u8()
				weight, ok3 := r.u16()
				size, ok4 := r.f32()
				rgba, ok5 := r.u32()
				if !ok1 || !ok2 || !ok3 || !ok4 || !ok5 {
					return
				}
				sp := mygoui.Span{
					Text:          text,
					Weight:        int(weight),
					Size:          size,
					Italic:        flags&1 != 0,
					Underline:     flags&2 != 0,
					Strikethrough: flags&8 != 0,
				}
				if flags&4 != 0 {
					sp.Color = unpackColor(rgba)
				}
				if flags&16 != 0 { // object replacement
					ow, okW := r.f32()
					oh, okH := r.f32()
					od, okD := r.f32()
					if !okW || !okH || !okD {
						return
					}
					sp.ObjectWidth = ow
					sp.ObjectHeight = oh
					sp.ObjectDescent = od
				}
				if flags&32 != 0 {
					bg, okBG := r.u32()
					if !okBG {
						return
					}
					sp.Background = unpackColor(bg)
				}
				spans = append(spans, sp)
			}
			f.cur = mygoui.RichText(c, spans...)

		case opRouter:
			key, ok1 := r.str()
			initial, ok2 := r.str()
			pageCbID, ok3 := r.u64()
			pageUD, ok4 := r.u64()
			if !ok1 || !ok2 || !ok3 || !ok4 {
				return
			}
			rt := f.host.routers[key]
			if rt == nil {
				rt = mygoui.NewRouter(initial)
				f.host.routers[key] = rt
			}
			wh, th := f.host, f.theme
			f.cur = rt.View(keyedCtx(c, key), func(route *mygoui.Route) {
				path := route.Path()
				info := cUIRouteInfo{
					WindowID: wh.winID,
					Theme:    th,
					PathPtr:  uintptr(unsafe.Pointer(unsafe.StringData(path))),
					PathLen:  uintptr(len(path)),
				}
				runFrame(c, wh, th, func(pageHandle uintptr) {
					if idx := int(pageHandle) - 1; idx >= 0 && idx < len(activeFrames) {
						activeFrames[idx].route = route
					}
					wh.callZig(host.ZigEventUIRoute, uintptr(pageCbID), pageHandle, uintptr(unsafe.Pointer(&info)), uintptr(pageUD))
				})
			})
			if out != nil {
				p := rt.Path()
				out.BoolVal = u8Bool(rt.CanGoBack())
				out.NumVal2 = 0
				if rt.CanGoForward() {
					out.NumVal2 = 1
				}
				if savedBufPtr != 0 && savedBufCap > 0 {
					n := min(len(p), int(savedBufCap))
					if n > 0 {
						copy(host.BytesView(savedBufPtr, uintptr(n)), p[:n])
					}
					out.TextLen = uintptr(n)
				}
			}

		case opRouterPush, opRouterReplace:
			key, ok1 := r.str()
			path, ok2 := r.str()
			if !ok1 || !ok2 {
				return
			}
			if rt := f.host.routers[key]; rt != nil {
				if op == opRouterReplace {
					rt.Replace(path)
				} else {
					rt.Push(path)
				}
			}

		case opRouterBack, opRouterForward:
			key, ok := r.str()
			if !ok {
				return
			}
			if rt := f.host.routers[key]; rt != nil {
				if op == opRouterBack {
					rt.Back()
				} else {
					rt.Forward()
				}
			}

		case opBackButton, opForwardButton:
			key, ok := r.str()
			if !ok {
				return
			}
			rt := f.host.routers[key]
			if rt == nil {
				rt = mygoui.NewRouter("/")
				f.host.routers[key] = rt
			}
			if op == opBackButton {
				f.cur = mygoui.BackButton(c, rt)
			} else {
				f.cur = mygoui.ForwardButton(c, rt)
			}

		case opOutlineTable:
			key, ok1 := r.str()
			selectedIn, ok2 := r.i32()
			openIDs, ok3 := r.strList()
			roots, ok4 := r.strList()
			branches, ok5 := r.u16()
			if !ok1 || !ok2 || !ok3 || !ok4 || !ok5 {
				return
			}
			childrenOf := map[string][]string{}
			for range int(branches) {
				id, okID := r.str()
				kids, okKids := r.strList()
				if !okID || !okKids {
					return
				}
				childrenOf[id] = kids
			}
			colCount, ok6 := r.u16()
			if !ok6 {
				return
			}
			cols := make([]mygoui.TableColumn, int(colCount))
			for i := range int(colCount) {
				title, okT := r.str()
				w, okW := r.f32()
				al, okA := r.u8()
				if !okT || !okW || !okA {
					return
				}
				cols[i] = mygoui.TableColumn{
					Title: title,
					ID:    strconv.Itoa(i) + ":" + title,
					Width: w,
					Align: mygoui.Align(al),
				}
			}
			cellCbID, ok7 := r.u64()
			cellUD, ok8 := r.u64()
			if !ok7 || !ok8 {
				return
			}
			zo := f.host.outlines[key]
			if zo == nil {
				zo = &zigOutline{selected: int(selectedIn)}
				f.host.outlines[key] = zo
			} else {
				zo.selected = int(selectedIn)
			}
			zo.state.List.Selected = &zo.selected
			zo.state.Open = mygoui.Selection[string]{}
			for _, id := range openIDs {
				zo.state.Open.Add(id)
			}
			wh, th := f.host, f.theme
			f.cur = mygoui.OutlineTable(keyedCtx(c, key), &zo.state, cols, roots, func(id string) []string {
				kids, ok := childrenOf[id]
				if !ok {
					return nil
				}
				return kids
			}, func(item string, col int) {
				row := -1
				for i := 0; i < zo.state.Rows(); i++ {
					if zo.state.Item(i) == item {
						row = i
						break
					}
				}
				depth := 0
				if row >= 0 {
					depth = zo.state.Depth(row)
				}
				_, isBranch := childrenOf[item]
				info := cUIOutlineCellInfo{
					WindowID: wh.winID,
					Row:      int32(row),
					Col:      int32(col),
					Depth:    int32(depth),
					Selected: u8Bool(zo.selected == row),
					Branch:   u8Bool(isBranch),
					Open:     u8Bool(zo.state.Open.Has(item)),
					Theme:    th,
					IDPtr:    uintptr(unsafe.Pointer(unsafe.StringData(item))),
					IDLen:    uintptr(len(item)),
				}
				runFrame(c, wh, th, func(cellHandle uintptr) {
					wh.callZig(host.ZigEventUIOutlineCell, uintptr(cellCbID), cellHandle, uintptr(unsafe.Pointer(&info)), uintptr(cellUD))
				})
			})
			if out != nil {
				out.IntVal = int64(zo.selected)
				out.BoolVal = u8Bool(f.cur.Changed())
				if savedBufPtr != 0 && savedBufCap > 0 {
					opened := make([]string, 0, zo.state.Open.Len())
					for id := range zo.state.Open.All() {
						opened = append(opened, id)
					}
					n := writeStrList(host.BytesView(savedBufPtr, savedBufCap), opened)
					out.TextLen = uintptr(n)
				}
			}

		case opDrag:
			payload, ok := r.str()
			if !ok {
				return
			}
			f.cur = f.cur.Drag(payload)

		case opDrop:
			v, okDrop := mygoui.Drop[string](f.cur)
			if okDrop {
				writeChosenID(out, savedBufPtr, savedBufCap, v)
			}

		case opDragOver:
			v, okOver := mygoui.DragOver[string](f.cur)
			if okOver {
				writeChosenID(out, savedBufPtr, savedBufCap, v)
			}

		case opDraggable:
			x, ok1 := r.f32()
			y, ok2 := r.f32()
			axis, ok3 := r.u8()
			hasBounds, ok4 := r.u8()
			if !ok1 || !ok2 || !ok3 || !ok4 {
				return
			}
			off := mygoui.Point{X: x, Y: y}
			opts := mygoui.DraggableOptions{}
			switch axis {
			case 1:
				opts.Axis = mygoui.Horizontal
			case 2:
				opts.Axis = mygoui.Vertical
			}
			if hasBounds != 0 {
				bx, okB1 := r.f32()
				by, okB2 := r.f32()
				bw, okB3 := r.f32()
				bh, okB4 := r.f32()
				rigid, okB5 := r.u8()
				if !okB1 || !okB2 || !okB3 || !okB4 || !okB5 {
					return
				}
				bounds := mygoui.Rect{X: bx, Y: by, W: bw, H: bh}
				opts.Bounds = &bounds
				opts.Rigid = rigid != 0
			}
			snapCount, okSnap := r.u16()
			if !okSnap {
				return
			}
			if snapCount > 0 {
				points := make([]mygoui.Point, int(snapCount))
				for i := range points {
					sx, okSX := r.f32()
					sy, okSY := r.f32()
					if !okSX || !okSY {
						return
					}
					points[i] = mygoui.Point{X: sx, Y: sy}
				}
				opts.Snap = mygoui.Nearest(points...)
			}
			f.cur = f.cur.Draggable(&off, opts)
			if out != nil {
				out.NumVal = float64(off.X)
				out.NumVal2 = float64(off.Y)
			}

		case opVideo:
			key, ok1 := r.str()
			fit, ok2 := r.u8()
			if !ok1 || !ok2 {
				return
			}
			p := f.host.videos[key]
			if p == nil {
				var (
					dec  mygoui.VideoDecoder
					loop bool
					err  error
				)
				if raw, ok := gifRegistry.Load(key); ok {
					asset := raw.(gifAsset)
					dec, err = mygoui.NewGIFDecoder(asset.data)
					loop = asset.loop
				} else if raw, ok := framesRegistry.Load(key); ok {
					asset := raw.(framesAsset)
					dec = &rgbaFramesDecoder{w: asset.w, h: asset.h, frames: asset.frames}
					loop = asset.loop
				} else if raw, ok := streamRegistry.Load(key); ok {
					asset := raw.(*streamAsset)
					dec = &streamDecoder{a: asset}
					loop = asset.loop
				} else {
					host.SetError(fmt.Errorf("zighost: video %q not registered (GIF/Frames/Stream first)", key))
					return
				}
				if err != nil {
					host.SetError(err)
					return
				}
				p, err = mygoui.NewVideoPlayer(dec)
				if err != nil {
					host.SetError(err)
					return
				}
				if loop {
					p.SetLoop(true)
				}
				f.host.videos[key] = p
			}
			e := mygoui.Video(c, p)
			switch fit {
			case 1:
				e = e.Fit(mygoui.Cover)
			case 2:
				e = e.Fit(mygoui.FillBox)
			case 3:
				e = e.Fit(mygoui.ScaleDown)
			default:
				e = e.Fit(mygoui.Contain)
			}
			f.cur = e
			if out != nil {
				out.BoolVal = u8Bool(p.Playing())
			}

		case opVideoControl:
			key, ok1 := r.str()
			ctl, ok2 := r.u8() // 1=play, 2=pause, 3=close
			if !ok1 || !ok2 {
				return
			}
			p := f.host.videos[key]
			if p == nil {
				return
			}
			switch ctl {
			case 1:
				p.Play()
			case 2:
				p.Pause()
			case 3:
				p.Close()
				delete(f.host.videos, key)
			}

		case opRouteMatch:
			pattern, ok := r.str()
			if !ok {
				return
			}
			if f.route == nil {
				if out != nil {
					out.BoolVal = 0
				}
				return
			}
			if out != nil {
				out.BoolVal = u8Bool(f.route.Match(pattern))
			}

		case opRouteParam:
			name, ok := r.str()
			if !ok {
				return
			}
			if f.route == nil {
				return
			}
			writeChosenID(out, savedBufPtr, savedBufCap, f.route.Param(name))

		case opRouteView:
			pageCbID, ok1 := r.u64()
			pageUD, ok2 := r.u64()
			if !ok1 || !ok2 {
				return
			}
			if f.route == nil {
				host.SetError(errors.New("zighost: routeView only works inside a router page"))
				return
			}
			wh, th := f.host, f.theme
			f.cur = f.route.View(c, func(inner *mygoui.Route) {
				path := inner.Path()
				info := cUIRouteInfo{
					WindowID: wh.winID,
					Theme:    th,
					PathPtr:  uintptr(unsafe.Pointer(unsafe.StringData(path))),
					PathLen:  uintptr(len(path)),
				}
				runFrame(c, wh, th, func(pageHandle uintptr) {
					if idx := int(pageHandle) - 1; idx >= 0 && idx < len(activeFrames) {
						activeFrames[idx].route = inner
					}
					wh.callZig(host.ZigEventUIRoute, uintptr(pageCbID), pageHandle, uintptr(unsafe.Pointer(&info)), uintptr(pageUD))
				})
			})

		case opDrawObjects:
			paintCbID, ok1 := r.u64()
			paintUD, ok2 := r.u64()
			if !ok1 || !ok2 {
				return
			}
			wh := f.host
			f.cur = f.cur.DrawObjects(func(p *mygoui.Painter, at int, rect mygoui.Rect) {
				activePainters = append(activePainters, p)
				pHandle := uintptr(len(activePainters))
				cr := cUIRect{
					X:         rect.X,
					Y:         rect.Y,
					W:         rect.W,
					H:         rect.H,
					NowMillis: p.Now().UnixMilli(),
					At:        int32(at),
				}
				wh.callZig(host.ZigEventUIPaint, uintptr(paintCbID), pHandle, uintptr(unsafe.Pointer(&cr)), uintptr(paintUD))
				activePainters[len(activePainters)-1] = nil
				activePainters = activePainters[:len(activePainters)-1]
			})

		case opToastViewport:
			bodyCbID, ok1 := r.u64()
			bodyUD, ok2 := r.u64()
			if !ok1 || !ok2 {
				return
			}
			wh, th := f.host, f.theme
			f.cur = mygoui.ToastViewportBase(c, func(viewport mygoui.Element, toasts []mygoui.Toast) {
				runFrame(c, wh, th, func(handle uintptr) {
					idx := int(handle) - 1
					if idx >= 0 && idx < len(activeFrames) && activeFrames[idx] != nil {
						activeFrames[idx].cur = viewport
						activeFrames[idx].toasts = toasts
					}
					info := cUIFrameInfo{
						WindowID:     wh.winID,
						WindowActive: 1,
						Theme:        th,
					}
					// Pack toast count into Width so Zig knows how many toastItem calls to make.
					info.Width = float32(len(toasts))
					wh.callZig(host.ZigEventUISubview, uintptr(bodyCbID), handle, uintptr(unsafe.Pointer(&info)), uintptr(bodyUD))
				})
			})

		case opToastItem:
			index, ok := r.i32()
			if !ok {
				return
			}
			if index < 0 || int(index) >= len(f.toasts) {
				return
			}
			ts := f.toasts[index]
			parts := mygoui.ToastBase(c, ts)
			f.toastParts = parts
			f.hasToast = true
			f.cur = parts.Root
			if out != nil {
				out.BoolVal = u8Bool(ts.Action != "")
				// Title\nDescription\nType\nAction\nData
				dataStr := ""
				var user uintptr
				switch d := ts.Data.(type) {
				case ZigToastData:
					dataStr, user = d.Text, d.User
				case string:
					dataStr = d
				}
				payload := ts.Title + "\n" + ts.Description + "\n" + ts.Type + "\n" + ts.Action + "\n" + dataStr
				writeChosenID(out, savedBufPtr, savedBufCap, payload)
				out.NumVal = float64(user)
			}

		case opToastCloseBtn:
			if !f.hasToast {
				return
			}
			f.cur = f.toastParts.CloseButton()

		case opToastActionBtn:
			if !f.hasToast {
				return
			}
			f.cur = f.toastParts.ActionButton()

		case opWebView:
			key, ok1 := r.str()
			url, ok2 := r.str()
			if !ok1 || !ok2 {
				return
			}
			wv := f.host.webviews[key]
			if wv == nil || wv.IsDestroyed() {
				if f.host.win == nil {
					host.SetError(errors.New("zighost: webview needs a native UI window"))
					return
				}
				var err error
				wv, err = f.host.win.NewWebView(mygo.WebViewOptions{URL: url})
				if err != nil {
					host.SetError(err)
					return
				}
				f.host.webviews[key] = wv
				f.host.wvURLs[key] = url
			} else if url != "" && url != f.host.wvURLs[key] {
				if err := wv.Page().LoadURL(url); err != nil {
					host.SetError(err)
				} else {
					f.host.wvURLs[key] = url
				}
			}
			f.cur = mygoui.WebView(c, wv)

		case opWebViewDestroy:
			key, ok := r.str()
			if !ok {
				return
			}
			if wv := f.host.webviews[key]; wv != nil {
				wv.Destroy()
				delete(f.host.webviews, key)
				delete(f.host.wvURLs, key)
			}

		case opDragData:
			text, ok := r.str()
			if !ok {
				return
			}
			f.cur = f.cur.DragData(transfer.TextData(text))

		case opDragMIME:
			n, ok := r.u16()
			if !ok {
				return
			}
			reps := make([]transfer.Representation, 0, int(n))
			for range int(n) {
				format, ok1 := r.str()
				payload, ok2 := r.str()
				if !ok1 || !ok2 {
					return
				}
				reps = append(reps, transfer.Bytes(transfer.Format(format), []byte(payload)))
			}
			if len(reps) == 0 {
				return
			}
			f.cur = f.cur.DragData(transfer.New(transfer.NewItem(reps...)))

		case opDragMIMELazy:
			// Advertised formats + Zig provider called when the gesture starts.
			n, ok1 := r.u16()
			cbID, ok2 := r.u64()
			ud, ok3 := r.u64()
			if !ok1 || !ok2 || !ok3 {
				return
			}
			formats := make([]transfer.Format, 0, int(n))
			for range int(n) {
				fmtName, okF := r.str()
				if !okF {
					return
				}
				formats = append(formats, transfer.Format(fmtName))
			}
			if len(formats) == 0 {
				return
			}
			wh := f.host
			f.cur = f.cur.DragDataFrom(func() transfer.Data {
				buf := make([]byte, 64*1024)
				nWritten := wh.callZig(host.ZigEventUIProvide, uintptr(cbID), uintptr(unsafe.Pointer(&buf[0])), uintptr(len(buf)), uintptr(ud))
				if nWritten == 0 || nWritten > uintptr(len(buf)) {
					// Fall back to empty text so the drag still starts.
					return transfer.TextData("")
				}
				reps, ok := parseMIMETape(buf[:nWritten])
				if !ok || len(reps) == 0 {
					return transfer.TextData("")
				}
				return transfer.New(transfer.NewItem(reps...))
			})

		case opAddToast:
			title, ok1 := r.str()
			desc, ok2 := r.str()
			typ, ok3 := r.str()
			data, ok4 := r.str()
			action, ok5 := r.str()
			timeoutMS, ok6 := r.i32()
			cbID, ok7 := r.u64()
			ud, ok8 := r.u64()
			userData, ok9 := r.u64()
			if !ok1 || !ok2 || !ok3 || !ok4 || !ok5 || !ok6 || !ok7 || !ok8 || !ok9 {
				return
			}
			ts := mygoui.Toast{
				Title:       title,
				Description: desc,
				Type:        typ,
				Data: ZigToastData{
					Text: data,
					User: uintptr(userData),
				},
				Action:  action,
				Timeout: time.Duration(timeoutMS) * time.Millisecond,
			}
			if action != "" && cbID != 0 {
				wh := f.host
				ts.OnAction = func() {
					wh.callZig(host.ZigEventUIAction, uintptr(cbID), 0, 0, uintptr(ud))
				}
			}
			id := c.AddToast(ts)
			if out != nil {
				writeChosenID(out, savedBufPtr, savedBufCap, id)
				out.NumVal = float64(userData)
			}

		case opDropData:
			opts := transfer.DropOptions{
				Formats:    []transfer.Format{transfer.Text, transfer.URIList, transfer.FileList},
				Operations: transfer.Copy | transfer.Move,
			}
			if drop, ok := mygoui.DropData(f.cur, opts); ok {
				payload := ""
				if b, err := drop.Data.Read(transfer.Text); err == nil {
					payload = string(b)
				} else if urls, err := drop.Data.URLs(); err == nil && len(urls) > 0 {
					payload = urls[0]
				} else if files, err := drop.Data.Files(); err == nil && len(files) > 0 {
					payload = files[0]
				}
				writeChosenID(out, savedBufPtr, savedBufCap, payload)
			}

		case opDropMIME:
			n, ok := r.u16()
			if !ok {
				return
			}
			formats := make([]transfer.Format, 0, int(n))
			for range int(n) {
				fmtName, okF := r.str()
				if !okF {
					return
				}
				formats = append(formats, transfer.Format(fmtName))
			}
			if len(formats) == 0 {
				formats = []transfer.Format{transfer.Text, transfer.URIList, transfer.FileList}
			}
			opts := transfer.DropOptions{
				Formats:    formats,
				Operations: transfer.Copy | transfer.Move,
			}
			if drop, ok := mygoui.DropData(f.cur, opts); ok {
				format, found := drop.Data.Preferred(formats...)
				payload := ""
				if found {
					if b, err := drop.Data.Read(format); err == nil {
						payload = string(format) + "\n" + string(b)
					}
				}
				if payload == "" {
					if b, err := drop.Data.Read(transfer.Text); err == nil {
						payload = string(transfer.Text) + "\n" + string(b)
					}
				}
				writeChosenID(out, savedBufPtr, savedBufCap, payload)
			}

		case opDataDragOver:
			n, okN := r.u16()
			var formats []transfer.Format
			if okN && n > 0 {
				formats = make([]transfer.Format, 0, int(n))
				for range int(n) {
					fmtName, okF := r.str()
					if !okF {
						return
					}
					formats = append(formats, transfer.Format(fmtName))
				}
			} else {
				formats = []transfer.Format{transfer.Text, transfer.URIList, transfer.FileList}
			}
			opts := transfer.DropOptions{
				Formats:    formats,
				Operations: transfer.Copy | transfer.Move,
			}
			if _, over := mygoui.DataDragOver(f.cur, opts); over {
				if out != nil {
					out.BoolVal = 1
				}
			}

		case opGridView:
			key, ok1 := r.str()
			count, ok2 := r.i32()
			selectedIn, ok3 := r.i32()
			minW, ok4 := r.f32()
			height, ok5 := r.f32()
			itemCbID, ok6 := r.u64()
			itemUD, ok7 := r.u64()
			if !ok1 || !ok2 || !ok3 || !ok4 || !ok5 || !ok6 || !ok7 {
				return
			}
			zg := f.host.grids[key]
			if zg == nil {
				zg = &zigGrid{selected: int(selectedIn)}
				f.host.grids[key] = zg
			} else {
				zg.selected = int(selectedIn)
			}
			zg.state.Selected = &zg.selected
			wh, th := f.host, f.theme
			f.cur = mygoui.GridView(keyedCtx(c, key), &zg.state, int(count), minW, height, func(i int) {
				info := cUIGridItemInfo{
					WindowID: wh.winID,
					Index:    int32(i),
					Selected: u8Bool(zg.selected == i),
					Theme:    th,
				}
				runFrame(c, wh, th, func(itemHandle uintptr) {
					wh.callZig(host.ZigEventUIGridItem, uintptr(itemCbID), itemHandle, uintptr(unsafe.Pointer(&info)), uintptr(itemUD))
				})
			})
			if out != nil {
				out.IntVal = int64(zg.selected)
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

		case opAfter:
			ms, ok := r.i32()
			if !ok {
				return
			}
			if ms < 0 {
				ms = 0
			}
			c.After(time.Duration(ms) * time.Millisecond)

		case opAnimationFrame:
			c.AnimationFrame()

		case opDisableAnims:
			c.DisableAnimations()

		case opInvalidate:
			c.Invalidate()

		case opCloseToast:
			id, ok := r.str()
			if !ok {
				return
			}
			c.CloseToast(id)

		case opAnimate:
			key, ok1 := r.str()
			target, ok2 := r.f32()
			durMS, ok3 := r.i32()
			if !ok1 || !ok2 || !ok3 {
				return
			}
			v := f.cur.Animate(key, target, time.Duration(durMS)*time.Millisecond)
			if out != nil {
				out.NumVal = float64(v)
			}

		case opAnimateTo:
			key, ok1 := r.str()
			target, ok2 := r.f32()
			preset, ok3 := r.u8()
			durMS, ok4 := r.i32()
			delayMS, ok5 := r.i32()
			nonMotion, ok6 := r.u8()
			bounce, ok7 := r.f32()
			if !ok1 || !ok2 || !ok3 || !ok4 || !ok5 || !ok6 || !ok7 {
				return
			}
			a := zigAnim(preset, durMS, delayMS, bounce, nonMotion != 0, false)
			v := f.cur.AnimateTo(key, target, a)
			if out != nil {
				out.NumVal = float64(v)
			}

		case opArrived:
			key, ok := r.str()
			if !ok {
				return
			}
			if out != nil {
				out.BoolVal = u8Bool(f.cur.Arrived(key))
			}

		case opAnimateColor:
			key, ok1 := r.str()
			rgba, ok2 := r.u32()
			preset, ok3 := r.u8()
			durMS, ok4 := r.i32()
			delayMS, ok5 := r.i32()
			nonMotion, ok6 := r.u8()
			oklab, ok7 := r.u8()
			if !ok1 || !ok2 || !ok3 || !ok4 || !ok5 || !ok6 || !ok7 {
				return
			}
			target := colorFromU32(rgba)
			a := zigAnim(preset, durMS, delayMS, 0, nonMotion != 0, oklab != 0)
			col := f.cur.AnimateColor(key, target, a)
			if out != nil {
				out.IntVal = int64(colorToU32(col))
			}

		case opAnimatePose:
			x, ok1 := r.f32()
			y, ok2 := r.f32()
			scale, ok3 := r.f32()
			rotate, ok4 := r.f32()
			fade, ok5 := r.f32()
			xPct, ok6 := r.f32()
			yPct, ok7 := r.f32()
			preset, ok8 := r.u8()
			durMS, ok9 := r.i32()
			delayMS, ok10 := r.i32()
			if !ok1 || !ok2 || !ok3 || !ok4 || !ok5 || !ok6 || !ok7 || !ok8 || !ok9 || !ok10 {
				return
			}
			a := zigAnim(preset, durMS, delayMS, 0, false, false)
			f.cur = f.cur.AnimatePose(mygoui.Pose{
				X: x, Y: y, Scale: scale, Rotate: rotate, Fade: fade,
				XPercent: xPct, YPercent: yPct,
			}, a)

		case opSpring:
			key, ok1 := r.str()
			target, ok2 := r.f32()
			bounce, ok3 := r.f32()
			durMS, ok4 := r.i32()
			velocity, ok5 := r.f32()
			if !ok1 || !ok2 || !ok3 || !ok4 || !ok5 {
				return
			}
			opt := mygoui.SpringOptions{Bounce: float64(bounce), Velocity: velocity}
			if durMS > 0 {
				opt.Duration = time.Duration(durMS) * time.Millisecond
			}
			v := f.cur.Spring(key, target, opt)
			if out != nil {
				out.NumVal = float64(v)
			}

		case opRole:
			role, ok := r.u8()
			if !ok {
				return
			}
			f.cur = f.cur.Role(mygoui.Role(role))

		case opLinearGradient:
			angle, ok1 := r.f32()
			from, ok2 := r.u32()
			to, ok3 := r.u32()
			oklab, ok4 := r.u8()
			if !ok1 || !ok2 || !ok3 || !ok4 {
				return
			}
			f.cur = f.cur.LinearGradient(mygoui.LinearGradient{
				Angle: angle,
				From:  unpackColor(from),
				To:    unpackColor(to),
				Oklab: oklab != 0,
			})

		case opBitmap:
			key, ok := r.str()
			if !ok {
				return
			}
			if raw, ok := bitmapRegistry.Load(key); ok {
				f.cur = mygoui.Image(c, raw.(*mygoui.Bitmap))
			} else {
				host.SetError(fmt.Errorf("zighost: bitmap %q not registered", key))
				f.cur = mygoui.Box(c)
			}

		case opCanvas:
			key, ok := r.str()
			if !ok {
				return
			}
			if raw, ok := canvasRegistry.Load(key); ok {
				f.cur = mygoui.Image(c, raw.(*mygoui.Canvas).Bitmap())
			} else {
				host.SetError(fmt.Errorf("zighost: canvas %q not registered", key))
				f.cur = mygoui.Box(c)
			}

		case opLinearGradStops:
			angle, ok1 := r.f32()
			oklab, ok2 := r.u8()
			if !ok1 || !ok2 {
				return
			}
			stops, ok := readGradientStops(&r)
			if !ok || len(stops) == 0 {
				return
			}
			f.cur = f.cur.LinearGradient(mygoui.LinearGradient{Angle: angle, Oklab: oklab != 0, Stops: stops})

		case opConicGradient:
			angle, ok1 := r.f32()
			cx, ok2 := r.f32()
			cy, ok3 := r.f32()
			oklab, ok4 := r.u8()
			if !ok1 || !ok2 || !ok3 || !ok4 {
				return
			}
			stops, ok := readGradientStops(&r)
			if !ok || len(stops) == 0 {
				return
			}
			f.cur = f.cur.ConicGradient(mygoui.ConicGradient{
				Angle: angle, Center: mygoui.Point{X: cx, Y: cy}, Oklab: oklab != 0, Stops: stops,
			})

		case opRadialGradient:
			radius, ok1 := r.f32()
			cx, ok2 := r.f32()
			cy, ok3 := r.f32()
			oklab, ok4 := r.u8()
			if !ok1 || !ok2 || !ok3 || !ok4 {
				return
			}
			stops, ok := readGradientStops(&r)
			if !ok || len(stops) == 0 {
				return
			}
			f.cur = f.cur.RadialGradient(mygoui.RadialGradient{
				Radius: radius, Center: mygoui.Point{X: cx, Y: cy}, Oklab: oklab != 0, Stops: stops,
			})

		default:
			return
		}
	}
}

func readGradientStops(r *tapeReader) ([]mygoui.GradientStop, bool) {
	n, ok := r.u8()
	if !ok {
		return nil, false
	}
	if n > 16 {
		n = 16
	}
	stops := make([]mygoui.GradientStop, 0, int(n))
	for range int(n) {
		rgba, ok1 := r.u32()
		at, ok2 := r.f32()
		if !ok1 || !ok2 {
			return nil, false
		}
		stops = append(stops, mygoui.GradientStop{Color: unpackColor(rgba), At: at})
	}
	return stops, true
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
	flushPaintTape(p, &r, false)
}

func flushPaintTape(p *mygoui.Painter, r *tapeReader, stopOnCanvasEnd bool) {
	var path *mygoui.Path
	for {
		op, ok := r.u8()
		if !ok {
			return
		}
		if stopOnCanvasEnd && op == paintCanvasEnd {
			return
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
		case paintPathBegin:
			rule, ok1 := r.u8()
			cap, ok2 := r.u8()
			join, ok3 := r.u8()
			miter, ok4 := r.f32()
			if !ok1 || !ok2 || !ok3 || !ok4 {
				return
			}
			path = &mygoui.Path{}
			path.FillRule(mygoui.FillRule(rule))
			path.Cap(mygoui.LineCap(cap))
			path.Join(mygoui.LineJoin(join))
			if miter > 0 {
				path.MiterLimit(miter)
			}
		case paintPathMove:
			x, ok1 := r.f32()
			y, ok2 := r.f32()
			if !ok1 || !ok2 || path == nil {
				return
			}
			path.MoveTo(x, y)
		case paintPathLine:
			x, ok1 := r.f32()
			y, ok2 := r.f32()
			if !ok1 || !ok2 || path == nil {
				return
			}
			path.LineTo(x, y)
		case paintPathQuad:
			cx, ok1 := r.f32()
			cy, ok2 := r.f32()
			x, ok3 := r.f32()
			y, ok4 := r.f32()
			if !ok1 || !ok2 || !ok3 || !ok4 || path == nil {
				return
			}
			path.QuadTo(cx, cy, x, y)
		case paintPathCubic:
			c1x, ok1 := r.f32()
			c1y, ok2 := r.f32()
			c2x, ok3 := r.f32()
			c2y, ok4 := r.f32()
			x, ok5 := r.f32()
			y, ok6 := r.f32()
			if !ok1 || !ok2 || !ok3 || !ok4 || !ok5 || !ok6 || path == nil {
				return
			}
			path.CubeTo(c1x, c1y, c2x, c2y, x, y)
		case paintPathClose:
			if path == nil {
				return
			}
			path.Close()
		case paintPathFill:
			rgba, ok := r.u32()
			if !ok || path == nil {
				return
			}
			p.FillPath(path, unpackColor(rgba))
		case paintPathStroke:
			w, ok1 := r.f32()
			rgba, ok2 := r.u32()
			if !ok1 || !ok2 || path == nil {
				return
			}
			p.StrokePath(path, w, unpackColor(rgba))
		case paintPathSVG:
			svg, ok1 := r.str()
			fillRGBA, ok2 := r.u32()
			strokeW, ok3 := r.f32()
			strokeRGBA, ok4 := r.u32()
			if !ok1 || !ok2 || !ok3 || !ok4 {
				return
			}
			parsed, err := mygoui.ParsePath(svg)
			if err != nil {
				host.SetError(err)
				return
			}
			path = parsed
			if fillRGBA != 0 {
				p.FillPath(path, unpackColor(fillRGBA))
			}
			if strokeW > 0 {
				p.StrokePath(path, strokeW, unpackColor(strokeRGBA))
			}
		case paintFillGradient:
			x, ok1 := r.f32()
			y, ok2 := r.f32()
			w, ok3 := r.f32()
			h, ok4 := r.f32()
			rad, ok5 := r.f32()
			angle, ok6 := r.f32()
			from, ok7 := r.u32()
			to, ok8 := r.u32()
			if !ok1 || !ok2 || !ok3 || !ok4 || !ok5 || !ok6 || !ok7 || !ok8 {
				return
			}
			p.FillGradient(mygoui.Rect{X: x, Y: y, W: w, H: h}, mygoui.LinearGradient{
				Angle: angle, From: unpackColor(from), To: unpackColor(to),
			}, rad)
		case paintPathFillGrad:
			angle, ok1 := r.f32()
			from, ok2 := r.u32()
			to, ok3 := r.u32()
			if !ok1 || !ok2 || !ok3 || path == nil {
				return
			}
			p.FillPathGradient(path, mygoui.LinearGradient{
				Angle: angle, From: unpackColor(from), To: unpackColor(to),
			})
		case paintFillGradStops:
			x, ok1 := r.f32()
			y, ok2 := r.f32()
			w, ok3 := r.f32()
			h, ok4 := r.f32()
			rad, ok5 := r.f32()
			angle, ok6 := r.f32()
			oklab, ok7 := r.u8()
			if !ok1 || !ok2 || !ok3 || !ok4 || !ok5 || !ok6 || !ok7 {
				return
			}
			stops, ok := readGradientStops(r)
			if !ok || len(stops) == 0 {
				return
			}
			p.FillGradient(mygoui.Rect{X: x, Y: y, W: w, H: h}, mygoui.LinearGradient{
				Angle: angle, Oklab: oklab != 0, Stops: stops,
			}, rad)
		case paintFillConic:
			x, ok1 := r.f32()
			y, ok2 := r.f32()
			w, ok3 := r.f32()
			h, ok4 := r.f32()
			rad, ok5 := r.f32()
			angle, ok6 := r.f32()
			cx, ok7 := r.f32()
			cy, ok8 := r.f32()
			oklab, ok9 := r.u8()
			if !ok1 || !ok2 || !ok3 || !ok4 || !ok5 || !ok6 || !ok7 || !ok8 || !ok9 {
				return
			}
			stops, ok := readGradientStops(r)
			if !ok || len(stops) == 0 {
				return
			}
			p.FillConicGradient(mygoui.Rect{X: x, Y: y, W: w, H: h}, mygoui.ConicGradient{
				Angle: angle, Center: mygoui.Point{X: cx, Y: cy}, Oklab: oklab != 0, Stops: stops,
			}, rad)
		case paintFillRadial:
			x, ok1 := r.f32()
			y, ok2 := r.f32()
			w, ok3 := r.f32()
			h, ok4 := r.f32()
			rad, ok5 := r.f32()
			radius, ok6 := r.f32()
			cx, ok7 := r.f32()
			cy, ok8 := r.f32()
			oklab, ok9 := r.u8()
			if !ok1 || !ok2 || !ok3 || !ok4 || !ok5 || !ok6 || !ok7 || !ok8 || !ok9 {
				return
			}
			stops, ok := readGradientStops(r)
			if !ok || len(stops) == 0 {
				return
			}
			p.FillRadialGradient(mygoui.Rect{X: x, Y: y, W: w, H: h}, mygoui.RadialGradient{
				Radius: radius, Center: mygoui.Point{X: cx, Y: cy}, Oklab: oklab != 0, Stops: stops,
			}, rad)
		case paintCanvasBegin:
			key, ok := r.str()
			if !ok {
				return
			}
			raw, ok := canvasRegistry.Load(key)
			if !ok {
				host.SetError(fmt.Errorf("zighost: canvas %q not registered", key))
				// Skip nested ops until end so the tape stays aligned.
				flushPaintTape(p, r, true)
				continue
			}
			cv := raw.(*mygoui.Canvas)
			cv.Draw(p, func(cp *mygoui.Painter) {
				flushPaintTape(cp, r, true)
			})
		case paintCanvasEnd:
			// Unmatched end: ignore.
		case paintImage:
			key, ok1 := r.str()
			x, ok2 := r.f32()
			y, ok3 := r.f32()
			w, ok4 := r.f32()
			h, ok5 := r.f32()
			fit, ok6 := r.u8()
			if !ok1 || !ok2 || !ok3 || !ok4 || !ok5 || !ok6 {
				return
			}
			var src mygoui.ImageSource
			if raw, ok := bitmapRegistry.Load(key); ok {
				src = raw.(*mygoui.Bitmap)
			} else if raw, ok := canvasRegistry.Load(key); ok {
				src = raw.(*mygoui.Canvas).Bitmap()
			} else {
				continue
			}
			f := mygoui.Contain
			switch fit {
			case 1:
				f = mygoui.Cover
			case 2:
				f = mygoui.FillBox
			case 3:
				f = mygoui.ScaleDown
			}
			p.Image(src, mygoui.Rect{X: x, Y: y, W: w, H: h}, f)
		default:
			return
		}
	}
}
