package display

import (
	"encoding/json"
	"time"

	"github.com/example/factorio-physical-display/daemon/internal/config"
)

type Pixel struct {
	Index  int    `json:"index"`
	R      uint8  `json:"r"`
	G      uint8  `json:"g"`
	B      uint8  `json:"b"`
	Effect string `json:"effect"`
}
type Frame struct {
	Version     int     `json:"version"`
	Device      string  `json:"device"`
	Sequence    uint64  `json:"sequence"`
	ExpiresInMS uint32  `json:"expires_in_ms"`
	Brightness  uint8   `json:"brightness"`
	Pixels      []Pixel `json:"pixels"`
}

func BuildFrames(c *config.Config, statuses map[string]string, stale bool, sequence uint64, expiry time.Duration) map[string]Frame {
	frames := make(map[string]Frame, len(c.Devices))
	for id, d := range c.Devices {
		pixels := make([]Pixel, d.PixelCount)
		for i := range pixels {
			pixels[i] = Pixel{Index: i, Effect: "solid"}
		}
		frames[id] = Frame{Version: 1, Device: id, Sequence: sequence, ExpiresInMS: uint32(expiry / time.Millisecond), Brightness: c.Brightness, Pixels: pixels}
	}
	for _, m := range c.Mappings {
		status := "unknown"
		if stale {
			status = "stale_game"
		} else if s, ok := statuses[m.Channel]; ok {
			status = s
		}
		color := c.Colors[status]
		f := frames[m.Device]
		f.Pixels[m.Pixel] = Pixel{Index: m.Pixel, R: color.R, G: color.G, B: color.B, Effect: color.Effect}
		frames[m.Device] = f
	}
	return frames
}
func MarshalFrame(f Frame) ([]byte, error) { return json.Marshal(f) }
