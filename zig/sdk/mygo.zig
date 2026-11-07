//! Idiomatic Zig SDK for MyGo (`libmygo`):
//! - Step 1: WebView windows, comptime-typed IPC (`mygo.bind`), typed events (`mygo.emit`).
//! - Step 2: Desktop Shell (window controls & close-prevention events, clipboard,
//!           native dialogs, menus, system tray, shortcuts, shell, zero-copy `@embedFile` assets).
//! - Step 3: Native GPU UI (`mygo.ui` + `mygo.newWindowUi`) via stack CommandBuffer.

const std = @import("std");
pub const ui = @import("ui.zig");

pub const c = struct {
    pub const Str = extern struct {
        data: ?[*]const u8 = null,
        len: usize = 0,

        pub fn fromSlice(s: []const u8) Str {
            return .{
                .data = if (s.len > 0) s.ptr else null,
                .len = s.len,
            };
        }
    };

    pub const CWindowOptions = extern struct {
        title: Str = .{},
        url: Str = .{},
        background_color: Str = .{},
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
    };

    pub const ReadyFn = *const fn (?*anyopaque) callconv(.c) void;
    pub const BytesFn = *const fn (?[*]const u8, usize, ?*anyopaque) callconv(.c) void;
    pub const IpcFn = *const fn (
        caller_window_id: i32,
        args_json: ?[*]const u8,
        args_len: usize,
        reply: usize,
        userdata: ?*anyopaque,
    ) callconv(.c) void;
    pub const WindowEventFn = *const fn (
        win_id: i32,
        event_kind: i32,
        payload_json: ?[*]const u8,
        payload_len: usize,
        userdata: ?*anyopaque,
    ) callconv(.c) i32;
    pub const MenuClickFn = *const fn (
        item_id: ?[*]const u8,
        id_len: usize,
        win_id: i32,
        checked: u8,
        userdata: ?*anyopaque,
    ) callconv(.c) void;

    pub extern "c" fn mygo_app_set_name(name_ptr: ?[*]const u8, name_len: usize) void;
    pub extern "c" fn mygo_app_run(on_ready: ?ReadyFn, userdata: ?*anyopaque) i32;
    pub extern "c" fn mygo_app_quit() void;
    pub extern "c" fn mygo_last_error(buf: ?[*]u8, cap: usize) usize;

    pub extern "c" fn mygo_window_new(opts: *const CWindowOptions) i32;
    pub extern "c" fn mygo_window_new_ui(opts: *const CWindowOptions, view: ui.ViewFn, userdata: ?*anyopaque) i32;
    pub extern "c" fn mygo_window_set_title(win_id: i32, title_ptr: ?[*]const u8, title_len: usize) void;
    pub extern "c" fn mygo_window_show(win_id: i32) void;
    pub extern "c" fn mygo_window_hide(win_id: i32) void;
    pub extern "c" fn mygo_window_close(win_id: i32) void;
    pub extern "c" fn mygo_window_center(win_id: i32) void;
    pub extern "c" fn mygo_window_minimize(win_id: i32) void;
    pub extern "c" fn mygo_window_maximize(win_id: i32) void;
    pub extern "c" fn mygo_window_unmaximize(win_id: i32) void;
    pub extern "c" fn mygo_window_set_fullscreen(win_id: i32, fullscreen: u8) void;
    pub extern "c" fn mygo_window_get_bounds(win_id: i32, x: *i32, y: *i32, w: *i32, h: *i32) i32;
    pub extern "c" fn mygo_window_set_bounds(win_id: i32, x: i32, y: i32, w: i32, h: i32) void;
    pub extern "c" fn mygo_window_invalidate(win_id: i32) void;
    pub extern "c" fn mygo_window_on_event(win_id: i32, event_kind: i32, callback: WindowEventFn, userdata: ?*anyopaque) i32;

    pub extern "c" fn mygo_page_load_url(win_id: i32, url_ptr: ?[*]const u8, url_len: usize) i32;
    pub extern "c" fn mygo_page_load_html(
        win_id: i32,
        html_ptr: ?[*]const u8,
        html_len: usize,
        base_url_ptr: ?[*]const u8,
        base_url_len: usize,
    ) void;

    pub extern "c" fn mygo_bind_raw(
        method_ptr: ?[*]const u8,
        method_len: usize,
        callback: IpcFn,
        userdata: ?*anyopaque,
    ) i32;
    pub extern "c" fn mygo_ipc_defer(reply: usize) void;
    pub extern "c" fn mygo_ipc_resolve(reply: usize, json_ptr: ?[*]const u8, json_len: usize) void;
    pub extern "c" fn mygo_ipc_reject(reply: usize, err_ptr: ?[*]const u8, err_len: usize) void;
    pub extern "c" fn mygo_emit_raw(
        win_id: i32,
        event_ptr: ?[*]const u8,
        event_len: usize,
        json_ptr: ?[*]const u8,
        json_len: usize,
    ) i32;

    pub extern "c" fn mygo_clipboard_read_text(out: BytesFn, userdata: ?*anyopaque) void;
    pub extern "c" fn mygo_clipboard_write_text(text_ptr: ?[*]const u8, text_len: usize) void;
    pub extern "c" fn mygo_clipboard_clear() void;

    pub extern "c" fn mygo_dialog_open(opts_json: ?[*]const u8, opts_len: usize, out: BytesFn, userdata: ?*anyopaque) i32;
    pub extern "c" fn mygo_dialog_save(opts_json: ?[*]const u8, opts_len: usize, out: BytesFn, userdata: ?*anyopaque) i32;
    pub extern "c" fn mygo_dialog_message(opts_json: ?[*]const u8, opts_len: usize, out: BytesFn, userdata: ?*anyopaque) i32;

    pub extern "c" fn mygo_app_set_menu(items_json: ?[*]const u8, items_len: usize, on_click: ?MenuClickFn, userdata: ?*anyopaque) i32;
    pub extern "c" fn mygo_shortcut_register(acc_ptr: ?[*]const u8, acc_len: usize, cb: ReadyFn, userdata: ?*anyopaque) i32;
    pub extern "c" fn mygo_shortcut_unregister(acc_ptr: ?[*]const u8, acc_len: usize) void;
    pub extern "c" fn mygo_shortcut_unregister_all() void;

    pub extern "c" fn mygo_shell_open_external(url_ptr: ?[*]const u8, url_len: usize) i32;
    pub extern "c" fn mygo_shell_open_path(path_ptr: ?[*]const u8, path_len: usize) i32;
    pub extern "c" fn mygo_shell_beep() void;

    pub extern "c" fn mygo_frontend_add_asset(
        path_ptr: ?[*]const u8,
        path_len: usize,
        data_ptr: ?[*]const u8,
        data_len: usize,
        static_lifetime: u8,
    ) i32;
};

pub const Error = error{
    MyGoError,
    OutOfMemory,
};

pub const DevTools = enum(i32) {
    auto = 0,
    enabled = 1,
    disabled = 2,
};

pub const WindowEventKind = enum(i32) {
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

    fn toC(self: WindowOptions) c.CWindowOptions {
        return .{
            .title = c.Str.fromSlice(self.title),
            .url = c.Str.fromSlice(self.url),
            .background_color = c.Str.fromSlice(self.background_color),
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

    pub fn setTitle(self: Window, title: []const u8) void {
        c.mygo_window_set_title(self.id, slicePtr(title), title.len);
    }

    pub fn show(self: Window) void {
        c.mygo_window_show(self.id);
    }

    pub fn hide(self: Window) void {
        c.mygo_window_hide(self.id);
    }

    pub fn close(self: Window) void {
        c.mygo_window_close(self.id);
    }

    pub fn center(self: Window) void {
        c.mygo_window_center(self.id);
    }

    pub fn minimize(self: Window) void {
        c.mygo_window_minimize(self.id);
    }

    pub fn maximize(self: Window) void {
        c.mygo_window_maximize(self.id);
    }

    pub fn unmaximize(self: Window) void {
        c.mygo_window_unmaximize(self.id);
    }

    pub fn setFullscreen(self: Window, full: bool) void {
        c.mygo_window_set_fullscreen(self.id, @intFromBool(full));
    }

    pub fn bounds(self: Window) Error!Rectangle {
        var r: Rectangle = undefined;
        if (c.mygo_window_get_bounds(self.id, &r.x, &r.y, &r.width, &r.height) != 0) {
            return Error.MyGoError;
        }
        return r;
    }

    pub fn setBounds(self: Window, r: Rectangle) void {
        c.mygo_window_set_bounds(self.id, r.x, r.y, r.width, r.height);
    }

    pub fn invalidate(self: Window) void {
        c.mygo_window_invalidate(self.id);
    }

    /// Registers a close handler; returning `true` prevents the window from closing.
    pub fn onClose(self: Window, comptime handler: fn (Window) bool) Error!void {
        const T = struct {
            fn cb(win_id: i32, _: i32, _: ?[*]const u8, _: usize, _: ?*anyopaque) callconv(.c) i32 {
                return if (handler(.{ .id = win_id })) 1 else 0;
            }
        };
        if (c.mygo_window_on_event(self.id, @intFromEnum(WindowEventKind.close), &T.cb, null) != 0) {
            return Error.MyGoError;
        }
    }

    pub fn loadUrl(self: Window, url: []const u8) Error!void {
        if (c.mygo_page_load_url(self.id, slicePtr(url), url.len) != 0) {
            return Error.MyGoError;
        }
    }

    pub fn loadHtml(self: Window, html: []const u8, base_url: []const u8) void {
        c.mygo_page_load_html(
            self.id,
            slicePtr(html),
            html.len,
            slicePtr(base_url),
            base_url.len,
        );
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
        c.mygo_clipboard_write_text(slicePtr(text), text.len);
    }

    pub fn clear() void {
        c.mygo_clipboard_clear();
    }

    pub fn readText(allocator: std.mem.Allocator) Error![]u8 {
        const Capture = struct {
            alloc: std.mem.Allocator,
            result: ?[]u8 = null,
            oom: bool = false,

            fn cb(ptr: ?[*]const u8, len: usize, ud: ?*anyopaque) callconv(.c) void {
                const self: *@This() = @ptrCast(@alignCast(ud));
                const src = if (ptr) |p| p[0..len] else "";
                self.result = self.alloc.dupe(u8, src) catch {
                    self.oom = true;
                    return;
                };
            }
        };
        var cap = Capture{ .alloc = allocator };
        c.mygo_clipboard_read_text(&Capture.cb, &cap);
        if (cap.oom) return Error.OutOfMemory;
        return cap.result orelse allocator.dupe(u8, "") catch Error.OutOfMemory;
    }
};

pub const Shell = struct {
    pub fn openExternal(url: []const u8) Error!void {
        if (c.mygo_shell_open_external(slicePtr(url), url.len) != 0) return Error.MyGoError;
    }

    pub fn openPath(path: []const u8) Error!void {
        if (c.mygo_shell_open_path(slicePtr(path), path.len) != 0) return Error.MyGoError;
    }

    pub fn beep() void {
        c.mygo_shell_beep();
    }
};

/// Registers a static comptime/rodata asset (such as `@embedFile("dist/index.html")`)
/// served at `mygo://localhost/<path>` with zero heap copies.
pub fn addEmbeddedAsset(path: []const u8, comptime data: []const u8) Error!void {
    if (c.mygo_frontend_add_asset(slicePtr(path), path.len, slicePtr(data), data.len, 1) != 0) {
        return Error.MyGoError;
    }
}

pub fn setName(name: []const u8) void {
    c.mygo_app_set_name(slicePtr(name), name.len);
}

pub fn quit() void {
    c.mygo_app_quit();
}

pub fn lastError(buf: []u8) []const u8 {
    const total = c.mygo_last_error(if (buf.len > 0) buf.ptr else null, buf.len);
    const n = @min(total, buf.len);
    return buf[0..n];
}

pub fn newWindow(opts: WindowOptions) Error!Window {
    const raw = opts.toC();
    const id = c.mygo_window_new(&raw);
    if (id <= 0) return Error.MyGoError;
    return .{ .id = id };
}

/// Creates a GPU-rendered Native UI window driven by `state` and `viewFn(state, *ui.Context)`.
pub fn newWindowUi(
    StatePtr: type,
    state: StatePtr,
    opts: WindowOptions,
    comptime viewFn: fn (StatePtr, *ui.Context) void,
) Error!Window {
    const Trampoline = struct {
        fn onView(frame_handle: usize, info: *const ui.CFrameInfo, ud: ?*anyopaque) callconv(.c) void {
            const s: StatePtr = @ptrCast(@alignCast(ud));
            var ctx = ui.Context.init(frame_handle, info);
            viewFn(s, &ctx);
            ctx.flush();
        }
    };
    const raw = opts.toC();
    const id = c.mygo_window_new_ui(&raw, &Trampoline.onView, @ptrCast(state));
    if (id <= 0) return Error.MyGoError;
    return .{ .id = id };
}

pub fn run(comptime on_ready: fn () void) Error!void {
    const Trampoline = struct {
        fn cb(_: ?*anyopaque) callconv(.c) void {
            on_ready();
        }
    };
    if (c.mygo_app_run(&Trampoline.cb, null) != 0) {
        return Error.MyGoError;
    }
}

pub fn broadcast(event: []const u8, payload: anytype) Error!void {
    try emitTarget(0, event, payload);
}

fn emitTarget(win_id: i32, event: []const u8, payload: anytype) Error!void {
    var out: std.Io.Writer.Allocating = .init(std.heap.c_allocator);
    defer out.deinit();
    std.json.Stringify.value(payload, .{}, &out.writer) catch return Error.OutOfMemory;
    const json = out.written();
    if (c.mygo_emit_raw(win_id, slicePtr(event), event.len, slicePtr(json), json.len) != 0) {
        return Error.MyGoError;
    }
}

pub fn bind(method: []const u8, comptime func: anytype) Error!void {
    const FnType = @TypeOf(func);
    const fn_info = switch (@typeInfo(FnType)) {
        .@"fn" => |info| info,
        else => @compileError("mygo.bind expects a function, got " ++ @typeName(FnType)),
    };

    const has_ctx = fn_info.param_types.len > 0 and fn_info.param_types[0] == CallContext;
    const json_start: usize = if (has_ctx) 1 else 0;
    const json_arity: usize = fn_info.param_types.len - json_start;

    comptime var json_types: [json_arity]type = undefined;
    inline for (0..json_arity) |i| {
        json_types[i] = fn_info.param_types[json_start + i] orelse
            @compileError("mygo.bind does not support anytype parameters");
    }
    const JsonArgsTuple = @Tuple(&json_types);

    comptime var full_types: [fn_info.param_types.len]type = undefined;
    inline for (0..fn_info.param_types.len) |i| {
        full_types[i] = fn_info.param_types[i].?;
    }
    const FullArgsTuple = @Tuple(&full_types);

    const RetType = fn_info.return_type orelse void;

    const Wrapper = struct {
        fn invoke(
            caller_window_id: i32,
            args_ptr: ?[*]const u8,
            args_len: usize,
            reply: usize,
            _: ?*anyopaque,
        ) callconv(.c) void {
            var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
            defer arena.deinit();
            const alloc = arena.allocator();

            const raw_args: []const u8 = if (args_ptr) |p| p[0..args_len] else "[]";
            const parsed_json = std.json.parseFromSliceLeaky(JsonArgsTuple, alloc, raw_args, .{}) catch |err| {
                const msg = std.fmt.allocPrint(alloc, "invalid arguments: {s}", .{@errorName(err)}) catch "invalid arguments";
                c.mygo_ipc_reject(reply, slicePtr(msg), msg.len);
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
                    c.mygo_ipc_reject(reply, slicePtr(msg), msg.len);
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
                c.mygo_ipc_resolve(reply, null_lit.ptr, null_lit.len);
                return;
            }
            var out: std.Io.Writer.Allocating = .init(alloc);
            std.json.Stringify.value(val, .{}, &out.writer) catch {
                const msg = "failed to serialize response";
                c.mygo_ipc_reject(reply, msg.ptr, msg.len);
                return;
            };
            const json = out.written();
            c.mygo_ipc_resolve(reply, slicePtr(json), json.len);
        }
    };

    if (c.mygo_bind_raw(slicePtr(method), method.len, &Wrapper.invoke, null) != 0) {
        return Error.MyGoError;
    }
}

fn slicePtr(s: []const u8) ?[*]const u8 {
    return if (s.len > 0) s.ptr else null;
}
