package display

import (
	"github.com/example/factorio-physical-display/daemon/internal/config"
	"github.com/example/factorio-physical-display/daemon/internal/protocol"
	"testing"
	"time"
)

func frameConfig() *config.Config {
	return &config.Config{Colors: map[string]config.RGB{"working": {R: 1, Effect: "solid"}, "unknown": {R: 2, Effect: "solid"}, "stale_game": {B: 3, Effect: "pulse"}}}
}
func TestBuildFrame(t *testing.T) {
	f := BuildFrame(frameConfig(), map[int]Value{1: {Status: "working"}}, false, 7, 7*time.Second)
	if len(f.Channels) != protocol.ChannelCount || f.Channels[1].R != 1 || f.Channels[0].R != 0 || f.Sequence != 7 || f.ExpiresInMS != 7000 {
		t.Fatalf("bad frame %#v", f)
	}
	f = BuildFrame(frameConfig(), nil, true, 8, 7*time.Second)
	if f.Channels[0].B != 3 || f.Channels[63].B != 3 || f.Channels[1].Effect != "pulse" {
		t.Fatalf("bad stale frame %#v", f)
	}
	direct := &protocol.Direct{R: 4, G: 5, B: 6, Brightness: 77, Effect: "blink"}
	f = BuildFrame(frameConfig(), map[int]Value{63: {Direct: direct}}, false, 9, 7*time.Second)
	if f.Channels[63].R != 4 || f.Channels[63].Brightness != 77 || f.Channels[63].Effect != "blink" {
		t.Fatalf("bad direct frame %#v", f)
	}
	payload, err := MarshalFrame(f)
	if err != nil {
		t.Fatal(err)
	}
	if len(payload) >= 8000 {
		t.Fatalf("64-channel frame is too large for the firmware MQTT buffer: %d bytes", len(payload))
	}
}
