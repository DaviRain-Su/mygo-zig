//go:build windows

package mygo

import win "github.com/egoist/mygo/internal/windows"

func writeShortcutLink(opts ShortcutLinkOptions) error {
	return onMainValue(func() error {
		return win.WriteShortcutLink(win.ShortcutLink{
			LinkPath:    opts.LinkPath,
			Target:      opts.Target,
			Args:        append([]string(nil), opts.Args...),
			WorkingDir:  opts.WorkingDir,
			Description: opts.Description,
			IconPath:    opts.IconPath,
			IconIndex:   opts.IconIndex,
		})
	})
}
