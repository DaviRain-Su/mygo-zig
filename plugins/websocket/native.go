package websocket

import (
	"context"
	"fmt"
	"net/http"
	"time"

	"github.com/egoist/mygo/netproxy"
)

// DialOptions configure Dial for Go and native UI (Zig) callers.
type DialOptions struct {
	// Client makes the opening handshake; nil uses netproxy.Transport().
	Client *http.Client
	// Protocols are Sec-WebSocket-Protocol values; the server's choice is
	// Conn.Protocol.
	Protocols []string
	// Headers are extra handshake headers (Authorization, Cookie, …).
	Headers [][2]string
	// MaxMessageSize is the most bytes a received message may have, 64 MiB
	// when zero.
	MaxMessageSize int64
	// CloseTimeout is how long Close waits for the peer, 5s when zero.
	CloseTimeout time.Duration
}

// Conn is a WebSocket for Go / Zig apps (not the page IPC plugin service).
type Conn struct {
	c        *conn
	protocol string
	timeout  time.Duration
}

// Dial opens a WebSocket. It is safe for native UI and Zig hosts that need
// headers browsers forbid.
func Dial(ctx context.Context, rawURL string, opts DialOptions) (*Conn, error) {
	client := opts.Client
	if client == nil {
		client = &http.Client{Transport: netproxy.Transport()}
	}
	max := opts.MaxMessageSize
	if max <= 0 {
		max = 64 << 20
	}
	timeout := opts.CloseTimeout
	if timeout <= 0 {
		timeout = 5 * time.Second
	}
	c, proto, err := dial(ctx, client, rawURL, opts.Protocols, opts.Headers, nil, max)
	if err != nil {
		return nil, err
	}
	return &Conn{c: c, protocol: proto, timeout: timeout}, nil
}

// Protocol is the subprotocol the server selected, if any.
func (c *Conn) Protocol() string { return c.protocol }

// Message is one WebSocket data or close frame from Read.
type Message struct {
	Type   string // text, binary, or close
	Text   string
	Data   []byte
	Code   int
	Reason string
}

// Read returns the next text, binary or close message. After close, further
// reads fail.
func (c *Conn) Read() (Message, error) {
	op, data, err := c.c.readMessage()
	if err != nil {
		return Message{}, err
	}
	switch op {
	case opText:
		return Message{Type: "text", Text: string(data)}, nil
	case opBinary:
		return Message{Type: "binary", Data: data}, nil
	case opClose:
		code, reason, perr := parseClose(data)
		if perr != nil {
			_ = c.c.writeClose(closeProtocolError, "")
			c.c.terminate()
			return Message{}, perr
		}
		_ = c.c.writeClose(code, "")
		c.c.terminate()
		return Message{Type: "close", Code: code, Reason: reason}, nil
	default:
		return Message{}, fmt.Errorf("websocket: unexpected opcode %d", op)
	}
}

// WriteText sends a text message.
func (c *Conn) WriteText(text string) error {
	return c.c.writeFrame(opText, []byte(text))
}

// WriteBinary sends a binary message.
func (c *Conn) WriteBinary(data []byte) error {
	return c.c.writeFrame(opBinary, data)
}

// Close starts the closing handshake.
func (c *Conn) Close(code int, reason string) error {
	if code != closeNoStatus && code != closeNormal && (code < 3000 || code > 4999) {
		return fmt.Errorf("invalid close code %d", code)
	}
	if len(reason) > 123 {
		return fmt.Errorf("close reason over 123 bytes")
	}
	return c.c.close(code, reason, c.timeout)
}
