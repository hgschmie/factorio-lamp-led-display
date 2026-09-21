# Run from this directory. Paths with spaces in the parent directory are fine.
.DEFAULT_GOAL := all
.DELETE_ON_ERROR:

OPENSCAD ?= openscad
PYTHON ?= python3
SCAD_FLAGS ?= --hardwarnings

MAIN_PARTS := output/lamp-base-plate.stl output/foot.stl output/feet.stl \
              output/foot-tpu95a.stl output/feet-tpu95a.stl \
              output/lamp-fit-test.stl output/box-fit-test.stl
STLS := $(MAIN_PARTS) output/lamp-base-plate-alternative.stl \
        output/lamp-base-plate-five.stl output/lamp-position-cover.stl \
        output/foot-tpu95a-v2.stl output/feet-tpu95a-v2.stl
ASSEMBLY_PREVIEWS := output/assembly.png output/alternative-assembly.png \
                     output/alternative-top.png output/five-assembly.png output/five-top.png
PREVIEWS := $(ASSEMBLY_PREVIEWS) output/plate.png output/alternative-plate.png \
            output/five-plate.png output/lamp-lip-test.png output/foot-tpu95a-v2.png \
            output/lamp-position-cover-detail.png
REFERENCE_MESHES := ../case/out/base.stl ../case/out/lid.stl ../lamp/lamp.stl

.PHONY: all stls check previews everything clean help
all: stls check
stls: $(STLS)
check: output/mesh-checks.json
previews: $(PREVIEWS)
everything: all previews

output:
	mkdir -p "$@"

$(MAIN_PARTS): PART = plate
$(MAIN_PARTS): MATERIAL = PETG
output/foot.stl output/foot-tpu95a.stl: PART = foot
output/feet.stl output/feet-tpu95a.stl: PART = feet
output/foot-tpu95a.stl output/feet-tpu95a.stl: MATERIAL = TPU95A
output/lamp-fit-test.stl: PART = lamp_test
output/box-fit-test.stl: PART = box_test
$(MAIN_PARTS): lamp-base-plate.scad Makefile | output
	"$(OPENSCAD)" $(SCAD_FLAGS) --export-format binstl -o "$@" -D 'part="$(PART)"' -D 'foot_material="$(MATERIAL)"' "$<"

# Each standalone design imports the shared geometry from the original plate.
output/%.stl: %.scad lamp-base-plate.scad Makefile | output
	"$(OPENSCAD)" $(SCAD_FLAGS) --export-format binstl -o "$@" "$<"

# Keep the explicit V2 download names identical to the current TPU exports.
output/foot-tpu95a-v2.stl: output/foot-tpu95a.stl Makefile | output
	cp "$<" "$@"
output/feet-tpu95a-v2.stl: output/feet-tpu95a.stl Makefile | output
	cp "$<" "$@"

output/mesh-checks.json: $(STLS) reference/verify_meshes.py Makefile
	"$(PYTHON)" reference/verify_meshes.py

# Current design previews; historical proposal/comparison images are preserved.
$(PREVIEWS): SOURCE = lamp-base-plate.scad
$(PREVIEWS): PART = plate
$(PREVIEWS): MATERIAL = PETG
$(PREVIEWS): SIZE = 1500,1200
$(PREVIEWS): CAMERA = 100,90,0,52,0,155,400
$(PREVIEWS): lamp-base-plate.scad Makefile | output
	"$(OPENSCAD)" $(SCAD_FLAGS) -o "$@" -D 'part="$(PART)"' -D 'foot_material="$(MATERIAL)"' --imgsize=$(SIZE) --camera=$(CAMERA) --autocenter --viewall --projection=o --colorscheme=Tomorrow "$(SOURCE)"

$(ASSEMBLY_PREVIEWS): PART = assembly
$(ASSEMBLY_PREVIEWS): $(REFERENCE_MESHES)
output/alternative-assembly.png output/alternative-top.png output/alternative-plate.png: SOURCE = lamp-base-plate-alternative.scad
output/alternative-assembly.png output/alternative-top.png output/alternative-plate.png: lamp-base-plate-alternative.scad
output/alternative-assembly.png output/alternative-plate.png: SIZE = 1500,1400
output/alternative-assembly.png output/alternative-plate.png: CAMERA = 80,104,0,45,0,20,400
output/alternative-top.png: SIZE = 1100,1400
output/alternative-top.png: CAMERA = 80,104,0,0,0,0,400
output/five-assembly.png output/five-top.png output/five-plate.png: SOURCE = lamp-base-plate-five.scad
output/five-assembly.png output/five-top.png output/five-plate.png: lamp-base-plate-five.scad
output/five-assembly.png output/five-plate.png: SIZE = 1400,1200
output/five-assembly.png output/five-plate.png: CAMERA = 80,80,0,45,0,20,400
output/five-top.png: SIZE = 1100,1100
output/five-top.png: CAMERA = 80,80,0,0,0,0,400
output/lamp-lip-test.png: PART = lamp_test
output/lamp-lip-test.png: SIZE = 1000,800
output/lamp-lip-test.png: CAMERA = 24,24,0,55,0,25,180
output/foot-tpu95a-v2.png: PART = foot
output/foot-tpu95a-v2.png: MATERIAL = TPU95A
output/foot-tpu95a-v2.png: SIZE = 850,850
output/foot-tpu95a-v2.png: CAMERA = 0,0,8,60,0,25,80
output/lamp-position-cover-detail.png: SOURCE = lamp-position-cover.scad
output/lamp-position-cover-detail.png: PART = detail
output/lamp-position-cover-detail.png: SIZE = 1200,1000
output/lamp-position-cover-detail.png: CAMERA = 0,0,3,35,0,0,180
output/lamp-position-cover-detail.png: lamp-position-cover.scad

clean:
	rm -f $(STLS) $(PREVIEWS) output/mesh-checks.json

help:
	@echo 'make             Build all printable STLs and validate their meshes'
	@echo 'make previews    Render current design previews'
	@echo 'make everything  Build STLs, validate meshes, and render previews'
	@echo 'make -B          Force a rebuild of the printable outputs'
	@echo 'make clean       Remove only the outputs managed by this Makefile'
	@echo 'Override tools with OPENSCAD=/path/to/openscad PYTHON=python3'
