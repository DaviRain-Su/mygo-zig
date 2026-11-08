package main

import (
	"github.com/egoist/mygo/zig/host"
	_ "github.com/egoist/mygo/zig/host/chart"
	_ "github.com/egoist/mygo/zig/host/editor"
	_ "github.com/egoist/mygo/zig/host/markdown"
	_ "github.com/egoist/mygo/zig/host/terminal"
	_ "github.com/egoist/mygo/zig/host/sqlite"
	_ "github.com/egoist/mygo/zig/host/watch"
	_ "github.com/egoist/mygo/zig/host/permissionflow"
	_ "github.com/egoist/mygo/zig/host/fetch"
	_ "github.com/egoist/mygo/zig/host/websocket"
	_ "github.com/egoist/mygo/zig/host/glass"
	_ "github.com/egoist/mygo/zig/host/gamepad"
	_ "github.com/egoist/mygo/zig/host/webview"
	_ "github.com/egoist/mygo/zig/host/graph"
	_ "github.com/egoist/mygo/zig/host/richtext"
	_ "github.com/egoist/mygo/zig/host/ui"
)

func main() {
	host.Main("galleryzig")
}
