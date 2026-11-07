//go:build mygo_ffi && !(windows && (amd64 || arm64)) && !js

package mygo

// FFIClaimMainThread is a no-op on platforms where IsMainThread queries the OS
// process main thread directly (pthread_main_np on macOS, gettid == getpid on Linux).
func FFIClaimMainThread() {}
