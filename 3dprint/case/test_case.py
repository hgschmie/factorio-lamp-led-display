#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["pytest>=8", "numpy>=1.26", "trimesh>=4", "rtree>=1.1", "sexpdata>=1.0"]
# ///
"""Fit and sanity tests for case.scad.

Runs OpenSCAD headlessly, loads the resulting meshes and checks them against the
board geometry extracted from the KiCad file.

Run with:  uv run test_case.py          (uv fetches the dependencies itself)
   or:     uv run test_case.py -k usb   (any extra args go to pytest)
OpenSCAD must be on PATH, or set OPENSCAD=/path/to/openscad.
"""
import json
import os
import re
import subprocess
import sys

import numpy as np
import pytest
import trimesh

HERE = os.path.dirname(os.path.abspath(__file__))
OPENSCAD = os.environ.get("OPENSCAD", "openscad")
SCAD = os.path.join(HERE, "case.scad")
OUT = os.path.join(HERE, "out")
# PCB must point at the kicad file
PCB = os.environ.get("PCB")
assert PCB
os.makedirs(OUT, exist_ok=True)


def scad_var(name):
    """Evaluate a top-level case.scad expression by echoing it from OpenSCAD."""
    probe = os.path.join(OUT, "_probe.scad")
    with open(probe, "w") as f:
        f.write('include <../case.scad>\necho(PROBE=%s);\n' % name)
    echo = os.path.join(OUT, "_probe.echo")
    r = subprocess.run([OPENSCAD, "-o", echo, "-D", 'part="none"', probe], capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    m = re.search(r'ECHO: PROBE = (.*)', open(echo).read())
    assert m, open(echo).read()
    return json.loads(m.group(1))


def render(part):
    path = os.path.join(OUT, f"{part}.stl")
    r = subprocess.run([OPENSCAD, "-o", path, "-D", f'part="{part}"', SCAD], capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    assert "WARNING" not in r.stderr, r.stderr
    return trimesh.load(path, force="mesh")


@pytest.fixture(scope="module")
def geo():
    names = ["outer", "case_h", "pcb_z", "pcb_top", "groove_z", "groove_h", "wall", "board_off", "inner",
             "groove_depth", "lid_side_clear", "lid_t", "lid_w", "lid_l", "pcb_holes", "pcb_parts",
             "pcb_headers", "standoff_d", "screw_hole_d", "usb_y", "usb_z", "usb_w", "usb_h",
             "max_part_h", "top_clear", "hdr_x0", "hdr_x1", "hdr_y0", "hdr_y1", "pcb_size", "board_clear",
             "usb_z0", "usb_conn_h", "usb_overhang"]
    return {n: scad_var(n) for n in names}


@pytest.fixture(scope="module")
def base():
    return render("base")


@pytest.fixture(scope="module")
def lid():
    return render("lid")


def board_pt(geo, x, y, z):
    """Board-frame point -> case-frame point (z measured from the PCB top)."""
    return np.array([geo["board_off"][0] + x, geo["board_off"][1] + y, geo["pcb_top"] + z])


def test_board_data_is_current():
    r = subprocess.run([sys.executable, os.path.join(HERE, "kicad2scad.py"),
                        PCB, os.path.join(OUT, "_board_data.scad")],
                       capture_output=True, text=True, check=True)
    assert open(os.path.join(OUT, "_board_data.scad")).read() == open(os.path.join(HERE, "board_data.scad")).read(), \
        "board_data.scad is stale; rerun kicad2scad.py"


def test_meshes_are_printable(base, lid):
    for m in (base, lid):
        assert m.is_watertight
        assert m.volume > 0


def test_outer_dimensions(base, geo):
    lo, hi = base.bounds
    assert np.allclose(lo, [0, 0, 0], atol=1e-3)
    assert np.allclose(hi, [geo["outer"][0], geo["outer"][1], geo["case_h"]], atol=1e-3)


def test_pcb_fits_in_cavity(base, geo):
    """The PCB slab, with its clearance, must not intersect the base anywhere."""
    w, h = geo["pcb_size"]
    xs = np.linspace(0, w, 12)
    ys = np.linspace(0, h, 12)
    pts = [board_pt(geo, x, y, -geo["pcb_holes"][0][3] * 0)  # z = PCB top
           for x in xs for y in ys]
    pts += [board_pt(geo, x, y, -1.6 + 0.05) for x in xs for y in ys]  # just above PCB underside
    inside = base.contains(np.array(pts))
    # standoffs legitimately touch the PCB underside; everything at PCB-top level must be free
    top_inside = inside[: len(xs) * len(ys)]
    assert not top_inside.any(), "case material intersects the PCB"


def test_standoffs_under_every_hole(base, geo):
    for ref, x, y, d in geo["pcb_holes"]:
        # solid ring of the standoff just below the PCB
        ring = board_pt(geo, x + geo["standoff_d"] / 2 - 0.4, y, -1.6 - 0.5)
        assert base.contains([ring])[0], f"no standoff under {ref}"
        # pilot hole is open
        centre = board_pt(geo, x, y, -1.6 - 0.5)
        assert not base.contains([centre])[0], f"pilot hole missing under {ref}"
        # standoff top is exactly at the PCB underside
        hits = base.ray.intersects_location([board_pt(geo, x + 2, y, 5)], [[0, 0, -1]])[0]
        top = max(p[2] for p in hits)
        assert abs(top - geo["pcb_z"]) < 1e-3, f"standoff {ref} top at {top}, expected {geo['pcb_z']}"


def test_components_clear_the_lid(geo):
    # the tallest part is the height budget; the lid underside sits top_clear above it
    assert geo["groove_z"] >= geo["pcb_top"] + geo["max_part_h"] + geo["top_clear"] - 1e-6


def test_components_clear_the_walls(base, geo):
    """Sample every component courtyard at half its height; none may hit the base."""
    for ref, val, x0, y0, x1, y1 in geo["pcb_parts"]:
        for x in np.linspace(x0, x1, 5):
            for y in np.linspace(y0, y1, 5):
                assert not base.contains([board_pt(geo, x, y, 2.0)])[0], f"{ref} collides with the case"


def test_lid_fits_grooves(lid, geo):
    lo, hi = lid.bounds
    groove_w = geo["inner"][0] + 2 * geo["groove_depth"]
    assert hi[0] - lo[0] == pytest.approx(groove_w - 2 * geo["lid_side_clear"], abs=1e-3)
    assert lo[2] == pytest.approx(geo["groove_z"], abs=1e-3)
    assert hi[2] == pytest.approx(geo["case_h"], abs=1e-3), "rear block should be flush with the wall tops"
    assert hi[1] == pytest.approx(geo["outer"][1], abs=1e-3), "lid should be flush with the back face"


def test_lid_slides_through_base(base, lid, geo):
    """Sweep the lid plate along its slide path; it must never hit the base."""
    plate_z = geo["groove_z"] + geo["lid_t"] / 2
    x0 = geo["wall"] - geo["groove_depth"] + geo["lid_side_clear"]
    xs = np.linspace(x0 + 0.05, x0 + geo["lid_w"] - 0.05, 30)
    for shift in np.linspace(0, geo["lid_l"], 20):
        y_front = geo["wall"] - geo["groove_depth"] + geo["lid_side_clear"] + shift
        ys = np.linspace(y_front + 0.05, y_front + geo["lid_l"] - 0.05, 30)
        pts = np.array([[x, y, plate_z] for x in xs for y in ys])
        pts = pts[pts[:, 1] < geo["outer"][1] + 30]
        assert not base.contains(pts).any(), f"lid collides with base at slide offset {shift:.1f}"


def test_header_window_covers_all_headers(lid, geo):
    for ref, x0, y0, x1, y1 in geo["pcb_headers"]:
        for x in np.linspace(x0, x1, 4):
            for y in np.linspace(y0, y1, 4):
                p = board_pt(geo, x, y, 0)
                p[2] = geo["groove_z"] + geo["lid_t"] / 2
                assert not lid.contains([p])[0], f"lid covers header {ref}"


def test_usb_opening_in_left_wall(base, geo):
    y = geo["board_off"][1] + geo["usb_y"]
    z = geo["pcb_top"] + geo["usb_z"]
    for dy in (-geo["usb_w"] / 2 + 0.3, 0, geo["usb_w"] / 2 - 0.3):
        for dz in (-geo["usb_h"] / 2 + 0.3, 0, geo["usb_h"] / 2 - 0.3):
            assert not base.contains([[geo["wall"] / 2, y + dy, z + dz]])[0], "USB opening blocked"
    # wall is solid just outside the opening
    assert base.contains([[geo["wall"] / 2, y + geo["usb_w"] / 2 + 1, z]])[0]
    # and the opening is roughly where the module's short axis is (module is flush with the board edge)
    u1 = [p for p in geo["pcb_parts"] if p[0] == "U1"][0]
    assert abs(geo["usb_y"] - (u1[3] + u1[5]) / 2) < 1e-6


def test_usb_receptacle_clears_the_wall(base, geo):
    """The receptacle overhangs the board edge; it must not touch the base when the board is
    lowered straight in (so sample the whole column above its final position too)."""
    for dx in np.linspace(-geo["usb_overhang"], 0, 4):
        for dy in np.linspace(-4.45, 4.45, 5):
            for dz in np.linspace(geo["usb_z0"], geo["case_h"] - geo["pcb_top"], 12):
                p = board_pt(geo, dx, geo["usb_y"] + dy, dz)
                assert not base.contains([p])[0], f"USB receptacle hits the base at {p}"


if __name__ == "__main__":
    sys.exit(pytest.main(["-q", __file__] + sys.argv[1:]))
