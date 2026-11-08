# Upstream reviews

This fork merges `egoist/mygo` often. Most of what upstream does is Go-side —
platform backends, the renderer, `package ui` internals — and reaches Zig apps
for free through the host. A few changes do reach the Zig side, and this page
records each review so the next one starts where the last ended.

## The procedure

```sh
git fetch upstream
git log --reverse --oneline <last reviewed>..upstream/main
git diff --stat <last reviewed>..upstream/main
```

Then, for the commits that matter:

1. **`ui/api_gen.go`** — if it changed, `go run ./zig/cmd/uigen` and commit the
   regenerated `host/ui/modifiers_gen.go` and `sdk/element_gen.zig`. New
   exported methods also need a hand-written wrapper when they return values
   or take callbacks (see `handWrittenQueries` in `cmd/uigen/main.go`).
2. **Exported API in the packages the host binds** — `ui`, `plugins/*`,
   `internal/surface`. `git diff … -- 'ui/*.go' plugins` and look for
   `^+func [A-Z]`, `^+func (…) [A-Z]`, `^+type [A-Z]`. A new player method,
   window option or event means a host subop and an SDK function.
3. **ABI-shaped changes** — new events, window controls, menu fields. Add
   them on both sides (`zig/host/abi.go`, `zig/sdk/abi.zig`) and pin the
   layout in `zig/host/abi_test.go` and `zig/sdk/tests.zig`.
4. **Shaders** (`plugins/glass/shaders_*.go`) — recompiled libraries only;
   nothing to do unless the plugin's Go API changed.
5. Verify: `go build ./…`, `CGO_ENABLED=0 go build ./zig/...`,
   `go vet ./zig/...`, `cd zig/sdk && zig test tests.zig`,
   `go test ./zig/...`, and `zig build` the examples.

A review that needs nothing is a result too: it goes in the table.

## Ledger

| Reviewed through | What upstream did | Zig needed |
| --- | --- | --- |
| `dd14cc3a` (Ferry showcase, #1477/#1478) | A showcase entry: website assets only. | Nothing. |
| `de0966c4` (native video, #1469; APNG; Han text; terminal links) | Replaced video playback with the system's media frameworks (`ui/video`), added `ui.NewAPNGDecoder`, and grew `ui.VideoPlayer` with duration, position, seek, rate, volume, muting, looping, readiness and size. `ui/api_gen.go` unchanged. | **Synced** (`5d1d325b`): new opt-in `zig/host/video` (files, data, URLs, APNG) behind a `VideoSource` hook so no media framework links unless imported; the full player control and query surface on the element wire (`opVideoControl` codes 4–8, `opVideoQuery=423`); tests for APNG registration and release. |
| `92336637` (GPU clip chains, #1489; Tester links, #1488; automation frames, #1485) | Analytic clip reduction in `internal/gpu`; a Tester fix; `internal/surface.Automated` gained `Settle()`, which `ui` implements and `plugins/automation` calls so an out-of-sight window builds the frame a press needs. `ui/api_gen.go` unchanged; the only new exported methods are `ui.automated.Settle` and `FramePending`, internal to the plugin. | Nothing. `zig/host/automation` is a blank import of the plugin, and Zig windows are Go `ui` windows, so automation of a hidden Zig app gets the fix for free. |

## Keeping this honest

`zig/COMPLETENESS.md` says what the SDK covers; this page says how it keeps up
with upstream. When a review is done, move the range above to the newest
commit reviewed and add its row.
