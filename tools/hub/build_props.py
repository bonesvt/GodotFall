"""Models the temple hub's props in Blender and exports them as glTF.

    blender -b --python tools/hub/build_props.py

Writes assets/models/hub/<name>.glb. Everything is low-poly and flat shaded in
the PS2 style. Objects are named "<part>__<material>"; the game swaps in its own
material for each suffix (scripts/hub/hub_props.gd), so no textures or UVs ship
in the files: the ps2 surface shader box-projects its textures. Empties named
"*Marker" mark attach points (the idol's eye). Origins sit on the ground.

Seeded, so re-running gives the same meshes.
"""
import math
import random
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

OUT = Path(__file__).resolve().parent.parent.parent / "assets" / "models" / "hub"


# --- scene helpers -----------------------------------------------------------

def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for block in (bpy.data.meshes, bpy.data.materials):
        for item in list(block):
            block.remove(item)


def obj_from_bm(bm, name):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = False
    ob = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(ob)
    return ob


def material_slot(ob, mat_name):
    mat = bpy.data.materials.get(mat_name) or bpy.data.materials.new(mat_name)
    ob.data.materials.append(mat)


def part(bm, name, mat):
    ob = obj_from_bm(bm, f"{name}__{mat}")
    material_slot(ob, mat)
    return ob


def marker(name, loc):
    em = bpy.data.objects.new(name, None)
    em.location = loc
    bpy.context.collection.objects.link(em)
    return em


def export(name):
    OUT.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(OUT / f"{name}.glb"), export_format="GLB", export_apply=True,
        export_yup=True, export_materials="PLACEHOLDER", export_normals=True,
        export_texcoords=False, export_colors=False,
    )
    print("wrote", name)
    clear()


# --- shape helpers (bmesh, Z up; glTF export turns Z up into Y up) --------------

def tapered_tube(bm, points, radii, sides=6, twist=0.0):
    """A ring per point, joined into a tube; caps at both ends."""
    rings = []
    for i, (p, r) in enumerate(zip(points, radii)):
        p = Vector(p)
        d = (Vector(points[min(i + 1, len(points) - 1)]) - Vector(points[max(i - 1, 0)])).normalized()
        side = d.orthogonal().normalized()
        up = d.cross(side).normalized()
        ring = []
        for k in range(sides):
            a = 2 * math.pi * k / sides + twist * i
            ring.append(bm.verts.new(p + (side * math.cos(a) + up * math.sin(a)) * r))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for k in range(sides):
            bm.faces.new((a[k], a[(k + 1) % sides], b[(k + 1) % sides], b[k]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])


def blob(bm, center, size, rng, subdiv=1, wobble=0.22, seed=0):
    """A faceted lumpy ball: icosphere with noisy vertices, scaled to `size`."""
    res = bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0)
    for v in res["verts"]:
        n = noise.noise(v.co * 1.7 + Vector((seed, seed * 0.3, 0)))
        v.co *= 1.0 + wobble * n + rng.uniform(-wobble, wobble) * 0.5
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2])) + Vector(center)
    return res["verts"]


def box(bm, center, size, rot_z=0.0, bevel=0.0):
    """A (bevelled) box, built in its own bmesh and copied into `bm`."""
    tmp = bmesh.new()
    res = bmesh.ops.create_cube(tmp, size=1.0)
    bmesh.ops.scale(tmp, vec=Vector(size), verts=res["verts"])
    if bevel > 0.0:
        bmesh.ops.bevel(tmp, geom=list(tmp.edges), offset=bevel, segments=1, affect="EDGES")
    bmesh.ops.rotate(tmp, verts=list(tmp.verts), cent=Vector((0, 0, 0)), matrix=Matrix.Rotation(rot_z, 3, "Z"))
    bmesh.ops.translate(tmp, vec=Vector(center), verts=list(tmp.verts))
    merge(bm, tmp)


def merge(bm, tmp):
    """Copies every face of `tmp` into `bm` and frees `tmp`."""
    for f in tmp.faces:
        bm.faces.new([bm.verts.new(v.co) for v in f.verts])
    tmp.free()


def face2(bm, cos):
    """A double-sided face: front and back each get their own vertices."""
    cos = [Vector(c) for c in cos]
    bm.faces.new([bm.verts.new(c) for c in cos])
    bm.faces.new([bm.verts.new(c) for c in reversed(cos)])


def new_bm():
    return bmesh.new()


# --- vegetation --------------------------------------------------------------

def broad_tree(name, seed, height):
    """Jungle hardwood: a leaning, tapering trunk splitting into two or three
    limbs, each carrying a cluster of faceted leaf clumps."""
    rng = random.Random(seed)
    trunk = new_bm()
    lean = Vector((rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), 0))
    pts = [Vector((0, 0, 0)) + lean * (t * t) + Vector((0, 0, height * 0.62 * t)) for t in (0.0, 0.25, 0.55, 0.8, 1.0)]
    base_r = 0.28 + height * 0.025
    tapered_tube(trunk, pts, [base_r * 1.7, base_r * 1.05, base_r * 0.9, base_r * 0.8, base_r * 0.7], sides=7)
    # Root flare.
    for k in range(4):
        a = k * math.pi / 2 + rng.uniform(-0.3, 0.3)
        d = Vector((math.cos(a), math.sin(a), 0))
        tapered_tube(trunk, [d * base_r * 0.5 + Vector((0, 0, 0.6)), d * base_r * 2.3 + Vector((0, 0, -0.05))], [base_r * 0.45, base_r * 0.2], sides=4)
    top = pts[-1]
    tips = []
    for k in range(rng.choice((2, 3))):
        a = 2 * math.pi * k / 3 + rng.uniform(-0.4, 0.4)
        out = Vector((math.cos(a), math.sin(a), 0)) * height * rng.uniform(0.18, 0.26)
        tip = top + out + Vector((0, 0, height * rng.uniform(0.18, 0.3)))
        mid = top.lerp(tip, 0.5) + Vector((0, 0, 0.3))
        tapered_tube(trunk, [top - Vector((0, 0, 0.4)), mid, tip], [base_r * 0.6, base_r * 0.42, base_r * 0.25], sides=5)
        tips.append(tip)
    part(trunk, "trunk", "bark")
    leaves = new_bm()
    s = height * 0.2
    for i, tip in enumerate(tips):
        blob(leaves, tip + Vector((0, 0, s * 0.3)), (s * 1.3, s * 1.3, s * 0.75), rng, seed=seed + i)
        for j in range(2):
            off = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.2, 0.4))) * s * 0.9
            blob(leaves, tip + off, (s * 0.8, s * 0.8, s * 0.55), rng, seed=seed + 10 * i + j)
    blob(leaves, top + Vector((0, 0, height * 0.32)), (s * 1.2, s * 1.2, s * 0.8), rng, seed=seed + 99)
    part(leaves, "canopy", "leaves")
    export(name)


def palm(name, seed, height):
    """A curved, ringed palm trunk with a crown of drooping fronds."""
    rng = random.Random(seed)
    trunk = new_bm()
    bend = Vector((rng.uniform(0.8, 1.6), rng.uniform(-0.4, 0.4), 0))
    n = 8
    pts = [bend * math.sin(t / n * math.pi * 0.5) ** 2 * (height * 0.25) + Vector((0, 0, height * t / n)) for t in range(n + 1)]
    radii = [0.32 - 0.12 * t / n + (0.04 if t % 2 else 0.0) for t in range(n + 1)]
    tapered_tube(trunk, pts, radii, sides=6)
    part(trunk, "trunk", "bark")
    crown = pts[-1]
    fronds = new_bm()
    count = 9
    for k in range(count):
        a = 2 * math.pi * k / count + rng.uniform(-0.15, 0.15)
        d = Vector((math.cos(a), math.sin(a), 0))
        side = Vector((-d.y, d.x, 0))
        length = height * rng.uniform(0.32, 0.42)
        segs = 5
        left, right, spine = [], [], []
        for i in range(segs + 1):
            t = i / segs
            droop = (t * t) * length * 0.7 - t * length * 0.25
            p = crown + d * (t * length) - Vector((0, 0, droop))
            w = math.sin(min(t * 1.2, 1.0) * math.pi) * length * 0.16 + 0.05
            spine.append(p + Vector((0, 0, 0.05)))
            left.append(p + side * w - Vector((0, 0, w * 0.35)))
            right.append(p - side * w - Vector((0, 0, w * 0.35)))
        for i in range(segs):
            for row_a, row_b in ((left, spine), (spine, right)):
                face2(fronds, (row_a[i], row_a[i + 1], row_b[i + 1], row_b[i]))
    # Coconuts.
    for k in range(3):
        a = k * 2.1
        blob(fronds, crown + Vector((math.cos(a) * 0.35, math.sin(a) * 0.35, -0.35)), (0.22, 0.22, 0.25), rng, subdiv=1, wobble=0.05)
    part(fronds, "fronds", "leaves")
    export(name)


def bush(name, seed, size):
    rng = random.Random(seed)
    bm = new_bm()
    for i in range(rng.randint(3, 5)):
        c = Vector((rng.uniform(-0.5, 0.5) * size, rng.uniform(-0.5, 0.5) * size, size * rng.uniform(0.25, 0.45)))
        s = size * rng.uniform(0.45, 0.65)
        blob(bm, c, (s, s, s * 0.8), rng, seed=seed + i)
    part(bm, "leaves", "leaves")
    export(name)


def fern(name, seed):
    """Low ground fern: a rosette of arched leaf blades."""
    rng = random.Random(seed)
    bm = new_bm()
    for k in range(7):
        a = 2 * math.pi * k / 7 + rng.uniform(-0.2, 0.2)
        d = Vector((math.cos(a), math.sin(a), 0))
        side = Vector((-d.y, d.x, 0))
        length = rng.uniform(0.9, 1.3)
        pts = []
        for i in range(5):
            t = i / 4
            p = d * t * length + Vector((0, 0, math.sin(t * math.pi * 0.8) * 0.5))
            w = math.sin(t * math.pi) * 0.18 + 0.02
            pts.append((p + side * w, p - side * w))
        for i in range(4):
            a1, b1 = pts[i]
            a2, b2 = pts[i + 1]
            face2(bm, (a1, a2, b2, b1))
    part(bm, "fern", "leaves")
    export(name)


def grass_tuft(name, seed):
    """A clump of tapering grass blades, double sided."""
    rng = random.Random(seed)
    bm = new_bm()
    for k in range(9):
        a = rng.uniform(0, 2 * math.pi)
        base = Vector((math.cos(a), math.sin(a), 0)) * rng.uniform(0.0, 0.25)
        lean = Vector((math.cos(a), math.sin(a), 0)) * rng.uniform(0.1, 0.35)
        h = rng.uniform(0.35, 0.65)
        side = Vector((-math.sin(a), math.cos(a), 0)) * 0.05
        face2(bm, (base - side, base + side, base + lean + Vector((0, 0, h))))
    part(bm, "blades", "grass_blade")
    export(name)


def rock(name, seed, size):
    rng = random.Random(seed)
    bm = new_bm()
    verts = blob(bm, (0, 0, size[2] * 0.35), size, rng, subdiv=1, wobble=0.3, seed=seed)
    # Flatten the bottom into the ground.
    for v in verts:
        if v.co.z < 0.0:
            v.co.z = rng.uniform(-0.15, 0.0)
    part(bm, "rock", "rock")
    export(name)


def hill(name, seed, radius, height):
    """A jungle hill for the horizon: a lumpy cone of forest with a rocky crown."""
    rng = random.Random(seed)
    bm = new_bm()
    rings, sides = 6, 14
    grid = []
    for r in range(rings + 1):
        t = r / rings
        row = []
        for k in range(sides):
            a = 2 * math.pi * k / sides
            rad = radius * (1.0 - t) * (1.0 + 0.18 * noise.noise(Vector((math.cos(a) * 2, math.sin(a) * 2, t * 3 + seed))))
            z = height * (1.0 - (1.0 - t) ** 1.6) + rng.uniform(-0.04, 0.04) * height
            row.append(bm.verts.new((math.cos(a) * rad, math.sin(a) * rad, z - height * 0.05)))
        grid.append(row)
    top = bm.verts.new((0, 0, height * 1.03))
    for r in range(rings):
        for k in range(sides):
            bm.faces.new((grid[r][k], grid[r][(k + 1) % sides], grid[r + 1][(k + 1) % sides], grid[r + 1][k]))
    for k in range(sides):
        bm.faces.new((grid[rings][k], grid[rings][(k + 1) % sides], top))
    # Split: upper rings become rock.
    rock_bm = new_bm()
    forest = new_bm()
    for src in (bm,):
        for f in src.faces:
            zc = sum(v.co.z for v in f.verts) / len(f.verts)
            target = rock_bm if zc > height * 0.72 else forest
            target.faces.new([target.verts.new(v.co) for v in f.verts])
    bm.free()
    part(forest, "slopes", "hill_forest")
    part(rock_bm, "peak", "rock")
    export(name)


# --- temple pieces -----------------------------------------------------------

def idol():
    """The precursor god: seated cross-legged on a throne, hands open on its
    knees, a flared crown, and one great eye socket in its brow. About 8.5 m
    tall from the dais; faces -Y in Blender (+Z in Godot), toward the temple door."""
    bm = new_bm()
    # Throne block with a stepped back.
    box(bm, (0, 1.6, 1.0), (7.6, 3.4, 2.0), bevel=0.12)
    box(bm, (0, 2.9, 3.0), (6.2, 1.2, 4.0), bevel=0.1)
    # Crossed legs: two tapered logs across the lap, feet tucked.
    for s in (-1, 1):
        tapered_tube(bm, [(s * 2.9, 0.1, 2.55), (s * 0.3, -0.5, 2.7), (-s * 1.6, -0.2, 2.6)], [0.75, 0.7, 0.45], sides=8)
        box(bm, (-s * 1.9, -0.25, 2.55), (0.9, 0.6, 0.45), rot_z=s * 0.4, bevel=0.06)
    # Torso: waist to shoulders, then a broad chest plate.
    tapered_tube(bm, [(0, 1.3, 2.8), (0, 1.25, 4.6), (0, 1.35, 6.2)], [1.3, 1.55, 1.9], sides=8)
    box(bm, (0, 1.3, 6.35), (4.4, 1.9, 0.6), bevel=0.15)
    # Necklace ring.
    tapered_tube(bm, [(-1.6, 0.6, 6.0), (0, 0.15, 5.4), (1.6, 0.6, 6.0)], [0.18, 0.2, 0.18], sides=5)
    # Arms: shoulder, upper arm down, forearm forward onto the knee, open hand.
    for s in (-1, 1):
        sh = Vector((s * 2.3, 1.3, 6.1))
        el = Vector((s * 2.7, 1.1, 4.0))
        wr = Vector((s * 2.4, -0.8, 3.35))
        tapered_tube(bm, [sh, el], [0.62, 0.5], sides=7)
        tapered_tube(bm, [el, wr], [0.5, 0.38], sides=7)
        box(bm, (s * 2.35, -1.25, 3.3), (0.95, 1.1, 0.22), rot_z=s * 0.15, bevel=0.05)
        for f in range(4):
            box(bm, (s * (2.0 + f * 0.22), -1.95, 3.3), (0.14, 0.45, 0.16), bevel=0.0)
        blob(bm, sh + Vector((0, 0, 0.15)), (0.75, 0.75, 0.6), random.Random(7 + s), subdiv=1, wobble=0.05)
    # Neck and head, wider at the brow than the chin.
    tapered_tube(bm, [(0, 1.3, 6.5), (0, 1.3, 7.0)], [0.75, 0.7], sides=8)
    box(bm, (0, 1.25, 8.1), (2.6, 2.2, 2.3), bevel=0.15)
    # Brow ridge, nose, mouth bar.
    box(bm, (0, 0.05, 8.75), (2.5, 0.35, 0.3), bevel=0.05)
    box(bm, (0, 0.05, 7.85), (0.45, 0.45, 0.9), bevel=0.06)
    box(bm, (0, 0.12, 7.25), (1.2, 0.2, 0.18))
    # Flared crown with spikes, and ear flaps.
    tapered_tube(bm, [(0, 1.25, 9.2), (0, 1.25, 9.95)], [1.5, 1.95], sides=8)
    for k in range(8):
        a = 2 * math.pi * k / 8 + math.pi / 8
        base = Vector((math.cos(a) * 1.8, 1.25 + math.sin(a) * 1.8, 9.9))
        tapered_tube(bm, [base, base + Vector((math.cos(a) * 0.4, math.sin(a) * 0.4, 0.9))], [0.3, 0.05], sides=4)
    for s in (-1, 1):
        box(bm, (s * 1.5, 1.3, 7.6), (0.3, 1.2, 1.9), bevel=0.06)
    part(bm, "statue", "idol")
    # The eye socket: a dark recessed plate on the brow.
    sock = new_bm()
    box(sock, (0, 0.12, 8.35), (1.5, 0.08, 0.7), bevel=0.04)
    part(sock, "socket", "gunmetal")
    marker("EyeMarker", (0, 0.04, 8.35))
    export("idol")


def tent(name, seed):
    """An A-frame canvas tent with sagging sides, a pinned-back door flap,
    poles, guy ropes and pegs. Door faces -Y in Blender (+Z in Godot is the back)."""
    rng = random.Random(seed)
    w, h, l = 3.2, 2.3, 4.2
    canvas = new_bm()
    segs_u, segs_v = 4, 5
    for s in (-1, 1):
        grid = []
        for i in range(segs_u + 1):
            u = i / segs_u  # ridge -> ground
            row = []
            for j in range(segs_v + 1):
                v = j / segs_v
                sag = math.sin(u * math.pi) * math.sin(v * math.pi) * 0.12
                x = s * (u * w * 0.5 + 0.02) - s * sag
                z = h * (1 - u) - sag * 0.5
                y = (v - 0.5) * l
                row.append(Vector((x, y, z)))
            grid.append(row)
        for i in range(segs_u):
            for j in range(segs_v):
                face2(canvas, (grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]))
    # Back wall triangle.
    y = l * 0.5
    face2(canvas, ((-w * 0.5, y, 0), (w * 0.5, y, 0), (0, y, h)))
    # Door flaps: one closed half, one pinned back.
    y = -l * 0.5
    face2(canvas, ((0, y, h), (-w * 0.5, y, 0), (-0.1, y - 0.05, 0)))
    face2(canvas, ((0, y, h), (w * 0.5 + 0.2, y - 0.5, 0.2), (w * 0.45, y - 0.15, 0.9)))
    part(canvas, "canvas", "canvas")
    # Dark interior so the open door reads.
    inside = new_bm()
    face2(inside, ((-w * 0.45, -l * 0.3, 0.02), (w * 0.45, -l * 0.3, 0.02), (0, -l * 0.3, h * 0.92)))
    box(inside, (0, 0, 0.02), (w * 0.85, l * 0.95, 0.04))
    part(inside, "inside", "shadow")
    wood = new_bm()
    tapered_tube(wood, [(0, -l * 0.5 - 0.15, 0), (0, -l * 0.5 - 0.15, h + 0.25)], [0.06, 0.05], sides=5)
    tapered_tube(wood, [(0, l * 0.5 + 0.15, 0), (0, l * 0.5 + 0.15, h + 0.25)], [0.06, 0.05], sides=5)
    tapered_tube(wood, [(0, -l * 0.5 - 0.2, h + 0.05), (0, l * 0.5 + 0.2, h + 0.05)], [0.05, 0.05], sides=5)
    # Pegs.
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(wood, (sx * (w * 0.5 + 0.9), sy * (l * 0.5 + 0.3), 0.1), (0.08, 0.08, 0.25))
    part(wood, "poles", "bark")
    rope = new_bm()
    for sy in (-1, 1):
        top = Vector((0, sy * (l * 0.5 + 0.15), h + 0.2))
        for sx in (-1, 1):
            tapered_tube(rope, [top, Vector((sx * (w * 0.5 + 0.9), sy * (l * 0.5 + 0.3), 0.15))], [0.015, 0.015], sides=3)
    part(rope, "ropes", "rope")
    export(name)


def main():
    clear()
    broad_tree("tree_a", 11, 10.0)
    broad_tree("tree_b", 23, 12.0)
    broad_tree("tree_c", 37, 8.0)
    palm("palm_a", 41, 9.0)
    palm("palm_b", 53, 11.0)
    bush("bush_a", 61, 2.0)
    bush("bush_b", 67, 2.6)
    fern("fern", 71)
    grass_tuft("grass_tuft", 73)
    rock("rock_a", 81, (1.4, 1.1, 0.9))
    rock("rock_b", 83, (2.2, 1.6, 1.2))
    rock("rock_c", 89, (0.8, 0.7, 0.6))
    hill("hill_a", 91, 60.0, 55.0)
    hill("hill_b", 97, 75.0, 40.0)
    idol()
    tent("tent", 101)


if __name__ == "__main__":
    main()
