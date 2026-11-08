//go:build !js

package host

import (
	"testing"
	"unsafe"
)

// TestABILayout pins the structs Zig reads, as sdk/tests.zig pins them from
// its side: a change in either language fails a test here.
func TestABILayout(t *testing.T) {
	cases := []struct {
		name string
		got  uintptr
		want uintptr
	}{
		{"CUIInput", unsafe.Sizeof(CUIInput{}), 88},
		{"CUIHit", unsafe.Sizeof(CUIHit{}), 24},
		{"CEffectPaint", unsafe.Sizeof(CEffectPaint{}), 40},
		{"CTextKey", unsafe.Sizeof(CTextKey{}), 48},
		{"CTextClientReq", unsafe.Sizeof(CTextClientReq{}), 104},
		{"CSpanStyle", unsafe.Sizeof(CSpanStyle{}), 28},
	}
	for _, c := range cases {
		if c.got != c.want {
			t.Errorf("%s is %d bytes, want %d (update sdk/tests.zig too)", c.name, c.got, c.want)
		}
	}

	// The fields the Zig side reads by offset.
	if got := unsafe.Offsetof(CUIInput{}.X); got != 48 {
		t.Errorf("CUIInput.X at %d, want 48", got)
	}
	if got := unsafe.Offsetof(CUIInput{}.TextPtr); got != 72 {
		t.Errorf("CUIInput.TextPtr at %d, want 72", got)
	}
	if got := unsafe.Offsetof(CEffectPaint{}.Bitmap); got != 32 {
		t.Errorf("CEffectPaint.Bitmap at %d, want 32", got)
	}
	if got := unsafe.Offsetof(CTextClientReq{}.X); got != 32 {
		t.Errorf("CTextClientReq.X at %d, want 32", got)
	}
	if got := unsafe.Offsetof(CTextClientReq{}.TextPtr); got != 64 {
		t.Errorf("CTextClientReq.TextPtr at %d, want 64", got)
	}
}
