# MyZig — writing MyGo apps in Zig

This fork of [MyGo](https://github.com/egoist/mygo) makes **Zig a first-class
authoring language**. You write the app in Zig; a small Go shim boots it.

```zig
const mygo = @import("mygo");

fn view(app: *App, c: *ui.Context) void {
    const root = c.column().fill().center().gap(12).begin();
    defer root.end();
    _ = c.text("Hello from Zig").fontSize(32).bold();
    if (c.primaryButton("go", "Count").clicked()) app.n += 1;
}

comptime {
    mygo.exportApp(.{ .ready = onReady });
}
```

```go
// main.go — the whole Go side
func main() { host.Main("myapp") }
```

## How it works

- **No cgo.** The Go side calls into the Zig `cdylib` through `purego`, and
  Zig calls back through one exported symbol, `mygo_zig_entry`. Everything
  builds with `CGO_ENABLED=0` on macOS, Linux and Windows, `amd64` and
  `arm64`.
- **One wire.** Native UI is a `CommandBuffer` of widgets and modifiers that
  Zig records into a buffer; the host replays it into `package ui`, which
  draws it on the GPU. WebView windows use the same host.
- **Pay for what you use.** `zig/host` alone is a WebView app and links none
  of `package ui`; each heavy surface (rich text, charts, terminal, SQLite,
  video, graph…) is its own opt-in package. Pure-Go MyGo apps are unchanged:
  `examples/hello` and `examples/counter-native` stay at +0 bytes.

## What you can write

| | |
|---|---|
| **Windows** | webview or native UI, menus, tray, flyouts, dialogs, notifications, vibrancy, window state |
| **Native UI** | 297 Element methods: layout, 40+ widgets, tables, lists, text editing, IME, drag and drop, motion, timelines, masks, transforms, effects, a node canvas, rich text, video |
| **Platform** | clipboard (rich MIME), secrets, cookies, sessions, locale, content rules, protocols, deep links, hotkeys, screen, power, shell, dock/jump list, single instance |
| **Data** | typed documents (`DocumentsOf(T)`), HTTP, WebSocket, SQLite, watch, updater, audio |
| **Runtime** | typed IPC and events, a generated TypeScript client for pages, the `mygo` CLI for packaging |

> The rest of this file is the Zig reference: every API, the ABI, the opt-in
> packages, and what stays Go. Upstream keeps apps Go-authored
> ([`egoist/mygo#1451`](https://github.com/egoist/mygo/issues/1451));
> [#1430](https://github.com/egoist/mygo/pull/1430) is the supported Go→native
> direction. Maintained on
> [`DaviRain-Su/myzig`](https://github.com/DaviRain-Su/myzig).

## Directory layout

| Path | Role |
|------|------|
| `cmd/build/` | One-shot `zig build` + `mygo build` for an app |
| `cmd/scaffold/` | New Native UI Zig app (`-build` packages it) |
| `cmd/uigen/` | AST codegen from `ui/api_gen.go` → **202** Element modifiers (`host/ui/modifiers_gen.go` + `sdk/element_gen.zig`), including `Align` / `BorderStyle` / `Cursor` / `Direction` |
| `host/` | Pure-Go purego host: windows, IPC, embed, clipboard, menus, shell |
| `host/ui/` | Opt-in Native GPU UI CommandBuffer (widgets below) |
| `host/markdown/` | Opt-in `ui/markdown` (`View` + `Stream`) |
| `host/editor/` | Opt-in `ui/editor` (`View` + `DiffView`) |
| `host/terminal/` | Opt-in `plugins/terminal` (Ghostty VT) |
| `host/sqlite/` | Opt-in `plugins/sqlite` (Open/Execute/Query/Tx) |
| `host/watch/` | Opt-in `mygo.WatchFiles` (JSON event push) |
| `host/permissionflow/` | Opt-in `plugins/permissionflow` |
| `host/fetch/` | Opt-in HTTP (`netproxy`) for Zig |
| `host/websocket/` | Opt-in WebSocket dial + events |
| `host/updater/` | Opt-in auto-update (`mygo.Use` on import) |
| `host/glass/` | Opt-in Liquid Glass / Blur / ScrollEdge |
| `host/game/` | Opt-in fixed-step game View |
| `host/automation/` | Opt-in MYGO_AUTOMATION (inspector builds) |
| `host/gamepad/` | Opt-in controller poll |
| `host/webview/` | First-class WebView handles |
| `host/documents/` | Byte-level document controller (`sdk` adds `DocumentsOf(T)`) |
| `host/graph/` | Opt-in `ui/graph` node canvas (boards, callbacks, node bodies) |
| `host/richtext/` | Opt-in `ui/richtext` rich text (Markdown/HTML/JSON, undo) |
| `host/video/` | Opt-in `ui/video` native playback + APNG |
| `sdk/mygo.zig` | Idiomatic Zig SDK (`exportApp`, `bind`, `declareEvent`, `Window`, …) |
| `sdk/ui.zig` | Zero-alloc CommandBuffer client, controls, IME, graph, rich text, effects |
| `sdk/element_gen.zig` | 202 generated modifiers + 95 hand-written queries and hooks |
| `examples/hello-zig/` | WebView + generated `src/mygo.ts` |
| `examples/counter-native-zig/` | GPU UI: numeric transition, Painter wave, 100k-row List |
| `examples/gallery-zig/` | Widget tour, 13 tabs (Controls … Graph, Rich, Term) |
| `examples/documents-zig/` | `DocumentsOf(Note)` demo (typed open/save/revert) |

## Native UI surface (Zig)

### Layout & chrome
`column` · `row` · `box` · `grid` · `scroll` · `scrollHorizontal` · `scrollBoth` · `spacer` · `divider` · `split` / `splitVertical` / `splitPercent` / `splitVerticalPercent` · `collapsible` · `accordion` / `accordionItem` · `sidebar` · `tabs` · `segmented` · `breadcrumbs` · `fieldset` · `field` · `form` · `toolbar` · `overlay` · `tree` / `treeItem` · `themed` · `router` / `routeView` / `routeMatch` / `routeParam` / `backButton` / `forwardButton`

### Controls
`button` / `primaryButton` · `checkbox` / `checkboxState` / `checkboxGroup` · `toggle` / `toggleGroup` · `switchControl` · `radio` / `radioGroup` · `slider` / `stepSlider` / `rangeSlider` · `stepper` · `numberInput` · `decimalInput` · `rating` · `textInput` / `textArea` / `editableText` / `searchField` / `autocomplete` / `tokenField` / `findBar` · `selectIndex` · `combobox` · `menuButton` / `popoverMenuButton` · `contextMenu` / `popoverMenu` (nested `MenuEntry` + submenus) · `badge` · `link` · `progress` / `meter` · `spinner` · `avatar` · `icon` · `image` · `alertDialog` · `modal` · `popover` · `toast` / `toastAction` · `richText` (+ object spans / `drawObjects`) · `webView` · `video` / `registerVideoGIF` / `registerVideoFrames` / `openVideoStream`+`pushVideoFrame` · `toastViewport` / `toastItem` · `drag` / `drop` / `dragOver` · `dragData` / `dropData` / `dataDragOver` · `dragMIME` / `dragMIMELazy` / `dropMIME` · `addToast`/`closeToast` (string Data + userdata + toast id) · `videoSeek`/`videoSetRate`/`videoSetVolume`/`videoSetMuted`/`videoSetLoop` + position/duration/size · motion (`after`/`animateTo`/`animatePose`/…) · `role` · `linearGradient` · `registerBitmap`/`bitmap` · `registerFont` · `registerCanvas` · `conicGradient`/`radialGradient`/`linearGradStops`

### Dates & color
`dateInput` · `timeInput` · `calendar` · `colorPicker` · `colorWell`

### Data
Virtualized `list` (100k+ rows) · multi-column `table` · virtualized `gridView` · hierarchical `outline` / `outlineTable` · custom `draw` + `Painter`

### Opt-in surfaces
`markdown` / `markdownStream` (`zig/host/markdown`) · `codeEditor` / `diffView`
(`zig/host/editor`) · `lineChart` / `barChart` / `areaChart` / `pieChart`
(`zig/host/chart`) · `terminalView` / `mygo.Terminal` (`zig/host/terminal`) ·
`ui.Graph` (`zig/host/graph`) · `ui.RichText` (`zig/host/richtext`) · native
video and APNG (`zig/host/video`) · `mygo.SQLite` · `mygo.Watch` ·
`mygo.PermissionFlow` · `mygo.Fetch` · `mygo.WebSocket` · `mygo.Updater` ·
glass · game · gamepad · automation · webview · documents

### Element modifiers (202 generated, 297 total)
padding, gap, grow, border, radius, fonts, `tooltip`, `cursor`, `direction`, `justify` / `alignItems`, `draggable`, …

### Element queries and hooks (hand-written)

Beyond the generated modifiers, `element_gen.zig` carries the Element API that
returns values or takes callbacks:

| Group | Methods |
| --- | --- |
| Focus | `focused` · `focusVisible` · `focusWithin` · `focusLeft` · `focusGroup` |
| Scroll | `trackScroll(&state)` — read and set a container's offset |
| Press/click | `clicks` · `clickModifiers` · `pressedButton` · `pressedInside` · `pressedOutside` · `pressedPointer` · `pressCanceled` · `doubleClicked` · `rightClicked` |
| State | `isDisabled` · `highlighted` · `dismissed` · `composing` · `transitioning` · `dragging` |
| Geometry | `bounds` · `layoutBounds` · `localToWindow` · `windowToLocal` · `pointerPosition` |
| Scroll | `inView` · `inViewAmount` · `inViewMargin` |
| Text | `textSelection` · `textAnchorCaret` |
| Session | `Window.sessionState` / `WindowOptions.session_state` |
| Drag | `dragOffset` · `dragVelocity` · `dragEnded` · `dragMissed` |
| Keys | `shortcut` · `overlayShortcut` · `keyShortcuts` |
| Input | `observeInput` · `handleInput` · `hitTest` |
| Scroll | `scrollSnap` · `scrollIntoView` · `droppedFiles` · `fileDragOver` |
| Motion | `transition` · `contentTransition` |
| Masks | `maskLinearGradient` · `maskRadialGradient` · `maskConicGradient` |
| Transform | `transform(ui.Transform{}.translate(x, y).rotate(deg)…)` |
| Masks | `masks(&.{ ui.Mask{ … } })` — gradient layers with composite + box |
| Timeline | `timeline(key, opts)` → `tween` / `label` / `durationMs` / `timeMs` / `progress` / `settled` / `arrived` |
| Text | `onTextKey(*T, state, handler)` — replace the text a key takes |

```zig
const field = c.textInput("q", buf[0..], &len);
if (field.focused()) { ... }
const r = field.bounds();      // ui.Rect in window coordinates
if (field.shortcut(.{ .super = true }, .k)) { ... }
```

`Rect` queries fill `CQuery.num_val..num_val4`; optional results come back as
`?ui.Point` / `?i32`.

Input hooks take a comptime handler, as `draw` does:

```zig
_ = c.searchField("q", buf[0..], &len)
    .observeInput(*App, &app, App.onInput)          // sees, takes nothing
    .handleInput(*App, &app, App.onInputTake);      // true consumes the event

fn onInput(app: *App, ev: ui.InputEvent) void {
    if (ev.kind == .key_down and ev.key == .f1) app.help = !app.help;
}
```

### Node canvas

`ui/graph` is bound as an opt-in host: `_ "github.com/egoist/mygo/zig/host/graph"`.

```zig
var board = try ui.Graph.create(doc_json, .{ .minimap = true, .snap_grid = 16 });
board.setContent(*App, &app, App.nodeBody);   // Zig draws each node's body
board.onSelect(*App, &app, App.onSelect);

_ = board.view(c, .{ .minimap = true, .snap_grid = 16 }).fill().grow(1.0);
```

`Board` also has `load` / `exportJSON` (the `ui/graph` document format),
`addNode` (returns the id), `selection`, `delete` / `group` / `ungroup` /
`layout` / `fit` / `undo` / `redo` / `copy` / `paste` / `lock` / `selectAll`,
and `onConnect` / `onMove` / `onDelete` / `onViewport` (JSON payloads).

### Rich text

`ui/richtext` is bound as an opt-in host: `_ "github.com/egoist/mygo/zig/host/richtext"`.

```zig
var doc = try ui.RichText.markdown(src);          // or .create(.html, …)
_ = doc.command(.bold);                            // bold/italic/underline/code/lists/quote/undo…
doc.heading(2);
doc.setAlign(.center);
var buf: [64 << 10]u8 = undefined;
const md = doc.save(.markdown, buf[0..]);          // .text / .html / .json
_ = doc.view(c, .{ .placeholder = "Write…" }).fill().grow(1.0);
```

`Doc` also has `set(format, data)`, `insert(at, text)`, `selection` /
`setSelection`, `version`, `canUndo` / `canRedo` and `destroy`.

Links and tags stay in Zig:

```zig
doc = doc.onLink(*App, &app, App.openLink)          // a URL was clicked
         .onLinkCommand(*App, &app, App.askForLink) // Cmd+K
         .onTagStyle(*App, &app, App.tagStyle);     // color a @mention
```

`onTagStyle` fills a `ui.RichText.Style` (color, background, weight, italic,
underline, strikethrough, radius, padding).

### Video

GIFs, frame pushes and streams need only `zig/host/ui`; native video and APNGs
come from the opt-in `zig/host/video` (`_ "github.com/egoist/mygo/zig/host/video"`),
which plays files and streams with the system's media framework.

```zig
// GIF / pushed frames (zig/host/ui)
try ui.registerVideoGIF("waves", gif_bytes, true);
_ = c.video("waves", .cover).fillWidth().height(160);

// A file, data, URL or APNG (zig/host/video)
try ui.VideoSource.openFile("trailer", path, true);
try ui.VideoSource.openData("clip", mp4_bytes, false);
try ui.VideoSource.openURL("live", "https://example.com/live.m3u8", false);
try ui.VideoSource.registerAPNG("anim", png_bytes, true);
_ = c.video("trailer", .contain).fillWidth().height(240);
```

The player is the same for all of them:

```zig
c.videoPlay("waves");  c.videoPause("waves");  c.videoSeek("waves", 1500);
c.videoSetRate("waves", 2);  c.videoSetVolume("waves", 0.6);
c.videoSetMuted("waves", true);  c.videoSetLoop("waves", false);

const at = c.videoPositionMs("waves");     // where the playhead is
const len = c.videoDurationMs("waves");    // 0 until known, and for streams
const size = c.videoSize("waves");         // 0x0 until the first picture
if (c.videoReady("waves") and !c.videoEnded("waves")) { ... }
```

`ui.VideoSource.release("trailer")` closes a player.

### Documents (typed)

`mygo.DocumentsOf(T, …)` is `NewDocuments[T]` for Zig: a controller whose
documents hold `T`, with your `read` / `write` as the codecs.

```zig
const Notes = mygo.DocumentsOf(Note, .{
    .types_json = "[{\"name\":\"Note\",\"extensions\":[\"note\"]}]",
    .new_content = Note{ .title_buf = initTitle("Untitled"), .title_len = 8 },
    .autosave_off = true,
    .read = Note.read,
    .write = Note.write,
});

try Notes.init(*App, &app, App.windowFor);     // before App.Run
const doc = try Notes.new();                    // or Notes.open(path)
self.note = try doc.content(alloc);             // decode
try doc.setContent(alloc, self.note);            // encode + mark edited
try doc.save();
```

`Document` also has `saveAs`, `saveAnyway`, `revert`, `rename`, `moveTo`,
`duplicate`, `close`, `setEdited`, `focus`, `stateJSON`, `filePath`,
`displayName`, `windowID`, `isReadOnly` and `hasConflict`; the namespace has
`openDialog`, `list` and `forWindow`. `zig/examples/documents-zig` is built
on it.

### Go plugins

A Zig app still uses Go plugins, from its shim:

```go
func main() {
    host.Use(fetch.Plugin, websocket.Plugin) // their Setup runs, services bind
    host.Main("myapp")
}
```

The Zig side then uses the feature through `zig/host/fetch` and
`zig/host/websocket`; the plugin's JavaScript service is for pages.

### Effects

`ui.Effect` draws an element from what it renders: the element and its
children render into a bitmap, and Zig paints it.

```zig
_ = c.box().size(150, 56).background(t.surface)
    .effect(ui.effectOf(*App, &app, .{ .x = 6, .y = 6 }, App.wash))
    .begin();

fn wash(app: *App, p: *ui.Painter, box: ui.Rect, content: ui.Bitmap, inset: ui.Point) void {
    content.draw(p, .{
        .x = box.x - inset.x,
        .y = box.y - inset.y,
        .w = box.w + 2 * inset.x,
        .h = box.h + 2 * inset.y,
    }, .fill_box);
    p.fillRect(box.x, box.y, box.w, box.h, ui.Color.rgba(99, 102, 241, 70), 8);
}
```

The margin says how far beyond the box the effect reads; `inset` is where the
box corner lies in the content bitmap. `bitmap.draw` paints the content, and
any `Painter` operation works over it.

### Window state

Windows with a `state_key` remember their bounds. Zig can own that storage:

```zig
fn load(app: *App, buf: []u8) usize {   // JSON of map[string]WindowState
    @memcpy(buf[0..app.saved.len], app.saved);
    return app.saved.len;
}
fn save(app: *App, json: []const u8) void { app.saved = json; }

mygo.setWindowStateStore(*App, &app, App.load, App.save);  // before the first window
```

### System text input (IME)

```zig
const client = ui.TextInputClient{ .ctx = &app, .vtable = &app.text };
_ = c.box().handleTextInput(&client);
```

The vtable covers `textForRange`, `selection`, `markedRange`, `replaceText`,
`setMarkedText`, `unmarkText`, `boundsForRange` and `indexForPoint`, with
`ui.TextInputRange` counting UTF-16 code units.

### Timeline

```zig
const tl = card.timeline("intro", .{ .run = app.opened });
const x = tl.tween(.{ .from = -200, .to = 0, .duration_ms = 400 }, &.{});
_ = card.translate(x, 0);
```

Placements: `.{ .after_previous = 80 }`, `.{ .with_previous = 0 }`, `.{ .at_ms = 200 }`,
`.{ .at_label = .{ .name = "rows", .offset_ms = 40 } }`.

### Masks

```zig
_ = c.box().masks(&.{
    .{ .image = .{ .linear = .{ .angle = 90, .stops = &.{
        .{ .color = ui.Color.rgb(0, 0, 0), .at = 0 },
        .{ .color = ui.Color.rgba(0, 0, 0, 0), .at = 1 },
    } } } },
    .{ .image = .{ .radial = .{ .radius = 80, .stops = stops } },
       .composite = .intersect, .box = .padding },
});
```

### Text input keys

```zig
_ = c.textInput("q", buf[0..], &len).onTextKey(*App, &app, App.onKey);

fn onKey(app: *App, k: *ui.TextKey) bool {
    if (k.key == .f2) { k.replace("…"); return true; }
    return false;
}
```

### Audio

```zig
const beep = try mygo.Audio.decodeSound(wav_bytes);   // WAV, Ogg/MP3 with their Go plugins
const p = try beep.play();
_ = p.setVolume(0.4).setPan(-0.2).setSpeed(1.0).setLoop(true);
p.onEnd(*App, &app, App.onBeepEnd);

const music = try mygo.Audio.openStream(file_bytes);  // streams as it plays
music.play();
```

`Sound.durationMs()` and `Player.{play,pause,stop,close,playing,volume,pan,speed,looping,seekMs,positionMs,durationMs,setLoopRangeMs}`.

### Menus

Menus are JSON on the wire, with a Zig builder in front of it:

```zig
const items = [_]mygo.MenuItem{
    .{ .id = "open", .label = "Open…", .accelerator = "CmdOrCtrl+O",
       .tooltip = "Open a file", .subtitle = "⌘O", .icon_png = icon, .icon_template = true },
    .{ .kind = .separator },
    .{ .id = "quit", .label = "Quit", .role = "quit" },
};
mygo.Desktop.setAppMenu(*App, &app, &items, App.onMenu) catch {};
tray.setMenu(&tray_items) catch {};
```

`MenuItem` supports `id`, `label`, `kind` (`normal` / `separator` / `checkbox` /
`radio`), `role`, `accelerator`, `disabled`, `hidden`, `checked`, `tooltip`,
`subtitle`, `icon_png` (PNG bytes, base64 on the wire), `icon_template`, and
nested `submenu`.

### Scaffold

```sh
go run ./zig/cmd/scaffold myapp          # → zig/examples/myapp-zig
go run ./zig/cmd/scaffold -dir ./apps/x demo
```

### Status

Every capability a Go app has is reachable from Zig; the SDK carries 297
Element methods, 20 host packages, and 400+ ABI operations.

| Area | What is there |
|------|---------------|
| Widgets and chrome | Windows, menus, tray, flyouts, dialogs, notifications, vibrancy, window state, title bar |
| Native UI | Layout, 40+ widgets, virtualized lists and tables, outline, tree, grid, toolbar, find bar, toasts |
| Input | Keys, text, IME (`TextInputClient`), `observeInput`/`handleInput`/`hitTest`, drag and drop, rich MIME |
| Drawing | Painter paths, gradients, masks, transforms, effects (`ui.Effect`), bitmaps, canvases, fonts |
| Motion | `animate`/`animateTo`/`spring`, keyframes, timelines, transitions, content transitions |
| Documents | `DocumentsOf(T)` with autosave, typed content, window factory; rich text with Markdown/HTML/JSON |
| Media | GIF, APNG, pushed frames, streams, native video with the system's framework, audio |
| Data | HTTP, WebSocket, SQLite, watch, updater |
| Canvas | `ui.Graph`: boards, node bodies built by Zig, selection/connect/move/delete callbacks |
| Platform | Clipboard, secrets, cookies, session, locale, content rules, protocol, deep links, hotkey, screen, power, shell, dock/jump list, single instance |

What stays Go, and why it is not a gap:

| Item | Why |
|------|-----|
| `Plugin` / `mygo.Use` | It is how Go packages register themselves; the shim calls `host.Use(...)` and Zig uses the feature through its `zig/host` package. |
| A plugin's JavaScript service | Pages call it; Zig does not go through JS. |
| Go's type parameters | `DocumentsOf(T)` is their Zig spelling. |

## Quick start

```sh
# A new app, from the template
go run ./zig/cmd/scaffold myapp                   # zig/examples/myapp-zig
(cd zig/examples/myapp-zig && zig build)          # the dylib
go run ./cmd/mygo build -skip-dmg zig/examples/myapp-zig

# Or build an example, dylib and bundle, in one step
go run ./zig/cmd/build zig/examples/gallery-zig
open zig/examples/gallery-zig/dist/darwin-arm64/"Gallery Zig.app"

# Regenerate the Element modifiers after ui/api_gen.go changes
go run ./zig/cmd/uigen
```

## Linking opt-in features

An app's Go shim is the only Go it writes:

```go
package main

import (
	"github.com/egoist/mygo/zig/host"
	_ "github.com/egoist/mygo/zig/host/ui"      // native UI
	_ "github.com/egoist/mygo/zig/host/markdown"
	_ "github.com/egoist/mygo/zig/host/editor"
	_ "github.com/egoist/mygo/zig/host/chart"
	_ "github.com/egoist/mygo/zig/host/richtext"
	_ "github.com/egoist/mygo/zig/host/graph"
	_ "github.com/egoist/mygo/zig/host/video"
	_ "github.com/egoist/mygo/zig/host/terminal"
	_ "github.com/egoist/mygo/zig/host/sqlite"
	_ "github.com/egoist/mygo/zig/host/fetch"
	_ "github.com/egoist/mygo/zig/host/websocket"
	_ "github.com/egoist/mygo/zig/host/watch"
	_ "github.com/egoist/mygo/zig/host/updater"
	_ "github.com/egoist/mygo/zig/host/permissionflow"
	_ "github.com/egoist/mygo/zig/host/glass"
	_ "github.com/egoist/mygo/zig/host/game"
	_ "github.com/egoist/mygo/zig/host/gamepad"
	_ "github.com/egoist/mygo/zig/host/webview"
	_ "github.com/egoist/mygo/zig/host/documents"
)

func main() {
	host.Use(fetch.Plugin) // Go plugins, when the app has pages that call them
	host.Main("myapp")
}
```

An app that imports only `host` is a WebView app and links none of `package
ui`; each package above registers its own host opcode, so an app that does not
import it pays nothing for it.

## Syncing upstream

```sh
git fetch upstream && git merge upstream/main
go run ./zig/cmd/uigen   # refresh modifiers after ui/api_gen.go changes
```
