package mygo

import "testing"

// TestEmptySubmenuIsNoSubmenu: the Zig host's menu JSON gives items
// without children an empty, non-nil submenu slice.
func TestEmptySubmenuIsNoSubmenu(t *testing.T) {
	m := NewMenu([]*MenuItem{
		{ID: "open", Label: "Open", Submenu: []*MenuItem{}},
		{ID: "edit", Label: "Edit", Submenu: []*MenuItem{{ID: "cut", Label: "Cut", Submenu: []*MenuItem{}}}},
	})
	open := m.Items()[0]
	if open.Type != MenuItemNormal {
		t.Fatalf("leaf type = %q, want normal", open.Type)
	}
	if len(open.Submenu) > 0 || open.sub != nil {
		t.Fatalf("leaf grew a submenu")
	}
	edit := m.Items()[1]
	if edit.Type != MenuItemSubmenu {
		t.Fatalf("parent type = %q, want submenu", edit.Type)
	}
}
