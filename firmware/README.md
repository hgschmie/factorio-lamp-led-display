# ESP32-C3 NeoPixel controller firmware

This firmware receives the retained 64-channel MQTT frame from the Factorio display daemon and renders a configured consecutive range on locally attached NeoPixels. It targets an ESP32-C3 SuperMini using the Arduino framework and PlatformIO.

The controller stores its network, MQTT, and channel configuration in non-volatile storage. Initial setup uses a captive portal; MQTT and display settings can subsequently be changed through a normal web page on the trusted LAN.

See [the protocol reference](../docs/protocol.md) for MQTT payloads and topics, and [the wiring guide](../docs/wiring.md) before connecting LEDs.

## Hardware target

- ESP32-C3 SuperMini, built through PlatformIO's `esp32-c3-devkitm-1` board definition.
- GPIO4: 800 kHz NeoPixel data output.
- GPIO9: onboard BOOT button, monitored for provisioning requests.
- Between 1 and 16 RGB NeoPixels in firmware; the project PCB exposes eight connectors.
- `RGB` and `GRB` byte order support.
- USB CDC serial console at 115200 baud.
- USB-only firmware installation; OTA updates are not implemented.

GPIO4 must feed the LEDs through the 74AHCT125 level shifter and series resistor described in the wiring guide. Do not connect a 5 V NeoPixel data input directly to the ESP pin.

## Build dependencies

Install [PlatformIO Core](https://docs.platformio.org/en/latest/core/installation/index.html) or use the PlatformIO IDE extension. PlatformIO downloads the Espressif toolchain, Arduino framework, and pinned libraries automatically.

The embedded environment is defined in `platformio.ini`:

| Component | Version |
| --- | ---: |
| PlatformIO Espressif 32 platform | `6.10.0` |
| Arduino framework | supplied by the platform |
| PubSubClient | `2.8` |
| WiFiManager | `2.0.17` |
| ArduinoJson | `7.3.1` |
| Adafruit NeoPixel | `1.12.5` |
| Firmware version reported in telemetry | `2.0.1` |

The native parser tests additionally require a host C++ compiler supported by PlatformIO. Unity is selected as the test framework.

## Build, flash, and monitor

Run commands from the `firmware` directory:

```sh
pio run -e esp32-c3-supermini
pio run -e esp32-c3-supermini -t upload
pio device monitor -b 115200
```

The first command compiles without flashing. The firmware binary is normally written beneath:

```text
.pio/build/esp32-c3-supermini/
```

If PlatformIO cannot choose the serial device automatically, provide it explicitly:

```sh
pio run -e esp32-c3-supermini -t upload --upload-port /dev/cu.usbmodemXXXX
pio device monitor --port /dev/cu.usbmodemXXXX -b 115200
```

The exact device name varies by operating system and USB connection. The build enables USB CDC on boot and uses DIO flash mode.

From the repository root, the equivalent build target is:

```sh
make build-firmware
```

## Tests

Run the host-native frame-parser tests without an ESP:

```sh
cd firmware
PLATFORMIO_CORE_DIR=.pio-core pio test -e native
```

Or, from the repository root:

```sh
make test-firmware
```

The tests cover configured channel extraction, default and explicit brightness, effects, sequence rejection, channel-range bounds, complete-frame enforcement, duplicate channels, invalid protocol versions, expiry, atomic rejection, and connection-state transitions.

## First boot and captive provisioning

At startup the firmware loads saved settings and asks WiFiManager to connect using saved Wi-Fi credentials. If there are no credentials or the connection fails, it starts a captive portal.

1. Power the ESP32-C3 over USB.
2. Join the Wi-Fi network named `Factorio-Display-<chip-id>`.
3. If the portal does not open automatically, visit `http://192.168.4.1/`.
4. Select the target Wi-Fi network and enter its password.
5. Fill in the MQTT and display fields described below.
6. Save and allow the controller to join the selected Wi-Fi network.

Each portal session times out after five minutes. If connection or validation fails, the firmware waits one second and retries the Wi-Fi/provisioning flow.

### Captive-portal fields

| Field | Valid value |
| --- | --- |
| MQTT broker host | Required hostname or IP address reachable from the ESP; up to 64 characters |
| MQTT broker port | `1..65535`; normally `1883` |
| MQTT username | Mosquitto device username; normally `device`; up to 64 characters |
| MQTT password | Password created for the device user; up to 64 characters |
| Device ID | 1–32 letters, digits, `.`, `_`, or `-` |
| Pixel count | `1..16` |
| Channel offset | `0..63` |
| Pixel color order | `RGB` or `GRB` |

The broker field is passed directly to the Arduino MQTT client. Enter only a hostname or IP address, such as `192.168.1.20`; do not enter a URL such as `tcp://192.168.1.20:1883`. The port has its own field. When Mosquitto runs through Docker Compose, use the Docker host's LAN address, not the internal service name `mosquitto`.

The device ID becomes part of the MQTT client ID, availability topic, telemetry topic, and mDNS hostname. Give every controller a unique ID.

### Pixel count and channel offset

The daemon publishes 64 global channels numbered `0..63`. Each controller extracts a consecutive local range:

```text
local pixel 0 = global channel offset
local pixel n = global channel offset + n
```

The configuration must satisfy:

```text
1 <= pixel_count <= 16
0 <= channel_offset <= 63
channel_offset + pixel_count <= 64
```

For two eight-pixel controllers:

| Controller | Pixel count | Offset | Global channels |
| --- | ---: | ---: | --- |
| First | 8 | 0 | `0..7` |
| Second | 8 | 8 | `8..15` |

Factorio's assignment interface is one-based, so global MQTT channel `0` corresponds to Factorio lamp channel `1`.

## Re-entering the captive portal

Hold the onboard BOOT button continuously for five seconds while the firmware is running. The background button monitor sets a provisioning request independently of MQTT connection attempts. The main loop then:

1. Stops the normal management server and mDNS.
2. Publishes `offline` and disconnects MQTT when connected.
3. Starts the `Factorio-Display-<chip-id>` captive portal.
4. Restarts the ESP after provisioning completes or times out.

Use this portal when Wi-Fi credentials need to change. Holding BOOT during reset can select the ESP ROM bootloader; wait until the firmware is running before beginning the five-second hold.

## Normal management page

After the ESP joins Wi-Fi, it starts an HTTP server on port 80 and advertises it over mDNS. Open either address shown on the serial console:

```text
http://<controller-ip>/
http://factorio-display-<device-id>.local/
```

The mDNS name is lowercase. Characters other than letters, digits, and hyphens are replaced with hyphens. If `.local` discovery is unavailable on the client network, use the numeric IP address.

The page displays the controller's IP address and current MQTT connected/disconnected state. It can change:

- MQTT broker host and port.
- MQTT username and password.
- Device ID.
- Pixel count and channel offset.
- `RGB` or `GRB` pixel order.

The stored MQTT password is never displayed on this page. Leave the password field empty to retain it; enter a value to replace it. Submitted values are validated as a complete configuration before they are written.

After a successful save, the ESP sends a confirmation page, waits approximately 300 ms, and restarts. The confirmation page attempts to return to `/` after ten seconds, once the controller has rejoined Wi-Fi.

The normal management page does **not** edit Wi-Fi SSID or password. Use the five-second BOOT procedure to return to the captive portal for Wi-Fi changes.

Unknown HTTP paths redirect to `/`. There is no HTTP authentication or TLS, so expose this page only on a trusted LAN.

## MQTT operation

The firmware uses a fixed protocol prefix and subscribes to the retained global frame at QoS 1:

```text
factorio-display/v2/channels/set
```

It connects with client ID:

```text
factorio-display-<device-id>
```

Connection behavior:

- MQTT is attempted immediately and retried every five seconds after failure.
- Wi-Fi power saving is disabled for connection stability. After a Wi-Fi loss, the controller explicitly retries every five seconds and reconnects MQTT as soon as an IP address is restored.
- If Wi-Fi remains unavailable for 60 seconds, the controller restarts. The normal startup provisioning behavior applies if the network is still unavailable.
- Keepalive is 30 seconds and socket timeout is two seconds.
- The MQTT packet buffer is enlarged to 8192 bytes for the complete 64-channel frame.
- Reconnecting resets the local sequence baseline and waits for the broker's retained frame.
- The Last Will is retained `offline` at QoS 1.
- A successful connection publishes retained `online` and subscribes to the frame topic.

Availability and telemetry topics are device-specific:

```text
factorio-display/v2/device/<device-id>/availability
factorio-display/v2/device/<device-id>/telemetry
```

Telemetry is non-retained and published every 30 seconds. It contains protocol version, firmware version, IP address, RSSI, uptime, pixel count, channel offset, and pixel order.

MQTT uses plain TCP without TLS. The broker credentials and management page are suitable only for a trusted network.

The captive provisioning access point is also created without an AP password. Start it only in a trusted physical environment and close provisioning promptly after saving the configuration.

## Frame validation

Frames are accepted atomically: a malformed message never partially changes the displayed pixels. A valid frame must have:

- Protocol version `2`.
- A sequence larger than the last accepted sequence in the current MQTT session.
- Relative expiry from `1` through `60000` ms.
- Exactly 64 unique channel records covering `0..63`.
- RGB values in `0..255`.
- Optional brightness in `0..255`; omitted brightness defaults to `255`.
- Effect `solid`, `blink`, or `pulse`.

Only the configured range is copied into the local frame after the complete global message validates. Rejection reasons are printed to the serial console as `Rejected MQTT frame: ...`.

## LED behavior

| State | Display |
| --- | --- |
| MQTT disconnected | Amber breathing pattern on every configured pixel |
| MQTT connected, no accepted frame | Black |
| Last accepted frame expired | Black |
| Active frame | Per-channel RGB, brightness, and effect |

`solid` holds the configured value. `blink` alternates on/off every 500 ms. `pulse` applies a smooth sine-wave brightness modulation. Per-channel brightness is applied in software across the complete `0..255` range; the NeoPixel library's global brightness remains at full scale.

Factorio staleness is represented by a normal daemon-generated frame—cyan pulse by default—so it remains visually distinct from both MQTT-disconnected amber and connected-without-frame black.

Pixel order defaults to `RGB`. If a green command produces red, or colors otherwise appear swapped, change the controller to `GRB` through the management page.

## Persistent settings

MQTT and display values are stored with Arduino `Preferences` in the NVS namespace `display`. Stored values are:

- Broker host and port.
- MQTT username and password.
- Device ID.
- Pixel count and channel offset.
- Pixel color order.

WiFiManager/ESP Wi-Fi storage retains the Wi-Fi SSID and password separately. Flashing a new firmware image normally does not erase NVS; an explicit full-flash erase is required to remove all saved configuration.

## Troubleshooting

- **No serial port appears:** use a data-capable USB cable, reconnect the board, and check PlatformIO's device list with `pio device list`.
- **Upload cannot connect:** select the correct upload port. If necessary, use the board's BOOT/reset procedure to enter the ROM bootloader, then retry.
- **Captive portal does not appear:** hold BOOT for five seconds after the firmware is running, reconnect to the `Factorio-Display-<chip-id>` access point, and browse to `192.168.4.1`.
- **Wi-Fi works but MQTT authentication fails:** open the normal management page and replace the MQTT password. The `device` password is different from the daemon password.
- **MQTT broker is unreachable:** use the Docker host's LAN IP, not `localhost`, `mosquitto`, or a `tcp://` URL.
- **LEDs breathe amber:** MQTT or Wi-Fi is disconnected. The controller retries Wi-Fi and MQTT automatically and restarts after 60 seconds without Wi-Fi. Check the serial log, broker address, credentials, Mosquitto ACLs, signal strength, and LAN reachability.
- **LEDs remain black:** MQTT is connected, but no complete unexpired frame has been accepted. Inspect daemon logs and the serial console.
- **LEDs show cyan pulse:** the controller is operating, but the daemon considers Factorio stale.
- **Wrong LEDs are addressed:** verify pixel count and channel offset, remembering that Factorio channels are one-based while MQTT channels are zero-based.
- **Colors are swapped:** change `RGB`/`GRB` pixel order.
- **Frames are rejected as stale:** confirm the daemon is publishing increasing sequences. An MQTT reconnect resets the controller's sequence baseline.
