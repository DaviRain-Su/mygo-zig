//! GPU-rendered Native UI counter in Zig (no WebView!), powered by MyGo's `ui`
//! CommandBuffer over C ABI.

const std = @import("std");
const mygo = @import("mygo");
const ui = mygo.ui;

const CounterApp = struct {
    n: i64 = 0,
    step: f64 = 1.0,
    animate_digits: bool = true,
    decreased: bool = false,
    note_buf: [128]u8 = initNote(),
    note_len: usize = "Zig + MyGo GPU UI".len,
    frames_rendered: u32 = 0,
    autotest: bool = false,

    fn initNote() [128]u8 {
        var b: [128]u8 = @splat(0);
        const seed = "Zig + MyGo GPU UI";
        @memcpy(b[0..seed.len], seed);
        return b;
    }

    fn view(self: *CounterApp, c: *ui.Context) void {
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

        const root = c.column().fill().center().padding(24).gap(14).begin();
        defer root.end();

        const num_el = c.textf("{d}", .{self.n}).fontSize(56).bold();
        if (self.animate_digits) {
            _ = num_el.numericTransition(self.decreased);
        }

        {
            const row = c.row().gap(8).begin();
            defer row.end();

            if (c.button("dec", "−").label("Decrement").width(44).clicked()) {
                self.n -= delta;
                self.decreased = true;
            }
            if (c.button("reset", "Reset").disabled(self.n == 0).clicked()) {
                self.decreased = self.n > 0;
                self.n = 0;
            }
            if (c.primaryButton("inc", "+").label("Increment").width(44).clicked()) {
                self.n += delta;
                self.decreased = false;
            }
            if (c.button("copy", "Copy").clicked()) {
                var tmp: [64]u8 = undefined;
                const txt = std.fmt.bufPrint(&tmp, "{d}", .{self.n}) catch "0";
                mygo.Clipboard.writeText(txt);
            }
        }

        {
            const step_row = c.row().gap(10).width(260).begin();
            defer step_row.end();
            _ = c.textf("Step: {d}", .{delta}).fontSize(13).width(64);
            _ = c.slider("step", &self.step, 1.0, 10.0).grow(1.0);
        }

        _ = c.checkbox("anim", &self.animate_digits, "Rolling numeric transition");
        _ = c.textInput("note", &self.note_buf, &self.note_len).width(260).placeholder("Type a note (IME supported)…");
        _ = c.text("↑ and ↓ count too · Zero WebView · GPU rendered").fontSize(12).textColor(t.text_muted);

        self.frames_rendered += 1;
        if (self.autotest and self.frames_rendered >= 1) {
            std.debug.print(
                "[counter-native-zig] GPU UI frame rendered: size={d:.0}x{d:.0}, dark={}, note=\"{s}\"\n",
                .{ c.width_dip, c.height_dip, t.dark, self.note_buf[0..self.note_len] },
            );
            mygo.quit();
        }
    }
};

var app_state = CounterApp{};

fn isAutotest() bool {
    if (std.c.getenv("MYGO_AUTOTEST")) |v| {
        return std.mem.span(v).len > 0 and v[0] == '1';
    }
    return false;
}

fn onReady() void {
    app_state.autotest = isAutotest();
    _ = mygo.newWindowUi(*CounterApp, &app_state, .{
        .title = "Counter (Zig Native GPU UI)",
        .width = 380,
        .height = 340,
        .hidden = app_state.autotest,
    }, CounterApp.view) catch |err| {
        var buf: [256]u8 = undefined;
        std.debug.print("newWindowUi failed ({s}): {s}\n", .{ @errorName(err), mygo.lastError(&buf) });
        mygo.quit();
    };
}

pub fn main() !void {
    mygo.setName("Counter Zig");
    try mygo.run(onReady);
}
