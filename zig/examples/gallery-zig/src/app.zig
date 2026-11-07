//! Zig gallery of MyGo Native UI widgets (Model A purego host).
//! Tabs: Controls · Inputs · Layout · Data · Markdown · Editor

const std = @import("std");
const mygo = @import("mygo");
const ui = mygo.ui;

const tabs = [_][]const u8{ "Controls", "Inputs", "Layout", "Data", "Tree", "More", "Nav", "Charts", "Markdown", "Editor" };
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
        _ = c.radio("plan", &self.radio, 0, "Free");
        _ = c.radio("plan", &self.radio, 1, "Pro");
        _ = c.radio("plan", &self.radio, 2, "Team");
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

        _ = c.searchField("search", self.search_buf[0..], &self.search_len).fillWidth().placeholder("Search…");
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

    fn onToastUndo(self: *Gallery) void {
        self.toast_undos += 1;
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

        if (std.mem.eql(u8, route.path, "/settings")) {
            _ = c.text("Settings page").fontSize(14);
        } else if (std.mem.eql(u8, route.path, "/about")) {
            _ = c.text("About MyGo × Zig").fontSize(14);
        } else {
            _ = c.text("Home page").fontSize(14);
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
        _ = c.text("Outline · Router · WebView · Native drag").fontSize(16).bold();

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
        }

        if (self.show_web) {
            _ = c.webView("docs", "https://mygo.egoist.dev").fillWidth().grow(1.0).border(1, t.border).radius(8);
        }
    }

    fn viewCharts(self: *Gallery, c: *ui.Context) void {
        const t = c.theme();
        _ = c.text("Charts · Draggable").fontSize(16).bold();

        _ = c.text("Line (monotone)").fontSize(13).bold().textColor(t.text_muted);
        _ = c.lineChart(&.{}, self.line_ys[0..], t.accent, 160, true).fillWidth();

        _ = c.text("Bars").fontSize(13).bold().textColor(t.text_muted);
        _ = c.barChart(self.bar_ys[0..], t.success, 140, true).fillWidth();

        _ = c.text("Draggable card (bounded)").fontSize(13).bold().textColor(t.text_muted);
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
                });
            {
                const body = card.begin();
                defer body.end();
                _ = c.text("Drag me").bold();
                _ = c.textf("{d:.0},{d:.0}", .{ self.drag_x, self.drag_y }).fontSize(11).textColor(t.text_muted);
            }
        }
    }

    fn viewMore(self: *Gallery, c: *ui.Context) void {
        const t = c.theme();
        _ = c.text("Toolbar · Grid · Icon · Themed · Find · Toast · Menu").fontSize(16).bold();

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
            _ = c.menuButton("file", "Menu", &menu_entries, self.menu_id_buf[0..], &self.menu_id_len);
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
        const root = c.column().fill().padding(16).gap(12).begin();
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
            7 => self.viewCharts(c),
            8 => self.viewMarkdown(c),
            else => self.viewEditor(c),
        }
    }
};

var app_state = Gallery{};

fn init() !void {
    mygo.setName("Gallery Zig");
}

fn onReady() void {
    _ = mygo.newWindowUi(*Gallery, &app_state, .{
        .title = "Zig UI Gallery",
        .width = 860,
        .height = 680,
    }, Gallery.view) catch |err| {
        var buf: [256]u8 = undefined;
        std.debug.print("newWindowUi failed ({s}): {s}\n", .{ @errorName(err), mygo.lastError(&buf) });
        mygo.quit();
    };
}

comptime {
    mygo.exportApp(.{
        .init = init,
        .ready = onReady,
    });
}
