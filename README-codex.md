# Lamp LED Display

This monorepo mirrors circuit-controlled Factorio 2.1 lamps on physical NeoPixels. The Factorio mod reports up to 64 lamp channels over localhost UDP, the Go daemon converts them into a retained global MQTT frame, and each ESP32-C3 controller displays a configured slice of that frame.

```text
Factorio lamps ── UDP 127.0.0.1:34198 ──► Go daemon ── MQTT ──► ESP32-C3 ──► NeoPixels
```

The current mod is lamp-only. It does not monitor crafting machines and does not add a separate lamp entity; it assigns ordinary Factorio lamps, including compatible lamps supplied by other mods.

## Quick start

Requirements are Factorio 2.1, Docker with Compose, PlatformIO, an ESP32-C3 SuperMini, a 74AHCT125-compatible level shifter, and the parts described in [the wiring guide](docs/wiring.md).

### 1. Start Mosquitto and the daemon

Create the local configuration and separate credentials for the daemon and devices:

```sh
cp config.example.yaml config.yaml
./scripts/create-credentials.sh
docker compose up -d --build
```

The credentials script prompts for two passwords. It creates the `daemon` and `device` Mosquitto users, stores the daemon credentials in Compose secrets, and writes the device password to `secrets/device_password` for use during controller provisioning. These generated files and `config.yaml` are ignored by Git.

Docker publishes the daemon's UDP receiver only on host loopback at port `34198`. Mosquitto port `1883` is exposed on all host interfaces so controllers on the LAN can connect. MQTT is authenticated but unencrypted; use it only on a trusted network.

`config.yaml` contains the MQTT broker/client settings and all daemon status colors. The `factorio-display/v2` prefix is fixed for protocol version 2. Color changes are checked every second and hot-reloaded only after the complete YAML file validates. An invalid reload leaves the previous configuration active. Changing the broker or client ID requires a daemon restart.

### 2. Install and configure the Factorio mod

Copy `factorio-mod/lamp_led_display` into the Factorio mods directory and enable **Lamp LED Display**. Launch Factorio with Lua UDP enabled; on macOS:

```sh
/Applications/factorio.app/Contents/MacOS/factorio --enable-lua-udp 34199
```

Port `34199` is Factorio's Lua UDP port and must be available. The mod's startup setting targets the daemon on port `34198`; the two port numbers are intentionally different.

After lamp technology is available:

- Use the toolbar shortcut or Alt+Shift+D, select exactly one lamp, and enter a channel from `1` through `64`.
- Set per-lamp brightness from `0` through `255` and choose `solid`, `blink`, or `pulse`.
- Use Ctrl+Shift+D to open the assignment list, jump to a lamp, edit brightness/effect values, or remove an assignment.
- Enable Factorio Alt mode to show the green channel-number marker on assigned lamps.

The in-game channel number is one-based: lamp channel `1` becomes wire channel `0`, and lamp channel `64` becomes wire channel `63`. Assigning an occupied channel transfers it to the newly selected lamp. Assignments, brightness/effect settings, the per-save ID, and packet sequence are stored in the save.

The mod reads the lamp control behavior's evaluated color every tick. Circuit enable/disable, signal color mapping, separate RGB signals, and packed RGB therefore remain configured through Factorio's normal lamp interface. A disabled, unpowered, low-power, or daytime-off lamp is sent as black.

The mod's startup settings select the UDP destination port and the default brightness for new assignments. Default brightness is `64`; the startup setting accepts `16..255`, while an individual assignment can subsequently be set to `0..255`.

### 3. Flash and provision a controller

Build and flash the firmware over USB:

```sh
cd firmware
pio run -e esp32-c3-supermini -t upload
pio device monitor
```

The image targets an ESP32-C3 DevKitM-compatible SuperMini, uses GPIO4 for NeoPixel data and GPIO9 for BOOT, and identifies itself as firmware `2.0.0`.

On first boot, join the `Factorio-Display-xxxxxx` access point and configure:

- Wi-Fi credentials.
- The Mosquitto host's LAN address and port `1883`.
- MQTT username `device` and the password in `secrets/device_password`.
- A unique device ID using at most 32 letters, digits, dots, underscores, or hyphens.
- Pixel count `1..16`, channel offset `0..63`, and `RGB` or `GRB` pixel order.

The range must satisfy `channel_offset + pixel_count <= 64`. Pixel zero displays the offset channel; each later pixel displays the next channel. For example, two eight-pixel controllers use `(pixel_count=8, offset=0)` and `(pixel_count=8, offset=8)`.

Wi-FiManager stores Wi-Fi data in the ESP Wi-Fi configuration, while MQTT and display settings are stored in the firmware's NVS namespace. If Wi-Fi cannot connect, the captive portal starts automatically and remains available for up to five minutes. Holding BOOT continuously for five seconds requests the portal explicitly.

During normal operation, the same MQTT/display settings are available at either:

```text
http://<controller-ip>/
http://factorio-display-<device-id>.local/
```

The normal page does not display the saved MQTT password; leave the password field empty to keep it. Saving restarts the controller, and the confirmation page attempts to return to `/` after ten seconds. This page uses plain HTTP and belongs only on the trusted LAN. Firmware updates are USB-only.

If a logical green value lights red, change the pixel order between `RGB` and `GRB` on the controller page.

## Runtime behavior

The mod evaluates assigned lamps every game tick. It sends an `update` as soon as a value changes, a complete `snapshot` every 300 ticks (five seconds at 60 UPS), and a complete `reset` when a saved game is loaded. Removed assignments generate one black update for their former channel.

The daemon validates protocol version 2, packet shape, channel range, direct colors/effects, and sequence ordering. A `reset` is authoritative: it may establish a lower sequence after reloading an older save, replaces all channel state, and becomes the new sequence baseline. Snapshots also replace all state; updates merge only their listed channels.

The daemon publishes immediately after each accepted UDP packet and configuration reload, and republishes every five seconds. Each retained frame contains exactly 64 channels and expires on the controller after seven seconds. Unassigned channels are black with brightness `255` and `solid` effect.

If no valid full snapshot or reset arrives for more than ten seconds, every channel uses the configurable `stale_game` color (cyan pulse by default). An ESP with MQTT connected but no valid unexpired frame displays black. An ESP disconnected from MQTT displays an amber breathing pattern. These are three separate states.

Although the current mod sends direct RGB lamp records, the daemon still accepts legacy/status records and requires all status colors in YAML. Defaults are green working, yellow pulse starved, red blocked, blue blink no power, purple disabled, magenta missing, white unknown, and cyan pulse stale game. Direct lamp records carry their own `0..255` brightness and effect.

Each controller publishes retained `online`/`offline` availability, using an MQTT Last Will for unclean disconnects. Every 30 seconds it publishes non-retained telemetry with firmware version, IP address, RSSI, uptime, pixel count, channel offset, and pixel order.

## Development and verification

```sh
make test                    # Go, isolated Lua, and native firmware tests
make build-firmware          # compile the ESP32-C3 firmware
make compose-config          # validate the Compose model
./scripts/integration-test.sh
```

The integration test requires generated credentials and Docker. It uses UDP port `44198` by default, verifies status conversion and direct-lamp pass-through, exercises valid and invalid YAML reloads, observes the retained MQTT frame, and waits for the stale-game transition. Override its UDP port with `DISPLAY_INTEGRATION_UDP_PORT`.

Detailed wire formats and topics are in [the protocol reference](docs/protocol.md). The manual Factorio acceptance checklist lives under `factorio-mod/tests`.

## Troubleshooting

- **Daemon logs `invalid udp packet`:** confirm the sender uses protocol version 2, a positive sequence, a `channels` array (or `{}` only when empty), and channel IDs `0..63`.
- **Daemon logs `out-of-order packet ignored` after loading an older save:** the first authoritative packet must be type `reset`; subsequent packets must use larger sequences.
- **Controller cannot authenticate to MQTT:** open its normal HTTP page and replace the MQTT password. The daemon uses different credentials from devices.
- **Controller is amber:** MQTT is disconnected. Check broker address, LAN reachability, username/password, and Mosquitto port `1883`.
- **Controller is black:** MQTT is connected but no complete, valid, unexpired global frame has been accepted.
- **All pixels show cyan pulse:** MQTT is working, but the daemon has not received a full Factorio snapshot/reset for more than ten seconds.
- **Colors are swapped:** select the matching `RGB` or `GRB` order in controller configuration.
