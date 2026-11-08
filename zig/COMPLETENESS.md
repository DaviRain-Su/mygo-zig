# Zig FFI completeness plan

Last updated after Phase 0 consolidate + Phase 1 `terminal` plugin SDK.

## Layers (read this first)

```
Zig app  →  Zig SDK (zig/sdk)  →  Zig Host (zig/host)  →  MyGo core / plugins
```

| Layer | What it is | Default in every Zig app? |
|-------|------------|---------------------------|
| **Core SDK** | `mygo.zig` / `ui.zig`: App, Window, Page, Shell, Clipboard, Lifecycle, native UI widgets | Yes |
| **Opt-in host packages** | blank-import `zig/host/{ui,markdown,editor,chart,terminal}` | No — pay for what you use |
| **Plugins** | `plugins/*` (terminal, sqlite, …). Zig binds them as opt-in host packages | No |
| **Product** | docs site, go.mod branding, version strategy | Not FFI |

Plugins are **not** core SDK, but they **are** optional SDK modules once bound
(`import` host package + Zig API). Same pattern as `markdown` / `editor`.

## Core desktop SDK — Done

Widgets, painter, motion, dialogs, tray, flyout, notifications, protocol,
desktop/JumpList/Dock, secrets, cookies/downloads, session, auth/cert, page
lifecycle, permission/window.open, locale/find, login/relaunch, context menu,
ContentRules, media, eval, zoom/UA/DevTools/print, capture PNG, PrintToPDF,
Path/Screen/Hotkey, Appearance/Power, Lifecycle, window chrome/events, Shell
basics + icons/trash, Clipboard text/image/files, page stop/theme/title.

## Opt-in packages

| Package | Status | Blank-import |
|---------|--------|--------------|
| `zig/host/ui` | Done | required for Native UI |
| `zig/host/markdown` | Done | Markdown tab |
| `zig/host/editor` | Done | Editor tab |
| `zig/host/chart` | Done | Charts tab |
| `zig/host/terminal` | Done (Phase 1) | Term tab; ships libghostty-vt via plugin JSON |
| `zig/host/sqlite` | Done (Phase 2) | More-tab demo; JSON args/results |
| `zig/host/fetch` / `websocket` | Done | HTTP+WS with netproxy / plugin dialer |
| `zig/host/updater` | Done | Check + automatic prefs; `Use` on import |
| `zig/host/permissionflow` | Done (Phase 3) | Check/Allowed/OpenSettings + async Request/Guide/Wait |
| `zig/host/watch` | Done (Phase 3) | push JSON FileEvent batches |

## Explicitly deferred (niche / product)

| Item | Why |
|------|-----|
| Branding docs (`myzig`) | **Done** (`zig/BRANDING.md` + `docs/zig.md`) |
| ~~`Shell.InstalledApps` / `LaunchApp`~~ | **Done** (Shell 8/9) |
| `Shell.WriteShortcutLink` | Windows-only |
| ~~Arbitrary MIME `Clipboard.Write`~~ | **Done** (Clipboard 12/13) |
| Documents (bytes wire; full Document ops) | **Done** (`zig/host/documents` + `documents-zig` example) |
| First-class Zig `WebView` + PageOptions | **Done** (`zig/host/webview`) |
| ~~glass / game / automation Zig~~ | **Done** (HostOp 246/247 + blank-import) |

## Roadmap

1. **Phase 0** — consolidate docs + CI (this file) — Done
2. **Phase 1** — `terminal` opt-in SDK + gallery Term tab — Done
3. **Phase 2** — `sqlite` minimal Open/Execute/Query/Transaction — Done
4. **Phase 3** — watch + permissionflow — Done
5. **Phase 4** — docs/zig.md + fetch/websocket/updater — Done
6. **Phase 5** — edge FFI (apps/MIME/glass/game/automation/recent list) — Done
7. **Phase 6** — documents/webview/shortcut/gamepad/branding — Done

## Terminal ABI notes

- `HostOpTerminal = 235` (lifecycle subops), `HostOpTerminalView = 236` (BindFrameElement)
- `ZigEventTerminal = 35`: kind 1=title (*CStr), 2=exit (code), 3=bell
- Theme: 0=DarkTheme, 1=LightTheme, 2=GhosttyTheme(name)

## SQLite ABI notes

- `HostOpSQLite = 237` subops: open/close/execute/query/transaction
- Args / statement lists / results are UTF-8 JSON (plugin TS client shape)
- Query out buffer currently 256 KiB on the Zig side (dupe after host write)

## Watch / PermissionFlow ABI notes

- `HostOpWatch = 238`, `ZigEventWatch = 36` (batch JSON / done)
- `HostOpPermissionFlow = 239`, `ZigEventPermFlow = 37` (async status)
- Permission names match Go strings (`microphone`, `accessibility`, …)
- Status codes: 0 unknown, 1 not_determined, 2 denied, 3 granted

## Fetch / WebSocket / Updater ABI notes

- `HostOpFetch = 243` — sync JSON response (body as JSON base64), 16 MiB cap
- `HostOpWebSocket = 244`, `ZigEventWebSocket = 38` — open/text/binary/close
- `HostOpUpdater = 245` — check + automatic checks/downloads prefs
- `plugins/websocket.Dial` is the shared Go API for native / Zig callers

## Phase 5 edge ABI

- Shell 8/9: InstalledApps JSON, LaunchApp JSON
- Clipboard 9–13: HTML, Flush, MIME map (format→base64)
- Desktop 8: RecentDocuments JSON list
- HostOpGlass=246, HostOpGame=247, ZigEventGameUpdate/Draw=39/40
- Still Go-only: NewDocuments[T], first-class WebView type, Win shortcut API (none public), go.mod branding

## Phase 6 ABI

- `HostOpGamepad=248` — pads JSON + packed state (+ Zig Pressed/Just*/stick helpers)
- `HostOpWebView=249` — full create options (PageOptions) + destroy/focus/capture + parent/page ids; `ui` op 340
- `HostOpDocuments=250`, `ZigEventDocuments=41` — configure…focus (subops 1–23), Zig supplies window
- `Shell` subop 10 — `WriteShortcutLink` (Windows; ErrUnsupported elsewhere)

## Phase 7 — remaining desktop parity

- `WindowOptions.state_key` → Go `StateKey` (remember bounds)
- Documents `isReadOnly` / `hasConflict`
- `HostOpNetwork=251`, `ZigEventNetwork=42` — Status JSON + OnChanged
- `HostOpNowPlaying=252`, `ZigEventNowPlaying=43` — Set/Clear/Info/SetPlayback/OnCommand

## Phase 8 — Element queries, hooks, menus

- Fixed the dispatcher: opcodes >= 302 (drag, video, toast, routes, gradients,
  bitmap, canvas, motion) were sent to the generated-modifier switch and
  aborted the frame. `isGeneratedModifier` now confines uigen to 100..301.
- 37 Element queries/hooks at opcodes 360..396: focus, press/click, state,
  geometry (Rect through `CQuery.num_val3/4`), scroll, text, drag, shortcuts,
  `focusGroup`, `keyShortcuts`.
- `CQuery` grew `num_val3`, `num_val4`, `int_val2` (host and SDK together).
- Menus: JSON gained `tooltip`, `subtitle`, `iconPng`, `iconTemplate`;
  `mygo.MenuItem` + `menuJSON` build the wire in Zig, with
  `Desktop.setAppMenu` / `Desktop.setDockMenu` / `Tray.setMenu`.
- Still Go-only: `OnTextKey` (its `TextKey` needs the live editor),
  `HandleTextInput` (IME client), `ObserveInput`/`HandleInput`, `HitTest`.

## Phase 9 — input hooks, scroll, motion, masks

- Input: `observeInput`, `handleInput`, `hitTest` over `ZigEventUIInput=44`
  and `ZigEventUIHitTest=45`, with `sdk/abi.zig` mirroring `CUIInput`/`CUIHit`
  and a new `ui.InputEvent` (kind, key, physical key, code, mods, text, caret,
  pointer, pressure, scroll, zoom, selection).
- Scroll: `scrollSnap`, `scrollIntoView(block, inline, smooth)`,
  `droppedFiles(buf, out)`, `fileDragOver`.
- Motion: `transition(TransitionOptions)` and
  `contentTransition(ContentTransitionOptions)`; presets reuse `zigAnim`.
- Masks: `maskLinearGradient`, `maskRadialGradient`, `maskConicGradient`.
- Widget: `Context.checkboxState` (off / on / mixed).
- `Key` gained `f1`..`f12`; `flushQueryInto` is public for generated helpers.

Still Go-only, with reasons:
- `OnTextKey` / `HandleTextInput`: their `TextKey` and `TextInputClient`
  are handles into a live editor, not values.
- `Transform`, `Masks(layers)`, `Effect`: struct trees and interfaces; the SDK
  keeps the per-property equivalents (`translate`, `rotate`, `scale`, `skew`,
  `perspective`, gradient masks).
- `Timeline`, `AnimateWith`: `animateTo` covers the same curve presets.
- `Audio`, `Page.SessionState`, `App.SetWindowStateStore`, `Plugin`,
  `NewDocuments[T]`, `ui/graph`, `ui/richtext`, `plugins/loading`,
  `plugins/sfsymbols`.

## Phase 10 — session state, transforms, audio

- `Window.sessionState(buf)` saves a page's back/forward list and form fields;
  `WindowOptions.session_state` (and `PageOptions.SessionState` on the Go side)
  brings them back.
- `ui.Transform` composes translate/translate3D/scale/rotate/rotateX/rotateY/
  skew/perspective, applied by `Element.transform`.
- `mygo.Audio`: `decodeSound`, `openStream`, `Sound.play/durationMs`, and
  `Player` with play/pause/stop/close/playing/volume/pan/speed/loop/seek/
  position/duration/loop-range/onEnd (`HostOpAudio=253`, `ZigEventAudioEnd=46`).
  Decoders come from the Go shim's blank imports (audio/vorbis, audio/mp3).

## Phase 11 — masks, timelines, text keys

- `Element.masks(layers)` with gradient layers (`linear`, `radial`, `conic`),
  `MaskComposite` (add/subtract/intersect/exclude) and `MaskBox`
  (border/padding/content), op 415.
- `Element.timeline(key, TimelineOptions)` returns a `ui.Timeline` handle:
  `tween(Tween, placements)`, `label`, `durationMs`, `timeMs`, `progress`,
  `settled`, `arrived` (ops 416..419). Placements: after/with previous, at
  time, at label. The host keeps the pointers in a registry, so the handle
  is stable across frames.
- `Element.onTextKey(StatePtr, state, handler)` (op 420,
  `ZigEventUITextKey=47`): the handler sees key, mods and the input's text,
  and `TextKey.replace` writes the replacement into a host scratch buffer.
- The gallery exercises all three: a timeline-driven card with a two-layer
  mask, and a text input that uppercases on F2.

Not done, with the reason:
- `HandleTextInput` (the system IME client): feasible the same way, but it
  needs an IME test harness to be trustworthy (composition, marked ranges,
  surrogate pairs), which the repo does not have.
- `ui/richtext` / `ui/graph` hosts: these are document models (9k lines of
  rich text; a board with its own history), so a host is a port of their
  APIs, not a binding.

## Phase 12 — IME client and the node canvas

- `HandleTextInput`: `ui.TextInputClient` is a vtable of eight calls
  (`textForRange`, `selection`, `markedRange`, `replaceText`,
  `setMarkedText`, `unmarkText`, `boundsForRange`, `indexForPoint`,
  `ZigEventUITextClient=48`). The host proxies `ui.TextInputClient` one round
  trip per question; `zig/host/ui` tests the marshalling with a fake Zig side.
- `zig/host/graph` (opt-in, `HostOpGraph=255`) binds `ui/graph`:
  create / load / exportJSON / addNode / selection / actions
  (delete, group, ungroup, layout, fit, undo, redo, copy, paste, lock,
  select all) / destroy, the five callbacks (`select`, `connect`, `move`,
  `delete`, `viewport`, events 49..53) and node bodies
  (`ZigEventGraphNode=54`) built in nested frames.
- `zig/host/ui` gained `CurrentFrame`, `BindSubframe` and `SubframeInfo`, so a
  Go widget can let Zig build parts of it.
- `ui/graph` gained `RemoveSelection`, `SelectAll` and `FitContent`.
- The gallery has a Graph tab: a board from JSON, Zig node bodies, layout,
  undo/redo, grouping and JSON export.

## Phase 13 — rich text

- `zig/host/richtext` (opt-in, `HostOpRichText=256`) binds `ui/richtext`:
  create from text / Markdown / HTML / JSON / RTF, export to
  text / Markdown / HTML / JSON, `set` and `insert`,
  commands (bold, italic, underline, strikethrough, code, bullet and number
  lists, quote, code block, undo, redo), `heading`, `setAlign`,
  selection, `version`, `canUndo` / `canRedo`, destroy, and the editor view
  with label / placeholder / read-only / no-Markdown.
- The gallery has a Rich tab: commands over a Markdown document, version,
  and "Copy Markdown".
- `zig/host/richtext` tests create/export in every format, formatting by
  selection, insert, undo and selection round trips.

Still Go-only, all by design rather than by effort:
- `EditorOptions.OnLink`, `OnLinkCommand` and `TagStyle` are Go callbacks;
  the SDK takes the data options (label, placeholder, read-only, no
  Markdown).
- `ui/richtext`'s `Theme` and per-run attributes stay in Go; Zig drives the
  document, not its styling tables.

## Phase 14 — the callbacks that were still Go-only

- Rich text: `EditorOptions.OnLink`, `OnLinkCommand` and `TagStyle` are
  events now (`ZigEventRichTextLink=55`, `...LinkCommand=56`, `...Tag=57`),
  with `Doc.onLink` / `onLinkCommand` / `onTagStyle` in the SDK; a tag style
  comes back as a `ui.RichText.Style` (color, background, weight, italic,
  underline, strikethrough, radius, padding).
- `App.SetWindowStateStore`: `mygo.setWindowStateStore` owns the storage in
  Zig (`HostOpWindowStates=254`, events 58/59), JSON in and out, so windows
  with a `state_key` persist without Go-side files.
- The gallery wires all of them: link/link-command/tag callbacks on the Rich
  tab, and a Zig-backed window state store for its own window.

What stays Go-only, and why it is not a gap:
- `ui.Effect` paints a GPU effect over a content bitmap: it needs shader
  code and a bitmap-draw primitive in Zig. The glass plugin already gives
  Zig effects; a general shader effect is a renderer feature, not a binding.
- `Plugin` / `mygo.Use` is how Go packages register themselves. Zig features
  are opt-in host imports instead; there is nothing to call.
- `NewDocuments[T]` is a generic wrapper over the byte-level `Documents`
  API the SDK already has; Zig types its own content.

## Phase 15 — effects

- `Element.effect(ui.effectOf(StatePtr, state, margin, paintFn))` (op 422,
  `ZigEventUIEffect=60`): the element and its children render into a content
  bitmap, and the Zig paint function draws it with a `ui.Painter`.
- `ui.Bitmap.draw(p, rect, fit)` paints the content through the new
  `paintImageHandle` painter op, so effects can offset, scale, tile or
  overlay the element's pixels.
- The margin is fixed at registration (`EffectMargin` on the Go side), so no
  round trip happens unless the element paints.
- The gallery draws a card through an effect on the Controls tab.

## Phase 16 — the last two

- `mygo.DocumentsOf(T, cfg)` is `NewDocuments[T]` for Zig: a controller whose
  documents hold T, with `read` / `write` codecs over the byte wire, plus
  `new` / `open` / `openDialog` / `list` / `forWindow` and the full Document
  surface. `zig/examples/documents-zig` now uses it (a Note with a title
  line and a body).
- `host.Use(plugins...)` registers Go plugins from a Zig app's shim, so a
  plugin's Setup runs and its services bind; the Zig side then calls the
  feature through its zig/host package.

Both were the last items on the parity list. What stays Go is by
construction: a plugin's JavaScript service (pages call it, Zig does not)
and Go's type parameters themselves (DocumentsOf is the Zig spelling).
