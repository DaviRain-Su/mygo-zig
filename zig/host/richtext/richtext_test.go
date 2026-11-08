//go:build !js

package richtext

import (
	"strings"
	"testing"
	"unsafe"

	"github.com/egoist/mygo/zig/host"
)

func unsafePointer[T any](v *T) unsafe.Pointer { return unsafe.Pointer(v) }

func mustCreate(t *testing.T, kind uintptr, text string) uintptr {
	t.Helper()
	raw := []byte(text)
	ptr, n := host.SliceAddr(raw)
	spec := &CSpec{Ptr: ptr, Len: n, Kind: uint32(kind)}
	id := dispatch(host.HostOpRichText, opCreate, ptrOf(spec), 0, 0)
	if id == 0 || id == ^uintptr(0) {
		t.Fatalf("create failed: %d", id)
	}
	return id
}

func ptrOf[T any](v *T) uintptr {
	return uintptr(unsafePointer(v))
}

func exportText(t *testing.T, id, kind uintptr) string {
	t.Helper()
	buf := make([]byte, 256<<10)
	out := &COut{Ptr: uintptr(unsafePointer(&buf[0])), Cap: uintptr(len(buf))}
	n := dispatch(host.HostOpRichText, opExport, id, uintptr(unsafePointer(out)), kind)
	if n == ^uintptr(0) {
		t.Fatalf("export failed")
	}
	return string(buf[:n])
}

func TestRichTextCreateAndExport(t *testing.T) {
	id := mustCreate(t, FormatMarkdown, "# Title\n\nHello **bold**.")
	defer dispatch(host.HostOpRichText, opDestroy, id, 0, 0)

	md := exportText(t, id, FormatMarkdown)
	if !strings.Contains(md, "Title") || !strings.Contains(md, "**bold**") {
		t.Fatalf("markdown=%q", md)
	}
	html := exportText(t, id, FormatHTML)
	if !strings.Contains(html, "<h1") || !strings.Contains(html, "<b>bold</b>") {
		t.Fatalf("html=%q", html)
	}
	plain := exportText(t, id, FormatText)
	if !strings.Contains(plain, "Hello bold.") {
		t.Fatalf("text=%q", plain)
	}
	js := exportText(t, id, FormatJSON)
	if !strings.HasPrefix(js, "{") {
		t.Fatalf("json=%q", js[:min(len(js), 40)])
	}
}

func TestRichTextSetAndCommand(t *testing.T) {
	id := mustCreate(t, FormatText, "abc")
	defer dispatch(host.HostOpRichText, opDestroy, id, 0, 0)

	// Select all, toggle bold, and see it in Markdown.
	dispatch(host.HostOpRichText, opSetSelection, id, 0, 3)
	if got := dispatch(host.HostOpRichText, opCommand, id, CmdBold, 0); got != 1 {
		t.Fatalf("bold = %d", got)
	}
	if md := exportText(t, id, FormatMarkdown); !strings.Contains(md, "**abc**") {
		t.Fatalf("markdown=%q", md)
	}

	// Replace the text.
	raw := []byte("replaced")
	ptr, n := host.SliceAddr(raw)
	in := &CIn{Ptr: ptr, Len: n}
	if got := dispatch(host.HostOpRichText, opSet, id, FormatText, ptrOf(in)); got != 0 {
		t.Fatalf("set = %d", got)
	}
	if text := exportText(t, id, FormatText); text != "replaced" {
		t.Fatalf("text=%q", text)
	}

	// Typing is undoable; SetText alone is not.
	ins := []byte("!")
	ipt, ilen := host.SliceAddr(ins)
	insert := &CIn{Ptr: ipt, Len: ilen}
	dispatch(host.HostOpRichText, opInsert, id, 8, ptrOf(insert))
	if text := exportText(t, id, FormatText); text != "replaced!" {
		t.Fatalf("inserted text=%q", text)
	}
	if got := dispatch(host.HostOpRichText, opCan, id, 0, 0); got != 1 {
		t.Fatalf("canUndo = %d", got)
	}
	dispatch(host.HostOpRichText, opCommand, id, CmdUndo, 0)
	if text := exportText(t, id, FormatText); text != "replaced" {
		t.Fatalf("after undo=%q", text)
	}
}

func TestRichTextSelectionAndVersion(t *testing.T) {
	id := mustCreate(t, FormatText, "hello")
	defer dispatch(host.HostOpRichText, opDestroy, id, 0, 0)

	dispatch(host.HostOpRichText, opSetSelection, id, 1, 3)
	var sel CSel
	dispatch(host.HostOpRichText, opSelection, id, uintptr(unsafePointer(&sel)), 0)
	if sel.Anchor != 1 || sel.Caret != 3 {
		t.Fatalf("sel=%+v", sel)
	}
	if v := dispatch(host.HostOpRichText, opVersion, id, 0, 0); v == 0 {
		t.Fatal("version 0")
	}
}
