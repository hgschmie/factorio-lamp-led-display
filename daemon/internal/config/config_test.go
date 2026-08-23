package config

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func valid() Config {
	return Config{MQTT: MQTT{Broker: "tcp://localhost:1883"}, Colors: map[string]RGB{
		"working": {Effect: "solid"}, "starved": {Effect: "pulse"}, "blocked": {Effect: "solid"}, "no_power": {Effect: "blink"},
		"disabled": {Effect: "solid"}, "missing": {Effect: "solid"}, "unknown": {Effect: "solid"}, "stale_game": {Effect: "pulse"},
	}}
}
func TestValidate(t *testing.T) {
	c := valid()
	if err := c.Validate(); err != nil {
		t.Fatal(err)
	}
	c.MQTT.Prefix = "factorio-display/v1"
	if c.Validate() == nil {
		t.Error("accepted wrong protocol prefix")
	}
	c = valid()
	delete(c.Colors, "working")
	if c.Validate() == nil {
		t.Error("accepted missing required color")
	}
}

const reloadYAML = `
mqtt: {broker: tcp://localhost:1883}
colors:
  working: {r: 10, effect: solid}
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
	updated := strings.Replace(reloadYAML, "working: {r: 10", "working: {r: 20", 1)
	if err := os.WriteFile(path, []byte(updated), 0o600); err != nil {
		t.Fatal(err)
	}
	nextTime = nextTime.Add(2 * time.Second)
	if err := os.Chtimes(path, nextTime, nextTime); err != nil {
		t.Fatal(err)
	}
	got, changed, err = r.Check()
	if err != nil || !changed || got.Colors["working"].R != 20 {
		t.Fatalf("valid reload failed: working.r=%d changed=%v err=%v", got.Colors["working"].R, changed, err)
	}
}
