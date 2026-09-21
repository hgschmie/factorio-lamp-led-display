use <../lamp-base-plate-alternative.scad>
check = "lamps";
$fn = 64; // Match the exported plate and foot cylinder tessellation.
intersection() {
    alternative_plate();
    if(check=="lamps") alternative_lamps();
    else if(check=="box") alternative_box();
    else if(check=="feet") alternative_feet();
}
