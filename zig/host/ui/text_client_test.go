//go:build !js

package ui

import (
	"testing"

	"github.com/egoist/mygo"
	mygoui "github.com/egoist/mygo/ui"
	"github.com/egoist/mygo/zig/host"
)

// fakeZig answers text-input client questions, recording what was asked.
type fakeZig struct {
	last   host.CTextClientReq
	calls  int
	answer func(*host.CTextClientReq)
}

func (f *fakeZig) call(req *host.CTextClientReq) {
	f.calls++
	f.last = *req
	if f.answer != nil {
		f.answer(req)
	}
}

func newFake() (*fakeZig, *zigTextClient) {
	f := &fakeZig{}
	return f, &zigTextClient{call: f.call, buf: make([]byte, 1024)}
}

func TestTextClientTextForRange(t *testing.T) {
	f, c := newFake()
	f.answer = func(req *host.CTextClientReq) {
		copy(c.buf, "héllo")
		req.TextLen = uintptr(len("héllo"))
		req.OutStart, req.OutEnd = 1, 3
	}
	text, r := c.TextForRange(mygoui.TextInputRange{Start: 1, End: 2})
	if text != "héllo" || r.Start != 1 || r.End != 3 {
		t.Fatalf("text=%q range=%+v", text, r)
	}
	if f.last.Sub != host.TextClientTextForRange || f.last.Start != 1 || f.last.End != 2 {
		t.Fatalf("req=%+v", f.last)
	}
}

func TestTextClientSelectionAndMarked(t *testing.T) {
	f, c := newFake()
	f.answer = func(req *host.CTextClientReq) {
		switch req.Sub {
		case host.TextClientSelection:
			req.OutStart, req.OutEnd, req.HasMarked = 2, 5, 1
		case host.TextClientMarkedRange:
			req.HasMarked, req.OutStart, req.OutEnd = 1, 3, 4
		}
	}
	sel := c.Selection()
	if sel.Range.Start != 2 || sel.Range.End != 5 || !sel.Reversed {
		t.Fatalf("sel=%+v", sel)
	}
	m, ok := c.MarkedRange()
	if !ok || m.Start != 3 || m.End != 4 {
		t.Fatalf("marked=%+v ok=%v", m, ok)
	}
}

func TestTextClientReplaceAndMark(t *testing.T) {
	f, c := newFake()
	r := mygoui.TextInputRange{Start: 1, End: 2}
	c.ReplaceText(&r, "abc")
	if f.last.Sub != host.TextClientReplaceText || f.last.HasRange != 1 || f.last.InLen != 3 {
		t.Fatalf("replace req=%+v", f.last)
	}
	c.ReplaceText(nil, "x")
	if f.last.HasRange != 0 {
		t.Fatal("nil range should not be sent")
	}

	c.SetMarkedText(&r, "にほん", mygoui.TextInputRange{Start: 0, End: 2})
	if f.last.Sub != host.TextClientSetMarked || f.last.SelStart != 0 || f.last.SelEnd != 2 {
		t.Fatalf("marked req=%+v", f.last)
	}
	c.UnmarkText()
	if f.last.Sub != host.TextClientUnmarkText {
		t.Fatalf("unmark req=%+v", f.last)
	}
}

func TestTextClientBoundsAndIndex(t *testing.T) {
	f, c := newFake()
	f.answer = func(req *host.CTextClientReq) {
		if req.Sub == host.TextClientBoundsFor {
			req.Found = 1
			req.RectX, req.RectY, req.RectW, req.RectH = 4, 8, 40, 20
			req.OutStart, req.OutEnd = 0, 2
		}
		if req.Sub == host.TextClientIndexFor {
			req.Found, req.OutStart = 1, 6
		}
	}
	rect, r, ok := c.BoundsForRange(mygoui.TextInputRange{Start: 0, End: 1})
	if !ok || rect != (mygoui.Rect{X: 4, Y: 8, W: 40, H: 20}) || r.End != 2 {
		t.Fatalf("rect=%+v r=%+v ok=%v", rect, r, ok)
	}
	if i, ok := c.IndexForPoint(mygoui.Point{X: 3, Y: 9}); !ok || i != 6 {
		t.Fatalf("i=%d ok=%v", i, ok)
	}
	if f.last.X != 3 || f.last.Y != 9 {
		t.Fatalf("point req=%+v", f.last)
	}
}

var _ = mygo.Version
