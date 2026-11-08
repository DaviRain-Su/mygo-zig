//go:build !js

// Package glass registers Liquid Glass / Blur / ScrollEdge materials for Zig.
//
// Import with `_ "github.com/egoist/mygo/zig/host/glass"` in Zig apps that
// use `mygo.ui` glass helpers.
package glass

import (
	"errors"

	plug "github.com/egoist/mygo/plugins/glass"
	mygoui "github.com/egoist/mygo/ui"
	"github.com/egoist/mygo/zig/host"
	zigui "github.com/egoist/mygo/zig/host/ui"
)

func init() {
	host.GlassDispatch = dispatch
}

const (
	glassMaterial   = 1 // a1=frame a2=*cGlassSpec
	glassBlur       = 2 // a1=frame a2=*cBlurSpec
	glassScrollEdge = 3 // a1=frame a2=*cScrollEdgeSpec
)

type cGlassSpec struct {
	Style       uint8
	Interactive uint8
	Native      uint8
	_           byte
	Clarity     float32
	Tint        uint32 // packed RGBA
}

type cBlurSpec struct {
	Radius  float32
	HasMask uint8
	_       [3]byte
	From    uint32
	To      uint32
	Angle   float32
}

type cScrollEdgeSpec struct {
	Hard       uint8
	Bottom     uint8
	HasBG      uint8
	_          byte
	Background uint32
}

func dispatch(op, a0, a1, a2, a3 uintptr) uintptr {
	_ = a3
	if op != host.HostOpGlass {
		host.SetError(errors.New("zighost: unknown glass op"))
		return ^uintptr(0)
	}
	switch a0 {
	case glassMaterial:
		spec := host.PtrTo[cGlassSpec](a2)
		if spec == nil {
			host.SetError(errors.New("zighost: glass needs spec"))
			return ^uintptr(0)
		}
		g := plug.Glass{
			Style:       plug.Style(spec.Style),
			Tint:        unpack(spec.Tint),
			Interactive: spec.Interactive != 0,
			Native:      spec.Native != 0,
			Clarity:     spec.Clarity,
		}
		if !zigui.BindFrameModifier(a1, func(e mygoui.Element) mygoui.Element {
			return e.Material(g)
		}) {
			return ^uintptr(0)
		}
		return 0
	case glassBlur:
		spec := host.PtrTo[cBlurSpec](a2)
		if spec == nil {
			host.SetError(errors.New("zighost: blur needs spec"))
			return ^uintptr(0)
		}
		b := plug.Blur{Radius: spec.Radius}
		if spec.HasMask != 0 {
			b.Mask = &mygoui.LinearGradient{
				From:  unpack(spec.From),
				To:    unpack(spec.To),
				Angle: spec.Angle,
			}
		}
		if !zigui.BindFrameModifier(a1, func(e mygoui.Element) mygoui.Element {
			return e.Material(b)
		}) {
			return ^uintptr(0)
		}
		return 0
	case glassScrollEdge:
		spec := host.PtrTo[cScrollEdgeSpec](a2)
		if spec == nil {
			host.SetError(errors.New("zighost: scrollEdge needs spec"))
			return ^uintptr(0)
		}
		e := plug.ScrollEdge{Hard: spec.Hard != 0, Bottom: spec.Bottom != 0}
		if spec.HasBG != 0 {
			e.Background = unpack(spec.Background)
		}
		if !zigui.BindFrameModifier(a1, func(e0 mygoui.Element) mygoui.Element {
			return e0.Material(e)
		}) {
			return ^uintptr(0)
		}
		return 0
	default:
		host.SetError(errors.New("zighost: unknown glass subop"))
		return ^uintptr(0)
	}
}

func unpack(c uint32) mygoui.Color {
	return mygoui.Color{
		R: uint8(c >> 24),
		G: uint8(c >> 16),
		B: uint8(c >> 8),
		A: uint8(c),
	}
}
