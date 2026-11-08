//go:build !windows

package mygo

import "github.com/egoist/mygo/internal/platform"

func writeShortcutLink(ShortcutLinkOptions) error {
	return platform.ErrUnsupported
}
