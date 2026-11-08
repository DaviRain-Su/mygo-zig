package graph

import (
	"math"

	"github.com/egoist/mygo/ui"
)

// EdgeStyle chooses how edges are drawn.
type EdgeStyle int

const (
	// EdgeBezier is a cubic curve (default).
	EdgeBezier EdgeStyle = iota
	// EdgeOrthogonal is an elbow polyline with rounded corners.
	EdgeOrthogonal
)

func cubicControls(x0, y0, x1, y1 float32) (cx0, cy0, cx1, cy1 float32) {
	dx := float32(math.Abs(float64(x1 - x0)))
	if dx < 40 {
		dx = 40
	}
	return x0 + dx*0.5, y0, x1 - dx*0.5, y1
}

func strokeCubic(p *ui.Painter, x0, y0, x1, y1 float32, c ui.Color, width float32) {
	cx0, cy0, cx1, cy1 := cubicControls(x0, y0, x1, y1)
	path := (&ui.Path{}).
		MoveTo(x0, y0).
		CubeTo(cx0, cy0, cx1, cy1, x1, y1)
	p.StrokePath(path, width, c)
}

func orthogonalPoints(x0, y0, x1, y1 float32, outSide, inSide Side) [][2]float32 {
	const stub = float32(24)
	sx, sy := x0, y0
	ex, ey := x1, y1
	switch outSide {
	case Left:
		sx = x0 - stub
	case Right:
		sx = x0 + stub
	case Top:
		sy = y0 - stub
	default:
		sy = y0 + stub
	}
	switch inSide {
	case Left:
		ex = x1 - stub
	case Right:
		ex = x1 + stub
	case Top:
		ey = y1 - stub
	default:
		ey = y1 + stub
	}
	midX := (sx + ex) / 2
	midY := (sy + ey) / 2
	horizontalOut := outSide == Left || outSide == Right
	horizontalIn := inSide == Left || inSide == Right
	if horizontalOut && horizontalIn {
		return [][2]float32{{x0, y0}, {sx, sy}, {midX, sy}, {midX, ey}, {ex, ey}, {x1, y1}}
	}
	if !horizontalOut && !horizontalIn {
		return [][2]float32{{x0, y0}, {sx, sy}, {sx, midY}, {ex, midY}, {ex, ey}, {x1, y1}}
	}
	if horizontalOut {
		return [][2]float32{{x0, y0}, {sx, sy}, {sx, ey}, {ex, ey}, {x1, y1}}
	}
	return [][2]float32{{x0, y0}, {sx, sy}, {ex, sy}, {ex, ey}, {x1, y1}}
}

func strokeOrthogonal(p *ui.Painter, pts [][2]float32, c ui.Color, width float32) {
	if len(pts) < 2 {
		return
	}
	path := &ui.Path{}
	path.MoveTo(pts[0][0], pts[0][1])
	for i := 1; i < len(pts); i++ {
		path.LineTo(pts[i][0], pts[i][1])
	}
	p.StrokePath(path, width, c)
}

func strokeEdge(p *ui.Painter, style EdgeStyle, x0, y0, x1, y1 float32, outSide, inSide Side, c ui.Color, width float32) {
	if style == EdgeOrthogonal {
		strokeOrthogonal(p, orthogonalPoints(x0, y0, x1, y1, outSide, inSide), c, width)
		return
	}
	strokeCubic(p, x0, y0, x1, y1, c, width)
}

// distToCubic approximates distance from point to the cubic by sampling.
func distToCubic(px, py, x0, y0, x1, y1 float32) float32 {
	cx0, cy0, cx1, cy1 := cubicControls(x0, y0, x1, y1)
	best := float32(math.MaxFloat32)
	const steps = 24
	for i := 0; i <= steps; i++ {
		t := float32(i) / steps
		u := 1 - t
		x := u*u*u*x0 + 3*u*u*t*cx0 + 3*u*t*t*cx1 + t*t*t*x1
		y := u*u*u*y0 + 3*u*u*t*cy0 + 3*u*t*t*cy1 + t*t*t*y1
		dx, dy := px-x, py-y
		d2 := dx*dx + dy*dy
		if d2 < best {
			best = d2
		}
	}
	return float32(math.Sqrt(float64(best)))
}

func distToPolyline(px, py float32, pts [][2]float32) float32 {
	best := float32(math.MaxFloat32)
	for i := 0; i+1 < len(pts); i++ {
		d := distToSegment(px, py, pts[i][0], pts[i][1], pts[i+1][0], pts[i+1][1])
		if d < best {
			best = d
		}
	}
	return best
}

func distToSegment(px, py, x0, y0, x1, y1 float32) float32 {
	dx, dy := x1-x0, y1-y0
	if dx == 0 && dy == 0 {
		dx2, dy2 := px-x0, py-y0
		return float32(math.Sqrt(float64(dx2*dx2 + dy2*dy2)))
	}
	t := ((px-x0)*dx + (py-y0)*dy) / (dx*dx + dy*dy)
	if t < 0 {
		t = 0
	} else if t > 1 {
		t = 1
	}
	x, y := x0+t*dx, y0+t*dy
	dx2, dy2 := px-x, py-y
	return float32(math.Sqrt(float64(dx2*dx2 + dy2*dy2)))
}

func distToEdge(style EdgeStyle, px, py, x0, y0, x1, y1 float32, outSide, inSide Side) float32 {
	if style == EdgeOrthogonal {
		return distToPolyline(px, py, orthogonalPoints(x0, y0, x1, y1, outSide, inSide))
	}
	return distToCubic(px, py, x0, y0, x1, y1)
}
