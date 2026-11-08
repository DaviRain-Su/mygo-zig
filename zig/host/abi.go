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
	ZigEventNotification  uintptr = 19 // a0=cb_id a1=kind(1 note click / 2 app click) a2=*CStr id
	ZigEventHotkey        uintptr = 20 // a0=cb_id a1=hotkey_id
	ZigEventTheme         uintptr = 21 // a0=cb_id
	ZigEventPower         uintptr = 22 // a0=cb_id a1=*CStr event
	ZigEventApp           uintptr = 23 // a0=cb_id a1=kind a2=*CStr|flag a3
	ZigEventProtocol      uintptr = 24 // a0=cb_id a1=req_id a2=*CProtocolReq
	ZigEventAuth          uintptr = 25 // a0=cb_id a1=win_id a2=*CAuthReq a3=req_id
	ZigEventCert          uintptr = 26 // a0=cb_id a1=win_id a2=*CCertErr; return !=0 allow
	ZigEventDownload      uintptr = 27 // a0=cb_id a1=win_id a2=kind(1 will/2 done) a3=*CDownload
	ZigEventPage          uintptr = 28 // a0=cb_id a1=win_id a2=kind a3=*CPageEvent
	ZigEventPermission    uintptr = 29 // a0=cb_id a1=win_id a2=*CPermReq; return !=0 grant
	ZigEventWindowOpen    uintptr = 30 // a0=cb_id a1=win_id a2=*CWindowOpenReq a3=req_id
	ZigEventContextMenu   uintptr = 31 // a0=cb_id a1=win_id a2=*CContextMenuEv a3=req_id
	ZigEventPageMedia     uintptr = 32 // a0=cb_id a1=win_id a2=kind(1 audible/2 capture) a3=payload
	ZigEventLocale        uintptr = 33 // a0=cb_id a1=*CStr locale
	ZigEventRegion        uintptr = 34 // a0=cb_id a1=*CStr region JSON
	ZigEventTerminal      uintptr = 35 // a0=cb_id a1=term_id a2=kind a3=payload
	ZigEventWatch         uintptr = 36 // a0=cb_id a1=watch_id a2=kind a3=payload
	ZigEventPermFlow      uintptr = 37 // a0=cb_id a1=req_id a2=status a3=*CStr err
	ZigEventWebSocket     uintptr = 38 // a0=cb_id a1=conn_id a2=kind a3=payload
	ZigEventGameUpdate    uintptr = 39 // a0=cb_id a1=*CGameInput a2=0 a3=userdata
	ZigEventGameDraw      uintptr = 40 // a0=cb_id a1=painter a2=*CGameDraw a3=userdata
	ZigEventDocuments     uintptr = 41 // a0=cb_id a1=doc_id a2=kind a3=payload → return win_id for kind=1
	ZigEventNetwork       uintptr = 42 // a0=cb_id a1=*CStr JSON NetworkStatus
	ZigEventNowPlaying    uintptr = 43 // a0=cb_id a1=cmd a2=position_ns
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
	HostOpNotification  uintptr = 22 // a0=subop, a1=spec|id, a2, a3
	HostOpPath          uintptr = 23 // a0=1 get / 2 set, a1=name, a2=path/out
	HostOpScreen        uintptr = 24 // a0=subop
	HostOpHotkey        uintptr = 25 // a0=subop
	HostOpTheme         uintptr = 26 // a0=subop
	HostOpPower         uintptr = 27 // a0=subop
	HostOpAppEvents     uintptr = 28 // a0=subop
	HostOpProtocol      uintptr = 29 // a0=subop
	HostOpDesktop       uintptr = 30 // a0=subop — dock/jumplist/recent
	HostOpSecrets       uintptr = 31 // a0=subop
	HostOpCookies       uintptr = 32 // a0=subop
	HostOpSession       uintptr = 33 // a0=subop
	HostOpLocale        uintptr = 34 // a0=subop
	HostOpContentRules  uintptr = 35 // a0=subop

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
	HostOpTerminal       uintptr = 235 // a0=subop (lifecycle)
	HostOpTerminalView   uintptr = 236 // a0=frame a1=term_id
	HostOpSQLite         uintptr = 237 // a0=subop
	HostOpWatch          uintptr = 238 // a0=subop (mygo.WatchFiles)
	HostOpPermissionFlow uintptr = 239 // a0=subop
	HostOpFetch          uintptr = 243 // a0=subop HTTP for Zig
	HostOpWebSocket      uintptr = 244 // a0=subop
	HostOpUpdater        uintptr = 245 // a0=subop
	HostOpGlass          uintptr = 246 // a0=subop (material)
	HostOpGame           uintptr = 247 // a0=subop
	HostOpGamepad        uintptr = 248 // a0=subop
	HostOpWebView        uintptr = 249 // a0=subop first-class WebView
	HostOpDocuments      uintptr = 250 // a0=subop bytes documents
	HostOpNetwork        uintptr = 251 // a0=subop Network.Status/OnChanged
	HostOpNowPlaying     uintptr = 252 // a0=subop NowPlaying
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
	WinCtlShow                 uintptr = 1
	WinCtlHide                 uintptr = 2
	WinCtlClose                uintptr = 3
	WinCtlCenter               uintptr = 4
	WinCtlMinimize             uintptr = 5
	WinCtlMaximize             uintptr = 6
	WinCtlUnmaximize           uintptr = 7
	WinCtlSetFullscreen        uintptr = 8
	WinCtlInvalidate           uintptr = 9
	WinCtlSetTitle             uintptr = 10
	WinCtlGetBounds            uintptr = 11
	WinCtlSetBounds            uintptr = 12
	WinCtlLoadURL              uintptr = 13
	WinCtlLoadHTML             uintptr = 14
	WinCtlSetInputRegion       uintptr = 15 // a2=*CBounds, a3=count; a3=^0 → nil (full)
	WinCtlSetAnchor            uintptr = 16 // a2=*CBounds — flyout only
	WinCtlSetVibrancy          uintptr = 17 // a2=vibrancy ptr, a3=len
	WinCtlSetVibrancyTint      uintptr = 18 // a2=tint ptr, a3=len
	WinCtlSetProgressBar       uintptr = 19 // a2=*CProgressSpec
	WinCtlSetContentProtection uintptr = 20 // a2=1/0
	WinCtlSetAuthHandler       uintptr = 21 // a2=cb_id (0 clears)
	WinCtlAuthRespond          uintptr = 22 // a2=*CAuthResp
	WinCtlSetCertHandler       uintptr = 23 // a2=cb_id (0 clears)
	WinCtlOnDownload           uintptr = 24 // a2=cb_id (0 clears)
	WinCtlDownloadRespond      uintptr = 25 // a2=*CDownloadResp
	WinCtlOnPage               uintptr = 26 // a2=cb_id (0 clears)
	WinCtlNavigateRespond      uintptr = 27 // a2=*CNavResp
	WinCtlSetPermissionHandler uintptr = 28 // a2=cb_id (0 clears)
	WinCtlSetWindowOpenHandler uintptr = 29 // a2=cb_id (0 clears)
	WinCtlWindowOpenRespond    uintptr = 30 // a2=*CWindowOpenResp
	WinCtlFindInPage           uintptr = 31 // a2=*CFindSpec → (matches<<32)|active
	WinCtlStopFindInPage       uintptr = 32
	WinCtlReload               uintptr = 33
	WinCtlGoBack               uintptr = 34
	WinCtlGoForward            uintptr = 35
	WinCtlEval                 uintptr = 36 // a2=*CEvalSpec → nbytes JSON
	WinCtlOnContextMenu        uintptr = 37 // a2=cb_id
	WinCtlContextMenuRespond   uintptr = 38 // a2=*CContextMenuResp
	WinCtlSetContentRules      uintptr = 39 // a2=ids_json ("[]" clears)
	WinCtlSetAudioMuted        uintptr = 40 // a2=1/0
	WinCtlIsAudioMuted         uintptr = 41 // → 1/0
	WinCtlIsAudible            uintptr = 42 // → 1/0
	WinCtlOnPageMedia          uintptr = 43 // a2=cb_id audible+capture
	WinCtlCaptureState         uintptr = 44 // a2=kind → state
	WinCtlSetCaptureState      uintptr = 45 // a2=kind a3=state
	WinCtlTogglePiP            uintptr = 46
	WinCtlIsPiPActive          uintptr = 47 // → 1/0
	WinCtlSetZoom              uintptr = 48 // a2=bits of float64
	WinCtlGetZoom              uintptr = 49 // → bits of float64
	WinCtlSetUserAgent         uintptr = 50 // a2=ptr a3=len
	WinCtlGetUserAgent         uintptr = 51 // a2=out a3=cap → len
	WinCtlOpenDevTools         uintptr = 52
	WinCtlCloseDevTools        uintptr = 53
	WinCtlIsDevToolsOpened     uintptr = 54 // → 1/0
	WinCtlToggleDevTools       uintptr = 55
	WinCtlPrint                uintptr = 56
	WinCtlURL                  uintptr = 57 // a2=out a3=cap → len
	WinCtlIsLoading            uintptr = 58 // → 1/0
	WinCtlCapturePage          uintptr = 59 // a2=out a3=cap → nbytes PNG
	WinCtlPrintToPDF           uintptr = 60 // a2=*CPDFSpec → nbytes
	WinCtlSetMinSize           uintptr = 61 // a2=w a3=h
	WinCtlSetMaxSize           uintptr = 62
	WinCtlSetSize              uintptr = 63
	WinCtlSetPosition          uintptr = 64 // a2=x a3=y
	WinCtlSetResizable         uintptr = 65 // a2=0/1
	WinCtlIsResizable          uintptr = 66
	WinCtlSetClosable          uintptr = 67
	WinCtlIsClosable           uintptr = 68
	WinCtlSetMaximizable       uintptr = 69
	WinCtlIsMaximizable        uintptr = 70
	WinCtlSetMinimizable       uintptr = 71
	WinCtlIsMinimizable        uintptr = 72
	WinCtlSetMovable           uintptr = 73
	WinCtlIsMovable            uintptr = 74
	WinCtlSetAlwaysOnTop       uintptr = 75
	WinCtlIsAlwaysOnTop        uintptr = 76
	WinCtlSetHasShadow         uintptr = 77
	WinCtlHasShadow            uintptr = 78
	WinCtlSetOpacity           uintptr = 79 // a2=float64 bits
	WinCtlGetOpacity           uintptr = 80
	WinCtlSetBackgroundColor   uintptr = 81 // a2=ptr a3=len
	WinCtlSetIgnoreMouseEvents uintptr = 82
	WinCtlFlashFrame           uintptr = 83
	WinCtlSetDocumentEdited    uintptr = 84
	WinCtlIsDocumentEdited     uintptr = 85
	WinCtlSetRepresentedFile   uintptr = 86
	WinCtlGetRepresentedFile   uintptr = 87 // a2=out a3=cap
	WinCtlIsVisible            uintptr = 88
	WinCtlIsFocused            uintptr = 89
	WinCtlIsMinimized          uintptr = 90
	WinCtlIsMaximized          uintptr = 91
	WinCtlIsFullScreen         uintptr = 92
	WinCtlIsDestroyed          uintptr = 93
	WinCtlBlur                 uintptr = 94
	WinCtlRestore              uintptr = 95
	WinCtlShowInactive         uintptr = 96
	WinCtlSetIcon              uintptr = 97 // a2=ptr a3=len PNG
	WinCtlSetSkipTaskbar       uintptr = 98
	WinCtlSetAutoHideMenuBar   uintptr = 99
	WinCtlSetActiveAppearance  uintptr = 100
	WinCtlNativeHandle         uintptr = 101
	WinCtlStop                 uintptr = 102
	WinCtlReloadIgnoringCache  uintptr = 103
	WinCtlLoadFile             uintptr = 104 // a2=ptr a3=len
	WinCtlCanGoBack            uintptr = 105
	WinCtlCanGoForward         uintptr = 106
	WinCtlProcessID            uintptr = 107
	WinCtlGPUProcessID         uintptr = 108
	WinCtlThemeColor           uintptr = 109 // a2=*CThemeColor
	WinCtlTitleRespond         uintptr = 110 // a2=*CNavResp (reuse prevent)
)

// CProgressSpec is WinCtlSetProgressBar a2.
type CProgressSpec struct {
	StatePtr, StateLen uintptr
	Value              float64
}

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
	Vibrancy        CStr
	VibrancyTint    CStr
	TitleBarStyle   CStr
	TitleBarHeight  int32
	_PadTB          [4]byte
	SessionName     CStr
	StateKey        CStr
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

// TerminalDispatch is populated by `zig/host/terminal` when imported.
var TerminalDispatch func(call CallZigFn, op, a0, a1, a2, a3 uintptr) uintptr

// SQLiteDispatch is populated by `zig/host/sqlite` when imported.
var SQLiteDispatch func(op, a0, a1, a2, a3 uintptr) uintptr

// WatchDispatch is populated by `zig/host/watch` when imported.
var WatchDispatch func(call CallZigFn, op, a0, a1, a2, a3 uintptr) uintptr

// PermissionFlowDispatch is populated by `zig/host/permissionflow` when imported.
var PermissionFlowDispatch func(call CallZigFn, op, a0, a1, a2, a3 uintptr) uintptr

var FetchDispatch func(op, a0, a1, a2, a3 uintptr) uintptr
var WebSocketDispatch func(call CallZigFn, op, a0, a1, a2, a3 uintptr) uintptr
var UpdaterDispatch func(op, a0, a1, a2, a3 uintptr) uintptr
var GlassDispatch func(op, a0, a1, a2, a3 uintptr) uintptr
var GameDispatch func(call CallZigFn, op, a0, a1, a2, a3 uintptr) uintptr
var GamepadDispatch func(op, a0, a1, a2, a3 uintptr) uintptr
var WebViewDispatch func(op, a0, a1, a2, a3 uintptr) uintptr
var DocumentsDispatch func(call CallZigFn, op, a0, a1, a2, a3 uintptr) uintptr

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

// Notification sub-ops for HostOpNotification.
const (
	NotifSupported  uintptr = 1 // → 1/0
	NotifShow       uintptr = 2 // a1=*CNotificationShowSpec, a2=out_id_ptr, a3=out_id_cap → id len
	NotifClose      uintptr = 3 // a1=id_ptr, a2=id_len
	NotifClear      uintptr = 4
	NotifOnAppClick uintptr = 5 // a1=cb_id
)

// CNotificationShowSpec shows a desktop notification.
type CNotificationShowSpec struct {
	IDPtr, IDLen             uintptr
	TitlePtr, TitleLen       uintptr
	SubtitlePtr, SubtitleLen uintptr
	BodyPtr, BodyLen         uintptr
	GroupPtr, GroupLen       uintptr
	ImagePtr, ImageLen       uintptr
	Silent                   uint8
	_                        [7]byte
	ClickCbID                uintptr
}

// Screen sub-ops for HostOpScreen.
const (
	ScreenDisplaysJSON uintptr = 1 // a1=out_ptr a2=out_cap → JSON array of displays
	ScreenCursor       uintptr = 2 // a1=*CPoint
)

// Hotkey sub-ops for HostOpHotkey.
const (
	HotkeyRegister      uintptr = 1 // a1=acc_ptr a2=acc_len a3=cb_id → 0 ok
	HotkeyUnregister    uintptr = 2 // a1=acc_ptr a2=acc_len
	HotkeyUnregisterAll uintptr = 3
	HotkeyIsRegistered  uintptr = 4 // → 1/0
)

type CPoint struct {
	X, Y int32
}

// Theme sub-ops for HostOpTheme.
const (
	ThemeIsDark    uintptr = 1 // → 1/0
	ThemeSourceGet uintptr = 2 // a1=out_ptr a2=out_cap → source string len
	ThemeSourceSet uintptr = 3 // a1=ptr a2=len
	ThemePrefsJSON uintptr = 4 // a1=out_ptr a2=out_cap → JSON
	ThemeOnUpdated uintptr = 5 // a1=cb_id
)

// Power sub-ops for HostOpPower.
const (
	PowerIsOnBattery uintptr = 1 // → 1/0
	PowerIdleMs      uintptr = 2 // → idle milliseconds
	PowerKeepAwake   uintptr = 3 // a1=reason_ptr a2=reason_len a3=display(1/0) → token id
	PowerRelease     uintptr = 4 // a1=token
	PowerOnEvent     uintptr = 5 // a1=cb_id (all power events)
)

// App event sub-ops for HostOpAppEvents.
const (
	AppEvOnActivate            uintptr = 1 // a1=cb_id — kind=1, a2=hasVisibleWindows 0/1; return !=0 → n/a
	AppEvOnDidBecomeActive     uintptr = 2
	AppEvOnDidResignActive     uintptr = 3
	AppEvOnBeforeQuit          uintptr = 4  // kind=4; return !=0 → PreventDefault
	AppEvOnWillQuit            uintptr = 5  // kind=5; return !=0 → PreventDefault
	AppEvOnOpenURL             uintptr = 6  // kind=6, a2=*CStr url
	AppEvOnOpenFile            uintptr = 7  // kind=7, a2=*CStr path
	AppEvOnSecondInstance      uintptr = 8  // kind=8, a2=*CStr JSON {args,wd}
	AppEvRequestSingleInstance uintptr = 9  // → 1 if first instance
	AppEvShowAbout             uintptr = 10 // a1=*CAboutSpec
	AppEvSetBadge              uintptr = 11 // a1=text_ptr a2=text_len
	AppEvGetBadge              uintptr = 12 // a1=out_ptr a2=out_cap → len
	AppEvBounce                uintptr = 13 // a1=critical 0/1 → bounce id
	AppEvCancelBounce          uintptr = 14 // a1=id
	AppEvRegisterScheme        uintptr = 15 // a1=scheme_ptr a2=scheme_len
	AppEvUnregisterScheme      uintptr = 16
	AppEvIsSchemeRegistered    uintptr = 17 // → 1/0
	AppEvSetOpenAtLogin        uintptr = 18 // a1=0/1
	AppEvOpenAtLogin           uintptr = 19 // → 1/0
	AppEvWasOpenedAtLogin      uintptr = 20 // → 1/0
	AppEvRelaunch              uintptr = 21
	AppEvHide                  uintptr = 22
	AppEvShow                  uintptr = 23
	AppEvIsHidden              uintptr = 24
	AppEvFocus                 uintptr = 25
	AppEvIsActive              uintptr = 26
	AppEvIsReady               uintptr = 27
	AppEvIsPackaged            uintptr = 28
	AppEvName                  uintptr = 29 // a1=out a2=cap
	AppEvVersion               uintptr = 30
	AppEvSetVersion            uintptr = 31
	AppEvExit                  uintptr = 32 // a1=code
	AppEvActivationPolicyGet   uintptr = 33
	AppEvActivationPolicySet   uintptr = 34
	AppEvRegionJSON            uintptr = 35
	AppEvOnQuit                uintptr = 36 // ZigEventApp kind=9
	AppEvOnReady               uintptr = 37 // kind=10
	AppEvOnWindowAllClosed     uintptr = 38 // kind=11
	AppEvOnWindowCreated       uintptr = 39 // kind=12 a2=win_id
	AppEvOnRegionChanged       uintptr = 40 // ZigEventRegion
)

type CAboutSpec struct {
	NamePtr, NameLen           uintptr
	VersionPtr, VersionLen     uintptr
	CopyrightPtr, CopyrightLen uintptr
	CreditsPtr, CreditsLen     uintptr
}

// Protocol sub-ops for HostOpProtocol.
const (
	ProtocolHandle    uintptr = 1 // a1=scheme_ptr a2=scheme_len a3=cb_id
	ProtocolUnhandle  uintptr = 2 // a1=scheme_ptr a2=scheme_len
	ProtocolIsHandled uintptr = 3 // → 1/0
	ProtocolRespond   uintptr = 4 // a1=*CProtocolResp
)

// CProtocolRequest is passed to Zig for each custom-scheme request.
type CProtocolRequest struct {
	MethodPtr, MethodLen   uintptr
	URLPtr, URLLen         uintptr
	HeadersPtr, HeadersLen uintptr // JSON object string→string
}

// CProtocolResp is written by Zig via ProtocolRespond during the request callback.
type CProtocolResp struct {
	ReqID                  uintptr
	Status                 int32
	_                      [4]byte
	HeadersPtr, HeadersLen uintptr // JSON object
	BodyPtr, BodyLen       uintptr
}

// Desktop sub-ops for HostOpDesktop.
const (
	DesktopJumpListSet uintptr = 1 // a1=json_ptr a2=json_len (array of tasks)
	DesktopRecentAdd   uintptr = 2 // a1=path_ptr a2=path_len
	DesktopRecentClear uintptr = 3
	DesktopRecentList  uintptr = 8 // → JSON paths via a1=out a2=cap
	DesktopDockSetMenu uintptr = 4 // a1=json_ptr a2=json_len a3=cb_id
	DesktopDockSetIcon uintptr = 5 // a1=png_ptr a2=png_len
	DesktopDockHide    uintptr = 6
	DesktopDockShow    uintptr = 7
)

// Secrets sub-ops for HostOpSecrets.
const (
	SecretsSet    uintptr = 1 // a1=*CSecretSpec
	SecretsGet    uintptr = 2 // a1=*CSecretSpec, a2=out_ptr, a3=out_cap → len; ^0 + ErrSecretNotFound
	SecretsDelete uintptr = 3 // a1=*CSecretSpec
)

type CSecretSpec struct {
	ServicePtr, ServiceLen uintptr // empty → app id
	KeyPtr, KeyLen         uintptr
	ValuePtr, ValueLen     uintptr // Set only
}

type CAuthReq struct {
	HostPtr, HostLen     uintptr
	Port                 int32
	_                    [4]byte
	RealmPtr, RealmLen   uintptr
	SchemePtr, SchemeLen uintptr
	IsProxy              uint8
	_2                   [7]byte
}

type CAuthResp struct {
	ReqID            uintptr
	UserPtr, UserLen uintptr
	PassPtr, PassLen uintptr
}

type CCertErr struct {
	URLPtr, URLLen     uintptr
	HostPtr, HostLen   uintptr
	ErrorPtr, ErrorLen uintptr
	CertPtr, CertLen   uintptr
}

// Cookies sub-ops for HostOpCookies.
const (
	CookiesList   uintptr = 1 // a1=*CCookiesListSpec → nbytes written
	CookiesSet    uintptr = 2 // a1=cookie_json
	CookiesDelete uintptr = 3
	CookiesClear  uintptr = 4
)

type CCookiesListSpec struct {
	FilterPtr, FilterLen uintptr
	OutPtr, OutCap       uintptr
}

type CDownloadEvent struct {
	ReqID                      uintptr
	URLPtr, URLLen             uintptr
	SuggestedPtr, SuggestedLen uintptr
	PathPtr, PathLen           uintptr
	ErrPtr, ErrLen             uintptr
}

type CDownloadResp struct {
	ReqID            uintptr
	Prevent          uint8
	_                [7]byte
	PathPtr, PathLen uintptr
}

// Session sub-ops for HostOpSession.
const (
	SessionClearBrowsing uintptr = 1 // App.ClearBrowsingData (default session, all)
	SessionClearData     uintptr = 2 // a1=*CSessionClearSpec
)

type CSessionClearSpec struct {
	NamePtr, NameLen uintptr // empty → default session
	Types            uint64  // SiteData bitset; 0 = SiteDataAll
}

// Page event kinds for ZigEventPage.
const (
	PageWillNavigate uintptr = 1
	PageDidNavigate  uintptr = 2
	PageDOMReady     uintptr = 3
	PageDidFinish    uintptr = 4
	PageDidFail      uintptr = 5
	PageRenderGone   uintptr = 6
	PageTitleUpdated uintptr = 7 // req_id in event; respond with WinCtlTitleRespond
	PageThemeColor   uintptr = 8 // packed in CPageEvent.Code as RGBA; UserInitiated=ok
)

type CPageEvent struct {
	ReqID            uintptr
	URLPtr, URLLen   uintptr
	DescPtr, DescLen uintptr
	Code             int32
	UserInitiated    uint8
	_                [3]byte
}

type CNavResp struct {
	ReqID   uintptr
	Prevent uint8
	_       [7]byte
}

type CPermReq struct {
	OriginPtr, OriginLen uintptr
	PermsPtr, PermsLen   uintptr // JSON array of strings
}

type CWindowOpenReq struct {
	URLPtr, URLLen     uintptr
	FramePtr, FrameLen uintptr
	Width, Height      int32
	UserInitiated      uint8
	_                  [3]byte
}

type CWindowOpenResp struct {
	ReqID uintptr
	Deny  uint8 // 1 = deny
	_     [7]byte
	Opts  CWindowOptions
}

type CFindSpec struct {
	TextPtr, TextLen uintptr
	MatchCase        uint8
	Backward         uint8
	FindNext         uint8
	_                [5]byte
}

// Locale sub-ops for HostOpLocale.
const (
	LocaleGet              uintptr = 1 // a1=out a2=cap → len
	LocaleSet              uintptr = 2 // a1=tag (empty = follow user)
	LocalePreferredJSON    uintptr = 3 // a1=out a2=cap
	LocaleLanguagesJSON    uintptr = 4
	LocaleSetLanguagesJSON uintptr = 5 // a1=json array
	LocaleOnChanged        uintptr = 6 // a1=cb_id
)

type CEvalSpec struct {
	CodePtr, CodeLen uintptr
	OutPtr, OutCap   uintptr
}

type CContextMenuEv struct {
	LinkURLPtr, LinkURLLen     uintptr
	LinkTextPtr, LinkTextLen   uintptr
	ImageURLPtr, ImageURLLen   uintptr
	MediaURLPtr, MediaURLLen   uintptr
	SelectionPtr, SelectionLen uintptr
	FrameURLPtr, FrameURLLen   uintptr
	Editable                   uint8
	_                          [7]byte
	MenuPtr, MenuLen           uintptr // default menu JSON
}

type CContextMenuResp struct {
	ReqID            uintptr
	Prevent          uint8
	_                [7]byte
	MenuPtr, MenuLen uintptr // empty → keep default; non-empty replaces
}

// ContentRules sub-ops for HostOpContentRules.
const (
	ContentRulesCompile uintptr = 1 // a1=*CContentRulesCompileSpec
)

type CContentRulesCompileSpec struct {
	IDPtr, IDLen       uintptr
	RulesPtr, RulesLen uintptr
}

type CPDFSpec struct {
	OutPtr, OutCap                                       uintptr
	PageWidth, PageHeight                                float64
	MarginsTop, MarginsRight, MarginsBottom, MarginsLeft float64
	Landscape, Background, HasMargins                    uint8
	_                                                    [5]byte
}

type CThemeColor struct {
	R, G, B, A uint8
	OK         uint8
	_          [3]byte
}

type CIconSpec struct {
	PathPtr, PathLen uintptr
	Size             int32
	_                [4]byte
	OutPtr, OutCap   uintptr
}

// Terminal lifecycle sub-ops for HostOpTerminal.
const (
	TermNew      uintptr = 1 // a1=*CTerminalNewSpec → id
	TermClose     uintptr = 2 // a1=id
	TermPaste     uintptr = 3 // a1=id a2=ptr a3=len
	TermSend      uintptr = 4 // a1=id a2=ptr a3=len
	TermUseTheme  uintptr = 5 // a1=id a2=kind(0 dark/1 light/2 ghostty) a3=name_ptr… via CStr at a3
	TermResize    uintptr = 6 // a1=id a2=cols a3=rows
	TermTitle     uintptr = 7 // a1=id a2=out a3=cap
	TermDir       uintptr = 8
	TermExitCode  uintptr = 9 // → code; running → maxUintptr-1 sentinel? use bit: high bit set if running
	TermClear     uintptr = 10
	TermSearch    uintptr = 11 // a1=id a2=ptr a3=len; empty ends
)

// Terminal event kinds (ZigEventTerminal a2).
const (
	TermEvTitle uintptr = 1 // a3=*CStr
	TermEvExit  uintptr = 2 // a3=exit code
	TermEvBell  uintptr = 3
)

// CTerminalNewSpec creates a plugins/terminal.Terminal.
type CTerminalNewSpec struct {
	CommandPtr, CommandLen uintptr // NUL-separated argv; empty = user shell
	DirPtr, DirLen         uintptr
	TitleCb                uintptr // ZigEventTerminal cb id (0 = none)
	ExitCb                 uintptr
	BellCb                 uintptr
	ShellIntegration       uint8
	Transparent            uint8
	_                      [6]byte
}

// SQLite sub-ops for HostOpSQLite.
const (
	SQLiteOpen        uintptr = 1 // a1=*CSQLiteOpenSpec → id
	SQLiteClose       uintptr = 2 // a1=id
	SQLiteExecute     uintptr = 3 // a1=*CSQLiteExecSpec → nbytes JSON
	SQLiteQuery       uintptr = 4 // a1=*CSQLiteExecSpec → nbytes JSON
	SQLiteTransaction uintptr = 5 // a1=*CSQLiteTxSpec → nbytes JSON
)

type CSQLiteOpenSpec struct {
	PathPtr, PathLen uintptr
	ReadOnly         uint8
	_                [7]byte
}

type CSQLiteExecSpec struct {
	DBID              uintptr
	SQLPtr, SQLLen    uintptr
	ArgsPtr, ArgsLen  uintptr // JSON array
	OutPtr, OutCap    uintptr
}

type CSQLiteTxSpec struct {
	DBID                 uintptr
	StmtsPtr, StmtsLen   uintptr // JSON [{sql,args},...]
	OutPtr, OutCap       uintptr
}

// Watch sub-ops for HostOpWatch.
const (
	WatchStart uintptr = 1 // a1=*CWatchStartSpec → id
	WatchClose uintptr = 2 // a1=id
)

const (
	WatchEvBatch uintptr = 1 // a3=*CStr JSON []FileEvent
	WatchEvDone  uintptr = 2 // a3=*CStr error message (empty = EOF/clean)
)

type CWatchStartSpec struct {
	PathPtr, PathLen uintptr
	EventCb          uintptr
	Recursive        uint8
	HintsOnly        uint8
	_                [6]byte
	DebounceMS       int32
	MaxDelayMS       int32
	MaxEntries       int32
}

// PermissionFlow sub-ops for HostOpPermissionFlow.
const (
	PermCheck        uintptr = 1 // a1=name_ptr a2=name_len → status (0..3), ^0 on err
	PermAllowed      uintptr = 2 // → 1/0
	PermRequest      uintptr = 3 // a1=*CPermAsyncSpec → req_id; result via ZigEventPermFlow
	PermOpenSettings uintptr = 4 // → 0 ok
	PermGuide        uintptr = 5 // a1=*CPermAsyncSpec → req_id
	PermWait         uintptr = 6 // a1=*CPermAsyncSpec → req_id
)

type CPermAsyncSpec struct {
	NamePtr, NameLen uintptr
	AppPtr, AppLen   uintptr // Guide only
	NameLabelPtr, NameLabelLen uintptr
	CbID             uintptr
}

const (
	FetchDo uintptr = 1 // a1=*CFetchSpec → nbytes JSON response
)

type CFetchSpec struct {
	URLPtr, URLLen       uintptr
	MethodPtr, MethodLen uintptr
	HeadersPtr, HeadersLen uintptr // JSON [[name,value],...]
	BodyPtr, BodyLen     uintptr
	RedirectPtr, RedirectLen uintptr // follow|error|manual; empty=follow
	OutPtr, OutCap       uintptr
}

const (
	WSConnect    uintptr = 1 // a1=*CWSConnectSpec → id
	WSSendText   uintptr = 2 // a1=id a2=ptr a3=len
	WSSendBinary uintptr = 3
	WSClose      uintptr = 4 // a1=id a2=code a3=reason via CStr at… use a2=code, a3=*CStr reason
)

const (
	WSEvOpen   uintptr = 1 // a3=*CStr protocol
	WSEvText   uintptr = 2 // a3=*CStr
	WSEvBinary uintptr = 3 // a3=*CStr bytes
	WSEvClose  uintptr = 4 // a3=*CStr JSON {code,reason,clean,error}
)

type CWSConnectSpec struct {
	URLPtr, URLLen             uintptr
	ProtocolsPtr, ProtocolsLen uintptr // JSON string array
	HeadersPtr, HeadersLen     uintptr // JSON [[k,v],...]
	EventCb                    uintptr
}

const (
	UpdaterCheck              uintptr = 1
	UpdaterAutomaticChecksGet uintptr = 2 // → 1/0
	UpdaterAutomaticChecksSet uintptr = 3 // a1=0/1
	UpdaterAutomaticDownloadsGet uintptr = 4
	UpdaterAutomaticDownloadsSet uintptr = 5
	UpdaterAvailableVersion   uintptr = 6 // a1=out a2=cap
)
