package graph

import (
	"math"
	"testing"

	"github.com/egoist/mygo/ui"
)

func TestCameraRoundTrip(t *testing.T) {
	r := ui.Rect{W: 400, H: 300}
	cam := Camera{X: 10, Y: -20, Zoom: 2}
	wx, wy := float32(50), float32(80)
	x, y := cam.ToView(r, wx, wy)
	backX, backY := cam.ToWorld(r, x, y)
	if math.Abs(float64(backX-wx)) > 1e-3 || math.Abs(float64(backY-wy)) > 1e-3 {
		t.Fatalf("round-trip %v,%v → %v,%v → %v,%v", wx, wy, x, y, backX, backY)
	}
}

func TestCameraZoomAtKeepsPoint(t *testing.T) {
	r := ui.Rect{W: 400, H: 300}
	cam := Camera{Zoom: 1}
	px, py := float32(100), float32(80)
	wx, wy := cam.ToWorld(r, px, py)
	cam.ZoomAt(r, px, py, 2)
	wx2, wy2 := cam.ToWorld(r, px, py)
	if math.Abs(float64(wx2-wx)) > 1e-3 || math.Abs(float64(wy2-wy)) > 1e-3 {
		t.Fatalf("zoom moved world under cursor from %v,%v to %v,%v", wx, wy, wx2, wy2)
	}
	if cam.Zoom != 2 {
		t.Fatalf("zoom=%v", cam.Zoom)
	}
}

func TestCameraVisible(t *testing.T) {
	r := ui.Rect{W: 200, H: 100}
	cam := Camera{X: 0, Y: 0, Zoom: 1}
	v := cam.Visible(r)
	if math.Abs(float64(v.W-200)) > 1e-3 || math.Abs(float64(v.H-100)) > 1e-3 {
		t.Fatalf("visible=%+v", v)
	}
}
