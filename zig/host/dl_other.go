//go:build !(darwin || linux || windows) || !(amd64 || arm64)

package host

import "errors"

const supported = false

func openLibrary(string) (uintptr, error)            { return 0, errors.ErrUnsupported }
func librarySymbol(uintptr, string) (uintptr, error) { return 0, errors.ErrUnsupported }
func newHostCallback(func(op, a0, a1, a2, a3 uintptr) uintptr) uintptr {
	return 0
}
func callZig(uintptr, uintptr, uintptr, uintptr, uintptr, uintptr) uintptr {
	panic("zighost: unsupported platform")
}
