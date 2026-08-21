package config

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func valid() Config {
	return Config{MQTT: MQTT{Broker: "tcp://localhost:1883"}, Devices: map[string]Device{"d": {2}}, Mappings: []Mapping{{"a", "d", 0}}, Colors: map[string]RGB{
		"working": {Effect: "solid"}, "starved": {Effect: "pulse"}, "blocked": {Effect: "solid"}, "no_power": {Effect: "blink"},
		"disabled": {Effect: "solid"}, "missing": {Effect: "solid"}, "unknown": {Effect: "solid"}, "stale_game": {Effect: "pulse"},
	}}
}
func TestValidate(t *testing.T) {
	c := valid()
	if err := c.Validate(); err != nil {
		t.Fatal(err)
	}
	c = valid()
	c.Mappings = append(c.Mappings, Mapping{"a", "d", 1})
	if c.Validate() == nil {
		t.Error("accepted duplicate channel")
	}
	c = valid()
	c.Mappings = append(c.Mappings, Mapping{"b", "d", 0})
	if c.Validate() == nil {
		t.Error("accepted duplicate pixel")
	}
	c = valid()
	c.Mappings[0].Device = "nope"
	if c.Validate() == nil {
		t.Error("accepted unknown device")
	}
	c = valid()
	c.Mappings[0].Pixel = 2
	if c.Validate() == nil {
		t.Error("accepted out of range pixel")
	}
}

const reloadYAML = `
mqtt: {broker: tcp://localhost:1883}
brightness: 10
devices: {d: {pixel_count: 2}}
mappings: [{channel: a, device: d, pixel: 0}]
colors:
  working: {effect: solid}
  starved: {effect: pulse}
  blocked: {effect: solid}
  no_power: {effect: blink}
  disabled: {effect: solid}
  missing: {effect: solid}
  unknown: {effect: solid}
  stale_game: {effect: pulse}
`

func TestReloaderKeepsLastValidConfig(t *testing.T) {
	path := filepath.Join(t.TempDir(), "display.yaml")
	if err := os.WriteFile(path, []byte(reloadYAML), 0o600); err != nil {
		t.Fatal(err)
	}
	r, err := NewReloader(path)
	if err != nil {
		t.Fatal(err)
	}
	initial := r.Current()
	if err := os.WriteFile(path, []byte("not: [valid"), 0o600); err != nil {
		t.Fatal(err)
	}
	nextTime := time.Now().Add(2 * time.Second)
	if err := os.Chtimes(path, nextTime, nextTime); err != nil {
		t.Fatal(err)
	}
	got, changed, err := r.Check()
	if err == nil || changed || got != initial || r.Current() != initial {
		t.Fatalf("invalid reload replaced config: changed=%v err=%v", changed, err)
	}
	updated := strings.Replace(reloadYAML, "brightness: 10", "brightness: 20", 1)
	if err := os.WriteFile(path, []byte(updated), 0o600); err != nil {
		t.Fatal(err)
	}
	nextTime = nextTime.Add(2 * time.Second)
	if err := os.Chtimes(path, nextTime, nextTime); err != nil {
		t.Fatal(err)
	}
	got, changed, err = r.Check()
	if err != nil || !changed || got.Brightness != 20 {
		t.Fatalf("valid reload failed: brightness=%d changed=%v err=%v", got.Brightness, changed, err)
	}
}
