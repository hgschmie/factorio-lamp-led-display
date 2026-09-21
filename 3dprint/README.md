# 3D Print files

These designs have been printed multiple times on a Bambu Lab X1 Carbon. If you use a different printer, load the 3MF files in your slicer and reslice them for your printer.

## Lamp

The lamps use the [Factorio lamp for a 5 mm LED](https://makerworld.com/en/models/3225142-factorio-lamp-for-5mm-led) design, with an opaque base and a translucent dome. The [lamp folder](lamp/) contains PETG and PLA 3MF projects and the assembled `lamp.stl` used in the base plate previews.

## Controller case

The [case](case/) houses the 55 × 55 mm controller PCB that drives up to eight lamps. Its outside dimensions are approximately **62.2 × 61 × 27 mm**.

The base has four PCB mounting posts for M3 self-tapping screws. A sliding lid runs in V-shaped grooves, with a window over the eight lamp headers for the four-wire cables. A separate opening in the side wall provides access to the controller's USB-C connector. The base and lid are designed to print without supports.

The OpenSCAD model is parameterized, and a small screw-fit test piece is available for checking the mounting-hole fit. See the [case README](case/README.md) for assembly, printing, calibration, and build instructions.

## Base plates

The [base plates](baseplate/) hold the lamps and controller case together. Three layouts are available:

| Layout | Lamps | Plate size | Printable file |
| --- | --- | --- | --- |
| Two rows of four, case behind the lamps | 8 | 200 × 180 mm | `baseplate/output/lamp-base-plate.stl` |
| Two rows of three, with two more lamps beside the case | 8 | 160 × 208 mm | `baseplate/output/lamp-base-plate-alternative.stl` |
| One row of three, with two more lamps beside the case | 5 | 160 × 160 mm | `baseplate/output/lamp-base-plate-five.stl` |

Each plate has shallow lamp recesses with small retaining lips and 14 × 7 mm cable slots offset toward one side of each lamp. The controller case clips into its mount **lid-down**, aligning its cable window with an opening in the plate. Six removable feet provide 10 mm of clearance for routing the wires underneath.

Use PETG for the plate and its clips. Feet are available in PETG or TPU 95A; use the **V2 TPU feet**, which have smaller, split retaining heads for easier insertion. Small lamp and box fit-test pieces are included.

There is also a thin glue-on cover for replacing a lamp at the specified position on the two-row-of-four plate if you make a mistake (or destroy an LED after you glued down a lamp and need to dremel it off the board.

See the [base plate README](baseplate/README.md) for fit tests, materials, dimensions, and the cover's intended position.

I ended up super-glueing the lamps to the base boards, once I confirmed that the LEDs work with the controller. Once you have glued them down, it is almost impossible to remove the lamps again. It really important to double-check the wire connections before powering on, flipping a connector by accident is a surefire way to kill the LED and then you have to hack off the lamp from the base board. I was trying to use a less destructive way (with the little retaining lips) but that did not work too well and I got bored and wanted to get this done.

## Generate the print files

With OpenSCAD on your PATH and Python 3 installed, run these commands from this directory:

```bash
make -C case OUT=out          # Case STLs and previews; refresh shared references
make -C baseplate             # All base plate parts, feet, and mesh validation
make -C baseplate previews    # Assembly and part previews
```

The case Makefile normally writes to `case/build/`; `OUT=out` writes to the `case/out/` location used by the base plate previews and clearance checks. Those previews also use `lamp/lamp.stl`. Base plate outputs go in `baseplate/output/`. Use `make -C baseplate everything` to build both printable parts and previews.
