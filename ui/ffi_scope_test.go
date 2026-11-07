//go:build mygo_ffi

package ui

import "testing"

func TestFFIPushPopParent(t *testing.T) {
	count := 0
	tt := NewTester(func(c *Context) {
		col := Column(c).Fill().Center().Gap(12)
		colScope, ok := FFIPushParent(c, col)
		if !ok {
			t.Fatal("FFIPushParent(col) failed")
		}
		row := Row(c).Gap(8)
		rowScope, ok := FFIPushParent(c, row)
		if !ok {
			t.Fatal("FFIPushParent(row) failed")
		}
		if PrimaryButton(c.Key("inc"), "+").Width(60).Height(36).Clicked() {
			count++
		}
		FFIPopParent(c, rowScope)
		Text(c, "footer")
		FFIPopParent(c, colScope)
	}, 240, 180)

	tt.Frame()
	// Click the centered 60x36 button inside the 240x180 window.
	tt.PressButton(0, 120, 80)
	tt.ReleaseButton(0, 120, 80)
	tt.Frame()
	if count != 1 {
		t.Fatalf("expected count=1 after click inside FFIPushParent tree, got %d", count)
	}
}
