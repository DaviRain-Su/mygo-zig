//go:build !js

package host

import (
	"bytes"
	"errors"
	"math"
	"sync"
	"sync/atomic"
	"time"

	"github.com/egoist/mygo/audio"
)

// Zig audio bindings: sounds decoded into memory and players, by handle.
var (
	audioMu      sync.Mutex
	audioSeq     atomic.Uint64
	audioSounds  = map[uintptr]*audio.Sound{}
	audioPlayers = map[uintptr]*audio.Player{}
	audioEndCbs  = map[uintptr]uintptr{}
)

func nextAudioID() uintptr {
	for {
		id := uintptr(audioSeq.Add(1))
		audioMu.Lock()
		_, isSound := audioSounds[id]
		_, isPlayer := audioPlayers[id]
		audioMu.Unlock()
		if !isSound && !isPlayer {
			return id
		}
	}
}

func audioSound(id uintptr) *audio.Sound {
	audioMu.Lock()
	defer audioMu.Unlock()
	return audioSounds[id]
}

func audioPlayer(id uintptr) *audio.Player {
	audioMu.Lock()
	defer audioMu.Unlock()
	return audioPlayers[id]
}

func floatBits(v float64) uintptr { return uintptr(math.Float64bits(v)) }
func bitsFloat(v uintptr) float64 { return math.Float64frombits(uint64(v)) }

func hostAudio(sub, a1, a2, a3 uintptr) uintptr {
	switch sub {
	case AudioDecodeSound:
		sound, err := audio.DecodeSound(CopyBytes(a1, a2))
		if err != nil {
			SetError(err)
			return 0
		}
		id := nextAudioID()
		audioMu.Lock()
		audioSounds[id] = sound
		audioMu.Unlock()
		return id
	case AudioSoundDuration:
		s := audioSound(a1)
		if s == nil {
			return 0
		}
		return uintptr(s.Duration() / time.Millisecond)
	case AudioSoundPlay:
		s := audioSound(a1)
		if s == nil {
			return 0
		}
		p := s.Play()
		id := nextAudioID()
		audioMu.Lock()
		audioPlayers[id] = p
		audioMu.Unlock()
		return id
	case AudioOpenStream:
		p, err := audio.OpenStream(bytes.NewReader(CopyBytes(a1, a2)))
		if err != nil {
			SetError(err)
			return 0
		}
		id := nextAudioID()
		audioMu.Lock()
		audioPlayers[id] = p
		audioMu.Unlock()
		return id
	case AudioPlayerPlay:
		if p := audioPlayer(a1); p != nil {
			p.Play()
		}
	case AudioPlayerPause:
		if p := audioPlayer(a1); p != nil {
			p.Pause()
		}
	case AudioPlayerStop:
		if p := audioPlayer(a1); p != nil {
			p.Stop()
		}
	case AudioPlayerClose:
		audioMu.Lock()
		p := audioPlayers[a1]
		delete(audioPlayers, a1)
		delete(audioEndCbs, a1)
		audioMu.Unlock()
		if p != nil {
			p.Close()
		}
	case AudioPlayerPlaying:
		if p := audioPlayer(a1); p != nil && p.Playing() {
			return 1
		}
		return 0
	case AudioPlayerSetVolume:
		if p := audioPlayer(a1); p != nil {
			p.SetVolume(bitsFloat(a2))
		}
	case AudioPlayerVolume:
		if p := audioPlayer(a1); p != nil {
			return floatBits(p.Volume())
		}
		return floatBits(1)
	case AudioPlayerSetPan:
		if p := audioPlayer(a1); p != nil {
			p.SetPan(bitsFloat(a2))
		}
	case AudioPlayerPan:
		if p := audioPlayer(a1); p != nil {
			return floatBits(p.Pan())
		}
	case AudioPlayerSetSpeed:
		if p := audioPlayer(a1); p != nil {
			p.SetSpeed(bitsFloat(a2))
		}
	case AudioPlayerSpeed:
		if p := audioPlayer(a1); p != nil {
			return floatBits(p.Speed())
		}
	case AudioPlayerSetLoop:
		if p := audioPlayer(a1); p != nil {
			p.SetLoop(a2 != 0)
		}
	case AudioPlayerLoop:
		if p := audioPlayer(a1); p != nil && p.Loop() {
			return 1
		}
		return 0
	case AudioPlayerSeek:
		if p := audioPlayer(a1); p != nil {
			p.Seek(time.Duration(a2) * time.Millisecond)
		}
	case AudioPlayerPosition:
		if p := audioPlayer(a1); p != nil {
			return uintptr(p.Position() / time.Millisecond)
		}
		return 0
	case AudioPlayerDuration:
		if p := audioPlayer(a1); p != nil {
			return uintptr(p.Duration() / time.Millisecond)
		}
		return 0
	case AudioPlayerSetLoopRange:
		if p := audioPlayer(a1); p != nil {
			p.SetLoopRange(time.Duration(a2)*time.Millisecond, time.Duration(a3)*time.Millisecond)
		}
	case AudioPlayerOnEnd:
		p := audioPlayer(a1)
		if p == nil {
			return 0
		}
		cbID := a2
		ud := a3
		playerID := a1
		p.OnEnd(func() { activeCall(ZigEventAudioEnd, cbID, playerID, ud, 0) })
		audioMu.Lock()
		audioEndCbs[playerID] = cbID
		audioMu.Unlock()
		return 0
	default:
		SetError(errors.New("zighost: unknown audio subop"))
		return ^uintptr(0)
	}
	return 0
}
