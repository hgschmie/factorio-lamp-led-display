// Portrait alternative: 3 + 3 lamps above, 2 down the left beside the box.
// Reuses the original recess, clips, connector slots and TPU foot geometry.
use <lamp-base-plate.scad>
part = "plate"; // [plate,assembly]
alt_width = 160;
alt_depth = 208;
alt_lamps = [[32,176],[80,176],[128,176],
             [32,128],[80,128],[128,128],[32,80],[32,32]];
alt_feet = [[8,8],[152,8],[8,200],[152,200],[8,104],[152,104]];
alt_box = [80.9,25.5];
$fn = 64;

// Move the complete original box mount as a unit, rotating it 180 degrees
// in plan so its side connector port faces the outer right edge.
module box_placement() {
    translate([alt_box[0]+62.2+68.9,alt_box[1]+61+9,0])
        rotate([0,0,180]) children();
}
module alternative_plate() {
    union() {
        difference() {
            deck(alt_width,alt_depth);
            for(p=alt_lamps) translate([p[0],p[1],0]) lamp_cut();
            box_placement() box_cut();
            for(p=alt_feet) translate([p[0],p[1],-0.02]) cylinder(d=5.8,h=4.04);
        }
        box_placement() box_mount();
        for(p=alt_lamps) translate([p[0],p[1],0])
            lamp_lips(box_direction(p,[alt_box[0]+62.2/2,alt_box[1]+61/2]));
    }
}
module alternative_lamps() {
    for(p=alt_lamps) translate([p[0],p[1],2.6]) reference_lamp();
}
module alternative_box() {
    translate([alt_box[0]+62.2,alt_box[1],31.02426407]) rotate([0,180,0]) {
        color([0.56,0.59,0.61]) import("../case/out/base.stl");
        color([0.4,0.44,0.46]) import("../case/out/lid.stl");
    }
}
module alternative_feet() {
    for(p=alt_feet) translate([p[0],p[1],-10]) tpu_foot();
}
module alternative_assembly() {
    color([0.28,0.39,0.46]) alternative_plate();
    alternative_lamps();
    alternative_box();
    color([0.18,0.21,0.23]) alternative_feet();
}

if(part=="plate") alternative_plate();
else if(part=="assembly") alternative_assembly();
else assert(false,"Unknown part");
