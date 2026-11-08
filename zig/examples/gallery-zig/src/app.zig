//! Zig gallery of MyGo Native UI widgets (Model A purego host).
//! Tabs: Controls · Inputs · Layout · Data · Tree · More · Nav · Charts · Markdown · Editor · Term

const std = @import("std");
const mygo = @import("mygo");
const ui = mygo.ui;

const waves_gif = @embedFile("waves.gif");
const tray_png = @embedFile("tray.png");
const tray_menu_items = [_]mygo.MenuItem{
    .{
        .id = "show",
        .label = "Show Gallery",
        .tooltip = "Bring the gallery forward",
        .subtitle = "⌘↩",
        .icon_png = tray_png,
        .icon_template = true,
    },
    .{ .kind = .separator },
    .{ .id = "quit", .label = "Quit", .role = "quit" },
};
const dock_menu_items = [_]mygo.MenuItem{
    .{ .id = "dock-new", .label = "New Gallery Window", .subtitle = "⌘N" },
    .{ .id = "dock-about", .label = "About Gallery Zig", .tooltip = "Version 0.1.0" },
};

const tabs = [_][]const u8{ "Controls", "Inputs", "Layout", "Data", "Tree", "More", "Nav", "Graph", "Charts", "Markdown", "Editor", "Rich", "Term" };
const edit_submenu = [_]ui.MenuEntry{
    ui.MenuEntry.ofLabel("Cut"),
    ui.MenuEntry.ofLabel("Copy"),
    ui.MenuEntry.ofLabel("Paste"),
};
const menu_entries = [_]ui.MenuEntry{
    ui.MenuEntry.ofItem("new", "New"),
    ui.MenuEntry.ofItem("open", "Open…"),
    ui.MenuEntry.sep(),
    ui.MenuEntry.ofSub("Edit", &edit_submenu),
    ui.MenuEntry.sep(),
    ui.MenuEntry.ofItem("save", "Save"),
    ui.MenuEntry.ofItem("quit", "Quit"),
};
const ctx_entries = [_]ui.MenuEntry{
    ui.MenuEntry.ofItem("copy", "Copy"),
    ui.MenuEntry.ofItem("paste", "Paste"),
    ui.MenuEntry.sep(),
    ui.MenuEntry.ofItem("delete", "Delete"),
};
const outline_table_cols = [_]ui.TableColumn{
    .{ .title = "Name", .width = 180 },
    .{ .title = "Kind", .width = 80 },
    .{ .title = "Note", .width = 0 },
};
const outline_roots = [_][]const u8{ "src", "zig", "docs" };
const outline_src_kids = [_][]const u8{ "app.zig", "main.go" };
const outline_zig_kids = [_][]const u8{ "sdk", "host" };
const outline_sdk_kids = [_][]const u8{ "ui.zig", "mygo.zig" };
const outline_nodes = [_]ui.OutlineNode{
    .{ .id = "src", .children = &outline_src_kids },
    .{ .id = "zig", .children = &outline_zig_kids },
    .{ .id = "sdk", .children = &outline_sdk_kids },
    .{ .id = "docs", .children = &.{} }, // empty branch
};
const star_svg =
    \\<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16">
    \\<path fill="currentColor" d="M8 1.5l1.8 3.7 4.1.6-3 2.9.7 4.1L8 11.2l-3.6 1.9.7-4.1-3-2.9 4.1-.6z"/>
    \\</svg>
;
const themes = [_][]const u8{ "System", "Light", "Dark" };
const fruits = [_][]const u8{ "Apple", "Banana", "Cherry", "Durian", "Elderberry" };
const cities = [_][]const u8{ "Amsterdam", "Berlin", "Chicago", "Dubai", "Edinburgh", "Fukuoka" };
const crumbs = [_][]const u8{ "Home", "Projects", "MyGo", "Zig" };
const sidebar_items = [_][]const u8{ "Inbox", "Starred", "Sent", "Archive", "Trash" };
const table_cols = [_]ui.TableColumn{
    .{ .title = "#", .width = 48, .@"align" = .end },
    .{ .title = "Name", .width = 160 },
    .{ .title = "Score", .width = 72, .@"align" = .end },
    .{ .title = "Status", .width = 0 },
};

const sample_rich =
    \\# Rich text in Zig
    \\
    \\Edit **formatted** text through `ui/richtext`: headings, _emphasis_,
    \\lists, quotes and code, with undo.
    \\
    \\- Toggle bold, italic, code
    \\- Undo and redo
    \\- Save back to Markdown
    \\
    \\> The document lives in Go; Zig drives the commands.
;

const graph_doc =
    \\{"camera":{"x":220,"y":140,"zoom":1},"edgeStyle":0,"snapGrid":16,
    \\ "nodes":[
    \\  {"id":"note","title":"Note","x":-140,"y":-50,"w":170,"h":100,"ports":[{"id":"out","side":1,"at":0.5}]},
    \\  {"id":"card","title":"Excerpt","x":120,"y":10,"w":190,"h":110,"ports":[{"id":"in","side":0,"at":0.5},{"id":"out","side":1,"at":0.5}]},
    \\  {"id":"sink","title":"Sink","x":400,"y":-20,"w":150,"h":80,"ports":[{"id":"in","side":0,"at":0.5}]}
    \\ ],
    \\ "edges":[{"id":"e1","source":"note","sourcePort":"out","target":"card","targetPort":"in","label":"cites"}]}
;

const sample_md =
    \\# MyGo × Zig
    \\,
    \\GPU Native UI from **Zig**, over a single `purego` callback
    \\(`CGO_ENABLED=0`).
    \\,
    \\- Tabs / Segmented / Select / Combobox / Autocomplete
    \\- Split · Accordion · Sidebar · Modal · Popover
    \\- Virtualized List & Table
    \\- `ui/markdown` + `ui/editor`
    \\,
    \\```zig
    \\_ = c.markdown(src);
    \\```
;

const sample_zig =
    \\const std = @import("std");
    \\const mygo = @import("mygo");
    \\const ui = mygo.ui;
    \\,
    \\fn view(self: *App, c: *ui.Context) void {
    \\    const root = c.column().fill().padding(16).gap(10).begin();
    \\    defer root.end();
    \\    _ = c.text("Hello from Zig").fontSize(20).bold();
    \\    if (c.primaryButton("go", "Run").clicked()) {
    \\        self.n += 1;
    \\    }
    \\}
;

/// makeBeepWav writes a mono 16-bit WAV of a 440 Hz tone into buf.
fn makeBeepWav(buf: []u8, ms: u32) []u8 {
    const rate: u32 = 22050;
    const samples = rate * ms / 1000;
    const data_len = samples * 2;
    const n = 44 + data_len;
    if (buf.len < n) return buf[0..0];
    const put32 = struct {
        fn f(b: []u8, off: usize, v: u32) void {
            std.mem.writeInt(u32, b[off..][0..4], v, .little);
        }
    }.f;
    const put16 = struct {
        fn f(b: []u8, off: usize, v: u16) void {
            std.mem.writeInt(u16, b[off..][0..2], v, .little);
        }
    }.f;
    @memcpy(buf[0..4], "RIFF");
    put32(buf, 4, 36 + data_len);
    @memcpy(buf[8..12], "WAVE");
    @memcpy(buf[12..16], "fmt ");
    put32(buf, 16, 16);
    put16(buf, 20, 1); // PCM
    put16(buf, 22, 1); // mono
    put32(buf, 24, rate);
    put32(buf, 28, rate * 2);
    put16(buf, 32, 2);
    put16(buf, 34, 16);
    @memcpy(buf[36..40], "data");
    put32(buf, 40, data_len);
    var i: u32 = 0;
    while (i < samples) : (i += 1) {
        const t_s = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(rate));
        const fade = 1.0 - @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(samples));
        const v: i16 = @intFromFloat(@sin(t_s * 2 * std.math.pi * 440) * 12000 * fade);
        put16(buf, 44 + i * 2, @bitCast(v));
    }
    return buf[0..n];
}

const Gallery = struct {
    tab: i32 = 0,
    theme_idx: i32 = 0,
    fruit_idx: i32 = 1,
    radio: i32 = 0,
    segmented: i32 = 0,
    sidebar: i32 = 0,
    crumb: i32 = 2,
    progress: f64 = 0.42,
    volume: f64 = 0.65,
    number: f64 = 3,
    step_val: f64 = 2,
    range_lo: f64 = 20,
    range_hi: f64 = 80,
    rating_val: i32 = 3,
    date_ms: i64 = 1_704_067_200_000, // 2024-01-01 UTC
    time_ms: i64 = 1_704_067_200_000,
    color: ui.Color = ui.Color.rgb(99, 102, 241),
    notified: bool = true,
    bold_on: bool = false,
    italic_on: bool = true,
    mail_on: bool = true,
    push_on: bool = false,
    dark_preview: bool = false,
    details_open: bool = true,
    acc_a: bool = true,
    acc_b: bool = false,
    split_size: f32 = 200,
    vsplit_size: f32 = 160,
    table_sel: i32 = 0,
    list_sel: i32 = 0,
    combo_idx: i32 = 0,
    combo_buf: [64]u8 = initBuf64("Banana"),
    combo_len: usize = 6,
    note_buf: [256]u8 = @splat(0),
    note_len: usize = 0,
    search_buf: [64]u8 = @splat(0),
    search_len: usize = 0,
    auto_buf: [64]u8 = @splat(0),
    auto_len: usize = 0,
    decimal_buf: [32]u8 = initBuf32("12.50"),
    decimal_len: usize = 5,
    ed_stats: ui.EditorStats = .{},
    soft_wrap: bool = true,
    show_diff: bool = false,
    ask_delete: bool = false,
    last_alert: i32 = -1,
    modal_open: bool = false,
    popover_open: bool = false,
    tree_src: bool = true,
    tree_sdk: bool = true,
    tree_host: bool = false,
    tag_store: [8][32]u8 = initTags(),
    tag_lens: [8]usize = .{ 3, 4, 2, 0, 0, 0, 0, 0 },
    tag_count: usize = 3,
    tag_pack: [512]u8 = undefined,
    tag_pack_len: usize = 0,
    edit_buf: [64]u8 = initBuf64("Rename me"),
    edit_len: usize = 9,
    find_open: bool = false,
    find_buf: [64]u8 = @splat(0),
    find_len: usize = 0,
    find_current: i32 = 0,
    grid_sel: i32 = 0,
    menu_id_buf: [32]u8 = undefined,
    menu_id_len: usize = 0,
    toast_undos: u32 = 0,
    ctx_id_buf: [32]u8 = undefined,
    ctx_id_len: usize = 0,
    drop_buf: [64]u8 = undefined,
    drop_len: usize = 0,
    drag_over: bool = false,
    ot_sel: i32 = 0,
    ot_open: [256]u8 = undefined,
    ot_open_len: usize = 0,
    drag_x: f32 = 20,
    drag_y: f32 = 20,
    line_ys: [12]f32 = .{ 4, 8, 6, 12, 9, 15, 11, 18, 14, 20, 16, 22 },
    bar_ys: [6]f32 = .{ 12, 18, 9, 22, 15, 11 },
    native_drop: [128]u8 = undefined,
    native_drop_len: usize = 0,
    native_over: bool = false,
    show_web: bool = false,
    web_url_is_proto: bool = false,
    show_video: bool = false,
    video_registered: bool = false,
    frames_registered: bool = false,
    stream_registered: bool = false,
    stream_tick: u32 = 0,
    motion_on: bool = false,
    motion_entered: bool = false,
    toast_id_buf: [64]u8 = undefined,
    last_toast_id_len: usize = 0,
    dialog_buf: [512]u8 = undefined,
    dialog_len: usize = 0,
    tray_id: usize = 0,
    tray_clicks: u32 = 0,
    tray_menu_buf: [32]u8 = undefined,
    tray_menu_len: usize = 0,
    input_kind: ui.InputKind = .key_down,
    input_key: ui.Key = .unknown,
    input_events: u32 = 0,
    hit_text: []const u8 = "",
    reveal: bool = false,
    check_state: ui.CheckState = .mixed,
    beep: mygo.Audio.Sound = .{ .id = 0 },
    beep_ms: u64 = 0,
    timeline_run: u64 = 0,
    board: ui.Graph.Board = .{ .id = 0 },
    doc: ui.RichText.Doc = .{ .id = 0 },
    rich_status: []const u8 = "",
    win_states: [8 * 1024]u8 = @splat(0),
    win_states_len: usize = 0,
    rich_buf: [64 * 1024]u8 = @splat(0),
    graph_sel: [4][]const u8 = @splat(""),
    graph_sel_count: usize = 0,
    graph_sel_buf: [512]u8 = @splat(0),
    tk_buf: [64]u8 = @splat(0),
    tk_len: usize = 0,
    drop_names: [8][]const u8 = @splat(""),
    drop_count: usize = 0,
    flyout_id: i32 = 0,
    main_win_id: i32 = 0,
        term_id: usize = 0,
        term_title_len: usize = 0,
        term_title_buf: [128]u8 = undefined,
        sqlite_id: usize = 0,
        watch_id: usize = 0,
    web_win_id: i32 = 0,
    notif_id_buf: [64]u8 = undefined,
    notif_id_len: usize = 0,
    notif_clicks: u32 = 0,
    notif_supported: bool = false,
    notif_click_cb: usize = 0,
    win_vibrancy: bool = false,
    content_protect: bool = false,
    hotkey_hits: u32 = 0,
    path_buf: [256]u8 = undefined,
    path_len: usize = 0,
    cursor_x: i32 = 0,
    cursor_y: i32 = 0,
    theme_dark: bool = false,
    on_battery: bool = false,
    idle_ms: usize = 0,
    power_event_buf: [32]u8 = undefined,
    power_event_len: usize = 0,
    awake_token: usize = 0,
    app_active: bool = true,
    open_url_buf: [128]u8 = undefined,
    open_url_len: usize = 0,
    dock_progress: f64 = 0,
    pie_vals: [4]f64 = .{ 30, 20, 25, 15 },
    custom_toasts: bool = false,
    mime_drop: [256]u8 = undefined,
    mime_drop_len: usize = 0,
    toast_info_buf: [256]u8 = undefined,
    outline_sel: i32 = 0,
    outline_open: [256]u8 = undefined,
    outline_open_len: usize = 0,
    router: ui.RouterState = ui.RouterState.init("gallery"),

    fn initBuf64(comptime seed: []const u8) [64]u8 {
        var b: [64]u8 = @splat(0);
        @memcpy(b[0..seed.len], seed);
        return b;
    }

    fn initBuf32(comptime seed: []const u8) [32]u8 {
        var b: [32]u8 = @splat(0);
        @memcpy(b[0..seed.len], seed);
        return b;
    }

    fn initTags() [8][32]u8 {
        var tags: [8][32]u8 = @splat(@splat(0));
        @memcpy(tags[0][0..3], "zig");
        @memcpy(tags[1][0..4], "mygo");
        @memcpy(tags[2][0..2], "ui");
        return tags;
    }

    fn renderListRow(self: *Gallery, row: ui.ListRow) void {
        _ = self;
        const c = row.ctx;
        const t = c.theme();
        const r = c.row().fillWidth().padding(8).gap(10).begin();
        defer r.end();
        _ = c.textf("Row {d}", .{row.index}).fontSize(13).grow(1.0);
        if (row.selected) {
            _ = c.badge("selected").fontSize(11).textColor(t.accent);
        }
    }

    fn renderTableCell(self: *Gallery, cell: ui.TableCell) void {
        _ = self;
        const c = cell.ctx;
        switch (cell.col) {
            0 => _ = c.textf("{d}", .{cell.row + 1}).fontSize(12).font("monospace"),
            1 => _ = c.textf("Item {d}", .{cell.row}).fontSize(13),
            2 => _ = c.textf("{d}", .{(cell.row * 17) % 100}).fontSize(12),
            else => {
                const label = switch (cell.row % 3) {
                    0 => "ok",
                    1 => "pending",
                    else => "fail",
                };
                _ = c.badge(label).fontSize(11);
            },
        }
    }

    fn splitLeft(self: *Gallery, c: *ui.Context) void {
        const t = c.theme();
        const col = c.column().fill().padding(10).gap(8).begin();
        defer col.end();
        _ = c.text("Sidebar pane").bold().fontSize(14);
        _ = c.text("Drag the divider.").fontSize(12).textColor(t.text_muted);
        _ = c.sidebar("nav", &self.sidebar, &sidebar_items).fillWidth().grow(1.0);
    }

    fn splitRight(self: *Gallery, c: *ui.Context) void {
        const t = c.theme();
        const col = c.column().fill().padding(12).gap(8).begin();
        defer col.end();
        _ = c.textf("Selected: {s}", .{sidebar_items[@intCast(self.sidebar)]}).fontSize(14).bold();
        _ = c.progress(self.progress).fillWidth();
        _ = c.meter(self.volume, 0, 1).fillWidth();
        _ = c.text("Vertical split below:").fontSize(12).textColor(t.text_muted);
        _ = c.splitVertical("vsplit", &self.vsplit_size, *Gallery, self, Gallery.vsplitTop, Gallery.vsplitBottom)
            .fillWidth()
            .grow(1.0);
    }

    fn vsplitTop(self: *Gallery, c: *ui.Context) void {
        _ = self;
        const box = c.box().fill().padding(10).begin();
        defer box.end();
        _ = c.text("Top pane").bold();
    }

    fn vsplitBottom(self: *Gallery, c: *ui.Context) void {
        _ = self;
        const box = c.box().fill().padding(10).begin();
        defer box.end();
        _ = c.text("Bottom pane").bold();
    }

    fn detailsBody(self: *Gallery, c: *ui.Context) void {
        const t = c.theme();
        const col = c.column().gap(6).begin();
        defer col.end();
        _ = c.text("Collapsible body built from Zig via ui_subview.").fontSize(13);
        _ = c.link("MyGo docs", "https://mygo.dev").fontSize(13);
        _ = c.checkbox("dark", &self.dark_preview, "Preview flag");
        _ = c.textf("progress={d:.0}%", .{self.progress * 100}).fontSize(12).textColor(t.text_muted);
    }

    fn accordionBody(self: *Gallery, c: *ui.Context) void {
        _ = c.accordionItem("a", "Getting started", &self.acc_a, *Gallery, self, Gallery.accABody);
        _ = c.accordionItem("b", "Advanced", &self.acc_b, *Gallery, self, Gallery.accBBody);
    }

    fn accABody(self: *Gallery, c: *ui.Context) void {
        _ = self;
        _ = c.text("Install Zig, link zig/host/ui, call mygo.exportApp.").fontSize(13);
    }

    fn accBBody(self: *Gallery, c: *ui.Context) void {
        _ = self;
        _ = c.text("Opt-in markdown & editor packages keep binary size lean.").fontSize(13);
    }

    fn notifGroup(self: *Gallery, c: *ui.Context) void {
        _ = c.checkbox("mail", &self.mail_on, "Email");
        _ = c.checkbox("push", &self.push_on, "Push");
    }

    fn planGroup(self: *Gallery, c: *ui.Context) void {
        _ = c.radio("plan/free", &self.radio, 0, "Free");
        _ = c.radio("plan/pro", &self.radio, 1, "Pro");
        _ = c.radio("plan/team", &self.radio, 2, "Team");
    }

    fn styleGroup(self: *Gallery, c: *ui.Context) void {
        _ = c.toggle("bold", &self.bold_on, "Bold");
        _ = c.toggle("italic", &self.italic_on, "Italic");
    }

    fn accountFieldset(self: *Gallery, c: *ui.Context) void {
        _ = c.textInput("note", &self.note_buf, &self.note_len).fillWidth().placeholder("Display name");
        _ = c.switchControl("notify", &self.notified);
    }

    fn modalBody(self: *Gallery, c: *ui.Context) void {
        const col = c.column().gap(10).padding(8).begin();
        defer col.end();
        _ = c.text("Modal from Zig").fontSize(18).bold();
        _ = c.text("Escape or the backdrop dismisses it.").fontSize(13);
        if (c.primaryButton("close-modal", "Close").clicked()) {
            self.modal_open = false;
        }
    }

    fn popoverBody(self: *Gallery, c: *ui.Context) void {
        const col = c.column().gap(6).padding(8).width(180).begin();
        defer col.end();
        _ = c.text("Popover menu").bold().fontSize(13);
        if (c.button("p1", "Action A").fillWidth().clicked()) self.popover_open = false;
        if (c.button("p2", "Action B").fillWidth().clicked()) self.popover_open = false;
    }

    fn viewControls(self: *Gallery, c: *ui.Context) void {
        const t = c.theme();

        _ = c.breadcrumbs("crumbs", &self.crumb, &crumbs).fillWidth();

        {
            const row = c.row().gap(10).center().begin();
            defer row.end();
            _ = c.avatar("Ada Lovelace");
            _ = c.avatar("Zig Lang");
            _ = c.spinner();
            _ = c.badge("beta").fontSize(11).textColor(t.accent);
        }

        {
            const row = c.row().fillWidth().gap(10).begin();
            defer row.end();
            _ = c.segmented("seg", &self.segmented, &.{"Day", "Week", "Month"}).grow(1.0);
        }

        {
            const row = c.row().fillWidth().gap(12).begin();
            defer row.end();
            _ = c.selectIndex("theme", &self.theme_idx, &themes).width(140).label("Theme");
            _ = c.selectIndex("fruit", &self.fruit_idx, &fruits).width(160).label("Fruit");
            _ = c.combobox("combo", &self.combo_idx, &fruits, self.combo_buf[0..], &self.combo_len)
                .grow(1.0)
                .label("Combobox");
        }

        _ = c.radioGroup("plans", *Gallery, self, Gallery.planGroup);
        _ = c.checkboxGroup("notif", "Notifications", *Gallery, self, Gallery.notifGroup);
        _ = c.toggleGroup("style", *Gallery, self, Gallery.styleGroup);
        _ = c.fieldset("account", "Account", *Gallery, self, Gallery.accountFieldset);

        {
            const row = c.row().fillWidth().gap(10).center().begin();
            defer row.end();
            _ = c.text("Volume").width(64);
            _ = c.slider("vol", &self.volume, 0, 1).grow(1.0);
            _ = c.switchControl("notify2", &self.notified);
            _ = c.text("Notify").fontSize(12);
        }

        _ = c.progress(self.progress).fillWidth();
        {
            const row = c.row().gap(8).begin();
            defer row.end();
            if (c.button("bump", "Advance progress").clicked()) {
                self.progress = @min(1.0, self.progress + 0.08);
            }
            if (c.button("ask", "Alert…").clicked()) self.ask_delete = true;
            if (c.button("modal", "Modal…").clicked()) self.modal_open = true;
            if (c.button("pop", "Popover…").clicked()) self.popover_open = true;
            _ = c.popover(&self.popover_open, *Gallery, self, Gallery.popoverBody);
        }

        switch (c.alertDialog(&self.ask_delete, "Delete item?", "This cannot be undone.", &.{"Cancel", "Delete"})) {
            1 => self.last_alert = 1,
            0 => self.last_alert = 0,
            ui.alert_dismissed => self.last_alert = ui.alert_dismissed,
            else => {},
        }
        _ = c.modal("demo-modal", &self.modal_open, *Gallery, self, Gallery.modalBody);

        if (self.last_alert != -1) {
            _ = c.textf("last alert result={d}", .{self.last_alert}).fontSize(12).textColor(t.text_muted);
        }
    }

    fn viewInputs(self: *Gallery, c: *ui.Context) void {
        const t = c.theme();
        _ = c.text("Numbers · dates · color · search").fontSize(16).bold();

        _ = c.searchField("search", self.search_buf[0..], &self.search_len).fillWidth().placeholder("Search…")
            .observeInput(*Gallery, self, Gallery.onInput)
            .handleInput(*Gallery, self, Gallery.onInputTake);
        _ = c.autocomplete("city", self.auto_buf[0..], &self.auto_len, &cities).fillWidth().label("City");

        {
            const row = c.row().fillWidth().gap(10).center().begin();
            defer row.end();
            _ = c.text("Number").width(64);
            _ = c.numberInput("num", &self.number, 0, 10, 0.5).width(100);
            _ = c.stepper("step", &self.step_val, 0, 10, 1);
            _ = c.rating("stars", &self.rating_val, 5);
        }

        _ = c.stepSlider("steps", &self.number, 0, 10, 1).fillWidth();
        _ = c.rangeSlider("price", &self.range_lo, &self.range_hi, 0, 100, 1).fillWidth();
        _ = c.textf("range {d:.0} … {d:.0}", .{ self.range_lo, self.range_hi }).fontSize(12).textColor(t.text_muted);

        _ = c.decimalInput("dec", self.decimal_buf[0..], &self.decimal_len, "0", "100", "0.01")
            .fillWidth()
            .label("Decimal");

        {
            const row = c.row().fillWidth().gap(12).begin();
            defer row.end();
            _ = c.dateInput("date", &self.date_ms).label("Date");
            _ = c.timeInput("time", &self.time_ms).label("Time");
            _ = c.colorWell("well", &self.color).label("Color");
        }
        {
            const row = c.row().fillWidth().gap(12).begin();
            defer row.end();
            _ = c.calendar("cal", &self.date_ms).width(280);
            _ = c.colorPicker("picker", &self.color).grow(1.0).height(200);
        }

        _ = c.textArea("notes", self.note_buf[0..], &self.note_len)
            .fillWidth()
            .height(80)
            .placeholder("Notes…");
    
        // Element observeInput / hitTest / handleInput.
        {
            const row = c.row().fillWidth().gap(10).center().begin();
            defer row.end();
            _ = c.textf("input {s} {s} x{d}", .{
                @tagName(self.input_kind),
                @tagName(self.input_key),
                self.input_events,
            }).fontSize(12).textColor(t.text_muted).grow(1.0);
            const probe = c.box().size(120, 36).background(t.surface).radius(8)
                .hitTest(*Gallery, self, Gallery.hitProbe);
            const pr = probe.begin();
            defer pr.end();
            _ = c.text(self.hit_text).fontSize(12).center();
        }
}

    fn viewLayout(self: *Gallery, c: *ui.Context) void {
        _ = c.text("Split · Sidebar · Collapsible · Accordion").fontSize(16).bold();
        _ = c.collapsible("details", "Details", &self.details_open, *Gallery, self, Gallery.detailsBody)
            .fillWidth();
        _ = c.accordion("acc", *Gallery, self, Gallery.accordionBody).fillWidth();
        _ = c.split("main", &self.split_size, *Gallery, self, Gallery.splitLeft, Gallery.splitRight)
            .fillWidth()
            .grow(1.0)
            .border(1, c.theme().border)
            .radius(8);
    }

    fn treeBody(self: *Gallery, c: *ui.Context) void {
        _ = c.treeItem("src", "src/", &self.tree_src, *Gallery, self, Gallery.treeSrcBody);
        _ = c.treeItem("readme", "README.md", null, *Gallery, self, Gallery.noop);
        _ = c.treeItem("build", "build.zig", null, *Gallery, self, Gallery.noop);
    }

    fn treeSrcBody(self: *Gallery, c: *ui.Context) void {
        _ = c.treeItem("sdk", "sdk/", &self.tree_sdk, *Gallery, self, Gallery.treeSdkBody);
        _ = c.treeItem("host", "host/", &self.tree_host, *Gallery, self, Gallery.treeHostBody);
        _ = c.treeItem("app", "app.zig", null, *Gallery, self, Gallery.noop);
    }

    fn treeSdkBody(self: *Gallery, c: *ui.Context) void {
        _ = c.treeItem("ui", "ui.zig", null, *Gallery, self, Gallery.noop);
        _ = c.treeItem("mygo", "mygo.zig", null, *Gallery, self, Gallery.noop);
    }

    fn treeHostBody(self: *Gallery, c: *ui.Context) void {
        _ = c.treeItem("hostgo", "host.go", null, *Gallery, self, Gallery.noop);
        _ = c.treeItem("uigo", "ui/ui.go", null, *Gallery, self, Gallery.noop);
    }

    fn noop(self: *Gallery, c: *ui.Context) void {
        _ = self;
        _ = c;
    }

    fn toolbarBody(self: *Gallery, c: *ui.Context) void {
        const row = c.row().gap(6).center().begin();
        defer row.end();
        _ = c.icon(star_svg);
        if (c.button("tb-save", "Save").clicked()) c.toast("Saved");
        if (c.button("tb-find", "Find").clicked()) self.find_open = true;
        if (c.menuButton("tb-menu", "File", &menu_entries, self.menu_id_buf[0..], &self.menu_id_len)) {}
        _ = c.spacer();
        _ = c.badge("toolbar").fontSize(11);
    }

    fn renderGridItem(self: *Gallery, item: ui.GridItem) void {
        _ = self;
        const c = item.ctx;
        const t = c.theme();
        const box = c.box().fill().padding(8).gap(4).center().begin();
        defer box.end();
        _ = c.icon(star_svg);
        _ = c.textf("#{d}", .{item.index}).fontSize(12);
        if (item.selected) {
            _ = c.badge("sel").fontSize(10).textColor(t.accent);
        }
    }



    fn viewFlyout(self: *Gallery, c: *ui.Context) void {
        const t = c.theme();
        const root = c.column().fill().padding(14).gap(10).begin();
        defer root.end();
        _ = c.box().fillWidth().height(8).radius(4).linearGradient(90, t.accent, t.success, false);
        _ = c.text("Flyout panel").fontSize(16).bold();
        _ = c.textf("Native UI · vibrancy={s}", .{if (c.hasVibrancy()) "yes" else "no"}).fontSize(12).textColor(t.text_muted);
        _ = c.textf("tray clicks={d}", .{self.tray_clicks}).fontSize(12);
        if (c.primaryButton("fly-close", "Close").clicked()) {
            if (self.flyout_id != 0) {
                const w: mygo.Window = .{ .id = self.flyout_id };
                w.close();
                self.flyout_id = 0;
            }
        }
    }

    fn openParentFlyout(self: *Gallery) void {
        if (self.flyout_id != 0) {
            const w: mygo.Window = .{ .id = self.flyout_id };
            w.close();
            self.flyout_id = 0;
        }
        if (self.main_win_id == 0) return;
        const fl = mygo.newFlyoutUi(*Gallery, self, .{
            .parent = .{ .id = self.main_win_id },
            .anchor = .{ .x = 40, .y = 80, .width = 120, .height = 28 },
            .placement = "bottom-start",
            .gap = 6,
            .width = 260,
            .height = 180,
            .flags = mygo.FlyoutFlag.focusable | mygo.FlyoutFlag.shadow,
            .vibrancy = "glass",
            .corner_radius = 12,
        }, Gallery.viewFlyout) catch return;
        self.flyout_id = fl.id;
    }

    fn openTrayFlyout(self: *Gallery) void {
        if (self.tray_id == 0) return;
        if (self.flyout_id != 0) {
            const w: mygo.Window = .{ .id = self.flyout_id };
            w.close();
            self.flyout_id = 0;
        }
        const fl = mygo.newFlyoutUi(*Gallery, self, .{
            .tray = .{ .id = self.tray_id },
            .placement = "bottom",
            .gap = 4,
            .width = 280,
            .height = 200,
            .flags = mygo.FlyoutFlag.focusable | mygo.FlyoutFlag.shadow | mygo.FlyoutFlag.popover,
            .vibrancy = "popover",
        }, Gallery.viewFlyout) catch return;
        self.flyout_id = fl.id;
    }













    fn onLocaleChanged(self: *Gallery, locale: []const u8) void {
        const n = @min(locale.len, self.path_buf.len);
        @memcpy(self.path_buf[0..n], locale[0..n]);
        self.path_len = n;
    }

    fn onContextMenu(self: *Gallery, ev: mygo.ContextMenuEvent) void {
        const src = if (ev.link_url.len > 0) ev.link_url else if (ev.selection.len > 0) ev.selection else "context-menu";
        const n = @min(src.len, self.path_buf.len);
        @memcpy(self.path_buf[0..n], src[0..n]);
        self.path_len = n;
        if (self.web_win_id != 0) {
            const win = mygo.Window{ .id = self.web_win_id };
            // Keep default menu.
            win.contextMenuRespond(ev.req_id, false, "");
        }
    }

    fn onPageMedia(self: *Gallery, kind: u8, payload: usize) void {
        var buf: [64]u8 = undefined;
        const msg = if (kind == 1)
            std.fmt.bufPrint(&buf, "audible={d}", .{payload}) catch "media"
        else
            std.fmt.bufPrint(&buf, "capture kind={d} state={d}", .{ payload >> 16, payload & 0xffff }) catch "media";
        const n = @min(msg.len, self.path_buf.len);
        @memcpy(self.path_buf[0..n], msg[0..n]);
        self.path_len = n;
    }

    fn onPermission(self: *Gallery, req: mygo.PermissionRequest) bool {
        const n = @min(req.origin.len, self.path_buf.len);
        @memcpy(self.path_buf[0..n], req.origin[0..n]);
        self.path_len = n;
        return false; // deny by default in gallery
    }

    fn onWindowOpen(self: *Gallery, req_id: usize, req: mygo.WindowOpenRequest) void {
        const n = @min(req.url.len, self.path_buf.len);
        @memcpy(self.path_buf[0..n], req.url[0..n]);
        self.path_len = n;
        if (self.web_win_id != 0) {
            const win = mygo.Window{ .id = self.web_win_id };
            // Deny scripted popups; allow user-initiated into a small window.
            if (!req.user_initiated) {
                win.windowOpenRespond(req_id, true, .{});
            } else {
                win.windowOpenRespond(req_id, false, .{ .title = "Opened", .url = req.url, .width = if (req.width > 0) req.width else 480, .height = if (req.height > 0) req.height else 360 });
            }
        }
    }

    fn onPageEvent(self: *Gallery, kind: u8, ev: mygo.PageEvent) void {
        if (kind == @intFromEnum(mygo.PageEventKind.will_navigate) and self.web_win_id != 0) {
            const win = mygo.Window{ .id = self.web_win_id };
            win.navigateRespond(ev.req_id, false);
        }
        if (kind == @intFromEnum(mygo.PageEventKind.title_updated) and self.web_win_id != 0) {
            const win = mygo.Window{ .id = self.web_win_id };
            win.titleRespond(ev.req_id, false);
        }
        const src = if (ev.url.len > 0) ev.url else ev.description;
        const n = @min(src.len, self.path_buf.len);
        @memcpy(self.path_buf[0..n], src[0..n]);
        self.path_len = n;
    }

    fn onDownload(self: *Gallery, kind: u8, ev: mygo.DownloadEvent) void {
        if (kind == 1) {
            // Accept default path.
            if (self.main_win_id != 0) {
                const win = mygo.Window{ .id = self.main_win_id };
                win.downloadRespond(ev.req_id, false, ev.path);
            }
            const n = @min(ev.suggested.len, self.path_buf.len);
            @memcpy(self.path_buf[0..n], ev.suggested[0..n]);
            self.path_len = n;
            return;
        }
        // done
        const src = if (ev.err.len > 0) ev.err else ev.path;
        const n = @min(src.len, self.path_buf.len);
        @memcpy(self.path_buf[0..n], src[0..n]);
        self.path_len = n;
    }

    fn onAuthChallenge(self: *Gallery, req_id: usize, req: mygo.AuthRequest) void {
        const n = @min(req.host.len, self.path_buf.len);
        @memcpy(self.path_buf[0..n], req.host[0..n]);
        self.path_len = n;
        // Cancel by default (empty credentials) — demo only records the host.
        if (self.main_win_id != 0) {
            const win = mygo.Window{ .id = self.main_win_id };
            win.authRespond(req_id, "", "");
        }
    }

    fn onCertError(self: *Gallery, err: mygo.CertificateError) bool {
        const n = @min(err.host.len, self.path_buf.len);
        @memcpy(self.path_buf[0..n], err.host[0..n]);
        self.path_len = n;
        return false; // never auto-trust
    }

    fn onDockMenu(self: *Gallery, id: []const u8) void {
        const n = @min(id.len, self.menu_id_buf.len);
        @memcpy(self.menu_id_buf[0..n], id[0..n]);
        self.menu_id_len = n;
    }

    fn onProtocol(self: *Gallery, req_id: usize, req: mygo.ProtocolRequest) void {
        _ = self;
        if (std.mem.indexOf(u8, req.url, "/hello") != null) {
            const body = "<!doctype html><meta charset=utf-8><title>gzig</title><body style='font:16px system-ui;padding:24px'><h1>galleryzig://</h1><p>Served from Zig Protocol.handle</p></body>";
            const headers = "{\"Content-Type\":\"text/html; charset=utf-8\"}";
            mygo.Protocol.respond(req_id, 200, headers, body);
            return;
        }
        mygo.Protocol.respond(req_id, 404, "{\"Content-Type\":\"text/plain\"}", "not found");
    }

    fn onDidBecomeActive(self: *Gallery) void {
        self.app_active = true;
    }

    fn onDidResignActive(self: *Gallery) void {
        self.app_active = false;
    }

    fn onOpenURL(self: *Gallery, url: []const u8) void {
        const n = @min(url.len, self.open_url_buf.len);
        @memcpy(self.open_url_buf[0..n], url[0..n]);
        self.open_url_len = n;
    }

    fn onThemeUpdated(self: *Gallery) void {
        self.theme_dark = mygo.Appearance.isDark();
    }

    fn onPowerEvent(self: *Gallery, ev: []const u8) void {
        const n = @min(ev.len, self.power_event_buf.len);
        @memcpy(self.power_event_buf[0..n], ev[0..n]);
        self.power_event_len = n;
        self.on_battery = mygo.Power.isOnBattery();
        self.idle_ms = mygo.Power.idleMs();
    }

    fn onHotkey(self: *Gallery) void {
        self.hotkey_hits +%= 1;
    }

    fn onNotifClick(self: *Gallery, id: []const u8) void {
        self.notif_clicks +%= 1;
        const n = @min(id.len, self.notif_id_buf.len);
        @memcpy(self.notif_id_buf[0..n], id[0..n]);
        self.notif_id_len = n;
    }

    fn onTrayMenu(self: *Gallery, id: []const u8) void {
        const n = @min(id.len, self.tray_menu_buf.len);
        @memcpy(self.tray_menu_buf[0..n], id[0..n]);
        self.tray_menu_len = n;
        if (std.mem.eql(u8, id, "quit")) {
            mygo.quit();
        } else if (std.mem.eql(u8, id, "show")) {
            self.openTrayFlyout();
        }
    }

    fn onTrayClick(self: *Gallery) void {
        self.tray_clicks +%= 1;
        if (self.tray_id != 0) {
            const tr: mygo.Tray = .{ .id = self.tray_id };
            var buf: [16]u8 = undefined;
            const title = std.fmt.bufPrint(&buf, "{d}", .{self.tray_clicks}) catch "*";
            tr.setTitle(title);
            // Menu owns single-click on some platforms; when OnClick fires, show panel.
            self.openTrayFlyout();
        }
    }

    fn ensureTray(self: *Gallery) void {
        if (self.tray_id != 0) return;
        const menu_cb = mygo.Tray.registerMenuHandler(*Gallery, self, Gallery.onTrayMenu);
        const tr = mygo.Tray.new(.{
            .id = "gallery-zig",
            .icon_png = tray_png,
            .title = "Zig",
            .tooltip = "MyGo Zig Gallery",
            .menu_json = "",
            .menu_cb = menu_cb,
        }) catch return;
        self.tray_id = tr.id;
        tr.setMenu(&tray_menu_items) catch {};
        tr.onClick(*Gallery, self, Gallery.onTrayClick);
    }

    fn destroyTray(self: *Gallery) void {
        if (self.tray_id == 0) return;
        const tr: mygo.Tray = .{ .id = self.tray_id };
        tr.destroy();
        self.tray_id = 0;
    }

    fn onToastUndo(self: *Gallery) void {
        self.toast_undos += 1;
    }

    fn onInput(self: *Gallery, ev: ui.InputEvent) void {
        self.input_kind = ev.kind;
        self.input_key = ev.key;
        self.input_events +%= 1;
    }

    fn beepNow(self: *Gallery) void {
        if (self.beep.id == 0) {
            var wav: [44 + 22050 * 2 * 300 / 1000]u8 = undefined;
            const bytes = makeBeepWav(wav[0..], 300);
            self.beep = mygo.Audio.decodeSound(bytes) catch return;
            self.beep_ms = self.beep.durationMs();
        }
        const player = self.beep.play() catch return;
        _ = player.setVolume(0.4);
    }

    fn onTextKey(self: *Gallery, k: *ui.TextKey) bool {
        _ = self;
        if (k.key != .f2) return false;
        var buf: [128]u8 = undefined;
        const n = @min(k.text.len, buf.len);
        for (k.text[0..n], 0..) |ch, i| buf[i] = std.ascii.toUpper(ch);
        k.replace(buf[0..n]);
        return true;
    }

    fn onInputTake(self: *Gallery, ev: ui.InputEvent) bool {
        // Consume F1 to show handleInput taking one, and nothing else.
        if (ev.kind == .key_down and ev.key == .f1) {
            self.input_events +%= 1;
            return true;
        }
        return false;
    }

    fn hitProbe(self: *Gallery, px: f32, py: f32, r: ui.Rect) bool {
        const cx = r.x + r.w / 2;
        const cy = r.y + r.h / 2;
        const dx = px - cx;
        const dy = py - cy;
        const hit = dx * dx + dy * dy <= (r.h / 2) * (r.h / 2);
        if (hit) self.hit_text = "circle" else self.hit_text = "box";
        return hit;
    }

    fn renderOutlineRow(self: *Gallery, row: ui.OutlineRow) void {
        _ = self;
        const c = row.ctx;
        const t = c.theme();
        const r = c.row().fillWidth().gap(6).center().begin();
        defer r.end();
        if (row.branch) {
            _ = c.badge(if (row.open) "−" else "+").fontSize(10);
        } else {
            _ = c.badge("·").fontSize(10).textColor(t.text_muted);
        }
        _ = c.text(row.id).fontSize(13).grow(1.0);
        if (row.selected) {
            _ = c.badge("sel").fontSize(10).textColor(t.accent);
        }
    }

    fn renderRoute(self: *Gallery, route: ui.Route) void {
        const c = route.ctx;
        const t = c.theme();
        const col = c.column().fill().padding(12).gap(8).begin();
        defer col.end();
        _ = c.textf("path: {s}", .{route.path}).fontSize(16).bold();
        _ = c.text("Use Back/Forward or the links below.").fontSize(12).textColor(t.text_muted);

        const spans = [_]ui.Span{
            ui.Span.plain("RichText: "),
            ui.Span.bold("bold"),
            ui.Span.plain(" · "),
            .{ .text = "italic", .italic = true },
            ui.Span.plain(" · "),
            .{ .text = "accent", .color = t.accent, .weight = 600 },
        };
        _ = c.richText(&spans);

        {
            const row = c.row().gap(8).begin();
            defer row.end();
            if (c.button("to-home", "/home").clicked()) c.routerPush(&self.router, "/home");
            if (c.button("to-settings", "/settings").clicked()) c.routerPush(&self.router, "/settings");
            if (c.button("to-about", "/about").clicked()) c.routerPush(&self.router, "/about");
        }

        if (c.routeMatch("/settings/{section...}")) {
            _ = c.text("Settings layout").fontSize(14).bold();
            {
                const row = c.row().gap(8).begin();
                defer row.end();
                if (c.button("sec-general", "General").clicked()) c.routerPush(&self.router, "/settings/general");
                if (c.button("sec-fonts", "Fonts").clicked()) c.routerPush(&self.router, "/settings/fonts");
            }
            _ = c.routeView(*Gallery, self, Gallery.renderSettingsSection).fillWidth().grow(1.0).border(1, t.border).radius(8).padding(8);
        } else if (std.mem.eql(u8, route.path, "/about")) {
            _ = c.text("About MyGo × Zig").fontSize(14);
        } else {
            _ = c.text("Home page").fontSize(14);
        }
    }

    fn renderSettingsSection(self: *Gallery, route: ui.Route) void {
        _ = self;
        const c = route.ctx;
        const t = c.theme();
        const col = c.column().fill().gap(6).begin();
        defer col.end();
        if (c.routeMatch("/fonts")) {
            _ = c.text("Fonts section").fontSize(13).bold();
            _ = c.text("Nested Route.View keeps layout state.").fontSize(12).textColor(t.text_muted);
        } else if (c.routeMatch("/general") or c.routeMatch("/")) {
            _ = c.text("General section").fontSize(13).bold();
            _ = c.textf("inner path: {s}", .{route.path}).fontSize(12).textColor(t.text_muted);
        } else {
            _ = c.textf("section: {s}", .{route.path}).fontSize(12);
        }
    }

    fn renderOutlineCell(self: *Gallery, cell: ui.OutlineCell) void {
        _ = self;
        const c = cell.ctx;
        const t = c.theme();
        switch (cell.col) {
            0 => {
                const r = c.row().fillWidth().gap(6).center().begin();
                defer r.end();
                if (cell.branch) {
                    _ = c.badge(if (cell.open) "−" else "+").fontSize(10);
                }
                _ = c.text(cell.id).fontSize(13).grow(1.0);
            },
            1 => {
                _ = c.text(if (cell.branch) "dir" else "file").fontSize(12).textColor(t.text_muted);
            },
            else => {
                if (cell.selected) {
                    _ = c.badge("sel").fontSize(10).textColor(t.accent);
                } else {
                    _ = c.textf("d={d}", .{cell.depth}).fontSize(11).textColor(t.text_muted);
                }
            },
        }
    }

    fn viewNav(self: *Gallery, c: *ui.Context) void {
        const t = c.theme();
        _ = c.text("Outline · Nested routes · WebView · Video · Native drag").fontSize(16).bold();

        {
            const row = c.row().fillWidth().gap(8).center().begin();
            defer row.end();
            _ = c.backButton(&self.router);
            _ = c.forwardButton(&self.router);
            _ = c.textf("{s}", .{self.router.path()}).fontSize(12).textColor(t.text_muted).grow(1.0);
            if (self.router.can_go_back) {
                _ = c.badge("can←").fontSize(10);
            }
            if (self.router.can_go_forward) {
                _ = c.badge("can→").fontSize(10);
            }
        }

        _ = c.router(&self.router, "/home", *Gallery, self, Gallery.renderRoute)
            .fillWidth()
            .height(140)
            .border(1, t.border)
            .radius(8);

        {
            const row = c.row().fillWidth().gap(10).center().begin();
            defer row.end();
            const label = c.text("Right-click / nested menu").padding(8).border(1, t.border).radius(6);
            _ = label.contextMenu(&ctx_entries, self.ctx_id_buf[0..], &self.ctx_id_len);
            _ = c.popoverMenuButton("pmb", "Popover Menu", &menu_entries, self.menu_id_buf[0..], &self.menu_id_len);

            _ = c.badge("Drag me").padding(8).radius(6).drag("gallery-chip");

            var over_buf: [64]u8 = undefined;
            var over_len: usize = 0;
            const target = c.box().padding(8).radius(6).border(1, if (self.drag_over) t.accent else t.border);
            self.drag_over = target.dragOver(over_buf[0..], &over_len);
            if (target.drop(self.drop_buf[0..], &self.drop_len)) {
                self.drag_over = false;
            }
            {
                const body = target.begin();
                defer body.end();
                if (self.drop_len > 0) {
                    _ = c.textf("drop={s}", .{self.drop_buf[0..self.drop_len]}).fontSize(12);
                } else if (self.drag_over) {
                    _ = c.text("drop here").fontSize(12).textColor(t.accent);
                } else {
                    _ = c.text("Drop target").fontSize(12).textColor(t.text_muted);
                }
            }
        }
        if (self.ctx_id_len > 0) {
            _ = c.textf("context chose {s}", .{self.ctx_id_buf[0..self.ctx_id_len]}).fontSize(12).textColor(t.text_muted);
        }
        if (self.menu_id_len > 0) {
            _ = c.textf("menu chose {s}", .{self.menu_id_buf[0..self.menu_id_len]}).fontSize(12).textColor(t.text_muted);
        }

        _ = c.text("Outline").fontSize(13).bold().textColor(t.text_muted);
        _ = c.outline(
            "files",
            &self.outline_sel,
            self.outline_open[0..],
            &self.outline_open_len,
            &outline_roots,
            &outline_nodes,
            *Gallery,
            self,
            Gallery.renderOutlineRow,
        )
            .fillWidth()
            .height(140)
            .border(1, t.border)
            .radius(8);

        _ = c.text("OutlineTable").fontSize(13).bold().textColor(t.text_muted);
        _ = c.outlineTable(
            "files-table",
            &self.ot_sel,
            self.ot_open[0..],
            &self.ot_open_len,
            &outline_roots,
            &outline_nodes,
            &outline_table_cols,
            *Gallery,
            self,
            Gallery.renderOutlineCell,
        )
            .fillWidth()
            .height(120)
            .border(1, t.border)
            .radius(8);

        {
            const row = c.row().fillWidth().gap(10).center().begin();
            defer row.end();
            _ = c.badge("Native drag text").padding(8).radius(6).dragData("hello from Zig gallery");
            const zone = c.box().padding(8).radius(6).border(1, if (self.native_over) t.accent else t.border).grow(1.0);
            self.native_over = zone.dataDragOver();
            if (zone.dropData(self.native_drop[0..], &self.native_drop_len)) {
                self.native_over = false;
            }
            {
                const body = zone.begin();
                defer body.end();
                if (self.native_drop_len > 0) {
                    _ = c.textf("got {s}", .{self.native_drop[0..self.native_drop_len]}).fontSize(12);
                } else if (self.native_over) {
                    _ = c.text("drop text/url/file").fontSize(12).textColor(t.accent);
                } else {
                    _ = c.text("Native drop target").fontSize(12).textColor(t.text_muted);
                }
            }
            if (c.button("toggle-web", if (self.show_web) "Hide Web" else "Show Web").clicked()) {
                self.show_web = !self.show_web;
                if (!self.show_web) c.destroyWebView("docs");
            }
            if (c.button("proto-web", "Protocol page").clicked()) {
                self.web_url_is_proto = true;
                self.show_web = true;
                c.destroyWebView("docs");
            }
            if (c.button("docs-web", "Docs page").clicked()) {
                self.web_url_is_proto = false;
                self.show_web = true;
                c.destroyWebView("docs");
            }
        }

        if (self.show_web) {
            const url: []const u8 = if (self.web_url_is_proto) "galleryzig://localhost/hello" else "https://mygo.egoist.dev";
            _ = c.webView("docs", url).fillWidth().height(180).border(1, t.border).radius(8);
        }

        {
            const row = c.row().fillWidth().gap(10).center().begin();
            defer row.end();
            if (c.button("toggle-video", if (self.show_video) "Hide GIF" else "Show GIF").clicked()) {
                self.show_video = !self.show_video;
                if (!self.show_video) c.videoClose("waves");
            }
            if (c.button("toggle-frames", if (self.frames_registered) "Hide frames" else "Frames video").clicked()) {
                if (self.frames_registered) {
                    c.videoClose("frames");
                    self.frames_registered = false;
                } else {
                    self.ensureFrameVideo(c);
                }
            }
            if (c.button("toggle-stream", if (self.stream_registered) "Hide stream" else "Stream video").clicked()) {
                if (self.stream_registered) {
                    c.endVideoStream("stream");
                    c.videoClose("stream");
                    self.stream_registered = false;
                } else {
                    self.ensureStreamVideo(c);
                }
            }
            if (self.show_video) {
                if (c.button("pause-video", "Pause").clicked()) c.videoPause("waves");
                if (c.button("play-video", "Play").clicked()) c.videoPlay("waves");
            }
        }
        if (self.show_video) {
            c.registerVideoGIF("waves", waves_gif, true);
            _ = c.video("waves", .cover).fillWidth().height(160).border(1, t.border).radius(8);
        }
        if (self.frames_registered) {
            _ = c.video("frames", .contain).width(80).height(80).border(1, t.border).radius(6);
        }

        if (self.stream_registered) {
            self.pumpStream(c);
            _ = c.video("stream", .contain).fillWidth().height(140);
        }
    }

    fn viewRich(self: *Gallery, c: *ui.Context) void {
        const t = c.theme();
        if (self.doc.id == 0) {
            self.doc = ui.RichText.markdown(sample_rich) catch .{ .id = 0 };
            if (self.doc.id != 0) {
                self.doc = self.doc.onLink(*Gallery, self, Gallery.onRichLink);
                self.doc = self.doc.onLinkCommand(*Gallery, self, Gallery.onRichLinkCommand);
                self.doc = self.doc.onTagStyle(*Gallery, self, Gallery.onRichTag);
            }
        }
        {
            const row = c.row().fillWidth().gap(6).center().begin();
            defer row.end();
            if (c.button("rt-b", "B").clicked()) _ = self.doc.command(.bold);
            if (c.button("rt-i", "I").clicked()) _ = self.doc.command(.italic);
            if (c.button("rt-u", "U").clicked()) _ = self.doc.command(.underline);
            if (c.button("rt-code", "Code").clicked()) _ = self.doc.command(.code);
            if (c.button("rt-ul", "• List").clicked()) _ = self.doc.command(.bullet_list);
            if (c.button("rt-ol", "1. List").clicked()) _ = self.doc.command(.number_list);
            if (c.button("rt-quote", "Quote").clicked()) _ = self.doc.command(.quote);
            if (c.button("rt-h2", "H2").clicked()) self.doc.heading(2);
            if (c.button("rt-undo", "Undo").clicked()) _ = self.doc.command(.undo);
            if (c.button("rt-redo", "Redo").clicked()) _ = self.doc.command(.redo);
            if (c.button("rt-save", "Copy Markdown").clicked()) {
                const md = self.doc.save(.markdown, self.rich_buf[0..]);
                mygo.Clipboard.writeText(md);
            }
            _ = c.textf("v{d} {s}", .{ self.doc.version(), self.rich_status }).fontSize(11).textColor(t.text_muted).grow(1.0);
        }
        _ = self.doc.view(c, .{ .placeholder = "Write something…" }).fill().grow(1.0);
    }

    fn loadWindowStates(self: *Gallery, buf: []u8) usize {
        if (self.win_states_len == 0 or self.win_states_len > buf.len) return 0;
        @memcpy(buf[0..self.win_states_len], self.win_states[0..self.win_states_len]);
        return self.win_states_len;
    }

    fn saveWindowStates(self: *Gallery, json: []const u8) void {
        const n = @min(json.len, self.win_states.len);
        @memcpy(self.win_states[0..n], json[0..n]);
        self.win_states_len = n;
    }

    fn onRichLink(self: *Gallery, url: []const u8) void {
        mygo.Shell.openExternal(url) catch {};
        self.rich_status = "link";
    }

    fn onRichLinkCommand(self: *Gallery) void {
        self.rich_status = "cmd+k";
    }

    fn onRichTag(self: *Gallery, tag: []const u8, style: *ui.RichText.Style) void {
        _ = tag;
        self.rich_status = "tag";
        style.color = ui.Color.rgb(99, 102, 241);
        style.weight = 600;
    }

    fn viewGraph(self: *Gallery, c: *ui.Context) void {
        const t = c.theme();
        if (self.board.id == 0) {
            self.board = ui.Graph.create(graph_doc, .{ .minimap = true, .snap_grid = 16 }) catch .{ .id = 0 };
            if (self.board.id != 0) {
                self.board.setContent(*Gallery, self, Gallery.graphNodeBody);
                self.board.onSelect(*Gallery, self, Gallery.graphSelect);
            }
        }
        {
            const row = c.row().fillWidth().gap(8).center().begin();
            defer row.end();
            if (c.button("g-add", "+ Node").clicked()) {
                var idb: [32]u8 = undefined;
                _ = self.board.addNode(.{
                    .title = "Card",
                    .x = 40,
                    .y = 120,
                    .w = 160,
                    .h = 90,
                    .ports = &.{
                        .{ .id = "in", .side = .left },
                        .{ .id = "out", .side = .right },
                    },
                }, idb[0..]) catch {};
            }
            if (c.button("g-layout", "Layout").clicked()) _ = self.board.layout();
            if (c.button("g-undo", "Undo").clicked()) _ = self.board.undo();
            if (c.button("g-redo", "Redo").clicked()) _ = self.board.redo();
            if (c.button("g-group", "Group").clicked()) _ = self.board.group();
            if (c.button("g-fit", "Fit").clicked()) _ = self.board.fit();
            if (c.button("g-save", "Copy JSON").clicked()) {
                if (self.board.exportJSON(std.heap.page_allocator)) |json| {
                    defer std.heap.page_allocator.free(json);
                    mygo.Clipboard.writeText(json);
                } else |_| {}
            }
            _ = c.textf("selected {d}", .{self.graph_sel_count}).fontSize(12).textColor(t.text_muted).grow(1.0);
        }
        _ = self.board.view(c, .{ .minimap = true, .snap_grid = 16 }).fill().grow(1.0);
    }

    fn graphNodeBody(self: *Gallery, c: *ui.Context, id: []const u8) void {
        _ = self;
        const t = c.theme();
        const box = c.column().gap(3).begin();
        defer box.end();
        _ = c.text(id).fontSize(12).bold();
        _ = c.text("Zig body").fontSize(11).textColor(t.text_muted);
    }

    fn graphSelect(self: *Gallery, json: []const u8) void {
        _ = json;
        self.graph_sel_count = self.board.selection(self.graph_sel_buf[0..], &self.graph_sel);
    }

    fn viewCharts(self: *Gallery, c: *ui.Context) void {
        const t = c.theme();
        _ = c.text("Charts · Draggable").fontSize(16).bold();

        _ = c.text("Line (monotone)").fontSize(13).bold().textColor(t.text_muted);
        _ = c.lineChart(&.{}, self.line_ys[0..], t.accent, 160, true).fillWidth();

        _ = c.text("Bars").fontSize(13).bold().textColor(t.text_muted);
        _ = c.barChart(self.bar_ys[0..], t.success, 140, true).fillWidth();

        _ = c.text("Area").fontSize(13).bold().textColor(t.text_muted);
        _ = c.areaChart(&.{}, self.line_ys[0..], t.warning, 140, true).fillWidth();

        {
            const row = c.row().fillWidth().gap(12).begin();
            defer row.end();
            {
                const col = c.column().grow(1.0).gap(6).begin();
                defer col.end();
                _ = c.text("Pie").fontSize(13).bold().textColor(t.text_muted);
                _ = c.pieChart(self.pie_vals[0..], &.{ t.accent, t.success, t.warning, t.danger }, 160, 0, 0.02).fillWidth();
            }
            {
                const col = c.column().grow(1.0).gap(6).begin();
                defer col.end();
                _ = c.text("Donut").fontSize(13).bold().textColor(t.text_muted);
                _ = c.pieChart(self.pie_vals[0..], &.{ t.accent, t.success, t.warning, t.danger }, 160, 0.45, 0.02).fillWidth();
            }
        }

        _ = c.text("Painter paths · gradients · canvas").fontSize(13).bold().textColor(t.text_muted);
        c.registerCanvas("chip", 64, 64);
        _ = c.box()
            .fillWidth()
            .height(160)
            .border(1, t.border)
            .radius(8)
            .draw(*Gallery, self, Gallery.paintPaths);

        // Element-level multi-stop / conic / radial fills
        {
            const stops = [_]ui.GradientStop{
                .{ .color = ui.Color.rgb(56, 189, 248), .at = 0 },
                .{ .color = ui.Color.rgb(167, 139, 250), .at = 0.5 },
                .{ .color = ui.Color.rgb(244, 63, 94), .at = 1 },
            };
            const row = c.row().fillWidth().gap(8);
            {
                const b = row.begin();
                defer b.end();
                _ = c.box().grow(1).height(48).radius(8).linearGradStops(90, false, &stops);
                _ = c.box().grow(1).height(48).radius(8).conicGradient(0, .{}, false, &stops);
                _ = c.box().grow(1).height(48).radius(8).radialGradient(0, .{}, false, &stops);
            }
        }

        _ = c.text("Draggable card (snap corners)").fontSize(13).bold().textColor(t.text_muted);
        {
            const stage = c.box().fillWidth().height(160).border(1, t.border).radius(8).begin();
            defer stage.end();
            const card = c.box()
                .absolute()
                .left(self.drag_x)
                .top(self.drag_y)
                .width(120)
                .height(72)
                .padding(10)
                .radius(8)
                .background(t.surface)
                .border(1, t.border)
                .draggable(&self.drag_x, &self.drag_y, .both, .{
                    .x = 0,
                    .y = 0,
                    .w = 280,
                    .h = 80,
                    .rigid = true,
                }, &.{ .{ 0, 0 }, .{ 160, 0 }, .{ 0, 80 }, .{ 160, 80 } });
            {
                const body = card.begin();
                defer body.end();
                _ = c.text("Drag me").bold();
                _ = c.textf("{d:.0},{d:.0}", .{ self.drag_x, self.drag_y }).fontSize(11).textColor(t.text_muted);
            }
        }
    }




    fn paintPaths(self: *Gallery, p: *ui.Painter, r: ui.Rect) void {
        _ = self;
        const stops = [_]ui.GradientStop{
            .{ .color = ui.Color.rgb(30, 41, 59), .at = 0 },
            .{ .color = ui.Color.rgb(15, 23, 42), .at = 1 },
        };
        p.fillLinearGradientStops(r.x, r.y, r.w, r.h, 8, 135, false, &stops);
        // Chevron via imperative path commands.
        const x0 = r.x + 24;
        const y0 = r.y + r.h * 0.5;
        p.pathBegin(.non_zero, .round, .round, 4);
        p.pathMoveTo(x0, y0 - 28);
        p.pathLineTo(x0 + 28, y0);
        p.pathLineTo(x0, y0 + 28);
        p.pathStroke(4, ui.Color.rgb(99, 102, 241));
        // Heart-ish cubic blob.
        const hx = r.x + r.w * 0.45;
        const hy = r.y + 28;
        p.pathBegin(.non_zero, .round, .round, 4);
        p.pathMoveTo(hx, hy + 20);
        p.pathCubicTo(hx - 36, hy - 10, hx - 10, hy - 36, hx, hy - 8);
        p.pathCubicTo(hx + 10, hy - 36, hx + 36, hy - 10, hx, hy + 20);
        p.pathClose();
        p.pathFillLinearGradient(200, ui.Color.rgb(244, 63, 94), ui.Color.rgb(251, 146, 60));
        // Star via SVG path `d` (translated into the element).
        var dbuf: [192]u8 = undefined;
        const d = std.fmt.bufPrint(&dbuf, "M {d:.1} {d:.1} L {d:.1} {d:.1} L {d:.1} {d:.1} L {d:.1} {d:.1} L {d:.1} {d:.1} L {d:.1} {d:.1} L {d:.1} {d:.1} L {d:.1} {d:.1} L {d:.1} {d:.1} L {d:.1} {d:.1} Z",
            .{
                r.x + r.w - 78, r.y + 18,
                r.x + r.w - 66, r.y + 42,
                r.x + r.w - 42, r.y + 42,
                r.x + r.w - 60, r.y + 58,
                r.x + r.w - 54, r.y + 82,
                r.x + r.w - 78, r.y + 68,
                r.x + r.w - 102, r.y + 82,
                r.x + r.w - 96, r.y + 58,
                r.x + r.w - 114, r.y + 42,
                r.x + r.w - 90, r.y + 42,
            }) catch "";
        if (d.len > 0) {
            p.pathSVG(d, ui.Color.rgb(250, 204, 21), 1.5, ui.Color.rgb(161, 98, 7));
        }
        p.text(r.x + r.w - 120, r.y + 12, "path + SVG", 12, ui.Color.rgb(100, 116, 139));
    
        // Offscreen canvas blit (registered once in viewCharts).
        p.canvasBegin("chip");
        p.fillRect(0, 0, 64, 64, ui.Color.rgb(15, 23, 42), 12);
        const chip_stops = [_]ui.GradientStop{
            .{ .color = ui.Color.rgb(56, 189, 248), .at = 0 },
            .{ .color = ui.Color.rgb(244, 63, 94), .at = 1 },
        };
        p.fillRadialGradient(4, 4, 56, 56, 28, 0, .{}, false, &chip_stops);
        p.canvasEnd();
        p.image("chip", r.x + r.w - 80, r.y + 12, 64, 64, .contain);
    }

    fn provideLazyMIME(self: *Gallery, buf: []u8) usize {
        // Fresh payload each drag start.
        var tmp: [64]u8 = undefined;
        const msg = std.fmt.bufPrint(&tmp, "lazy-{d}", .{self.toast_undos}) catch "lazy";
        return ui.Context.writeMIMETape(buf, &.{
            .{ "application/x-mygo-demo", msg },
            .{ "text/plain", msg },
        });
    }

    fn onRichToast(self: *Gallery) void {
        self.toast_undos += 1;
    }

    
    fn ensureStreamVideo(self: *Gallery, c: *ui.Context) void {
        if (self.stream_registered) return;
        c.openVideoStream("stream", 160, 90, 8, false);
        self.stream_registered = true;
        self.stream_tick = 0;
        self.pumpStream(c);
    }

    fn pumpStream(self: *Gallery, c: *ui.Context) void {
        if (!self.stream_registered) return;
        // Generate a simple sweeping RGBA frame each view pass.
        const w: u32 = 160;
        const h: u32 = 90;
        var pixels: [160 * 90 * 4]u8 = undefined;
        const tick = self.stream_tick;
        self.stream_tick +%= 1;
        var y: u32 = 0;
        while (y < h) : (y += 1) {
            var x: u32 = 0;
            while (x < w) : (x += 1) {
                const i = (y * w + x) * 4;
                const v: u8 = @truncate(x +% tick);
                pixels[i + 0] = v;
                pixels[i + 1] = @truncate(y *% 2);
                pixels[i + 2] = 200;
                pixels[i + 3] = 255;
            }
        }
        c.pushVideoFrame("stream", 33, pixels[0..]);
        c.after(16);
    }

    fn ensureFrameVideo(self: *Gallery, c: *ui.Context) void {
        if (self.frames_registered) return;
        // Tiny 16×16 bouncing square, 4 frames.
        const w: u32 = 16;
        const h: u32 = 16;
        var pixels: [16 * 16 * 4 * 4]u8 = @splat(0);
        const durs = [_]u32{ 120, 120, 120, 120 };
        var f: usize = 0;
        while (f < 4) : (f += 1) {
            const off = f * 16 * 16 * 4;
            const cx: i32 = 4 + @as(i32, @intCast(f)) * 2;
            const cy: i32 = 4 + @as(i32, @intCast(f % 2)) * 4;
            var y: i32 = 0;
            while (y < 16) : (y += 1) {
                var x: i32 = 0;
                while (x < 16) : (x += 1) {
                    const i = off + @as(usize, @intCast(y * 16 + x)) * 4;
                    const inside = x >= cx and x < cx + 6 and y >= cy and y < cy + 6;
                    if (inside) {
                        pixels[i] = 59;
                        pixels[i + 1] = 130;
                        pixels[i + 2] = 246;
                        pixels[i + 3] = 255;
                    } else {
                        pixels[i + 3] = 255;
                        pixels[i] = 20;
                        pixels[i + 1] = 20;
                        pixels[i + 2] = 30;
                    }
                }
            }
        }
        c.registerVideoFrames("frames", w, h, &durs, pixels[0..], true);
        self.frames_registered = true;
    }

    fn paintRichObject(self: *Gallery, p: *ui.Painter, at: i32, r: ui.Rect) void {
        _ = self;
        _ = at;
        p.fillRect(r.x, r.y, r.w, r.h, ui.Color.rgb(59, 130, 246), 6);
        p.fillRect(r.x + 2, r.y + 2, r.w - 4, r.h - 4, ui.Color.rgb(37, 99, 235), 4);
    }

    fn renderCustomToasts(self: *Gallery, c: *ui.Context, count: usize) void {
        const t = c.theme();
        // Current element is the viewport column; style it then build each toast.
        _ = (ui.Element{ .ctx = c }).padding(16).gap(8).alignItems(.end);
        var i: usize = 0;
        while (i < count) : (i += 1) {
            var info: ui.Context.ToastInfo = .{};
            const root = c.toastItem(@intCast(i), self.toast_info_buf[0..], &info)
                .row()
                .gap(10)
                .padding(10)
                .radius(10)
                .background(t.surface)
                .border(1, t.accent)
                .maxWidth(360);
            {
                const body = root.begin();
                defer body.end();
                {
                    const col = c.column().gap(2).grow(1.0).begin();
                    defer col.end();
                    _ = c.text(info.title).bold().fontSize(13);
                    if (info.description.len > 0) {
                        _ = c.text(info.description).fontSize(11).textColor(t.text_muted);
                    }
                    if (info.data.len > 0) {
                        _ = c.textf("data={s} ud={d}", .{ info.data, info.userdata }).fontSize(10).textColor(t.accent);
                    }
                }
                if (info.has_action) {
                    const action = c.toastActionButton().padding(6).radius(6).background(t.accent);
                    {
                        const a = action.begin();
                        defer a.end();
                        const label = if (info.action.len > 0) info.action else "Action";
                        _ = c.text(label).fontSize(12).textColor(t.accent_text);
                    }
                }
                const close = c.toastCloseButton().padding(6).radius(6);
                {
                    const b = close.begin();
                    defer b.end();
                    _ = c.text("×").fontSize(14);
                }
            }
        }
    }

    fn viewMore(self: *Gallery, c: *ui.Context) void {
        const t = c.theme();
        _ = c.text("Toolbar · Toasts · Dialogs · Tray · Notify · RichText").fontSize(16).bold();

        // Motion, masks, scroll-snap and file drops.
        {
            const row = c.row().fillWidth().gap(12).center().begin();
            defer row.end();
            _ = c.box().width(120).height(40).radius(8).background(t.accent)
                .transition(.{ .duration_ms = 180, .size = true, .colors = true });
            _ = c.textf("{d}", .{self.input_events}).fontSize(28).bold()
                .contentTransition(.{ .numeric = true, .morph = true });
            _ = c.box().width(120).height(40).radius(8)
                .linearGradient(90, t.accent, t.success, false)
                .maskLinearGradient(90, false, &.{
                    .{ .color = ui.Color.rgba(0, 0, 0, 255), .at = 0 },
                    .{ .color = ui.Color.rgba(0, 0, 0, 0), .at = 1 },
                });
            if (c.button("reveal", if (self.reveal) "Hide row 6" else "Reveal row 6").clicked()) {
                self.reveal = !self.reveal;
            }
            _ = c.checkboxState("tri", &self.check_state, "Select all");
            if (c.button("beep", "Beep").clicked()) self.beepNow();
            if (self.beep_ms > 0) {
                _ = c.textf("audio {d}ms", .{self.beep_ms}).fontSize(11).textColor(t.text_muted);
            }
        }

        {
            const row = c.row().fillWidth().gap(12).center().begin();
            defer row.end();
            const tl = (ui.Element{ .ctx = c }).timeline("intro", .{ .run = self.timeline_run });
            const x = tl.tween(.{ .from = -120, .to = 0, .duration_ms = 350 }, &.{});
            const card = c.box().width(120).height(44).radius(8).background(t.accent);
            _ = card.translate(x, 0.0);
            _ = card.masks(&.{
                .{ .image = .{ .linear = .{ .angle = 90, .stops = &.{
                    .{ .color = ui.Color.rgba(0, 0, 0, 255), .at = 0 },
                    .{ .color = ui.Color.rgba(0, 0, 0, 40), .at = 1 },
                } } } },
                .{ .image = .{ .radial = .{ .radius = 70, .center = .{ .x = 60, .y = 22 }, .stops = &.{
                    .{ .color = ui.Color.rgba(0, 0, 0, 255), .at = 0 },
                    .{ .color = ui.Color.rgba(0, 0, 0, 0), .at = 1 },
                } } }, .composite = .intersect, .box = .padding },
            });
            const inner = card.begin();
            defer inner.end();
            _ = c.text("timeline").fontSize(12).center().textColor(t.accent_text);

            if (c.button("replay", "Replay").clicked()) self.timeline_run +%= 1;
            _ = c.textInput("tk", self.tk_buf[0..], &self.tk_len)
                .width(140)
                .placeholder("F2 uppercases")
                .onTextKey(*Gallery, self, Gallery.onTextKey);
        }

        {
            const drop = c.box().fillWidth().height(52).radius(8)
                .border(1, t.border)
                .background(t.surface);
            self.drop_count = drop.droppedFiles(self.drop_buf[0..], &self.drop_names);
            const over = drop.fileDragOver();
            const body = drop.begin();
            defer body.end();
            if (self.drop_count > 0) {
                _ = c.textf("{d} file(s): {s}", .{ self.drop_count, self.drop_names[0] })
                    .fontSize(12).textColor(t.accent).center();
            } else {
                _ = c.text(if (over) "Drop files here" else "Drop files on this box").fontSize(12)
                    .textColor(t.text_muted).center();
            }
        }

        {
            const sc = c.scroll("fade-rows").fillWidth().height(74).scrollSnap(.mandatory);
            const body = sc.begin();
            defer body.end();
            const col = c.column().gap(6).begin();
            defer col.end();
            var i: usize = 0;
            while (i < 8) : (i += 1) {
                const item = c.box().fillWidth().height(30).radius(6).background(t.surface);
                if (self.reveal and i == 6) {
                    _ = item.scrollIntoView(.center, .nearest, true);
                }
                const b = item.begin();
                defer b.end();
                _ = c.textf("Row {d}", .{i}).fontSize(12);
            }
        }

                _ = c.box().fillWidth().height(36).radius(8).linearGradient(90, t.accent, t.success, false);

        _ = c.toolbar("tb", *Gallery, self, Gallery.toolbarBody).fillWidth();

        _ = c.findBar("find", &self.find_open, self.find_buf[0..], &self.find_len, 12, &self.find_current)
            .fillWidth();

        {
            const row = c.row().fillWidth().gap(10).center().begin();
            defer row.end();
            _ = c.editableText("name", self.edit_buf[0..], &self.edit_len).grow(1.0);
            if (c.button("toast", "Toast").clicked()) c.toast("Hello from Zig");
            if (c.button("undoable", "Delete…").clicked()) {
                c.toastAction("Item deleted", "Undo", *Gallery, self, Gallery.onToastUndo);
            }
            if (c.button("custom-toast-toggle", if (self.custom_toasts) "Default toasts" else "Custom toasts").clicked()) {
                self.custom_toasts = !self.custom_toasts;
            }
            if (c.button("rich-toast", "Toast+Data").clicked()) {
                const tid = c.addToast("Upload done", "report.pdf", "success", "id:42", "Open", 6000, 42, *Gallery, self, Gallery.onRichToast, self.toast_id_buf[0..]);
                self.last_toast_id_len = tid.len;
            }
            if (self.last_toast_id_len > 0) {
                if (c.button("close-toast", "Close toast").clicked()) {
                    c.closeToast(self.toast_id_buf[0..self.last_toast_id_len]);
                    self.last_toast_id_len = 0;
                }
            }
            if (c.button("dlg-msg", "Message…").clicked()) {
                const res = mygo.Dialog.message(c.window, .question, "Gallery", "Run the open dialog next?", "Dialog bindings", &.{ "Open", "Cancel" }) catch mygo.MessageResult{};
                if (res.button == 0) {
                    const filters = [_]mygo.FileFilter{
                        .{ .name = "Images", .extensions = "png,jpg,gif", .mime_types = "image/*" },
                        .{ .name = "Zig", .extensions = "zig" },
                        .{ .name = "All", .extensions = "*" },
                    };
                    if (mygo.Dialog.open(std.heap.page_allocator, c.window, "Open a file", "", &filters, 0)) |paths| {
                        defer std.heap.page_allocator.free(paths);
                        const n = @min(paths.len, self.dialog_buf.len);
                        @memcpy(self.dialog_buf[0..n], paths[0..n]);
                        self.dialog_len = n;
                    } else |_| {
                        self.dialog_len = 0;
                    }
                }
            }
            if (c.button("dlg-save", "Save…").clicked()) {
                const filters = [_]mygo.FileFilter{
                    .{ .name = "Text", .extensions = "txt" },
                    .{ .name = "Markdown", .extensions = "md" },
                };
                if (mygo.Dialog.save(std.heap.page_allocator, c.window, "Save as", "out.txt", &filters, mygo.DialogFlag.create_dirs)) |path| {
                    defer std.heap.page_allocator.free(path);
                    const n = @min(path.len, self.dialog_buf.len);
                    @memcpy(self.dialog_buf[0..n], path[0..n]);
                    self.dialog_len = n;
                } else |_| {
                    self.dialog_len = 0;
                }
            }
            if (self.dialog_len > 0) {
                _ = c.textf("dialog: {s}", .{self.dialog_buf[0..self.dialog_len]}).fontSize(11).textColor(t.text_muted);
            }

            if (c.button("show-locale", "Show locale").clicked()) {
                if (mygo.Locale.get(std.heap.page_allocator)) |loc| {
                    defer std.heap.page_allocator.free(loc);
                    const n = @min(loc.len, self.path_buf.len);
                    @memcpy(self.path_buf[0..n], loc[0..n]);
                    self.path_len = n;
                } else |_| {}
            }
            if (c.button("compile-rules", "Compile ad-block rules").clicked()) {
                const rules =
                    \\[{"trigger":{"url-filter":"ads\.example\.com"},"action":{"type":"block"}}]
                ;
                mygo.ContentRules.compile("ads", rules) catch {};
                if (self.web_win_id != 0) {
                    const win = mygo.Window{ .id = self.web_win_id };
                    const ids =
                        \\["ads"]
                    ;
                    win.setContentRulesJSON(ids) catch {};
                }
            }
            _ = c.box().height(48).fill().radius(12).glass(.{ .style = .regular, .clarity = 0.3 });
            _ = c.text("glass (Liquid Glass material)").fontSize(12).textColor(t.text_muted);
            if (c.button("pads-demo", "List gamepads").clicked()) {
                self.runPadsDemo();
            }
            if (c.button("apps-demo", "List installed apps").clicked()) {
                self.runAppsDemo();
            }
            if (c.button("fetch-demo", "HTTP GET example.com").clicked()) {
                self.runFetchDemo();
            }
            if (c.button("watch-demo", "Watch userData").clicked()) {
                self.startWatchDemo();
            }
            if (c.button("perm-check", "Check microphone").clicked()) {
                self.checkMic();
            }
            if (c.button("perm-settings", "Open Accessibility settings").clicked()) {
                mygo.PermissionFlow.openSettings("accessibility") catch {};
            }
            if (c.button("sqlite-demo", "SQLite insert+query").clicked()) {
                self.runSQLiteDemo();
            }
            if (c.button("win-chrome-demo", "Toggle always-on-top").clicked()) {
                const win = mygo.Window{ .id = self.main_win_id };
                win.setAlwaysOnTop(!win.isAlwaysOnTop());
            }
            if (c.button("app-name", "Show app name/version").clicked()) {
                if (mygo.Lifecycle.name(std.heap.page_allocator)) |n| {
                    defer std.heap.page_allocator.free(n);
                    const m = @min(n.len, self.path_buf.len);
                    @memcpy(self.path_buf[0..m], n[0..m]);
                    self.path_len = m;
                } else |_| {}
            }
            if (c.button("region-json", "Show region JSON").clicked()) {
                if (mygo.Lifecycle.regionJSON(std.heap.page_allocator)) |j| {
                    defer std.heap.page_allocator.free(j);
                    const m = @min(j.len, self.path_buf.len);
                    @memcpy(self.path_buf[0..m], j[0..m]);
                    self.path_len = m;
                } else |_| {}
            }
            if (c.button("capture-page", "Capture page PNG size").clicked()) {
                if (self.web_win_id != 0) {
                    const win = mygo.Window{ .id = self.web_win_id };
                    if (win.capturePagePNG(std.heap.page_allocator)) |png| {
                        defer std.heap.page_allocator.free(png);
                        var buf: [64]u8 = undefined;
                        const msg = std.fmt.bufPrint(&buf, "png={d}B", .{png.len}) catch "png";
                        const n = @min(msg.len, self.path_buf.len);
                        @memcpy(self.path_buf[0..n], msg[0..n]);
                        self.path_len = n;
                    } else |_| {}
                }
            }
            if (c.button("print-pdf", "Print page to PDF size").clicked()) {
                if (self.web_win_id != 0) {
                    const win = mygo.Window{ .id = self.web_win_id };
                    if (win.printToPDF(std.heap.page_allocator, .{ .background = true })) |pdf| {
                        defer std.heap.page_allocator.free(pdf);
                        var buf: [64]u8 = undefined;
                        const msg = std.fmt.bufPrint(&buf, "pdf={d}B", .{pdf.len}) catch "pdf";
                        const n = @min(msg.len, self.path_buf.len);
                        @memcpy(self.path_buf[0..n], msg[0..n]);
                        self.path_len = n;
                    } else |_| {}
                }
            }
            if (c.button("page-url", "Show page URL").clicked()) {
                if (self.web_win_id != 0) {
                    const win = mygo.Window{ .id = self.web_win_id };
                    if (win.pageURL(std.heap.page_allocator)) |u| {
                        defer std.heap.page_allocator.free(u);
                        const n = @min(u.len, self.path_buf.len);
                        @memcpy(self.path_buf[0..n], u[0..n]);
                        self.path_len = n;
                    } else |_| {}
                }
            }
            if (c.button("zoom-in", "Zoom in page").clicked()) {
                if (self.web_win_id != 0) {
                    const win = mygo.Window{ .id = self.web_win_id };
                    win.setZoomFactor(win.zoomFactor() * 1.1);
                }
            }
            if (c.button("toggle-devtools", "Toggle DevTools").clicked()) {
                if (self.web_win_id != 0) {
                    const win = mygo.Window{ .id = self.web_win_id };
                    win.toggleDevTools();
                }
            }
            if (c.button("toggle-mute", "Toggle page mute").clicked()) {
                if (self.web_win_id != 0) {
                    const win = mygo.Window{ .id = self.web_win_id };
                    win.setAudioMuted(!win.isAudioMuted());
                }
            }
            if (c.button("eval-title", "Eval document.title").clicked()) {
                if (self.web_win_id != 0) {
                    const win = mygo.Window{ .id = self.web_win_id };
                    if (win.evalJSON(std.heap.page_allocator, "document.title")) |json| {
                        defer std.heap.page_allocator.free(json);
                        const n = @min(json.len, self.path_buf.len);
                        @memcpy(self.path_buf[0..n], json[0..n]);
                        self.path_len = n;
                    } else |_| {}
                }
            }
            if (c.button("find-example", "Find Example in page win").clicked()) {
                if (self.web_win_id != 0) {
                    const win = mygo.Window{ .id = self.web_win_id };
                    if (win.findInPage("Example", .{ .find_next = true })) |res| {
                        var buf: [64]u8 = undefined;
                        const msg = std.fmt.bufPrint(&buf, "matches={d} active={d}", .{ res.matches, res.active }) catch "ok";
                        const n = @min(msg.len, self.path_buf.len);
                        @memcpy(self.path_buf[0..n], msg[0..n]);
                        self.path_len = n;
                    } else |_| {}
                }
            }
            if (c.button("open-at-login", "Toggle open at login").clicked()) {
                const cur = mygo.Lifecycle.openAtLogin();
                mygo.Lifecycle.setOpenAtLogin(!cur) catch {};
            }
            if (c.button("relaunch-app", "Relaunch app").clicked()) {
                mygo.Lifecycle.relaunch();
            }
            if (c.button("open-page-win", "Open page-events window").clicked()) {
                if (mygo.newWindow(.{ .title = "Page events", .url = "https://example.com", .width = 480, .height = 360 })) |w| {
                    self.web_win_id = w.id;
                    w.onPage(*Gallery, self, Gallery.onPageEvent);
                    w.setPermissionHandler(*Gallery, self, Gallery.onPermission);
                    w.setWindowOpenHandler(*Gallery, self, Gallery.onWindowOpen);
                    w.onContextMenu(*Gallery, self, Gallery.onContextMenu);
                    w.onPageMedia(*Gallery, self, Gallery.onPageMedia);
                } else |_| {}
            }
            if (c.button("clear-browsing", "Clear browsing data").clicked()) {
                mygo.Session.clearBrowsingData() catch {};
            }
            if (c.button("clear-cookies-sess", "Clear default cookies").clicked()) {
                mygo.Cookies.clear("") catch {};
            }
            if (c.button("cookie-list", "List cookies").clicked()) {
                if (mygo.Cookies.listJSON(std.heap.page_allocator, "{}")) |json| {
                    defer std.heap.page_allocator.free(json);
                    const n = @min(json.len, self.path_buf.len);
                    @memcpy(self.path_buf[0..n], json[0..n]);
                    self.path_len = n;
                } else |_| {}
            }
            if (c.button("secret-set", "Secret set demo").clicked()) {
                mygo.Secrets.set("", "gallery-zig-demo", "hello-from-zig") catch {};
            }
            if (c.button("secret-get", "Secret get").clicked()) {
                if (mygo.Secrets.get(std.heap.page_allocator, "", "gallery-zig-demo")) |v| {
                    defer std.heap.page_allocator.free(v);
                    const n = @min(v.len, self.path_buf.len);
                    @memcpy(self.path_buf[0..n], v[0..n]);
                    self.path_len = n;
                } else |_| {
                    const msg = "(missing or unsupported)";
                    @memcpy(self.path_buf[0..msg.len], msg);
                    self.path_len = msg.len;
                }
            }
            if (c.button("secret-del", "Secret delete").clicked()) {
                mygo.Secrets.delete("", "gallery-zig-demo") catch {};
            }
            if (c.button("clip-formats", "Clipboard formats").clicked()) {
                if (mygo.Clipboard.availableFormatsJSON(std.heap.page_allocator)) |json| {
                    defer std.heap.page_allocator.free(json);
                    const n = @min(json.len, self.path_buf.len);
                    @memcpy(self.path_buf[0..n], json[0..n]);
                    self.path_len = n;
                } else |_| {}
            }
            if (c.button("clip-image", "Copy tray PNG").clicked()) {
                mygo.Clipboard.writeImage(tray_png) catch {};
            }
            if (c.button("dock-hide", "Hide Dock icon").clicked()) {
                mygo.Desktop.hideDock();
            }
            if (c.button("dock-show", "Show Dock icon").clicked()) {
                mygo.Desktop.showDock();
            }
            if (c.button("recent-clear", "Clear recent docs").clicked()) {
                mygo.Desktop.clearRecentDocuments() catch {};
            }
            if (c.button("badge-set", "Badge 3").clicked()) {
                mygo.Lifecycle.setBadge("3");
            }
            if (c.button("badge-clear", "Clear badge").clicked()) {
                mygo.Lifecycle.setBadge("");
            }
            if (c.button("dock-bounce", "Bounce Dock").clicked()) {
                _ = mygo.Lifecycle.bounce(false);
            }

            if (c.button("about-show", "About…").clicked()) {
                mygo.Lifecycle.showAbout(.{ .name = "Gallery Zig", .version = "0.1.0", .credits = "Zig binding demo" });
            }
            _ = c.textf("app active={s} openURL={s}", .{
                if (self.app_active) "yes" else "no",
                if (self.open_url_len > 0) self.open_url_buf[0..self.open_url_len] else "-",
            }).fontSize(11).textColor(t.text_muted);

            if (c.button("theme-toggle", if (self.theme_dark) "Force light" else "Force dark").clicked()) {
                if (self.theme_dark) {
                    mygo.Appearance.setSource("light");
                } else {
                    mygo.Appearance.setSource("dark");
                }
                self.theme_dark = mygo.Appearance.isDark();
            }
            if (c.button("theme-system", "Theme system").clicked()) {
                mygo.Appearance.setSource("system");
                self.theme_dark = mygo.Appearance.isDark();
            }
            if (c.button("awake-toggle", if (self.awake_token != 0) "Allow sleep" else "Keep awake").clicked()) {
                if (self.awake_token != 0) {
                    mygo.Power.release(self.awake_token);
                    self.awake_token = 0;
                } else {
                    self.awake_token = mygo.Power.keepAwake("gallery-zig", false);
                }
            }
            _ = c.textf("theme dark={s} battery={s} idle={d}ms awake={s} power={s}", .{
                if (self.theme_dark) "yes" else "no",
                if (self.on_battery) "yes" else "no",
                self.idle_ms,
                if (self.awake_token != 0) "on" else "off",
                if (self.power_event_len > 0) self.power_event_buf[0..self.power_event_len] else "-",
            }).fontSize(11).textColor(t.text_muted);

            if (c.button("path-user", "Path userData").clicked()) {
                if (mygo.Path.get(std.heap.page_allocator, "userData")) |path| {
                    defer std.heap.page_allocator.free(path);
                    const n = @min(path.len, self.path_buf.len);
                    @memcpy(self.path_buf[0..n], path[0..n]);
                    self.path_len = n;
                } else |_| {}
                const pt = mygo.Screen.cursor();
                self.cursor_x = pt.x;
                self.cursor_y = pt.y;
            }
            if (self.path_len > 0) {
                _ = c.textf("userData={s}", .{self.path_buf[0..self.path_len]}).fontSize(11).textColor(t.text_muted);
            }
            _ = c.textf("cursor=({d},{d}) hotkey={d}", .{ self.cursor_x, self.cursor_y, self.hotkey_hits }).fontSize(11).textColor(t.text_muted);

            if (c.button("protect-toggle", "Toggle content protect").clicked()) {
                if (self.main_win_id != 0) {
                    const win = mygo.Window{ .id = self.main_win_id };
                    self.content_protect = !self.content_protect;
                    win.setContentProtection(self.content_protect);
                }
            }
            if (c.button("vib-toggle", if (self.win_vibrancy) "Clear vibrancy" else "Window glass").clicked()) {
                if (self.main_win_id != 0) {
                    const win = mygo.Window{ .id = self.main_win_id };
                    if (self.win_vibrancy) {
                        win.setVibrancy("");
                        self.win_vibrancy = false;
                    } else {
                        win.setVibrancy("glass");
                        self.win_vibrancy = true;
                    }
                }
            }
            if (c.button("progress-bump", "Progress +25%").clicked()) {
                if (self.main_win_id != 0) {
                    self.dock_progress = @min(1.0, self.dock_progress + 0.25);
                    const win = mygo.Window{ .id = self.main_win_id };
                    if (self.dock_progress >= 1.0) {
                        win.setProgressBar("", 0);
                        self.dock_progress = 0;
                    } else {
                        win.setProgressBar("normal", self.dock_progress);
                    }
                }
            }
            _ = c.textf("vibrancy={s} progress={d}% ctx={s} protect={s} titlebar h={d}", .{
                if (self.win_vibrancy) "glass" else "off",
                @as(u32, @intFromFloat(self.dock_progress * 100)),
                if (c.hasVibrancy()) "yes" else "no",
                if (self.content_protect) "on" else "off",
                @as(i32, @intFromFloat(c.titleBar().height)),
            }).fontSize(11).textColor(t.text_muted);

            if (self.notif_supported) {
                if (c.button("notif-show", "Notify…").clicked()) {
                    if (mygo.Notification.show(std.heap.page_allocator, .{
                        .id = "gallery-zig-demo",
                        .title = "Gallery Zig",
                        .subtitle = "Desktop notification",
                        .body = "Clicked from the Zig binding.",
                        .image = tray_png,
                        .click_cb = self.notif_click_cb,
                    })) |id| {
                        defer std.heap.page_allocator.free(id);
                        const n = @min(id.len, self.notif_id_buf.len);
                        @memcpy(self.notif_id_buf[0..n], id[0..n]);
                        self.notif_id_len = n;
                    } else |_| {}
                }
                if (self.notif_id_len > 0) {
                    if (c.button("notif-close", "Close notify").clicked()) {
                        mygo.Notification.close(self.notif_id_buf[0..self.notif_id_len]);
                    }
                    if (c.button("notif-clear", "Clear all").clicked()) {
                        mygo.Notification.clearAll();
                        self.notif_id_len = 0;
                    }
                    _ = c.textf("notif id={s} clicks={d}", .{ self.notif_id_buf[0..self.notif_id_len], self.notif_clicks }).fontSize(11).textColor(t.text_muted);
                }
            } else {
                _ = c.text("Notifications unsupported here").fontSize(11).textColor(t.text_muted);
            }

            if (c.button("flyout-open", if (self.flyout_id != 0) "Close flyout" else "Flyout…").clicked()) {
                if (self.flyout_id != 0) {
                    const w: mygo.Window = .{ .id = self.flyout_id };
                    w.close();
                    self.flyout_id = 0;
                } else {
                    self.openParentFlyout();
                }
            }

            if (c.button("tray-toggle", if (self.tray_id != 0) "Remove tray" else "Add tray").clicked()) {
                if (self.tray_id != 0) self.destroyTray() else self.ensureTray();
            }
            if (self.tray_id != 0) {
                _ = c.textf("tray id={d} clicks={d}", .{ self.tray_id, self.tray_clicks }).fontSize(11).textColor(t.text_muted);
                if (self.tray_menu_len > 0) {
                    _ = c.textf("tray menu: {s}", .{self.tray_menu_buf[0..self.tray_menu_len]}).fontSize(11).textColor(t.text_muted);
                }
            }

            if (c.button("motion", if (self.motion_on) "Reset motion" else "Animate").clicked()) {
                self.motion_on = !self.motion_on;
                self.motion_entered = false;
                c.invalidate();
            }
            _ = c.menuButton("file", "Menu", &menu_entries, self.menu_id_buf[0..], &self.menu_id_len);
        }



        // ARIA status — screen readers announce when the text changes.
        {
            const st = c.box().fillWidth().padding(10).radius(8).border(1, t.border).role(.status);
            {
                const b = st.begin();
                defer b.end();
                _ = c.textf("Status: undos={d} stream_tick={d}", .{ self.toast_undos, self.stream_tick }).fontSize(12);
            }
        }

        // Motion: AnimateTo + AnimatePose
        {
            const target: f32 = if (self.motion_on) 1.0 else 0.0;
            const card = c.box().fillWidth().padding(14).radius(12).border(1, t.border).background(t.surface);
            const op = card.animateTo("fade", target, .snappy, 0, 0, true, 0);
            _ = card.opacity(0.35 + 0.65 * op);
            var pose: ui.Pose = .{};
            if (!self.motion_entered) {
                pose = .{ .y = 12, .fade = 1 };
                self.motion_entered = true;
                c.invalidate();
            }
            _ = card.animatePose(pose, .snappy, 0, 0);
            {
                const body = card.begin();
                defer body.end();
                _ = c.textf("Motion op={d:.2} (AnimateTo fade + Pose enter)", .{op}).fontSize(13);
                const w = card.animate("w", if (self.motion_on) 220.0 else 80.0, 280);
                _ = c.box().width(w).height(8).radius(4).background(t.accent);
            }
        }

        // RichText with an inline object chip
        {
            const spans = [_]ui.Span{
                ui.Span.plain("Inline object: "),
                ui.Span.object(52, 18, 4),
                ui.Span.plain(" between words"),
            };
            _ = c.richText(&spans)
                .drawObjects(*Gallery, self, Gallery.paintRichObject)
                .fillWidth();
        }

        // Custom MIME drag / drop
        {
            const row = c.row().fillWidth().gap(10).center().begin();
            defer row.end();
            _ = c.badge("MIME drag")
                .padding(8)
                .radius(6)
                .dragMIME(&.{ .{ "application/x-mygo-demo", "zig-demo-v1" }, .{ "text/plain", "fallback text" } });
            _ = c.badge("Lazy MIME")
                .padding(8)
                .radius(6)
                .dragMIMELazy(&.{ "application/x-mygo-demo", "text/plain" }, *Gallery, self, Gallery.provideLazyMIME);
            const zone = c.box().padding(8).radius(6).border(1, t.border).grow(1.0);
            if (zone.dropMIME(&.{ "application/x-mygo-demo", "text/plain" }, self.mime_drop[0..], &self.mime_drop_len)) {}
            {
                const body = zone.begin();
                defer body.end();
                if (self.mime_drop_len > 0) {
                    _ = c.textf("{s}", .{self.mime_drop[0..self.mime_drop_len]}).fontSize(11);
                } else {
                    _ = c.text("Drop custom MIME here").fontSize(12).textColor(t.text_muted);
                }
            }
        }

        if (self.custom_toasts) {
            _ = c.toastViewport(*Gallery, self, Gallery.renderCustomToasts);
        }

        if (self.menu_id_len > 0) {
            _ = c.textf("menu chose {s}", .{self.menu_id_buf[0..self.menu_id_len]}).fontSize(12).textColor(t.text_muted);
        }
        if (self.toast_undos > 0) {
            _ = c.textf("toast undos={d}", .{self.toast_undos}).fontSize(12).textColor(t.text_muted);
        }

        // Side-by-side themed panels
        {
            const row = c.row().fillWidth().gap(12).begin();
            defer row.end();
            {
                var light = t;
                light.dark = false;
                light.background = ui.Color.rgb(250, 250, 252);
                light.surface = ui.Color.rgb(255, 255, 255);
                light.text = ui.Color.rgb(20, 20, 30);
                light.text_muted = ui.Color.rgb(100, 100, 120);
                light.border = ui.Color.rgb(210, 210, 220);
                light.accent = ui.Color.rgb(99, 102, 241);
                const panel = c.themed(light).grow(1.0).padding(12).gap(6).radius(8).begin();
                defer panel.end();
                _ = c.text("Light theme").bold();
                _ = c.primaryButton("l-ok", "OK");
            }
            {
                var dark = t;
                dark.dark = true;
                dark.background = ui.Color.rgb(24, 24, 28);
                dark.surface = ui.Color.rgb(36, 36, 42);
                dark.text = ui.Color.rgb(240, 240, 245);
                dark.text_muted = ui.Color.rgb(160, 160, 175);
                dark.border = ui.Color.rgb(60, 60, 70);
                dark.accent = ui.Color.rgb(129, 140, 248);
                const panel = c.themed(dark).grow(1.0).padding(12).gap(6).radius(8).begin();
                defer panel.end();
                _ = c.text("Dark theme").bold();
                _ = c.primaryButton("d-ok", "OK");
            }
        }

        _ = c.text("GridView (virtualized)").fontSize(13).bold().textColor(t.text_muted);
        _ = c.gridView("icons", 500, &self.grid_sel, 72, 72, *Gallery, self, Gallery.renderGridItem)
            .fillWidth()
            .grow(1.0)
            .border(1, t.border)
            .radius(8)
            .gap(8)
            .padding(8);
    }

    fn viewTree(self: *Gallery, c: *ui.Context) void {
        const t = c.theme();
        _ = c.text("Tree & TokenField").fontSize(16).bold();

        var current: [8][]const u8 = undefined;
        const n = @min(self.tag_count, current.len);
        for (0..n) |i| current[i] = self.tag_store[i][0..self.tag_lens[i]];
        _ = c.tokenField("tags", current[0..n], &fruits, self.tag_pack[0..], &self.tag_pack_len)
            .fillWidth()
            .label("Tags");
        if (self.tag_pack_len > 0) {
            var decoded: [8][]const u8 = undefined;
            const got = ui.readStrList(self.tag_pack[0..self.tag_pack_len], decoded[0..]);
            self.tag_count = got;
            for (0..got) |i| {
                const src = decoded[i];
                const m = @min(src.len, self.tag_store[i].len);
                @memcpy(self.tag_store[i][0..m], src[0..m]);
                self.tag_lens[i] = m;
            }
            _ = c.textf("{d} tags", .{got}).fontSize(12).textColor(t.text_muted);
        }

        _ = c.tree("files", *Gallery, self, Gallery.treeBody)
            .fillWidth()
            .grow(1.0)
            .border(1, t.border)
            .radius(8)
            .padding(8);
    }

    fn viewData(self: *Gallery, c: *ui.Context) void {
        const t = c.theme();
        _ = c.text("Virtualized List & Table").fontSize(16).bold();
        {
            const row = c.row().fillWidth().gap(8).begin();
            defer row.end();
            _ = c.textf("list sel={d}", .{self.list_sel}).fontSize(12).textColor(t.text_muted).grow(1.0);
            _ = c.textf("table sel={d}", .{self.table_sel}).fontSize(12).textColor(t.text_muted);
        }
        _ = c.list("rows", 10_000, &self.list_sel, *Gallery, self, Gallery.renderListRow)
            .fillWidth()
            .height(160)
            .border(1, t.border)
            .radius(8);
        _ = c.table("grid", &table_cols, 5_000, &self.table_sel, *Gallery, self, Gallery.renderTableCell)
            .fillWidth()
            .grow(1.0)
            .border(1, t.border)
            .radius(8);
    }

    fn viewMarkdown(self: *Gallery, c: *ui.Context) void {
        _ = self;
        _ = c.text("GFM Markdown (`zig/host/markdown`)").fontSize(16).bold();
        const scroll = c.scroll("md").fillWidth().grow(1.0).border(1, c.theme().border).radius(8).begin();
        defer scroll.end();
        _ = c.markdown(sample_md).fillWidth().padding(12);
    }

    





    fn runPadsDemo(self: *Gallery) void {
        const alloc = std.heap.page_allocator;
        const raw = mygo.Gamepad.padsJSON(alloc) catch {
            const msg = "pads: failed";
            @memcpy(self.path_buf[0..msg.len], msg);
            self.path_len = msg.len;
            return;
        };
        defer alloc.free(raw);
        const n = @min(raw.len, self.path_buf.len);
        @memcpy(self.path_buf[0..n], raw[0..n]);
        self.path_len = n;
    }

    fn runAppsDemo(self: *Gallery) void {
        const alloc = std.heap.page_allocator;
        const raw = mygo.Shell.installedAppsJSON(alloc) catch {
            const msg = "apps: failed";
            @memcpy(self.path_buf[0..msg.len], msg);
            self.path_len = msg.len;
            return;
        };
        defer alloc.free(raw);
        const n = @min(raw.len, self.path_buf.len);
        @memcpy(self.path_buf[0..n], raw[0..n]);
        self.path_len = n;
    }

    fn runFetchDemo(self: *Gallery) void {
        const alloc = std.heap.page_allocator;
        const raw = mygo.Fetch.request(alloc, "https://example.com", "GET", "[]", "", "follow") catch {
            const msg = "fetch: failed";
            @memcpy(self.path_buf[0..msg.len], msg);
            self.path_len = msg.len;
            return;
        };
        defer alloc.free(raw);
        const n = @min(raw.len, self.path_buf.len);
        @memcpy(self.path_buf[0..n], raw[0..n]);
        self.path_len = n;
    }

    fn startWatchDemo(self: *Gallery) void {
        if (self.watch_id != 0) {
            (mygo.Watch{ .id = self.watch_id }).close();
            self.watch_id = 0;
        }
        const alloc = std.heap.page_allocator;
        const dir = mygo.Path.get(alloc, "userData") catch {
            const msg = "watch: no userData";
            @memcpy(self.path_buf[0..msg.len], msg);
            self.path_len = msg.len;
            return;
        };
        defer alloc.free(dir);
        const w = mygo.Watch.start(dir, .{ .recursive = false, .hints_only = true }, *Gallery, self, onWatchEvent) catch {
            const msg = "watch: start failed";
            @memcpy(self.path_buf[0..msg.len], msg);
            self.path_len = msg.len;
            return;
        };
        self.watch_id = w.id;
        const msg = "watching userData…";
        @memcpy(self.path_buf[0..msg.len], msg);
        self.path_len = msg.len;
    }

    fn onWatchEvent(self: *Gallery, _: mygo.Watch, ev: mygo.Watch.Event) void {
        switch (ev) {
            .batch => |json| {
                const n = @min(json.len, self.path_buf.len);
                @memcpy(self.path_buf[0..n], json[0..n]);
                self.path_len = n;
            },
            .done => |msg| {
                self.watch_id = 0;
                if (msg.len == 0) {
                    const done = "watch: done";
                    @memcpy(self.path_buf[0..done.len], done);
                    self.path_len = done.len;
                } else {
                    const n = @min(msg.len, self.path_buf.len);
                    @memcpy(self.path_buf[0..n], msg[0..n]);
                    self.path_len = n;
                }
            },
        }
    }

    fn checkMic(self: *Gallery) void {
        const st = mygo.PermissionFlow.check("microphone") catch {
            const msg = "perm: check failed";
            @memcpy(self.path_buf[0..msg.len], msg);
            self.path_len = msg.len;
            return;
        };
        const label: []const u8 = switch (st) {
            .unknown => "microphone: unknown",
            .not_determined => "microphone: not determined",
            .denied => "microphone: denied",
            .granted => "microphone: granted",
        };
        @memcpy(self.path_buf[0..label.len], label);
        self.path_len = label.len;
    }

    fn runSQLiteDemo(self: *Gallery) void {
        const alloc = std.heap.page_allocator;
        const dir = mygo.Path.get(alloc, "userData") catch {
            const msg = "sqlite: no userData";
            @memcpy(self.path_buf[0..msg.len], msg);
            self.path_len = msg.len;
            return;
        };
        defer alloc.free(dir);
        var path_buf: [512]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, "{s}/gallery-zig-demo.db", .{dir}) catch {
            return;
        };
        if (self.sqlite_id != 0) {
            (mygo.SQLite{ .id = self.sqlite_id }).close();
            self.sqlite_id = 0;
        }
        const db = mygo.SQLite.open(path, false) catch {
            const msg = "sqlite: open failed";
            @memcpy(self.path_buf[0..msg.len], msg);
            self.path_len = msg.len;
            return;
        };
        self.sqlite_id = db.id;
        _ = db.execute(alloc, "CREATE TABLE IF NOT EXISTS notes (id INTEGER PRIMARY KEY, body TEXT)", "[]") catch {
            const msg = "sqlite: create failed";
            @memcpy(self.path_buf[0..msg.len], msg);
            self.path_len = msg.len;
            return;
        };
        _ = db.execute(alloc, "INSERT INTO notes(body) VALUES (?)", "[\"hello from zig\"]") catch {
            const msg = "sqlite: insert failed";
            @memcpy(self.path_buf[0..msg.len], msg);
            self.path_len = msg.len;
            return;
        };
        const rows = db.query(alloc, "SELECT id, body FROM notes ORDER BY id DESC LIMIT 3", "[]") catch {
            const msg = "sqlite: query failed";
            @memcpy(self.path_buf[0..msg.len], msg);
            self.path_len = msg.len;
            return;
        };
        defer alloc.free(rows);
        const n = @min(rows.len, self.path_buf.len);
        @memcpy(self.path_buf[0..n], rows[0..n]);
        self.path_len = n;
    }

    fn ensureTerm(self: *Gallery) void {
        if (self.term_id != 0) return;
        const term = mygo.Terminal.createWithEvents(.{}, *Gallery, self, onTermEvent) catch return;
        self.term_id = term.id;
    }

    fn onTermEvent(self: *Gallery, _: mygo.Terminal, ev: mygo.Terminal.Event) void {
        switch (ev) {
            .title => |title_text| {
                const n = @min(title_text.len, self.term_title_buf.len);
                @memcpy(self.term_title_buf[0..n], title_text[0..n]);
                self.term_title_len = n;
            },
            .exit => {
                self.term_id = 0;
                const msg = "(exited)";
                @memcpy(self.term_title_buf[0..msg.len], msg);
                self.term_title_len = msg.len;
            },
            .bell => {},
        }
    }

    fn viewTerm(self: *Gallery, c: *ui.Context) void {
        self.ensureTerm();
        const root = c.column().gap(8).padding(12).fill().begin();
        defer root.end();
        {
            const row = c.row().gap(8).fillWidth().begin();
            defer row.end();
            if (c.button("term-dark", "Dark theme").clicked()) {
                if (self.term_id != 0) (mygo.Terminal{ .id = self.term_id }).useDarkTheme();
            }
            if (c.button("term-light", "Light theme").clicked()) {
                if (self.term_id != 0) (mygo.Terminal{ .id = self.term_id }).useLightTheme();
            }
            if (c.button("term-paste", "Paste hello").clicked()) {
                if (self.term_id != 0) (mygo.Terminal{ .id = self.term_id }).paste("echo hello-from-zig\n");
            }
            if (c.button("term-clear", "Clear").clicked()) {
                if (self.term_id != 0) (mygo.Terminal{ .id = self.term_id }).clearScreen();
            }
            if (c.button("term-restart", "Restart").clicked()) {
                if (self.term_id != 0) {
                    (mygo.Terminal{ .id = self.term_id }).close();
                    self.term_id = 0;
                }
                self.ensureTerm();
            }
        }
        if (self.term_title_len > 0) {
            _ = c.text(self.term_title_buf[0..self.term_title_len]).fillWidth();
        } else {
            _ = c.text("Terminal (user shell) — needs zig/host/terminal").fillWidth();
        }
        if (self.term_id != 0) {
            _ = c.terminalView(.{ .id = self.term_id }).fill().grow(1.0);
        }
    }

    fn viewEditor(self: *Gallery, c: *ui.Context) void {
        const t = c.theme();
        {
            const row = c.row().fillWidth().gap(10).center().begin();
            defer row.end();
            _ = c.text("Code editor / diff (`zig/host/editor`)").fontSize(16).bold().grow(1.0);
            _ = c.checkbox("wrap", &self.soft_wrap, "Soft wrap");
            _ = c.checkbox("diff", &self.show_diff, "Diff view");
        }
        if (self.show_diff) {
            _ = c.diffView("demo.zig", sample_zig, true, self.soft_wrap)
                .fillWidth()
                .grow(1.0)
                .border(1, t.border)
                .radius(8);
        } else {
            _ = c.codeEditor("demo.zig", sample_zig, null, null, self.soft_wrap, &self.ed_stats)
                .fillWidth()
                .grow(1.0)
                .border(1, t.border)
                .radius(8);
        }
        _ = c.textf(
            "Ln {d}, Col {d} · {d} lines · +{d}/-{d} · modified={}",
            .{
                self.ed_stats.line,
                self.ed_stats.col,
                self.ed_stats.line_count,
                self.ed_stats.added,
                self.ed_stats.deleted,
                self.ed_stats.modified,
            },
        ).fontSize(12).textColor(t.text_muted);
    }

    fn view(self: *Gallery, c: *ui.Context) void {
        const t = c.theme();
        var root_el = c.column().fill().padding(16).gap(12);
        if (c.hasVibrancy()) {
            root_el = root_el.background(ui.Color.rgba(0, 0, 0, 0));
        }
        const root = root_el.begin();
        defer root.end();

        {
            const header = c.row().fillWidth().gap(12).center().begin();
            defer header.end();
            _ = c.text("Zig UI Gallery").fontSize(22).bold().grow(1.0);
            _ = c.badge("CGO_ENABLED=0").fontSize(11).textColor(t.accent);
        }

        _ = c.tabs("tabs", &self.tab, &tabs).fillWidth();

        switch (self.tab) {
            0 => self.viewControls(c),
            1 => self.viewInputs(c),
            2 => self.viewLayout(c),
            3 => self.viewData(c),
            4 => self.viewTree(c),
            5 => self.viewMore(c),
            6 => self.viewNav(c),
            7 => self.viewGraph(c),
            8 => self.viewCharts(c),
            9 => self.viewMarkdown(c),
            10 => self.viewEditor(c),
            11 => self.viewRich(c),
            else => self.viewTerm(c),
        }
    }
};

var app_state = Gallery{};

fn init() !void {
    mygo.setName("Gallery Zig");
}

fn onReady() void {
    mygo.Protocol.handle(*Gallery, &app_state, "galleryzig", Gallery.onProtocol) catch {};
    mygo.Desktop.setDockMenu(*Gallery, &app_state, &dock_menu_items, Gallery.onDockMenu) catch {};
    const jump_tasks =
        \\[{"title":"Open Gallery","args":["galleryzig://localhost/hello"]}]
    ;
    mygo.Desktop.setJumpListTasksJSON(jump_tasks) catch {};
    app_state.ensureTray();
    app_state.notif_supported = mygo.Notification.supported();
    app_state.notif_click_cb = mygo.Notification.registerClickHandler(*Gallery, &app_state, Gallery.onNotifClick);
    mygo.Notification.onAppClick(*Gallery, &app_state, Gallery.onNotifClick);
    mygo.Hotkey.register(*Gallery, &app_state, "CmdOrCtrl+Shift+G", Gallery.onHotkey) catch {};
    app_state.theme_dark = mygo.Appearance.isDark();
    app_state.on_battery = mygo.Power.isOnBattery();
    app_state.idle_ms = mygo.Power.idleMs();
    mygo.Appearance.onUpdated(*Gallery, &app_state, Gallery.onThemeUpdated);
    mygo.Power.onEvent(*Gallery, &app_state, Gallery.onPowerEvent);
    mygo.Lifecycle.onDidBecomeActive(*Gallery, &app_state, Gallery.onDidBecomeActive);
    mygo.Lifecycle.onDidResignActive(*Gallery, &app_state, Gallery.onDidResignActive);
    mygo.Lifecycle.onOpenURL(*Gallery, &app_state, Gallery.onOpenURL);
    mygo.setWindowStateStore(*Gallery, &app_state, Gallery.loadWindowStates, Gallery.saveWindowStates);
    const win = mygo.newWindowUi(*Gallery, &app_state, .{
        .title = "Zig UI Gallery",
        .width = 860,
        .height = 680,
        .state_key = "gallery-zig",
    }, Gallery.view) catch |err| {
        var buf: [256]u8 = undefined;
        std.debug.print("newWindowUi failed ({s}): {s}\n", .{ @errorName(err), mygo.lastError(&buf) });
        mygo.quit();
        return;
    };
    app_state.main_win_id = win.id;
    mygo.Locale.onChanged(*Gallery, &app_state, Gallery.onLocaleChanged);
    win.setAuthHandler(*Gallery, &app_state, Gallery.onAuthChallenge);
    win.setCertificateErrorHandler(*Gallery, &app_state, Gallery.onCertError);
    win.onDownload(*Gallery, &app_state, Gallery.onDownload);
}

comptime {
    mygo.exportApp(.{
        .init = init,
        .ready = onReady,
    });
}
