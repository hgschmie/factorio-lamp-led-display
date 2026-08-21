package protocol

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"strings"
)

const Version = 1

type Channel struct {
	ID     string `json:"id"`
	Status string `json:"status"`
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
	var p Packet
	dec := json.NewDecoder(strings.NewReader(string(data)))
	dec.DisallowUnknownFields()
	if err := dec.Decode(&p); err != nil {
		return p, fmt.Errorf("decode packet: %w", err)
	}
	var extra any
	if err := dec.Decode(&extra); !errors.Is(err, io.EOF) {
		return p, errors.New("decode packet: trailing data")
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
	if p.Type != "snapshot" && p.Type != "update" {
		return p, fmt.Errorf("unsupported packet type %q", p.Type)
	}
	seen := make(map[string]struct{}, len(p.Channels))
	for _, c := range p.Channels {
		if strings.TrimSpace(c.ID) == "" {
			return p, errors.New("channel id is required")
		}
		if _, ok := seen[c.ID]; ok {
			return p, fmt.Errorf("duplicate channel %q", c.ID)
		}
		seen[c.ID] = struct{}{}
		if strings.TrimSpace(c.Status) == "" {
			return p, fmt.Errorf("channel %q has empty status", c.ID)
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
