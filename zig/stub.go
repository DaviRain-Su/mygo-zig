//go:build !(mygo_ffi && cgo)

// Package main builds libmygo (-buildmode=c-archive or c-shared) when compiled
// with -tags mygo_ffi and CGO_ENABLED=1. Without mygo_ffi, it stays an empty
// pure-Go binary so `CGO_ENABLED=0 go build ./...` succeeds everywhere.
package main

func main() {}
