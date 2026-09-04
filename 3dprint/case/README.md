# Enclosure for the lamp-led-display PCB

Parametric OpenSCAD sliding-lid box for the 55 x 55 mm board (ESP32-C3 SuperMini on a socket,
74AHCT125, 1000 uF cap, eight 1x4 LED headers).

## Files

| file | purpose |
|---|---|
| `case.scad` | the model. Open in OpenSCAD; pick `part` in the Customizer (base / lid / board / assembly / exploded) |
| `board_data.scad` | board outline, holes, headers and component courtyards, **generated** from `../pcb.kicad_pcb` |
| `kicad2scad.py` | the generator: `uv run kicad2scad.py ../pcb.kicad_pcb board_data.scad` |
| `test_case.py` | fit tests: `uv run test_case.py` renders the STLs and checks them against the board data |
| `build.mk` | `make -f build.mk` builds `out/base.stl`, `out/lid.stl` and previews; `make -f build.mk test`; `make -f build.mk board_data` |
| `out/base.stl`, `out/lid.stl` | ready to slice |

Both Python scripts carry inline dependency metadata, so the only tool you need is
[uv](https://docs.astral.sh/uv/) (`brew install uv`); it creates a throwaway environment on first run.
OpenSCAD has to be on `PATH` (or set `OPENSCAD=/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD`).

## Design

* Outer size 62.2 x 61 x 26.9 mm, walls 2.5 mm, floor 2 mm.
* Board sits on four 6.5 mm standoffs (4 mm tall) over its M3 holes; 2.5 mm pilot holes for
  M3 self-tapping screws (M3 x 6 works).
* Lid (2 mm) slides in from the back edge (the edge away from the LED headers) in 1.4 mm grooves;
  a raised block on its rear edge fills the recess flush with the wall tops and doubles as a grip.
* Window in the lid over J1..J8 so Dupont cables plug in from the top.
* USB-C opening (13 x 6.7 mm) in the left wall, centred on the ESP32 module. The receptacle's lower edge is
  2.9 mm above the PCB and it sticks out 1 mm past the board edge, so the left wall is pushed out by 1.2 mm
  and the board still drops straight in; the receptacle ends up flush with the inner wall face, inside the opening.
* Height budget: tallest part (C1) measured 14 mm above the PCB, plus 1.5 mm air.

## Things to tune after the first print (all at the top of `case.scad`)

* `max_part_h` -- C1 height above the PCB (14 mm measured). Every mm changes the case height directly.
* `usb_z0`, `usb_overhang` -- USB-C lower edge above the PCB (2.9) and how far it sticks out past the board edge (1.0).
* `lid_side_clear`, `groove_clear` -- lid too tight: +0.1; lid rattles: -0.1.
* `board_clear` -- board should drop in without force; the 0.5 mm default suits most printers.
* `screw_hole_d` -- 2.5 mm bites well in PLA/PETG; use 2.8 if screws are hard to drive.

## Printing

* Base: as modelled, open side up. No supports (the USB opening is a 13 mm bridge, the grooves a 1.4 mm bridge).
* Lid: flip it so the flat plate is on the bed (rear block pointing up). No supports.
* 0.2 mm layers, 3 walls, 20 % infill is plenty.

## Workflow

1. Change the PCB in KiCad -> `make -f build.mk board_data` -> `make -f build.mk test` -> `make -f build.mk`.
2. Tweak parameters -> `make -f build.mk test` -> `make -f build.mk`.

The tests check that the PCB and every component courtyard clear the base, standoffs sit exactly under
each hole, the lid fits the grooves and can be swept along its slide path without hitting anything,
the lid window clears all eight headers, the USB opening is open where the module is, and both meshes
are watertight.
