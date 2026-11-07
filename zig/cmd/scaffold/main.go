// Command scaffold creates a minimal Zig Native UI app under zig/examples/ or a path.
//
//	go run ./zig/cmd/scaffold myapp
//	go run ./zig/cmd/scaffold -dir ./apps/demo demo
package main

import (
	"embed"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

//go:embed template template/src
var templates embed.FS

func main() {
	dirFlag := flag.String("dir", "", "output directory (default zig/examples/<name>-zig)")
	flag.Parse()
	if flag.NArg() != 1 {
		fmt.Fprintf(os.Stderr, "usage: scaffold [-dir path] <name>\n")
		os.Exit(2)
	}
	name := flag.Arg(0)
	lib := sanitize(name)
	if lib == "" {
		fmt.Fprintf(os.Stderr, "invalid name %q\n", name)
		os.Exit(2)
	}
	out := *dirFlag
	if out == "" {
		out = filepath.Join("zig", "examples", lib+"-zig")
	}
	if err := os.MkdirAll(filepath.Join(out, "src"), 0o755); err != nil {
		fail(err)
	}
	if err := os.MkdirAll(filepath.Join(out, "resources"), 0o755); err != nil {
		fail(err)
	}

	repoRoot, err := filepath.Abs(".")
	if err != nil {
		fail(err)
	}
	if repoRoot, err = filepath.EvalSymlinks(repoRoot); err != nil {
		repoRoot, _ = filepath.Abs(".")
	}
	absOut, err := filepath.Abs(out)
	if err != nil {
		fail(err)
	}
	if resolved, err := filepath.EvalSymlinks(absOut); err == nil {
		absOut = resolved
	}
	absSDK := filepath.Join(repoRoot, "zig", "sdk")
	relSDK := absSDK
	if strings.HasPrefix(absOut+string(filepath.Separator), repoRoot+string(filepath.Separator)) {
		if rel, err := filepath.Rel(absOut, absSDK); err == nil {
			relSDK = rel
		}
	}
	relSDK = filepath.ToSlash(relSDK)

	display := titleCase(name)
	repls := map[string]string{
		"{{NAME}}":  display,
		"{{LIB}}":   lib,
		"{{IDENT}}": "dev.mygo." + lib,
		"{{SDK}}":   relSDK,
	}

	files := []struct{ src, dst string }{
		{"template/main.go", "main.go"},
		{"template/mygo.json", "mygo.json"},
		{"template/build.zig", "build.zig"},
		{"template/src/app.zig", "src/app.zig"},
	}
	for _, f := range files {
		b, err := templates.ReadFile(f.src)
		if err != nil {
			fail(err)
		}
		s := string(b)
		for k, v := range repls {
			s = strings.ReplaceAll(s, k, v)
		}
		dst := filepath.Join(out, f.dst)
		if err := os.WriteFile(dst, []byte(s), 0o644); err != nil {
			fail(err)
		}
		fmt.Println("wrote", dst)
	}
	fmt.Printf(`
Next:
  (cd %s && zig build -Doptimize=ReleaseSmall)
  go run ./cmd/mygo build -skip-dmg %s
`, out, out)
}

func sanitize(s string) string {
	s = strings.ToLower(s)
	re := regexp.MustCompile(`[^a-z0-9]+`)
	s = re.ReplaceAllString(s, "")
	if s == "" {
		return ""
	}
	if s[0] >= '0' && s[0] <= '9' {
		s = "app" + s
	}
	return s
}

func titleCase(s string) string {
	parts := regexp.MustCompile(`[^A-Za-z0-9]+`).Split(s, -1)
	var b strings.Builder
	for _, p := range parts {
		if p == "" {
			continue
		}
		if b.Len() > 0 {
			b.WriteByte(' ')
		}
		b.WriteString(strings.ToUpper(p[:1]) + strings.ToLower(p[1:]))
	}
	if b.Len() == 0 {
		return "MyGo Zig App"
	}
	return b.String()
}

func fail(err error) {
	fmt.Fprintln(os.Stderr, err)
	os.Exit(1)
}
