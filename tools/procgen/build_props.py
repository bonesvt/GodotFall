"""Models the generated zones' own set pieces in Blender and exports them as glTF.

    blender -b --python tools/procgen/build_props.py
    (or: python3 tools/procgen/build_props.py, with the bpy module installed)

Writes assets/models/procgen/<name>.glb and scripts/run/procgen/prop_shapes.gd,
which holds every model's colliders, grapple hooks and standing surfaces so the
game's colliders always match the meshes. The pieces are shared by all three
biomes (the game tints their materials per biome: set_pieces.gd):

  buildings: bunker, blockhouse (stairs to the roof), garage, warehouse, silo,
    water tower, scaffold, two bombed-out house shells, a tower crane
  movement: billboards to wallrun (short, medium, long), blast-wall sections,
    a kick slot (two walls to wall-jump up between, a deck on top), a leaning
    slab, grapple masts (tall and short) and a hook bracket
  props: jersey barrier, tank trap, tyre stack, cable reel, burnt-out jeep,
    fire barrel, concrete pipes, a supply pod, a warning sign, a sandbag nest

Same conventions as the forest props (tools/forest/build_props.py, whose
helpers this reuses): low-poly, flat shaded, objects named "<part>__<material>",
origins on the ground, fronts facing -Y in Blender (+Z in Godot, the way the
pilot comes from). Orange ("anchor") marks a grapple hook, blue ("wallrun") a
wall made to run or kick off.

Seeded, so re-running gives the same meshes.
"""
import math
import random
from pathlib import Path

import bpy  # noqa: F401  (first: the bpy module brings bmesh and mathutils)
import bmesh
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
_src = (HERE.parent / "forest" / "build_props.py").read_text().rsplit("\nmain()", 1)[0]
FP = {"__file__": str(HERE.parent / "forest" / "build_props.py")}
exec(compile(_src, "forest_build_props", "exec"), FP)

import bpy  # noqa: E402

REPO = HERE.parent.parent
OUT = REPO / "assets" / "models" / "procgen"
SHAPES_GD = REPO / "scripts" / "run" / "procgen" / "prop_shapes.gd"
clear, part, new_bm, box, blob, tapered_tube, cyl = (
    FP["clear"], FP["part"], FP["new_bm"], FP["box"], FP["blob"], FP["tapered_tube"], FP["cyl"])

# Per model: colliders, columns, grapple hooks and standing tops, in Godot's frame.
SHAPES = {}
_cur = {}


def begin(name):
    global _cur
    _cur = {"boxes": [], "columns": [], "hooks": [], "tops": [], "size": None}
    SHAPES[name] = _cur


def gd(v):
    """Blender (x, y, z), Z up, front -Y  ->  Godot (x, y, z), Y up, front +Z."""
    return (v[0], v[2], -v[1])


def solid(center, size, yaw=0.0, tilt=0.0):
    """A collider box: `size` before turning, tilted `tilt` degrees about X,
    then turned `yaw` degrees about the vertical."""
    _cur["boxes"].append((gd(center), (size[0], size[2], size[1]), yaw, tilt))


def column(base, radius, height):
    _cur["columns"].append((gd(base), radius, height))


def hook(at):
    """Where a grapple hook is (the orange block's centre)."""
    _cur["hooks"].append(gd(at))


def top(at):
    """A place to stand on top (centre of a roof or deck)."""
    _cur["tops"].append(gd(at))


def footprint(sx, sy):
    _cur["size"] = (sx, sy)


def tbox(bm, center, size, yaw=0.0, tilt=0.0, bevel=0.0):
    """A box tilted about X then turned about Z (degrees), like solid()."""
    tmp = bmesh.new()
    res = bmesh.ops.create_cube(tmp, size=1.0)
    bmesh.ops.scale(tmp, vec=Vector(size), verts=res["verts"])
    if bevel > 0.0:
        bmesh.ops.bevel(tmp, geom=list(tmp.edges), offset=bevel, segments=1, affect="EDGES")
    rot = Matrix.Rotation(math.radians(yaw), 3, "Z") @ Matrix.Rotation(math.radians(tilt), 3, "X")
    bmesh.ops.rotate(tmp, verts=list(tmp.verts), cent=Vector((0, 0, 0)), matrix=rot)
    bmesh.ops.translate(tmp, vec=Vector(center), verts=list(tmp.verts))
    _merge(bm, tmp)


def _merge(bm, tmp):
    for f in tmp.faces:
        bm.faces.new([bm.verts.new(v.co) for v in f.verts])
    tmp.free()


def sbox(bm, center, size, yaw=0.0, tilt=0.0, bevel=0.0):
    """A box that is also a collider."""
    tbox(bm, center, size, yaw, tilt, bevel)
    solid(center, size, yaw, tilt)


def ring(bm, center, radius, tube, sides=10):
    """A flat ring (a hook loop or a tyre) round the Z axis."""
    c = Vector(center)
    for k in range(sides):
        a0 = 2 * math.pi * k / sides
        a1 = 2 * math.pi * (k + 1) / sides
        cyl(bm, c + Vector((math.cos(a0) * radius, math.sin(a0) * radius, 0)),
            c + Vector((math.cos(a1) * radius, math.sin(a1) * radius, 0)), tube, sides=5)


def hook_block(bm_metal, bm_orange, center, size=1.2):
    """The grapple target everyone learns to look for: an orange block with a
    steel eye on its underside and hazard chevrons."""
    c = Vector(center)
    tbox(bm_orange, c, (size, size, size * 0.8), bevel=0.06)
    ring(bm_metal, c + Vector((0, 0, -size * 0.55)), size * 0.28, 0.06, sides=8)
    hook(c)
    solid(c, (size, size, size * 0.8))


# Blender 4 calls it export_colors; 5 dropped it (and exports no colours we didn't add).
_NO_COLORS = {"export_colors": False} if bpy.app.version < (5, 0, 0) else {}


def export(name):
    OUT.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(OUT / f"{name}.glb"), export_format="GLB", export_apply=True,
        export_yup=True, export_materials="PLACEHOLDER", export_normals=True,
        export_texcoords=False, **_NO_COLORS,
    )
    print("wrote procgen", name)
    clear()


# =============================================================================
# Buildings
# =============================================================================

def bunker(name):
    """A concrete pillbox, 6 W x 5 D, roof at 2.7: a firing slit on the front,
    a blast door round the back, sandbags along the roof's front lip."""
    begin(name)
    con = new_bm()
    sbox(con, (0, 0, 1.2), (6.0, 5.0, 2.4), bevel=0.08)
    sbox(con, (0, 0, 2.55), (6.4, 5.4, 0.3))
    tbox(con, (0, -2.6, 0.35), (6.2, 0.6, 0.7), tilt=-20)  # sloped apron
    part(con, "shell", "concrete")
    dark = new_bm()
    tbox(dark, (0, -2.52, 1.65), (3.4, 0.06, 0.32))
    tbox(dark, (1.6, 2.52, 1.0), (1.2, 0.06, 2.0))
    part(dark, "slit", "shadow")
    steel = new_bm()
    tbox(steel, (1.6, 2.56, 1.0), (1.3, 0.06, 2.1))
    cyl(steel, (-2.0, 1.2, 2.7), (-2.0, 1.2, 3.6), 0.12, sides=6)
    part(steel, "door", "gunmetal")
    bags = new_bm()
    rng = random.Random(5)
    for k in range(7):
        blob(bags, (-2.7 + k * 0.9, -2.35, 2.85), (0.48, 0.28, 0.2), rng, subdiv=1, wobble=0.1, seed=k)
    part(bags, "bags", "canvas")
    band = new_bm()
    tbox(band, (0, -2.72, 2.55), (6.3, 0.04, 0.22))
    part(band, "band", "anchor")
    top((0, 0, 2.7))
    footprint(6.4, 5.4)
    export(name)


def blockhouse(name):
    """A two-storey colony blockhouse: concrete below, steel above, a flat roof
    at 6.5 with a hook on its back corner. Stairs climb its +X side to a
    landing at 3.2, then along the back to the roof."""
    begin(name)
    con = new_bm()
    sbox(con, (0, 0, 1.6), (7.0, 6.0, 3.2), bevel=0.06)
    part(con, "base", "concrete")
    steel = new_bm()
    sbox(steel, (0, 0, 4.75), (6.6, 5.6, 2.9))
    sbox(steel, (0, 0, 6.35), (7.2, 6.6, 0.3))
    for x in (-2.4, -0.8, 0.8, 2.4):
        tbox(steel, (x, -2.83, 4.75), (0.12, 0.08, 2.8))
    # Low lips round the roof (visual only: too low to snag on).
    for s in (-1, 1):
        tbox(steel, (0, s * 3.25, 6.62), (7.2, 0.1, 0.25))
        tbox(steel, (s * 3.55, 0, 6.62), (0.1, 6.6, 0.25))
    part(steel, "upper", "gunmetal")
    stairs = new_bm()
    # Flight 1 up the +X side, front to back: 3.2 m over 5 m.
    run1 = math.hypot(5.0, 3.2)
    ang1 = math.degrees(math.atan2(3.2, 5.0))
    sbox(stairs, (4.25, -0.5, 1.6 - 0.15), (1.5, run1, 0.3), tilt=ang1)
    sbox(stairs, (4.25, 3.25, 3.05), (1.5, 2.5, 0.3))  # landing
    # Flight 2 along the back, +X to -X: 3.3 m over 5.9 m.
    run2 = math.hypot(5.9, 3.3)
    ang2 = math.degrees(math.atan2(3.3, 5.9))
    sbox(stairs, (0.55, 3.75, 4.85 - 0.15), (1.5, run2, 0.3), yaw=90, tilt=ang2)
    sbox(stairs, (-3.05, 3.75, 6.35), (1.1, 1.5, 0.3))  # top step onto the roof
    for x, y in ((3.5, -3.0), (5.0, -3.0), (3.5, 4.5), (5.0, 4.5), (-3.6, 4.5)):
        tbox(stairs, (x, y, 1.6), (0.12, 0.12, 3.2))
    part(stairs, "stairs", "gunmetal")
    dark = new_bm()
    tbox(dark, (-1.5, -3.02, 1.1), (1.2, 0.06, 2.2))
    for x in (-1.6, 1.6):
        tbox(dark, (x, -2.82, 5.0), (1.0, 0.05, 0.4))
    part(dark, "door", "shadow")
    lit = new_bm()
    tbox(lit, (1.2, -3.02, 2.0), (1.3, 0.05, 0.6))
    part(lit, "windows", "light")
    metal = new_bm()
    orange = new_bm()
    tbox(metal, (-3.2, 3.6, 7.4), (0.25, 0.25, 1.8))
    hook_block(metal, orange, (-3.2, 3.6, 8.7), 1.1)
    part(metal, "mast", "gunmetal")
    part(orange, "hook", "anchor")
    band = new_bm()
    tbox(band, (0, -3.03, 3.0), (6.9, 0.03, 0.3))
    part(band, "band", "anchor")
    top((0, 0, 6.5))
    footprint(10.0, 9.0)
    export(name)


def garage(name):
    """A vehicle shed open to the front, 9 W x 7 D, flat roof at 4.2: posts,
    corrugated side and back walls, a workbench and a hoist inside."""
    begin(name)
    steel = new_bm()
    sbox(steel, (0, 3.35, 2.0), (9.0, 0.3, 4.0))
    for s in (-1, 1):
        sbox(steel, (s * 4.35, 0, 2.0), (0.3, 7.0, 4.0))
        for y in range(-3, 4):
            tbox(steel, (s * 4.53, y * 0.95, 2.0), (0.08, 0.1, 3.9))
    sbox(steel, (0, 0, 4.1), (9.4, 7.4, 0.25))
    for x in (-4.35, -1.45, 1.45, 4.35):
        tbox(steel, (x, -3.45, 2.0), (0.3, 0.3, 4.0))
    tbox(steel, (0, -3.45, 3.85), (9.0, 0.35, 0.35))
    part(steel, "shell", "gunmetal")
    wood = new_bm()
    sbox(wood, (2.5, 2.6, 0.5), (3.0, 1.0, 1.0))
    part(wood, "bench", "wood")
    metal = new_bm()
    tbox(metal, (-1.5, 0, 3.6), (0.3, 6.6, 0.3))
    cyl(metal, (-1.5, -0.5, 3.5), (-1.5, -0.5, 2.0), 0.03, sides=4)
    part(metal, "hoist", "gunmetal")
    orange = new_bm()
    tbox(orange, (-1.5, -0.5, 1.85), (0.3, 0.3, 0.3))
    tbox(orange, (0, -3.64, 3.85), (8.8, 0.04, 0.25))
    part(orange, "stripe", "anchor")
    dark = new_bm()
    tbox(dark, (0, 3.18, 2.0), (8.6, 0.04, 3.8))
    part(dark, "inside", "shadow")
    top((0, 0, 4.22))
    footprint(9.4, 7.4)
    export(name)


def warehouse(name):
    """A big depot warehouse, 14 W x 10 D, walls 6 m, a pitched roof to 8.5
    with a hook at each gable end. A roller door and a loading dock out front."""
    begin(name)
    steel = new_bm()
    sbox(steel, (0, 0, 3.0), (14.0, 10.0, 6.0))
    for x in range(-6, 7, 2):
        tbox(steel, (x, -5.05, 3.0), (0.15, 0.1, 6.0))
        tbox(steel, (x, 5.05, 3.0), (0.15, 0.1, 6.0))
    part(steel, "walls", "gunmetal")
    roof = new_bm()
    slope = math.degrees(math.atan2(2.5, 5.0))
    length = math.hypot(5.0, 2.5) + 0.6
    for s in (-1, 1):
        sbox(roof, (0, s * 2.5, 7.25), (14.6, length, 0.25), tilt=-s * slope)
    part(roof, "roof", "gunmetal")
    con = new_bm()
    sbox(con, (2.5, -6.0, 0.6), (6.0, 2.0, 1.2))
    part(con, "dock", "concrete")
    dark = new_bm()
    tbox(dark, (2.5, -5.04, 2.6), (5.0, 0.06, 4.2))
    tbox(dark, (-4.5, -5.04, 1.1), (1.2, 0.06, 2.2))
    part(dark, "door", "shadow")
    metal = new_bm()
    orange = new_bm()
    for s in (-1, 1):
        tbox(metal, (s * 7.3, 0, 8.4), (0.25, 0.25, 0.8))
        hook_block(metal, orange, (s * 7.3, 0, 9.3), 1.0)
    tbox(orange, (0, -5.07, 5.4), (13.6, 0.04, 0.35))
    part(metal, "hook_posts", "gunmetal")
    part(orange, "hooks", "anchor")
    lit = new_bm()
    for x in (-5.0, -2.0):
        tbox(lit, (x, -5.06, 4.2), (1.6, 0.05, 0.6))
    part(lit, "windows", "light")
    top((0, 0, 8.5))
    footprint(14.4, 12.0)
    export(name)


def silo(name):
    """A grain silo the colony turned into a lookout: 5.2 m across, 11 m to
    the walkway ring, a cone cap and a hook on its peak."""
    begin(name)
    steel = new_bm()
    tapered_tube(steel, [(0, 0, 0), (0, 0, 11.0)], [2.6, 2.6], sides=14)
    for z in (2.5, 5.0, 7.5, 10.0):
        tapered_tube(steel, [(0, 0, z), (0, 0, z + 0.15)], [2.66, 2.66], sides=14)
    column((0, 0, 0), 2.6, 11.0)
    part(steel, "body", "gunmetal")
    cap = new_bm()
    FP["cone"](cap, (0, 0, 11.0), 2.8, 2.0, sides=14)
    solid((0, 0, 11.5), (3.6, 3.6, 1.0))
    part(cap, "cap", "concrete")
    rail = new_bm()
    ring(rail, (0, 0, 11.9), 3.1, 0.05, sides=14)
    tapered_tube(rail, [(0, 0, 10.95), (0, 0, 11.05)], [3.2, 3.2], sides=14)
    solid((0, 0, 11.0), (6.2, 6.2, 0.1))
    # Ladder cage up the back.
    for x in (-0.3, 0.3):
        tbox(rail, (x, 2.75, 5.5), (0.06, 0.06, 11.0))
    for k in range(27):
        tbox(rail, (0, 2.75, 0.4 + k * 0.4), (0.6, 0.05, 0.05))
    part(rail, "rail", "gunmetal")
    metal = new_bm()
    orange = new_bm()
    tbox(metal, (0, 0, 13.4), (0.2, 0.2, 1.2))
    hook_block(metal, orange, (0, 0, 14.3), 1.0)
    tapered_tube(orange, [(0, 0, 9.0), (0, 0, 9.4)], [2.64, 2.64], sides=14)
    part(metal, "post", "gunmetal")
    part(orange, "hook", "anchor")
    top((0, -2.9, 11.05))
    footprint(6.4, 6.4)
    export(name)


def water_tower(name):
    """A water tower: a tank from 9 to 13 m on four braced legs, a catwalk
    ring round its base, a hook on the roof."""
    begin(name)
    steel = new_bm()
    for sx in (-1, 1):
        for sy in (-1, 1):
            tapered_tube(steel, [(sx * 2.4, sy * 2.4, 0), (sx * 1.8, sy * 1.8, 9.0)], [0.2, 0.16], sides=5)
            column((sx * 2.1, sy * 2.1, 0), 0.25, 9.0)
    for z0, z1 in ((0.3, 4.5), (4.5, 8.8)):
        for s in (-1, 1):
            w0, w1 = 2.4 - z0 * 0.066, 2.4 - z1 * 0.066
            cyl(steel, (-w0, s * w0, z0), (w1, s * w1, z1), 0.06, sides=4)
            cyl(steel, (s * w0, -w0, z0), (s * w1, w1, z1), 0.06, sides=4)
    ring(steel, (0, 0, 10.0), 3.35, 0.05, sides=12)
    part(steel, "legs", "gunmetal")
    deck = new_bm()
    tapered_tube(deck, [(0, 0, 8.9), (0, 0, 9.1)], [3.4, 3.4], sides=12)
    solid((0, 0, 9.0), (6.6, 6.6, 0.2))
    part(deck, "deck", "wood")
    tank = new_bm()
    tapered_tube(tank, [(0, 0, 9.1), (0, 0, 13.0)], [2.8, 2.8], sides=12)
    FP["cone"](tank, (0, 0, 13.0), 3.0, 1.2, sides=12)
    column((0, 0, 9.1), 2.8, 3.9)
    solid((0, 0, 13.4), (4.0, 4.0, 0.8))
    part(tank, "tank", "concrete")
    metal = new_bm()
    orange = new_bm()
    tbox(metal, (0, 0, 14.4), (0.2, 0.2, 0.9))
    hook_block(metal, orange, (0, 0, 15.2), 1.0)
    tapered_tube(orange, [(0, 0, 11.6), (0, 0, 12.0)], [2.84, 2.84], sides=12)
    part(metal, "post", "gunmetal")
    part(orange, "hook", "anchor")
    top((0, -3.0, 9.1))
    footprint(6.8, 6.8)
    export(name)


def scaffold(name):
    """A steel pipe scaffold with a plank deck at 4 m, 4 W x 6 D, and steps up
    its +X side at 1, 2 and 3 m. A rooftop to the high lane, a climb to anyone."""
    begin(name)
    pipe = new_bm()
    for x in (-2.0, 2.0):
        for y in (-3.0, 0.0, 3.0):
            tbox(pipe, (x, y, 2.0), (0.1, 0.1, 4.0))
    for z in (1.0, 2.0, 3.0, 4.6):
        for s in (-1, 1):
            tbox(pipe, (0, s * 3.0, z), (4.0, 0.08, 0.08))
            tbox(pipe, (s * 2.0, 0, z), (0.08, 6.0, 0.08))
    for s in (-1, 1):
        cyl(pipe, (s * 2.0, -3.0, 0.1), (s * 2.0, 0.0, 3.9), 0.04, sides=4)
        cyl(pipe, (s * 2.0, 0.0, 0.1), (s * 2.0, 3.0, 3.9), 0.04, sides=4)
    for k, y in enumerate((-2.25, -0.75, 0.75)):
        z = 1.0 + k
        tbox(pipe, (3.4, y, z * 0.5), (0.08, 0.08, z))
    part(pipe, "pipes", "gunmetal")
    wood = new_bm()
    sbox(wood, (0, 0, 3.9), (4.2, 6.2, 0.2))
    for k, y in enumerate((-2.25, -0.75, 0.75)):
        sbox(wood, (2.75, y, 0.9 + k), (1.5, 1.5, 0.2))
    part(wood, "planks", "wood")
    tarp = new_bm()
    tbox(tarp, (-2.05, 0, 2.4), (0.04, 5.8, 2.6))
    part(tarp, "tarp", "canvas")
    top((0, 0, 4.0))
    footprint(7.0, 6.4)
    export(name)


def ruin_house(name, seed):
    """A bombed-out house, 8 W x 6 D, no roof. A 6 m wall on its +X side (to
    wallrun), a broken front with a door and a window, the back half fallen
    in, the -X side gone to rubble. Floor slab to stand on."""
    begin(name)
    rng = random.Random(seed)
    wall = new_bm()
    sbox(wall, (0, 0, 0.08), (8.0, 6.0, 0.16))
    # Front (-Y): pier, window, pier, door, low right part.
    sbox(wall, (-3.6, -2.8, 2.6), (0.8, 0.4, 5.2))
    sbox(wall, (-2.6, -2.8, 0.5), (1.2, 0.4, 1.0))
    sbox(wall, (-2.6, -2.8, 3.8), (1.2, 0.4, 2.8))
    sbox(wall, (-1.5, -2.8, 2.5), (1.0, 0.4, 5.0))
    sbox(wall, (-0.3, -2.8, 2.65), (1.4, 0.4, 0.7))
    sbox(wall, (2.2, -2.8, 1.5), (3.6, 0.4, 3.0))
    # +X side: the tall one.
    sbox(wall, (3.8, 0, 3.0), (0.4, 6.0, 6.0))
    # Back (+Y): half fallen.
    sbox(wall, (-1.6, 2.8, 1.0), (4.8, 0.4, 2.0))
    sbox(wall, (2.2, 2.8, 2.0), (3.2, 0.4, 4.0))
    # Inner wall stub.
    sbox(wall, (0.6, 0.6, 1.6), (0.3, 3.2, 3.2))
    # Broken tops: chunks sitting proud of the colliders.
    for k in range(10):
        x = rng.uniform(-3.8, 3.6)
        tbox(wall, (x, -2.8, (5.0 if x < -1.0 else 3.0) + 0.1), (rng.uniform(0.3, 0.8), 0.42, 0.25), yaw=rng.uniform(-8, 8))
        tbox(wall, (3.8, rng.uniform(-2.8, 2.8), 6.05), (0.42, rng.uniform(0.3, 0.9), 0.2))
    part(wall, "walls", "concrete")
    rubble = new_bm()
    for k in range(9):
        blob(rubble, (-4.2 + rng.uniform(-0.6, 0.8), rng.uniform(-2.6, 2.6), 0.2), (rng.uniform(0.4, 0.9), rng.uniform(0.4, 0.9), rng.uniform(0.2, 0.5)), rng, subdiv=1, wobble=0.2, seed=seed + k)
    for k in range(5):
        blob(rubble, (rng.uniform(-3, 1), rng.uniform(1.5, 3.4), 0.25), (rng.uniform(0.5, 1.0), rng.uniform(0.4, 0.8), 0.3), rng, subdiv=1, wobble=0.2, seed=seed + 20 + k)
    solid((-4.2, 0, 0.25), (1.2, 6.0, 0.5))
    part(rubble, "rubble", "rock")
    wood = new_bm()
    for k in range(4):
        tbox(wood, (rng.uniform(-3, 2), rng.uniform(-1.5, 2.0), 0.3), (0.2, rng.uniform(2.0, 3.5), 0.15), yaw=rng.uniform(0, 180), tilt=rng.uniform(5, 20))
    part(wood, "beams", "wood")
    soot = new_bm()
    tbox(soot, (3.59, 0, 4.0), (0.02, 4.0, 2.4))
    part(soot, "soot", "shadow")
    blue = new_bm()
    tbox(blue, (4.02, 0, 2.2), (0.03, 5.6, 0.3))
    part(blue, "stripe", "wallrun")
    top((-2.0, 0, 0.16))
    footprint(9.4, 6.8)
    export(name)


def ruin_shell(name, seed):
    """The shell of a two-storey building, 7 x 7: walls 7.5 m (front and back)
    and 5 m (sides) with blown-out windows, half the upper floor still there at
    3.6 m, and a slope of rubble up to it inside."""
    begin(name)
    rng = random.Random(seed)
    wall = new_bm()
    sbox(wall, (0, 0, 0.08), (7.0, 7.0, 0.16))
    for s in (-1, 1):
        y = s * 3.3
        # Front/back: pillars and spandrels, window holes between.
        for x in (-3.15, 0.0, 3.15):
            sbox(wall, (x, y, 3.75), (0.7, 0.4, 7.5))
        for x in (-1.55, 1.55):
            sbox(wall, (x, y, 0.5), (2.4, 0.4, 1.0))
            sbox(wall, (x, y, 3.4), (2.4, 0.4, 1.4))
            sbox(wall, (x, y, 6.9), (2.4, 0.4, 1.2))
    # Sides, lower and solid (wallrun them).
    for s in (-1, 1):
        sbox(wall, (s * 3.3, 0, 2.5), (0.4, 6.2, 5.0))
    for k in range(8):
        tbox(wall, (rng.uniform(-3.2, 3.2), rng.choice((-3.3, 3.3)), 7.55), (rng.uniform(0.4, 1.0), 0.42, 0.25))
    part(wall, "walls", "concrete")
    floor = new_bm()
    sbox(floor, (0, 1.5, 3.6), (6.2, 3.0, 0.3))
    for k in range(3):
        tbox(floor, (rng.uniform(-2.5, 2.5), -0.2, 3.3), (0.6, 0.6, 0.3), tilt=rng.uniform(-30, 30))
    part(floor, "floor", "concrete")
    rubble = new_bm()
    # Rubble slope from the front door up to the floor: 3.6 m over 4.2 m.
    ang = math.degrees(math.atan2(3.6, 4.2))
    sbox(rubble, (-1.8, -1.0, 1.8 - 0.25), (2.0, math.hypot(4.2, 3.6), 0.5), tilt=ang)
    for k in range(10):
        t = k / 9
        blob(rubble, (-1.8 + rng.uniform(-0.6, 0.6), -3.1 + 4.2 * t, 3.6 * t), (0.7, 0.6, 0.35), rng, subdiv=1, wobble=0.2, seed=seed + k)
    part(rubble, "rubble", "rock")
    blue = new_bm()
    for s in (-1, 1):
        tbox(blue, (s * 3.52, 0, 2.2), (0.03, 5.8, 0.3))
    part(blue, "stripe", "wallrun")
    top((0, 1.5, 3.75))
    footprint(7.8, 7.8)
    export(name)


def tower_crane(name):
    """A tower crane: a lattice mast to 18 m, the jib out 17 m along -Y with
    the trolley and an orange hook block hanging at 12.3 m, 14.5 m out."""
    begin(name)
    steel = new_bm()
    for sx in (-0.8, 0.8):
        for sy in (-0.8, 0.8):
            tbox(steel, (sx, sy, 9.0), (0.14, 0.14, 18.0))
    for k in range(9):
        z = 1.0 + k * 2.0
        for s in (-1, 1):
            cyl(steel, (-0.8, s * 0.8, z), (0.8, s * 0.8, z + 2.0), 0.04, sides=4)
            cyl(steel, (s * 0.8, -0.8, z), (s * 0.8, 0.8, z + 2.0), 0.04, sides=4)
    solid((0, 0, 9.0), (1.7, 1.7, 18.0))
    # Jib (-Y) and counter-jib (+Y).
    tbox(steel, (0, -8.5, 18.4), (1.0, 17.0, 0.8))
    tbox(steel, (0, 3.5, 18.4), (1.0, 5.0, 0.8))
    solid((0, -6.0, 18.4), (1.0, 22.0, 0.8))
    cyl(steel, (0, 0, 21.5), (0, -16.5, 18.8), 0.05, sides=4)
    cyl(steel, (0, 0, 21.5), (0, 5.5, 18.8), 0.05, sides=4)
    tbox(steel, (0, 0, 20.0), (0.6, 0.6, 3.0))
    tbox(steel, (0, -14.5, 17.8), (1.2, 1.4, 0.4))  # trolley
    cyl(steel, (-0.2, -14.5, 17.6), (-0.2, -14.5, 12.8), 0.03, sides=3)
    cyl(steel, (0.2, -14.5, 17.6), (0.2, -14.5, 12.8), 0.03, sides=3)
    part(steel, "frame", "gunmetal")
    con = new_bm()
    sbox(con, (0, 0, 0.3), (3.0, 3.0, 0.6))
    tbox(con, (0, 5.0, 17.6), (1.6, 1.8, 1.2))  # counterweights
    part(con, "base", "concrete")
    cab = new_bm()
    tbox(cab, (0.9, -0.4, 17.3), (1.0, 1.2, 1.2))
    part(cab, "cab", "light")
    orange = new_bm()
    metal = new_bm()
    hook_block(metal, orange, (0, -14.5, 12.3), 1.3)
    for k in range(8):
        tbox(orange, (0, -1.0 - k * 2.0, 18.85), (1.02, 0.6, 0.1))
    part(orange, "hook", "anchor")
    part(metal, "eye", "gunmetal")
    footprint(3.0, 3.0)
    export(name)


# =============================================================================
# Movement pieces
# =============================================================================

def billboard(name, length, height, seed):
    """A colony propaganda board on steel legs, `length` along X, its face from
    1.0 m up to 1.0 + `height`. Blue trim top and bottom: run along it."""
    begin(name)
    rng = random.Random(seed)
    bottom = 1.0
    mid = bottom + height * 0.5
    board = new_bm()
    sbox(board, (0, 0, mid), (length, 0.35, height))
    part(board, "board", "canvas")
    legs = new_bm()
    n = max(2, int(length / 3.2) + 1)
    for k in range(n):
        x = -length * 0.5 + 0.4 + (length - 0.8) * k / (n - 1)
        tbox(legs, (x, 0.35, bottom * 0.5 + 0.3), (0.22, 0.22, bottom + 0.6))
        cyl(legs, (x, 1.4, 0.0), (x, 0.3, bottom + height * 0.6), 0.06, sides=4)
        column((x, 0.35, 0), 0.15, bottom)
    tbox(legs, (0, 0.3, bottom + height + 0.15), (length, 0.25, 0.12))
    for k in range(n):
        x = -length * 0.5 + 0.4 + (length - 0.8) * k / (n - 1)
        tbox(legs, (x, -0.45, bottom + height + 0.45), (0.06, 0.5, 0.06))
    part(legs, "frame", "gunmetal")
    trim = new_bm()
    for s in (-1, 1):
        tbox(trim, (0, s * 0.19, bottom + 0.12), (length, 0.03, 0.24))
        tbox(trim, (0, s * 0.19, bottom + height - 0.12), (length, 0.03, 0.24))
    part(trim, "trim", "wallrun")
    # The poster: a stencilled colony fist and a slogan bar, both faces.
    art = new_bm()
    for s in (-1, 1):
        cx = rng.uniform(-length * 0.25, length * 0.25)
        tbox(art, (cx, s * 0.185, mid + 0.2), (min(2.0, length * 0.25), 0.02, height * 0.45))
        tbox(art, (cx, s * 0.185, mid + height * 0.32), (min(1.2, length * 0.15), 0.02, 0.4))
    part(art, "fist", "shadow")
    slogan = new_bm()
    for s in (-1, 1):
        tbox(slogan, (0, s * 0.185, bottom + height * 0.22), (length * 0.8, 0.02, 0.35))
    part(slogan, "slogan", "anchor")
    footprint(length + 0.4, 2.0)
    export(name)


def blast_wall(name, seed):
    """One T-wall section, 1.6 W x 4.2 H, on a 1.4 m deep foot: line them up
    for a wall to run along or hide behind."""
    begin(name)
    rng = random.Random(seed)
    con = new_bm()
    sbox(con, (0, 0, 2.2), (1.6, 0.35, 4.0), bevel=0.03)
    sbox(con, (0, 0, 0.3), (1.6, 1.4, 0.6))
    tbox(con, (0, 0, 4.1), (1.6, 0.25, 0.2))
    tbox(con, (rng.uniform(-0.6, 0.6), -0.18, 4.2), (0.3, 0.1, 0.2))
    part(con, "slab", "concrete")
    blue = new_bm()
    tbox(blue, (0, -0.19, 2.2), (1.58, 0.02, 0.3))
    tbox(blue, (0, 0.19, 2.2), (1.58, 0.02, 0.3))
    part(blue, "stripe", "wallrun")
    stencil = new_bm()
    tbox(stencil, (0, -0.19, 3.3), (0.6, 0.02, 0.6))
    part(stencil, "stencil", "anchor")
    footprint(1.6, 1.4)
    export(name)


def kick_slot(name, length, height):
    """Two concrete walls `length` long and `height` high, 3.4 m apart: run in
    along the slot and kick from wall to wall up to the deck at its far end,
    level with the wall tops."""
    begin(name)
    half = length * 0.5
    con = new_bm()
    for s in (-1, 1):
        sbox(con, (s * 2.0, 0, height * 0.5), (0.6, length, height), bevel=0.04)
        for y in range(int(-half) + 1, int(half), 3):
            tbox(con, (s * 2.35, y, height * 0.5), (0.15, 0.4, height))
    part(con, "walls", "concrete")
    deck = new_bm()
    # The deck past the far end, with a parapet round it to stop you at speed.
    sbox(deck, (0, half + 2.5, height - 0.15), (4.6, 5.0, 0.3))
    sbox(deck, (0, half + 4.9, height + 0.55), (4.6, 0.2, 1.1))
    for s in (-1, 1):
        sbox(deck, (s * 2.2, half + 2.9, height + 0.55), (0.2, 4.2, 1.1))
    for x in (-2.0, 2.0):
        tbox(deck, (x, half + 4.6, height * 0.5), (0.25, 0.25, height))
        column((x, half + 4.6, 0), 0.15, height)
    part(deck, "deck", "gunmetal")
    blue = new_bm()
    for s in (-1, 1):
        z = 1.4
        while z < height - 0.6:
            tbox(blue, (s * 1.69, 0, z), (0.02, length - 0.6, 0.25))
            z += 1.6
    part(blue, "chevrons", "wallrun")
    orange = new_bm()
    tbox(orange, (0, half + 0.01, height - 0.15), (4.6, 0.02, 0.3))
    part(orange, "edge", "anchor")
    top((0, half + 2.5, height))
    footprint(4.8, length + 5.4)
    export(name)


def lean_slab(name, seed):
    """A fallen wall slab, 8 long x 5 high, leaning back 12 degrees against a
    broken support: steep enough to run along, low enough to crouch under."""
    begin(name)
    rng = random.Random(seed)
    lean = 12.0
    con = new_bm()
    c = (0, 0.5 * 5.0 * math.sin(math.radians(lean)), 2.5 * math.cos(math.radians(lean)))
    sbox(con, c, (8.0, 0.5, 5.0), tilt=lean)
    for k in range(5):
        tbox(con, (rng.uniform(-3.5, 3.5), c[1] + 0.6, c[2] + 2.3), (rng.uniform(0.4, 0.9), 0.4, 0.3), tilt=lean)
    part(con, "slab", "concrete")
    rebar = new_bm()
    for k in range(6):
        x = -3.5 + k * 1.4
        top_pt = (x, 0.5 + 5.0 * math.sin(math.radians(lean)), 5.0 * math.cos(math.radians(lean)))
        cyl(rebar, top_pt, (x + rng.uniform(-0.2, 0.2), top_pt[1] + rng.uniform(0.1, 0.4), top_pt[2] + rng.uniform(0.3, 0.7)), 0.02, sides=3)
    tbox(rebar, (2.5, 1.9, 1.6), (0.3, 0.3, 3.4), tilt=-20)
    part(rebar, "rebar", "gunmetal")
    blue = new_bm()
    tbox(blue, (0, c[1] - 0.26 * math.cos(math.radians(lean)), c[2] + 0.26 * math.sin(math.radians(lean)) - 0.6), (7.8, 0.02, 0.3), tilt=lean)
    part(blue, "stripe", "wallrun")
    footprint(8.4, 3.0)
    export(name)


def grapple_mast(name, height):
    """A steel mast with an orange hook block on top, guyed to three pegs."""
    begin(name)
    steel = new_bm()
    tapered_tube(steel, [(0, 0, 0), (0, 0, height - 0.6)], [0.3, 0.2], sides=6)
    column((0, 0, 0), 0.3, height - 0.6)
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.4
        peg = (math.cos(a) * height * 0.35, math.sin(a) * height * 0.35, 0.05)
        cyl(steel, peg, (0, 0, height * 0.7), 0.025, sides=3)
        tbox(steel, peg, (0.3, 0.3, 0.3))
    for z in range(2, int(height) - 1, 2):
        tbox(steel, (0, 0.25, z), (0.4, 0.06, 0.06))
    part(steel, "mast", "gunmetal")
    orange = new_bm()
    metal = new_bm()
    hook_block(metal, orange, (0, 0, height), 1.3)
    tapered_tube(orange, [(0, 0, 2.0), (0, 0, 2.4)], [0.32, 0.31], sides=6)
    part(orange, "hook", "anchor")
    part(metal, "eye", "gunmetal")
    lamp = new_bm()
    tbox(lamp, (0, 0, height + 0.6), (0.25, 0.25, 0.2))
    part(lamp, "beacon", "light")
    footprint(3.0, 3.0)  # the guy wires' pegs are only for show
    export(name)


def hook_bracket(name):
    """A hook block on an arm, for bolting to the side of things: the arm
    sticks out 1.4 m along -Y from a plate at the origin."""
    begin(name)
    steel = new_bm()
    tbox(steel, (0, 0, 0), (0.8, 0.12, 0.8))
    tbox(steel, (0, -0.7, 0), (0.25, 1.4, 0.25))
    cyl(steel, (0, -0.05, -0.6), (0, -1.0, -0.05), 0.04, sides=4)
    part(steel, "arm", "gunmetal")
    orange = new_bm()
    metal = new_bm()
    hook_block(metal, orange, (0, -1.6, 0), 0.9)
    part(orange, "hook", "anchor")
    part(metal, "eye", "gunmetal")
    footprint(1.0, 2.2)
    export(name)


# =============================================================================
# Props
# =============================================================================

def jersey_barrier(name):
    """A concrete road barrier, 3 L x 0.9 H: crouch-high cover."""
    begin(name)
    con = new_bm()
    tbox(con, (0, 0, 0.15), (3.0, 0.62, 0.3))
    tbox(con, (0, 0, 0.6), (3.0, 0.3, 0.6))
    for s in (-1, 1):
        tbox(con, (0, s * 0.2, 0.42), (3.0, 0.12, 0.3), tilt=s * 35)
    solid((0, 0, 0.45), (3.0, 0.6, 0.9))
    part(con, "barrier", "concrete")
    band = new_bm()
    for k in range(4):
        tbox(band, (-1.1 + k * 0.75, -0.16, 0.78), (0.35, 0.02, 0.18), yaw=0)
    part(band, "stripes", "anchor")
    footprint(3.0, 0.8)
    export(name)


def tank_trap(name):
    """A czech hedgehog: three steel beams at right angles to each other,
    standing on three of their ends, about 1.5 m high."""
    begin(name)
    steel = new_bm()
    # Turn the three axes so their diagonal points straight up.
    up = Vector((1, 1, 1)).normalized()
    rot = up.rotation_difference(Vector((0, 0, 1))).to_matrix()
    c = Vector((0, 0, 0.78))
    for axis in (Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))):
        d = rot @ axis
        tapered_tube(steel, [c - d * 1.05, c + d * 1.05], [0.09, 0.09], sides=4)
    solid((0, 0, 0.7), (1.1, 1.1, 1.4))
    part(steel, "beams", "gunmetal")
    footprint(1.8, 1.8)
    export(name)


def tire_stack(name, seed):
    """Old tyres stacked four high, one leaning on the side."""
    begin(name)
    rng = random.Random(seed)
    rubber = new_bm()
    for k in range(4):
        c = (rng.uniform(-0.06, 0.06), rng.uniform(-0.06, 0.06), 0.13 + k * 0.26)
        tapered_tube(rubber, [(c[0], c[1], c[2] - 0.12), (c[0], c[1], c[2] + 0.12)], [0.45, 0.45], sides=10)
    # One stood on its edge against the stack.
    tapered_tube(rubber, [(0.62, -0.13, 0.45), (0.74, 0.13, 0.47)], [0.45, 0.45], sides=10)
    hub = new_bm()
    for k in range(4):
        tapered_tube(hub, [(0, 0, 0.12 + k * 0.26 + 0.11), (0, 0, 0.12 + k * 0.26 + 0.13)], [0.22, 0.22], sides=8)
    part(hub, "rims", "gunmetal")
    column((0, 0, 0), 0.48, 1.05)
    part(rubber, "tyres", "shadow")
    footprint(1.6, 1.0)
    export(name)


def cable_reel(name):
    """A big wooden cable spool on its side, 1.8 m across."""
    begin(name)
    wood = new_bm()
    for x in (-0.55, 0.55):
        tapered_tube(wood, [(x - 0.05, 0, 0.9), (x + 0.05, 0, 0.9)], [0.9, 0.9], sides=12)
    part(wood, "spool", "wood")
    cable = new_bm()
    tapered_tube(cable, [(-0.5, 0, 0.9), (0.5, 0, 0.9)], [0.6, 0.6], sides=12)
    part(cable, "cable", "shadow")
    solid((0, 0, 0.9), (1.2, 1.8, 1.8))
    footprint(1.4, 2.0)
    export(name)


def jeep(name, seed):
    """A burnt-out colony jeep, 4.4 L along X, sitting low on a flat tyre."""
    begin(name)
    rng = random.Random(seed)
    hull = new_bm()
    tbox(hull, (0, 0, 0.8), (4.2, 1.9, 0.7), tilt=3)
    tbox(hull, (1.4, 0, 1.25), (1.3, 1.8, 0.3), tilt=3)  # bonnet
    tbox(hull, (0.4, 0, 1.6), (0.12, 1.7, 0.7))  # windscreen frame
    for k in range(3):
        tbox(hull, (rng.uniform(-1.6, 0.0), rng.uniform(-0.6, 0.6), 1.25), (0.5, 0.4, 0.15))
    cyl(hull, (-0.6, 0, 1.2), (-0.6, 0, 2.0), 0.04, sides=4)  # gun post
    tbox(hull, (-0.6, -0.1, 2.05), (0.2, 0.9, 0.18))
    solid((0, 0, 0.85), (4.2, 1.9, 1.3))
    part(hull, "hull", "gunmetal")
    tyres = new_bm()
    for x, y, z in ((1.4, -0.95, 0.42), (1.4, 0.95, 0.42), (-1.4, -0.95, 0.42), (-1.4, 0.95, 0.3)):
        tapered_tube(tyres, [(x, y - 0.15, z), (x, y + 0.15, z)], [0.42, 0.42], sides=8)
    part(tyres, "tyres", "shadow")
    rust = new_bm()
    tbox(rust, (0, -0.96, 0.85), (3.8, 0.03, 0.4))
    part(rust, "stripe", "anchor")
    footprint(4.6, 2.4)
    export(name)


def fire_barrel(name):
    """A drum with a fire in it, for grunts to warm their hands at."""
    begin(name)
    steel = new_bm()
    tapered_tube(steel, [(0, 0, 0), (0, 0, 0.95)], [0.32, 0.32], sides=10)
    for z in (0.3, 0.65):
        tapered_tube(steel, [(0, 0, z), (0, 0, z + 0.04)], [0.34, 0.34], sides=10)
    column((0, 0, 0), 0.34, 0.95)
    part(steel, "drum", "gunmetal")
    fire = new_bm()
    rng = random.Random(3)
    for k in range(4):
        FP["cone"](fire, (rng.uniform(-0.12, 0.12), rng.uniform(-0.12, 0.12), 0.9), 0.16, rng.uniform(0.35, 0.6), sides=5, rng=rng)
    part(fire, "fire", "light")
    footprint(0.8, 0.8)
    export(name)


def pipe_stack(name):
    """Three concrete drain pipes, 3 m long along Y, two below and one on top."""
    begin(name)
    con = new_bm()
    for c in ((-0.75, 0.7), (0.75, 0.7), (0.0, 1.95)):
        x, z = c
        tapered_tube(con, [(x, -1.5, z), (x, 1.5, z)], [0.7, 0.7], sides=10)
    solid((0, 0, 0.7), (3.0, 3.0, 1.4))
    solid((0, 0, 1.95), (1.4, 3.0, 1.1))
    part(con, "pipes", "concrete")
    dark = new_bm()
    for c in ((-0.75, 0.7), (0.75, 0.7), (0.0, 1.95)):
        tapered_tube(dark, [(c[0], -1.52, c[1]), (c[0], -1.5, c[1])], [0.55, 0.55], sides=10)
        tapered_tube(dark, [(c[0], 1.5, c[1]), (c[0], 1.52, c[1])], [0.55, 0.55], sides=10)
    part(dark, "holes", "shadow")
    top((0, 0, 2.6))
    footprint(3.2, 3.2)
    export(name)


def supply_pod(name):
    """A colony supply drop: a pod punched into the ground at a tilt, its
    chute draped behind it."""
    begin(name)
    steel = new_bm()
    tapered_tube(steel, [(0, 0, -0.3), (0, 0.3, 1.2), (0, 0.45, 2.2)], [0.7, 0.75, 0.55], sides=8)
    for k in range(4):
        a = k * math.pi / 2
        tbox(steel, (math.cos(a) * 0.72, math.sin(a) * 0.72 + 0.2, 0.9), (0.15, 0.15, 1.6), tilt=8)
    column((0, 0.2, 0), 0.75, 2.2)
    part(steel, "pod", "gunmetal")
    chute = new_bm()
    rng = random.Random(9)
    for k in range(3):
        blob(chute, (rng.uniform(-1.0, 1.0), 1.6 + k * 0.6, 0.15), (1.2, 0.8, 0.15), rng, subdiv=1, wobble=0.25, seed=k)
    part(chute, "chute", "canvas")
    band = new_bm()
    tapered_tube(band, [(0, 0.3, 1.2), (0, 0.33, 1.4)], [0.77, 0.77], sides=8)
    part(band, "band", "anchor")
    footprint(2.4, 3.6)
    export(name)


def warning_sign(name):
    """A post with a colony warning board: TURN BACK, painted crude."""
    begin(name)
    wood = new_bm()
    tbox(wood, (0, 0, 1.1), (0.14, 0.14, 2.2))
    tbox(wood, (0, -0.1, 1.9), (1.4, 0.06, 0.8), yaw=4)
    part(wood, "post", "wood")
    paint = new_bm()
    tbox(paint, (0, -0.14, 1.95), (1.1, 0.02, 0.18), yaw=4)
    tbox(paint, (0.1, -0.14, 1.7), (0.7, 0.02, 0.12), yaw=4)
    part(paint, "paint", "anchor")
    column((0, 0, 0), 0.1, 2.2)
    footprint(1.4, 0.4)
    export(name)


def sandbag_nest(name, seed):
    """A ring of sandbags 4 m across, open at the back, an MG on a tripod."""
    begin(name)
    rng = random.Random(seed)
    bags = new_bm()
    for k in range(16):
        a = -math.pi * 0.95 + k * (math.pi * 1.9 / 15)  # open toward +Y
        a -= math.pi / 2
        for row in range(3):
            r = 1.9
            blob(bags, (math.cos(a) * r, math.sin(a) * r, 0.2 + row * 0.38), (0.45, 0.3, 0.2), rng, subdiv=1, wobble=0.1, seed=seed + k * 3 + row)
    # Colliders: front, two sides.
    solid((0, -1.9, 0.6), (3.6, 0.6, 1.2))
    for s in (-1, 1):
        solid((s * 1.9, -0.3, 0.6), (0.6, 3.0, 1.2))
    part(bags, "bags", "canvas")
    gun = new_bm()
    for k in range(3):
        a = k * 2.1
        cyl(gun, (math.cos(a) * 0.4, math.sin(a) * 0.4 - 0.9, 0.0), (0, -0.9, 0.9), 0.03, sides=3)
    tbox(gun, (0, -1.3, 1.0), (0.15, 1.1, 0.18))
    tbox(gun, (0, -0.8, 1.05), (0.25, 0.35, 0.25))
    part(gun, "mg", "gunmetal")
    footprint(4.6, 4.6)
    export(name)


# =============================================================================

# =============================================================================
# Round 2: more buildings, biome props, wall styles, climbs and grapple roosts
# =============================================================================

def cabin(name, seed):
    """A colony cabin of logs, 6 W x 5 D, eaves at 2.8 and a pitched roof to
    4.3 you can run up, a stovepipe, a porch with a lamp."""
    begin(name)
    rng = random.Random(seed)
    wood = new_bm()
    sbox(wood, (0, 0, 1.4), (6.0, 5.0, 2.8))
    for z in [0.25 + k * 0.45 for k in range(6)]:
        for s in (-1, 1):
            tapered_tube(wood, [(-3.15, s * 2.55, z), (3.15, s * 2.55, z)], [0.2, 0.2], sides=6)
    part(wood, "logs", "timber")
    roof = new_bm()
    slope = math.degrees(math.atan2(1.5, 2.9))
    for s in (-1, 1):
        sbox(roof, (0, s * 1.45, 3.55), (6.8, math.hypot(2.9, 1.5) + 0.4, 0.2), tilt=-s * slope)
    for s in (-1, 1):
        tbox(roof, (s * 3.0, 0, 3.4), (0.1, 5.4, 1.3))
    part(roof, "roof", "gunmetal")
    porch = new_bm()
    sbox(porch, (0, -3.2, 0.15), (3.2, 1.4, 0.3))
    for x in (-1.5, 1.5):
        tbox(porch, (x, -3.8, 1.3), (0.15, 0.15, 2.6))
    tbox(porch, (0, -3.3, 2.65), (3.4, 1.6, 0.12), tilt=-12)
    cyl(porch, (1.8, 1.0, 3.6), (1.8, 1.0, 5.0), 0.15, sides=6)
    part(porch, "porch", "wood")
    dark = new_bm()
    tbox(dark, (-0.6, -2.62, 1.05), (1.0, 0.05, 2.1))
    part(dark, "door", "shadow")
    lit = new_bm()
    tbox(lit, (1.5, -2.62, 1.6), (1.0, 0.05, 0.6))
    tbox(lit, (-1.4, -3.75, 2.4), (0.25, 0.25, 0.25))
    part(lit, "windows", "light")
    top((0, 0, 4.3))
    footprint(6.8, 7.2)
    export(name)


def quonset(name, length):
    """A half-round steel hut, 6 m across and 3 m high, `length` long along
    Y, a door and two windows in the front end. You can run along its curve."""
    begin(name)
    steel = new_bm()
    n = 9
    half = length * 0.5
    for k in range(n):
        a0 = math.pi * k / n
        a1 = math.pi * (k + 1) / n
        p0 = (math.cos(a0) * 3.0, math.sin(a0) * 3.0)
        p1 = (math.cos(a1) * 3.0, math.sin(a1) * 3.0)
        cx, cz = (p0[0] + p1[0]) * 0.5, (p0[1] + p1[1]) * 0.5
        w = math.hypot(p1[0] - p0[0], p1[1] - p0[1])
        ang = math.degrees(math.atan2(p1[1] - p0[1], p1[0] - p0[0]))
        # A strip along Y, turned about Y by the arc's slope: build it as a
        # box tilted about X after a quarter turn, i.e. along X, then turned.
        tmp = bmesh.new()
        res = bmesh.ops.create_cube(tmp, size=1.0)
        bmesh.ops.scale(tmp, vec=Vector((w + 0.05, length, 0.12)), verts=res["verts"])
        bmesh.ops.rotate(tmp, verts=list(tmp.verts), cent=Vector((0, 0, 0)), matrix=Matrix.Rotation(math.radians(-ang), 3, "Y"))
        bmesh.ops.translate(tmp, vec=Vector((cx, 0, cz)), verts=list(tmp.verts))
        _merge(steel, tmp)
    for y in range(int(-half) + 1, int(half), 2):
        for k in range(n):
            a0 = math.pi * k / n
            a1 = math.pi * (k + 1) / n
            cyl(steel, (math.cos(a0) * 3.08, y, math.sin(a0) * 3.08), (math.cos(a1) * 3.08, y, math.sin(a1) * 3.08), 0.04, sides=3)
    part(steel, "shell", "gunmetal")
    # Colliders: a box for the body and two slabs for the shoulders.
    solid((0, 0, 1.0), (5.6, length, 2.0))
    solid((0, 0, 2.5), (3.6, length, 1.0))
    ends = new_bm()
    for s in (-1, 1):
        verts = [(math.cos(math.pi * k / 12) * 2.95, s * (half - 0.05), math.sin(math.pi * k / 12) * 2.95) for k in range(13)]
        FP["face2"](ends, verts)
    part(ends, "ends", "concrete")
    dark = new_bm()
    tbox(dark, (0, -half - 0.03, 1.1), (1.4, 0.05, 2.2))
    part(dark, "door", "shadow")
    lit = new_bm()
    for x in (-1.8, 1.8):
        tbox(lit, (x, -half - 0.03, 1.4), (0.8, 0.05, 0.5))
    part(lit, "windows", "light")
    top((0, 0, 3.0))
    footprint(6.2, length + 0.4)
    export(name)


def radio_hut(name):
    """A plywood radio hut, 4 x 4, roof at 2.8, beside a 14 m lattice radio
    mast with a hook block at its top and a dish halfway up."""
    begin(name)
    wood = new_bm()
    sbox(wood, (0, 0, 1.3), (4.0, 4.0, 2.6))
    sbox(wood, (0, 0, 2.7), (4.4, 4.4, 0.2))
    part(wood, "hut", "wood")
    steel = new_bm()
    mx, my = 3.2, 1.2
    for sx in (-0.45, 0.45):
        for sy in (-0.45, 0.45):
            tbox(steel, (mx + sx, my + sy, 7.0), (0.1, 0.1, 14.0))
    for k in range(7):
        z = 0.5 + k * 2.0
        cyl(steel, (mx - 0.45, my - 0.45, z), (mx + 0.45, my + 0.45, z + 2.0), 0.03, sides=3)
        cyl(steel, (mx + 0.45, my - 0.45, z), (mx - 0.45, my + 0.45, z + 2.0), 0.03, sides=3)
    solid((mx, my, 7.0), (1.0, 1.0, 14.0))
    FP["cone"](steel, (mx - 0.9, my, 7.0), 0.9, -0.4, sides=10)
    part(steel, "mast", "gunmetal")
    orange = new_bm()
    metal = new_bm()
    hook_block(metal, orange, (mx, my, 14.6), 1.2)
    part(orange, "hook", "anchor")
    part(metal, "eye", "gunmetal")
    dark = new_bm()
    tbox(dark, (-0.8, -2.02, 1.0), (0.9, 0.05, 2.0))
    part(dark, "door", "shadow")
    lit = new_bm()
    tbox(lit, (0.9, -2.02, 1.6), (1.0, 0.05, 0.5))
    tbox(lit, (mx, my, 15.4), (0.25, 0.25, 0.25))
    part(lit, "windows", "light")
    top((0, 0, 2.8))
    footprint(8.0, 5.0)
    export(name)


def blockhouse_low(name):
    """A one-storey blockhouse, 7 W x 6 D, flat roof at 3.4 behind a low
    parapet, steps up its +X side."""
    begin(name)
    con = new_bm()
    sbox(con, (0, 0, 1.6), (7.0, 6.0, 3.2), bevel=0.06)
    sbox(con, (0, 0, 3.3), (7.4, 6.4, 0.2))
    for s in (-1, 1):
        tbox(con, (0, s * 3.15, 3.6), (7.4, 0.12, 0.4))
    part(con, "base", "concrete")
    steps = new_bm()
    for k in range(4):
        sbox(steps, (4.2, -2.2 + k * 1.3, 0.425 + k * 0.85 - 0.425 * 0 - 0.0), (1.4, 1.3, 0.85 + k * 0.85))
    part(steps, "steps", "concrete")
    dark = new_bm()
    tbox(dark, (-1.5, -3.02, 1.1), (1.2, 0.06, 2.2))
    tbox(dark, (1.6, -3.02, 2.2), (2.0, 0.06, 0.35))
    part(dark, "door", "shadow")
    band = new_bm()
    tbox(band, (0, -3.04, 3.0), (6.9, 0.03, 0.3))
    part(band, "band", "anchor")
    top((0, 0, 3.4))
    footprint(9.4, 6.6)
    export(name)


# --- props shared by every biome ----------------------------------------------

def ammo_crates(name, seed):
    """Colony ammo crates: two stacked and one beside, about 1.4 high."""
    begin(name)
    rng = random.Random(seed)
    wood = new_bm()
    tbox(wood, (0, 0, 0.35), (1.2, 0.8, 0.7))
    tbox(wood, (0.05, 0.02, 1.05), (1.1, 0.75, 0.7), yaw=rng.uniform(-8, 8))
    tbox(wood, (1.05, 0.1, 0.3), (0.8, 0.6, 0.6), yaw=rng.uniform(-20, 20))
    solid((0.3, 0, 0.7), (1.9, 0.9, 1.4))
    part(wood, "crates", "wood")
    band = new_bm()
    for z in (0.35, 1.05):
        tbox(band, (0, -0.42, z), (1.0, 0.03, 0.12))
    part(band, "stencil", "anchor")
    footprint(2.2, 1.2)
    export(name)


def comms_dish(name):
    """A field comms dish on a tripod, about 2.6 m, aimed up and out."""
    begin(name)
    steel = new_bm()
    for k in range(3):
        a = k * 2.1
        cyl(steel, (math.cos(a) * 0.9, math.sin(a) * 0.9, 0), (0, 0, 1.6), 0.04, sides=4)
    tbox(steel, (0, 0, 1.8), (0.2, 0.2, 0.5))
    part(steel, "tripod", "gunmetal")
    dish = new_bm()
    FP["cone"](dish, (0, -0.3, 2.1), 1.0, -0.35, sides=12)
    # Tip it to face up and toward -Y.
    bmesh.ops.rotate(dish, verts=list(dish.verts), cent=Vector((0, -0.3, 2.1)), matrix=Matrix.Rotation(math.radians(-50), 3, "X"))
    part(dish, "dish", "concrete")
    lit = new_bm()
    tbox(lit, (0, -0.9, 2.5), (0.12, 0.12, 0.12))
    part(lit, "tip", "light")
    column((0, 0, 0), 0.5, 2.2)
    footprint(2.2, 2.2)
    export(name)


def lamp_post(name):
    """A work-light post, 5 m, two lamps on an arm."""
    begin(name)
    steel = new_bm()
    tapered_tube(steel, [(0, 0, 0), (0, 0, 5.0)], [0.12, 0.08], sides=6)
    tbox(steel, (0, -0.6, 4.9), (0.1, 1.3, 0.1))
    tbox(steel, (0, 0, 0.1), (0.5, 0.5, 0.2))
    part(steel, "post", "gunmetal")
    lit = new_bm()
    for x in (-0.25, 0.25):
        tbox(lit, (x, -1.2, 4.75), (0.35, 0.3, 0.2))
    part(lit, "lamps", "light")
    column((0, 0, 0), 0.15, 5.0)
    footprint(0.8, 1.6)
    export(name)


def tarp_shelter(name, seed):
    """A tarp lean-to on poles over a bench and crates, 4 x 3, 2.4 high at
    the front, 1.4 at the back. Crouch under it, or climb its roof."""
    begin(name)
    rng = random.Random(seed)
    wood = new_bm()
    for x in (-1.9, 1.9):
        tbox(wood, (x, -1.4, 1.2), (0.12, 0.12, 2.4))
        tbox(wood, (x, 1.4, 0.7), (0.12, 0.12, 1.4))
    tbox(wood, (0, 0.6, 0.45), (2.6, 0.5, 0.1))
    for x in (-1.0, 1.0):
        tbox(wood, (x, 0.6, 0.2), (0.1, 0.4, 0.4))
    part(wood, "poles", "wood")
    tarp = new_bm()
    ang = math.degrees(math.atan2(1.0, 2.8))
    tbox(tarp, (0, 0, 1.95), (4.4, math.hypot(2.8, 1.0) + 0.3, 0.05), tilt=-ang)
    for k in range(3):
        tbox(tarp, (rng.uniform(-1.5, 1.5), -1.55, 2.3 - rng.uniform(0, 0.3)), (0.5, 0.05, 0.4))
    part(tarp, "tarp", "canvas")
    for x in (-1.9, 1.9):
        column((x, -1.4, 0), 0.1, 2.4)
        column((x, 1.4, 0), 0.1, 1.4)
    solid((0, 0, 1.95), (4.4, math.hypot(2.8, 1.0) + 0.3, 0.1), tilt=-ang)
    crates = new_bm()
    tbox(crates, (1.2, 1.0, 0.35), (0.9, 0.6, 0.7))
    part(crates, "crates", "wood")
    footprint(4.6, 3.4)
    export(name)


def field_table(name, seed):
    """A folding table with a map and a radio, two stools: someone's post."""
    begin(name)
    rng = random.Random(seed)
    wood = new_bm()
    tbox(wood, (0, 0, 0.78), (1.8, 0.9, 0.06))
    for sx in (-0.8, 0.8):
        for sy in (-0.38, 0.38):
            tbox(wood, (sx, sy, 0.38), (0.05, 0.05, 0.76))
    for x in (-0.5, 0.6):
        tbox(wood, (x, -0.8, 0.25), (0.4, 0.4, 0.5))
    part(wood, "table", "wood")
    paper = new_bm()
    tbox(paper, (-0.3, 0.05, 0.82), (0.8, 0.55, 0.01), yaw=rng.uniform(-10, 10))
    part(paper, "map", "canvas")
    radio = new_bm()
    tbox(radio, (0.55, 0.1, 0.95), (0.4, 0.3, 0.3))
    cyl(radio, (0.65, 0.15, 1.1), (0.7, 0.2, 1.7), 0.01, sides=3)
    part(radio, "radio", "gunmetal")
    lit = new_bm()
    tbox(lit, (0.55, -0.06, 1.0), (0.2, 0.01, 0.08))
    part(lit, "dial", "light")
    solid((0, 0, 0.4), (1.8, 0.9, 0.8))
    footprint(2.0, 2.0)
    export(name)


# --- props of one biome each --------------------------------------------------

def lumber_stack(name, seed):
    """Forest: sawn planks stacked on bunks with stickers between, 4 x 1.4 x 1.3."""
    begin(name)
    rng = random.Random(seed)
    wood = new_bm()
    for x in (-1.5, 0.0, 1.5):
        tbox(wood, (x, 0, 0.1), (0.2, 1.4, 0.2))
    for layer in range(5):
        z = 0.28 + layer * 0.22
        for k in range(5):
            tbox(wood, (rng.uniform(-0.1, 0.1), -0.56 + k * 0.28, z), (4.0 - rng.uniform(0, 0.4), 0.25, 0.12))
        for x in (-1.5, 0.0, 1.5):
            tbox(wood, (x, 0, z + 0.09), (0.05, 1.4, 0.05))
    solid((0, 0, 0.65), (4.0, 1.4, 1.3))
    part(wood, "planks", "timber")
    straps = new_bm()
    for x in (-1.0, 1.0):
        tbox(straps, (x, 0, 0.7), (0.05, 1.45, 1.35))
    part(straps, "straps", "anchor")
    footprint(4.2, 1.6)
    export(name)


def woodpile(name, seed):
    """Forest: split firewood heaped against a chopping stump with an axe in it."""
    begin(name)
    rng = random.Random(seed)
    wood = new_bm()
    for k in range(26):
        x = rng.uniform(-1.0, 1.0)
        y = rng.uniform(-0.4, 0.4)
        z = 0.12 + (1.0 - abs(x)) * rng.uniform(0.0, 0.7)
        a = rng.uniform(-0.3, 0.3)
        tapered_tube(wood, [(x, y - 0.35, z), (x + a, y + 0.35, z)], [0.1, 0.1], sides=4)
    tapered_tube(wood, [(1.6, 0, 0), (1.6, 0, 0.6)], [0.35, 0.33], sides=8)
    part(wood, "logs", "bark")
    steel = new_bm()
    tbox(steel, (1.6, 0, 0.75), (0.05, 0.25, 0.15), tilt=30)
    cyl(steel, (1.6, 0.05, 0.7), (1.6, 0.6, 1.1), 0.03, sides=4)
    part(steel, "axe", "gunmetal")
    solid((0.2, 0, 0.45), (2.4, 1.0, 0.9))
    footprint(3.0, 1.4)
    export(name)


def rowboat(name, seed):
    """Marsh: a flat-bottomed rowboat pulled up and tipped on its side, 4 m."""
    begin(name)
    rng = random.Random(seed)
    wood = new_bm()
    pts = [(-2.0, 0, 0.5), (-1.0, 0, 0.45), (1.0, 0, 0.45), (2.0, 0, 0.6)]
    for s in (-1, 1):
        for k in range(len(pts) - 1):
            a, b = pts[k], pts[k + 1]
            wa = 0.15 if k == 0 else 0.7
            wb = 0.7 if k < len(pts) - 2 else 0.25
            FP["face2"](wood, [(a[0], s * wa, 0.1), (b[0], s * wb, 0.1), (b[0], s * wb, 0.75), (a[0], s * wa, 0.75)])
    tbox(wood, (0, 0, 0.1), (3.6, 1.2, 0.08))
    for x in (-0.6, 0.6):
        tbox(wood, (x, 0, 0.5), (0.3, 1.3, 0.06))
    bmesh.ops.rotate(wood, verts=list(wood.verts), cent=Vector((0, 0, 0)), matrix=Matrix.Rotation(math.radians(70), 3, "X"))
    bmesh.ops.translate(wood, vec=Vector((0, 0, 0.5)), verts=list(wood.verts))
    part(wood, "hull", "wood")
    oar = new_bm()
    tbox(oar, (0.3, -1.0, 0.08), (2.4, 0.08, 0.05), yaw=rng.uniform(-20, 20))
    part(oar, "oar", "timber")
    solid((0, 0, 0.6), (4.0, 0.9, 1.2))
    footprint(4.2, 2.0)
    export(name)


def net_rack(name, seed):
    """Marsh: poles with fishing nets hung to dry, 4 m long, 2.2 high."""
    begin(name)
    rng = random.Random(seed)
    wood = new_bm()
    for x in (-2.0, 0.0, 2.0):
        tbox(wood, (x, 0, 1.1), (0.12, 0.12, 2.2))
    tbox(wood, (0, 0, 2.15), (4.3, 0.1, 0.1))
    part(wood, "poles", "wood")
    net = new_bm()
    for k in range(4):
        x0 = -2.0 + k
        FP["face2"](net, [(x0, 0, 2.1), (x0 + 1.0, 0, 2.1), (x0 + 1.0, rng.uniform(-0.1, 0.1), rng.uniform(0.6, 1.0)), (x0, rng.uniform(-0.1, 0.1), rng.uniform(0.5, 0.9))])
    part(net, "net", "rope")
    floats = new_bm()
    for k in range(6):
        blob(floats, (-1.8 + k * 0.7, 0, 2.0), (0.1, 0.1, 0.1), rng, subdiv=1, wobble=0.0, seed=k)
    part(floats, "floats", "anchor")
    for x in (-2.0, 0.0, 2.0):
        column((x, 0, 0), 0.1, 2.2)
    footprint(4.4, 1.0)
    export(name)


def buoy(name, seed):
    """Marsh: a channel buoy washed up, rusty, on its side, 1.4 across."""
    begin(name)
    rng = random.Random(seed)
    steel = new_bm()
    tapered_tube(steel, [(-0.9, 0, 0.6), (-0.3, 0, 0.7), (0.5, 0, 0.7), (1.1, 0, 0.5)], [0.4, 0.7, 0.7, 0.2], sides=10)
    part(steel, "body", "anchor")
    band = new_bm()
    tapered_tube(band, [(0.0, 0, 0.7), (0.3, 0, 0.7)], [0.72, 0.72], sides=10)
    tbox(band, (1.3, 0, 0.5), (0.5, 0.08, 0.08))
    part(band, "band", "concrete")
    solid((0, 0, 0.6), (2.0, 1.3, 1.2))
    footprint(2.4, 1.6)
    export(name)


def rib_arch(name, seed):
    """Boneyard: a titan's ribcage plate arching out of the ground, 7 m across
    and 5 m high: walk under it, run along its flank."""
    begin(name)
    rng = random.Random(seed)
    hull = new_bm()
    n = 10
    for k in range(n):
        a0 = math.pi * k / n
        a1 = math.pi * (k + 1) / n
        p0 = Vector((math.cos(a0) * 3.5, 0, math.sin(a0) * 5.0))
        p1 = Vector((math.cos(a1) * 3.5, 0, math.sin(a1) * 5.0))
        tapered_tube(hull, [p0, p1], [0.45 - 0.1 * math.sin(a0), 0.45 - 0.1 * math.sin(a1)], sides=6)
    for s in (-1, 1):
        blob(hull, (s * 3.5, 0, 0.3), (0.9, 0.9, 0.5), rng, subdiv=1, wobble=0.2, seed=s + 5)
    part(hull, "rib", "titan_armor")
    plates = new_bm()
    for k in range(3):
        a = math.pi * (0.2 + 0.3 * k)
        tbox(plates, (math.cos(a) * 3.3, 0.35, math.sin(a) * 4.7), (1.2, 0.15, 0.8), yaw=0, tilt=0)
    part(plates, "plates", "gunmetal")
    for s in (-1, 1):
        solid((s * 3.2, 0, 1.6), (1.0, 0.9, 3.2))
    solid((0, 0, 4.8), (3.6, 0.9, 0.8))
    footprint(8.2, 2.0)
    export(name)


def hull_plate(name, seed):
    """Boneyard: a sheet of titan hull armour driven edge-down into the ground,
    5 m long and 3.5 high, leaning a little: cover, or a short wall to run."""
    begin(name)
    rng = random.Random(seed)
    hull = new_bm()
    sbox(hull, (0, 0.25, 1.7), (5.0, 0.35, 3.6), tilt=8)
    for k in range(6):
        tbox(hull, (rng.uniform(-2.2, 2.2), 0.05, rng.uniform(0.6, 3.0)), (0.12, 0.1, 0.12), tilt=8)
    part(hull, "plate", "titan_armor")
    paint = new_bm()
    tbox(paint, (-0.8, 0.02, 2.4), (1.6, 0.03, 0.5), tilt=8)
    part(paint, "marking", "anchor")
    footprint(5.4, 1.8)
    export(name)


def engine_block(name, seed):
    """Boneyard: a titan's reactor housing torn out and dumped, 3 x 2.2 x 2.4,
    cables spilling out of it."""
    begin(name)
    rng = random.Random(seed)
    steel = new_bm()
    sbox(steel, (0, 0, 1.0), (3.0, 2.2, 2.0), bevel=0.15)
    tapered_tube(steel, [(0, 0, 2.0), (0, 0, 2.5)], [0.8, 0.6], sides=8)
    for x in (-1.0, 0.0, 1.0):
        tbox(steel, (x, -1.12, 1.2), (0.6, 0.06, 1.4))
    part(steel, "housing", "titan_armor")
    cable = new_bm()
    for k in range(4):
        p0 = Vector((rng.uniform(-1.2, 1.2), 1.1, rng.uniform(0.6, 1.6)))
        p1 = p0 + Vector((rng.uniform(-0.6, 0.6), rng.uniform(0.6, 1.4), -p0.z + 0.08))
        tapered_tube(cable, [p0, (p0 + p1) * 0.5 + Vector((0, 0, 0.2)), p1], [0.08, 0.08, 0.08], sides=4)
    part(cable, "cables", "shadow")
    glow = new_bm()
    tbox(glow, (0, -1.16, 1.6), (0.8, 0.03, 0.3))
    part(glow, "core", "light")
    footprint(3.4, 3.6)
    export(name)


# --- walls to run ------------------------------------------------------------

def panel_wall(name, length, seed):
    """Plywood hoarding on posts, painted over with colony slogans: `length`
    along X, 4.4 high. Blue trim along the top and bottom."""
    begin(name)
    rng = random.Random(seed)
    wood = new_bm()
    sbox(wood, (0, 0, 2.4), (length, 0.3, 4.0))
    n = int(length / 1.2)
    for k in range(n):
        x = -length * 0.5 + (k + 0.5) * length / n
        tbox(wood, (x, -0.16, 2.4 + rng.uniform(-0.05, 0.05)), (length / n - 0.04, 0.03, 3.9))
    part(wood, "boards", "wood")
    posts = new_bm()
    for x in [(-length * 0.5 + 0.3) + k * (length - 0.6) / 4 for k in range(5)]:
        tbox(posts, (x, 0.25, 2.2), (0.2, 0.2, 4.4))
        column((x, 0.25, 0), 0.15, 0.4)
    part(posts, "posts", "timber")
    trim = new_bm()
    for s in (-1, 1):
        for z in (0.55, 4.25):
            tbox(trim, (0, s * 0.17, z), (length, 0.03, 0.2))
    part(trim, "trim", "wallrun")
    paint = new_bm()
    for k in range(3):
        tbox(paint, (rng.uniform(-length * 0.35, length * 0.35), -0.18, rng.uniform(1.4, 3.4)), (rng.uniform(1.2, 2.4), 0.02, rng.uniform(0.3, 0.6)), yaw=0)
    part(paint, "paint", "anchor")
    footprint(length + 0.4, 1.4)
    export(name)


def container_wall(name, seed):
    """Two shipping containers end to end with a third stacked across the
    joint: a 12 m wall, 5.2 high in the middle. Blue chevrons along its side."""
    begin(name)
    rng = random.Random(seed)
    steel = new_bm()
    for x in (-3.05, 3.05):
        sbox(steel, (x, 0, 1.3), (6.0, 2.4, 2.6))
        for k in range(12):
            tbox(steel, (x - 2.75 + k * 0.5, -1.22, 1.3), (0.15, 0.05, 2.5))
    sbox(steel, (0, 0.05, 3.9), (6.0, 2.4, 2.6))
    for k in range(12):
        tbox(steel, (-2.75 + k * 0.5, -1.17, 3.9), (0.15, 0.05, 2.5))
    part(steel, "containers", "gunmetal")
    trim = new_bm()
    for x in (-3.05, 3.05):
        tbox(trim, (x, -1.26, 2.3), (5.6, 0.02, 0.25))
    tbox(trim, (0, -1.21, 4.9), (5.6, 0.02, 0.25))
    part(trim, "chevrons", "wallrun")
    doors = new_bm()
    for x in (-6.07, 6.07):
        tbox(doors, (x, 0, 1.3), (0.05, 2.2, 2.4))
    part(doors, "doors", "shadow")
    top((0, 0.05, 5.2))
    footprint(12.4, 2.8)
    export(name)


def hull_wall(name, seed):
    """Titan hull plates riveted to a girder frame: a 12 m wall, 5 high."""
    begin(name)
    rng = random.Random(seed)
    hull = new_bm()
    sbox(hull, (0, 0, 2.7), (12.0, 0.4, 4.6))
    for k in range(5):
        x = -4.8 + k * 2.4
        tbox(hull, (x, -0.24, 2.7 + rng.uniform(-0.2, 0.2)), (2.3, 0.08, 4.4 + rng.uniform(-0.3, 0.3)), yaw=rng.uniform(-2, 2))
    part(hull, "plates", "titan_armor")
    frame = new_bm()
    for x in (-5.8, -2.9, 0.0, 2.9, 5.8):
        tbox(frame, (x, 0.35, 2.5), (0.3, 0.3, 5.0))
        cyl(frame, (x, 1.8, 0.0), (x, 0.4, 3.5), 0.08, sides=4)
        column((x, 0.35, 0), 0.2, 0.4)
    part(frame, "girders", "gunmetal")
    trim = new_bm()
    tbox(trim, (0, -0.29, 0.6), (12.0, 0.02, 0.25))
    tbox(trim, (0, -0.29, 4.8), (12.0, 0.02, 0.25))
    part(trim, "trim", "wallrun")
    footprint(12.4, 2.4)
    export(name)


# --- climbs and roosts ---------------------------------------------------------

def corner_kick(name, height):
    """Two concrete walls `height` high meeting in a corner, 7 m each, and a
    deck behind the corner flush with their tops, railed on the far side. Run
    the inside of one wall into the corner, kick off it, and double jump over
    the end wall (or wallrun it and kick back off it) onto the deck. (A deck inside the corner sits in the way of
    the run.)"""
    begin(name)
    con = new_bm()
    # Wall A along Y on the +X side (run it toward +Y); wall B along X at +Y.
    sbox(con, (3.3, 0, height * 0.5), (0.6, 7.0, height), bevel=0.04)
    sbox(con, (0, 3.3, height * 0.5), (7.0, 0.6, height), bevel=0.04)
    part(con, "walls", "concrete")
    deck = new_bm()
    sbox(deck, (0.15, 5.1, height - 0.15), (7.3, 3.0, 0.3))
    for x in (-3.3, 3.5):
        tbox(deck, (x, 6.5, height * 0.5), (0.2, 0.2, height))
        column((x, 6.5, 0), 0.12, height)
    part(deck, "deck", "gunmetal")
    rail = new_bm()
    sbox(rail, (0.15, 6.55, height + 0.55), (7.3, 0.1, 1.1))
    for x in (-3.45, 3.75):
        sbox(rail, (x, 5.1, height + 0.55), (0.1, 3.0, 1.1))
    part(rail, "rail", "gunmetal")
    blue = new_bm()
    z = 1.0
    while z < height - 0.3:
        tbox(blue, (2.99, -0.5, z), (0.02, 6.0, 0.25))
        tbox(blue, (-0.5, 2.99, z), (6.0, 0.02, 0.25))
        z += 1.1
    part(blue, "chevrons", "wallrun")
    orange = new_bm()
    tbox(orange, (0, 2.99, height - 0.12), (7.0, 0.02, 0.24))
    part(orange, "edge", "anchor")
    top((0.15, 5.1, height))
    footprint(7.6, 14.0)
    export(name)


def pillar_ledge(name, height):
    """A concrete block `height` high, 6 W x 3 D, with a squat pillar half its
    height built against its face: hop the pillar, then onto the block."""
    begin(name)
    con = new_bm()
    sbox(con, (0, 1.5, height * 0.5), (6.0, 3.0, height), bevel=0.05)
    pillar_h = height * 0.5
    sbox(con, (0, -0.9, pillar_h * 0.5), (2.0, 1.8, pillar_h), bevel=0.05)
    part(con, "block", "concrete")
    steel = new_bm()
    for s in (-1, 1):
        tbox(steel, (s * 2.9, 1.5, height + 0.5), (0.08, 2.8, 0.08))
        tbox(steel, (s * 2.9, 0.2, height + 0.25), (0.08, 0.08, 0.5))
        tbox(steel, (s * 2.9, 2.8, height + 0.25), (0.08, 0.08, 0.5))
    part(steel, "rail", "gunmetal")
    orange = new_bm()
    tbox(orange, (0, -0.01, height - 0.15), (6.0, 0.02, 0.3))
    tbox(orange, (0, -1.81, pillar_h - 0.12), (2.0, 0.02, 0.24))
    part(orange, "edges", "anchor")
    top((0, 1.5, height))
    footprint(6.4, 6.2)
    export(name)


def scaffold_roost(name):
    """A tall scaffold tower, 3 x 3, a plank deck at 7 m with a hook hung
    3.2 m over it on a gallows arm: grapple up and land on the deck."""
    begin(name)
    pipe = new_bm()
    for x in (-1.5, 1.5):
        for y in (-1.5, 1.5):
            tbox(pipe, (x, y, 5.0), (0.1, 0.1, 10.0))
            column((x, y, 0), 0.08, 7.0)
    for z in (1.5, 3.0, 4.5, 6.0, 7.9):
        for s in (-1, 1):
            tbox(pipe, (0, s * 1.5, z), (3.0, 0.08, 0.08))
            tbox(pipe, (s * 1.5, 0, z), (0.08, 3.0, 0.08))
    for s in (-1, 1):
        cyl(pipe, (s * 1.5, -1.5, 0.1), (s * 1.5, 1.5, 3.0), 0.04, sides=4)
        cyl(pipe, (s * 1.5, 1.5, 3.1), (s * 1.5, -1.5, 6.9), 0.04, sides=4)
    tbox(pipe, (1.5, 1.5, 10.2), (0.12, 0.12, 0.5))
    tbox(pipe, (0.4, 0.4, 10.4), (2.6, 0.12, 0.12), yaw=45)
    part(pipe, "pipes", "gunmetal")
    wood = new_bm()
    sbox(wood, (0, 0, 6.9), (3.2, 3.2, 0.2))
    part(wood, "deck", "wood")
    tarp = new_bm()
    tbox(tarp, (0, 1.55, 7.6), (3.0, 0.04, 1.2))
    tbox(tarp, (-1.55, 0, 7.6), (0.04, 3.0, 1.2))
    part(tarp, "screens", "canvas")
    orange = new_bm()
    metal = new_bm()
    cyl(metal, (-0.4, -0.4, 10.4), (-0.4, -0.4, 10.0), 0.02, sides=3)
    hook_block(metal, orange, (-0.4, -0.4, 10.2), 0.9)
    part(orange, "hook", "anchor")
    part(metal, "eye", "gunmetal")
    top((0, 0, 7.0))
    footprint(3.6, 3.6)
    export(name)


def hook_pole(name):
    """A steel pole 9 m tall planted just behind a wall, a hook block on top:
    grapple it from outside and swing over."""
    begin(name)
    steel = new_bm()
    tapered_tube(steel, [(0, 0, 0), (0, 0, 8.4)], [0.22, 0.16], sides=6)
    tbox(steel, (0, 0, 0.3), (0.8, 0.8, 0.6))
    column((0, 0, 0), 0.22, 8.4)
    part(steel, "pole", "gunmetal")
    orange = new_bm()
    metal = new_bm()
    hook_block(metal, orange, (0, 0, 9.0), 1.2)
    part(orange, "hook", "anchor")
    part(metal, "eye", "gunmetal")
    footprint(1.2, 1.2)
    export(name)


def shield_towers(name, span, drop):
    """For a chasm: two lattice towers standing in the river `span` apart
    along Y, a blast shield hung between them on chains, its face from 0.5 to
    6 m above the lip (origin) for wallrunning across. The towers reach `drop`
    m down to the riverbed."""
    begin(name)
    half = span * 0.5
    steel = new_bm()
    for y in (-half - 1.2, half + 1.2):
        for sx in (-0.7, 0.7):
            for sy in (-0.7, 0.7):
                tbox(steel, (sx, y + sy, (10.0 - drop) * 0.5), (0.14, 0.14, 10.0 + drop))
        for k in range(int((10 + drop) / 2.5)):
            z = -drop + k * 2.5
            cyl(steel, (-0.7, y - 0.7, z), (0.7, y + 0.7, z + 2.5), 0.04, sides=3)
            cyl(steel, (0.7, y - 0.7, z), (-0.7, y + 0.7, z + 2.5), 0.04, sides=3)
        solid((0, y, (10.0 - drop) * 0.5), (1.5, 1.5, 10.0 + drop))
    tbox(steel, (0, 0, 9.8), (0.4, span + 3.8, 0.4))
    for y in (-half + 1.0, -half * 0.3, half * 0.3, half - 1.0):
        cyl(steel, (0, y, 9.6), (0, y, 6.1), 0.03, sides=3)
    part(steel, "towers", "gunmetal")
    shield = new_bm()
    sbox(shield, (0, 0, 3.25), (1.0, span, 5.5))
    part(shield, "shield", "concrete")
    blue = new_bm()
    for s in (-1, 1):
        for z in (1.0, 5.5):
            tbox(blue, (s * 0.51, 0, z), (0.02, span - 0.4, 0.3))
    part(blue, "trim", "wallrun")
    lit = new_bm()
    for y in (-half - 1.2, half + 1.2):
        tbox(lit, (0, y, 10.2), (0.3, 0.3, 0.3))
    part(lit, "beacons", "light")
    footprint(2.0, span + 4.0)
    export(name)


def round2():
    cabin("cabin", 501)
    quonset("quonset", 10.0)
    radio_hut("radio_hut")
    blockhouse_low("blockhouse_low")
    ammo_crates("ammo_crates", 503)
    comms_dish("comms_dish")
    lamp_post("lamp_post")
    tarp_shelter("tarp_shelter", 507)
    field_table("field_table", 509)
    lumber_stack("lumber_stack", 511)
    woodpile("woodpile", 513)
    rowboat("rowboat", 517)
    net_rack("net_rack", 519)
    buoy("buoy", 521)
    rib_arch("rib_arch", 523)
    hull_plate("hull_plate", 527)
    engine_block("engine_block", 529)
    panel_wall("panel_wall", 12.0, 531)
    container_wall("container_wall", 533)
    hull_wall("hull_wall", 537)
    corner_kick("corner_kick", 3.2)
    pillar_ledge("pillar_ledge", 4.0)
    scaffold_roost("scaffold_roost")
    hook_pole("hook_pole")
    shield_towers("shield_towers", 16.0, 16.0)


def write_shapes():
    def v3(v):
        return "Vector3(%.3f, %.3f, %.3f)" % tuple(round(c, 3) + 0.0 for c in v)

    lines = [
        "extends RefCounted",
        "## Generated by tools/procgen/build_props.py: do not edit by hand.",
        "## Per model in assets/models/procgen: colliders (local centre, size,",
        "## yaw, tilt about X, degrees), columns (base, radius, height), grapple",
        "## hooks and standing tops, and the footprint (x, z), all in the model's",
        "## own frame (front +Z).",
        "",
        "const SHAPES := {",
    ]
    for name, s in SHAPES.items():
        lines.append('\t"%s": {' % name)
        lines.append('\t\t"boxes": [%s],' % ", ".join(
            "[%s, %s, %.2f, %.2f]" % (v3(c), v3(sz), yaw, tilt) for c, sz, yaw, tilt in s["boxes"]))
        lines.append('\t\t"columns": [%s],' % ", ".join(
            "[%s, %.2f, %.2f]" % (v3(b), r, h) for b, r, h in s["columns"]))
        lines.append('\t\t"hooks": [%s],' % ", ".join(v3(h) for h in s["hooks"]))
        lines.append('\t\t"tops": [%s],' % ", ".join(v3(t) for t in s["tops"]))
        sx, sy = s["size"] or (2.0, 2.0)
        lines.append('\t\t"size": Vector2(%.2f, %.2f),' % (sx, sy))
        lines.append("\t},")
    lines.append("}")
    SHAPES_GD.write_text("\n".join(lines) + "\n")
    print("wrote", SHAPES_GD)


def main():
    clear()
    bunker("bunker")
    blockhouse("blockhouse")
    garage("garage")
    warehouse("warehouse")
    silo("silo")
    water_tower("water_tower")
    scaffold("scaffold")
    ruin_house("ruin_house", 401)
    ruin_shell("ruin_shell", 409)
    tower_crane("tower_crane")
    billboard("billboard_s", 6.0, 3.4, 419)
    billboard("billboard_m", 10.0, 4.0, 421)
    billboard("billboard_l", 16.0, 4.6, 431)
    blast_wall("blast_wall", 433)
    kick_slot("kick_slot", 12.0, 4.6)
    lean_slab("lean_slab", 439)
    grapple_mast("grapple_mast", 13.0)
    grapple_mast("grapple_mast_short", 9.0)
    hook_bracket("hook_bracket")
    jersey_barrier("jersey_barrier")
    tank_trap("tank_trap")
    tire_stack("tire_stack", 443)
    cable_reel("cable_reel")
    jeep("jeep", 449)
    fire_barrel("fire_barrel")
    pipe_stack("pipe_stack")
    supply_pod("supply_pod")
    warning_sign("warning_sign")
    sandbag_nest("sandbag_nest", 457)
    round2()
    write_shapes()


main()
