# Zig FFI completeness plan

Last updated with `main` after the batch close-out. Pure-Go apps stay +0 bytes; Zig hosts opt in via `zig/host`.

## Principle

- **Do in core Zig host**: anything already on `mygo.App` / `Window` / `Page` / `Shell` / `Clipboard` / desktop modules that is useful to Zig-authored apps and has a clear ABI.
- **Defer**: standalone docs/version branding; terminal / sqlite / websocket / updater plugins (opt-in packages later); Windows-only shortcut links; full `Documents` flow; raw `Clipboard.Write(transfer.Data)` MIME soup (text/image/files already covered).

## Status matrix

### Done (desktop + page shell)

Widgets, painter, motion, dialogs, tray, flyout, notifications, protocol, desktop/JumpList/Dock, secrets, cookies/downloads, session, auth/cert, page lifecycle, permission/window.open, locale/find, login/relaunch, context menu, ContentRules, media mute/capture/PiP, eval, zoom/UA/DevTools/print, capture PNG, PrintToPDF, Path/Screen/Hotkey, Appearance/Power, Lifecycle badge/bounce/URL schemes.

### Batch close-out (this pass)

| Batch | Surface |
|-------|---------|
| A | App hide/show/focus/state/name/version/exit/activation; OnQuit/OnReady/OnWindowAllClosed/OnWindowCreated; Region JSON + OnRegionChanged |
| B | Shell showItemInFolder/trashItem/fileIcon/typeIcon; Clipboard readFiles/writeFiles |
| C | Window chrome: size/min/max/position, resizable/closable/maximizable/minimizable/movable, alwaysOnTop/shadow/opacity/bg, ignoreMouse/flash/icon, documentEdited/representedFile, visibility getters, blur/restore/showInactive, skipTaskbar/autoHideMenuBar/activeAppearance, nativeHandle |
| D | Window events: move/show/hide/minimize/restore/maximize/unmaximize/enterFS/leaveFS/readyToShow |
| E | Page: stop/reloadIgnoringCache/loadFile/canGoBack/Forward, processIDs, themeColor, title+theme events |

### Explicitly deferred

| Item | Why |
|------|-----|
| Standalone `mygo-zig` docs site / go.mod branding | packaging, not FFI |
| `plugins/terminal` Zig binding | opt-in purego + large surface |
| sqlite / websocket / fetch / updater / automation Zig | opt-in plugins; same Model A later |
| `Shell.InstalledApps` / `LaunchApp` | heavy, niche |
| `Shell.WriteShortcutLink` | Windows-specific |
| `Clipboard.Write` arbitrary MIME | text/image/files enough for apps |
| Full Documents / NSDocument flow | Go-first; rare for Zig PoC apps |
| Nested `WebView` as first-class Zig window type | UI `WebView` widget already exists |

## ABI notes

- New AppEv subops continue after relaunch (**22+**).
- New WinCtl subops continue after printToPDF (**61+**).
- Window event kinds continue after file_drop (**7+**).
- Page event kinds continue after render_gone (**7+** title, **8+** theme color).
- ZigEventRegion = **34** for region-changed (or reuse Locale channel with JSON).
