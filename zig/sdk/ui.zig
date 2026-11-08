//! Zero-allocation CommandBuffer client for MyGo's GPU-accelerated Native UI (`package ui`).
//!
//! Combines:
//! - 202 AST-generated `Element` style & layout modifiers (`element_gen.zig`),
//! - Rich controls (`Tabs`, `Segmented`, `Select`, `Radio`, `Sidebar`, `Collapsible`,
//!   `Split` / `SplitVertical`, `Badge`, `Link`, `Progress`, `Meter`, `TextArea`),
//! - Virtualized 100,000+ row `List` & multi-column `Table`,
//! - Custom GPU vector drawing (`elem.draw(...)` + `Painter`),
//! - Opt-in GFM `markdown`, `codeEditor`, charts, and `terminalView`
//! - Opt-in GFM `markdown` (`zig/host/markdown`) & syntax-highlighted `codeEditor` +
//!   `diffView` (`zig/host/editor`),
//! - All running over a single `purego` callback (`CGO_ENABLED=0`).

const std = @import("std");
const mygo = @import("mygo.zig");
const abi = @import("abi.zig");
pub const Element = @import("element_gen.zig").Element;

pub const RawViewHandler = *const fn (frame_handle: usize, info: *const CFrameInfo, userdata: usize) void;
pub const RawListRowHandler = *const fn (frame_handle: usize, info: *const CListRowInfo, userdata: usize) void;
pub const RawTableCellHandler = *const fn (frame_handle: usize, info: *const CTableCellInfo, userdata: usize) void;
pub const RawPaintHandler = *const fn (painter_handle: usize, rect: *const CRect, userdata: usize) void;
pub const RawActionHandler = *const fn (userdata: usize) void;
pub const RawProvideHandler = *const fn (buf: []u8, userdata: usize) usize;
pub const RawGridItemHandler = *const fn (frame_handle: usize, info: *const CGridItemInfo, userdata: usize) void;
pub const RawOutlineRowHandler = *const fn (frame_handle: usize, info: *const COutlineRowInfo, userdata: usize) void;
pub const RawRouteHandler = *const fn (frame_handle: usize, info: *const CRouteInfo, userdata: usize) void;
pub const RawOutlineCellHandler = *const fn (frame_handle: usize, info: *const COutlineCellInfo, userdata: usize) void;

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

/// Which arrows move the focus in a `FocusGroup`.
pub const Orientation = packed struct(u8) {
    horizontal: bool = false,
    vertical: bool = false,
    _pad: u6 = 0,
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
    f1 = 16,
    f2 = 17,
    f3 = 18,
    f4 = 19,
    f5 = 20,
    f6 = 21,
    f7 = 22,
    f8 = 23,
    f9 = 24,
    f10 = 25,
    f11 = 26,
    f12 = 27,
    _,
};

/// The device moving the pointer (`float` events' pointerType).
pub const PointerType = enum(u8) {
    mouse = 0,
    pen = 1,
    touch = 2,
    _,
};

/// Kinds of input (`ui.InputKind`).
pub const InputKind = enum(u8) {
    key_down = 1,
    key_up = 2,
    text = 3,
    compose = 4,
    command = 5,
    pointer_down = 6,
    pointer_up = 7,
    pointer_move = 8,
    scroll = 9,
    select = 10,
    zoom = 11,
    _,
};

/// One input event, as an element's `observeInput` / `handleInput` see it.
pub const InputEvent = struct {
    kind: InputKind = .key_down,
    key: Key = .unknown,
    physical_key: Key = .unknown,
    /// The key by its position on any keyboard (`ui.KeyCode`).
    code: u16 = 0,
    mods: Modifiers = .{},
    repeat: bool = false,
    canceled: bool = false,
    /// UTF-8 text of a text or compose event; valid while the handler runs.
    text: []const u8 = "",
    caret: i32 = 0,
    x: f32 = 0,
    y: f32 = 0,
    button: i32 = 0,
    clicks: i32 = 0,
    pointer: PointerType = .mouse,
    pressure: f32 = 0,
    dx: f32 = 0,
    dy: f32 = 0,
    precise: bool = false,
    momentum: bool = false,
    scale: f32 = 0,
    start: i32 = 0,
    end: i32 = 0,
};

pub const CInput = abi.Input;
pub const Hit = abi.Hit;

/// inputEvent reads a host event. The text slice is valid while the handler runs.
pub fn inputEvent(c: *const abi.Input) InputEvent {
    const text: []const u8 = if (c.text_len > 0 and c.text_ptr != 0)
        @as([*]const u8, @ptrFromInt(c.text_ptr))[0..c.text_len]
    else
        "";
    return .{
        .kind = @enumFromInt(@as(u8, @truncate(c.kind))),
        .key = @enumFromInt(@as(u16, @truncate(c.key))),
        .physical_key = @enumFromInt(@as(u16, @truncate(c.physical_key))),
        .code = @truncate(c.code),
        .mods = @bitCast(@as(u8, @truncate(c.mods))),
        .repeat = c.flags & 1 != 0,
        .canceled = c.flags & 2 != 0,
        .precise = c.flags & 4 != 0,
        .momentum = c.flags & 8 != 0,
        .text = text,
        .caret = c.caret,
        .x = c.x,
        .y = c.y,
        .button = @bitCast(c.button),
        .clicks = @bitCast(c.clicks),
        .pointer = @enumFromInt(@as(u8, @truncate(c.pointer))),
        .pressure = c.pressure,
        .dx = c.dx,
        .dy = c.dy,
        .scale = c.scale,
        .start = c.start,
        .end = c.end,
    };
}

/// registerInputHandler adds an element input handler, returning its id.
pub fn registerInputHandler(handler: mygo.RawUIInput) usize {
    if (mygo.ui_input_count >= mygo.ui_input_handlers.len) return 0;
    mygo.ui_input_handlers[mygo.ui_input_count] = handler;
    mygo.ui_input_count += 1;
    return mygo.ui_input_count;
}

/// registerHitHandler adds an element hit test, returning its id.
pub fn registerHitHandler(handler: mygo.RawUIHit) usize {
    if (mygo.ui_hit_count >= mygo.ui_hit_handlers.len) return 0;
    mygo.ui_hit_handlers[mygo.ui_hit_count] = handler;
    mygo.ui_hit_count += 1;
    return mygo.ui_hit_count;
}

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
    grid = 67,
    editable_text = 68,
    find_bar = 69,
    toolbar = 70,
    themed = 71,
    icon = 72,
    image = 73,
    toast = 74,
    toast_action = 75,
    menu_button = 76,
    grid_view = 77,
    context_menu = 78,
    popover_menu = 79,

    query_clicked = 80,
    query_hovered = 81,
    query_pressed = 82,
    query_changed = 83,
    query_submitted = 84,
    query_shortcut = 85,

    popover_menu_button = 86,
    outline = 87,
    rich_text = 88,
    router = 89,
    router_push = 90,
    router_replace = 91,
    router_back = 92,
    router_forward = 93,
    back_button = 94,
    forward_button = 95,
    outline_table = 96,
    drag = 97,
    drop = 98,
    drag_over = 99,

    // 100..301 = Element modifiers (uigen). Widget ops continue after.
    draggable = 302,
    web_view = 303,
    web_view_destroy = 304,
    web_view_handle = 340,
    drag_data = 305,
    drop_data = 306,
    data_drag_over = 307,
    video = 308,
    video_control = 309,
    route_view = 310,
    route_match = 311,
    route_param = 312,
    draw_objects = 313,
    toast_viewport = 314,
    toast_item = 315,
    toast_close_btn = 316,
    toast_action_btn = 317,
    drag_mime = 318,
    drop_mime = 319,
    drag_mime_lazy = 320,
    add_toast = 321,
    after = 322,
    animation_frame = 323,
    disable_animations = 324,
    invalidate = 325,
    close_toast = 326,
    animate = 327,
    animate_to = 328,
    arrived = 329,
    animate_color = 330,
    animate_pose = 331,
    spring = 332,
    role = 333,
    linear_gradient = 334,
    bitmap = 335,
    canvas = 336,
    linear_grad_stops = 337,
    conic_gradient = 338,
    radial_gradient = 339,

    // 360+ = hand-written Element queries and hooks (see element_gen.zig).
    query_focused = 360,
    query_focus_visible = 361,
    query_focus_within = 362,
    query_focus_left = 363,
    query_is_disabled = 364,
    query_highlighted = 365,
    query_dismissed = 366,
    query_double_clicked = 367,
    query_right_clicked = 368,
    query_clicks = 369,
    query_click_modifiers = 370,
    query_pressed_button = 371,
    query_pressed_inside = 372,
    query_pressed_outside = 373,
    query_pressed_pointer = 374,
    query_press_canceled = 375,
    query_composing = 376,
    query_bounds = 377,
    query_layout_bounds = 378,
    query_local_to_window = 379,
    query_window_to_local = 380,
    query_pointer_position = 381,
    query_in_view = 382,
    query_in_view_amount = 383,
    query_text_selection = 384,
    query_text_anchor_caret = 385,
    query_dragging = 386,
    query_drag_offset = 387,
    query_drag_velocity = 388,
    query_drag_ended = 389,
    query_drag_missed = 390,
    query_transitioning = 391,
    query_overlay_shortcut = 392,
    element_shortcut = 393,
    focus_group = 394,
    key_shortcuts = 395,
    query_in_view_margin = 396,
    observe_input = 397,
    handle_input = 398,
    hit_test = 399,
    scroll_snap = 400,
    scroll_into_view = 401,
    query_dropped_files = 402,
    query_file_drag_over = 403,
    mask_linear_gradient = 404,
    mask_radial_gradient = 405,
    mask_conic_gradient = 406,
    transition = 407,
    content_transition = 408,
    checkbox_state = 409,
    transform = 410,
};

/// A composed 2D/3D transform, as Element.transform applies it.
pub const Transform = struct {
    ops: [8]Op = undefined,
    len: u8 = 0,

    pub const Op = union(enum) {
        translate: [2]f32,
        translate_3d: [3]f32,
        scale: [2]f32,
        rotate: f32,
        skew: [2]f32,
        rotate_x: f32,
        rotate_y: f32,
        perspective: f32,
    };

    fn push(self: Transform, op: Op) Transform {
        var out = self;
        if (out.len < out.ops.len) {
            out.ops[out.len] = op;
            out.len += 1;
        }
        return out;
    }

    pub fn translate(self: Transform, x: f32, y: f32) Transform {
        return self.push(.{ .translate = .{ x, y } });
    }

    pub fn translate3D(self: Transform, x: f32, y: f32, z: f32) Transform {
        return self.push(.{ .translate_3d = .{ x, y, z } });
    }

    pub fn scale(self: Transform, x: f32, y: f32) Transform {
        return self.push(.{ .scale = .{ x, y } });
    }

    pub fn rotate(self: Transform, degrees: f32) Transform {
        return self.push(.{ .rotate = degrees });
    }

    pub fn rotateX(self: Transform, degrees: f32) Transform {
        return self.push(.{ .rotate_x = degrees });
    }

    pub fn rotateY(self: Transform, degrees: f32) Transform {
        return self.push(.{ .rotate_y = degrees });
    }

    pub fn skew(self: Transform, x: f32, y: f32) Transform {
        return self.push(.{ .skew = .{ x, y } });
    }

    pub fn perspective(self: Transform, distance: f32) Transform {
        return self.push(.{ .perspective = distance });
    }
};

/// The state of a check box that may be mixed, as a "select all" box.
pub const CheckState = enum(u8) {
    off = 0,
    on = 1,
    mixed = 2,
    _,
};

/// How an element's changes animate (Element.transition).
pub const TransitionOptions = struct {
    duration_ms: i32 = 0,
    delay_ms: i32 = 0,
    /// Negative shows every change at once, without a copy.
    exit_ms: i32 = 0,
    animation: AnimPreset = .custom,
    bounce: f32 = 0,
    non_motion: bool = false,
    position: bool = false,
    size: bool = false,
    colors: bool = false,
    shadows: bool = false,
    width: bool = false,
    height: bool = false,
};

/// How an element's content animates as it changes (Element.contentTransition).
pub const ContentTransitionOptions = struct {
    numeric: bool = false,
    down: bool = false,
    morph: bool = false,
    duration_ms: i32 = 0,
    delay_ms: i32 = 0,
    animation: AnimPreset = .custom,
    bounce: f32 = 0,
    non_motion: bool = false,
};

/// Where ScrollIntoView lines an element up (`ui.ScrollAlign`).
pub const ScrollAlign = enum(u8) {
    nearest = 0,
    start = 1,
    center = 2,
    end = 3,
    _,
};

/// How a scroll container rests (`ui.Snap`).
pub const Snap = enum(u8) {
    none = 0,
    mandatory = 1,
    proximity = 2,
    _,
};

const PaintOp = enum(u8) {
    fill_rect = 1,
    stroke_rect = 2,
    line = 3,
    text = 4,
    shadow = 5,
    animation_frame = 6,
    path_begin = 7,
    path_move = 8,
    path_line = 9,
    path_quad = 10,
    path_cubic = 11,
    path_close = 12,
    path_fill = 13,
    path_stroke = 14,
    path_svg = 15,
    fill_gradient = 16,
    path_fill_grad = 17,
    fill_grad_stops = 18,
    fill_conic = 19,
    fill_radial = 20,
    canvas_begin = 21,
    canvas_end = 22,
    image = 23,
};

pub const FillRule = enum(u8) {
    non_zero = 0,
    even_odd = 1,
};

pub const LineCap = enum(u8) {
    round = 0,
    butt = 1,
    square = 2,
};

pub const LineJoin = enum(u8) {
    round = 0,
    miter = 1,
    bevel = 2,
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
    vibrancy: u8 = 0,
    _pad: [2]u8 = .{ 0, 0 },
    title_bar_h: f32 = 0,
    title_bar_l: f32 = 0,
    title_bar_r: f32 = 0,
    theme: CTheme,
};

pub const TitleBar = struct {
    height: f32 = 0,
    left: f32 = 0,
    right: f32 = 0,
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

pub const CGridItemInfo = extern struct {
    window_id: i32,
    index: i32,
    selected: u8,
    _pad: [3]u8 = .{ 0, 0, 0 },
    theme: CTheme,
};

pub const COutlineRowInfo = extern struct {
    window_id: i32,
    index: i32,
    depth: i32,
    selected: u8,
    branch: u8,
    open: u8,
    _pad: u8 = 0,
    theme: CTheme,
    id_ptr: usize,
    id_len: usize,

    pub fn id(self: *const COutlineRowInfo) []const u8 {
        if (self.id_ptr == 0 or self.id_len == 0) return "";
        const p: [*]const u8 = @ptrFromInt(self.id_ptr);
        return p[0..self.id_len];
    }
};

pub const CRouteInfo = extern struct {
    window_id: i32,
    _pad: [4]u8 = .{ 0, 0, 0, 0 },
    theme: CTheme,
    path_ptr: usize,
    path_len: usize,

    pub fn path(self: *const CRouteInfo) []const u8 {
        if (self.path_ptr == 0 or self.path_len == 0) return "/";
        const p: [*]const u8 = @ptrFromInt(self.path_ptr);
        return p[0..self.path_len];
    }
};

pub const COutlineCellInfo = extern struct {
    window_id: i32,
    row: i32,
    col: i32,
    depth: i32,
    selected: u8,
    branch: u8,
    open: u8,
    _pad: u8 = 0,
    theme: CTheme,
    id_ptr: usize,
    id_len: usize,

    pub fn id(self: *const COutlineCellInfo) []const u8 {
        if (self.id_ptr == 0 or self.id_len == 0) return "";
        const p: [*]const u8 = @ptrFromInt(self.id_ptr);
        return p[0..self.id_len];
    }
};

pub const CRect = extern struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,
    now_ms: i64,
    at: i32 = 0,
    _pad_at: i32 = 0,
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
    num_val3: f64 = 0,
    num_val4: f64 = 0,
    int_val2: i64 = 0,
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

pub const GridItem = struct {
    ctx: *Context,
    index: usize,
    selected: bool,
};

pub const OutlineRow = struct {
    ctx: *Context,
    id: []const u8,
    index: i32,
    depth: i32,
    selected: bool,
    branch: bool,
    open: bool,
};

pub const Route = struct {
    ctx: *Context,
    path: []const u8,
};

pub const Span = struct {
    text: []const u8,
    weight: u16 = 400,
    size: f32 = 0,
    italic: bool = false,
    underline: bool = false,
    strikethrough: bool = false,
    color: ?Color = null,
    background: ?Color = null,
    /// When set, `text` should be U+FFFC object replacement characters.
    object_width: ?f32 = null,
    object_height: f32 = 0,
    object_descent: f32 = 0,

    pub fn plain(text: []const u8) Span {
        return .{ .text = text };
    }

    pub fn bold(text: []const u8) Span {
        return .{ .text = text, .weight = 700 };
    }

    pub fn colored(text: []const u8, color: Color) Span {
        return .{ .text = text, .color = color };
    }

    pub fn object(width: f32, height: f32, descent: f32) Span {
        return .{ .text = "\u{FFFC}", .object_width = width, .object_height = height, .object_descent = descent };
    }
};

pub const OutlineNode = struct {
    id: []const u8,
    /// `null` = leaf; empty slice = branch with no children yet.
    children: ?[]const []const u8 = null,
};

pub const OutlineCell = struct {
    ctx: *Context,
    id: []const u8,
    row: i32,
    col: i32,
    depth: i32,
    selected: bool,
    branch: bool,
    open: bool,
};

/// Nested menu entry for `menuButton` / `contextMenu` / `popoverMenu*`.
pub const MenuEntry = union(enum) {
    item: struct { id: []const u8, label: []const u8 },
    separator,
    submenu: struct { label: []const u8, entries: []const MenuEntry },

    pub fn ofLabel(lbl: []const u8) MenuEntry {
        return .{ .item = .{ .id = lbl, .label = lbl } };
    }

    pub fn ofItem(id: []const u8, lbl: []const u8) MenuEntry {
        return .{ .item = .{ .id = id, .label = lbl } };
    }

    pub fn sep() MenuEntry {
        return .separator;
    }

    pub fn ofSub(lbl: []const u8, entries: []const MenuEntry) MenuEntry {
        return .{ .submenu = .{ .label = lbl, .entries = entries } };
    }
};

pub const DragAxis = enum(u8) {
    both = 0,
    horizontal = 1,
    vertical = 2,
};




pub const GradientStop = struct {
    color: Color,
    at: f32,
};

pub const Point = struct {
    x: f32 = 0,
    y: f32 = 0,
};

pub const Fit = enum(u8) {
    contain = 0,
    cover = 1,
    fill_box = 2,
    scale_down = 3,
    natural_size = 4,
};

pub const Role = enum(u8) {
    auto = 0,
    none = 1,
    group = 2,
    text = 3,
    button = 4,
    link = 5,
    check_box = 6,
    radio = 7,
    @"switch" = 8,
    slider = 9,
    progress = 10,
    text_field = 11,
    image = 12,
    list = 13,
    scroll = 14,
    dialog = 15,
    popup = 16,
    tooltip = 17,
    pop_up_button = 18,
    tab_list = 19,
    tab = 20,
    splitter = 21,
    status = 22,
    table = 23,
    row = 24,
    cell = 25,
    column_header = 26,
    tree = 27,
    tree_item = 28,
    list_item = 29,
    menu_button = 30,
    toolbar = 31,
    radio_group = 32,
    toggle_button = 33,
    combo_box = 34,
    disclosure = 35,
    meter = 36,
    stepper = 37,
    color_well = 38,
    alert_dialog = 39,
    menu = 40,
    menu_bar = 41,
    menu_item = 42,
    menu_item_check_box = 43,
    menu_item_radio = 44,
    heading = 45,
    region = 46,
    log = 47,
    timer = 48,
    alert = 49,
    separator = 50,
    row_header = 51,
};
pub const AnimPreset = enum(u8) {
    /// Duration-based EaseOut curve (or Smooth spring when duration_ms == 0).
    custom = 0,
    smooth = 1,
    snappy = 2,
    bouncy = 3,
};

pub const Pose = struct {
    x: f32 = 0,
    y: f32 = 0,
    scale: f32 = 1,
    rotate: f32 = 0,
    fade: f32 = 0,
    x_percent: f32 = 0,
    y_percent: f32 = 0,
};
pub const DragBounds = struct {
    x: f32 = 0,
    y: f32 = 0,
    w: f32 = 0,
    h: f32 = 0,
    rigid: bool = false,
};

const CChartSpec = extern struct {
    xs_ptr: usize = 0,
    xs_len: usize = 0,
    ys_ptr: usize = 0,
    ys_len: usize = 0,
    color: u32 = 0,
    height: f32 = 160,
    flags: u8 = 1,
    _pad: [3]u8 = .{ 0, 0, 0 },
};

const CPieSpec = extern struct {
    values_ptr: usize = 0,
    values_len: usize = 0,
    colors_ptr: usize = 0,
    colors_len: usize = 0,
    height: f32 = 180,
    inner: f32 = 0,
    pad: f32 = 0.02,
    _pad: [4]u8 = .{ 0, 0, 0, 0 },
};

const CVideoGIFSpec = extern struct {
    key_ptr: usize = 0,
    key_len: usize = 0,
    gif_ptr: usize = 0,
    gif_len: usize = 0,
    loop: u8 = 1,
    _pad: [7]u8 = .{ 0, 0, 0, 0, 0, 0, 0 },
};

const CVideoFramesSpec = extern struct {
    key_ptr: usize = 0,
    key_len: usize = 0,
    width: u32 = 0,
    height: u32 = 0,
    frame_count: u32 = 0,
    loop: u8 = 1,
    _pad: [3]u8 = .{ 0, 0, 0 },
    durations_ptr: usize = 0,
    pixels_ptr: usize = 0,
    pixels_len: usize = 0,
};

const CVideoStreamSpec = extern struct {
    key_ptr: usize = 0,
    key_len: usize = 0,
    width: u32 = 0,
    height: u32 = 0,
    capacity: u32 = 4,
    loop: u8 = 0,
    _pad: [3]u8 = .{ 0, 0, 0 },
};

const CVideoPushSpec = extern struct {
    key_ptr: usize = 0,
    key_len: usize = 0,
    duration_ms: u32 = 0,
    _pad: [4]u8 = .{ 0, 0, 0, 0 },
    pixels_ptr: usize = 0,
    pixels_len: usize = 0,
};

pub const RouterState = struct {
    key: []const u8,
    path_buf: [256]u8 = undefined,
    path_len: usize = 1,
    can_go_back: bool = false,
    can_go_forward: bool = false,

    pub fn init(key: []const u8) RouterState {
        var s: RouterState = .{ .key = key, .path_len = 1 };
        s.path_buf[0] = '/';
        return s;
    }

    pub fn path(self: *const RouterState) []const u8 {
        return self.path_buf[0..self.path_len];
    }
};

pub const FindBarState = struct {
    open: bool = false,
    query_len: usize = 0,
    current: i32 = 0,
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

    /// Start a vector path (`ui.Path`). Follow with move/line/… then fill/stroke.
    pub fn pathBegin(self: *Painter, rule: FillRule, cap: LineCap, join: LineJoin, miter: f32) void {
        self.ensure(8);
        self.writeU8(@intFromEnum(PaintOp.path_begin));
        self.writeU8(@intFromEnum(rule));
        self.writeU8(@intFromEnum(cap));
        self.writeU8(@intFromEnum(join));
        self.writeF32(miter);
    }

    pub fn pathMoveTo(self: *Painter, x: f32, y: f32) void {
        self.ensure(9);
        self.writeU8(@intFromEnum(PaintOp.path_move));
        self.writeF32(x);
        self.writeF32(y);
    }

    pub fn pathLineTo(self: *Painter, x: f32, y: f32) void {
        self.ensure(9);
        self.writeU8(@intFromEnum(PaintOp.path_line));
        self.writeF32(x);
        self.writeF32(y);
    }

    pub fn pathQuadTo(self: *Painter, cx: f32, cy: f32, x: f32, y: f32) void {
        self.ensure(17);
        self.writeU8(@intFromEnum(PaintOp.path_quad));
        self.writeF32(cx);
        self.writeF32(cy);
        self.writeF32(x);
        self.writeF32(y);
    }

    pub fn pathCubicTo(self: *Painter, c1x: f32, c1y: f32, c2x: f32, c2y: f32, x: f32, y: f32) void {
        self.ensure(25);
        self.writeU8(@intFromEnum(PaintOp.path_cubic));
        self.writeF32(c1x);
        self.writeF32(c1y);
        self.writeF32(c2x);
        self.writeF32(c2y);
        self.writeF32(x);
        self.writeF32(y);
    }

    pub fn pathClose(self: *Painter) void {
        self.ensure(1);
        self.writeU8(@intFromEnum(PaintOp.path_close));
    }

    pub fn pathFill(self: *Painter, color: Color) void {
        self.ensure(5);
        self.writeU8(@intFromEnum(PaintOp.path_fill));
        self.writeU32(color.toU32());
    }

    pub fn pathStroke(self: *Painter, width: f32, color: Color) void {
        self.ensure(9);
        self.writeU8(@intFromEnum(PaintOp.path_stroke));
        self.writeF32(width);
        self.writeU32(color.toU32());
    }

    /// Parse an SVG path `d` string and fill and/or stroke it.
    /// Pass `fill` with a=0 to skip fill; `stroke_width <= 0` skips stroke.
    pub fn pathSVG(self: *Painter, d: []const u8, fill: Color, stroke_width: f32, stroke: Color) void {
        self.ensure(13 + d.len);
        self.writeU8(@intFromEnum(PaintOp.path_svg));
        self.writeStr(d);
        self.writeU32(fill.toU32());
        self.writeF32(stroke_width);
        self.writeU32(stroke.toU32());
    }

    pub fn fillLinearGradient(self: *Painter, x: f32, y: f32, w: f32, h: f32, radius: f32, angle: f32, from: Color, to: Color) void {
        self.ensure(37);
        self.writeU8(@intFromEnum(PaintOp.fill_gradient));
        self.writeF32(x);
        self.writeF32(y);
        self.writeF32(w);
        self.writeF32(h);
        self.writeF32(radius);
        self.writeF32(angle);
        self.writeU32(from.toU32());
        self.writeU32(to.toU32());
    }

    pub fn pathFillLinearGradient(self: *Painter, angle: f32, from: Color, to: Color) void {
        self.ensure(13);
        self.writeU8(@intFromEnum(PaintOp.path_fill_grad));
        self.writeF32(angle);
        self.writeU32(from.toU32());
        self.writeU32(to.toU32());
    }

    fn writeStops(self: *Painter, stops: []const GradientStop) void {
        const n: u8 = @intCast(@min(stops.len, 16));
        self.writeU8(n);
        for (stops[0..n]) |s| {
            self.writeU32(s.color.toU32());
            self.writeF32(s.at);
        }
    }

    pub fn fillLinearGradientStops(self: *Painter, x: f32, y: f32, w: f32, h: f32, radius: f32, angle: f32, oklab: bool, stops: []const GradientStop) void {
        self.ensure(22 + stops.len * 8);
        self.writeU8(@intFromEnum(PaintOp.fill_grad_stops));
        self.writeF32(x);
        self.writeF32(y);
        self.writeF32(w);
        self.writeF32(h);
        self.writeF32(radius);
        self.writeF32(angle);
        self.writeU8(@intFromBool(oklab));
        self.writeStops(stops);
    }

    pub fn fillConicGradient(self: *Painter, x: f32, y: f32, w: f32, h: f32, radius: f32, angle: f32, center: Point, oklab: bool, stops: []const GradientStop) void {
        self.ensure(30 + stops.len * 8);
        self.writeU8(@intFromEnum(PaintOp.fill_conic));
        self.writeF32(x);
        self.writeF32(y);
        self.writeF32(w);
        self.writeF32(h);
        self.writeF32(radius);
        self.writeF32(angle);
        self.writeF32(center.x);
        self.writeF32(center.y);
        self.writeU8(@intFromBool(oklab));
        self.writeStops(stops);
    }

    pub fn fillRadialGradient(self: *Painter, x: f32, y: f32, w: f32, h: f32, radius: f32, grad_radius: f32, center: Point, oklab: bool, stops: []const GradientStop) void {
        self.ensure(30 + stops.len * 8);
        self.writeU8(@intFromEnum(PaintOp.fill_radial));
        self.writeF32(x);
        self.writeF32(y);
        self.writeF32(w);
        self.writeF32(h);
        self.writeF32(radius);
        self.writeF32(grad_radius);
        self.writeF32(center.x);
        self.writeF32(center.y);
        self.writeU8(@intFromBool(oklab));
        self.writeStops(stops);
    }

    /// Begin drawing into a registered canvas. Nested paint ops until `canvasEnd`.
    pub fn canvasBegin(self: *Painter, key: []const u8) void {
        self.ensure(5 + key.len);
        self.writeU8(@intFromEnum(PaintOp.canvas_begin));
        self.writeStr(key);
    }

    pub fn canvasEnd(self: *Painter) void {
        self.ensure(1);
        self.writeU8(@intFromEnum(PaintOp.canvas_end));
    }

    pub fn image(self: *Painter, key: []const u8, x: f32, y: f32, w: f32, h: f32, fit: Fit) void {
        self.ensure(22 + key.len);
        self.writeU8(@intFromEnum(PaintOp.image));
        self.writeStr(key);
        self.writeF32(x);
        self.writeF32(y);
        self.writeF32(w);
        self.writeF32(h);
        self.writeU8(@intFromEnum(fit));
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


pub const GlassStyle = enum(u8) { regular = 0, clear = 1 };

pub const GlassOptions = struct {
    style: GlassStyle = .regular,
    tint: u32 = 0,
    interactive: bool = false,
    native: bool = false,
    clarity: f32 = 0,
};

pub const BlurOptions = struct {
    radius: f32 = 12,
    mask_from: u32 = 0,
    mask_to: u32 = 0,
    mask_angle: f32 = 180,
    has_mask: bool = false,
};

pub const Context = struct {
    frame_handle: usize,
    window: mygo.Window,
    width_dip: f32,
    height_dip: f32,
    window_active: bool,
    vibrancy: bool = false,
    title_bar: TitleBar = .{},
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
            .vibrancy = info.vibrancy != 0,
            .title_bar = .{ .height = info.title_bar_h, .left = info.title_bar_l, .right = info.title_bar_r },
            .ui_theme = Theme.fromC(info.theme),
        };
    }

    /// True when the window shows a system vibrancy/material behind content.
    pub fn hasVibrancy(self: *const Context) bool {
        return self.vibrancy;
    }

    /// Room taken by window controls when the title bar is hidden.
    pub fn titleBar(self: *const Context) TitleBar {
        return self.title_bar;
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

    pub fn flushQueryInto(self: *Context, q: *CQuery) void {
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

    /// A check box that may be mixed: a row that sets it to on when clicked,
    /// or to off when it is on.
    pub fn checkboxState(self: *Context, key: []const u8, state: *CheckState, lbl: []const u8) Element {
        self.writeOp(@intFromEnum(CoreOp.checkbox_state));
        self.writeStr(key);
        self.writeU8(@intFromEnum(state.*));
        self.writeStr(lbl);
        const q = self.flushQuery();
        state.* = @enumFromInt(@as(u8, @intCast(q.int_val)));
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

    pub fn grid(self: *Context, key: []const u8) Element {
        self.ensureSpace(6 + key.len);
        self.writeOp(@intFromEnum(CoreOp.grid));
        self.writeStr(key);
        return .{ .ctx = self };
    }

    pub fn editableText(self: *Context, key: []const u8, buf: []u8, len: *usize) Element {
        self.ensureSpace(10 + key.len + len.*);
        self.writeOp(@intFromEnum(CoreOp.editable_text));
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

    pub fn findBar(
        self: *Context,
        key: []const u8,
        open: *bool,
        query_buf: []u8,
        query_len: *usize,
        matches: i32,
        current: *i32,
    ) Element {
        self.writeOp(@intFromEnum(CoreOp.find_bar));
        self.writeStr(key);
        self.writeU8(@intFromBool(open.*));
        self.writeStr(query_buf[0..query_len.*]);
        self.writeI32(matches);
        self.writeI32(current.*);
        var q = CQuery{
            .text_buf_ptr = if (query_buf.len > 0) @intFromPtr(query_buf.ptr) else 0,
            .text_buf_cap = query_buf.len,
        };
        self.flushQueryInto(&q);
        open.* = q.bool_val != 0;
        current.* = @intCast(q.int_val);
        query_len.* = @min(q.text_len, query_buf.len);
        return .{ .ctx = self };
    }

    pub fn toolbar(
        self: *Context,
        key: []const u8,
        comptime StatePtr: type,
        state: StatePtr,
        comptime bodyFn: fn (StatePtr, *Context) void,
    ) Element {
        return self.groupBody(.toolbar, key, StatePtr, state, bodyFn);
    }

    /// Applies a local theme to children (use `.begin()` / `.end()`).
    pub fn themed(self: *Context, th: Theme) Element {
        self.ensureSpace(1 + 4 * 12 + 4 * 3);
        self.writeOp(@intFromEnum(CoreOp.themed));
        self.writeU8(@intFromBool(th.dark));
        self.writeU32(th.background.toU32());
        self.writeU32(th.surface.toU32());
        self.writeU32(th.surface_hover.toU32());
        self.writeU32(th.surface_pressed.toU32());
        self.writeU32(th.border.toU32());
        self.writeU32(th.text.toU32());
        self.writeU32(th.text_muted.toU32());
        self.writeU32(th.accent.toU32());
        self.writeU32(th.accent_text.toU32());
        self.writeU32(th.danger.toU32());
        self.writeU32(th.warning.toU32());
        self.writeU32(th.success.toU32());
        self.writeF32(th.radius);
        self.writeF32(th.spacing);
        self.writeF32(th.font_size);
        return .{ .ctx = self };
    }

    /// Renders an SVG icon (`ui.ParseSVG`); bytes are cached on the host.
    pub fn icon(self: *Context, svg_bytes: []const u8) Element {
        self.ensureSpace(6 + svg_bytes.len);
        self.writeOp(@intFromEnum(CoreOp.icon));
        self.writeStr(svg_bytes);
        return .{ .ctx = self };
    }

    /// Renders a bitmap or SVG (`ui.DecodeImage`); bytes are cached on the host.
    pub fn image(self: *Context, image_bytes: []const u8) Element {
        self.ensureSpace(6 + image_bytes.len);
        self.writeOp(@intFromEnum(CoreOp.image));
        self.writeStr(image_bytes);
        return .{ .ctx = self };
    }

    pub fn toast(self: *Context, message: []const u8) void {
        self.ensureSpace(6 + message.len);
        self.writeOp(@intFromEnum(CoreOp.toast));
        self.writeStr(message);
        self.flush();
    }

    pub fn toastAction(
        self: *Context,
        message: []const u8,
        label: []const u8,
        comptime StatePtr: type,
        state: StatePtr,
        comptime actionFn: fn (StatePtr) void,
    ) void {
        const S = struct {
            var cb_id: usize = 0;
            fn onAction(ud: usize) void {
                const s: StatePtr = @ptrFromInt(ud);
                actionFn(s);
            }
        };
        if (S.cb_id == 0) {
            mygo.ui_action_handlers[mygo.ui_action_count] = &S.onAction;
            mygo.ui_action_count += 1;
            S.cb_id = mygo.ui_action_count;
        }
        self.ensureSpace(22 + message.len + label.len);
        self.writeOp(@intFromEnum(CoreOp.toast_action));
        self.writeStr(message);
        self.writeStr(label);
        self.writeU64(@intCast(S.cb_id));
        self.writeU64(@intCast(@intFromPtr(state)));
        self.flush();
    }

    fn writeMenuEntries(self: *Context, entries: []const MenuEntry) void {
        self.writeU16(@intCast(entries.len));
        for (entries) |e| {
            switch (e) {
                .item => |it| {
                    self.writeU8(0);
                    self.writeStr(it.id);
                    self.writeStr(it.label);
                },
                .separator => self.writeU8(1),
                .submenu => |sm| {
                    self.writeU8(2);
                    self.writeStr(sm.label);
                    self.writeMenuEntries(sm.entries);
                },
            }
        }
    }

    fn flushChosenID(self: *Context, id_buf: []u8, id_len: *usize) bool {
        var q = CQuery{
            .text_buf_ptr = if (id_buf.len > 0) @intFromPtr(id_buf.ptr) else 0,
            .text_buf_cap = id_buf.len,
        };
        self.flushQueryInto(&q);
        if (q.bool_val == 0) {
            id_len.* = 0;
            return false;
        }
        id_len.* = @min(q.text_len, id_buf.len);
        return true;
    }

    /// Menu button with nested `MenuEntry` support. Writes chosen item id into
    /// `id_buf` when an item was Chosen.
    pub fn menuButton(
        self: *Context,
        key: []const u8,
        lbl: []const u8,
        entries: []const MenuEntry,
        id_buf: []u8,
        id_len: *usize,
    ) bool {
        self.writeOp(@intFromEnum(CoreOp.menu_button));
        self.writeStr(key);
        self.writeStr(lbl);
        self.writeMenuEntries(entries);
        return self.flushChosenID(id_buf, id_len);
    }

    pub fn gridView(
        self: *Context,
        key: []const u8,
        count: usize,
        selected: *i32,
        min_width: f32,
        row_height: f32,
        comptime StatePtr: type,
        state: StatePtr,
        comptime itemFn: fn (StatePtr, GridItem) void,
    ) Element {
        const S = struct {
            var cb_id: usize = 0;
            fn onItem(item_handle: usize, info: *const CGridItemInfo, ud: usize) void {
                const s: StatePtr = @ptrFromInt(ud);
                var item_ctx = Context{
                    .frame_handle = item_handle,
                    .window = .{ .id = info.window_id },
                    .width_dip = 0,
                    .height_dip = 0,
                    .window_active = true,
                    .ui_theme = Theme.fromC(info.theme),
                };
                itemFn(s, .{
                    .ctx = &item_ctx,
                    .index = @intCast(info.index),
                    .selected = info.selected != 0,
                });
                item_ctx.flush();
            }
        };
        if (S.cb_id == 0) {
            mygo.ui_grid_item_handlers[mygo.ui_grid_item_count] = &S.onItem;
            mygo.ui_grid_item_count += 1;
            S.cb_id = mygo.ui_grid_item_count;
        }
        self.ensureSpace(38 + key.len);
        self.writeOp(@intFromEnum(CoreOp.grid_view));
        self.writeStr(key);
        self.writeI32(@intCast(count));
        self.writeI32(selected.*);
        self.writeF32(min_width);
        self.writeF32(row_height);
        self.writeU64(@intCast(S.cb_id));
        self.writeU64(@intCast(@intFromPtr(state)));
        selected.* = @intCast(self.flushQuery().int_val);
        return .{ .ctx = self };
    }

    pub fn attachMenu(
        self: *Context,
        op: CoreOp,
        entries: []const MenuEntry,
        id_buf: []u8,
        id_len: *usize,
    ) bool {
        self.writeOp(@intFromEnum(op));
        self.writeMenuEntries(entries);
        return self.flushChosenID(id_buf, id_len);
    }

    pub fn popoverMenuButton(
        self: *Context,
        key: []const u8,
        lbl: []const u8,
        entries: []const MenuEntry,
        id_buf: []u8,
        id_len: *usize,
    ) bool {
        self.writeOp(@intFromEnum(CoreOp.popover_menu_button));
        self.writeStr(key);
        self.writeStr(lbl);
        self.writeMenuEntries(entries);
        return self.flushChosenID(id_buf, id_len);
    }

    /// Hierarchical outline. Only branches go in `nodes` (`children != null`);
    /// ids not listed are leaves. `open_pack`/`open_len` uses the same packed
    /// string-list format as `tokenField` (`u16` count + `u32` len + bytes).
    pub fn outline(
        self: *Context,
        key: []const u8,
        selected: *i32,
        open_pack: []u8,
        open_len: *usize,
        roots: []const []const u8,
        nodes: []const OutlineNode,
        comptime StatePtr: type,
        state: StatePtr,
        comptime rowFn: fn (StatePtr, OutlineRow) void,
    ) Element {
        const S = struct {
            var cb_id: usize = 0;
            fn onRow(row_handle: usize, info: *const COutlineRowInfo, ud: usize) void {
                const s: StatePtr = @ptrFromInt(ud);
                var row_ctx = Context{
                    .frame_handle = row_handle,
                    .window = .{ .id = info.window_id },
                    .width_dip = 0,
                    .height_dip = 0,
                    .window_active = true,
                    .ui_theme = Theme.fromC(info.theme),
                };
                rowFn(s, .{
                    .ctx = &row_ctx,
                    .id = info.id(),
                    .index = info.index,
                    .depth = info.depth,
                    .selected = info.selected != 0,
                    .branch = info.branch != 0,
                    .open = info.open != 0,
                });
                row_ctx.flush();
            }
        };
        if (S.cb_id == 0) {
            mygo.ui_outline_row_handlers[mygo.ui_outline_row_count] = &S.onRow;
            mygo.ui_outline_row_count += 1;
            S.cb_id = mygo.ui_outline_row_count;
        }

        var open_ids_buf: [64][]const u8 = undefined;
        const open_count = readStrList(open_pack[0..open_len.*], &open_ids_buf);

        var branch_count: u16 = 0;
        for (nodes) |node| {
            if (node.children != null) branch_count += 1;
        }

        self.writeOp(@intFromEnum(CoreOp.outline));
        self.writeStr(key);
        self.writeI32(selected.*);
        self.writeStrSlice(open_ids_buf[0..open_count]);
        self.writeStrSlice(roots);
        self.writeU16(branch_count);
        for (nodes) |node| {
            if (node.children) |kids| {
                self.writeStr(node.id);
                self.writeStrSlice(kids);
            }
        }
        self.writeU64(@intCast(S.cb_id));
        self.writeU64(@intCast(@intFromPtr(state)));

        var q = CQuery{
            .text_buf_ptr = if (open_pack.len > 0) @intFromPtr(open_pack.ptr) else 0,
            .text_buf_cap = open_pack.len,
        };
        self.flushQueryInto(&q);
        selected.* = @intCast(q.int_val);
        open_len.* = @min(q.text_len, open_pack.len);
        return .{ .ctx = self };
    }

    /// Outline whose rows are table cells (first column shows the disclosure).
    pub fn outlineTable(
        self: *Context,
        key: []const u8,
        selected: *i32,
        open_pack: []u8,
        open_len: *usize,
        roots: []const []const u8,
        nodes: []const OutlineNode,
        columns: []const TableColumn,
        comptime StatePtr: type,
        state: StatePtr,
        comptime cellFn: fn (StatePtr, OutlineCell) void,
    ) Element {
        const S = struct {
            var cb_id: usize = 0;
            fn onCell(cell_handle: usize, info: *const COutlineCellInfo, ud: usize) void {
                const s: StatePtr = @ptrFromInt(ud);
                var cell_ctx = Context{
                    .frame_handle = cell_handle,
                    .window = .{ .id = info.window_id },
                    .width_dip = 0,
                    .height_dip = 0,
                    .window_active = true,
                    .ui_theme = Theme.fromC(info.theme),
                };
                cellFn(s, .{
                    .ctx = &cell_ctx,
                    .id = info.id(),
                    .row = info.row,
                    .col = info.col,
                    .depth = info.depth,
                    .selected = info.selected != 0,
                    .branch = info.branch != 0,
                    .open = info.open != 0,
                });
                cell_ctx.flush();
            }
        };
        if (S.cb_id == 0) {
            mygo.ui_outline_cell_handlers[mygo.ui_outline_cell_count] = &S.onCell;
            mygo.ui_outline_cell_count += 1;
            S.cb_id = mygo.ui_outline_cell_count;
        }

        var open_ids_buf: [64][]const u8 = undefined;
        const open_count = readStrList(open_pack[0..open_len.*], &open_ids_buf);

        var branch_count: u16 = 0;
        for (nodes) |node| {
            if (node.children != null) branch_count += 1;
        }

        self.writeOp(@intFromEnum(CoreOp.outline_table));
        self.writeStr(key);
        self.writeI32(selected.*);
        self.writeStrSlice(open_ids_buf[0..open_count]);
        self.writeStrSlice(roots);
        self.writeU16(branch_count);
        for (nodes) |node| {
            if (node.children) |kids| {
                self.writeStr(node.id);
                self.writeStrSlice(kids);
            }
        }
        self.writeU16(@intCast(columns.len));
        for (columns) |col| {
            self.writeStr(col.title);
            self.writeF32(col.width);
            self.writeU8(@intFromEnum(col.@"align"));
        }
        self.writeU64(@intCast(S.cb_id));
        self.writeU64(@intCast(@intFromPtr(state)));

        var q = CQuery{
            .text_buf_ptr = if (open_pack.len > 0) @intFromPtr(open_pack.ptr) else 0,
            .text_buf_cap = open_pack.len,
        };
        self.flushQueryInto(&q);
        selected.* = @intCast(q.int_val);
        open_len.* = @min(q.text_len, open_pack.len);
        return .{ .ctx = self };
    }

    /// Makes the current element a drag source of a UTF-8 payload.
    pub fn drag(self: *Context, payload: []const u8) void {
        self.writeOp(@intFromEnum(CoreOp.drag));
        self.writeStr(payload);
    }

    /// Makes the current element a string drop target. Returns true and writes
    /// the payload when a drop happened since the last frame.
    pub fn drop(self: *Context, buf: []u8, len: *usize) bool {
        self.writeOp(@intFromEnum(CoreOp.drop));
        return self.flushChosenID(buf, len);
    }

    /// True while a matching string drag is over the current element.
    pub fn dragOver(self: *Context, buf: []u8, len: *usize) bool {
        self.writeOp(@intFromEnum(CoreOp.drag_over));
        return self.flushChosenID(buf, len);
    }

    pub fn richText(self: *Context, spans: []const Span) Element {
        self.ensureSpace(4 + spans.len * 16);
        self.writeOp(@intFromEnum(CoreOp.rich_text));
        self.writeU16(@intCast(spans.len));
        for (spans) |sp| {
            var flags: u8 = 0;
            if (sp.italic) flags |= 1;
            if (sp.underline) flags |= 2;
            if (sp.color != null) flags |= 4;
            if (sp.strikethrough) flags |= 8;
            if (sp.object_width != null) flags |= 16;
            if (sp.background != null) flags |= 32;
            self.writeStr(sp.text);
            self.writeU8(flags);
            self.writeU16(sp.weight);
            self.writeF32(sp.size);
            self.writeU32(if (sp.color) |c| c.toU32() else 0);
            if (sp.object_width) |ow| {
                self.writeF32(ow);
                self.writeF32(sp.object_height);
                self.writeF32(sp.object_descent);
            }
            if (sp.background) |bg| self.writeU32(bg.toU32());
        }
        return .{ .ctx = self };
    }

    /// Host-owned router. `pageFn` paints the page for the current path.
    pub fn router(
        self: *Context,
        rt: *RouterState,
        initial: []const u8,
        comptime StatePtr: type,
        state: StatePtr,
        comptime pageFn: fn (StatePtr, Route) void,
    ) Element {
        const S = struct {
            var cb_id: usize = 0;
            fn onPage(page_handle: usize, info: *const CRouteInfo, ud: usize) void {
                const s: StatePtr = @ptrFromInt(ud);
                var page_ctx = Context{
                    .frame_handle = page_handle,
                    .window = .{ .id = info.window_id },
                    .width_dip = 0,
                    .height_dip = 0,
                    .window_active = true,
                    .ui_theme = Theme.fromC(info.theme),
                };
                pageFn(s, .{ .ctx = &page_ctx, .path = info.path() });
                page_ctx.flush();
            }
        };
        if (S.cb_id == 0) {
            mygo.ui_route_handlers[mygo.ui_route_count] = &S.onPage;
            mygo.ui_route_count += 1;
            S.cb_id = mygo.ui_route_count;
        }
        self.writeOp(@intFromEnum(CoreOp.router));
        self.writeStr(rt.key);
        self.writeStr(initial);
        self.writeU64(@intCast(S.cb_id));
        self.writeU64(@intCast(@intFromPtr(state)));
        var q = CQuery{
            .text_buf_ptr = @intFromPtr(&rt.path_buf),
            .text_buf_cap = rt.path_buf.len,
        };
        self.flushQueryInto(&q);
        rt.path_len = @min(q.text_len, rt.path_buf.len);
        if (rt.path_len == 0) {
            rt.path_buf[0] = '/';
            rt.path_len = 1;
        }
        rt.can_go_back = q.bool_val != 0;
        rt.can_go_forward = q.num_val2 != 0;
        return .{ .ctx = self };
    }

    pub fn routerPush(self: *Context, rt: *RouterState, path: []const u8) void {
        self.writeOp(@intFromEnum(CoreOp.router_push));
        self.writeStr(rt.key);
        self.writeStr(path);
        self.flush();
    }

    pub fn routerReplace(self: *Context, rt: *RouterState, path: []const u8) void {
        self.writeOp(@intFromEnum(CoreOp.router_replace));
        self.writeStr(rt.key);
        self.writeStr(path);
        self.flush();
    }

    pub fn routerBack(self: *Context, rt: *RouterState) void {
        self.writeOp(@intFromEnum(CoreOp.router_back));
        self.writeStr(rt.key);
        self.flush();
    }

    pub fn routerForward(self: *Context, rt: *RouterState) void {
        self.writeOp(@intFromEnum(CoreOp.router_forward));
        self.writeStr(rt.key);
        self.flush();
    }

    pub fn backButton(self: *Context, rt: *RouterState) Element {
        self.writeOp(@intFromEnum(CoreOp.back_button));
        self.writeStr(rt.key);
        return .{ .ctx = self };
    }

    pub fn forwardButton(self: *Context, rt: *RouterState) Element {
        self.writeOp(@intFromEnum(CoreOp.forward_button));
        self.writeStr(rt.key);
        return .{ .ctx = self };
    }

    /// Embeds a system webview (`mygo.Window.NewWebView`). Created once per
    /// `key`; changing `url` navigates. Destroy with `destroyWebView`.
    pub fn webView(self: *Context, key: []const u8, url: []const u8) Element {
        self.writeOp(@intFromEnum(CoreOp.web_view));
        self.writeStr(key);
        self.writeStr(url);
        return .{ .ctx = self };
    }

    pub fn destroyWebView(self: *Context, key: []const u8) void {
        self.writeOp(@intFromEnum(CoreOp.web_view_destroy));
        self.writeStr(key);
        self.flush();
    }
    /// Places a first-class `mygo.WebView` created with `mygo.WebView.create`.
    pub fn webViewHandle(self: *Context, wv: mygo.WebView) Element {
        self.writeOp(@intFromEnum(CoreOp.web_view_handle));
        self.writeU64(wv.id);
        return .{ .ctx = self };
    }



    /// Native text drag source (Finder / other apps can receive it).
    pub fn dragData(self: *Context, payload: []const u8) void {
        self.writeOp(@intFromEnum(CoreOp.drag_data));
        self.writeStr(payload);
    }

    /// Native drop target for text / URL / file paths.
    pub fn dropData(self: *Context, buf: []u8, len: *usize) bool {
        self.writeOp(@intFromEnum(CoreOp.drop_data));
        return self.flushChosenID(buf, len);
    }

    /// True while a native drag matching text/URL/files is over the element.
    pub fn dataDragOver(self: *Context) bool {
        self.writeOp(@intFromEnum(CoreOp.data_drag_over));
        self.writeU16(0); // default text/url/file formats
        return self.flushQuery().bool_val != 0;
    }

    /// Native drag-over for an explicit MIME list.
    pub fn dataDragOverMIME(self: *Context, formats: []const []const u8) bool {
        self.writeOp(@intFromEnum(CoreOp.data_drag_over));
        self.writeU16(@intCast(formats.len));
        for (formats) |fmt| self.writeStr(fmt);
        return self.flushQuery().bool_val != 0;
    }

    /// Lets the pointer move the current element by *x/*y.
    /// Optional `snap` points are nearest-snap targets on release.
    pub fn draggable(
        self: *Context,
        x: *f32,
        y: *f32,
        axis: DragAxis,
        bounds: ?DragBounds,
        snap: []const [2]f32,
    ) void {
        self.writeOp(@intFromEnum(CoreOp.draggable));
        self.writeF32(x.*);
        self.writeF32(y.*);
        self.writeU8(@intFromEnum(axis));
        if (bounds) |b| {
            self.writeU8(1);
            self.writeF32(b.x);
            self.writeF32(b.y);
            self.writeF32(b.w);
            self.writeF32(b.h);
            self.writeU8(@intFromBool(b.rigid));
        } else {
            self.writeU8(0);
        }
        self.writeU16(@intCast(snap.len));
        for (snap) |pt| {
            self.writeF32(pt[0]);
            self.writeF32(pt[1]);
        }
        const q = self.flushQuery();
        x.* = @floatCast(q.num_val);
        y.* = @floatCast(q.num_val2);
    }


    /// Schedule another view build after `ms` milliseconds (`ui.Context.After`).
    pub fn after(self: *Context, ms: i32) void {
        self.writeOp(@intFromEnum(CoreOp.after));
        self.writeI32(ms);
        self.flush();
    }

    /// Ask for another frame as soon as the display can show it.
    pub fn animationFrame(self: *Context) void {
        self.writeOp(@intFromEnum(CoreOp.animation_frame));
        self.flush();
    }

    /// Settle animated values / transitions in this frame at their targets.
    pub fn disableAnimations(self: *Context) void {
        self.writeOp(@intFromEnum(CoreOp.disable_animations));
        self.flush();
    }

    /// Rebuild the view as soon as possible (`ui.Context.Invalidate`).
    pub fn invalidate(self: *Context) void {
        self.writeOp(@intFromEnum(CoreOp.invalidate));
        self.flush();
    }

    /// Close the toast with `id`, or every toast when `id` is empty.
    pub fn closeToast(self: *Context, id: []const u8) void {
        self.writeOp(@intFromEnum(CoreOp.close_toast));
        self.writeStr(id);
        self.flush();
    }

    /// Registers GIF bytes once (by key) for later `video` embeds.

    pub fn registerFont(_: *Context, family: []const u8, data: []const u8) void {
        const CFontSpec = extern struct {
            family_ptr: usize = 0,
            family_len: usize = 0,
            data_ptr: usize = 0,
            data_len: usize = 0,
        };
        var spec = CFontSpec{
            .family_ptr = mygo.sliceAddr(family),
            .family_len = family.len,
            .data_ptr = mygo.sliceAddr(data),
            .data_len = data.len,
        };
        _ = mygo.dispatch(.register_font, @intFromPtr(&spec), 0, 0, 0);
    }


    pub fn registerCanvas(_: *Context, key: []const u8, width: u32, height: u32) void {
        const CCanvasSpec = extern struct {
            key_ptr: usize = 0,
            key_len: usize = 0,
            width: u32 = 0,
            height: u32 = 0,
        };
        var spec = CCanvasSpec{
            .key_ptr = mygo.sliceAddr(key),
            .key_len = key.len,
            .width = width,
            .height = height,
        };
        _ = mygo.dispatch(.register_canvas, @intFromPtr(&spec), 0, 0, 0);
    }

    pub fn canvas(self: *Context, key: []const u8) Element {
        self.writeOp(@intFromEnum(CoreOp.canvas));
        self.writeStr(key);
        return .{ .ctx = self };
    }

    pub fn registerBitmap(_: *Context, key: []const u8, data: []const u8) void {
        const CBitmapSpec = extern struct {
            key_ptr: usize = 0,
            key_len: usize = 0,
            data_ptr: usize = 0,
            data_len: usize = 0,
        };
        var spec = CBitmapSpec{
            .key_ptr = mygo.sliceAddr(key),
            .key_len = key.len,
            .data_ptr = mygo.sliceAddr(data),
            .data_len = data.len,
        };
        _ = mygo.dispatch(.register_bitmap, @intFromPtr(&spec), 0, 0, 0);
    }

    pub fn bitmap(self: *Context, key: []const u8) Element {
        self.writeOp(@intFromEnum(CoreOp.bitmap));
        self.writeStr(key);
        return .{ .ctx = self };
    }

    pub fn registerVideoGIF(_: *Context, key: []const u8, gif: []const u8, loop: bool) void {
        var spec = CVideoGIFSpec{
            .key_ptr = mygo.sliceAddr(key),
            .key_len = key.len,
            .gif_ptr = mygo.sliceAddr(gif),
            .gif_len = gif.len,
            .loop = @intFromBool(loop),
        };
        _ = mygo.dispatch(.video_gif, @intFromPtr(&spec), 0, 0, 0);
    }

    /// Registers an RGBA frame sequence (w×h×4 bytes per frame).
    pub fn registerVideoFrames(
        _: *Context,
        key: []const u8,
        width: u32,
        height: u32,
        durations_ms: []const u32,
        pixels: []const u8,
        loop: bool,
    ) void {
        var spec = CVideoFramesSpec{
            .key_ptr = mygo.sliceAddr(key),
            .key_len = key.len,
            .width = width,
            .height = height,
            .frame_count = @intCast(durations_ms.len),
            .loop = @intFromBool(loop),
            .durations_ptr = if (durations_ms.len > 0) @intFromPtr(durations_ms.ptr) else 0,
            .pixels_ptr = mygo.sliceAddr(pixels),
            .pixels_len = pixels.len,
        };
        _ = mygo.dispatch(.video_frames, @intFromPtr(&spec), 0, 0, 0);
    }

    /// Opens a push-driven RGBA stream. Push frames with `pushVideoFrame`, then
    /// show with `video(key, ...)`. Seeded with a blank first frame on the host.
    pub fn openVideoStream(_: *Context, key: []const u8, width: u32, height: u32, capacity: u32, loop: bool) void {
        var spec = CVideoStreamSpec{
            .key_ptr = mygo.sliceAddr(key),
            .key_len = key.len,
            .width = width,
            .height = height,
            .capacity = if (capacity == 0) 4 else capacity,
            .loop = @intFromBool(loop),
        };
        _ = mygo.dispatch(.video_stream, @intFromPtr(&spec), 0, 0, 0);
    }

    pub fn pushVideoFrame(_: *Context, key: []const u8, duration_ms: u32, pixels: []const u8) void {
        var spec = CVideoPushSpec{
            .key_ptr = mygo.sliceAddr(key),
            .key_len = key.len,
            .duration_ms = duration_ms,
            .pixels_ptr = mygo.sliceAddr(pixels),
            .pixels_len = pixels.len,
        };
        _ = mygo.dispatch(.video_push, @intFromPtr(&spec), 0, 0, 0);
    }

    pub fn endVideoStream(_: *Context, key: []const u8) void {
        _ = mygo.dispatch(.video_end, mygo.sliceAddr(key), key.len, 0, 0);
    }

    /// Full toast with optional action, UTF-8 `data`, and opaque `userdata`.
    /// Returns the toast id written by the host (empty on tape overflow).
    pub fn addToast(
        self: *Context,
        title: []const u8,
        description: []const u8,
        typ: []const u8,
        data: []const u8,
        action: []const u8,
        timeout_ms: i32,
        userdata: usize,
        comptime StatePtr: type,
        state: StatePtr,
        comptime actionFn: fn (StatePtr) void,
        id_buf: []u8,
    ) []const u8 {
        var cb_id: usize = 0;
        var ud: usize = 0;
        if (action.len > 0) {
            const S = struct {
                var id: usize = 0;
                fn onAction(u: usize) void {
                    const s: StatePtr = @ptrFromInt(u);
                    actionFn(s);
                }
            };
            if (S.id == 0) {
                mygo.ui_action_handlers[mygo.ui_action_count] = &S.onAction;
                mygo.ui_action_count += 1;
                S.id = mygo.ui_action_count;
            }
            cb_id = S.id;
            ud = @intFromPtr(state);
        }
        self.writeOp(@intFromEnum(CoreOp.add_toast));
        self.writeStr(title);
        self.writeStr(description);
        self.writeStr(typ);
        self.writeStr(data);
        self.writeStr(action);
        self.writeI32(timeout_ms);
        self.writeU64(@intCast(cb_id));
        self.writeU64(@intCast(ud));
        self.writeU64(@intCast(userdata));
        var q = CQuery{
            .text_buf_ptr = if (id_buf.len > 0) @intFromPtr(id_buf.ptr) else 0,
            .text_buf_cap = id_buf.len,
        };
        self.flushQueryInto(&q);
        const n = @min(q.text_len, id_buf.len);
        return id_buf[0..n];
    }

    /// Plays a previously registered GIF (`registerVideoGIF`).
    pub fn video(self: *Context, key: []const u8, fit: Fit) Element {
        self.writeOp(@intFromEnum(CoreOp.video));
        self.writeStr(key);
        self.writeU8(@intFromEnum(fit));
        return .{ .ctx = self };
    }

    pub fn videoPlay(self: *Context, key: []const u8) void {
        self.writeOp(@intFromEnum(CoreOp.video_control));
        self.writeStr(key);
        self.writeU8(1);
        self.flush();
    }

    pub fn videoPause(self: *Context, key: []const u8) void {
        self.writeOp(@intFromEnum(CoreOp.video_control));
        self.writeStr(key);
        self.writeU8(2);
        self.flush();
    }

    pub fn videoClose(self: *Context, key: []const u8) void {
        self.writeOp(@intFromEnum(CoreOp.video_control));
        self.writeStr(key);
        self.writeU8(3);
        self.flush();
    }

    /// Nested `Route.View` for a `{name...}` layout page.
    pub fn routeView(
        self: *Context,
        comptime StatePtr: type,
        state: StatePtr,
        comptime pageFn: fn (StatePtr, Route) void,
    ) Element {
        const S = struct {
            var cb_id: usize = 0;
            fn onPage(page_handle: usize, info: *const CRouteInfo, ud: usize) void {
                const s: StatePtr = @ptrFromInt(ud);
                var page_ctx = Context{
                    .frame_handle = page_handle,
                    .window = .{ .id = info.window_id },
                    .width_dip = 0,
                    .height_dip = 0,
                    .window_active = true,
                    .ui_theme = Theme.fromC(info.theme),
                };
                pageFn(s, .{ .ctx = &page_ctx, .path = info.path() });
                page_ctx.flush();
            }
        };
        if (S.cb_id == 0) {
            mygo.ui_route_handlers[mygo.ui_route_count] = &S.onPage;
            mygo.ui_route_count += 1;
            S.cb_id = mygo.ui_route_count;
        }
        self.writeOp(@intFromEnum(CoreOp.route_view));
        self.writeU64(@intCast(S.cb_id));
        self.writeU64(@intCast(@intFromPtr(state)));
        return .{ .ctx = self };
    }

    /// `ui.Route.Match` — must precede `routeView` for `{name...}` layouts.
    pub fn routeMatch(self: *Context, pattern: []const u8) bool {
        self.writeOp(@intFromEnum(CoreOp.route_match));
        self.writeStr(pattern);
        return self.flushQuery().bool_val != 0;
    }

    /// Wildcard captured by the last successful `routeMatch`.
    pub fn routeParam(self: *Context, name: []const u8, buf: []u8, len: *usize) void {
        self.writeOp(@intFromEnum(CoreOp.route_param));
        self.writeStr(name);
        _ = self.flushChosenID(buf, len);
    }

    /// Draws inline objects of the current RichText (`Span.object`).
    pub fn drawObjects(
        self: *Context,
        comptime StatePtr: type,
        state: StatePtr,
        comptime paintFn: fn (StatePtr, *Painter, i32, Rect) void,
    ) void {
        const S = struct {
            var cb_id: usize = 0;
            fn onPaint(painter_handle: usize, cr: *const CRect, ud: usize) void {
                const s: StatePtr = @ptrFromInt(ud);
                var p = Painter{ .handle = painter_handle };
                paintFn(s, &p, cr.at, .{ .x = cr.x, .y = cr.y, .w = cr.w, .h = cr.h });
            }
        };
        if (S.cb_id == 0) {
            mygo.ui_paint_handlers[mygo.ui_paint_count] = &S.onPaint;
            mygo.ui_paint_count += 1;
            S.cb_id = mygo.ui_paint_count;
        }
        self.writeOp(@intFromEnum(CoreOp.draw_objects));
        self.writeU64(@intCast(S.cb_id));
        self.writeU64(@intCast(@intFromPtr(state)));
    }

    pub const ToastInfo = struct {
        title: []const u8 = "",
        description: []const u8 = "",
        type: []const u8 = "",
        action: []const u8 = "",
        data: []const u8 = "",
        userdata: usize = 0,
        has_action: bool = false,
    };

    /// Custom toast look. Inside `bodyFn`, style the viewport (current element),
    /// then call `toastItem` for each toast (`info.width` is the count).
    pub fn toastViewport(
        self: *Context,
        comptime StatePtr: type,
        state: StatePtr,
        comptime bodyFn: fn (StatePtr, *Context, usize) void,
    ) Element {
        const S = struct {
            var cb_id: usize = 0;
            fn onBody(frame_handle: usize, info: *const CFrameInfo, ud: usize) void {
                const s: StatePtr = @ptrFromInt(ud);
                var ctx = Context{
                    .frame_handle = frame_handle,
                    .window = .{ .id = info.window_id },
                    .width_dip = info.width,
                    .height_dip = info.height,
                    .window_active = info.window_active != 0,
                    .ui_theme = Theme.fromC(info.theme),
                };
                const count: usize = @intFromFloat(@max(info.width, 0));
                bodyFn(s, &ctx, count);
                ctx.flush();
            }
        };
        if (S.cb_id == 0) {
            mygo.ui_subview_handlers[mygo.ui_subview_count] = &S.onBody;
            mygo.ui_subview_count += 1;
            S.cb_id = mygo.ui_subview_count;
        }
        self.writeOp(@intFromEnum(CoreOp.toast_viewport));
        self.writeU64(@intCast(S.cb_id));
        self.writeU64(@intCast(@intFromPtr(state)));
        return .{ .ctx = self };
    }

    /// Builds toast `index` inside `toastViewport`; returns Root as current element.
    pub fn toastItem(self: *Context, index: i32, info_buf: []u8, info: *ToastInfo) Element {
        self.writeOp(@intFromEnum(CoreOp.toast_item));
        self.writeI32(index);
        var q = CQuery{
            .text_buf_ptr = if (info_buf.len > 0) @intFromPtr(info_buf.ptr) else 0,
            .text_buf_cap = info_buf.len,
        };
        self.flushQueryInto(&q);
        const len = @min(q.text_len, info_buf.len);
        info.* = .{};
        info.has_action = q.bool_val != 0;
        info.userdata = @intFromFloat(q.num_val);
        if (len > 0) {
            const raw = info_buf[0..len];
            var parts: [5][]const u8 = .{ "", "", "", "", "" };
            var n: usize = 0;
            var start: usize = 0;
            for (raw, 0..) |ch, i| {
                if (ch == '\n' and n < parts.len) {
                    parts[n] = raw[start..i];
                    n += 1;
                    start = i + 1;
                }
            }
            if (n < parts.len and start <= raw.len) {
                parts[n] = raw[start..];
            }
            info.title = parts[0];
            info.description = parts[1];
            info.type = parts[2];
            info.action = parts[3];
            info.data = parts[4];
        }
        return .{ .ctx = self };
    }

    pub fn toastCloseButton(self: *Context) Element {
        self.writeOp(@intFromEnum(CoreOp.toast_close_btn));
        return .{ .ctx = self };
    }

    pub fn toastActionButton(self: *Context) Element {
        self.writeOp(@intFromEnum(CoreOp.toast_action_btn));
        return .{ .ctx = self };
    }

    /// Multi-MIME native drag source: pairs of (format, payload).
    pub fn dragMIME(self: *Context, parts: []const struct { []const u8, []const u8 }) void {
        self.writeOp(@intFromEnum(CoreOp.drag_mime));
        self.writeU16(@intCast(parts.len));
        for (parts) |pair| {
            self.writeStr(pair[0]);
            self.writeStr(pair[1]);
        }
    }

    /// Lazy multi-MIME drag: `provideFn` runs when the gesture starts and must
    /// write the dragMIME tape into `buf` (u16 count + format/payload pairs),
    /// returning bytes written.
    pub fn dragMIMELazy(
        self: *Context,
        formats: []const []const u8,
        comptime StatePtr: type,
        state: StatePtr,
        comptime provideFn: fn (StatePtr, []u8) usize,
    ) void {
        const S = struct {
            var cb_id: usize = 0;
            fn onProvide(buf: []u8, ud: usize) usize {
                const s: StatePtr = @ptrFromInt(ud);
                return provideFn(s, buf);
            }
        };
        if (S.cb_id == 0) {
            mygo.ui_provide_handlers[mygo.ui_provide_count] = &S.onProvide;
            mygo.ui_provide_count += 1;
            S.cb_id = mygo.ui_provide_count;
        }
        self.writeOp(@intFromEnum(CoreOp.drag_mime_lazy));
        self.writeU16(@intCast(formats.len));
        self.writeU64(@intCast(S.cb_id));
        self.writeU64(@intCast(@intFromPtr(state)));
        for (formats) |fmt| self.writeStr(fmt);
    }

    /// Helper: encode MIME pairs into a provide buffer for `dragMIMELazy`.
    /// Wire format matches CommandBuffer strings: u16 count, then (u32 len + bytes)*.
    pub fn writeMIMETape(buf: []u8, parts: []const struct { []const u8, []const u8 }) usize {
        var w: usize = 0;
        if (buf.len < 2) return 0;
        const n: u16 = @intCast(@min(parts.len, 32));
        buf[0] = @truncate(n);
        buf[1] = @truncate(n >> 8);
        w = 2;
        for (parts[0..n]) |pair| {
            inline for (.{ pair[0], pair[1] }) |s| {
                if (w + 4 + s.len > buf.len) return w;
                const ln: u32 = @intCast(s.len);
                buf[w] = @truncate(ln);
                buf[w + 1] = @truncate(ln >> 8);
                buf[w + 2] = @truncate(ln >> 16);
                buf[w + 3] = @truncate(ln >> 24);
                w += 4;
                @memcpy(buf[w..][0..s.len], s);
                w += s.len;
            }
        }
        return w;
    }

    /// Native drop for explicit MIME list. Buffer receives `format\npayload`.
    pub fn dropMIME(self: *Context, formats: []const []const u8, buf: []u8, len: *usize) bool {
        self.writeOp(@intFromEnum(CoreOp.drop_mime));
        self.writeU16(@intCast(formats.len));
        for (formats) |fmt| self.writeStr(fmt);
        return self.flushChosenID(buf, len);
    }

    fn chartSpec(xs: []const f32, ys: []const f32, color: Color, height: f32, show_axes: bool) CChartSpec {
        return .{
            .xs_ptr = if (xs.len > 0) @intFromPtr(xs.ptr) else 0,
            .xs_len = xs.len,
            .ys_ptr = if (ys.len > 0) @intFromPtr(ys.ptr) else 0,
            .ys_len = ys.len,
            .color = color.toU32(),
            .height = height,
            .flags = if (show_axes) 1 else 0,
        };
    }

    /// Line chart (`_ "…/zig/host/chart"`). Empty `xs` uses 0..n-1.
    pub fn lineChart(
        self: *Context,
        xs: []const f32,
        ys: []const f32,
        color: Color,
        height: f32,
        show_axes: bool,
    ) Element {
        self.flush();
        var spec = chartSpec(xs, ys, color, height, show_axes);
        _ = mygo.dispatch(.line_chart, self.frame_handle, @intFromPtr(&spec), 0, 0);
        return .{ .ctx = self };
    }

    /// Bar chart (`_ "…/zig/host/chart"`). Uses `ys` only; categories are 1..n.
    pub fn barChart(
        self: *Context,
        ys: []const f32,
        color: Color,
        height: f32,
        show_axes: bool,
    ) Element {
        self.flush();
        var spec = chartSpec(&.{}, ys, color, height, show_axes);
        _ = mygo.dispatch(.bar_chart, self.frame_handle, @intFromPtr(&spec), 0, 0);
        return .{ .ctx = self };
    }

    /// Filled area chart under a monotone line.
    pub fn areaChart(
        self: *Context,
        xs: []const f32,
        ys: []const f32,
        color: Color,
        height: f32,
        show_axes: bool,
    ) Element {
        self.flush();
        var spec = chartSpec(xs, ys, color, height, show_axes);
        _ = mygo.dispatch(.area_chart, self.frame_handle, @intFromPtr(&spec), 0, 0);
        return .{ .ctx = self };
    }

    /// Pie / donut chart. `inner` is hole radius as a fraction of outer (0 = pie).
    pub fn pieChart(
        self: *Context,
        values: []const f64,
        colors: []const Color,
        height: f32,
        inner: f32,
        pad: f32,
    ) Element {
        self.flush();
        var packed_colors: [32]u32 = undefined;
        const n = @min(colors.len, packed_colors.len);
        for (colors[0..n], 0..) |col, i| packed_colors[i] = col.toU32();
        var spec = CPieSpec{
            .values_ptr = if (values.len > 0) @intFromPtr(values.ptr) else 0,
            .values_len = values.len,
            .colors_ptr = if (n > 0) @intFromPtr(&packed_colors) else 0,
            .colors_len = n,
            .height = height,
            .inner = inner,
            .pad = pad,
        };
        _ = mygo.dispatch(.pie_chart, self.frame_handle, @intFromPtr(&spec), 0, 0);
        return .{ .ctx = self };
    }



    // =========================================================================
    // Opt-in glass (`zig/host/glass`) & game (`zig/host/game`)
    // =========================================================================

    /// Applies Liquid Glass material to the current element.
    pub fn glass(self: *Context, opts: GlassOptions) Element {
        self.flush();
        const Spec = extern struct {
            style: u8 = 0,
            interactive: u8 = 0,
            native: u8 = 0,
            _pad: u8 = 0,
            clarity: f32 = 0,
            tint: u32 = 0,
        };
        var spec = Spec{
            .style = @intFromEnum(opts.style),
            .interactive = @intFromBool(opts.interactive),
            .native = @intFromBool(opts.native),
            .clarity = opts.clarity,
            .tint = opts.tint,
        };
        _ = mygo.dispatch(.glass, 1, self.frame_handle, @intFromPtr(&spec), 0);
        return .{ .ctx = self };
    }

    pub fn glassBlur(self: *Context, opts: BlurOptions) Element {
        self.flush();
        const Spec = extern struct {
            radius: f32 = 0,
            has_mask: u8 = 0,
            _pad: [3]u8 = .{ 0, 0, 0 },
            from: u32 = 0,
            to: u32 = 0,
            angle: f32 = 0,
        };
        var spec = Spec{
            .radius = opts.radius,
            .has_mask = @intFromBool(opts.has_mask),
            .from = opts.mask_from,
            .to = opts.mask_to,
            .angle = opts.mask_angle,
        };
        _ = mygo.dispatch(.glass, 2, self.frame_handle, @intFromPtr(&spec), 0);
        return .{ .ctx = self };
    }

    pub fn scrollEdge(self: *Context, hard: bool, at_bottom: bool, bg: u32) Element {
        self.flush();
        const Spec = extern struct {
            hard: u8 = 0,
            bottom: u8 = 0,
            has_bg: u8 = 0,
            _pad: u8 = 0,
            background: u32 = 0,
        };
        var spec = Spec{
            .hard = @intFromBool(hard),
            .bottom = @intFromBool(at_bottom),
            .has_bg = @intFromBool(bg != 0),
            .background = bg,
        };
        _ = mygo.dispatch(.glass, 3, self.frame_handle, @intFromPtr(&spec), 0);
        return .{ .ctx = self };
    }

    /// Fixed-step game view. Requires `_ "github.com/egoist/mygo/zig/host/game"`.
    pub fn gameView(
        self: *Context,
        comptime StatePtr: type,
        state: StatePtr,
        rate: i32,
        comptime onUpdate: fn (StatePtr, *const mygo.GameInput) void,
        comptime onDraw: fn (StatePtr, *Painter, *const mygo.GameDrawInfo) void,
    ) Element {
        self.flush();
        const S = struct {
            var upd_cb: usize = 0;
            var draw_cb: usize = 0;
            fn upd(inp: *const mygo.GameInput, ud: usize) void {
                onUpdate(@ptrFromInt(ud), inp);
            }
            fn draw(painter_handle: usize, info: *const mygo.GameDrawInfo, ud: usize) void {
                var p = Painter{ .handle = painter_handle };
                onDraw(@ptrFromInt(ud), &p, info);
            }
        };
        if (S.upd_cb == 0) {
            S.upd_cb = mygo.registerGameUpdate(&S.upd, 0);
            S.draw_cb = mygo.registerGameDraw(&S.draw, 0);
        }
        const Spec = extern struct {
            update_cb: u64 = 0,
            update_ud: u64 = 0,
            draw_cb: u64 = 0,
            draw_ud: u64 = 0,
            rate: i32 = 0,
            _pad: i32 = 0,
        };
        var spec = Spec{
            .update_cb = S.upd_cb,
            .update_ud = @intFromPtr(state),
            .draw_cb = S.draw_cb,
            .draw_ud = @intFromPtr(state),
            .rate = rate,
        };
        _ = mygo.dispatch(.game, 1, self.frame_handle, @intFromPtr(&spec), 0);
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

    /// Embeds a `plugins/terminal` view (`_ "…/zig/host/terminal"`).
    /// Create the terminal with `mygo.Terminal.create` / `createWithEvents`.
    pub fn terminalView(self: *Context, term: mygo.Terminal) Element {
        self.flush();
        _ = mygo.dispatch(.terminal_view, self.frame_handle, term.id, 0, 0);
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
