//go:build windows && (amd64 || arm64)

package windows

import (
	"os"
	"path/filepath"
	"runtime"
	"syscall"
	"unsafe"
)

var (
	iidIPersistFile = guid("0000010b-0000-0000-c000-000000000046")
	// IPersistFile::Save is vtable index 6 (after IUnknown + GetClassID + IsDirty + Load).
	pfSave = 6
)

// ShortcutLink describes a Windows .lnk file.
type ShortcutLink struct {
	LinkPath, Target, WorkingDir, Description, IconPath string
	Args                                               []string
	IconIndex                                          int
}

// WriteShortcutLink creates a .lnk with IShellLinkW + IPersistFile.
func WriteShortcutLink(link ShortcutLink) error {
	if link.LinkPath == "" || link.Target == "" {
		return syscall.EINVAL
	}
	if err := os.MkdirAll(filepath.Dir(link.LinkPath), 0o755); err != nil {
		return err
	}
	sl, err := coCreate(clsidShellLink, iidIShellLinkW)
	if err != nil {
		return err
	}
	defer release(sl)
	if hr := comCall(sl, slSetPath, uintptr(unsafe.Pointer(u16(link.Target)))); failed(hr) {
		return hresultError("IShellLinkW::SetPath", hr)
	}
	if hr := comCall(sl, slSetArguments, uintptr(unsafe.Pointer(u16(commandLine(link.Args))))); failed(hr) {
		return hresultError("IShellLinkW::SetArguments", hr)
	}
	if link.Description != "" {
		if hr := comCall(sl, slSetDescription, uintptr(unsafe.Pointer(u16(link.Description)))); failed(hr) {
			return hresultError("IShellLinkW::SetDescription", hr)
		}
	}
	if link.WorkingDir != "" {
		if hr := comCall(sl, slSetWorkingDirectory, uintptr(unsafe.Pointer(u16(link.WorkingDir)))); failed(hr) {
			return hresultError("IShellLinkW::SetWorkingDirectory", hr)
		}
	}
	icon := link.IconPath
	if icon == "" {
		icon = link.Target
	}
	if hr := comCall(sl, slSetIconLocation, uintptr(unsafe.Pointer(u16(icon))), uintptr(link.IconIndex)); failed(hr) {
		return hresultError("IShellLinkW::SetIconLocation", hr)
	}
	pf := queryInterface(sl, &iidIPersistFile)
	if pf == 0 {
		return hresultError("IShellLinkW::QueryInterface(IPersistFile)", 0)
	}
	defer release(pf)
	path := utf16z(link.LinkPath)
	hr := comCall(pf, pfSave, uintptr(unsafe.Pointer(&path[0])), 1) // TRUE = remember
	runtime.KeepAlive(path)
	if failed(hr) {
		return hresultError("IPersistFile::Save", hr)
	}
	return nil
}
