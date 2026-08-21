package main

import (
	"context"
	"flag"
	"fmt"
	"log/slog"
	"net"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/example/factorio-physical-display/daemon/internal/config"
	"github.com/example/factorio-physical-display/daemon/internal/display"
	"github.com/example/factorio-physical-display/daemon/internal/protocol"
	"github.com/example/factorio-physical-display/daemon/internal/service"
)

type received struct {
	packet protocol.Packet
	at     time.Time
}

func main() {
	configPath := flag.String("config", env("DISPLAY_CONFIG", "/config/display.yaml"), "mapping configuration")
	udpAddr := flag.String("udp", env("DISPLAY_UDP_ADDR", ":34198"), "UDP listen address")
	flag.Parse()
	log := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: logLevel()}))
	if err := run(*configPath, *udpAddr, log); err != nil {
		log.Error("daemon stopped", "error", err)
		os.Exit(1)
	}
}

func run(configPath, udpAddr string, log *slog.Logger) error {
	reloader, err := config.NewReloader(configPath)
	if err != nil {
		return fmt.Errorf("load config: %w", err)
	}
	cfg := reloader.Current()
	username, err := secret("MQTT_USERNAME", "MQTT_USERNAME_FILE")
	if err != nil {
		return err
	}
	password, err := secret("MQTT_PASSWORD", "MQTT_PASSWORD_FILE")
	if err != nil {
		return err
	}
	client, err := service.ConnectMQTT(cfg, username, password, log)
	if err != nil {
		return fmt.Errorf("connect mqtt: %w", err)
	}
	defer client.Disconnect(1000)
	addr, err := net.ResolveUDPAddr("udp", udpAddr)
	if err != nil {
		return err
	}
	conn, err := net.ListenUDP("udp", addr)
	if err != nil {
		return fmt.Errorf("listen udp: %w", err)
	}
	defer conn.Close()
	log.Info("udp listener ready", "address", conn.LocalAddr())
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()
	packets := make(chan received, 32)
	go receiveUDP(ctx, conn, packets, log)
	state := display.NewState()
	publisher := service.NewFramePublisher(client, log)
	publishTicker := time.NewTicker(5 * time.Second)
	defer publishTicker.Stop()
	watchTicker := time.NewTicker(time.Second)
	defer watchTicker.Stop()
	var lastStale = true
	publish := func() {
		statuses, stale := state.Snapshot(time.Now(), 10*time.Second)
		if err := publisher.Publish(ctx, cfg, statuses, stale); err != nil {
			log.Error("publish frames", "error", err)
		}
		lastStale = stale
	}
	publish()
	for {
		select {
		case <-ctx.Done():
			return nil
		case got := <-packets:
			if !state.Apply(got.packet, got.at) {
				log.Warn("out-of-order packet ignored", "save_id", got.packet.SaveID, "sequence", got.packet.Sequence)
				continue
			}
			log.Info("factorio packet accepted", "save_id", got.packet.SaveID, "sequence", got.packet.Sequence, "type", got.packet.Type, "channels", len(got.packet.Channels))
			publish()
		case <-publishTicker.C:
			publish()
		case <-watchTicker.C:
			if next, changed, e := reloader.Check(); e != nil {
				log.Error("config reload rejected; retaining previous config", "error", e)
			} else if changed {
				cfg = next
				log.Info("configuration reloaded")
				publish()
			}
			_, stale := state.Snapshot(time.Now(), 10*time.Second)
			if stale != lastStale {
				publish()
			}
		}
	}
}

func receiveUDP(ctx context.Context, conn *net.UDPConn, out chan<- received, log *slog.Logger) {
	buf := make([]byte, 65535)
	for {
		_ = conn.SetReadDeadline(time.Now().Add(time.Second))
		n, peer, err := conn.ReadFromUDP(buf)
		if err != nil {
			if ne, ok := err.(net.Error); ok && ne.Timeout() {
				select {
				case <-ctx.Done():
					return
				default:
					continue
				}
			}
			if ctx.Err() != nil {
				return
			}
			log.Error("udp receive failed", "error", err)
			continue
		}
		p, err := protocol.Decode(buf[:n])
		if err != nil {
			log.Warn("invalid udp packet", "peer", peer, "error", err)
			continue
		}
		select {
		case out <- received{p, time.Now()}:
		case <-ctx.Done():
			return
		}
	}
}
func env(name, fallback string) string {
	if v := os.Getenv(name); v != "" {
		return v
	}
	return fallback
}
func secret(valueName, fileName string) (string, error) {
	if path := os.Getenv(fileName); path != "" {
		b, err := os.ReadFile(path)
		if err != nil {
			return "", fmt.Errorf("read %s: %w", fileName, err)
		}
		return strings.TrimSpace(string(b)), nil
	}
	if v := os.Getenv(valueName); v != "" {
		return v, nil
	}
	return "", fmt.Errorf("%s or %s is required", valueName, fileName)
}
func logLevel() slog.Level {
	if strings.EqualFold(os.Getenv("LOG_LEVEL"), "debug") {
		return slog.LevelDebug
	}
	return slog.LevelInfo
}
