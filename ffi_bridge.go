//go:build !js

package mygo

import (
	"context"
	"encoding/json/jsontext"
	"errors"
	"fmt"
	"reflect"
	"strings"
)

// FFIBindRaw binds a raw JSON method ("Service.Method") for non-Go hosts
// without invoking reflect.Type.Method or linking internal/tsgen.
// Pure Go apps never call it, so the linker drops it completely.
func FFIBindRaw(fullName string, fn func(ctx context.Context, argsJSON []byte) ([]byte, error)) error {
	if fn == nil {
		return errors.New("mygo: cannot bind nil FFI handler")
	}
	if strings.HasPrefix(fullName, "mygo:") {
		return fmt.Errorf("mygo: method %q: names starting with \"mygo:\" are reserved", fullName)
	}
	svcName, methodName, ok := strings.Cut(fullName, ".")
	if !ok || svcName == "" || methodName == "" || strings.Contains(methodName, ".") {
		return fmt.Errorf("mygo: method %q must have the form \"Service.Method\"", fullName)
	}
	wrapped := func(ctx context.Context, args ...jsontext.Value) (jsontext.Value, error) {
		var buf []byte
		if len(args) == 0 {
			buf = []byte("[]")
		} else {
			n := 2 + len(args) - 1
			for _, a := range args {
				n += len(a)
			}
			buf = make([]byte, 0, n)
			buf = append(buf, '[')
			for i, a := range args {
				if i > 0 {
					buf = append(buf, ',')
				}
				buf = append(buf, a...)
			}
			buf = append(buf, ']')
		}
		out, err := fn(ctx, buf)
		if err != nil {
			return nil, err
		}
		if len(out) == 0 {
			return jsontext.Value("null"), nil
		}
		v := jsontext.Value(out)
		if !v.IsValid() {
			return nil, fmt.Errorf("mygo: %s returned invalid JSON", fullName)
		}
		return v, nil
	}
	mi, err := newMethod(svcName, methodName, reflect.ValueOf(wrapped))
	if err != nil {
		return err
	}

	ipc.Lock()
	defer ipc.Unlock()
	if ipc.methods == nil {
		ipc.methods = map[string]*method{}
	}
	if ipc.methods[fullName] != nil {
		return fmt.Errorf("mygo: method %s is already bound", fullName)
	}
	var svc *service
	for _, x := range ipc.services {
		if x.name == svcName {
			if !x.internal {
				return fmt.Errorf("mygo: a service named %s is already bound", svcName)
			}
			svc = x
			break
		}
	}
	if svc == nil {
		svc = &service{name: svcName, internal: true}
		ipc.services = append(ipc.services, svc)
	}
	svc.methods = append(svc.methods, mi)
	ipc.methods[fullName] = mi
	return nil
}

func ffiEncodeRawEvent(name string, payloadJSON []byte) (message, error) {
	if name == "" {
		return message{}, errors.New("mygo: event name cannot be empty")
	}
	if strings.HasPrefix(name, "mygo:") {
		return message{}, fmt.Errorf("mygo: event %q: names starting with \"mygo:\" are reserved", name)
	}
	v := jsontext.Value("null")
	if len(payloadJSON) > 0 {
		v = jsontext.Value(payloadJSON)
		if !v.IsValid() {
			return message{}, fmt.Errorf("mygo: event %q: invalid JSON payload", name)
		}
	}
	return encodeEvent(name, v)
}

// FFIEmitRaw sends an event with a raw JSON payload to w (or broadcasts when w is nil).
func FFIEmitRaw(w *Window, name string, payloadJSON []byte) error {
	msg, err := ffiEncodeRawEvent(name, payloadJSON)
	if err != nil {
		return err
	}
	if w == nil {
		for _, pw := range pageWindows() {
			if !pw.untrusted {
				pw.enqueue(msg, true)
			}
		}
		return nil
	}
	if w.IsDestroyed() {
		return errDestroyed
	}
	if w.content {
		windows.Lock()
		views := append([]*Window(nil), w.webViews...)
		windows.Unlock()
		for _, v := range views {
			if !v.untrusted {
				v.enqueue(msg, true)
			}
		}
		return nil
	}
	w.enqueue(msg, true)
	return nil
}
