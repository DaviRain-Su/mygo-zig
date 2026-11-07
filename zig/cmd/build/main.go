// Command build runs `zig build` then `mygo build` for a Zig example/app.
//
//	go run ./zig/cmd/build zig/examples/gallery-zig
//	go run ./zig/cmd/build -skip-dmg -optimize ReleaseSafe zig/examples/hello-zig
package main

import (
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
)

func main() {
	skipDMG := flag.Bool("skip-dmg", true, "pass -skip-dmg to mygo build")
	optimize := flag.String("optimize", "ReleaseSmall", "zig -Doptimize value")
	flag.Parse()
	if flag.NArg() != 1 {
		fmt.Fprintf(os.Stderr, "usage: build [-skip-dmg=false] [-optimize ReleaseSmall] <app-dir>\n")
		os.Exit(2)
	}
	dir := flag.Arg(0)
	abs, err := filepath.Abs(dir)
	if err != nil {
		fail(err)
	}
	if _, err := os.Stat(filepath.Join(abs, "build.zig")); err != nil {
		fail(fmt.Errorf("%s: need build.zig (not a Zig MyGo app?)", abs))
	}
	if _, err := os.Stat(filepath.Join(abs, "main.go")); err != nil {
		fail(fmt.Errorf("%s: need main.go host entry", abs))
	}

	zigArgs := []string{"build", "-Doptimize=" + *optimize}
	fmt.Printf("→ zig %v  (in %s)\n", zigArgs, abs)
	if err := runIn(abs, "zig", zigArgs...); err != nil {
		fail(err)
	}

	mygoArgs := []string{"run", "./cmd/mygo", "build"}
	if *skipDMG {
		mygoArgs = append(mygoArgs, "-skip-dmg")
	}
	mygoArgs = append(mygoArgs, abs)
	fmt.Printf("→ go %v\n", mygoArgs)
	if err := runIn(".", "go", mygoArgs...); err != nil {
		fail(err)
	}

	dist := filepath.Join(abs, "dist")
	fmt.Printf("✓ built %s\n", dist)
	if runtime.GOOS == "darwin" {
		_ = filepath.Walk(dist, func(path string, info os.FileInfo, err error) error {
			if err == nil && info.IsDir() && filepath.Ext(path) == ".app" {
				fmt.Printf("  open %q\n", path)
			}
			return nil
		})
	}
}

func runIn(dir, name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Dir = dir
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func fail(err error) {
	fmt.Fprintln(os.Stderr, err)
	os.Exit(1)
}
