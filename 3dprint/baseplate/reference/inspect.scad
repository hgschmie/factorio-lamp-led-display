use <../lamp-base-plate.scad>
color("gray") import("../../case/out/base.stl");
translate([80,0,-23.1]) color("orange") import("../../case/out/lid.stl");
translate([180,30,0]) reference_lamp();
