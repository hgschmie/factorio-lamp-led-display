// Five-lamp plate: 3 lamps above, 2 down the left beside the box.
// Reuses the original recess, clips, connector slots and TPU foot geometry.
use <lamp-base-plate.scad>
part = "plate"; // [plate,assembly]
five_width = 160;
five_depth = 160;
five_lamps = [[32,128],[80,128],[128,128],[32,80],[32,32]];
five_feet = [[8,8],[152,8],[8,152],[152,152],[8,80],[152,80]];
five_box = [80.9,25.5];
$fn = 64;

// Move the complete original box mount as a unit, rotating it 180 degrees
// in plan so its side connector port faces the outer right edge.
module box_placement() {
    translate([five_box[0]+62.2+68.9,five_box[1]+61+9,0])
        rotate([0,0,180]) children();
}
module five_plate() {
    union() {
        difference() {
            deck(five_width,five_depth);
            for(p=five_lamps) translate([p[0],p[1],0]) lamp_cut();
            box_placement() box_cut();
            for(p=five_feet) translate([p[0],p[1],-0.02]) cylinder(d=5.8,h=4.04);
        }
        box_placement() box_mount();
        for(p=five_lamps) translate([p[0],p[1],0])
            lamp_lips(box_direction(p,[five_box[0]+62.2/2,five_box[1]+61/2]));
    }
}
module five_lamps() {
    for(p=five_lamps) translate([p[0],p[1],2.6]) reference_lamp();
}
module five_box() {
    translate([five_box[0]+62.2,five_box[1],31.02426407]) rotate([0,180,0]) {
        color([0.56,0.59,0.61]) import("base.stl");
        color([0.4,0.44,0.46]) import("lid.stl");
    }
}
module five_feet() {
    for(p=five_feet) translate([p[0],p[1],-10]) tpu_foot();
}
module five_assembly() {
    color([0.28,0.39,0.46]) five_plate();
    five_lamps();
    five_box();
    color([0.18,0.21,0.23]) five_feet();
}

if(part=="plate") five_plate();
else if(part=="assembly") five_assembly();
else assert(false,"Unknown part");
