//go:build !js

// Package websocket registers `plugins/websocket.Dial` for Zig apps.
// Import with `_ "github.com/egoist/mygo/zig/host/websocket"`.
package websocket

import (
	"context"
	"encoding/json"
	"errors"
	"sync"
	"sync/atomic"

	plug "github.com/egoist/mygo/plugins/websocket"
	"github.com/egoist/mygo/zig/host"
)

func init() {
	host.WebSocketDispatch = dispatch
}

var (
	connsMu sync.Mutex
	conns   = map[uintptr]*plug.Conn{}
	nextID  atomic.Uintptr
	callZig host.CallZigFn
)

func dispatch(call host.CallZigFn, op, a0, a1, a2, a3 uintptr) uintptr {
	callZig = call
	if op != host.HostOpWebSocket {
		host.SetError(errors.New("zighost: unknown websocket op"))
		return ^uintptr(0)
	}
	switch a0 {
	case host.WSConnect:
		return connect(a1)
	case host.WSSendText:
		if c := get(a1); c != nil {
			if err := c.WriteText(host.CopyString(a2, a3)); err != nil {
				host.SetError(err)
				return ^uintptr(0)
			}
			host.SetError(nil)
		}
		return 0
	case host.WSSendBinary:
		if c := get(a1); c != nil {
			if err := c.WriteBinary(host.CopyBytes(a2, a3)); err != nil {
				host.SetError(err)
				return ^uintptr(0)
			}
			host.SetError(nil)
		}
		return 0
	case host.WSClose:
		return closeConn(a1, a2, a3)
	default:
		host.SetError(errors.New("zighost: unknown websocket subop"))
		return ^uintptr(0)
	}
}

func connect(specPtr uintptr) uintptr {
	spec := host.PtrTo[host.CWSConnectSpec](specPtr)
	if spec == nil {
		host.SetError(errors.New("zighost: websocket.connect needs spec"))
		return ^uintptr(0)
	}
	var protocols []string
	if spec.ProtocolsLen > 0 {
		if err := json.Unmarshal(host.CopyBytes(spec.ProtocolsPtr, spec.ProtocolsLen), &protocols); err != nil {
			host.SetError(err)
			return ^uintptr(0)
		}
	}
	var headers [][2]string
	if spec.HeadersLen > 0 {
		if err := json.Unmarshal(host.CopyBytes(spec.HeadersPtr, spec.HeadersLen), &headers); err != nil {
			host.SetError(err)
			return ^uintptr(0)
		}
	}
	c, err := plug.Dial(context.Background(), host.CopyString(spec.URLPtr, spec.URLLen), plug.DialOptions{
		Protocols: protocols,
		Headers:   headers,
	})
	if err != nil {
		host.SetError(err)
		return ^uintptr(0)
	}
	host.SetError(nil)
	id := nextID.Add(1)
	connsMu.Lock()
	conns[id] = c
	connsMu.Unlock()
	cb := spec.EventCb
	if cb != 0 {
		proto := c.Protocol()
		b := []byte(proto)
		cs := host.CStr{}
		cs.Data, cs.Len = host.SliceAddr(b)
		callZig(host.ZigEventWebSocket, cb, id, host.WSEvOpen, host.PtrOf(&cs))
	}
	go pump(id, c, cb)
	return id
}

func pump(id uintptr, c *plug.Conn, cb uintptr) {
	defer func() {
		connsMu.Lock()
		delete(conns, id)
		connsMu.Unlock()
		_ = c.Close(1000, "")
	}()
	for {
		m, err := c.Read()
		if err != nil {
			if cb != 0 {
				raw, _ := json.Marshal(map[string]any{"code": 0, "reason": "", "clean": false, "error": err.Error()})
				cs := host.CStr{}
				cs.Data, cs.Len = host.SliceAddr(raw)
				callZig(host.ZigEventWebSocket, cb, id, host.WSEvClose, host.PtrOf(&cs))
			}
			return
		}
		if cb == 0 {
			if m.Type == "close" {
				return
			}
			continue
		}
		switch m.Type {
		case "text":
			b := []byte(m.Text)
			cs := host.CStr{}
			cs.Data, cs.Len = host.SliceAddr(b)
			callZig(host.ZigEventWebSocket, cb, id, host.WSEvText, host.PtrOf(&cs))
		case "binary":
			cs := host.CStr{}
			cs.Data, cs.Len = host.SliceAddr(m.Data)
			callZig(host.ZigEventWebSocket, cb, id, host.WSEvBinary, host.PtrOf(&cs))
		case "close":
			raw, _ := json.Marshal(map[string]any{"code": m.Code, "reason": m.Reason, "clean": true, "error": ""})
			cs := host.CStr{}
			cs.Data, cs.Len = host.SliceAddr(raw)
			callZig(host.ZigEventWebSocket, cb, id, host.WSEvClose, host.PtrOf(&cs))
			return
		}
	}
}

func closeConn(id, code, reasonSpec uintptr) uintptr {
	c := get(id)
	if c == nil {
		return 0
	}
	reason := ""
	if cs := host.PtrTo[host.CStr](reasonSpec); cs != nil {
		reason = host.StrField(*cs)
	}
	if code == 0 {
		code = 1000
	}
	if err := c.Close(int(code), reason); err != nil {
		host.SetError(err)
		return ^uintptr(0)
	}
	host.SetError(nil)
	return 0
}

func get(id uintptr) *plug.Conn {
	connsMu.Lock()
	defer connsMu.Unlock()
	return conns[id]
}
