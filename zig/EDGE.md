# Edge coverage

## Done (FFI-complete)

| Surface | Notes |
|---------|-------|
| Documents | Full public `Document` / `Documents` ops for wire content `[]byte` (configure, new/open/dialog/list, content, save/saveAs/saveAnyway, revert, rename, moveTo, duplicate, close, setEdited/changed, state/path/name, forWindow, focus, window callback + state/reload events). |
| WebView | First-class create/destroy/focus/isDestroyed/setBackground/capture + parent/page ids; `CreateOptions` covers PageOptions (devtools, session, preload, UA, trusted origins, gestures, zoom, …); page APIs via `pageWindow()` / existing WinCtl. Place with `ui.webViewHandle`. |
| Shortcut | `Shell.WriteShortcutLink` / Zig typed + JSON (Windows `.lnk`; ErrUnsupported elsewhere). |
| Gamepad | `padsJSON` + packed `state` + Pressed/JustPressed/JustReleased/LeftStick/RightStick helpers matching Go. |
| Branding | `docs/zig.md` + `zig/BRANDING.md` for `DaviRain-Su/myzig`. |
| Phase 5 edges | apps/MIME/glass/game/automation/recent list, … |

## Not FFI (by nature of Go)

| Item | Why |
|------|-----|
| `Documents[T]` for arbitrary Go `T` | Generics + Go callbacks (`Read`/`Write`/`Snapshot`/`Equal`/`New`) are Go types. Zig apps encode/decode their own format into `[]byte` (same capability; example: `zig/examples/documents-zig`). |
| Installing a separate docs site / publishing `github.com/DaviRain-Su/myzig` module | Release/packaging step when you cut a branded tag — capability docs already in-tree. |
