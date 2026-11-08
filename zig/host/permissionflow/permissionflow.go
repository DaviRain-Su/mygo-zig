//go:build !js

// Package permissionflow registers `plugins/permissionflow` into `zig/host`.
//
// Import with `_ "github.com/egoist/mygo/zig/host/permissionflow"`.
// Check / Allowed / OpenSettings are synchronous. Request / Guide / Wait run
// off the main thread and deliver status via ZigEventPermFlow (they must not
// block the UI thread).
package permissionflow

import (
	"context"
	"errors"
	"sync/atomic"

	plug "github.com/egoist/mygo/plugins/permissionflow"
	"github.com/egoist/mygo/zig/host"
)

func init() {
	host.PermissionFlowDispatch = dispatch
}

var (
	nextReq atomic.Uintptr
	callZig host.CallZigFn
)

func dispatch(call host.CallZigFn, op, a0, a1, a2, a3 uintptr) uintptr {
	callZig = call
	if op != host.HostOpPermissionFlow {
		host.SetError(errors.New("zighost: unknown permissionflow op"))
		return ^uintptr(0)
	}
	switch a0 {
	case host.PermCheck:
		return check(a1, a2)
	case host.PermAllowed:
		if plug.Allowed(plug.Permission(host.CopyString(a1, a2))) {
			return 1
		}
		return 0
	case host.PermRequest:
		return async(a1, doRequest)
	case host.PermOpenSettings:
		if err := plug.OpenSettings(plug.Permission(host.CopyString(a1, a2))); err != nil {
			host.SetError(err)
			return ^uintptr(0)
		}
		host.SetError(nil)
		return 0
	case host.PermGuide:
		return async(a1, doGuide)
	case host.PermWait:
		return async(a1, doWait)
	default:
		host.SetError(errors.New("zighost: unknown permissionflow subop"))
		return ^uintptr(0)
	}
}

func statusCode(st plug.Status) uintptr {
	switch st {
	case plug.NotDetermined:
		return 1
	case plug.Denied:
		return 2
	case plug.Granted:
		return 3
	default:
		return 0 // Unknown
	}
}

func check(namePtr, nameLen uintptr) uintptr {
	st, err := plug.Check(plug.Permission(host.CopyString(namePtr, nameLen)))
	if err != nil {
		host.SetError(err)
		return ^uintptr(0)
	}
	host.SetError(nil)
	return statusCode(st)
}

type asyncFn func(ctx context.Context, spec *host.CPermAsyncSpec) (plug.Status, error)

func async(specPtr uintptr, fn asyncFn) uintptr {
	spec := host.PtrTo[host.CPermAsyncSpec](specPtr)
	if spec == nil {
		host.SetError(errors.New("zighost: permissionflow async needs spec"))
		return ^uintptr(0)
	}
	// Copy fields — the Zig stack frame may vanish after return.
	copied := *spec
	reqID := nextReq.Add(1)
	host.SetError(nil)
	go func() {
		st, err := fn(context.Background(), &copied)
		var errCS host.CStr
		if err != nil {
			b := []byte(err.Error())
			errCS.Data, errCS.Len = host.SliceAddr(b)
		}
		var errPtr uintptr
		if err != nil {
			errPtr = host.PtrOf(&errCS)
		}
		callZig(host.ZigEventPermFlow, copied.CbID, reqID, statusCode(st), errPtr)
	}()
	return reqID
}

func doRequest(ctx context.Context, spec *host.CPermAsyncSpec) (plug.Status, error) {
	return plug.Request(ctx, plug.Permission(host.CopyString(spec.NamePtr, spec.NameLen)))
}

func doWait(ctx context.Context, spec *host.CPermAsyncSpec) (plug.Status, error) {
	return plug.Wait(ctx, plug.Permission(host.CopyString(spec.NamePtr, spec.NameLen)))
}

func doGuide(ctx context.Context, spec *host.CPermAsyncSpec) (plug.Status, error) {
	opts := plug.GuideOptions{
		App:  host.CopyString(spec.AppPtr, spec.AppLen),
		Name: host.CopyString(spec.NameLabelPtr, spec.NameLabelLen),
	}
	return plug.Guide(ctx, plug.Permission(host.CopyString(spec.NamePtr, spec.NameLen)), opts)
}
