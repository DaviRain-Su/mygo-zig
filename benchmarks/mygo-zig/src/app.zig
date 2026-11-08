//! The Zig app of benchmarks/run: the same scenes as the Go, GPUI and egui
//! apps, written with the MyGo Zig SDK, timed on standard output.
//!
//! The runner sets BENCH_SCENE (counter, list, grid, document) and, for the
//! animated scenes, BENCH_WARMUP and BENCH_FRAMES.

const std = @import("std");
const mygo = @import("mygo");
const ui = mygo.ui;

/// nowUs reads a monotonic clock.
fn nowUs() i64 {
    var ts: std.c.timespec = undefined;
    _ = std.c.clock_gettime(.MONOTONIC, &ts);
    return @as(i64, @intCast(ts.sec)) * 1_000_000 + @divTrunc(@as(i64, @intCast(ts.nsec)), 1000);
}

fn say(comptime fmt: []const u8, args: anytype) void {
    var buf: [512]u8 = undefined;
    const s = std.fmt.bufPrint(&buf, fmt, args) catch return;
    mygo.printStdout(s);
}

fn envUsize(name: [:0]const u8, fallback: usize) usize {
    const v = mygo.environment(name) orelse return fallback;
    return std.fmt.parseInt(usize, v, 10) catch fallback;
}

// recorder times frames as the other apps do: a warmup, then frames whose
// intervals it reports, and asks for the next frame while the run wants one.
const Recorder = struct {
    warmup: usize = 120,
    frames: usize = 600,
    seen: usize = 0,
    last: i64 = 0,
    started: i64 = 0,
    at: i64 = 0,
    more: bool = true,
    intervals: [2000]i64 = undefined,
    n: usize = 0,

    fn init() Recorder {
        return .{
            .warmup = envUsize("BENCH_WARMUP", 120),
            .frames = envUsize("BENCH_FRAMES", 600),
        };
    }

    fn frame(self: *Recorder, c: *ui.Context) bool {
        // A frame can have several build passes: only the first of a frame
        // counts, as in the Go app (ui.Context.Now).
        const started = c.nowMs() != self.at;
        if (started) self.at = c.nowMs();
        const now = nowUs();
        if (started) self.tick(now);
        if (self.more) c.animationFrame();
        self.last = now;
        return started and self.more;
    }

    fn tick(self: *Recorder, now: i64) void {
        self.seen += 1;
        if (self.seen == self.warmup) {
            self.started = now;
            mygo.printStdout("start\n");
        } else if (self.seen > self.warmup and self.seen <= self.warmup + self.frames) {
            if (self.n < self.intervals.len) {
                self.intervals[self.n] = now - self.last;
                self.n += 1;
            }
            if (self.n == self.frames) {
                std.mem.sort(i64, self.intervals[0..self.n], {}, std.sort.asc(i64));
                const f = self.n;
                say("done {{\"frames\":{d},\"wallUs\":{d},\"p50Us\":{d},\"p99Us\":{d},\"maxUs\":{d}}}\n", .{
                    f,
                    now - self.started,
                    self.intervals[f / 2],
                    self.intervals[f * 99 / 100],
                    self.intervals[f - 1],
                });
            }
        }
        self.more = self.seen <= self.warmup + self.frames;
    }
};

const word_list = [_][]const u8{
    "window",  "button", "layout", "render",  "scroll", "update",   "shadow", "cursor",
    "memory",  "thread", "signal", "bitmap",  "stroke", "column",   "editor", "kernel",
    "packet",  "vector", "syntax", "buffer",  "format", "cipher",   "socket", "module",
    "branch",  "commit", "server", "client",  "screen", "pointer",  "display", "palette",
};

/// words makes the text of a seed, the same in every framework's app.
fn words(buf: []u8, seed: u32, n: usize) []const u8 {
    var x = seed;
    var at: usize = 0;
    var i: usize = 0;
    while (i < n) : (i += 1) {
        x = x *% 1103515245 +% 12345;
        const w = word_list[(x >> 16) % word_list.len];
        if (i > 0 and at < buf.len) {
            buf[at] = ' ';
            at += 1;
        }
        const take = @min(w.len, buf.len - at);
        @memcpy(buf[at..][0..take], w[0..take]);
        at += take;
    }
    return buf[0..at];
}

fn cellValue(cell: usize, frame: usize) f64 {
    return @floatFromInt((cell * 7919 + frame * 31) % 100_000);
}

fn cellColor(v: f64) ui.Color {
    if (v < 333) return ui.Color.rgb(0xf6, 0xc9, 0xc4);
    if (v < 666) return ui.Color.rgb(0xf4, 0xe8, 0xb8);
    return ui.Color.rgb(0xc6, 0xe9, 0xc8);
}

// counter: the smallest app, for starting and idling.
var counter_n: i64 = 0;

fn viewCounter(_: *App, c: *ui.Context) void {
    const col = c.column().fill().center().gap(16).begin();
    defer col.end();
    _ = c.textf("{d}", .{counter_n}).fontSize(56).bold();
    const row = c.row().gap(8).begin();
    defer row.end();
    if (c.button("decrement", "−").width(44).clicked()) counter_n -= 1;
    if (c.button("reset", "Reset").clicked()) counter_n = 0;
    if (c.button("increment", "+").width(44).clicked()) counter_n += 1;
}

// list: 100,000 rows of text, scrolling 8 DIPs a frame.
const ListState = struct {
    rec: Recorder = .{},
    scroll: ui.ScrollState = .{},
    selected: i32 = 0,
};

var list_state: ListState = .{};

fn viewList(_: *App, c: *ui.Context) void {
    if (list_state.rec.frame(c)) list_state.scroll.y += 8;
    const muted = c.theme().text_muted;
    _ = muted;
    _ = c.list("rows", 100_000, &list_state.selected, *ListState, &list_state, rowList)
        .fill();
}

fn rowList(_: *ListState, row: ui.ListRow) void {
    const c = row.ctx;
    const muted = c.theme().text_muted;
    const r = c.row().height(40).padding(12).gap(12).alignItems(.center).begin();
    defer r.end();
    const col = c.column().grow(1.0).begin();
    defer col.end();
    _ = c.textf("Item {d}", .{row.index}).fontSize(13).noWrap();
    var buf: [256]u8 = undefined;
    _ = c.text(words(&buf, @intCast(row.index + 1), 6)).fontSize(11).textColor(muted).noWrap();
    var vbuf: [32]u8 = undefined;
    const v = std.fmt.bufPrint(&vbuf, "{d:.2}", .{cellValue(@intCast(row.index), 0) / 100}) catch "";
    _ = c.text(v).fontSize(13).noWrap();
}

// grid: 600 cells of a live dashboard, each changing every frame.
var grid_state = struct {
    rec: Recorder = .{},
    frame: usize = 0,
}{};

fn viewGrid(_: *App, c: *ui.Context) void {
    if (grid_state.rec.frame(c)) grid_state.frame += 1;
    const col = c.column().fill().begin();
    defer col.end();
    var row_i: usize = 0;
    while (row_i < 30) : (row_i += 1) {
        const row = c.row().begin();
        defer row.end();
        var col_i: usize = 0;
        while (col_i < 20) : (col_i += 1) {
            const cell = row_i * 20 + col_i;
            const v = cellValue(cell, grid_state.frame) / 100;
            const box = c.box().size(40, 20).center().background(cellColor(v)).begin();
            defer box.end();
            var buf: [16]u8 = undefined;
            const s = std.fmt.bufPrint(&buf, "{d:.2}", .{v}) catch "";
            _ = c.text(s).fontSize(11).textColor(ui.Color.rgb(0x10, 0x10, 0x10)).noWrap();
        }
    }
}

// document: 40 paragraphs wrapping to a width that changes every frame.
var doc_state = struct {
    rec: Recorder = .{},
    frame: usize = 0,
    paragraphs: [40][420]u8 = undefined,
    lengths: [40]usize = undefined,
}{};

fn viewDocument(_: *App, c: *ui.Context) void {
    if (doc_state.rec.frame(c)) doc_state.frame += 1;
    const phase = @as(f32, @floatFromInt(doc_state.frame)) / 30;
    const width = @round(600 + 150 * @sin(phase));
    const sc = c.scroll("doc").fill().begin();
    defer sc.end();
    const col = c.column().width(width).gap(8).padding(12).begin();
    defer col.end();
    for (doc_state.paragraphs[0..], doc_state.lengths) |*p, n| {
        _ = c.text(p[0..n]).fontSize(13).wrap();
    }
}

const App = struct {};

var app: App = .{};
var scene: []const u8 = "counter";

fn onReadyToShow(_: mygo.Window) void {
    mygo.printStdout("ready\n");
}

fn onReady() void {
    scene = mygo.environment("BENCH_SCENE") orelse "counter";
    var created: ?mygo.Window = null;
    if (std.mem.eql(u8, scene, "counter")) {
        created = mygo.newWindowUi(*App, &app, .{
            .title = "Benchmark",
            .width = 360,
            .height = 260,
            .use_content_size = true,
        }, viewCounter) catch return;
    } else if (std.mem.eql(u8, scene, "list")) {
        list_state.rec = Recorder.init();
        created = mygo.newWindowUi(*App, &app, .{
            .title = "Benchmark",
            .width = 800,
            .height = 600,
            .use_content_size = true,
        }, viewList) catch return;
    } else if (std.mem.eql(u8, scene, "grid")) {
        grid_state.rec = Recorder.init();
        created = mygo.newWindowUi(*App, &app, .{
            .title = "Benchmark",
            .width = 800,
            .height = 600,
            .use_content_size = true,
        }, viewGrid) catch return;
    } else if (std.mem.eql(u8, scene, "document")) {
        doc_state.rec = Recorder.init();
        var i: usize = 0;
        while (i < 40) : (i += 1) {
            doc_state.lengths[i] = words(&doc_state.paragraphs[i], @intCast(i + 1), 70).len;
        }
        created = mygo.newWindowUi(*App, &app, .{
            .title = "Benchmark",
            .width = 800,
            .height = 600,
            .use_content_size = true,
        }, viewDocument) catch return;
    } else {
        mygo.printStdout("unknown scene\n");
        mygo.quit();
        return;
    }
    if (created) |w| w.onReadyToShow(onReadyToShow) catch {};
}

comptime {
    mygo.exportApp(.{ .ready = onReady });
}
