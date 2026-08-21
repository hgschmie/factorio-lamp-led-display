package service

import (
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"testing"
	"time"

	mqtt "github.com/eclipse/paho.mqtt.golang"
	"github.com/example/factorio-physical-display/daemon/internal/config"
	"github.com/example/factorio-physical-display/daemon/internal/display"
)

type testToken struct{ done chan struct{} }

func (t testToken) Wait() bool                     { return true }
func (t testToken) WaitTimeout(time.Duration) bool { return true }
func (t testToken) Done() <-chan struct{}          { return t.done }
func (t testToken) Error() error                   { return nil }

type publishedMessage struct {
	topic    string
	qos      byte
	retained bool
	payload  []byte
}
type mqttPublisher struct{ messages []publishedMessage }

func (c *mqttPublisher) Publish(topic string, qos byte, retained bool, payload interface{}) mqtt.Token {
	b, _ := payload.([]byte)
	c.messages = append(c.messages, publishedMessage{topic, qos, retained, b})
	done := make(chan struct{})
	close(done)
	return testToken{done}
}

func TestFramePublisherUsesRetainedQoS1FullFrame(t *testing.T) {
	client := &mqttPublisher{}
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	publisher := NewFramePublisher(client, logger)
	cfg := &config.Config{MQTT: config.MQTT{Prefix: config.TopicPrefix}, Brightness: 12, Devices: map[string]config.Device{"dev": {PixelCount: 2}}, Mappings: []config.Mapping{{Channel: "a", Device: "dev", Pixel: 0}}, Colors: map[string]config.RGB{"working": {G: 9, Effect: "solid"}, "unknown": {Effect: "solid"}, "stale_game": {Effect: "pulse"}}}
	if err := publisher.Publish(context.Background(), cfg, map[string]string{"a": "working"}, false); err != nil {
		t.Fatal(err)
	}
	if len(client.messages) != 1 {
		t.Fatalf("got %d messages", len(client.messages))
	}
	m := client.messages[0]
	if m.topic != "factorio-display/v1/device/dev/set" || m.qos != 1 || !m.retained {
		t.Fatalf("bad publish metadata %#v", m)
	}
	var frame display.Frame
	if err := json.Unmarshal(m.payload, &frame); err != nil {
		t.Fatal(err)
	}
	if len(frame.Pixels) != 2 || frame.Pixels[0].G != 9 || frame.Sequence != 1 {
		t.Fatalf("bad frame %#v", frame)
	}
}
