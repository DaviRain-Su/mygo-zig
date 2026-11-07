//go:build js

package mygo

import "context"

func FFIBindRaw(fullName string, fn func(ctx context.Context, argsJSON []byte) ([]byte, error)) error {
	return nil
}

func FFIEmitRaw(w *Window, name string, payloadJSON []byte) error {
	return nil
}
