// Sliding-lid enclosure for the lamp-led-display PCB (ESP32-C3 SuperMini, 8x LED headers).
//
// Board geometry comes from board_data.scad, generated from pcb.kicad_pcb by kicad2scad.py.
// Everything below is parametric; the values that most likely need tuning after a test print
// are marked "TUNE".
//
// Frames of reference
//   board frame : origin at the PCB lower-left corner, y up (matches the KiCad editor view)
//   case frame  : origin at the outer lower-left-bottom corner of the base
//   board frame = case frame translated by board_off (= wall + board_clear, plus the USB overhang gap in x)
//
// Lid slides in from the BACK (+y edge, away from the LED headers) towards the front.
// Its left, right and front edges are chamfered to a V (45 deg top and bottom) that runs in a matching
// V groove in the walls: every groove face is at 45 deg or steeper, so neither part needs support.
// A full-width bar on the lid's rear edge fills the recess in the back wall and is the end stop.

include <board_data.scad>

/* [What to render] */
part = "assembly"; // [base, lid, board, assembly, exploded, section]

/* [Walls and floor] */
wall        = 2.5;   // side wall thickness
floor_t     = 2.0;   // floor thickness
lid_t       = 2.0;   // lid plate thickness
corner_r    = 2.0;   // outer vertical edge radius

/* [Board mounting] */
board_clear  = 0.5;  // gap between PCB edge and inner wall, per side. TUNE
standoff_h   = 4.0;  // PCB underside above the floor (room for trimmed THT leads)
standoff_d   = 6.5;  // standoff outer diameter
screw_hole_d = 2.5;  // pilot hole for M3 self-tapping into plastic. TUNE (2.8 if too tight)

/* [Height budget] */
max_part_h = 14;     // tallest part above the PCB top (C1, measured 14 mm). TUNE
top_clear  = 1.5;    // air gap between tallest part and lid underside

/* [Sliding lid] */
lid_tip       = 0.4;  // flat at the tip of the V edge (two layers, avoids a knife edge)
lid_clear     = 0.3;  // gap between the lid's V edge and every groove flank, per face. TUNE
lid_end_clear = 0.3;  // extra gap at the front so the rear bar, not the front groove, is the end stop
groove_angle  = 45;   // flank angle from horizontal; 45 prints without support
top_lip       = 1.5;  // wall material above the groove mouth

/* [Cutouts] */
usb_z0       = 2.9;  // USB-C lower edge above the PCB top (measured)
usb_conn_h   = 3.2;  // USB-C receptacle height
usb_overhang = 1.0;  // how far the receptacle sticks out past the board edge (measured)
usb_w        = 13;   // cutout width along the wall
usb_margin_below = 1.0; // cutout extends this far below the receptacle
usb_margin_above = 2.5; // ... and this far above (room for the plug body)
header_margin_x = 1.5; // extra opening around the header row, x
header_margin_y = 1.5; // extra opening around the header row, y

/* [Rendering] */
$fn = 48;
eps = 0.01;

// ---------------------------------------------------------------- derived
// the left (USB) wall is pushed out by the receptacle overhang so the board drops straight in
usb_gap = usb_overhang + 0.2;
inner   = [pcb_size[0] + 2 * board_clear + usb_gap, pcb_size[1] + 2 * board_clear];
outer   = [inner[0] + 2 * wall, inner[1] + 2 * wall];
usb_h   = usb_margin_below + usb_conn_h + usb_margin_above;   // cutout height
usb_z   = usb_z0 - usb_margin_below + usb_h / 2;              // cutout centre above the PCB top
pcb_z   = floor_t + standoff_h;                 // PCB underside
pcb_top = pcb_z + pcb_thickness;
cavity_h = standoff_h + pcb_thickness + max_part_h + top_clear;
groove_z = floor_t + cavity_h;                  // nominal lid underside (lid centred in the V)
board_off = [wall + board_clear + usb_gap, wall + board_clear];

// V edge / V groove. The groove is the lid's V profile grown by lid_clear perpendicular to every face,
// so the groove's back flat has the height of the lid tip, lid_clear/sin(angle) beyond it.
v_run        = (lid_t - lid_tip) / 2 / tan(groove_angle);   // horizontal run of each lid chamfer = tongue depth
v_rise       = v_run * tan(groove_angle);                    // = (lid_t - lid_tip) / 2
v_shift      = lid_clear / cos(groove_angle);                // flank offset measured vertically
groove_depth = v_run + lid_clear / sin(groove_angle);        // apex depth into the wall
mouth_lo     = groove_z - v_shift;                           // groove mouth at the inner wall face
mouth_hi     = groove_z + lid_t + v_shift;
case_h       = mouth_hi + top_lip;                           // overall base height

lid_w = inner[0] + 2 * v_run;                       // tip to tip
lid_l = inner[1] + v_run - lid_end_clear + wall;    // front tip .. flush with the back face

assert(v_run > 0, "lid_tip must be smaller than lid_t");
assert(groove_depth < wall - 0.8, "groove too deep for the wall thickness");
assert(v_shift < top_clear, "lid can drop onto the tallest part: raise top_clear or lower lid_clear");

// header row extents in board frame (courtyards of J1..J8)
function part_box(ref) = [for (p = pcb_parts) if (p[0] == ref) [p[2], p[3], p[4], p[5]]][0];
hdr_x0 = min([for (h = pcb_headers) part_box(h[0])[0]]) - header_margin_x;
hdr_x1 = max([for (h = pcb_headers) part_box(h[0])[2]]) + header_margin_x;
hdr_y0 = min([for (h = pcb_headers) part_box(h[0])[1]]) - header_margin_y;
hdr_y1 = max([for (h = pcb_headers) part_box(h[0])[3]]) + header_margin_y;

// USB-C: centre of the ESP32 module's short axis, on the left board edge
u1 = part_box("U1");
usb_y = (u1[1] + u1[3]) / 2;

echo(str("outer=", outer, " case_h=", case_h, " groove_z=", groove_z, " groove_depth=", groove_depth,
         " mouth=", [mouth_lo, mouth_hi], " lid=", [lid_w, lid_l],
         " header_window=", [hdr_x0, hdr_y0, hdr_x1, hdr_y1], " usb_y=", usb_y));

// ---------------------------------------------------------------- helpers
module rounded_box(size, r) {
    linear_extrude(size[2])
        offset(r) offset(-r) square([size[0], size[1]]);
}

module in_board_frame() {
    translate([board_off[0], board_off[1], pcb_z]) children();
}

// thin horizontal slab: the cavity outline grown by u on the left, right and front, running back to y1.
// Hulls of these give the V profiles with mitred corners.
module rim_slab(u, z, front = 0, y1 = outer[1]) {
    translate([wall - u, wall - u + front, z]) cube([inner[0] + 2 * u, y1 - (wall - u + front), eps]);
}

// V groove in the left, right and front walls, up to the inner face of the back wall. The back wall itself is
// cut down to groove_z across the full width, so the lid enters over it and its V edges run into the grooves.
module groove_void() {
    y1 = outer[1] - wall + eps;
    hull() {
        rim_slab(0, mouth_lo, y1 = y1);
        rim_slab(groove_depth, groove_z + v_rise, y1 = y1);
        rim_slab(groove_depth, groove_z + lid_t - v_rise - eps, y1 = y1);
        rim_slab(0, mouth_hi - eps, y1 = y1);
    }
}

// ---------------------------------------------------------------- base
module base() {
    difference() {
        union() {
            difference() {
                rounded_box([outer[0], outer[1], case_h], corner_r);
                // cavity
                translate([wall, wall, floor_t]) cube([inner[0], inner[1], case_h]);
            }
            // standoffs
            in_board_frame() translate([0, 0, -standoff_h])
                for (h = pcb_holes) translate([h[1], h[2], 0]) cylinder(d = standoff_d, h = standoff_h);
        }
        // screw pilot holes (leave 1 mm of floor)
        in_board_frame() for (h = pcb_holes)
            translate([h[1], h[2], -(standoff_h + floor_t - 1)]) cylinder(d = screw_hole_d, h = standoff_h + floor_t);
        // lid groove: left + right walls and the front wall, open at the back
        groove_void();
        // back wall lowered to the lid underside so the lid can slide in; the lid's rear bar fills the recess
        translate([-eps, outer[1] - wall - eps, groove_z]) cube([outer[0] + 2 * eps, wall + 2 * eps, case_h]);
        // USB-C opening in the left wall
        in_board_frame() translate([-board_off[0] - eps, usb_y - usb_w / 2, pcb_thickness + usb_z - usb_h / 2])
            cube([board_off[0] + 2 * eps, usb_w, usb_h]);
    }
}

// ---------------------------------------------------------------- lid
// plate with the V edge on the left, right and front, cut straight at the back face
module lid_plate() {
    hull() {
        rim_slab(0, groove_z, front = lid_end_clear);
        rim_slab(v_run, groove_z + v_rise, front = lid_end_clear);
        rim_slab(v_run, groove_z + lid_t - v_rise - eps, front = lid_end_clear);
        rim_slab(0, groove_z + lid_t - eps, front = lid_end_clear);
    }
}

// rear bar: full outer width with the case's rounded corners, fills the recess in the back wall flush
// with the wall tops and seats against the side walls as the end stop
module lid_bar() {
    intersection() {
        rounded_box([outer[0], outer[1], case_h], corner_r);
        translate([-eps, outer[1] - wall, groove_z]) cube([outer[0] + 2 * eps, wall + eps, case_h - groove_z]);
    }
}

module lid() {
    difference() {
        union() { lid_plate(); lid_bar(); }
        // window over the LED header row
        in_board_frame() translate([hdr_x0, hdr_y0, -pcb_z - eps])
            cube([hdr_x1 - hdr_x0, hdr_y1 - hdr_y0, case_h + 2 * eps]);
    }
}

// ---------------------------------------------------------------- board mock-up (for fit checks only)
function part_h(ref, value) =
    ref == "C1" ? max_part_h :
    ref == "U1" ? usb_z0 + usb_conn_h : // module incl. USB-C receptacle
    ref == "U2" ? 8 :        // DIP socket + IC
    ref == "C2" ? 6 :
    ref == "R1" ? 3 :
    ref[0] == "J" ? 8.5 :    // 1x4 pin header (2.5 plastic + 6 pin)
    ref[0] == "T" ? 0.5 : 5;

module board() {
    in_board_frame() {
        color("darkgreen") difference() {
            cube([pcb_size[0], pcb_size[1], pcb_thickness]);
            for (h = pcb_holes) translate([h[1], h[2], -eps]) cylinder(d = h[3], h = pcb_thickness + 2 * eps);
        }
        // USB-C receptacle: sticks out past the left board edge
        color("silver") translate([-usb_overhang, usb_y - 4.45, pcb_thickness + usb_z0]) cube([7, 8.9, usb_conn_h]);
        for (p = pcb_parts)
            color(p[0][0] == "J" ? "black" : p[0] == "C1" ? "navy" : "silver")
                translate([p[2], p[3], pcb_thickness])
                    cube([p[4] - p[2], p[5] - p[3], part_h(p[0], p[1])]);
    }
}

// ---------------------------------------------------------------- dispatch
if (part == "base") base();
else if (part == "lid") lid();
else if (part == "board") board();
else if (part == "assembly") { base(); board(); color("lightsteelblue", 0.6) lid(); }
else if (part == "exploded") { base(); translate([0, 0, 8]) board(); translate([0, 25, 25]) color("lightsteelblue") lid(); }
// XZ cross-section through the middle of the closed box: shows the V edge sitting in the V groove
else if (part == "section") projection(cut = true) rotate([-90, 0, 0]) translate([0, -outer[1] / 2, 0]) { base(); lid(); }
