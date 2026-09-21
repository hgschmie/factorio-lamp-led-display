// Dimensioned top-view comparison only; not a print part.
use <../lamp-base-plate.scad>
$fn=64;
color([0.55,0.59,0.61]) lamp_test([0,0]);
translate([64,0,0]) color([0.28,0.45,0.53]) lamp_test([0,10]);
color([0.15,0.18,0.21]) {
    translate([24,54,4.1]) linear_extrude(0.1) text("OLD",size=4,halign="center");
    translate([88,54,4.1]) linear_extrude(0.1) text("NEW",size=4,halign="center");
    translate([24,-7,4.1]) linear_extrude(0.1) text("Centered",size=3.4,halign="center");
    translate([88,-7,4.1]) linear_extrude(0.1) text("10 mm toward +Y",size=3.4,halign="center");
}
// Dashed orange outline on the new piece marks the former hole.
color([0.85,0.36,0.1]) {
    for(x=[81:3:93],y=[20.5,27.5]) translate([x,y,4.1]) cube([1.5,0.25,0.1]);
    for(x=[81,95],y=[20.5:3:26.5]) translate([x,y,4.1]) cube([0.25,1.5,0.1]);
}
color([0.15,0.18,0.21]) {
    for(y=[24,34]) translate([97,y,4.1]) cube([8.5,0.22,0.1]);
    translate([104,24,4.1]) cube([0.22,10,0.1]);
    translate([104.11,24,4.1]) linear_extrude(0.1) polygon([[0,0],[-0.7,1.5],[0.7,1.5]]);
    translate([104.11,34,4.1]) linear_extrude(0.1) polygon([[0,0],[-0.7,-1.5],[0.7,-1.5]]);
    translate([107,29,4.1]) linear_extrude(0.1) text("10 mm",size=3,valign="center");
}
