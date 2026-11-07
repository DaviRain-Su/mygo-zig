package main

import (
	"github.com/egoist/mygo/zig/host"
	_ "github.com/egoist/mygo/zig/host/ui"
)

func main() {
	host.Main("counterzig")
}
