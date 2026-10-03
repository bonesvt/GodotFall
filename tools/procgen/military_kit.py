"""The militia's bases and outposts: the forward bases of the crude soldiers
Eco fights, set out like a Titanfall forward operating base but in chunky
PS2-era shapes. Olive drab painted steel, corrugated sheds, HESCO and T-wall
lines, camo netting, tarmac pads, sandbags, red beacons and stencilled numbers.

Run through tools/procgen/build_kits.py (military), which execs this file in
the namespace of tools/procgen/build_props.py: begin, sbox, tbox, solid,
column, hook_block, top, footprint, part, export, cyl, ring, blob,
tapered_tube, FP["cone"], FP["face2"] are all globals here.

  centrepiece: mil_hangar (an arched hangar to grapple onto and run along)
  buildings: mil_barracks, mil_command, mil_ammo_bunker, mil_radar, mil_gate
  climbs and landmarks: mil_guard_tower, mil_comms_tower, mil_helipad
  wallrun walls: mil_hesco_wall, mil_t_wall
  props: mil_fuel_bladder, mil_apc, mil_aa_gun, mil_razor_fence,
    mil_camo_shelter, mil_searchlight, mil_generator, mil_footlockers,
    mil_sandbag_wall, mil_artillery, mil_tent_large

Same conventions as build_props.py: Z up, fronts facing -Y, origins on the
ground at the footprint centre, objects named "<part>__<material>", orange
("anchor") for grapple hooks (and a few thin hazard strips only), blue
("wallrun") trim on faces made to run along, "<part>_<colour>__neon" for the
few lights that glow (red beacons, green and amber panel lamps).

Seeded, so re-running gives the same meshes.
"""
import math
import random

import bmesh
from mathutils import Matrix, Vector


# =============================================================================
# Helpers
# =============================================================================

def _flight(bm, a, b, width, treads=None, thick=0.25):
    """A straight flight of stairs from `a` (bottom) to `b` (top), both on the
    walking surface: a tilted slab collider (like blockhouse's) with visual
    treads on it, if `treads` is given."""
    a, b = Vector(a), Vector(b)
    d = b - a
    horiz = math.hypot(d.x, d.y)
    yaw = math.degrees(math.atan2(-d.x, d.y))
    tilt = math.degrees(math.atan2(d.z, horiz))
    c = (a + b) * 0.5
    c.z -= thick * 0.5 / math.cos(math.radians(tilt))
    sbox(bm, tuple(c), (width, math.hypot(horiz, d.z), thick), yaw=yaw, tilt=tilt)
    if treads is not None:
        n = max(2, int(round(d.z / 0.22)))
        for i in range(n):
            p = a + d * ((i + 0.5) / n)
            tbox(treads, tuple(p), (width - 0.08, horiz / n + 0.02, d.z / n), yaw=yaw)


def _rail(bm, a, b, h=1.0, posts=None, r=0.03):
    """A handrail: posts from `a` to `b` (on the deck), top and mid rails."""
    a, b = Vector(a), Vector(b)
    n = posts or max(2, int((b - a).length / 1.4) + 1)
    for k in range(n):
        p = a.lerp(b, k / (n - 1))
        cyl(bm, p, p + Vector((0, 0, h)), r * 1.3, sides=4)
    for f in (1.0, 0.5):
        up = Vector((0, 0, h * f))
        cyl(bm, a + up, b + up, r, sides=4)


# Seven-segment stencil glyphs: a top, b/c right, d bottom, e/f left, g middle.
_SEG = {
    "0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc",
    "5": "afgcd", "6": "afgedc", "7": "abc", "8": "abcdefg", "9": "abcdfg",
    "A": "abcefg", "C": "adef", "E": "adefg", "F": "aefg", "H": "bcefg",
    "L": "def", "P": "abefg", "U": "bcdef", "-": "g",
}
_SEGPOS = {
    "a": (0.0, 0.43, True), "g": (0.0, 0.0, True), "d": (0.0, -0.43, True),
    "b": (0.42, 0.215, False), "c": (0.42, -0.215, False),
    "e": (-0.42, -0.215, False), "f": (-0.42, 0.215, False),
}


def _stencil(bm, text, center, normal, h, depth=0.03):
    """Stencilled characters `h` high, centred on `center` (just proud of a
    face) and read from the side `normal` (x, y) points to. The segments stop
    short of each other, like a real stencil's bridges."""
    nx, ny = normal
    ux, uy = -ny, nx
    yaw = math.degrees(math.atan2(uy, ux))
    w, t = h * 0.56, h * 0.15
    pitch = w * 1.45
    c = Vector(center)
    n = len(text)
    for i, ch in enumerate(text):
        cu = (i - (n - 1) * 0.5) * pitch
        for s in _SEG.get(ch, ""):
            du, dv, horiz = _SEGPOS[s]
            off = cu + du * w
            p = c + Vector((ux * off, uy * off, dv * h))
            size = (w * 0.74, depth, t) if horiz else (t, depth, h * 0.40)
            tbox(bm, tuple(p), size, yaw=yaw)


def _wheel(tyre, hub, c, r, w, axis="y", sides=10):
    """A tyre with a hub, its axle along Y (or X)."""
    x, y, z = c
    if axis == "y":
        a, b = (x, y - w / 2, z), (x, y + w / 2, z)
        ha, hb = (x, y - w / 2 - 0.03, z), (x, y + w / 2 + 0.03, z)
    else:
        a, b = (x - w / 2, y, z), (x + w / 2, y, z)
        ha, hb = (x - w / 2 - 0.03, y, z), (x + w / 2 + 0.03, y, z)
    tapered_tube(tyre, [a, b], [r, r], sides=sides)
    tapered_tube(hub, [ha, hb], [r * 0.5, r * 0.5], sides=6)


def _bag(bm, rng, c, yaw, size=(0.28, 0.18, 0.15), seed=0):
    """One sandbag, long along its own X, turned `yaw` degrees."""
    tmp = bmesh.new()
    blob(tmp, (0, 0, 0), size, rng, subdiv=1, wobble=0.08, seed=seed)
    bmesh.ops.rotate(tmp, verts=list(tmp.verts), cent=Vector(), matrix=Matrix.Rotation(math.radians(yaw), 3, "Z"))
    bmesh.ops.translate(tmp, vec=Vector(c), verts=list(tmp.verts))
    _merge(bm, tmp)


def _loft(bm, ring0, ring1):
    """A closed prism between two matching rings of points (e.g. a profile
    extruded along an axis), its normals put right."""
    tmp = bmesh.new()
    A = [tmp.verts.new(Vector(p)) for p in ring0]
    B = [tmp.verts.new(Vector(p)) for p in ring1]
    n = len(A)
    for k in range(n):
        tmp.faces.new((A[k], A[(k + 1) % n], B[(k + 1) % n], B[k]))
    tmp.faces.new(list(reversed(A)))
    tmp.faces.new(B)
    bmesh.ops.recalc_face_normals(tmp, faces=list(tmp.faces))
    _merge(bm, tmp)


def _extrude_x(bm, prof_yz, x0, x1):
    _loft(bm, [(x0, y, z) for y, z in prof_yz], [(x1, y, z) for y, z in prof_yz])


def _extrude_y(bm, prof_xz, y0, y1):
    _loft(bm, [(x, y0, z) for x, z in prof_xz], [(x, y1, z) for x, z in prof_xz])


def _ridge(bm, a, b, wb, wt, h, z0=0.0):
    """An earth berm along the ground from `a` to `b` (x, y): a trapezoid
    section `wb` wide at the foot, `wt` on top, `h` high."""
    a, b = Vector((a[0], a[1], z0)), Vector((b[0], b[1], z0))
    d = (b - a).normalized()
    n = Vector((-d.y, d.x, 0))
    up = Vector((0, 0, h))
    prof = lambda p: [p - n * wb / 2, p + n * wb / 2, p + n * wt / 2 + up, p - n * wt / 2 + up]
    _loft(bm, prof(a), prof(b))


def _sheet(bm, grid, double=False):
    """A surface through a grid of points (rows along Y, columns along X),
    facing up; both sides if `double`."""
    for j in range(len(grid) - 1):
        for i in range(len(grid[0]) - 1):
            q = [grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]]
            bm.faces.new([bm.verts.new(p) for p in q])
            if double:
                bm.faces.new([bm.verts.new(p) for p in reversed(q)])


def _dish(bm, center, radius, depth, direction, sides=12):
    """A parabolic-ish dish (a shallow cone) opening toward `direction`."""
    tmp = bmesh.new()
    FP["cone"](tmp, (0, 0, 0), radius, -depth, sides=sides)
    rot = Vector((0, 0, 1)).rotation_difference(Vector(direction).normalized()).to_matrix()
    bmesh.ops.rotate(tmp, verts=list(tmp.verts), cent=Vector(), matrix=rot)
    bmesh.ops.translate(tmp, vec=Vector(center), verts=list(tmp.verts))
    _merge(bm, tmp)


def _ring_x(bm, center, radius, tube, sides=8, yaw=0.0):
    """A ring round the X axis (a razor-wire loop), turned `yaw` degrees."""
    c = Vector(center)
    rot = Matrix.Rotation(math.radians(yaw), 3, "Z")
    pts = [c + rot @ Vector((0, math.cos(2 * math.pi * k / sides) * radius, math.sin(2 * math.pi * k / sides) * radius)) for k in range(sides)]
    for k in range(sides):
        cyl(bm, pts[k], pts[(k + 1) % sides], tube, sides=3)


def _xz_slab(bm, p0, p1, length_y, thick, cy=0.0, collide=False):
    """A plank running along Y whose cross-section goes from p0 to p1 (x, z):
    a roof panel or glacis plate sloping in the XZ plane."""
    cx, cz = (p0[0] + p1[0]) * 0.5, (p0[1] + p1[1]) * 0.5
    w = math.hypot(p1[0] - p0[0], p1[1] - p0[1])
    ang = math.degrees(math.atan2(p1[1] - p0[1], p1[0] - p0[0]))
    if ang > 90:
        ang -= 180
    elif ang < -90:
        ang += 180
    (sbox if collide else tbox)(bm, (cx, cy, cz), (length_y, w, thick), yaw=-90, tilt=ang)


def _beacon(bm, c, s=0.18):
    """A small red warning lamp (part of a "beacon_red" neon group)."""
    tbox(bm, c, (s, s, s * 1.2), bevel=s * 0.15)


# =============================================================================
# Centrepiece
# =============================================================================

def mil_hangar(name):
    """A big arched corrugated hangar, 18 W x 14 D, eaves at 2.5, ridge at
    9.0. Open front (a 12 x 6.6 opening, its doors slid aside onto a track),
    a gantry crane and a mezzanine catwalk inside (stairs up). The roof's
    arch is colliders all the way over: run up and along it. A flat ridge
    catwalk on top (top()) with a hook at each end of the ridge, 10.1 m up."""
    begin(name)
    A, B, Z0, D = 9.0, 6.5, 2.5, 14.0  # half span, arch rise, eave height, depth
    hy = D * 0.5
    N = 11  # odd, so the middle panel is flat: the ridge walk

    def arc(a):
        return (A * math.cos(a), Z0 + B * math.sin(a))

    def half_width(z):
        return A if z <= Z0 else A * math.sqrt(max(0.0, 1.0 - ((z - Z0) / B) ** 2))

    shell = new_bm()
    ribs = new_bm()
    for s in (-1, 1):
        sbox(shell, (s * A, 0, Z0 * 0.5), (0.3, D + 0.2, Z0))
    for k in range(N):
        p0, p1 = arc(math.pi * k / N), arc(math.pi * (k + 1) / N)
        w = math.hypot(p1[0] - p0[0], p1[1] - p0[1])
        _xz_slab(shell, p0, p1, D + 0.2, 0.16)
        # Collider a touch thicker so the visual skin sits on it.
        cx, cz = (p0[0] + p1[0]) * 0.5, (p0[1] + p1[1]) * 0.5
        ux, uz = (p1[0] - p0[0]) / w, (p1[1] - p0[1]) / w
        nx, nz = uz, -ux  # outward
        ang = math.degrees(math.atan2(p1[1] - p0[1], p1[0] - p0[0]))
        ang = ang - 180 if ang > 90 else (ang + 180 if ang < -90 else ang)
        solid((cx - nx * 0.02, 0, cz - nz * 0.02), (D + 0.2, w + 0.1, 0.2), yaw=-90, tilt=ang)
        # Steel arch ribs over the skin every 3.5 m.
        for y in (-hy + 0.15, -3.5, 0.0, 3.5, hy - 0.15):
            tbox(ribs, (cx + nx * 0.12, y, cz + nz * 0.12), (0.28, w + 0.12, 0.1), yaw=-90, tilt=ang)
    for s in (-1, 1):
        for y in (-hy + 0.15, -3.5, 0.0, 3.5, hy - 0.15):
            tbox(ribs, (s * (A + 0.2), y, Z0 * 0.5), (0.1, 0.28, Z0))
        tbox(ribs, (s * (A + 0.2), 0, 0.15), (0.2, D + 0.3, 0.3))  # sill
    part(shell, "arch", "corrugated")

    # End walls: the back closed, the front an arch round the door opening.
    ends = new_bm()
    angs = [math.pi * k / N for k in range(N + 1)]
    back = [(A, hy, 0.0)] + [(arc(a)[0], hy, arc(a)[1]) for a in angs] + [(-A, hy, 0.0)]
    _extrude_y(ends, [(p[0], p[2]) for p in back], hy - 0.12, hy)
    OW, OH = 6.0, 6.6  # door opening half width, height
    ac = math.atan2((OH - Z0) * A, B * OW)
    fangs = sorted(angs + [ac, math.pi - ac])

    def inner(a):
        dx, dz = A * math.cos(a), B * math.sin(a)
        t = min(OW / abs(dx) if abs(dx) > 1e-6 else 1e9, (OH - Z0) / dz if dz > 1e-6 else 1e9)
        return (dx * t, Z0 + dz * t)

    y = -hy
    for a0, a1 in zip(fangs, fangs[1:]):
        o0, o1, i0, i1 = arc(a0), arc(a1), inner(a0), inner(a1)
        _extrude_y(ends, [o0, o1, i1, i0], y, y + 0.12)
    for s in (-1, 1):
        _extrude_y(ends, [(s * A, 0), (s * A, Z0), (s * OW, Z0), (s * OW, 0)], y, y + 0.12)
    part(ends, "ends", "corrugated")
    # End wall colliders, in bands under the arch.
    solid((0, hy, Z0 * 0.5), (2 * A, 0.3, Z0))
    for z0, z1 in ((Z0, 5.0), (5.0, 7.5), (7.5, 8.9)):
        solid((0, hy, (z0 + z1) * 0.5), (2 * half_width(z1), 0.3, z1 - z0))
    for s in (-1, 1):
        for z0, z1 in ((0.0, Z0), (Z0, 4.5), (4.5, OH)):
            x1 = half_width(z1)
            solid((s * (OW + x1) * 0.5, -hy, (z0 + z1) * 0.5), (x1 - OW, 0.3, z1 - z0))
    for z0, z1 in ((OH, 7.6), (7.6, 8.6)):
        solid((0, -hy, (z0 + z1) * 0.5), (2 * half_width(z1), 0.3, z1 - z0))

    # Door track across the front, the doors slid aside onto its ends.
    steel = new_bm()
    tbox(steel, (0, -hy - 0.45, 6.75), (2 * A + 1.4, 0.3, 0.3))
    for s in (-1, 1):
        tbox(steel, (s * (A + 0.55), -hy - 0.45, 3.45), (0.3, 0.3, 6.9))
        column((s * (A + 0.55), -hy - 0.45, 0), 0.2, 6.9)
    olive = new_bm()
    for s in (-1, 1):
        for k, (x, dy) in enumerate(((7.55, -0.3), (7.85, -0.6))):
            tbox(olive, (s * x, -hy + dy, 3.3), (3.1, 0.14, 6.45))
            for z in (1.2, 2.6, 4.0, 5.4):
                tbox(steel, (s * x, -hy + dy - 0.08, z), (3.0, 0.04, 0.12))
            tbox(steel, (s * x, -hy + dy, 6.6), (0.5, 0.2, 0.2))  # trolley
        solid((s * 7.75, -hy - 0.45, 3.25), (3.5, 0.6, 6.5))

    # Inside: a gantry crane on two runways, a catwalk along the back.
    for x in (-6.3, 6.3):
        for yy in (-6.0, -0.5, 4.5):
            tbox(steel, (x, yy, 2.75), (0.35, 0.35, 5.5))
            column((x, yy, 0), 0.2, 5.5)
        sbox(steel, (x, -0.75, 5.7), (0.4, 11.6, 0.4))
    sbox(steel, (0, -2.0, 6.15), (13.2, 0.55, 0.5))
    for s in (-1, 1):
        tbox(steel, (s * 6.3, -2.0, 6.05), (0.6, 1.2, 0.35))
    tbox(steel, (1.8, -2.0, 5.75), (0.9, 0.8, 0.4))  # trolley
    for dx in (-0.15, 0.15):
        cyl(steel, (1.8 + dx, -2.0, 5.55), (1.8 + dx, -2.0, 3.1), 0.025, sides=3)
    tbox(steel, (1.8, -2.0, 2.95), (0.5, 0.35, 0.3))
    # Mezzanine catwalk at 3.2 along the back wall, stairs up from the right.
    deck = new_bm()
    sbox(deck, (-2.7, 5.8, 3.1), (10.8, 2.0, 0.2))
    for x in (-7.9, -4.5, -1.0, 2.6):
        tbox(steel, (x, 4.9, 1.5), (0.18, 0.18, 3.0))
        column((x, 4.9, 0), 0.12, 3.0)
    _rail(steel, (-8.1, 4.85, 3.2), (2.6, 4.85, 3.2), posts=8)
    _flight(deck, (8.0, 5.8, 0.0), (2.95, 5.8, 3.2), 1.2, treads=steel)
    _rail(steel, (8.0, 5.15, 0.0), (3.0, 5.15, 3.2), posts=4)
    # Ridge catwalk on top of the arch, between the two hook posts.
    ztop = arc(math.pi * 5 / N)[1] + 0.08
    sbox(deck, (0, 0, ztop + 0.04), (1.8, D - 0.6, 0.08))
    for s in (-1, 1):
        tbox(steel, (s * 0.95, 0, ztop + 0.12), (0.06, D - 0.6, 0.12))
    part(deck, "decks", "gunmetal")
    hooks = new_bm()
    zh = ztop + 1.1
    for s in (-1, 1):
        tbox(steel, (0, s * (hy - 0.4), ztop + 0.3), (0.25, 0.25, 0.6))
        hook_block(steel, hooks, (0, s * (hy - 0.4), zh), 1.1)
    part(hooks, "hooks", "anchor")
    # Floor, crates, hanging lamps.
    pad = new_bm()
    sbox(pad, (0, 0, 0.04), (2 * A - 0.3, D, 0.08))
    part(pad, "floor", "tarmac")
    crates = olive
    sbox(crates, (-5.2, -2.8, 0.6), (1.4, 1.4, 1.2))
    sbox(crates, (-5.0, -1.2, 0.5), (1.2, 1.2, 1.0))
    tbox(crates, (-5.2, -2.7, 1.5), (1.0, 1.0, 0.6))
    solid((-5.2, -2.7, 1.5), (1.0, 1.0, 0.6))
    part(steel, "frame", "gunmetal")
    part(olive, "doors", "olive")
    part(ribs, "ribs", "gunmetal")
    lit = new_bm()
    for x in (-3.0, 3.0):
        for yy in (-3.5, 3.0):
            tbox(lit, (x, yy, 7.2), (0.5, 0.5, 0.14))
    part(lit, "lamps", "light")
    wires = new_bm()
    for x in (-3.0, 3.0):
        for yy in (-3.5, 3.0):
            cyl(wires, (x, yy, 7.25), (x, yy, 8.4), 0.02, sides=3)
    part(wires, "wires", "shadow")
    paint = new_bm()
    _stencil(paint, "07", (0, -hy - 0.03, 7.75), (0, -1), 1.2)
    for s in (-1, 1):
        _stencil(paint, "07", (s * (A + 0.04), 0, 1.3), (s, 0), 1.2)
    part(paint, "stencil", "shadow")
    stripe = new_bm()
    tbox(stripe, (0, -hy + 0.25, 0.09), (2 * OW, 0.25, 0.02))  # door threshold line
    part(stripe, "threshold", "anchor")
    red = new_bm()
    for s in (-1, 1):
        _beacon(red, (0.2, s * (hy - 0.4), ztop + 0.45))
        _beacon(red, (s * (A + 0.55), -hy - 0.45, 7.0))
    part(red, "beacon_red", "neon")
    top((0, 0, ztop + 0.08))
    footprint(2 * A + 1.6, D + 1.4)
    export(name)


# =============================================================================
# Buildings
# =============================================================================

def mil_barracks(name):
    """A prefab barracks module, 10 W x 5 D, on concrete blocks: floor at 0.5,
    a flat roof at 3.45. Steps up to the front door, lit windows, an AC unit on
    its +X end, steel stairs up the back to the roof (a top())."""
    begin(name)
    con = new_bm()
    for x in (-4.5, -1.5, 1.5, 4.5):
        for y in (-2.0, 2.0):
            sbox(con, (x, y, 0.25), (0.6, 0.6, 0.5))
    # Front door landing and steps.
    sbox(con, (0, -2.95, 0.25), (1.8, 0.9, 0.5))
    sbox(con, (0, -3.575, 0.165), (1.6, 0.35, 0.33))
    sbox(con, (0, -3.925, 0.085), (1.6, 0.35, 0.17))
    part(con, "blocks", "concrete")
    body = new_bm()
    sbox(body, (0, 0, 1.9), (10.0, 5.0, 2.8))
    sbox(body, (0, 0, 3.375), (10.4, 5.4, 0.15))
    tbox(body, (0, -3.0, 2.85), (1.8, 1.0, 0.08), tilt=-12)  # door awning
    part(body, "body", "olive")
    steel = new_bm()
    for x in (-5.0, -3.75, -2.5, -1.25, 1.25, 2.5, 3.75, 5.0):
        for s in (-1, 1):
            tbox(steel, (x, s * 2.52, 1.9), (0.06, 0.05, 2.8))
    for s in (-1, 1):
        tbox(steel, (0, s * 2.53, 0.55), (10.0, 0.06, 0.1))
        # Low lips round the roof, front and ends only (the stairs land at the back).
        tbox(steel, (0, -2.65, 3.5), (10.4, 0.1, 0.12))
        tbox(steel, (s * 5.15, 0, 3.5), (0.1, 5.4, 0.12))
    # Window frames and shutters.
    for x in (-3.6, -2.0, 2.0, 3.6):
        tbox(steel, (x, -2.54, 2.1), (1.1, 0.06, 0.75))
        tbox(steel, (x, -2.6, 1.68), (1.2, 0.18, 0.06))
    # AC unit on the +X end.
    tbox(steel, (5.3, -1.0, 1.7), (0.6, 1.0, 0.8))
    tbox(steel, (5.3, -1.0, 1.25), (0.5, 0.9, 0.1))
    cyl(steel, (5.0, -1.0, 2.0), (5.0, -1.0, 3.0), 0.08, sides=6)
    # Roof vents and a whip antenna.
    for x in (-2.5, 1.0):
        tbox(steel, (x, 0.6, 3.6), (0.6, 0.6, 0.35))
    cyl(steel, (4.4, 1.8, 3.45), (4.4, 1.8, 6.0), 0.025, sides=4)
    # Stairs up the back: +X to -X, 3.45 m over 7 m, landing onto the roof.
    stairs = new_bm()
    _flight(stairs, (4.0, 3.2, 0.0), (-3.0, 3.2, 3.45), 1.1, treads=steel)
    sbox(stairs, (-3.75, 3.2, 3.35), (1.5, 1.1, 0.2))
    for x in (-4.3, -3.2, 0.5):
        z = 3.45 if x < -3 else 3.45 * (4.0 - x) / 7.0
        tbox(steel, (x, 3.65, z * 0.5), (0.12, 0.12, z))
    _rail(steel, (4.0, 3.72, 0.0), (-3.0, 3.72, 3.45), posts=5)
    _rail(steel, (-3.0, 3.72, 3.45), (-4.45, 3.72, 3.45), posts=2)
    part(stairs, "stairs", "gunmetal")
    part(steel, "trim", "gunmetal")
    dark = new_bm()
    tbox(dark, (0, -2.53, 1.55), (1.0, 0.05, 2.05))
    for x in (-3.6, -2.0, 2.0, 3.6):
        tbox(dark, (x, 2.53, 2.1), (1.0, 0.05, 0.65))
    tapered_tube(dark, [(5.62, -1.0, 1.7), (5.64, -1.0, 1.7)], [0.32, 0.32], sides=10)
    part(dark, "door", "shadow")
    lit = new_bm()
    for x in (-3.6, -2.0, 2.0, 3.6):
        tbox(lit, (x, -2.55, 2.1), (0.95, 0.05, 0.62))
    tbox(lit, (0, -2.6, 2.75), (0.3, 0.12, 0.12))
    part(lit, "windows", "light")
    paint = new_bm()
    _stencil(paint, "12", (-5.04, 0, 2.0), (-1, 0), 1.0)
    _stencil(paint, "12", (1.0, -2.55, 2.9), (0, -1), 0.35)
    part(paint, "stencil", "canvas")
    top((0, 0, 3.45))
    footprint(11.4, 8.4)
    export(name)


def mil_command(name):
    """A two-storey command post, 9 W x 7 D: concrete below, olive steel above
    with a band of lit windows, a flat roof at 6.5. Stairs up the +X side to a
    landing at 3.2, then along the back to the roof. An antenna farm and a
    satellite dish on the roof, and a lattice mast with a hook block at 10.1."""
    begin(name)
    con = new_bm()
    sbox(con, (0, 0, 1.6), (9.0, 7.0, 3.2), bevel=0.05)
    rng = random.Random(41)
    bags = new_bm()
    for s in (-1, 1):
        for k in range(4):
            for row in range(3):
                _bag(bags, rng, (1.5 + s * 1.5 + s * (0.55 * k + (0.27 if row % 2 else 0)) - s * 0.6, -3.75, 0.16 + row * 0.29), 0, seed=k * 7 + row + (s + 1) * 20)
    for s in (-1, 1):
        solid((1.5 + s * 1.9, -3.75, 0.45), (2.2, 0.5, 0.9))
    part(bags, "bags", "canvas")
    part(con, "base", "concrete")
    olive = new_bm()
    sbox(olive, (0, 0, 4.7), (8.6, 6.6, 3.0))
    sbox(olive, (0, 0, 6.35), (9.4, 7.4, 0.3))
    for s in (-1, 1):
        tbox(olive, (0, -3.65, 6.62), (9.4, 0.1, 0.25))
        tbox(olive, (s * 4.65, 0, 6.62), (0.1, 7.4, 0.25))
    part(olive, "upper", "olive")
    steel = new_bm()
    for x in (-4.3, -2.15, 0.0, 2.15, 4.3):
        tbox(steel, (x, -3.32, 4.7), (0.12, 0.08, 3.0))
    tbox(steel, (0, -3.33, 5.0), (7.2, 0.06, 0.9))  # window frame
    for x in (-2.4, -1.2, 1.2, 2.4):
        tbox(steel, (x, -3.38, 5.0), (0.08, 0.06, 0.8))
    tbox(steel, (0, -3.55, 5.55), (7.4, 0.5, 0.08))  # sunshade
    # Stairs: +X side front to back, landing, then along the back to the roof.
    stairs = new_bm()
    _flight(stairs, (5.25, -3.0, 0.0), (5.25, 2.3, 3.2), 1.3, treads=steel)
    sbox(stairs, (5.25, 3.6, 3.075), (1.4, 2.6, 0.25))
    _flight(stairs, (4.55, 4.25, 3.2), (-2.6, 4.25, 6.5), 1.3, treads=steel)
    sbox(stairs, (-3.4, 4.25, 6.375), (1.6, 1.3, 0.25))
    for x, y, h in ((5.85, 2.4, 3.2), (5.85, 4.8, 3.2), (4.6, 4.8, 3.2), (-2.7, 4.8, 6.5), (-4.1, 4.8, 6.5), (1.0, 4.8, 4.85)):
        tbox(steel, (x, y, h * 0.5), (0.14, 0.14, h))
        column((x, y, 0), 0.1, h)
    _rail(steel, (5.92, -3.0, 0.0), (5.92, 2.3, 3.2), posts=4)
    _rail(steel, (5.92, 2.3, 3.2), (5.92, 4.9, 3.2), posts=2)
    _rail(steel, (4.6, 4.92, 3.2), (-2.6, 4.92, 6.5), posts=5)
    part(stairs, "stairs", "gunmetal")
    # Roof: lattice mast with the hook, whips, a dish, an AC box.
    mx, my = -3.6, -2.7
    for sx in (-0.3, 0.3):
        for sy in (-0.3, 0.3):
            tbox(steel, (mx + sx, my + sy, 8.0), (0.08, 0.08, 3.0))
    for k in range(3):
        z = 6.5 + k * 1.0
        cyl(steel, (mx - 0.3, my - 0.3, z), (mx + 0.3, my + 0.3, z + 1.0), 0.025, sides=3)
        cyl(steel, (mx + 0.3, my - 0.3, z), (mx - 0.3, my + 0.3, z + 1.0), 0.025, sides=3)
    solid((mx, my, 8.0), (0.7, 0.7, 3.0))
    hooks = new_bm()
    hook_block(steel, hooks, (mx, my, 10.05), 1.1)
    part(hooks, "hook", "anchor")
    red = new_bm()
    for x, y, h in ((-1.4, -3.0, 3.4), (0.4, -3.1, 2.6), (3.9, -2.9, 3.0), (4.0, 2.9, 2.2)):
        cyl(steel, (x, y, 6.5), (x, y, 6.5 + h), 0.03, sides=4)
        tbox(steel, (x, y, 6.6), (0.25, 0.25, 0.2))
        _beacon(red, (x, y, 6.55 + h), 0.12)
    _beacon(red, (mx + 0.45, my, 9.3))
    part(red, "beacon_red", "neon")
    tbox(steel, (2.6, 1.6, 6.9), (0.6, 0.6, 0.8))
    solid((2.6, 1.6, 6.9), (1.0, 1.0, 0.8))
    tbox(steel, (-0.6, 2.4, 6.85), (1.6, 1.0, 0.7))
    solid((-0.6, 2.4, 6.85), (1.6, 1.0, 0.7))
    part(steel, "steel", "gunmetal")
    dish = new_bm()
    _dish(dish, (2.6, 1.4, 7.75), 1.1, 0.35, (0, -0.7, 0.7))
    cyl(dish, (2.6, 1.4, 7.75), (2.6, 0.75, 8.4), 0.03, sides=3)
    part(dish, "dish", "canvas")
    dark = new_bm()
    tbox(dark, (1.5, -3.53, 1.1), (1.3, 0.06, 2.2))
    for x in (-3.4, -1.6):
        tbox(dark, (x, -3.53, 2.3), (1.0, 0.06, 0.3))
    for s in (-1, 1):
        tbox(dark, (s * 4.52, 0, 2.3), (0.06, 3.0, 0.3))
    part(dark, "slits", "shadow")
    lit = new_bm()
    tbox(lit, (0, -3.31, 5.0), (7.0, 0.05, 0.75))
    for s in (-1, 1):
        tbox(lit, (s * 4.32, 0.0, 5.0), (0.05, 4.0, 0.75))
    tbox(lit, (1.5, -3.6, 2.45), (0.4, 0.15, 0.15))
    part(lit, "windows", "light")
    grn = new_bm()
    tbox(grn, (2.45, -3.53, 1.3), (0.18, 0.04, 0.3))
    part(grn, "panel_green", "neon")
    paint = new_bm()
    _stencil(paint, "01", (-2.5, -3.53, 1.9), (0, -1), 0.9)
    part(paint, "stencil", "canvas")
    stripe = new_bm()
    tbox(stripe, (0, -3.52, 3.15), (8.9, 0.03, 0.12))
    part(stripe, "band", "anchor")
    top((-0.5, 0.0, 6.5))
    footprint(12.2, 10.0)
    export(name)


def mil_ammo_bunker(name):
    """An earth-covered igloo ammo bunker, 9 W x 10.5 D, 4 m high: a concrete
    headwall with steel blast doors and wing walls, the vault buried under a
    mound you can walk up from the back (about 40 degrees) and along the top
    (top() above the doors). Two mushroom vents on top."""
    begin(name)
    W, H = 4.6, 4.0
    rng = random.Random(77)
    prof = lambda x: max(0.0, 1.0 - (abs(x) / W) ** 3.5)
    tail = lambda y: 1.0 if y <= 0.8 else max(0.0, 1.0 - (y - 0.8) / 4.8)
    xs = [-W + 2 * W * i / 20 for i in range(21)]
    ys = [-4.6 + 10.2 * j / 20 for j in range(21)]
    grid = []
    for y in ys:
        row = []
        for x in xs:
            h = H * prof(x) * tail(y)
            if 0.05 < h and abs(x) < W - 0.2 and y < 5.4:
                h += rng.uniform(-0.07, 0.07)
            row.append(Vector((x, y, max(0.0, h))))
        grid.append(row)
    earth = new_bm()
    _sheet(earth, grid)
    part(earth, "mound", "dirt")
    # Mound colliders: a crown, two side slopes, the back ramp.
    solid((0, -1.9, 1.98), (3.0, 5.4, 3.96))
    for s in (-1, 1):
        for x0, x1 in ((1.5, 3.4), (3.4, W)):
            p0, p1 = (s * x0, H * prof(x0) - 0.25), (s * x1, H * prof(x1) - 0.25)
            cx, cz = (p0[0] + p1[0]) * 0.5, (p0[1] + p1[1]) * 0.5
            w = math.hypot(p1[0] - p0[0], p1[1] - p0[1])
            ang = math.degrees(math.atan2(p1[1] - p0[1], p1[0] - p0[0]))
            ang = ang - 180 if ang > 90 else (ang + 180 if ang < -90 else ang)
            solid((cx, -1.9, cz), (5.4, w, 0.5), yaw=-90, tilt=ang)
    ang = math.degrees(math.atan2(H, 4.8))
    solid((0, 3.2, H * 0.5 - 0.3), (6.0, math.hypot(4.8, H), 0.5), tilt=-ang)
    solid((0, 1.0, 1.5), (7.0, 3.0, 3.0))
    con = new_bm()
    sbox(con, (0, -4.9, 2.15), (9.0, 0.6, 4.3), bevel=0.04)
    tbox(con, (0, -4.9, 4.35), (9.2, 0.75, 0.15))
    for s in (-1, 1):
        sbox(con, (s * 5.0, -5.55, 1.1), (0.45, 1.8, 2.2), yaw=-s * 25)
        tbox(con, (s * 2.05, -5.3, 1.6), (0.35, 0.3, 3.2))  # door piers
    tbox(con, (0, -5.3, 3.35), (4.45, 0.35, 0.35))  # lintel
    sbox(con, (0, -6.0, 0.06), (5.0, 1.8, 0.12))  # apron
    part(con, "headwall", "concrete")
    olive = new_bm()
    for s in (-1, 1):
        tbox(olive, (s * 0.94, -5.27, 1.6), (1.84, 0.14, 3.0))
    solid((0, -5.27, 1.6), (3.8, 0.2, 3.2))
    part(olive, "doors", "olive")
    steel = new_bm()
    for s in (-1, 1):
        for z in (0.6, 1.6, 2.6):
            tbox(steel, (s * 1.1, -5.36, z), (1.5, 0.05, 0.14))
        tbox(steel, (s * 0.12, -5.38, 1.5), (0.06, 0.08, 0.5))  # handles
        tbox(steel, (s * 1.9, -5.37, 1.6), (0.1, 0.06, 3.0))
    tbox(steel, (0, -5.45, 3.75), (0.6, 0.35, 0.15))  # lamp hood
    for x, y in ((-1.2, 0.0), (1.4, -2.5)):
        z = H * prof(x) * tail(y)
        cyl(steel, (x, y, z - 0.3), (x, y, z + 0.7), 0.12, sides=6)
        tapered_tube(steel, [(x, y, z + 0.7), (x, y, z + 0.85)], [0.32, 0.12], sides=8)
    part(steel, "steel", "gunmetal")
    lit = new_bm()
    tbox(lit, (0, -5.45, 3.62), (0.4, 0.25, 0.1))
    part(lit, "lamp", "light")
    paint = new_bm()
    _stencil(paint, "03", (-3.2, -5.22, 2.6), (0, -1), 0.9)
    _stencil(paint, "03", (3.2, -5.22, 2.6), (0, -1), 0.9)
    part(paint, "stencil", "canvas")
    haz = new_bm()
    dark = new_bm()
    for k in range(9):
        tbox(haz if k % 2 == 0 else dark, (-2.0 + k * 0.5, -5.49, 3.35), (0.5, 0.02, 0.3))
    part(haz, "hazard", "anchor")
    tbox(dark, (0, -5.335, 1.6), (0.04, 0.02, 3.0))  # door seam
    part(dark, "hazard_dark", "shadow")
    top((0, -2.0, 4.0))
    footprint(10.4, 13.0)
    export(name)


def mil_radar(name):
    """A radar station: a 7 x 7 olive base 3 m high, a walkway deck on top at
    3.2 round a faceted radome 5.2 across (top at 8.0, a red beacon on it).
    Stairs up the front of the base onto the deck (top() at its corner)."""
    begin(name)
    olive = new_bm()
    sbox(olive, (0, 0, 1.5), (7.0, 7.0, 3.0))
    part(olive, "base", "olive")
    con = new_bm()
    sbox(con, (0, 0, 3.1), (7.6, 7.6, 0.2))
    tbox(con, (0, 0, 0.1), (7.3, 7.3, 0.2))
    part(con, "deck", "concrete")
    steel = new_bm()
    tapered_tube(steel, [(0, 0, 3.2), (0, 0, 3.8)], [2.55, 2.5], sides=16)
    for x in (-3.5, -1.75, 0.0, 1.75, 3.5):
        for s in (-1, 1):
            tbox(steel, (x, s * 3.52, 1.6), (0.12, 0.06, 2.8))
            tbox(steel, (s * 3.52, x, 1.6), (0.06, 0.12, 2.8))
    # Railings round the deck, open where the stairs land.
    _rail(steel, (-3.75, -3.75, 3.2), (2.2, -3.75, 3.2), posts=5)
    _rail(steel, (3.75, -3.0, 3.2), (3.75, 3.75, 3.2), posts=5)
    _rail(steel, (3.75, 3.75, 3.2), (-3.75, 3.75, 3.2), posts=5)
    _rail(steel, (-3.75, 3.75, 3.2), (-3.75, -3.75, 3.2), posts=5)
    stairs = new_bm()
    _flight(stairs, (-2.8, -4.15, 0.0), (2.4, -4.15, 3.2), 1.2, treads=steel)
    sbox(stairs, (3.0, -4.15, 3.1), (1.2, 1.2, 0.2))
    for x, h in ((3.5, 3.2), (2.5, 3.2), (0.0, 1.66)):
        tbox(steel, (x, -4.65, h * 0.5), (0.12, 0.12, h))
    _rail(steel, (-2.8, -4.72, 0.0), (2.4, -4.72, 3.2), posts=4)
    _rail(steel, (2.4, -4.72, 3.2), (3.6, -4.72, 3.2), posts=2)
    part(stairs, "stairs", "gunmetal")
    # AC units and a cable tray on the +X side, door on the back.
    for y in (-1.6, 0.2):
        tbox(steel, (3.85, y, 0.6), (0.7, 1.2, 1.2))
    solid((3.85, -0.7, 0.6), (0.7, 3.0, 1.2))
    tbox(steel, (-3.65, 0.0, 2.4), (0.3, 6.0, 0.15))
    cyl(steel, (0, 0, 7.95), (0, 0, 8.9), 0.03, sides=4)  # lightning rod
    part(steel, "steel", "gunmetal")
    dome = new_bm()
    tmp = bmesh.new()
    bmesh.ops.create_icosphere(tmp, subdivisions=2, radius=2.6)
    bmesh.ops.translate(tmp, vec=Vector((0, 0, 5.4)), verts=list(tmp.verts))
    _merge(dome, tmp)
    part(dome, "radome", "canvas")
    column((0, 0, 3.2), 2.5, 4.4)
    solid((0, 0, 7.75), (2.6, 2.6, 0.5))
    dark = new_bm()
    tbox(dark, (1.2, 3.53, 1.1), (1.2, 0.06, 2.2))
    for y in (-1.6, 0.2):
        tapered_tube(dark, [(4.2, y, 0.75), (4.22, y, 0.75)], [0.35, 0.35], sides=10)
    part(dark, "door", "shadow")
    lit = new_bm()
    tbox(lit, (1.2, 3.62, 2.45), (0.4, 0.15, 0.12))
    part(lit, "lamp", "light")
    red = new_bm()
    _beacon(red, (0.0, 0.25, 8.02), 0.2)
    for sx in (-1, 1):
        _beacon(red, (sx * 3.75, 3.75, 4.3), 0.14)
    part(red, "beacon_red", "neon")
    paint = new_bm()
    _stencil(paint, "07", (-1.2, -3.54, 1.8), (0, -1), 1.1)
    part(paint, "stencil", "canvas")
    top((-2.9, -2.9, 3.2))
    footprint(8.4, 9.6)
    export(name)


def mil_gate(name):
    """A checkpoint gate, 9 W x 4.6 D: a guard booth with lit windows on the
    right (its roof a top() at 3.0, climbed by two stacked concrete blocks
    behind it, 1 and 2 m), a striped boom barrier across the 5 m lane, and
    jersey-profile blocks lining the left side."""
    begin(name)
    bx, by = 3.4, -0.6
    olive = new_bm()
    sbox(olive, (bx, by, 1.4), (2.0, 2.0, 2.8))
    sbox(olive, (bx, by, 2.9), (2.6, 2.6, 0.2))
    part(olive, "booth", "olive")
    lit = new_bm()
    tbox(lit, (bx, by - 1.02, 1.75), (1.6, 0.05, 0.8))
    tbox(lit, (bx - 1.02, by, 1.75), (0.05, 1.6, 0.8))
    tbox(lit, (bx, by + 1.02, 1.75), (1.6, 0.05, 0.8))
    tbox(lit, (bx - 0.5, by - 1.25, 2.68), (0.35, 0.12, 0.1))
    part(lit, "windows", "light")
    steel = new_bm()
    for d in (-0.4, 0.4):
        tbox(steel, (bx + d, by - 1.05, 1.75), (0.06, 0.05, 0.85))
        tbox(steel, (bx - 1.05, by + d, 1.75), (0.05, 0.06, 0.85))
        tbox(steel, (bx + d, by + 1.05, 1.75), (0.06, 0.05, 0.85))
    tbox(steel, (bx, by - 1.06, 1.3), (1.7, 0.08, 0.06))
    tbox(steel, (bx - 1.06, by, 1.3), (0.08, 1.7, 0.06))
    # Roof spotlight and whip.
    tbox(steel, (bx - 0.7, by - 0.7, 3.15), (0.25, 0.25, 0.3))
    cyl(steel, (bx + 0.9, by + 0.9, 3.0), (bx + 0.9, by + 0.9, 5.2), 0.025, sides=4)
    # Boom pivot post, counterweight, the arm's rest post on the far side.
    px, py = 1.6, -1.6
    tbox(steel, (px, py, 0.55), (0.35, 0.35, 1.1))
    column((px, py, 0), 0.25, 1.1)
    tbox(steel, (-4.05, py, 0.45), (0.15, 0.15, 0.9))
    for s in (-1, 1):
        tbox(steel, (-4.05, py + s * 0.1, 0.98), (0.06, 0.06, 0.2), tilt=s * 25)
    column((-4.05, py, 0), 0.1, 0.9)
    part(steel, "steel", "gunmetal")
    con = new_bm()
    sbox(con, (px, py, 0.1), (0.7, 0.7, 0.2))
    tbox(con, (px + 0.45, py, 1.05), (0.5, 0.4, 0.4))  # counterweight
    # Climbing blocks behind the booth.
    sbox(con, (bx, 0.9, 1.0), (1.3, 1.0, 2.0), bevel=0.04)
    sbox(con, (bx, 1.85, 0.5), (1.3, 0.9, 1.0), bevel=0.04)
    # Jersey blocks down the left side of the lane.
    for y in (-1.2, 1.0):
        _extrude_y(con, [(-4.55, 0.0), (-3.85, 0.0), (-3.85, 0.25), (-4.05, 0.45), (-4.05, 0.9), (-4.35, 0.9), (-4.35, 0.45), (-4.55, 0.25)][::-1], y - 1.0, y + 1.0)
        solid((-4.2, y, 0.45), (0.7, 2.0, 0.9))
    part(con, "concrete", "concrete")
    # Boom arm: pale and dark stripes.
    pale, dark = new_bm(), new_bm()
    n = 9
    x0, x1 = px - 0.1, -4.0
    seg = (x0 - x1) / n
    for k in range(n):
        tbox(pale if k % 2 == 0 else dark, (x0 - (k + 0.5) * seg, py, 1.05), (seg, 0.12, 0.14))
    solid(((x0 + x1) * 0.5, py, 1.05), (x0 - x1, 0.15, 0.15))
    tbox(dark, (bx, by - 1.02, 0.6), (1.4, 0.05, 1.0))  # booth plinth band
    tbox(dark, (bx + 1.02, by + 0.2, 1.05), (0.05, 0.9, 2.1))  # door
    part(pale, "arm", "canvas")
    _stencil(dark, "04", (bx, by - 1.03, 2.45), (0, -1), 0.4)
    # Stop line across the lane.
    line = new_bm()
    tbox(line, (-1.2, -2.2, 0.01), (5.0, 0.3, 0.02))
    part(line, "stopline", "canvas")
    part(dark, "stripes", "shadow")
    red = new_bm()
    _beacon(red, (x1 + 0.1, py, 1.18), 0.12)
    _beacon(red, (px, py, 1.18), 0.14)
    _beacon(red, (bx + 0.9, by - 0.9, 3.1), 0.16)
    part(red, "beacon_red", "neon")
    top((bx, by, 3.0))
    footprint(9.4, 5.0)
    export(name)


# =============================================================================
# Climbs and landmarks
# =============================================================================

def mil_guard_tower(name):
    """A guard tower, legs on a 3.4 m square: a cabin deck at 7.0 with a
    plated front and gappy railings, a searchlight, a flat roof at 9.5 with a
    hook block on top at 10.6. A stair winds up round the outside of the legs,
    a flight per side, to a landing at the deck's front-left corner (the
    deck is the top(): a reward crate up there)."""
    begin(name)
    steel = new_bm()
    for sx in (-1, 1):
        for sy in (-1, 1):
            tapered_tube(steel, [(sx * 1.75, sy * 1.75, 0), (sx * 1.55, sy * 1.55, 6.8)], [0.13, 0.11], sides=4)
            column((sx * 1.65, sy * 1.65, 0), 0.16, 6.8)
            tbox(steel, (sx * 1.75, sy * 1.75, 0.08), (0.5, 0.5, 0.16))
    for z0, z1 in ((0.3, 3.5), (3.5, 6.7)):
        for s in (-1, 1):
            w0, w1 = 1.75 - z0 * 0.03, 1.75 - z1 * 0.03
            cyl(steel, (-w0, s * w0, z0), (w1, s * w1, z1), 0.05, sides=4)
            cyl(steel, (s * w0, -w0, z0), (s * w1, w1, z1), 0.05, sides=4)
    # Corner posts and the roof.
    for sx in (-1, 1):
        for sy in (-1, 1):
            tbox(steel, (sx * 1.65, sy * 1.65, 8.2), (0.12, 0.12, 2.4))
    part(steel, "legs", "gunmetal")
    deck = new_bm()
    sbox(deck, (0, 0, 6.875), (3.6, 3.6, 0.25))
    olive = new_bm()
    sbox(olive, (0, 0, 9.4), (4.0, 4.0, 0.2))
    tbox(olive, (0, 0, 9.55), (3.0, 3.0, 0.1))
    # Plated front (with a gap at the stair corner) and half-plates on the sides.
    sbox(olive, (0.15, -1.78, 7.5), (3.3, 0.08, 1.0))
    tbox(olive, (1.78, -0.6, 7.3), (0.08, 1.8, 0.6))
    part(olive, "cabin", "olive")
    rail = new_bm()
    _rail(rail, (1.78, 0.3, 7.0), (1.78, 1.78, 7.0), posts=2)
    _rail(rail, (1.78, 1.78, 7.0), (-1.78, 1.78, 7.0), posts=4)
    _rail(rail, (-1.78, 1.78, 7.0), (-1.78, -1.0, 7.0), posts=3)
    # Stairs round the outside: one flight per side, corner landings.
    o, w = 2.2, 0.9
    flights = [
        ((-1.6, -o, 0.0), (1.6, -o, 1.75)),
        ((o, -1.6, 1.75), (o, 1.6, 3.5)),
        ((1.6, o, 3.5), (-1.6, o, 5.25)),
        ((-o, 1.6, 5.25), (-o, -1.6, 7.0)),
    ]
    for a, b in flights:
        _flight(deck, a, b, w, treads=rail)
    for (x, y), z in (((o, -o), 1.75), ((o, o), 3.5), ((-o, o), 5.25)):
        sbox(deck, (x, y, z - 0.1), (w + 0.1, w + 0.1, 0.2))
        tbox(rail, (x + (0.4 if x > 0 else -0.4), y + (0.4 if y > 0 else -0.4), z * 0.5), (0.1, 0.1, z))
    sbox(deck, (-2.05, -2.05, 6.9), (1.3, 1.3, 0.2))  # top landing onto the deck
    part(deck, "deck", "gunmetal")
    tbox(rail, (-2.6, -2.6, 3.45), (0.1, 0.1, 6.9))
    # Outer stair rails.
    _rail(rail, (-1.6, -o - 0.45, 0.0), (1.6, -o - 0.45, 1.75), posts=3)
    _rail(rail, (o + 0.45, -1.6, 1.75), (o + 0.45, 1.6, 3.5), posts=3)
    _rail(rail, (1.6, o + 0.45, 3.5), (-1.6, o + 0.45, 5.25), posts=3)
    _rail(rail, (-o - 0.45, 1.6, 5.25), (-o - 0.45, -1.6, 7.0), posts=3)
    # Searchlight on the front-right corner.
    tbox(rail, (1.3, -1.3, 7.45), (0.12, 0.12, 0.9))
    tapered_tube(rail, [(1.3, -1.1, 8.05), (1.3, -1.55, 7.98)], [0.26, 0.3], sides=10)
    cyl(rail, (0, 0, 9.5), (0, 0, 9.6), 0.3, sides=6)
    tbox(rail, (0, 0, 9.85), (0.22, 0.22, 0.5))
    hooks = new_bm()
    hook_block(rail, hooks, (0, 0, 10.6), 1.1)
    part(hooks, "hook", "anchor")
    part(rail, "rails", "gunmetal")
    lens = new_bm()
    tapered_tube(lens, [(1.3, -1.56, 7.98), (1.3, -1.6, 7.975)], [0.25, 0.25], sides=10)
    part(lens, "searchlight", "light")
    red = new_bm()
    for sx, sy in ((-1, 1), (1, 1)):
        _beacon(red, (sx * 1.85, sy * 1.85, 9.6), 0.16)
    part(red, "beacon_red", "neon")
    paint = new_bm()
    _stencil(paint, "4", (-0.6, -1.83, 7.5), (0, -1), 0.7)
    part(paint, "stencil", "canvas")
    top((0.3, 0.3, 7.0))
    footprint(5.6, 5.6)
    export(name)


def mil_comms_tower(name):
    """A 16 m lattice radio tower on four concrete footings, tapering from
    3.0 to 1.2 across, with microwave drum dishes at 9.5 and 11, red beacons
    at 8 and on top, a whip to 18.5, and a hook block out front on an arm at
    13.0 (grapple it, swing round)."""
    begin(name)
    H = 16.0
    hw = lambda z: 1.5 - 0.9 * z / H
    steel = new_bm()
    for sx in (-1, 1):
        for sy in (-1, 1):
            tapered_tube(steel, [(sx * hw(0), sy * hw(0), 0), (sx * hw(H), sy * hw(H), H)], [0.1, 0.07], sides=4)
    for k in range(8):
        z0, z1 = k * 2.0, (k + 1) * 2.0
        a, b = hw(z0), hw(z1)
        for s in (-1, 1):
            cyl(steel, (-a, s * a, z0), (b, s * b, z1), 0.035, sides=3)
            cyl(steel, (a, s * a, z0), (-b, s * b, z1), 0.035, sides=3)
            cyl(steel, (s * a, -a, z0), (s * b, b, z1), 0.035, sides=3)
            cyl(steel, (s * a, a, z0), (s * b, -b, z1), 0.035, sides=3)
            cyl(steel, (-b, s * b, z1), (b, s * b, z1), 0.04, sides=3)
            cyl(steel, (s * b, -b, z1), (s * b, b, z1), 0.04, sides=3)
    solid((0, 0, 4.0), (2.6, 2.6, 8.0))
    solid((0, 0, 12.0), (1.7, 1.7, 8.0))
    # Top platform and the whip.
    tbox(steel, (0, 0, H + 0.05), (1.6, 1.6, 0.1))
    cyl(steel, (0, 0, H), (0, 0, H + 2.5), 0.04, sides=4)
    # Hook arm out front at 13.
    zh = 13.0
    tbox(steel, (0, -hw(zh) - 0.7, zh), (0.25, 1.5, 0.25))
    cyl(steel, (0, -hw(zh), zh - 1.0), (0, -hw(zh) - 1.2, zh - 0.1), 0.05, sides=4)
    hooks = new_bm()
    hook_block(steel, hooks, (0, -hw(zh) - 1.9, zh), 1.2)
    part(hooks, "hook", "anchor")
    # Dish mounts.
    tbox(steel, (hw(9.5) + 0.25, 0, 9.5), (0.5, 0.15, 0.15))
    tbox(steel, (-hw(11.0) - 0.25, 0.3, 11.0), (0.5, 0.15, 0.15))
    # Equipment cabinet at the foot, cable up a leg.
    cyl(steel, (hw(0) + 0.1, hw(0) - 0.1, 1.2), (hw(H) + 0.1, hw(H) - 0.1, H), 0.05, sides=3)
    part(steel, "lattice", "gunmetal")
    drums = new_bm()
    tapered_tube(drums, [(hw(9.5) + 0.5, 0, 9.5), (hw(9.5) + 0.95, 0, 9.5)], [0.6, 0.6], sides=12)
    tapered_tube(drums, [(-hw(11.0) - 0.5, 0.3, 11.0), (-hw(11.0) - 0.85, 0.0, 11.0)], [0.45, 0.45], sides=12)
    part(drums, "drums", "olive")
    faces = new_bm()
    tapered_tube(faces, [(hw(9.5) + 0.95, 0, 9.5), (hw(9.5) + 1.0, 0, 9.5)], [0.62, 0.62], sides=12)
    tapered_tube(faces, [(-hw(11.0) - 0.85, 0.0, 11.0), (-hw(11.0) - 0.89, -0.035, 11.0)], [0.47, 0.47], sides=12)
    _dish(faces, (0.0, hw(6.0) + 0.6, 6.0), 0.9, 0.3, (0.2, 1.0, 0.25))
    part(faces, "radomes", "canvas")
    con = new_bm()
    for sx in (-1, 1):
        for sy in (-1, 1):
            sbox(con, (sx * hw(0), sy * hw(0), 0.2), (0.7, 0.7, 0.4))
    part(con, "footings", "concrete")
    olive = new_bm()
    sbox(olive, (hw(0) + 0.9, -0.6, 0.7), (0.8, 1.0, 1.4))
    part(olive, "cabinet", "olive")
    grn = new_bm()
    tbox(grn, (hw(0) + 0.9, -1.11, 1.1), (0.3, 0.03, 0.1))
    part(grn, "panel_green", "neon")
    red = new_bm()
    for sx, sy in ((-1, -1), (1, 1)):
        _beacon(red, (sx * (hw(8.0) + 0.12), sy * (hw(8.0) + 0.12), 8.0), 0.2)
    _beacon(red, (0, 0, H + 0.25), 0.25)
    _beacon(red, (0, 0, H + 2.55), 0.12)
    part(red, "beacon_red", "neon")
    footprint(4.2, 7.0)
    export(name)


def mil_helipad(name):
    """A tarmac helipad 12 x 12, raised 0.3: a painted H in a circle and an
    edge border, edge lights all round, tie-down rings, and a windsock on a
    4.5 m pole at its back-right corner. The pad is a top()."""
    begin(name)
    pad = new_bm()
    sbox(pad, (0, 0, 0.15), (12.0, 12.0, 0.3), bevel=0.04)
    part(pad, "pad", "tarmac")
    paint = new_bm()
    z = 0.31
    for s in (-1, 1):
        tbox(paint, (s * 1.2, 0, z), (0.6, 4.0, 0.03))
        tbox(paint, (0, s * 5.4, z), (10.8, 0.3, 0.03))
        tbox(paint, (s * 5.4, 0, z), (0.3, 10.5, 0.03))
    tbox(paint, (0, 0, z), (1.8, 0.6, 0.03))
    n = 28
    for k in range(n):
        a = 2 * math.pi * (k + 0.5) / n
        if k % 7 == 3:
            continue  # gaps in the ring, like the painted originals
        tbox(paint, (math.cos(a) * 4.0, math.sin(a) * 4.0, z), (0.35, 2 * math.pi * 4.0 / n + 0.04, 0.03), yaw=math.degrees(a))
    part(paint, "markings", "canvas")
    steel = new_bm()
    lit = new_bm()
    for k in range(6):
        t = -5.8 + k * 11.6 / 5
        for p in ((t, -5.85), (t, 5.85), (-5.85, t), (5.85, t)):
            tbox(steel, (p[0], p[1], 0.33), (0.2, 0.2, 0.06))
            tbox(lit, (p[0], p[1], 0.4), (0.13, 0.13, 0.1))
    for x, y in ((-2.8, -2.8), (2.8, -2.8), (-2.8, 2.8), (2.8, 2.8)):
        ring(steel, (x, y, 0.32), 0.14, 0.025, sides=6)
    # Windsock.
    wx, wy = 5.5, 5.5
    tbox(steel, (wx, wy, 0.4), (0.4, 0.4, 0.2))
    cyl(steel, (wx, wy, 0.3), (wx, wy, 4.8), 0.06, sides=6)
    column((wx, wy, 0.3), 0.08, 4.5)
    ring(steel, (wx - 0.3, wy, 4.6), 0.28, 0.025, sides=8)
    part(steel, "fittings", "gunmetal")
    part(lit, "edge_lights", "light")
    sock = new_bm()
    pts = [(wx - 0.3 - 0.0, wy, 4.6), (wx - 0.9, wy - 0.15, 4.45), (wx - 1.5, wy - 0.35, 4.25), (wx - 2.1, wy - 0.6, 4.0)]
    tapered_tube(sock, pts[:2], [0.28, 0.24], sides=8)
    tapered_tube(sock, pts[2:], [0.19, 0.15], sides=8)
    part(sock, "sock", "canvas")
    bands = new_bm()
    tapered_tube(bands, pts[1:3], [0.24, 0.19], sides=8)
    part(bands, "sock_band", "anchor")
    red = new_bm()
    _beacon(red, (wx, wy, 4.92), 0.16)
    part(red, "beacon_red", "neon")
    top((0, 0, 0.3))
    footprint(12.4, 12.4)
    export(name)


# =============================================================================
# Wallrun walls
# =============================================================================

def mil_hesco_wall(name, seed):
    """A 12 m line of HESCO bastion baskets, two tiers (4.4 m), 1.1 m thick,
    capped by a steel rail at 4.5 with a steel kick rail along its foot. Blue
    trim along top and bottom of both faces: a wall to run along."""
    begin(name)
    rng = random.Random(seed)
    L, T, Hb = 12.0, 1.1, 2.2
    n = 10
    bw = L / n
    baskets = new_bm()
    wire = new_bm()
    for tier in range(2):
        zc = Hb * (tier + 0.5)
        for k in range(n):
            x = -L * 0.5 + bw * (k + 0.5)
            tbox(baskets, (x + rng.uniform(-0.02, 0.02), rng.uniform(-0.02, 0.02), zc), (bw - 0.03, T + rng.uniform(-0.02, 0.03), Hb - 0.04), yaw=rng.uniform(-0.8, 0.8))
            for s in (-1, 1):
                tbox(wire, (x - bw * 0.5, s * (T * 0.5 + 0.02), zc), (0.05, 0.04, Hb - 0.04))
                tbox(wire, (x, s * (T * 0.5 + 0.02), zc + Hb * 0.5 - 0.06), (bw, 0.03, 0.04))
    solid((0, 0, 2.25), (L, T + 0.1, 4.5))
    part(baskets, "baskets", "hesco")
    for s in (-1, 1):
        tbox(wire, (s * L * 0.5, 0, Hb), (0.05, T + 0.08, 2 * Hb))
    # Steel cap rail with flanges, and kick rails along the foot.
    tbox(wire, (0, 0, 4.45), (L + 0.1, T + 0.14, 0.1))
    for s in (-1, 1):
        tbox(wire, (0, s * (T * 0.5 + 0.06), 4.25), (L + 0.1, 0.05, 0.4))
        tbox(wire, (0, s * (T * 0.5 + 0.06), 0.35), (L + 0.1, 0.05, 0.4))
    part(wire, "frame", "gunmetal")
    dirt = new_bm()
    for k in range(n):
        x = -L * 0.5 + bw * (k + 0.5)
        blob(dirt, (x, 0, 0.04), (0.7, 0.75, 0.12), rng, subdiv=1, wobble=0.2, seed=seed + k)
    part(dirt, "spill", "dirt")
    trim = new_bm()
    for s in (-1, 1):
        for z in (0.35, 4.25):
            tbox(trim, (0, s * (T * 0.5 + 0.09), z), (L, 0.02, 0.22))
    part(trim, "trim", "wallrun")
    top((0, 0, 4.5))
    footprint(L + 0.4, 1.8)
    export(name)


def mil_t_wall(name, seed):
    """A 12 m row of eight concrete T-walls (each 1.5 W x 4.8 H, a 1.5 m deep
    footing), stencilled with numbers, lifting eyes on top. Blue trim along
    the top and bottom of both faces: a wall to run along."""
    begin(name)
    rng = random.Random(seed)
    n, w = 8, 1.5
    L = n * w
    con = new_bm()
    steel = new_bm()
    paint = new_bm()
    for k in range(n):
        x = -L * 0.5 + w * (k + 0.5)
        lean = rng.uniform(-0.6, 0.6)
        tbox(con, (x, 0, 2.3), (w - 0.04, 0.36, 4.6), tilt=lean * 0.3, bevel=0.03)
        tbox(con, (x, 0, 4.7), (w - 0.04, 0.26, 0.2), bevel=0.02)
        tbox(con, (x, 0, 0.2), (w - 0.04, 1.5, 0.4), bevel=0.03)
        for s in (-1, 1):
            tbox(con, (x, s * 0.36, 0.45), (w - 0.06, 0.42, 0.2), tilt=s * 25)
        for d in (-0.4, 0.4):
            cyl(steel, (x + d - 0.1, 0, 4.8), (x + d - 0.1, 0, 4.95), 0.025, sides=3)
            cyl(steel, (x + d + 0.1, 0, 4.8), (x + d + 0.1, 0, 4.95), 0.025, sides=3)
            cyl(steel, (x + d - 0.1, 0, 4.95), (x + d + 0.1, 0, 4.95), 0.025, sides=3)
        num = "%02d" % rng.randint(10, 99)
        _stencil(paint, num, (x, -0.19, 3.5), (0, -1), 0.55)
        _stencil(paint, num, (x, 0.19, 3.5), (0, 1), 0.55)
    solid((0, 0, 2.4), (L, 0.36, 4.8))
    solid((0, 0, 0.2), (L, 1.5, 0.4))
    part(con, "slabs", "concrete")
    part(steel, "eyes", "gunmetal")
    part(paint, "stencil", "shadow")
    trim = new_bm()
    for s in (-1, 1):
        for z in (0.8, 4.45):
            tbox(trim, (0, s * 0.195, z), (L - 0.04, 0.02, 0.22))
    part(trim, "trim", "wallrun")
    footprint(L + 0.2, 1.8)
    export(name)


# =============================================================================
# Props
# =============================================================================

def mil_fuel_bladder(name, seed):
    """A fuel bladder in its berm: a fat black rubber pillow (about 4 x 2 x
    0.9) inside an earth berm topped with sandbags, a pump skid and hoses
    out to the right, a FUEL board. About 7 x 4.4, 1.6 at the pump."""
    begin(name)
    rng = random.Random(seed)
    earth = new_bm()
    for s in (-1, 1):
        _ridge(earth, (-2.75, s * 1.75), (2.75, s * 1.75), 0.9, 0.35, 0.75)
        _ridge(earth, (s * 2.75, -1.75), (s * 2.75, 1.75), 0.9, 0.35, 0.75)
        solid((0, s * 1.75, 0.45), (5.9, 0.7, 0.9))
        solid((s * 2.75, 0, 0.45), (0.7, 3.5, 0.9))
    part(earth, "berm", "dirt")
    bags = new_bm()
    for s in (-1, 1):
        for k in range(9):
            _bag(bags, rng, (-2.4 + k * 0.6, s * 1.75, 0.86), rng.uniform(-6, 6), seed=seed + k + (s + 1) * 10)
        for k in range(5):
            if s > 0 and k == 3:
                continue  # the hose goes over here
            _bag(bags, rng, (s * 2.75, -1.25 + k * 0.62, 0.86), 90 + rng.uniform(-6, 6), seed=seed + 40 + k + (s + 1) * 10)
    part(bags, "bags", "canvas")
    rubber = new_bm()
    blob(rubber, (0, 0, 0.42), (2.05, 1.1, 0.48), rng, subdiv=2, wobble=0.03, seed=seed)
    solid((0, 0, 0.42), (3.8, 2.0, 0.84))
    # Hose from the fitting over the berm to the pump.
    tapered_tube(rubber, [(1.5, 0.3, 0.75), (2.2, 0.35, 1.05), (2.75, 0.35, 1.15), (3.2, 0.35, 0.8), (3.45, 0.2, 0.4)], [0.07] * 5, sides=6)
    tapered_tube(rubber, [(3.6, -0.3, 0.3), (3.6, -1.2, 0.08), (2.8, -2.4, 0.08), (1.0, -2.5, 0.08)], [0.06] * 4, sides=6)
    part(rubber, "bladder", "shadow")
    steel = new_bm()
    for x, y in ((1.5, 0.3), (-1.4, -0.4)):
        cyl(steel, (x, y, 0.72), (x, y, 0.88), 0.12, sides=8)
    # Pump skid.
    tbox(steel, (3.55, 0, 0.1), (1.0, 1.4, 0.2))
    tapered_tube(steel, [(3.35, 0.45, 0.5), (3.35, 0.45, 1.1)], [0.16, 0.16], sides=8)
    cyl(steel, (3.75, -0.4, 1.0), (3.75, -0.4, 1.6), 0.04, sides=4)
    part(steel, "fittings", "gunmetal")
    olive = new_bm()
    sbox(olive, (3.65, -0.15, 0.55), (0.8, 0.8, 0.7))
    tbox(olive, (3.65, -0.15, 0.95), (0.9, 0.9, 0.1))
    part(olive, "pump", "olive")
    # FUEL board on a post at the front-left.
    wood = new_bm()
    tbox(wood, (-2.2, -2.45, 0.7), (0.1, 0.1, 1.4))
    tbox(wood, (-2.2, -2.5, 1.3), (1.5, 0.06, 0.5))
    column((-2.2, -2.45, 0), 0.08, 1.4)
    part(wood, "sign", "canvas")
    paint = new_bm()
    _stencil(paint, "FUEL", (-2.2, -2.54, 1.3), (0, -1), 0.3, depth=0.02)
    part(paint, "lettering", "shadow")
    amb = new_bm()
    tbox(amb, (3.65, -0.56, 0.7), (0.2, 0.03, 0.1))
    part(amb, "panel_amber", "neon")
    footprint(8.0, 5.4)
    export(name)


def mil_apc(name):
    """A wheeled armoured personnel carrier, 6.5 L along X x 2.9 W x 2.6 H:
    eight wheels, a sloped nose at +X, a sloped-sided troop roof, a small
    turret with a cannon, rear door, stencilled numbers. Tall cover."""
    begin(name)
    olive = new_bm()
    _extrude_y(olive, [(-3.1, 0.75), (2.5, 0.75), (3.25, 1.3), (2.3, 1.95), (-3.0, 1.95), (-3.25, 1.6)], -1.2, 1.2)
    _extrude_x(olive, [(-1.2, 1.94), (1.2, 1.94), (0.92, 2.3), (-0.92, 2.3)], -3.0, 1.6)
    # Fenders over the wheels and side boxes.
    for s in (-1, 1):
        for x0, x1 in ((-2.95, -0.35), (0.25, 2.6)):
            tbox(olive, ((x0 + x1) * 0.5, s * 1.32, 1.2), (x1 - x0, 0.25, 0.08))
        tbox(olive, (-1.6, s * 1.25, 1.55), (1.2, 0.15, 0.4))
    # Turret.
    tapered_tube(olive, [(-0.4, 0, 2.28), (-0.4, 0, 2.62)], [0.78, 0.62], sides=8)
    tbox(olive, (0.35, 0, 2.45), (0.45, 0.5, 0.3))
    part(olive, "hull", "olive")
    solid((0, 0, 1.12), (6.5, 2.9, 2.25))
    solid((-0.4, 0, 2.45), (1.5, 1.5, 0.35))
    tyre, hub = new_bm(), new_bm()
    for x in (-2.3, -1.0, 0.85, 2.15):
        for s in (-1, 1):
            _wheel(tyre, hub, (x, s * 1.25, 0.55), 0.55, 0.38)
    part(tyre, "tyres", "shadow")
    steel = hub
    cyl(steel, (0.55, 0, 2.45), (2.6, 0, 2.52), 0.07, sides=6)
    cyl(steel, (2.45, 0, 2.515), (2.75, 0, 2.525), 0.1, sides=6)
    cyl(steel, (0.5, 0.2, 2.5), (1.1, 0.2, 2.5), 0.04, sides=4)
    for s in (-1, 1):
        for k in range(2):
            cyl(steel, (-0.6, s * 0.6, 2.45 + k * 0.12), (-0.6, s * 0.85, 2.55 + k * 0.12), 0.05, sides=5)
    tbox(steel, (-0.9, 0, 2.66), (0.5, 0.5, 0.08))  # hatch
    tbox(steel, (-2.2, 0.5, 2.33), (0.7, 0.6, 0.06))
    tbox(steel, (-2.2, -0.5, 2.33), (0.7, 0.6, 0.06))
    cyl(steel, (-2.8, 0.8, 2.3), (-2.8, 0.8, 4.2), 0.015, sides=3)  # whip
    for s in (-1, 1):
        tbox(steel, (2.9, s * 0.95, 0.9), (0.2, 0.25, 0.12))  # tow hooks
    part(hub, "steel", "gunmetal")
    dark = new_bm()
    tbox(dark, (-3.27, 0, 1.25), (0.04, 1.2, 0.8))  # rear door
    for x in (-0.2, 1.0, 2.0):
        for s in (-1, 1):
            tbox(dark, (x, s * 1.205, 1.75), (0.35, 0.03, 0.12))
    for s in (-1, 1):
        tbox(dark, (s * 0.0 + 1.3, s * 0.72, 2.2), (0.25, 0.05, 0.1), yaw=0)
    part(dark, "vision", "shadow")
    lit = new_bm()
    for s in (-1, 1):
        tbox(lit, (2.98, s * 0.9, 1.15), (0.1, 0.22, 0.15))
    part(lit, "headlights", "light")
    paint = new_bm()
    for s in (-1, 1):
        _stencil(paint, "21", (-1.9, s * 1.215, 1.1), (0, s), 0.36)
        _stencil(paint, "21", (0.9, s * 1.215, 1.4), (0, s), 0.22)
    _stencil(paint, "21", (-3.28, 0, 1.85), (-1, 0), 0.22)
    part(paint, "stencil", "canvas")
    footprint(6.8, 3.0)
    export(name)


def mil_aa_gun(name, seed):
    """A twin-barrel anti-aircraft gun on a pivot, its barrels raised toward
    -Y, inside a ring of sandbags 4.6 across (open at the back), with ammo
    cans: about 2.5 high at the muzzles."""
    begin(name)
    rng = random.Random(seed)
    bags = new_bm()
    for k in range(18):
        a = -math.pi * 0.85 + k * (math.pi * 1.7 / 17) - math.pi / 2
        for row in range(3):
            r = 1.95
            off = (0.5 / r) * 0.5 * (row % 2)
            _bag(bags, rng, (math.cos(a + off) * r, math.sin(a + off) * r, 0.17 + row * 0.3), math.degrees(a + off) + 90, size=(0.34, 0.2, 0.16), seed=seed + k * 3 + row)
    solid((0, -1.95, 0.5), (3.4, 0.6, 1.0))
    for s in (-1, 1):
        solid((s * 1.75, -0.2, 0.5), (0.6, 2.8, 1.0), yaw=s * 18)
    part(bags, "bags", "canvas")
    steel = new_bm()
    tapered_tube(steel, [(0, 0, 0), (0, 0, 0.75)], [0.45, 0.32], sides=8)
    tbox(steel, (0, 0, 0.05), (1.3, 1.3, 0.1))
    column((0, 0, 0), 0.6, 1.4)
    # Barrels, elevated 28 degrees toward -Y.
    el = math.radians(28)
    d = Vector((0, -math.cos(el), math.sin(el)))
    for x in (-0.22, 0.22):
        p = Vector((x, -0.1, 1.45))
        cyl(steel, p, p + d * 2.3, 0.07, sides=6)
        cyl(steel, p + d * 2.05, p + d * 2.35, 0.11, sides=6)
        cyl(steel, p - d * 0.5, p + d * 0.6, 0.08, sides=6)
    tbox(steel, (0.75, 0.55, 0.9), (0.4, 0.35, 0.08))  # seat
    tbox(steel, (0.75, 0.75, 1.15), (0.4, 0.06, 0.45))
    cyl(steel, (0.6, 0.2, 0.8), (0.75, 0.55, 0.88), 0.04, sides=4)
    tbox(steel, (-0.35, -0.75, 1.75), (0.06, 0.06, 0.35))  # sight post
    ring(steel, (-0.35, -0.75, 1.95), 0.15, 0.015, sides=8)
    part(steel, "gun", "gunmetal")
    olive = new_bm()
    tapered_tube(olive, [(0, 0, 0.75), (0, 0, 0.88)], [0.95, 0.95], sides=12)
    for s in (-1, 1):
        tbox(olive, (s * 0.5, 0.0, 1.25), (0.1, 0.9, 0.8))
    for x in (-0.22, 0.22):
        tbox(olive, (x, -0.1, 1.45), (0.22, 1.0, 0.3), tilt=-28)
        tbox(olive, (x, 0.2, 1.75), (0.18, 0.35, 0.25), tilt=-28)  # magazines
    # Ammo cans along the inside of the wall.
    for k, (x, y) in enumerate(((-1.2, 0.6), (-1.25, 0.25), (-1.2, -0.1), (1.25, -0.4))):
        tbox(olive, (x, y, 0.13), (0.32, 0.18, 0.26), yaw=rng.uniform(-10, 10) + 90)
    part(olive, "mount", "olive")
    paint = new_bm()
    _stencil(paint, "2", (0.56, 0.0, 1.25), (1, 0), 0.4)
    _stencil(paint, "2", (-0.56, 0.0, 1.25), (-1, 0), 0.4)
    part(paint, "stencil", "canvas")
    footprint(4.6, 4.6)
    export(name)


def mil_razor_fence(name, seed):
    """A 6 m chain-link fence panel, 2.4 m of mesh between three steel posts,
    Y-arms on the posts carrying a coil of razor wire to about 3.1 m. One
    thin collider: a boundary."""
    begin(name)
    rng = random.Random(seed)
    L, Hm = 6.0, 2.4
    steel = new_bm()
    for x in (-L * 0.5, 0.0, L * 0.5):
        tapered_tube(steel, [(x, 0, 0), (x, 0, Hm + 0.1)], [0.05, 0.05], sides=6)
        tbox(steel, (x, 0, 0.05), (0.25, 0.25, 0.1))
        for s in (-1, 1):
            cyl(steel, (x, 0, Hm + 0.05), (x, s * 0.35, Hm + 0.5), 0.03, sides=4)
    for z in (0.05, Hm, 1.2):
        cyl(steel, (-L * 0.5, 0, z), (L * 0.5, 0, z), 0.025, sides=4)
    for s in (-1, 1):
        cyl(steel, (-L * 0.5, s * 0.33, Hm + 0.47), (L * 0.5, s * 0.33, Hm + 0.47), 0.008, sides=3)
    part(steel, "posts", "gunmetal")
    mesh = new_bm()
    sp = 0.3
    # Diagonal mesh lines x - z = c and x + z = c, clipped to the panel.
    x0, x1, z0, z1 = -L * 0.5, L * 0.5, 0.05, Hm
    c = x0 - z1
    while c < x1 - z0:
        for sign in (1, -1):
            pts = []
            # Line x = c + sign*z, clipped.
            for z in (z0, z1):
                x = (c + z) if sign > 0 else (x0 + x1 - (c + z))
                pts.append((x, z))
            (xa, za), (xb, zb) = pts
            # Clip to [x0, x1].
            def clip(xa, za, xb, zb):
                if xa < x0:
                    za = za + (x0 - xa) * (zb - za) / (xb - xa)
                    xa = x0
                if xa > x1:
                    za = za + (x1 - xa) * (zb - za) / (xb - xa)
                    xa = x1
                return xa, za
            xa, za = clip(xa, za, xb, zb)
            xb, zb = clip(xb, zb, xa, za)
            if abs(xb - xa) > 0.05:
                cyl(mesh, (xa, 0, za), (xb, 0, zb), 0.008, sides=3)
        c += sp
    part(mesh, "mesh", "gunmetal")
    wire = new_bm()
    k = 0
    x = -L * 0.5 + 0.1
    while x < L * 0.5:
        _ring_x(wire, (x, 0, Hm + 0.42), 0.3, 0.012, sides=9, yaw=18 if k % 2 else -18)
        x += 0.16
        k += 1
    part(wire, "razor", "gunmetal")
    solid((0, 0, 1.5), (L, 0.15, 3.0))
    footprint(L + 0.3, 1.0)
    export(name)


def mil_camo_shelter(name, seed):
    """A camo net draped over poles above a vehicle bay, 8 x 6: 3.0 m at the
    edge poles, 3.7 at the two ridge poles, the net's skirt dropping to about
    2.2 at its sides, guyed to pegs. Crates and jerry cans along the back,
    room for a vehicle in front."""
    begin(name)
    rng = random.Random(seed)
    poles = new_bm()
    pts = [(-3.8, -2.8, 3.0), (0.0, -2.8, 3.0), (3.8, -2.8, 3.0), (-3.8, 2.8, 3.0), (0.0, 2.8, 3.0), (3.8, 2.8, 3.0), (-2.0, 0.0, 3.7), (2.0, 0.0, 3.7)]
    for x, y, h in pts:
        tapered_tube(poles, [(x, y, 0), (x, y, h - 0.05)], [0.05, 0.04], sides=5)
        column((x, y, 0), 0.08, h)
        tbox(poles, (x, y, h - 0.05), (0.35, 0.35, 0.04))
    tbox(poles, (0, 0, 3.66), (4.2, 0.05, 0.05))
    for x, y, h in pts[:6]:
        sx = 1 if x > 0 else (-1 if x < 0 else 0)
        sy = 1 if y > 0 else -1
        peg = (x + sx * 1.6, y + sy * 1.4, 0.0)
        cyl(poles, (x, y, h - 0.2), peg, 0.01, sides=3)
        tbox(poles, (peg[0], peg[1], 0.08), (0.06, 0.06, 0.2))
    part(poles, "poles", "gunmetal")
    # The net: a sagging sheet over the poles, skirts drooping at the edges.
    xs = [-4.6 + 9.2 * i / 23 for i in range(24)]
    ys = [-3.6 + 7.2 * j / 18 for j in range(19)]
    grid = []
    for y in ys:
        row = []
        for x in xs:
            ay = abs(y)
            z = 3.68 - 0.62 * min(1.0, ay / 2.8) ** 1.3
            # Sag between the edge poles, lifted near the ridge poles.
            z -= 0.18 * math.sin(math.pi * x / 3.8) ** 2 * min(1.0, ay / 2.8)
            z -= 0.25 * (1.0 - min(1.0, abs(abs(x) - 2.0) / 2.0)) * 0.0
            if ay > 2.8:
                z -= (ay - 2.8) * 1.0
            if abs(x) > 3.8:
                z -= (abs(x) - 3.8) * 1.0
            z += rng.uniform(-0.05, 0.05)
            row.append(Vector((x, y, z)))
        grid.append(row)
    net = new_bm()
    _sheet(net, grid, double=True)
    # A few scrap tufts hanging off the skirt.
    for k in range(10):
        x = rng.uniform(-4.4, 4.4)
        s = rng.choice((-1, 1))
        blob(net, (x, s * 3.55, 2.15), (0.3, 0.08, 0.25), rng, subdiv=1, wobble=0.3, seed=seed + k)
    part(net, "net", "camo")
    olive = new_bm()
    for x, z, sz in ((-2.4, 0.4, (1.2, 0.8, 0.8)), (-2.4, 1.2, (1.2, 0.8, 0.8)), (-1.1, 0.4, (1.2, 0.8, 0.8))):
        sbox(olive, (x, 2.0, z), sz)
    for k in range(5):
        tbox(olive, (2.2 + k * 0.24, 2.3, 0.3), (0.18, 0.45, 0.6))  # jerry cans
    solid((2.7, 2.3, 0.3), (1.3, 0.5, 0.6))
    part(olive, "crates", "olive")
    wood = new_bm()
    sbox(wood, (2.7, 2.3, 0.06), (1.4, 1.0, 0.12))
    part(wood, "pallet", "wood")
    tarp = new_bm()
    blob(tarp, (0.4, 2.1, 0.45), (0.8, 0.55, 0.5), rng, subdiv=1, wobble=0.15, seed=seed + 50)
    solid((0.4, 2.1, 0.45), (1.4, 1.0, 0.9))
    part(tarp, "tarp", "canvas")
    paint = new_bm()
    _stencil(paint, "16", (-2.4, 1.59, 1.2), (0, -1), 0.4)
    _stencil(paint, "08", (-1.1, 1.59, 0.4), (0, -1), 0.4)
    part(paint, "stencil", "canvas")
    footprint(9.4, 8.0)
    export(name)


def mil_searchlight(name):
    """A searchlight on a two-wheeled trailer: a big lamp drum (0.8 across)
    on a yoke, aimed toward -Y and a little up, about 2.4 high, outrigger
    legs, a tow bar, a control box."""
    begin(name)
    steel = new_bm()
    tbox(steel, (0, 0, 0.55), (1.5, 0.9, 0.12))
    tbox(steel, (-1.05, 0, 0.5), (0.8, 0.1, 0.08))
    tbox(steel, (-1.45, 0, 0.3), (0.06, 0.06, 0.45))
    for sx in (-1, 1):
        for sy in (-1, 1):
            cyl(steel, (sx * 0.7, sy * 0.4, 0.5), (sx * 1.0, sy * 0.75, 0.05), 0.035, sides=4)
            tbox(steel, (sx * 1.0, sy * 0.75, 0.03), (0.18, 0.18, 0.06))
    tapered_tube(steel, [(0.15, 0, 0.6), (0.15, 0, 1.45)], [0.14, 0.11], sides=8)
    tbox(steel, (0.15, 0, 1.5), (0.95, 0.3, 0.1))
    for s in (-1, 1):
        tbox(steel, (0.15 + s * 0.47, 0, 1.8), (0.06, 0.2, 0.6))
    part(steel, "frame", "gunmetal")
    tyre, hub = new_bm(), new_bm()
    for s in (-1, 1):
        _wheel(tyre, hub, (0.1, s * 0.58, 0.33), 0.33, 0.2)
    part(tyre, "tyres", "shadow")
    part(hub, "hubs", "gunmetal")
    olive = new_bm()
    tilt = math.radians(18)
    d = Vector((0, -math.cos(tilt), math.sin(tilt)))
    c = Vector((0.15, 0, 1.85))
    tapered_tube(olive, [c - d * 0.4, c + d * 0.35], [0.36, 0.4], sides=14)
    tapered_tube(olive, [c + d * 0.35, c + d * 0.42], [0.44, 0.44], sides=14)
    tapered_tube(olive, [c - d * 0.55, c - d * 0.4], [0.24, 0.32], sides=14)
    for s in (-1, 1):
        cyl(olive, (0.15 + s * 0.43, 0, 1.85), (0.15 + s * 0.5, 0, 1.85), 0.08, sides=6)
    tbox(olive, (-0.55, 0.2, 0.85), (0.4, 0.3, 0.5))
    part(olive, "lamp", "olive")
    lens = new_bm()
    tapered_tube(lens, [c + d * 0.42, c + d * 0.44], [0.38, 0.38], sides=14)
    part(lens, "lens", "light")
    amb = new_bm()
    tbox(amb, (-0.55, 0.04, 0.95), (0.15, 0.03, 0.08))
    part(amb, "panel_amber", "neon")
    solid((0, 0, 1.1), (1.6, 1.3, 2.2))
    footprint(3.0, 1.8)
    export(name)


def mil_generator(name):
    """A trailer-mounted diesel generator, 3.2 L x 1.8 W: an olive enclosure
    with louvres and a control panel (green and amber lamps), an exhaust stack
    to 2.4, a tow bar, cables run out along the ground."""
    begin(name)
    steel = new_bm()
    tbox(steel, (0.2, 0, 0.62), (2.7, 1.3, 0.14))
    tbox(steel, (-1.35, 0, 0.55), (0.6, 0.1, 0.08))
    cyl(steel, (-1.15, -0.5, 0.6), (-1.6, 0, 0.55), 0.04, sides=4)
    cyl(steel, (-1.15, 0.5, 0.6), (-1.6, 0, 0.55), 0.04, sides=4)
    tbox(steel, (-1.45, 0, 0.3), (0.07, 0.07, 0.5))
    for s in (-1, 1):
        tbox(steel, (1.4, s * 0.55, 0.3), (0.07, 0.07, 0.55))
    # Exhaust.
    cyl(steel, (1.15, 0.35, 1.9), (1.15, 0.35, 2.35), 0.07, sides=8)
    tbox(steel, (1.15, 0.27, 2.38), (0.18, 0.18, 0.03), tilt=-25)
    tbox(steel, (0.3, 0, 1.92), (2.3, 1.3, 0.06))
    for x in (-0.6, 0.3, 1.2):
        tbox(steel, (x, 0, 1.97), (0.15, 1.0, 0.05))  # lifting rails
    part(steel, "frame", "gunmetal")
    tyre, hub = new_bm(), new_bm()
    for s in (-1, 1):
        _wheel(tyre, hub, (0.2, s * 0.78, 0.38), 0.38, 0.24)
    part(hub, "hubs", "gunmetal")
    olive = new_bm()
    sbox(olive, (0.3, 0, 1.3), (2.2, 1.2, 1.2))
    for s in (-1, 1):
        tbox(olive, (0.2, s * 0.78, 0.82), (0.95, 0.32, 0.06))  # fenders
    part(olive, "enclosure", "olive")
    dark = tyre
    for s in (-1, 1):
        for k in range(5):
            tbox(dark, (0.9 + 0.0, s * 0.61, 1.0 + k * 0.12), (0.7, 0.03, 0.05))
    tbox(dark, (-0.79, 0, 1.3), (0.03, 0.9, 0.8))  # panel recess
    for k in range(3):
        tapered_tube(dark, [(-0.8, -0.3 + k * 0.2, 0.95), (-1.0, -0.4 + k * 0.25, 0.4), (-1.3, -0.6 - k * 0.2, 0.05), (-2.0 + k * 0.15, -0.8 - k * 0.15, 0.04)], [0.035] * 4, sides=4)
    ring(dark, (-1.9, -0.75, 0.05), 0.3, 0.035, sides=8)
    part(dark, "tyres", "shadow")
    lit = new_bm()
    tbox(lit, (-0.82, 0.2, 1.5), (0.03, 0.35, 0.22))
    part(lit, "dial", "light")
    grn, amb = new_bm(), new_bm()
    tbox(grn, (-0.82, -0.2, 1.55), (0.03, 0.08, 0.08))
    tbox(amb, (-0.82, -0.35, 1.55), (0.03, 0.08, 0.08))
    part(grn, "panel_green", "neon")
    part(amb, "panel_amber", "neon")
    paint = new_bm()
    _stencil(paint, "60", (-0.15, -0.62, 1.55), (0, -1), 0.3)
    _stencil(paint, "60", (-0.15, 0.62, 1.55), (0, 1), 0.3)
    part(paint, "stencil", "canvas")
    solid((0.2, 0, 1.0), (2.8, 1.7, 2.0))
    footprint(3.6, 2.2)
    export(name)


def mil_footlockers(name, seed):
    """Two olive footlockers stacked with ammo cans on top and beside them,
    about 2 x 1.2, 1.1 high: low cover."""
    begin(name)
    rng = random.Random(seed)
    olive = new_bm()
    steel = new_bm()
    paint = new_bm()
    sbox(olive, (-0.35, 0, 0.21), (1.0, 0.55, 0.42))
    tbox(olive, (-0.35, 0, 0.43), (1.04, 0.59, 0.04))
    yaw = rng.uniform(-6, 6)
    sbox(olive, (-0.32, 0.03, 0.64), (0.95, 0.52, 0.4), yaw=yaw)
    tbox(olive, (-0.32, 0.03, 0.85), (0.99, 0.56, 0.04), yaw=yaw)
    for z, yy in ((0.21, 0.0), (0.64, 0.03)):
        for d in (-0.3, 0.3):
            tbox(steel, (-0.35 + d, yy - 0.29, z + 0.05), (0.08, 0.03, 0.1))
        for s in (-1, 1):
            tbox(steel, (-0.35 + s * 0.52, yy, z), (0.04, 0.15, 0.05))
        tbox(paint, (-0.35, yy - 0.285, z - 0.07), (0.5, 0.02, 0.07))
    # Ammo cans: two on top, a row beside.
    for k, (x, y, z, yw) in enumerate(((-0.55, 0.0, 0.97, 90), (-0.15, 0.05, 0.97, 85), (0.5, -0.25, 0.13, 0), (0.5, 0.0, 0.13, 3), (0.5, 0.25, 0.13, -4), (0.5, 0.0, 0.39, 10), (0.85, 0.1, 0.13, 70))):
        tbox(olive, (x, y, z), (0.3, 0.16, 0.24), yaw=yw)
        tbox(steel, (x, y, z + 0.13), (0.14, 0.04, 0.02), yaw=yw)
    solid((-0.2, 0.0, 0.55), (1.3, 0.6, 1.1))
    solid((0.65, 0.0, 0.25), (0.7, 0.8, 0.5))
    part(olive, "lockers", "olive")
    part(steel, "latches", "gunmetal")
    _stencil(paint, "37", (0.05, -0.29, 0.25), (0, -1), 0.13, depth=0.015)
    _stencil(paint, "08", (0.06, -0.262, 0.68), (0, -1), 0.13, depth=0.015)
    part(paint, "stencil", "canvas")
    footprint(2.0, 1.2)
    export(name)


def mil_sandbag_wall(name, seed):
    """A straight-ish sandbag wall, 4 m long, 1.2 high, bowed slightly
    forward (-Y), two bags thick at the bottom: low cover."""
    begin(name)
    rng = random.Random(seed)
    R = 8.0
    span = 4.0 / R
    def at(t, off):
        a = t * span * 0.5
        return (R * math.sin(a), -R * math.cos(a) + R * math.cos(span * 0.5) - 0.12 + off * math.cos(a), math.degrees(a))
    bags = new_bm()
    for row in range(4):
        z = 0.15 + row * 0.29
        offs = (-0.2, 0.2) if row < 2 else (0.0,)
        n = 7
        for off in offs:
            for k in range(n + (row % 2)):
                t = -1.0 + (k + (0.5 if row % 2 == 0 else 0.0)) * (2.0 / n)
                if t > 1.0 or t < -1.0:
                    continue
                x, y, yaw = at(t, off)
                _bag(bags, rng, (x, y, z), yaw + rng.uniform(-4, 4), size=(0.3, 0.19, 0.155), seed=seed + row * 40 + k + int(off * 10))
    part(bags, "bags", "canvas")
    for s in (-1, 1):
        x, y, yaw = at(s * 0.5, 0.0)
        solid((x, y, 0.6), (2.05, 0.6, 1.2), yaw=yaw)
    footprint(4.4, 1.2)
    export(name)


# =============================================================================
# Extras
# =============================================================================

def mil_artillery(name):
    """A towed howitzer, barrel toward -Y raised 15 degrees: two road wheels,
    a gun shield, split trails dug in behind with spades, a few rounds on a
    pallet. About 3.2 W x 7.8 L, 2.4 high at the muzzle."""
    begin(name)
    olive = new_bm()
    steel = new_bm()
    # Carriage and trails.
    tbox(olive, (0, 0.3, 0.6), (1.6, 0.6, 0.35))
    for s in (-1, 1):
        cyl(olive, (s * 0.35, 0.5, 0.6), (s * 1.3, 3.6, 0.15), 0.12, sides=4)
        tbox(olive, (s * 1.32, 3.7, 0.2), (0.6, 0.12, 0.5), tilt=-20)  # spades
    # Shield.
    tbox(olive, (0, -0.25, 1.25), (2.1, 0.08, 1.2), tilt=-10)
    for s in (-1, 1):
        tbox(olive, (s * 1.12, -0.05, 1.15), (0.08, 0.5, 1.0), yaw=s * 20)
    el = math.radians(15)
    d = Vector((0, -math.cos(el), math.sin(el)))
    p = Vector((0, 0.4, 1.15))
    # Cradle and recoil gear.
    c = p + d * 0.3
    tbox(olive, tuple(c), (0.45, 1.9, 0.4), tilt=-15)
    tbox(olive, tuple(p - d * 0.7), (0.35, 0.5, 0.35), tilt=-15)  # breech
    part(olive, "carriage", "olive")
    cyl(steel, p, p + d * 4.2, 0.09, sides=8)
    cyl(steel, p + d * 4.0, p + d * 4.35, 0.15, sides=8)
    for s in (-1, 1):
        cyl(steel, p + Vector((s * 0.12, 0, 0.27)), p + Vector((s * 0.12, 0, 0.27)) + d * 1.6, 0.06, sides=6)
    for s in (-1, 1):
        cyl(steel, (s * 0.85, 0.3, 0.6), (s * 1.2, 0.3, 0.6), 0.06, sides=6)
    part(steel, "barrel", "gunmetal")
    tyre, hub = new_bm(), new_bm()
    for s in (-1, 1):
        _wheel(tyre, hub, (s * 1.12, 0.3, 0.6), 0.6, 0.32, axis="x", sides=12)
    part(tyre, "tyres", "shadow")
    part(hub, "hubs", "gunmetal")
    wood = new_bm()
    sbox(wood, (1.9, 2.3, 0.07), (1.0, 0.8, 0.14))
    part(wood, "pallet", "wood")
    rounds = new_bm()
    tips = new_bm()
    for k in range(4):
        x = 1.6 + k * 0.2
        cyl(rounds, (x, 1.95, 0.24), (x, 2.55, 0.24), 0.08, sides=6)
        cyl(tips, (x, 1.95, 0.24), (x, 1.75, 0.24), 0.05, sides=6)
    part(rounds, "rounds", "gunmetal")
    part(tips, "tips", "canvas")
    paint = new_bm()
    _stencil(paint, "88", (0.55, -0.31, 1.5), (0, -1), 0.35)
    part(paint, "stencil", "canvas")
    solid((0, 0.3, 0.75), (2.6, 1.0, 1.5))
    solid((0, -0.25, 1.3), (2.2, 0.3, 1.2))
    for s in (-1, 1):
        solid((s * 0.85, 2.1, 0.35), (0.3, 3.0, 0.4), yaw=-s * 17)
    footprint(3.2, 8.0)
    export(name)


def mil_tent_large(name, seed):
    """A big frame tent, 8 L x 5 W: walls 1.8, ridge 3.4, the roof sagging a
    little between its frame arches, a lit doorway in the long front (-Y), flaps rolled up, guy ropes to pegs. The roof slopes
    (33 degrees) take colliders: run up and over it."""
    begin(name)
    rng = random.Random(seed)
    L, W, Hw, Hr = 8.0, 5.0, 1.8, 3.4
    cloth = new_bm()
    # Walls.
    for s in (-1, 1):
        sbox(cloth, (0, s * W * 0.5, Hw * 0.5), (L, 0.06, Hw))
    for s in (-1, 1):
        _extrude_x(cloth, [(-W * 0.5, 0.0), (W * 0.5, 0.0), (W * 0.5, Hw), (0.0, Hr), (-W * 0.5, Hw)], s * L * 0.5 - 0.03, s * L * 0.5 + 0.03)
        solid((s * L * 0.5, 0, Hw * 0.5), (0.1, W, Hw))
    # Roof: four bays per side, each a little lower in the middle.
    fly = new_bm()
    bays = 4
    for s in (-1, 1):
        p0 = (s * (W * 0.5 + 0.25), Hw - 0.15)
        p1 = (0.0, Hr)
        for k in range(bays):
            x = -L * 0.5 + L * (k + 0.5) / bays
            sag = rng.uniform(0.03, 0.08)
            # A roof panel: along X, sloping in YZ.
            ang = math.degrees(math.atan2(Hr - (Hw - 0.15), W * 0.5 + 0.25))
            tbox(fly, (x, s * (W * 0.5 + 0.25) * 0.5, (Hr + Hw - 0.15) * 0.5 - sag), (L / bays + 0.04, math.hypot(W * 0.5 + 0.25, Hr - Hw + 0.15), 0.05), tilt=-s * ang)
        solid((0, s * (W * 0.5 + 0.25) * 0.5, (Hr + Hw - 0.15) * 0.5 - 0.05), (L, math.hypot(W * 0.5 + 0.25, Hr - Hw + 0.15), 0.1), tilt=-s * ang)
    # Rolled door flaps over the front door.
    for d in (-0.75, 0.75):
        cyl(cloth, (d, -W * 0.5 - 0.08, 0.2), (d, -W * 0.5 - 0.08, Hw - 0.1), 0.09, sides=6)
    part(cloth, "canvas", "canvas")
    part(fly, "fly", "camo")
    steel = new_bm()
    for k in range(bays + 1):
        x = -L * 0.5 + L * k / bays
        for s in (-1, 1):
            cyl(steel, (x, s * W * 0.5, 0), (x, s * W * 0.5, Hw), 0.03, sides=4)
            ex = x + (0.04 if k == 0 else (-0.04 if k == bays else 0))
            cyl(steel, (ex, s * (W * 0.5 + 0.05), Hw), (ex, 0, Hr + 0.03), 0.03, sides=4)
            # Guy ropes to pegs.
            peg = (x, s * (W * 0.5 + 1.4), 0.0)
            cyl(steel, (x, s * (W * 0.5 + 0.25), Hw - 0.15), peg, 0.01, sides=3)
            tbox(steel, (peg[0], peg[1], 0.08), (0.05, 0.05, 0.2))
    cyl(steel, (-L * 0.5, 0, Hr + 0.03), (L * 0.5, 0, Hr + 0.03), 0.04, sides=4)
    cyl(steel, (L * 0.5 - 0.6, 1.0, Hr - 0.4), (L * 0.5 - 0.6, 1.0, Hr + 0.6), 0.06, sides=6)  # stovepipe
    part(steel, "frame", "gunmetal")
    dark = new_bm()
    tbox(dark, (0, -W * 0.5 - 0.035, 0.9), (1.3, 0.02, 1.8))
    part(dark, "doorway", "shadow")
    lit = new_bm()
    tbox(lit, (0, -W * 0.5 - 0.045, 0.7), (0.8, 0.02, 0.9))
    for x in (-2.5, 2.5):
        tbox(lit, (x, -W * 0.5 - 0.035, 1.2), (1.0, 0.02, 0.4))
    part(lit, "glow", "light")
    paint = new_bm()
    _stencil(paint, "05", (L * 0.5 + 0.035, 0, 1.0), (1, 0), 0.5)
    part(paint, "stencil", "shadow")
    footprint(L + 0.4, W + 3.0)
    export(name)


# =============================================================================

def build_all():
    mil_hangar("mil_hangar")
    mil_barracks("mil_barracks")
    mil_command("mil_command")
    mil_guard_tower("mil_guard_tower")
    mil_hesco_wall("mil_hesco_wall", 811)
    mil_t_wall("mil_t_wall", 812)
    mil_helipad("mil_helipad")
    mil_comms_tower("mil_comms_tower")
    mil_fuel_bladder("mil_fuel_bladder", 813)
    mil_apc("mil_apc")
    mil_aa_gun("mil_aa_gun", 814)
    mil_ammo_bunker("mil_ammo_bunker")
    mil_razor_fence("mil_razor_fence", 815)
    mil_camo_shelter("mil_camo_shelter", 816)
    mil_gate("mil_gate")
    mil_searchlight("mil_searchlight")
    mil_radar("mil_radar")
    mil_generator("mil_generator")
    mil_footlockers("mil_footlockers", 817)
    mil_sandbag_wall("mil_sandbag_wall", 818)
    mil_artillery("mil_artillery")
    mil_tent_large("mil_tent_large", 819)
