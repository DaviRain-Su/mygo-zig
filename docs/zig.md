# Zig apps (external `mygo-zig`)

MyGo's core is Go-authored apps. Zig (and other languages) sit **outside**
core on the [Model A](https://github.com/DaviRain-Su/mygo-zig) host: a
`CGO_ENABLED=0` purego process loads your Zig dylib and talks over one
callback. Official inclusion of Zig-authored apps in `egoist/mygo` was
declined; maintain apps against [`DaviRain-Su/myzig`](https://github.com/DaviRain-Su/myzig)
(canonical rename of `mygo-zig`) and merge `upstream/main` periodically.

Module path in this tree is still `github.com/egoist/mygo/...` so pure-Go
apps and upstream stay compatible; a standalone `go.mod` rename is optional
packaging (see `zig/BRANDING.md`).

## Layers

```
Zig app  →  zig/sdk (mygo.zig, ui.zig)  →  zig/host (purego)  →  MyGo core / plugins
```

| Layer | What |
|-------|------|
| **Core SDK** | Windows, pages, shell, clipboard, lifecycle, Native UI widgets, IME, audio, effects, timelines |
| **Opt-in host** | blank-import packages under `zig/host/*` — pay only for what you use |
| **Plugins** | Official `plugins/*`; Zig binds them as opt-in hosts (terminal, sqlite, …) |

Apps that omit `zig/host/ui` never link `package ui`. Heavy surfaces
(markdown, editor, chart, terminal, sqlite, …) register only when imported.

## Quick start

```sh
go run ./zig/cmd/scaffold -build myapp
# or
go run ./zig/cmd/build zig/examples/hello-zig
```

Minimal host `main.go`:

```go
package main

import (
	"github.com/egoist/mygo/zig/host"
	_ "github.com/egoist/mygo/zig/host/ui" // Native GPU UI
)

func main() { host.Main("myapp") }
```

Zig entry (`src/app.zig`):

```zig
const mygo = @import("mygo");
const ui = mygo.ui;

export fn mygo_zig_entry(...) ... // via mygo.exportApp
```

See `zig/README.md` and `zig/COMPLETENESS.md` in the fork for the full
opcode map and status matrix.

## Opt-in packages

| Blank-import | Zig API |
|--------------|---------|
| `zig/host/ui` | `mygo.ui` CommandBuffer widgets |
| `zig/host/markdown` | `c.markdown` / `markdownStream` |
| `zig/host/editor` | `c.codeEditor` / `diffView` |
| `zig/host/chart` | line/bar/area/pie |
| `zig/host/terminal` | `mygo.Terminal` + `c.terminalView` |
| `zig/host/sqlite` | `mygo.SQLite` (JSON args/results) |
| `zig/host/watch` | `mygo.Watch` (JSON FileEvent push) |
| `zig/host/permissionflow` | `mygo.PermissionFlow` |
| `zig/host/fetch` | `mygo.Fetch.request` (HTTP + system proxy) |
| `zig/host/websocket` | `mygo.WebSocket` (headers browsers forbid) |
| `zig/host/updater` | `mygo.Updater` (+ `mygo.Use` on import) |
| `zig/host/glass` | `c.glass` / `glassBlur` / `scrollEdge` |
| `zig/host/game` | `c.gameView` (fixed-step Update/Draw) |
| `zig/host/automation` | blank-import `plugins/automation` |
| `zig/host/gamepad` | `mygo.Gamepad` poll |
| `zig/host/webview` | first-class `mygo.WebView` + `c.webViewHandle` |
| `zig/host/documents` | byte-level `Documents`; `mygo.DocumentsOf(T)` adds typed content |
| `zig/host/graph` | `ui.Graph`: node canvas, boards, Zig-built node bodies |
| `zig/host/richtext` | `ui.RichText`: rich text with Markdown/HTML/JSON and undo |
| `zig/host/video` | native video (`ui/video`) and APNG, with the system's media framework |

`Fetch` / `WebSocket` exist because Zig's ecosystem HTTP and WebSocket
clients are often incomplete for desktop apps (proxies, forbidden headers,
TLS via the OS). They reuse MyGo's `netproxy` and the websocket plugin's
dialer.

## Examples

- `zig/examples/hello-zig` — webview hello
- `zig/examples/counter-native-zig` — Native UI counter
- `zig/examples/gallery-zig` — widget + plugin tour, 13 tabs
- `zig/examples/documents-zig` — `DocumentsOf(Note)`, typed documents

## Syncing upstream

```sh
git fetch upstream && git merge upstream/main
go run ./zig/cmd/uigen   # regenerate Element modifiers if ui changed
```
