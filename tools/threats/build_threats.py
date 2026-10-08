"""Exports the Choir and the wildlife past the border as game models, built
from the same Blender scripts as their toon concept sheets (choir.py, wild.py).
Run through Blender (one creature, or all of them):

    blender -b --factory-startup -P tools/threats/build_threats.py -- <out_dir> [name ...]

Each creature is a rigid-part puppet like the grunt: the concept model is cut
into parts (legs, head, jaw, wings...) and every part hangs on a pivot node
that scripts/threats/threat_model.gd moves. Parts tagged while building
(kit.PIVOT, see piv() in choir.py and wild.py) keep their tag; untagged pieces
and the one-piece metaball bodies are cut up by where they sit, triangle by
triangle, with the CUT function of their creature.

Meshes are named <material>__<pivot> and joined per material and pivot. The
material names are swapped for assets/materials/threats/<name>.tres on import
(assets/models/threats/threat_import.gd). Blender's -Y (the way the concept
models face) becomes the game's -Z."""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import bpy
import bmesh
from mathutils import Matrix, Vector as V

import kit

kit.GAME = True
kit.RES_MULT = 2.0
import choir  # noqa: E402  (after the game switches are set)
import wild  # noqa: E402
import colony  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:]
OUT = Path(argv[0])
ONLY = argv[1:]


def side(c):
    # Concept models face -Y; once turned round to face the game's forward,
    # their -X side is on the right.
    return "R" if c.x < 0 else "L"


def cut_hush(c):
    if c.z > 1.98:
        return "Head"
    if (c.y < -0.25 and c.z > 1.0) or c.z > 1.16 or (abs(c.x) > 0.24 and c.z > 1.0):
        return "Torso"
    if abs(c.x) < 0.07:
        return "Hips"
    return ("Knee" if c.z < 0.74 else "Leg") + side(c)


def cut_hound(c):
    if c.y > 0.85 and c.z > 0.7:
        return "Tail"
    if -1.1 < c.y < -0.2 and c.z < 0.85 and abs(c.x) > 0.13:
        return "Front" + side(c)
    if c.y < -0.6:
        return "Head"
    if c.y > 0.3 and c.z < 0.78 and abs(c.x) > 0.08:
        return "Hind" + side(c)
    return "Body"


def cut_cantor(c):
    if c.z > 1.55 or abs(c.x) > 0.5:
        return "Torso"
    if abs(c.x) < 0.12:
        return "Hips"
    return ("Knee" if c.z < 1.0 else "Leg") + side(c)


def cut_seraph(c):
    return "Body"


GB_LEGS = [(-1.3, 1.05), (0.2, 1.1), (1.75, 1.05)]


def cut_glassback(c):
    if c.y < -1.8:
        return "Head"
    if c.z < 2.0 and abs(c.x) > 0.45:
        i = min(range(3), key=lambda k: abs(c.y - GB_LEGS[k][0]))
        return "Leg%s%d" % (side(c), i + 1)
    if c.y > 2.7 and c.z < 2.7:
        return "Tail"
    return "Body"


def cut_lampjaw(c):
    if c.y > 1.25:
        return "Tail"
    return "Body"


def cut_quillcat(c):
    if c.y > 0.85 and c.z > 0.85:
        return "Tail"
    if c.z < 0.8 and abs(c.x) > 0.08:
        return ("Front" if c.y < 0 else "Hind") + side(c)
    if c.y < -0.8:
        return "Head"
    return "Body"


def cut_shepherd(c):
    if c.z > 1.88:
        return "Head"
    if c.z > 1.12 or (abs(c.x) > 0.2 and c.z > 0.9):
        return "Torso"
    if abs(c.x) < 0.06:
        return "Hips"
    return ("Knee" if c.z < 0.56 else "Leg") + side(c)


def cut_body(c):
    return "Body"


# name: (builder, cut, pivots {name: (parent, joint in concept coords)}, triangle budget)
CREATURES = {
    "hush": (lambda M: choir.hush(M), cut_hush, {
        "Hips": (None, (0, 0.02, 1.1)),
        "LegR": (None, (-0.11, 0.02, 1.1)), "LegL": (None, (0.11, 0.02, 1.1)),
        "KneeR": ("LegR", (-0.14, -0.2, 0.74)), "KneeL": ("LegL", (0.14, -0.2, 0.74)),
        "Torso": (None, (0, 0, 1.16)),
        "Head": ("Torso", (0, -0.08, 1.98)),
    }, 26000),
    "hound": (lambda M: choir.hound(M), cut_hound, {
        "Body": (None, (0, 0.15, 0.95)),
        "FrontR": ("Body", (-0.16, -0.38, 0.92)), "FrontL": ("Body", (0.16, -0.38, 0.92)),
        "HindR": ("Body", (-0.15, 0.62, 0.8)), "HindL": ("Body", (0.15, 0.62, 0.8)),
        "Head": ("Body", (0, -0.6, 0.98)),
        "Tail": ("Body", (0, 0.85, 0.88)),
    }, 22000),
    "cantor": (lambda M: choir.cantor(M), cut_cantor, {
        "Hips": (None, (0, 0.08, 1.5)),
        "LegR": (None, (-0.22, 0.08, 1.5)), "LegL": (None, (0.22, 0.08, 1.5)),
        "KneeR": ("LegR", (-0.32, -0.32, 1.0)), "KneeL": ("LegL", (0.32, -0.32, 1.0)),
        "Torso": (None, (0, 0.06, 1.6)),
    }, 34000),
    "seraph": (lambda M: choir.seraph(M), cut_seraph, {
        "Body": (None, (0, 0, 0)),
        "Ring": ("Body", (0, 0, 0)), "Ring2": ("Body", (0, 0, 0)),
        "Tail": ("Body", (0, 0, -0.25)),
    }, 9000),
    "glassback": (lambda M: wild.glassback(M), cut_glassback, dict(
        [("Body", (None, (0, 0.2, 2.6))), ("Head", ("Body", (0, -1.6, 2.8))),
         ("Tail", ("Body", (0, 2.6, 2.5)))]
        + [("Leg%s%d" % ("R" if s < 0 else "L", i + 1), ("Body", (s * x * 0.8, y, 2.4)))
           for s in (1, -1) for i, (y, x) in enumerate(GB_LEGS)]), 30000),
    "lampjaw": (lambda M: wild.lampjaw(M), cut_lampjaw, {
        "Body": (None, (0, 0, 0.4)),
        "Jaw": ("Body", (0, -0.75, 0.4)),
        "Lure": ("Body", (0, -0.6, 0.75)),
        "Tail": ("Body", (0, 1.2, 0.35)),
    }, 18000),
    "quillcat": (lambda M: wild.quillcat(M), cut_quillcat, {
        "Body": (None, (0, 0, 0.95)),
        "FrontR": ("Body", (-0.17, -0.45, 0.95)), "FrontL": ("Body", (0.17, -0.45, 0.95)),
        "HindR": ("Body", (-0.15, 0.65, 0.95)), "HindL": ("Body", (0.15, 0.65, 0.95)),
        "Head": ("Body", (0, -0.85, 0.95)),
        "Frill": ("Body", (0, -0.68, 1.02)),
        "Tail": ("Body", (0, 0.85, 0.98)),
    }, 16000),
    "picker": (lambda M: wild.picker(M, V((0, 0, 0))), cut_body, {
        "Body": (None, (0, 0, 0.1)),
    }, 2500),
    "shepherd": (lambda M: colony.shepherd(M), cut_shepherd, {
        "Hips": (None, (0, 0, 1.0)),
        "LegR": (None, (-0.11, 0, 1.0)), "LegL": (None, (0.11, 0, 1.0)),
        "KneeR": ("LegR", (-0.115, -0.02, 0.55)), "KneeL": ("LegL", (0.115, -0.02, 0.55)),
        "Torso": (None, (0, 0, 1.08)),
        "Head": ("Torso", (0, -0.01, 1.86)),
    }, 24000),
    "veilray": (lambda M: wild.veilray(M), cut_body, {
        "Body": (None, (0, 0, 0)),
        "WingR": ("Body", (-0.25, 0, 0.02)), "WingL": ("Body", (0.25, 0, 0.02)),
        "Tail": ("Body", (0, 0.8, 0)),
    }, 8000),
}
CHOIR = ("hush", "hound", "cantor", "seraph")
# turns a concept model round to face the game's forward
TURN = Matrix.Rotation(math.pi, 4, "Z")


def build(name):
    builder, cut, pivots, budget = CREATURES[name]
    kit.reset()
    if "--dry" not in sys.argv:
        sys.argv.append("--dry")  # no water plane under the lampjaw
    M = colony.mats() if name == "shepherd" else (choir.mats() if name in CHOIR else wild.mats())
    builder(M)
    bpy.context.view_layer.update()
    # Bake modifiers and metaballs into plain meshes.
    for o in list(bpy.data.objects):
        if o.type not in ("MESH", "META"):
            bpy.data.objects.remove(o)
    bpy.ops.object.select_all(action="SELECT")
    bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
    bpy.ops.object.convert(target="MESH")
    bpy.context.view_layer.update()

    # Sort every triangle into a (pivot, material) bucket, sharing vertices
    # within each source object so the parts stay smooth shaded.
    buckets = {}
    for o in [o for o in bpy.data.objects if o.type == "MESH"]:
        me = o.data
        if not me.polygons or not me.materials:
            continue
        tag = o.get("pivot")
        mw = o.matrix_world
        nm = mw.to_3x3().inverted().transposed()
        center = mw @ (sum((V(c) for c in o.bound_box), V()) / 8.0)
        whole = None if tag is None and len(me.polygons) > 2000 else (tag or cut(center))
        me.calc_loop_triangles()
        verts = [mw @ v.co for v in me.vertices]
        norms = [(nm @ v.normal).normalized() for v in me.vertices]
        for tri in me.loop_triangles:
            mat = me.materials[tri.material_index].name if me.materials[tri.material_index] else "black"
            p = whole
            if p is None:
                p = cut((verts[tri.vertices[0]] + verts[tri.vertices[1]] + verts[tri.vertices[2]]) / 3.0)
            if p not in pivots:
                p = next(iter(pivots))
            b = buckets.setdefault((p, mat), {"map": {}, "v": [], "n": [], "f": []})
            face = []
            for vi in tri.vertices:
                key = (o.name, vi)
                if key not in b["map"]:
                    b["map"][key] = len(b["v"])
                    b["v"].append(verts[vi])
                    b["n"].append(norms[vi])
                face.append(b["map"][key])
            if len(set(face)) == 3:
                b["f"].append(face)
    mats = {m.name: m for m in bpy.data.materials}
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)

    total = sum(len(b["f"]) for b in buckets.values())
    ratio = min(1.0, budget / max(total, 1))
    print(name, "triangles", total, "ratio", round(ratio, 3), flush=True)

    # Pivot nodes, turned round with the model.
    piv = {}
    for pname, (parent, pos) in pivots.items():
        e = bpy.data.objects.new(pname, None)
        bpy.context.collection.objects.link(e)
        world = TURN @ V(pos)
        if parent:
            e.parent = piv[parent]
            e.location = world - (TURN @ V(pivots[parent][1]))
        else:
            e.location = world
        piv[pname] = e
    bpy.context.view_layer.update()

    for (pname, mat), b in sorted(buckets.items()):
        origin = TURN @ V(pivots[pname][1])
        me = bpy.data.meshes.new(f"{mat}__{pname}")
        me.from_pydata([TURN @ v - origin for v in b["v"]], [], b["f"])
        me.validate()
        me.materials.append(mats[mat])
        obj = bpy.data.objects.new(f"{mat}__{pname}", me)
        bpy.context.collection.objects.link(obj)
        obj.parent = piv[pname]
        obj.matrix_parent_inverse = piv[pname].matrix_world.inverted()
        obj.matrix_world = Matrix.Translation(origin)
        bpy.ops.object.select_all(action="DESELECT")
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        if ratio < 0.98 and len(b["f"]) > 60:
            mod = obj.modifiers.new("dec", "DECIMATE")
            mod.ratio = ratio
            bpy.ops.object.modifier_apply(modifier="dec")
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.remove_doubles(threshold=0.0004)
        bpy.ops.mesh.delete_loose()
        bpy.ops.object.mode_set(mode="OBJECT")
        bpy.ops.object.shade_smooth()
    tris = sum(len(o.data.polygons) for o in bpy.data.objects if o.type == "MESH")
    print(name, "exported faces", tris, flush=True)
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / f"{name}.glb"
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", export_materials="EXPORT",
                              export_image_format="NONE", export_yup=True, export_colors=False,
                              export_animations=False)
    print("exported", path, flush=True)


for n in (ONLY or list(CREATURES)):
    build(n)
