use <../lamp-base-plate-five.scad>
$fn=64;
check="box";
intersection() {
    five_plate();
    if(check=="box") five_box();
    else if(check=="feet") five_feet();
    else if(check=="lamps") five_lamps();
}
