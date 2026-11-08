//! Idiomatic Zig SDK for MyGo (`CGO_ENABLED=0` purego host architecture).
//!
//! Exports a single `mygo_zig_entry` symbol via `comptime { mygo.exportApp(...); }`
//! and communicates with the pure-Go MyGo host over a single `HostDispatchFn`
//! pointer—requiring zero `cgo`, supporting `mygo generate` TypeScript client
//! synthesis from Zig `comptime` types, and packaging directly into `.app` / `.dmg`
//! / Linux / Windows installers via `mygo build`.

const std = @import("std");
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
    register_font = 240,
    register_bitmap = 241,
    register_canvas = 242,
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

    pub fn invalidate(self: Window) void {
        _ = self.ctl(.invalidate, 0, 0);
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

    pub fn clear() Error!void {
        if (dispatch(.cookies, 4, 0, 0, 0) == std.math.maxInt(usize)) return Error.MyGoError;
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
