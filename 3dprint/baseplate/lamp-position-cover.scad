// Glue-on cover for the first (2x4) board, near-box row, second from left
// in the delivered front-facing view. Local +Y points toward the box;
// the adjacent center foot is at the cover's upper-right corner.
use <lamp-base-plate.scad>
part="print"; // [print,installed,assembly,detail,collision]
overlap=2.5;
skin=1.2;
lip_clearance=0; // User confirmed retaining lips have been removed.
cover_height=skin+lip_clearance;
cover_size=[38.36+2*overlap,38.566+2*overlap];
pocket_size=[40.36,40.566]; // Clears the existing lips by 0.3 mm per side.
foot_notch_radius=4.2; // Clears even the original 7 mm TPU head by 0.7 mm.
$fn=96;

module cover() {
    difference() {
        linear_extrude(cover_height) rounded_rect(cover_size[0],cover_size[1],1);
        translate([24,23,-0.02]) cylinder(r=foot_notch_radius,h=cover_height+0.04);
        translate([0,-10,0]) slot([14,7],-0.02,cover_height+0.04);
        if(lip_clearance>0)
            translate([0,0,-0.02]) linear_extrude(lip_clearance+0.02)
                rounded_rect(pocket_size[0],pocket_size[1],0.4);
    }
}
module installed_cover() {
    // Corresponds to lamp at (124,101) in the original board coordinates.
    translate([124,101,4]) rotate([0,0,180]) cover();
}
module supporting_board() {
    // Represent the reported physical board: target lips trimmed flush.
    difference() {
        plate();
        translate([102,79,4]) cube([44,44,2]);
    }
}
module local_detail() {
    // Show the covered lamp position, a little deck around it and the foot.
    color([0.28,0.39,0.46]) difference() {
        translate([-28,-28,0]) cube([60,60,4]);
        rotate([0,0,180]) lamp_cut();
        translate([24,23,-0.02]) cylinder(d=5.8,h=4.04);
    }
    if(lip_clearance>0) color([0.28,0.39,0.46]) lamp_lips([1,1]);
    translate([24,23,-10]) color([0.18,0.21,0.23]) tpu_foot();
    translate([0,0,4]) color([0.88,0.59,0.22]) cover();
}

if(part=="print") {
    // Either broad face can sit on the bed for the flat 1.2 mm version.
    translate([0,0,cover_height]) rotate([180,0,0]) cover();
} else if(part=="installed") cover();
else if(part=="detail") local_detail();
else if(part=="assembly") {
    color([0.28,0.39,0.46]) supporting_board();
    color([0.88,0.59,0.22]) installed_cover();
    translate([100,78,-10]) color([0.18,0.21,0.23]) tpu_foot();
} else if(part=="collision") {
    intersection() {
        // Lift 0.01 mm to exclude intended coplanar glue-contact surfaces.
        translate([0,0,0.01]) installed_cover();
        union() {
            supporting_board();
            translate([100,78,-10]) tpu_foot();
            // Conservative envelope of every prior foot head version.
            translate([100,78,4]) cylinder(d=7,h=3);
        }
    }
} else assert(false,"Unknown part");
