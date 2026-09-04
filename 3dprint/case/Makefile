# Build the enclosure STLs and preview images from case.scad.   Usage:  make -f build.mk [target]
#   (default)   -> out/base.stl out/lid.stl + previews
#   test        -> fit tests (needs only uv: https://docs.astral.sh/uv/ ; deps are fetched automatically)
#   board_data  -> regenerate board_data.scad from ../pcb.kicad_pcb (or PCB=path)
#
# On macOS, OpenSCAD is usually at /Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD;
# override with  make OPENSCAD=/path/to/openscad

OPENSCAD ?= $(shell command -v openscad 2>/dev/null || echo /Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD)
PCB ?= ../../pcb/pcb/pcb.kicad_pcb
OUT = build

all: $(OUT)/base.stl $(OUT)/lid.stl $(OUT)/assembly.png $(OUT)/exploded.png

$(OUT):
	mkdir -p $(OUT)

$(OUT)/%.stl: case.scad board_data.scad | $(OUT)
	$(OPENSCAD) -o $@ -D 'part="$*"' case.scad

$(OUT)/%.png: case.scad board_data.scad | $(OUT)
	$(OPENSCAD) -o $@ -D 'part="$*"' --imgsize=1400,1000 --camera=0,0,0,55,0,215,260 --autocenter --viewall --projection=p case.scad

board_data:
	uv run kicad2scad.py $(PCB) board_data.scad

test:
	OPENSCAD=$(OPENSCAD) PCB=$(PCB) uv run test_case.py

clean:
	rm -rf $(OUT)

.PHONY: all test clean board_data
