# PCB

This directory contains the KiCad project for the eight-channel LED interface board and the LED adapter

## Interface Board (pcb folder)

![KiCad rendered PCB Image](/images/pcb-rendered.png)

### Project files

- `pcb.kicad_pro`, `pcb.kicad_sch`, and `pcb.kicad_pcb` are the KiCad project, schematic, and board layout.
- `display_parts.kicad_sym`, `display_parts.pretty/`, `sym-lib-table`, and `fp-lib-table` are the project-local symbol and footprint libraries.
- `fabrication-toolkit-options.json` contains settings for the optional Fabrication Toolkit plugin.
- `production/` is generated output and is not an editable source of the design.

Open `pcb.kicad_pro` in KiCad. Use the Schematic Editor to change the circuit, then run **Inspect → Electrical Rules Checker**. Transfer changes with **Tools → Update PCB from Schematic**, finish placement and routing in the PCB Editor, refill copper zones, and run **Inspect → Design Rules Checker**. Resolve all DRC errors before ordering.

### Creating fabrication files

Save the project before exporting. In the PCB Editor, use **File → Fabrication Outputs** to create:

- Gerbers for `F.Cu`, `B.Cu`, `F.Mask`, `B.Mask`, `F.Silkscreen`, `B.Silkscreen`, and `Edge.Cuts`;
- separate plated and non-plated Excellon drill files;
- paste layers only when ordering a solder stencil;
- a BOM and component-position file only when ordering assembly.

Alternatively, if the Fabrication Toolkit plugin is installed, run it from **Tools → External Plugins** and export into `production/`. Zip the Gerber and drill files together and upload that archive to the PCB manufacturer. Check the manufacturer's Gerber preview, board dimensions, layer count, thickness, and drill holes before placing the order.

KiCad lock files, `pcb-backups/`, `*.kicad_prl`, exported netlists, and files under `production/` are generated or machine-local and do not need to be committed.


## LED Board (led folder)

Soldering the LEDs to wires became cumbersome so I designed another, small board. I ordered 50 of those from both JLCPCB and PCBWAY (and I paid more for shipping than the actual boards).

I used LEDs from adafruit (https://www.adafruit.com/product/1938) but they are expensive and often out of stock. Those can be used with the board but DIn and DOut are swapped compared to the board print. Also, make sure that the ground pin (inner short pin) really is in the right place on the board. These LEDs use RGB order, so the controller must be set accordingly.

I used *WAY MORE* shockingly cheap (~$.24 compared to roughly $1 from adafruit) LEDs from Amazon (https://www.amazon.com/dp/B0H87Y196Q). While it looked a bit shady, they came straight from China (8 business days) and work fine. Two caveats, however: a) They have a different color order (GRB). This can be configured on the controller but it means you can not mix with adafruit LEDs. And b) more importantly, those LEDs are really sensitive to be wired up wrong. Almost any LED I ever used can survive a brief wiring error but not those. One mistake and the LED is toast. Double check your connections and order more than the few you need (I mean, they come in 100 packs) because you will fry a few (I fried about a dozen).

The boards show a wire connector but in reality there is not enough space below the 3d printed LED case for that. Solder the wires directly to the board.

Speaking of wires:

Unless you really like crimping dupont connectors (I don't), making the connectors for the LEDs is pretty annoying. I ended up buying breadboard jumper cables (https://www.amazon.com/dp/B0FJXZZM83) and cut off the connectors on one side and soldered them directly onto the LED boards. That leaves you with the problem of four separate, small pins one the other end which are annoying to plug onto the controller board (especially through the opening in the top of the box or the underside of a base plate. Enter https://makerworld.com/en/models/2594713-dupont-connector-bridge which is fantastic for turning four pins into a single connector (with a pin 1 marker! That is really important, see above). Except that it is a tiny bit too tall to fit eight in a row onto the board (if I had discovered those before I ordered the boards, I would have left more space but I did not). So I asked claude to make a slimmer version, which is in the `3dprint/connector` folder.
