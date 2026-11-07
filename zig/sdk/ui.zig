//! Zero-allocation CommandBuffer client for MyGo's GPU-accelerated Native UI (`ui`).
//! Style modifiers and layout nodes record compact binary opcodes on a stack
//! buffer with 0 FFI calls, flushing across C ABI only on interactive queries
//! or at the end of the frame.

const std = @import("std");
const mygo = @import("mygo.zig");

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

const Op = enum(u8) {
    column = 1,
    row = 2,
    scroll = 3,
    spacer = 4,
    divider = 5,
    text = 6,
    button = 7,
    primary_button = 8,
    checkbox = 9,
    toggle = 10,
    switch_ = 11,
    slider = 12,
    text_input = 13,

    push_parent = 20,
    pop_parent = 21,

    fill = 30,
    fill_width = 31,
    fill_height = 32,
    grow = 33,
    center = 34,
    gap = 35,
    padding_all = 36,
    padding_xy = 37,
    padding_trbl = 38,
    width = 39,
    height = 40,
    min_width = 41,
    max_width = 42,
    background = 43,
    radius = 44,
    border = 45,
    font_size = 46,
    bold = 47,
    text_color = 48,
    disabled = 49,
    label = 50,
    placeholder = 51,
    numeric_transition = 52,

    query_clicked = 80,
    query_hovered = 81,
    query_changed = 82,
    query_submitted = 83,
    query_shortcut = 84,
};

pub const CTheme = extern struct {
    dark: u8,
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
    theme: CTheme,
};

pub const CQuery = extern struct {
    bool_val: u8 = 0,
    num_val: f64 = 0,
    text_ptr: ?[*]const u8 = null,
    text_len: usize = 0,
};

pub const ViewFn = *const fn (
    frame_handle: usize,
    info: *const CFrameInfo,
    userdata: ?*anyopaque,
) callconv(.c) void;

extern "c" fn mygo_ui_flush(
    frame_handle: usize,
    cmd_ptr: ?[*]const u8,
    cmd_len: usize,
    out: ?*CQuery,
) void;

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

    fn fromC(raw: CTheme) Theme {
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
        self.ctx.writeOp(.pop_parent);
    }
};

pub const Element = struct {
    ctx: *Context,

    /// Enters this container's children scope; pair with `defer scope.end();`.
    pub fn begin(self: Element) Scope {
        self.ctx.writeOp(.push_parent);
        return .{ .ctx = self.ctx };
    }

    pub fn fill(self: Element) Element {
        self.ctx.writeOp(.fill);
        return self;
    }

    pub fn fillWidth(self: Element) Element {
        self.ctx.writeOp(.fill_width);
        return self;
    }

    pub fn fillHeight(self: Element) Element {
        self.ctx.writeOp(.fill_height);
        return self;
    }

    pub fn grow(self: Element, factor: f32) Element {
        self.ctx.writeOp(.grow);
        self.ctx.writeF32(factor);
        return self;
    }

    pub fn center(self: Element) Element {
        self.ctx.writeOp(.center);
        return self;
    }

    pub fn gap(self: Element, v: f32) Element {
        self.ctx.writeOp(.gap);
        self.ctx.writeF32(v);
        return self;
    }

    pub fn padding(self: Element, v: f32) Element {
        self.ctx.writeOp(.padding_all);
        self.ctx.writeF32(v);
        return self;
    }

    pub fn paddingXY(self: Element, x: f32, y: f32) Element {
        self.ctx.writeOp(.padding_xy);
        self.ctx.writeF32(x);
        self.ctx.writeF32(y);
        return self;
    }

    pub fn width(self: Element, w: f32) Element {
        self.ctx.writeOp(.width);
        self.ctx.writeF32(w);
        return self;
    }

    pub fn height(self: Element, h: f32) Element {
        self.ctx.writeOp(.height);
        self.ctx.writeF32(h);
        return self;
    }

    pub fn minWidth(self: Element, w: f32) Element {
        self.ctx.writeOp(.min_width);
        self.ctx.writeF32(w);
        return self;
    }

    pub fn maxWidth(self: Element, w: f32) Element {
        self.ctx.writeOp(.max_width);
        self.ctx.writeF32(w);
        return self;
    }

    pub fn background(self: Element, col: Color) Element {
        self.ctx.writeOp(.background);
        self.ctx.writeU32(col.toU32());
        return self;
    }

    pub fn radius(self: Element, r: f32) Element {
        self.ctx.writeOp(.radius);
        self.ctx.writeF32(r);
        return self;
    }

    pub fn border(self: Element, w: f32, col: Color) Element {
        self.ctx.writeOp(.border);
        self.ctx.writeF32(w);
        self.ctx.writeU32(col.toU32());
        return self;
    }

    pub fn fontSize(self: Element, size: f32) Element {
        self.ctx.writeOp(.font_size);
        self.ctx.writeF32(size);
        return self;
    }

    pub fn bold(self: Element) Element {
        self.ctx.writeOp(.bold);
        return self;
    }

    pub fn textColor(self: Element, col: Color) Element {
        self.ctx.writeOp(.text_color);
        self.ctx.writeU32(col.toU32());
        return self;
    }

    pub fn disabled(self: Element, d: bool) Element {
        self.ctx.writeOp(.disabled);
        self.ctx.writeU8(@intFromBool(d));
        return self;
    }

    pub fn label(self: Element, s: []const u8) Element {
        self.ctx.writeOp(.label);
        self.ctx.writeStr(s);
        return self;
    }

    pub fn placeholder(self: Element, s: []const u8) Element {
        self.ctx.writeOp(.placeholder);
        self.ctx.writeStr(s);
        return self;
    }

    pub fn numericTransition(self: Element, down: bool) Element {
        self.ctx.writeOp(.numeric_transition);
        self.ctx.writeU8(@intFromBool(down));
        return self;
    }

    pub fn clicked(self: Element) bool {
        self.ctx.writeOp(.query_clicked);
        return self.ctx.flushQuery().bool_val != 0;
    }

    pub fn hovered(self: Element) bool {
        self.ctx.writeOp(.query_hovered);
        return self.ctx.flushQuery().bool_val != 0;
    }

    pub fn changed(self: Element) bool {
        self.ctx.writeOp(.query_changed);
        return self.ctx.flushQuery().bool_val != 0;
    }

    pub fn submitted(self: Element) bool {
        self.ctx.writeOp(.query_submitted);
        return self.ctx.flushQuery().bool_val != 0;
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

    pub fn theme(self: *const Context) Theme {
        return self.ui_theme;
    }

    pub fn flush(self: *Context) void {
        if (self.len == 0) return;
        mygo_ui_flush(self.frame_handle, &self.buf, self.len, null);
        self.len = 0;
    }

    fn flushQuery(self: *Context) CQuery {
        var q: CQuery = .{};
        if (self.len > 0) {
            mygo_ui_flush(self.frame_handle, &self.buf, self.len, &q);
            self.len = 0;
        }
        return q;
    }

    fn ensureSpace(self: *Context, needed: usize) void {
        if (self.len + needed > self.buf.len) {
            self.flush();
        }
    }

    fn writeOp(self: *Context, op: Op) void {
        self.ensureSpace(1);
        self.buf[self.len] = @intFromEnum(op);
        self.len += 1;
    }

    fn writeU8(self: *Context, v: u8) void {
        self.ensureSpace(1);
        self.buf[self.len] = v;
        self.len += 1;
    }

    fn writeU16(self: *Context, v: u16) void {
        self.ensureSpace(2);
        std.mem.writeInt(u16, self.buf[self.len..][0..2], v, .little);
        self.len += 2;
    }

    fn writeU32(self: *Context, v: u32) void {
        self.ensureSpace(4);
        std.mem.writeInt(u32, self.buf[self.len..][0..4], v, .little);
        self.len += 4;
    }

    fn writeF32(self: *Context, v: f32) void {
        self.writeU32(@bitCast(v));
    }

    fn writeF64(self: *Context, v: f64) void {
        self.ensureSpace(8);
        std.mem.writeInt(u64, self.buf[self.len..][0..8], @bitCast(v), .little);
        self.len += 8;
    }

    fn writeStr(self: *Context, s: []const u8) void {
        if (4 + s.len > self.buf.len) {
            self.flush();
        }
        const clipped = if (4 + s.len > self.buf.len) s[0 .. self.buf.len - 4] else s;
        self.writeU32(@intCast(clipped.len));
        @memcpy(self.buf[self.len .. self.len + clipped.len], clipped);
        self.len += clipped.len;
    }

    pub fn shortcut(self: *Context, mods: Modifiers, key: Key) bool {
        self.writeOp(.query_shortcut);
        self.writeU8(@bitCast(mods));
        self.writeU16(@intFromEnum(key));
        return self.flushQuery().bool_val != 0;
    }

    pub fn column(self: *Context) Element {
        return self.columnKeyed("");
    }

    pub fn columnKeyed(self: *Context, key: []const u8) Element {
        self.writeOp(.column);
        self.writeStr(key);
        return .{ .ctx = self };
    }

    pub fn row(self: *Context) Element {
        return self.rowKeyed("");
    }

    pub fn rowKeyed(self: *Context, key: []const u8) Element {
        self.writeOp(.row);
        self.writeStr(key);
        return .{ .ctx = self };
    }

    pub fn scroll(self: *Context, key: []const u8) Element {
        self.writeOp(.scroll);
        self.writeStr(key);
        return .{ .ctx = self };
    }

    pub fn spacer(self: *Context) Element {
        self.writeOp(.spacer);
        return .{ .ctx = self };
    }

    pub fn divider(self: *Context) Element {
        self.writeOp(.divider);
        return .{ .ctx = self };
    }

    pub fn text(self: *Context, s: []const u8) Element {
        self.writeOp(.text);
        self.writeStr(s);
        return .{ .ctx = self };
    }

    pub fn textf(self: *Context, comptime fmt: []const u8, args: anytype) Element {
        const s = std.fmt.bufPrint(&self.fmt_buf, fmt, args) catch self.fmt_buf[0..];
        return self.text(s);
    }

    pub fn button(self: *Context, key: []const u8, lbl: []const u8) Element {
        self.writeOp(.button);
        self.writeStr(key);
        self.writeStr(lbl);
        return .{ .ctx = self };
    }

    pub fn primaryButton(self: *Context, key: []const u8, lbl: []const u8) Element {
        self.writeOp(.primary_button);
        self.writeStr(key);
        self.writeStr(lbl);
        return .{ .ctx = self };
    }

    pub fn checkbox(self: *Context, key: []const u8, checked: *bool, lbl: []const u8) Element {
        self.writeOp(.checkbox);
        self.writeStr(key);
        self.writeU8(@intFromBool(checked.*));
        self.writeStr(lbl);
        checked.* = self.flushQuery().bool_val != 0;
        return .{ .ctx = self };
    }

    pub fn toggle(self: *Context, key: []const u8, on: *bool, lbl: []const u8) Element {
        self.writeOp(.toggle);
        self.writeStr(key);
        self.writeU8(@intFromBool(on.*));
        self.writeStr(lbl);
        on.* = self.flushQuery().bool_val != 0;
        return .{ .ctx = self };
    }

    pub fn switchControl(self: *Context, key: []const u8, on: *bool) Element {
        self.writeOp(.switch_);
        self.writeStr(key);
        self.writeU8(@intFromBool(on.*));
        on.* = self.flushQuery().bool_val != 0;
        return .{ .ctx = self };
    }

    pub fn slider(self: *Context, key: []const u8, value: *f64, lo: f64, hi: f64) Element {
        self.writeOp(.slider);
        self.writeStr(key);
        self.writeF64(value.*);
        self.writeF64(lo);
        self.writeF64(hi);
        value.* = self.flushQuery().num_val;
        return .{ .ctx = self };
    }

    /// Editable single-line text input backed by a caller-owned slice buffer.
    pub fn textInput(self: *Context, key: []const u8, buf: []u8, len: *usize) Element {
        self.writeOp(.text_input);
        self.writeStr(key);
        self.writeStr(buf[0..len.*]);
        const q = self.flushQuery();
        if (q.bool_val != 0) {
            if (q.text_ptr) |p| {
                const n = @min(q.text_len, buf.len);
                @memcpy(buf[0..n], p[0..n]);
                len.* = n;
            } else {
                len.* = 0;
            }
        }
        return .{ .ctx = self };
    }
};
