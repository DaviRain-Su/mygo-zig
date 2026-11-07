package host

import "unsafe"

// CallZigFn invokes the Zig library's single entry point `mygo_zig_entry`.
type CallZigFn func(kind, a0, a1, a2, a3 uintptr) uintptr

// Zig entry event kinds (`mygo_zig_entry(kind, a0, a1, a2, a3)`).
const (
	ZigEventInit          uintptr = 1  // a0 = host_dispatch_fn_ptr
	ZigEventReady         uintptr = 2  // app WhenReady on main thread
	ZigEventIPC           uintptr = 3  // a0 = cb_id, a1 = win_id, a2 = *CIpcArgs, a3 = reply_handle
	ZigEventWindow        uintptr = 4  // a0 = cb_id, a1 = win_id, a2 = payload_ptr, a3 = payload_len
	ZigEventMenu          uintptr = 5  // a0 = cb_id, a1 = win_id, a2 = id_ptr, a3 = id_len
	ZigEventBytes         uintptr = 6  // a0 = cb_id, a1 = ptr, a2 = len, a3 = userdata
	ZigEventUIView        uintptr = 7  // a0 = cb_id, a1 = frame_handle, a2 = *CUIFrameInfo, a3 = userdata
	ZigEventUIListRow     uintptr = 8  // a0 = cb_id, a1 = frame_handle, a2 = *CUIListRowInfo, a3 = userdata
	ZigEventUIPaint       uintptr = 9  // a0 = cb_id, a1 = painter_handle, a2 = *CUIRect, a3 = userdata
	ZigEventUISubview     uintptr = 10 // a0 = cb_id, a1 = frame_handle, a2 = *CUIFrameInfo, a3 = userdata
	ZigEventUITableCell   uintptr = 11 // a0 = cb_id, a1 = frame_handle, a2 = *CUITableCellInfo, a3 = userdata
	ZigEventUIAction      uintptr = 12 // a0 = cb_id, a1 = 0, a2 = 0, a3 = userdata (toast action, …)
	ZigEventUIGridItem    uintptr = 13 // a0 = cb_id, a1 = frame_handle, a2 = *CUIGridItemInfo, a3 = userdata
	ZigEventUIOutlineRow  uintptr = 14 // a0 = cb_id, a1 = frame_handle, a2 = *CUIOutlineRowInfo, a3 = userdata
	ZigEventUIRoute       uintptr = 15 // a0 = cb_id, a1 = frame_handle, a2 = *CUIRouteInfo, a3 = userdata
	ZigEventUIOutlineCell uintptr = 16 // a0 = cb_id, a1 = frame_handle, a2 = *CUIOutlineCellInfo, a3 = userdata
	ZigEventUIProvide     uintptr = 17 // a0 = cb_id, a1 = out_buf_ptr, a2 = out_buf_cap, a3 = userdata → bytes written
	ZigEventTray          uintptr = 18 // a0=cb_id a1=tray_id a2=kind(1 click/2 right/3 appearance/4 menu) a3=*CStr menu id when kind=4
)

// Host dispatch opcodes (`host_dispatch(op, a0, a1, a2, a3)`).
const (
	HostOpSetName       uintptr = 1
	HostOpQuit          uintptr = 2
	HostOpLastError     uintptr = 3
	HostOpRegisterTS    uintptr = 4
	HostOpFrontendAsset uintptr = 5
	HostOpBindRaw       uintptr = 6
	HostOpEmitRaw       uintptr = 7
	HostOpIPCDefer      uintptr = 8
	HostOpIPCResolve    uintptr = 9
	HostOpIPCReject     uintptr = 10
	HostOpWindowNew     uintptr = 11
	HostOpWindowControl uintptr = 12
	HostOpWindowOnEvent uintptr = 13
	HostOpClipboard     uintptr = 14
	HostOpShell         uintptr = 15
	HostOpAppSetMenu    uintptr = 16
	HostOpDialog        uintptr = 20 // a0=kind, a1=*spec, a2=out_ptr, a3=out_cap
	HostOpTray          uintptr = 21 // a0=subop, a1=tray_id|spec, a2, a3

	// Opcodes >= HostOpUIBase are handled by zig/host/ui (and opt-in subpackages) when linked.
	HostOpUIBase       uintptr = 100
	HostOpWindowNewUI  uintptr = 100
	HostOpUIFlush      uintptr = 101
	HostOpUIPaintFlush uintptr = 102
	HostOpFlyoutNewUI  uintptr = 103 // a0=*CFlyoutSpec, a1=view_cb, a2=userdata

	HostOpMarkdownView   uintptr = 200
	HostOpEditorView     uintptr = 210
	HostOpDiffView       uintptr = 211
	HostOpLineChart      uintptr = 220
	HostOpBarChart       uintptr = 221
	HostOpAreaChart      uintptr = 222
	HostOpPieChart       uintptr = 223
	HostOpVideoGIF       uintptr = 230 // a0 = *CVideoGIFSpec
	HostOpVideoFrames    uintptr = 231 // a0 = *CVideoFramesSpec
	HostOpVideoStream    uintptr = 232 // a0 = *CVideoStreamSpec (open)
	HostOpVideoPush      uintptr = 233 // a0 = *CVideoPushSpec
	HostOpVideoEnd       uintptr = 234 // a0 = key ptr, a1 = key len
	HostOpRegisterFont   uintptr = 240 // a0=*CFontSpec
	HostOpRegisterBitmap uintptr = 241 // a0=*CBitmapSpec
	HostOpRegisterCanvas uintptr = 242 // a0=*CCanvasSpec
)

// CVideoGIFSpec registers a looping GIF player by key for later Video() ops.
type CVideoGIFSpec struct {
	KeyPtr, KeyLen uintptr
	GIFPtr, GIFLen uintptr
	Loop           uint8
	_              [7]byte
}

// CVideoFramesSpec registers an RGBA frame-sequence player by key.
type CVideoFramesSpec struct {
	KeyPtr, KeyLen       uintptr
	Width, Height        uint32
	FrameCount           uint32
	Loop                 uint8
	_                    [3]byte
	DurationsPtr         uintptr // frameCount × uint32 milliseconds
	PixelsPtr, PixelsLen uintptr // contiguous RGBA, frameCount×w×h×4
}

// CVideoStreamSpec opens a push-driven stream decoder (Zig pushes frames).
type CVideoStreamSpec struct {
	KeyPtr, KeyLen uintptr
	Width, Height  uint32
	Capacity       uint32 // buffered frames; 0 → 4
	Loop           uint8
	_              [3]byte
}

// CVideoPushSpec appends one RGBA frame to an open stream.
type CVideoPushSpec struct {
	KeyPtr, KeyLen       uintptr
	DurationMS           uint32
	_                    [4]byte
	PixelsPtr, PixelsLen uintptr
}

// CFontSpec registers a TTF/OTF with ui.RegisterFont.
type CFontSpec struct {
	FamilyPtr, FamilyLen uintptr
	DataPtr, DataLen     uintptr
}

// CBitmapSpec registers decoded image bytes under a key for `bitmap`.
type CBitmapSpec struct {
	KeyPtr, KeyLen   uintptr
	DataPtr, DataLen uintptr
}

// CCanvasSpec creates/resizes an offscreen Canvas by key.
type CCanvasSpec struct {
	KeyPtr, KeyLen uintptr
	Width, Height  uint32
}

// Window control sub-opcodes for HostOpWindowControl.
const (
	WinCtlShow           uintptr = 1
	WinCtlHide           uintptr = 2
	WinCtlClose          uintptr = 3
	WinCtlCenter         uintptr = 4
	WinCtlMinimize       uintptr = 5
	WinCtlMaximize       uintptr = 6
	WinCtlUnmaximize     uintptr = 7
	WinCtlSetFullscreen  uintptr = 8
	WinCtlInvalidate     uintptr = 9
	WinCtlSetTitle       uintptr = 10
	WinCtlGetBounds      uintptr = 11
	WinCtlSetBounds      uintptr = 12
	WinCtlLoadURL        uintptr = 13
	WinCtlLoadHTML       uintptr = 14
	WinCtlSetInputRegion uintptr = 15 // a2=*CBounds, a3=count; a3=^0 → nil (full)
	WinCtlSetAnchor      uintptr = 16 // a2=*CBounds — flyout only
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

// CDialogOpenSpec configures Dialog.Open (HostOpDialog kind=1).
type CDialogOpenSpec struct {
	ParentWinID                    uintptr
	TitlePtr, TitleLen             uintptr
	DefaultPathPtr, DefaultPathLen uintptr
	ButtonLabelPtr, ButtonLabelLen uintptr
	MessagePtr, MessageLen         uintptr
	FilterNamePtr, FilterNameLen   uintptr // legacy single filter (ignored if FiltersLen>0)
	FilterExtPtr, FilterExtLen     uintptr
	FiltersPtr, FiltersLen         uintptr // packed multi-filter blob
	Flags                          uint32  // 1=dir 2=multi 4=hidden 8=createDirs 16=packages
	_                              [4]byte
}

// CDialogSaveSpec configures Dialog.Save (HostOpDialog kind=2).
type CDialogSaveSpec struct {
	ParentWinID                     uintptr
	TitlePtr, TitleLen              uintptr
	DefaultPathPtr, DefaultPathLen  uintptr
	ButtonLabelPtr, ButtonLabelLen  uintptr
	MessagePtr, MessageLen          uintptr
	NameFieldLabelPtr, NameFieldLen uintptr
	FilterNamePtr, FilterNameLen    uintptr
	FilterExtPtr, FilterExtLen      uintptr
	FiltersPtr, FiltersLen          uintptr
	Flags                           uint32 // 4=hidden 8=createDirs 16=packages
	_                               [4]byte
}

// CDialogMessageSpec configures Dialog.Message (HostOpDialog kind=3).
type CDialogMessageSpec struct {
	ParentWinID                   uintptr
	Type                          uint8 // 0 none 1 info 2 warning 3 error 4 question
	CheckboxChecked               uint8
	_pad                          [2]byte
	DefaultButton                 int32
	CancelButton                  int32
	TitlePtr, TitleLen            uintptr
	MessagePtr, MessageLen        uintptr
	DetailPtr, DetailLen          uintptr
	CheckboxLabelPtr, CheckboxLen uintptr
	ButtonsPtr, ButtonsLen        uintptr // NUL-separated button labels
	ButtonCount                   uint32
	_                             [4]byte
}

// CDialogMessageResult is written for HostOpDialog kind=3 when out_cap >= size.
type CDialogMessageResult struct {
	Button          int32
	CheckboxChecked uint8
	_               [3]byte
}

// Tray sub-ops for HostOpTray.
const (
	TrayNew        uintptr = 1  // a1=*CTrayNewSpec → tray id
	TrayDestroy    uintptr = 2  // a1=tray_id
	TraySetIcon    uintptr = 3  // a1=tray_id, a2=png_ptr, a3=png_len; template in high bit of unused — use CTrayIconSpec at a2
	TraySetTitle   uintptr = 4  // a1=tray_id, a2=ptr, a3=len
	TraySetToolTip uintptr = 5  // a1=tray_id, a2=ptr, a3=len
	TraySetMenu    uintptr = 6  // a1=tray_id, a2=json_ptr, a3=json_len; menu cb via CTrayNewSpec.MenuCb reused — pass menu_cb in high? use a0 packing: store cb on tray
	TrayPopUpMenu  uintptr = 7  // a1=tray_id
	TrayBounds     uintptr = 8  // a1=tray_id, a2=*CBounds
	TrayDark       uintptr = 9  // a1=tray_id → 1/0
	TrayOnEvent    uintptr = 10 // a1=tray_id, a2=kind(1/2/3), a3=cb_id
)

// CTrayNewSpec creates a tray icon.
type CTrayNewSpec struct {
	IDPtr, IDLen         uintptr
	IconPtr, IconLen     uintptr
	TitlePtr, TitleLen   uintptr
	TipPtr, TipLen       uintptr
	MenuJSONPtr, MenuLen uintptr
	MenuCbID             uintptr
	Template             uint8
	_                    [7]byte
}

// CTrayIconSpec replaces a tray icon.
type CTrayIconSpec struct {
	PNGPtr, PNGLen uintptr
	Template       uint8
	_              [7]byte
}

// CFlyoutSpec creates a NewFlyout with Native UI Content (HostOpFlyoutNewUI).
type CFlyoutSpec struct {
	ParentWinID                uintptr
	TrayID                     uintptr
	Anchor                     CBounds
	Width, Height              int32
	Gap                        int32
	MinWidth, MinHeight        int32
	MaxWidth, MaxHeight        int32
	CornerRadius               int32
	PlacementPtr, PlacementLen uintptr
	Flags                      uint32 // 1=focusable 2=hidden 4=shadow 8=popover 16=fit_content
	VibrancyPtr, VibrancyLen   uintptr
}
