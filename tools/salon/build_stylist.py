"""Builds Juno, the stylist at the Solace hair salon (scripts/hub/salon_screen.gd),
from the same VRoid preset as Eco and the hub NPCs (preset/anime-fox-girl-preset.zip
-> Untitled.glb). Run through Blender 4:

    blender -b --factory-startup -P tools/salon/build_stylist.py -- <Untitled.glb> <repo root>

Juno is the preset nearly as it came: she keeps its corset, shorts, stockings and
boots, and its long pastel hair (a stylist wears her own best work), with the
fox ears and tail taken off and the fringe lifted off her eyes. She gets a
confident hand-on-hip stance and the hub NPCs' idle and talk loops
(tools/npc/build_npc.py make_actions).

Writes assets/models/npc/stylist.glb and assets/textures/npc/stylist/*.png;
assets/models/npc/npc_import.gd gives every npc_stylist_<part> material the hub
NPCs' toon shading and its texture, so she is spawned like them (hub_npc.gd).
"""
import math
import os
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, ROOT = argv[0], argv[1]

# The hub NPC builder's helpers (and through it Eco's), without running it. It
# needs one of its own characters to load; its size and colours are replaced below.
_npc_path = os.path.join(ROOT, "tools", "npc", "build_npc.py")
_src = open(_npc_path).read()
_src = _src[:_src.rindex("\nmain()")]
_saved = sys.argv
sys.argv = ["blender", "--", SRC, ROOT, "mom", "--no-export"]
N = {"__name__": "build_npc"}
exec(compile(_src, _npc_path, "exec"), N)
sys.argv = _saved
E = N["E"]
WHO = "stylist"
TEX_OUT = os.path.join(ROOT, "assets", "textures", "npc", WHO)
GLB_OUT = os.path.join(ROOT, "assets", "models", "npc", WHO + ".glb")
E["TEX_OUT"] = TEX_OUT
N["TEX_OUT"] = TEX_OUT
N["WHO"] = WHO
X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)
read_px, write_png, mat_index, delete_faces = E["read_px"], E["write_png"], E["mat_index"], E["delete_faces"]

HEIGHT, HEAD, LEGS = 1.65, 0.96, 1.03

# the preset's materials -> her parts (npc_stylist_<part>; npc_import.gd shades
# unknown parts like her skin)
PARTS = [
    ("Face_00_SKIN", "face"), ("FaceBrow", "brow"), ("FaceEyeline", "eyeline"), ("FaceEyelash", "lash"),
    ("FaceMouth", "mouth"), ("EyeIris", "iris"), ("EyeHighlight", "eye_glint"), ("EyeWhite", "eye_white"),
    ("HAIR_01", "hair"), ("HAIR_02", "hair_fringe"), ("Body_00_SKIN", "body"), ("HairBack", "hair_cap"),
    ("Shoes", "boots"), ("Bottoms_01_CLOTH_01", "shorts"), ("Bottoms_01_CLOTH_02", "shorts_trim"),
    ("Bottoms_01_CLOTH (", "belt"), ("Tops_01_CLOTH_01", "corset"), ("Tops_01_CLOTH_02", "corset_frill"),
    ("Onepiece_00_CLOTH_01", "dress"), ("Onepiece_00_CLOTH_02", "dress_trim"), ("Onepiece_00_CLOTH_03", "dress_lace"),
]


def lift_fringe():
    """The fringe lifted off her eyes and swept to her right; the rest stays long."""
    hair = bpy.data.objects["Hair"]
    import math as _m
    me = hair.data
    mat_of = {}
    for p in me.polygons:
        for v in p.vertices:
            mat_of[v] = min(mat_of.get(v, 9), p.material_index)
    smooth = E["smooth"]

    def fold(i, p):
        if mat_of.get(i, 0) != 1:
            return p
        z0, L = 1.33 - 0.02 * smooth(0.0, -0.05, p.x), 0.03
        d = z0 - p.z
        if d <= 0:
            return p
        return p.__class__((p.x, p.y, z0 - L * (1 - _m.exp(-d / L))))
    N["move_verts"](hair, fold)


def stance():
    """Hand on her hip, weight on one leg, head up: she knows she's good."""
    p = E["base_pose"]()
    add = E["add"]
    add(p, "upperarm.L", Y, 34)
    add(p, "upperarm.L", X, -18)
    add(p, "forearm.L", X, 78)
    add(p, "forearm.L", Z, -30)
    add(p, "hand.L", Z, -20)
    add(p, "hips", Y, -6)
    add(p, "hips", Z, 4)
    add(p, "thigh.R", Z, -3)
    add(p, "thigh.L", X, 8)
    add(p, "shin.L", X, -14)
    add(p, "chest", Z, -3)
    add(p, "head", Y, 7)
    add(p, "head", X, 3)
    return p


def textures(objs):
    tex_of = E["tex_of"]
    plan = []
    for ob in objs:
        for i, m in enumerate(ob.data.materials):
            if m is None:
                continue
            part = next((p for k, p in PARTS if k in m.name), None)
            if part is None:
                continue
            img = tex_of(m)
            if img is not None:
                write_png(read_px(img), part)
            plan.append((ob, i, part))
    for ob, i, part in plan:
        ob.material_slots[i].material = N["new_mat"]("npc_%s_%s" % (WHO, part))
    for ob in objs:
        bpy.context.view_layer.objects.active = ob
        for o in bpy.data.objects:
            o.select_set(o == ob)
        bpy.ops.object.material_slot_remove_unused()


def main():
    os.makedirs(TEX_OUT, exist_ok=True)
    E["HEIGHT"], E["HEAD_SCALE"], E["LEG_SCALE"] = HEIGHT, HEAD, LEGS
    arm = E["setup_scene"]()
    E["remove_fox_parts"]()
    lift_fringe()
    objs = [bpy.data.objects[n] for n in ("Body", "Face", "Hair")]
    textures(objs)
    E["prune_bones"](arm)
    E["proportions"](arm, objs)
    E["face_forward_and_scale"](arm, objs)
    N["stance"] = stance
    N["make_actions"](arm)
    if "rest" in bpy.data.objects["Body"].data.attributes:
        bpy.data.objects["Body"].data.attributes.remove(bpy.data.objects["Body"].data.attributes["rest"])
    for o in bpy.data.objects:
        o.select_set(o == arm or o in objs)
    os.makedirs(os.path.dirname(GLB_OUT), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=GLB_OUT, export_format="GLB", use_selection=True,
                              export_animations=True, export_animation_mode="ACTIONS", export_skins=True,
                              export_morph=True, export_materials="EXPORT", export_image_format="NONE",
                              export_yup=True, export_apply=False)
    print("exported", GLB_OUT)


main()
