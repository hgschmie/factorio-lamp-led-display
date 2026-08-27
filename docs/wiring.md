# Controller and NeoPixel wiring

The personal-use PCB carries an ESP32-C3 SuperMini, a 74AHCT125 level shifter, bulk capacitance, and eight four-pin LED connectors. It is powered through the ESP module's USB-C connector; the module's 5 V/VBUS output supplies the level shifter and LEDs.

```text
USB-C / ESP32-C3 SuperMini       74AHCT125                  first NeoPixel

GPIO4 (3.3 V) ────────────────► 1A
GND ──────────────────────────► /1OE and GND
5 V/VBUS ─────────────────────► VCC ─────────────────────► VCC
                                1Y ── 330–470 Ω ─────────► DIN
GND ─────────────────────────────────────────────────────► GND

C1: approximately 1000 µF between 5 V/VBUS and GND
```

The 74AHCT125 accepts the ESP's 3.3 V GPIO signal and produces a 5 V data signal. Its active-low output enable is tied low. All unused level-shifter inputs are tied to ground rather than left floating. All ESP, level-shifter, and LED grounds must be common.

Observe the bulk capacitor's polarity, place the 330–470 Ω resistor in series with the level-shifted data output, and keep the controller-to-first-pixel data lead short.

## LED connector pinout

Each of the eight 1x4 male connectors follows the LED's physical pin order so four straight conductors can be used:

1. Data In
2. +5 V (Vcc)
3. GND
4. Data Out

The chain runs from the level-shifter output into connector 1 Data In, then from each LED's Data Out to the next connector's Data In. The board distributes common +5 V and ground to every connector.

## Firmware relationship

The firmware drives an 800 kHz NeoPixel stream on GPIO4. Pixel order is configurable as `RGB` or `GRB`; select the order expected by the installed LEDs. If a requested green pixel appears red, switch the configured order.

Firmware supports `1..16` pixels, but this PCB exposes eight connectors. Device pixel count should normally therefore be configured as `8` or fewer for this board.

Holding the ESP32-C3 SuperMini BOOT button pulls GPIO9 low. The firmware detects a continuous five-second hold and restarts into captive provisioning; GPIO9 is not part of the LED wiring.

## Power budget

For eight LEDs specified at 12 mA maximum each, the maximum LED load is 96 mA at full brightness. The firmware permits the full `0..255` brightness range. Allow additional current for the ESP32-C3 and level shifter, and use a sound USB-C supply and cable.

This design intentionally uses the ESP module's 5 V/VBUS rail and has no separate LED power connector. Do not apply a second independent 5 V source at the same time. C1 remains fitted to support transient LED current.
