//go:build !js

package host

import "encoding/binary"

// WriteToOut copies b into a caller buffer, returning len(b).
func WriteToOut(b []byte, outPtr, outCap uintptr) uintptr {
	return writeBytesToOut(b, outPtr, outCap)
}

// WriteStrListOut writes a string list into a caller buffer: u16 count, then
// each string as u32 length and bytes, as ui.readStrList reads it.
func WriteStrListOut(items []string, outPtr, outCap uintptr) int {
	if outPtr == 0 || outCap < 2 {
		return 0
	}
	dst := BytesView(outPtr, outCap)
	need := 2
	for _, s := range items {
		need += 4 + len(s)
	}
	if need > len(dst) {
		return 0
	}
	binary.LittleEndian.PutUint16(dst[0:2], uint16(len(items)))
	off := 2
	for _, s := range items {
		binary.LittleEndian.PutUint32(dst[off:off+4], uint32(len(s)))
		off += 4
		copy(dst[off:], s)
		off += len(s)
	}
	return len(items)
}

// CallZig calls the Zig entry, for a package that needs one callback of its own.
func CallZig(kind, a0, a1, a2, a3 uintptr) uintptr {
	if activeCall == nil {
		return 0
	}
	return activeCall(kind, a0, a1, a2, a3)
}

// CallZigPayload calls the Zig entry with a JSON payload in a1/a2.
func CallZigPayload(kind, cb uintptr, payload []byte) {
	if activeCall == nil {
		return
	}
	ptr, n := SliceAddr(payload)
	activeCall(kind, cb, ptr, n, 0)
}
