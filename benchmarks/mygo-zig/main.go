// Command mygo-zig is the Zig app of the comparison in benchmarks/run: the
// same scenes as the other frameworks' apps, written with the Zig SDK. The
// dylib is built by zig and sits beside this binary.
package main

import (
	"github.com/egoist/mygo/zig/host"
	_ "github.com/egoist/mygo/zig/host/ui"
)

func main() { host.Main("benchzig") }
