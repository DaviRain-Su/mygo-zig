//go:build !js

// Package richtext registers `ui/richtext` (the rich text editor) into
// `zig/host`.
//
// Import with `_ "github.com/egoist/mygo/zig/host/richtext"` in Zig apps
// that edit formatted text.
package richtext

import (
	"encoding/json"
	"sync"

	mygoui "github.com/egoist/mygo/ui"
	"github.com/egoist/mygo/ui/richtext"
	"github.com/egoist/mygo/zig/host"
	zigui "github.com/egoist/mygo/zig/host/ui"
)

func init() {
	host.RichTextDispatch = dispatch
}

// Sub-ops of host.HostOpRichText.
const (
	opCreate       uintptr = 1  // a1=*CSpec → doc id
	opDestroy      uintptr = 2  // a1=id
	opExport       uintptr = 3  // a1=id a2=kind a3=*COut → len
	opSet          uintptr = 4  // a1=id a2=kind a3=*CIn
	opInsert       uintptr = 5  // a1=id a2=at a3=*CIn
	opCommand      uintptr = 6  // a1=id a2=command → 0/1
	opHeading      uintptr = 7  // a1=id a2=level
	opAlign        uintptr = 8  // a1=id a2=align
	opSelection    uintptr = 9  // a1=id → anchor/caret in NumVal/NumVal2
	opSetSelection uintptr = 10 // a1=id a2=anchor a3=caret
	opVersion      uintptr = 11 // a1=id → version
	opView         uintptr = 12 // a1=frame a2=id a3=*CView
	opCan          uintptr = 13 // a1=id a2=0 undo / 1 redo → 0/1
)

// Formats of text, for create, export and set.
const (
	FormatText     uintptr = 0
	FormatMarkdown uintptr = 1
	FormatHTML     uintptr = 2
	FormatJSON     uintptr = 3
	FormatRTF      uintptr = 4
)

// Commands of opCommand.
const (
	CmdBold          uintptr = 1
	CmdItalic        uintptr = 2
	CmdUnderline     uintptr = 3
	CmdStrikethrough uintptr = 4
	CmdCode          uintptr = 5
	CmdBulletList    uintptr = 6
	CmdNumberList    uintptr = 7
	CmdQuote         uintptr = 8
	CmdCodeBlock     uintptr = 9
	CmdUndo          uintptr = 10
	CmdRedo          uintptr = 11
)

// CSpec creates a document from text of one format.
type CSpec struct {
	Ptr, Len uintptr
	Kind     uint32
	_        [4]byte
}

// CIn is text passed in for set or insert.
type CIn struct {
	Ptr, Len uintptr
}

// COut is a caller buffer.
type COut struct {
	Ptr, Cap uintptr
}

// CSel is a selection out: anchor and caret, in runes.
type CSel struct {
	Anchor, Caret int32
}

// CView is how an editor looks.
type CView struct {
	LabelPtr, LabelLen             uintptr
	PlaceholderPtr, PlaceholderLen uintptr
	// Flags: 1 read only, 2 no markdown shortcuts.
	Flags uint32
	_     [4]byte
}

type docHost struct {
	doc *richtext.Document
}

var (
	docsMu sync.Mutex
	docs   = map[uintptr]*docHost{}
	docSeq uintptr
)

func docByID(id uintptr) *docHost {
	docsMu.Lock()
	defer docsMu.Unlock()
	return docs[id]
}

func newDoc(d *richtext.Document) uintptr {
	docsMu.Lock()
	docSeq++
	id := docSeq
	docs[id] = &docHost{doc: d}
	docsMu.Unlock()
	return id
}

func textOf(format uintptr, b []byte) richtext.Text {
	switch format {
	case FormatMarkdown:
		return richtext.ParseMarkdown(string(b))
	case FormatHTML:
		return richtext.ParseHTML(string(b))
	case FormatJSON:
		var t richtext.Text
		if err := json.Unmarshal(b, &t); err != nil {
			return richtext.NewText(string(b))
		}
		return t
	case FormatRTF:
		return richtext.ParseRTF(b)
	}
	return richtext.NewText(string(b))
}

func bytesOf(t richtext.Text, format uintptr) []byte {
	switch format {
	case FormatMarkdown:
		return []byte(t.Markdown())
	case FormatHTML:
		return []byte(t.HTML())
	case FormatJSON:
		raw, err := json.Marshal(t)
		if err != nil {
			return nil
		}
		return raw
	}
	return []byte(t.String())
}

func dispatch(op, a0, a1, a2, a3 uintptr) uintptr {
	if op != host.HostOpRichText {
		return ^uintptr(0)
	}
	switch a0 {
	case opCreate:
		spec := host.PtrTo[CSpec](a1)
		if spec == nil {
			return ^uintptr(0)
		}
		t := textOf(uintptr(spec.Kind), host.CopyBytes(spec.Ptr, spec.Len))
		return newDoc(richtext.NewDocument(t))

	case opDestroy:
		docsMu.Lock()
		delete(docs, a1)
		docsMu.Unlock()
		return 0

	case opExport:
		h, out := docByID(a1), host.PtrTo[COut](a2)
		if h == nil || out == nil {
			return ^uintptr(0)
		}
		return host.WriteToOut(bytesOf(h.doc.Text(), a3), out.Ptr, out.Cap)

	case opSet:
		h, in := docByID(a1), host.PtrTo[CIn](a3)
		if h == nil || in == nil {
			return ^uintptr(0)
		}
		h.doc.SetText(textOf(a2, host.CopyBytes(in.Ptr, in.Len)))
		return 0

	case opInsert:
		h, in := docByID(a1), host.PtrTo[CIn](a3)
		if h == nil || in == nil {
			return ^uintptr(0)
		}
		h.doc.SetSelection(int(a2), int(a2))
		h.doc.InsertText(string(host.CopyBytes(in.Ptr, in.Len)))
		return 0

	case opCommand:
		h := docByID(a1)
		if h == nil {
			return 0
		}
		return runCommand(h.doc, a2)

	case opHeading:
		if h := docByID(a1); h != nil {
			h.doc.SetHeading(int(a2))
		}
		return 0

	case opAlign:
		if h := docByID(a1); h != nil {
			h.doc.SetAlign(mygoui.Align(a2))
		}
		return 0

	case opSelection:
		h, out := docByID(a1), host.PtrTo[CSel](a2)
		if h == nil || out == nil {
			return 0
		}
		anchor, caret := h.doc.Selection()
		out.Anchor = int32(anchor)
		out.Caret = int32(caret)
		return 0

	case opSetSelection:
		if h := docByID(a1); h != nil {
			h.doc.SetSelection(int(a2), int(a3))
		}
		return 0

	case opVersion:
		h := docByID(a1)
		if h == nil {
			return 0
		}
		return uintptr(h.doc.Version())

	case opCan:
		h := docByID(a1)
		if h == nil {
			return 0
		}
		if a2 == 1 && h.doc.CanRedo() {
			return 1
		}
		if a2 == 0 && h.doc.CanUndo() {
			return 1
		}
		return 0

	case opView:
		h := docByID(a2)
		if h == nil {
			return ^uintptr(0)
		}
		view := host.PtrTo[CView](a3)
		ok := zigui.BindFrameElement(a1, func(c *mygoui.Context, winID int32) mygoui.Element {
			_ = winID
			opts := richtext.EditorOptions{}
			if view != nil {
				opts.Label = host.CopyString(view.LabelPtr, view.LabelLen)
				opts.Placeholder = host.CopyString(view.PlaceholderPtr, view.PlaceholderLen)
				opts.ReadOnly = view.Flags&1 != 0
				opts.NoMarkdown = view.Flags&2 != 0
			}
			return richtext.Editor(c, h.doc, opts)
		})
		if !ok {
			return ^uintptr(0)
		}
		return 0
	}
	return ^uintptr(0)
}

func runCommand(d *richtext.Document, cmd uintptr) uintptr {
	switch cmd {
	case CmdBold:
		d.ToggleBold()
	case CmdItalic:
		d.ToggleItalic()
	case CmdUnderline:
		d.ToggleUnderline()
	case CmdStrikethrough:
		d.ToggleStrikethrough()
	case CmdCode:
		d.ToggleCode()
	case CmdBulletList:
		d.ToggleList(richtext.Bullets)
	case CmdNumberList:
		d.ToggleList(richtext.Numbers)
	case CmdQuote:
		d.ToggleQuote()
	case CmdCodeBlock:
		d.ToggleCodeBlock()
	case CmdUndo:
		d.Undo()
	case CmdRedo:
		d.Redo()
	default:
		return 0
	}
	return 1
}
