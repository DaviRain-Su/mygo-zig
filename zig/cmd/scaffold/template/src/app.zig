//! Minimal MyGo Native UI app in Zig (Model A purego host).

const std = @import("std");
const mygo = @import("mygo");
const ui = mygo.ui;

const App = struct {
    n: i64 = 0,

    fn view(self: *App, c: *ui.Context) void {
        const t = c.theme();
        const col = c.column().fill().padding(24).gap(12).center().begin();
        defer col.end();

        _ = c.text("{{NAME}}").fontSize(22).bold();
        _ = c.textf("count = {d}", .{self.n}).fontSize(18).textColor(t.accent);

        const row = c.row().gap(8).begin();
        defer row.end();
        if (c.button("dec", "−").clicked()) self.n -= 1;
        if (c.primaryButton("inc", "+").clicked()) self.n += 1;
        if (c.button("toast", "Toast").clicked()) c.toast("Hello from Zig");
    }
};

var app_state = App{};

fn init() !void {
    mygo.setName("{{NAME}}");
}

fn onReady() void {
    _ = mygo.newWindowUi(*App, &app_state, .{
        .title = "{{NAME}}",
        .width = 420,
        .height = 320,
    }, App.view) catch |err| {
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
