//go:build !js

package host

import (
	"encoding/json"
	"errors"
	"runtime"
	"unsafe"

	"github.com/egoist/mygo"
)

// WindowStates sub-ops of HostOpWindowStates.
const (
	WindowStatesRegister uintptr = 1 // a1=load cb, a2=save cb
)

// windowStateStore asks Zig for the saved window states, as JSON.
type windowStateStore struct {
	// ask fills buf with JSON and returns its length, or 0 for none.
	ask func(buf []byte) uintptr
	// put receives the states as JSON.
	put func(json []byte)
}

func (s windowStateStore) LoadWindowStates() (map[string]mygo.WindowState, error) {
	if s.ask == nil {
		return nil, nil
	}
	buf := make([]byte, 1<<20)
	got := s.ask(buf)
	if got == 0 || got == ^uintptr(0) || got > uintptr(len(buf)) {
		return nil, nil
	}
	var states map[string]mygo.WindowState
	if err := json.Unmarshal(buf[:got], &states); err != nil {
		return nil, err
	}
	return states, nil
}

func (s windowStateStore) SaveWindowStates(states map[string]mygo.WindowState) error {
	if s.put == nil {
		return nil
	}
	raw, err := json.Marshal(states)
	if err != nil {
		return err
	}
	s.put(raw)
	return nil
}

func hostWindowStates(sub, a1, a2, a3 uintptr) uintptr {
	switch sub {
	case WindowStatesRegister:
		store := windowStateStore{}
		if a1 != 0 && activeCall != nil {
			cb := a1
			store.ask = func(buf []byte) uintptr {
				return activeCall(ZigEventWindowStatesLoad, cb, uintptr(unsafe.Pointer(&buf[0])), uintptr(len(buf)), 0)
			}
		}
		if a2 != 0 && activeCall != nil {
			cb := a2
			store.put = func(raw []byte) {
				ptr, n := SliceAddr(raw)
				activeCall(ZigEventWindowStatesSave, cb, ptr, n, 0)
				runtime.KeepAlive(raw)
			}
		}
		mygo.App.SetWindowStateStore(store)
		return 0
	}
	SetError(errors.New("zighost: unknown window states subop"))
	return ^uintptr(0)
}
