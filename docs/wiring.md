# Controller and NeoPixel wiring

Use an external regulated 5 V, 2 A supply for the LEDs. Never power the LED chain from the ESP32-C3 board's 5 V pin.

```text
ESP32-C3 SuperMini                 74AHCT125                   NeoPixel chain
┌─────────────────┐          ┌─────────────────┐          ┌───────────────┐
│ GPIO4 ──────────┼─────────►│ 1A          1Y  ├──[330–470 Ω]──► DIN     │
│ 3V3 ────────────┼─────────►│ /1OE (low enables; tie to GND)            │
│ GND ────────────┼─────┬───►│ GND             │          │ GND          │
└─────────────────┘     │    │ VCC ◄───────────┼─────┬────│ +5 V         │
                        │    └─────────────────┘     │    │ DOUT ──► DIN │
5 V / 2 A supply        │                            │    └───────────────┘
  GND ──────────────────┴────────────────────────────┘
  +5 V ──────────────────────────────────────────────┘
          └── approximately 1000 µF capacitor across +5 V and GND near pixel 0
```

The 74AHCT125 input accepts the ESP's 3.3 V GPIO level and produces a clean 5 V data signal. Tie its active-low output-enable pin to ground. All grounds must be common. Observe capacitor polarity, keep the controller-to-first-pixel data lead short, and inject 5 V again along long or high-current chains. The firmware supports at most 16 GRB, 800 kHz NeoPixels on GPIO4.

For the planned eight LEDs rated at 12 mA maximum each, the LED load is at most 96 mA at full brightness. The firmware therefore permits the complete `0..255` brightness range, and the example configuration uses `255`. The specified external 2 A supply has ample headroom; still size wiring and protection for the actual supply and verify that the particular LEDs really carry the 12 mA maximum rating.
