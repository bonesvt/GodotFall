"""Assembles the grunt in Blender from the sculpted parts (sculpt_grunt.py):
decimates them, hangs each one on its segment pivot, bakes occlusion into the
vertex colour and exports assets/models/grunt/grunt.glb. Run through Blender:

    blender -b --factory-startup -P tools/grunt/build_grunt.py -- <parts_dir> <out.glb> [--preview <png_prefix>]

He is a rigid-part puppet: the pivots below are plain nodes in the glTF that
scripts/ps2/grunt_model.gd moves (legs swing from the hips, shins bend at
the knee, torso swaggers, head tilts back). Material names (grunt_*) are
swapped for assets/materials/grunt/*.tres on import by grunt_import.gd."""
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

argv = sys.argv[sys.argv.index("--") + 1:]
PARTS_DIR = Path(argv[0])
OUT = Path(argv[1])
PREVIEW = argv[argv.index("--preview") + 1] if "--preview" in argv else None

# segment: (parent, pivot in Blender coords). Must match the joints in sculpt_grunt.py.
SEGMENTS = {
    "Hips": (None, (0.0, 0.0, 0.9)),
    "LegR": (None, (0.125, 0.0, 0.86)),
    "LegL": (None, (-0.125, 0.0, 0.86)),
    "KneeR": ("LegR", (0.135, 0.02, 0.48)),
    "KneeL": ("LegL", (-0.135, 0.02, 0.48)),
    "Torso": (None, (0.0, 0.0, 1.0)),
    "Head": ("Torso", (0.0, 0.0, 1.47)),
}
# sculpt segment names -> pivot
SEG_OF = {"ThighR": "LegR", "ThighL": "LegL", "ShinR": "KneeR", "ShinL": "KneeL",
          "Hips": "Hips", "Torso": "Torso", "Head": "Head"}

PREVIEW_COLORS = {
    "grunt_uniform": (0.42, 0.45, 0.3), "grunt_armor": (0.3, 0.36, 0.24),
    "grunt_skin": (0.86, 0.55, 0.42), "grunt_leather": (0.36, 0.24, 0.15),
    "grunt_dark": (0.14, 0.13, 0.12), "grunt_metal": (0.35, 0.36, 0.38),
    "grunt_brass": (0.9, 0.7, 0.3), "grunt_ribbon": (0.75, 0.15, 0.15),
    "grunt_visor": (1.0, 0.75, 0.25), "grunt_cigar": (0.45, 0.3, 0.18),
    "grunt_stubble": (0.5, 0.45, 0.45), "grunt_teeth": (0.95, 0.92, 0.8),
    "grunt_glass": (0.15, 0.12, 0.1),
}
AO_SKIP = ("Visor",)


def material(name):
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name)
        c = PREVIEW_COLORS.get(name, (0.8, 0.8, 0.8))
        m.diffuse_color = (*c, 1.0)
        m.use_nodes = True
        m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*c, 1.0)
    return m


def activate(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def make_pivots():
    piv = {}
    for name, (parent, pos) in SEGMENTS.items():
        e = bpy.data.objects.new(name, None)
        e.empty_display_size = 0.05
        bpy.context.collection.objects.link(e)
        if parent:
            e.parent = piv[parent]
            e.location = Vector(pos) - Vector(SEGMENTS[parent][1])
        else:
            e.location = pos
        piv[name] = e
    return piv


def load_part(path, piv):
    data = np.load(path)
    verts, faces, target = data["verts"], data["faces"], int(data["target"])
    seg, mat = SEG_OF[str(data["segment"])], str(data["material"])
    origin = _world(seg)
    me = bpy.data.meshes.new(path.stem)
    me.from_pydata((verts - origin).tolist(), [], faces.tolist())
    me.validate()
    name = "".join(w.title() for w in path.stem.split("_"))
    obj = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(obj)
    obj.parent = piv[seg]
    activate(obj)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    if len(faces) > target:
        mod = obj.modifiers.new("dec", "DECIMATE")
        mod.ratio = target / len(faces)
        bpy.ops.object.modifier_apply(modifier="dec")
    bpy.ops.object.mode_set(mode="EDIT")  # decimation can leave strays that break export
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=0.0005)
    bpy.ops.mesh.dissolve_degenerate(threshold=0.0005)
    bpy.ops.mesh.delete_loose()
    bpy.ops.object.mode_set(mode="OBJECT")
    me.validate()
    bpy.ops.object.shade_smooth()
    me.materials.append(material(mat))
    return obj


def _world(seg):
    return np.array(SEGMENTS[seg][1], dtype=np.float64)


def bake_ao(objs, rays=24, reach=0.08, strength=0.75):
    """Occlusion per vertex from every part at once (under the helmet brim,
    pauldrons and vest, between arm and body), times a gentle darkening toward
    the feet, stored in the "Col" vertex colour (the shader's vertex_ao)."""
    bpy.context.view_layer.update()
    verts, polys, world = [], [], {}
    for o in objs:
        base = len(verts)
        mw = o.matrix_world
        wv = [mw @ v.co for v in o.data.vertices]
        world[o.name] = wv
        verts += wv
        polys += [[base + i for i in p.vertices] for p in o.data.polygons]
    tree = BVHTree.FromPolygons(verts, polys)
    rng = np.random.default_rng(1)
    u = rng.random((rays, 2))
    r, phi = np.sqrt(u[:, 0]), 2 * np.pi * u[:, 1]
    dirs = [Vector(d) for d in np.stack([r * np.cos(phi), r * np.sin(phi), np.sqrt(1 - u[:, 0])], 1)]
    for o in objs:
        me = o.data
        attr = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
        me.color_attributes.active_color = attr
        rot = o.matrix_world.to_3x3()
        for i, v in enumerate(me.vertices):
            p = world[o.name][i]
            foot = 0.72 + 0.28 * min(max(p.z / 1.1, 0.0), 1.0)
            if o.name.startswith(AO_SKIP):
                attr.data[i].color = (1, 1, 1, 1)
                continue
            n = (rot @ v.normal).normalized()
            frame = n.to_track_quat("Z", "Y").to_matrix()
            origin = p + n * 0.002
            hits = sum(1 for d in dirs if tree.ray_cast(origin, frame @ d, reach)[0] is not None)
            ao = (1.0 - strength * hits / rays) * foot
            attr.data[i].color = (ao, ao, ao, 1.0)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    piv = make_pivots()
    objs = []
    for path in sorted(PARTS_DIR.glob("*.npz")):
        obj = load_part(path, piv)
        objs.append(obj)
        print(obj.name, len(obj.data.polygons), "faces", flush=True)
    bake_ao(objs)
    print("total faces", sum(len(o.data.polygons) for o in objs))
    if PREVIEW:
        preview(piv)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(OUT), export_format="GLB", export_materials="EXPORT",
                              export_image_format="NONE", export_yup=True, export_colors=True,
                              export_animations=False)
    print("exported", OUT)


def preview(piv):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_cavity = True
    scene.render.resolution_x = 700
    scene.render.resolution_y = 1000
    scene.world = bpy.data.worlds.new("w")
    cam_data = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    shots = {
        "front": ((0, 3.6, 1.0), (0, 0, 0.95), 30),
        "q34": ((2.2, 2.9, 1.15), (0, 0, 0.95), 30),
        "side": ((3.6, 0, 1.0), (0, 0, 0.95), 30),
        "back": ((-1.2, -3.4, 1.1), (0, 0, 0.95), 30),
        "face": ((0.35, 0.95, 1.62), (0, 0.05, 1.6), 22),
    }
    for name, (loc, target, deg) in shots.items():
        cam.location = loc
        cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        cam_data.angle = math.radians(deg)
        scene.render.filepath = f"{PREVIEW}_{name}.png"
        bpy.ops.render.render(write_still=True)


main()
