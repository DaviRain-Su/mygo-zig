//! SDK tests that need no host: the ABI's layout, the encodings the wire
//! carries, and the pure helpers the SDK builds them with.
//!
//!     zig test zig/sdk/tests.zig

const std = @import("std");
const mygo = @import("mygo.zig");
const abi = @import("abi.zig");
const ui = @import("ui.zig");

const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const expect = std.testing.expect;

const EffectState = struct { painted: usize = 0 };

fn paintEffect(_: *EffectState, _: *ui.Painter, _: ui.Rect, _: ui.Bitmap, _: ui.Point) void {}

// The Go side defines the same structs in zig/host/abi.go; a test there
// asserts the same numbers, so a change on either side fails.
test "ABI: ui and host agree on the event structs" {
    try expectEqual(@as(usize, 88), @sizeOf(abi.Input));
    try expectEqual(@as(usize, 24), @sizeOf(abi.Hit));
    try expectEqual(@as(usize, 40), @sizeOf(abi.EffectPaint));
    try expectEqual(@as(usize, 48), @sizeOf(abi.TextKey));
    try expectEqual(@as(usize, 104), @sizeOf(abi.TextClientReq));
    try expectEqual(@as(usize, 28), @sizeOf(abi.SpanStyle));

    // The pointers come last, so the scalars stay where the host writes them.
    try expectEqual(@as(usize, 48), @offsetOf(abi.Input, "x"));
    try expectEqual(@as(usize, 72), @offsetOf(abi.Input, "text_ptr"));
    try expectEqual(@as(usize, 32), @offsetOf(abi.EffectPaint, "bitmap"));
    try expectEqual(@as(usize, 8), @offsetOf(abi.TextKey, "text_ptr"));
    try expectEqual(@as(usize, 32), @offsetOf(abi.TextClientReq, "x"));
}

test "ABI: the query struct the host writes" {
    // cUIQuery in zig/host/ui/ui.go: u8 + pad, two f64, i64, three uintptr,
    // then the rect and span fields this session added.
    try expectEqual(@as(usize, 8), @offsetOf(ui.CQuery, "num_val"));
    try expectEqual(@as(usize, 24), @offsetOf(ui.CQuery, "int_val"));
    try expectEqual(@as(usize, 32), @offsetOf(ui.CQuery, "text_buf_ptr"));
    try expectEqual(@as(usize, 48), @offsetOf(ui.CQuery, "text_len"));
    try expectEqual(@as(usize, 56), @offsetOf(ui.CQuery, "num_val3"));
    try expectEqual(@as(usize, 72), @offsetOf(ui.CQuery, "int_val2"));
    try expectEqual(@as(usize, 80), @sizeOf(ui.CQuery));
}

test "menuJSON: fields, escaping, icons and nesting" {
    const alloc = std.testing.allocator;
    const icon = [_]u8{ 0x89, 'P', 'N', 'G' };
    const items = [_]mygo.MenuItem{
        .{
            .id = "open",
            .label = "Open \"recent\"\nfile",
            .accelerator = "CmdOrCtrl+O",
            .tooltip = "Open a file",
            .subtitle = "⌘O",
            .icon_png = &icon,
            .icon_template = true,
            .submenu = &.{
                .{ .id = "recent", .label = "Recent" },
            },
        },
        .{ .kind = .separator },
        .{ .id = "check", .label = "Show", .kind = .checkbox, .checked = true, .disabled = true },
        .{ .id = "quit", .label = "Quit", .role = "quit", .hidden = true },
    };
    const json = try mygo.menuJSON(alloc, &items);
    defer alloc.free(json);

    const parsed = try std.json.parseFromSlice(std.json.Value, alloc, json, .{});
    defer parsed.deinit();
    const list = parsed.value.array;
    try expectEqual(@as(usize, 4), list.items.len);

    const open = list.items[0].object;
    try expectEqualStrings("Open \"recent\"\nfile", open.get("label").?.string);
    try expectEqualStrings("Open a file", open.get("tooltip").?.string);
    try expectEqualStrings("⌘O", open.get("subtitle").?.string);
    try expectEqualStrings("CmdOrCtrl+O", open.get("accelerator").?.string);
    try expect(open.get("iconTemplate").?.bool);
    // base64 of 0x89 'P' 'N' 'G'
    try expectEqualStrings("iVBORw==", open.get("iconPng").?.string);
    try expectEqual(@as(usize, 1), open.get("submenu").?.array.items.len);

    try expectEqualStrings("separator", list.items[1].object.get("type").?.string);
    const check = list.items[2].object;
    try expectEqualStrings("checkbox", check.get("type").?.string);
    try expect(check.get("checked").?.bool);
    try expect(check.get("disabled").?.bool);
    try expect(list.items[3].object.get("hidden").?.bool);
    // `role` alone is enough: no accelerator, no submenu, no click.
    try expectEqualStrings("quit", list.items[3].object.get("role").?.string);
}

test "menuJSON: an empty menu is an empty array" {
    const alloc = std.testing.allocator;
    const json = try mygo.menuJSON(alloc, &.{});
    defer alloc.free(json);
    try expectEqualStrings("[]", json);
}

test "readStrList: the u16/u32 layout the host writes" {
    var buf: [64]u8 = undefined;
    var at: usize = 0;
    std.mem.writeInt(u16, buf[0..2], 2, .little);
    at = 2;
    for ([_][]const u8{ "one", "two" }) |s| {
        std.mem.writeInt(u32, buf[at..][0..4], @intCast(s.len), .little);
        at += 4;
        @memcpy(buf[at..][0..s.len], s);
        at += s.len;
    }
    var out: [4][]const u8 = @splat("");
    const n = ui.readStrList(buf[0..at], &out);
    try expectEqual(@as(usize, 2), n);
    try expectEqualStrings("one", out[0]);
    try expectEqualStrings("two", out[1]);

    // A truncated list reads as far as it can.
    try expectEqual(@as(usize, 1), ui.readStrList(buf[0 .. at - 3], &out));
    try expectEqual(@as(usize, 0), ui.readStrList(buf[0..1], &out));
}

test "inputEvent: the host's fields become an InputEvent" {
    var c = abi.Input{
        .kind = @intFromEnum(ui.InputKind.key_down),
        .key = @intFromEnum(ui.Key.enter),
        .physical_key = @intFromEnum(ui.Key.enter),
        .code = 40,
        .mods = @as(u8, @bitCast(ui.Modifiers{ .shift = true, .super = true })),
        .flags = 1 | 2, // repeat, canceled
        .caret = 3,
        .x = 1.5,
        .y = 2.5,
        .button = @bitCast(@as(i32, 1)),
        .clicks = 2,
        .pointer = @intFromEnum(ui.PointerType.pen),
        .pressure = 0.7,
        .dx = 4,
        .dy = -4,
        .scale = 1.25,
        .start = 5,
        .end = 8,
    };
    const text = "hi";
    c.text_ptr = @intFromPtr(text.ptr);
    c.text_len = text.len;

    const ev = ui.inputEvent(&c);
    try expectEqual(ui.InputKind.key_down, ev.kind);
    try expectEqual(ui.Key.enter, ev.key);
    try expectEqual(@as(u16, 40), ev.code);
    try expect(ev.mods.shift and ev.mods.super and !ev.mods.ctrl);
    try expect(ev.repeat and ev.canceled);
    try expectEqualStrings("hi", ev.text);
    try expectEqual(@as(i32, 3), ev.caret);
    try expectEqual(@as(f32, 1.5), ev.x);
    try expectEqual(@as(i32, 1), ev.button);
    try expectEqual(@as(i32, 2), ev.clicks);
    try expectEqual(ui.PointerType.pen, ev.pointer);
    try expectEqual(@as(f32, 0.7), ev.pressure);
    try expectEqual(@as(f32, 4), ev.dx);
    try expectEqual(@as(f32, 1.25), ev.scale);
    try expectEqual(@as(i32, 5), ev.start);
    try expectEqual(@as(i32, 8), ev.end);
}

test "textKey: replace writes into the host buffer" {
    var out: [16]u8 = undefined;
    var c = abi.TextKey{
        .key = @intFromEnum(ui.Key.f2),
        .out_ptr = @intFromPtr(&out),
        .out_cap = out.len,
    };
    const text = "abc";
    c.text_ptr = @intFromPtr(text.ptr);
    c.text_len = text.len;

    var k = ui.textKey(&c);
    try expectEqual(ui.Key.f2, k.key);
    try expectEqualStrings("abc", k.text);

    k.replace("xyz");
    try expectEqual(@as(usize, 3), k.out_len);
    try expectEqualStrings("xyz", out[0..3]);

    // Too long for the buffer is clipped, not overrun.
    var small: [2]u8 = undefined;
    var c2 = abi.TextKey{ .out_ptr = @intFromPtr(&small), .out_cap = small.len };
    var k2 = ui.textKey(&c2);
    k2.replace("toolong");
    try expectEqual(@as(usize, 2), k2.out_len);
    try expectEqualStrings("to", small[0..2]);
}

test "Transform: ops compose in order and stop at the buffer" {
    var t = ui.Transform{};
    t = t.translate(1, 2);
    t = t.rotate(90);
    t = t.scale(2, 3);
    try expectEqual(@as(u8, 3), t.len);
    try expectEqual(@as(f32, 1), t.ops[0].translate[0]);
    try expectEqual(@as(f32, 90), t.ops[1].rotate);
    try expectEqual(@as(f32, 3), t.ops[2].scale[1]);

    var full = ui.Transform{};
    var i: usize = 0;
    while (i < 20) : (i += 1) full = full.translate(@floatFromInt(i), 0);
    try expectEqual(@as(u8, full.ops.len), full.len);
}

test "Effect: margin and ids survive effectOf" {
    var state = EffectState{};
    const fx = ui.effectOf(*EffectState, &state, .{ .x = 6, .y = 7 }, paintEffect);
    try expectEqual(@as(f32, 6), fx.margin.x);
    try expectEqual(@as(f32, 7), fx.margin.y);
    try expect(fx.cb_id > 0);
    try expectEqual(@intFromPtr(&state), fx.ud);
}
