package display

import (
	"encoding/json"
	"time"

	"github.com/example/factorio-physical-display/daemon/internal/config"
	"github.com/example/factorio-physical-display/daemon/internal/protocol"
)

type Pixel struct {
	Channel    int    `json:"channel"`
	R          uint8  `json:"r"`
	G          uint8  `json:"g"`
	B          uint8  `json:"b"`
	Brightness uint8  `json:"brightness"`
	Effect     string `json:"effect"`
}
type Frame struct {
	Version     int     `json:"version"`
	Sequence    uint64  `json:"sequence"`
	ExpiresInMS uint32  `json:"expires_in_ms"`
	Channels    []Pixel `json:"channels"`
}

func BuildFrame(c *config.Config, values map[int]Value, stale bool, sequence uint64, expiry time.Duration) Frame {
	channels := make([]Pixel, protocol.ChannelCount)
	for channel := range channels {
		channels[channel] = Pixel{Channel: channel, Brightness: 255, Effect: "solid"}
		value, ok := values[channel]
		if ok && value.Direct != nil && !stale {
			direct := value.Direct
			channels[channel] = Pixel{Channel: channel, R: direct.R, G: direct.G, B: direct.B, Brightness: direct.Brightness, Effect: direct.Effect}
			continue
		}
		if !stale && !ok {
			continue
		}
		status := "stale_game"
		if !stale {
			status = value.Status
		}
		color := c.Colors[status]
		channels[channel] = Pixel{Channel: channel, R: color.R, G: color.G, B: color.B, Brightness: 255, Effect: color.Effect}
	}
	return Frame{Version: protocol.Version, Sequence: sequence, ExpiresInMS: uint32(expiry / time.Millisecond), Channels: channels}
}
func MarshalFrame(f Frame) ([]byte, error) { return json.Marshal(f) }
