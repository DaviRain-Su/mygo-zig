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
| Standalone docs site / go.mod branding | packaging (in-tree `docs/zig.md` Done) |
| `Shell.InstalledApps` / `LaunchApp` | heavy, rare |
| `Shell.WriteShortcutLink` | Windows-only |
| Arbitrary MIME `Clipboard.Write` | text/image/files enough |
| Full Documents / NSDocument | Go-first document apps |
| First-class Zig `WebView` type | Page + UI WebView already |
| glass / game / automation Zig | low demand or already indirect |

## Roadmap

1. **Phase 0** — consolidate docs + CI (this file) — Done
2. **Phase 1** — `terminal` opt-in SDK + gallery Term tab — Done
3. **Phase 2** — `sqlite` minimal Open/Execute/Query/Transaction — Done
4. **Phase 3** — watch + permissionflow — Done
5. **Phase 4** — docs/zig.md + fetch/websocket/updater — Done

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
