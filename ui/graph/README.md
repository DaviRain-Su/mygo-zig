# ui/graph — node canvas

Opt-in package: an infinite 2D world with a camera, free-positioned nodes
that host arbitrary `ui` subtrees, ports, cubic or orthogonal edges, tools
(select/drag, pan, connect), marquee multi-select, undo/redo, and a minimap.

A simplified React Flow for native MyGo UI — foundation for whiteboards,
book cards, excerpts and links.

Apps pay only when they import it (`examples/hello` stays +0).

## Quick start

```go
import "github.com/egoist/mygo/ui/graph"

board := &graph.Board{
    Camera:  graph.Camera{Zoom: 1},
    Tool:    graph.ToolSelect,
    Minimap: true,
    Nodes: []graph.Node{{
        ID: "a", Title: "Note", X: 0, Y: 0, W: 180, H: 100,
        Ports: []graph.Port{{ID: "out", Side: graph.Right}},
        Content: func(c *ui.Context) { ui.Text(c, "body") },
    }},
}
graph.View(c, board).Fill()
```

```sh
go run ./examples/node-canvas
```

## Tools & input

| Tool / gesture | Action |
| --- | --- |
| **Select (V)** | Click node/edge; drag node (moves whole selection); empty-drag marquee; Shift-click / Shift-marquee additive |
| **Pan (H)** | Drag empty canvas; middle-button pans in any tool |
| **Connect (C)** | Press a port, drag to another port |
| **O** | Toggle bezier ↔ orthogonal edges |
| Delete / Backspace | Remove selection |
| ⌘/Ctrl+A | Select all nodes |
| ⌘/Ctrl+D | Duplicate selected nodes |
| ⌘/Ctrl+Z · ⇧⌘/Ctrl+Z | Undo · Redo |
| Wheel | Pan; Ctrl/⌘+wheel or pinch zooms around the pointer |

Callbacks: `OnSelection`, `OnMove`, `OnConnect`, `OnDelete`, `OnViewport`.
Public helpers: `AddNode`, `Undo`/`Redo`, `CanUndo`/`CanRedo`.

## Architecture

- **Camera** — same idea as `plugins/game.Camera` (pan/zoom, world↔view),
  kept local so whiteboard apps do not pull in the game loop.
- **Drawing** — edges, ports, grid, marquee and minimap are painted in
  world/view space via `Camera.Draw` + `Painter` (viewport clipped).
- **Nodes** — `Absolute` cards in view space, scaled by zoom, with normal
  `ui` children in the body slot; `Dragged` moves the selection in world units.
- **Hit testing** — edges/ports use world-space geometry; node chrome uses
  the element tree so buttons inside a card keep working.
- **History** — document snapshots (nodes/edges/selection/camera); Content
  callbacks are rebound by id across undo.

## Not in this layer yet

Groups, auto-layout, edge labels, persistence formats, collaborative CRDT.
Those build on `Board` + events.
