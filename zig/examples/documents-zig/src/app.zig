//! Documents demo, typed: `mygo.DocumentsOf(Note, …)` is NewDocuments[T] for
//! Zig. The controller reads and writes `Note` values; the wire stays bytes.
const std = @import("std");
const mygo = @import("mygo");
const ui = mygo.ui;

/// Note is the document content: a title line, then the body.
const Note = struct {
    title_buf: [64]u8 = @splat(0),
    title_len: usize = 0,
    body_buf: [64 * 1024]u8 = @splat(0),
    body_len: usize = 0,

    pub fn title(self: *const Note) []const u8 {
        return self.title_buf[0..self.title_len];
    }

    pub fn body(self: *const Note) []const u8 {
        return self.body_buf[0..self.body_len];
    }

    /// read parses a note: its first line is the title, the rest the body.
    pub fn read(bytes: []const u8) anyerror!Note {
        var note = Note{};
        const at = std.mem.indexOfScalar(u8, bytes, '\n') orelse bytes.len;
        const title_part = bytes[0..at];
        const body_part = if (at < bytes.len) bytes[at + 1 ..] else "";
        note.title_len = @min(title_part.len, note.title_buf.len);
        @memcpy(note.title_buf[0..note.title_len], title_part[0..note.title_len]);
        note.body_len = @min(body_part.len, note.body_buf.len);
        @memcpy(note.body_buf[0..note.body_len], body_part[0..note.body_len]);
        return note;
    }

    /// write encodes a note as its title line and body.
    pub fn write(_: std.mem.Allocator, note: Note, out: *std.ArrayList(u8)) anyerror!void {
        try out.appendSlice(std.heap.page_allocator, note.title());
        try out.append(std.heap.page_allocator, '\n');
        try out.appendSlice(std.heap.page_allocator, note.body());
    }
};

const Notes = mygo.DocumentsOf(Note, .{
    .types_json = "[{\"name\":\"Note\",\"extensions\":[\"note\"]}]",
    .autosave_off = true, // save explicitly
    .ask_on_quit = true,
    .new_content = Note{ .title_buf = initTitle("Untitled"), .title_len = 8 },
    .read = Note.read,
    .write = Note.write,
});

fn initTitle(comptime s: []const u8) [64]u8 {
    var buf: [64]u8 = @splat(0);
    @memcpy(buf[0..s.len], s);
    return buf;
}

const App = struct {
    doc: ?Notes.Document = null,
    editing: Note = .{},
    status_buf: [256]u8 = undefined,
    status_len: usize = 0,

    fn setStatus(self: *App, msg: []const u8) void {
        const n = @min(msg.len, self.status_buf.len);
        @memcpy(self.status_buf[0..n], msg[0..n]);
        self.status_len = n;
    }

    /// sync reads the document into the editor.
    fn sync(self: *App) void {
        const doc = self.doc orelse return;
        self.editing = doc.content(std.heap.page_allocator) catch {
            self.setStatus("read failed");
            return;
        };
        self.setStatus("loaded");
    }

    /// push writes the editor into the document, which marks it edited.
    fn push(self: *App) void {
        const doc = self.doc orelse return;
        doc.setContent(std.heap.page_allocator, self.editing) catch {
            self.setStatus("write failed");
            return;
        };
    }

    /// windowFor is the controller's window factory.
    fn windowFor(self: *App, doc: Notes.Document) mygo.Window {
        self.doc = doc;
        self.sync();
        const win = mygo.newWindowUi(*App, self, .{
            .title = "Documents Zig",
            .width = 720,
            .height = 520,
        }, App.view) catch return .{ .id = 0 };
        return win;
    }

    fn view(self: *App, c: *ui.Context) void {
        const col = c.column().fill().padding(16).gap(10).begin();
        defer col.end();

        _ = c.text("Documents Zig").fontSize(20).bold();
        _ = c.text("mygo.DocumentsOf(Note) — typed content over the byte wire").fontSize(12);

        const bar = c.row().gap(8).begin();
        defer bar.end();
        if (c.button("new", "New").clicked()) {
            self.doc = Notes.new() catch null;
            self.sync();
        }
        if (c.button("open", "Open…").clicked()) {
            const alloc = std.heap.page_allocator;
            if (Notes.openDialog(alloc)) |docs| {
                defer alloc.free(docs);
                if (docs.len > 0) {
                    self.doc = docs[0];
                    self.sync();
                }
            } else |_| {
                self.setStatus("open dialog failed");
            }
        }
        if (c.button("save", "Save").clicked()) {
            if (self.doc) |doc| {
                self.push();
                doc.save() catch {
                    self.setStatus("save failed");
                    return;
                };
                self.sync();
            }
        }
        if (c.button("revert", "Revert").clicked()) {
            if (self.doc) |doc| {
                doc.revert() catch {
                    self.setStatus("revert failed");
                    return;
                };
                self.sync();
            }
        }

        _ = c.text(self.status_buf[0..self.status_len]).fontSize(11);

        var len = self.editing.body_len;
        if (c.textArea("body", self.editing.body_buf[0..], &len).changed()) {
            self.editing.body_len = len;
            self.push();
        } else {
            self.editing.body_len = len;
        }
    }
};

var g_app: App = .{};

fn init() !void {
    mygo.setName("Documents Zig");
    try Notes.init(*App, &g_app, App.windowFor);
}

fn onReady() void {
    g_app.doc = Notes.new() catch null;
    g_app.sync();
}

comptime {
    mygo.exportApp(.{
        .init = init,
        .ready = onReady,
    });
}
