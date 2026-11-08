//go:build !js

package host

import (
	"bytes"
	"encoding/base64"
	"image"
	"image/color"
	"image/png"
	"testing"

	"github.com/egoist/mygo"
)

func testPNG(t *testing.T) []byte {
	t.Helper()
	img := image.NewRGBA(image.Rect(0, 0, 2, 2))
	img.Set(0, 0, color.RGBA{R: 255, A: 255})
	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		t.Fatal(err)
	}
	return buf.Bytes()
}

func TestConvertMenuSpecCarriesIconTooltipSubtitle(t *testing.T) {
	pngBytes := testPNG(t)
	spec := []menuSpecItem{
		{
			ID:           "open",
			Label:        "Open",
			ToolTip:      "Open a file",
			Subtitle:     "Cmd+O",
			IconPNG:      base64.StdEncoding.EncodeToString(pngBytes),
			IconTemplate: true,
			Submenu: []menuSpecItem{
				{ID: "recent", Label: "Recent"},
			},
		},
		{Type: "separator"},
	}
	var clicked []string
	items := convertMenuSpec(spec, func(item *mygo.MenuItem) { clicked = append(clicked, item.ID) })
	if items[0].ToolTip != "Open a file" || items[0].Subtitle != "Cmd+O" {
		t.Fatalf("item=%+v", items[0])
	}
	if items[0].Icon == nil {
		t.Fatal("icon not decoded")
	}
	if len(items[0].Submenu) != 1 {
		t.Fatalf("submenu=%v", items[0].Submenu)
	}
	if items[0].Click != nil {
		t.Fatal("a submenu item should not take a click")
	}
	child := items[0].Submenu[0]
	if child.Click == nil {
		t.Fatal("leaf item has no click")
	}
	child.Click(child, nil)
	if len(clicked) != 1 || clicked[0] != "recent" {
		t.Fatalf("clicked=%v", clicked)
	}
}

func TestConvertMenuSpecSkipsIconsOfBadBase64(t *testing.T) {
	items := convertMenuSpec([]menuSpecItem{{ID: "a", Label: "A", IconPNG: "!!!"}}, nil)
	if items[0].Icon != nil {
		t.Fatal("bad base64 made an icon")
	}
}
