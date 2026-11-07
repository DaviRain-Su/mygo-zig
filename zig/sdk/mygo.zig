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

    window_new_ui = 100,
    ui_flush = 101,
    ui_paint_flush = 102,

    markdown_view = 200,
    editor_view = 210,
    diff_view = 211,
    line_chart = 220,
    bar_chart = 221,
    area_chart = 222,
    pie_chart = 223,
    video_gif = 230,
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

fn registerBytesHandler(h: RawBytesHandler) usize {
    bytes_handlers[bytes_count] = h;
    bytes_count += 1;
    return bytes_count;
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
                .menu => return 0,
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

pub const Clipboard = struct {
    pub fn writeText(text: []const u8) void {
        _ = dispatch(.clipboard, 1, sliceAddr(text), text.len, 0);
    }

    pub fn clear() void {
        _ = dispatch(.clipboard, 2, 0, 0, 0);
    }

    pub fn readText(allocator: std.mem.Allocator) Error![]u8 {
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
        _ = dispatch(.clipboard, 3, S.cb_id, @intFromPtr(&cap), 0);
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
