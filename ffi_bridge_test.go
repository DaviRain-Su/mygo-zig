//go:build !js

package mygo

import (
	"context"
	"encoding/json/v2"
	"errors"
	"fmt"
	"testing"
)

func TestFFIRawBindAndEmit(t *testing.T) {
	w, fw := readyWindow(t, WindowOptions{})

	if err := FFIBindRaw("FFIGreeter.greet", func(ctx context.Context, argsJSON []byte) ([]byte, error) {
		var args []string
		if err := json.Unmarshal(argsJSON, &args); err != nil {
			return nil, err
		}
		cw := CallerWindow(ctx)
		if cw == nil || cw.ID() != w.ID() {
			return nil, fmt.Errorf("unexpected caller window: %v", cw)
		}
		return json.Marshal(map[string]any{
			"greeting": "Hello, " + args[0] + "!",
			"win":      cw.ID(),
		})
	}); err != nil {
		t.Fatalf("FFIBindRaw(greet): %v", err)
	}

	if err := FFIBindRaw("FFIGreeter.fail", func(ctx context.Context, argsJSON []byte) ([]byte, error) {
		return nil, errors.New("boom")
	}); err != nil {
		t.Fatalf("FFIBindRaw(fail): %v", err)
	}

	reply := call(t, fw, 101, "FFIGreeter.greet", "Zig")
	if reply["ok"] != true {
		t.Fatalf("expected ok=true, got %+v", reply)
	}
	val, _ := reply["v"].(map[string]any)
	if val["greeting"] != "Hello, Zig!" || val["win"] != float64(w.ID()) {
		t.Fatalf("unexpected reply value: %+v", val)
	}

	errReply := call(t, fw, 102, "FFIGreeter.fail")
	if errReply["ok"] != false || errReply["e"] != "boom" {
		t.Fatalf("unexpected error reply: %+v", errReply)
	}

	if err := FFIEmitRaw(w, "ffi:tick", []byte(`{"n":42}`)); err != nil {
		t.Fatalf("FFIEmitRaw: %v", err)
	}
	ev := received(t, fw, func(m map[string]any) bool {
		return m["t"] == "event" && m["n"] == "ffi:tick"
	})
	payload, _ := ev["p"].(map[string]any)
	if payload["n"] != float64(42) {
		t.Fatalf("unexpected event payload: %+v", ev)
	}
}
