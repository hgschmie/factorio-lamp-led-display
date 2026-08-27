# Factorio Physical Status Display

This monorepo connects crafting-machine status and circuit-driven lamp colors in Factorio 2.1 to small physical NeoPixel displays. The mod reports 64 numbered channels over Factorio's localhost-only UDP API; a Go daemon translates them into one retained MQTT frame; ESP32-C3 SuperMini controllers independently select the channel range rendered by their pixels.

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

2. Copy `factorio-mod/lamp_led_display` into the Factorio mods directory and launch the game with Lua UDP explicitly enabled. On macOS this can be done from a terminal (adjust the application path if needed):

   ```sh
   /Applications/factorio.app/Contents/MacOS/factorio --enable-lua-udp 34199
   ```

   Port `34199` is Factorio's local UDP port and must be unused. It is intentionally different from the daemon's destination port, `34198`, which the mod passes to `helpers.send_udp`. Enable **Physical Status Display**, load a save, click its shortcut, select one assembler/furnace/rocket silo, and enter a unique channel number from `0` to `63`. Ctrl+Shift+D opens change/remove operations. Assignments and a per-save ID persist in the save. Upgrading from a named-channel mod release removes assignments whose old names cannot be converted to numbers, so reassign those entities once. Factorio's supported UDP API can target localhost only and must be enabled with this flag. See the [command-line documentation](https://wiki.factorio.com/Command_line_parameters) and [Factorio Lua API](https://lua-api.factorio.com/latest/classes/LuaHelpers.html).

   The assignment shortcut also accepts any lamp entity, including the standard small lamp and lamps added by other mods. Select exactly one lamp with the same point-and-click tool used for machines; the assignment dialog adds brightness `0..255` and `solid`, `blink`, or `pulse`. Ctrl+Shift+D shows those controls inline for every assigned lamp, with an Apply button. Opening a lamp normally still shows its native lamp GUI, including circuit enable/disable, signal-to-color mapping, separate red/green/blue signals, and packed RGB mode.

   The mod also keeps its craftable **Physical display lamp**, unlocked alongside the standard small lamp and using the standard graphics. The evaluated lamp color, brightness, and effect are sent directly on its numbered channel. When the in-game lamp is disabled, unpowered, or off during daytime, its physical output is black.

3. Edit `config.yaml` only if you want to change the broker connection or status colors. The daemon has no device list, physical mappings, or brightness setting. When upgrading, change the MQTT prefix to `factorio-display/v2` and remove the old `brightness`, `devices`, and `mappings` sections. Saving valid color changes reloads them within a second; invalid files are logged and the last valid configuration remains active. Broker/client changes require a daemon restart.

4. Build and flash the controller over USB:

   ```sh
   cd firmware
   pio run -e esp32-c3-supermini -t upload
   pio device monitor
   ```

   On first boot, connect to the `Factorio-Display-xxxxxx` access point and enter Wi-Fi, broker LAN address/port, username `device`, the password saved in `secrets/device_password`, a unique device ID, pixel count, and channel offset. The ESP Wi-Fi stack and the firmware preferences both use NVS. For example, an eight-pixel `shop-floor-a` uses pixel count `8` and offset `0`; the next eight-pixel controller uses count `8` and offset `8`.

   During normal operation, open `http://<controller-ip>/` or `http://factorio-display-<device-id>.local/` to change the MQTT host, port, username/password, device ID, pixel count, channel offset, or RGB/GRB pixel color order. Pixel `0` displays the offset channel and each following pixel displays the next channel; `offset + pixel_count` may not exceed `64`. The page never displays the stored password; leave its password field empty to retain it. Saving restarts the controller. This configuration page uses plain HTTP and should only be exposed on the trusted LAN.

   Pixel color order defaults to `RGB`. If a logical green frame lights red, the controller and LEDs disagree about byte order; select `RGB` for LEDs that interpret red first or `GRB` for the common WS2812-style order.

   If Wi-Fi startup fails, the captive portal reappears. Holding BOOT (GPIO9) continuously for five seconds also starts it; BOOT is monitored independently from MQTT connection attempts. Firmware updates are USB-only—there is no OTA service.

## Behavior

The mod samples twice per second, sends changed machine statuses and lamp outputs immediately at the next sample, and sends a complete snapshot every five seconds. The daemon rejects malformed/out-of-order packets and channel IDs outside `0..63`, classifies raw Factorio statuses, passes direct lamp outputs through, and republishes one retained 64-channel frame every five seconds. Every channel switches to configurable cyan pulse when no valid full snapshot has arrived for ten seconds. Unassigned channels are black during normal operation.

Default colors are green working, yellow pulse starved, red blocked, blue blink no power, purple disabled, magenta missing, white unknown, and cyan pulse stale game. They are all configurable in YAML. Each channel supports the full `0..255` brightness range; status channels use `255`, while lamps use their in-game brightness setting. Eight of the specified 12 mA LEDs draw at most 96 mA at full brightness. The controller shows an independent amber breathing pattern while MQTT is disconnected. Its MQTT Last Will is retained `offline`; telemetry includes firmware version, IP, RSSI, uptime, pixel count, channel offset, and pixel color order.

## Development and verification

```sh
make test                 # Go, isolated Lua, native frame-parser tests
make build-firmware       # compile the ESP32-C3 image
make compose-config       # validate Compose structure
./scripts/integration-test.sh  # live UDP → retained MQTT → stale transition
```

The integration script requires generated credentials and a running Docker engine; it creates a temporary configuration from `config.example.yaml`. The Factorio in-game checklist is in [factorio-mod/tests/README.md](factorio-mod/tests/README.md). Hardware acceptance should verify fresh captive provisioning, offset routing across two controllers, under-two-second machine updates, retained-frame restoration after reboot, distinct MQTT/stale warnings, and all configured pixels on each controller.

Protocol details are in [docs/protocol.md](docs/protocol.md). Factorio status values come from [`LuaEntity.status`](https://lua-api.factorio.com/latest/classes/LuaEntity.html).
