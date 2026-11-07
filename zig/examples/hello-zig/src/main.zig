const std = @import("std");
const builtin = @import("builtin");
const mygo = @import("mygo");

var counter: std.atomic.Value(i64) = .init(0);

const GreetResponse = struct {
    message: []const u8,
    zigVersion: []const u8,
    windowId: i32,
};

fn greet(ctx: mygo.CallContext, name: []const u8) !GreetResponse {
    const msg = try std.fmt.allocPrint(
        ctx.allocator,
        "Hello {s}, from Zig {s} + MyGo!",
        .{ name, builtin.zig_version_string },
    );
    return .{
        .message = msg,
        .zigVersion = builtin.zig_version_string,
        .windowId = ctx.window.id,
    };
}

fn add(ctx: mygo.CallContext, delta: i64) !i64 {
    const next = counter.fetchAdd(delta, .seq_cst) + delta;
    try ctx.window.emit("zig:count", .{ .count = next });
    return next;
}

fn autotestDone(_: mygo.CallContext, summary: []const u8) void {
    std.debug.print("[hello-zig] E2E verified: {s}\n", .{summary});
    mygo.quit();
}

fn isAutotest() bool {
    if (std.c.getenv("MYGO_AUTOTEST")) |v| {
        return std.mem.span(v).len > 0 and v[0] == '1';
    }
    return false;
}

fn onReady() void {
    const autotest = isAutotest();
    _ = mygo.newWindow(.{
        .title = "MyGo + Zig",
        .url = "/",
        .width = 520,
        .height = 360,
        .hidden = autotest,
    }) catch |err| {
        var buf: [256]u8 = undefined;
        std.debug.print("newWindow failed ({s}): {s}\n", .{ @errorName(err), mygo.lastError(&buf) });
        mygo.quit();
        return;
    };
}

pub fn main() !void {
    mygo.setName("Hello Zig");
    if (isAutotest()) {
        try mygo.addEmbeddedAsset("index.html", autotest_page);
    } else {
        try mygo.addEmbeddedAsset("index.html", interactive_page);
    }
    try mygo.bind("Greeter.greet", greet);
    try mygo.bind("Counter.add", add);
    try mygo.bind("Autotest.done", autotestDone);
    try mygo.run(onReady);
}

const interactive_page =
    \\<!doctype html>
    \\<html>
    \\<head>
    \\  <meta charset="utf-8">
    \\  <title>MyGo + Zig</title>
    \\  <style>
    \\    :root { color-scheme: light dark; font-family: system-ui, -apple-system, sans-serif; }
    \\    body { margin: 0; height: 100vh; display: grid; place-content: center; gap: 14px; text-align: center; }
    \\    .row { display: flex; gap: 8px; justify-content: center; }
    \\    input, button { font: inherit; padding: 8px 14px; border-radius: 8px; border: 1px solid #8884; }
    \\    button { cursor: pointer; font-weight: 600; }
    \\    #event-log { font-size: 13px; opacity: 0.75; }
    \\  </style>
    \\</head>
    \\<body>
    \\  <h2 id="greeting">Loading…</h2>
    \\  <div class="row">
    \\    <input id="name" value="Zigacean" />
    \\    <button id="btn-greet">Greet</button>
    \\    <button id="btn-inc">Count +1</button>
    \\  </div>
    \\  <div id="event-log">Events from Zig will appear here</div>
    \\  <script>
    \\    const greeting = document.getElementById("greeting");
    \\    const nameInput = document.getElementById("name");
    \\    const logEl = document.getElementById("event-log");
    \\
    \\    mygo.on("zig:count", (p) => {
    \\      logEl.textContent = `Zig emitted event zig:count → ${p.count}`;
    \\    });
    \\
    \\    async function refreshGreeting() {
    \\      const res = await mygo.call("Greeter.greet", nameInput.value);
    \\      greeting.textContent = res.message;
    \\    }
    \\
    \\    document.getElementById("btn-greet").onclick = refreshGreeting;
    \\    document.getElementById("btn-inc").onclick = () => mygo.call("Counter.add", 1);
    \\    refreshGreeting();
    \\  </script>
    \\</body>
    \\</html>
;

const autotest_page =
    \\<!doctype html>
    \\<html><body><script>
    \\  (async () => {
    \\    let eventCount = null;
    \\    const gotEvent = new Promise((resolve) => {
    \\      mygo.on("zig:count", (p) => resolve(p.count));
    \\    });
    \\    const g = await mygo.call("Greeter.greet", "World");
    \\    const c = await mygo.call("Counter.add", 7);
    \\    eventCount = await gotEvent;
    \\    await mygo.call("Autotest.done", `${g.message} | count=${c} | event=${eventCount}`);
    \\  })();
    \\</script></body></html>
;
