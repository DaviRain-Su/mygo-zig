# Branding / standalone module

The Zig host lives in the MyGo tree under `github.com/egoist/mygo/zig/...`
so blank-imports and upstream merges stay zero-friction. The public GitHub
home for Zig-authored apps is **[DaviRain-Su/myzig](https://github.com/DaviRain-Su/myzig)**.

## Optional standalone `go.mod`

If you publish a thin module that only re-exports the Zig host:

```go
module github.com/DaviRain-Su/myzig

go 1.22

require github.com/egoist/mygo v0.8.3
```

Apps then:

```go
import (
    "github.com/DaviRain-Su/myzig/host"
    _ "github.com/DaviRain-Su/myzig/host/ui"
)
```

…with `replace` or a published tag that mirrors `zig/host`. Keeping the
in-tree path is recommended until you need a separate release cadence.

## Docs site

In-tree guide: [`docs/zig.md`](../docs/zig.md). A standalone site can
mirror that page + `zig/COMPLETENESS.md` / `zig/EDGE.md`.
