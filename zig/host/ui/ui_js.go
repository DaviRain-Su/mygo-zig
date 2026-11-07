//go:build js

package ui

import mygoui "github.com/egoist/mygo/ui"

func BindFrameElement(frameHandle uintptr, build func(c *mygoui.Context, winID int32) mygoui.Element) bool {
	return false
}
