# ui/graph — node canvas

Opt-in package: an infinite 2D world with a camera, free-positioned nodes
that host arbitrary `ui` subtrees, ports, cubic/orthogonal edges with
labels, nested groups, tools (select/drag, pan, connect), marquee
multi-select, snap/align/distribute, undo/redo, minimap, JSON persistence,
and layered auto-layout.

A simplified React Flow for native MyGo UI — foundation for whiteboards,
book cards, excerpts and links.

Apps pay only when they import it (`examples/hello` stays +0).

## Quick start

```go
import "github.com/egoist/mygo/ui/graph"

board := &graph.Board{
    Camera:   graph.Camera{Zoom: 1},
    Tool:     graph.ToolSelect,
    Minimap:  true,
    SnapGrid: 16,
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
| **O** | Toggle bezier ↔ orthogonal (obstacle-aware) edges |
| **G / ⇧G** | Group selected nodes/groups (nested) / ungroup |
| **L** | Auto-layout (layered) + fit |
| **F** | Fit camera to content |
| **Arrows** | Nudge selection (Shift = ×10; snaps when `SnapGrid` set) |
| **⌘C/X/V** | Copy / cut / paste selection (internal clipboard) |
| **⇧F** | Fit camera to selection |
| **⌘←↑↓→** | Align left/top/right/bottom |
| Double-click edge / **Enter** | Edit edge label in place |
| Resize handle | SE corner on selected node |
| **K** | Toggle lock on selection |
| `Node.Color` / `Locked` | Tint + lock flags (persisted) |
| Delete / Backspace | Remove selection |
| ⌘/Ctrl+A · ⌘/Ctrl+D | Select all · duplicate nodes |
| ⌘/Ctrl+Z · ⇧⌘/Ctrl+Z | Undo · Redo |
| Wheel | Pan; Ctrl/⌘+wheel or pinch zooms |

Helpers: `AddNode`, `GroupSelection`, `UngroupSelection`, `AlignSelection`,
`DistributeSelection`, `ToggleLockSelection`, `AutoLayout`, `FitCamera`/`FitSelection`,
`Export`/`Load`/`MarshalJSON`, `BindNodeContent`, `CopySelection`/`PasteClipboard`,
`Undo`/`Redo`.

## Persistence

`MarshalJSON` / `Load` persist camera, snap grid, nodes (without `Content`),
edges (including `Label`), and groups (`Parent` for nesting). After load,
reattach bodies with `BindNodeContent`.

## Architecture

- **Camera** — pan/zoom, world↔view.
- **Drawing** — grid, nested groups, routed edges/labels, ports, marquee, minimap.
- **Nodes** — Absolute cards with zoom Scale; Dragged moves the selection.
- **Routing** — orthogonal edges try alternate midlines around node AABBs.
- **History** — document snapshots; Content rebound by id across undo.

## Not yet

Collaborative CRDT, freehand ink, frames-as-nodes, OS clipboard for board JSON.
