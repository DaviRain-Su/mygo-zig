package main

import (
	"github.com/egoist/mygo/zig/host"
	_ "github.com/egoist/mygo/zig/host/chart"
	_ "github.com/egoist/mygo/zig/host/editor"
	_ "github.com/egoist/mygo/zig/host/markdown"
	_ "github.com/egoist/mygo/zig/host/terminal"
	_ "github.com/egoist/mygo/zig/host/ui"
)

func main() {
	host.Main("galleryzig")
}
