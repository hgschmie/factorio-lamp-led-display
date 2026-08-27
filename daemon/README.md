# Factorio display daemon

The daemon receives Factorio display protocol version 2 packets over UDP, maintains the current state of 64 logical channels, and publishes complete retained frames to MQTT for the ESP32-C3 controllers.

It accepts direct RGB lamp values as well as status values, rejects malformed and out-of-order packets, and switches the complete frame to the configured `stale_game` color when no full snapshot or reset has arrived for more than ten seconds.

See [the protocol reference](../docs/protocol.md) for packet schemas, sequence behavior, and MQTT topics.

## Dependencies

For a native build:

- Go 1.24 or newer, as declared by `go.mod`.
- An MQTT 3.1.1 broker reachable from the daemon.
- A version 2 UDP sender, normally the `lamp_led_display` Factorio mod.
- A valid YAML configuration file.

Direct Go dependencies are:

- `github.com/eclipse/paho.mqtt.golang` for MQTT.
- `gopkg.in/yaml.v3` for strict YAML parsing.

The daemon does not require CGo. The Docker build uses `golang:1.26-alpine`, produces a static binary, and copies it into an `alpine:3.24` runtime image. No runtime packages are installed, and the process runs as numeric UID/GID `65532` rather than root.

## Build and test

From the repository root:

```sh
cd daemon
go test ./...
go build -o factorio-display ./cmd/factorio-display
```

The repository Makefile also provides:

```sh
make test-go
```

Build the container from the repository root:

```sh
docker build -t factorio-display-daemon ./daemon
```

The equivalent optimized static build used by the Dockerfile is:

```sh
cd daemon
CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o factorio-display ./cmd/factorio-display
```

## Configuration file

Start from the repository example:

```sh
cp config.example.yaml config.yaml
```

The schema is:

```yaml
mqtt:
  broker: tcp://localhost:1883
  client_id: factorio-display-daemon
  prefix: factorio-display/v2

colors:
  working:    {r: 0,   g: 255, b: 0,   effect: solid}
  starved:    {r: 255, g: 180, b: 0,   effect: pulse}
  blocked:    {r: 255, g: 0,   b: 0,   effect: solid}
  no_power:   {r: 0,   g: 80,  b: 255, effect: blink}
  disabled:   {r: 150, g: 0,   b: 255, effect: solid}
  missing:    {r: 255, g: 0,   b: 180, effect: solid}
  unknown:    {r: 255, g: 255, b: 255, effect: solid}
  stale_game: {r: 0,   g: 255, b: 255, effect: pulse}
```

Configuration rules:

- `mqtt.broker` is required. Paho accepts broker URLs such as `tcp://localhost:1883`.
- `mqtt.client_id` defaults to `factorio-display-daemon` when omitted.
- `mqtt.prefix` defaults to, and must equal, `factorio-display/v2`. A trailing slash is removed before validation.
- Every listed color is required, even if the current Factorio mod sends only direct RGB lamp records.
- RGB components are YAML integers in `0..255`.
- Effects must be `solid`, `blink`, or `pulse`.
- Unknown YAML fields are rejected.

The daemon checks the file modification time once per second. A fully valid edit is applied without restart and immediately publishes a new frame. Invalid changes are logged and the previous valid configuration remains active. MQTT broker and client-ID changes are rejected during reload and require a restart. The protocol prefix is fixed and cannot be changed.

## Command-line interface

```text
factorio-display [-config PATH] [-udp ADDRESS]
```

| Flag | Environment fallback | Default | Description |
| --- | --- | --- | --- |
| `-config PATH` | `DISPLAY_CONFIG` | `/config/display.yaml` | YAML configuration file |
| `-udp ADDRESS` | `DISPLAY_UDP_ADDR` | `:34198` | Address passed to Go's UDP listener |

An explicitly supplied flag overrides its environment fallback. Useful UDP values include:

- `:34198` to listen on all interfaces.
- `127.0.0.1:34198` to listen only on host loopback.
- `:44198` to use a different port for testing.

## Environment variables

| Variable | Required | Purpose |
| --- | --- | --- |
| `DISPLAY_CONFIG` | No | Default for `-config` |
| `DISPLAY_UDP_ADDR` | No | Default for `-udp` |
| `MQTT_USERNAME_FILE` | One username source | Read the MQTT username from a file |
| `MQTT_USERNAME` | One username source | Supply the MQTT username directly |
| `MQTT_PASSWORD_FILE` | One password source | Read the MQTT password from a file |
| `MQTT_PASSWORD` | One password source | Supply the MQTT password directly |
| `LOG_LEVEL` | No | Set to `debug` for debug logging; every other value uses `info` |

For each credential, the corresponding `*_FILE` variable takes precedence over the direct value. Leading and trailing whitespace is removed from file contents. File-based credentials are recommended because direct environment values may be exposed by process or container inspection.

## Run the native binary

Using direct credential variables:

```sh
cd daemon
MQTT_USERNAME=daemon \
MQTT_PASSWORD='replace-me' \
./factorio-display \
  -config ../config.yaml \
  -udp 127.0.0.1:34198
```

Using credential files:

```sh
cd daemon
MQTT_USERNAME_FILE=../secrets/daemon_username \
MQTT_PASSWORD_FILE=../secrets/daemon_password \
LOG_LEVEL=debug \
./factorio-display \
  -config ../config.yaml \
  -udp 127.0.0.1:34198
```

For a native process, set `mqtt.broker` to a broker address reachable from the host, commonly `tcp://localhost:1883`. The example configuration uses `tcp://mosquitto:1883`, which is the Compose service name and normally resolves only inside the Compose network.

The process writes structured JSON logs to standard output. `SIGINT` and `SIGTERM` trigger a graceful shutdown, including MQTT disconnect and UDP listener cleanup.

## Run with Docker Compose

From the repository root:

```sh
cp config.example.yaml config.yaml
./scripts/create-credentials.sh
docker compose up -d --build
docker compose logs -f daemon
```

The supplied Compose model:

- Builds the daemon from `daemon/Dockerfile`.
- Mounts `config.yaml` read-only at `/config/display.yaml`.
- supplies the daemon username/password through Compose secrets.
- publishes container UDP port `34198` as `127.0.0.1:34198/udp` on the host.
- connects to Mosquitto at `tcp://mosquitto:1883`.
- publishes Mosquitto TCP port `1883` to the LAN for controllers.

Stop the stack with:

```sh
docker compose down
```

## Runtime behavior

On startup the daemon validates configuration and credentials, connects to MQTT, opens the UDP socket, and publishes an initial stale frame. It then:

- Publishes immediately after every accepted UDP packet.
- Republishes the retained complete frame every five seconds.
- Publishes immediately after a valid color reload or stale/fresh transition.
- Uses a seven-second relative frame expiry.
- Treats Factorio as stale after ten seconds without a valid `snapshot` or `reset`; an `update` alone does not refresh this heartbeat.
- Accepts an authoritative `reset` even when its Factorio sequence is lower, then uses that reset sequence as the new baseline.
- Publishes retained QoS 1 frames to `factorio-display/v2/channels/set`.

Malformed UDP packets and out-of-order non-reset packets are logged and ignored. MQTT publishing errors are logged without terminating the main loop. Startup failures, including an unreadable configuration, missing credentials, MQTT connection failure, or inability to bind UDP, terminate the process with a nonzero exit status.

## Security and networking

Factorio's Lua UDP API is localhost-only, so a host-native daemon should bind to `127.0.0.1:34198`. Compose safely achieves the same host exposure even though the daemon listens on `:34198` inside its container.

The included Mosquitto setup uses username/password authentication without TLS. It is intended for a trusted LAN. The `daemon` user can publish global frames and read device availability/telemetry; the `device` user can read global frames and publish device availability/telemetry.
