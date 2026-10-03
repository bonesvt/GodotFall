"""The high tech city's street kit: the megacorp's hard, cold downtown, Solace's
security-state cousin. Dark composite facades and glass curtain walls, cyan,
pink and amber neon, holo ads, security walls and checkpoints, maglev
viaducts and monorail, drones docked on their pylons.

Run by tools/procgen/build_kits.py (python3 tools/procgen/build_kits.py city),
which execs this file in tools/procgen/build_props.py's namespace: begin,
sbox, tbox, solid, column, top, hook_block, footprint, part, export and the
rest are its helpers. Writes assets/models/city/<id>.glb.

  buildings: a 30 m tower with a balcony deck to grapple to, a two-storey
    shopfront with a fire escape to its roof, a three-storey apartment block
    (grapple its roof mast), a stepped plaza with a corp obelisk
  movement: an elevated road viaduct with stairs, a holo ad wall and a
    security wall to wallrun, a drone pylon, a monorail span with a hook
    under it, a billboard tower with a catwalk
  yard: a security checkpoint with a scanner gate and a guard booth
  props: tram stop, barricade, hover car, noodle kiosk, holo-tree planter,
    streetlight, ad pillar, dumpster, HVAC cluster, traffic light

Neon parts are "<part>_<colour>__neon"; the game lights them in that colour.
"""
import math
import random

import bmesh
from mathutils import Matrix, Vector


# =============================================================================
# Kit helpers
# =============================================================================

class _Parts:
    """One bmesh per (part, material), made on first use and turned into
    objects in order by done(). Empty ones are dropped."""

    def __init__(self):
        self.bms = {}

    def __call__(self, name, mat):
        key = (name, mat)
        if key not in self.bms:
            self.bms[key] = new_bm()
        return self.bms[key]

    def neon(self, name, colour):
        return self(f"{name}_{colour}", "neon")

    def done(self):
        for (name, mat), bm in self.bms.items():
            if len(bm.faces):
                part(bm, name, mat)
            else:
                bm.free()
        self.bms = {}


def _flight(bm, p0, p1, width, thick=0.3, rise=0.26, rail=0):
    """A flight of stairs whose walking line runs from p0 up to p1: a tilted
    collider slab (like the blockhouse's), saw-tooth treads on it, stringers
    down both sides and, if `rail` is -1 or 1, a handrail on that side."""
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    horiz = math.hypot(d.x, d.y)
    length = d.length
    yaw = math.degrees(math.atan2(-d.x, d.y))
    tilt = math.degrees(math.atan2(d.z, horiz))
    rot = Matrix.Rotation(math.radians(yaw), 3, "Z") @ Matrix.Rotation(math.radians(tilt), 3, "X")
    up = rot @ Vector((0, 0, 1))
    side = rot @ Vector((1, 0, 0))
    mid = (p0 + p1) * 0.5
    sbox(bm, mid - up * (thick * 0.5), (width, length, thick), yaw, tilt)
    n = max(2, round(d.z / rise))
    for k in range(n):
        t = (k + 0.5) / n
        c = p0 + d * t
        tbox(bm, (c.x, c.y, p0.z + d.z * (k + 0.5) / n), (width - 0.1, horiz / n, d.z / n), yaw)
    for s in (-1, 1):
        tbox(bm, mid - up * 0.2 + side * s * (width * 0.5 + 0.04), (0.08, length + 0.1, 0.4), yaw, tilt)
    if rail:
        rs = side * rail * (width * 0.5 + 0.04)
        tbox(bm, mid + rs + Vector((0, 0, 1.0)), (0.06, length, 0.06), yaw, tilt)
        for t in (0.0, 0.5, 1.0):
            c = p0 + d * t + rs
            tbox(bm, (c.x, c.y, c.z + 0.5), (0.06, 0.06, 1.0))


def _rail(bm, a, b, h=1.0, step=1.2):
    """A handrail from a to b (both at deck level), posts every `step` m."""
    a, b = Vector(a), Vector(b)
    d = b - a
    n = max(1, round(d.length / step))
    yaw = math.degrees(math.atan2(-d.x, d.y))
    m = (a + b) * 0.5
    tbox(bm, (m.x, m.y, m.z + h), (0.06, d.length, 0.06), yaw)
    tbox(bm, (m.x, m.y, m.z + h * 0.5), (0.03, d.length, 0.03), yaw)
    for k in range(n + 1):
        c = a + d * (k / n)
        tbox(bm, (c.x, c.y, c.z + h * 0.5), (0.06, 0.06, h))


def _hull(bm, pts):
    """The convex hull of `pts` (a car body, a wedge), merged into bm."""
    tmp = bmesh.new()
    vs = [tmp.verts.new(Vector(p)) for p in pts]
    bmesh.ops.convex_hull(tmp, input=vs)
    _merge(bm, tmp)


def _prism(bm, n, r, z0, z1, x=0.0, y=0.0, rot=None):
    """An n-sided upright prism; with the default `rot` a face looks along +X."""
    rot = -math.pi / n if rot is None else rot
    lo = [bm.verts.new((x + math.cos(rot + 2 * math.pi * k / n) * r, y + math.sin(rot + 2 * math.pi * k / n) * r, z0)) for k in range(n)]
    hi = [bm.verts.new((x + math.cos(rot + 2 * math.pi * k / n) * r, y + math.sin(rot + 2 * math.pi * k / n) * r, z1)) for k in range(n)]
    for k in range(n):
        j = (k + 1) % n
        bm.faces.new((lo[k], lo[j], hi[j], hi[k]))
    bm.faces.new(list(reversed(lo)))
    bm.faces.new(hi)


def _ring_y(bm, center, radius, tube, sides=10):
    """An upright ring in the XZ plane (an emblem on a face that looks along Y)."""
    c = Vector(center)
    for k in range(sides):
        a0 = 2 * math.pi * k / sides
        a1 = 2 * math.pi * (k + 1) / sides
        cyl(bm, c + Vector((math.cos(a0) * radius, 0, math.sin(a0) * radius)),
            c + Vector((math.cos(a1) * radius, 0, math.sin(a1) * radius)), tube, sides=4)


def _diag(bm, center, width, length, ang):
    """A thin stripe lying on a face that looks along Y, slanted `ang` degrees
    in the XZ plane (hazard chevrons)."""
    tbox(bm, center, (0.02, width, length), yaw=90, tilt=ang)


def _hazard(bm, x0, x1, y, z, h, step=0.36):
    """Slanted hazard stripes from x0 to x1 on a face at y, centred at z."""
    x = x0 + step * 0.5
    while x < x1 - step * 0.25:
        _diag(bm, (x, y, z), 0.12, h * 1.3, 45)
        x += step


def _seams(bm, x0, x1, y, z0, z1, step, w=0.06, t=0.03):
    """Raised panel seams (vertical strips) on a face that looks along Y."""
    n = max(1, round((x1 - x0) / step))
    for k in range(1, n):
        x = x0 + (x1 - x0) * k / n
        tbox(bm, (x, y, (z0 + z1) * 0.5), (w, t, z1 - z0))


def _seams_y(bm, y0, y1, x, z0, z1, step, w=0.06, t=0.03):
    """Raised panel seams on a face that looks along X."""
    n = max(1, round((y1 - y0) / step))
    for k in range(1, n):
        y = y0 + (y1 - y0) * k / n
        tbox(bm, (x, y, (z0 + z1) * 0.5), (t, w, z1 - z0))


def _ac_unit(bm, dark, center, facing=-1):
    """A wall-hung air conditioner: a box with a fan disc on its face. `facing`
    is the Y direction its face looks."""
    c = Vector(center)
    tbox(bm, c, (0.9, 0.55, 0.65), bevel=0.03)
    tbox(bm, c + Vector((0, -facing * 0.15, -0.42)), (0.7, 0.12, 0.2))  # bracket
    cyl(dark, c + Vector((0.1, facing * 0.27, 0)), c + Vector((0.1, facing * 0.3, 0)), 0.22, sides=8)


def _fan_top(steel, dark, center, r):
    """A fan in a round guard, looking up: dark well, four blades, a ring."""
    c = Vector(center)
    tapered_tube(dark, [c, c + Vector((0, 0, 0.03))], [r, r], sides=12)
    for k in range(4):
        tbox(steel, c + Vector((0, 0, 0.06)), (r * 1.7, 0.12, 0.03), yaw=k * 45 + 20, tilt=12)
    ring(steel, c + Vector((0, 0, 0.1)), r, 0.03, sides=12)
    tbox(steel, c + Vector((0, 0, 0.1)), (r * 2, 0.04, 0.04))
    tbox(steel, c + Vector((0, 0, 0.1)), (0.04, r * 2, 0.04))


def _drone(steel, glow, center, yaw=0.0):
    """A small security drone: a wedge pod, four rotor rings, a glowing eye
    on its front (which looks along -Y turned by `yaw`)."""
    c = Vector(center)
    rot = Matrix.Rotation(math.radians(yaw), 3, "Z")
    pts = [(-0.3, -0.35, -0.1), (0.3, -0.35, -0.1), (-0.3, 0.35, -0.1), (0.3, 0.35, -0.1),
           (-0.22, -0.28, 0.14), (0.22, -0.28, 0.14), (-0.22, 0.3, 0.12), (0.22, 0.3, 0.12),
           (0, -0.45, 0.0), (0, 0.4, -0.16)]
    _hull(steel, [c + rot @ Vector(p) for p in pts])
    for sx in (-1, 1):
        for sy in (-1, 1):
            o = c + rot @ Vector((sx * 0.48, sy * 0.42, 0.06))
            ring(steel, o, 0.2, 0.025, sides=8)
            cyl(steel, c + rot @ Vector((sx * 0.25, sy * 0.25, 0.04)), o, 0.03, sides=4)
    tbox(glow, c + rot @ Vector((0, -0.37, 0.02)), (0.28, 0.04, 0.08), yaw=yaw)


# =============================================================================
# Buildings
# =============================================================================

def city_tower(name):
    """A corp high-rise, 12 W x 10 D, roof at 30.5: glass curtain faces between
    charcoal corner columns and floor bands, a neon blade sign down the front,
    a lit lobby with a canopy. A cantilevered balcony deck (top at 9.0) sticks
    3.3 m out of the front with an orange hook on an arm 3.6 m above it:
    grapple up, drop onto the deck (the reward spot). Roof: penthouse plant
    room, AC units, a 10 m antenna with a red beacon."""
    begin(name)
    P = _Parts()
    fac = P("shell", "facade")
    glass = P("glass", "curtain")
    steel = P("steel", "gunmetal")
    dark = P("dark", "shadow")
    lit = P("lobby", "light")
    # Body: one collider for the whole tower.
    solid((0, 0, 15.25), (12.0, 10.0, 30.5))
    tbox(fac, (0, 0, 2.0), (11.8, 9.8, 4.0))
    tbox(glass, (0, 0, 17.0), (11.6, 9.6, 26.0))
    for sx in (-1, 1):
        for sy in (-1, 1):
            tbox(fac, (sx * 5.45, sy * 4.45, 15.15), (1.3, 1.3, 30.3))
    for k in range(8):
        z = 4.0 + k * 3.25
        tbox(fac, (0, 0, z), (12.0, 10.0, 0.35))
    # Vertical fins over the glass.
    for k in range(8):
        x = -4.2 + k * 1.2
        for s in (-1, 1):
            tbox(fac, (x, s * 4.85, 17.0), (0.1, 0.22, 26.0))
    for k in range(6):
        y = -3.25 + k * 1.3
        for s in (-1, 1):
            tbox(fac, (s * 5.85, y, 17.0), (0.22, 0.1, 26.0))
    # Crown.
    tbox(fac, (0, 0, 30.25), (12.6, 10.6, 0.5))
    for s in (-1, 1):
        tbox(fac, (0, s * 5.2, 30.62), (12.6, 0.2, 0.25))
        tbox(fac, (s * 6.2, 0, 30.62), (0.2, 10.6, 0.25))
    tbox(fac, (-1.2, 1.4, 32.0), (6.4, 5.0, 3.0))
    tbox(fac, (-1.2, 1.4, 33.6), (6.8, 5.4, 0.25))
    # Lobby: doors, glazing, canopy.
    tbox(dark, (-1.5, -4.93, 1.4), (3.2, 0.06, 2.8))
    for x in (-2.3, -0.7):
        tbox(steel, (x, -4.97, 1.4), (0.08, 0.04, 2.8))
    for x in (-4.4, 2.6):
        tbox(lit, (x, -4.93, 1.9), (2.4, 0.06, 2.6))
    tbox(fac, (-1.5, -5.8, 3.4), (5.0, 1.8, 0.25))
    for x in (-3.6, 0.6):
        cyl(steel, (x, -6.4, 3.3), (x, -5.0, 4.4), 0.05, sides=4)
    # Neon blade sign down the front (left), edge strips on the corners.
    tbox(fac, (-4.0, -5.65, 19.5), (0.35, 1.3, 13.0))
    for z in (13.5, 19.5, 25.5):
        tbox(steel, (-4.0, -5.15, z), (0.5, 0.3, 0.3))
    for s in (-1, 1):
        tbox(P.neon("blade", "pink"), (-4.0 + s * 0.19, -5.75, 19.5), (0.03, 0.95, 12.2))
    tbox(P.neon("edge", "cyan"), (-4.0, -6.32, 19.5), (0.2, 0.04, 12.8))
    for x in (-5.45, 5.45):
        tbox(P.neon("edge", "cyan"), (x, -5.12, 17.0), (0.16, 0.04, 26.0))
    tbox(P.neon("edge", "cyan"), (0, -5.32, 30.25), (12.0, 0.04, 0.12))
    tbox(P.neon("canopy", "amber"), (-1.5, -5.8, 3.26), (4.6, 1.4, 0.03))
    tbox(P.neon("logo", "pink"), (-1.2, -1.12, 32.2), (2.0, 0.04, 1.6))
    tbox(dark, (-1.2, -1.11, 32.2), (1.0, 0.05, 0.8))
    # Balcony deck, cantilevered on braces, and the hook arm over it.
    bal = P("balcony", "gunmetal")
    sbox(bal, (1.8, -6.525, 8.85), (6.0, 3.35, 0.3))
    for x in (-0.9, 1.8, 4.5):
        cyl(bal, (x, -5.0, 6.9), (x, -7.6, 8.7), 0.08, sides=5)
    _rail(bal, (-1.15, -8.15, 9.0), (4.75, -8.15, 9.0))
    for x in (-1.15, 4.75):
        _rail(bal, (x, -5.1, 9.0), (x, -8.15, 9.0))
    tbox(P.neon("deck", "cyan"), (1.8, -8.22, 8.85), (6.0, 0.04, 0.14))
    tbox(lit, (1.8, -4.82, 10.4), (2.0, 0.04, 2.6))
    orange = P("hook", "anchor")
    tbox(bal, (1.8, -6.25, 13.25), (0.3, 2.7, 0.3))
    cyl(bal, (1.8, -5.0, 11.6), (1.8, -6.6, 13.1), 0.08, sides=5)
    hook_block(bal, orange, (1.8, -7.4, 12.6), 1.2)
    # Roof clutter: AC units, antenna with a red beacon.
    for x, y in ((3.6, -2.6), (3.6, -0.6), (-4.4, -3.2)):
        tbox(steel, (x, y, 31.0), (1.6, 1.4, 1.0))
        _fan_top(steel, dark, (x, y, 31.5), 0.5)
    tapered_tube(steel, [(3.6, 2.8, 30.5), (3.6, 2.8, 40.0)], [0.22, 0.08], sides=6)
    for z in (33.0, 35.5, 38.0):
        tbox(steel, (3.6, 2.8, z), (1.4, 0.08, 0.08))
    tbox(P.neon("beacon", "red"), (3.6, 2.8, 40.15), (0.3, 0.3, 0.3))
    top((1.8, -6.6, 9.0))
    footprint(12.6, 16.6)
    P.done()
    export(name)


def city_shopfront(name):
    """A two-storey street block, 10 W x 8 D, flat roof at 7.1: a shop below
    (half-raised shutter, a glowing window, a pink neon sign over an awning),
    curtain-glass offices above. Steel fire-escape stairs climb its +X side,
    front to back to a landing at 3.5, then back to front to a top landing
    level with the roof. Low lips on three roof edges, none on the +X side."""
    begin(name)
    P = _Parts()
    fac = P("shell", "facade")
    glass = P("glass", "curtain")
    steel = P("steel", "gunmetal")
    dark = P("dark", "shadow")
    lit = P("window", "light")
    sbox(fac, (0, 0, 3.45), (10.0, 8.0, 6.9))
    sbox(fac, (0, 0, 7.0), (10.3, 8.3, 0.2))
    for s in (-1, 1):
        tbox(fac, (0, s * 4.075, 7.225), (10.3, 0.15, 0.25))
    tbox(fac, (-5.075, 0, 7.225), (0.15, 8.0, 0.25))
    tbox(fac, (0, 0, 4.0), (10.2, 8.2, 0.3))
    _seams(fac, -5.0, 5.0, 4.03, 0.0, 6.9, 2.0)
    _seams_y(fac, -4.0, 4.0, -5.03, 0.0, 3.85, 2.0)
    # Ground floor: shutter, window, door.
    tbox(dark, (-2.6, -4.03, 0.55), (3.4, 0.06, 1.1))
    tbox(P("shutter", "corrugated"), (-2.6, -4.06, 1.95), (3.4, 0.08, 1.7))
    tbox(steel, (-2.6, -4.15, 2.95), (3.7, 0.3, 0.3))
    for x in (-4.35, -0.85):
        tbox(steel, (x, -4.06, 1.4), (0.12, 0.1, 2.8))
    tbox(lit, (2.0, -4.03, 1.55), (3.4, 0.06, 1.9))
    for x in (0.9, 2.0, 3.1):
        tbox(steel, (x, -4.07, 1.55), (0.06, 0.04, 1.9))
    tbox(steel, (2.0, -4.12, 0.55), (3.6, 0.2, 0.1))
    tbox(dark, (4.4, 4.03, 1.1), (1.0, 0.06, 2.2))  # back door
    # Awning, sign board, blade sign.
    tbox(P("awning", "canvas"), (0, -4.65, 3.0), (9.0, 1.4, 0.08), tilt=15)
    for x in (-4.2, 0.0, 4.2):
        cyl(steel, (x, -4.0, 3.6), (x, -5.2, 3.18), 0.03, sides=4)
    tbox(P.neon("awning", "cyan"), (0, -5.34, 2.83), (9.0, 0.04, 0.06))
    tbox(fac, (0.8, -4.12, 3.55), (5.6, 0.24, 0.6))
    for k, w in enumerate((0.9, 0.5, 1.1, 0.7, 0.9)):
        tbox(P.neon("sign", "pink"), (-1.2 + k * 1.0, -4.25, 3.55), (w, 0.03, 0.26))
    tbox(fac, (-4.6, -4.65, 5.3), (0.3, 1.1, 2.4))
    tbox(steel, (-4.6, -4.1, 5.3), (0.4, 0.12, 2.0))
    for s in (-1, 1):
        tbox(P.neon("blade", "amber"), (-4.6 + s * 0.165, -4.7, 5.3), (0.03, 0.8, 2.1))
    # Upper floor: curtain glass strip on the front and -X side, fins.
    tbox(glass, (0.5, -4.03, 5.45), (8.0, 0.06, 2.1))
    tbox(glass, (-5.03, 0, 5.45), (0.06, 6.4, 2.1))
    for x in (-3.5, -1.5, 0.5, 2.5, 4.5):
        tbox(fac, (x, -4.1, 5.45), (0.12, 0.14, 2.3))
    _ac_unit(steel, dark, (-5.33, -2.0, 3.0), facing=-1)
    tbox(lit, (5.03, -1.0, 5.6), (0.06, 1.6, 0.8))
    # Roof: a HVAC box and a sign frame on the back edge.
    tbox(steel, (-2.5, 1.6, 7.6), (2.0, 1.4, 1.0))
    _fan_top(steel, dark, (-2.5, 1.6, 8.1), 0.5)
    solid((-2.5, 1.6, 7.6), (2.0, 1.4, 1.0))
    for x in (-1.6, 1.6):
        tbox(steel, (x, 3.75, 8.0), (0.15, 0.15, 1.8))
    sbox(fac, (0, 3.75, 8.9), (4.6, 0.25, 1.3))
    tbox(P.neon("roofsign", "cyan"), (0, 3.61, 8.9), (4.2, 0.03, 1.0))
    tbox(dark, (-0.8, 3.59, 8.95), (1.6, 0.03, 0.3))
    # Fire escape on +X: flight up toward +Y, landing, flight back toward -Y.
    fe = P("stairs", "gunmetal")
    _flight(fe, (5.75, -2.4, 0.0), (5.75, 2.6, 3.5), 1.2)
    sbox(fe, (6.35, 3.3, 3.35), (2.4, 1.4, 0.3))
    _flight(fe, (6.95, 2.6, 3.5), (6.95, -2.4, 7.0), 1.2, rail=1)
    sbox(fe, (6.35, -3.1, 6.85), (2.4, 1.4, 0.3))
    for x, y, h in ((7.5, 3.95, 3.5), (7.5, 2.65, 3.5), (5.2, 3.95, 3.5), (7.5, -3.75, 7.0), (5.2, -3.75, 7.0), (7.5, -2.45, 7.0)):
        tbox(fe, (x, y, h * 0.5), (0.12, 0.12, h))
        column((x, y, 0), 0.08, h)
    _rail(fe, (7.55, 2.65, 3.5), (7.55, 3.95, 3.5))
    _rail(fe, (5.2, 3.95, 3.5), (7.55, 3.95, 3.5))
    _rail(fe, (7.55, -3.75, 7.0), (7.55, -2.45, 7.0))
    _rail(fe, (5.2, -3.75, 7.0), (7.55, -3.75, 7.0))
    tbox(P("edge", "anchor"), (6.35, -3.81, 6.85), (2.4, 0.03, 0.12))
    # Sidewalk.
    tbox(P("walk", "pavers"), (0, -4.9, 0.04), (10.4, 1.8, 0.08))
    top((0, -0.8, 7.1))
    footprint(15.2, 10.8)
    P.done()
    export(name)


def city_apartment(name):
    """A narrow three-storey apartment block, 8 W x 7 D, roof at 10.1: lit
    windows, two small balconies, AC units on the facade, a neon blade sign on
    its corner. No stairs: grapple the orange hook on the roof mast (14 m)."""
    begin(name)
    P = _Parts()
    fac = P("shell", "facade")
    glass = P("glass", "curtain")
    steel = P("steel", "gunmetal")
    dark = P("dark", "shadow")
    lit = P("windows", "light")
    sbox(fac, (0, 0, 4.95), (8.0, 7.0, 9.9))
    sbox(fac, (0, 0, 10.0), (8.3, 7.3, 0.2))
    for s in (-1, 1):
        tbox(fac, (0, s * 3.575, 10.22), (8.3, 0.15, 0.24))
        tbox(fac, (s * 4.075, 0, 10.22), (0.15, 7.0, 0.24))
    for z in (3.3, 6.6):
        tbox(fac, (0, 0, z), (8.2, 7.2, 0.25))
    for s in (-1, 1):
        _seams_y(fac, -3.5, 3.5, s * 4.03, 0.0, 9.9, 1.75)
    _seams(fac, -4.0, 4.0, 3.53, 0.0, 9.9, 2.0)
    # Front windows: two per floor, alternately lit.
    for f, z in enumerate((1.75, 5.0, 8.3)):
        for k, x in enumerate((-1.6, 1.8)):
            if f == 0 and k == 0:
                continue
            m = lit if (f + k) % 2 == 0 else glass
            tbox(m, (x, -3.53, z), (2.0, 0.06, 1.6))
            tbox(steel, (x, -3.6, z - 0.85), (2.2, 0.2, 0.08))
    tbox(dark, (-1.6, -3.53, 1.1), (1.2, 0.06, 2.2))
    tbox(lit, (-1.6, -3.55, 2.45), (1.4, 0.04, 0.3))
    for s in (-1, 1):
        for z in (5.0, 8.3):
            tbox(glass, (s * 4.03, 0.6, z), (0.06, 2.4, 1.4))
    tbox(lit, (-4.03, 0.6, 1.75), (0.06, 2.4, 1.2))
    # Balconies at the second and third floors.
    for z in (3.3, 6.6):
        sbox(steel, (-1.6, -4.15, z - 0.1), (2.6, 1.3, 0.2))
        _rail(steel, (-2.9, -4.8, z), (-0.3, -4.8, z), 1.0, 0.65)
        for x in (-2.9, -0.3):
            _rail(steel, (x, -3.5, z), (x, -4.8, z), 1.0, 0.65)
    for x, z in ((1.8, 4.0), (1.8, 7.3), (-3.3, 9.2)):
        _ac_unit(steel, dark, (x, -3.88, z))
    # Drain pipe and conduit down the -X side.
    cyl(steel, (-4.12, 3.1, 0.0), (-4.12, 3.1, 10.1), 0.08, sides=6)
    cyl(steel, (-4.12, -3.1, 0.3), (-4.12, -3.1, 9.8), 0.05, sides=6)
    # Blade sign on the front right corner.
    tbox(fac, (3.6, -4.15, 6.0), (0.3, 1.2, 5.0))
    for z in (4.0, 8.0):
        tbox(steel, (3.6, -3.55, z), (0.4, 0.1, 0.3))
    for s in (-1, 1):
        tbox(P.neon("blade", "amber"), (3.6 + s * 0.165, -4.2, 6.0), (0.03, 0.9, 4.6))
    tbox(P.neon("edge", "cyan"), (3.6, -4.77, 6.0), (0.2, 0.04, 4.8))
    tbox(P.neon("door", "cyan"), (-1.6, -3.58, 2.25), (1.6, 0.04, 0.06))
    # Roof: water tank, dish, the hook mast.
    tapered_tube(steel, [(2.2, 1.8, 10.1), (2.2, 1.8, 11.6)], [0.8, 0.8], sides=10)
    FP["cone"](steel, (2.2, 1.8, 11.6), 0.85, 0.35, sides=10)
    column((2.2, 1.8, 10.1), 0.8, 1.6)
    tbox(steel, (1.0, -2.2, 10.6), (1.4, 1.0, 1.0))
    _fan_top(steel, dark, (1.0, -2.2, 11.1), 0.4)
    tapered_tube(steel, [(-2.8, 2.4, 10.1), (-2.8, 2.4, 13.3)], [0.22, 0.16], sides=6)
    tbox(steel, (-2.8, 2.4, 10.3), (0.7, 0.7, 0.4))
    column((-2.8, 2.4, 10.1), 0.22, 3.2)
    orange = P("hook", "anchor")
    hook_block(steel, orange, (-2.8, 2.4, 13.9), 1.2)
    tapered_tube(orange, [(-2.8, 2.4, 11.4), (-2.8, 2.4, 11.7)], [0.23, 0.22], sides=6)
    tbox(P("walk", "pavers"), (0, -4.6, 0.04), (8.4, 2.4, 0.08))
    top((0.6, -0.6, 10.1))
    footprint(8.6, 9.8)
    P.done()
    export(name)


def city_stairs_plaza(name):
    """A corporate plaza: a paved deck 10 W x 4 D at 2.4 m, a 5 m wide stair
    up its front, raised planters (1.2 m: cover, and a step) either side of the
    stair, benches on the deck and a 4.5 m corp obelisk with neon at its back."""
    begin(name)
    P = _Parts()
    con = P("plinth", "concrete")
    pav = P("paving", "pavers")
    fac = P("obelisk", "facade")
    steel = P("steel", "gunmetal")
    sbox(con, (0, 2.0, 1.15), (10.0, 4.0, 2.3))
    sbox(pav, (0, 2.0, 2.35), (10.0, 4.0, 0.1))
    _flight(pav, (0, -4.0, 0.0), (0, 0.0, 2.4), 5.0, rise=0.3)
    for s in (-1, 1):
        sbox(con, (s * 3.75, -2.0, 0.6), (2.5, 4.0, 1.2))
        tbox(P("soil", "dirt"), (s * 3.75, -2.0, 1.2), (2.1, 3.6, 0.06))
        tbox(con, (s * 2.55, -2.0, 1.25), (0.12, 4.0, 0.1))
        # Holo shrubs in the planters.
        rng = random.Random(611 + s)
        for k in range(3):
            y = -3.2 + k * 1.2
            cyl(P("stems", "wood"), (s * 3.75, y, 1.2), (s * 3.75, y, 1.7), 0.06, sides=5)
            blob(P.neon("shrub", "green"), (s * 3.75, y, 1.85), (0.45, 0.45, 0.32), rng, subdiv=1, wobble=0.15, seed=k + s)
    # Step nosings lit every other tread, and a lit edge on the deck.
    for k in range(1, 8, 2):
        tbox(P.neon("nosing", "white"), (0, -4.0 + k * 0.5 + 0.02, (k + 1) * 0.3 + 0.005), (4.8, 0.05, 0.02))
    tbox(P.neon("edge", "cyan"), (0, -0.02, 2.2), (10.0, 0.04, 0.1))
    # Benches and the obelisk.
    for x in (-3.4, 3.4):
        sbox(fac, (x, 2.6, 2.625), (2.0, 0.6, 0.45))
        tbox(P("seat", "wood"), (x, 2.6, 2.87), (2.0, 0.6, 0.04))
    sbox(fac, (0, 3.2, 4.65), (1.2, 1.2, 4.5))
    tbox(fac, (0, 3.2, 2.55), (1.6, 1.6, 0.3))
    FP["cone"](fac, (0, 3.2, 6.9), 0.85, 0.6, sides=4)
    for s in (-1, 1):
        tbox(P.neon("obelisk", "cyan"), (s * 0.45, 2.58, 4.65), (0.08, 0.04, 4.2))
    tbox(P.neon("logo", "pink"), (0, 2.58, 5.6), (0.6, 0.04, 0.6))
    for x in (-4.7, 4.7):
        tbox(steel, (x, 0.3, 2.9), (0.2, 0.2, 1.0))
        tbox(P.neon("bollard", "white"), (x, 0.3, 3.45), (0.22, 0.22, 0.1))
    top((0, 2.0, 2.4))
    footprint(10.4, 8.4)
    P.done()
    export(name)


# =============================================================================
# Movement pieces
# =============================================================================

def city_overpass(name):
    """An elevated road / maglev viaduct span, 16 m along X, 6 m wide, deck at
    6.5 on two big concrete piers. Low jersey lips along both sides (gaps at the
    ends and at the stair head), lit lane dashes, cyan edge lights. Stairs
    climb its -Y flank from the +X end: 3.25 m to a mid landing, then on up to
    a head landing that joins the deck's -X end."""
    begin(name)
    P = _Parts()
    con = P("structure", "concrete")
    steel = P("girders", "gunmetal")
    for x in (-4.5, 4.5):
        sbox(con, (x, 0, 2.8), (1.6, 3.2, 5.6), bevel=0.05)
        sbox(con, (x, 0, 5.3), (2.4, 5.0, 0.6))
        tbox(con, (x, 0, 0.2), (2.6, 4.2, 0.4))
        for s in (-1, 1):
            tbox(con, (x, s * 1.62, 2.8), (0.5, 0.06, 5.2))
    sbox(con, (0, 0, 6.0), (16.0, 6.0, 0.8))
    sbox(P("road", "asphalt"), (0, 0, 6.45), (15.96, 5.0, 0.1))
    # Jersey lips.
    for (x0, x1), y in (((-6.5, 6.5), 2.75), ((-5.3, 6.5), -2.75)):
        sbox(con, ((x0 + x1) * 0.5, y, 6.85), (x1 - x0, 0.5, 0.9))
        tbox(con, ((x0 + x1) * 0.5, y, 6.55), (x1 - x0, 0.7, 0.3))
        for x in (x0 + 0.6, x1 - 0.6):
            tbox(steel, (x, y, 7.6), (0.12, 0.12, 0.6))
            tbox(P.neon("post", "white"), (x, y, 7.95), (0.25, 0.25, 0.1))
        tbox(P.neon("lip", "amber"), ((x0 + x1) * 0.5, y - math.copysign(0.26, y), 7.1), (x1 - x0 - 0.2, 0.03, 0.08))
    for k in range(6):
        tbox(P.neon("lane", "white"), (-6.25 + k * 2.5, 0, 6.505), (1.2, 0.14, 0.01))
    for s in (-1, 1):
        tbox(P.neon("fascia", "cyan"), (0, s * 3.02, 6.05), (16.0, 0.04, 0.12))
        tbox(steel, (0, s * 1.8, 5.35), (16.0, 0.4, 0.5))
    for x in range(-7, 8, 2):
        tbox(steel, (x, 0, 5.5), (0.25, 5.4, 0.2))
    # Stairs up the -Y flank.
    st = P("stairs", "gunmetal")
    _flight(st, (6.8, -3.8, 0.0), (1.2, -3.8, 3.25), 1.6, rail=-1)
    sbox(st, (0.4, -3.8, 3.1), (1.6, 1.6, 0.3))
    _flight(st, (-0.4, -3.8, 3.25), (-5.6, -3.8, 6.5), 1.6, rail=-1)
    sbox(st, (-6.6, -3.8, 6.35), (2.0, 1.6, 0.3))
    _rail(st, (-5.6, -4.65, 6.5), (-7.6, -4.65, 6.5))
    _rail(st, (-7.6, -4.65, 6.5), (-7.6, -3.05, 6.5))
    _rail(st, (1.2, -4.65, 3.25), (-0.4, -4.65, 3.25))
    for x, y, h in ((1.1, -4.5, 3.0), (-0.3, -4.5, 3.0), (1.1, -3.1, 3.0), (-0.3, -3.1, 3.0), (-7.4, -4.5, 6.2), (-7.4, -3.1, 6.2), (-5.8, -4.5, 6.2)):
        tbox(st, (x, y, h * 0.5), (0.16, 0.16, h))
        column((x, y, 0), 0.1, h)
    tbox(P("edge", "anchor"), (-5.65, -3.8, 6.42), (0.1, 1.6, 0.16))
    top((0, 0, 6.5))
    footprint(16.4, 9.4)
    P.done()
    export(name)


def city_holo_wall(name):
    """A huge holo ad wall on a steel frame: a dark backing 13 m long, its
    faces from 0.8 to 5.8 m, glowing ad screens on both faces (pink, cyan,
    amber), projector hoods along the top. Blue trim top and bottom on both
    faces: run along it."""
    begin(name)
    P = _Parts()
    fac = P("backing", "facade")
    steel = P("frame", "gunmetal")
    sbox(fac, (0, 0, 3.3), (13.0, 0.5, 5.0))
    for x in (-6.65, 6.65):
        sbox(steel, (x, 0, 3.1), (0.3, 0.7, 6.2))
        tbox(steel, (x, 0, 0.1), (0.8, 2.2, 0.2))
    for x in (-3.0, 3.0):
        tbox(steel, (x, 0, 0.4), (0.4, 0.4, 0.8))
        tbox(steel, (x, 0, 0.08), (0.7, 2.2, 0.16))
        column((x, 0, 0), 0.25, 0.8)
        for s in (-1, 1):
            cyl(steel, (x, s * 1.0, 0.16), (x, s * 0.28, 0.85), 0.06, sides=4)
    tbox(steel, (0, 0, 5.92), (13.3, 0.7, 0.25))
    for x in (-4.5, -1.5, 1.5, 4.5):
        tbox(steel, (x, 0, 6.2), (0.8, 0.9, 0.3))
        for s in (-1, 1):
            tbox(P.neon("projector", "cyan"), (x, s * 0.46, 6.15), (0.6, 0.03, 0.08))
    # Screens: three per face, the colours turned round on the back.
    cols = ("pink", "cyan", "amber")
    rng = random.Random(631)
    for s, shift in ((-1, 0), (1, 1)):
        for k, x in enumerate((-4.2, 0.0, 4.2)):
            col = cols[(k + shift) % 3]
            y = s * 0.265
            tbox(P.neon("screen", col), (x, y, 3.3), (4.0, 0.03, 4.0))
            # Dark ad graphics on the screens: a logo, slogan bars.
            ys = s * 0.285
            tbox(P("ad", "shadow"), (x + rng.uniform(-0.8, 0.8), ys, 3.9), (1.4, 0.02, 1.4), bevel=0.0)
            tbox(P("ad", "shadow"), (x, ys, 2.0), (3.2, 0.02, 0.35))
            tbox(P.neon("text", "white"), (x - 0.4, ys, 2.6), (2.4, 0.02, 0.18))
        for x in (-2.1, 2.1):
            tbox(fac, (x, s * 0.27, 3.3), (0.2, 0.04, 4.2))
    trim = P("trim", "wallrun")
    for s in (-1, 1):
        for z in (0.95, 5.65):
            tbox(trim, (0, s * 0.265, z), (12.8, 0.03, 0.25))
    footprint(13.6, 2.4)
    P.done()
    export(name)


def city_security_wall(name):
    """A corporate security wall, 12 m long and 4.6 high: a concrete plinth to
    1 m with hazard stripes, charcoal composite panels above, red and pink
    neon warning strips, a corp emblem, a sensor coping with red lights and a
    camera on one end post. Blue trim top and bottom on both faces: run it."""
    begin(name)
    P = _Parts()
    con = P("plinth", "concrete")
    fac = P("panels", "facade")
    steel = P("steel", "gunmetal")
    sbox(con, (0, 0, 0.5), (12.0, 0.9, 1.0), bevel=0.04)
    sbox(fac, (0, 0, 2.8), (11.6, 0.5, 3.6))
    for x in (-6.0, 6.0):
        sbox(fac, (x, 0, 2.45), (0.4, 0.8, 4.9))
    for s in (-1, 1):
        _seams(fac, -5.8, 5.8, s * 0.26, 1.0, 4.6, 1.93)
    tbox(steel, (0, 0, 4.68), (12.0, 0.6, 0.16))
    tbox(steel, (0, 0, 4.86), (11.6, 0.2, 0.2))
    for k in range(12):
        tbox(P.neon("sensor", "red"), (-5.5 + k * 1.0, 0, 4.98), (0.12, 0.22, 0.06))
    # Camera on the +X post.
    tbox(steel, (6.0, -0.2, 5.05), (0.3, 0.3, 0.3))
    tbox(steel, (6.0, -0.5, 5.15), (0.35, 0.6, 0.3), tilt=-12)
    tbox(P.neon("lens", "red"), (6.0, -0.81, 5.08), (0.14, 0.03, 0.14))
    trim = P("trim", "wallrun")
    stripes = P("hazard", "anchor")
    for s in (-1, 1):
        for z in (1.2, 4.4):
            tbox(trim, (0, s * 0.265, z), (11.6, 0.03, 0.25))
        tbox(P.neon("warn", "red"), (0, s * 0.27, 1.8), (11.6, 0.03, 0.1))
        for k in range(6):
            tbox(P.neon("warn", "pink"), (-4.85 + k * 1.94, s * 0.27, 3.95), (0.9, 0.03, 0.14))
        # The emblem: a dark plate with a cyan ring.
        tbox(fac, (0, s * 0.29, 2.9), (1.4, 0.05, 1.4))
        _ring_y(P.neon("emblem", "cyan"), (0, s * 0.33, 2.9), 0.45, 0.05, sides=10)
        _hazard(stripes, -5.6, 5.6, s * 0.46, 0.7, 0.3)
    footprint(12.4, 1.8)
    P.done()
    export(name)


def city_drone_pylon(name):
    """A slim drone-charging pylon, hook on top at 11.6 m: a hexagonal shaft
    with cyan charge rings, two docking arms with security drones parked on
    their cradles, red blinkers on the head. Grapple roost / climb marker."""
    begin(name)
    P = _Parts()
    con = P("plinth", "concrete")
    fac = P("shaft", "facade")
    steel = P("steel", "gunmetal")
    sbox(con, (0, 0, 0.3), (2.2, 2.2, 0.6), bevel=0.05)
    tapered_tube(fac, [(0, 0, 0.6), (0, 0, 10.6)], [0.55, 0.38], sides=6)
    column((0, 0, 0), 0.55, 10.6)
    for z in (2.6, 4.6, 7.6, 9.6):
        r = 0.55 - (z - 0.6) * 0.017 + 0.03
        tapered_tube(P.neon("ring", "cyan"), [(0, 0, z), (0, 0, z + 0.12)], [r, r], sides=6)
    tbox(fac, (0, 0, 10.8), (1.3, 1.3, 0.4))
    for sx in (-1, 1):
        for sy in (-1, 1):
            tbox(P.neon("blink", "red"), (sx * 0.62, sy * 0.62, 11.05), (0.12, 0.12, 0.1))
    tbox(steel, (0, 0, 11.15), (0.3, 0.3, 0.3))
    orange = P("hook", "anchor")
    hook_block(steel, orange, (0, 0, 11.75), 1.1)
    # Docking arms with cradles and drones.
    eyes = P.neon("eye", "amber")
    for z, ang in ((5.6, -90.0), (8.4, 30.0)):
        a = math.radians(ang)
        d = Vector((math.cos(a), math.sin(a), 0))
        cyl(steel, (0, 0, z), d * 1.6 + Vector((0, 0, z)), 0.09, sides=5)
        cyl(steel, (0, 0, z - 0.8), d * 1.2 + Vector((0, 0, z - 0.05)), 0.05, sides=4)
        c = d * 1.75 + Vector((0, 0, z))
        tbox(fac, c, (0.8, 0.8, 0.12), yaw=ang)
        tbox(P.neon("pad", "cyan"), c + Vector((0, 0, 0.065)), (0.5, 0.5, 0.01), yaw=ang)
        _drone(steel, eyes, c + Vector((0, 0, 0.3)), yaw=ang + 90)
    tbox(P.neon("panel", "green"), (0, -0.56, 1.6), (0.3, 0.04, 0.5))
    tbox(steel, (0, -0.58, 1.6), (0.5, 0.05, 0.8))
    footprint(4.0, 4.0)
    P.done()
    export(name)


def city_monorail(name):
    """A monorail pier, 1.4 m square to its cap at 9 m, carrying a 14 m track
    beam (1.6 wide, top at 10.2: walkable) along X, power rails and cyan guide
    lights down its sides. An orange hook hangs under the beam's +X end at
    8.2 m: grapple it from the street and swing up onto the beam."""
    begin(name)
    P = _Parts()
    con = P("structure", "concrete")
    fac = P("cladding", "facade")
    steel = P("steel", "gunmetal")
    tbox(con, (0, 0, 0.2), (2.6, 2.6, 0.4))
    sbox(con, (0, 0, 4.1), (1.4, 1.4, 8.2))
    tbox(con, (0, 0, 7.8), (1.8, 2.6, 0.8))
    sbox(con, (0, 0, 8.6), (2.0, 3.0, 0.8))
    for s in (-1, 1):
        tbox(fac, (0, s * 0.72, 4.0), (1.1, 0.06, 6.0))
        tbox(fac, (s * 0.72, 0, 4.0), (0.06, 1.1, 6.0))
    tbox(P.neon("number", "amber"), (0, -0.76, 6.4), (0.5, 0.03, 0.5))
    tbox(P.neon("strip", "cyan"), (-0.4, -0.76, 4.0), (0.08, 0.03, 5.2))
    cyl(steel, (0.75, 0.5, 0.4), (0.75, 0.5, 8.2), 0.08, sides=5)
    for x in (-0.5, 0.5):
        tbox(steel, (x, 0, 9.05), (0.6, 1.4, 0.1))
    # The beam.
    sbox(con, (0, 0, 9.6), (14.0, 1.6, 1.2))
    tbox(con, (0, 0, 9.12), (14.0, 1.1, 0.25))
    for s in (-1, 1):
        tbox(steel, (0, s * 0.85, 9.35), (14.0, 0.1, 0.2))
        tbox(P.neon("guide", "cyan"), (0, s * 0.815, 9.85), (14.0, 0.03, 0.08))
    tbox(steel, (0, 0, 10.24), (14.0, 0.3, 0.08))
    for x in (-6.9, 6.9):
        tbox(steel, (x, 0, 9.6), (0.15, 1.65, 1.25))
    # Hook under the +X end.
    orange = P("hook", "anchor")
    tbox(steel, (5.8, 0, 8.85), (0.25, 0.25, 0.4))
    tbox(steel, (5.8, 0, 9.0), (0.8, 1.2, 0.08))
    hook_block(steel, orange, (5.8, 0, 8.2), 1.1)
    top((0, 0, 10.2))
    footprint(14.0, 3.2)
    P.done()
    export(name)


def city_billboard_tower(name):
    """A billboard tower: a charcoal shaft to a double-sided neon billboard
    (6 x 3.2, from 9.8 to 13 m), a railed service catwalk along its front at
    9.6 with spotlights, an orange hook on top at 13.8. Grapple up, land on
    the catwalk (or on the board's roof)."""
    begin(name)
    P = _Parts()
    con = P("plinth", "concrete")
    fac = P("shaft", "facade")
    steel = P("steel", "gunmetal")
    sbox(con, (0, 0.2, 0.3), (2.4, 2.4, 0.6), bevel=0.05)
    sbox(fac, (0, 0.2, 5.2), (1.0, 1.0, 9.2))
    _seams_y(fac, -0.3, 0.7, -0.53, 0.6, 9.8, 0.5)
    for z in (2.0, 5.0, 8.0):
        tbox(fac, (0, 0.2, z), (1.12, 1.12, 0.2))
    sbox(fac, (0, 0.2, 11.4), (6.0, 0.6, 3.2))
    tbox(steel, (0, 0.2, 13.05), (6.2, 0.8, 0.1))
    tbox(P.neon("board", "pink"), (0, -0.115, 11.4), (5.6, 0.03, 2.8))
    tbox(P.neon("board", "cyan"), (0, 0.515, 11.4), (5.6, 0.03, 2.8))
    tbox(P("art", "shadow"), (-1.2, -0.135, 11.6), (1.8, 0.02, 1.8))
    tbox(P.neon("text", "white"), (1.4, -0.135, 10.6), (2.2, 0.02, 0.3))
    tbox(P("art", "shadow"), (1.0, 0.535, 11.8), (2.6, 0.02, 0.6))
    # Catwalk.
    sbox(steel, (0, -0.8, 9.525), (6.4, 1.4, 0.15))
    for x in (-3.0, 0.0, 3.0):
        cyl(steel, (x, -0.1, 8.5), (x, -1.4, 9.45), 0.06, sides=4)
    _rail(steel, (-3.2, -1.5, 9.6), (3.2, -1.5, 9.6))
    for x in (-3.2, 3.2):
        _rail(steel, (x, -1.5, 9.6), (x, -0.1, 9.6))
    for x in (-2.0, 2.0):
        tbox(steel, (x, -1.35, 9.85), (0.3, 0.3, 0.25), tilt=30)
        tbox(P("lamps", "light"), (x, -1.25, 10.0), (0.24, 0.05, 0.18), tilt=30)
    orange = P("hook", "anchor")
    tbox(steel, (0, 0.2, 13.25), (0.25, 0.25, 0.3))
    hook_block(steel, orange, (0, 0.2, 13.85), 1.2)
    tbox(orange, (0, -0.81, 9.47), (6.4, 0.03, 0.08))
    top((0, -0.8, 9.6))
    top((0, 0.2, 13.0))
    footprint(6.4, 3.6)
    P.done()
    export(name)


# =============================================================================
# Yard
# =============================================================================

def city_checkpoint(name):
    """A corp security checkpoint across a road lane, 10 W x 4 D: two scanner
    pylons and an overhead scanner bar (bottom at 4.4) with red laser beams
    down across the lane, a striped boom arm, and a guard booth with lit
    windows, its roof at 3.0 (a utility box behind it to climb from)."""
    begin(name)
    P = _Parts()
    fac = P("shell", "facade")
    steel = P("steel", "gunmetal")
    lit = P("windows", "light")
    red = P.neon("laser", "red")
    tbox(P("road", "asphalt"), (-1.5, 0, 0.025), (5.2, 4.2, 0.05))
    tbox(P.neon("stopline", "white"), (-1.5, -1.6, 0.055), (5.0, 0.2, 0.01))
    for x in (-4.4, 1.4):
        sbox(fac, (x, 0, 2.2), (0.8, 1.4, 4.4))
        tbox(steel, (x, 0, 0.15), (1.1, 1.7, 0.3))
        inner = 1 if x < 0 else -1
        tbox(red, (x + inner * 0.41, 0, 2.3), (0.03, 0.2, 3.6))
        _hazard(P("hazard", "anchor"), x - 0.4, x + 0.4, -0.71, 0.7, 0.35, step=0.3)
    sbox(fac, (-1.5, 0, 4.7), (6.6, 0.8, 0.6))
    tbox(steel, (-1.5, 0, 4.4), (5.2, 0.4, 0.06))
    tbox(red, (-1.5, 0, 4.365), (5.0, 0.12, 0.02))
    for k in range(6):
        tbox(red, (-3.75 + k * 0.9, 0, 2.2), (0.04, 0.04, 4.3))
    tbox(P.neon("sign", "cyan"), (-1.5, -0.41, 4.7), (3.0, 0.03, 0.3))
    # Boom arm from the right pylon.
    tbox(steel, (0.85, -0.6, 1.1), (0.4, 0.4, 0.5))
    tbox(steel, (-1.6, -0.6, 1.1), (4.8, 0.12, 0.14))
    for k in range(6):
        tbox(P("hazard", "anchor"), (-3.6 + k * 0.8, -0.6, 1.1), (0.4, 0.13, 0.15))
    # Guard booth.
    sbox(fac, (3.6, 0, 0.5), (2.6, 2.6, 1.0))
    tbox(fac, (3.6, 0, 1.9), (2.4, 2.4, 1.8))
    solid((3.6, 0, 1.9), (2.6, 2.6, 1.8))
    for sx in (-1, 1):
        for sy in (-1, 1):
            tbox(fac, (3.6 + sx * 1.2, sy * 1.2, 1.9), (0.2, 0.2, 1.8))
    for s in (-1, 1):
        tbox(lit, (3.6, s * 1.21, 1.9), (2.0, 0.04, 1.0))
        tbox(lit, (3.6 + s * 1.21, 0, 1.9), (0.04, 2.0, 1.0))
    sbox(fac, (3.6, 0, 2.9), (3.2, 3.2, 0.2))
    for s in (-1, 1):
        tbox(P.neon("roof", "cyan"), (3.6, s * 1.62, 2.9), (3.2, 0.04, 0.08))
        tbox(P.neon("roof", "cyan"), (3.6 + s * 1.62, 0, 2.9), (0.04, 3.2, 0.08))
    cyl(steel, (4.8, 1.2, 3.0), (4.8, 1.2, 4.6), 0.04, sides=4)
    tbox(steel, (2.7, -1.2, 3.2), (0.3, 0.3, 0.4))
    tbox(steel, (2.7, -1.35, 3.45), (0.35, 0.45, 0.3), tilt=-20)
    tbox(lit, (2.7, -1.58, 3.38), (0.26, 0.03, 0.2), tilt=-20)
    sbox(steel, (3.6, 1.75, 0.6), (1.4, 0.7, 1.2))
    tbox(P.neon("status", "green"), (3.3, 2.11, 0.9), (0.3, 0.03, 0.15))
    # Bollards outside the pylons.
    for x in (-4.4, 1.4):
        for y in (-1.5, 1.5):
            cyl(steel, (x, y, 0.0), (x, y, 0.8), 0.14, sides=8)
            cyl(P.neon("bollard", "amber"), (x, y, 0.8), (x, y, 0.9), 0.14, sides=8)
            column((x, y, 0), 0.14, 0.9)
    top((3.6, 0, 3.0))
    footprint(10.0, 4.2)
    P.done()
    export(name)


# =============================================================================
# Props
# =============================================================================

def city_tram_stop(name):
    """A maglev tram shelter on a paved platform, 7 x 3.2: a glass canopy at
    3.2 on two back posts (walkable), a low back wall (1.2: cover) with a bench
    in front and a timetable screen, a pink ad lightbox at the +X end, the
    route sign hanging from the canopy."""
    begin(name)
    P = _Parts()
    fac = P("shell", "facade")
    steel = P("steel", "gunmetal")
    sbox(P("platform", "pavers"), (0, 0, 0.075), (7.0, 3.2, 0.15))
    tbox(P("edge", "anchor"), (0, -1.45, 0.155), (7.0, 0.25, 0.01))
    sbox(fac, (0, 1.15, 0.75), (6.0, 0.3, 1.2))
    tbox(fac, (0, 1.15, 1.38), (6.1, 0.4, 0.06))
    tbox(P.neon("timetable", "cyan"), (-1.0, 0.98, 0.95), (1.2, 0.03, 0.5))
    for x in (-2.7, 2.7):
        tbox(steel, (x, 1.15, 1.6), (0.2, 0.2, 3.1))
        column((x, 1.15, 0), 0.12, 3.1)
        cyl(steel, (x, 1.1, 2.4), (x, -0.9, 3.0), 0.05, sides=4)
    # Canopy: a frame round a glass sheet.
    solid((0, 0, 3.1), (6.6, 3.0, 0.2))
    for s in (-1, 1):
        tbox(steel, (0, s * 1.4, 3.1), (6.6, 0.2, 0.2))
        tbox(steel, (s * 3.2, 0, 3.1), (0.2, 2.6, 0.2))
    tbox(P("canopy", "curtain"), (0, 0, 3.08), (6.2, 2.6, 0.06))
    tbox(P.neon("fascia", "cyan"), (0, -1.52, 3.1), (6.6, 0.04, 0.1))
    tbox(fac, (-1.8, -1.2, 2.75), (1.6, 0.15, 0.4))
    for x in (-2.4, -1.2):
        tbox(steel, (x, -1.2, 2.98), (0.04, 0.04, 0.06))
    tbox(P.neon("route", "amber"), (-1.8, -1.28, 2.75), (1.4, 0.02, 0.28))
    # Bench.
    tbox(fac, (0.4, 0.75, 0.6), (3.4, 0.5, 0.08))
    tbox(fac, (0.4, 0.97, 0.85), (3.4, 0.06, 0.4))
    for x in (-1.1, 1.9):
        tbox(steel, (x, 0.75, 0.38), (0.08, 0.4, 0.45))
    # Lightbox.
    sbox(steel, (3.1, 0, 1.4), (0.25, 1.9, 2.5))
    for s in (-1, 1):
        tbox(P.neon("ad", "pink"), (3.1 + s * 0.135, 0, 1.45), (0.02, 1.6, 2.1))
        tbox(P("ad", "shadow"), (3.1 + s * 0.15, 0.1, 1.8), (0.02, 0.9, 0.9))
    top((0, 0, 3.2))
    footprint(7.0, 3.4)
    P.done()
    export(name)


def city_barricade(name):
    """A corp security barricade, 2.2 W x 1.1 H: a chunky sloped steel block
    on feet, a hazard-striped kick plate, a red and cyan light bar on top.
    Low cover."""
    begin(name)
    P = _Parts()
    steel = P("body", "gunmetal")
    fac = P("plates", "facade")
    pts = []
    for x in (-1.05, 1.05):
        pts += [(x, -0.45, 0.12), (x, 0.45, 0.12), (x, -0.25, 1.0), (x, 0.25, 1.0)]
    _hull(steel, pts)
    for x in (-0.85, 0.85):
        tbox(steel, (x, 0, 0.06), (0.35, 1.0, 0.12))
    for x in (-1.08, 1.08):
        tbox(fac, (x, 0, 0.56), (0.06, 0.8, 0.8))
    tbox(fac, (0, -0.47, 0.3), (2.0, 0.06, 0.32))
    _hazard(P("stripes", "anchor"), -0.95, 0.95, -0.505, 0.3, 0.26, step=0.3)
    tbox(steel, (0, 0, 1.04), (1.6, 0.3, 0.1))
    tbox(P.neon("bar", "red"), (-0.42, 0, 1.13), (0.7, 0.26, 0.1))
    tbox(P.neon("bar", "cyan"), (0.42, 0, 1.13), (0.7, 0.26, 0.1))
    tbox(steel, (0, 0, 1.13), (0.1, 0.28, 0.12))
    solid((0, 0, 0.55), (2.2, 0.9, 1.1))
    footprint(2.4, 1.2)
    P.done()
    export(name)


def city_hovercar(name):
    """A parked hover car, 4.4 L x 2 W x 1.35 H, nose to +X: a sleek wedge
    body on skids, a tinted canopy, twin rear thrusters glowing cyan, glow
    pads underneath, head and tail lights. Low cover."""
    begin(name)
    P = _Parts()
    body = P("body", "facade")
    steel = P("steel", "gunmetal")
    pts = []
    for s in (-1, 1):
        pts += [(2.2, s * 0.55, 0.55), (2.2, s * 0.5, 0.75), (1.4, s * 0.95, 0.45), (1.4, s * 0.85, 0.95),
                (-0.6, s * 1.0, 0.45), (-0.6, s * 0.9, 1.05), (-2.1, s * 0.95, 0.5), (-2.1, s * 0.85, 1.1)]
    _hull(body, pts)
    cpts = []
    for s in (-1, 1):
        cpts += [(1.3, s * 0.6, 0.93), (-1.5, s * 0.7, 1.0), (0.3, s * 0.5, 1.33), (-0.8, s * 0.55, 1.33)]
    _hull(P("canopy", "shadow"), cpts)
    for s in (-1, 1):
        tbox(steel, (0, s * 0.75, 0.08), (3.4, 0.14, 0.1))
        for x in (-1.0, 1.0):
            tbox(steel, (x, s * 0.75, 0.28), (0.12, 0.12, 0.38))
        cyl(steel, (-1.95, s * 0.6, 0.8), (-2.45, s * 0.6, 0.8), 0.24, sides=8)
        cyl(P.neon("thruster", "cyan"), (-2.45, s * 0.6, 0.8), (-2.48, s * 0.6, 0.8), 0.17, sides=8)
        tbox(P.neon("head", "white"), (2.21, s * 0.32, 0.66), (0.04, 0.28, 0.07))
        tbox(P.neon("trim", "pink"), (-0.3, s * 0.985, 0.72), (3.0, 0.02, 0.05))
    tbox(P.neon("tail", "red"), (-2.12, 0, 0.96), (0.04, 1.3, 0.06))
    for x in (-1.0, 1.0):
        tbox(P.neon("pad", "cyan"), (x, 0, 0.43), (1.0, 0.7, 0.03))
    tbox(steel, (-1.95, 0, 1.3), (0.45, 1.9, 0.06))
    for s in (-1, 1):
        tbox(steel, (-1.9, s * 0.7, 1.18), (0.3, 0.06, 0.22))
    solid((0, 0, 0.68), (4.4, 1.9, 1.3))
    footprint(4.9, 2.2)
    P.done()
    export(name)


def city_kiosk(name):
    """A noodle / vending kiosk, 2.4 W x 1.6 D x 2.8: a serving hatch with a
    lit galley behind a counter, an awning hung with red lanterns, a cyan
    menu screen, a vending panel on its +X side and a pink neon sign box on
    the roof. Two stools. Tall cover."""
    begin(name)
    P = _Parts()
    fac = P("shell", "facade")
    steel = P("steel", "gunmetal")
    sbox(fac, (0, 0, 1.15), (2.4, 1.6, 2.3))
    tbox(fac, (0, 0, 2.38), (2.6, 1.8, 0.16))
    tbox(P("galley", "light"), (-0.25, -0.81, 1.45), (1.5, 0.04, 0.8))
    tbox(P("galley", "shadow"), (-0.25, -0.83, 1.2), (1.3, 0.02, 0.25))
    tbox(steel, (-0.25, -0.95, 1.02), (1.8, 0.35, 0.06))
    tbox(steel, (-0.25, -0.82, 1.9), (1.7, 0.08, 0.1))
    tbox(P.neon("menu", "cyan"), (0.85, -0.81, 1.5), (0.45, 0.04, 0.8))
    tbox(P("awning", "canvas"), (0, -1.15, 2.2), (2.6, 0.8, 0.06), tilt=18)
    rng = random.Random(651)
    for x in (-0.9, 0.0, 0.9):
        cyl(steel, (x, -1.45, 2.1), (x, -1.45, 1.95), 0.01, sides=3)
        blob(P.neon("lantern", "red"), (x, -1.45, 1.83), (0.13, 0.13, 0.16), rng, subdiv=1, wobble=0.05, seed=int(x * 10))
    tbox(P.neon("vend", "amber"), (1.215, 0.0, 1.35), (0.03, 0.9, 1.3))
    for k in range(3):
        tbox(steel, (1.23, -0.25 + k * 0.25, 0.5), (0.03, 0.16, 0.1))
    tbox(steel, (0, 0, 2.62), (1.8, 0.4, 0.4))
    for s in (-1, 1):
        tbox(P.neon("sign", "pink"), (0, s * 0.215, 2.62), (1.6, 0.03, 0.3))
    for x in (-0.7, 0.2):
        cyl(steel, (x, -1.35, 0.0), (x, -1.35, 0.65), 0.04, sides=5)
        cyl(fac, (x, -1.35, 0.65), (x, -1.35, 0.72), 0.2, sides=8)
    footprint(2.6, 3.0)
    P.done()
    export(name)


def city_planter(name):
    """A raised concrete planter, 2.2 x 2.2 x 0.8, with a bench cap on its
    front and a stylised holo-tree (a wood trunk under a faceted green neon
    canopy, about 3.4 m) on a projector ring. Low cover; the street's tree."""
    begin(name)
    P = _Parts()
    con = P("box", "concrete")
    sbox(con, (0, 0, 0.4), (2.2, 2.2, 0.8), bevel=0.04)
    tbox(P("soil", "dirt"), (0, 0, 0.8), (1.9, 1.9, 0.06))
    tbox(P("seat", "wood"), (0, -0.95, 0.83), (2.0, 0.3, 0.06))
    for s in (-1, 1):
        tbox(P.neon("base", "cyan"), (0, s * 1.11, 0.12), (1.8, 0.03, 0.06))
        tbox(P.neon("base", "cyan"), (s * 1.11, 0, 0.12), (0.03, 1.8, 0.06))
    wood = P("trunk", "wood")
    tapered_tube(wood, [(0, 0, 0.8), (0.1, 0.05, 1.8), (-0.05, 0.1, 2.6)], [0.16, 0.11, 0.06], sides=6)
    tapered_tube(wood, [(0.08, 0.04, 1.6), (0.6, -0.1, 2.3)], [0.07, 0.04], sides=5)
    tapered_tube(wood, [(0.0, 0.08, 2.0), (-0.55, 0.25, 2.55)], [0.06, 0.04], sides=5)
    ring(P("emitter", "gunmetal"), (0, 0, 0.86), 0.35, 0.04, sides=10)
    rng = random.Random(661)
    leaf = P.neon("canopy", "green")
    for c, sz in (((0.0, 0.1, 2.85), (0.95, 0.85, 0.5)), ((0.65, -0.1, 2.4), (0.6, 0.55, 0.32)),
                  ((-0.6, 0.25, 2.65), (0.6, 0.55, 0.32)), ((0.1, 0.0, 3.25), (0.55, 0.5, 0.25))):
        blob(leaf, c, sz, rng, subdiv=1, wobble=0.12, seed=int(c[0] * 10))
    column((0, 0, 0.8), 0.16, 1.8)
    footprint(2.4, 2.4)
    P.done()
    export(name)


def city_streetlight(name):
    """A tall LED streetlight, 7.2 m: a charcoal base, a tapered pole curving
    out 2.2 m over the road (-Y), a slim head with a white light strip under
    it, a cyan ring and a holo street sign on the pole."""
    begin(name)
    P = _Parts()
    fac = P("base", "facade")
    steel = P("pole", "gunmetal")
    tbox(fac, (0, 0, 0.35), (0.5, 0.5, 0.7))
    tbox(fac, (0, 0, 0.05), (0.7, 0.7, 0.1))
    tapered_tube(steel, [(0, 0, 0.7), (0, 0, 6.5)], [0.14, 0.09], sides=8)
    tapered_tube(steel, [(0, 0, 6.4), (0, -0.25, 6.95), (0, -0.9, 7.2), (0, -1.6, 7.22), (0, -2.3, 7.15)], [0.09, 0.085, 0.08, 0.07, 0.06], sides=6)
    tbox(fac, (0, -1.95, 7.08), (0.32, 1.3, 0.14))
    tbox(P.neon("led", "white"), (0, -1.95, 6.995), (0.22, 1.15, 0.03))
    tapered_tube(P.neon("ring", "cyan"), [(0, 0, 2.8), (0, 0, 2.9)], [0.15, 0.15], sides=8)
    tbox(fac, (0, -0.55, 3.4), (0.06, 0.8, 0.26))
    tbox(steel, (0, -0.2, 3.4), (0.08, 0.2, 0.08))
    for s in (-1, 1):
        tbox(P.neon("sign", "cyan"), (s * 0.035, -0.55, 3.4), (0.01, 0.7, 0.16))
    column((0, 0, 0), 0.25, 6.5)
    footprint(0.8, 2.6)
    P.done()
    export(name)


def city_ad_pillar(name):
    """A round ad column, 1.5 m across and 3.3 tall: an octagonal charcoal
    drum on a concrete foot, four glowing lightbox ads (pink, cyan, amber,
    white), a cap with a cyan ring. Tall cover."""
    begin(name)
    P = _Parts()
    _prism(P("foot", "concrete"), 8, 0.78, 0.0, 0.3)
    fac = P("drum", "facade")
    _prism(fac, 8, 0.7, 0.3, 2.95)
    _prism(fac, 8, 0.8, 2.95, 3.12)
    FP["cone"](fac, (0, 0, 3.12), 0.7, 0.2, sides=8)
    _prism(P.neon("ring", "cyan"), 8, 0.81, 2.98, 3.06)
    d = 0.7 * math.cos(math.pi / 8) + 0.012
    for k, col in enumerate(("pink", "cyan", "amber", "white")):
        a = k * math.pi / 2 - math.pi / 2
        c = (math.cos(a) * d, math.sin(a) * d, 1.65)
        tbox(P.neon("ad", col), c, (0.44, 0.03, 2.0), yaw=math.degrees(a) + 90)
        cd = (math.cos(a) * (d + 0.02), math.sin(a) * (d + 0.02), 2.0)
        tbox(P("ad", "shadow"), cd, (0.3, 0.02, 0.3), yaw=math.degrees(a) + 90)
    column((0, 0, 0), 0.75, 3.2)
    footprint(1.6, 1.6)
    P.done()
    export(name)


def city_dumpster(name):
    """An industrial dumpster, 2.1 x 1.25 x 1.3, flared steel body on casters,
    one lid shut and one propped on trash bags, fork pockets, hazard corners.
    Low cover."""
    begin(name)
    P = _Parts()
    steel = P("body", "gunmetal")
    pts = []
    for x in (-1.0, 1.0):
        pts += [(x, -0.52, 0.18), (x, 0.52, 0.18)]
    for x in (-1.05, 1.05):
        pts += [(x, -0.62, 1.15), (x, 0.62, 1.15)]
    _hull(steel, pts)
    tbox(steel, (0, 0, 1.15), (2.16, 1.3, 0.08))
    for x in (-0.6, 0.6):
        tbox(steel, (x, -0.6, 0.55), (0.35, 0.12, 0.18))
        tbox(steel, (x, 0.6, 0.55), (0.35, 0.12, 0.18))
    for x in (-0.85, 0.85):
        for y in (-0.4, 0.4):
            cyl(P("wheels", "shadow"), (x, y - 0.04, 0.08), (x, y + 0.04, 0.08), 0.08, sides=6)
            tbox(steel, (x, y, 0.15), (0.12, 0.12, 0.06))
    lid = P("lids", "facade")
    tbox(lid, (-0.53, 0, 1.24), (1.02, 1.3, 0.06), tilt=-3)
    tbox(lid, (0.53, 0.05, 1.42), (1.02, 1.3, 0.06), tilt=-18)
    rng = random.Random(671)
    for k in range(3):
        blob(P("bags", "canvas"), (0.3 + k * 0.28, -0.3 + k * 0.1, 1.22), (0.26, 0.22, 0.18), rng, subdiv=1, wobble=0.15, seed=k)
    st = P("hazard", "anchor")
    for x in (-0.9, 0.9):
        _diag(st, (x, -0.6, 0.9), 0.1, 0.4, 45 if x < 0 else -45)
    tbox(P("label", "shadow"), (0, -0.585, 0.75), (0.6, 0.02, 0.3), tilt=-6)
    solid((0, 0, 0.65), (2.1, 1.25, 1.3))
    footprint(2.4, 1.6)
    P.done()
    export(name)


def city_hvac(name):
    """A HVAC cluster, 3 x 2 x 2: a big condenser with a fan on top, a taller
    air handler with louvres and a green status light, insulated pipes looping
    between them, all on a steel skid. Tall cover (rooftops or street)."""
    begin(name)
    P = _Parts()
    steel = P("units", "gunmetal")
    dark = P("dark", "shadow")
    tbox(steel, (0, 0, 0.075), (3.0, 2.0, 0.15))
    tbox(steel, (-0.55, 0, 0.85), (1.8, 1.8, 1.4), bevel=0.04)
    _fan_top(steel, dark, (-0.55, 0, 1.55), 0.6)
    for k in range(5):
        tbox(steel, (-0.55, -0.92, 0.45 + k * 0.2), (1.5, 0.06, 0.06))
    tbox(dark, (-0.55, -0.905, 0.85), (1.5, 0.02, 1.0))
    tbox(steel, (1.0, 0, 1.05), (1.0, 1.6, 1.8), bevel=0.03)
    for k in range(6):
        tbox(steel, (1.0, -0.82, 0.4 + k * 0.2), (0.8, 0.08, 0.06), tilt=30)
    tbox(dark, (1.0, -0.805, 0.9), (0.8, 0.02, 1.2))
    tbox(P.neon("status", "green"), (1.3, -0.815, 1.75), (0.15, 0.02, 0.08))
    pipe = P("pipes", "facade")
    for y in (-0.4, 0.4):
        tapered_tube(pipe, [(1.0, y, 1.95), (1.0, y, 2.05), (0.4, y, 2.05), (0.2, y, 1.6)], [0.09] * 4, sides=6)
    tapered_tube(pipe, [(1.4, 0.82, 0.3), (1.4, 0.9, 0.3), (1.4, 0.9, 1.6)], [0.07] * 3, sides=6)
    solid((-0.55, 0, 0.85), (1.8, 1.8, 1.7))
    solid((1.0, 0, 1.05), (1.0, 1.6, 2.1))
    footprint(3.2, 2.2)
    P.done()
    export(name)


def city_traffic_light(name):
    """A traffic signal: a 5.6 m pole with an arm out 4 m over the road (+X),
    two signal heads with red / amber / green lamps, a cyan holo street sign,
    a pedestrian button box."""
    begin(name)
    P = _Parts()
    fac = P("heads", "facade")
    steel = P("pole", "gunmetal")
    tbox(fac, (0, 0, 0.3), (0.45, 0.45, 0.6))
    tapered_tube(steel, [(0, 0, 0.6), (0, 0, 5.7)], [0.13, 0.1], sides=8)
    tapered_tube(steel, [(0, 0, 5.45), (4.2, 0, 5.45)], [0.09, 0.06], sides=6)
    cyl(steel, (0, 0, 4.6), (1.6, 0, 5.4), 0.04, sides=4)
    for x in (2.4, 4.0):
        tbox(steel, (x, 0, 5.3), (0.08, 0.08, 0.25))
        tbox(fac, (x, 0, 4.7), (0.36, 0.3, 1.0))
        for k, col in enumerate(("red", "amber", "green")):
            z = 5.0 - k * 0.3
            cyl(P.neon("lamp", col), (x, -0.15, z), (x, -0.17, z), 0.1, sides=8)
            tbox(fac, (x, -0.22, z + 0.12), (0.26, 0.14, 0.03))
    tbox(fac, (1.2, -0.02, 5.75), (1.6, 0.08, 0.35))
    tbox(P.neon("street", "cyan"), (1.2, -0.07, 5.75), (1.4, 0.02, 0.22))
    tbox(P.neon("street", "cyan"), (1.2, 0.03, 5.75), (1.4, 0.02, 0.22))
    for x in (0.6, 1.8):
        tbox(steel, (x, 0, 5.56), (0.04, 0.04, 0.12))
    tbox(fac, (0, -0.18, 1.2), (0.2, 0.12, 0.3))
    tbox(P.neon("button", "white"), (0, -0.25, 1.22), (0.08, 0.02, 0.08))
    column((0, 0, 0), 0.2, 5.7)
    footprint(1.2, 1.2)
    P.done()
    export(name)


def build_all():
    city_tower("city_tower")
    city_shopfront("city_shopfront")
    city_apartment("city_apartment")
    city_overpass("city_overpass")
    city_holo_wall("city_holo_wall")
    city_security_wall("city_security_wall")
    city_drone_pylon("city_drone_pylon")
    city_tram_stop("city_tram_stop")
    city_barricade("city_barricade")
    city_hovercar("city_hovercar")
    city_kiosk("city_kiosk")
    city_planter("city_planter")
    city_streetlight("city_streetlight")
    city_ad_pillar("city_ad_pillar")
    city_dumpster("city_dumpster")
    city_hvac("city_hvac")
    city_checkpoint("city_checkpoint")
    city_monorail("city_monorail")
    city_stairs_plaza("city_stairs_plaza")
    city_billboard_tower("city_billboard_tower")
    city_traffic_light("city_traffic_light")
