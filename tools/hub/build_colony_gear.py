"""Models the Shepherd's gear (scripts/hub/colony_gear.gd) in Blender and
exports it as one glTF:

    blender -b --factory-startup --python tools/hub/build_colony_gear.py

Writes assets/models/colony_gear/colony_gear.glb. Every part is an object
named "<part>__<material>" (several objects may share a part); colony_gear.gd
swaps in its own material for each suffix (shell, dark, lit, chrome, steel,
lens, blink) and hangs each part's meshes on the node it already animates in
the fitting (Cup_L, Pin_R, Shell, Needle_N, EyeCup_L, Band, Speaker, ...).

Parts are authored in Godot's space (Y up, she faces -Z, her left is -X), in
either her rest model space (the "whole" parts, at absolute positions on her
head) or a part's own local frame (the moving ones, origin at their pivot), as
colony_gear.gd builds them; the whole scene is turned Z-up at the end so the
glTF exporter's Y-up conversion lands it back where Godot expects it.
Smooth shaded, bevelled, enough segments to hold up in a close-up.
"""
import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

OUT = Path(__file__).resolve().parent.parent.parent / "assets" / "models" / "colony_gear" / "colony_gear.glb"

# her landmarks in rest model space (colony_gear.gd)
EAR = Vector((0.072, 1.522, 0.012))
NOSTRIL = Vector((0.009, 1.481, -0.07))
NOSE_BRIDGE = Vector((0.0, 1.515, -0.071))
TEMPLE = Vector((0.07, 1.555, -0.035))
EYE = Vector((0.032, 1.532, -0.064))

SEG = 48  # round things


# --- helpers ----------------------------------------------------------------

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


def finish(ob, part, material, bevel=0.0, segs=3, subdiv=0, smooth=True):
    """Bevels, smooths and names `ob` "<part>__<material>"."""
    if bevel > 0.0:
        m = ob.modifiers.new("bevel", "BEVEL")
        m.width = bevel
        m.segments = segs
        m.limit_method = "ANGLE"
        m.angle_limit = math.radians(35)
    if subdiv > 0:
        m = ob.modifiers.new("subd", "SUBSURF")
        m.levels = subdiv
        m.render_levels = subdiv
    bpy.context.view_layer.objects.active = ob
    for mod in list(ob.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)
    if smooth:
        bpy.ops.object.select_all(action="DESELECT")
        ob.select_set(True)
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(40))
    ob.name = f"{part}__{material}"
    ob.data.name = ob.name
    ob.data.materials.clear()
    ob.data.materials.append(mat(material))
    return ob


def cyl(r, depth, loc, rot=(0, 0, 0), verts=SEG, r2=None):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc, rotation=rot)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=depth, location=loc, rotation=rot)
    return active()


def tube(r_out, r_in, depth, loc, rot=(0, 0, 0), verts=SEG):
    """A thick ring (a pipe section) along local Z."""
    bm = bmesh.new()
    rings = []
    for z in (-depth / 2, depth / 2):
        for r in (r_out, r_in):
            rings.append([bm.verts.new((math.cos(a) * r, math.sin(a) * r, z))
                          for a in (math.tau * i / verts for i in range(verts))])
    bo, bi, to, ti = rings
    for i in range(verts):
        j = (i + 1) % verts
        bm.faces.new((bo[i], bo[j], to[j], to[i]))      # outside
        bm.faces.new((bi[j], bi[i], ti[i], ti[j]))      # inside
        bm.faces.new((to[i], to[j], ti[j], ti[i]))      # top
        bm.faces.new((bo[j], bo[i], bi[i], bi[j]))      # bottom
    me = bpy.data.meshes.new("tube")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("tube", me)
    bpy.context.collection.objects.link(ob)
    ob.location = loc
    ob.rotation_euler = rot
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return ob


def tor(major, minor, loc, rot=(0, 0, 0), maj_seg=SEG, min_seg=16):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=maj_seg,
                                     minor_segments=min_seg, location=loc, rotation=rot)
    return active()


def sph(r, loc, scale=(1, 1, 1), seg=32):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=seg // 2, radius=r, location=loc)
    ob = active()
    ob.scale = scale
    return ob


def box(size, loc, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    ob = active()
    ob.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return ob


def path(points, radius, part, material, closed=False, profile=None):
    """A smooth tube along `points` (Godot space), round or with a flat profile (w, h)."""
    cu = bpy.data.curves.new("path", "CURVE")
    cu.dimensions = "3D"
    sp = cu.splines.new("POLY")
    sp.points.add(len(points) - 1)
    for p, v in zip(sp.points, points):
        p.co = (v[0], v[1], v[2], 1.0)
    sp.use_cyclic_u = closed
    cu.bevel_depth = radius
    cu.bevel_resolution = 6
    cu.use_fill_caps = True
    ob = bpy.data.objects.new("path", cu)
    bpy.context.collection.objects.link(ob)
    if profile is not None:
        ob.scale = (1, 1, 1)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.ops.object.convert(target="MESH")
    ob = active()
    return finish(ob, part, material)


def rot_y_to(v):
    """Euler that turns local +Z (a primitive's axis) onto direction v."""
    v = Vector(v).normalized()
    q = Vector((0, 0, 1)).rotation_difference(v)
    return q.to_euler()


AX_X = (0, math.pi / 2, 0)   # a primitive's Z axis turned onto X
AX_Y = (-math.pi / 2, 0, 0)  # ... onto Y


# --- the pieces ---------------------------------------------------------------

def headphones():
    for side, s in (("L", -1.0), ("R", 1.0)):
        c = Vector((0.088 * s, 1.505, 0.012))
        # the can: a rounded shell cup, outer face slightly domed
        finish(cyl(0.048, 0.034, c, AX_X), f"hp_cup_{side}", "shell", bevel=0.009, segs=4)
        finish(sph(0.044, c + Vector((0.012 * s, 0, 0)), scale=(0.32, 1, 1)), f"hp_cup_{side}", "shell")
        # a lit ring round the outside, inset, and a dark band round the rim
        finish(tor(0.03, 0.0032, c + Vector((0.0215 * s, 0, 0)), AX_X), f"hp_cup_{side}", "lit")
        finish(tube(0.0495, 0.046, 0.008, c + Vector((0.006 * s, 0, 0)), AX_X), f"hp_cup_{side}", "dark", bevel=0.0015)
        # soft cushion against her head
        finish(tor(0.034, 0.011, c + Vector((-0.017 * s, 0, 0)), AX_X), f"hp_cup_{side}", "dark")
        # the yoke up to the band
        finish(box((0.012, 0.03, 0.05), c + Vector((0.004 * s, 0.045, 0))), f"hp_cup_{side}", "dark", bevel=0.004)
    # the band over her head: dark core, a white top strip
    arc = [Vector((math.cos(a) * 0.098, 1.515 + math.sin(a) * 0.125, 0.012))
           for a in (math.radians(8) + (math.pi - math.radians(16)) * i / 40 for i in range(41))]
    path(arc, 0.009, "hp_band", "dark")
    arc2 = [p + Vector((0, 0.009 * math.sin(math.radians(8) + (math.pi - math.radians(16)) * i / 40), 0))
            for i, p in enumerate(arc)]
    path([Vector((p.x * 1.02, p.y + 0.004, p.z)) for p in arc2[3:-3]], 0.006, "hp_band", "shell")
    # the pin: a fine needle grown along its own +Y, a collar at its root
    finish(cyl(0.0035, 0.036, (0, 0.018, 0), AX_Y, verts=24), "pin", "lit")
    finish(cyl(0.0035, 0.008, (0, 0.04, 0), AX_Y, verts=24, r2=0.0005), "pin", "lit")
    finish(cyl(0.01, 0.006, (0, 0.003, 0), AX_Y, verts=32), "pin", "shell", bevel=0.0015)


def visor():
    # a curved wraparound slab in front of her eyes: front arc radius 0.13
    # about a point just behind her face, 84 degrees across, 0.068 tall
    centre = Vector((0, 1.533, 0.0075))
    bm = bmesh.new()
    steps = 40
    outer, inner = 0.114, 0.09
    half = math.radians(42)
    rows = []
    for r in (outer, inner):
        for y in (-0.034, 0.034):
            rows.append([bm.verts.new((centre.x + math.sin(-half + 2 * half * i / steps) * r,
                                       centre.y + y * (0.86 if r == inner else 1.0),
                                       centre.z - math.cos(-half + 2 * half * i / steps) * r))
                         for i in range(steps + 1)])
    ob_lo, ob_hi, ib_lo, ib_hi = rows
    for i in range(steps):
        bm.faces.new((ob_lo[i], ob_lo[i + 1], ob_hi[i + 1], ob_hi[i]))
        bm.faces.new((ib_lo[i + 1], ib_lo[i], ib_hi[i], ib_hi[i + 1]))
        bm.faces.new((ob_hi[i], ob_hi[i + 1], ib_hi[i + 1], ib_hi[i]))
        bm.faces.new((ob_lo[i + 1], ob_lo[i], ib_lo[i], ib_lo[i + 1]))
    for k in (0, steps):
        bm.faces.new((ob_lo[k], ob_hi[k], ib_hi[k], ib_lo[k]) if k == 0 else (ob_hi[k], ob_lo[k], ib_lo[k], ib_hi[k]))
    me = bpy.data.meshes.new("visor")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("visor", me)
    bpy.context.collection.objects.link(ob)
    finish(ob, "visor_body", "shell", bevel=0.007, segs=4)
    # the lit slit across the front
    slit = []
    for i in range(steps + 1):
        a = -half * 0.9 + 2 * half * 0.9 * i / steps
        slit.append(Vector((math.sin(a) * (outer + 0.0005), 1.535, centre.z - math.cos(a) * (outer + 0.0005))))
    path(slit, 0.0045, "visor_body", "lit")
    # side arms back to her temples
    for s in (-1.0, 1.0):
        a = Vector((math.sin(half) * 0.1 * s, 1.54, centre.z - math.cos(half) * 0.1))
        path([a, Vector((0.088 * s, 1.542, -0.035)), Vector((0.084 * s, 1.545, 0.04))], 0.0065, "visor_body", "dark")
    # an eye cup: a glass dome facing away from her eye, a dark rim on it
    finish(sph(0.0145, (0, 0, -0.002), scale=(1, 1, 0.55)), "eyecup", "lens")
    finish(tor(0.0135, 0.0022, (0, 0, 0)), "eyecup", "dark")
    finish(cyl(0.0035, 0.006, (0, 0, -0.009), verts=16), "eyecup", "dark")
    # a temple prong, grown along its +Y
    finish(cyl(0.0032, 0.026, (0, 0.013, 0), AX_Y, verts=20), "prong", "lit")
    finish(cyl(0.0032, 0.006, (0, 0.029, 0), AX_Y, verts=20, r2=0.0004), "prong", "lit")
    finish(cyl(0.008, 0.005, (0, 0.0025, 0), AX_Y, verts=24), "prong", "dark", bevel=0.001)


def bridge():
    # a saddle clip over the bridge of her nose
    arc = [NOSE_BRIDGE + Vector((math.sin(a) * 0.022, -0.001, 0.007 - math.cos(a) * 0.01))
           for a in (math.radians(-80 + 160 * i / 16) for i in range(17))]
    path(arc, 0.0045, "bridge_clip", "shell")
    finish(box((0.012, 0.009, 0.004), NOSE_BRIDGE + Vector((0, 0.002, -0.011))), "bridge_clip", "lit", bevel=0.0015)
    for s in (-1.0, 1.0):
        v = Vector((0.074 * s, 1.5, 0.045))
        # a glass vial behind her ear, capped both ends, lit inside
        finish(cyl(0.0085, 0.024, v, (math.pi / 2, 0, 0), verts=32), "bridge_vial", "lens")
        finish(cyl(0.0058, 0.02, v, (math.pi / 2, 0, 0), verts=24), "bridge_vial", "lit")
        for dz in (-0.0135, 0.0135):
            finish(cyl(0.0095, 0.004, v + Vector((0, 0, dz)), (math.pi / 2, 0, 0), verts=32), "bridge_vial", "shell", bevel=0.0012)
        # the line along her cheek to it
        a = NOSE_BRIDGE + Vector((0.022 * s, -0.004, 0.0))
        b = Vector((0.074 * s, 1.5, 0.03))
        mid = (a + b) / 2 + Vector((0.012 * s, 0.006, -0.01))
        path([a, mid, b], 0.0022, "bridge_vial", "shell")


def cuff():
    # the dose cuff: a thick white ring along X, a lit groove, a dose window
    finish(tube(0.043, 0.033, 0.05, (0, 0, 0), AX_X), "cuff_shell", "shell", bevel=0.006, segs=4)
    finish(tor(0.0435, 0.0022, (0, 0, 0), AX_X), "cuff_shell", "lit")
    finish(box((0.024, 0.006, 0.014), (0, 0.044, 0)), "cuff_shell", "dark", bevel=0.002)
    finish(box((0.018, 0.002, 0.009), (0, 0.0472, 0)), "cuff_shell", "lit", bevel=0.0007)
    for s in (-1.0, 1.0):
        finish(tor(0.0425, 0.0016, (0.023 * s, 0, 0), AX_X), "cuff_shell", "dark")
    # a needle, grown along its +Y
    finish(cyl(0.0022, 0.024, (0, 0.012, 0), AX_Y, verts=16), "needle", "lit")
    finish(cyl(0.0022, 0.006, (0, 0.027, 0), AX_Y, verts=16, r2=0.0003), "needle", "lit")
    finish(cyl(0.0045, 0.004, (0, 0.002, 0), AX_Y, verts=16), "needle", "chrome", bevel=0.0008)


def crown():
    c = Vector((0, 1.603, 0.004))
    tilt = (math.radians(-90 - 12), 0, 0)  # a ring in the horizontal plane, tipped forward 8 degrees
    ring = tube(0.113, 0.103, 0.015, c, tilt)
    finish(ring, "crown_ring", "shell", bevel=0.003, segs=3)
    finish(tor(0.1135, 0.0018, c, tilt), "crown_ring", "lit")
    # the peak at the front: a slim chevron
    bm = bmesh.new()
    pts = [(-0.018, 0.0), (0.0, 0.055), (0.018, 0.0), (0.0, 0.016)]
    for z in (-0.004, 0.004):
        for x, y in pts:
            bm.verts.new((x, y, z))
    bm.verts.ensure_lookup_table()
    v = bm.verts
    bm.faces.new((v[0], v[1], v[2], v[3]))
    bm.faces.new((v[7], v[6], v[5], v[4]))
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new((v[i], v[4 + i], v[4 + j], v[j]))
    me = bpy.data.meshes.new("peak")
    bm.to_mesh(me)
    bm.free()
    peak = bpy.data.objects.new("peak", me)
    bpy.context.collection.objects.link(peak)
    peak.location = c + Vector((0, -0.006, -0.112))
    bpy.context.view_layer.objects.active = peak
    finish(peak, "crown_ring", "shell", bevel=0.0018, segs=2)
    finish(sph(0.006, c + Vector((0, 0.02, -0.118))), "crown_ring", "lit")
    # a node: a lit bead in a small socket
    finish(sph(0.0075, (0, 0, 0)), "crown_node", "lit")
    finish(tor(0.0075, 0.0018, (0, 0, 0), (math.pi / 2, 0, 0)), "crown_node", "chrome")


def band():
    # the Processed tracker band: heavy, grey, ridged top and bottom
    finish(tube(0.06, 0.052, 0.034, (0, 0, 0), (math.pi / 2, 0, 0), verts=64), "band_body", "steel", bevel=0.004, segs=3)
    for y in (-0.0165, 0.0165):
        finish(tor(0.0595, 0.0028, (0, y, 0), (math.pi / 2, 0, 0), maj_seg=64), "band_body", "dark")
    # the seam at the back, and a flat plate at the front for the speaker
    finish(box((0.004, 0.036, 0.006), (0, 0, 0.0595)), "band_body", "dark", bevel=0.001)
    finish(box((0.044, 0.024, 0.006), (0, -0.001, -0.0595)), "band_body", "steel", bevel=0.002)
    # a bolt: a hex head
    finish(cyl(0.0055, 0.006, (0, 0, 0.003), verts=6), "band_bolt", "chrome", bevel=0.0008, smooth=False)
    finish(cyl(0.0025, 0.0015, (0, 0, 0.0065), verts=12), "band_bolt", "dark")
    # the speaker: a round grille, dark, with slots, in a chrome rim
    finish(tor(0.0105, 0.0016, (0, 0, -0.001)), "band_speaker", "chrome")
    finish(cyl(0.0102, 0.003, (0, 0, 0), verts=40), "band_speaker", "dark")
    for i in range(4):
        finish(box((0.013 - abs(i - 1.5) * 0.004, 0.0013, 0.002), (0, (i - 1.5) * 0.004, -0.0016)), "band_speaker", "chrome", bevel=0.0004)
    # the light: a small lens in a housing
    finish(box((0.009, 0.009, 0.004), (0, 0, 0.0005)), "band_light", "dark", bevel=0.0012)
    finish(sph(0.003, (0, 0, -0.0018), scale=(1, 1, 0.6)), "band_light", "blink")


def spine():
    # a vertebra plate, 0.05 across (colony_gear.gd scales it down the back)
    finish(box((0.05, 0.026, 0.02), (0, 0, 0)), "spine_seg", "shell", bevel=0.007, segs=4)
    finish(box((0.03, 0.012, 0.02), (0, 0, -0.012)), "spine_seg", "dark", bevel=0.003)
    finish(cyl(0.0095, 0.012, (0, 0, 0.009), verts=32), "spine_seg", "chrome", bevel=0.002)
    finish(sph(0.0062, (0, 0, 0.016), scale=(1, 1, 0.7)), "spine_seg", "lit")
    for s in (-1.0, 1.0):
        finish(sph(0.006, (0.024 * s, 0, -0.002)), "spine_seg", "chrome")


def turn_z_up():
    """Built Y-up (Godot); turn it Z-up so the exporter's Y-up conversion undoes it."""
    for ob in bpy.data.objects:
        ob.matrix_world = Matrix.Rotation(math.pi / 2, 4, "X") @ ob.matrix_world
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def main():
    clear()
    headphones()
    visor()
    bridge()
    cuff()
    crown()
    band()
    spine()
    turn_z_up()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(OUT), export_format="GLB", use_selection=False,
                              export_apply=True, export_yup=True, export_materials="PLACEHOLDER")
    print("wrote", OUT, len(bpy.data.objects), "objects")


main()
