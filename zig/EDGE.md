# Edge coverage

## Done (FFI-complete for app features)

Core desktop + opt-in hosts cover the Go public app surface Zig apps need:
windows/pages/webview, native UI, documents (bytes wire), shell/clipboard/
secrets/cookies/session/locale, tray/flyout/dialogs/notifications, power/
appearance/hotkey/screen/path, protocol, desktop/dock/jumplist/recent,
single-instance, lifecycle, **network status**, **now playing / media keys**,
gamepad, glass/game, plugins (terminal/sqlite/watch/permissionflow/fetch/
websocket/updater), window `state_key` restore, etc.

## Not a missing feature (language / product boundary)

| Item | Why Zig still has full capability |
|------|-----------------------------------|
| `Documents[T]` Go generics | Zig uses `[]byte` + own encode/decode (`documents-zig`) |
| `NowPlaying.Control(MediaPlayer)` | Go interface to `audio.Player`; Zig uses `onCommand` + `set`/`setPlayback` |
| `Channel[T]` page streams | WebView Zig apps use `bind` / `emit` / events |
| `SetWindowStateStore` custom store | Default file store via `state_key` is enough; custom Go store is rare |
| Element.DroppedFiles sugar | Covered by `dropData` / `dropMIME` (FileList) + `Window.on(.file_drop)` |
| Branding / separate go.mod site | Packaging (`zig/BRANDING.md`) |
