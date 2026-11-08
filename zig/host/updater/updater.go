//go:build !js

// Package updater registers `plugins/updater` for Zig apps.
// Import with `_ "github.com/egoist/mygo/zig/host/updater"` — that also
// calls `mygo.Use(updater.Plugin)` so background checks run.
package updater

import (
	"errors"

	"github.com/egoist/mygo"
	plug "github.com/egoist/mygo/plugins/updater"
	"github.com/egoist/mygo/zig/host"
)

func init() {
	mygo.Use(plug.Plugin)
	host.UpdaterDispatch = dispatch
}

func dispatch(op, a0, a1, a2, a3 uintptr) uintptr {
	_ = a3
	if op != host.HostOpUpdater {
		host.SetError(errors.New("zighost: unknown updater op"))
		return ^uintptr(0)
	}
	switch a0 {
	case host.UpdaterCheck:
		plug.CheckForUpdates()
		return 0
	case host.UpdaterAutomaticChecksGet:
		if plug.AutomaticChecks() {
			return 1
		}
		return 0
	case host.UpdaterAutomaticChecksSet:
		plug.SetAutomaticChecks(a1 != 0)
		return 0
	case host.UpdaterAutomaticDownloadsGet:
		if plug.AutomaticDownloads() {
			return 1
		}
		return 0
	case host.UpdaterAutomaticDownloadsSet:
		plug.SetAutomaticDownloads(a1 != 0)
		return 0
	case host.UpdaterAvailableVersion:
		return host.WriteStringToOut(plug.AvailableVersion(), a1, a2)
	default:
		host.SetError(errors.New("zighost: unknown updater subop"))
		return ^uintptr(0)
	}
}
