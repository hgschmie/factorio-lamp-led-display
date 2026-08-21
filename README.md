# Factorio Physical Status Display

This monorepo connects crafting-machine status in Factorio 2.1 to small physical NeoPixel displays. The mod reports over Factorio's localhost-only UDP API; a Go daemon validates and maps channels; Mosquitto retains complete frames; ESP32-C3 SuperMini controllers render up to 16 pixels each.

```text
Factorio mod ── UDP 127.0.0.1:34198 ──► Go daemon ── MQTT ──► ESP32-C3 ──► NeoPixels
```

## Quick start

Requirements are Factorio 2.1, Docker Desktop, PlatformIO, an ESP32-C3 SuperMini, a 74AHCT125-compatible level shifter, and the parts in [the wiring guide](docs/wiring.md).

1. Create the runtime configuration and broker credentials:

   ```sh
   cp config.example.yaml config.yaml
   ./scripts/create-credentials.sh
   docker compose up -d --build
   ```

   MQTT port 1883 is exposed to the LAN and is intentionally unencrypted; use only a trusted network. UDP is published by Docker on host loopback only. The daemon and controllers use separate Mosquitto users. Generated passwords, the Mosquitto password database, and `config.yaml` are gitignored.

2. Copy `factorio-mod/factorio_status_display` into the Factorio mods directory and launch the game with Lua UDP explicitly enabled. On macOS this can be done from a terminal (adjust the application path if needed):

   ```sh
   /Applications/factorio.app/Contents/MacOS/factorio --enable-lua-udp 34199
   ```

   Port `34199` is Factorio's local UDP port and must be unused. It is intentionally different from the daemon's destination port, `34198`, which the mod passes to `helpers.send_udp`. Enable **Physical Status Display**, load a save, click its shortcut, select one assembler/furnace/rocket silo, and enter a unique channel. Ctrl+Shift+D opens rename/remove operations. Assignments and a per-save ID persist in the save. Factorio's supported UDP API can target localhost only and must be enabled with this flag. See the [command-line documentation](https://wiki.factorio.com/Command_line_parameters) and [Factorio Lua API](https://lua-api.factorio.com/latest/classes/LuaHelpers.html).

3. Edit `config.yaml` to map those logical names to `{device, pixel}` pairs. Device and channel IDs are case-sensitive. Saving a fully valid file reloads it within a second; invalid files are logged and the last valid configuration remains active. Duplicate channels, duplicate device/pixel pairs, unknown devices, and indices outside both the device size and `0..15` are rejected. Broker/client changes require a daemon restart; mapping, color, brightness, and device changes hot-reload.

4. Build and flash the controller over USB:

   ```sh
   cd firmware
   pio run -e esp32-c3-supermini -t upload
   pio device monitor
   ```

   On first boot, connect to the `Factorio-Display-xxxxxx` access point and enter Wi-Fi, broker LAN address/port, username `device`, the password saved in `secrets/device_password`, the matching device ID, and pixel count. The ESP Wi-Fi stack and the firmware preferences both use NVS.

   During normal operation, open `http://<controller-ip>/` or `http://factorio-display-<device-id>.local/` to change the MQTT host, port, username/password, device ID, pixel count, or RGB/GRB pixel color order. The page never displays the stored password; leave its password field empty to retain it. Saving restarts the controller. This configuration page uses plain HTTP and should only be exposed on the trusted LAN.

   Pixel color order defaults to `RGB`. If a logical green frame lights red, the controller and LEDs disagree about byte order; select `RGB` for LEDs that interpret red first or `GRB` for the common WS2812-style order.

   If Wi-Fi startup fails, the captive portal reappears. Holding BOOT (GPIO9) continuously for five seconds also starts it; BOOT is monitored independently from MQTT connection attempts. Firmware updates are USB-only—there is no OTA service.

## Behavior

The mod samples twice per second, sends changed statuses immediately at the next sample, and sends a complete snapshot every five seconds. The daemon rejects malformed/out-of-order packets, classifies raw Factorio statuses, republishes retained full frames every five seconds, and switches mapped pixels to configurable cyan pulse when no valid full snapshot has arrived for ten seconds.

Default mappings are green working, yellow pulse starved, red blocked, blue blink no power, purple disabled, magenta missing, white unknown, and cyan pulse stale game. They are all configurable in YAML. Brightness supports the full `0..255` range; eight of the specified 12 mA LEDs draw at most 96 mA at full brightness. The controller shows an independent amber breathing pattern while MQTT is disconnected. Its MQTT Last Will is retained `offline`; telemetry includes firmware version, IP, RSSI, uptime, and pixel count.

## Development and verification

```sh
make test                 # Go, isolated Lua, native frame-parser tests
make build-firmware       # compile the ESP32-C3 image
make compose-config       # validate Compose structure
./scripts/integration-test.sh  # live UDP → retained MQTT → stale transition
```

The integration script requires generated credentials, `config.yaml` retaining the example's first mapping, and a running Docker engine. The Factorio in-game checklist is in [factorio-mod/tests/README.md](factorio-mod/tests/README.md). Hardware acceptance should verify fresh captive provisioning, under-two-second machine updates, retained-frame restoration after reboot, distinct MQTT/stale warnings, two independent controllers, and all 16 pixels on each.

Protocol details are in [docs/protocol.md](docs/protocol.md). Factorio status values come from [`LuaEntity.status`](https://lua-api.factorio.com/latest/classes/LuaEntity.html).
