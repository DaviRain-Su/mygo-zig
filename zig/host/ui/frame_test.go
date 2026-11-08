//go:build !js

package ui

import (
	"testing"
	"unsafe"
)

// TestFrameInfoLayout pins the frame info Zig reads (ui.CFrameInfo), as
// sdk/tests.zig pins it from its side.
func TestFrameInfoLayout(t *testing.T) {
	if got := unsafe.Sizeof(cUIFrameInfo{}); got != 104 {
		t.Errorf("cUIFrameInfo is %d bytes, want 104 (update sdk/tests.zig too)", got)
	}
	if got := unsafe.Offsetof(cUIFrameInfo{}.NowMillis); got != 96 {
		t.Errorf("cUIFrameInfo.NowMillis at %d, want 96", got)
	}
}
