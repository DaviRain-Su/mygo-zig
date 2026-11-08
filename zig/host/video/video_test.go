//go:build !js

package video

import (
	"bytes"
	"image"
	"image/color"
	"image/png"
	"testing"
	"unsafe"

	"github.com/egoist/mygo/zig/host"
)

func pngBytes(t *testing.T) []byte {
	t.Helper()
	img := image.NewRGBA(image.Rect(0, 0, 2, 2))
	img.Set(1, 1, color.RGBA{R: 255, A: 255})
	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		t.Fatal(err)
	}
	return buf.Bytes()
}

func specOf(key string, payload []byte, loop bool) *CSpec {
	kp, kn := host.SliceAddr([]byte(key))
	pp, pn := host.SliceAddr(payload)
	return &CSpec{KeyPtr: kp, KeyLen: kn, Ptr: pp, Len: pn, Loop: b2u(loop)}
}

func b2u(b bool) uint32 {
	if b {
		return 1
	}
	return 0
}

func TestAPNGRegistersAPlayer(t *testing.T) {
	key := "apng-test"
	data := pngBytes(t)
	spec := specOf(key, data, true)
	if got := dispatch(host.HostOpVideo, opAPNG, uintptr(unsafe.Pointer(spec)), 0, 0); got != 0 {
		t.Fatalf("apng = %d", got)
	}
	p := source(key)
	if p == nil {
		t.Fatal("no player for the APNG")
	}
	if !p.Loop() {
		t.Fatal("APNG player should loop")
	}
	dispatch(host.HostOpVideo, opRelease, uintptr(unsafe.Pointer(specOf(key, nil, false))), 0, 0)
	if source(key) != nil {
		t.Fatal("release kept the player")
	}
}

func TestOpenDataLoadsInTheBackground(t *testing.T) {
	// A video opens at once and loads later: bad bytes make a player whose
	// Err reports the failure, not an error from the open call.
	key := "bad.mp4"
	spec := specOf(key, []byte("not a video"), false)
	if got := dispatch(host.HostOpVideo, opOpenData, uintptr(unsafe.Pointer(spec)), 0, 0); got != 0 {
		t.Fatalf("open = %d", got)
	}
	if source(key) == nil {
		t.Fatal("no player for the opened data")
	}
	dispatch(host.HostOpVideo, opRelease, uintptr(unsafe.Pointer(specOf(key, nil, false))), 0, 0)
	host.SetError(nil)
}

func TestReleaseUnknownKeyIsSafe(t *testing.T) {
	dispatch(host.HostOpVideo, opRelease, uintptr(unsafe.Pointer(specOf("nope", nil, false))), 0, 0)
}

func TestAPNGWithBadBytesFails(t *testing.T) {
	key := "bad-apng"
	spec := specOf(key, []byte("nope"), false)
	dispatch(host.HostOpVideo, opAPNG, uintptr(unsafe.Pointer(spec)), 0, 0)
	if p := source(key); p != nil {
		t.Fatal("bad APNG made a player")
	}
	host.SetError(nil)
}
