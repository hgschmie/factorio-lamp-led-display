use <../lamp-base-plate.scad>
// Lamps now intentionally have small interference at the retaining beads.
// Box and feet should have only seating-plane contact, or an empty result.
$fn=64;
check = "lamps";
intersection() {
    plate();
    if(check=="lamps") {
        for(row=[0:1], col=[0:3]) translate([28+48*col,101+48*row,2.6])
            reference_lamp();
    } else if(check=="box") {
        translate([68.9,70,31.02426407]) rotate([180,0,0]) {
            import("../../case/out/base.stl");
            import("../../case/out/lid.stl");
        }
    } else if(check=="feet") {
        for(p=[[9,9],[191,9],[9,173],[191,173],[100,78],[100,173]])
            translate([p[0],p[1],-10]) foot();
    }
}
