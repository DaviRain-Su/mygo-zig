# Edge coverage

## Done

All previously deferred FFI-reachable edges from Phase 5–6, including:
Documents (bytes), first-class WebView, Windows `.lnk`, gamepad, branding notes.

## Remaining product choices (not missing FFI)

| Item | Note |
|------|------|
| Generic `Documents[T]` beyond `[]byte` | Zig apps use bytes + own parse |
| Standalone npm/docs deploy | packaging when you want a site |
| gamepad JustPressed helpers | doable in Zig from consecutive `state` polls |
