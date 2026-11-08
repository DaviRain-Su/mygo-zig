// Command uigen reads ui/api_gen.go and generates the binary CommandBuffer
// Element modifier bindings for both Go (zig/host/ui/modifiers_gen.go) and
// Zig (zig/sdk/element_gen.zig).
//
// Run from the repository root:
//
//	go run ./zig/cmd/uigen
package main

import (
	"bytes"
	"fmt"
	"go/ast"
	"go/format"
	"go/parser"
	"go/token"
	"os"
	"sort"
	"strings"
	"unicode"
)

type paramKind int

const (
	pkF32 paramKind = iota + 1
	pkInt
	pkBool
	pkColor
	pkString
	pkVarF32 // ...float32
	pkAlign
	pkBorderStyle
	pkCursor
	pkDirection
)

type paramSpec struct {
	name string
	kind paramKind
}

type methodSpec struct {
	goName   string
	zigName  string
	opcode   uint16
	params   []paramSpec
	variadic bool // ...float32: encoded as [u8 count][f32 * count]
}

var zigKeywords = map[string]bool{
	"align": true, "allowzero": true, "and": true, "anyframe": true, "anytype": true,
	"asm": true, "async": true, "await": true, "break": true, "callconv": true,
	"catch": true, "comptime": true, "const": true, "continue": true, "defer": true,
	"else": true, "enum": true, "errdefer": true, "error": true, "export": true,
	"extern": true, "false": true, "fn": true, "for": true, "if": true,
	"inline": true, "linksection": true, "noalias": true, "noinline": true,
	"nosuspend": true, "null": true, "opaque": true, "or": true, "orelse": true,
	"packed": true, "pub": true, "resume": true, "return": true, "struct": true,
	"suspend": true, "switch": true, "test": true, "threadlocal": true, "true": true,
	"try": true, "type": true, "undefined": true, "union": true, "unreachable": true,
	"var": true, "volatile": true, "while": true,
}

// Hand-written methods on Element in element_gen.zig that must not be duplicated.
var handWrittenZigNames = map[string]bool{
	"begin":             true,
	"draw":              true,
	"numericTransition": true,
	"clicked":           true,
	"hovered":           true,
	"pressed":           true,
	"changed":           true,
	"submitted":         true,
	"contextMenu":       true,
	"popoverMenu":       true,
	"drag":              true,
	"drop":              true,
	"dragOver":          true,
	"draggable":         true,
	"dragData":          true,
	"dropData":          true,
	"dataDragOver":      true,
	"dataDragOverMIME":  true,
	"drawObjects":       true,
	"dragMIME":          true,
	"dropMIME":          true,
	"dragMIMELazy":      true,
	"animate":           true,
	"animateTo":         true,
	"arrived":           true,
	"animateColor":      true,
	"animatePose":       true,
	"spring":            true,
	"role":              true,
	"glass":             true,
	"glassBlur":         true,
	"scrollEdge":        true,
	"linearGradient":    true,
	"linearGradStops":   true,
	"conicGradient":     true,
	"radialGradient":    true,
}

func toCamel(s string) string {
	if s == "" {
		return s
	}
	runes := []rune(s)
	// Lowercase leading acronym run (e.g. "RTL" -> "rtl", "URL" -> "url", "ZIndex" -> "zIndex").
	i := 0
	for i < len(runes) && unicode.IsUpper(runes[i]) {
		i++
	}
	if i == 0 {
		return s
	}
	if i == 1 || i == len(runes) {
		for j := 0; j < i; j++ {
			runes[j] = unicode.ToLower(runes[j])
		}
	} else {
		for j := 0; j < i-1; j++ {
			runes[j] = unicode.ToLower(runes[j])
		}
	}
	out := string(runes)
	if zigKeywords[out] {
		return `@"` + out + `"`
	}
	return out
}

func safeParamName(name string, idx int) string {
	if name == "" || zigKeywords[name] || name == "self" || name == "c" || name == "ctx" || name == "Color" || name == "Element" {
		return fmt.Sprintf("p%d", idx)
	}
	return name
}

func parseParamKind(expr ast.Expr) (paramKind, bool) {
	switch e := expr.(type) {
	case *ast.Ident:
		switch e.Name {
		case "float32":
			return pkF32, true
		case "int":
			return pkInt, true
		case "bool":
			return pkBool, true
		case "Color":
			return pkColor, true
		case "string":
			return pkString, true
		case "Align":
			return pkAlign, true
		case "BorderStyle":
			return pkBorderStyle, true
		case "Cursor":
			return pkCursor, true
		case "Direction":
			return pkDirection, true
		}
	case *ast.Ellipsis:
		if id, ok := e.Elt.(*ast.Ident); ok && id.Name == "float32" {
			return pkVarF32, true
		}
	}
	return 0, false
}

func main() {
	fset := token.NewFileSet()
	f, err := parser.ParseFile(fset, "ui/api_gen.go", nil, 0)
	if err != nil {
		panic(err)
	}

	var methods []methodSpec
	for _, decl := range f.Decls {
		fn, ok := decl.(*ast.FuncDecl)
		if !ok || fn.Recv == nil || len(fn.Recv.List) != 1 || fn.Type.TypeParams != nil {
			continue
		}
		recvIdent, ok := fn.Recv.List[0].Type.(*ast.Ident)
		if !ok || recvIdent.Name != "Element" {
			continue
		}
		if fn.Type.Results == nil || len(fn.Type.Results.List) != 1 {
			continue
		}
		retIdent, ok := fn.Type.Results.List[0].Type.(*ast.Ident)
		if !ok || retIdent.Name != "Element" {
			continue
		}
		zigName := toCamel(fn.Name.Name)
		if handWrittenZigNames[zigName] {
			continue
		}

		var params []paramSpec
		supported := true
		variadic := false
		if fn.Type.Params != nil {
			idx := 0
			for _, field := range fn.Type.Params.List {
				pk, ok := parseParamKind(field.Type)
				if !ok {
					supported = false
					break
				}
				if pk == pkVarF32 {
					if len(fn.Type.Params.List) != 1 {
						supported = false
						break
					}
					variadic = true
				}
				names := field.Names
				if len(names) == 0 {
					params = append(params, paramSpec{name: safeParamName("", idx), kind: pk})
					idx++
				} else {
					for _, n := range names {
						params = append(params, paramSpec{name: safeParamName(n.Name, idx), kind: pk})
						idx++
					}
				}
			}
		}
		if !supported {
			continue
		}
		methods = append(methods, methodSpec{
			goName:   fn.Name.Name,
			zigName:  zigName,
			params:   params,
			variadic: variadic,
		})
	}

	sort.Slice(methods, func(i, j int) bool {
		return methods[i].goName < methods[j].goName
	})
	allNames := map[string]bool{}
	for k := range handWrittenZigNames {
		allNames[k] = true
	}
	for _, m := range methods {
		allNames[m.zigName] = true
		if m.variadic {
			allNames[m.zigName+"Values"] = true
		}
	}
	for i := range methods {
		methods[i].opcode = uint16(100 + i)
		for j := range methods[i].params {
			if allNames[methods[i].params[j].name] {
				methods[i].params[j].name = fmt.Sprintf("arg%d", j)
			}
		}
	}

	writeGoDecoder(methods)
	writeZigElement(methods)
	fmt.Printf("zig/cmd/uigen: generated %d Element modifier methods (opcodes 100..%d)\n", len(methods), 99+len(methods))
}

func writeGoDecoder(methods []methodSpec) {
	var b bytes.Buffer
	b.WriteString("//go:build !js\n\n")
	b.WriteString("// Code generated by go run ./zig/cmd/uigen; DO NOT EDIT.\n\n")
	b.WriteString("package ui\n\n")
	b.WriteString("import mygoui \"github.com/egoist/mygo/ui\"\n\n")
	b.WriteString("func execGeneratedModifier(op uint16, cur mygoui.Element, r *tapeReader) (mygoui.Element, bool) {\n")
	b.WriteString("\tswitch op {\n")
	for _, m := range methods {
		fmt.Fprintf(&b, "\tcase %d: // %s\n", m.opcode, m.goName)
		if m.variadic {
			b.WriteString("\t\tcnt, ok := r.u8()\n\t\tif !ok { return cur, false }\n")
			b.WriteString("\t\tvar vals [4]float32\n\t\tn := min(int(cnt), 4)\n")
			b.WriteString("\t\tfor i := 0; i < int(cnt); i++ {\n\t\t\tv, ok := r.f32()\n\t\t\tif !ok { return cur, false }\n\t\t\tif i < 4 { vals[i] = v }\n\t\t}\n")
			fmt.Fprintf(&b, "\t\treturn cur.%s(vals[:n]...), true\n", m.goName)
			continue
		}
		var args []string
		for i, p := range m.params {
			v := fmt.Sprintf("a%d", i)
			switch p.kind {
			case pkF32:
				fmt.Fprintf(&b, "\t\t%s, ok := r.f32()\n\t\tif !ok { return cur, false }\n", v)
				args = append(args, v)
			case pkInt:
				fmt.Fprintf(&b, "\t\t%s, ok := r.i32()\n\t\tif !ok { return cur, false }\n", v)
				args = append(args, fmt.Sprintf("int(%s)", v))
			case pkBool:
				fmt.Fprintf(&b, "\t\t%s, ok := r.u8()\n\t\tif !ok { return cur, false }\n", v)
				args = append(args, fmt.Sprintf("%s != 0", v))
			case pkColor:
				fmt.Fprintf(&b, "\t\t%s, ok := r.u32()\n\t\tif !ok { return cur, false }\n", v)
				args = append(args, fmt.Sprintf("unpackColor(%s)", v))
			case pkString:
				fmt.Fprintf(&b, "\t\t%s, ok := r.str()\n\t\tif !ok { return cur, false }\n", v)
				args = append(args, v)
			case pkAlign:
				fmt.Fprintf(&b, "\t\t%s, ok := r.u8()\n\t\tif !ok { return cur, false }\n", v)
				args = append(args, fmt.Sprintf("mygoui.Align(%s)", v))
			case pkBorderStyle:
				fmt.Fprintf(&b, "\t\t%s, ok := r.u8()\n\t\tif !ok { return cur, false }\n", v)
				args = append(args, fmt.Sprintf("mygoui.BorderStyle(%s)", v))
			case pkCursor:
				fmt.Fprintf(&b, "\t\t%s, ok := r.u8()\n\t\tif !ok { return cur, false }\n", v)
				args = append(args, fmt.Sprintf("mygoui.Cursor(%s)", v))
			case pkDirection:
				fmt.Fprintf(&b, "\t\t%s, ok := r.u8()\n\t\tif !ok { return cur, false }\n", v)
				args = append(args, fmt.Sprintf("mygoui.Direction(%s)", v))
			}
		}
		fmt.Fprintf(&b, "\t\treturn cur.%s(%s), true\n", m.goName, strings.Join(args, ", "))
	}
	b.WriteString("\t}\n\treturn cur, false\n}\n")

	src, err := format.Source(b.Bytes())
	if err != nil {
		os.WriteFile("/tmp/bad_modifiers_gen.go", b.Bytes(), 0o644)
		panic(err)
	}
	if err := os.MkdirAll("zig/host/ui", 0o755); err != nil {
		panic(err)
	}
	if err := os.WriteFile("zig/host/ui/modifiers_gen.go", src, 0o644); err != nil {
		panic(err)
	}
}

func zigParamType(k paramKind) string {
	switch k {
	case pkF32:
		return "f32"
	case pkInt:
		return "i32"
	case pkBool:
		return "bool"
	case pkColor:
		return "Color"
	case pkString:
		return "[]const u8"
	case pkVarF32:
		return "[]const f32"
	case pkAlign:
		return "ui.Align"
	case pkBorderStyle:
		return "ui.BorderStyle"
	case pkCursor:
		return "ui.Cursor"
	case pkDirection:
		return "ui.Direction"
	}
	return "void"
}

func writeZigElement(methods []methodSpec) {
	var b bytes.Buffer
	b.WriteString("//! Code generated by `go run ./zig/cmd/uigen`; DO NOT EDIT.\n")
	b.WriteString("//! Wraps MyGo's `ui.Element` with zero-FFI stack CommandBuffer recording.\n\n")
	b.WriteString("const ui = @import(\"ui.zig\");\n")
	b.WriteString("const Context = ui.Context;\n")
	b.WriteString("const Color = ui.Color;\n")
	b.WriteString("const Scope = ui.Scope;\n")
	b.WriteString("const Painter = ui.Painter;\n")
	b.WriteString("const Rect = ui.Rect;\n")
	b.WriteString("const CoreOp = ui.CoreOp;\n\n")

	b.WriteString("pub const Element = struct {\n")
	b.WriteString("    ctx: *Context,\n\n")
	b.WriteString(`    /// Enters this container's children scope; pair with ` + "`defer scope.end();`" + `.
    pub fn begin(self: Element) Scope {
        self.ctx.writeOp(@intFromEnum(CoreOp.push_parent));
        return .{ .ctx = self.ctx };
    }

    /// Attaches a custom GPU vector paint callback (` + "`fn (StatePtr, *Painter, Rect) void`" + `).
    pub fn draw(
        self: Element,
        comptime StatePtr: type,
        state: StatePtr,
        comptime paintFn: fn (StatePtr, *Painter, Rect) void,
    ) Element {
        self.ctx.attachDraw(StatePtr, state, paintFn);
        return self;
    }

    pub fn numericTransition(self: Element, down: bool) Element {
        self.ctx.writeOp(@intFromEnum(CoreOp.numeric_transition));
        self.ctx.writeU8(@intFromBool(down));
        return self;
    }

    pub fn clicked(self: Element) bool {
        self.ctx.writeOp(@intFromEnum(CoreOp.query_clicked));
        return self.ctx.flushQuery().bool_val != 0;
    }

    pub fn hovered(self: Element) bool {
        self.ctx.writeOp(@intFromEnum(CoreOp.query_hovered));
        return self.ctx.flushQuery().bool_val != 0;
    }

    pub fn pressed(self: Element) bool {
        self.ctx.writeOp(@intFromEnum(CoreOp.query_pressed));
        return self.ctx.flushQuery().bool_val != 0;
    }

    pub fn changed(self: Element) bool {
        self.ctx.writeOp(@intFromEnum(CoreOp.query_changed));
        return self.ctx.flushQuery().bool_val != 0;
    }

    pub fn submitted(self: Element) bool {
        self.ctx.writeOp(@intFromEnum(CoreOp.query_submitted));
        return self.ctx.flushQuery().bool_val != 0;
    }

    /// Nested context menu. Writes chosen item id into id_buf when Chosen.
    pub fn contextMenu(self: Element, entries: []const ui.MenuEntry, id_buf: []u8, id_len: *usize) bool {
        return self.ctx.attachMenu(.context_menu, entries, id_buf, id_len);
    }

    /// Like contextMenu, drawn by MyGo rather than the system menu.
    pub fn popoverMenu(self: Element, entries: []const ui.MenuEntry, id_buf: []u8, id_len: *usize) bool {
        return self.ctx.attachMenu(.popover_menu, entries, id_buf, id_len);
    }

    /// Makes this element a UTF-8 drag source.
    pub fn drag(self: Element, payload: []const u8) Element {
        self.ctx.drag(payload);
        return self;
    }

    /// String drop target; true when a payload arrived since last frame.
    pub fn drop(self: Element, buf: []u8, len: *usize) bool {
        return self.ctx.drop(buf, len);
    }

    /// True while a matching string drag is over this element.
    pub fn dragOver(self: Element, buf: []u8, len: *usize) bool {
        return self.ctx.dragOver(buf, len);
    }

    /// Free-move drag of this element; updates *x/*y each frame.
    pub fn draggable(self: Element, x: *f32, y: *f32, axis: ui.DragAxis, bounds: ?ui.DragBounds, snap: []const [2]f32) Element {
        self.ctx.draggable(x, y, axis, bounds, snap);
        return self;
    }

    /// Native text drag source for other apps.
    pub fn dragData(self: Element, payload: []const u8) Element {
        self.ctx.dragData(payload);
        return self;
    }

    /// Native drop target for text / URL / file paths.
    pub fn dropData(self: Element, buf: []u8, len: *usize) bool {
        return self.ctx.dropData(buf, len);
    }

    /// True while a native drag matching text/URL/files is over this element.
    pub fn dataDragOver(self: Element) bool {
        return self.ctx.dataDragOver();
    }

    pub fn dataDragOverMIME(self: Element, formats: []const []const u8) bool {
        return self.ctx.dataDragOverMIME(formats);
    }

    pub fn drawObjects(self: Element, comptime StatePtr: type, state: StatePtr, comptime paintFn: fn (StatePtr, *ui.Painter, i32, ui.Rect) void) Element {
        self.ctx.drawObjects(StatePtr, state, paintFn);
        return self;
    }

    pub fn dragMIME(self: Element, parts: []const struct { []const u8, []const u8 }) Element {
        self.ctx.dragMIME(parts);
        return self;
    }

    pub fn dragMIMELazy(
        self: Element,
        formats: []const []const u8,
        comptime StatePtr: type,
        state: StatePtr,
        comptime provideFn: fn (StatePtr, []u8) usize,
    ) Element {
        self.ctx.dragMIMELazy(formats, StatePtr, state, provideFn);
        return self;
    }

    pub fn dropMIME(self: Element, formats: []const []const u8, buf: []u8, len: *usize) bool {
        return self.ctx.dropMIME(formats, buf, len);
    }

    pub fn animate(self: Element, key: []const u8, target: f32, duration_ms: i32) f32 {
        self.ctx.writeOp(@intFromEnum(CoreOp.animate));
        self.ctx.writeStr(key);
        self.ctx.writeF32(target);
        self.ctx.writeI32(duration_ms);
        return @floatCast(self.ctx.flushQuery().num_val);
    }

    pub fn animateTo(
        self: Element,
        key: []const u8,
        target: f32,
        preset: ui.AnimPreset,
        duration_ms: i32,
        delay_ms: i32,
        non_motion: bool,
        bounce: f32,
    ) f32 {
        self.ctx.writeOp(@intFromEnum(CoreOp.animate_to));
        self.ctx.writeStr(key);
        self.ctx.writeF32(target);
        self.ctx.writeU8(@intFromEnum(preset));
        self.ctx.writeI32(duration_ms);
        self.ctx.writeI32(delay_ms);
        self.ctx.writeU8(@intFromBool(non_motion));
        self.ctx.writeF32(bounce);
        return @floatCast(self.ctx.flushQuery().num_val);
    }

    pub fn arrived(self: Element, key: []const u8) bool {
        self.ctx.writeOp(@intFromEnum(CoreOp.arrived));
        self.ctx.writeStr(key);
        return self.ctx.flushQuery().bool_val != 0;
    }

    pub fn animateColor(
        self: Element,
        key: []const u8,
        target: Color,
        preset: ui.AnimPreset,
        duration_ms: i32,
        delay_ms: i32,
        non_motion: bool,
        oklab: bool,
    ) Color {
        self.ctx.writeOp(@intFromEnum(CoreOp.animate_color));
        self.ctx.writeStr(key);
        self.ctx.writeU32(target.toU32());
        self.ctx.writeU8(@intFromEnum(preset));
        self.ctx.writeI32(duration_ms);
        self.ctx.writeI32(delay_ms);
        self.ctx.writeU8(@intFromBool(non_motion));
        self.ctx.writeU8(@intFromBool(oklab));
        const q = self.ctx.flushQuery();
        return Color.fromU32(@intCast(q.int_val));
    }

    pub fn animatePose(self: Element, pose: ui.Pose, preset: ui.AnimPreset, duration_ms: i32, delay_ms: i32) Element {
        self.ctx.writeOp(@intFromEnum(CoreOp.animate_pose));
        self.ctx.writeF32(pose.x);
        self.ctx.writeF32(pose.y);
        self.ctx.writeF32(pose.scale);
        self.ctx.writeF32(pose.rotate);
        self.ctx.writeF32(pose.fade);
        self.ctx.writeF32(pose.x_percent);
        self.ctx.writeF32(pose.y_percent);
        self.ctx.writeU8(@intFromEnum(preset));
        self.ctx.writeI32(duration_ms);
        self.ctx.writeI32(delay_ms);
        return self;
    }

    pub fn spring(self: Element, key: []const u8, target: f32, bounce: f32, duration_ms: i32, velocity: f32) f32 {
        self.ctx.writeOp(@intFromEnum(CoreOp.spring));
        self.ctx.writeStr(key);
        self.ctx.writeF32(target);
        self.ctx.writeF32(bounce);
        self.ctx.writeI32(duration_ms);
        self.ctx.writeF32(velocity);
        return @floatCast(self.ctx.flushQuery().num_val);
    }

    pub fn role(self: Element, r: ui.Role) Element {
        self.ctx.writeOp(@intFromEnum(CoreOp.role));
        self.ctx.writeU8(@intFromEnum(r));
        return self;
    }

    pub fn linearGradient(self: Element, angle: f32, from: Color, to: Color, oklab: bool) Element {
        self.ctx.writeOp(@intFromEnum(CoreOp.linear_gradient));
        self.ctx.writeF32(angle);
        self.ctx.writeU32(from.toU32());
        self.ctx.writeU32(to.toU32());
        self.ctx.writeU8(@intFromBool(oklab));
        return self;
    }

    pub fn linearGradStops(self: Element, angle: f32, oklab: bool, stops: []const ui.GradientStop) Element {
        self.ctx.writeOp(@intFromEnum(CoreOp.linear_grad_stops));
        self.ctx.writeF32(angle);
        self.ctx.writeU8(@intFromBool(oklab));
        const n: u8 = @intCast(@min(stops.len, 16));
        self.ctx.writeU8(n);
        for (stops[0..n]) |s| {
            self.ctx.writeU32(s.color.toU32());
            self.ctx.writeF32(s.at);
        }
        return self;
    }

    pub fn conicGradient(self: Element, angle: f32, center_pt: ui.Point, oklab: bool, stops: []const ui.GradientStop) Element {
        self.ctx.writeOp(@intFromEnum(CoreOp.conic_gradient));
        self.ctx.writeF32(angle);
        self.ctx.writeF32(center_pt.x);
        self.ctx.writeF32(center_pt.y);
        self.ctx.writeU8(@intFromBool(oklab));
        const n: u8 = @intCast(@min(stops.len, 16));
        self.ctx.writeU8(n);
        for (stops[0..n]) |s| {
            self.ctx.writeU32(s.color.toU32());
            self.ctx.writeF32(s.at);
        }
        return self;
    }

    pub fn radialGradient(self: Element, radius_dip: f32, center_pt: ui.Point, oklab: bool, stops: []const ui.GradientStop) Element {
        self.ctx.writeOp(@intFromEnum(CoreOp.radial_gradient));
        self.ctx.writeF32(radius_dip);
        self.ctx.writeF32(center_pt.x);
        self.ctx.writeF32(center_pt.y);
        self.ctx.writeU8(@intFromBool(oklab));
        const n: u8 = @intCast(@min(stops.len, 16));
        self.ctx.writeU8(n);
        for (stops[0..n]) |s| {
            self.ctx.writeU32(s.color.toU32());
            self.ctx.writeF32(s.at);
        }
        return self;
    }

    /// Liquid Glass material (blank-import zig/host/glass).
    pub fn glass(self: Element, opts: ui.GlassOptions) Element {
        _ = self.ctx.glass(opts);
        return self;
    }

    pub fn glassBlur(self: Element, opts: ui.BlurOptions) Element {
        _ = self.ctx.glassBlur(opts);
        return self;
    }

    pub fn scrollEdge(self: Element, hard: bool, at_bottom: bool, bg: u32) Element {
        _ = self.ctx.scrollEdge(hard, at_bottom, bg);
        return self;
    }
`)

	for _, m := range methods {
		if m.variadic {
			// Generate convenient 1-arg, XY 2-arg (if not already present), and slice overload (`...Values`).
			fmt.Fprintf(&b, "\n    pub fn %s(self: Element, v: f32) Element {\n", m.zigName)
			fmt.Fprintf(&b, "        self.ctx.writeOp(%d);\n", m.opcode)
			b.WriteString("        self.ctx.writeU8(1);\n")
			b.WriteString("        self.ctx.writeF32(v);\n")
			b.WriteString("        return self;\n    }\n")

			fmt.Fprintf(&b, "\n    pub fn %sValues(self: Element, vals: []const f32) Element {\n", m.zigName)
			fmt.Fprintf(&b, "        self.ctx.writeOp(%d);\n", m.opcode)
			b.WriteString("        const n: usize = @min(vals.len, 4);\n")
			b.WriteString("        self.ctx.writeU8(@intCast(n));\n")
			b.WriteString("        for (vals[0..n]) |v| self.ctx.writeF32(v);\n")
			b.WriteString("        return self;\n    }\n")
			continue
		}

		var sig []string
		sig = append(sig, "self: Element")
		for _, p := range m.params {
			sig = append(sig, fmt.Sprintf("%s: %s", p.name, zigParamType(p.kind)))
		}
		fmt.Fprintf(&b, "\n    pub fn %s(%s) Element {\n", m.zigName, strings.Join(sig, ", "))
		fmt.Fprintf(&b, "        self.ctx.writeOp(%d);\n", m.opcode)
		for _, p := range m.params {
			switch p.kind {
			case pkF32:
				fmt.Fprintf(&b, "        self.ctx.writeF32(%s);\n", p.name)
			case pkInt:
				fmt.Fprintf(&b, "        self.ctx.writeI32(%s);\n", p.name)
			case pkBool:
				fmt.Fprintf(&b, "        self.ctx.writeU8(@intFromBool(%s));\n", p.name)
			case pkColor:
				fmt.Fprintf(&b, "        self.ctx.writeU32(%s.toU32());\n", p.name)
			case pkString:
				fmt.Fprintf(&b, "        self.ctx.writeStr(%s);\n", p.name)
			case pkAlign, pkBorderStyle, pkCursor, pkDirection:
				fmt.Fprintf(&b, "        self.ctx.writeU8(@intFromEnum(%s));\n", p.name)
			}
		}
		b.WriteString("        return self;\n    }\n")
	}
	b.WriteString("};\n")

	if err := os.MkdirAll("zig/sdk", 0o755); err != nil {
		panic(err)
	}
	if err := os.WriteFile("zig/sdk/element_gen.zig", b.Bytes(), 0o644); err != nil {
		panic(err)
	}
}
