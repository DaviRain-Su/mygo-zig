//go:build !js

// Package game registers plugins/game.View for Zig-authored games.
//
// Import with `_ "github.com/egoist/mygo/zig/host/game"`. Zig supplies
// Update/Draw callbacks; the host runs the fixed-step loop and input.
package game

import (
	"errors"
	"unsafe"

	plug "github.com/egoist/mygo/plugins/game"
	mygoui "github.com/egoist/mygo/ui"
	"github.com/egoist/mygo/zig/host"
	zigui "github.com/egoist/mygo/zig/host/ui"
)

func init() {
	host.GameDispatch = dispatch
}

const gameView = 1 // a0=1 a1=frame a2=*cGameSpec

type cGameSpec struct {
	UpdateCb, UpdateUD uint64
	DrawCb, DrawUD     uint64
	Rate               int32
	_                  int32
}

// cGameInput is a snapshot of plug.Input for Zig (keys as bitset of common keys).
type cGameInput struct {
	KeysDown, KeysPressed, KeysReleased uint64 // bits for KeyA..KeyZ + arrows via helpers
	PointerX, PointerY                  float32
	PointerOver                         uint8
	Focused                             uint8
	Buttons                             uint8 // bit0 primary, bit1 secondary, bit2 middle
	ButtonsPressed                      uint8
	ButtonsReleased                     uint8
	_                                   byte
	WheelX, WheelY                      float32
	Width, Height                       float32
	KeyW, KeyA, KeyS, KeyD              uint8 // 1=down (WASD convenience)
	KeyLeft, KeyRight, KeyUp, KeyDown   uint8
	KeySpace, KeyEscape                 uint8
	_pad                                [2]byte
}

type cGameDraw struct {
	X, Y, W, H float32
	Alpha      float32 // 0..1
	_          float32
}

type zigGame struct {
	call               host.CallZigFn
	updateCb, updateUD uintptr
	drawCb, drawUD     uintptr
	rate               int
}

func (g *zigGame) Rate() int {
	if g.rate > 0 {
		return g.rate
	}
	return plug.Rate
}

func (g *zigGame) Update(in *plug.Input) {
	snap := packInput(in)
	g.call(host.ZigEventGameUpdate, g.updateCb, uintptr(unsafe.Pointer(&snap)), 0, g.updateUD)
}

func (g *zigGame) Draw(p *mygoui.Painter, r mygoui.Rect, alpha float64) {
	draw := cGameDraw{X: r.X, Y: r.Y, W: r.W, H: r.H, Alpha: float32(alpha)}
	zigui.WithPainter(p, func(handle uintptr) {
		g.call(host.ZigEventGameDraw, g.drawCb, handle, uintptr(unsafe.Pointer(&draw)), g.drawUD)
	})
}

func packInput(in *plug.Input) cGameInput {
	var s cGameInput
	sx, sy, over := in.Pointer()
	s.PointerX, s.PointerY = sx, sy
	if over {
		s.PointerOver = 1
	}
	if in.Focused() {
		s.Focused = 1
	}
	for b := 0; b < 3; b++ {
		bit := uint8(1 << b)
		if in.PointerDown(b) {
			s.Buttons |= bit
		}
		if in.PointerPressed(b) {
			s.ButtonsPressed |= bit
		}
		if in.PointerReleased(b) {
			s.ButtonsReleased |= bit
		}
	}
	s.WheelX, s.WheelY = in.Wheel()
	s.Width, s.Height = in.Size()
	set := func(dst *uint8, k mygoui.Key) {
		if in.Down(k) {
			*dst = 1
		}
	}
	set(&s.KeyW, mygoui.KeyW)
	set(&s.KeyA, mygoui.KeyA)
	set(&s.KeyS, mygoui.KeyS)
	set(&s.KeyD, mygoui.KeyD)
	set(&s.KeyLeft, mygoui.KeyLeft)
	set(&s.KeyRight, mygoui.KeyRight)
	set(&s.KeyUp, mygoui.KeyUp)
	set(&s.KeyDown, mygoui.KeyDown)
	set(&s.KeySpace, mygoui.KeySpace)
	set(&s.KeyEscape, mygoui.KeyEscape)
	return s
}

func dispatch(call host.CallZigFn, op, a0, a1, a2, a3 uintptr) uintptr {
	_ = a3
	if op != host.HostOpGame {
		host.SetError(errors.New("zighost: unknown game op"))
		return ^uintptr(0)
	}
	switch a0 {
	case gameView:
		spec := host.PtrTo[cGameSpec](a2)
		if spec == nil || spec.UpdateCb == 0 || spec.DrawCb == 0 {
			host.SetError(errors.New("zighost: gameView needs update and draw callbacks"))
			return ^uintptr(0)
		}
		g := &zigGame{
			call:     call,
			updateCb: uintptr(spec.UpdateCb),
			updateUD: uintptr(spec.UpdateUD),
			drawCb:   uintptr(spec.DrawCb),
			drawUD:   uintptr(spec.DrawUD),
			rate:     int(spec.Rate),
		}
		if !zigui.BindFrameElement(a1, func(c *mygoui.Context, _ int32) mygoui.Element {
			return plug.View(c, g)
		}) {
			return ^uintptr(0)
		}
		return 0
	default:
		host.SetError(errors.New("zighost: unknown game subop"))
		return ^uintptr(0)
	}
}
