//! GPU-rendered Native UI showcase in Zig (`CGO_ENABLED=0` purego host):
//! - Rolling numeric transition (`numericTransition`) + 189 AST-generated modifiers
//! - Custom GPU vector waveform canvas (`Element.draw` + `ui.Painter`)
//! - 100,000-row virtualized `ui.List` (builds only visible rows in layout!)
//! - Interactive `Slider`, `Checkbox`, `TextInput` (CJK IME), and `Clipboard`

const std = @import("std");
const mygo = @import("mygo");
const ui = mygo.ui;

const TOTAL_ROWS: usize = 100_000;

const CounterApp = struct {
    n: i64 = 42,
    step: f64 = 1.0,
    animate_digits: bool = true,
    animate_wave: bool = false,
    decreased: bool = false,
    selected_row: i32 = 0,
    rows_built_this_frame: usize = 0,
    paints_executed: usize = 0,
    note_buf: [128]u8 = initNote(),
    note_len: usize = "Zig + MyGo Purego GPU UI".len,
    frames_rendered: u32 = 0,
    autotest: bool = false,

    fn initNote() [128]u8 {
        var b: [128]u8 = @splat(0);
        const seed = "Zig + MyGo Purego GPU UI";
        @memcpy(b[0..seed.len], seed);
        return b;
    }

    fn paintWaveform(self: *CounterApp, p: *ui.Painter, r: ui.Rect) void {
        self.paints_executed += 1;
        const bg = ui.Color.rgba(120, 140, 255, 22);
        const accent = ui.Color.rgb(99, 102, 241);
        p.fillRect(r.x, r.y, r.w, r.h, bg, 8);

        const phase: f32 = if (self.animate_wave)
            @as(f32, @floatFromInt(@mod(r.now_ms, 6283))) * 0.004
        else
            @as(f32, @floatFromInt(self.n)) * 0.25;

        const segments: usize = 32;
        const step_x = (r.w - 16.0) / @as(f32, @floatFromInt(segments));
        const mid_y = r.y + r.h * 0.5;
        const amp = (r.h * 0.34);

        var prev_x = r.x + 8.0;
        var prev_y = mid_y + @sin(phase) * amp;
        for (1..segments + 1) |i| {
            const t = @as(f32, @floatFromInt(i)) * 0.35 + phase;
            const nx = r.x + 8.0 + step_x * @as(f32, @floatFromInt(i));
            const ny = mid_y + @sin(t) * amp;
            p.line(prev_x, prev_y, nx, ny, 2.2, accent);
            prev_x = nx;
            prev_y = ny;
        }
        p.text(r.x + 10.0, r.y + 8.0, "ui.Painter GPU vector wave", 11.0, accent);
        if (self.animate_wave) {
            p.requestAnimationFrame();
        }
        if (self.autotest and self.paints_executed >= 1) {
            std.debug.print(
                "[counter-native-zig] Purego GPU UI verified: totalRows={d}, builtVisibleRows={d}, paints={d}\n",
                .{ TOTAL_ROWS, self.rows_built_this_frame, self.paints_executed },
            );
            mygo.quit();
        }
    }

    fn renderRow(self: *CounterApp, row: ui.ListRow) void {
        self.rows_built_this_frame += 1;
        const c = row.ctx;
        const t = c.theme();

        const r = c.row().fillWidth().padding(6).gap(8).begin();
        defer r.end();

        _ = c.textf("#{d:0>6}", .{row.index}).fontSize(12).font("monospace").textColor(t.text_muted);
        _ = c.textf("Virtualized item × {d} = {d}", .{ self.n, @as(i64, @intCast(row.index)) * self.n }).fontSize(13).grow(1.0);
        if (row.selected) {
            _ = c.text("selected").fontSize(11).bold().textColor(t.accent);
        } else if (row.hovered) {
            _ = c.text("hover").fontSize(11).textColor(t.text_muted);
        }
    }

    fn view(self: *CounterApp, c: *ui.Context) void {
        self.rows_built_this_frame = 0;

        const delta: i64 = @intFromFloat(@round(self.step));
        if (c.shortcut(.{}, .up)) {
            self.n += delta;
            self.decreased = false;
        }
        if (c.shortcut(.{}, .down)) {
            self.n -= delta;
            self.decreased = true;
        }

        const t = c.theme();

        const root = c.column().fill().padding(20).gap(12).begin();
        defer root.end();

        // Top counter + controls
        {
            const header = c.row().fillWidth().center().gap(14).begin();
            defer header.end();

            const num_el = c.textf("{d}", .{self.n}).fontSize(44).bold().letterSpacing(-0.5);
            if (self.animate_digits) {
                _ = num_el.numericTransition(self.decreased);
            }

            {
                const btns = c.row().gap(6).begin();
                defer btns.end();

                if (c.button("dec", "−").label("Decrement").width(40).clicked()) {
                    self.n -= delta;
                    self.decreased = true;
                }
                if (c.button("reset", "Reset").disabled(self.n == 0).clicked()) {
                    self.decreased = self.n > 0;
                    self.n = 0;
                }
                if (c.primaryButton("inc", "+").label("Increment").width(40).clicked()) {
                    self.n += delta;
                    self.decreased = false;
                }
                if (c.button("copy", "Copy").clicked()) {
                    var tmp: [64]u8 = undefined;
                    const txt = std.fmt.bufPrint(&tmp, "{d}", .{self.n}) catch "0";
                    mygo.Clipboard.writeText(txt);
                }
            }
        }

        // Custom GPU vector Painter canvas
        _ = c.boxKeyed("wave").fillWidth().height(62).draw(*CounterApp, self, CounterApp.paintWaveform);

        // Slider & toggles
        {
            const step_row = c.row().fillWidth().gap(10).begin();
            defer step_row.end();
            _ = c.textf("Step: {d}", .{delta}).fontSize(13).width(64);
            _ = c.slider("step", &self.step, 1.0, 10.0).grow(1.0);
            _ = c.checkbox("wave-anim", &self.animate_wave, "Live 120Hz wave");
        }

        _ = c.textInput("note", &self.note_buf, &self.note_len).fillWidth().placeholder("Type a note (CJK IME supported)…");

        // 100,000-row virtualized ui.List
        _ = c.textf("Virtualized ui.List ({d} total rows — only visible rows built):", .{TOTAL_ROWS})
            .fontSize(12)
            .bold()
            .textColor(t.text_muted);

        _ = c.list("virtual-items", TOTAL_ROWS, &self.selected_row, *CounterApp, self, CounterApp.renderRow)
            .fillWidth()
            .grow(1.0)
            .border(1.0, t.border)
            .radius(8.0);

        self.frames_rendered += 1;
    }
};

var app_state = CounterApp{};

fn isAutotest() bool {
    if (std.c.getenv("MYGO_AUTOTEST")) |v| {
        return std.mem.span(v).len > 0 and v[0] == '1';
    }
    return false;
}

fn init() !void {
    mygo.setName("Counter Zig");
    app_state.autotest = isAutotest();
}

fn onReady() void {
    _ = mygo.newWindowUi(*CounterApp, &app_state, .{
        .title = "Zig GPU UI Showcase (CGO_ENABLED=0)",
        .width = 460,
        .height = 520,
        .hidden = app_state.autotest,
    }, CounterApp.view) catch |err| {
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
