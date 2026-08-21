package service

import (
	"context"
	"fmt"
	"log/slog"
	"sync"
	"time"

	mqtt "github.com/eclipse/paho.mqtt.golang"
	"github.com/example/factorio-physical-display/daemon/internal/config"
	"github.com/example/factorio-physical-display/daemon/internal/display"
)

type Publisher interface {
	Publish(topic string, qos byte, retained bool, payload interface{}) mqtt.Token
}

type FramePublisher struct {
	mu       sync.Mutex
	client   Publisher
	log      *slog.Logger
	sequence uint64
}

func NewFramePublisher(client Publisher, log *slog.Logger) *FramePublisher {
	return &FramePublisher{client: client, log: log}
}
func (p *FramePublisher) Publish(ctx context.Context, c *config.Config, statuses map[string]string, stale bool) error {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.sequence++
	frames := display.BuildFrames(c, statuses, stale, p.sequence, 7*time.Second)
	for device, frame := range frames {
		payload, err := display.MarshalFrame(frame)
		if err != nil {
			return err
		}
		topic := fmt.Sprintf("%s/device/%s/set", c.MQTT.Prefix, device)
		token := p.client.Publish(topic, 1, true, payload)
		if !token.WaitTimeout(5 * time.Second) {
			return fmt.Errorf("publish %s timed out", topic)
		}
		if err := token.Error(); err != nil {
			return fmt.Errorf("publish %s: %w", topic, err)
		}
		p.log.DebugContext(ctx, "frame published", "device", device, "sequence", p.sequence, "stale", stale)
	}
	return nil
}

func ConnectMQTT(c *config.Config, username, password string, log *slog.Logger) (mqtt.Client, error) {
	opts := mqtt.NewClientOptions().AddBroker(c.MQTT.Broker).SetClientID(c.MQTT.ClientID).SetUsername(username).SetPassword(password)
	opts.SetAutoReconnect(true).SetConnectRetry(true).SetConnectRetryInterval(2 * time.Second)
	opts.SetConnectionLostHandler(func(_ mqtt.Client, err error) { log.Error("mqtt connection lost", "error", err) })
	opts.SetOnConnectHandler(func(_ mqtt.Client) { log.Info("mqtt connected", "broker", c.MQTT.Broker) })
	client := mqtt.NewClient(opts)
	token := client.Connect()
	if !token.WaitTimeout(15 * time.Second) {
		return nil, fmt.Errorf("mqtt connection timed out")
	}
	if err := token.Error(); err != nil {
		return nil, err
	}
	return client, nil
}
