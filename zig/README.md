# Writing MyGo Apps in Zig (`zig/` — `CGO_ENABLED=0` Purego Architecture)

Full MyGo applications—both **WebView** apps and **GPU-rendered Native UI (`package ui`)** apps—written in **Zig**, built on a **100% `CGO_ENABLED=0` `purego` host**:

- **Zero `cgo` (`CGO_ENABLED=0`)** across macOS, Linux, and Windows (`amd64` & `arm64`).
- **Single `purego.NewCallback` (`hostDispatch`)** and **single Zig symbol (`mygo_zig_entry`)** for the entire framework.
- **Zero overhead on pure-Go MyGo apps** (`+0 bytes` on `examples/hello` and `examples/counter-native`).
- **Pay-only-for-what-you-use**: WebView Zig apps (`zig/host` alone) build to a **7.1 MB** signed `.app` without linking `package ui`; Native GPU UI Zig apps (`_ "github.com/egoist/mygo/zig/host/ui"`) build to a **9.9 MB** signed `.app`.
- **Full `mygo` CLI integration out of the box**:
  - `mygo generate` synthesizes a typed `src/mygo.ts` (`mygo-runtime`) directly from Zig `comptime` function & struct reflection!
  - `mygo build` packages and codesigns `.app` + `.dmg` (macOS), `.deb` / `.tar.gz` (Linux), and NSIS installers (Windows).

## Directory layout

- `cmd/uigen/` — AST code generator parsing `ui/api_gen.go` to emit **189 `ui.Element` style & layout modifiers** for both Go (`host/ui/modifiers_gen.go`) and Zig (`sdk/element_gen.zig`).
- `host/` — Pure-Go (`CGO_ENABLED=0`) `purego` host: WebView windows, raw JSON IPC (sync & deferred async), zero-copy `@embedFile` `.rodata` frontend serving (`mygo://localhost/`), TypeScript client writer (`MYGO_GENERATE`), clipboard, menus, shell, and window events.
- `host/ui/` — Opt-in Native GPU UI plugin: 16-bit `CommandBuffer` decoder, **100,000+ row virtualized `ui.List`**, and **custom GPU vector `ui.Painter`** (`Element.Draw`).
- `sdk/mygo.zig` — Idiomatic Zig SDK (`mygo.exportApp`, `comptime` `mygo.bind` & `mygo.declareEvent`, `mygo.addEmbeddedAsset`, `Window`, `Clipboard`, `Shell`).
- `sdk/ui.zig` & `sdk/element_gen.zig` — Zero-allocation 16 KiB stack `CommandBuffer` + 8 KiB stack `PaintBuffer` for `package ui`.
- `examples/hello-zig/` — WebView + `comptime` TypeScript client (`src/mygo.ts`) + zero-copy `@embedFile` frontend (`7.1 MB` `.app`).
- `examples/counter-native-zig/` — Pure GPU Native UI showcase: rolling numeric transitions, `ui.Painter` animated vector wave, `100,000`-row virtualized `ui.List`, `Slider`, `Checkbox`, and CJK IME `TextInput` (`9.9 MB` `.app`).

## Quick start

```sh
# Regenerate the 189 Element modifiers from ui/api_gen.go:
go run ./zig/cmd/uigen

# 1. WebView app: build Zig library, generate src/mygo.ts, and package Hello Zig.app
(cd zig/examples/hello-zig && zig build -Doptimize=ReleaseSmall)
go run ./cmd/mygo generate zig/examples/hello-zig
go run ./cmd/mygo build -skip-dmg zig/examples/hello-zig

# 2. GPU Native UI app: build Zig library and package Counter Zig.app
(cd zig/examples/counter-native-zig && zig build -Doptimize=ReleaseSmall)
go run ./cmd/mygo build -skip-dmg zig/examples/counter-native-zig
```
