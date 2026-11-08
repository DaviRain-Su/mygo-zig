//go:build !js && !mygo_noinspector

// Package automation blank-imports plugins/automation so Zig apps can be
// driven over MYGO_AUTOMATION when built with the inspector.
//
// Import with `_ "github.com/egoist/mygo/zig/host/automation"`.
// Release builds (`mygo_noinspector`) leave this package empty.
package automation

import _ "github.com/egoist/mygo/plugins/automation"
