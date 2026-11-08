// Node canvas: infinite whiteboard with nodes, ports, edges and tools.
//
//	go run ./examples/node-canvas
//
// Keys: V select · H pan · C connect · O edge style · Delete · ⌘Z/⇧⌘Z undo/redo
// ⌘A select all · ⌘D duplicate · Shift-click / marquee multi-select
// Wheel pans; Ctrl/⌘+wheel or pinch zooms. Middle-drag pans any tool.
package main

import (
	"fmt"
	"log"

	"github.com/egoist/mygo"
	"github.com/egoist/mygo/ui"
	"github.com/egoist/mygo/ui/graph"
)

type app struct {
	board  *graph.Board
	status string
}

func main() {
	a := &app{
		board: &graph.Board{
			Camera:    graph.Camera{Zoom: 1},
			Tool:      graph.ToolSelect,
			EdgeStyle: graph.EdgeBezier,
			Minimap:   true,
			Nodes: []graph.Node{
				{
					ID: "note", Title: "Note", X: -120, Y: -40, W: 180, H: 110,
					Ports: []graph.Port{
						{ID: "out", Side: graph.Right, At: 0.5},
					},
					Content: func(c *ui.Context) {
						ui.Text(c, "A native slot —").FontSize(12)
						ui.Text(c, "buttons live here.").FontSize(12)
					},
				},
				{
					ID: "card", Title: "Excerpt", X: 140, Y: 20, W: 200, H: 120,
					Ports: []graph.Port{
						{ID: "in", Side: graph.Left, At: 0.5},
						{ID: "out", Side: graph.Right, At: 0.5},
					},
					Content: func(c *ui.Context) {
						ui.Text(c, "Connect me from Note.").FontSize(12)
					},
				},
				{
					ID: "sink", Title: "Sink", X: 420, Y: -10, W: 160, H: 90,
					Ports: []graph.Port{
						{ID: "in", Side: graph.Left, At: 0.5},
					},
				},
			},
			Edges: []graph.Edge{
				{ID: "e1", Source: "note", SourcePort: "out", Target: "card", TargetPort: "in"},
			},
		},
		status: "V select · H pan · C connect · O edges",
	}
	a.board.OnSelection = func(ids []string) {
		a.status = fmt.Sprintf("selection %v", ids)
	}
	a.board.OnConnect = func(e graph.Edge) {
		a.status = fmt.Sprintf("connected %s → %s", e.Source, e.Target)
	}
	a.board.OnMove = func(id string, x, y float32) {
		a.status = fmt.Sprintf("moved %s to %.0f,%.0f", id, x, y)
	}
	a.board.OnDelete = func(edgeIDs, nodeIDs []string) {
		a.status = fmt.Sprintf("deleted edges=%v nodes=%v", edgeIDs, nodeIDs)
	}
	mygo.App.SetName("Node Canvas")
	mygo.App.WhenReady(func() {
		mygo.NewWindow(mygo.WindowOptions{
			Title:   "Node Canvas",
			Width:   960,
			Height:  640,
			Content: ui.View(a.view),
		})
	})
	if err := mygo.App.Run(); err != nil {
		log.Fatal(err)
	}
}

func (a *app) view(c *ui.Context) {
	ui.Column(c).Fill().Children(func() {
		ui.Row(c).Height(40).Padding(0, 12).Gap(8).AlignItems(ui.Center).Background(c.Theme().Surface).Children(func() {
			toolBtn(c, a, graph.ToolSelect, "Select (V)")
			toolBtn(c, a, graph.ToolPan, "Pan (H)")
			toolBtn(c, a, graph.ToolConnect, "Connect (C)")
			style := "Bezier (O)"
			if a.board.EdgeStyle == graph.EdgeOrthogonal {
				style = "Ortho (O)"
			}
			if ui.Button(c.Key("edge-style"), style).Clicked() {
				if a.board.EdgeStyle == graph.EdgeOrthogonal {
					a.board.EdgeStyle = graph.EdgeBezier
				} else {
					a.board.EdgeStyle = graph.EdgeOrthogonal
				}
			}
			undo := ui.Button(c.Key("undo"), "Undo")
			undo.Disabled(!a.board.CanUndo())
			if undo.Clicked() {
				a.board.Undo()
			}
			redo := ui.Button(c.Key("redo"), "Redo")
			redo.Disabled(!a.board.CanRedo())
			if redo.Clicked() {
				a.board.Redo()
			}
			ui.Text(c, a.status).FontSize(12).TextColor(c.Theme().TextMuted).Grow(1)
			if ui.Button(c.Key("add"), "+ Node").Clicked() {
				addNode(a.board)
			}
		})
		graph.View(c, a.board).Grow(1).Fill()
	})
}

func addNode(b *graph.Board) {
	b.AddNode(graph.Node{
		Title: fmt.Sprintf("Card %d", len(b.Nodes)+1),
		X:     b.Camera.X + float32(len(b.Nodes)%3)*40,
		Y:     b.Camera.Y + float32(len(b.Nodes)%3)*30,
		W:     160, H: 90,
		Ports: []graph.Port{
			{ID: "in", Side: graph.Left, At: 0.5},
			{ID: "out", Side: graph.Right, At: 0.5},
		},
	})
}

func toolBtn(c *ui.Context, a *app, tool graph.Tool, label string) {
	b := ui.Button(c.Key(label), label)
	if a.board.Tool == tool {
		b.Background(c.Theme().Accent).TextColor(c.Theme().AccentText)
	}
	if b.Clicked() {
		a.board.Tool = tool
	}
}
