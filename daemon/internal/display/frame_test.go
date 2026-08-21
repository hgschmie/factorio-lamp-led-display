package display

import (
	"github.com/example/factorio-physical-display/daemon/internal/config"
	"testing"
	"time"
)

func frameConfig() *config.Config {
	return &config.Config{Brightness: 32, Devices: map[string]config.Device{"d": {PixelCount: 2}}, Mappings: []config.Mapping{{Channel: "a", Device: "d", Pixel: 1}}, Colors: map[string]config.RGB{"working": {R: 1, Effect: "solid"}, "unknown": {R: 2, Effect: "solid"}, "stale_game": {B: 3, Effect: "pulse"}}}
}
func TestBuildFrames(t *testing.T) {
	f := BuildFrames(frameConfig(), map[string]string{"a": "working"}, false, 7, 7*time.Second)["d"]
	if len(f.Pixels) != 2 || f.Pixels[1].R != 1 || f.Sequence != 7 || f.ExpiresInMS != 7000 {
		t.Fatalf("bad frame %#v", f)
	}
	f = BuildFrames(frameConfig(), nil, true, 8, 7*time.Second)["d"]
	if f.Pixels[1].B != 3 || f.Pixels[1].Effect != "pulse" {
		t.Fatalf("bad stale frame %#v", f)
	}
}
