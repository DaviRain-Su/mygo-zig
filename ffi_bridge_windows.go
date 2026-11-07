//go:build mygo_ffi && windows && (amd64 || arm64)

package mygo

import win "github.com/egoist/mygo/internal/windows"

// FFIClaimMainThread binds the calling OS thread as the Windows UI main thread.
func FFIClaimMainThread() { win.ClaimMainThread() }
