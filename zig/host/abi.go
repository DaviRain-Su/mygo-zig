package host

import "unsafe"

// CallZigFn invokes the Zig library's single entry point `mygo_zig_entry`.
type CallZigFn func(kind, a0, a1, a2, a3 uintptr) uintptr

// Zig entry event kinds (`mygo_zig_entry(kind, a0, a1, a2, a3)`).
const (
	ZigEventInit         uintptr = 1 // a0 = host_dispatch_fn_ptr
	ZigEventReady        uintptr = 2 // app WhenReady on main thread
	ZigEventIPC          uintptr = 3 // a0 = cb_id, a1 = win_id, a2 = *CIpcArgs, a3 = reply_handle
	ZigEventWindow       uintptr = 4 // a0 = cb_id, a1 = win_id, a2 = payload_ptr, a3 = payload_len
	ZigEventMenu         uintptr = 5 // a0 = cb_id, a1 = win_id, a2 = id_ptr, a3 = id_len
	ZigEventBytes        uintptr = 6 // a0 = cb_id, a1 = ptr, a2 = len, a3 = userdata
	ZigEventUIView       uintptr = 7  // a0 = cb_id, a1 = frame_handle, a2 = *CUIFrameInfo, a3 = userdata
	ZigEventUIListRow    uintptr = 8  // a0 = cb_id, a1 = frame_handle, a2 = *CUIListRowInfo, a3 = userdata
	ZigEventUIPaint      uintptr = 9  // a0 = cb_id, a1 = painter_handle, a2 = *CUIRect, a3 = userdata
	ZigEventUISubview    uintptr = 10 // a0 = cb_id, a1 = frame_handle, a2 = *CUIFrameInfo, a3 = userdata
	ZigEventUITableCell  uintptr = 11 // a0 = cb_id, a1 = frame_handle, a2 = *CUITableCellInfo, a3 = userdata
	ZigEventUIAction     uintptr = 12 // a0 = cb_id, a1 = 0, a2 = 0, a3 = userdata (toast action, …)
	ZigEventUIGridItem   uintptr = 13 // a0 = cb_id, a1 = frame_handle, a2 = *CUIGridItemInfo, a3 = userdata
	ZigEventUIOutlineRow  uintptr = 14 // a0 = cb_id, a1 = frame_handle, a2 = *CUIOutlineRowInfo, a3 = userdata
	ZigEventUIRoute       uintptr = 15 // a0 = cb_id, a1 = frame_handle, a2 = *CUIRouteInfo, a3 = userdata
	ZigEventUIOutlineCell uintptr = 16 // a0 = cb_id, a1 = frame_handle, a2 = *CUIOutlineCellInfo, a3 = userdata
)

// Host dispatch opcodes (`host_dispatch(op, a0, a1, a2, a3)`).
const (
	HostOpSetName        uintptr = 1
	HostOpQuit           uintptr = 2
	HostOpLastError      uintptr = 3
	HostOpRegisterTS     uintptr = 4
	HostOpFrontendAsset  uintptr = 5
	HostOpBindRaw        uintptr = 6
	HostOpEmitRaw        uintptr = 7
	HostOpIPCDefer       uintptr = 8
	HostOpIPCResolve     uintptr = 9
	HostOpIPCReject      uintptr = 10
	HostOpWindowNew      uintptr = 11
	HostOpWindowControl  uintptr = 12
	HostOpWindowOnEvent  uintptr = 13
	HostOpClipboard      uintptr = 14
	HostOpShell          uintptr = 15
	HostOpAppSetMenu     uintptr = 16

	// Opcodes >= HostOpUIBase are handled by zig/host/ui (and opt-in subpackages) when linked.
	HostOpUIBase         uintptr = 100
	HostOpWindowNewUI    uintptr = 100
	HostOpUIFlush        uintptr = 101
	HostOpUIPaintFlush   uintptr = 102

	HostOpMarkdownView   uintptr = 200
	HostOpEditorView     uintptr = 210
	HostOpDiffView       uintptr = 211
	HostOpLineChart      uintptr = 220
	HostOpBarChart       uintptr = 221
	HostOpAreaChart      uintptr = 222
	HostOpPieChart       uintptr = 223
	HostOpVideoGIF       uintptr = 230 // a0 = *CVideoGIFSpec
)

// CVideoGIFSpec registers a looping GIF player by key for later Video() ops.
type CVideoGIFSpec struct {
	KeyPtr, KeyLen uintptr
	GIFPtr, GIFLen uintptr
	Loop           uint8
	_              [7]byte
}

// Window control sub-opcodes for HostOpWindowControl.
const (
	WinCtlShow          uintptr = 1
	WinCtlHide          uintptr = 2
	WinCtlClose         uintptr = 3
	WinCtlCenter        uintptr = 4
	WinCtlMinimize      uintptr = 5
	WinCtlMaximize      uintptr = 6
	WinCtlUnmaximize    uintptr = 7
	WinCtlSetFullscreen uintptr = 8
	WinCtlInvalidate    uintptr = 9
	WinCtlSetTitle      uintptr = 10
	WinCtlGetBounds     uintptr = 11
	WinCtlSetBounds     uintptr = 12
	WinCtlLoadURL       uintptr = 13
	WinCtlLoadHTML      uintptr = 14
)

// CStr matches `extern struct { data: ?[*]const u8, len: usize }` in Zig.
type CStr struct {
	Data uintptr
	Len  uintptr
}

// CWindowOptions matches `CWindowOptions` in `zig/sdk/mygo.zig`.
type CWindowOptions struct {
	Title           CStr
	URL             CStr
	BackgroundColor CStr
	Width           int32
	Height          int32
	MinWidth        int32
	MinHeight       int32
	MaxWidth        int32
	MaxHeight       int32
	DevTools        int32
	UseContentSize  uint8
	Hidden          uint8
	Frameless       uint8
	DisableResize   uint8
	AlwaysOnTop     uint8
	Transparent     uint8
	_               [2]byte
}

// CAssetSpec describes an embedded asset registered by Zig (`@embedFile`).
type CAssetSpec struct {
	Path           CStr
	Data           uintptr
	DataLen        uintptr
	StaticLifetime uint8
	_              [7]byte
}

// CEmitSpec describes a raw JSON event emitted by Zig.
type CEmitSpec struct {
	Event   CStr
	Payload CStr
}

// CBounds matches `extern struct { x: i32, y: i32, width: i32, height: i32 }`.
type CBounds struct {
	X, Y, Width, Height int32
}

// CHtmlSpec passes `(html, base_url)` for LoadHTML.
type CHtmlSpec struct {
	HTML    CStr
	BaseURL CStr
}

// UIDispatch is populated by `zig/host/ui` when an application imports it.
// Apps that only use WebView windows leave UIDispatch nil and link none of `package ui`.
var UIDispatch func(call CallZigFn, op, a0, a1, a2, a3 uintptr) uintptr

// MarkdownDispatch is populated by `zig/host/markdown` when imported.
var MarkdownDispatch func(frameHandle, a1, a2, a3 uintptr) uintptr

// EditorDispatch is populated by `zig/host/editor` when imported.
var EditorDispatch func(op, frameHandle, a1, a2, a3 uintptr) uintptr

// ChartDispatch is populated by `zig/host/chart` when imported.
var ChartDispatch func(op, frameHandle, a1, a2, a3 uintptr) uintptr

// CChartSpec is the line/bar/area chart payload from Zig (`zig/sdk/ui.zig`).
type CChartSpec struct {
	XSPtr, XSLen uintptr
	YSPtr, YSLen uintptr
	Color        uint32
	Height       float32
	Flags        uint8 // bit0 = show axes
	_            [3]byte
}

// CPieSpec is the pie/donut chart payload from Zig.
type CPieSpec struct {
	ValuesPtr, ValuesLen uintptr
	ColorsPtr, ColorsLen uintptr
	Height               float32
	Inner                float32 // hole radius as fraction of outer (0 = pie)
	Pad                  float32 // gap between slices, 0..1 of full circle
	_                    [4]byte
}

// PtrTo reinterprets a non-zero C/Zig address as *T without triggering unsafeptr warnings.
func PtrTo[T any](addr uintptr) *T {
	if addr == 0 {
		return nil
	}
	return *(**T)(unsafe.Pointer(&addr))
}

// BytesView returns a non-owning view of `n` bytes at `addr`.
func BytesView(addr, n uintptr) []byte {
	if addr == 0 || n == 0 {
		return nil
	}
	return unsafe.Slice(*(**byte)(unsafe.Pointer(&addr)), int(n))
}

// Float32View returns a non-owning view of `n` float32s at `addr`.
func Float32View(addr, n uintptr) []float32 {
	if addr == 0 || n == 0 {
		return nil
	}
	return unsafe.Slice(*(**float32)(unsafe.Pointer(&addr)), int(n))
}

// Float64View returns a non-owning view of `n` float64s at `addr`.
func Float64View(addr, n uintptr) []float64 {
	if addr == 0 || n == 0 {
		return nil
	}
	return unsafe.Slice(*(**float64)(unsafe.Pointer(&addr)), int(n))
}

// Uint32View returns a non-owning view of `n` uint32s at `addr`.
func Uint32View(addr, n uintptr) []uint32 {
	if addr == 0 || n == 0 {
		return nil
	}
	return unsafe.Slice(*(**uint32)(unsafe.Pointer(&addr)), int(n))
}

// CopyBytes copies `n` bytes from `addr` into a new Go slice.
func CopyBytes(addr, n uintptr) []byte {
	src := BytesView(addr, n)
	if len(src) == 0 {
		return nil
	}
	out := make([]byte, len(src))
	copy(out, src)
	return out
}

// CopyString copies a UTF-8 string from `(addr, n)`.
func CopyString(addr, n uintptr) string {
	src := BytesView(addr, n)
	if len(src) == 0 {
		return ""
	}
	return string(src)
}

// StrField copies a CStr into a Go string.
func StrField(s CStr) string {
	return CopyString(s.Data, s.Len)
}

// SliceAddr returns the address and length of b for passing to Zig during a synchronous call.
func SliceAddr(b []byte) (uintptr, uintptr) {
	if len(b) == 0 {
		return 0, 0
	}
	return uintptr(unsafe.Pointer(unsafe.SliceData(b))), uintptr(len(b))
}
