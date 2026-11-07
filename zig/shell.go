//go:build mygo_ffi && cgo && !js

package main

/*
#define MYGO_BUILDING_FFI 1
#include "include/mygo.h"

static inline void mygo_call_bytes(mygo_bytes_fn fn, mygo_chars_t ptr, size_t len, uintptr_t ud) {
	if (fn != NULL) {
		fn(ptr, len, (void*)ud);
	}
}

static inline int32_t mygo_call_window_event(
	mygo_window_event_fn fn,
	int32_t win_id,
	int32_t kind,
	mygo_chars_t payload,
	size_t len,
	uintptr_t ud
) {
	if (fn == NULL) return 0;
	return fn(win_id, kind, payload, len, (void*)ud);
}

static inline void mygo_call_menu_click(
	mygo_menu_click_fn fn,
	mygo_chars_t id_ptr,
	size_t id_len,
	int32_t win_id,
	uint8_t checked,
	uintptr_t ud
) {
	if (fn != NULL) {
		fn(id_ptr, id_len, win_id, checked, (void*)ud);
	}
}

static inline void mygo_call_ready_shell(mygo_ready_fn fn, uintptr_t ud) {
	if (fn != NULL) {
		fn((void*)ud);
	}
}

static inline void mygo_call_protocol(
	mygo_protocol_fn fn,
	int32_t win_id,
	mygo_chars_t method_ptr,
	size_t method_len,
	mygo_chars_t url_ptr,
	size_t url_len,
	uintptr_t req_handle,
	uintptr_t ud
) {
	if (fn != NULL) {
		fn(win_id, method_ptr, method_len, url_ptr, url_len, req_handle, (void*)ud);
	}
}
*/
import "C"

import (
	"bytes"
	"encoding/json/v2"
	"errors"
	"io"
	"io/fs"
	"net/http"
	"path"
	"strings"
	"sync"
	"sync/atomic"
	"time"
	"unsafe"

	"github.com/egoist/mygo"
)

func deliverBytes(fn C.mygo_bytes_fn, data []byte, ud C.uintptr_t) {
	if fn == nil {
		return
	}
	var ptr C.mygo_chars_t
	if len(data) > 0 {
		ptr = C.mygo_chars_t(unsafe.Pointer(unsafe.SliceData(data)))
	}
	C.mygo_call_bytes(fn, ptr, C.size_t(len(data)), ud)
}

//export mygo_window_hide
func mygo_window_hide(winID C.int32_t) {
	if w := mygo.WindowByID(int(winID)); w != nil {
		w.Hide()
	}
}

//export mygo_window_center
func mygo_window_center(winID C.int32_t) {
	if w := mygo.WindowByID(int(winID)); w != nil {
		w.Center()
	}
}

//export mygo_window_minimize
func mygo_window_minimize(winID C.int32_t) {
	if w := mygo.WindowByID(int(winID)); w != nil {
		w.Minimize()
	}
}

//export mygo_window_maximize
func mygo_window_maximize(winID C.int32_t) {
	if w := mygo.WindowByID(int(winID)); w != nil {
		w.Maximize()
	}
}

//export mygo_window_unmaximize
func mygo_window_unmaximize(winID C.int32_t) {
	if w := mygo.WindowByID(int(winID)); w != nil {
		w.Unmaximize()
	}
}

//export mygo_window_set_fullscreen
func mygo_window_set_fullscreen(winID C.int32_t, fullscreen C.uint8_t) {
	if w := mygo.WindowByID(int(winID)); w != nil {
		w.SetFullScreen(fullscreen != 0)
	}
}

//export mygo_window_get_bounds
func mygo_window_get_bounds(winID C.int32_t, x, y, width, height *C.int32_t) C.int32_t {
	w := mygo.WindowByID(int(winID))
	if w == nil {
		setError(errors.New("mygo: window not found"))
		return -1
	}
	b := w.Bounds()
	if x != nil {
		*x = C.int32_t(b.X)
	}
	if y != nil {
		*y = C.int32_t(b.Y)
	}
	if width != nil {
		*width = C.int32_t(b.Width)
	}
	if height != nil {
		*height = C.int32_t(b.Height)
	}
	return 0
}

//export mygo_window_set_bounds
func mygo_window_set_bounds(winID, x, y, width, height C.int32_t) {
	if w := mygo.WindowByID(int(winID)); w != nil {
		w.SetBounds(mygo.Rectangle{
			X:      int(x),
			Y:      int(y),
			Width:  int(width),
			Height: int(height),
		})
	}
}

//export mygo_window_invalidate
func mygo_window_invalidate(winID C.int32_t) {
	if w := mygo.WindowByID(int(winID)); w != nil {
		w.Invalidate()
	}
}

//export mygo_window_on_event
func mygo_window_on_event(
	winID C.int32_t,
	eventKind C.int32_t,
	callback C.mygo_window_event_fn,
	userdata unsafe.Pointer,
) C.int32_t {
	w := mygo.WindowByID(int(winID))
	if w == nil || callback == nil {
		setError(errors.New("mygo: invalid window or callback"))
		return -1
	}
	ud := C.uintptr_t(uintptr(userdata))
	fire := func(payload []byte) C.int32_t {
		var ptr C.mygo_chars_t
		if len(payload) > 0 {
			ptr = C.mygo_chars_t(unsafe.Pointer(unsafe.SliceData(payload)))
		}
		return C.mygo_call_window_event(callback, winID, eventKind, ptr, C.size_t(len(payload)), ud)
	}

	switch eventKind {
	case C.MYGO_WINDOW_EVENT_CLOSE:
		w.OnClose(func(e *mygo.CloseEvent) {
			if fire(nil) != 0 {
				e.PreventDefault()
			}
		})
	case C.MYGO_WINDOW_EVENT_CLOSED:
		w.OnClosed(func() { fire(nil) })
	case C.MYGO_WINDOW_EVENT_FOCUS:
		w.OnFocus(func() { fire(nil) })
	case C.MYGO_WINDOW_EVENT_BLUR:
		w.OnBlur(func() { fire(nil) })
	case C.MYGO_WINDOW_EVENT_RESIZE:
		w.OnResize(func() {
			b := w.Bounds()
			raw, _ := json.Marshal(struct {
				Width  int `json:"width"`
				Height int `json:"height"`
			}{b.Width, b.Height})
			fire(raw)
		})
	case C.MYGO_WINDOW_EVENT_FILE_DROP:
		w.OnFileDrop(func(e *mygo.FileDropEvent) {
			raw, _ := json.Marshal(e)
			fire(raw)
		})
	default:
		setError(errors.New("mygo: unknown window event kind"))
		return -1
	}
	setError(nil)
	return 0
}

//export mygo_clipboard_read_text
func mygo_clipboard_read_text(out C.mygo_bytes_fn, userdata unsafe.Pointer) {
	text := mygo.Clipboard.ReadText()
	deliverBytes(out, []byte(text), C.uintptr_t(uintptr(userdata)))
}

//export mygo_clipboard_write_text
func mygo_clipboard_write_text(textPtr C.mygo_chars_t, textLen C.size_t) {
	mygo.Clipboard.WriteText(goString(textPtr, textLen))
}

//export mygo_clipboard_clear
func mygo_clipboard_clear() {
	mygo.Clipboard.Clear()
}

type ffiFilter struct {
	Name       string   `json:"name"`
	Extensions []string `json:"extensions"`
	MIMETypes  []string `json:"mimeTypes"`
}

func decodeFilters(in []ffiFilter) []mygo.FileFilter {
	if len(in) == 0 {
		return nil
	}
	out := make([]mygo.FileFilter, len(in))
	for i, f := range in {
		out[i] = mygo.FileFilter{Name: f.Name, Extensions: f.Extensions, MIMETypes: f.MIMETypes}
	}
	return out
}

//export mygo_dialog_open
func mygo_dialog_open(optsJSON C.mygo_chars_t, optsLen C.size_t, out C.mygo_bytes_fn, userdata unsafe.Pointer) C.int32_t {
	var in struct {
		ParentID          int         `json:"parentId"`
		Title             string      `json:"title"`
		DefaultPath       string      `json:"defaultPath"`
		ButtonLabel       string      `json:"buttonLabel"`
		Message           string      `json:"message"`
		Filters           []ffiFilter `json:"filters"`
		Directory         bool        `json:"directory"`
		Multiple          bool        `json:"multiple"`
		ShowHiddenFiles   bool        `json:"showHiddenFiles"`
		CreateDirectories bool        `json:"createDirectories"`
	}
	if optsLen > 0 {
		if err := json.Unmarshal(goBytes(optsJSON, optsLen), &in); err != nil {
			setError(err)
			return -1
		}
	}
	paths, err := mygo.Dialog.Open(mygo.OpenDialogOptions{
		Parent:            mygo.WindowByID(in.ParentID),
		Title:             in.Title,
		DefaultPath:       in.DefaultPath,
		ButtonLabel:       in.ButtonLabel,
		Message:           in.Message,
		Filters:           decodeFilters(in.Filters),
		Directory:         in.Directory,
		Multiple:          in.Multiple,
		ShowHiddenFiles:   in.ShowHiddenFiles,
		CreateDirectories: in.CreateDirectories,
	})
	if err != nil {
		setError(err)
		return -1
	}
	if paths == nil {
		paths = []string{}
	}
	raw, _ := json.Marshal(paths)
	deliverBytes(out, raw, C.uintptr_t(uintptr(userdata)))
	setError(nil)
	return 0
}

//export mygo_dialog_save
func mygo_dialog_save(optsJSON C.mygo_chars_t, optsLen C.size_t, out C.mygo_bytes_fn, userdata unsafe.Pointer) C.int32_t {
	var in struct {
		ParentID          int         `json:"parentId"`
		Title             string      `json:"title"`
		DefaultPath       string      `json:"defaultPath"`
		ButtonLabel       string      `json:"buttonLabel"`
		Message           string      `json:"message"`
		NameFieldLabel    string      `json:"nameFieldLabel"`
		Filters           []ffiFilter `json:"filters"`
		ShowHiddenFiles   bool        `json:"showHiddenFiles"`
		CreateDirectories bool        `json:"createDirectories"`
	}
	if optsLen > 0 {
		if err := json.Unmarshal(goBytes(optsJSON, optsLen), &in); err != nil {
			setError(err)
			return -1
		}
	}
	chosen, err := mygo.Dialog.Save(mygo.SaveDialogOptions{
		Parent:            mygo.WindowByID(in.ParentID),
		Title:             in.Title,
		DefaultPath:       in.DefaultPath,
		ButtonLabel:       in.ButtonLabel,
		Message:           in.Message,
		NameFieldLabel:    in.NameFieldLabel,
		Filters:           decodeFilters(in.Filters),
		ShowHiddenFiles:   in.ShowHiddenFiles,
		CreateDirectories: in.CreateDirectories,
	})
	if err != nil {
		setError(err)
		return -1
	}
	deliverBytes(out, []byte(chosen), C.uintptr_t(uintptr(userdata)))
	setError(nil)
	return 0
}

//export mygo_dialog_message
func mygo_dialog_message(optsJSON C.mygo_chars_t, optsLen C.size_t, out C.mygo_bytes_fn, userdata unsafe.Pointer) C.int32_t {
	var in struct {
		ParentID           int      `json:"parentId"`
		Type               string   `json:"type"`
		Title              string   `json:"title"`
		Message            string   `json:"message"`
		Detail             string   `json:"detail"`
		Buttons            []string `json:"buttons"`
		DefaultButton      int      `json:"defaultButton"`
		CancelButton       int      `json:"cancelButton"`
		DestructiveButtons []int    `json:"destructiveButtons"`
		CheckboxLabel      string   `json:"checkboxLabel"`
		CheckboxChecked    bool     `json:"checkboxChecked"`
	}
	if optsLen > 0 {
		if err := json.Unmarshal(goBytes(optsJSON, optsLen), &in); err != nil {
			setError(err)
			return -1
		}
	}
	res, err := mygo.Dialog.Message(mygo.MessageOptions{
		Parent:             mygo.WindowByID(in.ParentID),
		Type:               mygo.MessageType(in.Type),
		Title:              in.Title,
		Message:            in.Message,
		Detail:             in.Detail,
		Buttons:            in.Buttons,
		DefaultButton:      in.DefaultButton,
		CancelButton:       in.CancelButton,
		DestructiveButtons: in.DestructiveButtons,
		CheckboxLabel:      in.CheckboxLabel,
		CheckboxChecked:    in.CheckboxChecked,
	})
	if err != nil {
		setError(err)
		return -1
	}
	raw, _ := json.Marshal(struct {
		Button          int  `json:"button"`
		CheckboxChecked bool `json:"checkboxChecked"`
	}{res.Button, res.CheckboxChecked})
	deliverBytes(out, raw, C.uintptr_t(uintptr(userdata)))
	setError(nil)
	return 0
}

type ffiMenuItem struct {
	ID          string        `json:"id"`
	Label       string        `json:"label"`
	Type        string        `json:"type"`
	Role        string        `json:"role"`
	Accelerator string        `json:"accelerator"`
	Disabled    bool          `json:"disabled"`
	Hidden      bool          `json:"hidden"`
	Checked     bool          `json:"checked"`
	ToolTip     string        `json:"toolTip"`
	Subtitle    string        `json:"subtitle"`
	Submenu     []ffiMenuItem `json:"submenu"`
}

func buildMenu(raw []byte, onClick C.mygo_menu_click_fn, ud C.uintptr_t) (*mygo.Menu, error) {
	var spec []ffiMenuItem
	if err := json.Unmarshal(raw, &spec); err != nil {
		return nil, err
	}
	var convert func(items []ffiMenuItem) []*mygo.MenuItem
	convert = func(items []ffiMenuItem) []*mygo.MenuItem {
		out := make([]*mygo.MenuItem, len(items))
		for i, it := range items {
			mi := &mygo.MenuItem{
				ID:          it.ID,
				Label:       it.Label,
				Type:        mygo.MenuItemType(it.Type),
				Role:        mygo.MenuRole(it.Role),
				Accelerator: it.Accelerator,
				Disabled:    it.Disabled,
				Hidden:      it.Hidden,
				Checked:     it.Checked,
				ToolTip:     it.ToolTip,
				Subtitle:    it.Subtitle,
				Submenu:     convert(it.Submenu),
			}
			if onClick != nil && mi.Role == "" && len(mi.Submenu) == 0 && mi.Type != mygo.MenuItemSeparator {
				idCopy := mi.ID
				if idCopy == "" {
					idCopy = mi.Label
				}
				mi.Click = func(item *mygo.MenuItem, win *mygo.Window) {
					var wid int32
					if win != nil {
						wid = int32(win.ID())
					}
					var idPtr C.mygo_chars_t
					idBytes := []byte(idCopy)
					if len(idBytes) > 0 {
						idPtr = C.mygo_chars_t(unsafe.Pointer(unsafe.SliceData(idBytes)))
					}
					var checked C.uint8_t
					if item.Checked {
						checked = 1
					}
					C.mygo_call_menu_click(onClick, idPtr, C.size_t(len(idBytes)), C.int32_t(wid), checked, ud)
				}
			}
			out[i] = mi
		}
		return out
	}
	return mygo.NewMenu(convert(spec)), nil
}

//export mygo_app_set_menu
func mygo_app_set_menu(itemsJSON C.mygo_chars_t, itemsLen C.size_t, onClick C.mygo_menu_click_fn, userdata unsafe.Pointer) C.int32_t {
	m, err := buildMenu(goBytes(itemsJSON, itemsLen), onClick, C.uintptr_t(uintptr(userdata)))
	if err != nil {
		setError(err)
		return -1
	}
	mygo.App.SetMenu(m)
	setError(nil)
	return 0
}

//export mygo_window_popup_menu
func mygo_window_popup_menu(winID C.int32_t, itemsJSON C.mygo_chars_t, itemsLen C.size_t, onClick C.mygo_menu_click_fn, userdata unsafe.Pointer) C.int32_t {
	w := mygo.WindowByID(int(winID))
	if w == nil {
		setError(errors.New("mygo: window not found"))
		return -1
	}
	m, err := buildMenu(goBytes(itemsJSON, itemsLen), onClick, C.uintptr_t(uintptr(userdata)))
	if err != nil {
		setError(err)
		return -1
	}
	m.Popup(w)
	setError(nil)
	return 0
}

var (
	traysMu    sync.Mutex
	nextTrayID int32
	trays      = map[int32]*mygo.Tray{}
)

//export mygo_tray_new
func mygo_tray_new(
	optsJSON C.mygo_chars_t,
	optsLen C.size_t,
	iconPNG C.mygo_bytes_ptr_t,
	iconLen C.size_t,
	onMenu C.mygo_menu_click_fn,
	onClick C.mygo_ready_fn,
	userdata unsafe.Pointer,
) C.int32_t {
	var in struct {
		ID             string        `json:"id"`
		IconIsTemplate bool          `json:"iconIsTemplate"`
		Title          string        `json:"title"`
		ToolTip        string        `json:"toolTip"`
		Menu           []ffiMenuItem `json:"menu"`
	}
	if optsLen > 0 {
		if err := json.Unmarshal(goBytes(optsJSON, optsLen), &in); err != nil {
			setError(err)
			return 0
		}
	}
	ud := C.uintptr_t(uintptr(userdata))
	var menu *mygo.Menu
	if len(in.Menu) > 0 {
		menuRaw, _ := json.Marshal(in.Menu)
		var err error
		menu, err = buildMenu(menuRaw, onMenu, ud)
		if err != nil {
			setError(err)
			return 0
		}
	}
	var icon []byte
	if iconPNG != nil && iconLen > 0 {
		icon = C.GoBytes(unsafe.Pointer(iconPNG), C.int(iconLen))
	}
	t, err := mygo.NewTray(mygo.TrayOptions{
		ID:             in.ID,
		Icon:           icon,
		IconIsTemplate: in.IconIsTemplate,
		Title:          in.Title,
		ToolTip:        in.ToolTip,
		Menu:           menu,
	})
	if err != nil {
		setError(err)
		return 0
	}
	if onClick != nil {
		t.OnClick(func() {
			C.mygo_call_ready_shell(onClick, ud)
		})
	}
	traysMu.Lock()
	nextTrayID++
	id := nextTrayID
	trays[id] = t
	traysMu.Unlock()
	setError(nil)
	return C.int32_t(id)
}

func lookupTray(id C.int32_t) *mygo.Tray {
	traysMu.Lock()
	defer traysMu.Unlock()
	return trays[int32(id)]
}

//export mygo_tray_set_title
func mygo_tray_set_title(trayID C.int32_t, titlePtr C.mygo_chars_t, titleLen C.size_t) {
	if t := lookupTray(trayID); t != nil {
		t.SetTitle(goString(titlePtr, titleLen))
	}
}

//export mygo_tray_set_tooltip
func mygo_tray_set_tooltip(trayID C.int32_t, tipPtr C.mygo_chars_t, tipLen C.size_t) {
	if t := lookupTray(trayID); t != nil {
		t.SetToolTip(goString(tipPtr, tipLen))
	}
}

//export mygo_tray_destroy
func mygo_tray_destroy(trayID C.int32_t) {
	traysMu.Lock()
	t := trays[int32(trayID)]
	delete(trays, int32(trayID))
	traysMu.Unlock()
	if t != nil {
		t.Destroy()
	}
}

//export mygo_shortcut_register
func mygo_shortcut_register(accPtr C.mygo_chars_t, accLen C.size_t, cb C.mygo_ready_fn, userdata unsafe.Pointer) C.int32_t {
	ud := C.uintptr_t(uintptr(userdata))
	err := mygo.GlobalShortcut.Register(goString(accPtr, accLen), func() {
		C.mygo_call_ready_shell(cb, ud)
	})
	if err != nil {
		setError(err)
		return -1
	}
	setError(nil)
	return 0
}

//export mygo_shortcut_unregister
func mygo_shortcut_unregister(accPtr C.mygo_chars_t, accLen C.size_t) {
	mygo.GlobalShortcut.Unregister(goString(accPtr, accLen))
}

//export mygo_shortcut_unregister_all
func mygo_shortcut_unregister_all() {
	mygo.GlobalShortcut.UnregisterAll()
}

//export mygo_shell_open_external
func mygo_shell_open_external(urlPtr C.mygo_chars_t, urlLen C.size_t) C.int32_t {
	if err := mygo.Shell.OpenExternal(goString(urlPtr, urlLen)); err != nil {
		setError(err)
		return -1
	}
	return 0
}

//export mygo_shell_open_path
func mygo_shell_open_path(pathPtr C.mygo_chars_t, pathLen C.size_t) C.int32_t {
	if err := mygo.Shell.OpenPath(goString(pathPtr, pathLen)); err != nil {
		setError(err)
		return -1
	}
	return 0
}

//export mygo_shell_beep
func mygo_shell_beep() {
	mygo.Shell.Beep()
}

// Zero-copy static asset fs.FS for single-binary embedded frontends.
type staticAssetsFS struct {
	once  sync.Once
	mu    sync.RWMutex
	files map[string][]byte
}

var embeddedAssets = &staticAssetsFS{files: map[string][]byte{}}

type memFile struct {
	name string
	r    *bytes.Reader
	size int64
}

func (f *memFile) Stat() (fs.FileInfo, error) { return memFileInfo{f.name, f.size}, nil }
func (f *memFile) Read(p []byte) (int, error) { return f.r.Read(p) }
func (f *memFile) Seek(offset int64, whence int) (int64, error) {
	return f.r.Seek(offset, whence)
}
func (f *memFile) Close() error { return nil }

type memFileInfo struct {
	name string
	size int64
}

func (i memFileInfo) Name() string       { return path.Base(i.name) }
func (i memFileInfo) Size() int64        { return i.size }
func (i memFileInfo) Mode() fs.FileMode  { return 0444 }
func (i memFileInfo) ModTime() time.Time { return time.Time{} }
func (i memFileInfo) IsDir() bool        { return false }
func (i memFileInfo) Sys() any           { return nil }

type dirInfo struct{ name string }

func (d dirInfo) Name() string       { return path.Base(d.name) }
func (d dirInfo) Size() int64        { return 0 }
func (d dirInfo) Mode() fs.FileMode  { return fs.ModeDir | 0555 }
func (d dirInfo) ModTime() time.Time { return time.Time{} }
func (d dirInfo) IsDir() bool        { return true }
func (d dirInfo) Sys() any           { return nil }

type memDir struct {
	name    string
	entries []fs.DirEntry
	offset  int
}

func (d *memDir) Stat() (fs.FileInfo, error) { return dirInfo{d.name}, nil }
func (d *memDir) Read([]byte) (int, error)   { return 0, io.EOF }
func (d *memDir) Close() error               { return nil }
func (d *memDir) ReadDir(n int) ([]fs.DirEntry, error) {
	if d.offset >= len(d.entries) {
		if n <= 0 {
			return nil, nil
		}
		return nil, io.EOF
	}
	if n <= 0 || d.offset+n > len(d.entries) {
		out := d.entries[d.offset:]
		d.offset = len(d.entries)
		return out, nil
	}
	out := d.entries[d.offset : d.offset+n]
	d.offset += n
	return out, nil
}

func (s *staticAssetsFS) Open(name string) (fs.File, error) {
	if !fs.ValidPath(name) {
		return nil, &fs.PathError{Op: "open", Path: name, Err: fs.ErrInvalid}
	}
	s.mu.RLock()
	defer s.mu.RUnlock()
	if data, ok := s.files[name]; ok {
		return &memFile{name: name, r: bytes.NewReader(data), size: int64(len(data))}, nil
	}
	prefix := name + "/"
	if name == "." {
		prefix = ""
	}
	seen := map[string]fs.DirEntry{}
	for k, v := range s.files {
		if prefix != "" && !strings.HasPrefix(k, prefix) {
			continue
		}
		rest := strings.TrimPrefix(k, prefix)
		if rest == "" {
			continue
		}
		if child, _, isSubDir := strings.Cut(rest, "/"); isSubDir {
			seen[child] = fs.FileInfoToDirEntry(dirInfo{child})
		} else {
			seen[rest] = fs.FileInfoToDirEntry(memFileInfo{rest, int64(len(v))})
		}
	}
	if name == "." || len(seen) > 0 {
		entries := make([]fs.DirEntry, 0, len(seen))
		for _, e := range seen {
			entries = append(entries, e)
		}
		return &memDir{name: name, entries: entries}, nil
	}
	return nil, &fs.PathError{Op: "open", Path: name, Err: fs.ErrNotExist}
}

//export mygo_frontend_add_asset
func mygo_frontend_add_asset(
	pathPtr C.mygo_chars_t,
	pathLen C.size_t,
	dataPtr C.mygo_bytes_ptr_t,
	dataLen C.size_t,
	staticLifetime C.uint8_t,
) C.int32_t {
	clean := strings.TrimPrefix(path.Clean("/"+goString(pathPtr, pathLen)), "/")
	if clean == "" || !fs.ValidPath(clean) {
		setError(errors.New("mygo: invalid asset path"))
		return -1
	}
	var slice []byte
	if dataPtr != nil && dataLen > 0 {
		if staticLifetime != 0 {
			slice = unsafe.Slice((*byte)(unsafe.Pointer(dataPtr)), int(dataLen))
		} else {
			slice = C.GoBytes(unsafe.Pointer(dataPtr), C.int(dataLen))
		}
	}
	embeddedAssets.mu.Lock()
	embeddedAssets.files[clean] = slice
	embeddedAssets.mu.Unlock()
	embeddedAssets.once.Do(func() {
		mygo.SetFrontend(embeddedAssets)
	})
	setError(nil)
	return 0
}

type protoResponse struct {
	responded   bool
	status      int
	contentType string
	body        []byte
}

var (
	nextProtoID atomic.Uintptr
	protoMu     sync.Mutex
	protoReqs   = map[uintptr]*protoResponse{}
)

//export mygo_protocol_respond
func mygo_protocol_respond(
	reqHandle C.uintptr_t,
	statusCode C.int32_t,
	ctPtr C.mygo_chars_t,
	ctLen C.size_t,
	bodyPtr C.mygo_bytes_ptr_t,
	bodyLen C.size_t,
) {
	protoMu.Lock()
	resp := protoReqs[uintptr(reqHandle)]
	protoMu.Unlock()
	if resp == nil || resp.responded {
		return
	}
	resp.responded = true
	resp.status = int(statusCode)
	resp.contentType = goString(ctPtr, ctLen)
	if bodyPtr != nil && bodyLen > 0 {
		resp.body = C.GoBytes(unsafe.Pointer(bodyPtr), C.int(bodyLen))
	}
}

//export mygo_protocol_handle
func mygo_protocol_handle(
	schemePtr C.mygo_chars_t,
	schemeLen C.size_t,
	handler C.mygo_protocol_fn,
	userdata unsafe.Pointer,
) C.int32_t {
	if handler == nil {
		setError(errors.New("mygo: protocol handler cannot be NULL"))
		return -1
	}
	scheme := goString(schemePtr, schemeLen)
	ud := C.uintptr_t(uintptr(userdata))
	err := mygo.Protocol.HandleFunc(scheme, func(w http.ResponseWriter, r *http.Request) {
		var winID int32
		if cw := mygo.CallerWindow(r.Context()); cw != nil {
			winID = int32(cw.ID())
		}
		resp := &protoResponse{status: http.StatusNotFound}
		id := nextProtoID.Add(1)
		if id == 0 {
			id = nextProtoID.Add(1)
		}
		protoMu.Lock()
		protoReqs[id] = resp
		protoMu.Unlock()
		defer func() {
			protoMu.Lock()
			delete(protoReqs, id)
			protoMu.Unlock()
		}()

		methodBytes := []byte(r.Method)
		urlBytes := []byte(r.URL.String())
		var mPtr, uPtr C.mygo_chars_t
		if len(methodBytes) > 0 {
			mPtr = C.mygo_chars_t(unsafe.Pointer(unsafe.SliceData(methodBytes)))
		}
		if len(urlBytes) > 0 {
			uPtr = C.mygo_chars_t(unsafe.Pointer(unsafe.SliceData(urlBytes)))
		}
		C.mygo_call_protocol(handler, C.int32_t(winID), mPtr, C.size_t(len(methodBytes)), uPtr, C.size_t(len(urlBytes)), C.uintptr_t(id), ud)

		if resp.contentType != "" {
			w.Header().Set("Content-Type", resp.contentType)
		}
		if resp.status <= 0 {
			resp.status = http.StatusOK
		}
		w.WriteHeader(resp.status)
		if len(resp.body) > 0 {
			_, _ = io.Copy(w, bytes.NewReader(resp.body))
		}
	})
	if err != nil {
		setError(err)
		return -1
	}
	setError(nil)
	return 0
}
