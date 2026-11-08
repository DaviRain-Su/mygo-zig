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
