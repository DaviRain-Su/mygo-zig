//go:build !js

// Package video registers native video and animated PNGs into `zig/host`,
// for `ui.Video` elements built by Zig.
//
// Import with `_ "github.com/egoist/mygo/zig/host/video"` in Zig apps that
// play video files, streams or APNGs; the system's media framework decodes
// them (AVFoundation, Media Foundation, GStreamer, the video element).
package video

import (
	"errors"
	"sync"

	mygoui "github.com/egoist/mygo/ui"
	"github.com/egoist/mygo/ui/video"
	"github.com/egoist/mygo/zig/host"
	zigui "github.com/egoist/mygo/zig/host/ui"
)

func init() {
	host.VideoDispatch = dispatch
	zigui.VideoSource = source
}

// Sub-ops of host.HostOpVideo.
const (
	opOpenFile uintptr = 1 // a1=*CSpec
	opOpenData uintptr = 2 // a1=*CSpec
	opOpenURL  uintptr = 3 // a1=*CSpec
	opAPNG     uintptr = 4 // a1=*CSpec
	opRelease  uintptr = 5 // a1=key
)

// CSpec opens or registers a video under a key. Loop applies to openings;
// APNGs loop with Kind 0 and the flag.
type CSpec struct {
	KeyPtr, KeyLen uintptr
	Ptr, Len       uintptr
	Loop           uint32
	_              [4]byte
}

var (
	mu      sync.Mutex
	players = map[string]*mygoui.VideoPlayer{}
	apngs   = map[string]apngAsset{}
)

type apngAsset struct {
	data []byte
	loop bool
}

func source(key string) *mygoui.VideoPlayer {
	mu.Lock()
	defer mu.Unlock()
	if p, ok := players[key]; ok {
		return p
	}
	a, ok := apngs[key]
	if !ok {
		return nil
	}
	dec, err := mygoui.NewAPNGDecoder(a.data)
	if err != nil {
		host.SetError(err)
		return nil
	}
	p, err := mygoui.NewVideoPlayer(dec)
	if err != nil {
		host.SetError(err)
		return nil
	}
	if a.loop {
		p.SetLoop(true)
	}
	players[key] = p
	return p
}

func store(key string, p *mygoui.VideoPlayer, loop bool) {
	if loop {
		p.SetLoop(true)
	}
	mu.Lock()
	if old, ok := players[key]; ok && old != p {
		old.Close()
	}
	players[key] = p
	mu.Unlock()
}

func dispatch(op, a0, a1, a2, a3 uintptr) uintptr {
	if op != host.HostOpVideo {
		return ^uintptr(0)
	}
	spec := host.PtrTo[CSpec](a1)
	switch a0 {
	case opRelease:
		mu.Lock()
		p := players[spec2key(a1)]
		delete(players, spec2key(a1))
		delete(apngs, spec2key(a1))
		mu.Unlock()
		if p != nil {
			p.Close()
		}
		return 0
	}
	if spec == nil {
		return ^uintptr(0)
	}
	key := host.CopyString(spec.KeyPtr, spec.KeyLen)
	if key == "" {
		host.SetError(errors.New("zighost: video needs a key"))
		return ^uintptr(0)
	}
	switch a0 {
	case opAPNG:
		mu.Lock()
		apngs[key] = apngAsset{data: host.CopyBytes(spec.Ptr, spec.Len), loop: spec.Loop != 0}
		mu.Unlock()
		return 0
	case opOpenFile:
		p, err := video.Open(host.CopyString(spec.Ptr, spec.Len))
		if err != nil {
			host.SetError(err)
			return ^uintptr(0)
		}
		store(key, p, spec.Loop != 0)
		return 0
	case opOpenData:
		p, err := video.OpenData(host.CopyBytes(spec.Ptr, spec.Len))
		if err != nil {
			host.SetError(err)
			return ^uintptr(0)
		}
		store(key, p, spec.Loop != 0)
		return 0
	case opOpenURL:
		p, err := video.OpenURL(host.CopyString(spec.Ptr, spec.Len))
		if err != nil {
			host.SetError(err)
			return ^uintptr(0)
		}
		store(key, p, spec.Loop != 0)
		return 0
	}
	return ^uintptr(0)
}

// spec2key reads the key of a release spec: a1 is the CSpec pointer, whose
// first two fields are the key.
func spec2key(a1 uintptr) string {
	spec := host.PtrTo[CSpec](a1)
	if spec == nil {
		return ""
	}
	return host.CopyString(spec.KeyPtr, spec.KeyLen)
}
