package graph

import (
	"math"

	"github.com/egoist/mygo/ui"
)

// Camera looks at an infinite 2D world: the world's point X,Y shows at the
// middle of the view, Zoom times as large (0 means 1). World units are DIPs
// at a zoom of 1. Same idea as plugins/game.Camera, kept here so whiteboard
// apps do not import the game loop.
type Camera struct {
	X, Y float32
	Zoom float32
}

func (cam Camera) zoom() float32 {
	if cam.Zoom == 0 {
		return 1
	}
	return cam.Zoom
}

// Transform maps world coordinates into the view rectangle r.
func (cam Camera) Transform(r ui.Rect) ui.Transform {
	z := cam.zoom()
	return ui.Translation(-cam.X, -cam.Y).
		Then(ui.Scaling(z, z)).
		Then(ui.Translation(r.X+r.W/2, r.Y+r.H/2))
}

// Draw paints fn in world coordinates through the camera, clipped to r.
func (cam Camera) Draw(p *ui.Painter, r ui.Rect, fn func()) {
	z := cam.zoom()
	s := p.Scale()
	snap := func(v float32) float32 { return float32(math.Round(float64(v*s))) / s }
	t := ui.Scaling(z, z).Then(ui.Translation(snap(r.X+r.W/2-cam.X*z), snap(r.Y+r.H/2-cam.Y*z)))
	p.Clip(r, 0, func() { p.Transform(t, 0, 0, fn) })
}

// ToWorld returns the world point under view-local (x,y) in r.
func (cam Camera) ToWorld(r ui.Rect, x, y float32) (wx, wy float32) {
	z := cam.zoom()
	return cam.X + (x-r.W/2)/z, cam.Y + (y-r.H/2)/z
}

// ToView returns view-local coordinates of world (wx,wy) in r.
func (cam Camera) ToView(r ui.Rect, wx, wy float32) (x, y float32) {
	z := cam.zoom()
	return (wx-cam.X)*z + r.W/2, (wy-cam.Y)*z + r.H/2
}

// Visible is the axis-aligned world rectangle shown by r.
func (cam Camera) Visible(r ui.Rect) ui.Rect {
	x0, y0 := cam.ToWorld(r, 0, 0)
	x1, y1 := cam.ToWorld(r, r.W, r.H)
	if x1 < x0 {
		x0, x1 = x1, x0
	}
	if y1 < y0 {
		y0, y1 = y1, y0
	}
	return ui.Rect{X: x0, Y: y0, W: x1 - x0, H: y1 - y0}
}

// PanBy moves the camera by view-local deltas (screen space).
func (cam *Camera) PanBy(dx, dy float32) {
	z := cam.zoom()
	cam.X -= dx / z
	cam.Y -= dy / z
}

// ZoomAt zooms by factor around the view-local point (x,y) in r, keeping
// that world point under the cursor.
func (cam *Camera) ZoomAt(r ui.Rect, x, y, factor float32) {
	if factor <= 0 {
		return
	}
	wx, wy := cam.ToWorld(r, x, y)
	z := cam.zoom() * factor
	if z < 0.1 {
		z = 0.1
	}
	if z > 8 {
		z = 8
	}
	cam.Zoom = z
	// Keep (wx,wy) under (x,y).
	cam.X = wx - (x-r.W/2)/z
	cam.Y = wy - (y-r.H/2)/z
}
