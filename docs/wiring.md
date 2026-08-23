# Controller and NeoPixel wiring

This personal-use PCB is powered through the ESP32-C3 SuperMini's USB-C connector. The module's 5 V/VBUS pin supplies the 74AHCT125 and all eight LED connectors. C1 provides approximately 1000 µF of bulk capacitance across this rail.

```text
USB-C    ESP32-C3 SuperMini        74AHCT125                   NeoPixel chain
┌─────────────────┐          ┌─────────────────┐          ┌───────────────┐
│ GPIO4 ──────────┼─────────►│ 1A          1Y  ├──[330–470 Ω]──► DIN     │
│ GND ────────────┼─────┬───►│ /1OE (low enables)                       │
│                 │     ├───►│ GND             │          │ GND          │
│ 5V/VBUS ────────┼─────┼───►│ VCC             │     ├────│ +5 V         │
└─────────────────┘     │    └─────────────────┘     │    │ DOUT ──► DIN │
                        └─────────────────────────────┘    └───────────────┘
                 C1: approximately 1000 µF across +5 V and GND
```

The 74AHCT125 input accepts the ESP's 3.3 V GPIO level and produces a clean 5 V data signal. Tie its active-low output-enable pin to ground. All grounds must be common. Observe capacitor polarity and keep the controller-to-first-pixel data lead short. The firmware supports GRB, 800 kHz NeoPixels on GPIO4; this PCB provides eight LED connectors.

Each PCB LED connector matches the LED's physical pin order so it can be wired with four straight conductors:

1. Data In
2. +5 V (Vcc)
3. GND
4. Data Out

The PCB connects each connector's Data Out to the next connector's Data In.

For the eight LEDs rated at 12 mA maximum each, the LED load is at most 96 mA at full brightness. The firmware therefore permits the complete `0..255` brightness range, and the example configuration uses `255`. Use a USB-C supply and cable with enough headroom for the ESP32-C3, level shifter, and LED load.
