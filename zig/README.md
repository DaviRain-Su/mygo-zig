# Writing MyGo Apps in Zig (`zig/` — `CGO_ENABLED=0` Purego Architecture)

Full MyGo applications—both **WebView** apps and **GPU-rendered Native UI (`package ui`)** apps—written in **Zig**, built on a **100% `CGO_ENABLED=0` `purego` host**:

- **Zero `cgo` (`CGO_ENABLED=0`)** across macOS, Linux, and Windows (`amd64` & `arm64`).
- **Single `purego.NewCallback` (`hostDispatch`)** and **single Zig symbol (`mygo_zig_entry`)** for the entire framework.
- **Zero overhead on pure-Go MyGo apps** (`+0 bytes` on `examples/hello` and `examples/counter-native`).
- **Pay-only-for-what-you-use**: WebView Zig apps (`zig/host` alone) build without linking `package ui`; Native GPU UI, Markdown and the code editor are separate opt-in imports.
- **Full `mygo` CLI integration**: `mygo generate` (typed `src/mygo.ts` from Zig `comptime` reflection) and `mygo build` (`.app` / `.dmg` / `.deb` / NSIS).

> Maintained on the [`DaviRain-Su/mygo`](https://github.com/DaviRain-Su/mygo) fork. Upstream keeps apps Go-authored (`egoist/mygo#1451`); `#1430` `package ffi` is the supported Go→native direction.

## Directory layout

| Path | Role |
|------|------|
| `cmd/build/` | One-shot `zig build` + `mygo build` for an app |
| `cmd/scaffold/` | New Native UI Zig app (`-build` packages it) |
| `cmd/uigen/` | AST codegen from `ui/api_gen.go` → **202** Element modifiers (`host/ui/modifiers_gen.go` + `sdk/element_gen.zig`), including `Align` / `BorderStyle` / `Cursor` / `Direction` |
| `host/` | Pure-Go purego host: windows, IPC, embed, clipboard, menus, shell |
| `host/ui/` | Opt-in Native GPU UI CommandBuffer (widgets below) |
| `host/markdown/` | Opt-in `ui/markdown` (`View` + `Stream`) |
| `host/editor/` | Opt-in `ui/editor` (`View` + `DiffView`) |
| `sdk/mygo.zig` | Idiomatic Zig SDK (`exportApp`, `bind`, `declareEvent`, `Window`, …) |
| `sdk/ui.zig` | Zero-alloc CommandBuffer client + rich controls |
| `sdk/element_gen.zig` | Generated style / layout / query modifiers |
| `examples/hello-zig/` | WebView + generated `src/mygo.ts` |
| `examples/counter-native-zig/` | GPU UI: numeric transition, Painter wave, 100k-row List |
| `examples/gallery-zig/` | Full widget tour (Controls / Inputs / Layout / Data / Markdown / Editor) |

## Native UI surface (Zig)

### Layout & chrome
`column` · `row` · `box` · `grid` · `scroll` · `scrollHorizontal` · `scrollBoth` · `spacer` · `divider` · `split` / `splitVertical` / `splitPercent` / `splitVerticalPercent` · `collapsible` · `accordion` / `accordionItem` · `sidebar` · `tabs` · `segmented` · `breadcrumbs` · `fieldset` · `field` · `form` · `toolbar` · `overlay` · `tree` / `treeItem` · `themed` · `router` / `routeView` / `routeMatch` / `routeParam` / `backButton` / `forwardButton`

### Controls
`button` / `primaryButton` · `checkbox` / `checkboxGroup` · `toggle` / `toggleGroup` · `switchControl` · `radio` / `radioGroup` · `slider` / `stepSlider` / `rangeSlider` · `stepper` · `numberInput` · `decimalInput` · `rating` · `textInput` / `textArea` / `editableText` / `searchField` / `autocomplete` / `tokenField` / `findBar` · `selectIndex` · `combobox` · `menuButton` / `popoverMenuButton` · `contextMenu` / `popoverMenu` (nested `MenuEntry` + submenus) · `badge` · `link` · `progress` / `meter` · `spinner` · `avatar` · `icon` · `image` · `alertDialog` · `modal` · `popover` · `toast` / `toastAction` · `richText` (+ object spans / `drawObjects`) · `webView` · `video` / `registerVideoGIF` / `registerVideoFrames` / `openVideoStream`+`pushVideoFrame` · `toastViewport` / `toastItem` · `drag` / `drop` / `dragOver` · `dragData` / `dropData` / `dataDragOver` · `dragMIME` / `dragMIMELazy` / `dropMIME` · `addToast`/`closeToast` (string Data + userdata + toast id) · motion (`after`/`animateTo`/`animatePose`/…) · `role` · `linearGradient` · `registerBitmap`/`bitmap` · `registerFont`

### Dates & color
`dateInput` · `timeInput` · `calendar` · `colorPicker` · `colorWell`

### Data
Virtualized `list` (100k+ rows) · multi-column `table` · virtualized `gridView` · hierarchical `outline` / `outlineTable` · custom `draw` + `Painter`

### Opt-in rich text & charts
`markdown` / `markdownStream` (`_ "…/zig/host/markdown"`) · `codeEditor` / `diffView` (`_ "…/zig/host/editor"`) · `lineChart` / `barChart` / `areaChart` / `pieChart` (`_ "…/zig/host/chart"`)

### 202 Element modifiers (generated)
padding, gap, grow, border, radius, fonts, `tooltip`, `cursor`, `direction`, `justify` / `alignItems`, queries (`clicked` / `hovered` / …), shortcuts, `draggable`, …

### Scaffold

```sh
go run ./zig/cmd/scaffold myapp          # → zig/examples/myapp-zig
go run ./zig/cmd/scaffold -dir ./apps/x demo
```

### Solving the remaining edges

| Gap | Zig solution |
|-----|--------------|
| Custom / streaming video | `openVideoStream` → `pushVideoFrame` → `video` (HostOps 232–234). Decode in Zig (or another process) and push RGBA; host never calls Zig from the decode goroutine. |
| Toast `Data any` | Cross-FFI: UTF-8 `data` string + opaque `userdata` (`usize`). Host stores `ZigToastData{Text,User}`; `toastItem` returns both; `addToast` also returns the toast id. |

File-backed formats (mp4/webm) stay out of core: decode externally, push frames.

### Window / a11y (upstream sync)
`Window.setInputRegion` · Element `role(.status/.log/.alert/…)` (ARIA live status from #1462)

### Motion & timing (now bound)
`after` · `animationFrame` · `disableAnimations` · `invalidate` · `closeToast` · `animate` / `animateTo` / `spring` · `arrived` · `animateColor` · `animatePose` (`AnimPreset`: custom/smooth/snappy/bouncy)

### Roadmap to "complete"

| Track | Status | Notes |
|-------|--------|-------|
| Widgets / chrome / data | Done | Gallery covers Controls→Editor |
| Drag / toast / video / routes | Done | Incl. stream push + toast userdata |
| Motion / timing | Done | Ops 322–332 |
| Painter paths / gradients | Done | paths + `fillLinearGradient` / `pathFillLinearGradient` / element `linearGradient` |
| Bitmap / Canvas / Fonts | Bitmap+Font done | `registerBitmap`/`bitmap`, `registerFont`; Canvas still open |
| File dialogs / tray | Open | only if/when host `mygo` exposes them to Zig |
| DX: CI + one-shot build | Done | `.github/workflows/zig.yml`; `go run ./zig/cmd/build <app>`; `scaffold -build` |
| Standalone module path | Open | `mygo-zig` go.mod branding / docs site |

## Quick start

```sh
# Regenerate Element modifiers from ui/api_gen.go:
go run ./zig/cmd/uigen

# 1. WebView
(cd zig/examples/hello-zig && zig build -Doptimize=ReleaseSmall)
go run ./cmd/mygo generate zig/examples/hello-zig
go run ./cmd/mygo build -skip-dmg zig/examples/hello-zig

# 2. GPU Native UI (counter)
(cd zig/examples/counter-native-zig && zig build -Doptimize=ReleaseSmall)
go run ./cmd/mygo build -skip-dmg zig/examples/counter-native-zig

# 3. Widget gallery (one-shot)
go run ./zig/cmd/build zig/examples/gallery-zig
open zig/examples/gallery-zig/dist/darwin-arm64/Gallery\ Zig.app
```

## Linking opt-in features

```go
package main

import (
	"github.com/egoist/mygo/zig/host"
	_ "github.com/egoist/mygo/zig/host/ui"       // Native GPU UI
	_ "github.com/egoist/mygo/zig/host/markdown" // optional
	_ "github.com/egoist/mygo/zig/host/editor"   // optional
)

func main() { host.Main("myapp") }
```

Apps that omit `host/ui` never link `package ui`. Markdown and the editor register their own host opcodes (`200` / `210` / `211`) the same way.

## Syncing upstream

```sh
git fetch upstream && git merge upstream/main
go run ./zig/cmd/uigen   # refresh modifiers after ui/api_gen.go changes
```
