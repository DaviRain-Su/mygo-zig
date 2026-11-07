//go:build windows && (amd64 || arm64)

package host

import (
	"syscall"

	"github.com/ebitengine/purego"
)

const supported = true

func openLibrary(path string) (uintptr, error) {
	h, err := syscall.LoadLibrary(path)
	return uintptr(h), err
}

func librarySymbol(h uintptr, name string) (uintptr, error) {
	return syscall.GetProcAddress(syscall.Handle(h), name)
}

func newHostCallback(fn func(op, a0, a1, a2, a3 uintptr) uintptr) uintptr {
	return purego.NewCallback(fn)
}

//go:uintptrescapes
func callZig(fn uintptr, kind, a0, a1, a2, a3 uintptr) uintptr {
	r, _, _ := purego.SyscallN(fn, kind, a0, a1, a2, a3)
	return r
}
