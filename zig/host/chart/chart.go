//go:build !js

// Package chart registers `ui/chart` line/bar plots into `zig/host`.
//
// Import with `_ "github.com/egoist/mygo/zig/host/chart"` in Zig apps that
// draw charts.
package chart

import (
	"fmt"
	"math"

	mygoui "github.com/egoist/mygo/ui"
	uichart "github.com/egoist/mygo/ui/chart"
	"github.com/egoist/mygo/zig/host"
	zigui "github.com/egoist/mygo/zig/host/ui"
)

func init() {
	host.ChartDispatch = dispatchChart
}

func dispatchChart(op, frameHandle, specPtr, _, _ uintptr) uintptr {
	if specPtr == 0 {
		return ^uintptr(0)
	}
	spec := host.PtrTo[host.CChartSpec](specPtr)
	if spec == nil {
		return ^uintptr(0)
	}
	xs := copyF32(spec.XSPtr, spec.XSLen)
	ys := copyF32(spec.YSPtr, spec.YSLen)
	n := min(len(xs), len(ys))
	if n == 0 {
		n = len(ys)
		if len(xs) == 0 && n > 0 {
			xs = make([]float32, n)
			for i := range xs {
				xs[i] = float32(i)
			}
		}
	}
	if n == 0 {
		return ^uintptr(0)
	}
	xs, ys = xs[:n], ys[:n]
	color := unpackColor(spec.Color)
	height := spec.Height
	if height <= 0 {
		height = 160
	}
	showAxes := spec.Flags&1 != 0

	ok := zigui.BindFrameElement(frameHandle, func(c *mygoui.Context, _ int32) mygoui.Element {
		switch op {
		case host.HostOpBarChart:
			return barChart(c, ys, color, height, showAxes)
		default:
			return lineChart(c, xs, ys, color, height, showAxes)
		}
	})
	if !ok {
		return ^uintptr(0)
	}
	return 0
}

func lineChart(c *mygoui.Context, xs, ys []float32, color mygoui.Color, height float32, showAxes bool) mygoui.Element {
	xLo, xHi := extent32(xs)
	yLo, yHi := extent32(ys)
	xScale := uichart.NewLinear(float64(xLo), float64(xHi)).Nice(4)
	yScale := uichart.NewLinear(float64(yLo), float64(yHi)).Nice(4)
	fx := make([]float32, len(xs))
	fy := make([]float32, len(ys))
	for i := range xs {
		fx[i] = xScale.At(float64(xs[i]))
		fy[i] = yScale.At(float64(ys[i]))
	}
	axes := uichart.Axes{}
	if showAxes {
		axes.Left = yScale.Ticks(4)
		axes.Bottom = xScale.Ticks(4)
	}
	return uichart.Plot(c, axes, func(area mygoui.Element) {
		area.Draw(func(p *mygoui.Painter, r mygoui.Rect) {
			p.StrokePath(uichart.Line(r, fx, fy, uichart.CurveMonotone), 2, color)
		})
	}).Height(height).Gap(6)
}

func barChart(c *mygoui.Context, ys []float32, color mygoui.Color, height float32, showAxes bool) mygoui.Element {
	labels := make([]string, len(ys))
	vals := make([]float64, len(ys))
	for i, v := range ys {
		labels[i] = fmt.Sprintf("%d", i+1)
		vals[i] = float64(v)
	}
	_, yHi := extent32(ys)
	yLo := float64(0)
	if min32(ys) < 0 {
		yLo = float64(min32(ys))
	}
	x := uichart.NewBand(labels...).Padding(0.25, 0.1)
	y := uichart.NewLinear(yLo, float64(yHi)).Nice(4)
	axes := uichart.Axes{}
	if showAxes {
		axes.Left = y.Ticks(4)
		axes.Bottom = x.Ticks()
	}
	return uichart.Plot(c, axes, func(area mygoui.Element) {
		_ = area
		for i, v := range vals {
			uichart.Rect(c, x.Band(i), y.Span(0, v)).Background(color).Radius(3)
		}
	}).Height(height).Gap(6)
}

func copyF32(ptr, n uintptr) []float32 {
	src := host.Float32View(ptr, n)
	if len(src) == 0 {
		return nil
	}
	out := make([]float32, len(src))
	copy(out, src)
	return out
}

func extent32(vs []float32) (lo, hi float32) {
	lo, hi = float32(math.Inf(1)), float32(math.Inf(-1))
	for _, v := range vs {
		if math.IsNaN(float64(v)) {
			continue
		}
		lo, hi = min(lo, v), max(hi, v)
	}
	if !(lo <= hi) {
		return 0, 1
	}
	if lo == hi {
		if lo == 0 {
			return 0, 1
		}
		return lo * 0.9, hi * 1.1
	}
	return lo, hi
}

func min32(vs []float32) float32 {
	lo := float32(math.Inf(1))
	for _, v := range vs {
		lo = min(lo, v)
	}
	if math.IsInf(float64(lo), 1) {
		return 0
	}
	return lo
}

func unpackColor(v uint32) mygoui.Color {
	return mygoui.Color{
		R: uint8(v >> 24),
		G: uint8(v >> 16),
		B: uint8(v >> 8),
		A: uint8(v),
	}
}
