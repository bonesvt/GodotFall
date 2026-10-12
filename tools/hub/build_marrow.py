"""Models Marrow (scripts/hub/hush_den.gd) in Blender as a shadow man and
exports him as one glTF:

    blender -b --factory-startup --python tools/hub/build_marrow.py

Writes assets/models/marrow/marrow.glb with two poses, each its own objects:
  stand__shadow / stand__eyes    in the alley: ~2.1 m, too tall and too thin,
                                 a long coat that tatters into strips at the
                                 floor, a deep hood with nothing in it but two
                                 violet eyes, long fingers, his right hand held
                                 up and cupped (the game puts his Hush ember in
                                 it at EMBER_STAND), tendrils of him running out
                                 across the floor
  sit__shadow / sit__eyes        sunk into his basement armchair (the game's own
                                 chair), legs long under the coat, right hand
                                 raised with the ember (EMBER_SIT), the left
                                 draped off the armrest
Authored Y up in Godot's space, facing -Z, his right +X, his feet at the origin;
turned Z up at the end for the glTF exporter. hush_den.gd gives "shadow" its
dissolving shadow shader and "eyes" a violet glow; no textures ship.
"""
import math
import random
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

OUT = Path(__file__).resolve().parent.parent.parent / "assets" / "models" / "marrow" / "marrow.glb"
random.seed(7)


def clear():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.curves):
        for item in list(block):
            block.remove(item)


def mat(name):
    return bpy.data.materials.get(name) or bpy.data.materials.new(name)


def active():
    return bpy.context.view_layer.objects.active


def apply_all(ob):
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    for mod in list(ob.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def skin_body(name, joints, bones):
    """A body grown from a stick figure with the skin modifier: `joints` is
    {key: (position, radius)}, `bones` pairs of keys."""
    keys = list(joints)
    me = bpy.data.meshes.new(name)
    me.from_pydata([joints[k][0] for k in keys], [(keys.index(a), keys.index(b)) for a, b in bones], [])
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    sk = ob.modifiers.new("skin", "SKIN")
    sk.use_smooth_shade = True
    for i, k in enumerate(keys):
        r = joints[k][1]
        me.skin_vertices[0].data[i].radius = (r, r)
    me.skin_vertices[0].data[keys.index("pelvis")].use_root = True
    sub = ob.modifiers.new("subd", "SUBSURF")
    sub.levels = 2
    apply_all(ob)
    return ob


def coat(name, top_y, top_r, hem_y, hem_r, centre, lean=0.0, strips=26, rings=22, open_front=0.0, collar=False):
    """A long coat: a flaring tube from the shoulders to a hem torn into
    strips; with `collar`, closing in over the shoulders to a high collar."""
    bm = bmesh.new()
    seg = 48
    grid = []
    profile = []
    if collar:  # high collar, then the slope of the shoulders
        profile = [(top_y + 0.17, 0.085), (top_y + 0.1, 0.09), (top_y + 0.04, top_r * 0.8), (top_y, top_r)]
    for j in range(rings + 1):
        u = j / rings
        profile.append((top_y + (hem_y - top_y) * u, top_r + (hem_r - top_r) * (u ** 1.4)))
    rings = len(profile) - 1
    for j, (y, r) in enumerate(profile):
        u = j / rings
        row = []
        for i in range(seg):
            a = math.tau * i / seg
            rr = r * (1.0 + 0.05 * math.sin(a * 5 + u * 7))
            x = math.cos(a) * rr
            z = math.sin(a) * rr * 0.8 + lean * u
            row.append(bm.verts.new((centre.x + x, y, centre.z + z)))
        grid.append(row)
    for j in range(rings):
        for i in range(seg):
            k = (i + 1) % seg
            bm.faces.new((grid[j][i], grid[j][k], grid[j + 1][k], grid[j + 1][i]))
    # tear the hem into strips: every other column runs on, longer and ragged
    last = grid[-1]
    for i in range(seg):
        k = (i + 1) % seg
        if (i // 2) % 2 == 0:
            length = random.uniform(0.08, 0.3)
            a0, a1 = last[i].co.copy(), last[k].co.copy()
            out = Vector((a0.x - centre.x, 0, a0.z - centre.z)).normalized() * length * 0.6
            v0 = bm.verts.new(a0 + Vector((0, -length * 0.25, 0)) + out)
            v1 = bm.verts.new(a1 + Vector((0, -length * 0.25, 0)) + out * 1.1)
            bm.faces.new((last[i], last[k], v1, v0))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    so = ob.modifiers.new("solid", "SOLIDIFY")
    so.thickness = 0.012
    sub = ob.modifiers.new("subd", "SUBSURF")
    sub.levels = 1
    apply_all(ob)
    # flatten anything under the floor onto it, so the strips lie along it
    for v in ob.data.vertices:
        v.co.z = max(v.co.z, 0.004) if False else v.co.z
    return ob


def hood(name, head, size=0.17):
    """A deep cowl round `head`, open at the front onto nothing."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=40, ring_count=24, radius=size, location=head)
    ob = active()
    ob.scale = (1.0, 1.28, 1.2)
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=True)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    cut = [v for v in bm.verts if (v.co.z - head.z) < -size * 0.45 and abs(v.co.y - head.y + 0.02) < size * 0.9]
    bmesh.ops.delete(bm, geom=cut, context="VERTS")
    # the point at the back of the hood, falling to the shoulders
    for v in bm.verts:
        if v.co.z - head.z > size * 0.6 and v.co.y > head.y:
            v.co.z += 0.05 * (v.co.y - head.y) / size
            v.co.y += 0.03
    bm.to_mesh(ob.data)
    bm.free()
    so = ob.modifiers.new("solid", "SOLIDIFY")
    so.thickness = 0.018
    sub = ob.modifiers.new("subd", "SUBSURF")
    sub.levels = 1
    apply_all(ob)
    return ob


def tendril(name, start, direction, length, r0=0.035):
    """A shadow tendril running out over the floor from `start`, thinning."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    sp = cu.splines.new("NURBS")
    n = 7
    sp.points.add(n - 1)
    d = Vector(direction).normalized()
    side = Vector((-d.z, 0, d.x))
    for i in range(n):
        u = i / (n - 1)
        p = Vector(start) + d * length * u + side * math.sin(u * 5.0 + random.random() * 3) * 0.08 * u
        p.y = max(0.01, start[1] * (1 - u) ** 2 + 0.008)
        sp.points[i].co = (p.x, p.y, p.z, 1.0)
        sp.points[i].radius = (1.0 - u) * 0.9 + 0.1
    sp.use_endpoint_u = True
    sp.order_u = 4
    cu.bevel_depth = r0
    cu.bevel_resolution = 3
    ob = bpy.data.objects.new(name, cu)
    bpy.context.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.ops.object.convert(target="MESH")
    return active()


def fingers(joints, bones, side, wrist, direction, length=0.13, spread=0.022, curl=0.0, r=0.009):
    """Four long fingers and a thumb out of `wrist`, `curl` bending them in."""
    d = Vector(direction).normalized()
    across = d.cross(Vector((0, 1, 0)))
    if across.length < 0.1:
        across = Vector((1, 0, 0))
    across.normalize()
    up = across.cross(d).normalized()
    for i in range(5):
        off = (i - 1.5) * spread if i < 4 else -2.5 * spread
        base = Vector(wrist) + d * 0.04 + across * off
        ln = length * (0.6 if i == 4 else (1.0 - abs(i - 1.5) * 0.08))
        mid = base + d * ln * 0.5 + up * curl * ln * 0.3
        tip = base + d * ln * (1.0 - curl * 0.4) + up * curl * ln * 0.9
        k = f"{side}f{i}"
        joints[k + "a"] = (base, r)
        joints[k + "b"] = (mid, r * 0.85)
        joints[k + "c"] = (tip, r * 0.5)
        bones += [(f"{side}wrist", k + "a"), (k + "a", k + "b"), (k + "b", k + "c")]


def eyes(name, head):
    objs = []
    for s in (-1.0, 1.0):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=0.012,
                                             location=head + Vector((0.034 * s, 0.0, -0.1)))
        ob = active()
        ob.scale = (1.6, 0.6, 0.5)
        ob.rotation_euler = (0, 0, math.radians(-12 * s))
        apply_all(ob)
        objs.append(ob)
    return join(objs, name)


def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objs:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    ob = active()
    ob.name = name
    ob.data.name = name
    ob.data.materials.clear()
    ob.data.materials.append(mat(name.split("__")[1]))
    bpy.ops.object.shade_smooth()
    return ob


def standing():
    head = Vector((0, 1.9, -0.02))
    j = {
        "pelvis": (Vector((0, 1.02, 0)), 0.11), "belly": (Vector((0, 1.24, 0.0)), 0.1),
        "chest": (Vector((0, 1.5, 0.02)), 0.14), "neck": (Vector((0, 1.74, 0.0)), 0.045),
        "head": (head, 0.085),
        "Lhip": (Vector((-0.08, 1.0, 0)), 0.08), "Lknee": (Vector((-0.09, 0.53, -0.02)), 0.05), "Lankle": (Vector((-0.09, 0.08, 0.0)), 0.035), "Ltoe": (Vector((-0.1, 0.03, -0.16)), 0.025),
        "Rhip": (Vector((0.08, 1.0, 0)), 0.08), "Rknee": (Vector((0.09, 0.53, -0.02)), 0.05), "Rankle": (Vector((0.09, 0.08, 0.0)), 0.035), "Rtoe": (Vector((0.1, 0.03, -0.16)), 0.025),
        "Lshoulder": (Vector((-0.19, 1.64, 0.01)), 0.075), "Lelbow": (Vector((-0.25, 1.26, 0.04)), 0.06), "Lwrist": (Vector((-0.28, 0.9, 0.02)), 0.05),
        "Rshoulder": (Vector((0.19, 1.64, 0.01)), 0.075), "Relbow": (Vector((0.29, 1.27, 0.02)), 0.06), "Rwrist": (Vector((0.25, 1.06, -0.13)), 0.05),
    }
    b = [("pelvis", "belly"), ("belly", "chest"), ("chest", "neck"), ("neck", "head"),
         ("pelvis", "Lhip"), ("Lhip", "Lknee"), ("Lknee", "Lankle"), ("Lankle", "Ltoe"),
         ("pelvis", "Rhip"), ("Rhip", "Rknee"), ("Rknee", "Rankle"), ("Rankle", "Rtoe"),
         ("chest", "Lshoulder"), ("Lshoulder", "Lelbow"), ("Lelbow", "Lwrist"),
         ("chest", "Rshoulder"), ("Rshoulder", "Relbow"), ("Relbow", "Rwrist")]
    fingers(j, b, "L", j["Lwrist"][0], (0, -1, -0.05), length=0.17, curl=0.15)
    fingers(j, b, "R", j["Rwrist"][0], (-0.1, 0.25, -1), length=0.12, curl=0.8)
    parts = [skin_body("stand_body", j, b)]
    parts.append(coat("stand_coat", 1.6, 0.23, 0.03, 0.46, Vector((0, 0, 0.02)), lean=0.06, collar=True))
    parts.append(hood("stand_hood", head))
    for i in range(7):
        a = math.radians(-60 + i * 55 + random.uniform(-15, 15))
        start = (math.cos(a) * 0.4, 0.03, math.sin(a) * 0.35)
        parts.append(tendril(f"st{i}", start, (math.cos(a), 0, math.sin(a)), random.uniform(0.5, 1.1)))
    join(parts, "stand__shadow")
    eyes("stand__eyes", head)


def sitting():
    head = Vector((0, 1.43, 0.06))
    seat = 0.46
    j = {
        "pelvis": (Vector((0, seat + 0.1, 0.08)), 0.11), "belly": (Vector((0, seat + 0.3, 0.1)), 0.1),
        "chest": (Vector((0, seat + 0.58, 0.12)), 0.14), "neck": (Vector((0, seat + 0.82, 0.1)), 0.045),
        "head": (head, 0.085),
        "Lhip": (Vector((-0.09, seat + 0.08, 0.06)), 0.08), "Lknee": (Vector((-0.13, seat + 0.12, -0.42)), 0.05), "Lankle": (Vector((-0.13, 0.08, -0.5)), 0.035), "Ltoe": (Vector((-0.14, 0.03, -0.66)), 0.025),
        "Rhip": (Vector((0.09, seat + 0.08, 0.06)), 0.08), "Rknee": (Vector((0.15, seat + 0.14, -0.42)), 0.05), "Rankle": (Vector((0.2, 0.08, -0.56)), 0.035), "Rtoe": (Vector((0.22, 0.03, -0.72)), 0.025),
        "Lshoulder": (Vector((-0.19, seat + 0.72, 0.12)), 0.075), "Lelbow": (Vector((-0.3, seat + 0.42, 0.1)), 0.06), "Lwrist": (Vector((-0.33, seat + 0.24, -0.16)), 0.05),
        "Rshoulder": (Vector((0.19, seat + 0.72, 0.12)), 0.075), "Relbow": (Vector((0.3, seat + 0.38, 0.05)), 0.06), "Rwrist": (Vector((0.25, seat + 0.47, -0.13)), 0.05),
    }
    b = [("pelvis", "belly"), ("belly", "chest"), ("chest", "neck"), ("neck", "head"),
         ("pelvis", "Lhip"), ("Lhip", "Lknee"), ("Lknee", "Lankle"), ("Lankle", "Ltoe"),
         ("pelvis", "Rhip"), ("Rhip", "Rknee"), ("Rknee", "Rankle"), ("Rankle", "Rtoe"),
         ("chest", "Lshoulder"), ("Lshoulder", "Lelbow"), ("Lelbow", "Lwrist"),
         ("chest", "Rshoulder"), ("Rshoulder", "Relbow"), ("Relbow", "Rwrist")]
    fingers(j, b, "L", j["Lwrist"][0], (-0.05, -0.9, -0.4), length=0.17, curl=0.2)
    fingers(j, b, "R", j["Rwrist"][0], (-0.1, 0.25, -1), length=0.12, curl=0.8)
    parts = [skin_body("sit_body", j, b)]
    # the coat over his shoulders down to the seat, and its skirts over his
    # knees falling to the floor in front
    parts.append(coat("sit_coat", seat + 0.7, 0.23, seat + 0.02, 0.32, Vector((0, 0, 0.12)), strips=0, rings=10, collar=True))
    lap = coat("sit_lap", seat + 0.16, 0.2, 0.03, 0.34, Vector((0, 0, -0.34)), lean=-0.1, rings=14)
    lap.scale = (1.0, 1.0, 0.7)
    apply_all(lap)
    parts.append(lap)
    parts.append(hood("sit_hood", head))
    for i in range(5):
        a = math.radians(-150 + i * 30 + random.uniform(-10, 10))
        start = (math.cos(a) * 0.3, 0.03, -0.4 + math.sin(a) * 0.25)
        parts.append(tendril(f"sl{i}", start, (math.cos(a), 0, math.sin(a)), random.uniform(0.4, 0.9)))
    join(parts, "sit__shadow")
    eyes("sit__eyes", head)


def turn_z_up():
    for ob in bpy.data.objects:
        ob.matrix_world = Matrix.Rotation(math.pi / 2, 4, "X") @ ob.matrix_world
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def main():
    clear()
    standing()
    sitting()
    turn_z_up()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(OUT), export_format="GLB", use_selection=False,
                              export_apply=True, export_yup=True, export_materials="PLACEHOLDER")
    print("wrote", OUT, [ob.name for ob in bpy.data.objects], sum(len(ob.data.polygons) for ob in bpy.data.objects))


main()
