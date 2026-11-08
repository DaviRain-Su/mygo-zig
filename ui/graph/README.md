# ui/graph — node canvas

Opt-in package: an infinite 2D world with a camera, free-positioned nodes
that host arbitrary `ui` subtrees, ports, cubic/orthogonal edges with
labels, groups, tools (select/drag, pan, connect), marquee multi-select,
undo/redo, minimap, JSON persistence, and layered auto-layout.

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
| **Select (V)** | Click node/edge/group; drag selection; empty-drag marquee; Shift additive |
| **Pan (H)** | Drag empty canvas; middle-button pans in any tool |
| **Connect (C)** | Press a port, drag to another port |
| **O** | Toggle bezier ↔ orthogonal edges |
| **G / ⇧G** | Group selected nodes / ungroup |
| **L** | Auto-layout (layered) + fit |
| **F** | Fit camera to content |
| Delete / Backspace | Remove selection (group frame only, or nodes+incident edges) |
| ⌘/Ctrl+A · ⌘/Ctrl+D | Select all · duplicate nodes |
| ⌘/Ctrl+Z · ⇧⌘/Ctrl+Z | Undo · Redo |
| Wheel | Pan; Ctrl/⌘+wheel or pinch zooms |

Callbacks: `OnSelection`, `OnMove`, `OnConnect`, `OnDelete`, `OnViewport`.

Helpers: `AddNode`, `GroupSelection`, `UngroupSelection`, `AutoLayout`,
`FitCamera`, `Export`/`Load`/`MarshalJSON`, `BindNodeContent`,
`Undo`/`Redo`.

## Persistence

`MarshalJSON` / `Load` persist camera, nodes (without `Content`), edges
(including `Label`), and groups. After load, reattach bodies with
`BindNodeContent`.

## Architecture

- **Camera** — pan/zoom, world↔view (local copy of the game.Camera idea).
- **Drawing** — grid, groups, edges/labels, ports, marquee, minimap via Painter.
- **Nodes** — Absolute cards in view space with zoom Scale; Dragged moves the selection.
- **History** — document snapshots; Content rebound by id across undo.

## Not yet

Nested groups, edge routing around nodes, collaborative CRDT, auto edge labels from schema.
