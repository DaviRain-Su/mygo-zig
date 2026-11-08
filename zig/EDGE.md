# Remaining edge coverage

After Phase 5. Goal was to close every **FFI-reachable** edge that is still
useful, and document what cannot cross FFI cleanly.

## Done (this pass)

| Item | Status |
|------|--------|
| Shell InstalledApps / LaunchApp | Done — HostOpShell 8/9 JSON |
| Clipboard HTML + Flush + MIME map | Done — subs 9–13 |
| Recent documents list | Done — DesktopRecentList |
| glass | Done — `zig/host/glass` + `Element.glass` / `glassBlur` / `scrollEdge` |
| game | Done — `zig/host/game` + `Context.gameView` |
| automation | Done — blank-import `zig/host/automation` |

## Explicitly Go-only / skip

| Item | Why |
|------|-----|
| Full `NewDocuments[T]` | Go generics + Read/Write/Window callbacks are the product |
| Windows WriteShortcutLink | No public Shell API to bind |
| First-class WebView type | Duplicate of Page window + `ui.webView` |
| Standalone docs site / go.mod rename | packaging |
| gamepad deep binding | optional follow-on under game |
