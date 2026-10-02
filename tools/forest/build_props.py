"""Models the forest run level's props in Blender and exports them as glTF.

    blender -b --python tools/forest/build_props.py

Writes assets/models/forest/<name>.glb: conifers, fallen logs and stumps for the
forest, and the enemy's prefab outpost kit (wall slabs, gate, watchtower, huts,
sandbags, floodlights, antenna, fuel tank, log piles, sawmill, blown bridge) plus
the evac dropship for the forest's edge. Same conventions as the hub props
(tools/hub/build_props.py, whose shape helpers this reuses): low-poly, flat
shaded, objects named "<part>__<material>" so the game swaps in its own
materials, origins on the ground, fronts facing -Y in Blender (+Z in Godot, the
way the pilot comes from). Sizes match the colliders scripts/run/forest_kit.gd
gives them.

Seeded, so re-running gives the same meshes.
"""
import math
import random
from pathlib import Path

from mathutils import Vector

HERE = Path(__file__).resolve().parent
_src = (HERE.parent / "hub" / "build_props.py").read_text().rsplit("\nmain()", 1)[0]
H = {"__file__": str(HERE.parent / "hub" / "build_props.py")}
exec(compile(_src, "hub_build_props", "exec"), H)

import bpy  # noqa: E402

OUT = HERE.parent.parent / "assets" / "models" / "forest"
clear, part, new_bm, box, blob, tapered_tube, face2 = (
    H["clear"], H["part"], H["new_bm"], H["box"], H["blob"], H["tapered_tube"], H["face2"])


def export(name):
    OUT.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(OUT / f"{name}.glb"), export_format="GLB", export_apply=True,
        export_yup=True, export_materials="PLACEHOLDER", export_normals=True,
        export_texcoords=False, export_colors=False,
    )
    print("wrote", name)
    clear()


def cone(bm, center, radius, height, sides=7, rng=None, droop=0.0):
    """A low cone with a jittered rim (a pine tier)."""
    c = Vector(center)
    rim = []
    for k in range(sides):
        a = 2 * math.pi * k / sides + (rng.uniform(-0.15, 0.15) if rng else 0.0)
        r = radius * (rng.uniform(0.85, 1.12) if rng else 1.0)
        rim.append(bm.verts.new(c + Vector((math.cos(a) * r, math.sin(a) * r, -droop * (rng.uniform(0.5, 1.0) if rng else 1.0)))))
    tip = bm.verts.new(c + Vector((0, 0, height)))
    for k in range(sides):
        bm.faces.new((rim[k], rim[(k + 1) % sides], tip))
    bm.faces.new(list(reversed(rim)))


def cyl(bm, a, b, r, sides=8):
    tapered_tube(bm, [a, b], [r, r], sides=sides)


# --- forest -------------------------------------------------------------------

def pine(name, seed, height, tiers):
    """A conifer: straight tapering trunk, stacked drooping needle tiers."""
    rng = random.Random(seed)
    trunk = new_bm()
    base_r = 0.22 + height * 0.018
    tapered_tube(trunk, [(0, 0, 0), (0, 0, height * 0.5), (0, 0, height * 0.92)], [base_r * 1.5, base_r, base_r * 0.4], sides=6)
    for k in range(3):
        a = k * 2.1 + rng.uniform(-0.3, 0.3)
        d = Vector((math.cos(a), math.sin(a), 0))
        tapered_tube(trunk, [d * base_r * 0.4 + Vector((0, 0, 0.5)), d * base_r * 2.0 + Vector((0, 0, -0.05))], [base_r * 0.4, base_r * 0.15], sides=4)
    part(trunk, "trunk", "bark")
    needles = new_bm()
    bottom = height * 0.22
    for i in range(tiers):
        t = i / max(tiers - 1, 1)
        z = bottom + (height * 0.95 - bottom) * t * 0.86
        r = height * (0.3 - 0.21 * t) * rng.uniform(0.92, 1.08)
        cone(needles, (rng.uniform(-0.1, 0.1), rng.uniform(-0.1, 0.1), z), r, height * 0.26, sides=7, rng=rng, droop=r * 0.25)
    part(needles, "needles", "leaves")
    export(name)


def dead_pine(name, seed, height):
    """A dead snag: bare trunk with a few broken stubs."""
    rng = random.Random(seed)
    bm = new_bm()
    tapered_tube(bm, [(0, 0, 0), (0.2, 0, height * 0.6), (0.35, 0.1, height)], [0.4, 0.28, 0.1], sides=6)
    for k in range(6):
        z = height * rng.uniform(0.35, 0.9)
        a = rng.uniform(0, 2 * math.pi)
        d = Vector((math.cos(a), math.sin(a), 0.25))
        p = Vector((0.2 * z / height, 0, z))
        tapered_tube(bm, [p, p + d * rng.uniform(0.8, 1.8)], [0.1, 0.03], sides=4)
    part(bm, "trunk", "bark")
    export(name)


def fallen_log(name, seed, length):
    """A felled trunk lying along X, with snapped branch stubs and a root plate."""
    rng = random.Random(seed)
    bm = new_bm()
    r = 0.55
    pts = [Vector((-length * 0.5 + length * t, rng.uniform(-0.1, 0.1), r * 0.9)) for t in (0, 0.33, 0.66, 1.0)]
    tapered_tube(bm, pts, [r, r * 0.95, r * 0.85, r * 0.7], sides=7)
    for k in range(5):
        x = rng.uniform(-length * 0.4, length * 0.45)
        a = rng.uniform(0.3, 2.8)
        d = Vector((rng.uniform(-0.3, 0.3), math.cos(a), math.sin(a)))
        p = Vector((x, 0, r * 0.9))
        tapered_tube(bm, [p, p + d * rng.uniform(0.7, 1.4)], [0.14, 0.05], sides=4)
    # Root plate on the -X end.
    for k in range(7):
        a = 2 * math.pi * k / 7
        d = Vector((0, math.cos(a), math.sin(a) * 0.9 + 0.3))
        p = Vector((-length * 0.5, 0, r))
        tapered_tube(bm, [p, p + d * rng.uniform(1.0, 1.6) + Vector((-0.3, 0, 0))], [0.22, 0.06], sides=4)
    part(bm, "log", "bark")
    moss = new_bm()
    for k in range(3):
        x = rng.uniform(-length * 0.3, length * 0.3)
        blob(moss, (x, 0, r * 1.7), (1.0, 0.45, 0.18), rng, subdiv=1, wobble=0.15, seed=seed + k)
    part(moss, "moss", "leaves")
    export(name)


def stump(name, seed):
    rng = random.Random(seed)
    bm = new_bm()
    tapered_tube(bm, [(0, 0, 0), (0, 0, 0.7)], [0.75, 0.6], sides=8)
    for k in range(5):
        a = 2 * math.pi * k / 5 + rng.uniform(-0.2, 0.2)
        d = Vector((math.cos(a), math.sin(a), 0))
        tapered_tube(bm, [d * 0.4 + Vector((0, 0, 0.4)), d * 1.3 + Vector((0, 0, -0.05))], [0.22, 0.08], sides=4)
    part(bm, "stump", "bark")
    cut = new_bm()
    tapered_tube(cut, [(0, 0, 0.7), (0, 0, 0.74)], [0.58, 0.58], sides=8)
    part(cut, "cut", "wood")
    export(name)


# --- enemy outpost kit --------------------------------------------------------

def wall_slab(name, seed):
    """Prefab concrete wall panel, 4 W x 6 H x 0.8 D, with ribs, a hazard band,
    a walkway lip on the back, and razor wire coiled along the top."""
    rng = random.Random(seed)
    con = new_bm()
    box(con, (0, 0, 3.0), (3.96, 0.8, 6.0), bevel=0.04)
    # Vertical ribs on the front (-Y) face, a wider foot.
    for x in (-1.3, 1.3):
        box(con, (x, -0.5, 2.8), (0.4, 0.25, 5.6))
    box(con, (0, -0.1, 0.25), (4.0, 1.4, 0.5))
    # Chunks knocked off the top edge.
    for k in range(2):
        box(con, (rng.uniform(-1.6, 1.6), -0.3, 5.9), (rng.uniform(0.3, 0.7), 0.3, 0.3))
    part(con, "slab", "concrete")
    band = new_bm()
    box(band, (0, -0.42, 4.6), (3.9, 0.04, 0.45))
    part(band, "band", "anchor")
    metal = new_bm()
    # Posts and wire coils.
    for x in (-1.8, 0.0, 1.8):
        box(metal, (x, 0, 6.35), (0.08, 0.08, 0.7))
    for k in range(10):
        a = k * 0.9
        x = -1.9 + k * 0.42
        cyl(metal, (x, math.cos(a) * 0.22, 6.35 + math.sin(a) * 0.22), (x + 0.42, math.cos(a + 0.9) * 0.22, 6.35 + math.sin(a + 0.9) * 0.22), 0.025, sides=3)
    part(metal, "wire", "gunmetal")
    export(name)


def gate(name):
    """Sliding outpost gate, 8 W x 6.5 H x 1.2 D: concrete pillars, steel doors, a lamp."""
    con = new_bm()
    for s in (-1, 1):
        box(con, (s * 3.6, 0, 3.4), (0.8, 1.2, 6.8), bevel=0.05)
    box(con, (0, 0, 6.6), (8.0, 1.2, 0.6))
    part(con, "frame", "concrete")
    steel = new_bm()
    for s in (-1, 1):
        box(steel, (s * 1.6, 0, 3.0), (3.2, 0.3, 6.0))
        for z in (1.0, 3.0, 5.0):
            box(steel, (s * 1.6, -0.2, z), (3.0, 0.12, 0.2))
    part(steel, "doors", "gunmetal")
    band = new_bm()
    box(band, (0, -0.62, 6.6), (7.8, 0.04, 0.4))
    part(band, "band", "anchor")
    lamp = new_bm()
    for s in (-1, 1):
        box(lamp, (s * 3.6, -0.66, 6.0), (0.3, 0.1, 0.3))
    part(lamp, "lamp", "light")
    export(name)


def watchtower(name):
    """Four-legged tower: deck top at 7 m (4.4 x 4.4), waist-high front and side
    rails, a roof at 9.6 m, ladder on the back, searchlight on the front rail."""
    steel = new_bm()
    for sx in (-1, 1):
        for sy in (-1, 1):
            tapered_tube(steel, [(sx * 2.4, sy * 2.4, 0), (sx * 1.95, sy * 1.95, 6.85)], [0.16, 0.13], sides=5)
            box(steel, (sx * 1.95, sy * 1.95, 8.3), (0.14, 0.14, 2.6))
    # Cross bracing.
    for z0, z1 in ((0.3, 3.4), (3.6, 6.6)):
        for s in (-1, 1):
            w0, w1 = 2.4 - z0 * 0.065, 2.4 - z1 * 0.065
            cyl(steel, (-w0, s * w0, z0), (w1, s * w1, z1), 0.06, sides=4)
            cyl(steel, (s * w0, -w0, z0), (s * w1, w1, z1), 0.06, sides=4)
    # Ladder up the back (+Y).
    for x in (-0.3, 0.3):
        box(steel, (x, 2.3, 3.5), (0.06, 0.06, 7.0))
    for k in range(17):
        box(steel, (0, 2.3, 0.4 + k * 0.4), (0.6, 0.05, 0.05))
    # Rails (front and sides; the back is open where the ladder comes up).
    box(steel, (0, -2.15, 7.95), (4.4, 0.08, 0.08))
    for s in (-1, 1):
        box(steel, (s * 2.15, 0, 7.95), (0.08, 4.4, 0.08))
    part(steel, "frame", "gunmetal")
    deck = new_bm()
    box(deck, (0, 0, 6.85), (4.4, 4.4, 0.3))
    box(deck, (0, -2.15, 7.45), (4.4, 0.1, 0.9))
    for s in (-1, 1):
        box(deck, (s * 2.15, -0.6, 7.45), (0.1, 3.2, 0.9))
    part(deck, "deck", "wood")
    roof = new_bm()
    box(roof, (0, 0, 9.65), (5.0, 5.0, 0.25))
    part(roof, "roof", "gunmetal")
    band = new_bm()
    box(band, (0, -2.22, 7.45), (4.2, 0.02, 0.3))
    part(band, "band", "anchor")
    light = new_bm()
    box(light, (1.4, -2.3, 8.25), (0.5, 0.4, 0.4))
    part(light, "lamp", "light")
    export(name)


def hut(name, seed):
    """Prefab barracks, 8 W x 3.4 H x 5 D: ribbed metal box on skids, door and
    lit windows on the front, AC unit and vent on the roof, steps at the door."""
    rng = random.Random(seed)
    steel = new_bm()
    box(steel, (0, 0, 1.75), (8.0, 5.0, 3.3), bevel=0.06)
    for x in range(-3, 4):
        box(steel, (x * 1.15, -2.53, 1.75), (0.12, 0.08, 3.2))
        box(steel, (x * 1.15, 2.53, 1.75), (0.12, 0.08, 3.2))
    box(steel, (0, 0, 3.45), (8.2, 5.2, 0.12))
    box(steel, (2.2, 0.8, 3.85), (1.4, 1.2, 0.7))  # AC unit
    cyl(steel, (-2.4, -0.6, 3.5), (-2.4, -0.6, 4.3), 0.25, sides=6)
    part(steel, "shell", "gunmetal")
    skid = new_bm()
    for y in (-1.8, 1.8):
        box(skid, (0, y, 0.08), (8.4, 0.35, 0.16))
    box(skid, (-1.5, -2.9, 0.15), (1.6, 0.8, 0.3))  # steps
    box(skid, (-1.5, -2.7, 0.45), (1.6, 0.5, 0.3))
    part(skid, "skids", "concrete")
    door = new_bm()
    box(door, (-1.5, -2.52, 1.2), (1.1, 0.06, 2.1))
    part(door, "door", "shadow")
    win = new_bm()
    for x in (0.9, 2.6):
        box(win, (x, -2.53, 2.0), (1.1, 0.05, 0.7))
    part(win, "windows", "light")
    stripe = new_bm()
    box(stripe, (0, -2.55, 3.05), (7.9, 0.03, 0.25))
    part(stripe, "stripe", "anchor")
    export(name)


def sandbags(name, seed):
    """A low curved sandbag wall, 2.2 W x 1.2 H x 0.6 D: three courses of lumpy bags."""
    rng = random.Random(seed)
    bm = new_bm()
    for row in range(3):
        n = 4 - (row == 2)
        for k in range(n):
            x = -0.85 + k * (1.7 / max(n - 1, 1)) + (0.15 if row == 1 else 0.0)
            x = max(-0.85, min(0.85, x))
            y = 0.06 * math.cos(x * 1.2)
            blob(bm, (x, y, 0.2 + row * 0.38), (0.32, 0.27, 0.19), rng, subdiv=1, wobble=0.1, seed=seed + row * 5 + k)
    part(bm, "bags", "canvas")
    export(name)


def crate_stack(name, seed):
    """Tall cover, 1.4 W x 2.6 H x 1.4 D: two ammo crates and a smaller one on top."""
    rng = random.Random(seed)
    bm = new_bm()
    box(bm, (0, 0, 0.55), (1.4, 1.4, 1.1), bevel=0.04)
    box(bm, (0.02, 0.0, 1.62), (1.3, 1.3, 1.0), rot_z=rng.uniform(-0.15, 0.15), bevel=0.04)
    box(bm, (-0.1, 0.1, 2.38), (0.9, 0.7, 0.5), rot_z=rng.uniform(-0.4, 0.4), bevel=0.03)
    part(bm, "crates", "wood")
    trim = new_bm()
    for z in (0.55, 1.62):
        box(trim, (0, -0.72, z), (1.0, 0.04, 0.18))
    part(trim, "stencil", "anchor")
    export(name)


def floodlight(name):
    """Lamp pole with a two-lamp head facing -Y, about 6 m."""
    steel = new_bm()
    tapered_tube(steel, [(0, 0, 0), (0, 0, 6.0)], [0.14, 0.09], sides=6)
    box(steel, (0, 0, 0.15), (0.8, 0.8, 0.3))
    box(steel, (0, -0.1, 6.0), (1.4, 0.15, 0.15))
    for x in (-0.5, 0.5):
        box(steel, (x, -0.35, 6.0), (0.55, 0.4, 0.45))
    part(steel, "pole", "gunmetal")
    lamp = new_bm()
    for x in (-0.5, 0.5):
        box(lamp, (x, -0.57, 6.0), (0.45, 0.04, 0.35))
    part(lamp, "lamp", "light")
    export(name)


def antenna(name):
    """Comms mast: a 14 m lattice tower with a dish and a blinking tip."""
    steel = new_bm()
    h = 14.0
    for sx in (-1, 1):
        for sy in (-1, 1):
            tapered_tube(steel, [(sx * 0.9, sy * 0.9, 0), (sx * 0.25, sy * 0.25, h)], [0.07, 0.04], sides=4)
    for k in range(9):
        z0, z1 = k * h / 9, (k + 1) * h / 9
        w0, w1 = 0.9 - 0.65 * z0 / h, 0.9 - 0.65 * z1 / h
        cyl(steel, (-w0, -w0, z0), (w1, -w1, z1), 0.03, sides=3)
        cyl(steel, (w0, w0, z0), (-w1, w1, z1), 0.03, sides=3)
    cyl(steel, (0, 0, h), (0, 0, h + 2.5), 0.04, sides=4)
    box(steel, (0, 0, 0.2), (2.4, 2.4, 0.4))
    part(steel, "mast", "gunmetal")
    dish = new_bm()
    cone(dish, (0, -0.7, 10.5), 1.1, 0.45, sides=10)
    part(dish, "dish", "concrete")
    tip = new_bm()
    box(tip, (0, 0, h + 2.55), (0.25, 0.25, 0.25))
    part(tip, "tip", "light")
    export(name)


def fuel_tank(name):
    """Horizontal fuel tank on a cradle, 6 L x 3 H x 3 D, hazard bands."""
    steel = new_bm()
    tapered_tube(steel, [(-2.8, 0, 1.7), (2.8, 0, 1.7)], [1.25, 1.25], sides=10)
    for x in (-2.0, 2.0):
        box(steel, (x, 0, 0.5), (0.4, 2.6, 1.0))
    part(steel, "tank", "titan_armor")
    band = new_bm()
    for x in (-1.0, 1.0):
        tapered_tube(band, [(x - 0.15, 0, 1.7), (x + 0.15, 0, 1.7)], [1.29, 1.29], sides=10)
    part(band, "bands", "anchor")
    export(name)


def log_pile(name, seed):
    """Stacked cut logs, 5 W x 1.8 H x 2.4 D, held by stakes at the ends."""
    rng = random.Random(seed)
    bm = new_bm()
    r = 0.32
    rows = [(4, 0), (3, 1), (2, 2)]
    for n, row in rows:
        for k in range(n):
            y = (k - (n - 1) * 0.5) * (2 * r + 0.02) * 1.15
            z = r + row * r * 1.75
            x0, x1 = -2.4 + rng.uniform(0, 0.2), 2.4 - rng.uniform(0, 0.2)
            cyl(bm, (x0, y, z), (x1, y, z), r * rng.uniform(0.9, 1.05), sides=7)
    part(bm, "logs", "bark")
    ends = new_bm()
    for n, row in rows:
        for k in range(n):
            y = (k - (n - 1) * 0.5) * (2 * r + 0.02) * 1.15
            z = r + row * r * 1.75
            cyl(ends, (2.42, y, z), (2.45, y, z), r * 0.85, sides=7)
    part(ends, "ends", "wood")
    stakes = new_bm()
    for x in (-2.55, 2.55):
        for y in (-1.15, 1.15):
            box(stakes, (x, y, 0.95), (0.14, 0.14, 1.9))
    part(stakes, "stakes", "wood")
    export(name)


def sawmill(name):
    """Open-sided sawmill shed: 12 W x 8 D, roof top at 5 m, posts, a saw bench
    with a big circular blade, and a conveyor of half-cut logs."""
    wood = new_bm()
    for x in (-5.8, 0, 5.8):
        for y in (-3.8, 3.8):
            box(wood, (x, y, 2.4), (0.35, 0.35, 4.8))
    for y in (-3.8, 3.8):
        box(wood, (0, y, 4.6), (12.0, 0.3, 0.3))
    # Bench.
    box(wood, (0, 0, 0.5), (7.0, 1.4, 1.0))
    part(wood, "frame", "wood")
    roof = new_bm()
    box(roof, (0, 0, 4.88), (12.4, 8.4, 0.24))
    part(roof, "roof", "gunmetal")
    blade = new_bm()
    tapered_tube(blade, [(0, -0.06, 1.6), (0, 0.06, 1.6)], [1.0, 1.0], sides=12)
    part(blade, "blade", "titan_armor")
    logs = new_bm()
    for x in (-2.4, 2.2):
        cyl(logs, (x - 1.2, 0, 1.3), (x + 1.2, 0, 1.3), 0.3, sides=7)
    part(logs, "logs", "bark")
    band = new_bm()
    box(band, (0, -4.22, 4.88), (12.2, 0.04, 0.2))
    part(band, "band", "anchor")
    export(name)


def bridge_stub(name, seed):
    """One end of a blown concrete bridge: a 6 W x 10 L deck (top at 0) on a
    pier dropping 18 m, the far end shattered with rebar sticking out (+Y).
    Low curbs only, so you can run off the side onto the wallrun shield."""
    rng = random.Random(seed)
    con = new_bm()
    box(con, (0, 0, -0.6), (6.0, 10.0, 1.2))
    box(con, (0, 3.0, -9.5), (3.0, 2.5, 17.0))
    for s in (-1, 1):
        box(con, (s * 2.85, 0, 0.1), (0.3, 10.0, 0.2))  # curbs (the railings went with the blast)
    # Broken chunks hanging off the far end.
    for k in range(4):
        box(con, (rng.uniform(-2.2, 2.2), 5.2 + rng.uniform(0, 0.4), -0.9 - rng.uniform(0, 0.8)),
            (rng.uniform(0.8, 1.6), 0.8, 0.7), rot_z=rng.uniform(-0.4, 0.4))
    part(con, "deck", "concrete")
    rebar = new_bm()
    for k in range(9):
        x = -2.6 + k * 0.65
        a = Vector((x, 5.0, -0.6 + rng.uniform(-0.3, 0.3)))
        cyl(rebar, a, a + Vector((rng.uniform(-0.3, 0.3), rng.uniform(0.8, 1.6), rng.uniform(-0.8, 0.2))), 0.03, sides=3)
    part(rebar, "rebar", "gunmetal")
    band = new_bm()
    for s in (-1, 1):
        box(band, (s * 3.02, 0, -0.6), (0.04, 9.6, 0.4))
    part(band, "band", "anchor")
    export(name)


def pylon(name):
    """A bridge-crane pylon: a concrete column with a steel gantry arm overhead.
    Column 2 x 2, the arm's underside 12 m up. The arm reaches along -Y."""
    con = new_bm()
    box(con, (0, 0, 6.0), (2.0, 2.0, 12.0))
    part(con, "column", "concrete")
    steel = new_bm()
    box(steel, (0, -4.0, 12.6), (1.2, 10.0, 1.2))
    cyl(steel, (0, 0.5, 13.2), (0, -8.5, 13.2), 0.08, sides=4)
    for k in range(5):
        cyl(steel, (0, -k * 2.0, 13.2), (0, -k * 2.0 - 2.0, 12.0), 0.05, sides=4)
    part(steel, "arm", "gunmetal")
    export(name)


def wreck_truck(name, seed):
    """Burnt-out enemy truck, 7 L (along X) x 3 H x 3 W, cab on +X, tilted on a flat tyre."""
    rng = random.Random(seed)
    hull = new_bm()
    box(hull, (-0.8, 0, 1.55), (5.0, 2.6, 1.9), bevel=0.06)
    box(hull, (2.6, 0, 1.4), (1.8, 2.5, 1.6), bevel=0.08)
    box(hull, (2.5, 0, 2.4), (1.4, 2.3, 0.6))
    part(hull, "hull", "titan_armor")
    soot = new_bm()
    for k in range(3):
        blob(soot, (rng.uniform(-2.5, 1.5), rng.uniform(-1.0, 1.0), 2.6), (0.6, 0.6, 0.15), rng, subdiv=1, wobble=0.2, seed=seed + k)
    box(soot, (2.5, -1.26, 2.35), (1.2, 0.04, 0.45))
    part(soot, "soot", "shadow")
    tyres = new_bm()
    for x in (-2.4, -1.0, 2.6):
        for y in (-1.25, 1.25):
            cyl(tyres, (x, y - 0.2, 0.5), (x, y + 0.2, 0.5), 0.5, sides=8)
    part(tyres, "tyres", "fabric")
    export(name)


def evac_pad(name):
    """Evac landing pad: 14 m octagon slab, painted ring, edge lights."""
    con = new_bm()
    tapered_tube(con, [(0, 0, -0.5), (0, 0, 0.15)], [7.4, 7.4], sides=8)
    part(con, "pad", "concrete")
    ring = new_bm()
    tapered_tube(ring, [(0, 0, 0.15), (0, 0, 0.17)], [5.0, 5.0], sides=16)
    part(ring, "ring", "anchor")
    inner = new_bm()
    tapered_tube(inner, [(0, 0, 0.16), (0, 0, 0.19)], [4.3, 4.3], sides=16)
    part(inner, "inner", "concrete")
    lamps = new_bm()
    for k in range(8):
        a = 2 * math.pi * k / 8 + math.pi / 8
        box(lamps, (math.cos(a) * 6.9, math.sin(a) * 6.9, 0.25), (0.35, 0.35, 0.2))
    part(lamps, "lamps", "light")
    export(name)


def dropship(name):
    """Titan-lift dropship, about 22 m long along Y (nose at -Y), two tilt
    engines on stub wings, a clamp frame hanging under the belly."""
    hull = new_bm()
    tapered_tube(hull, [(0, -11, 0.6), (0, -7, 0.2), (0, 2, 0.4), (0, 9, 1.2), (0, 11.5, 1.6)], [0.8, 2.3, 2.6, 2.0, 0.9], sides=8)
    box(hull, (0, 10.5, 3.2), (0.3, 3.0, 3.4))  # tail fin
    for s in (-1, 1):
        box(hull, (s * 4.5, -1.0, 0.8), (6.5, 3.2, 0.5))
        box(hull, (s * 2.8, 10.5, 1.8), (3.0, 1.5, 0.25))
    part(hull, "hull", "titan_armor")
    eng = new_bm()
    for s in (-1, 1):
        tapered_tube(eng, [(s * 7.8, -3.0, 0.8), (s * 7.8, 1.5, 0.8)], [1.3, 1.1], sides=8)
    # Clamp frame.
    for s in (-1, 1):
        box(eng, (s * 2.2, 0, -2.0), (0.4, 0.4, 3.6))
        box(eng, (s * 2.2, 0, -3.8), (0.5, 3.0, 0.4))
    part(eng, "engines", "gunmetal")
    glass = new_bm()
    box(glass, (0, -8.8, 1.7), (1.8, 1.8, 0.6))
    part(glass, "canopy", "shadow")
    glow = new_bm()
    for s in (-1, 1):
        tapered_tube(glow, [(s * 7.8, 1.5, 0.8), (s * 7.8, 1.7, 0.8)], [0.9, 0.9], sides=8)
        box(glow, (s * 7.7, -1.0, 0.5), (0.3, 0.3, 0.2))
    part(glow, "lights", "light")
    export(name)


# --- route and clutter pieces -------------------------------------------------

def log_bridge(name, seed):
    """A giant pine fallen across a ravine, 26 m along X, top of the trunk
    0.3 m above its origin (walk along it), root plate on -X, broken crown on +X."""
    rng = random.Random(seed)
    bm = new_bm()
    r = 0.8
    pts = [Vector((-13 + 26 * t, rng.uniform(-0.15, 0.15), -r + 0.3 - 0.25 * math.sin(t * math.pi))) for t in (0, 0.25, 0.5, 0.75, 1.0)]
    tapered_tube(bm, pts, [r * 1.15, r, r * 0.95, r * 0.85, r * 0.7], sides=8)
    for k in range(9):
        a = 2 * math.pi * k / 9
        d = Vector((0, math.cos(a), math.sin(a) * 0.9 + 0.2))
        p = Vector((-13.0, 0, -r + 0.3))
        tapered_tube(bm, [p, p + d * rng.uniform(1.6, 2.6) + Vector((-0.4, 0, 0))], [0.3, 0.08], sides=4)
    for k in range(8):
        x = rng.uniform(-9, 12)
        side = rng.choice((-1, 1))
        p = Vector((x, side * r * 0.7, -r + 0.2))
        tapered_tube(bm, [p, p + Vector((rng.uniform(-0.5, 0.5), side * rng.uniform(1.0, 2.0), rng.uniform(-1.5, 0.3)))], [0.16, 0.05], sides=4)
    part(bm, "log", "bark")
    moss = new_bm()
    for k in range(6):
        x = rng.uniform(-11, 11)
        blob(moss, (x, rng.uniform(-0.3, 0.3), 0.32), (1.1, 0.5, 0.12), rng, subdiv=1, wobble=0.15, seed=seed + k)
    part(moss, "moss", "leaves")
    export(name)


def tall_grass(name, seed):
    """A clump of tall reeds, about 1.4 m high and 1.6 m across: crouch in it."""
    rng = random.Random(seed)
    bm = new_bm()
    for k in range(22):
        a = rng.uniform(0, 2 * math.pi)
        base = Vector((math.cos(a), math.sin(a), 0)) * rng.uniform(0.0, 0.75)
        lean = Vector((math.cos(a), math.sin(a), 0)) * rng.uniform(0.1, 0.45)
        h = rng.uniform(1.0, 1.6)
        side = Vector((-math.sin(a), math.cos(a), 0)) * 0.07
        mid = base + lean * 0.4 + Vector((0, 0, h * 0.55))
        face2(bm, (base - side, base + side, mid + side * 0.7, mid - side * 0.7))
        face2(bm, (mid - side * 0.7, mid + side * 0.7, base + lean + Vector((0, 0, h))))
    part(bm, "blades", "grass_blade")
    export(name)


def barrels(name, seed):
    """Three fuel drums and one on its side, about 2 x 1 x 2 m."""
    rng = random.Random(seed)
    steel = new_bm()
    spots = [(-0.5, -0.35), (0.25, -0.4), (-0.1, 0.35)]
    for x, y in spots:
        cyl(steel, (x, y, 0), (x, y, 0.9), 0.3, sides=8)
    cyl(steel, (0.65, 0.45, 0.3), (0.65, 0.45 + 0.9, 0.3), 0.3, sides=8)
    part(steel, "drums", "titan_armor")
    band = new_bm()
    for x, y in spots:
        cyl(band, (x, y, 0.55), (x, y, 0.68), 0.31, sides=8)
    part(band, "bands", "anchor")
    export(name)


def pallet(name, seed):
    """Supply pallet: crates under a tied-down tarp, 2.4 W x 1.5 H x 1.6 D."""
    rng = random.Random(seed)
    wood = new_bm()
    box(wood, (0, 0, 0.08), (2.4, 1.6, 0.16))
    part(wood, "pallet", "wood")
    tarp = new_bm()
    box(tarp, (0, 0, 0.82), (2.3, 1.5, 1.3), bevel=0.15)
    part(tarp, "tarp", "canvas")
    rope = new_bm()
    for x in (-0.6, 0.6):
        tapered_tube(rope, [(x, -0.78, 0.2), (x, -0.78, 1.45), (x, 0.78, 1.45), (x, 0.78, 0.2)], [0.025] * 4, sides=3)
    part(rope, "ropes", "rope")
    export(name)


def generator(name):
    """Field generator on skids with an exhaust stack and a lit panel, 2 x 1.4 x 1.2."""
    steel = new_bm()
    box(steel, (0, 0, 0.75), (2.0, 1.2, 1.2), bevel=0.05)
    cyl(steel, (0.7, 0.3, 1.35), (0.7, 0.3, 2.1), 0.08, sides=5)
    for y in (-0.45, 0.45):
        box(steel, (0, y, 0.08), (2.2, 0.15, 0.16))
    part(steel, "body", "titan_armor")
    panel = new_bm()
    box(panel, (-0.4, -0.61, 0.9), (0.5, 0.03, 0.35))
    part(panel, "panel", "light")
    stripe = new_bm()
    box(stripe, (0, -0.61, 1.25), (1.9, 0.03, 0.12))
    part(stripe, "stripe", "anchor")
    export(name)


def camo_net(name, seed):
    """Camouflage netting sagging over four poles, 8 x 6 m, 3 m up at the poles."""
    rng = random.Random(seed)
    net = new_bm()
    nx, ny = 8, 6
    grid = []
    for i in range(nx + 1):
        row = []
        for j in range(ny + 1):
            u, v = i / nx, j / ny
            sag = math.sin(u * math.pi) * math.sin(v * math.pi) * 0.7
            row.append(Vector(((u - 0.5) * 8.4, (v - 0.5) * 6.4, 3.0 - sag + rng.uniform(-0.08, 0.08))))
        grid.append(row)
    for i in range(nx):
        for j in range(ny):
            if rng.random() < 0.08:
                continue
            face2(net, (grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]))
    # Ragged strips hanging off the edges.
    for k in range(10):
        i = rng.randint(0, nx)
        p = grid[i][0] if k % 2 else grid[i][ny]
        face2(net, (p, p + Vector((0.5, 0, 0)), p + Vector((0.3, 0, -rng.uniform(0.6, 1.4)))))
    part(net, "net", "leaves")
    poles = new_bm()
    for sx in (-1, 1):
        for sy in (-1, 1):
            cyl(poles, (sx * 4.0, sy * 3.0, 0), (sx * 4.0, sy * 3.0, 3.0), 0.06, sides=5)
    part(poles, "poles", "gunmetal")
    export(name)


def deer_stand(name):
    """A hunter's blind: a wooden box on stilts, floor at 3 m, open at the back
    (+Y) with a ladder, a slot window on the front (-Y)."""
    wood = new_bm()
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(wood, (sx * 1.0, sy * 1.0, 1.5), (0.16, 0.16, 3.0))
    box(wood, (0, 0, 2.95), (2.4, 2.4, 0.1))
    box(wood, (0, -1.15, 3.35), (2.4, 0.1, 0.7))   # front, below the slot
    box(wood, (0, -1.15, 4.25), (2.4, 0.1, 0.5))   # front, above the slot
    for sx in (-1, 1):
        box(wood, (sx * 1.15, 0, 3.7), (0.1, 2.4, 1.4))
    box(wood, (0, 0.1, 4.55), (2.8, 2.8, 0.12))  # roof
    for x in (-0.25, 0.25):
        box(wood, (x, 1.35, 1.5), (0.06, 0.06, 3.0))
    for k in range(7):
        box(wood, (0, 1.35, 0.35 + k * 0.4), (0.5, 0.05, 0.05))
    part(wood, "blind", "wood")
    leaves = new_bm()
    box(leaves, (0, 0.1, 4.68), (2.6, 2.6, 0.12))
    part(leaves, "thatch", "leaves")
    export(name)


def culvert(name):
    """A drainage culvert through the wall: concrete lintel over a 2.2 m opening,
    a steel grate torn half off its hinges. 4 W, origin at the bottom of the opening."""
    con = new_bm()
    box(con, (0, 0, 4.85), (4.0, 0.8, 5.7))       # wall above the opening
    for s in (-1, 1):
        box(con, (s * 1.65, 0, 1.1), (0.7, 1.0, 2.2))  # jambs
    box(con, (0, -0.05, 2.35), (4.0, 1.1, 0.3))  # lintel
    part(con, "frame", "concrete")
    grate = new_bm()
    # Hanging off the left jamb, swung out toward the pilot.
    for k in range(6):
        box(grate, (-1.25 + 0.05 * k, -0.6 - 0.18 * k, 1.1), (0.06, 0.06, 2.0), rot_z=0.4)
    box(grate, (-1.0, -0.9, 2.05), (0.1, 1.2, 0.08), rot_z=0.4)
    box(grate, (-1.0, -0.9, 0.2), (0.1, 1.2, 0.08), rot_z=0.4)
    part(grate, "grate", "gunmetal")
    band = new_bm()
    box(band, (0, -0.42, 4.6), (3.9, 0.04, 0.45))
    part(band, "band", "anchor")
    export(name)


def main():
    clear()
    pine("pine_a", 201, 14.0, 5)
    pine("pine_b", 211, 18.0, 6)
    pine("pine_c", 223, 10.0, 4)
    dead_pine("snag", 229, 11.0)
    fallen_log("log_fallen", 233, 9.0)
    stump("stump", 239)
    wall_slab("wall_slab", 241)
    gate("gate")
    watchtower("watchtower")
    hut("hut", 251)
    sandbags("sandbags", 257)
    crate_stack("crate_stack", 263)
    floodlight("floodlight")
    antenna("antenna")
    fuel_tank("fuel_tank")
    log_pile("log_pile", 269)
    sawmill("sawmill")
    bridge_stub("bridge_stub", 271)
    pylon("pylon")
    wreck_truck("wreck_truck", 277)
    evac_pad("evac_pad")
    dropship("dropship")
    log_bridge("log_bridge", 281)
    tall_grass("tall_grass", 283)
    barrels("barrels", 289)
    pallet("pallet", 293)
    generator("generator")
    camo_net("camo_net", 307)
    deer_stand("deer_stand")
    culvert("culvert")


main()
