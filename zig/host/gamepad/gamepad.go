//go:build !js

// Package gamepad registers plugins/game/gamepad for Zig.
//
// Import with `_ "github.com/egoist/mygo/zig/host/gamepad"`.
package gamepad

import (
	"encoding/json"
	"errors"

	"github.com/egoist/mygo/plugins/game/gamepad"
	"github.com/egoist/mygo/zig/host"
)

func init() {
	host.GamepadDispatch = dispatch
}

const (
	padList  = 1 // → JSON [{id,name}] via a1=out a2=cap; id is index
	padState = 2 // a1=pad_id → write *cPadState at a2
)

type cPadState struct {
	Buttons [gamepad.ButtonCount]float32
	Axes    [gamepad.AxisCount]float32
	Connected uint8
	_         [3]byte
}

func dispatch(op, a0, a1, a2, a3 uintptr) uintptr {
	_ = a3
	if op != host.HostOpGamepad {
		host.SetError(errors.New("zighost: unknown gamepad op"))
		return ^uintptr(0)
	}
	switch a0 {
	case padList:
		pads := gamepad.Pads()
		type info struct {
			ID   int    `json:"id"`
			Name string `json:"name"`
		}
		out := make([]info, len(pads))
		for i, p := range pads {
			out[i] = info{ID: i, Name: p.Name()}
		}
		raw, _ := json.Marshal(out)
		host.SetError(nil)
		return host.WriteBytesToOut(raw, a1, a2)
	case padState:
		out := host.PtrTo[cPadState](a2)
		if out == nil {
			host.SetError(errors.New("zighost: gamepad state needs out"))
			return ^uintptr(0)
		}
		pads := gamepad.Pads()
		id := int(a1)
		if id < 0 || id >= len(pads) {
			*out = cPadState{}
			host.SetError(nil)
			return 0
		}
		p := pads[id]
		s := p.State()
		*out = cPadState{Buttons: s.Buttons, Axes: s.Axes, Connected: 1}
		if !p.Connected() {
			out.Connected = 0
		}
		host.SetError(nil)
		return 0
	default:
		host.SetError(errors.New("zighost: unknown gamepad subop"))
		return ^uintptr(0)
	}
}
