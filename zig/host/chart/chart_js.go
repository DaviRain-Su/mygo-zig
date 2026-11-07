//go:build js

package chart

// Charts are desktop-only for the Zig host; keep the package compiling under
// GOOS=js so `go vet` of the module still works.
