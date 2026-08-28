# PCB

This directory contains the KiCad project for the eight-channel LED interface board.

![KiCad rendered PCB Image](/images/pcb-rendered.png)

## Project files

- `pcb.kicad_pro`, `pcb.kicad_sch`, and `pcb.kicad_pcb` are the KiCad project, schematic, and board layout.
- `display_parts.kicad_sym`, `display_parts.pretty/`, `sym-lib-table`, and `fp-lib-table` are the project-local symbol and footprint libraries.
- `fabrication-toolkit-options.json` contains settings for the optional Fabrication Toolkit plugin.
- `production/` is generated output and is not an editable source of the design.

Open `pcb.kicad_pro` in KiCad. Use the Schematic Editor to change the circuit, then run **Inspect → Electrical Rules Checker**. Transfer changes with **Tools → Update PCB from Schematic**, finish placement and routing in the PCB Editor, refill copper zones, and run **Inspect → Design Rules Checker**. Resolve all DRC errors before ordering.

## Creating fabrication files

Save the project before exporting. In the PCB Editor, use **File → Fabrication Outputs** to create:

- Gerbers for `F.Cu`, `B.Cu`, `F.Mask`, `B.Mask`, `F.Silkscreen`, `B.Silkscreen`, and `Edge.Cuts`;
- separate plated and non-plated Excellon drill files;
- paste layers only when ordering a solder stencil;
- a BOM and component-position file only when ordering assembly.

Alternatively, if the Fabrication Toolkit plugin is installed, run it from **Tools → External Plugins** and export into `production/`. Zip the Gerber and drill files together and upload that archive to the PCB manufacturer. Check the manufacturer's Gerber preview, board dimensions, layer count, thickness, and drill holes before placing the order.

KiCad lock files, `pcb-backups/`, `*.kicad_prl`, exported netlists, and files under `production/` are generated or machine-local and do not need to be committed.
