//go:build js

package ui

import (
	"github.com/egoist/mygo"
	mygoui "github.com/egoist/mygo/ui"
)

func BindFrameElement(frameHandle uintptr, build func(c *mygoui.Context, winID int32) mygoui.Element) bool {
	return false
}

func BindFrameModifier(frameHandle uintptr, mod func(e mygoui.Element) mygoui.Element) bool {
	_ = frameHandle
	_ = mod
	return false
}

func WithPainter(p *mygoui.Painter, fn func(handle uintptr)) {
	_ = p
	_ = fn
}

func RegisterWebViewResolver(fn func(id int64) *mygo.WebView) { _ = fn }
