package config

import (
	"fmt"
	"os"
	"strings"
	"time"

	"gopkg.in/yaml.v3"
)

const TopicPrefix = "factorio-display/v2"

type RGB struct {
	R      uint8  `yaml:"r" json:"r"`
	G      uint8  `yaml:"g" json:"g"`
	B      uint8  `yaml:"b" json:"b"`
	Effect string `yaml:"effect" json:"effect"`
}

type MQTT struct {
	Broker   string `yaml:"broker"`
	ClientID string `yaml:"client_id"`
	Prefix   string `yaml:"prefix"`
}
type Config struct {
	MQTT   MQTT           `yaml:"mqtt"`
	Colors map[string]RGB `yaml:"colors"`
}

var requiredColors = []string{"working", "starved", "blocked", "no_power", "disabled", "missing", "unknown", "stale_game"}

func Load(path string) (*Config, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var c Config
	dec := yaml.NewDecoder(strings.NewReader(string(b)))
	dec.KnownFields(true)
	if err := dec.Decode(&c); err != nil {
		return nil, fmt.Errorf("parse config: %w", err)
	}
	if err := c.Validate(); err != nil {
		return nil, err
	}
	return &c, nil
}

func (c *Config) Validate() error {
	if c.MQTT.Broker == "" {
		return fmt.Errorf("mqtt.broker is required")
	}
	if c.MQTT.ClientID == "" {
		c.MQTT.ClientID = "factorio-display-daemon"
	}
	if c.MQTT.Prefix == "" {
		c.MQTT.Prefix = TopicPrefix
	}
	c.MQTT.Prefix = strings.TrimSuffix(c.MQTT.Prefix, "/")
	if c.MQTT.Prefix != TopicPrefix {
		return fmt.Errorf("mqtt.prefix must be %q for protocol version 2", TopicPrefix)
	}
	for _, name := range requiredColors {
		color, ok := c.Colors[name]
		if !ok {
			return fmt.Errorf("colors.%s is required", name)
		}
		if color.Effect != "solid" && color.Effect != "blink" && color.Effect != "pulse" {
			return fmt.Errorf("colors.%s.effect must be solid, blink, or pulse", name)
		}
	}
	return nil
}

type Reloader struct {
	path    string
	modTime time.Time
	current *Config
}

func NewReloader(path string) (*Reloader, error) {
	c, err := Load(path)
	if err != nil {
		return nil, err
	}
	r := &Reloader{path: path, current: c}
	if st, e := os.Stat(path); e == nil {
		r.modTime = st.ModTime()
	}
	return r, nil
}
func (r *Reloader) Current() *Config { return r.current }
func (r *Reloader) Check() (*Config, bool, error) {
	st, err := os.Stat(r.path)
	if err != nil {
		return r.current, false, err
	}
	if !st.ModTime().After(r.modTime) {
		return r.current, false, nil
	}
	r.modTime = st.ModTime()
	c, err := Load(r.path)
	if err != nil {
		return r.current, false, err
	}
	if c.MQTT.Broker != r.current.MQTT.Broker || c.MQTT.ClientID != r.current.MQTT.ClientID {
		return r.current, false, fmt.Errorf("mqtt broker and client_id changes require a daemon restart")
	}
	r.current = c
	return c, true, nil
}
