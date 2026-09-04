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
    names = ["outer", "case_h", "pcb_z", "pcb_top", "groove_z", "wall", "corner_r", "board_off", "inner",
             "lid_t", "lid_tip", "lid_clear", "lid_end_clear", "groove_angle", "v_run", "v_rise", "v_shift",
             "groove_depth", "mouth_lo", "mouth_hi", "lid_w", "lid_l", "pcb_holes", "pcb_parts",
             "pcb_headers", "standoff_d", "screw_hole_d", "usb_y", "usb_z", "usb_w", "usb_h",
             "max_part_h", "top_clear", "hdr_x0", "hdr_x1", "hdr_y0", "hdr_y1", "pcb_size", "board_clear",
             "hole_comp", "screw_hole_model", "screw_test_d", "floor_t", "standoff_h",
             "usb_z0", "usb_conn_h", "usb_overhang"]
    return {n: scad_var(n) for n in names}


@pytest.fixture(scope="module")
def base():
    return render("base")


@pytest.fixture(scope="module")
def lid():
    return render("lid")


@pytest.fixture(scope="module")
def coupon():
    return render("screw_test")


def hole_is(mesh, x, y, z, d, name):
    """There is an open hole of diameter d at (x, y, z), with solid material just outside it."""
    r = d / 2
    for ang in (0, 90, 180, 270):
        dx, dy = np.cos(np.radians(ang)), np.sin(np.radians(ang))
        assert not mesh.contains([[x + dx * (r - 0.05), y + dy * (r - 0.05), z]])[0], \
            f"{name}: hole is narrower than {d} mm"
        assert mesh.contains([[x + dx * (r + 0.15), y + dy * (r + 0.15), z]])[0], \
            f"{name}: hole is wider than {d} mm"


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
    # the lid rests on its lower V flanks, up to v_shift below the nominal underside; still above the tallest part
    assert geo["groove_z"] - geo["v_shift"] >= geo["pcb_top"] + geo["max_part_h"] - 1e-6


def test_components_clear_the_walls(base, geo):
    """Sample every component courtyard at half its height; none may hit the base."""
    for ref, val, x0, y0, x1, y1 in geo["pcb_parts"]:
        for x in np.linspace(x0, x1, 5):
            for y in np.linspace(y0, y1, 5):
                assert not base.contains([board_pt(geo, x, y, 2.0)])[0], f"{ref} collides with the case"


def test_lid_dimensions(lid, geo):
    outer, wall = geo["outer"], geo["wall"]
    lo, hi = lid.bounds
    assert np.allclose([lo[0], hi[0]], [0, outer[0]], atol=1e-3), "rear bar should span the full outer width"
    assert lo[2] == pytest.approx(geo["groove_z"], abs=1e-3)
    assert hi[2] == pytest.approx(geo["case_h"], abs=1e-3), "rear bar should be flush with the wall tops"
    assert hi[1] == pytest.approx(outer[1], abs=1e-3), "lid should be flush with the back face"
    # cross-section through the middle: V tips reach v_run past the inner wall faces, plate is lid_t thick
    segs = trimesh.intersections.mesh_plane(lid, plane_normal=[0, 1, 0], plane_origin=[0, outer[1] / 2, 0])
    slo, shi = segs.reshape(-1, 3).min(axis=0), segs.reshape(-1, 3).max(axis=0)
    assert slo[0] == pytest.approx(wall - geo["v_run"], abs=1e-3)
    assert shi[0] == pytest.approx(outer[0] - wall + geo["v_run"], abs=1e-3)
    assert slo[2] == pytest.approx(geo["groove_z"], abs=1e-3)
    assert shi[2] == pytest.approx(geo["groove_z"] + geo["lid_t"], abs=1e-3)
    # the bar fills the back corners that the base leaves open above the lid
    y, z = outer[1] - wall / 2, geo["case_h"] - 0.5
    assert lid.contains([[1.0, y, z], [outer[0] - 1.0, y, z]]).all(), "rear bar does not fill the back corners"


def lid_cloud(lid, geo):
    """Grid points inside the lid: dense across the V edges (x, z), a few slices along the slide (y)."""
    lo, hi = lid.bounds
    xs = np.arange(lo[0] + 0.05, hi[0], 0.25)
    zs = np.arange(lo[2] + 0.05, hi[2], 0.1)
    back = geo["outer"][1] - geo["wall"]
    ys = [lo[1] + 0.05, lo[1] + 0.5, geo["outer"][1] / 2, back - 0.05, back + 0.5]
    grid = np.array([[x, y, z] for y in ys for x in xs for z in zs])
    pts = grid[lid.contains(grid)]
    assert len(pts) > 1000
    return pts


def test_lid_slides_through_base(base, lid, geo):
    """Push the whole lid (plate, V edges, bar) along its slide path; it must never hit the base."""
    pts = lid_cloud(lid, geo)
    for shift in [0, 0.3, 1, 3, 10, geo["outer"][1] / 2]:
        hit = base.contains(pts + [0, shift, 0])
        assert not hit.any(), f"lid collides with base at slide offset {shift}: {pts[hit][:3]}"


def test_lid_is_retained_by_grooves(base, lid, geo):
    """Wall material sits right above the lid's upper V flank (within the clearance): the lid cannot lift out."""
    outer, wall = geo["outer"], geo["wall"]
    a = np.radians(geo["groove_angle"])
    u = geo["v_run"] / 2                                   # half-way along the chamfer
    z = geo["groove_z"] + geo["lid_t"] - u * np.tan(a)     # lid's upper flank there
    side_gap = geo["v_shift"]
    front_gap = geo["v_shift"] + geo["lid_end_clear"] * np.tan(a)
    probes = [(wall - u, outer[1] / 2, side_gap), (outer[0] - wall + u, outer[1] / 2, side_gap),
              (outer[0] / 2, wall - u + geo["lid_end_clear"], front_gap)]
    for x, y, gap in probes:
        assert lid.contains([[x, y, z - 0.05]])[0], f"expected lid material at {(x, y)}"
        assert not base.contains([[x, y, z + 0.05]])[0], f"no clearance above the lid flank at {(x, y)}"
        assert base.contains([[x, y, z + gap + 0.1]])[0], f"nothing holds the lid down at {(x, y)}"


def test_back_face_is_closed(base, lid, geo):
    """With the lid in, the back of the box is solid from the floor to the wall tops, corners included."""
    outer = geo["outer"]
    y = outer[1] - geo["wall"] / 2
    pts = np.array([[x, y, z] for x in (1.0, outer[0] / 2, outer[0] - 1.0)
                    for z in np.arange(0.5, geo["case_h"] - 0.4, 0.25)])
    covered = base.contains(pts) | lid.contains(pts)
    assert covered.all(), f"gap in the back face at {pts[~covered][:3]}"


def test_no_support_needed(base, lid, geo):
    """Every downward-facing face is on the bed, the USB bridge, or inclined at most 45 deg from vertical."""
    limit = -np.sin(np.radians(45)) - 1e-3
    y = geo["board_off"][1] + geo["usb_y"]
    z = geo["pcb_top"] + geo["usb_z"]
    usb = ([-1, y - geo["usb_w"] / 2 - 0.1, z - geo["usb_h"] / 2 - 0.1], [geo["wall"] + 1, y + geo["usb_w"] / 2 + 0.1, z + geo["usb_h"] / 2 + 0.1])

    def check(mesh, bed_z, name, allowed=()):
        nz = mesh.face_normals[:, 2]
        ctr = mesh.triangles_center
        down = (nz < -0.01) & (np.abs(ctr[:, 2] - bed_z) > 1e-3)
        for box in allowed:
            down &= ~np.all((ctr >= box[0]) & (ctr <= box[1]), axis=1)
        bad = down & (nz < limit)
        assert not bad.any(), f"{name}: {bad.sum()} faces overhang more than 45 deg, e.g. at {ctr[bad][:3]}"

    check(base, 0, "base", [usb])
    check(lid, geo["groove_z"], "lid")


def test_pilot_holes_are_compensated(base, geo):
    """The model cuts screw_hole_d + hole_comp, so the printed hole comes out at screw_hole_d."""
    assert geo["hole_comp"] > 0, "no FDM hole compensation: printed pilots come out undersized"
    assert geo["screw_hole_model"] == pytest.approx(geo["screw_hole_d"] + geo["hole_comp"], abs=1e-9)
    z = geo["pcb_z"] - geo["standoff_h"] / 2          # half-way down the boss
    for ref, x, y, d in geo["pcb_holes"]:
        p = board_pt(geo, x, y, 0)
        hole_is(base, p[0], p[1], z, geo["screw_hole_model"], f"pilot {ref}")


def test_standoff_wall_survives_the_screw(geo):
    """Enough plastic around the pilot for a thread-forming M3 not to split the boss."""
    wall = (geo["standoff_d"] - geo["screw_hole_model"]) / 2
    assert wall >= 1.2, f"standoff wall is only {wall:.2f} mm"


def test_pilot_holes_do_not_break_through_the_floor(base, geo):
    """A blind hole: the case bottom stays closed so the box does not leak light or dust."""
    for ref, x, y, d in geo["pcb_holes"]:
        p = board_pt(geo, x, y, 0)
        assert base.contains([[p[0], p[1], 0.5]])[0], f"pilot {ref} breaks through the floor"


def test_screw_test_coupon(coupon, geo):
    """The calibration coupon reproduces the real boss at each labelled diameter."""
    assert coupon.is_watertight
    targets = geo["screw_test_d"]
    assert len(targets) >= 3, "a calibration coupon needs a few sizes to choose from"
    assert geo["screw_hole_d"] in targets, "screw_hole_d should be one of the coupon's labelled sizes"
    pitch = geo["standoff_d"] + 5.5
    y = (len(targets) * pitch, geo["standoff_d"] + 8)[1] - geo["standoff_d"] / 2 - 1.5
    lo, hi = coupon.bounds
    assert hi[2] == pytest.approx(geo["floor_t"] + geo["standoff_h"], abs=1e-3), "boss height must match the case"
    for i, d in enumerate(targets):
        x = pitch * (i + 0.5)
        z = geo["floor_t"] + geo["standoff_h"] / 2
        hole_is(coupon, x, y, z, d + geo["hole_comp"], f"coupon boss {d}")
        assert coupon.contains([[x, y, 0.5]])[0], f"coupon boss {d} is not blind"


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
