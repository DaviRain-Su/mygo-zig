//go:build !js

package ui

import "testing"

func TestGeneratedModifierRange(t *testing.T) {
	cases := []struct {
		op   uint16
		want bool
	}{
		{99, false},
		{100, true},
		{301, true},
		{302, false}, // draggable: hand-written
		{308, false}, // video
		{321, false}, // addToast
		{340, false}, // webViewHandle
		{360, false}, // focused
		{396, false}, // inViewMargin
	}
	for _, c := range cases {
		if got := isGeneratedModifier(c.op); got != c.want {
			t.Errorf("isGeneratedModifier(%d)=%v want %v", c.op, got, c.want)
		}
	}
}
