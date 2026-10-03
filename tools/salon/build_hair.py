"""Builds the hair salon's haircuts (scripts/hub/hair.gd) for Eco and her romance
options, from the same VRoid preset their models are built from (the "anime fox
girl", preset/anime-fox-girl-preset.zip -> Untitled.glb). Run through Blender 4:

    blender -b --factory-startup -P tools/salon/build_hair.py -- <Untitled.glb> <repo root> <eco|ophelia> [--check <character glb>]

Each haircut is the preset's hair cut and restyled, then sized and posed
exactly as tools/eco/build_eco_vroid.py (Eco) or tools/npc/build_npc.py
(Ophelia) size the character, so it sits on their head. Every haircut is
written on its own as assets/models/hair/<who>_<style>.glb: the character's
armature and one mesh, "Hair", skinned to the same bones (the head and the
J_Sec_Hair* spring bones), so the game can swap it onto the character's own
skeleton by bone name. The character's built-in hair is their default style;
it is rebuilt here too (not exported) so --check can compare it with the
character's glb and prove the haircuts line up.

Haircuts (the preset has a shoulder-length layered cut, a fringe and two long
braids down the back; its rest space faces -Y, her left is +X):
- pixie: cropped short all round, ends flicked in, the fringe short
- shoulder: the preset's layers kept to the shoulders, braids gone
- braids: the shoulder layers and both long braids
- ponytail: everything pulled back tight to a braided tail from the crown
- undercut: her left side buzzed (the scalp shell shows, dyed), the right a bob
Each character keeps their own fringe and colour (Ophelia's falls over her right
eye with its violet streak). The materials are named after the character's
hair materials (eco_v_hair*, npc_ophelia_hair*); hair.gd gives each surface the
material of the character's own hair with the same name.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Quaternion, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, ROOT, WHO = argv[0], argv[1], argv[2]
CHECK = argv[argv.index("--check") + 1] if "--check" in argv else None
OUT = os.path.join(ROOT, "assets", "models", "hair")

# Eco's builder: every helper, without running it (as tools/npc/build_npc.py does).
_eco_path = os.path.join(ROOT, "tools", "eco", "build_eco_vroid.py")
_src = open(_eco_path).read()
_src = _src[:_src.rindex("\nmain()")]
_saved = sys.argv
sys.argv = ["blender", "--", SRC, ROOT]
E = {"__name__": "eco_vroid"}
exec(compile(_src, _eco_path, "exec"), E)
sys.argv = _saved
smooth, islands, new_mat = E["smooth"], E["islands"], E["new_mat"]

# height, head scale and leg scale of each character (as their builders size them)
SIZE = {"eco": (1.69, 0.95, 1.03), "ophelia": (1.62, 0.96, 1.03)}[WHO]
STYLES = ["pixie", "shoulder", "braids", "ponytail", "undercut"]
DEFAULT = {"eco": "bob", "ophelia": "choppy"}[WHO]
# material slot -> game material name (slot 2 was the fox ears; 3 is Ophelia's streak)
MATS = {"eco": {0: "eco_v_hair", 1: "eco_v_hair_fringe"},
        "ophelia": {0: "npc_ophelia_hair", 1: "npc_ophelia_hair_fringe", 3: "npc_ophelia_hair_streak"}}[WHO]


# --- mesh helpers ----------------------------------------------------------------------

def drop_islands(ob, dead_fn):
    """Delete every loose piece of hair for which dead_fn(list of vertex positions) is true."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    dead = [f for comp in islands(bm) if dead_fn([v.co for f in comp for v in f.verts]) for f in comp]
    bmesh.ops.delete(bm, geom=list(set(dead)), context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()


def drop_faces(ob, dead_fn):
    """Delete faces for which dead_fn(centre, material index) is true."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    dead = [f for f in bm.faces if dead_fn(f.calc_center_median(), f.material_index)]
    bmesh.ops.delete(bm, geom=dead, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()


def mat_of_verts(ob):
    out = {}
    for p in ob.data.polygons:
        for v in p.vertices:
            out[v] = min(out.get(v, 9), p.material_index)
    return out


def move(ob, fn):
    """fn(index, co, material) -> new co, for the mesh and any shape keys."""
    me = ob.data
    mats = mat_of_verts(ob)
    base = [v.co.copy() for v in me.vertices]
    new = [fn(i, p.copy(), mats.get(i, 0)) for i, p in enumerate(base)]
    if me.shape_keys:
        for kb in me.shape_keys.key_blocks:
            for i in range(len(base)):
                kb.data[i].co = kb.data[i].co + (new[i] - base[i])
    for v, p in zip(me.vertices, new):
        v.co = p


def fold(ob, rules, skip=()):
    """Fold every point below its cut height up into a soft end, as Eco's bob
    does (build_eco_vroid.py short_hair). rules(p, material) -> (cut z, end
    length, tuck); a cut below the hair leaves it alone, as does skip (indices)."""
    def f(i, p, m):
        if i in skip:
            return p
        z0, L, tuck = rules(p, m)
        d = z0 - p.z
        if d <= 0:
            return p
        w = smooth(z0, z0 - 0.12, p.z) * tuck
        return Vector((p.x * (1 - w), 0.02 + (p.y - 0.02) * (1 - w), z0 - L * (1 - math.exp(-d / L))))
    move(ob, f)


def braid(vs):
    """The braids are chains of small pieces hanging below the shoulder layers."""
    return max(v.z for v in vs) < 1.215


# --- each character's fringe -----------------------------------------------------------

def fringe_rules(p):
    """The fringe's cut (z0, end, tuck): Eco's swept off her eyes, longer over
    her right; Ophelia's left long over her right eye (stretched by
    ophelia_fringe) and short on her left."""
    if WHO == "eco":
        return 1.335 - 0.026 * smooth(0.005, -0.04, p.x), 0.035, 0.0
    if p.x < -0.004:
        return -1.0, 0.02, 0.0
    return 1.33, 0.03, 0.0


def ophelia_fringe(ob):
    """Her right side of the fringe falls over the eye; a violet streak through it
    (build_npc.py hair_ophelia)."""
    me = ob.data
    fringe = {v for p in me.polygons if p.material_index == 1 for v in p.vertices}

    def long_side(i, p, m):
        if i not in fringe:
            return p
        w = smooth(-0.002, -0.014, p.x)
        top = 1.40
        z = top - (top - p.z) * (1 + 0.3 * w)
        if z < 1.268:
            z = 1.268 - (1.268 - z) * 0.3
        return Vector((p.x, p.y - 0.009 * w * smooth(1.32, 1.27, z), z))
    move(ob, long_side)
    while len(me.materials) < 4:
        me.materials.append(me.materials[1])
    for p in me.polygons:
        if p.material_index == 1 and -0.032 < p.center.x < -0.012:
            p.material_index = 3


def finish_fringe(ob):
    if WHO == "ophelia":
        ophelia_fringe(ob)


# --- the haircuts ----------------------------------------------------------------------

def style_default(ob):
    """The character's own hair (Eco's bob, Ophelia's choppy jaw-length cut)."""
    drop_islands(ob, lambda vs: max(v.z for v in vs) < 1.22)

    def rules(p, m):
        if m == 1:
            return fringe_rules(p)
        if WHO == "eco":
            return 1.25, 0.035, 0.15
        jag = 0.012 * math.sin(math.atan2(p.y - 0.02, p.x) * 9.0)
        return 1.215 + jag, 0.035, 0.12
    fold(ob, rules)
    finish_fringe(ob)


def style_pixie(ob):
    """Cropped short all round: the back and sides folded up above the ears and
    tucked in to the head, the fringe cut to the brow."""
    drop_islands(ob, lambda vs: max(v.z for v in vs) < 1.22)

    def rules(p, m):
        if m == 1:
            if WHO == "ophelia" and p.x < -0.004:
                return 1.30, 0.025, 0.0   # her long side still dips over the eye, just shorter
            return 1.35, 0.02, 0.0
        # shortest at the nape, a little longer over the crown and the sides
        back = smooth(0.0, 0.08, p.y)
        return 1.305 + 0.015 * back, 0.022, 0.45
    fold(ob, rules)
    if WHO == "ophelia":
        ophelia_fringe(ob)


def style_shoulder(ob):
    """The preset's layers left to fall to the shoulders, braids taken out."""
    drop_islands(ob, braid)

    def rules(p, m):
        if m == 1:
            return fringe_rules(p)
        if WHO == "ophelia":   # ragged ends
            return 1.15 + 0.012 * math.sin(math.atan2(p.y - 0.02, p.x) * 9.0), 0.03, 0.0
        return -1.0, 0.03, 0.0
    fold(ob, rules)
    finish_fringe(ob)


def style_braids(ob):
    """The shoulder layers and both long braids down her back."""
    fold(ob, lambda p, m: fringe_rules(p) if m == 1 else (-1.0, 0.03, 0.0))
    finish_fringe(ob)


# where the ponytail is tied: high on the back of the head (preset rest space)
TIE = Vector((0.0, 0.112, 1.345))


def style_ponytail(ob):
    """Everything pulled back tight to the crown, and one braid (her left one)
    moved up to hang from the tie as a braided tail."""
    me = ob.data
    bm = bmesh.new()
    bm.from_mesh(me)
    keys = set()
    for comp in islands(bm):
        vs = [v.co for f in comp for v in f.verts]
        if braid(vs) and sum(v.x for v in vs) > 0:
            keys |= {tuple(round(x, 6) for x in c) for c in vs}
    bm.free()
    # the other braid and the stray ends go (as in the bob); the left braid is
    # found again by position
    drop_islands(ob, lambda vs: max(v.z for v in vs) < 1.22 and not (braid(vs) and sum(v.x for v in vs) > 0))
    tail = {v.index for v in me.vertices if tuple(round(x, 6) for x in v.co) in keys}
    top = max((me.vertices[i].co.copy() for i in tail), key=lambda c: c.z)
    # the braid's centre line, slice by slice down its length
    centre = {}
    for i in tail:
        c = me.vertices[i].co
        centre.setdefault(round(c.z * 100), []).append(c)
    centre = {k: (sum(c.x for c in cs) / len(cs), sum(c.y for c in cs) / len(cs)) for k, cs in centre.items()}

    def hang(i, p, m):
        """Each point keeps its place round the braid's centre line; the line
        itself now runs from the tie straight down the middle of her back,
        bowing out behind her shoulder blades."""
        if i not in tail:
            return p
        cx, cy = centre[round(p.z * 100)]
        drop = top.z - p.z
        y = TIE.y - 0.012 + 0.05 * smooth(0.0, 0.18, drop) + 0.03 * drop
        return Vector(((p.x - cx), y + (p.y - cy), TIE.z - drop))
    move(ob, hang)
    tail_weights(ob, tail)

    def rules(p, m):
        if m == 1:
            return fringe_rules(p)
        return 1.32, 0.02, 0.55   # pulled up and in toward the tie
    fold(ob, rules, skip=tail)
    finish_fringe(ob)


# the back hair chains' joints below the head, top to bottom (preset rest space)
CHAIN_STEP = 0.118


def tail_weights(ob, verts):
    """Reweight the ponytail: the head at the tie, then the back hair chains
    (J_Sec_Hair<n>_01 and _02, half each, so it swings about her middle), a level
    further down the chain for every CHAIN_STEP it hangs below the tie."""
    groups = {g.name: g for g in ob.vertex_groups}

    def group(name):
        if name not in groups:
            groups[name] = ob.vertex_groups.new(name=name)
        return groups[name]
    head = group("J_Bip_C_Head")
    for i in verts:
        v = ob.data.vertices[i]
        for g in list(v.groups):
            ob.vertex_groups[g.group].remove([i])
        drop = TIE.z - v.co.z
        h = smooth(0.03, 0.14, drop)   # how much it swings rather than following the head
        head.add([i], max(1.0 - h, 0.0), "REPLACE")
        if h <= 0.0:
            continue
        t = min(max(drop / CHAIN_STEP, 1.0), 4.0)
        lv = min(int(t), 3)
        f = t - lv
        for side in ("01", "02"):
            group("J_Sec_Hair%d_%s" % (lv, side)).add([i], h * 0.5 * (1 - f), "ADD")
            if f > 0.0:
                group("J_Sec_Hair%d_%s" % (lv + 1, side)).add([i], h * 0.5 * f, "ADD")


def style_undercut(ob):
    """Her left side buzzed short (the hair cut away above the ear, so the dyed
    scalp shell on the body shows) and the right side a bob to the jaw, the
    fringe swept across to the long side."""
    drop_islands(ob, lambda vs: max(v.z for v in vs) < 1.22)
    # left of the parting (her left is +X), below the crown: buzzed
    drop_faces(ob, lambda c, m: m == 0 and c.x > 0.022 and c.z < 1.41 - 0.2 * max(0.0, c.y - 0.06))

    def rules(p, m):
        if m == 1:
            if WHO == "eco" and p.x > 0.0:   # swept across from the shaved side, kept short
                return 1.35, 0.025, 0.0
            return fringe_rules(p)
        long_side = smooth(0.04, -0.01, p.x)
        return 1.38 - (1.38 - (1.24 if WHO == "eco" else 1.215)) * long_side, 0.03, 0.15 + 0.4 * (1 - long_side)
    fold(ob, rules)
    finish_fringe(ob)


BUILD = {"default": style_default, "pixie": style_pixie, "shoulder": style_shoulder,
         "braids": style_braids, "ponytail": style_ponytail, "undercut": style_undercut}


# --- scene, sizing, export ----------------------------------------------------------

def copy_hair(src, name):
    ob = src.copy()
    ob.data = src.data.copy()
    ob.name = name
    bpy.context.scene.collection.objects.link(ob)
    return ob


def size_like_character(arm, hairs):
    """The character builders' proportions() and face_forward_and_scale(): head
    scaled, legs lengthened, then turned to face +Y and scaled so the top of
    their (default) hair is at their height."""
    E["HEIGHT"], E["HEAD_SCALE"], E["LEG_SCALE"] = SIZE
    objs = [bpy.data.objects["Body"], bpy.data.objects["Face"]] + list(hairs.values())
    E["prune_bones"](arm)
    E["proportions"](arm, objs)
    dg = bpy.context.evaluated_depsgraph_get()
    top = 0.0
    for ob in (bpy.data.objects["Body"], bpy.data.objects["Face"], hairs["default"]):
        me = ob.evaluated_get(dg).to_mesh()
        top = max(top, max(v.co.z for v in me.vertices))
        ob.evaluated_get(dg).to_mesh_clear()
    k = SIZE[0] / top
    arm.rotation_mode = "QUATERNION"
    arm.rotation_quaternion = Quaternion((0, 0, 1), math.pi)
    arm.scale = (k, k, k)
    bpy.context.view_layer.update()
    for o in bpy.data.objects:
        o.select_set(o == arm or o in objs)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    print("sized by %.4f" % k)


def materials(ob):
    for i, slot in enumerate(ob.material_slots):
        name = MATS.get(i)
        if name:
            slot.material = new_mat(name)
    bpy.context.view_layer.objects.active = ob
    for o in bpy.data.objects:
        o.select_set(o == ob)
    bpy.ops.object.material_slot_remove_unused()


def bounds(vs):
    return [min(v[i] for v in vs) for i in range(3)], [max(v[i] for v in vs) for i in range(3)]


def check(default):
    """Compare the rebuilt default hair with the character's own glb's hair."""
    mine = [default.matrix_world @ v.co for v in default.data.vertices]
    bpy.ops.import_scene.gltf(filepath=CHECK)
    theirs_ob = [o for o in bpy.context.selected_objects if o.type == "MESH" and o.name.startswith("Hair")][0]
    theirs = [theirs_ob.matrix_world @ v.co for v in theirs_ob.data.vertices]
    # Blender imports glTF Y-up as Z-up; the export below goes the other way, so compare as imported
    a, b = bounds(mine), bounds(theirs)
    print("CHECK verts %d vs %d" % (len(mine), len(theirs)))
    print("CHECK mine   min %s max %s" % ([round(x, 4) for x in a[0]], [round(x, 4) for x in a[1]]))
    print("CHECK theirs min %s max %s" % ([round(x, 4) for x in b[0]], [round(x, 4) for x in b[1]]))
    err = max(abs(x - y) for x, y in zip(a[0] + a[1], b[0] + b[1]))
    print("CHECK largest bounds difference %.5f m" % err)


def main():
    os.makedirs(OUT, exist_ok=True)
    arm = E["setup_scene"]()
    E["remove_fox_parts"]()
    raw = bpy.data.objects["Hair"]
    raw.name = "HairPreset"
    hairs = {}
    for style in ["default"] + STYLES:
        ob = copy_hair(raw, "Hair_" + style)
        BUILD[style](ob)
        hairs[style] = ob
        print("%s: %d verts" % (style, len(ob.data.vertices)))
    bpy.data.objects.remove(raw)
    size_like_character(arm, hairs)
    for ob in hairs.values():
        materials(ob)
    if CHECK:
        check(hairs["default"])
    for style in STYLES:
        ob = hairs[style]
        ob.name = "Hair"
        for o in bpy.data.objects:
            o.select_set(o == arm or o == ob)
        path = os.path.join(OUT, "%s_%s.glb" % (WHO, style))
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
                                  export_animations=False, export_skins=True, export_morph=False,
                                  export_materials="EXPORT", export_image_format="NONE",
                                  export_yup=True, export_apply=False)
        ob.name = "Hair_" + style
        print("exported", path)


main()
