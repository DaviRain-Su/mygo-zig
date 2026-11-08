//go:build windows && !(amd64 || arm64)

package mygo

import "github.com/egoist/mygo/internal/platform"

func writeShortcutLink(ShortcutLinkOptions) error {
	return platform.ErrUnsupported
}
