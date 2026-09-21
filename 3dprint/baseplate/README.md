# Eight-lamp base plate

Reference models are shared with the neighboring projects: `../case/out/base.stl`, `../case/out/lid.stl`, and `../lamp/lamp.stl` (paths relative to this folder). Previews and clearance checks use these files; the printable baseplate geometry does not depend on importing them.

## Build with make

Run **`make`** in this folder to create all current printable STLs in `output/`: the three plates, glue-on cover, PETG and TPU V2 feet, and fit-test pieces. It also validates all meshes and writes `output/mesh-checks.json`. Builds are incremental, including dependencies on the shared SCAD source.

```bash
make                 # Printable files plus mesh validation
make previews        # Current PNG previews
make everything      # Printable files, validation, and previews
make -B              # Force a rebuild of printable files
make clean           # Remove only Makefile-managed generated files
```

The Makefile defaults to `openscad` on your PATH and `python3` (standard library only). Override them if needed: `make OPENSCAD=/path/to/openscad PYTHON=python3`. Source STL/3MF files, archived versions, and historical comparison images are preserved by `make clean`. When running through the Codex sandbox on this machine, OpenSCAD needs outside-sandbox execution; ordinary Terminal use requires no special flag.

## Small lamp-retaining lips

Both plate layouts and `output/lamp-fit-test.stl` now include retaining lips rising **1.5 mm above the deck**. They are 1 mm thick, move inward 0.3 mm to take up 0.6 mm of total sideways play, and have a 0.2 mm inward bead with a beveled insertion ramp. The small bead is intended to give a press-in grip; it creates up to approximately 0.15 mm nominal local interference with the source lamp's vertical outer details. The grip and insertion force require a new physical test.

For each lamp, the two sides away from the box have full-length lips. The other two sides have half-length lips anchored at the far corners, leaving the corner toward the box open. The direction is calculated from each lamp center to the box center, so it is mirrored appropriately across both layouts. The shifted cable slot remains in place.

Print the revised lamp test in PETG before printing a full plate. Press the lamp in gently and check retention and removal. If the bead is too tight, reduce `lamp_lip_bead` (currently 0.2 mm); adjust `lamp_lip_inset` for sideways fit. The box clips are unchanged. The TPU foot insertion problem is addressed by the V2 feet described below. Render colors only distinguish surfaces; each plate is one printed part.

## Lamp cable-slot revision after test printing

The box clip has been reported to fit successfully; the later TPU feet were too difficult to insert and have been revised below. The lamp cable slot has now moved **10 mm toward +Y** from each lamp center, retaining its 14 × 7 mm dimensions. +Y is upward in the top-view comparison and alternative-layout top view; the same lamp-relative direction is used on both plates. On the 48 mm lamp test piece, the hole center moves from (24,24) to (24,34) mm. The new location still has approximately 5.8 mm of recess floor between the slot and the nearby recess wall.

Both full plate STLs and `output/lamp-fit-test.stl` include this revision. `output/lamp-slot-comparison.png` shows the old and new positions; the dashed orange outline marks the former centered hole on the new test piece. The revised cable alignment still needs to be checked against the actual lamp. Adjust `lamp_hole_offset` in the shared SCAD source to change direction or distance. Copies of the previous centered-slot STLs are in `reference/centered-slot/`.

## Alternative layout: 3 + 3 + 2

`output/lamp-base-plate-alternative.stl` is a 160 × 208 mm portrait plate matching this top-view arrangement:

```text
lamp   lamp   lamp
lamp   lamp   lamp
lamp   +---------+
lamp   |   box   |
       +---------+
```

The lamps remain on a 48 mm grid. The lower-right box is centered vertically beside the bottom two lamps, lid-down, with its side connector facing the outer right edge. Its aligned 44 × 17 mm cable opening is centered at (111.4, 39.69) mm. Recesses, slots, deck thickness and retaining clips are reused from the first design. The same six TPU 95A feet fit sockets along the two side edges; no new feet or fit-test parts are needed.

Edit `lamp-base-plate-alternative.scad` to change this layout; keep `lamp-base-plate.scad` beside it because it supplies the shared geometry. Preview images are `output/alternative-top.png` and `output/alternative-assembly.png`. The original layout remains available separately.

The alternative STL passed closed-edge and connected-solid checks. The box and foot mountings retain their existing geometry. The lamp bead now intentionally introduces a small press-fit interference, so the earlier clearance-only checks for lamps are no longer acceptance criteria. Physical retention must be checked with the revised lamp test.

```bash
/opt/homebrew/bin/openscad -o output/lamp-base-plate-alternative.stl --export-format binstl lamp-base-plate-alternative.scad
```

## Third layout: five lamps

`output/lamp-base-plate-five.stl` is the shorter **160 × 160 mm** version of the second plate. Its top row of three lamps has been removed and the plate shortened by 48 mm. It retains one row of three above the box and two down the box's left side:

```text
lamp   lamp   lamp
lamp   +---------+
lamp   |   box   |
       +---------+
```

The remaining lamp centers, 1.5 mm retaining lips, off-center cable slots, inverted box mount, and side-facing connector orientation match the second plate. It uses the same six TPU V2 feet; foot sockets are repositioned along the shorter side edges. The first two plates remain separate and unchanged.

Source: `lamp-base-plate-five.scad` (requires the shared `lamp-base-plate.scad` beside it). Previews: `output/five-top.png` and `output/five-assembly.png`.

```bash
/opt/homebrew/bin/openscad -o output/lamp-base-plate-five.stl --export-format binstl lamp-base-plate-five.scad
```

## Print files

### Glue-on replacement-lamp cover

`output/lamp-position-cover.stl` is a **43.36 × 43.566 × 1.2 mm** flat cover for the first 2×4 board's near-box row, second lamp from the left in the delivered front view. The user confirmed the retaining lips at this position have been removed. The cover overlaps the recess by 2.5 mm on each side, except at the small curved corner notch that clears the adjacent central foot head.

The 14 × 7 mm rounded wire slot matches the existing slot, offset 10 mm from the lamp center. When installed, the notch points toward the nearby foot at the upper-right corner and the cable slot lies on the opposite half, away from the box. The notch radius is 4.2 mm, giving at least 0.7 mm nominal radial clearance around even the original 7 mm TPU head; clearance is larger around the current V2 head.

Print flat, either broad face down, with no supports. Dry-fit with the cable slot aligned and the notch around the foot, then glue the overlapping border to the board. The upper surface is flat for attaching the replacement lamp. A lamp placed on the cover will sit approximately 2.6 mm higher than one seated in the original recess, plus glue thickness.

Source: `lamp-position-cover.scad`. Preview: `output/lamp-position-cover-detail.png`. The cover passed closed-mesh checks and a digital collision check against the board with this position's lips removed and a conservative 7 mm foot-head envelope. The original board STLs are unchanged.

```bash
/opt/homebrew/bin/openscad -o output/lamp-position-cover.stl --export-format binstl lamp-position-cover.scad
```

### Base plates and test pieces

- `output/lamp-base-plate.stl`: main plate, 200 × 180 mm; 4 mm deck; tallest clip 33.30 mm above the underside.
- `output/feet.stl`: all six removable snap-in feet, providing 10 mm of clearance below the plate.
- `output/foot.stl`: one foot for a trial print or replacement.
- `output/lamp-fit-test.stl`: one lamp recess and cable slot, 48 × 48 mm.
- `output/box-fit-test.stl`: full-size box cradle with both clips and a foot socket, 84 × 80 mm.
- `output/assembly.png`: assembled reference view using the supplied lamp and enclosure meshes.
- `lamp-base-plate.scad`: editable, parameterized source. Set `part` to select a print part or the assembly preview.

The assembly preview is not a printable combined model. Print only the plate and feet; use the existing lamp and enclosure designs separately.

## Fit and wiring

### TPU 95A feet option

Use **`output/feet-tpu95a-v2.stl`** for six revised TPU 95A feet, or **`output/foot-tpu95a-v2.stl`** for one trial foot. The unversioned TPU STL names also contain V2. These replace the PETG feet and fit the same plate sockets, with the same 14 mm base diameter and nominal 10 mm clearance. Keep the plate and its box clips in PETG.

The original solid 7 mm head proved too difficult to insert. V2 reduces the head to 6.2 mm and the stem to 5.2 mm, and adds a 1.2 mm-wide compression slot through the head and stem, ending 1.5 mm into the foot body. This creates two broad halves that can flex inward through the nominal 5.8 mm socket. The narrower lead-in is 4.2 mm. Plate holes and the 14 mm foot base / 10 mm standing height are unchanged, so no plate reprint is needed. Original failed foot meshes are archived in `reference/tpu-v1/`.

Print broad end down with your TPU 95A profile. Preserve the compression slot: confirm it is open in the slicer preview and clear any stringing after printing. No supports are intended. Press the tapered head through the socket until the broad foot sits against the underside and the head expands above the plate.

Print one V2 foot first and try it in the actual printed plate. Check insertion, full seating, and resistance to pulling out or rocking before printing all six. V2 meshes passed closure checks, but insertion force and retention are not physically verified. If it still will not insert, measure the actual printed hole and head before further adjustment. Remove by squeezing the two halves together from above and easing the head back through the hole.

```bash
/opt/homebrew/bin/openscad -o output/foot-tpu95a.stl --export-format binstl -D 'part="foot"' -D 'foot_material="TPU95A"' lamp-base-plate.scad
/opt/homebrew/bin/openscad -o output/feet-tpu95a.stl --export-format binstl -D 'part="feet"' -D 'foot_material="TPU95A"' lamp-base-plate.scad
```

### Layout and PETG feet

Eight lamps sit on 48 mm centers in two rows of four. Each recess is 38.36 × 38.566 mm and 1.4 mm deep, with 0.35 mm nominal clearance per side around the source lamp's bounding footprint. The floor is 2.6 mm thick. A rounded 14 × 7 mm through-slot beneath each lamp allows a four-pin connector to be fed upward into the lamp's open underside. Check your actual connector, including any heat-shrink or sleeve, in the test piece.

The enclosure sits centered behind the lamps, upside down with its lid toward the plate. Rotate it 180° about its left-to-right axis: the large lid cable opening faces the lamp rows; the existing side connector port faces the left edge of the plate when viewed from the lamps. Its original top rails and lid lip rest on the plate. The matching 44 × 17 mm through-opening is at plate coordinates (100.6, 55.81), aligned with the source lid opening (approximately 41.54 × 14.16 mm).

Two PETG cantilever clips catch the enclosure's upper edge (its original bottom). Four low corner guides locate it. The clips have 0.35 mm side clearance, 0.8 mm nominal overlap, and about 0.3 mm vertical clearance. Press the outward tabs away from the enclosure to release it; remove the enclosure before sliding the lid. Leave enough cable slack to lift it for service. The existing side connector port is clear of the clips.

Wires run freely beneath the raised plate. Feed connectors upward through the lamp slots and downward through the box opening, one at a time. No connectors need to pass through a closed cable tunnel. The design does not add cable clamps or strain relief; retain those at the lamp/box as required by your existing assembly.

Six feet push in from below. Their split pegs snap through the round sockets and remain visible on the top face. To remove a foot, gently compress its prongs from above while pulling it down. Feet need no screws or glue.

## Print and assembly

Use PETG for the clips and snap feet. Suggested starting settings: 0.4 mm nozzle, 0.2 mm layers, four perimeters, five top/bottom layers, and 25% infill. Place all supplied STL files flat as exported. The main plate has a flat underside; feet print broad end down. The only small unsupported details are the clip hook ledges and foot collars; support-free printing is intended but should be checked in the slicer and on the test pieces. Use a brim if needed for the large plate.

1. Print the lamp test, box test, and one foot with the intended material and settings.
2. Check lamp insertion/removal, connector passage, box seating, clip engagement/release, and foot engagement. Clips must flex without cracking or forcing the enclosure.
3. If needed, adjust `lamp_clearance`, `box_clearance`, `clip_overlap`, or the foot diameters in the SCAD source, then re-export and retest.
4. Print the full plate and six feet. Fit the feet, route the cables, seat the lamps, and gently snap in the inverted enclosure.

The model has been checked digitally for mesh closure. The user has confirmed that the printed box clip works; the original solid-head TPU feet failed insertion and have been replaced with the V2 design below. The lamp-retaining bead and off-center cable slot need a physical fit check before committing to the full plate.

## Regenerate

Run from this directory, using the command-line OpenSCAD installation:

```bash
/opt/homebrew/bin/openscad -o output/lamp-base-plate.stl --export-format binstl lamp-base-plate.scad
/opt/homebrew/bin/openscad -o output/feet.stl --export-format binstl -D 'part="feet"' lamp-base-plate.scad
/opt/homebrew/bin/openscad -o output/foot.stl --export-format binstl -D 'part="foot"' lamp-base-plate.scad
/opt/homebrew/bin/openscad -o output/lamp-fit-test.stl --export-format binstl -D 'part="lamp_test"' lamp-base-plate.scad
/opt/homebrew/bin/openscad -o output/box-fit-test.stl --export-format binstl -D 'part="box_test"' lamp-base-plate.scad
python3 reference/verify_meshes.py
```

The shared lamp STL is imported as a single mesh for previews and clearance checks. Its corner-based coordinates are shifted by (-18.83, -18.933, 0) mm to align it with the centered lamp seats; its bottom remains at Z=0. STL does not retain the former multi-part color assignments, so the lamp preview is a single color. The older extracted component STLs in `reference/` are retained as historical assets and are no longer build dependencies. `reference/check-clearance.scad` contains checks for the default dimensions; update its fixed placements if the layout is changed. OpenSCAD may return zero-thickness contact faces for these checks; those are distinguished from positive-volume interference.
