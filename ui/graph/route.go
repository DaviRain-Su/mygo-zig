package graph

// obstacle is an AABB to dodge when routing orthogonal edges.
type obstacle struct {
	x0, y0, x1, y1 float32
}

func (b *Board) obstaclesExcept(src, dst string) []obstacle {
	out := make([]obstacle, 0, len(b.Nodes))
	const pad = float32(8)
	for _, n := range b.Nodes {
		if n.ID == src || n.ID == dst {
			continue
		}
		out = append(out, obstacle{
			x0: n.X - pad, y0: n.Y - pad,
			x1: n.X + n.W + pad, y1: n.Y + n.H + pad,
		})
	}
	return out
}

func segmentHits(x0, y0, x1, y1 float32, o obstacle) bool {
	// Axis-aligned segment vs AABB.
	if y0 == y1 { // horizontal
		if y0 < o.y0 || y0 > o.y1 {
			return false
		}
		lo, hi := x0, x1
		if hi < lo {
			lo, hi = hi, lo
		}
		return hi >= o.x0 && lo <= o.x1
	}
	if x0 == x1 { // vertical
		if x0 < o.x0 || x0 > o.x1 {
			return false
		}
		lo, hi := y0, y1
		if hi < lo {
			lo, hi = hi, lo
		}
		return hi >= o.y0 && lo <= o.y1
	}
	return false
}

func pathHits(pts [][2]float32, obs []obstacle) bool {
	for i := 0; i+1 < len(pts); i++ {
		for _, o := range obs {
			if segmentHits(pts[i][0], pts[i][1], pts[i+1][0], pts[i+1][1], o) {
				return true
			}
		}
	}
	return false
}

// orthogonalPointsAvoid builds an elbow path, trying alternate midlines
// when the default crosses an obstacle.
func orthogonalPointsAvoid(x0, y0, x1, y1 float32, outSide, inSide Side, obs []obstacle) [][2]float32 {
	base := orthogonalPoints(x0, y0, x1, y1, outSide, inSide)
	if len(obs) == 0 || !pathHits(base, obs) {
		return base
	}
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
	horizontalOut := outSide == Left || outSide == Right
	horizontalIn := inSide == Left || inSide == Right

	// Candidate detours: route around the bounding box of all obstacles.
	var minY, maxY, minX, maxX float32
	if len(obs) > 0 {
		minY, maxY = obs[0].y0, obs[0].y1
		minX, maxX = obs[0].x0, obs[0].x1
		for _, o := range obs[1:] {
			if o.y0 < minY {
				minY = o.y0
			}
			if o.y1 > maxY {
				maxY = o.y1
			}
			if o.x0 < minX {
				minX = o.x0
			}
			if o.x1 > maxX {
				maxX = o.x1
			}
		}
	}
	candidates := [][][2]float32{base}
	if horizontalOut && horizontalIn {
		for _, midY := range []float32{minY - 16, maxY + 16, (sy + ey) / 2} {
			candidates = append(candidates, [][2]float32{
				{x0, y0}, {sx, sy}, {sx, midY}, {ex, midY}, {ex, ey}, {x1, y1},
			})
		}
	} else if !horizontalOut && !horizontalIn {
		for _, midX := range []float32{minX - 16, maxX + 16, (sx + ex) / 2} {
			candidates = append(candidates, [][2]float32{
				{x0, y0}, {sx, sy}, {midX, sy}, {midX, ey}, {ex, ey}, {x1, y1},
			})
		}
	} else if horizontalOut {
		for _, midY := range []float32{minY - 16, maxY + 16} {
			candidates = append(candidates, [][2]float32{
				{x0, y0}, {sx, sy}, {sx, midY}, {ex, midY}, {ex, ey}, {x1, y1},
			})
		}
	} else {
		for _, midX := range []float32{minX - 16, maxX + 16} {
			candidates = append(candidates, [][2]float32{
				{x0, y0}, {sx, sy}, {midX, sy}, {midX, ey}, {ex, ey}, {x1, y1},
			})
		}
	}
	for _, c := range candidates[1:] {
		if !pathHits(c, obs) {
			return c
		}
	}
	return base
}

func (b *Board) edgePoints(e Edge, x0, y0, x1, y1 float32, outSide, inSide Side) [][2]float32 {
	if b.EdgeStyle != EdgeOrthogonal {
		return nil
	}
	obs := b.obstaclesExcept(e.Source, e.Target)
	return orthogonalPointsAvoid(x0, y0, x1, y1, outSide, inSide, obs)
}
