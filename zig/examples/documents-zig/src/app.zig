//! Bytes Documents demo: open/save/revert + edited state via Zig FFI.
const std = @import("std");
const mygo = @import("mygo");
const ui = mygo.ui;

const App = struct {
    doc_id: usize = 0,
    text_buf: [64 * 1024]u8 = undefined,
    text_len: usize = 0,
    status_buf: [256]u8 = undefined,
    status_len: usize = 0,

    fn setStatus(self: *App, msg: []const u8) void {
        const n = @min(msg.len, self.status_buf.len);
        @memcpy(self.status_buf[0..n], msg[0..n]);
        self.status_len = n;
    }

    fn syncFromDoc(self: *App) void {
        if (self.doc_id == 0) return;
        const alloc = std.heap.page_allocator;
        const bytes = mygo.Documents.content(alloc, self.doc_id) catch {
            self.setStatus("read failed");
            return;
        };
        defer alloc.free(bytes);
        const n = @min(bytes.len, self.text_buf.len);
        @memcpy(self.text_buf[0..n], bytes[0..n]);
        self.text_len = n;

        const st = mygo.Documents.stateJSON(alloc, self.doc_id) catch {
            self.setStatus("state failed");
            return;
        };
        defer alloc.free(st);
        self.setStatus(st);
    }

    fn pushToDoc(self: *App) void {
        if (self.doc_id == 0) return;
        mygo.Documents.setContent(self.doc_id, self.text_buf[0..self.text_len]) catch {
            self.setStatus("setContent failed");
            return;
        };
        mygo.Documents.changed(self.doc_id);
    }

    fn onDoc(self: *App, doc_id: usize, ev: mygo.Documents.Event) usize {
        switch (ev) {
            .need_window => {
                self.doc_id = doc_id;
                const win = mygo.newWindowUi(*App, self, .{
                    .title = "Documents Zig",
                    .width = 720,
                    .height = 520,
                }, App.view) catch return 0;
                return @intCast(win.id);
            },
            .state => |payload| {
                self.setStatus(payload);
                return 0;
            },
            .reload => {
                self.syncFromDoc();
                self.setStatus("reloaded");
                return 0;
            },
        }
    }

    fn view(self: *App, c: *ui.Context) void {
        const col = c.column().fill().padding(16).gap(10).begin();
        defer col.end();

        _ = c.text("Documents Zig").fontSize(20).bold();
        _ = c.text("Bytes Documents over FFI — New / Open / Save / Revert").fontSize(12);

        const bar = c.row().gap(8).begin();
        defer bar.end();
        if (c.button("new", "New").clicked()) {
            self.doc_id = mygo.Documents.new() catch 0;
            self.syncFromDoc();
        }
        if (c.button("open", "Open…").clicked()) {
            const alloc = std.heap.page_allocator;
            const raw = mygo.Documents.openDialogJSON(alloc) catch {
                self.setStatus("open dialog failed");
                return;
            };
            defer alloc.free(raw);
            var id: usize = 0;
            var i: usize = 0;
            while (i < raw.len) : (i += 1) {
                const ch = raw[i];
                if (ch >= '0' and ch <= '9') {
                    id = id * 10 + (ch - '0');
                } else if (id != 0) break;
            }
            if (id != 0) {
                self.doc_id = id;
                self.syncFromDoc();
            } else {
                self.setStatus(raw);
            }
        }
        if (c.button("save", "Save").clicked() and self.doc_id != 0) {
            self.pushToDoc();
            mygo.Documents.save(self.doc_id) catch {
                self.setStatus("save failed");
                return;
            };
            self.syncFromDoc();
        }
        if (c.button("revert", "Revert").clicked() and self.doc_id != 0) {
            mygo.Documents.revert(self.doc_id) catch {
                self.setStatus("revert failed");
                return;
            };
            self.syncFromDoc();
        }

        _ = c.text(self.status_buf[0..self.status_len]).fontSize(11);

        var len = self.text_len;
        if (c.textArea("body", self.text_buf[0..], &len).changed()) {
            self.text_len = len;
            self.pushToDoc();
        } else {
            self.text_len = len;
        }
    }
};

var g_app: App = .{};

fn init() !void {
    mygo.setName("Documents Zig");
    const types_json = "[{\"name\":\"Plain Text\",\"extensions\":[\"txt\"]}]";
    try mygo.Documents.configure(
        types_json,
        true, // AutosaveOff — Save is explicit
        true, // AskOnQuit
        true, // NoUntitled — we open one from ready
        0,
        *App,
        &g_app,
        App.onDoc,
    );
}

fn onReady() void {
    g_app.doc_id = mygo.Documents.new() catch 0;
    g_app.syncFromDoc();
}

comptime {
    mygo.exportApp(.{
        .init = init,
        .ready = onReady,
    });
}
