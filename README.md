# MyZig

**Desktop apps in Zig: native GPU user interfaces, or a web view, with no cgo.**

MyZig is the Zig face of [MyGo](https://github.com/egoist/mygo). An app is
written in Zig; a six-line Go shim starts it. MyGo draws the native interface
on the GPU from a command buffer Zig records, or shows a web page in the
system's own webview, with a TypeScript client generated from your types.

```zig
// src/app.zig
const mygo = @import("mygo");
const ui = mygo.ui;

const App = struct {
    n: i32 = 0,

    fn view(self: *App, c: *ui.Context) void {
        const root = c.column().fill().center().gap(12).begin();
        defer root.end();
        _ = c.textf("{d}", .{self.n}).fontSize(40).bold();
        if (c.primaryButton("inc", "Increment").clicked()) self.n += 1;
    }
};

var app: App = .{};

fn ready() void {
    _ = mygo.newWindowUi(*App, &app, .{ .title = "Counter", .width = 320, .height = 200 }, App.view) catch {};
}

comptime {
    mygo.exportApp(.{ .ready = ready });
}
```

```go
// main.go — the whole Go side
package main

import (
	"github.com/egoist/mygo/zig/host"
	_ "github.com/egoist/mygo/zig/host/ui"
)

func main() { host.Main("counter") }
```

```sh
go run ./zig/cmd/scaffold myapp      # a new app, with build.zig and main.go
go run ./zig/cmd/build myapp         # zig build, then mygo build: .app / .dmg / .deb / .exe
```

## Why

- **No cgo, ever.** The Go host calls into your Zig `cdylib` through
  [purego](https://github.com/ebitengine/purego), and Zig calls back through a
  single exported symbol. `CGO_ENABLED=0` on macOS, Linux, Windows, `amd64` and
  `arm64`: cross-compile from any of them.
- **Native UI is a command buffer, not a DOM.** Zig records widgets and
  modifiers into a buffer; the host replays it into MyGo's `package ui`, which
  lays out, animates and draws it on the GPU. No HTML, no JavaScript, no
  webview process: a window opens at once and takes a fraction of the memory.
- **Pay for what you use.** `zig/host` alone is a webview app and links none of
  `package ui`. Rich text, charts, terminal, SQLite, video and the node canvas
  are separate opt-in packages. Pure-Go MyGo apps keep their binary size:
  `examples/hello` and `examples/counter-native` measure **+0 bytes** on every
  push.
- **One app, both interfaces.** A window can show a page and another native UI;
  native UI can embed a first-class `WebView`, and pages get typed IPC and
  events generated from Zig declarations.

## What you get

| | |
|---|---|
| **Windows** | webview or native UI, menus and context menus, tray, flyout, dialogs, notifications, vibrancy, title bar, window state, panels |
| **Native UI** | 297 Element methods: flex and grid layout, 40+ widgets, virtualized lists and tables, outline, tree, grid view, text editing with input methods, drag and drop, motion, timelines, transitions, masks, transforms, effects |
| **Drawing** | `Painter` paths, gradients, SDF shapes, masks, bitmaps, canvases, fonts, SVG icons, and `ui.Effect` (the element renders to a bitmap, Zig paints it) |
| **Rich media** | GIF, APNG, pushed frames, streams, native video through the system's framework (AVFoundation, Media Foundation, GStreamer), and audio with mixing |
| **Documents** | `DocumentsOf(T)`: typed content, autosave, save prompts, revert, rename, duplicate, per-document windows; rich text with Markdown, HTML, JSON and RTF |
| **Canvas** | `ui.Graph`: an infinite board of nodes, ports and edges, with Zig building each node's body and callbacks for selection, connect, move and delete |
| **Platform** | clipboard with rich MIME, secrets (Keychain / libsecret / CredMan), cookies, sessions, locale, content rules, custom protocols, deep links, global hotkeys, screens, power, file watchers, updater |
| **Data** | HTTP with the system proxy, WebSocket, SQLite, file watch, single-instance, shell and installed apps |
| **Tooling** | `mygo dev` with live reload, `mygo generate` for the TypeScript client, `mygo build` for `.app` / `.dmg` / `.deb` / NSIS, and a scaffold that sets all of it up |

## How it works

```
your app (Zig + Zig std)
    │  one exported symbol: mygo_zig_entry(kind, a0…a3)
    ▼
zig/sdk          mygo.zig, ui.zig, element_gen.zig — the whole API
    │  one callback: host_dispatch(op, a0…a3)
    ▼
zig/host         purego, CGO_ENABLED=0, no package ui unless imported
    │
    ▼
MyGo core        windows, platform backends, package ui (GPU renderer)
```

- **The wire is a command buffer.** A view writes opcodes into a per-frame
  buffer: `column`, `text`, `button`, `padding`, `clicked`, `video`, … The host
  reads them, builds the same widget tree a Go app would, and answers the
  queries (`clicked`, `focused`, `bounds`) in the same tape.
- **Callbacks are scarce and fixed.** One `purego` callback per signature,
  created at startup, routed by id: views, list rows, table cells, painters,
  input handlers, effects, menus. Zig never allocates one per window.
- **The ABI is flat.** Strings are pointer + length, colors are `u32`, values
  travel in a small query struct. `zig/sdk/abi.zig` and `zig/host/abi.go`
  mirror each other.

## Opt-in host packages

Each adds a capability and its opcodes; an app that does not import it links
none of it.

| Package | Adds |
| --- | --- |
| `zig/host/ui` | Native UI (`package ui`), lists, tables, painter |
| `zig/host/markdown` | GFM Markdown view and stream |
| `zig/host/editor` | syntax-highlighted code editor and diff view |
| `zig/host/chart` | line, bar, area and pie charts |
| `zig/host/richtext` | the rich text editor (`ui.RichText`) |
| `zig/host/graph` | the node canvas (`ui.Graph`) |
| `zig/host/video` | native video and APNG (`ui/video`) |
| `zig/host/terminal` | a terminal on libghostty-vt |
| `zig/host/sqlite` | SQLite |
| `zig/host/fetch` | HTTP through the system's proxy |
| `zig/host/websocket` | WebSocket with headers browsers forbid |
| `zig/host/watch` | file watching |
| `zig/host/updater` | updates |
| `zig/host/permissionflow` | the system's permissions |
| `zig/host/glass` | Liquid Glass, blur and scroll edge |
| `zig/host/game` | a fixed-step game view |
| `zig/host/gamepad` | controllers |
| `zig/host/webview` | first-class `WebView` handles |
| `zig/host/documents` | the document controller |
| `zig/host/automation` | agent automation (inspector builds) |

## Examples

| | |
| --- | --- |
| [`hello-zig`](zig/examples/hello-zig) | a webview app with a generated TypeScript client |
| [`counter-native-zig`](zig/examples/counter-native-zig) | native UI: numeric transition, painter waveform, 100k-row list, IME |
| [`gallery-zig`](zig/examples/gallery-zig) | the widget tour, 13 tabs, every opt-in package |
| [`documents-zig`](zig/examples/documents-zig) | `DocumentsOf(Note)`: typed open, save, revert |

```sh
go run ./zig/cmd/build zig/examples/gallery-zig
open "zig/examples/gallery-zig/dist/darwin-arm64/Gallery Zig.app"
```

## Documentation

| | |
| --- | --- |
| [`zig/README.md`](zig/README.md) | the Zig reference: SDK, ABI, every API, the opt-in packages |
| [`zig/COMPLETENESS.md`](zig/COMPLETENESS.md) | what is covered, opcode by opcode |
| [`zig/EDGE.md`](zig/EDGE.md) | the host's edges and how they are closed |
| [`zig/UPSTREAM.md`](zig/UPSTREAM.md) | each upstream review: what changed, what Zig needed |
| [`docs/zig.md`](docs/zig.md) | the docs site page |
| [`docs/architecture.md`](docs/architecture.md) | MyGo's layers, threading and the wire |

## Requirements

- **Go 1.27** (the module's version) to build the host and the CLI.
- **Zig 0.17.1** to build the dylib.
- macOS 13+, Linux with WebKitGTK 4.1, or Windows 10+ with WebView2 for webview
  windows; native UI needs none of them.

CI builds the host for every platform and architecture, compiles the examples
with Zig, round-trips the scaffold, and checks that regenerating the Element
modifiers changes nothing.

## Upstream

MyZig tracks [egoist/mygo](https://github.com/egoist/mygo) and merges
`upstream/main` often; the host lives in-tree under `github.com/egoist/mygo/zig`
so a merge never touches an import. Upstream keeps apps Go-authored
([#1451](https://github.com/egoist/mygo/issues/1451)); its
[#1430](https://github.com/egoist/mygo/pull/1430) is the supported direction
for other languages. This fork is where the Zig bindings are maintained:
**[DaviRain-Su/myzig](https://github.com/DaviRain-Su/myzig)**.

The Go APIs themselves are MyGo's, documented in [`docs/`](docs): windows,
[menus](docs/menus.md), [documents](docs/documents.md),
[native UI](docs/native.md), [i18n](docs/i18n.md),
[distribution](docs/distribution.md) and the rest.
