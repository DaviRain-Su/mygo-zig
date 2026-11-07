//go:build !js

// Package markdown registers `ui/markdown` (GFM Markdown & streaming Markdown
// views) into `zig/host`.
//
// Import with `_ "github.com/egoist/mygo/zig/host/markdown"` in Zig apps that
// render Markdown.
package markdown

import (
	mygoui "github.com/egoist/mygo/ui"
	"github.com/egoist/mygo/ui/markdown"
	"github.com/egoist/mygo/zig/host"
	zigui "github.com/egoist/mygo/zig/host/ui"
)

func init() {
	host.MarkdownDispatch = dispatchMarkdown
}

func dispatchMarkdown(frameHandle, textPtr, textLen, streaming uintptr) uintptr {
	src := host.CopyString(textPtr, textLen)
	ok := zigui.BindFrameElement(frameHandle, func(c *mygoui.Context, _ int32) mygoui.Element {
		if streaming != 0 {
			return markdown.Stream(c, src, nil)
		}
		return markdown.View(c, src, nil)
	})
	if !ok {
		return ^uintptr(0)
	}
	return 0
}
