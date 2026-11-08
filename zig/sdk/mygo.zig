//! Idiomatic Zig SDK for MyGo (`CGO_ENABLED=0` purego host architecture).
//!
//! Exports a single `mygo_zig_entry` symbol via `comptime { mygo.exportApp(...); }`
//! and communicates with the pure-Go MyGo host over a single `HostDispatchFn`
//! pointer—requiring zero `cgo`, supporting `mygo generate` TypeScript client
//! synthesis from Zig `comptime` types, and packaging directly into `.app` / `.dmg`
//! / Linux / Windows installers via `mygo build`.

const std = @import("std");
pub const abi = @import("abi.zig");
pub const ui = @import("ui.zig");

pub const HostDispatchFn = *const fn (
    op: usize,
    a0: usize,
    a1: usize,
    a2: usize,
    a3: usize,
) callconv(.c) usize;

pub const HostOp = enum(usize) {
    set_name = 1,
    quit = 2,
    last_error = 3,
    register_ts = 4,
    frontend_asset = 5,
    bind_raw = 6,
    emit_raw = 7,
    ipc_defer = 8,
    ipc_resolve = 9,
    ipc_reject = 10,
    window_new = 11,
    window_control = 12,
    window_on_event = 13,
    clipboard = 14,
    shell = 15,
    app_set_menu = 16,
    dialog = 20,
    tray = 21,
    notification = 22,
    path = 23,
    screen = 24,
    hotkey = 25,
    theme = 26,
    power = 27,
    app_events = 28,
    protocol = 29,
    desktop = 30,
    secrets = 31,
    cookies = 32,
    session = 33,
    locale = 34,
    content_rules = 35,

    window_new_ui = 100,
    ui_flush = 101,
    ui_paint_flush = 102,
    flyout_new_ui = 103,

    markdown_view = 200,
    editor_view = 210,
    diff_view = 211,
    line_chart = 220,
    bar_chart = 221,
    area_chart = 222,
    pie_chart = 223,
    video_gif = 230,
    video_frames = 231,
    video_stream = 232,
    video_push = 233,
    video_end = 234,
    terminal = 235,
    terminal_view = 236,
    sqlite = 237,
    watch = 238,
    permission_flow = 239,
    fetch = 243,
    websocket = 244,
    updater = 245,
    glass = 246,
    game = 247,
    gamepad = 248,
    webview = 249,
    documents = 250,
    network = 251,
    now_playing = 252,
    register_font = 240,
    register_bitmap = 241,
    register_canvas = 242,
    audio = 253,
    graph = 255,
    richtext = 256,
    window_states = 254,
    video = 260,
};

pub const WinCtl = enum(usize) {
    show = 1,
    hide = 2,
    close = 3,
    center = 4,
    minimize = 5,
    maximize = 6,
    unmaximize = 7,
    set_fullscreen = 8,
    invalidate = 9,
    set_title = 10,
    get_bounds = 11,
    set_bounds = 12,
    load_url = 13,
    load_html = 14,
    set_input_region = 15,
    set_anchor = 16,
    set_vibrancy = 17,
    set_vibrancy_tint = 18,
    set_progress_bar = 19,
    set_content_protection = 20,
    set_auth_handler = 21,
    auth_respond = 22,
    set_cert_handler = 23,
    on_download = 24,
    download_respond = 25,
    on_page = 26,
    navigate_respond = 27,
    set_permission_handler = 28,
    set_window_open_handler = 29,
    window_open_respond = 30,
    find_in_page = 31,
    stop_find_in_page = 32,
    reload = 33,
    go_back = 34,
    go_forward = 35,
    eval = 36,
    on_context_menu = 37,
    context_menu_respond = 38,
    set_content_rules = 39,
    set_audio_muted = 40,
    is_audio_muted = 41,
    is_audible = 42,
    on_page_media = 43,
    capture_state = 44,
    set_capture_state = 45,
    toggle_pip = 46,
    is_pip_active = 47,
    set_zoom = 48,
    get_zoom = 49,
    set_user_agent = 50,
    get_user_agent = 51,
    open_devtools = 52,
    close_devtools = 53,
    is_devtools_opened = 54,
    toggle_devtools = 55,
    print = 56,
    url = 57,
    is_loading = 58,
    capture_page = 59,
    print_to_pdf = 60,
    set_min_size = 61,
    set_max_size = 62,
    set_size = 63,
    set_position = 64,
    set_resizable = 65,
    is_resizable = 66,
    set_closable = 67,
    is_closable = 68,
    set_maximizable = 69,
    is_maximizable = 70,
    set_minimizable = 71,
    is_minimizable = 72,
    set_movable = 73,
    is_movable = 74,
    set_always_on_top = 75,
    is_always_on_top = 76,
    set_has_shadow = 77,
    has_shadow = 78,
    set_opacity = 79,
    get_opacity = 80,
    set_background_color = 81,
    set_ignore_mouse_events = 82,
    flash_frame = 83,
    set_document_edited = 84,
    is_document_edited = 85,
    set_represented_file = 86,
    get_represented_file = 87,
    is_visible = 88,
    is_focused = 89,
    is_minimized = 90,
    is_maximized = 91,
    is_full_screen = 92,
    is_destroyed = 93,
    blur = 94,
    restore = 95,
    show_inactive = 96,
    set_icon = 97,
    set_skip_taskbar = 98,
    set_auto_hide_menu_bar = 99,
    set_active_appearance = 100,
    native_handle = 101,
    stop = 102,
    reload_ignoring_cache = 103,
    load_file = 104,
    can_go_back = 105,
    can_go_forward = 106,
    process_id = 107,
    gpu_process_id = 108,
    theme_color = 109,
    title_respond = 110,
    session_state = 111,
};


const ZigEvent = enum(usize) {
    init = 1,
    ready = 2,
    ipc = 3,
    window = 4,
    menu = 5,
    bytes = 6,
    ui_view = 7,
    ui_list_row = 8,
    ui_paint = 9,
    ui_subview = 10,
    ui_table_cell = 11,
    ui_action = 12,
    ui_grid_item = 13,
    ui_outline_row = 14,
    ui_route = 15,
    ui_outline_cell = 16,
    ui_provide = 17,
    tray = 18,
    notification = 19,
    hotkey = 20,
    theme = 21,
    power = 22,
    app = 23,
    protocol = 24,
    auth = 25,
    cert = 26,
    download = 27,
    page = 28,
    permission = 29,
    window_open = 30,
    context_menu = 31,
    page_media = 32,
    locale = 33,
    region = 34,
    terminal = 35,
    watch = 36,
    perm_flow = 37,
    websocket = 38,
    game_update = 39,
    game_draw = 40,
    documents = 41,
    network = 42,
    now_playing = 43,
    ui_input = 44,
    ui_hit_test = 45,
    audio_end = 46,
    ui_text_key = 47,
    ui_text_client = 48,
    graph_select = 49,
    graph_connect = 50,
    graph_move = 51,
    graph_delete = 52,
    graph_viewport = 53,
    graph_node = 54,
    richtext_link = 55,
    richtext_link_command = 56,
    richtext_tag = 57,
    window_states_load = 58,
    window_states_save = 59,
    ui_effect = 60,
};

pub const CStr = extern struct {
    data: usize = 0,
    len: usize = 0,

    pub fn fromSlice(s: []const u8) CStr {
        return .{
            .data = if (s.len > 0) @intFromPtr(s.ptr) else 0,
            .len = s.len,
        };
    }

    pub fn toSlice(self: CStr) []const u8 {
        if (self.data == 0 or self.len == 0) return "";
        const ptr: [*]const u8 = @ptrFromInt(self.data);
        return ptr[0..self.len];
    }
};

pub const CWindowOptions = extern struct {
    title: CStr = .{},
    url: CStr = .{},
    background_color: CStr = .{},
    width: i32 = 0,
    height: i32 = 0,
    min_width: i32 = 0,
    min_height: i32 = 0,
    max_width: i32 = 0,
    max_height: i32 = 0,
    devtools: i32 = 0,
    use_content_size: u8 = 0,
    hidden: u8 = 0,
    frameless: u8 = 0,
    disable_resize: u8 = 0,
    always_on_top: u8 = 0,
    transparent: u8 = 0,
    _pad: [2]u8 = .{ 0, 0 },
    vibrancy: CStr = .{},
    vibrancy_tint: CStr = .{},
    title_bar_style: CStr = .{},
    title_bar_height: i32 = 0,
    _pad_tb: [4]u8 = @splat(0),
    session_name: CStr = .{},
    state_key: CStr = .{},
    session_state_ptr: usize = 0,
    session_state_len: usize = 0,
};

const CAssetSpec = extern struct {
    path: CStr,
    data: usize,
    data_len: usize,
    static_lifetime: u8,
    _pad: [7]u8 = @splat(0),
};

const CEmitSpec = extern struct {
    event: CStr,
    payload: CStr,
};

const CTSSpec = extern struct {
    kind: u32,
    _pad: u32 = 0,
    service: CStr = .{},
    name: CStr = .{},
    params: CStr = .{},
    call_arg: CStr = .{},
    type_str: CStr = .{},
};

const CBounds = extern struct {
    x: i32 = 0,
    y: i32 = 0,
    width: i32 = 0,
    height: i32 = 0,
};

const CHtmlSpec = extern struct {
    html: CStr,
    base_url: CStr,
};

var host_fn: ?HostDispatchFn = null;

pub fn dispatch(op: HostOp, a0: usize, a1: usize, a2: usize, a3: usize) usize {
    return (host_fn.?)(@intFromEnum(op), a0, a1, a2, a3);
}

// Callback tables indexed by 1-based IDs passed to the purego host.
const RawIpcHandler = *const fn (win_id: i32, args: []const u8, reply: usize) void;
const RawWindowHandler = *const fn (win_id: i32, payload: []const u8) bool;
const RawBytesHandler = *const fn (bytes: []const u8, userdata: usize) void;

var ipc_handlers: [256]RawIpcHandler = undefined;
var ipc_count: usize = 0;

var win_handlers: [256]RawWindowHandler = undefined;
var win_count: usize = 0;

pub var ui_view_handlers: [64]ui.RawViewHandler = undefined;
pub var ui_view_count: usize = 0;

pub var ui_row_handlers: [128]ui.RawListRowHandler = undefined;
pub var ui_row_count: usize = 0;

pub var ui_paint_handlers: [128]ui.RawPaintHandler = undefined;
pub var ui_paint_count: usize = 0;

/// Element input handlers (observeInput / handleInput); returns 1 to take it.
pub const RawUIInput = *const fn (info: *const abi.Input, userdata: usize) usize;
pub var ui_input_handlers: [64]RawUIInput = undefined;
pub var ui_input_count: usize = 0;

/// Element hit tests; returns 1 when the pointer hits.
pub const RawUIHit = *const fn (hit: *const abi.Hit, userdata: usize) usize;
pub var ui_hit_handlers: [64]RawUIHit = undefined;
pub var ui_hit_count: usize = 0;

/// Text input key handlers (OnTextKey); returns 1 to take the key.
pub const RawUITextKey = *const fn (info: *abi.TextKey, userdata: usize) usize;
pub var ui_textkey_handlers: [64]RawUITextKey = undefined;
pub var ui_textkey_count: usize = 0;

/// Graph board callbacks: a JSON payload (and a state pointer per slot).
pub const RawGraphBytes = *const fn (json: []const u8, userdata: usize) void;
pub var graph_handlers: [128]RawGraphBytes = undefined;
pub var graph_ud: [128]usize = undefined;
pub var graph_count: usize = 0;

/// Graph node body builders: a nested frame and the node.
pub const RawGraphNode = *const fn (frame: usize, info: *const ui.Graph.CGraphNodeInfo, userdata: usize) void;
pub var graph_node_handlers: [128]RawGraphNode = undefined;
pub var graph_node_ud: [128]usize = undefined;
pub var graph_node_count: usize = 0;

/// registerGraphHandler adds a board callback, returning its id.
pub fn registerGraphHandler(handler: RawGraphBytes, userdata: usize) usize {
    if (graph_count >= graph_handlers.len) return 0;
    graph_handlers[graph_count] = handler;
    graph_ud[graph_count] = userdata;
    graph_count += 1;
    return graph_count;
}

/// registerGraphNode adds a node body builder, returning its id.
pub fn registerGraphNode(handler: RawGraphNode, userdata: usize) usize {
    if (graph_node_count >= graph_node_handlers.len) return 0;
    graph_node_handlers[graph_node_count] = handler;
    graph_node_ud[graph_node_count] = userdata;
    graph_node_count += 1;
    return graph_node_count;
}

/// Element effect paint callbacks (Element.effect).
pub const RawUIEffect = *const fn (painter: usize, spec: *abi.EffectPaint, userdata: usize) void;
pub var ui_effect_handlers: [64]RawUIEffect = undefined;
pub var ui_effect_ud: [64]usize = undefined;
pub var ui_effect_count: usize = 0;

/// registerUIEffect adds an effect paint callback, returning its id.
pub fn registerUIEffect(handler: RawUIEffect, userdata: usize) usize {
    if (ui_effect_count >= ui_effect_handlers.len) return 0;
    ui_effect_handlers[ui_effect_count] = handler;
    ui_effect_ud[ui_effect_count] = userdata;
    ui_effect_count += 1;
    return ui_effect_count;
}

/// Window state store: load writes JSON into a buffer, save reads it.
pub const RawWindowStatesLoad = *const fn (buf: []u8, userdata: usize) usize;
pub const RawWindowStatesSave = *const fn (json: []const u8, userdata: usize) void;
pub var window_states_load_handlers: [16]RawWindowStatesLoad = undefined;
pub var window_states_save_handlers: [16]RawWindowStatesSave = undefined;
pub var window_states_ud: [16]usize = undefined;
pub var window_states_count: usize = 0;

/// setWindowStateStore saves and restores windows with a StateKey through Zig.
pub fn setWindowStateStore(
    comptime StatePtr: type,
    state: StatePtr,
    comptime load: fn (StatePtr, []u8) usize,
    comptime save: fn (StatePtr, []const u8) void,
) void {
    const L = struct {
        fn onLoad(buf: []u8, ud: usize) usize {
            const s: StatePtr = @ptrFromInt(ud);
            return load(s, buf);
        }
    };
    const S = struct {
        fn onSave(json: []const u8, ud: usize) void {
            const s: StatePtr = @ptrFromInt(ud);
            save(s, json);
        }
    };
    if (window_states_count >= window_states_load_handlers.len) return;
    window_states_load_handlers[window_states_count] = &L.onLoad;
    window_states_save_handlers[window_states_count] = &S.onSave;
    window_states_ud[window_states_count] = @intFromPtr(state);
    window_states_count += 1;
    _ = dispatch(.window_states, 1, window_states_count, window_states_count, 0);
}

/// Rich text callbacks: a link URL, a link command, or a tag's style.
pub const RawRichTextBytes = *const fn (data: []const u8, userdata: usize) void;
pub const RawRichTextTag = *const fn (tag: []const u8, style: *abi.SpanStyle, userdata: usize) void;
pub var richtext_handlers: [64]RawRichTextBytes = undefined;
pub var richtext_tag_handlers: [64]RawRichTextTag = undefined;
pub var richtext_ud: [64]usize = undefined;
pub var richtext_count: usize = 0;

/// registerRichTextHandler adds a link or link-command handler, returning its id.
pub fn registerRichTextHandler(handler: RawRichTextBytes, userdata: usize) usize {
    if (richtext_count >= richtext_handlers.len) return 0;
    richtext_handlers[richtext_count] = handler;
    richtext_ud[richtext_count] = userdata;
    richtext_count += 1;
    return richtext_count;
}

/// registerRichTextTag adds a tag style handler, returning its id.
pub fn registerRichTextTag(handler: RawRichTextTag, userdata: usize) usize {
    if (richtext_count >= richtext_tag_handlers.len) return 0;
    richtext_tag_handlers[richtext_count] = handler;
    richtext_ud[richtext_count] = userdata;
    richtext_count += 1;
    return richtext_count;
}

/// Text-input client questions (HandleTextInput).
pub const RawUITextClient = *const fn (req: *abi.TextClientReq, userdata: usize) void;
pub var ui_textclient_handlers: [64]RawUITextClient = undefined;
pub var ui_textclient_count: usize = 0;

/// Player end-of-playback handlers.
pub const RawAudioEnd = *const fn (player_id: usize, userdata: usize) void;
pub var audio_end_handlers: [64]RawAudioEnd = undefined;
pub var audio_end_count: usize = 0;

pub var ui_subview_handlers: [128]ui.RawViewHandler = undefined;
pub var ui_subview_count: usize = 0;

pub var ui_table_cell_handlers: [64]ui.RawTableCellHandler = undefined;
pub var ui_table_cell_count: usize = 0;

pub var ui_action_handlers: [64]ui.RawActionHandler = undefined;
pub var ui_action_count: usize = 0;
pub var ui_provide_handlers: [32]ui.RawProvideHandler = undefined;
pub var ui_provide_count: usize = 0;

pub var ui_grid_item_handlers: [64]ui.RawGridItemHandler = undefined;
pub var ui_grid_item_count: usize = 0;

pub var ui_outline_row_handlers: [64]ui.RawOutlineRowHandler = undefined;
pub var ui_outline_row_count: usize = 0;

pub var ui_route_handlers: [32]ui.RawRouteHandler = undefined;
pub var ui_route_count: usize = 0;

pub var ui_outline_cell_handlers: [64]ui.RawOutlineCellHandler = undefined;
pub var ui_outline_cell_count: usize = 0;

var bytes_handlers: [32]RawBytesHandler = undefined;
var bytes_count: usize = 0;

const RawTrayHandler = *const fn (tray_id: usize, kind: u8, menu_id: []const u8, userdata: usize) void;
var tray_handlers: [32]RawTrayHandler = undefined;
var tray_count: usize = 0;
var tray_handler_userdata: [32]usize = undefined;

fn registerTrayHandler(h: RawTrayHandler, userdata: usize) usize {
    tray_handlers[tray_count] = h;
    tray_handler_userdata[tray_count] = userdata;
    tray_count += 1;
    return tray_count;
}

const RawNotifHandler = *const fn (kind: u8, id: []const u8, userdata: usize) void;
var notif_handlers: [32]RawNotifHandler = undefined;
var notif_count: usize = 0;
var notif_handler_userdata: [32]usize = undefined;

fn registerNotifHandler(h: RawNotifHandler, userdata: usize) usize {
    notif_handlers[notif_count] = h;
    notif_handler_userdata[notif_count] = userdata;
    notif_count += 1;
    return notif_count;
}

const RawHotkeyHandler = *const fn (userdata: usize) void;
var hotkey_handlers: [32]RawHotkeyHandler = undefined;
var hotkey_count: usize = 0;
var hotkey_handler_userdata: [32]usize = undefined;

fn registerHotkeyHandler(h: RawHotkeyHandler, userdata: usize) usize {
    hotkey_handlers[hotkey_count] = h;
    hotkey_handler_userdata[hotkey_count] = userdata;
    hotkey_count += 1;
    return hotkey_count;
}

const RawThemeHandler = *const fn (userdata: usize) void;
var theme_handlers: [8]RawThemeHandler = undefined;
var theme_count: usize = 0;
var theme_handler_userdata: [8]usize = undefined;

fn registerThemeHandler(h: RawThemeHandler, userdata: usize) usize {
    theme_handlers[theme_count] = h;
    theme_handler_userdata[theme_count] = userdata;
    theme_count += 1;
    return theme_count;
}

const RawPowerHandler = *const fn (event: []const u8, userdata: usize) void;
var power_handlers: [8]RawPowerHandler = undefined;
var power_count: usize = 0;
var power_handler_userdata: [8]usize = undefined;

fn registerPowerHandler(h: RawPowerHandler, userdata: usize) usize {
    power_handlers[power_count] = h;
    power_handler_userdata[power_count] = userdata;
    power_count += 1;
    return power_count;
}

/// kind: 1 activate(flag) 2 become 3 resign 4 beforeQuit 5 willQuit 6 openURL 7 openFile 8 secondInstance
/// Return nonzero from beforeQuit/willQuit handlers to prevent default.
const RawAppHandler = *const fn (kind: u8, a2: usize, a3: usize, userdata: usize) usize;
var app_handlers: [16]RawAppHandler = undefined;
var app_count: usize = 0;
var app_handler_userdata: [16]usize = undefined;

fn registerAppHandler(h: RawAppHandler, userdata: usize) usize {
    app_handlers[app_count] = h;
    app_handler_userdata[app_count] = userdata;
    app_count += 1;
    return app_count;
}

pub const ProtocolRequest = struct {
    method: []const u8,
    url: []const u8,
    headers_json: []const u8,
};

const RawProtocolHandler = *const fn (req_id: usize, req: ProtocolRequest, userdata: usize) void;
var protocol_handlers: [16]RawProtocolHandler = undefined;
var protocol_count: usize = 0;
var protocol_handler_userdata: [16]usize = undefined;

fn registerProtocolHandler(h: RawProtocolHandler, userdata: usize) usize {
    protocol_handlers[protocol_count] = h;
    protocol_handler_userdata[protocol_count] = userdata;
    protocol_count += 1;
    return protocol_count;
}

fn registerBytesHandler(h: RawBytesHandler) usize {
    bytes_handlers[bytes_count] = h;
    bytes_count += 1;
    return bytes_count;
}

const RawMenuHandler = *const fn (win_id: i32, id: []const u8, userdata: usize) void;
var menu_handlers: [16]RawMenuHandler = undefined;
var menu_count: usize = 0;
var menu_handler_userdata: [16]usize = undefined;

fn registerMenuHandler(h: RawMenuHandler, userdata: usize) usize {
    menu_handlers[menu_count] = h;
    menu_handler_userdata[menu_count] = userdata;
    menu_count += 1;
    return menu_count;
}

pub const AuthRequest = struct {
    host: []const u8,
    port: i32,
    realm: []const u8,
    scheme: []const u8,
    is_proxy: bool,
};

pub const AuthResponse = struct {
    username: []const u8 = "",
    password: []const u8 = "",
};

pub const CertificateError = struct {
    url: []const u8,
    host: []const u8,
    err: []const u8,
    certificate: []const u8,
};

const RawAuthHandler = *const fn (win_id: i32, req_id: usize, req: AuthRequest, userdata: usize) void;
var auth_handlers: [8]RawAuthHandler = undefined;
var auth_count: usize = 0;
var auth_handler_userdata: [8]usize = undefined;

fn registerAuthHandler(h: RawAuthHandler, userdata: usize) usize {
    auth_handlers[auth_count] = h;
    auth_handler_userdata[auth_count] = userdata;
    auth_count += 1;
    return auth_count;
}

const RawCertHandler = *const fn (win_id: i32, err: CertificateError, userdata: usize) bool;
var cert_handlers: [8]RawCertHandler = undefined;
var cert_count: usize = 0;
var cert_handler_userdata: [8]usize = undefined;

fn registerCertHandler(h: RawCertHandler, userdata: usize) usize {
    cert_handlers[cert_count] = h;
    cert_handler_userdata[cert_count] = userdata;
    cert_count += 1;
    return cert_count;
}

pub const DownloadEvent = struct {
    req_id: usize = 0,
    url: []const u8 = "",
    suggested: []const u8 = "",
    path: []const u8 = "",
    err: []const u8 = "",
};

const RawDownloadHandler = *const fn (win_id: i32, kind: u8, ev: DownloadEvent, userdata: usize) void;
var download_handlers: [8]RawDownloadHandler = undefined;
var download_count: usize = 0;
var download_handler_userdata: [8]usize = undefined;

fn registerDownloadHandler(h: RawDownloadHandler, userdata: usize) usize {
    download_handlers[download_count] = h;
    download_handler_userdata[download_count] = userdata;
    download_count += 1;
    return download_count;
}

pub const PageEventKind = enum(u8) {
    will_navigate = 1,
    did_navigate = 2,
    dom_ready = 3,
    did_finish = 4,
    did_fail = 5,
    render_gone = 6,
    title_updated = 7,
    theme_color = 8,
};

pub const PageEvent = struct {
    req_id: usize = 0,
    url: []const u8 = "",
    description: []const u8 = "",
    code: i32 = 0,
    user_initiated: bool = false,
};

const RawPageHandler = *const fn (win_id: i32, kind: u8, ev: PageEvent, userdata: usize) void;
var page_handlers: [8]RawPageHandler = undefined;
var page_count: usize = 0;
var page_handler_userdata: [8]usize = undefined;

fn registerPageHandler(h: RawPageHandler, userdata: usize) usize {
    page_handlers[page_count] = h;
    page_handler_userdata[page_count] = userdata;
    page_count += 1;
    return page_count;
}

pub const PermissionRequest = struct {
    origin: []const u8 = "",
    permissions_json: []const u8 = "[]",
};

pub const WindowOpenRequest = struct {
    url: []const u8 = "",
    frame_name: []const u8 = "",
    width: i32 = 0,
    height: i32 = 0,
    user_initiated: bool = false,
};

const RawPermissionHandler = *const fn (win_id: i32, req: PermissionRequest, userdata: usize) bool;
var permission_handlers: [8]RawPermissionHandler = undefined;
var permission_count: usize = 0;
var permission_handler_userdata: [8]usize = undefined;

fn registerPermissionHandler(h: RawPermissionHandler, userdata: usize) usize {
    permission_handlers[permission_count] = h;
    permission_handler_userdata[permission_count] = userdata;
    permission_count += 1;
    return permission_count;
}

const RawWindowOpenHandler = *const fn (win_id: i32, req_id: usize, req: WindowOpenRequest, userdata: usize) void;
var window_open_handlers: [8]RawWindowOpenHandler = undefined;
var window_open_count: usize = 0;
var window_open_handler_userdata: [8]usize = undefined;

fn registerWindowOpenHandler(h: RawWindowOpenHandler, userdata: usize) usize {
    window_open_handlers[window_open_count] = h;
    window_open_handler_userdata[window_open_count] = userdata;
    window_open_count += 1;
    return window_open_count;
}

pub const ContextMenuEvent = struct {
    req_id: usize = 0,
    link_url: []const u8 = "",
    link_text: []const u8 = "",
    image_url: []const u8 = "",
    media_url: []const u8 = "",
    selection: []const u8 = "",
    frame_url: []const u8 = "",
    editable: bool = false,
    menu_json: []const u8 = "[]",
};

const RawContextMenuHandler = *const fn (win_id: i32, ev: ContextMenuEvent, userdata: usize) void;
var context_menu_handlers: [8]RawContextMenuHandler = undefined;
var context_menu_count: usize = 0;
var context_menu_handler_userdata: [8]usize = undefined;

fn registerContextMenuHandler(h: RawContextMenuHandler, userdata: usize) usize {
    context_menu_handlers[context_menu_count] = h;
    context_menu_handler_userdata[context_menu_count] = userdata;
    context_menu_count += 1;
    return context_menu_count;
}

const RawPageMediaHandler = *const fn (win_id: i32, kind: u8, payload: usize, userdata: usize) void;
var page_media_handlers: [8]RawPageMediaHandler = undefined;
var page_media_count: usize = 0;
var page_media_handler_userdata: [8]usize = undefined;

fn registerPageMediaHandler(h: RawPageMediaHandler, userdata: usize) usize {
    page_media_handlers[page_media_count] = h;
    page_media_handler_userdata[page_media_count] = userdata;
    page_media_count += 1;
    return page_media_count;
}

const RawLocaleHandler = *const fn (locale: []const u8, userdata: usize) void;
var locale_handlers: [8]RawLocaleHandler = undefined;
var locale_count: usize = 0;
var locale_handler_userdata: [8]usize = undefined;

fn registerLocaleHandler(h: RawLocaleHandler, userdata: usize) usize {
    locale_handlers[locale_count] = h;
    locale_handler_userdata[locale_count] = userdata;
    locale_count += 1;
    return locale_count;
}

const RawRegionHandler = *const fn (json: []const u8, userdata: usize) void;
var region_handlers: [8]RawRegionHandler = undefined;
var region_count: usize = 0;
var region_handler_userdata: [8]usize = undefined;

fn registerRegionHandler(h: RawRegionHandler, userdata: usize) usize {
    region_handlers[region_count] = h;
    region_handler_userdata[region_count] = userdata;
    region_count += 1;
    return region_count;
}

const RawTerminalHandler = *const fn (term_id: usize, kind: u8, a3: usize, userdata: usize) void;
var terminal_handlers: [16]RawTerminalHandler = undefined;
var terminal_count: usize = 0;
var terminal_handler_userdata: [16]usize = undefined;

fn registerTerminalHandler(h: RawTerminalHandler, userdata: usize) usize {
    terminal_handlers[terminal_count] = h;
    terminal_handler_userdata[terminal_count] = userdata;
    terminal_count += 1;
    return terminal_count;
}

const RawWatchHandler = *const fn (watch_id: usize, kind: u8, a3: usize, userdata: usize) void;
var watch_handlers: [16]RawWatchHandler = undefined;
var watch_count: usize = 0;
var watch_handler_userdata: [16]usize = undefined;

fn registerWatchHandler(h: RawWatchHandler, userdata: usize) usize {
    watch_handlers[watch_count] = h;
    watch_handler_userdata[watch_count] = userdata;
    watch_count += 1;
    return watch_count;
}

const RawPermFlowHandler = *const fn (req_id: usize, status: u8, err_json: []const u8, userdata: usize) void;
var perm_handlers: [16]RawPermFlowHandler = undefined;
var perm_count: usize = 0;
var perm_handler_userdata: [16]usize = undefined;

fn registerPermFlowHandler(h: RawPermFlowHandler, userdata: usize) usize {
    perm_handlers[perm_count] = h;
    perm_handler_userdata[perm_count] = userdata;
    perm_count += 1;
    return perm_count;
}

const RawWSHandler = *const fn (conn_id: usize, kind: u8, a3: usize, userdata: usize) void;
var ws_handlers: [16]RawWSHandler = undefined;
var ws_count: usize = 0;
var ws_handler_userdata: [16]usize = undefined;

fn registerWSHandler(h: RawWSHandler, userdata: usize) usize {
    ws_handlers[ws_count] = h;
    ws_handler_userdata[ws_count] = userdata;
    ws_count += 1;
    return ws_count;
}

const RawGameUpdate = *const fn (input: *const GameInput, userdata: usize) void;
const RawGameDraw = *const fn (painter: usize, draw: *const GameDrawInfo, userdata: usize) void;
var game_update_handlers: [32]RawGameUpdate = undefined;
var game_draw_handlers: [32]RawGameDraw = undefined;
var game_update_ud: [32]usize = undefined;
var game_draw_ud: [32]usize = undefined;
var game_update_count: usize = 0;
var game_draw_count: usize = 0;

pub fn registerGameUpdate(h: RawGameUpdate, userdata: usize) usize {
    game_update_handlers[game_update_count] = h;
    game_update_ud[game_update_count] = userdata;
    game_update_count += 1;
    return game_update_count;
}
pub fn registerGameDraw(h: RawGameDraw, userdata: usize) usize {
    game_draw_handlers[game_draw_count] = h;
    game_draw_ud[game_draw_count] = userdata;
    game_draw_count += 1;
    return game_draw_count;
}

const RawDocHandler = *const fn (doc_id: usize, kind: u8, a3: usize, userdata: usize) usize;
var doc_handlers: [8]RawDocHandler = undefined;
var doc_handler_ud: [8]usize = undefined;
var doc_count: usize = 0;

pub fn registerDocHandler(h: RawDocHandler, userdata: usize) usize {
    doc_handlers[doc_count] = h;
    doc_handler_ud[doc_count] = userdata;
    doc_count += 1;
    return doc_count;
}

const RawNetworkHandler = *const fn (payload: []const u8, userdata: usize) void;
var network_handlers: [8]RawNetworkHandler = undefined;
var network_handler_ud: [8]usize = undefined;
var network_count: usize = 0;

pub fn registerNetworkHandler(h: RawNetworkHandler, userdata: usize) usize {
    network_handlers[network_count] = h;
    network_handler_ud[network_count] = userdata;
    network_count += 1;
    return network_count;
}

const RawNowPlayingHandler = *const fn (cmd: usize, position_ns: usize, userdata: usize) void;
var nowplaying_handlers: [8]RawNowPlayingHandler = undefined;
var nowplaying_handler_ud: [8]usize = undefined;
var nowplaying_count: usize = 0;

pub fn registerNowPlayingHandler(h: RawNowPlayingHandler, userdata: usize) usize {
    nowplaying_handlers[nowplaying_count] = h;
    nowplaying_handler_ud[nowplaying_count] = userdata;
    nowplaying_count += 1;
    return nowplaying_count;
}

pub const GameInput = extern struct {
    keys_down: u64 = 0,
    keys_pressed: u64 = 0,
    keys_released: u64 = 0,
    pointer_x: f32 = 0,
    pointer_y: f32 = 0,
    pointer_over: u8 = 0,
    focused: u8 = 0,
    buttons: u8 = 0,
    buttons_pressed: u8 = 0,
    buttons_released: u8 = 0,
    _pad0: u8 = 0,
    wheel_x: f32 = 0,
    wheel_y: f32 = 0,
    width: f32 = 0,
    height: f32 = 0,
    key_w: u8 = 0,
    key_a: u8 = 0,
    key_s: u8 = 0,
    key_d: u8 = 0,
    key_left: u8 = 0,
    key_right: u8 = 0,
    key_up: u8 = 0,
    key_down: u8 = 0,
    key_space: u8 = 0,
    key_escape: u8 = 0,
    _pad1: [2]u8 = .{ 0, 0 },
};

pub const GameDrawInfo = extern struct {
    x: f32 = 0,
    y: f32 = 0,
    w: f32 = 0,
    h: f32 = 0,
    alpha: f32 = 0,
    _pad: f32 = 0,
};

pub const AppConfig = struct {
    init: ?*const fn () anyerror!void = null,
    ready: *const fn () void,
};

/// Exports the `mygo_zig_entry` C ABI symbol consumed by `zig/host`.
pub fn exportApp(comptime cfg: AppConfig) void {
    const Entry = struct {
        pub fn mygo_zig_entry(kind_raw: usize, a0: usize, a1: usize, a2: usize, a3: usize) callconv(.c) isize {
            const kind: ZigEvent = @enumFromInt(kind_raw);
            switch (kind) {
                .init => {
                    host_fn = @ptrFromInt(a0);
                    if (cfg.init) |init_fn| {
                        init_fn() catch |err| {
                            std.debug.print("[mygo-zig] init error: {s}\n", .{@errorName(err)});
                            return -1;
                        };
                    }
                    return 0;
                },
                .ready => {
                    cfg.ready();
                    return 0;
                },
                .ipc => {
                    if (a0 == 0 or a0 > ipc_count) return -1;
                    const arg_view: *const CStr = @ptrFromInt(a2);
                    ipc_handlers[a0 - 1](@intCast(@as(isize, @bitCast(a1))), arg_view.toSlice(), a3);
                    return 0;
                },
                .window => {
                    if (a0 == 0 or a0 > win_count) return 0;
                    const slice: []const u8 = if (a2 != 0 and a3 > 0) @as([*]const u8, @ptrFromInt(a2))[0..a3] else "";
                    const prevent = win_handlers[a0 - 1](@intCast(@as(isize, @bitCast(a1))), slice);
                    return if (prevent) 1 else 0;
                },
                .menu => {
                    if (a0 == 0 or a0 > menu_count) return 0;
                    const win_id: i32 = @intCast(@as(isize, @bitCast(a1)));
                    const id: []const u8 = if (a2 != 0 and a3 > 0) @as([*]const u8, @ptrFromInt(a2))[0..a3] else "";
                    menu_handlers[a0 - 1](win_id, id, menu_handler_userdata[a0 - 1]);
                    return 0;
                },
                .bytes => {
                    if (a0 == 0 or a0 > bytes_count) return 0;
                    const slice: []const u8 = if (a1 != 0 and a2 > 0) @as([*]const u8, @ptrFromInt(a1))[0..a2] else "";
                    bytes_handlers[a0 - 1](slice, a3);
                    return 0;
                },
                .ui_view => {
                    if (a0 == 0 or a0 > ui_view_count) return 0;
                    const info: *const ui.CFrameInfo = @ptrFromInt(a2);
                    ui_view_handlers[a0 - 1](a1, info, a3);
                    return 0;
                },
                .ui_list_row => {
                    if (a0 == 0 or a0 > ui_row_count) return 0;
                    const info: *const ui.CListRowInfo = @ptrFromInt(a2);
                    ui_row_handlers[a0 - 1](a1, info, a3);
                    return 0;
                },
                .ui_paint => {
                    if (a0 == 0 or a0 > ui_paint_count) return 0;
                    const rect: *const ui.CRect = @ptrFromInt(a2);
                    ui_paint_handlers[a0 - 1](a1, rect, a3);
                    return 0;
                },
                .ui_input => {
                    if (a0 == 0 or a0 > ui_input_count) return 0;
                    const info: *const abi.Input = @ptrFromInt(a1);
                    return @intCast(ui_input_handlers[a0 - 1](info, a2));
                },
                .ui_hit_test => {
                    if (a0 == 0 or a0 > ui_hit_count) return 0;
                    const hit: *const abi.Hit = @ptrFromInt(a1);
                    return @intCast(ui_hit_handlers[a0 - 1](hit, a2));
                },
                .graph_select, .graph_connect, .graph_move, .graph_delete, .graph_viewport => {
                    if (a0 == 0 or a0 > graph_count) return 0;
                    const slice: []const u8 = if (a1 != 0 and a2 > 0) @as([*]const u8, @ptrFromInt(a1))[0..a2] else "";
                    graph_handlers[a0 - 1](slice, graph_ud[a0 - 1]);
                    return 0;
                },
                .ui_effect => {
                    if (a0 == 0 or a0 > ui_effect_count) return 0;
                    const spec: *abi.EffectPaint = @ptrFromInt(a2);
                    ui_effect_handlers[a0 - 1](a1, spec, ui_effect_ud[a0 - 1]);
                    return 0;
                },
                .window_states_load => {
                    if (a0 == 0 or a0 > window_states_count) return 0;
                    const buf: []u8 = if (a1 != 0 and a2 > 0) @as([*]u8, @ptrFromInt(a1))[0..a2] else &.{};
                    return @intCast(window_states_load_handlers[a0 - 1](buf, window_states_ud[a0 - 1]));
                },
                .window_states_save => {
                    if (a0 == 0 or a0 > window_states_count) return 0;
                    const json: []const u8 = if (a1 != 0 and a2 > 0) @as([*]const u8, @ptrFromInt(a1))[0..a2] else "";
                    window_states_save_handlers[a0 - 1](json, window_states_ud[a0 - 1]);
                    return 0;
                },
                .richtext_link => {
                    if (a0 == 0 or a0 > richtext_count) return 0;
                    const slice: []const u8 = if (a1 != 0 and a2 > 0) @as([*]const u8, @ptrFromInt(a1))[0..a2] else "";
                    richtext_handlers[a0 - 1](slice, richtext_ud[a0 - 1]);
                    return 0;
                },
                .richtext_link_command => {
                    if (a0 == 0 or a0 > richtext_count) return 0;
                    richtext_handlers[a0 - 1]("", richtext_ud[a0 - 1]);
                    return 0;
                },
                .richtext_tag => {
                    if (a0 == 0 or a0 > richtext_count) return 0;
                    const slice: []const u8 = if (a1 != 0 and a2 > 0) @as([*]const u8, @ptrFromInt(a1))[0..a2] else "";
                    const style: *abi.SpanStyle = @ptrFromInt(a3);
                    richtext_tag_handlers[a0 - 1](slice, style, richtext_ud[a0 - 1]);
                    return 0;
                },
                .graph_node => {
                    if (a0 == 0 or a0 > graph_node_count) return 0;
                    const info: *const ui.Graph.CGraphNodeInfo = @ptrFromInt(a2);
                    graph_node_handlers[a0 - 1](a1, info, graph_node_ud[a0 - 1]);
                    return 0;
                },
                .ui_text_client => {
                    if (a0 == 0 or a0 > ui_textclient_count) return 0;
                    const req: *abi.TextClientReq = @ptrFromInt(a1);
                    ui_textclient_handlers[a0 - 1](req, a2);
                    return 0;
                },
                .ui_text_key => {
                    if (a0 == 0 or a0 > ui_textkey_count) return 0;
                    const info: *abi.TextKey = @ptrFromInt(a1);
                    return @intCast(ui_textkey_handlers[a0 - 1](info, a2));
                },
                .audio_end => {
                    if (a0 == 0 or a0 > audio_end_count) return 0;
                    audio_end_handlers[a0 - 1](a1, a2);
                    return 0;
                },
                .ui_subview => {
                    if (a0 == 0 or a0 > ui_subview_count) return 0;
                    const info: *const ui.CFrameInfo = @ptrFromInt(a2);
                    ui_subview_handlers[a0 - 1](a1, info, a3);
                    return 0;
                },
                .ui_table_cell => {
                    if (a0 == 0 or a0 > ui_table_cell_count) return 0;
                    const info: *const ui.CTableCellInfo = @ptrFromInt(a2);
                    ui_table_cell_handlers[a0 - 1](a1, info, a3);
                    return 0;
                },
                .ui_action => {
                    if (a0 == 0 or a0 > ui_action_count) return 0;
                    ui_action_handlers[a0 - 1](a3);
                    return 0;
                },
                .ui_provide => {
                    if (a0 == 0 or a0 > ui_provide_count) return 0;
                    const buf: []u8 = if (a1 != 0 and a2 > 0) @as([*]u8, @ptrFromInt(a1))[0..a2] else &.{};
                    const n = ui_provide_handlers[a0 - 1](buf, a3);
                    return @intCast(n);
                },
                .ui_grid_item => {
                    if (a0 == 0 or a0 > ui_grid_item_count) return 0;
                    const info: *const ui.CGridItemInfo = @ptrFromInt(a2);
                    ui_grid_item_handlers[a0 - 1](a1, info, a3);
                    return 0;
                },
                .ui_outline_row => {
                    if (a0 == 0 or a0 > ui_outline_row_count) return 0;
                    const info: *const ui.COutlineRowInfo = @ptrFromInt(a2);
                    ui_outline_row_handlers[a0 - 1](a1, info, a3);
                    return 0;
                },
                .ui_route => {
                    if (a0 == 0 or a0 > ui_route_count) return 0;
                    const info: *const ui.CRouteInfo = @ptrFromInt(a2);
                    ui_route_handlers[a0 - 1](a1, info, a3);
                    return 0;
                },
                .ui_outline_cell => {
                    if (a0 == 0 or a0 > ui_outline_cell_count) return 0;
                    const info: *const ui.COutlineCellInfo = @ptrFromInt(a2);
                    ui_outline_cell_handlers[a0 - 1](a1, info, a3);
                    return 0;
                },
                .tray => {
                    if (a0 == 0 or a0 > tray_count) return 0;
                    const tray_kind: u8 = @intCast(a2);
                    const menu_id: []const u8 = blk: {
                        if (tray_kind == 4 and a3 != 0) {
                            const cs: *const CStr = @ptrFromInt(a3);
                            break :blk cs.toSlice();
                        }
                        break :blk "";
                    };
                    tray_handlers[a0 - 1](a1, tray_kind, menu_id, tray_handler_userdata[a0 - 1]);
                    return 0;
                },
                .notification => {
                    if (a0 == 0 or a0 > notif_count) return 0;
                    const notif_kind: u8 = @intCast(a1);
                    const id: []const u8 = if (a2 != 0) blk: {
                        const cs: *const CStr = @ptrFromInt(a2);
                        break :blk cs.toSlice();
                    } else "";
                    notif_handlers[a0 - 1](notif_kind, id, notif_handler_userdata[a0 - 1]);
                    return 0;
                },
                .hotkey => {
                    if (a0 == 0 or a0 > hotkey_count) return 0;
                    hotkey_handlers[a0 - 1](hotkey_handler_userdata[a0 - 1]);
                    return 0;
                },
                .theme => {
                    if (a0 == 0 or a0 > theme_count) return 0;
                    theme_handlers[a0 - 1](theme_handler_userdata[a0 - 1]);
                    return 0;
                },
                .power => {
                    if (a0 == 0 or a0 > power_count) return 0;
                    const ev: []const u8 = if (a1 != 0) blk: {
                        const cs: *const CStr = @ptrFromInt(a1);
                        break :blk cs.toSlice();
                    } else "";
                    power_handlers[a0 - 1](ev, power_handler_userdata[a0 - 1]);
                    return 0;
                },
                .app => {
                    if (a0 == 0 or a0 > app_count) return 0;
                    const app_kind: u8 = @intCast(a1);
                    return @intCast(app_handlers[a0 - 1](app_kind, a2, a3, app_handler_userdata[a0 - 1]));
                },
                .protocol => {
                    if (a0 == 0 or a0 > protocol_count) return 0;
                    const req_id = a1;
                    const creq: *const extern struct {
                        method_ptr: usize = 0,
                        method_len: usize = 0,
                        url_ptr: usize = 0,
                        url_len: usize = 0,
                        headers_ptr: usize = 0,
                        headers_len: usize = 0,
                    } = @ptrFromInt(a2);
                    const req = ProtocolRequest{
                        .method = if (creq.method_ptr != 0 and creq.method_len != 0)
                            @as([*]const u8, @ptrFromInt(creq.method_ptr))[0..creq.method_len]
                        else
                            "",
                        .url = if (creq.url_ptr != 0 and creq.url_len != 0)
                            @as([*]const u8, @ptrFromInt(creq.url_ptr))[0..creq.url_len]
                        else
                            "",
                        .headers_json = if (creq.headers_ptr != 0 and creq.headers_len != 0)
                            @as([*]const u8, @ptrFromInt(creq.headers_ptr))[0..creq.headers_len]
                        else
                            "{}",
                    };
                    protocol_handlers[a0 - 1](req_id, req, protocol_handler_userdata[a0 - 1]);
                    return 0;
                },
                .auth => {
                    if (a0 == 0 or a0 > auth_count) return 0;
                    const win_id: i32 = @intCast(@as(isize, @bitCast(a1)));
                    const creq: *const extern struct {
                        host_ptr: usize = 0,
                        host_len: usize = 0,
                        port: i32 = 0,
                        _pad: [4]u8 = @splat(0),
                        realm_ptr: usize = 0,
                        realm_len: usize = 0,
                        scheme_ptr: usize = 0,
                        scheme_len: usize = 0,
                        is_proxy: u8 = 0,
                        _pad2: [7]u8 = @splat(0),
                    } = @ptrFromInt(a2);
                    const req = AuthRequest{
                        .host = if (creq.host_ptr != 0 and creq.host_len != 0) @as([*]const u8, @ptrFromInt(creq.host_ptr))[0..creq.host_len] else "",
                        .port = creq.port,
                        .realm = if (creq.realm_ptr != 0 and creq.realm_len != 0) @as([*]const u8, @ptrFromInt(creq.realm_ptr))[0..creq.realm_len] else "",
                        .scheme = if (creq.scheme_ptr != 0 and creq.scheme_len != 0) @as([*]const u8, @ptrFromInt(creq.scheme_ptr))[0..creq.scheme_len] else "",
                        .is_proxy = creq.is_proxy != 0,
                    };
                    auth_handlers[a0 - 1](win_id, a3, req, auth_handler_userdata[a0 - 1]);
                    return 0;
                },
                .cert => {
                    if (a0 == 0 or a0 > cert_count) return 0;
                    const win_id: i32 = @intCast(@as(isize, @bitCast(a1)));
                    const creq: *const extern struct {
                        url_ptr: usize = 0,
                        url_len: usize = 0,
                        host_ptr: usize = 0,
                        host_len: usize = 0,
                        error_ptr: usize = 0,
                        error_len: usize = 0,
                        cert_ptr: usize = 0,
                        cert_len: usize = 0,
                    } = @ptrFromInt(a2);
                    const err = CertificateError{
                        .url = if (creq.url_ptr != 0 and creq.url_len != 0) @as([*]const u8, @ptrFromInt(creq.url_ptr))[0..creq.url_len] else "",
                        .host = if (creq.host_ptr != 0 and creq.host_len != 0) @as([*]const u8, @ptrFromInt(creq.host_ptr))[0..creq.host_len] else "",
                        .err = if (creq.error_ptr != 0 and creq.error_len != 0) @as([*]const u8, @ptrFromInt(creq.error_ptr))[0..creq.error_len] else "",
                        .certificate = if (creq.cert_ptr != 0 and creq.cert_len != 0) @as([*]const u8, @ptrFromInt(creq.cert_ptr))[0..creq.cert_len] else "",
                    };
                    return if (cert_handlers[a0 - 1](win_id, err, cert_handler_userdata[a0 - 1])) 1 else 0;
                },
                .download => {
                    if (a0 == 0 or a0 > download_count) return 0;
                    const win_id: i32 = @intCast(@as(isize, @bitCast(a1)));
                    const dl_kind: u8 = @intCast(a2);
                    const creq: *const extern struct {
                        req_id: usize = 0,
                        url_ptr: usize = 0,
                        url_len: usize = 0,
                        suggested_ptr: usize = 0,
                        suggested_len: usize = 0,
                        path_ptr: usize = 0,
                        path_len: usize = 0,
                        err_ptr: usize = 0,
                        err_len: usize = 0,
                    } = @ptrFromInt(a3);
                    const ev = DownloadEvent{
                        .req_id = creq.req_id,
                        .url = if (creq.url_ptr != 0 and creq.url_len != 0) @as([*]const u8, @ptrFromInt(creq.url_ptr))[0..creq.url_len] else "",
                        .suggested = if (creq.suggested_ptr != 0 and creq.suggested_len != 0) @as([*]const u8, @ptrFromInt(creq.suggested_ptr))[0..creq.suggested_len] else "",
                        .path = if (creq.path_ptr != 0 and creq.path_len != 0) @as([*]const u8, @ptrFromInt(creq.path_ptr))[0..creq.path_len] else "",
                        .err = if (creq.err_ptr != 0 and creq.err_len != 0) @as([*]const u8, @ptrFromInt(creq.err_ptr))[0..creq.err_len] else "",
                    };
                    download_handlers[a0 - 1](win_id, dl_kind, ev, download_handler_userdata[a0 - 1]);
                    return 0;
                },
                .page => {
                    if (a0 == 0 or a0 > page_count) return 0;
                    const win_id: i32 = @intCast(@as(isize, @bitCast(a1)));
                    const page_kind: u8 = @intCast(a2);
                    var ev = PageEvent{};
                    if (a3 != 0) {
                        const creq: *const extern struct {
                            req_id: usize = 0,
                            url_ptr: usize = 0,
                            url_len: usize = 0,
                            desc_ptr: usize = 0,
                            desc_len: usize = 0,
                            code: i32 = 0,
                            user_initiated: u8 = 0,
                            _pad: [3]u8 = @splat(0),
                        } = @ptrFromInt(a3);
                        ev = PageEvent{
                            .req_id = creq.req_id,
                            .url = if (creq.url_ptr != 0 and creq.url_len != 0) @as([*]const u8, @ptrFromInt(creq.url_ptr))[0..creq.url_len] else "",
                            .description = if (creq.desc_ptr != 0 and creq.desc_len != 0) @as([*]const u8, @ptrFromInt(creq.desc_ptr))[0..creq.desc_len] else "",
                            .code = creq.code,
                            .user_initiated = creq.user_initiated != 0,
                        };
                    }
                    page_handlers[a0 - 1](win_id, page_kind, ev, page_handler_userdata[a0 - 1]);
                    return 0;
                },
                .permission => {
                    if (a0 == 0 or a0 > permission_count) return 0;
                    const win_id: i32 = @intCast(@as(isize, @bitCast(a1)));
                    const creq: *const extern struct {
                        origin_ptr: usize = 0,
                        origin_len: usize = 0,
                        perms_ptr: usize = 0,
                        perms_len: usize = 0,
                    } = @ptrFromInt(a2);
                    const req = PermissionRequest{
                        .origin = if (creq.origin_ptr != 0 and creq.origin_len != 0) @as([*]const u8, @ptrFromInt(creq.origin_ptr))[0..creq.origin_len] else "",
                        .permissions_json = if (creq.perms_ptr != 0 and creq.perms_len != 0) @as([*]const u8, @ptrFromInt(creq.perms_ptr))[0..creq.perms_len] else "[]",
                    };
                    return if (permission_handlers[a0 - 1](win_id, req, permission_handler_userdata[a0 - 1])) 1 else 0;
                },
                .window_open => {
                    if (a0 == 0 or a0 > window_open_count) return 0;
                    const win_id: i32 = @intCast(@as(isize, @bitCast(a1)));
                    const creq: *const extern struct {
                        url_ptr: usize = 0,
                        url_len: usize = 0,
                        frame_ptr: usize = 0,
                        frame_len: usize = 0,
                        width: i32 = 0,
                        height: i32 = 0,
                        user_initiated: u8 = 0,
                        _pad: [3]u8 = @splat(0),
                    } = @ptrFromInt(a2);
                    const req = WindowOpenRequest{
                        .url = if (creq.url_ptr != 0 and creq.url_len != 0) @as([*]const u8, @ptrFromInt(creq.url_ptr))[0..creq.url_len] else "",
                        .frame_name = if (creq.frame_ptr != 0 and creq.frame_len != 0) @as([*]const u8, @ptrFromInt(creq.frame_ptr))[0..creq.frame_len] else "",
                        .width = creq.width,
                        .height = creq.height,
                        .user_initiated = creq.user_initiated != 0,
                    };
                    window_open_handlers[a0 - 1](win_id, a3, req, window_open_handler_userdata[a0 - 1]);
                    return 0;
                },
                .context_menu => {
                    if (a0 == 0 or a0 > context_menu_count) return 0;
                    const win_id: i32 = @intCast(@as(isize, @bitCast(a1)));
                    const creq: *const extern struct {
                        link_url_ptr: usize = 0,
                        link_url_len: usize = 0,
                        link_text_ptr: usize = 0,
                        link_text_len: usize = 0,
                        image_url_ptr: usize = 0,
                        image_url_len: usize = 0,
                        media_url_ptr: usize = 0,
                        media_url_len: usize = 0,
                        selection_ptr: usize = 0,
                        selection_len: usize = 0,
                        frame_url_ptr: usize = 0,
                        frame_url_len: usize = 0,
                        editable: u8 = 0,
                        _pad: [7]u8 = @splat(0),
                        menu_ptr: usize = 0,
                        menu_len: usize = 0,
                    } = @ptrFromInt(a2);
                    const ev = ContextMenuEvent{
                        .req_id = a3,
                        .link_url = if (creq.link_url_ptr != 0 and creq.link_url_len != 0) @as([*]const u8, @ptrFromInt(creq.link_url_ptr))[0..creq.link_url_len] else "",
                        .link_text = if (creq.link_text_ptr != 0 and creq.link_text_len != 0) @as([*]const u8, @ptrFromInt(creq.link_text_ptr))[0..creq.link_text_len] else "",
                        .image_url = if (creq.image_url_ptr != 0 and creq.image_url_len != 0) @as([*]const u8, @ptrFromInt(creq.image_url_ptr))[0..creq.image_url_len] else "",
                        .media_url = if (creq.media_url_ptr != 0 and creq.media_url_len != 0) @as([*]const u8, @ptrFromInt(creq.media_url_ptr))[0..creq.media_url_len] else "",
                        .selection = if (creq.selection_ptr != 0 and creq.selection_len != 0) @as([*]const u8, @ptrFromInt(creq.selection_ptr))[0..creq.selection_len] else "",
                        .frame_url = if (creq.frame_url_ptr != 0 and creq.frame_url_len != 0) @as([*]const u8, @ptrFromInt(creq.frame_url_ptr))[0..creq.frame_url_len] else "",
                        .editable = creq.editable != 0,
                        .menu_json = if (creq.menu_ptr != 0 and creq.menu_len != 0) @as([*]const u8, @ptrFromInt(creq.menu_ptr))[0..creq.menu_len] else "[]",
                    };
                    context_menu_handlers[a0 - 1](win_id, ev, context_menu_handler_userdata[a0 - 1]);
                    return 0;
                },
                .page_media => {
                    if (a0 == 0 or a0 > page_media_count) return 0;
                    const win_id: i32 = @intCast(@as(isize, @bitCast(a1)));
                    const media_kind: u8 = @intCast(a2);
                    page_media_handlers[a0 - 1](win_id, media_kind, a3, page_media_handler_userdata[a0 - 1]);
                    return 0;
                },
                .locale => {
                    if (a0 == 0 or a0 > locale_count) return 0;
                    const loc = if (a1 != 0) blk: {
                        const cs: *const CStr = @ptrFromInt(a1);
                        break :blk cs.toSlice();
                    } else "";
                    locale_handlers[a0 - 1](loc, locale_handler_userdata[a0 - 1]);
                    return 0;
                },
                .region => {
                    if (a0 == 0 or a0 > region_count) return 0;
                    const json = if (a1 != 0) blk: {
                        const cs: *const CStr = @ptrFromInt(a1);
                        break :blk cs.toSlice();
                    } else "{}";
                    region_handlers[a0 - 1](json, region_handler_userdata[a0 - 1]);
                    return 0;
                },
                .terminal => {
                    if (a0 == 0 or a0 > terminal_count) return 0;
                    terminal_handlers[a0 - 1](a1, @truncate(a2), a3, terminal_handler_userdata[a0 - 1]);
                    return 0;
                },
                .watch => {
                    if (a0 == 0 or a0 > watch_count) return 0;
                    watch_handlers[a0 - 1](a1, @truncate(a2), a3, watch_handler_userdata[a0 - 1]);
                    return 0;
                },
                .perm_flow => {
                    if (a0 == 0 or a0 > perm_count) return 0;
                    const err_msg = if (a3 != 0) blk: {
                        const cs: *const CStr = @ptrFromInt(a3);
                        break :blk cs.toSlice();
                    } else "";
                    perm_handlers[a0 - 1](a1, @truncate(a2), err_msg, perm_handler_userdata[a0 - 1]);
                    return 0;
                },
                .websocket => {
                    if (a0 == 0 or a0 > ws_count) return 0;
                    ws_handlers[a0 - 1](a1, @truncate(a2), a3, ws_handler_userdata[a0 - 1]);
                    return 0;
                },
                .game_update => {
                    if (a0 == 0 or a0 > game_update_count) return 0;
                    const inp: *const GameInput = @ptrFromInt(a1);
                    game_update_handlers[a0 - 1](inp, game_update_ud[a0 - 1]);
                    return 0;
                },
                .game_draw => {
                    if (a0 == 0 or a0 > game_draw_count) return 0;
                    const info: *const GameDrawInfo = @ptrFromInt(a2);
                    game_draw_handlers[a0 - 1](a1, info, game_draw_ud[a0 - 1]);
                    return 0;
                },
                .documents => {
                    if (a0 == 0 or a0 > doc_count) return 0;
                    return @intCast(doc_handlers[a0 - 1](a1, @truncate(a2), a3, doc_handler_ud[a0 - 1]));
                },
                .network => {
                    if (a0 == 0 or a0 > network_count) return 0;
                    const payload = if (a1 != 0) blk: {
                        const cs: *const CStr = @ptrFromInt(a1);
                        break :blk cs.toSlice();
                    } else "";
                    network_handlers[a0 - 1](payload, network_handler_ud[a0 - 1]);
                    return 0;
                },
                .now_playing => {
                    if (a0 == 0 or a0 > nowplaying_count) return 0;
                    nowplaying_handlers[a0 - 1](a1, a2, nowplaying_handler_ud[a0 - 1]);
                    return 0;
                },
            }
        }
    };
    @export(&Entry.mygo_zig_entry, .{ .name = "mygo_zig_entry", .linkage = .strong });
}

pub const Error = error{
    MyGoError,
    OutOfMemory,
};

pub const DevTools = enum(i32) {
    auto = 0,
    enabled = 1,
    disabled = 2,
};

pub const WindowEventKind = enum(usize) {
    close = 1,
    closed = 2,
    focus = 3,
    blur = 4,
    resize = 5,
    file_drop = 6,
    move = 7,
    show = 8,
    hide = 9,
    minimize = 10,
    restore = 11,
    maximize = 12,
    unmaximize = 13,
    enter_full_screen = 14,
    leave_full_screen = 15,
    ready_to_show = 16,
};

pub const Rectangle = struct {
    x: i32,
    y: i32,
    width: i32,
    height: i32,
};

pub const WindowOptions = struct {
    title: []const u8 = "",
    url: []const u8 = "",
    background_color: []const u8 = "",
    width: i32 = 800,
    height: i32 = 600,
    min_width: i32 = 0,
    min_height: i32 = 0,
    max_width: i32 = 0,
    max_height: i32 = 0,
    devtools: DevTools = .auto,
    use_content_size: bool = false,
    hidden: bool = false,
    frameless: bool = false,
    disable_resize: bool = false,
    always_on_top: bool = false,
    transparent: bool = false,
    vibrancy: []const u8 = "",
    vibrancy_tint: []const u8 = "",
    /// "", "default", "hidden", "hiddenInset".
    title_bar_style: []const u8 = "",
    title_bar_height: i32 = 0,
    /// Named persistent session (NewSession); empty = default.
    session_name: []const u8 = "",
    /// Remembers position/size/maximized across launches (WindowOptions.StateKey).
    state_key: []const u8 = "",
    /// Brings back a page as Window.sessionState saved it.
    session_state: []const u8 = "",

    pub fn toC(self: WindowOptions) CWindowOptions {
        return .{
            .title = CStr.fromSlice(self.title),
            .url = CStr.fromSlice(self.url),
            .background_color = CStr.fromSlice(self.background_color),
            .width = self.width,
            .height = self.height,
            .min_width = self.min_width,
            .min_height = self.min_height,
            .max_width = self.max_width,
            .max_height = self.max_height,
            .devtools = @intFromEnum(self.devtools),
            .use_content_size = @intFromBool(self.use_content_size),
            .hidden = @intFromBool(self.hidden),
            .frameless = @intFromBool(self.frameless),
            .disable_resize = @intFromBool(self.disable_resize),
            .always_on_top = @intFromBool(self.always_on_top),
            .transparent = @intFromBool(self.transparent),
            .vibrancy = CStr.fromSlice(self.vibrancy),
            .vibrancy_tint = CStr.fromSlice(self.vibrancy_tint),
            .title_bar_style = CStr.fromSlice(self.title_bar_style),
            .title_bar_height = self.title_bar_height,
            .session_name = CStr.fromSlice(self.session_name),
            .state_key = CStr.fromSlice(self.state_key),
            .session_state_ptr = sliceAddr(self.session_state),
            .session_state_len = self.session_state.len,
        };
    }
};

pub const Window = struct {
    id: i32,

    fn ctl(self: Window, sub: WinCtl, a2: usize, a3: usize) usize {
        return dispatch(.window_control, @intCast(self.id), @intFromEnum(sub), a2, a3);
    }

    pub fn setTitle(self: Window, title: []const u8) void {
        _ = self.ctl(.set_title, sliceAddr(title), title.len);
    }

    pub fn show(self: Window) void {
        _ = self.ctl(.show, 0, 0);
    }

    pub fn hide(self: Window) void {
        _ = self.ctl(.hide, 0, 0);
    }

    pub fn close(self: Window) void {
        _ = self.ctl(.close, 0, 0);
    }

    pub fn center(self: Window) void {
        _ = self.ctl(.center, 0, 0);
    }

    pub fn minimize(self: Window) void {
        _ = self.ctl(.minimize, 0, 0);
    }

    pub fn maximize(self: Window) void {
        _ = self.ctl(.maximize, 0, 0);
    }

    pub fn unmaximize(self: Window) void {
        _ = self.ctl(.unmaximize, 0, 0);
    }

    pub fn setFullscreen(self: Window, full: bool) void {
        _ = self.ctl(.set_fullscreen, @intFromBool(full), 0);
    }

    pub fn bounds(self: Window) Error!Rectangle {
        var b: CBounds = .{};
        if (self.ctl(.get_bounds, @intFromPtr(&b), 0) != 0) return Error.MyGoError;
        return .{ .x = b.x, .y = b.y, .width = b.width, .height = b.height };
    }

    pub fn setBounds(self: Window, r: Rectangle) void {
        var b = CBounds{ .x = r.x, .y = r.y, .width = r.width, .height = r.height };
        _ = self.ctl(.set_bounds, @intFromPtr(&b), 0);
    }

    /// Limit mouse hit-testing to `rects` (DIPs). Pass `null` to restore the
    /// full window; pass an empty slice to take no mouse events.
    pub fn setInputRegion(self: Window, rects: ?[]const Rectangle) void {
        if (rects == null) {
            _ = self.ctl(.set_input_region, 0, std.math.maxInt(usize));
            return;
        }
        const rs = rects.?;
        var buf: [32]CBounds = undefined;
        const n = @min(rs.len, buf.len);
        for (rs[0..n], 0..) |r, i| {
            buf[i] = .{ .x = r.x, .y = r.y, .width = r.width, .height = r.height };
        }
        _ = self.ctl(.set_input_region, if (n > 0) @intFromPtr(&buf) else 0, n);
    }

    /// Re-anchor a flyout against another rectangle of its parent (DIPs).
    pub fn setAnchor(self: Window, r: Rectangle) void {
        var b = CBounds{ .x = r.x, .y = r.y, .width = r.width, .height = r.height };
        _ = self.ctl(.set_anchor, @intFromPtr(&b), 0);
    }

    /// Material behind transparent content, e.g. "sidebar", "glass", "mica".
    pub fn setVibrancy(self: Window, material: []const u8) void {
        _ = self.ctl(.set_vibrancy, sliceAddr(material), material.len);
    }

    /// Tint for Liquid Glass (macOS 26); empty clears. Syntax of background_color.
    pub fn setVibrancyTint(self: Window, color: []const u8) Error!void {
        if (self.ctl(.set_vibrancy_tint, sliceAddr(color), color.len) != 0) return Error.MyGoError;
    }

    /// Taskbar/Dock progress. State: "", "normal", "indeterminate", "paused", "error".
    pub fn setProgressBar(self: Window, state: []const u8, value: f64) void {
        const Spec = extern struct {
            state_ptr: usize = 0,
            state_len: usize = 0,
            value: f64 = 0,
        };
        var spec = Spec{
            .state_ptr = sliceAddr(state),
            .state_len = state.len,
            .value = value,
        };
        _ = self.ctl(.set_progress_bar, @intFromPtr(&spec), 0);
    }

    pub fn setContentProtection(self: Window, on: bool) void {
        _ = self.ctl(.set_content_protection, @intFromBool(on), 0);
    }

    /// Register HTTP auth handler. Must call `Window.authRespond` before returning.
    pub fn setAuthHandler(self: Window, comptime StatePtr: type, state: StatePtr, comptime handler: fn (StatePtr, usize, AuthRequest) void) void {
        const S = struct {
            fn onAuth(_: i32, req_id: usize, req: AuthRequest, ud: usize) void {
                const s: StatePtr = @ptrFromInt(ud);
                handler(s, req_id, req);
            }
        };
        const cb = registerAuthHandler(&S.onAuth, @intFromPtr(state));
        _ = self.ctl(.set_auth_handler, cb, 0);
    }

    pub fn clearAuthHandler(self: Window) void {
        _ = self.ctl(.set_auth_handler, 0, 0);
    }

    pub fn authRespond(self: Window, req_id: usize, username: []const u8, password: []const u8) void {
        const Spec = extern struct {
            req_id: usize = 0,
            user_ptr: usize = 0,
            user_len: usize = 0,
            pass_ptr: usize = 0,
            pass_len: usize = 0,
        };
        var spec = Spec{
            .req_id = req_id,
            .user_ptr = sliceAddr(username),
            .user_len = username.len,
            .pass_ptr = sliceAddr(password),
            .pass_len = password.len,
        };
        _ = self.ctl(.auth_respond, @intFromPtr(&spec), 0);
    }

    /// Certificate error handler; return true to allow the load.
    pub fn setCertificateErrorHandler(self: Window, comptime StatePtr: type, state: StatePtr, comptime handler: fn (StatePtr, CertificateError) bool) void {
        const S = struct {
            fn onCert(_: i32, err: CertificateError, ud: usize) bool {
                const s: StatePtr = @ptrFromInt(ud);
                return handler(s, err);
            }
        };
        const cb = registerCertHandler(&S.onCert, @intFromPtr(state));
        _ = self.ctl(.set_cert_handler, cb, 0);
    }

    pub fn clearCertificateErrorHandler(self: Window) void {
        _ = self.ctl(.set_cert_handler, 0, 0);
    }

    /// kind 1 = will download (must call downloadRespond); kind 2 = done.
    pub fn onDownload(self: Window, comptime StatePtr: type, state: StatePtr, comptime handler: fn (StatePtr, u8, DownloadEvent) void) void {
        const S = struct {
            fn onDl(_: i32, kind: u8, ev: DownloadEvent, ud: usize) void {
                const s: StatePtr = @ptrFromInt(ud);
                handler(s, kind, ev);
            }
        };
        const cb = registerDownloadHandler(&S.onDl, @intFromPtr(state));
        _ = self.ctl(.on_download, cb, 0);
    }

    pub fn downloadRespond(self: Window, req_id: usize, prevent: bool, path: []const u8) void {
        const Spec = extern struct {
            req_id: usize = 0,
            prevent: u8 = 0,
            _pad: [7]u8 = @splat(0),
            path_ptr: usize = 0,
            path_len: usize = 0,
        };
        var spec = Spec{
            .req_id = req_id,
            .prevent = if (prevent) 1 else 0,
            .path_ptr = sliceAddr(path),
            .path_len = path.len,
        };
        _ = self.ctl(.download_respond, @intFromPtr(&spec), 0);
    }

    /// Page lifecycle: will/did navigate, DOM ready, finish/fail, render gone.
    /// For will_navigate (kind=1), call navigateRespond before returning.
    pub fn onPage(self: Window, comptime StatePtr: type, state: StatePtr, comptime handler: fn (StatePtr, u8, PageEvent) void) void {
        const S = struct {
            fn onPg(_: i32, kind: u8, ev: PageEvent, ud: usize) void {
                const s: StatePtr = @ptrFromInt(ud);
                handler(s, kind, ev);
            }
        };
        const cb = registerPageHandler(&S.onPg, @intFromPtr(state));
        _ = self.ctl(.on_page, cb, 0);
    }

    pub fn navigateRespond(self: Window, req_id: usize, prevent: bool) void {
        const Spec = extern struct {
            req_id: usize = 0,
            prevent: u8 = 0,
            _pad: [7]u8 = @splat(0),
        };
        var spec = Spec{
            .req_id = req_id,
            .prevent = if (prevent) 1 else 0,
        };
        _ = self.ctl(.navigate_respond, @intFromPtr(&spec), 0);
    }

    /// Return true to grant. Default (no handler) grants trusted pages only.
    pub fn setPermissionHandler(self: Window, comptime StatePtr: type, state: StatePtr, comptime handler: fn (StatePtr, PermissionRequest) bool) void {
        const S = struct {
            fn onPerm(_: i32, req: PermissionRequest, ud: usize) bool {
                const s: StatePtr = @ptrFromInt(ud);
                return handler(s, req);
            }
        };
        const cb = registerPermissionHandler(&S.onPerm, @intFromPtr(state));
        _ = self.ctl(.set_permission_handler, cb, 0);
    }

    pub fn clearPermissionHandler(self: Window) void {
        _ = self.ctl(.set_permission_handler, 0, 0);
    }

    /// Handler must call `windowOpenRespond` (or deny) before returning.
    pub fn setWindowOpenHandler(self: Window, comptime StatePtr: type, state: StatePtr, comptime handler: fn (StatePtr, usize, WindowOpenRequest) void) void {
        const S = struct {
            fn onOpen(_: i32, req_id: usize, req: WindowOpenRequest, ud: usize) void {
                const s: StatePtr = @ptrFromInt(ud);
                handler(s, req_id, req);
            }
        };
        const cb = registerWindowOpenHandler(&S.onOpen, @intFromPtr(state));
        _ = self.ctl(.set_window_open_handler, cb, 0);
    }

    pub fn clearWindowOpenHandler(self: Window) void {
        _ = self.ctl(.set_window_open_handler, 0, 0);
    }

    pub fn windowOpenRespond(self: Window, req_id: usize, deny: bool, opts: WindowOptions) void {
        const Spec = extern struct {
            req_id: usize = 0,
            deny: u8 = 0,
            _pad: [7]u8 = @splat(0),
            opts: CWindowOptions = .{},
        };
        var spec = Spec{
            .req_id = req_id,
            .deny = if (deny) 1 else 0,
            .opts = opts.toC(),
        };
        _ = self.ctl(.window_open_respond, @intFromPtr(&spec), 0);
    }

    pub const FindResult = struct { matches: u32 = 0, active: u32 = 0 };

    pub fn findInPage(self: Window, text: []const u8, opts: struct { match_case: bool = false, backward: bool = false, find_next: bool = false }) Error!FindResult {
        const Spec = extern struct {
            text_ptr: usize = 0,
            text_len: usize = 0,
            match_case: u8 = 0,
            backward: u8 = 0,
            find_next: u8 = 0,
            _pad: [5]u8 = @splat(0),
        };
        var spec = Spec{
            .text_ptr = sliceAddr(text),
            .text_len = text.len,
            .match_case = if (opts.match_case) 1 else 0,
            .backward = if (opts.backward) 1 else 0,
            .find_next = if (opts.find_next) 1 else 0,
        };
        const packed_res = self.ctl(.find_in_page, @intFromPtr(&spec), 0);
        if (packed_res == std.math.maxInt(usize)) return Error.MyGoError;
        return .{
            .matches = @intCast(packed_res >> 32),
            .active = @intCast(packed_res & 0xffff_ffff),
        };
    }

    pub fn stopFindInPage(self: Window) void {
        _ = self.ctl(.stop_find_in_page, 0, 0);
    }

    pub fn reload(self: Window) void {
        _ = self.ctl(.reload, 0, 0);
    }

    pub fn goBack(self: Window) void {
        _ = self.ctl(.go_back, 0, 0);
    }

    pub fn goForward(self: Window) void {
        _ = self.ctl(.go_forward, 0, 0);
    }

    /// Evaluate JS; returns JSON-encoded result (caller frees).
    pub fn evalJSON(self: Window, allocator: std.mem.Allocator, code: []const u8) Error![]u8 {
        const Spec = extern struct {
            code_ptr: usize = 0,
            code_len: usize = 0,
            out_ptr: usize = 0,
            out_cap: usize = 0,
        };
        var scratch: [65536]u8 = undefined;
        var spec = Spec{
            .code_ptr = sliceAddr(code),
            .code_len = code.len,
            .out_ptr = @intFromPtr(&scratch),
            .out_cap = scratch.len,
        };
        const got = self.ctl(.eval, @intFromPtr(&spec), 0);
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        const n = @min(got, scratch.len);
        return try allocator.dupe(u8, scratch[0..n]);
    }

    /// Must call contextMenuRespond before returning.
    /// Empty menu_json keeps the default; non-empty replaces; prevent hides it.
    pub fn onContextMenu(self: Window, comptime StatePtr: type, state: StatePtr, comptime handler: fn (StatePtr, ContextMenuEvent) void) void {
        const S = struct {
            fn onCM(_: i32, ev: ContextMenuEvent, ud: usize) void {
                const s: StatePtr = @ptrFromInt(ud);
                handler(s, ev);
            }
        };
        const cb = registerContextMenuHandler(&S.onCM, @intFromPtr(state));
        _ = self.ctl(.on_context_menu, cb, 0);
    }

    pub fn contextMenuRespond(self: Window, req_id: usize, prevent: bool, menu_json: []const u8) void {
        const Spec = extern struct {
            req_id: usize = 0,
            prevent: u8 = 0,
            _pad: [7]u8 = @splat(0),
            menu_ptr: usize = 0,
            menu_len: usize = 0,
        };
        var spec = Spec{
            .req_id = req_id,
            .prevent = if (prevent) 1 else 0,
            .menu_ptr = sliceAddr(menu_json),
            .menu_len = menu_json.len,
        };
        _ = self.ctl(.context_menu_respond, @intFromPtr(&spec), 0);
    }

    pub fn setContentRulesJSON(self: Window, ids_json: []const u8) Error!void {
        if (self.ctl(.set_content_rules, sliceAddr(ids_json), ids_json.len) == std.math.maxInt(usize)) return Error.MyGoError;
    }

    pub fn setAudioMuted(self: Window, muted: bool) void {
        _ = self.ctl(.set_audio_muted, @intFromBool(muted), 0);
    }

    pub fn isAudioMuted(self: Window) bool {
        return self.ctl(.is_audio_muted, 0, 0) != 0;
    }

    pub fn isAudible(self: Window) bool {
        return self.ctl(.is_audible, 0, 0) != 0;
    }

    /// kind 1 = audible (payload 0/1); kind 2 = capture ((kind<<16)|state).
    pub fn onPageMedia(self: Window, comptime StatePtr: type, state: StatePtr, comptime handler: fn (StatePtr, u8, usize) void) void {
        const S = struct {
            fn onMedia(_: i32, kind: u8, payload: usize, ud: usize) void {
                const s: StatePtr = @ptrFromInt(ud);
                handler(s, kind, payload);
            }
        };
        const cb = registerPageMediaHandler(&S.onMedia, @intFromPtr(state));
        _ = self.ctl(.on_page_media, cb, 0);
    }

    pub fn captureState(self: Window, kind: usize) usize {
        return self.ctl(.capture_state, kind, 0);
    }

    pub fn setCaptureState(self: Window, kind: usize, state: usize) void {
        _ = self.ctl(.set_capture_state, kind, state);
    }

    pub fn togglePictureInPicture(self: Window) void {
        _ = self.ctl(.toggle_pip, 0, 0);
    }

    pub fn isPictureInPictureActive(self: Window) bool {
        return self.ctl(.is_pip_active, 0, 0) != 0;
    }

    pub fn setZoomFactor(self: Window, factor: f64) void {
        _ = self.ctl(.set_zoom, @bitCast(factor), 0);
    }

    pub fn zoomFactor(self: Window) f64 {
        return @bitCast(self.ctl(.get_zoom, 0, 0));
    }

    pub fn setUserAgent(self: Window, ua: []const u8) void {
        _ = self.ctl(.set_user_agent, sliceAddr(ua), ua.len);
    }

    pub fn userAgent(self: Window, allocator: std.mem.Allocator) Error![]u8 {
        var scratch: [1024]u8 = undefined;
        const got = self.ctl(.get_user_agent, @intFromPtr(&scratch), scratch.len);
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        const n = @min(got, scratch.len);
        return try allocator.dupe(u8, scratch[0..n]);
    }

    pub fn openDevTools(self: Window) void {
        _ = self.ctl(.open_devtools, 0, 0);
    }

    pub fn closeDevTools(self: Window) void {
        _ = self.ctl(.close_devtools, 0, 0);
    }

    pub fn isDevToolsOpened(self: Window) bool {
        return self.ctl(.is_devtools_opened, 0, 0) != 0;
    }

    pub fn toggleDevTools(self: Window) void {
        _ = self.ctl(.toggle_devtools, 0, 0);
    }

    pub fn print(self: Window) void {
        _ = self.ctl(.print, 0, 0);
    }

    pub fn pageURL(self: Window, allocator: std.mem.Allocator) Error![]u8 {
        var scratch: [4096]u8 = undefined;
        const got = self.ctl(.url, @intFromPtr(&scratch), scratch.len);
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        const n = @min(got, scratch.len);
        return try allocator.dupe(u8, scratch[0..n]);
    }

    pub fn isLoading(self: Window) bool {
        return self.ctl(.is_loading, 0, 0) != 0;
    }

    /// PNG screenshot of the visible page/content (caller frees).
    /// Saves the page's session state into buf (its back/forward list and
    /// form fields). Returns the bytes written.
    pub fn sessionState(self: Window, buf: []u8) Error![]u8 {
        const got = dispatch(.window_control, self.id, @intFromEnum(WinCtl.session_state), @intFromPtr(buf.ptr), buf.len);
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        return buf[0..@min(got, buf.len)];
    }

    pub fn capturePagePNG(self: Window, allocator: std.mem.Allocator) Error![]u8 {
        var scratch: [8 * 1024 * 1024]u8 = undefined;
        const got = self.ctl(.capture_page, @intFromPtr(&scratch), scratch.len);
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        const n = @min(got, scratch.len);
        return try allocator.dupe(u8, scratch[0..n]);
    }

    pub const PDFOptions = struct {
        page_width: f64 = 0,
        page_height: f64 = 0,
        landscape: bool = false,
        background: bool = false,
        margins: ?struct { top: f64 = 0.4, right: f64 = 0.4, bottom: f64 = 0.4, left: f64 = 0.4 } = null,
    };

    /// PDF bytes (caller frees). Zero page size uses Letter.
    pub fn printToPDF(self: Window, allocator: std.mem.Allocator, opts: PDFOptions) Error![]u8 {
        const Spec = extern struct {
            out_ptr: usize = 0,
            out_cap: usize = 0,
            page_width: f64 = 0,
            page_height: f64 = 0,
            margins_top: f64 = 0,
            margins_right: f64 = 0,
            margins_bottom: f64 = 0,
            margins_left: f64 = 0,
            landscape: u8 = 0,
            background: u8 = 0,
            has_margins: u8 = 0,
            _pad: [5]u8 = @splat(0),
        };
        var scratch: [16 * 1024 * 1024]u8 = undefined;
        var spec = Spec{
            .out_ptr = @intFromPtr(&scratch),
            .out_cap = scratch.len,
            .page_width = opts.page_width,
            .page_height = opts.page_height,
            .landscape = if (opts.landscape) 1 else 0,
            .background = if (opts.background) 1 else 0,
        };
        if (opts.margins) |m| {
            spec.has_margins = 1;
            spec.margins_top = m.top;
            spec.margins_right = m.right;
            spec.margins_bottom = m.bottom;
            spec.margins_left = m.left;
        }
        const got = self.ctl(.print_to_pdf, @intFromPtr(&spec), 0);
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        const n = @min(got, scratch.len);
        return try allocator.dupe(u8, scratch[0..n]);
    }

    pub fn invalidate(self: Window) void {
        _ = self.ctl(.invalidate, 0, 0);
    }


    pub fn setMinSize(self: Window, w: i32, h: i32) void { _ = self.ctl(.set_min_size, @intCast(w), @intCast(h)); }
    pub fn setMaxSize(self: Window, w: i32, h: i32) void { _ = self.ctl(.set_max_size, @intCast(w), @intCast(h)); }
    pub fn setSize(self: Window, w: i32, h: i32) void { _ = self.ctl(.set_size, @intCast(w), @intCast(h)); }
    pub fn setPosition(self: Window, x: i32, y: i32) void { _ = self.ctl(.set_position, @intCast(x), @intCast(y)); }
    pub fn setResizable(self: Window, v: bool) void { _ = self.ctl(.set_resizable, @intFromBool(v), 0); }
    pub fn isResizable(self: Window) bool { return self.ctl(.is_resizable, 0, 0) != 0; }
    pub fn setClosable(self: Window, v: bool) void { _ = self.ctl(.set_closable, @intFromBool(v), 0); }
    pub fn isClosable(self: Window) bool { return self.ctl(.is_closable, 0, 0) != 0; }
    pub fn setMaximizable(self: Window, v: bool) void { _ = self.ctl(.set_maximizable, @intFromBool(v), 0); }
    pub fn isMaximizable(self: Window) bool { return self.ctl(.is_maximizable, 0, 0) != 0; }
    pub fn setMinimizable(self: Window, v: bool) void { _ = self.ctl(.set_minimizable, @intFromBool(v), 0); }
    pub fn isMinimizable(self: Window) bool { return self.ctl(.is_minimizable, 0, 0) != 0; }
    pub fn setMovable(self: Window, v: bool) void { _ = self.ctl(.set_movable, @intFromBool(v), 0); }
    pub fn isMovable(self: Window) bool { return self.ctl(.is_movable, 0, 0) != 0; }
    pub fn setAlwaysOnTop(self: Window, v: bool) void { _ = self.ctl(.set_always_on_top, @intFromBool(v), 0); }
    pub fn isAlwaysOnTop(self: Window) bool { return self.ctl(.is_always_on_top, 0, 0) != 0; }
    pub fn setHasShadow(self: Window, v: bool) void { _ = self.ctl(.set_has_shadow, @intFromBool(v), 0); }
    pub fn hasShadow(self: Window) bool { return self.ctl(.has_shadow, 0, 0) != 0; }
    pub fn setOpacity(self: Window, v: f64) void { _ = self.ctl(.set_opacity, @bitCast(v), 0); }
    pub fn opacity(self: Window) f64 { return @bitCast(self.ctl(.get_opacity, 0, 0)); }
    pub fn setBackgroundColor(self: Window, color: []const u8) Error!void {
        if (self.ctl(.set_background_color, sliceAddr(color), color.len) == std.math.maxInt(usize)) return Error.MyGoError;
    }
    pub fn setIgnoreMouseEvents(self: Window, v: bool) void { _ = self.ctl(.set_ignore_mouse_events, @intFromBool(v), 0); }
    pub fn flashFrame(self: Window, flash: bool) void { _ = self.ctl(.flash_frame, @intFromBool(flash), 0); }
    pub fn setDocumentEdited(self: Window, edited: bool) void { _ = self.ctl(.set_document_edited, @intFromBool(edited), 0); }
    pub fn isDocumentEdited(self: Window) bool { return self.ctl(.is_document_edited, 0, 0) != 0; }
    pub fn setRepresentedFile(self: Window, path: []const u8) void { _ = self.ctl(.set_represented_file, sliceAddr(path), path.len); }
    pub fn representedFile(self: Window, allocator: std.mem.Allocator) Error![]u8 {
        var scratch: [4096]u8 = undefined;
        const got = self.ctl(.get_represented_file, @intFromPtr(&scratch), scratch.len);
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        return try allocator.dupe(u8, scratch[0..@min(got, scratch.len)]);
    }
    pub fn isVisible(self: Window) bool { return self.ctl(.is_visible, 0, 0) != 0; }
    pub fn isFocused(self: Window) bool { return self.ctl(.is_focused, 0, 0) != 0; }
    pub fn isMinimized(self: Window) bool { return self.ctl(.is_minimized, 0, 0) != 0; }
    pub fn isMaximized(self: Window) bool { return self.ctl(.is_maximized, 0, 0) != 0; }
    pub fn isFullScreen(self: Window) bool { return self.ctl(.is_full_screen, 0, 0) != 0; }
    pub fn isDestroyed(self: Window) bool { return self.ctl(.is_destroyed, 0, 0) != 0; }
    pub fn blur(self: Window) void { _ = self.ctl(.blur, 0, 0); }
    pub fn restore(self: Window) void { _ = self.ctl(.restore, 0, 0); }
    pub fn showInactive(self: Window) void { _ = self.ctl(.show_inactive, 0, 0); }
    pub fn setIconPNG(self: Window, png: []const u8) Error!void {
        if (self.ctl(.set_icon, sliceAddr(png), png.len) == std.math.maxInt(usize)) return Error.MyGoError;
    }
    pub fn setSkipTaskbar(self: Window, v: bool) void { _ = self.ctl(.set_skip_taskbar, @intFromBool(v), 0); }
    pub fn setAutoHideMenuBar(self: Window, v: bool) void { _ = self.ctl(.set_auto_hide_menu_bar, @intFromBool(v), 0); }
    pub fn setActiveAppearance(self: Window, v: bool) void { _ = self.ctl(.set_active_appearance, @intFromBool(v), 0); }
    pub fn nativeHandle(self: Window) usize { return self.ctl(.native_handle, 0, 0); }

    pub fn stop(self: Window) void { _ = self.ctl(.stop, 0, 0); }
    pub fn reloadIgnoringCache(self: Window) void { _ = self.ctl(.reload_ignoring_cache, 0, 0); }
    pub fn loadFile(self: Window, path: []const u8) Error!void {
        if (self.ctl(.load_file, sliceAddr(path), path.len) == std.math.maxInt(usize)) return Error.MyGoError;
    }
    pub fn canGoBack(self: Window) bool { return self.ctl(.can_go_back, 0, 0) != 0; }
    pub fn canGoForward(self: Window) bool { return self.ctl(.can_go_forward, 0, 0) != 0; }
    pub fn processID(self: Window) usize { return self.ctl(.process_id, 0, 0); }
    pub fn gpuProcessID(self: Window) usize { return self.ctl(.gpu_process_id, 0, 0); }

    pub const ThemeColor = struct { r: u8 = 0, g: u8 = 0, b: u8 = 0, a: u8 = 0, ok: bool = false };
    pub fn themeColor(self: Window) ThemeColor {
        var out = extern struct { r: u8 = 0, g: u8 = 0, b: u8 = 0, a: u8 = 0, ok: u8 = 0, _pad: [3]u8 = @splat(0) }{};
        _ = self.ctl(.theme_color, @intFromPtr(&out), 0);
        return .{ .r = out.r, .g = out.g, .b = out.b, .a = out.a, .ok = out.ok != 0 };
    }

    /// For title_updated page events (kind=7); prevent=true keeps the previous window title.
    pub fn titleRespond(self: Window, req_id: usize, prevent: bool) void {
        const Spec = extern struct { req_id: usize = 0, prevent: u8 = 0, _pad: [7]u8 = @splat(0) };
        var spec = Spec{ .req_id = req_id, .prevent = if (prevent) 1 else 0 };
        _ = self.ctl(.title_respond, @intFromPtr(&spec), 0);
    }

    fn onWindowEvent(self: Window, kind: WindowEventKind, comptime handler: fn (Window, []const u8) void) Error!void {
        const T = struct {
            fn cb(win_id: i32, payload: []const u8) bool {
                handler(.{ .id = win_id }, payload);
                return false;
            }
        };
        win_handlers[win_count] = &T.cb;
        win_count += 1;
        if (dispatch(.window_on_event, @intCast(self.id), @intFromEnum(kind), win_count, 0) != 0) return Error.MyGoError;
    }

    pub fn onMove(self: Window, comptime handler: fn (Window, []const u8) void) Error!void { return self.onWindowEvent(.move, handler); }
    pub fn onShow(self: Window, comptime handler: fn (Window) void) Error!void {
        const S = struct { fn h(w: Window, _: []const u8) void { handler(w); } };
        return self.onWindowEvent(.show, S.h);
    }
    pub fn onHide(self: Window, comptime handler: fn (Window) void) Error!void {
        const S = struct { fn h(w: Window, _: []const u8) void { handler(w); } };
        return self.onWindowEvent(.hide, S.h);
    }
    pub fn onMinimize(self: Window, comptime handler: fn (Window) void) Error!void {
        const S = struct { fn h(w: Window, _: []const u8) void { handler(w); } };
        return self.onWindowEvent(.minimize, S.h);
    }
    pub fn onRestore(self: Window, comptime handler: fn (Window) void) Error!void {
        const S = struct { fn h(w: Window, _: []const u8) void { handler(w); } };
        return self.onWindowEvent(.restore, S.h);
    }
    pub fn onMaximize(self: Window, comptime handler: fn (Window) void) Error!void {
        const S = struct { fn h(w: Window, _: []const u8) void { handler(w); } };
        return self.onWindowEvent(.maximize, S.h);
    }
    pub fn onUnmaximize(self: Window, comptime handler: fn (Window) void) Error!void {
        const S = struct { fn h(w: Window, _: []const u8) void { handler(w); } };
        return self.onWindowEvent(.unmaximize, S.h);
    }
    pub fn onEnterFullScreen(self: Window, comptime handler: fn (Window) void) Error!void {
        const S = struct { fn h(w: Window, _: []const u8) void { handler(w); } };
        return self.onWindowEvent(.enter_full_screen, S.h);
    }
    pub fn onLeaveFullScreen(self: Window, comptime handler: fn (Window) void) Error!void {
        const S = struct { fn h(w: Window, _: []const u8) void { handler(w); } };
        return self.onWindowEvent(.leave_full_screen, S.h);
    }
    pub fn onReadyToShow(self: Window, comptime handler: fn (Window) void) Error!void {
        const S = struct { fn h(w: Window, _: []const u8) void { handler(w); } };
        return self.onWindowEvent(.ready_to_show, S.h);
    }
    pub fn onClose(self: Window, comptime handler: fn (Window) bool) Error!void {
        const T = struct {
            fn cb(win_id: i32, _: []const u8) bool {
                return handler(.{ .id = win_id });
            }
        };
        win_handlers[win_count] = &T.cb;
        win_count += 1;
        if (dispatch(.window_on_event, @intCast(self.id), @intFromEnum(WindowEventKind.close), win_count, 0) != 0) {
            return Error.MyGoError;
        }
    }

    pub fn loadUrl(self: Window, url: []const u8) Error!void {
        if (self.ctl(.load_url, sliceAddr(url), url.len) != 0) return Error.MyGoError;
    }

    pub fn loadHtml(self: Window, html: []const u8, base_url: []const u8) void {
        var spec = CHtmlSpec{
            .html = CStr.fromSlice(html),
            .base_url = CStr.fromSlice(base_url),
        };
        _ = self.ctl(.load_html, @intFromPtr(&spec), 0);
    }

    pub fn emit(self: Window, event: []const u8, payload: anytype) Error!void {
        try emitTarget(self.id, event, payload);
    }
};

pub const CallContext = struct {
    allocator: std.mem.Allocator,
    window: Window,
};


pub const DialogFlag = struct {
    pub const directory: u32 = 1;
    pub const multiple: u32 = 2;
    pub const show_hidden: u32 = 4;
    pub const create_dirs: u32 = 8;
    pub const packages: u32 = 16;
};

pub const MessageType = enum(u8) {
    none = 0,
    info = 1,
    warning = 2,
    @"error" = 3,
    question = 4,
};

pub const MessageResult = struct {
    button: i32 = 0,
    checkbox_checked: bool = false,
};

pub const FileFilter = struct {
    name: []const u8 = "",
    /// Comma-separated extensions, e.g. "png,jpg".
    extensions: []const u8 = "",
    /// Comma-separated MIME types, e.g. "image/*".
    mime_types: []const u8 = "",
};

fn packFileFilters(buf: []u8, filters: []const FileFilter) usize {
    if (filters.len == 0 or buf.len == 0) return 0;
    const n: u8 = @intCast(@min(filters.len, 16));
    var off: usize = 0;
    buf[off] = n;
    off += 1;
    for (filters[0..n]) |f| {
        if (off + 6 + f.name.len + f.extensions.len + f.mime_types.len > buf.len) break;
        std.mem.writeInt(u16, buf[off..][0..2], @intCast(f.name.len), .little);
        off += 2;
        @memcpy(buf[off .. off + f.name.len], f.name);
        off += f.name.len;
        std.mem.writeInt(u16, buf[off..][0..2], @intCast(f.extensions.len), .little);
        off += 2;
        @memcpy(buf[off .. off + f.extensions.len], f.extensions);
        off += f.extensions.len;
        std.mem.writeInt(u16, buf[off..][0..2], @intCast(f.mime_types.len), .little);
        off += 2;
        @memcpy(buf[off .. off + f.mime_types.len], f.mime_types);
        off += f.mime_types.len;
    }
    return off;
}

pub const Dialog = struct {
    const COpenSpec = extern struct {
        parent_win_id: usize = 0,
        title_ptr: usize = 0,
        title_len: usize = 0,
        default_path_ptr: usize = 0,
        default_path_len: usize = 0,
        button_label_ptr: usize = 0,
        button_label_len: usize = 0,
        message_ptr: usize = 0,
        message_len: usize = 0,
        filter_name_ptr: usize = 0,
        filter_name_len: usize = 0,
        filter_ext_ptr: usize = 0,
        filter_ext_len: usize = 0,
        filters_ptr: usize = 0,
        filters_len: usize = 0,
        flags: u32 = 0,
        _pad: [4]u8 = @splat(0),
    };

    const CSaveSpec = extern struct {
        parent_win_id: usize = 0,
        title_ptr: usize = 0,
        title_len: usize = 0,
        default_path_ptr: usize = 0,
        default_path_len: usize = 0,
        button_label_ptr: usize = 0,
        button_label_len: usize = 0,
        message_ptr: usize = 0,
        message_len: usize = 0,
        name_field_label_ptr: usize = 0,
        name_field_len: usize = 0,
        filter_name_ptr: usize = 0,
        filter_name_len: usize = 0,
        filter_ext_ptr: usize = 0,
        filter_ext_len: usize = 0,
        filters_ptr: usize = 0,
        filters_len: usize = 0,
        flags: u32 = 0,
        _pad: [4]u8 = @splat(0),
    };

    const CMessageSpec = extern struct {
        parent_win_id: usize = 0,
        type: u8 = 0,
        checkbox_checked: u8 = 0,
        _pad: [2]u8 = @splat(0),
        default_button: i32 = 0,
        cancel_button: i32 = 0,
        title_ptr: usize = 0,
        title_len: usize = 0,
        message_ptr: usize = 0,
        message_len: usize = 0,
        detail_ptr: usize = 0,
        detail_len: usize = 0,
        checkbox_label_ptr: usize = 0,
        checkbox_len: usize = 0,
        buttons_ptr: usize = 0,
        buttons_len: usize = 0,
        button_count: u32 = 0,
        _pad2: [4]u8 = @splat(0),
    };

    const CMessageResult = extern struct {
        button: i32 = 0,
        checkbox_checked: u8 = 0,
        _pad: [3]u8 = @splat(0),
    };

    /// Open a file/directory picker. Returns NUL-separated paths (empty on cancel).
    /// Caller owns the returned slice. Shows the dialog once.
    pub fn open(allocator: std.mem.Allocator, parent: ?Window, title: []const u8, default_path: []const u8, filters: []const FileFilter, flags: u32) Error![]u8 {
        var filter_buf: [4096]u8 = undefined;
        const filters_len = packFileFilters(&filter_buf, filters);
        var spec = COpenSpec{
            .parent_win_id = if (parent) |w| @intCast(w.id) else 0,
            .title_ptr = sliceAddr(title),
            .title_len = title.len,
            .default_path_ptr = sliceAddr(default_path),
            .default_path_len = default_path.len,
            .filters_ptr = if (filters_len > 0) @intFromPtr(&filter_buf) else 0,
            .filters_len = filters_len,
            .flags = flags,
        };
        var scratch: [65536]u8 = undefined;
        const got = dispatch(.dialog, 1, @intFromPtr(&spec), @intFromPtr(&scratch), scratch.len);
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        if (got == 0) return try allocator.dupe(u8, "");
        const n = @min(got, scratch.len);
        return try allocator.dupe(u8, scratch[0..n]);
    }

    pub fn save(allocator: std.mem.Allocator, parent: ?Window, title: []const u8, default_path: []const u8, filters: []const FileFilter, flags: u32) Error![]u8 {
        var filter_buf: [4096]u8 = undefined;
        const filters_len = packFileFilters(&filter_buf, filters);
        var spec = CSaveSpec{
            .parent_win_id = if (parent) |w| @intCast(w.id) else 0,
            .title_ptr = sliceAddr(title),
            .title_len = title.len,
            .default_path_ptr = sliceAddr(default_path),
            .default_path_len = default_path.len,
            .filters_ptr = if (filters_len > 0) @intFromPtr(&filter_buf) else 0,
            .filters_len = filters_len,
            .flags = flags,
        };
        var scratch: [65536]u8 = undefined;
        const got = dispatch(.dialog, 2, @intFromPtr(&spec), @intFromPtr(&scratch), scratch.len);
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        if (got == 0) return try allocator.dupe(u8, "");
        const n = @min(got, scratch.len);
        return try allocator.dupe(u8, scratch[0..n]);
    }

    pub fn message(parent: ?Window, msg_type: MessageType, title: []const u8, body: []const u8, detail: []const u8, buttons: []const []const u8) Error!MessageResult {
        // Pack buttons as NUL-separated into a stack buffer.
        var btn_buf: [1024]u8 = undefined;
        var len: usize = 0;
        var count: u32 = 0;
        for (buttons) |b| {
            if (len + b.len + 1 > btn_buf.len) break;
            @memcpy(btn_buf[len .. len + b.len], b);
            len += b.len;
            btn_buf[len] = 0;
            len += 1;
            count += 1;
        }
        var spec = CMessageSpec{
            .parent_win_id = if (parent) |w| @intCast(w.id) else 0,
            .type = @intFromEnum(msg_type),
            .title_ptr = sliceAddr(title),
            .title_len = title.len,
            .message_ptr = sliceAddr(body),
            .message_len = body.len,
            .detail_ptr = sliceAddr(detail),
            .detail_len = detail.len,
            .buttons_ptr = if (len > 0) @intFromPtr(&btn_buf) else 0,
            .buttons_len = len,
            .button_count = count,
            .default_button = 0,
            .cancel_button = if (count > 1) @as(i32, @intCast(count - 1)) else 0,
        };
        var out: CMessageResult = .{};
        const got = dispatch(.dialog, 3, @intFromPtr(&spec), @intFromPtr(&out), @sizeOf(CMessageResult));
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        return .{ .button = out.button, .checkbox_checked = out.checkbox_checked != 0 };
    }
};


pub const TrayEvent = enum(u8) {
    click = 1,
    right_click = 2,
    appearance = 3,
    menu = 4,
};

pub const Tray = struct {
    id: usize = 0,

    const CNewSpec = extern struct {
        id_ptr: usize = 0,
        id_len: usize = 0,
        icon_ptr: usize = 0,
        icon_len: usize = 0,
        title_ptr: usize = 0,
        title_len: usize = 0,
        tip_ptr: usize = 0,
        tip_len: usize = 0,
        menu_json_ptr: usize = 0,
        menu_len: usize = 0,
        menu_cb_id: usize = 0,
        template: u8 = 0,
        _pad: [7]u8 = @splat(0),
    };

    const CIconSpec = extern struct {
        png_ptr: usize = 0,
        png_len: usize = 0,
        template: u8 = 0,
        _pad: [7]u8 = @splat(0),
    };

    const Sub = enum(usize) {
        new = 1,
        destroy = 2,
        set_icon = 3,
        set_title = 4,
        set_tooltip = 5,
        set_menu = 6,
        popup = 7,
        bounds = 8,
        dark = 9,
        on_event = 10,
    };

    /// Create a tray icon. `menu_json` is optional App-menu-style JSON
    /// (`[{"id":"x","label":"X"},…]`). Menu clicks arrive on the handler
    /// registered with `onMenu` (or the same cb as `menu_cb` via `new`).
    pub fn new(opts: struct {
        id: []const u8 = "",
        icon_png: []const u8 = "",
        title: []const u8 = "",
        tooltip: []const u8 = "",
        menu_json: []const u8 = "",
        template: bool = false,
        menu_cb: usize = 0,
    }) Error!Tray {
        var spec = CNewSpec{
            .id_ptr = sliceAddr(opts.id),
            .id_len = opts.id.len,
            .icon_ptr = sliceAddr(opts.icon_png),
            .icon_len = opts.icon_png.len,
            .title_ptr = sliceAddr(opts.title),
            .title_len = opts.title.len,
            .tip_ptr = sliceAddr(opts.tooltip),
            .tip_len = opts.tooltip.len,
            .menu_json_ptr = sliceAddr(opts.menu_json),
            .menu_len = opts.menu_json.len,
            .menu_cb_id = opts.menu_cb,
            .template = if (opts.template) 1 else 0,
        };
        const id = dispatch(.tray, @intFromEnum(Sub.new), @intFromPtr(&spec), 0, 0);
        if (id == 0) return Error.MyGoError;
        return .{ .id = id };
    }

    pub fn destroy(self: Tray) void {
        _ = dispatch(.tray, @intFromEnum(Sub.destroy), self.id, 0, 0);
    }

    pub fn setIcon(self: Tray, png: []const u8, template: bool) Error!void {
        var spec = CIconSpec{
            .png_ptr = sliceAddr(png),
            .png_len = png.len,
            .template = if (template) 1 else 0,
        };
        if (dispatch(.tray, @intFromEnum(Sub.set_icon), self.id, @intFromPtr(&spec), 0) == std.math.maxInt(usize))
            return Error.MyGoError;
    }

    pub fn setTitle(self: Tray, title: []const u8) void {
        _ = dispatch(.tray, @intFromEnum(Sub.set_title), self.id, sliceAddr(title), title.len);
    }

    pub fn setToolTip(self: Tray, tip: []const u8) void {
        _ = dispatch(.tray, @intFromEnum(Sub.set_tooltip), self.id, sliceAddr(tip), tip.len);
    }

    /// Tray menu from MenuItem values. Empty clears.
    pub fn setMenu(self: Tray, items: []const MenuItem) Error!void {
        const allocator = std.heap.page_allocator;
        const json = try menuJSON(allocator, items);
        defer allocator.free(json);
        try self.setMenuJSON(json);
    }

    pub fn setMenuJSON(self: Tray, json: []const u8) Error!void {
        if (dispatch(.tray, @intFromEnum(Sub.set_menu), self.id, sliceAddr(json), json.len) == std.math.maxInt(usize))
            return Error.MyGoError;
    }

    pub fn clearMenu(self: Tray) void {
        _ = dispatch(.tray, @intFromEnum(Sub.set_menu), self.id, 0, 0);
    }

    pub fn popUpMenu(self: Tray) void {
        _ = dispatch(.tray, @intFromEnum(Sub.popup), self.id, 0, 0);
    }

    pub fn bounds(self: Tray) Rectangle {
        var b: CBounds = .{};
        _ = dispatch(.tray, @intFromEnum(Sub.bounds), self.id, @intFromPtr(&b), 0);
        return .{ .x = b.x, .y = b.y, .width = b.width, .height = b.height };
    }

    pub fn dark(self: Tray) bool {
        return dispatch(.tray, @intFromEnum(Sub.dark), self.id, 0, 0) != 0;
    }

    pub fn onClick(self: Tray, comptime StatePtr: type, state: StatePtr, comptime handler: fn (StatePtr) void) void {
        const S = struct {
            fn onTray(tray_id: usize, kind: u8, menu_id: []const u8, ud: usize) void {
                _ = tray_id;
                _ = menu_id;
                if (kind != @intFromEnum(TrayEvent.click)) return;
                const s: StatePtr = @ptrFromInt(ud);
                handler(s);
            }
        };
        const cb = registerTrayHandler(&S.onTray, @intFromPtr(state));
        _ = dispatch(.tray, @intFromEnum(Sub.on_event), self.id, 1, cb);
    }

    pub fn onRightClick(self: Tray, comptime StatePtr: type, state: StatePtr, comptime handler: fn (StatePtr) void) void {
        const S = struct {
            fn onTray(tray_id: usize, kind: u8, menu_id: []const u8, ud: usize) void {
                _ = tray_id;
                _ = menu_id;
                if (kind != @intFromEnum(TrayEvent.right_click)) return;
                const s: StatePtr = @ptrFromInt(ud);
                handler(s);
            }
        };
        const cb = registerTrayHandler(&S.onTray, @intFromPtr(state));
        _ = dispatch(.tray, @intFromEnum(Sub.on_event), self.id, 2, cb);
    }

    /// Register a menu-click handler; pass the returned id as `menu_cb` to `new`.
    pub fn registerMenuHandler(comptime StatePtr: type, state: StatePtr, comptime handler: fn (StatePtr, []const u8) void) usize {
        const S = struct {
            fn onTray(tray_id: usize, kind: u8, menu_id: []const u8, ud: usize) void {
                _ = tray_id;
                if (kind != @intFromEnum(TrayEvent.menu)) return;
                const s: StatePtr = @ptrFromInt(ud);
                handler(s, menu_id);
            }
        };
        return registerTrayHandler(&S.onTray, @intFromPtr(state));
    }
};



pub const Notification = struct {
    const Sub = enum(usize) {
        supported = 1,
        show = 2,
        close = 3,
        clear = 4,
        on_app_click = 5,
    };

    const CShowSpec = extern struct {
        id_ptr: usize = 0,
        id_len: usize = 0,
        title_ptr: usize = 0,
        title_len: usize = 0,
        subtitle_ptr: usize = 0,
        subtitle_len: usize = 0,
        body_ptr: usize = 0,
        body_len: usize = 0,
        group_ptr: usize = 0,
        group_len: usize = 0,
        image_ptr: usize = 0,
        image_len: usize = 0,
        silent: u8 = 0,
        _pad: [7]u8 = @splat(0),
        click_cb_id: usize = 0,
    };

    pub fn supported() bool {
        return dispatch(.notification, @intFromEnum(Sub.supported), 0, 0, 0) != 0;
    }

    /// Show a desktop notification. Returns the notification id (caller owns).
    /// Pass `click_cb` from `registerClickHandler` to receive clicks.
    pub fn show(allocator: std.mem.Allocator, opts: struct {
        id: []const u8 = "",
        title: []const u8 = "",
        subtitle: []const u8 = "",
        body: []const u8 = "",
        group: []const u8 = "",
        image: []const u8 = "",
        silent: bool = false,
        click_cb: usize = 0,
    }) Error![]u8 {
        var spec = CShowSpec{
            .id_ptr = sliceAddr(opts.id),
            .id_len = opts.id.len,
            .title_ptr = sliceAddr(opts.title),
            .title_len = opts.title.len,
            .subtitle_ptr = sliceAddr(opts.subtitle),
            .subtitle_len = opts.subtitle.len,
            .body_ptr = sliceAddr(opts.body),
            .body_len = opts.body.len,
            .group_ptr = sliceAddr(opts.group),
            .group_len = opts.group.len,
            .image_ptr = sliceAddr(opts.image),
            .image_len = opts.image.len,
            .silent = if (opts.silent) 1 else 0,
            .click_cb_id = opts.click_cb,
        };
        var scratch: [256]u8 = undefined;
        const got = dispatch(.notification, @intFromEnum(Sub.show), @intFromPtr(&spec), @intFromPtr(&scratch), scratch.len);
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        const n = @min(got, scratch.len);
        return try allocator.dupe(u8, scratch[0..n]);
    }

    pub fn close(id: []const u8) void {
        _ = dispatch(.notification, @intFromEnum(Sub.close), sliceAddr(id), id.len, 0);
    }

    pub fn clearAll() void {
        _ = dispatch(.notification, @intFromEnum(Sub.clear), 0, 0, 0);
    }

    /// Register a per-notification click handler; pass returned id as `click_cb` to `show`.
    pub fn registerClickHandler(comptime StatePtr: type, state: StatePtr, comptime handler: fn (StatePtr, []const u8) void) usize {
        const S = struct {
            fn onNotif(kind: u8, id: []const u8, ud: usize) void {
                if (kind != 1) return;
                const s: StatePtr = @ptrFromInt(ud);
                handler(s, id);
            }
        };
        return registerNotifHandler(&S.onNotif, @intFromPtr(state));
    }

    /// App-level click handler (also for notifications from earlier runs).
    pub fn onAppClick(comptime StatePtr: type, state: StatePtr, comptime handler: fn (StatePtr, []const u8) void) void {
        const S = struct {
            fn onNotif(kind: u8, id: []const u8, ud: usize) void {
                if (kind != 2) return;
                const s: StatePtr = @ptrFromInt(ud);
                handler(s, id);
            }
        };
        const cb = registerNotifHandler(&S.onNotif, @intFromPtr(state));
        _ = dispatch(.notification, @intFromEnum(Sub.on_app_click), cb, 0, 0);
    }
};









pub const SiteData = struct {
    pub const cookies: u64 = 1;
    pub const local_storage: u64 = 2;
    pub const indexed_db: u64 = 4;
    pub const caches: u64 = 8;
    pub const service_workers: u64 = 16;
    pub const all: u64 = 0; // host treats 0 as SiteDataAll
};



pub const ContentRules = struct {
    pub fn compile(id: []const u8, rules_json: []const u8) Error!void {
        const Spec = extern struct {
            id_ptr: usize = 0,
            id_len: usize = 0,
            rules_ptr: usize = 0,
            rules_len: usize = 0,
        };
        var spec = Spec{
            .id_ptr = sliceAddr(id),
            .id_len = id.len,
            .rules_ptr = sliceAddr(rules_json),
            .rules_len = rules_json.len,
        };
        if (dispatch(.content_rules, 1, @intFromPtr(&spec), 0, 0) == std.math.maxInt(usize)) return Error.MyGoError;
    }
};

pub const Locale = struct {
    pub fn get(allocator: std.mem.Allocator) Error![]u8 {
        var scratch: [64]u8 = undefined;
        const got = dispatch(.locale, 1, @intFromPtr(&scratch), scratch.len, 0);
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        const n = @min(got, scratch.len);
        return try allocator.dupe(u8, scratch[0..n]);
    }

    pub fn set(tag: []const u8) void {
        _ = dispatch(.locale, 2, sliceAddr(tag), tag.len, 0);
    }

    pub fn preferredJSON(allocator: std.mem.Allocator) Error![]u8 {
        var scratch: [2048]u8 = undefined;
        const got = dispatch(.locale, 3, @intFromPtr(&scratch), scratch.len, 0);
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        const n = @min(got, scratch.len);
        return try allocator.dupe(u8, scratch[0..n]);
    }

    pub fn languagesJSON(allocator: std.mem.Allocator) Error![]u8 {
        var scratch: [2048]u8 = undefined;
        const got = dispatch(.locale, 4, @intFromPtr(&scratch), scratch.len, 0);
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        const n = @min(got, scratch.len);
        return try allocator.dupe(u8, scratch[0..n]);
    }

    pub fn setLanguagesJSON(json: []const u8) Error!void {
        if (dispatch(.locale, 5, sliceAddr(json), json.len, 0) == std.math.maxInt(usize)) return Error.MyGoError;
    }

    pub fn onChanged(comptime StatePtr: type, state: StatePtr, comptime handler: fn (StatePtr, []const u8) void) void {
        const S = struct {
            fn onLoc(loc: []const u8, ud: usize) void {
                const s: StatePtr = @ptrFromInt(ud);
                handler(s, loc);
            }
        };
        const cb = registerLocaleHandler(&S.onLoc, @intFromPtr(state));
        _ = dispatch(.locale, 6, cb, 0, 0);
    }
};

pub const Session = struct {
    /// Clear all browsing data of the default session.
    pub fn clearBrowsingData() Error!void {
        if (dispatch(.session, 1, 0, 0, 0) == std.math.maxInt(usize)) return Error.MyGoError;
    }

    /// Clear data of a named session (empty name = default). types=0 means all.
    pub fn clearData(name: []const u8, types: u64) Error!void {
        const Spec = extern struct {
            name_ptr: usize = 0,
            name_len: usize = 0,
            types: u64 = 0,
        };
        var spec = Spec{
            .name_ptr = sliceAddr(name),
            .name_len = name.len,
            .types = types,
        };
        if (dispatch(.session, 2, @intFromPtr(&spec), 0, 0) == std.math.maxInt(usize)) return Error.MyGoError;
    }
};

pub const Cookies = struct {
    pub fn listJSON(allocator: std.mem.Allocator, filter_json: []const u8) Error![]u8 {
        const Spec = extern struct {
            filter_ptr: usize = 0,
            filter_len: usize = 0,
            out_ptr: usize = 0,
            out_cap: usize = 0,
        };
        var scratch: [65536]u8 = undefined;
        var spec = Spec{
            .filter_ptr = sliceAddr(filter_json),
            .filter_len = filter_json.len,
            .out_ptr = @intFromPtr(&scratch),
            .out_cap = scratch.len,
        };
        const got = dispatch(.cookies, 1, @intFromPtr(&spec), 0, 0);
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        const n = @min(got, scratch.len);
        return try allocator.dupe(u8, scratch[0..n]);
    }

    pub fn setJSON(cookie_json: []const u8) Error!void {
        if (dispatch(.cookies, 2, sliceAddr(cookie_json), cookie_json.len, 0) == std.math.maxInt(usize)) return Error.MyGoError;
    }

    pub fn deleteJSON(cookie_json: []const u8) Error!void {
        if (dispatch(.cookies, 3, sliceAddr(cookie_json), cookie_json.len, 0) == std.math.maxInt(usize)) return Error.MyGoError;
    }

    pub fn clear(session: []const u8) Error!void {
        if (dispatch(.cookies, 4, sliceAddr(session), session.len, 0) == std.math.maxInt(usize)) return Error.MyGoError;
    }
};

pub const Secrets = struct {
    const CSpec = extern struct {
        service_ptr: usize = 0,
        service_len: usize = 0,
        key_ptr: usize = 0,
        key_len: usize = 0,
        value_ptr: usize = 0,
        value_len: usize = 0,
    };

    fn fill(spec: *CSpec, service: []const u8, key: []const u8, value: []const u8) void {
        spec.* = .{
            .service_ptr = sliceAddr(service),
            .service_len = service.len,
            .key_ptr = sliceAddr(key),
            .key_len = key.len,
            .value_ptr = sliceAddr(value),
            .value_len = value.len,
        };
    }

    /// Empty service uses the app identifier.
    pub fn set(service: []const u8, key: []const u8, value: []const u8) Error!void {
        var spec: CSpec = .{};
        fill(&spec, service, key, value);
        if (dispatch(.secrets, 1, @intFromPtr(&spec), 0, 0) == std.math.maxInt(usize)) return Error.MyGoError;
    }

    pub fn get(allocator: std.mem.Allocator, service: []const u8, key: []const u8) Error![]u8 {
        var spec: CSpec = .{};
        fill(&spec, service, key, "");
        var scratch: [4096]u8 = undefined;
        const got = dispatch(.secrets, 2, @intFromPtr(&spec), @intFromPtr(&scratch), scratch.len);
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        const n = @min(got, scratch.len);
        return try allocator.dupe(u8, scratch[0..n]);
    }

    pub fn delete(service: []const u8, key: []const u8) Error!void {
        var spec: CSpec = .{};
        fill(&spec, service, key, "");
        if (dispatch(.secrets, 3, @intFromPtr(&spec), 0, 0) == std.math.maxInt(usize)) return Error.MyGoError;
    }
};

/// A menu item, the JSON menu wire in a Zig type: `Desktop.setAppMenu`,
/// `Tray.setMenu` and `Desktop.setDockMenu` take them.
/// Sound playback: effects decoded into memory and players.
///
/// Decoders are the Go side's: a WAV always decodes, and Ogg Vorbis or MP3
/// when the app (its Go shim) blank-imports audio/vorbis or audio/mp3.
pub const Audio = struct {
    const Sub = enum(usize) {
        decode_sound = 1,
        sound_duration = 2,
        sound_play = 3,
        open_stream = 4,
        play = 5,
        pause = 6,
        stop = 7,
        close = 8,
        playing = 9,
        set_volume = 10,
        volume = 11,
        set_pan = 12,
        pan = 13,
        set_speed = 14,
        speed = 15,
        set_loop = 16,
        loop = 17,
        seek = 18,
        position = 19,
        duration = 20,
        set_loop_range = 21,
        on_end = 22,
    };

    /// A Sound is audio decoded into memory, for effects that play often
    /// and over themselves: each play is a new Player.
    pub const Sound = struct {
        id: usize,

        /// durationMs is how long the sound is.
        pub fn durationMs(self: Sound) u64 {
            return dispatch(.audio, @intFromEnum(Sub.sound_duration), self.id, 0, 0);
        }

        /// play starts a new player of the sound.
        pub fn play(self: Sound) Error!Player {
            const id = dispatch(.audio, @intFromEnum(Sub.sound_play), self.id, 0, 0);
            if (id == 0 or id == std.math.maxInt(usize)) return Error.MyGoError;
            return .{ .id = id };
        }

        pub fn close(self: *Sound) void {
            self.id = 0;
        }
    };

    /// A Player plays a sound or a stream: its position, volume, pan, speed
    /// and looping are its own.
    pub const Player = struct {
        id: usize,

        pub fn play(self: Player) void {
            _ = dispatch(.audio, @intFromEnum(Sub.play), self.id, 0, 0);
        }
        pub fn pause(self: Player) void {
            _ = dispatch(.audio, @intFromEnum(Sub.pause), self.id, 0, 0);
        }
        pub fn stop(self: Player) void {
            _ = dispatch(.audio, @intFromEnum(Sub.stop), self.id, 0, 0);
        }
        pub fn close(self: *Player) void {
            if (self.id == 0) return;
            _ = dispatch(.audio, @intFromEnum(Sub.close), self.id, 0, 0);
            self.id = 0;
        }
        pub fn playing(self: Player) bool {
            return dispatch(.audio, @intFromEnum(Sub.playing), self.id, 0, 0) != 0;
        }
        pub fn setVolume(self: Player, v: f64) Player {
            _ = dispatch(.audio, @intFromEnum(Sub.set_volume), self.id, floatBits(v), 0);
            return self;
        }
        pub fn volume(self: Player) f64 {
            return bitsFloat(dispatch(.audio, @intFromEnum(Sub.volume), self.id, 0, 0));
        }
        pub fn setPan(self: Player, v: f64) Player {
            _ = dispatch(.audio, @intFromEnum(Sub.set_pan), self.id, floatBits(v), 0);
            return self;
        }
        pub fn pan(self: Player) f64 {
            return bitsFloat(dispatch(.audio, @intFromEnum(Sub.pan), self.id, 0, 0));
        }
        pub fn setSpeed(self: Player, v: f64) Player {
            _ = dispatch(.audio, @intFromEnum(Sub.set_speed), self.id, floatBits(v), 0);
            return self;
        }
        pub fn speed(self: Player) f64 {
            return bitsFloat(dispatch(.audio, @intFromEnum(Sub.speed), self.id, 0, 0));
        }
        pub fn setLoop(self: Player, on: bool) Player {
            _ = dispatch(.audio, @intFromEnum(Sub.set_loop), self.id, @intFromBool(on), 0);
            return self;
        }
        pub fn looping(self: Player) bool {
            return dispatch(.audio, @intFromEnum(Sub.loop), self.id, 0, 0) != 0;
        }
        pub fn seekMs(self: Player, ms: u64) void {
            _ = dispatch(.audio, @intFromEnum(Sub.seek), self.id, @intCast(ms), 0);
        }
        pub fn positionMs(self: Player) u64 {
            return dispatch(.audio, @intFromEnum(Sub.position), self.id, 0, 0);
        }
        pub fn durationMs(self: Player) u64 {
            return dispatch(.audio, @intFromEnum(Sub.duration), self.id, 0, 0);
        }
        pub fn setLoopRangeMs(self: Player, start_ms: u64, end_ms: u64) Player {
            _ = dispatch(.audio, @intFromEnum(Sub.set_loop_range), self.id, @intCast(start_ms), @intCast(end_ms));
            return self;
        }
        /// onEnd runs when the player stops playing by reaching its end.
        pub fn onEnd(
            self: Player,
            comptime StatePtr: type,
            state: StatePtr,
            comptime handler: fn (StatePtr) void,
        ) void {
            const S = struct {
                var cb_id: usize = 0;
                fn onEnd(player_id: usize, ud: usize) void {
                    _ = player_id;
                    const s: StatePtr = @ptrFromInt(ud);
                    handler(s);
                }
            };
            if (S.cb_id == 0) {
                if (audio_end_count >= audio_end_handlers.len) return;
                audio_end_handlers[audio_end_count] = &S.onEnd;
                audio_end_count += 1;
                S.cb_id = audio_end_count;
            }
            _ = dispatch(.audio, @intFromEnum(Sub.on_end), self.id, S.cb_id, @intFromPtr(state));
        }
    };

    /// decodeSound decodes audio bytes (WAV, and Ogg/MP3 with their plugins).
    pub fn decodeSound(data: []const u8) Error!Sound {
        const id = dispatch(.audio, @intFromEnum(Sub.decode_sound), sliceAddr(data), data.len, 0);
        if (id == 0 or id == std.math.maxInt(usize)) return Error.MyGoError;
        return .{ .id = id };
    }

    /// openStream streams audio bytes as they play.
    pub fn openStream(data: []const u8) Error!Player {
        const id = dispatch(.audio, @intFromEnum(Sub.open_stream), sliceAddr(data), data.len, 0);
        if (id == 0 or id == std.math.maxInt(usize)) return Error.MyGoError;
        return .{ .id = id };
    }

    fn floatBits(v: f64) usize {
        return @bitCast(v);
    }

    fn bitsFloat(bits: usize) f64 {
        return @bitCast(bits);
    }
};

/// DocumentsOf is NewDocuments[T] for Zig: a documents controller whose
/// content is T, encoded by cfg.write and decoded by cfg.read, over the
/// byte-level Documents wire.
///
/// ```zig
/// const Notes = DocumentsOf(Note, .{
///     .types_json = "[{\"name\":\"Note\",\"extensions\":[\"note\"]}]",
///     .read = Note.read,
///     .write = Note.write,
/// });
/// Notes.init(*App, app, App.newWindow) catch {};
/// ```
pub fn DocumentsOf(comptime T: type, comptime cfg: anytype) type {
    return struct {
        comptime {
            if (!@hasField(@TypeOf(cfg), "types_json")) @compileError("DocumentsOf needs types_json");
            if (!@hasField(@TypeOf(cfg), "read")) @compileError("DocumentsOf needs read");
            if (!@hasField(@TypeOf(cfg), "write")) @compileError("DocumentsOf needs write");
        }

        const Cfg = @TypeOf(cfg);
        const has_new = @hasField(Cfg, "new_content");
        const autosave_off = if (@hasField(Cfg, "autosave_off")) cfg.autosave_off else false;
        const ask_on_quit = if (@hasField(Cfg, "ask_on_quit")) cfg.ask_on_quit else false;
        const no_untitled = if (@hasField(Cfg, "no_untitled")) cfg.no_untitled else false;
        const autosave_delay_ms = if (@hasField(Cfg, "autosave_delay_ms")) cfg.autosave_delay_ms else 0;

        /// A document whose content is T.
        pub const Document = struct {
            id: usize,

            /// content decodes the document's content.
            pub fn content(self: Document, allocator: std.mem.Allocator) !T {
                const bytes = try Documents.content(allocator, self.id);
                defer allocator.free(bytes);
                return cfg.read(bytes);
            }

            /// setContent encodes value and marks the document edited.
            pub fn setContent(self: Document, allocator: std.mem.Allocator, value: T) !void {
                var out: std.ArrayList(u8) = .empty;
                defer out.deinit(allocator);
                try cfg.write(allocator, value, &out);
                try Documents.setContent(self.id, out.items);
                Documents.changed(self.id);
            }

            pub fn save(self: Document) Error!void {
                return Documents.save(self.id);
            }
            pub fn saveAs(self: Document, path: []const u8) Error!void {
                return Documents.saveAs(self.id, path);
            }
            pub fn saveAnyway(self: Document) Error!void {
                return Documents.saveAnyway(self.id);
            }
            pub fn revert(self: Document) Error!void {
                return Documents.revert(self.id);
            }
            pub fn rename(self: Document, name: []const u8) Error!void {
                return Documents.rename(self.id, name);
            }
            pub fn moveTo(self: Document, dir: []const u8) Error!void {
                return Documents.moveTo(self.id, dir);
            }
            /// duplicate makes another document with the same content.
            pub fn duplicate(self: Document) Error!Document {
                return .{ .id = try Documents.duplicate(self.id) };
            }
            pub fn close(self: Document) void {
                Documents.close(self.id);
            }
            pub fn setEdited(self: Document, edited: bool) void {
                Documents.setEdited(self.id, edited);
            }
            pub fn focus(self: Document) void {
                Documents.focus(self.id);
            }
            pub fn stateJSON(self: Document, allocator: std.mem.Allocator) Error![]u8 {
                return Documents.stateJSON(allocator, self.id);
            }
            pub fn filePath(self: Document, allocator: std.mem.Allocator) Error![]u8 {
                return Documents.filePath(allocator, self.id);
            }
            pub fn displayName(self: Document, allocator: std.mem.Allocator) Error![]u8 {
                return Documents.displayName(allocator, self.id);
            }
            pub fn windowID(self: Document) i32 {
                return Documents.windowID(self.id);
            }
            pub fn isReadOnly(self: Document) bool {
                return Documents.isReadOnly(self.id);
            }
            pub fn hasConflict(self: Document) bool {
                return Documents.hasConflict(self.id);
            }
        };

        /// init configures the controller; call it before App.Run, once.
        /// windowFor builds the window that shows a document.
        pub fn init(
            comptime StatePtr: type,
            state: StatePtr,
            comptime windowFor: fn (StatePtr, Document) Window,
        ) Error!void {
            const S = struct {
                fn onDoc(s: StatePtr, doc_id: usize, ev: Documents.Event) usize {
                    switch (ev) {
                        .need_window => {
                            const win = windowFor(s, .{ .id = doc_id });
                            return @intCast(win.id);
                        },
                        else => return 0,
                    }
                }
            };
            try Documents.configure(
                cfg.types_json,
                autosave_off,
                ask_on_quit,
                no_untitled,
                autosave_delay_ms,
                StatePtr,
                state,
                S.onDoc,
            );
        }

        /// new makes an untitled document. Give it cfg.new_content first.
        pub fn new() Error!Document {
            const d = Document{ .id = try Documents.new() };
            if (has_new) {
                d.setContent(std.heap.page_allocator, cfg.new_content) catch {};
            }
            return d;
        }

        pub fn open(file_path: []const u8) Error!Document {
            return .{ .id = try Documents.open(file_path) };
        }

        /// openDialog shows the system dialog and returns what was opened.
        pub fn openDialog(allocator: std.mem.Allocator) Error![]Document {
            const raw = try Documents.openDialogJSON(allocator);
            defer allocator.free(raw);
            const parsed = std.json.parseFromSlice([]usize, allocator, raw, .{}) catch return Error.MyGoError;
            defer parsed.deinit();
            const out = try allocator.alloc(Document, parsed.value.len);
            for (parsed.value, 0..) |id, i| out[i] = .{ .id = id };
            return out;
        }

        /// list returns the open documents.
        pub fn list(allocator: std.mem.Allocator) Error![]Document {
            const raw = try Documents.listJSON(allocator);
            defer allocator.free(raw);
            const parsed = std.json.parseFromSlice([]usize, allocator, raw, .{}) catch return Error.MyGoError;
            defer parsed.deinit();
            const out = try allocator.alloc(Document, parsed.value.len);
            for (parsed.value, 0..) |id, i| out[i] = .{ .id = id };
            return out;
        }

        /// forWindow finds the document a window shows.
        pub fn forWindow(win_id: i32) ?Document {
            const id = Documents.forWindow(win_id);
            if (id == 0) return null;
            return .{ .id = id };
        }
    };
}

pub const MenuItem = struct {
    pub const Kind = enum {
        normal,
        separator,
        checkbox,
        radio,

        fn wire(self: Kind) []const u8 {
            return switch (self) {
                .normal => "",
                .separator => "separator",
                .checkbox => "checkbox",
                .radio => "radio",
            };
        }
    };

    id: []const u8 = "",
    label: []const u8 = "",
    kind: Kind = .normal,
    role: []const u8 = "",
    accelerator: []const u8 = "",
    disabled: bool = false,
    hidden: bool = false,
    checked: bool = false,
    tooltip: []const u8 = "",
    subtitle: []const u8 = "",
    /// PNG bytes shown beside the label; empty shows none.
    icon_png: []const u8 = "",
    /// Draws the icon in the menu's text color (macOS).
    icon_template: bool = false,
    submenu: []const MenuItem = &.{},
};

/// menuJSON encodes items for `Desktop.setAppMenuJSON`, `Tray.setMenuJSON`
/// and `Desktop.setDockMenuJSON`. The caller frees the result.
pub fn menuJSON(allocator: std.mem.Allocator, items: []const MenuItem) Error![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try writeMenuItems(allocator, &out, items);
    return try out.toOwnedSlice(allocator);
}

fn writeMenuItems(allocator: std.mem.Allocator, out: *std.ArrayList(u8), items: []const MenuItem) Error!void {
    try out.append(allocator, '[');
    for (items, 0..) |item, i| {
        if (i > 0) try out.append(allocator, ',');
        try writeMenuItem(allocator, out, item);
    }
    try out.append(allocator, ']');
}

fn writeMenuItem(allocator: std.mem.Allocator, out: *std.ArrayList(u8), item: MenuItem) Error!void {
    try out.appendSlice(allocator, "{\"id\":");
    try writeJsonString(allocator, out, item.id);
    try out.appendSlice(allocator, ",\"label\":");
    try writeJsonString(allocator, out, item.label);
    if (item.kind != .normal) {
        try out.appendSlice(allocator, ",\"type\":");
        try writeJsonString(allocator, out, item.kind.wire());
    }
    if (item.role.len > 0) {
        try out.appendSlice(allocator, ",\"role\":");
        try writeJsonString(allocator, out, item.role);
    }
    if (item.accelerator.len > 0) {
        try out.appendSlice(allocator, ",\"accelerator\":");
        try writeJsonString(allocator, out, item.accelerator);
    }
    if (item.disabled) try out.appendSlice(allocator, ",\"disabled\":true");
    if (item.hidden) try out.appendSlice(allocator, ",\"hidden\":true");
    if (item.checked) try out.appendSlice(allocator, ",\"checked\":true");
    if (item.tooltip.len > 0) {
        try out.appendSlice(allocator, ",\"tooltip\":");
        try writeJsonString(allocator, out, item.tooltip);
    }
    if (item.subtitle.len > 0) {
        try out.appendSlice(allocator, ",\"subtitle\":");
        try writeJsonString(allocator, out, item.subtitle);
    }
    if (item.icon_png.len > 0) {
        const enc = std.base64.standard.Encoder;
        const n = enc.calcSize(item.icon_png.len);
        const b64 = try allocator.alloc(u8, n);
        defer allocator.free(b64);
        _ = enc.encode(b64, item.icon_png);
        try out.appendSlice(allocator, ",\"iconPng\":");
        try writeJsonString(allocator, out, b64);
        if (item.icon_template) try out.appendSlice(allocator, ",\"iconTemplate\":true");
    }
    if (item.submenu.len > 0) {
        try out.appendSlice(allocator, ",\"submenu\":");
        try writeMenuItems(allocator, out, item.submenu);
    }
    try out.append(allocator, '}');
}

pub fn writeJsonString(allocator: std.mem.Allocator, out: *std.ArrayList(u8), s: []const u8) Error!void {
    try out.append(allocator, '"');
    for (s) |ch| {
        switch (ch) {
            '"' => try out.appendSlice(allocator, "\\\""),
            '\\' => try out.appendSlice(allocator, "\\\\"),
            '\n' => try out.appendSlice(allocator, "\\n"),
            '\r' => try out.appendSlice(allocator, "\\r"),
            '\t' => try out.appendSlice(allocator, "\\t"),
            else => {
                if (ch < 0x20) {
                    var tmp: [6]u8 = undefined;
                    const esc = std.fmt.bufPrint(&tmp, "\\u{x:0>4}", .{ch}) catch unreachable;
                    try out.appendSlice(allocator, esc);
                } else {
                    try out.append(allocator, ch);
                }
            },
        }
    }
    try out.append(allocator, '"');
}

pub const Desktop = struct {
    /// Set Windows jump-list tasks. Pass JSON array of task objects. "[]" clears.
    pub fn setJumpListTasksJSON(json: []const u8) Error!void {
        if (dispatch(.desktop, 1, sliceAddr(json), json.len, 0) == std.math.maxInt(usize)) return Error.MyGoError;
    }

    pub fn addRecentDocument(path: []const u8) Error!void {
        if (dispatch(.desktop, 2, sliceAddr(path), path.len, 0) == std.math.maxInt(usize)) return Error.MyGoError;
    }

    pub fn clearRecentDocuments() Error!void {
        if (dispatch(.desktop, 3, 0, 0, 0) == std.math.maxInt(usize)) return Error.MyGoError;
    }

    pub fn recentDocumentsJSON(allocator: std.mem.Allocator) Error![]u8 {
        var scratch: [65536]u8 = undefined;
        const got = dispatch(.desktop, 8, @intFromPtr(&scratch), scratch.len, 0);
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        return try allocator.dupe(u8, scratch[0..@min(got, scratch.len)]);
    }

    /// Dock menu as JSON array (same shape as Tray.setMenuJSON). Empty clears.
    pub fn setDockMenuJSON(comptime StatePtr: type, state: StatePtr, json: []const u8, comptime handler: fn (StatePtr, []const u8) void) Error!void {
        const S = struct {
            fn onMenu(_: i32, id: []const u8, ud: usize) void {
                const s: StatePtr = @ptrFromInt(ud);
                handler(s, id);
            }
        };
        const cb = registerMenuHandler(&S.onMenu, @intFromPtr(state));
        if (dispatch(.desktop, 4, sliceAddr(json), json.len, cb) == std.math.maxInt(usize)) return Error.MyGoError;
    }

    pub fn setDockIcon(png: []const u8) Error!void {
        if (dispatch(.desktop, 5, sliceAddr(png), png.len, 0) == std.math.maxInt(usize)) return Error.MyGoError;
    }

    pub fn hideDock() void {
        _ = dispatch(.desktop, 6, 0, 0, 0);
    }

    pub fn showDock() void {
        _ = dispatch(.desktop, 7, 0, 0, 0);
    }

    /// Application menu bar from MenuItem values.
    pub fn setAppMenu(comptime StatePtr: type, state: StatePtr, items: []const MenuItem, comptime handler: fn (StatePtr, []const u8) void) Error!void {
        const allocator = std.heap.page_allocator;
        const json = try menuJSON(allocator, items);
        defer allocator.free(json);
        try setAppMenuJSON(StatePtr, state, json, handler);
    }

    /// Dock menu from MenuItem values. Empty clears.
    pub fn setDockMenu(comptime StatePtr: type, state: StatePtr, items: []const MenuItem, comptime handler: fn (StatePtr, []const u8) void) Error!void {
        const allocator = std.heap.page_allocator;
        const json = try menuJSON(allocator, items);
        defer allocator.free(json);
        try setDockMenuJSON(StatePtr, state, json, handler);
    }

    /// Application menu bar JSON (same shape as Tray menus).
    pub fn setAppMenuJSON(comptime StatePtr: type, state: StatePtr, json: []const u8, comptime handler: fn (StatePtr, []const u8) void) Error!void {
        const S = struct {
            fn onMenu(_: i32, id: []const u8, ud: usize) void {
                const s: StatePtr = @ptrFromInt(ud);
                handler(s, id);
            }
        };
        const cb = registerMenuHandler(&S.onMenu, @intFromPtr(state));
        if (dispatch(.app_set_menu, sliceAddr(json), json.len, cb, 0) == std.math.maxInt(usize)) return Error.MyGoError;
    }
};

pub const Protocol = struct {
    const CResp = extern struct {
        req_id: usize = 0,
        status: i32 = 200,
        _pad: [4]u8 = @splat(0),
        headers_ptr: usize = 0,
        headers_len: usize = 0,
        body_ptr: usize = 0,
        body_len: usize = 0,
    };

    /// Register a custom scheme. Handler must call `respond` before returning.
    pub fn handle(comptime StatePtr: type, state: StatePtr, scheme: []const u8, comptime handler: fn (StatePtr, usize, ProtocolRequest) void) Error!void {
        const S = struct {
            fn onReq(req_id: usize, req: ProtocolRequest, ud: usize) void {
                const s: StatePtr = @ptrFromInt(ud);
                handler(s, req_id, req);
            }
        };
        const cb = registerProtocolHandler(&S.onReq, @intFromPtr(state));
        if (dispatch(.protocol, 1, sliceAddr(scheme), scheme.len, cb) == std.math.maxInt(usize)) {
            return Error.MyGoError;
        }
    }

    pub fn unhandle(scheme: []const u8) void {
        _ = dispatch(.protocol, 2, sliceAddr(scheme), scheme.len, 0);
    }

    pub fn isHandled(scheme: []const u8) bool {
        return dispatch(.protocol, 3, sliceAddr(scheme), scheme.len, 0) != 0;
    }

    /// Must be called from the `handle` callback before it returns.
    pub fn respond(req_id: usize, status: i32, headers_json: []const u8, body: []const u8) void {
        var spec = CResp{
            .req_id = req_id,
            .status = status,
            .headers_ptr = sliceAddr(headers_json),
            .headers_len = headers_json.len,
            .body_ptr = sliceAddr(body),
            .body_len = body.len,
        };
        _ = dispatch(.protocol, 4, @intFromPtr(&spec), 0, 0);
    }
};






pub const Gamepad = struct {
    pub const Button = enum(u8) {
        south = 0,
        east = 1,
        west = 2,
        north = 3,
        left_bumper = 4,
        right_bumper = 5,
        left_trigger = 6,
        right_trigger = 7,
        select = 8,
        start = 9,
        left_stick_button = 10,
        right_stick_button = 11,
        dpad_up = 12,
        dpad_down = 13,
        dpad_left = 14,
        dpad_right = 15,
        guide = 16,
    };

    pub const Axis = enum(u8) {
        left_x = 0,
        left_y = 1,
        right_x = 2,
        right_y = 3,
    };

    pub fn padsJSON(allocator: std.mem.Allocator) Error![]u8 {
        var scratch: [4096]u8 = undefined;
        const got = dispatch(.gamepad, 1, @intFromPtr(&scratch), scratch.len, 0);
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        return try allocator.dupe(u8, scratch[0..@min(got, scratch.len)]);
    }

    pub const State = extern struct {
        buttons: [17]f32 = @splat(0),
        axes: [4]f32 = @splat(0),
        connected: u8 = 0,
        _pad: [3]u8 = .{ 0, 0, 0 },

        pub fn value(self: State, b: Button) f32 {
            return self.buttons[@intFromEnum(b)];
        }

        pub fn pressed(self: State, b: Button) bool {
            return self.value(b) >= 0.25;
        }

        pub fn justPressed(self: State, last: State, b: Button) bool {
            return self.pressed(b) and !last.pressed(b);
        }

        pub fn justReleased(self: State, last: State, b: Button) bool {
            return !self.pressed(b) and last.pressed(b);
        }

        pub fn leftStick(self: State) struct { x: f32, y: f32 } {
            const p = stick(self.axes[0], self.axes[1]);
            return .{ .x = p[0], .y = p[1] };
        }

        pub fn rightStick(self: State) struct { x: f32, y: f32 } {
            const p = stick(self.axes[2], self.axes[3]);
            return .{ .x = p[0], .y = p[1] };
        }

        fn stick(x: f32, y: f32) [2]f32 {
            const dead: f32 = 0.1;
            const m = @sqrt(x * x + y * y);
            if (m < dead) return .{ 0, 0 };
            const k = @min((m - dead) / (1 - dead), 1) / m;
            return .{ x * k, y * k };
        }
    };

    pub fn state(pad_id: usize) State {
        var out: State = .{};
        _ = dispatch(.gamepad, 2, pad_id, @intFromPtr(&out), 0);
        return out;
    }
};

pub const WebView = struct {
    id: usize = 0,

    pub const CreateOptions = struct {
        url: []const u8 = "",
        background: []const u8 = "",
        transparent: bool = false,
        scroll_to_container: bool = false,
        /// -1 = platform default, 0 = off, 1 = on
        devtools: i8 = -1,
        untrusted: bool = false,
        preload_all_frames: bool = false,
        safari_tab_focus: bool = false,
        picture_in_picture: bool = false,
        swipe_navigation: bool = false,
        pinch_zoom: bool = false,
        zoom_factor: f64 = 0,
        session_name: []const u8 = "",
        preload_script: []const u8 = "",
        user_agent: []const u8 = "",
        user_agent_suffix: []const u8 = "",
        /// JSON array of trusted origins, e.g. `["https://example.com"]`
        trusted_origins_json: []const u8 = "",
    };

    pub fn create(parent: Window, opts: CreateOptions) Error!WebView {
        const Spec = extern struct {
            url_ptr: usize = 0,
            url_len: usize = 0,
            background_ptr: usize = 0,
            background_len: usize = 0,
            transparent: u8 = 0,
            scroll_to_container: u8 = 0,
            devtools: i8 = -1,
            untrusted: u8 = 0,
            preload_all_frames: u8 = 0,
            safari_tab_focus: u8 = 0,
            picture_in_picture: u8 = 0,
            swipe_navigation: u8 = 0,
            pinch_zoom: u8 = 0,
            _pad: u8 = 0,
            zoom_factor: f64 = 0,
            session_name_ptr: usize = 0,
            session_name_len: usize = 0,
            preload_ptr: usize = 0,
            preload_len: usize = 0,
            user_agent_ptr: usize = 0,
            user_agent_len: usize = 0,
            ua_suffix_ptr: usize = 0,
            ua_suffix_len: usize = 0,
            trusted_ptr: usize = 0,
            trusted_len: usize = 0,
        };
        var spec = Spec{
            .url_ptr = sliceAddr(opts.url),
            .url_len = opts.url.len,
            .background_ptr = sliceAddr(opts.background),
            .background_len = opts.background.len,
            .transparent = @intFromBool(opts.transparent),
            .scroll_to_container = @intFromBool(opts.scroll_to_container),
            .devtools = opts.devtools,
            .untrusted = @intFromBool(opts.untrusted),
            .preload_all_frames = @intFromBool(opts.preload_all_frames),
            .safari_tab_focus = @intFromBool(opts.safari_tab_focus),
            .picture_in_picture = @intFromBool(opts.picture_in_picture),
            .swipe_navigation = @intFromBool(opts.swipe_navigation),
            .pinch_zoom = @intFromBool(opts.pinch_zoom),
            .zoom_factor = opts.zoom_factor,
            .session_name_ptr = sliceAddr(opts.session_name),
            .session_name_len = opts.session_name.len,
            .preload_ptr = sliceAddr(opts.preload_script),
            .preload_len = opts.preload_script.len,
            .user_agent_ptr = sliceAddr(opts.user_agent),
            .user_agent_len = opts.user_agent.len,
            .ua_suffix_ptr = sliceAddr(opts.user_agent_suffix),
            .ua_suffix_len = opts.user_agent_suffix.len,
            .trusted_ptr = sliceAddr(opts.trusted_origins_json),
            .trusted_len = opts.trusted_origins_json.len,
        };
        const id = dispatch(.webview, 1, @intCast(parent.id), @intFromPtr(&spec), 0);
        if (id == 0 or id == std.math.maxInt(usize)) return Error.MyGoError;
        return .{ .id = id };
    }

    pub fn destroy(self: WebView) void {
        _ = dispatch(.webview, 2, self.id, 0, 0);
    }

    pub fn focus(self: WebView) void {
        _ = dispatch(.webview, 3, self.id, 0, 0);
    }

    pub fn isDestroyed(self: WebView) bool {
        return dispatch(.webview, 4, self.id, 0, 0) != 0;
    }

    pub fn setBackgroundColor(self: WebView, color: []const u8) Error!void {
        if (dispatch(.webview, 5, self.id, sliceAddr(color), color.len) == std.math.maxInt(usize)) return Error.MyGoError;
    }

    pub fn capturePagePNG(self: WebView, allocator: std.mem.Allocator) Error![]u8 {
        var scratch: [4 * 1024 * 1024]u8 = undefined;
        const got = dispatch(.webview, 6, self.id, @intFromPtr(&scratch), scratch.len);
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        return try allocator.dupe(u8, scratch[0..@min(got, scratch.len)]);
    }

    /// Internal page window id — use with Window page / WinCtl helpers.
    pub fn pageWindow(self: WebView) Window {
        return .{ .id = @intCast(dispatch(.webview, 7, self.id, 0, 0)) };
    }

    pub fn pageWindowID(self: WebView) i32 {
        return @intCast(dispatch(.webview, 7, self.id, 0, 0));
    }

    pub fn parentWindowID(self: WebView) i32 {
        return @intCast(dispatch(.webview, 8, self.id, 0, 0));
    }

    // Page sugar — same surface as Window page APIs, routed via pageWindow.
    pub fn loadUrl(self: WebView, url: []const u8) Error!void {
        return self.pageWindow().loadUrl(url);
    }

    pub fn evalJSON(self: WebView, allocator: std.mem.Allocator, code: []const u8) Error![]u8 {
        return self.pageWindow().evalJSON(allocator, code);
    }
};

pub const Documents = struct {
    pub const Event = union(enum) {
        need_window: void,
        state: []const u8,
        reload: void,
    };

    /// Configure before App.Run. `types_json` is `[{ "name","extensions":[...]}]`.
    /// Handler for need_window must create a native UI window and return its id.
    /// Content is always raw bytes on the wire (Zig owns encode/decode).
    pub fn configure(
        types_json: []const u8,
        autosave_off: bool,
        ask_on_quit: bool,
        no_untitled: bool,
        autosave_delay_ms: u32,
        comptime StatePtr: type,
        state: StatePtr,
        comptime handler: fn (StatePtr, doc_id: usize, Event) usize,
    ) Error!void {
        const S = struct {
            fn onDoc(doc_id: usize, kind: u8, a3: usize, ud: usize) usize {
                const s: StatePtr = @ptrFromInt(ud);
                switch (kind) {
                    1 => return handler(s, doc_id, .need_window),
                    2 => {
                        const payload = if (a3 != 0) blk: {
                            const cs: *const CStr = @ptrFromInt(a3);
                            break :blk cs.toSlice();
                        } else "";
                        _ = handler(s, doc_id, .{ .state = payload });
                        return 0;
                    },
                    3 => {
                        _ = handler(s, doc_id, .reload);
                        return 0;
                    },
                    else => return 0,
                }
            }
        };
        const cb = registerDocHandler(&S.onDoc, @intFromPtr(state));
        const Spec = extern struct {
            types_ptr: usize = 0,
            types_len: usize = 0,
            autosave_off: u8 = 0,
            ask_on_quit: u8 = 0,
            no_untitled: u8 = 0,
            _pad: u8 = 0,
            autosave_delay_ms: u32 = 0,
            window_cb: usize = 0,
            window_ud: usize = 0,
        };
        var spec = Spec{
            .types_ptr = sliceAddr(types_json),
            .types_len = types_json.len,
            .autosave_off = @intFromBool(autosave_off),
            .ask_on_quit = @intFromBool(ask_on_quit),
            .no_untitled = @intFromBool(no_untitled),
            .autosave_delay_ms = autosave_delay_ms,
            .window_cb = cb,
            .window_ud = @intFromPtr(state),
        };
        if (dispatch(.documents, 1, @intFromPtr(&spec), 0, 0) == std.math.maxInt(usize)) return Error.MyGoError;
    }

    pub fn new() Error!usize {
        const id = dispatch(.documents, 2, 0, 0, 0);
        if (id == std.math.maxInt(usize)) return Error.MyGoError;
        return id;
    }

    pub fn open(file_path: []const u8) Error!usize {
        const id = dispatch(.documents, 3, sliceAddr(file_path), file_path.len, 0);
        if (id == std.math.maxInt(usize)) return Error.MyGoError;
        return id;
    }

    /// Opens the system file dialog; returns JSON array of doc ids.
    pub fn openDialogJSON(allocator: std.mem.Allocator) Error![]u8 {
        var scratch: [4096]u8 = undefined;
        const got = dispatch(.documents, 4, @intFromPtr(&scratch), scratch.len, 0);
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        return try allocator.dupe(u8, scratch[0..@min(got, scratch.len)]);
    }

    pub fn listJSON(allocator: std.mem.Allocator) Error![]u8 {
        var scratch: [4096]u8 = undefined;
        const got = dispatch(.documents, 5, @intFromPtr(&scratch), scratch.len, 0);
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        return try allocator.dupe(u8, scratch[0..@min(got, scratch.len)]);
    }

    pub fn content(allocator: std.mem.Allocator, doc_id: usize) Error![]u8 {
        var scratch: [1024 * 1024]u8 = undefined;
        const got = dispatch(.documents, 6, doc_id, @intFromPtr(&scratch), scratch.len);
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        return try allocator.dupe(u8, scratch[0..@min(got, scratch.len)]);
    }

    pub fn setContent(doc_id: usize, bytes: []const u8) Error!void {
        if (dispatch(.documents, 7, doc_id, sliceAddr(bytes), bytes.len) == std.math.maxInt(usize)) return Error.MyGoError;
    }

    pub fn save(doc_id: usize) Error!void {
        if (dispatch(.documents, 8, doc_id, 0, 0) == std.math.maxInt(usize)) return Error.MyGoError;
    }

    pub fn saveAs(doc_id: usize, file_path: []const u8) Error!void {
        if (dispatch(.documents, 9, doc_id, sliceAddr(file_path), file_path.len) == std.math.maxInt(usize)) return Error.MyGoError;
    }

    pub fn saveAnyway(doc_id: usize) Error!void {
        if (dispatch(.documents, 10, doc_id, 0, 0) == std.math.maxInt(usize)) return Error.MyGoError;
    }

    pub fn stateJSON(allocator: std.mem.Allocator, doc_id: usize) Error![]u8 {
        var scratch: [4096]u8 = undefined;
        const got = dispatch(.documents, 11, doc_id, @intFromPtr(&scratch), scratch.len);
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        return try allocator.dupe(u8, scratch[0..@min(got, scratch.len)]);
    }

    pub fn windowID(doc_id: usize) i32 {
        return @intCast(dispatch(.documents, 12, doc_id, 0, 0));
    }

    pub fn filePath(allocator: std.mem.Allocator, doc_id: usize) Error![]u8 {
        var scratch: [4096]u8 = undefined;
        const got = dispatch(.documents, 13, doc_id, @intFromPtr(&scratch), scratch.len);
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        return try allocator.dupe(u8, scratch[0..@min(got, scratch.len)]);
    }

    pub fn revert(doc_id: usize) Error!void {
        if (dispatch(.documents, 14, doc_id, 0, 0) == std.math.maxInt(usize)) return Error.MyGoError;
    }

    pub fn rename(doc_id: usize, new_name: []const u8) Error!void {
        if (dispatch(.documents, 15, doc_id, sliceAddr(new_name), new_name.len) == std.math.maxInt(usize)) return Error.MyGoError;
    }

    pub fn moveTo(doc_id: usize, dir: []const u8) Error!void {
        if (dispatch(.documents, 16, doc_id, sliceAddr(dir), dir.len) == std.math.maxInt(usize)) return Error.MyGoError;
    }

    pub fn duplicate(doc_id: usize) Error!usize {
        const id = dispatch(.documents, 17, doc_id, 0, 0);
        if (id == std.math.maxInt(usize)) return Error.MyGoError;
        return id;
    }

    pub fn close(doc_id: usize) void {
        _ = dispatch(.documents, 18, doc_id, 0, 0);
    }

    pub fn setEdited(doc_id: usize, edited: bool) void {
        _ = dispatch(.documents, 19, doc_id, @intFromBool(edited), 0);
    }

    pub fn changed(doc_id: usize) void {
        _ = dispatch(.documents, 20, doc_id, 0, 0);
    }

    pub fn displayName(allocator: std.mem.Allocator, doc_id: usize) Error![]u8 {
        var scratch: [1024]u8 = undefined;
        const got = dispatch(.documents, 21, doc_id, @intFromPtr(&scratch), scratch.len);
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        return try allocator.dupe(u8, scratch[0..@min(got, scratch.len)]);
    }

    pub fn forWindow(win_id: i32) usize {
        return dispatch(.documents, 22, @intCast(win_id), 0, 0);
    }

    pub fn focus(doc_id: usize) void {
        _ = dispatch(.documents, 23, doc_id, 0, 0);
    }

    pub fn isReadOnly(doc_id: usize) bool {
        return dispatch(.documents, 24, doc_id, 0, 0) != 0;
    }

    pub fn hasConflict(doc_id: usize) bool {
        return dispatch(.documents, 25, doc_id, 0, 0) != 0;
    }
};


pub const Network = struct {
    pub fn statusJSON(allocator: std.mem.Allocator) Error![]u8 {
        var scratch: [256]u8 = undefined;
        const got = dispatch(.network, 1, @intFromPtr(&scratch), scratch.len, 0);
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        return try allocator.dupe(u8, scratch[0..@min(got, scratch.len)]);
    }

    pub fn onChanged(comptime StatePtr: type, state: StatePtr, comptime handler: fn (StatePtr, []const u8) void) void {
        const S = struct {
            fn onNet(payload: []const u8, ud: usize) void {
                const s: StatePtr = @ptrFromInt(ud);
                handler(s, payload);
            }
        };
        const cb = registerNetworkHandler(&S.onNet, @intFromPtr(state));
        _ = dispatch(.network, 2, cb, 0, 0);
    }
};

pub const NowPlaying = struct {
    pub const MediaPlay: u32 = 1 << 0;
    pub const MediaPause: u32 = 1 << 1;
    pub const MediaTogglePlayPause: u32 = 1 << 2;
    pub const MediaStop: u32 = 1 << 3;
    pub const MediaNext: u32 = 1 << 4;
    pub const MediaPrevious: u32 = 1 << 5;
    pub const MediaSeek: u32 = 1 << 6;

    pub const PlaybackPlaying: i32 = 0;
    pub const PlaybackPaused: i32 = 1;
    pub const PlaybackStopped: i32 = 2;

    pub const Info = struct {
        title: []const u8 = "",
        artist: []const u8 = "",
        album: []const u8 = "",
        artwork: []const u8 = "",
        duration_ns: i64 = 0,
        position_ns: i64 = 0,
        rate: f64 = 0,
        state: i32 = PlaybackPlaying,
        commands: u32 = MediaPlay | MediaPause | MediaStop,
    };

    pub fn set(info: Info) void {
        const Spec = extern struct {
            title_ptr: usize = 0,
            title_len: usize = 0,
            artist_ptr: usize = 0,
            artist_len: usize = 0,
            album_ptr: usize = 0,
            album_len: usize = 0,
            artwork_ptr: usize = 0,
            artwork_len: usize = 0,
            duration_ns: i64 = 0,
            position_ns: i64 = 0,
            rate: f64 = 0,
            state: i32 = 0,
            commands: u32 = 0,
        };
        var spec = Spec{
            .title_ptr = sliceAddr(info.title),
            .title_len = info.title.len,
            .artist_ptr = sliceAddr(info.artist),
            .artist_len = info.artist.len,
            .album_ptr = sliceAddr(info.album),
            .album_len = info.album.len,
            .artwork_ptr = sliceAddr(info.artwork),
            .artwork_len = info.artwork.len,
            .duration_ns = info.duration_ns,
            .position_ns = info.position_ns,
            .rate = info.rate,
            .state = info.state,
            .commands = info.commands,
        };
        _ = dispatch(.now_playing, 1, @intFromPtr(&spec), 0, 0);
    }

    pub fn clear() void {
        _ = dispatch(.now_playing, 2, 0, 0, 0);
    }

    pub fn infoJSON(allocator: std.mem.Allocator) Error![]u8 {
        var scratch: [4096]u8 = undefined;
        const got = dispatch(.now_playing, 3, @intFromPtr(&scratch), scratch.len, 0);
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        return try allocator.dupe(u8, scratch[0..@min(got, scratch.len)]);
    }

    pub fn setPlayback(state: i32, position_ns: i64) void {
        _ = dispatch(.now_playing, 4, @intCast(state), @intCast(position_ns), 0);
    }

    pub fn onCommand(comptime StatePtr: type, state: StatePtr, comptime handler: fn (StatePtr, cmd: u32, position_ns: u64) void) void {
        const S = struct {
            fn onCmd(cmd: usize, pos: usize, ud: usize) void {
                const s: StatePtr = @ptrFromInt(ud);
                handler(s, @truncate(cmd), pos);
            }
        };
        const cb = registerNowPlayingHandler(&S.onCmd, @intFromPtr(state));
        _ = dispatch(.now_playing, 5, cb, 0, 0);
    }
};

pub const Fetch = struct {
    /// Performs one HTTP request. `headers_json` is `[["k","v"],...]` or "[]".
    /// `redirect` is "follow" (default), "error", or "manual".
    /// Returns JSON `{status,statusText,url,redirected,headers,body}` where
    /// `body` is standard JSON base64 for bytes. Caller owns the slice.
    pub fn request(
        allocator: std.mem.Allocator,
        url: []const u8,
        method: []const u8,
        headers_json: []const u8,
        body: []const u8,
        redirect: []const u8,
    ) Error![]u8 {
        const Spec = extern struct {
            url_ptr: usize = 0,
            url_len: usize = 0,
            method_ptr: usize = 0,
            method_len: usize = 0,
            headers_ptr: usize = 0,
            headers_len: usize = 0,
            body_ptr: usize = 0,
            body_len: usize = 0,
            redirect_ptr: usize = 0,
            redirect_len: usize = 0,
            out_ptr: usize = 0,
            out_cap: usize = 0,
        };
        var scratch: [1024 * 1024]u8 = undefined;
        var spec = Spec{
            .url_ptr = sliceAddr(url),
            .url_len = url.len,
            .method_ptr = sliceAddr(method),
            .method_len = method.len,
            .headers_ptr = sliceAddr(headers_json),
            .headers_len = headers_json.len,
            .body_ptr = sliceAddr(body),
            .body_len = body.len,
            .redirect_ptr = sliceAddr(redirect),
            .redirect_len = redirect.len,
            .out_ptr = @intFromPtr(&scratch),
            .out_cap = scratch.len,
        };
        const got = dispatch(.fetch, 1, @intFromPtr(&spec), 0, 0);
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        return try allocator.dupe(u8, scratch[0..@min(got, scratch.len)]);
    }
};

pub const WebSocket = struct {
    id: usize = 0,

    pub const Event = union(enum) {
        open: []const u8, // selected protocol
        text: []const u8,
        binary: []const u8,
        close: []const u8, // JSON {code,reason,clean,error}
    };

    pub fn connect(
        url: []const u8,
        protocols_json: []const u8,
        headers_json: []const u8,
        comptime StatePtr: type,
        state: StatePtr,
        comptime handler: fn (StatePtr, WebSocket, Event) void,
    ) Error!WebSocket {
        const S = struct {
            fn onWS(conn_id: usize, kind: u8, a3: usize, ud: usize) void {
                const s: StatePtr = @ptrFromInt(ud);
                const ws = WebSocket{ .id = conn_id };
                const payload = if (a3 != 0) blk: {
                    const cs: *const CStr = @ptrFromInt(a3);
                    break :blk cs.toSlice();
                } else "";
                switch (kind) {
                    1 => handler(s, ws, .{ .open = payload }),
                    2 => handler(s, ws, .{ .text = payload }),
                    3 => handler(s, ws, .{ .binary = payload }),
                    4 => handler(s, ws, .{ .close = payload }),
                    else => {},
                }
            }
        };
        const cb = registerWSHandler(&S.onWS, @intFromPtr(state));
        const Spec = extern struct {
            url_ptr: usize = 0,
            url_len: usize = 0,
            protocols_ptr: usize = 0,
            protocols_len: usize = 0,
            headers_ptr: usize = 0,
            headers_len: usize = 0,
            event_cb: usize = 0,
        };
        var spec = Spec{
            .url_ptr = sliceAddr(url),
            .url_len = url.len,
            .protocols_ptr = sliceAddr(protocols_json),
            .protocols_len = protocols_json.len,
            .headers_ptr = sliceAddr(headers_json),
            .headers_len = headers_json.len,
            .event_cb = cb,
        };
        const id = dispatch(.websocket, 1, @intFromPtr(&spec), 0, 0);
        if (id == std.math.maxInt(usize)) return Error.MyGoError;
        return .{ .id = id };
    }

    pub fn sendText(self: WebSocket, text: []const u8) Error!void {
        if (dispatch(.websocket, 2, self.id, sliceAddr(text), text.len) == std.math.maxInt(usize)) return Error.MyGoError;
    }

    pub fn sendBinary(self: WebSocket, data: []const u8) Error!void {
        if (dispatch(.websocket, 3, self.id, sliceAddr(data), data.len) == std.math.maxInt(usize)) return Error.MyGoError;
    }

    pub fn close(self: WebSocket, code: usize, reason: []const u8) Error!void {
        var cs = CStr.fromSlice(reason);
        if (dispatch(.websocket, 4, self.id, code, @intFromPtr(&cs)) == std.math.maxInt(usize)) return Error.MyGoError;
    }
};

pub const Updater = struct {
    pub fn checkForUpdates() void {
        _ = dispatch(.updater, 1, 0, 0, 0);
    }

    pub fn automaticChecks() bool {
        return dispatch(.updater, 2, 0, 0, 0) != 0;
    }

    pub fn setAutomaticChecks(on: bool) void {
        _ = dispatch(.updater, 3, @intFromBool(on), 0, 0);
    }

    pub fn automaticDownloads() bool {
        return dispatch(.updater, 4, 0, 0, 0) != 0;
    }

    pub fn setAutomaticDownloads(on: bool) void {
        _ = dispatch(.updater, 5, @intFromBool(on), 0, 0);
    }

    pub fn availableVersion(allocator: std.mem.Allocator) Error![]u8 {
        var scratch: [64]u8 = undefined;
        const got = dispatch(.updater, 6, @intFromPtr(&scratch), scratch.len, 0);
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        return try allocator.dupe(u8, scratch[0..@min(got, scratch.len)]);
    }
};

pub const Watch = struct {
    id: usize = 0,

    pub const Options = struct {
        recursive: bool = false,
        hints_only: bool = false,
        debounce_ms: i32 = 0, // 0 = host default (50ms); negative = immediate
        max_delay_ms: i32 = 0,
        max_entries: i32 = 0,
    };

    pub const Event = union(enum) {
        batch: []const u8, // JSON array of FileEvent
        done: []const u8, // empty = clean EOF; else error message
    };

    pub fn start(
        path: []const u8,
        opts: Options,
        comptime StatePtr: type,
        state: StatePtr,
        comptime handler: fn (StatePtr, Watch, Event) void,
    ) Error!Watch {
        const S = struct {
            fn onWatch(watch_id: usize, kind: u8, a3: usize, ud: usize) void {
                const s: StatePtr = @ptrFromInt(ud);
                const w = Watch{ .id = watch_id };
                const payload = if (a3 != 0) blk: {
                    const cs: *const CStr = @ptrFromInt(a3);
                    break :blk cs.toSlice();
                } else "";
                switch (kind) {
                    1 => handler(s, w, .{ .batch = payload }),
                    2 => handler(s, w, .{ .done = payload }),
                    else => {},
                }
            }
        };
        const cb = registerWatchHandler(&S.onWatch, @intFromPtr(state));
        const Spec = extern struct {
            path_ptr: usize = 0,
            path_len: usize = 0,
            event_cb: usize = 0,
            recursive: u8 = 0,
            hints_only: u8 = 0,
            _pad: [6]u8 = @splat(0),
            debounce_ms: i32 = 0,
            max_delay_ms: i32 = 0,
            max_entries: i32 = 0,
        };
        var spec = Spec{
            .path_ptr = sliceAddr(path),
            .path_len = path.len,
            .event_cb = cb,
            .recursive = @intFromBool(opts.recursive),
            .hints_only = @intFromBool(opts.hints_only),
            .debounce_ms = opts.debounce_ms,
            .max_delay_ms = opts.max_delay_ms,
            .max_entries = opts.max_entries,
        };
        const id = dispatch(.watch, 1, @intFromPtr(&spec), 0, 0);
        if (id == std.math.maxInt(usize)) return Error.MyGoError;
        return .{ .id = id };
    }

    pub fn close(self: Watch) void {
        _ = dispatch(.watch, 2, self.id, 0, 0);
    }
};

pub const PermissionFlow = struct {
    pub const Status = enum(u8) {
        unknown = 0,
        not_determined = 1,
        denied = 2,
        granted = 3,
    };

    pub fn check(name: []const u8) Error!Status {
        const v = dispatch(.permission_flow, 1, sliceAddr(name), name.len, 0);
        if (v == std.math.maxInt(usize)) return Error.MyGoError;
        return @enumFromInt(@as(u8, @truncate(v)));
    }

    pub fn allowed(name: []const u8) bool {
        return dispatch(.permission_flow, 2, sliceAddr(name), name.len, 0) != 0;
    }

    pub fn openSettings(name: []const u8) Error!void {
        if (dispatch(.permission_flow, 4, sliceAddr(name), name.len, 0) == std.math.maxInt(usize)) return Error.MyGoError;
    }

    fn kickAsync(
        sub: usize,
        name: []const u8,
        app: []const u8,
        label: []const u8,
        comptime StatePtr: type,
        state: StatePtr,
        comptime handler: fn (StatePtr, usize, Status, []const u8) void,
    ) Error!usize {
        const S = struct {
            fn onPerm(req_id: usize, status: u8, err_msg: []const u8, ud: usize) void {
                const s: StatePtr = @ptrFromInt(ud);
                handler(s, req_id, @enumFromInt(status), err_msg);
            }
        };
        const cb = registerPermFlowHandler(&S.onPerm, @intFromPtr(state));
        const Spec = extern struct {
            name_ptr: usize = 0,
            name_len: usize = 0,
            app_ptr: usize = 0,
            app_len: usize = 0,
            name_label_ptr: usize = 0,
            name_label_len: usize = 0,
            cb_id: usize = 0,
        };
        var spec = Spec{
            .name_ptr = sliceAddr(name),
            .name_len = name.len,
            .app_ptr = sliceAddr(app),
            .app_len = app.len,
            .name_label_ptr = sliceAddr(label),
            .name_label_len = label.len,
            .cb_id = cb,
        };
        const id = dispatch(.permission_flow, sub, @intFromPtr(&spec), 0, 0);
        if (id == std.math.maxInt(usize)) return Error.MyGoError;
        return id;
    }

    pub fn request(comptime StatePtr: type, state: StatePtr, name: []const u8, comptime handler: fn (StatePtr, usize, Status, []const u8) void) Error!usize {
        return kickAsync(3, name, "", "", StatePtr, state, handler);
    }

    pub fn guide(comptime StatePtr: type, state: StatePtr, name: []const u8, comptime handler: fn (StatePtr, usize, Status, []const u8) void) Error!usize {
        return kickAsync(5, name, "", "", StatePtr, state, handler);
    }

    pub fn wait(comptime StatePtr: type, state: StatePtr, name: []const u8, comptime handler: fn (StatePtr, usize, Status, []const u8) void) Error!usize {
        return kickAsync(6, name, "", "", StatePtr, state, handler);
    }
};

pub const SQLite = struct {
    id: usize = 0,

    pub fn open(path: []const u8, read_only: bool) Error!SQLite {
        const Spec = extern struct {
            path_ptr: usize = 0,
            path_len: usize = 0,
            read_only: u8 = 0,
            _pad: [7]u8 = @splat(0),
        };
        var spec = Spec{
            .path_ptr = sliceAddr(path),
            .path_len = path.len,
            .read_only = @intFromBool(read_only),
        };
        const id = dispatch(.sqlite, 1, @intFromPtr(&spec), 0, 0);
        if (id == std.math.maxInt(usize)) return Error.MyGoError;
        return .{ .id = id };
    }

    pub fn close(self: SQLite) void {
        _ = dispatch(.sqlite, 2, self.id, 0, 0);
    }

    /// Runs one statement. `args_json` is a JSON array ("[]" when none).
    /// Returns JSON `{changes,lastInsertId}` owned by `allocator`.
    pub fn execute(self: SQLite, allocator: std.mem.Allocator, sql: []const u8, args_json: []const u8) Error![]u8 {
        return self.call(allocator, 3, sql, args_json);
    }

    /// Returns JSON `{columns,rows}` owned by `allocator`.
    pub fn query(self: SQLite, allocator: std.mem.Allocator, sql: []const u8, args_json: []const u8) Error![]u8 {
        return self.call(allocator, 4, sql, args_json);
    }

    /// `stmts_json` is `[{{"sql":"...","args":[...]}}, ...]`.
    /// Returns JSON array of `{changes,lastInsertId}`.
    pub fn transaction(self: SQLite, allocator: std.mem.Allocator, stmts_json: []const u8) Error![]u8 {
        const Spec = extern struct {
            db_id: usize = 0,
            stmts_ptr: usize = 0,
            stmts_len: usize = 0,
            out_ptr: usize = 0,
            out_cap: usize = 0,
        };
        var scratch: [256 * 1024]u8 = undefined;
        var spec = Spec{
            .db_id = self.id,
            .stmts_ptr = sliceAddr(stmts_json),
            .stmts_len = stmts_json.len,
            .out_ptr = @intFromPtr(&scratch),
            .out_cap = scratch.len,
        };
        const got = dispatch(.sqlite, 5, @intFromPtr(&spec), 0, 0);
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        return try allocator.dupe(u8, scratch[0..@min(got, scratch.len)]);
    }

    fn call(self: SQLite, allocator: std.mem.Allocator, sub: usize, sql: []const u8, args_json: []const u8) Error![]u8 {
        const Spec = extern struct {
            db_id: usize = 0,
            sql_ptr: usize = 0,
            sql_len: usize = 0,
            args_ptr: usize = 0,
            args_len: usize = 0,
            out_ptr: usize = 0,
            out_cap: usize = 0,
        };
        var scratch: [256 * 1024]u8 = undefined;
        var spec = Spec{
            .db_id = self.id,
            .sql_ptr = sliceAddr(sql),
            .sql_len = sql.len,
            .args_ptr = sliceAddr(args_json),
            .args_len = args_json.len,
            .out_ptr = @intFromPtr(&scratch),
            .out_cap = scratch.len,
        };
        const got = dispatch(.sqlite, sub, @intFromPtr(&spec), 0, 0);
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        return try allocator.dupe(u8, scratch[0..@min(got, scratch.len)]);
    }
};

pub const Terminal = struct {
    id: usize = 0,

    pub const Options = struct {
        command: []const u8 = "", // NUL-separated argv; empty = user shell
        dir: []const u8 = "",
        shell_integration: bool = false,
        transparent: bool = false,
    };

    pub fn create(opts: Options) Error!Terminal {
        const Spec = extern struct {
            command_ptr: usize = 0,
            command_len: usize = 0,
            dir_ptr: usize = 0,
            dir_len: usize = 0,
            title_cb: usize = 0,
            exit_cb: usize = 0,
            bell_cb: usize = 0,
            shell_integration: u8 = 0,
            transparent: u8 = 0,
            _pad: [6]u8 = @splat(0),
        };
        var spec = Spec{
            .command_ptr = sliceAddr(opts.command),
            .command_len = opts.command.len,
            .dir_ptr = sliceAddr(opts.dir),
            .dir_len = opts.dir.len,
            .shell_integration = @intFromBool(opts.shell_integration),
            .transparent = @intFromBool(opts.transparent),
        };
        const id = dispatch(.terminal, 1, @intFromPtr(&spec), 0, 0);
        if (id == std.math.maxInt(usize)) return Error.MyGoError;
        return .{ .id = id };
    }

    /// Creates a terminal and registers title/exit/bell callbacks (same cb id).
    pub fn createWithEvents(
        opts: Options,
        comptime StatePtr: type,
        state: StatePtr,
        comptime handler: fn (StatePtr, Terminal, Event) void,
    ) Error!Terminal {
        const S = struct {
            fn onTerm(term_id: usize, kind: u8, a3: usize, ud: usize) void {
                const s: StatePtr = @ptrFromInt(ud);
                const term = Terminal{ .id = term_id };
                switch (kind) {
                    1 => {
                        const title_text = if (a3 != 0) blk: {
                            const cs: *const CStr = @ptrFromInt(a3);
                            break :blk cs.toSlice();
                        } else "";
                        handler(s, term, .{ .title = title_text });
                    },
                    2 => handler(s, term, .{ .exit = @intCast(a3) }),
                    3 => handler(s, term, .bell),
                    else => {},
                }
            }
        };
        const cb = registerTerminalHandler(&S.onTerm, @intFromPtr(state));
        const Spec = extern struct {
            command_ptr: usize = 0,
            command_len: usize = 0,
            dir_ptr: usize = 0,
            dir_len: usize = 0,
            title_cb: usize = 0,
            exit_cb: usize = 0,
            bell_cb: usize = 0,
            shell_integration: u8 = 0,
            transparent: u8 = 0,
            _pad: [6]u8 = @splat(0),
        };
        var spec = Spec{
            .command_ptr = sliceAddr(opts.command),
            .command_len = opts.command.len,
            .dir_ptr = sliceAddr(opts.dir),
            .dir_len = opts.dir.len,
            .title_cb = cb,
            .exit_cb = cb,
            .bell_cb = cb,
            .shell_integration = @intFromBool(opts.shell_integration),
            .transparent = @intFromBool(opts.transparent),
        };
        const id = dispatch(.terminal, 1, @intFromPtr(&spec), 0, 0);
        if (id == std.math.maxInt(usize)) return Error.MyGoError;
        return .{ .id = id };
    }

    pub const Event = union(enum) {
        title: []const u8,
        exit: usize,
        bell,
    };

    pub fn close(self: Terminal) void {
        _ = dispatch(.terminal, 2, self.id, 0, 0);
    }

    pub fn paste(self: Terminal, text: []const u8) void {
        _ = dispatch(.terminal, 3, self.id, sliceAddr(text), text.len);
    }

    pub fn send(self: Terminal, data: []const u8) void {
        _ = dispatch(.terminal, 4, self.id, sliceAddr(data), data.len);
    }

    pub fn useDarkTheme(self: Terminal) void {
        _ = dispatch(.terminal, 5, self.id, 0, 0);
    }

    pub fn useLightTheme(self: Terminal) void {
        _ = dispatch(.terminal, 5, self.id, 1, 0);
    }

    pub fn useGhosttyTheme(self: Terminal, name: []const u8) Error!void {
        var cs = CStr.fromSlice(name);
        if (dispatch(.terminal, 5, self.id, 2, @intFromPtr(&cs)) == std.math.maxInt(usize)) return Error.MyGoError;
    }

    pub fn resize(self: Terminal, cols: i32, rows: i32) void {
        _ = dispatch(.terminal, 6, self.id, @intCast(cols), @intCast(rows));
    }

    pub fn title(self: Terminal, allocator: std.mem.Allocator) Error![]u8 {
        var scratch: [1024]u8 = undefined;
        const got = dispatch(.terminal, 7, self.id, @intFromPtr(&scratch), scratch.len);
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        return try allocator.dupe(u8, scratch[0..@min(got, scratch.len)]);
    }

    pub fn dir(self: Terminal, allocator: std.mem.Allocator) Error![]u8 {
        var scratch: [4096]u8 = undefined;
        const got = dispatch(.terminal, 8, self.id, @intFromPtr(&scratch), scratch.len);
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        return try allocator.dupe(u8, scratch[0..@min(got, scratch.len)]);
    }

    /// null when the program is still running.
    pub fn exitCode(self: Terminal) ?usize {
        const v = dispatch(.terminal, 9, self.id, 0, 0);
        if (v == std.math.maxInt(usize)) return null;
        return v;
    }

    pub fn clearScreen(self: Terminal) void {
        _ = dispatch(.terminal, 10, self.id, 0, 0);
    }

    pub fn search(self: Terminal, query: []const u8) void {
        _ = dispatch(.terminal, 11, self.id, sliceAddr(query), query.len);
    }

    pub fn endSearch(self: Terminal) void {
        _ = dispatch(.terminal, 11, self.id, 0, 0);
    }
};

pub const Lifecycle = struct {
    fn cstrSlice(ptr: usize) []const u8 {
        if (ptr == 0) return "";
        const cs: *const CStr = @ptrFromInt(ptr);
        return cs.toSlice();
    }

    pub fn onActivate(comptime StatePtr: type, state: StatePtr, comptime handler: fn (StatePtr, bool) void) void {
        const S = struct {
            fn onApp(kind: u8, a2: usize, _: usize, ud: usize) usize {
                if (kind != 1) return 0;
                const s: StatePtr = @ptrFromInt(ud);
                handler(s, a2 != 0);
                return 0;
            }
        };
        const cb = registerAppHandler(&S.onApp, @intFromPtr(state));
        _ = dispatch(.app_events, 1, cb, 0, 0);
    }

    pub fn onDidBecomeActive(comptime StatePtr: type, state: StatePtr, comptime handler: fn (StatePtr) void) void {
        const S = struct {
            fn onApp(kind: u8, _: usize, _: usize, ud: usize) usize {
                if (kind != 2) return 0;
                const s: StatePtr = @ptrFromInt(ud);
                handler(s);
                return 0;
            }
        };
        const cb = registerAppHandler(&S.onApp, @intFromPtr(state));
        _ = dispatch(.app_events, 2, cb, 0, 0);
    }

    pub fn onDidResignActive(comptime StatePtr: type, state: StatePtr, comptime handler: fn (StatePtr) void) void {
        const S = struct {
            fn onApp(kind: u8, _: usize, _: usize, ud: usize) usize {
                if (kind != 3) return 0;
                const s: StatePtr = @ptrFromInt(ud);
                handler(s);
                return 0;
            }
        };
        const cb = registerAppHandler(&S.onApp, @intFromPtr(state));
        _ = dispatch(.app_events, 3, cb, 0, 0);
    }

    /// Handler returns true to cancel quit.
    pub fn onBeforeQuit(comptime StatePtr: type, state: StatePtr, comptime handler: fn (StatePtr) bool) void {
        const S = struct {
            fn onApp(kind: u8, _: usize, _: usize, ud: usize) usize {
                if (kind != 4) return 0;
                const s: StatePtr = @ptrFromInt(ud);
                return if (handler(s)) 1 else 0;
            }
        };
        const cb = registerAppHandler(&S.onApp, @intFromPtr(state));
        _ = dispatch(.app_events, 4, cb, 0, 0);
    }

    pub fn onWillQuit(comptime StatePtr: type, state: StatePtr, comptime handler: fn (StatePtr) bool) void {
        const S = struct {
            fn onApp(kind: u8, _: usize, _: usize, ud: usize) usize {
                if (kind != 5) return 0;
                const s: StatePtr = @ptrFromInt(ud);
                return if (handler(s)) 1 else 0;
            }
        };
        const cb = registerAppHandler(&S.onApp, @intFromPtr(state));
        _ = dispatch(.app_events, 5, cb, 0, 0);
    }

    pub fn onOpenURL(comptime StatePtr: type, state: StatePtr, comptime handler: fn (StatePtr, []const u8) void) void {
        const S = struct {
            fn onApp(kind: u8, a2: usize, _: usize, ud: usize) usize {
                if (kind != 6) return 0;
                const s: StatePtr = @ptrFromInt(ud);
                handler(s, cstrSlice(a2));
                return 0;
            }
        };
        const cb = registerAppHandler(&S.onApp, @intFromPtr(state));
        _ = dispatch(.app_events, 6, cb, 0, 0);
    }

    pub fn onOpenFile(comptime StatePtr: type, state: StatePtr, comptime handler: fn (StatePtr, []const u8) void) void {
        const S = struct {
            fn onApp(kind: u8, a2: usize, _: usize, ud: usize) usize {
                if (kind != 7) return 0;
                const s: StatePtr = @ptrFromInt(ud);
                handler(s, cstrSlice(a2));
                return 0;
            }
        };
        const cb = registerAppHandler(&S.onApp, @intFromPtr(state));
        _ = dispatch(.app_events, 7, cb, 0, 0);
    }

    /// Payload is JSON `{args:[],wd:""}`.
    pub fn onSecondInstance(comptime StatePtr: type, state: StatePtr, comptime handler: fn (StatePtr, []const u8) void) void {
        const S = struct {
            fn onApp(kind: u8, a2: usize, _: usize, ud: usize) usize {
                if (kind != 8) return 0;
                const s: StatePtr = @ptrFromInt(ud);
                handler(s, cstrSlice(a2));
                return 0;
            }
        };
        const cb = registerAppHandler(&S.onApp, @intFromPtr(state));
        _ = dispatch(.app_events, 8, cb, 0, 0);
    }

    /// Returns true if this is the first instance.
    pub fn requestSingleInstanceLock() bool {
        return dispatch(.app_events, 9, 0, 0, 0) != 0;
    }

    pub fn showAbout(opts: struct {
        name: []const u8 = "",
        version: []const u8 = "",
        copyright: []const u8 = "",
        credits: []const u8 = "",
    }) void {
        const Spec = extern struct {
            name_ptr: usize = 0,
            name_len: usize = 0,
            version_ptr: usize = 0,
            version_len: usize = 0,
            copyright_ptr: usize = 0,
            copyright_len: usize = 0,
            credits_ptr: usize = 0,
            credits_len: usize = 0,
        };
        var spec = Spec{
            .name_ptr = sliceAddr(opts.name),
            .name_len = opts.name.len,
            .version_ptr = sliceAddr(opts.version),
            .version_len = opts.version.len,
            .copyright_ptr = sliceAddr(opts.copyright),
            .copyright_len = opts.copyright.len,
            .credits_ptr = sliceAddr(opts.credits),
            .credits_len = opts.credits.len,
        };
        _ = dispatch(.app_events, 10, @intFromPtr(&spec), 0, 0);
    }

    pub fn setBadge(text: []const u8) void {
        _ = dispatch(.app_events, 11, sliceAddr(text), text.len, 0);
    }

    pub fn badge(allocator: std.mem.Allocator) Error![]u8 {
        var scratch: [256]u8 = undefined;
        const got = dispatch(.app_events, 12, @intFromPtr(&scratch), scratch.len, 0);
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        const n = @min(got, scratch.len);
        return try allocator.dupe(u8, scratch[0..n]);
    }

    pub fn bounce(critical: bool) usize {
        return dispatch(.app_events, 13, @intFromBool(critical), 0, 0);
    }

    pub fn cancelBounce(id: usize) void {
        _ = dispatch(.app_events, 14, id, 0, 0);
    }

    pub fn registerURLScheme(scheme: []const u8) Error!void {
        if (dispatch(.app_events, 15, sliceAddr(scheme), scheme.len, 0) == std.math.maxInt(usize)) return Error.MyGoError;
    }

    pub fn unregisterURLScheme(scheme: []const u8) Error!void {
        if (dispatch(.app_events, 16, sliceAddr(scheme), scheme.len, 0) == std.math.maxInt(usize)) return Error.MyGoError;
    }

    pub fn isURLSchemeRegistered(scheme: []const u8) bool {
        return dispatch(.app_events, 17, sliceAddr(scheme), scheme.len, 0) != 0;
    }

    pub fn setOpenAtLogin(open: bool) Error!void {
        if (dispatch(.app_events, 18, @intFromBool(open), 0, 0) == std.math.maxInt(usize)) return Error.MyGoError;
    }

    pub fn openAtLogin() bool {
        return dispatch(.app_events, 19, 0, 0, 0) != 0;
    }

    pub fn wasOpenedAtLogin() bool {
        return dispatch(.app_events, 20, 0, 0, 0) != 0;
    }

    pub fn relaunch() void {
        _ = dispatch(.app_events, 21, 0, 0, 0);
    }

    pub fn hide() void { _ = dispatch(.app_events, 22, 0, 0, 0); }
    pub fn show() void { _ = dispatch(.app_events, 23, 0, 0, 0); }
    pub fn isHidden() bool { return dispatch(.app_events, 24, 0, 0, 0) != 0; }
    pub fn focus() void { _ = dispatch(.app_events, 25, 0, 0, 0); }
    pub fn isActive() bool { return dispatch(.app_events, 26, 0, 0, 0) != 0; }
    pub fn isReady() bool { return dispatch(.app_events, 27, 0, 0, 0) != 0; }
    pub fn isPackaged() bool { return dispatch(.app_events, 28, 0, 0, 0) != 0; }

    pub fn name(allocator: std.mem.Allocator) Error![]u8 {
        var scratch: [256]u8 = undefined;
        const got = dispatch(.app_events, 29, @intFromPtr(&scratch), scratch.len, 0);
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        return try allocator.dupe(u8, scratch[0..@min(got, scratch.len)]);
    }
    pub fn version(allocator: std.mem.Allocator) Error![]u8 {
        var scratch: [64]u8 = undefined;
        const got = dispatch(.app_events, 30, @intFromPtr(&scratch), scratch.len, 0);
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        return try allocator.dupe(u8, scratch[0..@min(got, scratch.len)]);
    }
    pub fn setVersion(v: []const u8) void { _ = dispatch(.app_events, 31, sliceAddr(v), v.len, 0); }
    pub fn exit(code: usize) void { _ = dispatch(.app_events, 32, code, 0, 0); }

    pub fn activationPolicy(allocator: std.mem.Allocator) Error![]u8 {
        var scratch: [32]u8 = undefined;
        const got = dispatch(.app_events, 33, @intFromPtr(&scratch), scratch.len, 0);
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        return try allocator.dupe(u8, scratch[0..@min(got, scratch.len)]);
    }
    pub fn setActivationPolicy(policy: []const u8) void {
        _ = dispatch(.app_events, 34, sliceAddr(policy), policy.len, 0);
    }

    pub fn regionJSON(allocator: std.mem.Allocator) Error![]u8 {
        var scratch: [512]u8 = undefined;
        const got = dispatch(.app_events, 35, @intFromPtr(&scratch), scratch.len, 0);
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        return try allocator.dupe(u8, scratch[0..@min(got, scratch.len)]);
    }

    pub fn onQuit(comptime StatePtr: type, state: StatePtr, comptime handler: fn (StatePtr) void) void {
        const S = struct {
            fn onApp(kind: u8, _: usize, _: usize, ud: usize) usize {
                if (kind != 9) return 0;
                const s: StatePtr = @ptrFromInt(ud);
                handler(s);
                return 0;
            }
        };
        const cb = registerAppHandler(&S.onApp, @intFromPtr(state));
        _ = dispatch(.app_events, 36, cb, 0, 0);
    }
    pub fn onReady(comptime StatePtr: type, state: StatePtr, comptime handler: fn (StatePtr) void) void {
        const S = struct {
            fn onApp(kind: u8, _: usize, _: usize, ud: usize) usize {
                if (kind != 10) return 0;
                const s: StatePtr = @ptrFromInt(ud);
                handler(s);
                return 0;
            }
        };
        const cb = registerAppHandler(&S.onApp, @intFromPtr(state));
        _ = dispatch(.app_events, 37, cb, 0, 0);
    }
    pub fn onWindowAllClosed(comptime StatePtr: type, state: StatePtr, comptime handler: fn (StatePtr) void) void {
        const S = struct {
            fn onApp(kind: u8, _: usize, _: usize, ud: usize) usize {
                if (kind != 11) return 0;
                const s: StatePtr = @ptrFromInt(ud);
                handler(s);
                return 0;
            }
        };
        const cb = registerAppHandler(&S.onApp, @intFromPtr(state));
        _ = dispatch(.app_events, 38, cb, 0, 0);
    }
    pub fn onWindowCreated(comptime StatePtr: type, state: StatePtr, comptime handler: fn (StatePtr, i32) void) void {
        const S = struct {
            fn onApp(kind: u8, a2: usize, _: usize, ud: usize) usize {
                if (kind != 12) return 0;
                const s: StatePtr = @ptrFromInt(ud);
                handler(s, @intCast(@as(isize, @bitCast(a2))));
                return 0;
            }
        };
        const cb = registerAppHandler(&S.onApp, @intFromPtr(state));
        _ = dispatch(.app_events, 39, cb, 0, 0);
    }
    pub fn onRegionChanged(comptime StatePtr: type, state: StatePtr, comptime handler: fn (StatePtr, []const u8) void) void {
        const S = struct {
            fn onReg(json: []const u8, ud: usize) void {
                const s: StatePtr = @ptrFromInt(ud);
                handler(s, json);
            }
        };
        const cb = registerRegionHandler(&S.onReg, @intFromPtr(state));
        _ = dispatch(.app_events, 40, cb, 0, 0);
    }
};

pub const Appearance = struct {
    pub fn isDark() bool {
        return dispatch(.theme, 1, 0, 0, 0) != 0;
    }

    pub fn source(allocator: std.mem.Allocator) Error![]u8 {
        var scratch: [32]u8 = undefined;
        const got = dispatch(.theme, 2, @intFromPtr(&scratch), scratch.len, 0);
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        const n = @min(got, scratch.len);
        return try allocator.dupe(u8, scratch[0..n]);
    }

    /// "system", "light", or "dark".
    pub fn setSource(src: []const u8) void {
        _ = dispatch(.theme, 3, sliceAddr(src), src.len, 0);
    }

    /// Preferences JSON (caller owns).
    pub fn preferencesJSON(allocator: std.mem.Allocator) Error![]u8 {
        var scratch: [2048]u8 = undefined;
        const got = dispatch(.theme, 4, @intFromPtr(&scratch), scratch.len, 0);
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        const n = @min(got, scratch.len);
        return try allocator.dupe(u8, scratch[0..n]);
    }

    pub fn onUpdated(comptime StatePtr: type, state: StatePtr, comptime handler: fn (StatePtr) void) void {
        const S = struct {
            fn onTheme(ud: usize) void {
                const s: StatePtr = @ptrFromInt(ud);
                handler(s);
            }
        };
        const cb = registerThemeHandler(&S.onTheme, @intFromPtr(state));
        _ = dispatch(.theme, 5, cb, 0, 0);
    }
};

pub const Power = struct {
    pub fn isOnBattery() bool {
        return dispatch(.power, 1, 0, 0, 0) != 0;
    }

    pub fn idleMs() usize {
        return dispatch(.power, 2, 0, 0, 0);
    }

    /// Keep the machine awake; call `release(token)` when done.
    pub fn keepAwake(reason: []const u8, display: bool) usize {
        return dispatch(.power, 3, sliceAddr(reason), reason.len, @intFromBool(display));
    }

    pub fn release(token: usize) void {
        _ = dispatch(.power, 4, token, 0, 0);
    }

    pub fn onEvent(comptime StatePtr: type, state: StatePtr, comptime handler: fn (StatePtr, []const u8) void) void {
        const S = struct {
            fn onPower(ev: []const u8, ud: usize) void {
                const s: StatePtr = @ptrFromInt(ud);
                handler(s, ev);
            }
        };
        const cb = registerPowerHandler(&S.onPower, @intFromPtr(state));
        _ = dispatch(.power, 5, cb, 0, 0);
    }
};

pub const Path = struct {
    /// Well-known directory name: home, appData, userData, cache, logs,
    /// resources, temp, exe, desktop, documents, downloads, music, pictures, videos.
    pub fn get(allocator: std.mem.Allocator, name: []const u8) Error![]u8 {
        var name_cs = CStr.fromSlice(name);
        var scratch: [4096]u8 = undefined;
        const got = dispatch(.path, 1, @intFromPtr(&name_cs), @intFromPtr(&scratch), scratch.len);
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        const n = @min(got, scratch.len);
        return try allocator.dupe(u8, scratch[0..n]);
    }

    pub fn set(name: []const u8, path: []const u8) void {
        var name_cs = CStr.fromSlice(name);
        var path_cs = CStr.fromSlice(path);
        _ = dispatch(.path, 2, @intFromPtr(&name_cs), @intFromPtr(&path_cs), 0);
    }
};

pub const Point = struct {
    x: i32 = 0,
    y: i32 = 0,
};

pub const Screen = struct {
    const CPoint = extern struct { x: i32 = 0, y: i32 = 0 };

    /// JSON array of displays (caller owns). Fields: id,label,bounds,workArea,scaleFactor,rotation,internal,primary.
    pub fn displaysJSON(allocator: std.mem.Allocator) Error![]u8 {
        var scratch: [16384]u8 = undefined;
        const got = dispatch(.screen, 1, @intFromPtr(&scratch), scratch.len, 0);
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        const n = @min(got, scratch.len);
        return try allocator.dupe(u8, scratch[0..n]);
    }

    pub fn cursor() Point {
        var p: CPoint = .{};
        _ = dispatch(.screen, 2, @intFromPtr(&p), 0, 0);
        return .{ .x = p.x, .y = p.y };
    }
};

pub const Hotkey = struct {
    pub fn register(comptime StatePtr: type, state: StatePtr, accelerator: []const u8, comptime handler: fn (StatePtr) void) Error!void {
        const S = struct {
            fn onHotkey(ud: usize) void {
                const s: StatePtr = @ptrFromInt(ud);
                handler(s);
            }
        };
        const cb = registerHotkeyHandler(&S.onHotkey, @intFromPtr(state));
        if (dispatch(.hotkey, 1, sliceAddr(accelerator), accelerator.len, cb) == std.math.maxInt(usize)) {
            return Error.MyGoError;
        }
    }

    pub fn unregister(accelerator: []const u8) void {
        _ = dispatch(.hotkey, 2, sliceAddr(accelerator), accelerator.len, 0);
    }

    pub fn unregisterAll() void {
        _ = dispatch(.hotkey, 3, 0, 0, 0);
    }

    pub fn isRegistered(accelerator: []const u8) bool {
        return dispatch(.hotkey, 4, sliceAddr(accelerator), accelerator.len, 0) != 0;
    }
};

pub const Clipboard = struct {
    pub fn writeText(text: []const u8) void {
        _ = dispatch(.clipboard, 1, sliceAddr(text), text.len, 0);
    }

    pub fn clear() void {
        _ = dispatch(.clipboard, 2, 0, 0, 0);
    }

    pub fn readText(allocator: std.mem.Allocator) Error![]u8 {
        return readBytes(allocator, 3);
    }

    pub fn writeImage(png: []const u8) Error!void {
        if (dispatch(.clipboard, 4, sliceAddr(png), png.len, 0) == std.math.maxInt(usize)) return Error.MyGoError;
    }

    pub fn readImage(allocator: std.mem.Allocator) Error![]u8 {
        return readBytes(allocator, 5);
    }

    pub fn availableFormatsJSON(allocator: std.mem.Allocator) Error![]u8 {
        var scratch: [4096]u8 = undefined;
        const got = dispatch(.clipboard, 6, @intFromPtr(&scratch), scratch.len, 0);
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        const n = @min(got, scratch.len);
        return try allocator.dupe(u8, scratch[0..n]);
    }

    fn readBytes(allocator: std.mem.Allocator, sub: usize) Error![]u8 {
        const Capture = struct {
            alloc: std.mem.Allocator,
            result: ?[]u8 = null,
            oom: bool = false,

            fn handle(bytes: []const u8, ud: usize) void {
                const self: *@This() = @ptrFromInt(ud);
                self.result = self.alloc.dupe(u8, bytes) catch {
                    self.oom = true;
                    return;
                };
            }
        };
        const S = struct {
            var cb_id: usize = 0;
        };
        if (S.cb_id == 0) {
            S.cb_id = registerBytesHandler(&Capture.handle);
        }
        var cap = Capture{ .alloc = allocator };
        _ = dispatch(.clipboard, sub, S.cb_id, @intFromPtr(&cap), 0);
        if (cap.oom) return Error.OutOfMemory;
        return cap.result orelse (allocator.dupe(u8, "") catch Error.OutOfMemory);
    }

    pub fn readFilesJSON(allocator: std.mem.Allocator) Error![]u8 {
        var scratch: [65536]u8 = undefined;
        const got = dispatch(.clipboard, 7, @intFromPtr(&scratch), scratch.len, 0);
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        return try allocator.dupe(u8, scratch[0..@min(got, scratch.len)]);
    }

    pub fn writeFilesJSON(paths_json: []const u8) Error!void {
        if (dispatch(.clipboard, 8, sliceAddr(paths_json), paths_json.len, 0) == std.math.maxInt(usize)) return Error.MyGoError;
    }

    pub fn writeHTML(markup: []const u8) void {
        _ = dispatch(.clipboard, 9, sliceAddr(markup), markup.len, 0);
    }

    pub fn readHTML(allocator: std.mem.Allocator) Error![]u8 {
        return readBytes(allocator, 10);
    }

    pub fn flush() Error!void {
        if (dispatch(.clipboard, 11, 0, 0, 0) == std.math.maxInt(usize)) return Error.MyGoError;
    }

    /// Write custom MIME: JSON object `{ "text/plain": "<base64>", ... }`.
    pub fn writeMIMEJSON(map_json: []const u8) Error!void {
        if (dispatch(.clipboard, 12, sliceAddr(map_json), map_json.len, 0) == std.math.maxInt(usize)) return Error.MyGoError;
    }

    /// Read MIME formats. `formats_json` is a JSON array of format strings; "[]" reads all.
    /// Returns JSON object format→base64. Caller owns the slice.
    pub fn readMIMEJSON(allocator: std.mem.Allocator, formats_json: []const u8) Error![]u8 {
        const Spec = extern struct {
            formats_ptr: usize = 0,
            formats_len: usize = 0,
            out_ptr: usize = 0,
            out_cap: usize = 0,
        };
        var scratch: [1024 * 1024]u8 = undefined;
        var spec = Spec{
            .formats_ptr = sliceAddr(formats_json),
            .formats_len = formats_json.len,
            .out_ptr = @intFromPtr(&scratch),
            .out_cap = scratch.len,
        };
        const got = dispatch(.clipboard, 13, @intFromPtr(&spec), 0, 0);
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        return try allocator.dupe(u8, scratch[0..@min(got, scratch.len)]);
    }
};

pub const Shell = struct {
    pub fn openExternal(url: []const u8) Error!void {
        if (dispatch(.shell, 1, sliceAddr(url), url.len, 0) != 0) return Error.MyGoError;
    }

    pub fn openPath(path: []const u8) Error!void {
        if (dispatch(.shell, 2, sliceAddr(path), path.len, 0) != 0) return Error.MyGoError;
    }

    pub fn beep() void {
        _ = dispatch(.shell, 3, 0, 0, 0);
    }

    pub fn showItemInFolder(path: []const u8) void {
        _ = dispatch(.shell, 4, sliceAddr(path), path.len, 0);
    }

    pub fn trashItem(path: []const u8) Error!void {
        if (dispatch(.shell, 5, sliceAddr(path), path.len, 0) == std.math.maxInt(usize)) return Error.MyGoError;
    }

    pub fn fileIconPNG(allocator: std.mem.Allocator, path: []const u8, size: i32) Error![]u8 {
        const Spec = extern struct {
            path_ptr: usize = 0,
            path_len: usize = 0,
            size: i32 = 0,
            _pad: [4]u8 = @splat(0),
            out_ptr: usize = 0,
            out_cap: usize = 0,
        };
        var scratch: [1024 * 1024]u8 = undefined;
        var spec = Spec{
            .path_ptr = sliceAddr(path),
            .path_len = path.len,
            .size = size,
            .out_ptr = @intFromPtr(&scratch),
            .out_cap = scratch.len,
        };
        const got = dispatch(.shell, 6, @intFromPtr(&spec), 0, 0);
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        return try allocator.dupe(u8, scratch[0..@min(got, scratch.len)]);
    }

    pub fn typeIconPNG(allocator: std.mem.Allocator, ext: []const u8, size: i32) Error![]u8 {
        const Spec = extern struct {
            path_ptr: usize = 0,
            path_len: usize = 0,
            size: i32 = 0,
            _pad: [4]u8 = @splat(0),
            out_ptr: usize = 0,
            out_cap: usize = 0,
        };
        var scratch: [1024 * 1024]u8 = undefined;
        var spec = Spec{
            .path_ptr = sliceAddr(ext),
            .path_len = ext.len,
            .size = size,
            .out_ptr = @intFromPtr(&scratch),
            .out_cap = scratch.len,
        };
        const got = dispatch(.shell, 7, @intFromPtr(&spec), 0, 0);
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        return try allocator.dupe(u8, scratch[0..@min(got, scratch.len)]);
    }

    /// JSON array of {name,id,path}. Call from a worker if the list is large.
    pub fn installedAppsJSON(allocator: std.mem.Allocator) Error![]u8 {
        var scratch: [1024 * 1024]u8 = undefined;
        const got = dispatch(.shell, 8, @intFromPtr(&scratch), scratch.len, 0);
        if (got == std.math.maxInt(usize)) return Error.MyGoError;
        return try allocator.dupe(u8, scratch[0..@min(got, scratch.len)]);
    }

    /// `app_json` is one InstalledApp object, typically `{ "path": "..." }`.
    pub fn launchAppJSON(app_json: []const u8) Error!void {
        if (dispatch(.shell, 9, sliceAddr(app_json), app_json.len, 0) == std.math.maxInt(usize)) return Error.MyGoError;
    }

    /// Windows .lnk; ErrUnsupported elsewhere. JSON ShortcutLinkOptions.
    pub fn writeShortcutLinkJSON(opts_json: []const u8) Error!void {
        if (dispatch(.shell, 10, sliceAddr(opts_json), opts_json.len, 0) == std.math.maxInt(usize)) return Error.MyGoError;
    }

    pub const ShortcutLink = struct {
        link_path: []const u8,
        target: []const u8,
        args: []const []const u8 = &.{},
        working_dir: []const u8 = "",
        description: []const u8 = "",
        icon_path: []const u8 = "",
        icon_index: i32 = 0,
    };

    /// Typed Windows .lnk writer (builds JSON for writeShortcutLinkJSON).
    pub fn writeShortcutLink(allocator: std.mem.Allocator, opts: ShortcutLink) Error!void {
        var list: std.ArrayList(u8) = .empty;
        defer list.deinit(allocator);
        try std.json.Stringify.value(.{
            .linkPath = opts.link_path,
            .target = opts.target,
            .args = opts.args,
            .workingDir = opts.working_dir,
            .description = opts.description,
            .iconPath = opts.icon_path,
            .iconIndex = opts.icon_index,
        }, .{}, list.writer(allocator));
        try writeShortcutLinkJSON(list.items);
    }
};

pub fn setName(name: []const u8) void {
    _ = dispatch(.set_name, sliceAddr(name), name.len, 0, 0);
}

pub fn quit() void {
    _ = dispatch(.quit, 0, 0, 0, 0);
}

pub fn lastError(buf: []u8) []const u8 {
    const total = dispatch(.last_error, if (buf.len > 0) @intFromPtr(buf.ptr) else 0, buf.len, 0, 0);
    const n = @min(total, buf.len);
    return buf[0..n];
}

pub fn addEmbeddedAsset(path: []const u8, comptime data: []const u8) Error!void {
    var spec = CAssetSpec{
        .path = CStr.fromSlice(path),
        .data = sliceAddr(data),
        .data_len = data.len,
        .static_lifetime = 1,
    };
    if (dispatch(.frontend_asset, @intFromPtr(&spec), 0, 0, 0) != 0) {
        return Error.MyGoError;
    }
}

pub fn newWindow(opts: WindowOptions) Error!Window {
    var raw = opts.toC();
    const id: i32 = @intCast(@as(isize, @bitCast(dispatch(.window_new, @intFromPtr(&raw), 0, 0, 0))));
    if (id <= 0) return Error.MyGoError;
    return .{ .id = id };
}

pub fn newWindowUi(
    comptime StatePtr: type,
    state: StatePtr,
    opts: WindowOptions,
    comptime viewFn: fn (StatePtr, *ui.Context) void,
) Error!Window {
    const Trampoline = struct {
        fn onView(frame_handle: usize, info: *const ui.CFrameInfo, ud: usize) void {
            const s: StatePtr = @ptrFromInt(ud);
            var ctx = ui.Context.init(frame_handle, info);
            viewFn(s, &ctx);
            ctx.flush();
        }
    };
    ui_view_handlers[ui_view_count] = &Trampoline.onView;
    ui_view_count += 1;
    var raw = opts.toC();
    const id: i32 = @intCast(@as(isize, @bitCast(dispatch(
        .window_new_ui,
        @intFromPtr(&raw),
        ui_view_count,
        @intFromPtr(state),
        0,
    ))));
    if (id <= 0) return Error.MyGoError;
    return .{ .id = id };
}


pub const FlyoutFlag = struct {
    pub const focusable: u32 = 1;
    pub const hidden: u32 = 2;
    pub const shadow: u32 = 4;
    pub const popover: u32 = 8;
    pub const fit_content: u32 = 16;
};

pub const FlyoutOptions = struct {
    parent: ?Window = null,
    tray: ?Tray = null,
    anchor: Rectangle = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
    placement: []const u8 = "bottom-start",
    gap: i32 = 4,
    width: i32 = 280,
    height: i32 = 200,
    min_width: i32 = 0,
    min_height: i32 = 0,
    max_width: i32 = 0,
    max_height: i32 = 0,
    corner_radius: i32 = 0,
    flags: u32 = FlyoutFlag.focusable | FlyoutFlag.shadow,
    vibrancy: []const u8 = "",
};

const CFlyoutSpec = extern struct {
    parent_win_id: usize = 0,
    tray_id: usize = 0,
    anchor: CBounds = .{},
    width: i32 = 0,
    height: i32 = 0,
    gap: i32 = 0,
    min_width: i32 = 0,
    min_height: i32 = 0,
    max_width: i32 = 0,
    max_height: i32 = 0,
    corner_radius: i32 = 0,
    placement_ptr: usize = 0,
    placement_len: usize = 0,
    flags: u32 = 0,
    vibrancy_ptr: usize = 0,
    vibrancy_len: usize = 0,
};

/// Create a flyout window with Native UI content (same view callback as `newWindowUi`).
/// Provide exactly one of `opts.parent` or `opts.tray`.
pub fn newFlyoutUi(
    comptime StatePtr: type,
    state: StatePtr,
    opts: FlyoutOptions,
    comptime viewFn: fn (StatePtr, *ui.Context) void,
) Error!Window {
    if ((opts.parent == null) == (opts.tray == null)) return Error.MyGoError;
    const Trampoline = struct {
        fn onView(frame_handle: usize, info: *const ui.CFrameInfo, ud: usize) void {
            const s: StatePtr = @ptrFromInt(ud);
            var ctx = ui.Context.init(frame_handle, info);
            viewFn(s, &ctx);
            ctx.flush();
        }
    };
    ui_view_handlers[ui_view_count] = &Trampoline.onView;
    ui_view_count += 1;
    var spec = CFlyoutSpec{
        .parent_win_id = if (opts.parent) |w| @intCast(w.id) else 0,
        .tray_id = if (opts.tray) |tr| tr.id else 0,
        .anchor = .{ .x = opts.anchor.x, .y = opts.anchor.y, .width = opts.anchor.width, .height = opts.anchor.height },
        .width = opts.width,
        .height = opts.height,
        .gap = opts.gap,
        .min_width = opts.min_width,
        .min_height = opts.min_height,
        .max_width = opts.max_width,
        .max_height = opts.max_height,
        .corner_radius = opts.corner_radius,
        .placement_ptr = sliceAddr(opts.placement),
        .placement_len = opts.placement.len,
        .flags = opts.flags,
        .vibrancy_ptr = sliceAddr(opts.vibrancy),
        .vibrancy_len = opts.vibrancy.len,
    };
    const id: i32 = @intCast(@as(isize, @bitCast(dispatch(
        .flyout_new_ui,
        @intFromPtr(&spec),
        ui_view_count,
        @intFromPtr(state),
        0,
    ))));
    if (id <= 0) return Error.MyGoError;
    return .{ .id = id };
}

pub fn broadcast(event: []const u8, payload: anytype) Error!void {
    try emitTarget(0, event, payload);
}

fn emitTarget(win_id: i32, event: []const u8, payload: anytype) Error!void {
    var out: std.Io.Writer.Allocating = .init(std.heap.page_allocator);
    defer out.deinit();
    std.json.Stringify.value(payload, .{}, &out.writer) catch return Error.OutOfMemory;
    const json = out.written();
    var spec = CEmitSpec{
        .event = CStr.fromSlice(event),
        .payload = CStr.fromSlice(json),
    };
    if (dispatch(.emit_raw, @bitCast(@as(isize, win_id)), @intFromPtr(&spec), 0, 0) != 0) {
        return Error.MyGoError;
    }
}

/// Declares a typed frontend event (`export const events = { ... }`) for `mygo generate`.
pub fn declareEvent(comptime name: []const u8, comptime PayloadType: type) void {
    const ts_payload = comptime tsType(PayloadType);
    var spec = CTSSpec{
        .kind = 2,
        .name = CStr.fromSlice(name),
        .type_str = CStr.fromSlice(ts_payload),
    };
    _ = dispatch(.register_ts, @intFromPtr(&spec), 0, 0, 0);
}

/// Binds a Zig function to `"Service.method"` and registers its `comptime`-introspected
/// TypeScript signature for `mygo generate`.
pub fn bind(comptime full_name: []const u8, comptime func: anytype) Error!void {
    const FnType = @TypeOf(func);
    const fn_info = switch (@typeInfo(FnType)) {
        .@"fn" => |info| info,
        else => @compileError("mygo.bind expects a function, got " ++ @typeName(FnType)),
    };

    const dot = comptime std.mem.indexOfScalar(u8, full_name, '.') orelse
        @compileError("mygo.bind expects \"Service.method\", got " ++ full_name);
    const svc_name = full_name[0..dot];
    const method_name = full_name[dot + 1 ..];

    const has_ctx = fn_info.param_types.len > 0 and fn_info.param_types[0] == CallContext;
    const json_start: usize = if (has_ctx) 1 else 0;
    const json_arity: usize = fn_info.param_types.len - json_start;

    comptime var json_types: [json_arity]type = undefined;
    comptime var ts_params: []const u8 = "";
    comptime var ts_call_args: []const u8 = "";
    comptime {
        for (0..json_arity) |i| {
            const T = fn_info.param_types[json_start + i] orelse
                @compileError("mygo.bind does not support anytype parameters");
            json_types[i] = T;
            const arg_name = std.fmt.comptimePrint("arg{d}", .{i});
            if (i > 0) ts_params = ts_params ++ ", ";
            ts_params = ts_params ++ arg_name ++ ": " ++ tsType(T);
            ts_call_args = ts_call_args ++ ", " ++ arg_name;
        }
    }
    const JsonArgsTuple = @Tuple(&json_types);

    comptime var full_types: [fn_info.param_types.len]type = undefined;
    inline for (0..fn_info.param_types.len) |i| {
        full_types[i] = fn_info.param_types[i].?;
    }
    const FullArgsTuple = @Tuple(&full_types);

    const RetType = fn_info.return_type orelse void;
    const ts_ret = comptime tsType(RetType);

    var ts_spec = CTSSpec{
        .kind = 1,
        .service = CStr.fromSlice(svc_name),
        .name = CStr.fromSlice(method_name),
        .params = CStr.fromSlice(ts_params),
        .call_arg = CStr.fromSlice(ts_call_args),
        .type_str = CStr.fromSlice(ts_ret),
    };
    _ = dispatch(.register_ts, @intFromPtr(&ts_spec), 0, 0, 0);

    const Wrapper = struct {
        fn invoke(caller_window_id: i32, raw_args: []const u8, reply: usize) void {
            var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
            defer arena.deinit();
            const alloc = arena.allocator();

            const json_in = if (raw_args.len > 0) raw_args else "[]";
            const parsed_json = std.json.parseFromSliceLeaky(JsonArgsTuple, alloc, json_in, .{}) catch |err| {
                const msg = std.fmt.allocPrint(alloc, "invalid arguments: {s}", .{@errorName(err)}) catch "invalid arguments";
                _ = dispatch(.ipc_reject, reply, sliceAddr(msg), msg.len, 0);
                return;
            };

            var call_args: FullArgsTuple = undefined;
            if (has_ctx) {
                call_args[0] = CallContext{
                    .allocator = alloc,
                    .window = .{ .id = caller_window_id },
                };
            }
            inline for (0..json_arity) |i| {
                call_args[json_start + i] = parsed_json[i];
            }

            if (@typeInfo(RetType) == .error_union) {
                const val = @call(.auto, func, call_args) catch |err| {
                    const msg = @errorName(err);
                    _ = dispatch(.ipc_reject, reply, sliceAddr(msg), msg.len, 0);
                    return;
                };
                resolveValue(alloc, reply, val);
            } else {
                const val = @call(.auto, func, call_args);
                resolveValue(alloc, reply, val);
            }
        }

        fn resolveValue(alloc: std.mem.Allocator, reply: usize, val: anytype) void {
            if (@TypeOf(val) == void) {
                const null_lit = "null";
                _ = dispatch(.ipc_resolve, reply, sliceAddr(null_lit), null_lit.len, 0);
                return;
            }
            var out: std.Io.Writer.Allocating = .init(alloc);
            std.json.Stringify.value(val, .{}, &out.writer) catch {
                const msg = "failed to serialize response";
                _ = dispatch(.ipc_reject, reply, sliceAddr(msg), msg.len, 0);
                return;
            };
            const json = out.written();
            _ = dispatch(.ipc_resolve, reply, sliceAddr(json), json.len, 0);
        }
    };

    ipc_handlers[ipc_count] = &Wrapper.invoke;
    ipc_count += 1;
    if (dispatch(.bind_raw, sliceAddr(full_name), full_name.len, ipc_count, 0) != 0) {
        return Error.MyGoError;
    }
}

/// Comptime Zig -> TypeScript type synthesizer for `mygo generate`.
pub fn tsType(comptime T: type) []const u8 {
    if (T == void) return "void";
    return switch (@typeInfo(T)) {
        .bool => "boolean",
        .int, .float, .comptime_int, .comptime_float => "number",
        .error_union => |eu| tsType(eu.payload),
        .optional => |opt| tsType(opt.child) ++ " | null",
        .pointer => |ptr| switch (ptr.size) {
            .slice => if (ptr.child == u8) "string" else "(" ++ tsType(ptr.child) ++ ")[]",
            .one => tsType(ptr.child),
            else => "unknown",
        },
        .array => |arr| if (arr.child == u8) "string" else "(" ++ tsType(arr.child) ++ ")[]",
        .@"enum" => |en| blk: {
            if (en.field_names.len == 0) break :blk "never";
            var s: []const u8 = "";
            for (en.field_names, 0..) |fname, idx| {
                if (idx > 0) s = s ++ " | ";
                s = s ++ "\"" ++ fname ++ "\"";
            }
            break :blk s;
        },
        .@"struct" => |st| blk: {
            if (st.is_tuple) {
                var s: []const u8 = "[";
                for (st.field_types, 0..) |ft, idx| {
                    if (idx > 0) s = s ++ ", ";
                    s = s ++ tsType(ft);
                }
                break :blk s ++ "]";
            }
            if (st.field_names.len == 0) break :blk "Record<string, never>";
            var s: []const u8 = "{ ";
            for (st.field_names, st.field_types, 0..) |fname, ftype, idx| {
                if (idx > 0) s = s ++ "; ";
                s = s ++ fname ++ ": " ++ tsType(ftype);
            }
            break :blk s ++ " }";
        },
        else => "unknown",
    };
}

pub fn sliceAddr(s: []const u8) usize {
    return if (s.len > 0) @intFromPtr(s.ptr) else 0;
}
