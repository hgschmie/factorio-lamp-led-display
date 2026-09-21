// Eight-lamp base plate. Units: mm. PETG intended for spring clips and feet.
// Original STL/3MF files are unchanged. Reference meshes are preview-only.
// Export parts with -D 'part="plate"', "foot", "feet", "lamp_test", "box_test".
part = "plate"; // [plate,assembly,foot,feet,lamp_test,box_test]
foot_material = "PETG"; // [PETG,TPU95A]

plate_width = 200;
plate_depth = 180;
plate_thickness = 4;
corner_radius = 4;
lamp_width = 37.66;
lamp_depth = 37.866;
lamp_clearance = 0.35; // Per side; tune after printing lamp_test.
recess_depth = 1.4;
lamp_hole = [14,7]; // Clear opening for a single-row four-pin connector.
lamp_hole_offset = [0,10]; // 10 mm toward +Y from the lamp center.
lamp_lip_height = 1.5; // Above the deck; small press-in retaining rim.
lamp_lip_thickness = 1.0;
lamp_lip_inset = 0.3; // Takes up 0.6 mm of total lateral clearance.
lamp_lip_bead = 0.2; // Additional inward nib; physical fit test required.
lamp_pitch = 48;
lamp_origin = [28,101];

box_width = 62.2;
box_depth = 61;
box_height = 27.02426407;
box_origin = [68.9,9];
box_clearance = 0.35;
box_hole = [44,17];
// Original lid hole: x=10.93..52.47, y=7.11..21.27.
// Box is rotated 180 degrees about X: original y maps to box_depth-y.
box_hole_original_center = [31.7,14.19];
clip_thickness = 1.6;
clip_width = 12;
clip_overlap = 0.8;
clip_vertical_clearance = 0.3;
clip_y = 50; // Absolute Y; avoids side port at Y=28.5..41.5.

foot_height = 10;
foot_diameter = 14;
foot_hole_diameter = 5.8;
foot_stem_diameter = 5.4;
foot_barb_diameter = 6.2;
foot_slot = 1.2;
tpu_stem_diameter = 5.2;
tpu_head_diameter = 6.2; // V2: smaller head for the existing 5.8 mm socket.
tpu_compression_slot = 1.2; // Two broad flexible halves, not a solid mushroom.
foot_positions = [[9,9],[191,9],[9,173],[191,173],[100,78],[100,173]];
$fn = 64;
eps = 0.02;

assert(plate_thickness-recess_depth >= 2, "Keep at least 2 mm beneath recesses");
assert(foot_stem_diameter < foot_hole_diameter && foot_hole_diameter < foot_barb_diameter);

module rounded_rect(w,d,r) {
    offset(r=r) square([w-2*r,d-2*r],center=true);
}
module slot(size,z,h,r=0.7) {
    translate([0,0,z]) linear_extrude(height=h) rounded_rect(size[0],size[1],r);
}
module deck(w,d) {
    translate([w/2,d/2,0]) linear_extrude(height=plate_thickness)
        rounded_rect(w,d,corner_radius);
}
module lamp_cut(hole_offset=lamp_hole_offset) {
    slot([lamp_width+2*lamp_clearance,lamp_depth+2*lamp_clearance],
        plate_thickness-recess_depth, recess_depth+eps,0.5);
    translate([hole_offset[0],hole_offset[1],0])
        slot(lamp_hole,-eps,plate_thickness+2*eps);
}
// Canonical orientation: box toward +X,+Y. Full left/bottom rails;
// top-left and bottom-right half rails, leaving the near corner open.
module lamp_lips(toward_box=[1,1]) {
    w=lamp_width+2*lamp_clearance;
    d=lamp_depth+2*lamp_clearance;
    scale([toward_box[0],toward_box[1],1]) {
        mirror([0,1,0]) lamp_lip_rail(w,d/2-lamp_lip_inset);
        rotate([0,0,90]) lamp_lip_rail(d,w/2-lamp_lip_inset);
        translate([-w/4,0,0]) lamp_lip_rail(w/2,d/2-lamp_lip_inset);
        translate([0,-d/4,0]) rotate([0,0,-90]) lamp_lip_rail(d/2,w/2-lamp_lip_inset);
    }
}
module lamp_lip_rail(length,inner) {
    top=plate_thickness+lamp_lip_height;
    // Profile uses a 0.2 mm inward bead and a chamfered insertion ramp.
    // Slight interference with the source lamp's vertical outer details
    // is intentional for the press fit, unlike the previous loose recess.
    translate([-length/2,0,0]) rotate([90,0,90])
        linear_extrude(height=length) polygon([
            [inner,plate_thickness-recess_depth-eps],
            [inner+lamp_lip_thickness,plate_thickness-recess_depth-eps],
            [inner+lamp_lip_thickness,top],
            [inner+0.2,top],
            [inner-lamp_lip_bead,top-0.5],
            [inner-lamp_lip_bead,top-0.7],
            [inner,top-0.9]
        ]);
}
function box_direction(p,center) = [p[0]<center[0]?1:-1,p[1]<center[1]?1:-1];
module box_cut() {
    translate([box_origin[0]+box_hole_original_center[0],
               box_origin[1]+box_depth-box_hole_original_center[1],0])
        slot(box_hole,-eps,plate_thickness+2*eps,1);
}

// Clip is defined with X pointing into the box. A short flat hook catches
// the original bottom face. Push the outward tab to release the box.
module clip() {
    h = box_height+clip_vertical_clearance;
    t = clip_thickness;
    reach = box_clearance+clip_overlap;
    // Extrude the X/Z profile along Y. The hook's unsupported ledge is <1 mm.
    translate([0,clip_width/2,plate_thickness-eps]) rotate([90,0,0])
        linear_extrude(height=clip_width) polygon([
            [0,0],[t,0],[t,h-0.5],[t+0.5,h],
            [t+reach,h],[t+reach,h+0.6],[t,h+2],
            [-2,h+2],[-2,h+1.2],[0,h-0.8]
        ]);
    // Tapered root reinforcement; leave the upper arm free to bend.
    translate([0,clip_width/2,plate_thickness-eps]) rotate([90,0,0])
        linear_extrude(height=clip_width) polygon([[-2,0],[t,0],[t,4],[0,4]]);
}
module box_mount() {
    // Two clips, positioned away from the existing side connector port.
    translate([box_origin[0]-box_clearance-clip_thickness,clip_y,0]) clip();
    translate([box_origin[0]+box_width+box_clearance+clip_thickness,clip_y,0])
        mirror([1,0,0]) clip();
    // Four low L-shaped guides locate the box without gripping the lid.
    for (sx=[-1,1], sy=[-1,1]) {
        cx=box_origin[0]+box_width/2+sx*(box_width/2+box_clearance);
        cy=box_origin[1]+box_depth/2+sy*(box_depth/2+box_clearance);
        translate([cx,cy,plate_thickness-eps]) scale([sx,sy,1]) union() {
            translate([-7,0,0]) cube([8.8,1.8,2+eps]);
            translate([0,-7,0]) cube([1.8,8.8,2+eps]);
        }
    }
}
module plate() {
    union() {
        difference() {
            deck(plate_width,plate_depth);
            for(row=[0:1],col=[0:3])
                translate([lamp_origin[0]+col*lamp_pitch,lamp_origin[1]+row*lamp_pitch,0]) lamp_cut();
            box_cut();
            for(p=foot_positions) translate([p[0],p[1],-eps])
                cylinder(d=foot_hole_diameter,h=plate_thickness+2*eps);
        }
        box_mount();
        for(row=[0:1],col=[0:3]) {
            p=[lamp_origin[0]+col*lamp_pitch,lamp_origin[1]+row*lamp_pitch];
            translate([p[0],p[1],0]) lamp_lips(box_direction(p,
                [box_origin[0]+box_width/2,box_origin[1]+box_depth/2]));
        }
    }
}
module foot() {
    if(foot_material=="TPU95A") tpu_foot();
    else petg_foot();
}
module tpu_foot() {
    // V2: two broad halves can fold inward during insertion. The previous
    // solid 7 mm head proved too difficult to push through the printed hole.
    shoulder=foot_height+plate_thickness+0.15;
    flare=(tpu_head_diameter-tpu_stem_diameter)/2;
    assert(tpu_stem_diameter < foot_hole_diameter && tpu_head_diameter > foot_hole_diameter);
    difference() {
        union() {
            cylinder(d=foot_diameter,h=foot_height-1);
            translate([0,0,foot_height-1]) cylinder(d1=foot_diameter,d2=foot_diameter-2,h=1);
            translate([0,0,foot_height-eps]) cylinder(d=tpu_stem_diameter,h=plate_thickness+0.15+eps);
            translate([0,0,shoulder]) cylinder(d1=tpu_stem_diameter,d2=tpu_head_diameter,h=flare);
            translate([0,0,shoulder+flare]) cylinder(d=tpu_head_diameter,h=0.35);
            translate([0,0,shoulder+flare+0.35]) cylinder(d1=tpu_head_diameter,d2=4.2,h=1.4);
        }
        translate([-(tpu_head_diameter+1)/2,-tpu_compression_slot/2,foot_height-1.5])
            cube([tpu_head_diameter+1,tpu_compression_slot,plate_thickness+5]);
    }
}
module petg_foot() {
    // Print broad end down. Four spring prongs compress through the deck,
    // then their small collar expands above it. No screws or adhesive.
    shoulder=foot_height+plate_thickness+0.2;
    difference() {
        union() {
            cylinder(d=foot_diameter,h=foot_height-1);
            translate([0,0,foot_height-1]) cylinder(d1=foot_diameter,d2=foot_diameter-2,h=1);
            translate([0,0,foot_height-eps]) cylinder(d=foot_stem_diameter,h=plate_thickness+0.2+eps);
            translate([0,0,shoulder-0.4]) cylinder(d1=foot_stem_diameter,d2=foot_barb_diameter,h=0.4);
            translate([0,0,shoulder]) cylinder(d=foot_barb_diameter,h=0.4);
            translate([0,0,shoulder+0.4]) cylinder(d1=foot_barb_diameter,d2=4.6,h=1.1);
        }
        for(a=[0,90]) rotate([0,0,a]) translate([-4,-foot_slot/2,foot_height-3])
            cube([8,foot_slot,plate_thickness+6]);
    }
}
module lamp_test(hole_offset=lamp_hole_offset) {
    union() {
        difference() {
            deck(48,48);
            translate([24,24,0]) lamp_cut(hole_offset);
        }
        translate([24,24,0]) lamp_lips();
    }
}
module box_test() {
    // A full-size box cradle is necessary to test the paired snap clips.
    translate([-59,0,0]) union() {
        difference() {
            translate([59,0,0]) deck(84,80);
            box_cut();
            translate([100,75,-eps]) cylinder(d=foot_hole_diameter,h=plate_thickness+2*eps);
        }
        box_mount();
    }
}
module reference_lamp() {
    color([0.23,0.26,0.28]) import("reference/lamp-base.stl");
    color([0.86,0.94,0.87,0.88]) import("reference/lamp-dome.stl");
    color([0.32,0.34,0.35]) import("reference/lamp-antenna.stl");
    color([0.65,0.66,0.67]) import("reference/lamp-screws.stl");
}
module assembly() {
    color([0.28,0.39,0.46]) plate();
    for(p=foot_positions) translate([p[0],p[1],-foot_height]) color([0.18,0.21,0.23]) foot();
    for(row=[0:1],col=[0:3])
        translate([lamp_origin[0]+col*lamp_pitch,lamp_origin[1]+row*lamp_pitch,plate_thickness-recess_depth])
            reference_lamp();
    translate([box_origin[0],box_origin[1]+box_depth,plate_thickness+box_height]) rotate([180,0,0]) {
        color([0.56,0.59,0.61]) import("base.stl");
        color([0.4,0.44,0.46]) import("lid.stl");
    }
}

if(part=="plate") plate();
else if(part=="foot") foot();
else if(part=="feet") for(x=[0:2],y=[0:1]) translate([x*18,y*18,0]) foot();
else if(part=="lamp_test") lamp_test();
else if(part=="box_test") box_test();
else if(part=="assembly") assembly();
else assert(false,"Unknown part");
