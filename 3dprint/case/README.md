# Enclosure for the lamp-led-display PCB

Parametric OpenSCAD sliding-lid box for the 55 x 55 mm board (ESP32-C3 SuperMini on a socket,
74AHCT125, 1000 uF cap, eight 1x4 LED headers).

## Files

| file | purpose |
|---|---|
| `case.scad` | the model. Open in OpenSCAD; pick `part` in the Customizer (base / lid / board / assembly / exploded / section) |
| `board_data.scad` | board outline, holes, headers and component courtyards, **generated** from `../../pcb/pcb/pcb.kicad_pcb` |
| `kicad2scad.py` | the generator: `uv run kicad2scad.py ../../pcb/pcb/pcb.kicad_pcb board_data.scad` |
| `test_case.py` | fit tests: `uv run test_case.py` renders the STLs and checks them against the board data |
| `Makefile` | `make` builds `build/base.stl`, `build/lid.stl` and previews; `make test`; `make board_data` |
| `build/base.stl`, `build/lid.stl` | ready to slice (git-ignored, rebuild with `make`) |

Both Python scripts carry inline dependency metadata, so the only tool you need is
[uv](https://docs.astral.sh/uv/) (`brew install uv`); it creates a throwaway environment on first run.
OpenSCAD has to be on `PATH` (or set `OPENSCAD=/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD`).

## Design

* Outer size 62.2 x 61 x 27.0 mm, walls 2.5 mm, floor 2 mm.
* Board sits on four 6.5 mm standoffs (4 mm tall) over its M3 holes; 2.5 mm pilot holes for
  M3 self-tapping screws (M3 x 6 works).
* Lid (2 mm) slides in from the back edge (the edge away from the LED headers). Its left, right and front
  edges are chamfered top and bottom at 45 degrees to a V (0.4 mm flat at the tip) that runs in a matching V groove
  in the walls (1.2 mm deep, 0.3 mm gap to every flank). All groove faces are 45 degrees or steeper, so neither
  part needs support, and the lid centres itself in the grooves instead of binding on a flat ceiling.
* A full-width bar on the lid's rear edge (same rounded corners as the case) fills the recess in the back wall
  flush with the wall tops and seats against the side walls as the end stop, so the closed box has a continuous
  back face.
* Window in the lid over J1..J8 so Dupont cables plug in from the top.
* USB-C opening (13 x 6.7 mm) in the left wall, centred on the ESP32 module. The receptacle's lower edge is
  2.9 mm above the PCB and it sticks out 1 mm past the board edge, so the left wall is pushed out by 1.2 mm
  and the board still drops straight in; the receptacle ends up flush with the inner wall face, inside the opening.
* Height budget: tallest part (C1) measured 14 mm above the PCB, plus 1.5 mm air.

## Things to tune after the first print (all at the top of `case.scad`)

* `max_part_h` -- C1 height above the PCB (14 mm measured). Every mm changes the case height directly.
* `usb_z0`, `usb_overhang` -- USB-C lower edge above the PCB (2.9) and how far it sticks out past the board edge (1.0).
* `lid_clear` -- gap between the lid's V edge and every groove flank. Lid too tight: +0.05; lid rattles: -0.05.
* `lid_tip` -- flat at the tip of the V edge (0.4 mm = two layers). Larger makes the edge sturdier and the groove deeper.
* `board_clear` -- board should drop in without force; the 0.5 mm default suits most printers.
* `screw_hole_d` -- 2.5 mm bites well in PLA/PETG; use 2.8 if screws are hard to drive.

## Printing

* Base: as modelled, open side up. No supports: the groove flanks are 45 degrees, the USB opening is a 13 mm bridge.
* Lid: as modelled, flat underside on the bed, rear bar up. No supports; the lower V flanks are 45 degree overhangs.
* Do not enable supports in the slicer for either part; the V grooves are exactly where support is hard to remove.
* 0.2 mm layers, 3 walls, 20 % infill is plenty.

## Workflow

1. Change the PCB in KiCad -> `make board_data` -> `make test` -> `make`.
2. Tweak parameters -> `make test` -> `make`. `part=section` in the Customizer shows the V edge sitting in the groove.

The tests check that the PCB and every component courtyard clear the base, standoffs sit exactly under
each hole, the whole lid (plate, V edges, bar) can be swept along its slide path without hitting anything,
the grooves actually hold the lid down, the back face is closed when the lid is in, no face of either part
overhangs by more than 45 degrees (no supports), the lid window clears all eight headers, the USB opening is
open where the module is, and both meshes are watertight.
