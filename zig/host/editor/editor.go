//go:build !js

// Package editor registers `ui/editor` (syntax-highlighted code editor and
// split/unified diff viewer) into `zig/host`.
//
// Import with `_ "github.com/egoist/mygo/zig/host/editor"` in Zig apps that
// embed code editors or diff viewers.
package editor

import (
	"strings"
	"sync"
	"unicode"

	mygoui "github.com/egoist/mygo/ui"
	"github.com/egoist/mygo/ui/editor"
	"github.com/egoist/mygo/zig/host"
	zigui "github.com/egoist/mygo/zig/host/ui"
)

func init() {
	host.EditorDispatch = dispatchEditor
}

type cEditorSpec struct {
	FileName    host.CStr
	InitialText host.CStr
	SoftWrap    uint8
	SplitLayout uint8
	_           [6]byte
}

type cEditorStats struct {
	Line       int32
	Col        int32
	LineCount  int32
	Added      int32
	Deleted    int32
	HunkCount  int32
	Modified   uint8
	ChangedNow uint8
	_          [6]byte
	TextBufPtr uintptr
	TextBufCap uintptr
	TextLen    uintptr
}

type docKey struct {
	winID int32
	name  string
}

type managedDoc struct {
	original    *editor.Buffer
	buf         *editor.Buffer
	ed          *editor.State
	diff        *editor.DiffState
	lastVersion uint64
}

var (
	docsMu sync.Mutex
	docs   = map[docKey]*managedDoc{}
)

func getOrCreateDoc(winID int32, name, initial string) *managedDoc {
	k := docKey{winID: winID, name: name}
	docsMu.Lock()
	defer docsMu.Unlock()
	if d, ok := docs[k]; ok {
		return d
	}
	orig := editor.NewBuffer(initial)
	buf := editor.NewBuffer(initial)
	if lang := editor.LanguageFor(name); lang != nil {
		orig.SetLanguage(lang)
		buf.SetLanguage(lang)
	}
	ed := &editor.State{
		Buffer:     buf,
		DiffBase:   orig,
		WrapGuides: []int{100},
	}
	ed.OnCompletion = func(r editor.CompletionRequest) {
		ed.ShowCompletions(r.Offset-len(r.Prefix), bufferWords(ed.Buffer, r.Prefix))
	}
	diff := &editor.DiffState{
		Old:           orig,
		New:           buf,
		Editable:      true,
		HunkActions:   true,
		LineSelection: true,
		Inline:        editor.DiffInlineWordAlt,
	}
	d := &managedDoc{
		original:    orig,
		buf:         buf,
		ed:          ed,
		diff:        diff,
		lastVersion: buf.Version(),
	}
	docs[k] = d
	return d
}

func bufferWords(b *editor.Buffer, prefix string) []editor.Completion {
	seen := map[string]bool{}
	var out []editor.Completion
	words := strings.FieldsFunc(b.String(), func(r rune) bool {
		return !unicode.IsLetter(r) && !unicode.IsDigit(r) && r != '_'
	})
	for _, w := range words {
		if len(w) < 3 || seen[w] || w == prefix {
			continue
		}
		seen[w] = true
		out = append(out, editor.Completion{Label: w, Kind: editor.CompletionText, Detail: "word"})
	}
	for _, kw := range []string{"const", "var", "pub", "fn", "struct", "enum", "union", "defer", "errdefer", "try", "comptime", "return"} {
		if !seen[kw] {
			out = append(out, editor.Completion{Label: kw, Kind: editor.CompletionKeyword, Detail: "keyword"})
		}
	}
	return out
}

func dispatchEditor(op, frameHandle, specAddr, statsAddr, _ uintptr) uintptr {
	spec := host.PtrTo[cEditorSpec](specAddr)
	if spec == nil {
		return ^uintptr(0)
	}
	stats := host.PtrTo[cEditorStats](statsAddr)
	fileName := host.StrField(spec.FileName)
	initial := host.StrField(spec.InitialText)

	var doc *managedDoc
	ok := zigui.BindFrameElement(frameHandle, func(c *mygoui.Context, winID int32) mygoui.Element {
		doc = getOrCreateDoc(winID, fileName, initial)
		doc.ed.SoftWrap = spec.SoftWrap != 0
		doc.diff.Wrap = spec.SoftWrap != 0
		if op == host.HostOpDiffView {
			if spec.SplitLayout != 0 {
				doc.diff.Layout = editor.DiffSplit
			} else {
				doc.diff.Layout = editor.DiffUnified
			}
			return editor.DiffView(c.Key("diff:"+fileName), doc.diff)
		}
		return editor.View(c.Key("ed:"+fileName), doc.ed)
	})
	if !ok || doc == nil {
		return ^uintptr(0)
	}

	if stats != nil {
		pos := doc.ed.CursorPos()
		added, deleted := doc.diff.Stats()
		ver := doc.buf.Version()
		changedNow := ver != doc.lastVersion
		doc.lastVersion = ver

		stats.Line = int32(pos.Line + 1)
		stats.Col = int32(pos.Col + 1)
		stats.LineCount = int32(doc.buf.LineCount())
		stats.Added = int32(added)
		stats.Deleted = int32(deleted)
		stats.HunkCount = int32(len(doc.diff.Hunks()))
		if doc.buf.Modified() {
			stats.Modified = 1
		} else {
			stats.Modified = 0
		}
		if changedNow {
			stats.ChangedNow = 1
			if stats.TextBufPtr != 0 && stats.TextBufCap > 0 {
				cur := doc.buf.String()
				n := min(len(cur), int(stats.TextBufCap))
				if n > 0 {
					copy(host.BytesView(stats.TextBufPtr, uintptr(n)), cur[:n])
				}
				stats.TextLen = uintptr(n)
			}
		} else {
			stats.ChangedNow = 0
		}
	}
	return 0
}
