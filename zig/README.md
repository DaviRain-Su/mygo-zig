# Writing MyGo Apps in Zig (`zig/`)

Proof-of-concept bindings allowing full MyGo applications—both **WebView** apps and **GPU-rendered Native UI (`ui`)** apps—to be written in **Zig**, with zero overhead to pure-Go MyGo builds (`+0 bytes` on `examples/hello` and `examples/counter-native`, `CGO_ENABLED=0` preserved for default builds).

## Layout

- `include/mygo.h` — C99 ABI (`(ptr, len)` zero-copy slices, integer window handles, sync & deferred async IPC reply handles, UI `CommandBuffer` opcodes).
- `ffi.go`, `shell.go`, `ui.go` — Go host exports (`-tags mygo_ffi`, plus opt-in `-tags mygo_ffi_ui` so WebView-only Zig apps link none of `package ui`).
- `sdk/mygo.zig` — Idiomatic Zig SDK: `comptime`-typed `mygo.bind("Service.method", fn)` with per-call `ArenaAllocator`, typed `Window.emit` / `mygo.broadcast`, zero-copy `@embedFile` frontend serving (`mygo://localhost/`), clipboard, dialogs, menus, tray, shortcuts, and shell.
- `sdk/ui.zig` — Zero-allocation 16 KiB stack `CommandBuffer` client for `package ui`: layout containers, text, and chained style modifiers record compact binary opcodes with **0 FFI calls**, flushing only on interactive state queries (`.clicked()`, `slider`, `checkbox`, `textInput`, `shortcut`) or frame end.
- `examples/hello-zig/` — Single-binary Zig + MyGo WebView app (~7.5 MB on macOS arm64, ~7.1 MB on Linux x86_64, ~7.5 MB on Windows x86_64).
- `examples/counter-native-zig/` — Single-binary Zig + MyGo GPU-rendered Native UI app (~10.0 MB on macOS arm64, zero WebView, Metal/D3D11/OpenGL + CoreText/DirectWrite/Pango IME).

## Quick start

```sh
# 1. WebView + comptime IPC + zero-copy @embedFile frontend
cd zig/examples/hello-zig
zig build -Doptimize=ReleaseSmall run

# Cross-compile single binaries for Linux & Windows from macOS:
zig build -Dtarget=x86_64-linux-gnu -Doptimize=ReleaseSmall
zig build -Dtarget=x86_64-windows-gnu -Doptimize=ReleaseSmall

# 2. GPU-rendered Native UI counter (zero WebView)
cd ../counter-native-zig
zig build -Doptimize=ReleaseSmall run
```
