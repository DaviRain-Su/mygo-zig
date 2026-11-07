//! Zero-allocation CommandBuffer client for MyGo's GPU-accelerated Native UI (`package ui`).
//!
//! Combines:
//! - 202 AST-generated `Element` style & layout modifiers (`element_gen.zig`),
//! - Rich controls (`Tabs`, `Segmented`, `Select`, `Radio`, `Sidebar`, `Collapsible`,
//!   `Split` / `SplitVertical`, `Badge`, `Link`, `Progress`, `Meter`, `TextArea`),
//! - Virtualized 100,000+ row `List` & multi-column `Table`,
//! - Custom GPU vector drawing (`elem.draw(...)` + `Painter`),
//! - Opt-in GFM `markdown` (`zig/host/markdown`) & syntax-highlighted `codeEditor` +
//!   `diffView` (`zig/host/editor`),
//! - All running over a single `purego` callback (`CGO_ENABLED=0`).

const std = @import("std");
const mygo = @import("mygo.zig");
pub const Element = @import("element_gen.zig").Element;

pub const RawViewHandler = *const fn (frame_handle: usize, info: *const CFrameInfo, userdata: usize) void;
pub const RawListRowHandler = *const fn (frame_handle: usize, info: *const CListRowInfo, userdata: usize) void;
pub const RawTableCellHandler = *const fn (frame_handle: usize, info: *const CTableCellInfo, userdata: usize) void;
pub const RawPaintHandler = *const fn (painter_handle: usize, rect: *const CRect, userdata: usize) void;

pub const Align = enum(u8) {
    start = 0,
    center = 1,
    end = 2,
    stretch = 3,
    space_between = 4,
    space_around = 5,
    space_evenly = 6,
    baseline = 7,
};

pub const BorderStyle = enum(u8) {
    solid = 0,
    dashed = 1,
};

pub const Direction = enum(u8) {
    ltr = 0,
    rtl = 1,
};

pub const Cursor = enum(u8) {
    default = 0,
    pointer = 1,
    text = 2,
    move = 3,
    resize_ew = 4,
    resize_ns = 5,
    resize_nwse = 6,
    resize_nesw = 7,
    not_allowed = 8,
    crosshair = 9,
    grab = 10,
    grabbing = 11,
};

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

    badge = 16,
    link = 17,
    progress = 18,
    meter = 19,

    push_parent = 20,
    pop_parent = 21,
    draw = 22,
    numeric_transition = 23,

    tabs = 24,
    segmented = 25,
    select = 26,
    radio = 27,
    text_area = 28,
    collapsible = 29,
    split = 30,
    sidebar = 31,
    table = 32,
    combobox = 33,
    alert_dialog = 34,

    spinner = 35,
    search_field = 36,
    autocomplete = 37,
    number_input = 38,
    stepper = 39,
    step_slider = 40,
    range_slider = 41,
    rating = 42,
    date_input = 43,
    time_input = 44,
    color_picker = 45,
    color_well = 46,
    avatar = 47,
    breadcrumbs = 48,
    scroll_horizontal = 49,
    scroll_both = 50,
    decimal_input = 51,
    checkbox_group = 52,
    radio_group = 53,
    toggle_group = 54,
    fieldset = 55,
    accordion = 56,
    accordion_item = 57,
    modal = 58,
    popover = 59,
    calendar = 60,
    field = 61,
    form = 62,
    overlay = 63,
    token_field = 64,
    tree = 65,
    tree_item = 66,

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

pub const CTableCellInfo = extern struct {
    window_id: i32,
    row: i32,
    col: i32,
    selected: u8,
    _pad: [3]u8 = .{ 0, 0, 0 },
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
    num_val2: f64 = 0,
    int_val: i64 = 0,
    text_buf_ptr: usize = 0,
    text_buf_cap: usize = 0,
    text_len: usize = 0,
};

const CEditorSpec = extern struct {
    file_name: mygo.CStr,
    initial_text: mygo.CStr,
    soft_wrap: u8 = 0,
    split_layout: u8 = 1,
    _pad: [6]u8 = @splat(0),
};

const CEditorStats = extern struct {
    line: i32 = 1,
    col: i32 = 1,
    line_count: i32 = 1,
    added: i32 = 0,
    deleted: i32 = 0,
    hunk_count: i32 = 0,
    modified: u8 = 0,
    changed_now: u8 = 0,
    _pad: [6]u8 = @splat(0),
    text_buf_ptr: usize = 0,
    text_buf_cap: usize = 0,
    text_len: usize = 0,
};

pub const EditorStats = struct {
    line: i32 = 1,
    col: i32 = 1,
    line_count: i32 = 1,
    added: i32 = 0,
    deleted: i32 = 0,
    hunk_count: i32 = 0,
    modified: bool = false,
};

/// Returned by `Context.alertDialog` when Escape dismisses the alert.
pub const alert_dismissed: i32 = -2;

/// Decodes a packed string-list written by the host (`u16` count +
/// length-prefixed UTF-8). Returns the number of strings written into `out`.
pub fn readStrList(buf: []const u8, out: [][]const u8) usize {
    if (buf.len < 2) return 0;
    const count: usize = std.mem.readInt(u16, buf[0..2], .little);
    var off: usize = 2;
    var n: usize = 0;
    while (n < count and n < out.len) : (n += 1) {
        if (off + 4 > buf.len) break;
        const len: usize = std.mem.readInt(u32, buf[off..][0..4], .little);
        off += 4;
        if (off + len > buf.len) break;
        out[n] = buf[off .. off + len];
        off += len;
    }
    return n;
}

pub const TableColumn = struct {
    title: []const u8,
    width: f32 = 0,
    @"align": Align = .start,
};

pub const TableCell = struct {
    ctx: *Context,
    row: usize,
    col: usize,
    selected: bool,
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

pub const Painter = struct {
    handle: usize,
    buf: [8192]u8 = undefined,
    len: usize = 0,

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

    pub fn line(self: *Painter, x0: f32, y0: f32, x1: f32, y1: f32, stroke_width: f32, color: Color) void {
        self.ensure(25);
        self.writeU8(@intFromEnum(PaintOp.line));
        self.writeF32(x0);
        self.writeF32(y0);
        self.writeF32(x1);
        self.writeF32(y1);
        self.writeF32(stroke_width);
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

    pub fn requestAnimationFrame(self: *Painter) void {
        self.writeU8(@intFromEnum(PaintOp.animation_frame));
    }
};

fn registerSubview(comptime StatePtr: type, comptime fnPtr: fn (StatePtr, *Context) void) usize {
    const S = struct {
        var id: usize = 0;
        fn onSub(handle: usize, info: *const CFrameInfo, ud: usize) void {
            const s: StatePtr = @ptrFromInt(ud);
            var sub_ctx = Context.init(handle, info);
            fnPtr(s, &sub_ctx);
            sub_ctx.flush();
        }
    };
    if (S.id == 0) {
        mygo.ui_subview_handlers[mygo.ui_subview_count] = &S.onSub;
        mygo.ui_subview_count += 1;
        S.id = mygo.ui_subview_count;
    }
    return S.id;
}

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

    pub fn initForCell(handle: usize, info: *const CTableCellInfo) Context {
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

    fn writeStrSlice(self: *Context, items: []const []const u8) void {
        self.writeU16(@intCast(items.len));
        for (items) |it| {
            self.writeStr(it);
        }
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

    pub fn badge(self: *Context, s: []const u8) Element {
        self.ensureSpace(6 + s.len);
        self.writeOp(@intFromEnum(CoreOp.badge));
        self.writeStr(s);
        return .{ .ctx = self };
    }

    pub fn link(self: *Context, lbl: []const u8, url: []const u8) Element {
        self.ensureSpace(10 + lbl.len + url.len);
        self.writeOp(@intFromEnum(CoreOp.link));
        self.writeStr(lbl);
        self.writeStr(url);
        return .{ .ctx = self };
    }

    pub fn progress(self: *Context, value_0_to_1: f64) Element {
        self.ensureSpace(10);
        self.writeOp(@intFromEnum(CoreOp.progress));
        self.writeF64(value_0_to_1);
        return .{ .ctx = self };
    }

    pub fn meter(self: *Context, value: f64, lo: f64, hi: f64) Element {
        self.ensureSpace(26);
        self.writeOp(@intFromEnum(CoreOp.meter));
        self.writeF64(value);
        self.writeF64(lo);
        self.writeF64(hi);
        return .{ .ctx = self };
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

    pub fn textArea(self: *Context, key: []const u8, buf: []u8, len: *usize) Element {
        self.ensureSpace(10 + key.len + len.*);
        self.writeOp(@intFromEnum(CoreOp.text_area));
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

    pub fn tabs(self: *Context, key: []const u8, selected: *i32, labels: []const []const u8) Element {
        self.writeOp(@intFromEnum(CoreOp.tabs));
        self.writeStr(key);
        self.writeI32(selected.*);
        self.writeStrSlice(labels);
        selected.* = @intCast(self.flushQuery().int_val);
        return .{ .ctx = self };
    }

    pub fn segmented(self: *Context, key: []const u8, selected: *i32, labels: []const []const u8) Element {
        self.writeOp(@intFromEnum(CoreOp.segmented));
        self.writeStr(key);
        self.writeI32(selected.*);
        self.writeStrSlice(labels);
        selected.* = @intCast(self.flushQuery().int_val);
        return .{ .ctx = self };
    }

    pub fn selectIndex(self: *Context, key: []const u8, selected: *i32, options: []const []const u8) Element {
        self.writeOp(@intFromEnum(CoreOp.select));
        self.writeStr(key);
        self.writeI32(selected.*);
        self.writeStrSlice(options);
        selected.* = @intCast(self.flushQuery().int_val);
        return .{ .ctx = self };
    }

    /// Modal alert (`ui.AlertDialog`). Returns the button index, or
    /// `ui.alert_dismissed` (-2) when Escape closes it, or `-1` while open / idle.
    /// Updates `open` to match the dialog's visibility after the call.
    pub fn alertDialog(
        self: *Context,
        open: *bool,
        title: []const u8,
        message: []const u8,
        buttons: []const []const u8,
    ) i32 {
        self.writeOp(@intFromEnum(CoreOp.alert_dialog));
        self.writeU8(@intFromBool(open.*));
        self.writeStr(title);
        self.writeStr(message);
        self.writeStrSlice(buttons);
        const q = self.flushQuery();
        open.* = q.bool_val != 0;
        return @intCast(q.int_val);
    }

    /// Editable combobox: chooses among `options` or accepts free-form text.
    /// `selected` is the option index, or `-1` when the typed value is custom.
    /// `buf`/`len` hold the current string (required for free-form editing).
    pub fn combobox(
        self: *Context,
        key: []const u8,
        selected: *i32,
        options: []const []const u8,
        buf: []u8,
        len: *usize,
    ) Element {
        self.writeOp(@intFromEnum(CoreOp.combobox));
        self.writeStr(key);
        self.writeI32(selected.*);
        self.writeStr(buf[0..len.*]);
        self.writeStrSlice(options);
        var q = CQuery{
            .text_buf_ptr = if (buf.len > 0) @intFromPtr(buf.ptr) else 0,
            .text_buf_cap = buf.len,
        };
        self.flushQueryInto(&q);
        selected.* = @intCast(q.int_val);
        if (q.bool_val != 0) {
            len.* = @min(q.text_len, buf.len);
        }
        return .{ .ctx = self };
    }

    pub fn radio(self: *Context, key: []const u8, selected: *i32, value: i32, lbl: []const u8) Element {
        self.ensureSpace(18 + key.len + lbl.len);
        self.writeOp(@intFromEnum(CoreOp.radio));
        self.writeStr(key);
        self.writeI32(selected.*);
        self.writeI32(value);
        self.writeStr(lbl);
        selected.* = @intCast(self.flushQuery().int_val);
        return .{ .ctx = self };
    }

    pub fn sidebar(self: *Context, key: []const u8, selected: *i32, items: []const []const u8) Element {
        self.writeOp(@intFromEnum(CoreOp.sidebar));
        self.writeStr(key);
        self.writeI32(selected.*);
        self.writeStrSlice(items);
        selected.* = @intCast(self.flushQuery().int_val);
        return .{ .ctx = self };
    }

    pub fn collapsible(
        self: *Context,
        key: []const u8,
        lbl: []const u8,
        open: *bool,
        comptime StatePtr: type,
        state: StatePtr,
        comptime bodyFn: fn (StatePtr, *Context) void,
    ) Element {
        const body_id = registerSubview(StatePtr, bodyFn);
        self.ensureSpace(28 + key.len + lbl.len);
        self.writeOp(@intFromEnum(CoreOp.collapsible));
        self.writeStr(key);
        self.writeStr(lbl);
        self.writeU8(@intFromBool(open.*));
        self.writeU64(@intCast(body_id));
        self.writeU64(@intCast(@intFromPtr(state)));
        open.* = self.flushQuery().bool_val != 0;
        return .{ .ctx = self };
    }

    pub fn split(
        self: *Context,
        key: []const u8,
        size: *f32,
        comptime StatePtr: type,
        state: StatePtr,
        comptime firstFn: fn (StatePtr, *Context) void,
        comptime secondFn: fn (StatePtr, *Context) void,
    ) Element {
        return self.splitImpl(key, false, false, size, StatePtr, state, firstFn, secondFn);
    }

    pub fn splitVertical(
        self: *Context,
        key: []const u8,
        size: *f32,
        comptime StatePtr: type,
        state: StatePtr,
        comptime firstFn: fn (StatePtr, *Context) void,
        comptime secondFn: fn (StatePtr, *Context) void,
    ) Element {
        return self.splitImpl(key, true, false, size, StatePtr, state, firstFn, secondFn);
    }

    pub fn splitPercent(
        self: *Context,
        key: []const u8,
        percent: *f32,
        comptime StatePtr: type,
        state: StatePtr,
        comptime firstFn: fn (StatePtr, *Context) void,
        comptime secondFn: fn (StatePtr, *Context) void,
    ) Element {
        return self.splitImpl(key, false, true, percent, StatePtr, state, firstFn, secondFn);
    }

    pub fn splitVerticalPercent(
        self: *Context,
        key: []const u8,
        percent: *f32,
        comptime StatePtr: type,
        state: StatePtr,
        comptime firstFn: fn (StatePtr, *Context) void,
        comptime secondFn: fn (StatePtr, *Context) void,
    ) Element {
        return self.splitImpl(key, true, true, percent, StatePtr, state, firstFn, secondFn);
    }

    fn splitImpl(
        self: *Context,
        key: []const u8,
        vertical: bool,
        percent: bool,
        size: *f32,
        comptime StatePtr: type,
        state: StatePtr,
        comptime firstFn: fn (StatePtr, *Context) void,
        comptime secondFn: fn (StatePtr, *Context) void,
    ) Element {
        const first_id = registerSubview(StatePtr, firstFn);
        const second_id = registerSubview(StatePtr, secondFn);
        var mode: u8 = 0;
        if (vertical) mode |= 1;
        if (percent) mode |= 2;
        self.ensureSpace(36 + key.len);
        self.writeOp(@intFromEnum(CoreOp.split));
        self.writeStr(key);
        self.writeU8(mode);
        self.writeF32(size.*);
        self.writeU64(@intCast(first_id));
        self.writeU64(@intCast(second_id));
        self.writeU64(@intCast(@intFromPtr(state)));
        size.* = @floatCast(self.flushQuery().num_val);
        return .{ .ctx = self };
    }

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

    /// Virtualized multi-column resizable `ui.Table`.
    pub fn table(
        self: *Context,
        key: []const u8,
        columns: []const TableColumn,
        row_count: usize,
        selected_row: *i32,
        comptime StatePtr: type,
        state: StatePtr,
        comptime cellFn: fn (StatePtr, TableCell) void,
    ) Element {
        const S = struct {
            var cb_id: usize = 0;
            fn onCell(cell_handle: usize, info: *const CTableCellInfo, ud: usize) void {
                const s: StatePtr = @ptrFromInt(ud);
                var cell_ctx = Context.initForCell(cell_handle, info);
                cellFn(s, .{
                    .ctx = &cell_ctx,
                    .row = @intCast(info.row),
                    .col = @intCast(info.col),
                    .selected = info.selected != 0,
                });
                cell_ctx.flush();
            }
        };
        if (S.cb_id == 0) {
            mygo.ui_table_cell_handlers[mygo.ui_table_cell_count] = &S.onCell;
            mygo.ui_table_cell_count += 1;
            S.cb_id = mygo.ui_table_cell_count;
        }
        self.writeOp(@intFromEnum(CoreOp.table));
        self.writeStr(key);
        self.writeU16(@intCast(columns.len));
        for (columns) |col| {
            self.writeStr(col.title);
            self.writeF32(col.width);
            self.writeU8(@intFromEnum(col.@"align"));
        }
        self.writeI32(@intCast(row_count));
        self.writeI32(selected_row.*);
        self.writeU64(@intCast(S.cb_id));
        self.writeU64(@intCast(@intFromPtr(state)));
        selected_row.* = @intCast(self.flushQuery().int_val);
        return .{ .ctx = self };
    }

    // =========================================================================
    // Additional widgets
    // =========================================================================

    pub fn spinner(self: *Context) Element {
        self.writeOp(@intFromEnum(CoreOp.spinner));
        return .{ .ctx = self };
    }

    pub fn searchField(self: *Context, key: []const u8, buf: []u8, len: *usize) Element {
        self.ensureSpace(10 + key.len + len.*);
        self.writeOp(@intFromEnum(CoreOp.search_field));
        self.writeStr(key);
        self.writeStr(buf[0..len.*]);
        var q = CQuery{
            .text_buf_ptr = if (buf.len > 0) @intFromPtr(buf.ptr) else 0,
            .text_buf_cap = buf.len,
        };
        self.flushQueryInto(&q);
        if (q.bool_val != 0) len.* = @min(q.text_len, buf.len);
        return .{ .ctx = self };
    }

    pub fn autocomplete(self: *Context, key: []const u8, buf: []u8, len: *usize, suggestions: []const []const u8) Element {
        self.writeOp(@intFromEnum(CoreOp.autocomplete));
        self.writeStr(key);
        self.writeStr(buf[0..len.*]);
        self.writeStrSlice(suggestions);
        var q = CQuery{
            .text_buf_ptr = if (buf.len > 0) @intFromPtr(buf.ptr) else 0,
            .text_buf_cap = buf.len,
        };
        self.flushQueryInto(&q);
        if (q.bool_val != 0) len.* = @min(q.text_len, buf.len);
        return .{ .ctx = self };
    }

    pub fn numberInput(self: *Context, key: []const u8, value: *f64, lo: f64, hi: f64, step: f64) Element {
        return self.numericControl(.number_input, key, value, lo, hi, step);
    }

    pub fn stepper(self: *Context, key: []const u8, value: *f64, lo: f64, hi: f64, step: f64) Element {
        return self.numericControl(.stepper, key, value, lo, hi, step);
    }

    pub fn stepSlider(self: *Context, key: []const u8, value: *f64, lo: f64, hi: f64, step: f64) Element {
        return self.numericControl(.step_slider, key, value, lo, hi, step);
    }

    fn numericControl(self: *Context, op: CoreOp, key: []const u8, value: *f64, lo: f64, hi: f64, step: f64) Element {
        self.ensureSpace(38 + key.len);
        self.writeOp(@intFromEnum(op));
        self.writeStr(key);
        self.writeF64(value.*);
        self.writeF64(lo);
        self.writeF64(hi);
        self.writeF64(step);
        value.* = self.flushQuery().num_val;
        return .{ .ctx = self };
    }

    pub fn rangeSlider(self: *Context, key: []const u8, low: *f64, high: *f64, lo: f64, hi: f64, step: f64) Element {
        self.ensureSpace(46 + key.len);
        self.writeOp(@intFromEnum(CoreOp.range_slider));
        self.writeStr(key);
        self.writeF64(low.*);
        self.writeF64(high.*);
        self.writeF64(lo);
        self.writeF64(hi);
        self.writeF64(step);
        const q = self.flushQuery();
        low.* = q.num_val;
        high.* = q.num_val2;
        return .{ .ctx = self };
    }

    pub fn rating(self: *Context, key: []const u8, value: *i32, max: i32) Element {
        self.ensureSpace(14 + key.len);
        self.writeOp(@intFromEnum(CoreOp.rating));
        self.writeStr(key);
        self.writeI32(value.*);
        self.writeI32(max);
        value.* = @intCast(self.flushQuery().int_val);
        return .{ .ctx = self };
    }

    /// Date picker; `unix_ms` is milliseconds since Unix epoch (UTC).
    pub fn dateInput(self: *Context, key: []const u8, unix_ms: *i64) Element {
        return self.timeLike(.date_input, key, unix_ms);
    }

    /// Time-of-day picker; `unix_ms` is milliseconds since Unix epoch (UTC).
    pub fn timeInput(self: *Context, key: []const u8, unix_ms: *i64) Element {
        return self.timeLike(.time_input, key, unix_ms);
    }

    /// Full calendar month view; `unix_ms` is milliseconds since Unix epoch (UTC).
    pub fn calendar(self: *Context, key: []const u8, unix_ms: *i64) Element {
        return self.timeLike(.calendar, key, unix_ms);
    }

    fn timeLike(self: *Context, op: CoreOp, key: []const u8, unix_ms: *i64) Element {
        self.ensureSpace(14 + key.len);
        self.writeOp(@intFromEnum(op));
        self.writeStr(key);
        self.writeU64(@bitCast(unix_ms.*));
        unix_ms.* = self.flushQuery().int_val;
        return .{ .ctx = self };
    }

    pub fn colorPicker(self: *Context, key: []const u8, color: *Color) Element {
        return self.colorControl(.color_picker, key, color);
    }

    pub fn colorWell(self: *Context, key: []const u8, color: *Color) Element {
        return self.colorControl(.color_well, key, color);
    }

    fn colorControl(self: *Context, op: CoreOp, key: []const u8, color: *Color) Element {
        self.ensureSpace(10 + key.len);
        self.writeOp(@intFromEnum(op));
        self.writeStr(key);
        self.writeU32(color.toU32());
        color.* = Color.fromU32(@intCast(self.flushQuery().int_val));
        return .{ .ctx = self };
    }

    pub fn avatar(self: *Context, name: []const u8) Element {
        self.ensureSpace(6 + name.len);
        self.writeOp(@intFromEnum(CoreOp.avatar));
        self.writeStr(name);
        return .{ .ctx = self };
    }

    pub fn breadcrumbs(self: *Context, key: []const u8, chosen: *i32, items: []const []const u8) Element {
        self.writeOp(@intFromEnum(CoreOp.breadcrumbs));
        self.writeStr(key);
        self.writeI32(chosen.*);
        self.writeStrSlice(items);
        chosen.* = @intCast(self.flushQuery().int_val);
        return .{ .ctx = self };
    }

    pub fn scrollHorizontal(self: *Context, key: []const u8) Element {
        self.ensureSpace(6 + key.len);
        self.writeOp(@intFromEnum(CoreOp.scroll_horizontal));
        self.writeStr(key);
        return .{ .ctx = self };
    }

    pub fn scrollBoth(self: *Context, key: []const u8) Element {
        self.ensureSpace(6 + key.len);
        self.writeOp(@intFromEnum(CoreOp.scroll_both));
        self.writeStr(key);
        return .{ .ctx = self };
    }

    pub fn decimalInput(self: *Context, key: []const u8, buf: []u8, len: *usize, lo: []const u8, hi: []const u8, step: []const u8) Element {
        self.writeOp(@intFromEnum(CoreOp.decimal_input));
        self.writeStr(key);
        self.writeStr(buf[0..len.*]);
        self.writeStr(lo);
        self.writeStr(hi);
        self.writeStr(step);
        var q = CQuery{
            .text_buf_ptr = if (buf.len > 0) @intFromPtr(buf.ptr) else 0,
            .text_buf_cap = buf.len,
        };
        self.flushQueryInto(&q);
        if (q.bool_val != 0) len.* = @min(q.text_len, buf.len);
        return .{ .ctx = self };
    }

    pub fn checkboxGroup(
        self: *Context,
        key: []const u8,
        lbl: []const u8,
        comptime StatePtr: type,
        state: StatePtr,
        comptime bodyFn: fn (StatePtr, *Context) void,
    ) Element {
        const body_id = registerSubview(StatePtr, bodyFn);
        self.ensureSpace(26 + key.len + lbl.len);
        self.writeOp(@intFromEnum(CoreOp.checkbox_group));
        self.writeStr(key);
        self.writeStr(lbl);
        self.writeU64(@intCast(body_id));
        self.writeU64(@intCast(@intFromPtr(state)));
        return .{ .ctx = self };
    }

    pub fn radioGroup(
        self: *Context,
        key: []const u8,
        comptime StatePtr: type,
        state: StatePtr,
        comptime bodyFn: fn (StatePtr, *Context) void,
    ) Element {
        return self.groupBody(.radio_group, key, StatePtr, state, bodyFn);
    }

    pub fn toggleGroup(
        self: *Context,
        key: []const u8,
        comptime StatePtr: type,
        state: StatePtr,
        comptime bodyFn: fn (StatePtr, *Context) void,
    ) Element {
        return self.groupBody(.toggle_group, key, StatePtr, state, bodyFn);
    }

    fn groupBody(
        self: *Context,
        op: CoreOp,
        key: []const u8,
        comptime StatePtr: type,
        state: StatePtr,
        comptime bodyFn: fn (StatePtr, *Context) void,
    ) Element {
        const body_id = registerSubview(StatePtr, bodyFn);
        self.ensureSpace(22 + key.len);
        self.writeOp(@intFromEnum(op));
        self.writeStr(key);
        self.writeU64(@intCast(body_id));
        self.writeU64(@intCast(@intFromPtr(state)));
        return .{ .ctx = self };
    }

    pub fn fieldset(
        self: *Context,
        key: []const u8,
        legend: []const u8,
        comptime StatePtr: type,
        state: StatePtr,
        comptime bodyFn: fn (StatePtr, *Context) void,
    ) Element {
        const body_id = registerSubview(StatePtr, bodyFn);
        self.ensureSpace(26 + key.len + legend.len);
        self.writeOp(@intFromEnum(CoreOp.fieldset));
        self.writeStr(key);
        self.writeStr(legend);
        self.writeU64(@intCast(body_id));
        self.writeU64(@intCast(@intFromPtr(state)));
        return .{ .ctx = self };
    }

    pub fn accordion(
        self: *Context,
        key: []const u8,
        comptime StatePtr: type,
        state: StatePtr,
        comptime bodyFn: fn (StatePtr, *Context) void,
    ) Element {
        return self.groupBody(.accordion, key, StatePtr, state, bodyFn);
    }

    pub fn accordionItem(
        self: *Context,
        key: []const u8,
        title: []const u8,
        open: *bool,
        comptime StatePtr: type,
        state: StatePtr,
        comptime bodyFn: fn (StatePtr, *Context) void,
    ) Element {
        const body_id = registerSubview(StatePtr, bodyFn);
        self.ensureSpace(28 + key.len + title.len);
        self.writeOp(@intFromEnum(CoreOp.accordion_item));
        self.writeStr(key);
        self.writeStr(title);
        self.writeU8(@intFromBool(open.*));
        self.writeU64(@intCast(body_id));
        self.writeU64(@intCast(@intFromPtr(state)));
        open.* = self.flushQuery().bool_val != 0;
        return .{ .ctx = self };
    }

    pub fn modal(
        self: *Context,
        key: []const u8,
        open: *bool,
        comptime StatePtr: type,
        state: StatePtr,
        comptime bodyFn: fn (StatePtr, *Context) void,
    ) Element {
        const body_id = registerSubview(StatePtr, bodyFn);
        self.ensureSpace(23 + key.len);
        self.writeOp(@intFromEnum(CoreOp.modal));
        self.writeStr(key);
        self.writeU8(@intFromBool(open.*));
        self.writeU64(@intCast(body_id));
        self.writeU64(@intCast(@intFromPtr(state)));
        open.* = self.flushQuery().bool_val != 0;
        return .{ .ctx = self };
    }

    pub fn field(
        self: *Context,
        key: []const u8,
        lbl: []const u8,
        comptime StatePtr: type,
        state: StatePtr,
        comptime bodyFn: fn (StatePtr, *Context) void,
    ) Element {
        const body_id = registerSubview(StatePtr, bodyFn);
        self.ensureSpace(26 + key.len + lbl.len);
        self.writeOp(@intFromEnum(CoreOp.field));
        self.writeStr(key);
        self.writeStr(lbl);
        self.writeU64(@intCast(body_id));
        self.writeU64(@intCast(@intFromPtr(state)));
        return .{ .ctx = self };
    }

    pub fn form(
        self: *Context,
        key: []const u8,
        comptime StatePtr: type,
        state: StatePtr,
        comptime bodyFn: fn (StatePtr, *Context) void,
    ) Element {
        return self.groupBody(.form, key, StatePtr, state, bodyFn);
    }

    /// Editable token/chip field. `tokens_buf` receives a packed string-list
    /// (`u16` count + length-prefixed UTF-8) when the value changes; decode
    /// with `readStrList`. `tokens` is the current list sent to the host.
    pub fn tokenField(
        self: *Context,
        key: []const u8,
        tokens: []const []const u8,
        suggestions: []const []const u8,
        tokens_buf: []u8,
        tokens_len: *usize,
    ) Element {
        self.writeOp(@intFromEnum(CoreOp.token_field));
        self.writeStr(key);
        self.writeStrSlice(tokens);
        self.writeStrSlice(suggestions);
        var q = CQuery{
            .text_buf_ptr = if (tokens_buf.len > 0) @intFromPtr(tokens_buf.ptr) else 0,
            .text_buf_cap = tokens_buf.len,
        };
        self.flushQueryInto(&q);
        if (q.bool_val != 0) tokens_len.* = q.text_len;
        return .{ .ctx = self };
    }

    pub fn tree(
        self: *Context,
        key: []const u8,
        comptime StatePtr: type,
        state: StatePtr,
        comptime bodyFn: fn (StatePtr, *Context) void,
    ) Element {
        return self.groupBody(.tree, key, StatePtr, state, bodyFn);
    }

    /// Tree item. Pass `open != null` for a branch (children built by `bodyFn`);
    /// pass `open == null` for a leaf (`bodyFn` ignored).
    pub fn treeItem(
        self: *Context,
        key: []const u8,
        lbl: []const u8,
        open: ?*bool,
        comptime StatePtr: type,
        state: StatePtr,
        comptime bodyFn: fn (StatePtr, *Context) void,
    ) Element {
        const has_kids: u8 = if (open != null) 1 else 0;
        const body_id = if (open != null) registerSubview(StatePtr, bodyFn) else 0;
        self.ensureSpace(30 + key.len + lbl.len);
        self.writeOp(@intFromEnum(CoreOp.tree_item));
        self.writeStr(key);
        self.writeStr(lbl);
        self.writeU8(if (open) |o| @intFromBool(o.*) else 0);
        self.writeU8(has_kids);
        self.writeU64(@intCast(body_id));
        self.writeU64(@intCast(@intFromPtr(state)));
        if (open) |o| {
            o.* = self.flushQuery().bool_val != 0;
        }
        return .{ .ctx = self };
    }

    /// Draws into the window overlay layer (no returned element).
    pub fn overlay(
        self: *Context,
        comptime StatePtr: type,
        state: StatePtr,
        comptime bodyFn: fn (StatePtr, *Context) void,
    ) void {
        const body_id = registerSubview(StatePtr, bodyFn);
        self.ensureSpace(18);
        self.writeOp(@intFromEnum(CoreOp.overlay));
        self.writeU64(@intCast(body_id));
        self.writeU64(@intCast(@intFromPtr(state)));
        self.flush();
    }

    /// Shows a popover anchored to the most recently built element (`f.cur`).
    /// Call immediately after the anchor widget (e.g. a button).
    pub fn popover(
        self: *Context,
        open: *bool,
        comptime StatePtr: type,
        state: StatePtr,
        comptime bodyFn: fn (StatePtr, *Context) void,
    ) Element {
        const body_id = registerSubview(StatePtr, bodyFn);
        self.ensureSpace(19);
        self.writeOp(@intFromEnum(CoreOp.popover));
        self.writeU8(@intFromBool(open.*));
        self.writeU64(@intCast(body_id));
        self.writeU64(@intCast(@intFromPtr(state)));
        open.* = self.flushQuery().bool_val != 0;
        return .{ .ctx = self };
    }

    // =========================================================================
    // Opt-in Rich Extensions (`zig/host/markdown` & `zig/host/editor`)
    // =========================================================================

    /// Renders GitHub-Flavored Markdown (`_ "github.com/egoist/mygo/zig/host/markdown"`).
    pub fn markdown(self: *Context, md_src: []const u8) Element {
        self.flush();
        _ = mygo.dispatch(.markdown_view, self.frame_handle, mygo.sliceAddr(md_src), md_src.len, 0);
        return .{ .ctx = self };
    }

    /// Renders streaming Markdown (`markdown.Stream`).
    pub fn markdownStream(self: *Context, md_src: []const u8) Element {
        self.flush();
        _ = mygo.dispatch(.markdown_view, self.frame_handle, mygo.sliceAddr(md_src), md_src.len, 1);
        return .{ .ctx = self };
    }

    /// Syntax-highlighted code editor (`_ "github.com/egoist/mygo/zig/host/editor"`).
    pub fn codeEditor(
        self: *Context,
        file_name: []const u8,
        initial_text: []const u8,
        sync_buf: ?[]u8,
        sync_len: ?*usize,
        soft_wrap: bool,
        out_stats: ?*EditorStats,
    ) Element {
        self.flush();
        var spec = CEditorSpec{
            .file_name = mygo.CStr.fromSlice(file_name),
            .initial_text = mygo.CStr.fromSlice(initial_text),
            .soft_wrap = @intFromBool(soft_wrap),
        };
        var raw_stats = CEditorStats{
            .text_buf_ptr = if (sync_buf) |b| (if (b.len > 0) @intFromPtr(b.ptr) else 0) else 0,
            .text_buf_cap = if (sync_buf) |b| b.len else 0,
        };
        _ = mygo.dispatch(.editor_view, self.frame_handle, @intFromPtr(&spec), @intFromPtr(&raw_stats), 0);
        if (raw_stats.changed_now != 0) {
            if (sync_len) |l| l.* = raw_stats.text_len;
        }
        if (out_stats) |st| {
            st.* = .{
                .line = raw_stats.line,
                .col = raw_stats.col,
                .line_count = raw_stats.line_count,
                .added = raw_stats.added,
                .deleted = raw_stats.deleted,
                .hunk_count = raw_stats.hunk_count,
                .modified = raw_stats.modified != 0,
            };
        }
        return .{ .ctx = self };
    }

    /// Side-by-side (`split_layout = true`) or unified diff viewer sharing the
    /// buffer of `codeEditor` with the same `file_name`.
    pub fn diffView(
        self: *Context,
        file_name: []const u8,
        initial_text: []const u8,
        split_layout: bool,
        soft_wrap: bool,
    ) Element {
        self.flush();
        var spec = CEditorSpec{
            .file_name = mygo.CStr.fromSlice(file_name),
            .initial_text = mygo.CStr.fromSlice(initial_text),
            .soft_wrap = @intFromBool(soft_wrap),
            .split_layout = @intFromBool(split_layout),
        };
        var raw_stats = CEditorStats{};
        _ = mygo.dispatch(.diff_view, self.frame_handle, @intFromPtr(&spec), @intFromPtr(&raw_stats), 0);
        return .{ .ctx = self };
    }
};
