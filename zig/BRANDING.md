# Branding and the standalone module

The Zig host lives in the MyGo tree under `github.com/egoist/mygo/zig/...`, so
blank imports and upstream merges stay zero-friction. The public home for
Zig-authored MyGo apps is **[DaviRain-Su/myzig](https://github.com/DaviRain-Su/myzig)**
(formerly `mygo-zig`), where the Go module path is still
`github.com/egoist/mygo` until a release needs its own.

## Where things are

| | |
|---|---|
| Guide and API reference | [`README.md`](README.md) |
| Docs site page | [`docs/zig.md`](../docs/zig.md) |
| What is covered, and the ABI | [`COMPLETENESS.md`](COMPLETENESS.md) |
| The host's edges | [`EDGE.md`](EDGE.md) |

## Optional standalone `go.mod`

If you publish a thin module that only re-exports the Zig host — a separate
release cadence from upstream, say — it needs nothing but the re-export:

```go
module github.com/DaviRain-Su/myzig

go 1.27

require github.com/egoist/mygo v0.8.3
```

Apps then import the standalone path:

```go
import (
    "github.com/DaviRain-Su/myzig/host"
    _ "github.com/DaviRain-Su/myzig/host/ui"
)
```

…with a `replace` while the fork tracks upstream, or a published tag that
mirrors `zig/host`. Keeping the in-tree path is recommended until a separate
release is actually needed: it keeps `git merge upstream/main` a no-op for the
imports.

## Versioning

The Go module, `mygo-runtime` and `mygo-cli` share one version (`mygo.Version`,
`bun scripts/version.ts`). The Zig SDK is not versioned separately: it ships
with the tree, and an app's `build.zig` points at `../../sdk/mygo.zig`. A
standalone module would pin that same version.
