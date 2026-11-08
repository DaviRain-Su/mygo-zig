//go:build !js

// Package fetch registers a Go HTTP client for Zig apps (system proxy via
// netproxy). Import with `_ "github.com/egoist/mygo/zig/host/fetch"`.
//
// This is independent of the page IPC `plugins/fetch` service: Zig native
// apps call it directly. Response body is included as base64 in the JSON
// (`encoding/json` []byte encoding).
package fetch

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/egoist/mygo/netproxy"
	"github.com/egoist/mygo/zig/host"
)

func init() {
	host.FetchDispatch = dispatch
}

var client = &http.Client{
	Transport: netproxy.Transport(),
	Timeout:   60 * time.Second,
}

func dispatch(op, a0, a1, a2, a3 uintptr) uintptr {
	_ = a2
	_ = a3
	if op != host.HostOpFetch {
		host.SetError(errors.New("zighost: unknown fetch op"))
		return ^uintptr(0)
	}
	if a0 != host.FetchDo {
		host.SetError(errors.New("zighost: unknown fetch subop"))
		return ^uintptr(0)
	}
	return do(a1)
}

type responseJSON struct {
	Status     int         `json:"status"`
	StatusText string      `json:"statusText"`
	URL        string      `json:"url"`
	Redirected bool        `json:"redirected"`
	Headers    [][2]string `json:"headers"`
	Body       []byte      `json:"body"`
}

func do(specPtr uintptr) uintptr {
	spec := host.PtrTo[host.CFetchSpec](specPtr)
	if spec == nil {
		host.SetError(errors.New("zighost: fetch needs spec"))
		return ^uintptr(0)
	}
	method := host.CopyString(spec.MethodPtr, spec.MethodLen)
	if method == "" {
		method = http.MethodGet
	}
	urlStr := host.CopyString(spec.URLPtr, spec.URLLen)
	body := host.CopyBytes(spec.BodyPtr, spec.BodyLen)
	var bodyReader io.Reader
	if len(body) > 0 {
		bodyReader = bytes.NewReader(body)
	}
	req, err := http.NewRequestWithContext(context.Background(), method, urlStr, bodyReader)
	if err != nil {
		host.SetError(err)
		return ^uintptr(0)
	}
	if req.URL.Scheme != "http" && req.URL.Scheme != "https" {
		host.SetError(fmt.Errorf("unsupported URL scheme %q", req.URL.Scheme))
		return ^uintptr(0)
	}
	if len(body) > 0 {
		req.ContentLength = int64(len(body))
	}
	var headers [][2]string
	if spec.HeadersLen > 0 {
		if err := json.Unmarshal(host.CopyBytes(spec.HeadersPtr, spec.HeadersLen), &headers); err != nil {
			host.SetError(err)
			return ^uintptr(0)
		}
		for _, h := range headers {
			req.Header.Add(h[0], h[1])
		}
	}
	redirect := host.CopyString(spec.RedirectPtr, spec.RedirectLen)
	c := *client
	switch strings.ToLower(redirect) {
	case "", "follow":
		// default client follows
	case "error":
		c.CheckRedirect = func(*http.Request, []*http.Request) error {
			return errors.New("redirect refused")
		}
	case "manual":
		c.CheckRedirect = func(*http.Request, []*http.Request) error {
			return http.ErrUseLastResponse
		}
	default:
		host.SetError(fmt.Errorf("unknown redirect mode %q", redirect))
		return ^uintptr(0)
	}
	res, err := c.Do(req)
	if err != nil {
		host.SetError(err)
		return ^uintptr(0)
	}
	defer res.Body.Close()
	// Cap body at 16 MiB for the sync Zig binding.
	const maxBody = 16 << 20
	rawBody, err := io.ReadAll(io.LimitReader(res.Body, maxBody+1))
	if err != nil {
		host.SetError(err)
		return ^uintptr(0)
	}
	if len(rawBody) > maxBody {
		host.SetError(errors.New("zighost: response body over 16 MiB"))
		return ^uintptr(0)
	}
	outHeaders := make([][2]string, 0, len(res.Header))
	for k, vs := range res.Header {
		if strings.EqualFold(k, "Set-Cookie") || strings.EqualFold(k, "Set-Cookie2") {
			continue
		}
		for _, v := range vs {
			outHeaders = append(outHeaders, [2]string{k, v})
		}
	}
	payload, err := json.Marshal(responseJSON{
		Status:     res.StatusCode,
		StatusText: res.Status,
		URL:        res.Request.URL.String(),
		Redirected: res.Request.URL.String() != urlStr,
		Headers:    outHeaders,
		Body:       rawBody,
	})
	if err != nil {
		host.SetError(err)
		return ^uintptr(0)
	}
	host.SetError(nil)
	return host.WriteBytesToOut(payload, spec.OutPtr, spec.OutCap)
}
