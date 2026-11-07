//go:build mygo_ffi

package ui

// FFIScope saves the parent and theme state of an open container while an FFI
// CommandBuffer flushes mid-tree.
type FFIScope struct {
	elem           *node
	savedParent    *node
	savedTheme     *Theme
	savedWindow    *Theme
	hadCustomTheme bool
}

// FFIPushParent enters e's children scope, matching Element.Children.
func FFIPushParent(c *Context, e Element) (FFIScope, bool) {
	raw := c.build()
	n := e.node()
	if raw == nil || n == nil {
		return FFIScope{}, false
	}
	sc := FFIScope{elem: n, savedParent: raw.parent}
	raw.parent = n
	if t := n.themed; t != nil {
		sc.hadCustomTheme = true
		sc.savedTheme, sc.savedWindow = raw.theme, raw.window
		raw.theme = t
	}
	return sc, true
}

// FFIPopParent restores the scope entered by FFIPushParent.
func FFIPopParent(c *Context, sc FFIScope) {
	raw := c.build()
	if raw == nil || sc.elem == nil {
		return
	}
	if sc.hadCustomTheme {
		outer := sc.savedTheme
		if outer == sc.savedWindow {
			outer = raw.window
		}
		raw.theme = outer
	}
	raw.parent = sc.savedParent
	if sc.elem.kind == kindText && sc.elem.first != nil {
		sc.elem.inlineText()
	}
}
