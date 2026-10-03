"""Models the props for run zones 2 and 3 in Blender and exports them as glTF.

    blender -b --python tools/zones/build_props.py

Writes assets/models/marsh/<name>.glb (zone 2, Blackwater: swamp cypress,
cattail reeds, stilt huts, boardwalks and docks, the pipeline, the pump house,
storage tanks, a half-sunk barge and Eco's skiff) and
assets/models/boneyard/<name>.glb (zone 3, the Boneyard: dead titans, a
severed arm, trench revetments and wire, shipping containers, the salvage
gantry and shed, scrap heaps, and the precursor ruins: pillars, a fallen
obelisk and the eye shrine).

Same conventions as the forest props (tools/forest/build_props.py, whose
helpers this reuses): low-poly, flat shaded, objects named "<part>__<material>"
so the game swaps in its own materials, origins on the ground (or on the
walking surface for bridges), fronts facing -Y in Blender (+Z in Godot, the
way the pilot comes from). Sizes match the colliders in scripts/run/zone_kit.gd.

Seeded, so re-running gives the same meshes.
"""
import math
import random
from pathlib import Path

from mathutils import Vector

HERE = Path(__file__).resolve().parent
_src = (HERE.parent / "forest" / "build_props.py").read_text().rsplit("\nmain()", 1)[0]
FP = {"__file__": str(HERE.parent / "forest" / "build_props.py")}
exec(compile(_src, "forest_build_props", "exec"), FP)

import bpy  # noqa: E402

ROOT = HERE.parent.parent / "assets" / "models"
clear, part, new_bm, box, blob, tapered_tube, face2, cone, cyl = (
    FP["clear"], FP["part"], FP["new_bm"], FP["box"], FP["blob"], FP["tapered_tube"],
    FP["face2"], FP["cone"], FP["cyl"])

_out = ["marsh"]


def export(name):
    out = ROOT / _out[0]
    out.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(out / f"{name}.glb"), export_format="GLB", export_apply=True,
        export_yup=True, export_materials="PLACEHOLDER", export_normals=True,
        export_texcoords=False, export_colors=False,
    )
    print("wrote", _out[0], name)
    clear()


def plank_deck(bm, center, size, rng, gap=0.03, along_y=False):
    """A deck of planks (`size` x, y, thickness), slightly uneven."""
    cx, cy, cz = center
    sx, sy, t = size
    n = max(2, int((sx if not along_y else sy) / 0.3))
    w = (sx if not along_y else sy) / n
    for k in range(n):
        o = -((sx if not along_y else sy) * 0.5) + w * (k + 0.5)
        dz = rng.uniform(-0.02, 0.02)
        if along_y:
            box(bm, (cx, cy + o, cz + dz), (sx, w - gap, t))
        else:
            box(bm, (cx + o, cy, cz + dz), (w - gap, sy, t))


# =============================================================================
# Zone 2: Blackwater (the marsh)
# =============================================================================

def cypress(name, seed, height, dead=False):
    """A swamp cypress: a flared, buttressed base standing in the water, knees
    poking up round it, a crooked trunk, flat-topped clumps of needles and
    beards of moss hanging off the branches."""
    rng = random.Random(seed)
    trunk = new_bm()
    lean = Vector((rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), 0))
    pts = [Vector((0, 0, 0)), Vector((0, 0, 1.2)), lean * 0.4 + Vector((0, 0, height * 0.45)), lean + Vector((0, 0, height * 0.9))]
    tapered_tube(trunk, pts, [1.25, 0.6, 0.42, 0.18], sides=7)
    # Buttress roots flaring into the water.
    for k in range(6):
        a = 2 * math.pi * k / 6 + rng.uniform(-0.2, 0.2)
        d = Vector((math.cos(a), math.sin(a), 0))
        tapered_tube(trunk, [d * 0.3 + Vector((0, 0, 1.3)), d * 1.4 + Vector((0, 0, 0.2)), d * 2.0 + Vector((0, 0, -0.4))], [0.3, 0.2, 0.1], sides=4)
    # Knees: woody stumps sticking up out of the water.
    for k in range(5):
        a = rng.uniform(0, 2 * math.pi)
        d = Vector((math.cos(a), math.sin(a), 0)) * rng.uniform(2.2, 3.4)
        tapered_tube(trunk, [d + Vector((0, 0, -0.3)), d + Vector((0, 0, rng.uniform(0.4, 0.9)))], [0.18, 0.06], sides=4)
    branches = []
    for k in range(5 if not dead else 6):
        z = height * rng.uniform(0.45, 0.85)
        a = rng.uniform(0, 2 * math.pi)
        p = lean * (z / height) + Vector((0, 0, z))
        d = Vector((math.cos(a), math.sin(a), rng.uniform(0.15, 0.5))).normalized() * rng.uniform(2.0, 3.6)
        tapered_tube(trunk, [p, p + d], [0.16, 0.05], sides=4)
        branches.append(p + d)
    part(trunk, "trunk", "bark")
    if not dead:
        needles = new_bm()
        for tip in branches + [pts[-1]]:
            for j in range(2):
                blob(needles, tip + Vector((rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), 0.2 + j * 0.35)),
                     (rng.uniform(1.6, 2.3), rng.uniform(1.6, 2.3), 0.55), rng, subdiv=1, wobble=0.25, seed=seed + j)
        part(needles, "needles", "leaves")
    moss = new_bm()
    for tip in branches:
        for j in range(3):
            p = tip + Vector((rng.uniform(-0.8, 0.8), rng.uniform(-0.8, 0.8), -0.1))
            ln = rng.uniform(1.0, 2.4)
            face2(moss, (p + Vector((-0.12, 0, 0)), p + Vector((0.12, 0, 0)), p + Vector((0.03, 0.05, -ln))))
            face2(moss, (p + Vector((0, -0.12, 0)), p + Vector((0, 0.12, 0)), p + Vector((-0.04, 0.02, -ln * 0.8))))
    part(moss, "moss", "grass_blade")
    export(name)


def reeds(name, seed):
    """Cattails: a clump of tall blades and seed heads, about 2 m high, 2 m across."""
    rng = random.Random(seed)
    bm = new_bm()
    heads = new_bm()
    for k in range(26):
        a = rng.uniform(0, 2 * math.pi)
        base = Vector((math.cos(a), math.sin(a), -0.3)) * rng.uniform(0.0, 0.95)
        base.z = -0.3
        lean = Vector((math.cos(a), math.sin(a), 0)) * rng.uniform(0.05, 0.35)
        h = rng.uniform(1.4, 2.2)
        side = Vector((-math.sin(a), math.cos(a), 0)) * 0.06
        mid = base + lean * 0.5 + Vector((0, 0, h * 0.55))
        face2(bm, (base - side, base + side, mid + side * 0.6, mid - side * 0.6))
        face2(bm, (mid - side * 0.6, mid + side * 0.6, base + lean + Vector((0, 0, h))))
        if k % 3 == 0:
            top = base + lean * 0.8 + Vector((0, 0, h * 0.95))
            cyl(bm, base, top, 0.012, sides=3)
            cyl(heads, top, top + Vector((0, 0, 0.22)), 0.032, sides=5)
    part(bm, "blades", "grass_blade")
    part(heads, "heads", "bark")
    export(name)


def lily_pads(name, seed):
    """A raft of lily pads and duckweed, about 3 m across, sitting on the water."""
    rng = random.Random(seed)
    bm = new_bm()
    for k in range(14):
        c = Vector((rng.uniform(-1.4, 1.4), rng.uniform(-1.4, 1.4), rng.uniform(0.0, 0.02)))
        r = rng.uniform(0.18, 0.4)
        notch = rng.uniform(0, 2 * math.pi)
        rim = []
        for j in range(7):
            a = notch + 0.4 + j * (2 * math.pi - 0.8) / 6
            rim.append(c + Vector((math.cos(a) * r, math.sin(a) * r, 0)))
        face2(bm, [c] + rim)
    part(bm, "pads", "leaves")
    export(name)


def stilt_hut(name, seed):
    """A fishing hut on stilts the militia took over. Deck 6 x 6 with its top
    at 2.5 m, the cabin 4.4 W x 3.6 D x 2.6 H at the back of it, a low-pitched
    tin roof whose flat top is at 5.4 m (stand on it), a porch on the front
    (-Y) with a rail, and a ladder down to the water."""
    rng = random.Random(seed)
    wood = new_bm()
    for sx in (-2.7, 0, 2.7):
        for sy in (-2.7, 0, 2.7):
            tapered_tube(wood, [(sx, sy, -1.5), (sx + rng.uniform(-0.1, 0.1), sy, 2.4)], [0.14, 0.12], sides=5)
    for sy in (-2.7, 2.7):
        cyl(wood, (-2.8, sy, 0.6), (2.8, sy, 1.6), 0.05, sides=4)  # bracing
    plank_deck(wood, (0, 0, 2.42), (6.0, 6.0, 0.16), rng)
    # Cabin walls: vertical boards.
    for k in range(15):
        x = -2.2 + k * (4.4 / 14)
        box(wood, (x, 2.6, 3.8), (0.3, 0.1, 2.6))
    for s in (-1, 1):
        for k in range(12):
            y = -1.0 + k * (3.6 / 11)
            box(wood, (s * 2.2, y + 0.0, 3.8), (0.1, 0.3, 2.6))
    for k in range(15):
        x = -2.2 + k * (4.4 / 14)
        if -0.9 < x < 0.1:
            continue  # the doorway
        box(wood, (x, -1.0, 3.8), (0.3, 0.1, 2.6))
    box(wood, (-0.4, -1.0, 4.85), (1.1, 0.1, 0.5))  # over the door
    # Porch rail and the ladder.
    box(wood, (0, -2.95, 3.4), (6.0, 0.08, 0.08))
    for x in (-2.9, -1.0, 1.4, 2.9):
        box(wood, (x, -2.95, 3.0), (0.1, 0.1, 1.0))
    for x in (1.8, 2.4):
        box(wood, (x, -3.25, 0.9), (0.07, 0.07, 3.2))
    for k in range(7):
        box(wood, (2.1, -3.25, -0.2 + k * 0.4), (0.6, 0.05, 0.05))
    part(wood, "hut", "wood")
    tin = new_bm()
    # Low pitched roof: a flat walkable ridge strip, short slopes, eaves over the porch.
    box(tin, (0, 0.8, 5.3), (5.4, 4.8, 0.2))
    for s in (-1, 1):
        box(tin, (s * 2.9, 0.8, 5.05), (0.7, 4.8, 0.12))
    for k in range(9):
        box(tin, (-2.4 + k * 0.6, 0.8, 5.42), (0.06, 4.8, 0.05))
    cyl(tin, (1.4, 1.8, 5.4), (1.4, 1.8, 6.4), 0.12, sides=6)  # stove pipe
    part(tin, "roof", "gunmetal")
    win = new_bm()
    box(win, (1.2, -1.06, 3.9), (0.9, 0.04, 0.6))
    part(win, "window", "light")
    door = new_bm()
    box(door, (-0.4, -0.98, 3.6), (0.95, 0.05, 2.0))
    part(door, "door", "shadow")
    net = new_bm()
    # Fishing nets hung to dry along the side.
    for k in range(5):
        x = -2.0 + k * 0.9
        face2(net, ((x, -2.95, 3.4), (x + 0.8, -2.95, 3.4), (x + 0.6, -2.95, 2.5 - rng.uniform(0, 0.3)), (x + 0.1, -2.95, 2.6)))
    part(net, "nets", "rope")
    stripe = new_bm()
    box(stripe, (0, -1.08, 4.95), (4.0, 0.03, 0.18))
    part(stripe, "stripe", "anchor")
    export(name)


def boardwalk(name, seed):
    """A boardwalk segment: 2.2 W x 6 L (along Y), deck top at the origin,
    posts going 3 m down into the water and mud."""
    rng = random.Random(seed)
    wood = new_bm()
    plank_deck(wood, (0, 0, -0.08), (2.2, 6.0, 0.16), rng, along_y=True)
    for y in (-2.8, 0, 2.8):
        for x in (-1.0, 1.0):
            tapered_tube(wood, [(x, y, -3.0), (x + rng.uniform(-0.05, 0.05), y, -0.1)], [0.11, 0.1], sides=5)
        box(wood, (0, y, -0.25), (2.3, 0.15, 0.15))
    for x in (-1.05, 1.05):
        box(wood, (x, 0, -0.25), (0.12, 6.0, 0.12))
    part(wood, "walk", "wood")
    rope = new_bm()
    tapered_tube(rope, [(1.0, -2.8, 0.9), (1.0, -1.4, 0.75), (1.0, 0, 0.9), (1.0, 1.4, 0.75), (1.0, 2.8, 0.9)], [0.025] * 5, sides=3)
    for y in (-2.8, 0, 2.8):
        cyl(rope, (1.0, y, -0.1), (1.0, y, 0.95), 0.05, sides=4)
    part(rope, "rail", "rope")
    export(name)


def dock(name, seed):
    """A square dock 6 x 6, deck top at the origin, on posts 3 m deep, with
    mooring bollards and a stack of crab pots."""
    rng = random.Random(seed)
    wood = new_bm()
    plank_deck(wood, (0, 0, -0.08), (6.0, 6.0, 0.16), rng)
    for sx in (-2.8, 0, 2.8):
        for sy in (-2.8, 0, 2.8):
            tapered_tube(wood, [(sx, sy, -3.0), (sx, sy, -0.1)], [0.13, 0.12], sides=5)
    for s in (-2.9, 2.9):
        box(wood, (0, s, -0.25), (6.1, 0.15, 0.15))
        box(wood, (s, 0, -0.25), (0.15, 6.1, 0.15))
    for x, y in ((-2.7, -2.7), (2.7, -2.7)):
        cyl(wood, (x, y, -0.1), (x, y, 0.6), 0.16, sides=6)
    part(wood, "dock", "wood")
    pots = new_bm()
    for k in range(3):
        box(pots, (2.0, 2.0 - k * 0.1, 0.25 + k * 0.5), (0.8, 0.6, 0.48))
    part(pots, "pots", "rope")
    export(name)


def pipe_run(name):
    """12 m of the pumping station's main along X on two trestles: a 1.4 m pipe
    whose top is 3.6 m up (walk along it), flanged every 4 m."""
    steel = new_bm()
    tapered_tube(steel, [(-6.0, 0, 2.9), (6.0, 0, 2.9)], [0.7, 0.7], sides=10)
    for x in (-4.0, 0.0, 4.0):
        tapered_tube(steel, [(x - 0.12, 0, 2.9), (x + 0.12, 0, 2.9)], [0.82, 0.82], sides=10)
    part(steel, "pipe", "titan_armor")
    frame = new_bm()
    for x in (-3.0, 3.0):
        for s in (-1, 1):
            box(frame, (x, s * 0.9, 1.1), (0.25, 0.25, 2.4))
        box(frame, (x, 0, 2.15), (0.4, 2.2, 0.3))
        cyl(frame, (x, -0.9, 0.0), (x, 0.9, 2.0), 0.05, sides=4)
        box(frame, (x, 0, 0.1), (0.7, 2.4, 0.2))
    part(frame, "trestles", "gunmetal")
    band = new_bm()
    tapered_tube(band, [(-1.8, 0, 2.9), (-1.5, 0, 2.9)], [0.72, 0.72], sides=10)
    tapered_tube(band, [(1.5, 0, 2.9), (1.8, 0, 2.9)], [0.72, 0.72], sides=10)
    part(band, "bands", "anchor")
    export(name)


def pump_house(name, seed):
    """The pumping station: a concrete block 14 W x 10 D, flat roof top at 6 m
    with a low lip and vents to crouch behind, big intake pipes dropping into the
    water on the left, a roller door and lit windows on the front, vents and a
    railing on the roof."""
    rng = random.Random(seed)
    con = new_bm()
    box(con, (0, 0, 2.9), (14.0, 10.0, 5.8), bevel=0.05)
    box(con, (0, 0, 5.9), (14.4, 10.4, 0.2))
    for s in (-1, 1):
        box(con, (s * 7.1, 0, 6.05), (0.2, 10.4, 0.1))
    for s in (-1, 1):
        box(con, (0, s * 5.1, 6.05), (14.4, 0.2, 0.1))
    # Buttresses.
    for x in (-6.8, -2.3, 2.3, 6.8):
        box(con, (x, -5.15, 2.6), (0.6, 0.5, 5.2))
    # Stained band near the bottom where floods reach.
    part(con, "block", "concrete")
    steel = new_bm()
    for k, y in enumerate((-2.5, 2.0)):
        tapered_tube(steel, [(-7.0, y, 4.2), (-8.6, y, 4.2), (-9.4, y, 3.0), (-9.6, y, -1.5)], [0.75, 0.75, 0.75, 0.75], sides=10)
    box(steel, (2.5, -5.2, 2.1), (4.2, 0.2, 4.2))  # roller door
    for k in range(10):
        box(steel, (2.5, -5.32, 0.3 + k * 0.42), (4.2, 0.06, 0.06))
    box(steel, (-3.5, 2.5, 6.6), (2.0, 2.0, 1.2))  # roof vents
    box(steel, (3.5, 2.0, 6.5), (3.0, 1.6, 0.9))
    cyl(steel, (5.5, 3.5, 6.0), (5.5, 3.5, 9.0), 0.25, sides=6)
    part(steel, "pipes", "gunmetal")
    win = new_bm()
    for x in (-5.0, -2.5):
        box(win, (x, -5.03, 3.6), (1.6, 0.06, 0.8))
    box(win, (2.5, -5.35, 4.5), (0.5, 0.2, 0.3))
    part(win, "windows", "light")
    band = new_bm()
    box(band, (0, -5.22, 4.9), (13.6, 0.04, 0.4))
    box(band, (2.5, -5.36, 0.2), (4.2, 0.04, 0.3))
    part(band, "band", "anchor")
    grime = new_bm()
    box(grime, (0, -5.04, 0.6), (13.8, 0.03, 1.2))
    part(grime, "flood_line", "moss")
    export(name)


def storage_tank(name):
    """A squat fuel storage tank, 7 m across, roof at 6 m, banded and dented,
    with a walkway ring on top and a stair column up its side (+X)."""
    steel = new_bm()
    tapered_tube(steel, [(0, 0, 0), (0, 0, 6.0)], [3.5, 3.5], sides=16)
    cone(steel, (0, 0, 6.0), 3.6, 0.7, sides=16)
    part(steel, "tank", "titan_armor")
    band = new_bm()
    for z in (1.6, 4.4):
        tapered_tube(band, [(0, 0, z), (0, 0, z + 0.3)], [3.53, 3.53], sides=16)
    part(band, "bands", "anchor")
    frame = new_bm()
    for k in range(16):
        a = 2 * math.pi * k / 16
        box(frame, (math.cos(a) * 3.7, math.sin(a) * 3.7, 6.4), (0.06, 0.06, 0.9))
    tapered_tube(frame, [(0, 0, 6.85), (0, 0, 6.9)], [3.72, 3.72], sides=16)
    for k in range(12):
        box(frame, (3.9, -1.5 + k * 0.25, 0.25 + k * 0.5), (0.8, 0.3, 0.06))
    box(frame, (4.3, 0, 3.0), (0.06, 3.4, 6.0))
    part(frame, "stair", "gunmetal")
    grime = new_bm()
    tapered_tube(grime, [(0, 0, 0), (0, 0, 0.8)], [3.52, 3.52], sides=16)
    part(grime, "flood_line", "moss")
    export(name)


def barge(name, seed):
    """A rusted barge run aground, 17 m along X, 5 m wide. Its
    near side stands out of the water as a sheer 5 m wall painted with the
    wallrun stripes (the game puts the run along it); the deck tilts away."""
    rng = random.Random(seed)
    hull = new_bm()
    box(hull, (0, 0.6, 0.5), (17.0, 4.6, 3.0))
    box(hull, (8.8, 0.6, 1.2), (1.4, 4.2, 2.2))
    box(hull, (-6.0, 1.4, 3.2), (3.0, 2.6, 2.4))  # wheelhouse
    for k in range(6):
        box(hull, (rng.uniform(-6, 6), rng.uniform(0.0, 2.0), 2.1), (rng.uniform(0.8, 1.8), 1.2, 0.5))  # junk on the deck
    part(hull, "hull", "titan_armor")
    side = new_bm()
    box(side, (0, -1.85, 1.0), (17.0, 0.3, 5.0))
    part(side, "side", "wallrun")
    rust = new_bm()
    for k in range(5):
        blob(rust, (rng.uniform(-6.5, 6.5), -2.0, rng.uniform(-1.0, 2.5)), (0.9, 0.1, 0.7), rng, subdiv=1, wobble=0.25, seed=seed + k)
    part(rust, "rust", "shadow")
    glass = new_bm()
    box(glass, (-6.0, 0.08, 3.8), (2.2, 0.05, 0.7))
    part(glass, "windows", "shadow")
    export(name)


def skiff(name, seed):
    """Eco's flat-bottomed skiff, pulled up on the bank, 4 m long, with a pole."""
    rng = random.Random(seed)
    wood = new_bm()
    box(wood, (0, 0, 0.12), (1.2, 4.0, 0.12))
    for s in (-1, 1):
        box(wood, (s * 0.62, 0, 0.35), (0.08, 4.0, 0.5))
    box(wood, (0, 1.95, 0.35), (1.2, 0.08, 0.5))
    box(wood, (0, -1.95, 0.45), (1.0, 0.08, 0.4))
    box(wood, (0, 0.6, 0.45), (1.2, 0.3, 0.06))
    part(wood, "skiff", "wood")
    pole = new_bm()
    cyl(pole, (-0.3, -2.6, 0.5), (0.4, 2.8, 0.3), 0.04, sides=4)
    part(pole, "pole", "bark")
    bag = new_bm()
    blob(bag, (0.1, -0.8, 0.45), (0.35, 0.45, 0.28), rng, subdiv=1, wobble=0.1, seed=seed)
    part(bag, "pack", "canvas")
    export(name)


# =============================================================================
# Zone 3: the Boneyard (the titan graveyard)
# =============================================================================

def _plates(bm, center, size, rng, n=6):
    """Loose armour plates overlapping on a hull."""
    cx, cy, cz = center
    for k in range(n):
        box(bm, (cx + rng.uniform(-size[0], size[0]) * 0.4, cy + rng.uniform(-size[1], size[1]) * 0.4, cz + rng.uniform(-0.1, 0.1)),
            (size[0] * rng.uniform(0.3, 0.5), size[1] * rng.uniform(0.3, 0.5), 0.18), rot_z=rng.uniform(-0.3, 0.3), bevel=0.04)


def titan_fallen(name, seed):
    """A dead titan lying face down, about 26 m from the crown of its head (-X)
    to its boots (+X). The flat of its back is the walking surface, 2.2 m wide,
    and sits at the origin; the body hangs 3.5 m below it, so it lies on
    flat ground with its back 3.5 m up, or spans a gap as a bridge. One arm
    reaches forward past its head, the other is folded under it."""
    rng = random.Random(seed)
    armor = new_bm()
    # Back plate (the walkway) from shoulders to hips, then the legs.
    box(armor, (-3.5, 0, -0.5), (13.0, 2.6, 1.0), bevel=0.08)
    box(armor, (-3.5, 0, -2.0), (12.0, 5.2, 2.6), bevel=0.15)  # torso
    for s in (-1, 1):
        box(armor, (-8.0, s * 3.2, -1.6), (3.2, 2.0, 2.4), bevel=0.12)  # shoulder pauldrons
    box(armor, (4.2, 0, -1.2), (2.8, 3.6, 2.2), bevel=0.1)  # hips
    for s in (-1, 1):
        box(armor, (7.8, s * 1.1, -0.75), (5.0, 1.4, 1.4), bevel=0.08)   # thighs
        box(armor, (11.0, s * 1.2, -1.2), (1.4, 1.6, 2.2), bevel=0.06)   # knees
        box(armor, (12.4, s * 1.3, -2.4), (1.6, 1.8, 2.0), bevel=0.06)   # boots
    # Head, turned to the side, half buried.
    box(armor, (-11.2, 0.4, -1.0), (2.4, 2.4, 2.0), rot_z=0.3, bevel=0.15)
    # Forward arm past the head.
    box(armor, (-12.0, -3.2, -2.7), (5.0, 1.4, 1.4), rot_z=0.15, bevel=0.06)
    box(armor, (-15.0, -3.6, -2.9), (1.8, 2.0, 1.0), bevel=0.06)  # the hand
    _plates(armor, (-3.5, 0, 0.04), (12.0, 2.4, 0), rng, n=7)
    part(armor, "hull", "titan_armor")
    frame = new_bm()
    # Exposed frame where plates are torn off: ribs, spine, hydraulics.
    for k in range(7):
        x = -8.0 + k * 1.6
        box(frame, (x, 0, -1.1), (0.3, 5.6, 0.3))
    for s in (-1, 1):
        cyl(frame, (1.0, s * 1.6, -1.0), (6.0, s * 1.4, -1.0), 0.14, sides=5)
        cyl(frame, (6.0, s * 1.2, -0.6), (10.5, s * 1.2, -0.7), 0.1, sides=5)
    box(frame, (-10.0, 0, -0.9), (1.2, 1.2, 1.2))  # neck
    for k in range(4):
        a = rng.uniform(0, 2 * math.pi)
        p = Vector((rng.uniform(-6, 2), rng.uniform(-2.6, 2.6), -0.9))
        cyl(frame, p, p + Vector((math.cos(a), math.sin(a), rng.uniform(0.2, 0.8))) * 1.6, 0.06, sides=3)  # torn cables
    part(frame, "frame", "gunmetal")
    eye = new_bm()
    box(eye, (-12.45, 0.0, -0.9), (0.1, 1.2, 0.25), rot_z=0.3)
    part(eye, "eye", "shadow")
    soot = new_bm()
    for k in range(5):
        blob(soot, (rng.uniform(-8, 6), rng.uniform(-2.0, 2.0), 0.05), (1.4, 0.9, 0.08), rng, subdiv=1, wobble=0.2, seed=seed + k)
    part(soot, "soot", "shadow")
    band = new_bm()
    box(band, (-3.5, -2.62, -1.6), (11.0, 0.04, 0.45))
    part(band, "band", "anchor")
    export(name)


def titan_kneeling(name, seed):
    """A dead titan slumped on one knee, about 9 m tall at the shoulders, chin
    on its chest, one arm hanging to the ground. Faces -Y. Its shoulders make a
    ledge 8 m up, its bent knee a step at 2.8 m."""
    rng = random.Random(seed)
    armor = new_bm()
    box(armor, (0, 0.6, 2.9), (3.2, 2.4, 1.6), bevel=0.1)  # pelvis
    box(armor, (-1.0, -1.4, 1.4), (1.5, 3.0, 1.4), bevel=0.08)  # forward thigh
    box(armor, (-1.0, -2.6, 0.9), (1.5, 1.4, 1.8), bevel=0.06)  # shin up
    box(armor, (1.2, 1.2, 1.0), (1.5, 2.8, 1.2), bevel=0.06)  # rear shin on the ground
    box(armor, (0, 0.3, 5.6), (5.0, 3.4, 4.0), bevel=0.2)  # torso, leaning forward
    box(armor, (0, -0.8, 7.4), (6.4, 2.6, 1.4), bevel=0.12)  # shoulder yoke (the ledge)
    for s in (-1, 1):
        box(armor, (s * 3.6, -0.3, 7.0), (1.8, 2.4, 2.0), bevel=0.12)
    box(armor, (0, -1.6, 6.5), (1.6, 1.6, 1.3), bevel=0.1)  # head slumped forward
    box(armor, (-3.7, -0.8, 3.6), (1.2, 1.2, 4.2), bevel=0.06)  # left arm hanging
    box(armor, (-3.8, -1.2, 0.8), (1.6, 1.6, 1.4), bevel=0.06)  # its fist on the ground
    box(armor, (3.8, -1.6, 5.2), (1.2, 1.2, 3.0), bevel=0.06)  # right arm bent
    _plates(armor, (0, 0.0, 8.15), (6.0, 2.4, 0), rng, n=4)
    part(armor, "hull", "titan_armor")
    frame = new_bm()
    for s in (-1, 1):
        cyl(frame, (s * 1.2, 0.6, 3.5), (s * 1.6, 0.4, 6.5), 0.18, sides=5)
    box(frame, (0, 2.1, 5.0), (3.0, 0.6, 2.6))  # open back hatch
    for k in range(3):
        a = rng.uniform(0, 2 * math.pi)
        p = Vector((rng.uniform(-1, 1), 2.0, rng.uniform(4.0, 6.0)))
        cyl(frame, p, p + Vector((math.cos(a) * 0.5, 0.8, -1.4)), 0.05, sides=3)
    part(frame, "frame", "gunmetal")
    eye = new_bm()
    box(eye, (0, -2.42, 6.4), (1.0, 0.04, 0.22))
    part(eye, "eye", "shadow")
    hole = new_bm()
    blob(hole, (1.0, -1.35, 5.4), (0.9, 0.2, 0.9), rng, subdiv=1, wobble=0.2, seed=seed)
    part(hole, "breach", "shadow")
    band = new_bm()
    box(band, (0, -2.12, 7.4), (6.0, 0.04, 0.35))
    part(band, "band", "anchor")
    export(name)


def titan_arm(name, seed):
    """A titan's arm torn off at the shoulder, lying along X, 9 m long, about
    2 m high: pilot cover, with the fingers curled."""
    rng = random.Random(seed)
    armor = new_bm()
    box(armor, (-2.5, 0, 0.9), (4.4, 1.8, 1.8), bevel=0.1)
    box(armor, (1.6, 0.2, 0.75), (3.6, 1.5, 1.5), rot_z=0.12, bevel=0.08)
    box(armor, (-0.3, 0, 1.0), (1.2, 1.9, 1.9), bevel=0.08)  # elbow
    box(armor, (3.9, 0.5, 0.6), (1.2, 1.6, 1.2), bevel=0.06)  # hand
    for k in range(3):
        box(armor, (4.7, 0.0 + k * 0.5, 0.4), (0.8, 0.35, 0.35), rot_z=0.3)
    part(armor, "hull", "titan_armor")
    frame = new_bm()
    box(frame, (-4.9, 0, 0.9), (0.6, 1.3, 1.3))
    for k in range(5):
        a = rng.uniform(0, 2 * math.pi)
        p = Vector((-5.1, rng.uniform(-0.4, 0.4), rng.uniform(0.6, 1.2)))
        cyl(frame, p, p + Vector((-1.2, math.cos(a) * 0.6, math.sin(a) * 0.4 - 0.4)), 0.06, sides=3)
    part(frame, "frame", "gunmetal")
    band = new_bm()
    box(band, (-2.5, -0.92, 1.2), (3.6, 0.04, 0.3))
    part(band, "band", "anchor")
    export(name)


def revetment(name, seed):
    """A trench wall: 4 m of planks and corrugated sheet held by posts, 2.2 m
    high, with sandbags along the top lip. The face is -Y (inside the trench)."""
    rng = random.Random(seed)
    wood = new_bm()
    for x in (-1.9, 0.0, 1.9):
        box(wood, (x, -0.05, 1.1), (0.16, 0.16, 2.4))
    for k in range(5):
        box(wood, (0, 0.05, 0.25 + k * 0.42), (4.0, 0.08, 0.38), rot_z=rng.uniform(-0.01, 0.01))
    part(wood, "planks", "wood")
    sheet = new_bm()
    box(sheet, (rng.uniform(-0.8, 0.8), -0.02, 1.0), (1.6, 0.04, 1.6), rot_z=0.0)
    part(sheet, "sheet", "gunmetal")
    bags = new_bm()
    for k in range(5):
        blob(bags, (-1.6 + k * 0.8, 0.25, 2.35), (0.42, 0.3, 0.18), rng, subdiv=1, wobble=0.1, seed=seed + k)
    part(bags, "bags", "canvas")
    export(name)


def barbed_wire(name, seed):
    """Wire on X-shaped stakes, 4 m along X, about 1 m high. Jump it."""
    rng = random.Random(seed)
    wood = new_bm()
    for x in (-1.8, 0.0, 1.8):
        cyl(wood, (x - 0.4, 0, 0), (x + 0.4, 0, 1.0), 0.05, sides=4)
        cyl(wood, (x + 0.4, 0, 0), (x - 0.4, 0, 1.0), 0.05, sides=4)
    part(wood, "stakes", "wood")
    wire = new_bm()
    for k in range(18):
        a = k * 0.9
        x = -2.0 + k * 0.23
        cyl(wire, (x, math.cos(a) * 0.35, 0.5 + math.sin(a) * 0.35), (x + 0.23, math.cos(a + 0.9) * 0.35, 0.5 + math.sin(a + 0.9) * 0.35), 0.02, sides=3)
    for z in (0.3, 0.75):
        tapered_tube(wire, [(-2.0, 0, z), (0, 0.05, z - 0.08), (2.0, 0, z)], [0.015] * 3, sides=3)
    part(wire, "wire", "gunmetal")
    export(name)


def container(name, seed):
    """A shipping container, 6 L (X) x 2.6 H x 2.4 W, ribbed, doors on +X, dented."""
    rng = random.Random(seed)
    steel = new_bm()
    box(steel, (0, 0, 1.3), (6.0, 2.4, 2.6))
    for k in range(13):
        x = -2.85 + k * 0.475
        for s in (-1, 1):
            box(steel, (x, s * 1.23, 1.3), (0.14, 0.08, 2.45))
    part(steel, "box", "titan_armor")
    trim = new_bm()
    for s in (-1, 1):
        box(trim, (s * 2.95, 0, 1.3), (0.12, 2.5, 2.7))
    for z in (0.05, 2.55):
        box(trim, (0, 0, z), (6.1, 2.5, 0.1))
    for y in (-0.4, 0.4):
        cyl(trim, (3.05, y, 0.2), (3.05, y, 2.4), 0.04, sides=4)
    part(trim, "frame", "gunmetal")
    band = new_bm()
    box(band, (-1.0, -1.28, 1.9), (2.6, 0.03, 0.5))
    part(band, "stencil", "anchor")
    export(name)


def gantry(name):
    """The salvage gantry crane: two A-frame legs 16 m apart along X, the
    girder's underside 12 m up, a trolley in the middle with a chain and a
    hook hanging to 8 m (the grapple anchor sits on the trolley in the game)."""
    steel = new_bm()
    for s in (-1, 1):
        for y in (-1.6, 1.6):
            tapered_tube(steel, [(s * 8.0, y, 0), (s * 8.0, y * 0.4, 12.0)], [0.3, 0.25], sides=6)
        cyl(steel, (s * 8.0, -1.4, 3.0), (s * 8.0, 1.4, 3.0), 0.12, sides=4)
        cyl(steel, (s * 8.0, -1.2, 7.0), (s * 8.0, 1.2, 7.0), 0.12, sides=4)
        box(steel, (s * 8.0, 0, 0.2), (1.4, 4.0, 0.4))
    box(steel, (0, 0, 12.6), (17.4, 1.2, 1.2))
    for k in range(9):
        x = -8.0 + k * 2.0
        cyl(steel, (x, 0, 13.2), (x + 2.0, 0, 12.0), 0.06, sides=4)
    part(steel, "frame", "gunmetal")
    chain = new_bm()
    for k in range(10):
        box(chain, (0, 0, 11.5 - k * 0.32), (0.1, 0.2, 0.28), rot_z=(k % 2) * math.pi * 0.5)
    tapered_tube(chain, [(0, 0, 8.2), (0, 0, 7.6), (0.4, 0, 7.3), (0.7, 0, 7.7)], [0.15, 0.15, 0.12, 0.08], sides=5)
    part(chain, "hook", "titan_armor")
    band = new_bm()
    box(band, (0, -0.62, 12.6), (16.0, 0.04, 0.5))
    for s in (-1, 1):
        box(band, (s * 8.0, -1.72, 1.0), (0.5, 0.04, 2.0))
    part(band, "band", "anchor")
    lamp = new_bm()
    for s in (-1, 1):
        box(lamp, (s * 6.0, -0.65, 12.2), (0.5, 0.1, 0.3))
    part(lamp, "lamps", "light")
    export(name)


def salvage_shed(name, seed):
    """An open steel shed the strippers work under: 12 W x 8 D, roof top at 5 m
    (stand on it), a workbench of cut plates, chains, a lit panel."""
    rng = random.Random(seed)
    steel = new_bm()
    for x in (-5.8, 0, 5.8):
        for y in (-3.8, 3.8):
            box(steel, (x, y, 2.4), (0.3, 0.3, 4.8))
    for y in (-3.8, 3.8):
        box(steel, (0, y, 4.6), (12.0, 0.3, 0.3))
    box(steel, (0, 0, 0.5), (7.0, 1.4, 1.0))
    part(steel, "frame", "gunmetal")
    roof = new_bm()
    box(roof, (0, 0, 4.88), (12.4, 8.4, 0.24))
    part(roof, "roof", "canvas")
    plates = new_bm()
    for k in range(5):
        box(plates, (-3.0 + k * 1.4, rng.uniform(-0.3, 0.3), 1.1 + rng.uniform(0, 0.2)), (1.2, 1.0, 0.12), rot_z=rng.uniform(-0.4, 0.4))
    part(plates, "plates", "titan_armor")
    chain = new_bm()
    for x in (-3.0, 3.0):
        cyl(chain, (x, 0, 4.6), (x, 0, 2.2), 0.04, sides=3)
    part(chain, "chains", "gunmetal")
    panel = new_bm()
    box(panel, (5.6, -3.6, 1.6), (0.5, 0.1, 0.6))
    part(panel, "panel", "light")
    band = new_bm()
    box(band, (0, -4.22, 4.88), (12.2, 0.04, 0.2))
    part(band, "band", "anchor")
    export(name)


def scrap_pile(name, seed):
    """A heap of stripped plates, girders and a titan's helmet, about 4 m
    across and 2 m high: pilot cover."""
    rng = random.Random(seed)
    armor = new_bm()
    for k in range(9):
        r = rng.uniform(0, 1.4)
        a = rng.uniform(0, 2 * math.pi)
        z = 0.2 + (1.4 - r) * 1.0
        box(armor, (math.cos(a) * r, math.sin(a) * r, z), (rng.uniform(0.9, 1.6), rng.uniform(0.7, 1.2), 0.16),
            rot_z=rng.uniform(0, math.pi), bevel=0.03)
    blob(armor, (0, 0, 0.4), (1.8, 1.6, 0.8), rng, subdiv=1, wobble=0.25, seed=seed)
    part(armor, "plates", "titan_armor")
    steel = new_bm()
    for k in range(4):
        a = rng.uniform(0, math.pi)
        p = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), 0.6))
        box(steel, tuple(p + Vector((0, 0, 0.4))), (3.2, 0.25, 0.3), rot_z=a)
    part(steel, "girders", "gunmetal")
    helm = new_bm()
    box(helm, (0.6, -0.4, 1.7), (1.2, 1.0, 0.8), rot_z=0.5, bevel=0.15)
    part(helm, "helmet", "titan_armor")
    eye = new_bm()
    box(eye, (0.42, -0.95, 1.75), (0.7, 0.05, 0.14), rot_z=0.5)
    part(eye, "eye", "shadow")
    export(name)


def ruin_pillar(name, seed, height):
    """A precursor column, 2 x 2, carved with the god's eye near the top,
    weathered and leaning a touch. Top is flat (stand on it)."""
    rng = random.Random(seed)
    stone = new_bm()
    box(stone, (0, 0, 0.3), (2.6, 2.6, 0.6))
    k = 0
    z = 0.6
    while z < height - 0.6:
        seg = min(rng.uniform(1.4, 2.2), height - 0.6 - z)
        box(stone, (rng.uniform(-0.04, 0.04), rng.uniform(-0.04, 0.04), z + seg * 0.5), (2.0, 2.0, seg - 0.04), rot_z=rng.uniform(-0.03, 0.03), bevel=0.05)
        z += seg
        k += 1
    box(stone, (0, 0, height - 0.3), (2.4, 2.4, 0.6), bevel=0.05)
    part(stone, "column", "temple_stone")
    carve = new_bm()
    box(carve, (0, -1.02, height - 1.6), (1.4, 0.06, 0.9))
    part(carve, "carving", "temple_carving")
    eye = new_bm()
    box(eye, (0, -1.06, height - 1.6), (0.5, 0.04, 0.22))
    part(eye, "eye", "light")
    moss = new_bm()
    blob(moss, (0.5, -0.6, height - 0.02), (0.9, 0.8, 0.12), rng, subdiv=1, wobble=0.2, seed=seed)
    part(moss, "moss", "moss")
    export(name)


def obelisk_fallen(name, seed):
    """A precursor obelisk that fell across the rift: 28 m along X, 2.4 m
    square, the top face (walk along it) at the origin, its broken base on -X
    and the capstone with the god's eye on +X."""
    rng = random.Random(seed)
    stone = new_bm()
    x = -14.0
    while x < 12.5:
        seg = rng.uniform(2.6, 3.6)
        seg = min(seg, 12.5 - x)
        box(stone, (x + seg * 0.5, rng.uniform(-0.03, 0.03), -1.2 + rng.uniform(-0.02, 0.02)), (seg - 0.06, 2.4, 2.4), rot_z=rng.uniform(-0.01, 0.01), bevel=0.04)
        x += seg
    part(stone, "obelisk", "temple_stone")
    cap = new_bm()
    pts = [Vector((12.5, -1.2, -2.4)), Vector((12.5, 1.2, -2.4)), Vector((12.5, 1.2, 0.0)), Vector((12.5, -1.2, 0.0))]
    apex = Vector((14.8, 0, -1.2))
    for k in range(4):
        cap.faces.new((cap.verts.new(pts[k]), cap.verts.new(pts[(k + 1) % 4]), cap.verts.new(apex)))
    part(cap, "cap", "temple_carving")
    carve = new_bm()
    for k in range(6):
        box(carve, (-9.0 + k * 3.6, -1.22, -1.2), (1.6, 0.04, 1.4))
    part(carve, "glyphs", "temple_carving")
    eye = new_bm()
    box(eye, (11.6, -1.24, -1.2), (0.7, 0.04, 0.3))
    part(eye, "eye", "light")
    rubble = new_bm()
    for k in range(6):
        blob(rubble, (-14.2 + rng.uniform(-0.8, 0.4), rng.uniform(-1.4, 1.4), -1.6 + rng.uniform(-0.6, 0.6)), (0.6, 0.5, 0.5), rng, subdiv=1, wobble=0.3, seed=seed + k)
    part(rubble, "rubble", "temple_stone")
    moss = new_bm()
    for k in range(5):
        blob(moss, (rng.uniform(-11, 10), rng.uniform(-0.6, 0.6), 0.02), (1.2, 0.6, 0.08), rng, subdiv=1, wobble=0.2, seed=seed + 10 + k)
    part(moss, "moss", "moss")
    export(name)


def eye_shrine(name, seed):
    """The precursor shrine on the far hill: a stepped platform, two broken
    columns and a standing stone with the god's great eye, still faintly lit."""
    rng = random.Random(seed)
    stone = new_bm()
    box(stone, (0, 0, 0.3), (10.0, 8.0, 0.6), bevel=0.05)
    box(stone, (0, 0.6, 0.85), (7.0, 5.6, 0.5), bevel=0.05)
    box(stone, (0, 1.6, 3.6), (3.2, 1.4, 5.0), bevel=0.08)  # the standing stone
    for s in (-1, 1):
        box(stone, (s * 4.0, -2.6, 2.0), (1.4, 1.4, 3.4 + s * 0.8), bevel=0.05)
    for k in range(5):
        blob(stone, (rng.uniform(-5, 5), rng.uniform(-4.5, -3.0), 0.3), (0.6, 0.5, 0.4), rng, subdiv=1, wobble=0.3, seed=seed + k)
    part(stone, "shrine", "temple_stone")
    carve = new_bm()
    box(carve, (0, 0.88, 4.3), (2.6, 0.04, 2.4))
    part(carve, "carving", "temple_carving")
    eye = new_bm()
    box(eye, (0, 0.85, 4.3), (1.4, 0.04, 0.5))
    box(eye, (0, 0.84, 4.3), (0.45, 0.04, 0.45))
    part(eye, "eye", "light")
    moss = new_bm()
    for k in range(4):
        blob(moss, (rng.uniform(-4, 4), rng.uniform(-3, 3), 0.62), (1.0, 0.8, 0.08), rng, subdiv=1, wobble=0.2, seed=seed + 7 + k)
    part(moss, "moss", "moss")
    export(name)


def main():
    clear()
    _out[0] = "marsh"
    cypress("cypress_a", 401, 13.0)
    cypress("cypress_b", 409, 16.0)
    cypress("cypress_dead", 419, 12.0, dead=True)
    reeds("reeds", 421)
    lily_pads("lily_pads", 431)
    stilt_hut("stilt_hut", 433)
    boardwalk("boardwalk", 439)
    dock("dock", 443)
    pipe_run("pipe_run")
    pump_house("pump_house", 449)
    storage_tank("storage_tank")
    barge("barge", 457)
    skiff("skiff", 461)
    _out[0] = "boneyard"
    titan_fallen("titan_fallen", 503)
    titan_kneeling("titan_kneeling", 509)
    titan_arm("titan_arm", 521)
    revetment("revetment", 523)
    barbed_wire("barbed_wire", 541)
    container("container", 547)
    gantry("gantry")
    salvage_shed("salvage_shed", 557)
    scrap_pile("scrap_pile", 563)
    ruin_pillar("ruin_pillar", 569, 8.0)
    ruin_pillar("ruin_pillar_short", 571, 4.5)
    obelisk_fallen("obelisk_fallen", 577)
    eye_shrine("eye_shrine", 587)


main()
