package protocol

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"strings"
)

const Version = 2
const ChannelCount = 64

type Channel struct {
	ID         int    `json:"id"`
	Status     string `json:"status,omitempty"`
	R          *uint8 `json:"r,omitempty"`
	G          *uint8 `json:"g,omitempty"`
	B          *uint8 `json:"b,omitempty"`
	Brightness *uint8 `json:"brightness,omitempty"`
	Effect     string `json:"effect,omitempty"`
}

type Direct struct {
	R, G, B, Brightness uint8
	Effect              string
}

func (c Channel) Direct() (Direct, bool) {
	if c.R == nil || c.G == nil || c.B == nil || c.Brightness == nil {
		return Direct{}, false
	}
	return Direct{*c.R, *c.G, *c.B, *c.Brightness, c.Effect}, true
}

type Packet struct {
	Version  int       `json:"version"`
	SaveID   string    `json:"save_id"`
	Sequence uint64    `json:"sequence"`
	Tick     uint64    `json:"tick"`
	Type     string    `json:"type"`
	Channels []Channel `json:"channels"`
}

func Decode(data []byte) (Packet, error) {
	type wireChannel struct {
		ID         *int   `json:"id"`
		Status     string `json:"status,omitempty"`
		R          *uint8 `json:"r,omitempty"`
		G          *uint8 `json:"g,omitempty"`
		B          *uint8 `json:"b,omitempty"`
		Brightness *uint8 `json:"brightness,omitempty"`
		Effect     string `json:"effect,omitempty"`
	}
	type wirePacket struct {
		Version  int             `json:"version"`
		SaveID   string          `json:"save_id"`
		Sequence uint64          `json:"sequence"`
		Tick     uint64          `json:"tick"`
		Type     string          `json:"type"`
		Channels json.RawMessage `json:"channels"`
	}
	var wire wirePacket
	dec := json.NewDecoder(strings.NewReader(string(data)))
	dec.DisallowUnknownFields()
	if err := dec.Decode(&wire); err != nil {
		return Packet{}, fmt.Errorf("decode packet: %w", err)
	}
	var extra any
	if err := dec.Decode(&extra); !errors.Is(err, io.EOF) {
		return Packet{}, errors.New("decode packet: trailing data")
	}
	var wireChannels []wireChannel
	rawChannels := bytes.TrimSpace(wire.Channels)
	if len(rawChannels) == 0 {
		return Packet{}, errors.New("channels is required")
	}
	if bytes.Equal(rawChannels, []byte("{}")) {
		wireChannels = []wireChannel{}
	} else {
		channelDecoder := json.NewDecoder(bytes.NewReader(rawChannels))
		channelDecoder.DisallowUnknownFields()
		if err := channelDecoder.Decode(&wireChannels); err != nil {
			return Packet{}, fmt.Errorf("decode packet channels: %w", err)
		}
		if err := channelDecoder.Decode(&extra); !errors.Is(err, io.EOF) {
			return Packet{}, errors.New("decode packet channels: trailing data")
		}
	}
	p := Packet{Version: wire.Version, SaveID: wire.SaveID, Sequence: wire.Sequence, Tick: wire.Tick, Type: wire.Type}
	p.Channels = make([]Channel, 0, len(wireChannels))
	for _, c := range wireChannels {
		if c.ID == nil {
			return p, errors.New("channel id is required")
		}
		p.Channels = append(p.Channels, Channel{ID: *c.ID, Status: c.Status, R: c.R, G: c.G, B: c.B, Brightness: c.Brightness, Effect: c.Effect})
	}
	if p.Version != Version {
		return p, fmt.Errorf("unsupported version %d", p.Version)
	}
	if strings.TrimSpace(p.SaveID) == "" {
		return p, errors.New("save_id is required")
	}
	if p.Sequence == 0 {
		return p, errors.New("sequence must be positive")
	}
	if p.Type != "snapshot" && p.Type != "update" && p.Type != "reset" {
		return p, fmt.Errorf("unsupported packet type %q", p.Type)
	}
	seen := make(map[int]struct{}, len(p.Channels))
	for _, c := range p.Channels {
		if c.ID < 0 || c.ID >= ChannelCount {
			return p, fmt.Errorf("channel id %d is outside 0..%d", c.ID, ChannelCount-1)
		}
		if _, ok := seen[c.ID]; ok {
			return p, fmt.Errorf("duplicate channel %d", c.ID)
		}
		seen[c.ID] = struct{}{}
		direct, isDirect := c.Direct()
		hasDirectField := c.R != nil || c.G != nil || c.B != nil || c.Brightness != nil || c.Effect != ""
		if isDirect {
			if c.Status != "" {
				return p, fmt.Errorf("channel %d mixes status and direct color", c.ID)
			}
			if direct.Effect != "solid" && direct.Effect != "blink" && direct.Effect != "pulse" {
				return p, fmt.Errorf("channel %d has invalid effect", c.ID)
			}
		} else if hasDirectField {
			return p, fmt.Errorf("channel %d has incomplete direct color", c.ID)
		} else if strings.TrimSpace(c.Status) == "" {
			return p, fmt.Errorf("channel %d has neither status nor direct color", c.ID)
		}
	}
	return p, nil
}

func Classify(raw string) string {
	switch raw {
	case "working", "normal":
		return "working"
	case "no-ingredients", "item-ingredient-shortage", "fluid-ingredient-shortage", "no-fuel", "no-recipe":
		return "starved"
	case "full-output", "full-burnt-result-output", "waiting-for-space-in-destination":
		return "blocked"
	case "no-power", "low-power", "not-plugged-in-electric-network":
		return "no_power"
	case "disabled", "disabled-by-control-behavior", "disabled-by-script", "closed-by-circuit-network", "marked-for-deconstruction", "recipe-not-researched":
		return "disabled"
	case "missing":
		return "missing"
	default:
		return "unknown"
	}
}
