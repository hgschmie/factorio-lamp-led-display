// PREVIEW ONLY. Does not modify any production plate or STL.
// Box is toward +X,+Y. Half lips align to the far corners:
// top-left half of top edge; bottom-right half of right edge.
use <../lamp-base-plate.scad>
$fn=64;
view="top"; // [top,detail]
w=38.36;
d=38.566;
inset=0.3; // Takes up 0.6 mm of total lateral clearance.
wall=1.0;
rise=0.8; // Above the 4 mm plate surface.

module rail(length,inner) {
    translate([-length/2,inner,2.6]) cube([length,wall,1.4+rise-0.2]);
    hull() {
        translate([-length/2,inner,4+rise-0.21]) cube([length,wall,0.01]);
        translate([-length/2,inner+0.2,4+rise-0.01]) cube([length,wall-0.2,0.01]);
    }
}
module lips() {
    // Full length on bottom and left, away from the box.
    mirror([0,1,0]) rail(w,d/2-inset);
    rotate([0,0,90]) rail(d,w/2-inset);
    // Half length on top and right, anchored at the far corners.
    translate([-w/4,0,0]) rail(w/2,d/2-inset);
    translate([0,-d/4,0]) rotate([0,0,-90]) rail(d/2,w/2-inset);
}
color([0.30,0.43,0.50]) difference() {
    deck(48,48);
    translate([24,24,0]) lamp_cut();
}
translate([24,24,0]) color([0.96,0.56,0.15]) lips();

if(view=="top") color([0.15,0.18,0.21]) {
    translate([24,-7,4.9]) linear_extrude(0.1) text("Full length",size=3,halign="center");
    translate([-5,24,4.9]) rotate([0,0,90]) linear_extrude(0.1)
        text("Full length",size=3,halign="center");
    translate([14,51,4.9]) linear_extrude(0.1) text("Half length",size=2.8,halign="center");
    translate([51,14,4.9]) rotate([0,0,90]) linear_extrude(0.1)
        text("Half length",size=2.8,halign="center");
    translate([43,43,4.9]) rotate([0,0,45]) linear_extrude(0.1)
        polygon([[0,-0.2],[12,-0.2],[12,-1.2],[15,0],[12,1.2],[12,0.2],[0,0.2]]);
    translate([57,57,4.9]) linear_extrude(0.1) text("BOX",size=3.2,halign="center");
}
