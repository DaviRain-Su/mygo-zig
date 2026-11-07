//! Zero-allocation CommandBuffer client for MyGo's GPU-accelerated Native UI (`package ui`).
//!
//! Combines:
//! - 189 AST-generated `Element` style & layout modifiers (`element_gen.zig`),
//! - Virtualized 100,000+ row `List` (`c.list(...)`),
//! - Custom GPU vector drawing (`elem.draw(...)` + `Painter`),
//! - All running over a single `purego` callback (`CGO_ENABLED=0`).

const std = @import("std");
const mygo = @import("mygo.zig");
pub const Element = @import("element_gen.zig").Element;

pub const RawViewHandler = *const fn (frame_handle: usize, info: *const CFrameInfo, userdata: usize) void;
pub const RawListRowHandler = *const fn (frame_handle: usize, info: *const CListRowInfo, userdata: usize) void;
pub const RawPaintHandler = *const fn (painter_handle: usize, rect: *const CRect, userdata: usize) void;

pub const Color = packed struct(u32) {
    a: u8 = 255,
    b: u8 = 0,
    g: u8 = 0,
    r: u8 = 0,

    pub fn rgb(r: u8, g: u8, b: u8) Color {
        return .{ .r = r, .g = g, .b = b, .a = 255 };
    }

    pub fn rgba(r: u8, g: u8, b: u8, a: u8) Color {
        return .{ .r = r, .g = g, .b = b, .a = a };
    }

    pub fn toU32(self: Color) u32 {
        return (@as(u32, self.r) << 24) |
            (@as(u32, self.g) << 16) |
            (@as(u32, self.b) << 8) |
            @as(u32, self.a);
    }

    pub fn fromU32(v: u32) Color {
        return .{
            .r = @truncate(v >> 24),
            .g = @truncate(v >> 16),
            .b = @truncate(v >> 8),
            .a = @truncate(v),
        };
    }
};

pub const Rect = struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,
    now_ms: i64 = 0,
};

pub const Modifiers = packed struct(u8) {
    shift: bool = false,
    ctrl: bool = false,
    alt: bool = false,
    super: bool = false,
    _pad: u4 = 0,
};

pub const Key = enum(u16) {
    unknown = 0,
    enter = 1,
    escape = 2,
    backspace = 3,
    tab = 4,
    space = 5,
    delete = 6,
    insert = 7,
    home = 8,
    end = 9,
    page_up = 10,
    page_down = 11,
    left = 12,
    right = 13,
    up = 14,
    down = 15,
    _,
};

pub const CoreOp = enum(u16) {
    column = 1,
    row = 2,
    box = 3,
    scroll = 4,
    spacer = 5,
    divider = 6,
    text = 7,
    button = 8,
    primary_button = 9,
    checkbox = 10,
    toggle = 11,
    switch_ = 12,
    slider = 13,
    text_input = 14,
    list = 15,

    push_parent = 20,
    pop_parent = 21,
    draw = 22,
    numeric_transition = 23,

    query_clicked = 80,
    query_hovered = 81,
    query_pressed = 82,
    query_changed = 83,
    query_submitted = 84,
    query_shortcut = 85,
};

const PaintOp = enum(u8) {
    fill_rect = 1,
    stroke_rect = 2,
    line = 3,
    text = 4,
    shadow = 5,
    animation_frame = 6,
};

pub const CTheme = extern struct {
    dark: u8,
    _pad: [3]u8 = .{ 0, 0, 0 },
    background: u32,
    surface: u32,
    surface_hover: u32,
    surface_pressed: u32,
    border: u32,
    text: u32,
    text_muted: u32,
    accent: u32,
    accent_text: u32,
    danger: u32,
    warning: u32,
    success: u32,
    radius: f32,
    spacing: f32,
    font_size: f32,
};

pub const CFrameInfo = extern struct {
    window_id: i32,
    width: f32,
    height: f32,
    window_active: u8,
    _pad: [3]u8 = .{ 0, 0, 0 },
    theme: CTheme,
};

pub const CListRowInfo = extern struct {
    window_id: i32,
    index: i32,
    selected: u8,
    hovered: u8,
    pressed: u8,
    _pad: u8 = 0,
    theme: CTheme,
};

pub const CRect = extern struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,
    now_ms: i64,
};

pub const CQuery = extern struct {
    bool_val: u8 = 0,
    _pad: [7]u8 = @splat(0),
    num_val: f64 = 0,
    int_val: i64 = 0,
    text_buf_ptr: usize = 0,
    text_buf_cap: usize = 0,
    text_len: usize = 0,
};

pub const Theme = struct {
    dark: bool,
    background: Color,
    surface: Color,
    surface_hover: Color,
    surface_pressed: Color,
    border: Color,
    text: Color,
    text_muted: Color,
    accent: Color,
    accent_text: Color,
    danger: Color,
    warning: Color,
    success: Color,
    radius: f32,
    spacing: f32,
    font_size: f32,

    pub fn fromC(raw: CTheme) Theme {
        return .{
            .dark = raw.dark != 0,
            .background = Color.fromU32(raw.background),
            .surface = Color.fromU32(raw.surface),
            .surface_hover = Color.fromU32(raw.surface_hover),
            .surface_pressed = Color.fromU32(raw.surface_pressed),
            .border = Color.fromU32(raw.border),
            .text = Color.fromU32(raw.text),
            .text_muted = Color.fromU32(raw.text_muted),
            .accent = Color.fromU32(raw.accent),
            .accent_text = Color.fromU32(raw.accent_text),
            .danger = Color.fromU32(raw.danger),
            .warning = Color.fromU32(raw.warning),
            .success = Color.fromU32(raw.success),
            .radius = raw.radius,
            .spacing = raw.spacing,
            .font_size = raw.font_size,
        };
    }
};

pub const Scope = struct {
    ctx: *Context,

    pub fn end(self: Scope) void {
        self.ctx.writeOp(@intFromEnum(CoreOp.pop_parent));
    }
};

pub const ListRow = struct {
    ctx: *Context,
    index: usize,
    selected: bool,
    hovered: bool,
    pressed: bool,
};

/// Stack-buffered GPU vector painter for `Element.draw(...)` callbacks.
pub const Painter = struct {
    handle: usize,
    buf: [8192]u8 = undefined,
    len: usize = 0,
    fmt_buf: [256]u8 = undefined,

    pub fn flush(self: *Painter) void {
        if (self.len == 0) return;
        _ = mygo.dispatch(.ui_paint_flush, self.handle, @intFromPtr(&self.buf), self.len, 0);
        self.len = 0;
    }

    fn ensure(self: *Painter, n: usize) void {
        if (self.len + n > self.buf.len) self.flush();
    }

    fn writeU8(self: *Painter, v: u8) void {
        self.ensure(1);
        self.buf[self.len] = v;
        self.len += 1;
    }

    fn writeU32(self: *Painter, v: u32) void {
        self.ensure(4);
        std.mem.writeInt(u32, self.buf[self.len..][0..4], v, .little);
        self.len += 4;
    }

    fn writeF32(self: *Painter, v: f32) void {
        self.writeU32(@bitCast(v));
    }

    fn writeStr(self: *Painter, s: []const u8) void {
        if (5 + s.len > self.buf.len) self.flush();
        const clipped = if (5 + s.len > self.buf.len) s[0 .. self.buf.len - 5] else s;
        self.writeU32(@intCast(clipped.len));
        @memcpy(self.buf[self.len .. self.len + clipped.len], clipped);
        self.len += clipped.len;
    }

    pub fn fillRect(self: *Painter, x: f32, y: f32, w: f32, h: f32, color: Color, radius: f32) void {
        self.ensure(25);
        self.writeU8(@intFromEnum(PaintOp.fill_rect));
        self.writeF32(x);
        self.writeF32(y);
        self.writeF32(w);
        self.writeF32(h);
        self.writeU32(color.toU32());
        self.writeF32(radius);
    }

    pub fn strokeRect(self: *Painter, x: f32, y: f32, w: f32, h: f32, color: Color, radius: f32, stroke_width: f32) void {
        self.ensure(29);
        self.writeU8(@intFromEnum(PaintOp.stroke_rect));
        self.writeF32(x);
        self.writeF32(y);
        self.writeF32(w);
        self.writeF32(h);
        self.writeU32(color.toU32());
        self.writeF32(radius);
        self.writeF32(stroke_width);
    }

    pub fn line(self: *Painter, x0: f32, y0: f32, x1: f32, y1: f32, width: f32, color: Color) void {
        self.ensure(25);
        self.writeU8(@intFromEnum(PaintOp.line));
        self.writeF32(x0);
        self.writeF32(y0);
        self.writeF32(x1);
        self.writeF32(y1);
        self.writeF32(width);
        self.writeU32(color.toU32());
    }

    pub fn text(self: *Painter, x: f32, y: f32, s: []const u8, size: f32, color: Color) void {
        self.ensure(18 + s.len);
        self.writeU8(@intFromEnum(PaintOp.text));
        self.writeF32(x);
        self.writeF32(y);
        self.writeStr(s);
        self.writeF32(size);
        self.writeU32(color.toU32());
    }

    pub fn shadow(self: *Painter, x: f32, y: f32, w: f32, h: f32, radius: f32, dx: f32, dy: f32, blur: f32, spread: f32, color: Color) void {
        self.ensure(41);
        self.writeU8(@intFromEnum(PaintOp.shadow));
        self.writeF32(x);
        self.writeF32(y);
        self.writeF32(w);
        self.writeF32(h);
        self.writeF32(radius);
        self.writeF32(dx);
        self.writeF32(dy);
        self.writeF32(blur);
        self.writeF32(spread);
        self.writeU32(color.toU32());
    }

    /// Requests another animation frame on the display link (120Hz ProMotion / VSync).
    pub fn requestAnimationFrame(self: *Painter) void {
        self.writeU8(@intFromEnum(PaintOp.animation_frame));
    }
};

pub const Context = struct {
    frame_handle: usize,
    window: mygo.Window,
    width_dip: f32,
    height_dip: f32,
    window_active: bool,
    ui_theme: Theme,
    buf: [16384]u8 = undefined,
    len: usize = 0,
    fmt_buf: [512]u8 = undefined,

    pub fn init(handle: usize, info: *const CFrameInfo) Context {
        return .{
            .frame_handle = handle,
            .window = .{ .id = info.window_id },
            .width_dip = info.width,
            .height_dip = info.height,
            .window_active = info.window_active != 0,
            .ui_theme = Theme.fromC(info.theme),
        };
    }

    pub fn initForRow(handle: usize, info: *const CListRowInfo) Context {
        return .{
            .frame_handle = handle,
            .window = .{ .id = info.window_id },
            .width_dip = 0,
            .height_dip = 0,
            .window_active = true,
            .ui_theme = Theme.fromC(info.theme),
        };
    }

    pub fn theme(self: *const Context) Theme {
        return self.ui_theme;
    }

    pub fn flush(self: *Context) void {
        if (self.len == 0) return;
        _ = mygo.dispatch(.ui_flush, self.frame_handle, @intFromPtr(&self.buf), self.len, 0);
        self.len = 0;
    }

    pub fn flushQuery(self: *Context) CQuery {
        var q: CQuery = .{};
        if (self.len > 0) {
            _ = mygo.dispatch(.ui_flush, self.frame_handle, @intFromPtr(&self.buf), self.len, @intFromPtr(&q));
            self.len = 0;
        }
        return q;
    }

    fn flushQueryInto(self: *Context, q: *CQuery) void {
        if (self.len > 0) {
            _ = mygo.dispatch(.ui_flush, self.frame_handle, @intFromPtr(&self.buf), self.len, @intFromPtr(q));
            self.len = 0;
        }
    }

    fn ensureSpace(self: *Context, needed: usize) void {
        if (self.len + needed > self.buf.len) {
            self.flush();
        }
    }

    pub fn writeOp(self: *Context, op: u16) void {
        self.writeU16(op);
    }

    pub fn writeU8(self: *Context, v: u8) void {
        self.ensureSpace(1);
        self.buf[self.len] = v;
        self.len += 1;
    }

    pub fn writeU16(self: *Context, v: u16) void {
        self.ensureSpace(2);
        std.mem.writeInt(u16, self.buf[self.len..][0..2], v, .little);
        self.len += 2;
    }

    pub fn writeU32(self: *Context, v: u32) void {
        self.ensureSpace(4);
        std.mem.writeInt(u32, self.buf[self.len..][0..4], v, .little);
        self.len += 4;
    }

    pub fn writeI32(self: *Context, v: i32) void {
        self.writeU32(@bitCast(v));
    }

    pub fn writeU64(self: *Context, v: u64) void {
        self.ensureSpace(8);
        std.mem.writeInt(u64, self.buf[self.len..][0..8], v, .little);
        self.len += 8;
    }

    pub fn writeF32(self: *Context, v: f32) void {
        self.writeU32(@bitCast(v));
    }

    pub fn writeF64(self: *Context, v: f64) void {
        self.writeU64(@bitCast(v));
    }

    pub fn writeStr(self: *Context, s: []const u8) void {
        if (6 + s.len > self.buf.len) {
            self.flush();
        }
        const clipped = if (6 + s.len > self.buf.len) s[0 .. self.buf.len - 6] else s;
        self.writeU32(@intCast(clipped.len));
        @memcpy(self.buf[self.len .. self.len + clipped.len], clipped);
        self.len += clipped.len;
    }

    pub fn attachDraw(
        self: *Context,
        comptime StatePtr: type,
        state: StatePtr,
        comptime paintFn: fn (StatePtr, *Painter, Rect) void,
    ) void {
        const S = struct {
            var cb_id: usize = 0;
            fn onPaint(painter_handle: usize, cr: *const CRect, ud: usize) void {
                const s: StatePtr = @ptrFromInt(ud);
                var p = Painter{ .handle = painter_handle };
                paintFn(s, &p, .{
                    .x = cr.x,
                    .y = cr.y,
                    .w = cr.w,
                    .h = cr.h,
                    .now_ms = cr.now_ms,
                });
                p.flush();
            }
        };
        if (S.cb_id == 0) {
            mygo.ui_paint_handlers[mygo.ui_paint_count] = &S.onPaint;
            mygo.ui_paint_count += 1;
            S.cb_id = mygo.ui_paint_count;
        }
        self.ensureSpace(18);
        self.writeOp(@intFromEnum(CoreOp.draw));
        self.writeU64(@intCast(S.cb_id));
        self.writeU64(@intCast(@intFromPtr(state)));
    }

    pub fn shortcut(self: *Context, mods: Modifiers, key: Key) bool {
        self.ensureSpace(5);
        self.writeOp(@intFromEnum(CoreOp.query_shortcut));
        self.writeU8(@bitCast(mods));
        self.writeU16(@intFromEnum(key));
        return self.flushQuery().bool_val != 0;
    }

    pub fn column(self: *Context) Element {
        return self.columnKeyed("");
    }

    pub fn columnKeyed(self: *Context, key: []const u8) Element {
        self.ensureSpace(6 + key.len);
        self.writeOp(@intFromEnum(CoreOp.column));
        self.writeStr(key);
        return .{ .ctx = self };
    }

    pub fn row(self: *Context) Element {
        return self.rowKeyed("");
    }

    pub fn rowKeyed(self: *Context, key: []const u8) Element {
        self.ensureSpace(6 + key.len);
        self.writeOp(@intFromEnum(CoreOp.row));
        self.writeStr(key);
        return .{ .ctx = self };
    }

    pub fn box(self: *Context) Element {
        return self.boxKeyed("");
    }

    pub fn boxKeyed(self: *Context, key: []const u8) Element {
        self.ensureSpace(6 + key.len);
        self.writeOp(@intFromEnum(CoreOp.box));
        self.writeStr(key);
        return .{ .ctx = self };
    }

    pub fn scroll(self: *Context, key: []const u8) Element {
        self.ensureSpace(6 + key.len);
        self.writeOp(@intFromEnum(CoreOp.scroll));
        self.writeStr(key);
        return .{ .ctx = self };
    }

    pub fn spacer(self: *Context) Element {
        self.writeOp(@intFromEnum(CoreOp.spacer));
        return .{ .ctx = self };
    }

    pub fn divider(self: *Context) Element {
        self.writeOp(@intFromEnum(CoreOp.divider));
        return .{ .ctx = self };
    }

    pub fn text(self: *Context, s: []const u8) Element {
        self.ensureSpace(6 + s.len);
        self.writeOp(@intFromEnum(CoreOp.text));
        self.writeStr(s);
        return .{ .ctx = self };
    }

    pub fn textf(self: *Context, comptime fmt: []const u8, args: anytype) Element {
        const s = std.fmt.bufPrint(&self.fmt_buf, fmt, args) catch self.fmt_buf[0..];
        return self.text(s);
    }

    pub fn button(self: *Context, key: []const u8, lbl: []const u8) Element {
        self.ensureSpace(10 + key.len + lbl.len);
        self.writeOp(@intFromEnum(CoreOp.button));
        self.writeStr(key);
        self.writeStr(lbl);
        return .{ .ctx = self };
    }

    pub fn primaryButton(self: *Context, key: []const u8, lbl: []const u8) Element {
        self.ensureSpace(10 + key.len + lbl.len);
        self.writeOp(@intFromEnum(CoreOp.primary_button));
        self.writeStr(key);
        self.writeStr(lbl);
        return .{ .ctx = self };
    }

    pub fn checkbox(self: *Context, key: []const u8, checked: *bool, lbl: []const u8) Element {
        self.ensureSpace(11 + key.len + lbl.len);
        self.writeOp(@intFromEnum(CoreOp.checkbox));
        self.writeStr(key);
        self.writeU8(@intFromBool(checked.*));
        self.writeStr(lbl);
        checked.* = self.flushQuery().bool_val != 0;
        return .{ .ctx = self };
    }

    pub fn toggle(self: *Context, key: []const u8, on: *bool, lbl: []const u8) Element {
        self.ensureSpace(11 + key.len + lbl.len);
        self.writeOp(@intFromEnum(CoreOp.toggle));
        self.writeStr(key);
        self.writeU8(@intFromBool(on.*));
        self.writeStr(lbl);
        on.* = self.flushQuery().bool_val != 0;
        return .{ .ctx = self };
    }

    pub fn switchControl(self: *Context, key: []const u8, on: *bool) Element {
        self.ensureSpace(7 + key.len);
        self.writeOp(@intFromEnum(CoreOp.switch_));
        self.writeStr(key);
        self.writeU8(@intFromBool(on.*));
        on.* = self.flushQuery().bool_val != 0;
        return .{ .ctx = self };
    }

    pub fn slider(self: *Context, key: []const u8, value: *f64, lo: f64, hi: f64) Element {
        self.ensureSpace(30 + key.len);
        self.writeOp(@intFromEnum(CoreOp.slider));
        self.writeStr(key);
        self.writeF64(value.*);
        self.writeF64(lo);
        self.writeF64(hi);
        value.* = self.flushQuery().num_val;
        return .{ .ctx = self };
    }

    pub fn textInput(self: *Context, key: []const u8, buf: []u8, len: *usize) Element {
        self.ensureSpace(10 + key.len + len.*);
        self.writeOp(@intFromEnum(CoreOp.text_input));
        self.writeStr(key);
        self.writeStr(buf[0..len.*]);
        var q = CQuery{
            .text_buf_ptr = if (buf.len > 0) @intFromPtr(buf.ptr) else 0,
            .text_buf_cap = buf.len,
        };
        self.flushQueryInto(&q);
        if (q.bool_val != 0) {
            len.* = @min(q.text_len, buf.len);
        }
        return .{ .ctx = self };
    }

    /// Virtualized list (`ui.List`): smoothly scrolls 100,000+ rows while invoking
    /// `rowFn` only for the ~15–20 rows visible in the viewport.
    pub fn list(
        self: *Context,
        key: []const u8,
        count: usize,
        selected: *i32,
        comptime StatePtr: type,
        state: StatePtr,
        comptime rowFn: fn (StatePtr, ListRow) void,
    ) Element {
        const S = struct {
            var cb_id: usize = 0;
            fn onRow(row_handle: usize, info: *const CListRowInfo, ud: usize) void {
                const s: StatePtr = @ptrFromInt(ud);
                var row_ctx = Context.initForRow(row_handle, info);
                rowFn(s, .{
                    .ctx = &row_ctx,
                    .index = @intCast(info.index),
                    .selected = info.selected != 0,
                    .hovered = info.hovered != 0,
                    .pressed = info.pressed != 0,
                });
                row_ctx.flush();
            }
        };
        if (S.cb_id == 0) {
            mygo.ui_row_handlers[mygo.ui_row_count] = &S.onRow;
            mygo.ui_row_count += 1;
            S.cb_id = mygo.ui_row_count;
        }
        self.ensureSpace(30 + key.len);
        self.writeOp(@intFromEnum(CoreOp.list));
        self.writeStr(key);
        self.writeI32(@intCast(count));
        self.writeI32(selected.*);
        self.writeU64(@intCast(S.cb_id));
        self.writeU64(@intCast(@intFromPtr(state)));
        const q = self.flushQuery();
        selected.* = @intCast(q.int_val);
        return .{ .ctx = self };
    }
};
