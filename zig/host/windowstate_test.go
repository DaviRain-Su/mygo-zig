//go:build !js

package host

import (
	"encoding/json"
	"testing"

	"github.com/egoist/mygo"
)

func TestWindowStateStoreLoad(t *testing.T) {
	want := []byte(`{"main":{"x":10,"y":20,"width":640,"height":480,"maximized":true}}`)
	store := windowStateStore{ask: func(buf []byte) uintptr {
		copy(buf, want)
		return uintptr(len(want))
	}}
	states, err := store.LoadWindowStates()
	if err != nil {
		t.Fatal(err)
	}
	got, ok := states["main"]
	if !ok {
		t.Fatalf("states=%v", states)
	}
	if got.X != 10 || got.Width != 640 || !got.Maximized {
		t.Fatalf("state=%+v", got)
	}
}

func TestWindowStateStoreSave(t *testing.T) {
	var saved map[string]mygo.WindowState
	store := windowStateStore{put: func(raw []byte) {
		if err := json.Unmarshal(raw, &saved); err != nil {
			t.Fatal(err)
		}
	}}
	err := store.SaveWindowStates(map[string]mygo.WindowState{
		"main": {X: 1, Y: 2, Width: 300, Height: 200},
	})
	if err != nil {
		t.Fatal(err)
	}
	if saved["main"].Width != 300 {
		t.Fatalf("saved=%v", saved)
	}
}

func TestWindowStateStoreWithoutCallbacks(t *testing.T) {
	store := windowStateStore{}
	if states, err := store.LoadWindowStates(); err != nil || states != nil {
		t.Fatalf("load=%v %v", states, err)
	}
	if err := store.SaveWindowStates(nil); err != nil {
		t.Fatal(err)
	}
}
