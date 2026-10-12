"""Models the dispensary back room's machinery (scripts/hub/fitting_scene.gd)
in Blender and exports it as one glTF:

    blender -b --factory-startup --python tools/hub/build_fitting_room.py

Writes assets/models/colony_gear/fitting_room.glb. Objects are named
"<part>__<material>" like build_colony_gear.py (materials: shell, trim, dark,
lit, chrome); fitting_scene.gd swaps in its own materials. Authored Y up in
Godot's space, each part at its own pivot:
  chair         a fitting chair, the sitter's hips over the origin, facing -Z:
                a moulded white seat and low back on a grey pedestal
  arm_mount     the arm's mount, hanging from the ceiling (origin at the ceiling)
  arm_upper     the arm's upper segment, from the mount's joint along -Y, ARM m
  arm_lower     the lower segment, from the elbow along -Y, ARM m
  arm_head      the tool head at the wrist: a white housing, a lit eye, two jaws
"""
import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

OUT = Path(__file__).resolve().parent.parent.parent / "assets" / "models" / "colony_gear" / "fitting_room.glb"
SEAT = 0.46
ARM = 1.25  # each segment, joint to joint


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


def finish(ob, part, material, bevel=0.0, segs=3, subdiv=0):
    if bevel > 0.0:
        m = ob.modifiers.new("bevel", "BEVEL")
        m.width = bevel
        m.segments = segs
        m.limit_method = "ANGLE"
        m.angle_limit = math.radians(35)
    if subdiv > 0:
        m = ob.modifiers.new("subd", "SUBSURF")
        m.levels = subdiv
    bpy.context.view_layer.objects.active = ob
    for mod in list(ob.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(40))
    ob.name = f"{part}__{material}"
    ob.data.name = ob.name
    ob.data.materials.clear()
    ob.data.materials.append(mat(material))
    return ob


def cyl(r, depth, loc, rot=(0, 0, 0), verts=40, r2=None):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc, rotation=rot)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=depth, location=loc, rotation=rot)
    return active()


def sph(r, loc, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=r, location=loc)
    ob = active()
    ob.scale = scale
    return ob


def box(size, loc, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    ob = active()
    ob.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return ob


def tor(major, minor, loc, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=40,
                                     minor_segments=12, location=loc, rotation=rot)
    return active()


AX_Y = (-math.pi / 2, 0, 0)  # a primitive's Z axis onto Y
AX_X = (0, math.pi / 2, 0)


def chair():
    # seat: a moulded pan, front edge rolled down, under the hips and thighs
    finish(box((0.5, 0.07, 0.5), (0, SEAT - 0.035, -0.12)), "chair", "shell", bevel=0.03, segs=5)
    finish(box((0.44, 0.012, 0.42), (0, SEAT + 0.001, -0.13)), "chair", "dark", bevel=0.005)
    # low back that leaves the spine clear above the waist
    finish(box((0.46, 0.3, 0.06), (0, SEAT + 0.2, 0.17), (math.radians(-6), 0, 0)), "chair", "shell", bevel=0.025, segs=5)
    finish(box((0.36, 0.012, 0.02), (0, SEAT + 0.26, 0.137), (math.radians(-6), 0, 0)), "chair", "lit", bevel=0.004)
    # pedestal: a grey column on a round foot
    finish(cyl(0.06, SEAT - 0.07, (0, (SEAT - 0.07) / 2 + 0.02, -0.08), AX_Y), "chair", "trim", bevel=0.01)
    finish(cyl(0.24, 0.035, (0, 0.0175, -0.08), AX_Y, verts=56, r2=0.21), "chair", "trim", bevel=0.008)
    finish(tor(0.225, 0.004, (0, 0.032, -0.08), (math.pi / 2, 0, 0)), "chair", "lit")
    # a support from the column to the back
    finish(box((0.06, 0.04, 0.26), (0, SEAT - 0.09, 0.05)), "chair", "trim", bevel=0.012)


def arm():
    # the mount: a round plate in the ceiling and a turret under it
    finish(cyl(0.16, 0.03, (0, -0.015, 0), AX_Y, verts=48), "arm_mount", "trim", bevel=0.008)
    finish(cyl(0.09, 0.14, (0, -0.1, 0), AX_Y, verts=40), "arm_mount", "shell", bevel=0.015)
    finish(tor(0.092, 0.004, (0, -0.06, 0), (math.pi / 2, 0, 0)), "arm_mount", "lit")
    # upper segment: a joint drum, then a tapered white beam with a dark spine
    for part, r0, r1 in (("arm_upper", 0.07, 0.055), ("arm_lower", 0.055, 0.042)):
        finish(cyl(r0 * 1.05, r0 * 1.6, (0, 0, 0), AX_X, verts=40), part, "trim", bevel=0.01)
        finish(tor(r0 * 1.06, 0.004, (r0 * 0.8, 0, 0), AX_X), part, "lit")
        finish(tor(r0 * 1.06, 0.004, (-r0 * 0.8, 0, 0), AX_X), part, "lit")
        finish(cyl(r0, ARM - 0.12, (0, -ARM / 2, 0), AX_Y, verts=32, r2=r1), part, "shell", bevel=0.01)
        finish(box((r0 * 0.5, ARM - 0.26, r0 * 0.6), (0, -ARM / 2, r0 * 0.75)), part, "dark", bevel=0.008)
        # hydraulic rod down its back
        finish(cyl(0.012, ARM - 0.3, (r0 * 0.9, -ARM / 2, -r0 * 0.4), AX_Y, verts=16), part, "chrome")
    # the head at the wrist: a joint, a white housing, a lit eye, two jaws
    finish(sph(0.05, (0, 0, 0)), "arm_head", "trim")
    finish(box((0.2, 0.08, 0.13), (0, -0.07, 0)), "arm_head", "shell", bevel=0.025, segs=4)
    finish(box((0.14, 0.01, 0.006), (0, -0.07, -0.066)), "arm_head", "lit", bevel=0.002)
    for s in (-1.0, 1.0):
        finish(box((0.018, 0.075, 0.05), (0.07 * s, -0.135, 0)), "arm_head", "trim", bevel=0.006)
        finish(box((0.008, 0.02, 0.04), (0.06 * s, -0.17, 0)), "arm_head", "dark", bevel=0.003)


def turn_z_up():
    for ob in bpy.data.objects:
        ob.matrix_world = Matrix.Rotation(math.pi / 2, 4, "X") @ ob.matrix_world
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def main():
    clear()
    chair()
    arm()
    turn_z_up()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(OUT), export_format="GLB", use_selection=False,
                              export_apply=True, export_yup=True, export_materials="PLACEHOLDER")
    print("wrote", OUT, len(bpy.data.objects), "objects")


main()
