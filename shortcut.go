package mygo

import "errors"

// ShortcutLinkOptions describe a Windows .lnk file. Other platforms return
// an error that errors.Is(..., errors.ErrUnsupported).
type ShortcutLinkOptions struct {
	// LinkPath is where to write the .lnk (absolute).
	LinkPath string `json:"linkPath"`
	// Target is the file or executable the shortcut opens.
	Target string `json:"target"`
	// Args are passed to Target (Windows command-line quoting).
	Args []string `json:"args,omitempty"`
	// WorkingDir is the shortcut's start-in folder.
	WorkingDir string `json:"workingDir,omitempty"`
	// Description is the shortcut's comment.
	Description string `json:"description,omitempty"`
	// IconPath and IconIndex select an icon; empty IconPath uses Target.
	IconPath  string `json:"iconPath,omitempty"`
	IconIndex int    `json:"iconIndex,omitempty"`
}

// WriteShortcutLink creates or replaces a Windows shell link (.lnk).
func (ShellModule) WriteShortcutLink(opts ShortcutLinkOptions) error {
	needsApp("Shell.WriteShortcutLink")
	if opts.LinkPath == "" || opts.Target == "" {
		return errors.New("mygo: Shell.WriteShortcutLink needs linkPath and target")
	}
	return writeShortcutLink(opts)
}
