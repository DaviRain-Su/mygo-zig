# Writing MyGo Apps in Zig (`zig/` — `CGO_ENABLED=0` Purego Architecture)

Full MyGo applications—both **WebView** apps and **GPU-rendered Native UI (`package ui`)** apps—written in **Zig**, built on a **100% `CGO_ENABLED=0` `purego` host**:

- **Zero `cgo` (`CGO_ENABLED=0`)** across macOS, Linux, and Windows (`amd64` & `arm64`).
- **Single `purego.NewCallback` (`hostDispatch`)** and **single Zig symbol (`mygo_zig_entry`)** for the entire framework.
- **Zero overhead on pure-Go MyGo apps** (`+0 bytes` on `examples/hello` and `examples/counter-native`).
- **Pay-only-for-what-you-use**: WebView Zig apps (`zig/host` alone) build without linking `package ui`; Native GPU UI, Markdown and the code editor are separate opt-in imports.
- **Full `mygo` CLI integration**: `mygo generate` (typed `src/mygo.ts` from Zig `comptime` reflection) and `mygo build` (`.app` / `.dmg` / `.deb` / NSIS).

> Maintained on the [`DaviRain-Su/myzig`](https://github.com/DaviRain-Su/myzig) fork. Upstream keeps apps Go-authored (`egoist/mygo#1451`); `#1430` `package ffi` is the supported Go→native direction.

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
| `host/documents/` | Bytes document controller |
| `sdk/mygo.zig` | Idiomatic Zig SDK (`exportApp`, `bind`, `declareEvent`, `Window`, …) |
| `sdk/ui.zig` | Zero-alloc CommandBuffer client + rich controls |
| `sdk/element_gen.zig` | Generated style / layout / query modifiers |
| `examples/hello-zig/` | WebView + generated `src/mygo.ts` |
| `examples/counter-native-zig/` | GPU UI: numeric transition, Painter wave, 100k-row List |
| `examples/gallery-zig/` | Full widget tour (Controls / Inputs / Layout / Data / Markdown / Editor) |
| `examples/documents-zig/` | Bytes Documents demo (open/save/revert) |

## Native UI surface (Zig)

### Layout & chrome
`column` · `row` · `box` · `grid` · `scroll` · `scrollHorizontal` · `scrollBoth` · `spacer` · `divider` · `split` / `splitVertical` / `splitPercent` / `splitVerticalPercent` · `collapsible` · `accordion` / `accordionItem` · `sidebar` · `tabs` · `segmented` · `breadcrumbs` · `fieldset` · `field` · `form` · `toolbar` · `overlay` · `tree` / `treeItem` · `themed` · `router` / `routeView` / `routeMatch` / `routeParam` / `backButton` / `forwardButton`

### Controls
`button` / `primaryButton` · `checkbox` / `checkboxGroup` · `toggle` / `toggleGroup` · `switchControl` · `radio` / `radioGroup` · `slider` / `stepSlider` / `rangeSlider` · `stepper` · `numberInput` · `decimalInput` · `rating` · `textInput` / `textArea` / `editableText` / `searchField` / `autocomplete` / `tokenField` / `findBar` · `selectIndex` · `combobox` · `menuButton` / `popoverMenuButton` · `contextMenu` / `popoverMenu` (nested `MenuEntry` + submenus) · `badge` · `link` · `progress` / `meter` · `spinner` · `avatar` · `icon` · `image` · `alertDialog` · `modal` · `popover` · `toast` / `toastAction` · `richText` (+ object spans / `drawObjects`) · `webView` · `video` / `registerVideoGIF` / `registerVideoFrames` / `openVideoStream`+`pushVideoFrame` · `toastViewport` / `toastItem` · `drag` / `drop` / `dragOver` · `dragData` / `dropData` / `dataDragOver` · `dragMIME` / `dragMIMELazy` / `dropMIME` · `addToast`/`closeToast` (string Data + userdata + toast id) · motion (`after`/`animateTo`/`animatePose`/…) · `role` · `linearGradient` · `registerBitmap`/`bitmap` · `registerFont` · `registerCanvas` · `conicGradient`/`radialGradient`/`linearGradStops`

### Dates & color
`dateInput` · `timeInput` · `calendar` · `colorPicker` · `colorWell`

### Data
Virtualized `list` (100k+ rows) · multi-column `table` · virtualized `gridView` · hierarchical `outline` / `outlineTable` · custom `draw` + `Painter`

### Opt-in rich text & charts
`markdown` / `markdownStream` (`_ "…/zig/host/markdown"`) · `codeEditor` / `diffView` (`_ "…/zig/host/editor"`) · `lineChart` / `barChart` / `areaChart` / `pieChart` (`_ "…/zig/host/chart"`) · `terminalView` / `mygo.Terminal` (`_ "…/zig/host/terminal"`) · `mygo.SQLite` (`_ "…/zig/host/sqlite"`) · `mygo.Watch` · `mygo.PermissionFlow` · `mygo.Fetch` · `mygo.WebSocket` · `mygo.Updater` · glass · game · graph · richtext

### 202 Element modifiers (generated)
padding, gap, grow, border, radius, fonts, `tooltip`, `cursor`, `direction`, `justify` / `alignItems`, `draggable`, …

### Element queries and hooks (hand-written)

Beyond the generated modifiers, `element_gen.zig` carries the Element API that
returns values or takes callbacks:

| Group | Methods |
| --- | --- |
| Focus | `focused` · `focusVisible` · `focusWithin` · `focusLeft` · `focusGroup` |
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

### Solving the remaining edges

| Gap | Zig solution |
|-----|--------------|
| Custom / streaming video | `openVideoStream` → `pushVideoFrame` → `video` (HostOps 232–234). Decode in Zig (or another process) and push RGBA; host never calls Zig from the decode goroutine. |
| Toast `Data any` | Cross-FFI: UTF-8 `data` string + opaque `userdata` (`usize`). Host stores `ZigToastData{Text,User}`; `toastItem` returns both; `addToast` also returns the toast id. |

File-backed formats (mp4/webm) stay out of core: decode externally, push frames.

### Notification
`Notification.supported` · `show` · `close` · `clearAll` · click handlers

### Flyout
`newFlyoutUi` · parent/tray · vibrancy · placement/gap/flags · `Window.setAnchor` · `Context.hasVibrancy`

### Tray
`Tray.new` · `setIcon`/`setTitle`/`setToolTip`/`setMenuJSON` · `onClick`/`registerMenuHandler`

### Dialogs
`Dialog.open` / `save` / `message` (blocking, NUL-separated paths)

### Window / a11y (upstream sync)
`Window.setInputRegion` · Element `role(.status/.log/.alert/…)` (ARIA live status from #1462)

### Motion & timing (now bound)
`after` · `animationFrame` · `disableAnimations` · `invalidate` · `closeToast` · `animate` / `animateTo` / `spring` · `arrived` · `animateColor` · `animatePose` (`AnimPreset`: custom/smooth/snappy/bouncy)

### Roadmap to "complete"

| Track | Status | Notes |
|-------|--------|-------|
| Widgets / chrome / data | Done | Gallery covers Controls→Editor |
| Drag / toast / video / routes | Done | Incl. stream push + toast userdata |
| Motion / timing | Done | Ops 322–332 |
| Painter paths / gradients | Done | paths + linear/conic/radial + multi-stop (`linearGradStops`/`fill*Gradient`) |
| File dialogs | Done | `Dialog.open`/`save`/`message` + multi `FileFilter` |
| Tray | Done | `Tray.new` / menu / click / destroy |
| Fetch / WebSocket / Updater | Done | HTTP+WS for Zig; thin updater prefs/check |
| Watch + PermissionFlow | Done | `mygo.Watch` / `mygo.PermissionFlow` opt-in hosts |
| SQLite plugin SDK | Done | `mygo.SQLite` open/execute/query/transaction (JSON args) |
| Terminal plugin SDK | Done | `mygo.Terminal` + `ui.terminalView`; gallery Term tab |
| Completeness batch | Done | App state, window chrome/events, shell icons/trash, clipboard files, page stop/theme/title — see COMPLETENESS.md |
| Capture / PDF | Done | `capturePagePNG` / `printToPDF` |
| Zoom / DevTools / Print / Locale.onChanged | Done | page chrome + `Locale.onChanged` |
| Context menu / ContentRules / media | Done | `onContextMenu`, `ContentRules.compile`, mute/capture/PiP |
| Page.Eval | Done | `Window.evalJSON` |
| Locale / FindInPage | Done | `Locale.*`, `Window.findInPage`/`reload`/`goBack`/`goForward` |
| Login / Relaunch | Done | `Lifecycle.setOpenAtLogin`/`relaunch` |
| Permission / window.open | Done | `setPermissionHandler`/`setWindowOpenHandler` |
| Page events | Done | `Window.onPage` / `navigateRespond` (will/did/DOM/fail/gone) |
| Session | Done | `Session.clearBrowsingData`/`clearData` + window `session_name` |
| Cookies / Downloads | Done | `Cookies.listJSON`/`setJSON` + `Window.onDownload` |
| Page auth/cert | Done | `setAuthHandler`/`authRespond`/`setCertificateErrorHandler` |
| Secrets | Done | `Secrets.set`/`get`/`delete` (Keychain/libsecret/CredMan) |
| Clipboard image | Done | `writeImage`/`readImage`/`availableFormatsJSON` |
| Desktop | Done | JumpList / recent docs / Dock menu·icon·hide / App menu |
| Protocol | Done | `Protocol.handle`/`respond`/`unhandle` custom schemes |
| Lifecycle | Done | activate/quit/openURL/openFile/single-instance/about/badge/bounce/URL schemes |
| Appearance / Power | Done | `Appearance.isDark`/`setSource`/`preferencesJSON`, `Power.keepAwake`/`onEvent` |
| Path / Screen / Hotkey | Done | `Path.get`/`set`, `Screen.displaysJSON`/`cursor`, `Hotkey.register` |
| Window vibrancy/progress | Done | `setVibrancy`/`setVibrancyTint`/`setProgressBar`/`setContentProtection` + title bar opts/insets |
| Notification | Done | `Notification.show`/`close`/`clearAll`/`onAppClick` |
| Flyout | Done | `newFlyoutUi` + vibrancy + `Window.setAnchor` |
| Bitmap / Canvas / Fonts | Done | `registerBitmap`/`bitmap`, `registerFont`, `registerCanvas` + Painter `canvasBegin`/`End`/`image` |
| DX: CI + one-shot build | Done | `.github/workflows/zig.yml`; `go run ./zig/cmd/build <app>`; `scaffold -build` |
| Standalone module path | Open | `mygo-zig` go.mod branding / docs site |

## Quick start

```sh
# Regenerate Element modifiers from ui/api_gen.go:
go run ./zig/cmd/uigen

# 1. WebView
(cd zig/examples/hello-zig && zig build -Doptimize=ReleaseSmall)
go run ./cmd/mygo generate zig/examples/hello-zig
go run ./cmd/mygo build -skip-dmg zig/examples/hello-zig

# 2. GPU Native UI (counter)
(cd zig/examples/counter-native-zig && zig build -Doptimize=ReleaseSmall)
go run ./cmd/mygo build -skip-dmg zig/examples/counter-native-zig

# 3. Widget gallery (one-shot)
go run ./zig/cmd/build zig/examples/gallery-zig
open zig/examples/gallery-zig/dist/darwin-arm64/Gallery\ Zig.app
```

## Linking opt-in features

```go
package main

import (
	"github.com/egoist/mygo/zig/host"
	_ "github.com/egoist/mygo/zig/host/ui"       // Native GPU UI
	_ "github.com/egoist/mygo/zig/host/markdown" // optional
	_ "github.com/egoist/mygo/zig/host/editor"   // optional
	_ "github.com/egoist/mygo/zig/host/terminal" // optional
	_ "github.com/egoist/mygo/zig/host/sqlite"   // optional
	_ "github.com/egoist/mygo/zig/host/watch"    // optional
	_ "github.com/egoist/mygo/zig/host/permissionflow" // optional
)

func main() { host.Main("myapp") }
```

Apps that omit `host/ui` never link `package ui`. Markdown and the editor register their own host opcodes (`200` / `210` / `211`) the same way.

## Syncing upstream

```sh
git fetch upstream && git merge upstream/main
go run ./zig/cmd/uigen   # refresh modifiers after ui/api_gen.go changes
```
