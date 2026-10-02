"""Assembles Eco in Blender from the sculpted parts: decimates them, adds the
eyes, UVs, the armature with skin weights and spring bones (hair, rag),
idle/walk/run/fall/crouch/slide animations, and
exports assets/models/eco/eco.glb. Run through Blender:

    blender -b --factory-startup -P tools/eco/build_eco.py -- <parts_dir> <out.glb> [--preview <png_prefix>]

Material names (eco_*) are swapped for the game's PS2 materials on import by
assets/models/eco/eco_import.gd."""
import math
import sys
from pathlib import Path

import bpy
import bmesh
import numpy as np
from mathutils import Matrix, Quaternion, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from rig import J, BONES  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:]
PARTS_DIR = Path(argv[0])
OUT = Path(argv[1])
PREVIEW = argv[argv.index("--preview") + 1] if "--preview" in argv else None
FP = "--fp" in argv

# part: (material, uv mode, bone rule)
PARTS = {
    "body": ("eco_skin", "box", "auto"),
    "head": ("eco_face", "face", "head"),
    "lashes": ("eco_lash", "box", "head"),
    "hair": ("eco_hair", "box", "hair"),
    "hand_R": ("eco_skin", "box", "arm"),
    "hand_L": ("eco_skin", "box", "arm"),
    "glove_R": ("eco_leather", "box", "arm"),
    "glove_L": ("eco_leather", "box", "arm"),
    "shirt": ("eco_shirt", "box", "auto"),
    "pants": ("eco_pants", "box", "lower"),
    "knee_pads": ("eco_leather_dark", "box", "lower"),
    "boots": ("eco_leather", "box", "auto"),
    "soles": ("eco_sole", "box", "auto"),
    "toe_caps": ("eco_metal", "box", "auto"),
    "jacket": ("eco_jacket", "box", "auto"),
    "jacket_trim": ("eco_jacket_dark", "box", "auto"),
    "bandage": ("eco_bandage", "box", "arm"),
    "belt": ("eco_leather", "box", "lower"),
    "buckle": ("eco_brass", "box", "lower"),
    "pouches": ("eco_leather", "box", "lower"),
    "straps": ("eco_leather_dark", "box", "lower"),
    "plate": ("eco_titan", "box", "auto"),
    "plate_stripe": ("eco_titan_stripe", "box", "auto"),
    "metal": ("eco_metal", "box", "lower"),
    "rag": ("eco_rag", "box", "rag"),
    "goggle_rims": ("eco_brass", "box", "head"),
    "goggle_lenses": ("eco_lens", "box", "head"),
    "goggle_strap": ("eco_leather_dark", "box", "head"),
}
# first-person arm holding the pistol (static, no rig)
FP_PARTS = {
    "fp_hand": ("eco_skin", "box", None),
    "fp_glove": ("eco_leather", "box", None),
    "fp_sleeve": ("eco_jacket_dark", "box", None),
}

PREVIEW_COLORS = {
    "eco_skin": (0.86, 0.66, 0.52), "eco_face": (0.86, 0.66, 0.52), "eco_lash": (0.1, 0.08, 0.1),
    "eco_hair": (0.95, 0.95, 1.0), "eco_leather": (0.42, 0.28, 0.18), "eco_leather_dark": (0.25, 0.18, 0.14),
    "eco_metal": (0.6, 0.62, 0.66), "eco_shirt": (0.25, 0.27, 0.32), "eco_pants": (0.55, 0.55, 0.38),
    "eco_sole": (0.12, 0.11, 0.12), "eco_jacket": (0.85, 0.45, 0.24), "eco_jacket_dark": (0.6, 0.3, 0.17),
    "eco_bandage": (0.92, 0.88, 0.78), "eco_brass": (0.85, 0.65, 0.3), "eco_titan": (0.62, 0.7, 0.8),
    "eco_titan_stripe": (1.0, 0.55, 0.2), "eco_rag": (0.8, 0.22, 0.18), "eco_lens": (0.3, 0.7, 0.75),
    "eco_eye": (0.95, 0.95, 0.95), "eco_glint": (1, 1, 1),
}


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


def load_part(name):
    data = np.load(PARTS_DIR / f"{name}.npz")
    verts, faces, target = data["verts"], data["faces"], int(data["target"])
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts.tolist(), [], faces.tolist())
    me.validate()
    obj = bpy.data.objects.new(name + "_mesh", me)  # keeps bone names (head, rag) unique
    bpy.context.collection.objects.link(obj)
    activate(obj)
    # marching cubes winds faces inward for our sign convention
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    if len(faces) > target:
        mod = obj.modifiers.new("dec", "DECIMATE")
        mod.ratio = target / len(faces)
        bpy.ops.object.modifier_apply(modifier="dec")
    bpy.ops.object.shade_smooth()
    me.materials.append(material(PARTS[name][0]))
    return obj


HEAD_PIVOT = Vector((0.0, -0.004, 1.445))
HEAD_SCALE = 1.08


def enlarge_head(obj):
    """Jak-style proportions: the head, hair and goggles a touch bigger, about the neck."""
    for v in obj.data.vertices:
        v.co = HEAD_PIVOT + (v.co - HEAD_PIVOT) * HEAD_SCALE


def hair_tip_colors(obj):
    """Vertex colour red = how far out along its lock a hair vertex is (0 at the
    scalp, 1 at 4 cm), so the hair shader sways the tips and not the roots."""
    c, r = np.array([0, -0.012, 1.566]), np.array([0.085, 0.097, 0.097])
    attr = obj.data.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    for i, v in enumerate(obj.data.vertices):
        q = (np.array(v.co[:]) - c) / r
        dist = (np.linalg.norm(q) - 1.0) * r.min()
        t = float(np.clip((dist - 0.008) / 0.04, 0.0, 1.0))
        attr.data[i].color = (t, t, t, 1.0)
    obj.data.color_attributes.active_color = attr


def box_uvs(obj):
    """UVs in metres from the dominant axis of each face (like the game's box
    projection, but baked in the rest pose so textures stick when she moves)."""
    me = obj.data
    uv = me.uv_layers.new(name="UVMap")
    for poly in me.polygons:
        n = poly.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            if ax == 2:
                u, v = co.x, co.y
            elif ax == 0:
                u, v = co.y, co.z
            else:
                u, v = co.x, co.z
            uv.data[li].uv = (u, v)


def face_uvs(obj):
    """Front projection for the painted face texture: 0.2 m wide, 0.26 m tall."""
    me = obj.data
    uv = me.uv_layers.new(name="UVMap")
    for li, loop in enumerate(me.loops):
        co = HEAD_PIVOT + (me.vertices[loop.vertex_index].co - HEAD_PIVOT) / HEAD_SCALE
        uv.data[li].uv = ((co.x + 0.1) / 0.2, (co.z - 1.42) / 0.26)


def make_eyes():
    objs = []
    for s in (1.0, -1.0):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=16, radius=0.0205,
                                             location=(s * 0.0365, 0.06, 1.553))
        eye = bpy.context.active_object
        eye.name = "eye_R" if s > 0 else "eye_L"
        eye.rotation_euler = (-math.pi / 2, 0, 0)  # +Z pole (the iris) looks forward
        eye.scale = (1.12, 1.0, 1.0)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        enlarge_head(eye)
        bpy.ops.object.shade_smooth()
        eye.data.materials.append(material("eco_eye"))
        objs.append(eye)
        # catchlight
        bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=6, radius=0.0032,
                                             location=(s * 0.0365 + 0.006, 0.0795, 1.5605))
        glint = bpy.context.active_object
        glint.name = "glint_R" if s > 0 else "glint_L"
        glint.data.materials.append(material("eco_glint"))
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        enlarge_head(glint)
        objs.append(glint)
    return objs


# --- armature and weights ------------------------------------------------------

def _head_scaled(p):
    return tuple(HEAD_PIVOT + (Vector(p) - HEAD_PIVOT) * HEAD_SCALE)


# Spring bones: animated by the game (scripts/ps2/eco_model.gd), never keyed here.
# name: (head, tail, parent), in the sculpt's (unscaled) coordinates.
SPRINGS = {
    "hair_front": ((0.0, 0.05, 1.645), (-0.02, 0.105, 1.565), "head"),
    "hair_back": ((0.0, -0.07, 1.625), (0.0, -0.115, 1.5), "head"),
    "hair_side.R": ((0.06, 0.0, 1.635), (0.105, 0.005, 1.52), "head"),
    "hair_side.L": ((-0.06, 0.0, 1.635), (-0.105, 0.005, 1.52), "head"),
    "rag": ((0.075, -0.16, 0.975), (0.075, -0.17, 0.83), "hips"),
}


def make_armature():
    arm = bpy.data.armatures.new("EcoRig")
    rig = bpy.data.objects.new("Eco", arm)
    bpy.context.collection.objects.link(rig)
    activate(rig)
    bpy.ops.object.mode_set(mode="EDIT")
    for name, h, t, parent in BONES:
        b = arm.edit_bones.new(name)
        b.head = Vector(J[h])
        b.tail = Vector(J[t])
        b.roll = 0.0
        if parent:
            b.parent = arm.edit_bones[parent]
            b.use_connect = False
    for name, (h, t, parent) in SPRINGS.items():
        b = arm.edit_bones.new(name)
        if parent == "head":
            h, t = _head_scaled(h), _head_scaled(t)
        b.head, b.tail, b.roll = Vector(h), Vector(t), 0.0
        b.parent = arm.edit_bones[parent]
        b.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


SEGMENTS = [(name, np.array(J[h]), np.array(J[t])) for name, h, t, _ in BONES]


def seg_dist(P, a, b):
    ab = b - a
    t = np.clip(((P - a) @ ab) / (ab @ ab), 0, 1)
    return np.linalg.norm(P - (a + t[:, None] * ab), axis=1)


def auto_weights(P, no_arms=False, only_arms=False):
    names = [s[0] for s in SEGMENTS]
    D = np.stack([seg_dist(P, a, b) for _, a, b in SEGMENTS], 1)
    x = P[:, 0]
    for i, n in enumerate(names):
        if n.endswith(".R"):
            D[:, i] += np.where(x < -0.03, 1.0, 0.0)
        if n.endswith(".L"):
            D[:, i] += np.where(x > 0.03, 1.0, 0.0)
        if n.startswith(("upperarm", "forearm", "hand")):
            # arms only move what hangs off the shoulder
            D[:, i] += np.where((np.abs(x) < 0.15) | ((np.abs(x) < 0.215) & (P[:, 2] < 1.0)), 0.5, 0.0)
        if only_arms and not n.startswith(("upperarm", "forearm", "hand")):
            D[:, i] += 1.0
        if no_arms and n.startswith(("upperarm", "forearm", "hand")):
            # belt gear and trousers never follow the hanging hands
            D[:, i] += np.where(P[:, 2] < 1.1, 1.0, 0.0)
        if n.startswith("thigh"):
            # the pelvis and seat stay with the hips, so raised knees don't tear them
            D[:, i] += np.clip((P[:, 2] - 0.8) / 0.12, 0, 1) * 0.07
        if n in ("head",):
            D[:, i] += np.where(P[:, 2] < 1.43, 1.0, 0.0)
    D = np.maximum(D, 0.004)
    W = 1.0 / D ** 6
    # keep the 3 strongest
    order = np.argsort(-W, 1)
    mask = np.zeros_like(W, bool)
    np.put_along_axis(mask, order[:, :3], True, 1)
    W = np.where(mask, W, 0)
    W /= W.sum(1, keepdims=True)
    return names, W


def skin(obj, rig, rule):
    me = obj.data
    P = np.array([v.co[:] for v in me.vertices])
    if rule == "head":
        names = ["head", "neck"]
        w_head = np.clip((P[:, 2] - 1.425) / 0.04, 0, 1)
        W = np.stack([w_head, 1 - w_head], 1)
    elif rule == "hair":
        # locks follow the head at the root and the spring bones toward the tips
        tip = np.array([d.color[0] for d in me.color_attributes["Col"].data])
        Q = (P - np.array(HEAD_PIVOT)) / HEAD_SCALE + np.array(HEAD_PIVOT)  # unscaled
        phi = np.degrees(np.arctan2(Q[:, 0], Q[:, 1] + 0.012))
        fringe = np.clip(1 - np.abs(phi) / 55, 0, 1) * np.clip((Q[:, 2] - 1.5) / 0.04, 0, 1)
        side_r = np.clip(1 - np.abs(phi - 95) / 55, 0, 1)
        side_l = np.clip(1 - np.abs(phi + 95) / 55, 0, 1)
        back = np.clip(1 - (180 - np.abs(phi)) / 70, 0, 1)
        R4 = np.stack([fringe, back, side_r, side_l], 1) + 1e-6
        R4 /= R4.sum(1, keepdims=True)
        follow = (tip ** 1.3) * 0.85
        names = ["head", "hair_front", "hair_back", "hair_side.R", "hair_side.L"]
        W = np.concatenate([(1 - follow)[:, None], R4 * follow[:, None]], 1)
    elif rule == "rag":
        w = np.clip((0.97 - P[:, 2]) / 0.13, 0, 1) ** 1.2
        names = ["hips", "rag"]
        W = np.stack([1 - w, w], 1)
    else:
        names, W = auto_weights(P, rule == "lower", rule == "arm")
    for i, n in enumerate(names):
        idx = np.nonzero(W[:, i] > 1e-4)[0]
        if len(idx) == 0:
            continue
        vg = obj.vertex_groups.new(name=n)
        for j in idx:
            vg.add([int(j)], float(W[j, i]), "REPLACE")
    obj.parent = rig
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = rig


# --- animation -----------------------------------------------------------------

def set_rot(pb, axis_world, deg):
    m = pb.bone.matrix_local.to_3x3()
    ax = (m.inverted() @ Vector(axis_world)).normalized()
    pb.rotation_mode = "QUATERNION"
    pb.rotation_quaternion = Quaternion(ax, math.radians(deg))


def combine(pb, rots):
    m = pb.bone.matrix_local.to_3x3()
    q = Quaternion()
    for axis_world, deg in rots:
        ax = (m.inverted() @ Vector(axis_world)).normalized()
        q = Quaternion(ax, math.radians(deg)) @ q
    pb.rotation_mode = "QUATERNION"
    pb.rotation_quaternion = q


X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)


def key_pose(rig, frame, pose):
    for pb in rig.pose.bones:
        if pb.name in SPRINGS:
            continue
        rots = pose.get(pb.name, [])
        combine(pb, rots)
        pb.keyframe_insert("rotation_quaternion", frame=frame)
    hips = rig.pose.bones["hips"]
    hips.location = Vector(pose.get("_hips_loc", (0, 0, 0)))
    hips.keyframe_insert("location", frame=frame)


def base_pose():
    """Relaxed stance: arms closer in, slight elbow bend."""
    return {
        "upperarm.R": [(Y, 9)], "upperarm.L": [(Y, -9)],
        "forearm.R": [(X, 8)], "forearm.L": [(X, 8)],
    }


def add(pose, bone, axis, deg):
    pose.setdefault(bone, []).append((axis, deg))


def make_actions(rig):
    rig.animation_data_create()
    fps = 30
    bpy.context.scene.render.fps = fps
    # idle: 4 s breathing loop with a slow look around
    idle = bpy.data.actions.new("idle")
    rig.animation_data.action = idle
    n = 120
    for f in range(0, n + 1, 6):
        t = f / n * 2 * math.pi
        p = base_pose()
        breath = math.sin(t * 2)
        add(p, "chest", X, -1.2 * breath)
        add(p, "spine", Z, 1.5 * math.sin(t))
        add(p, "neck", Z, 4 * math.sin(t))
        add(p, "head", Z, 10 * math.sin(t) + 3 * math.sin(t * 3))
        add(p, "head", X, 2.5 * math.sin(t * 2 + 1))
        add(p, "upperarm.R", X, 1.5 * math.sin(t * 2 + 0.5))
        add(p, "upperarm.L", X, -1.5 * math.sin(t * 2 + 0.5))
        add(p, "hips", Y, 1.2 * math.sin(t))
        add(p, "thigh.R", Y, -1.2 * math.sin(t))
        add(p, "thigh.L", Y, -1.2 * math.sin(t))
        p["_hips_loc"] = (0, 0.0025 * breath, 0)
        key_pose(rig, f, p)
    # walk: one stride cycle (two steps) in 32 frames, about 1.3 m
    walk = bpy.data.actions.new("walk")
    rig.animation_data.action = walk
    n = 32
    for f in range(0, n + 1, 2):
        t = f / n * 2 * math.pi
        p = base_pose()
        sw = math.sin(t)
        add(p, "thigh.R", X, 26 * sw)
        add(p, "thigh.L", X, -26 * sw)
        # knees bend while each leg swings through
        add(p, "shin.R", X, -38 * max(0.0, math.sin(t - 1.2)) - 6)
        add(p, "shin.L", X, -38 * max(0.0, math.sin(t + math.pi - 1.2)) - 6)
        add(p, "foot.R", X, 10 * math.cos(t))
        add(p, "foot.L", X, -10 * math.cos(t))
        add(p, "upperarm.R", X, -20 * sw)
        add(p, "upperarm.L", X, 20 * sw)
        add(p, "forearm.R", X, 10 + 8 * max(0.0, -sw))
        add(p, "forearm.L", X, 10 + 8 * max(0.0, sw))
        add(p, "hips", Z, 6 * sw)
        add(p, "chest", Z, -8 * sw)
        add(p, "head", Z, 2 * sw)
        add(p, "spine", X, 3)
        p["_hips_loc"] = (0, 0, 0)
        hips_drop = -0.018 * abs(math.cos(t))
        # hips local Y is world up for the upward hips bone
        p["_hips_loc"] = (0, hips_drop, 0)
        key_pose(rig, f, p)
    run = bpy.data.actions.new("run")
    rig.animation_data.action = run
    n = 22  # one stride (two steps) in 22 frames, about 4.4 m: authored at 6 m/s
    for f in range(0, n + 1, 1):
        t = f / n * 2 * math.pi
        p = base_pose()
        sw = math.sin(t)
        add(p, "thigh.R", X, 44 * sw + 6)
        add(p, "thigh.L", X, -44 * sw + 6)
        add(p, "shin.R", X, -95 * max(0.0, math.sin(t - 1.4)) - 14)
        add(p, "shin.L", X, -95 * max(0.0, math.sin(t + math.pi - 1.4)) - 14)
        add(p, "foot.R", X, 16 * math.cos(t))
        add(p, "foot.L", X, -16 * math.cos(t))
        add(p, "upperarm.R", X, -40 * sw)
        add(p, "upperarm.L", X, 40 * sw)
        add(p, "forearm.R", X, 72 + 12 * max(0.0, -sw))
        add(p, "forearm.L", X, 72 + 12 * max(0.0, sw))
        add(p, "spine", X, -9)
        add(p, "head", X, 7)
        add(p, "hips", Z, 9 * sw)
        add(p, "chest", Z, -13 * sw)
        add(p, "head", Z, 4 * sw)
        p["_hips_loc"] = (0, -0.035 + 0.03 * abs(math.sin(t)), 0)
        key_pose(rig, f, p)
    # poses held while airborne, crouched and sliding (gentle motion so they loop)
    fall = bpy.data.actions.new("fall")
    rig.animation_data.action = fall
    n = 30
    for f in range(0, n + 1, 5):
        t = f / n * 2 * math.pi
        p = base_pose()
        add(p, "thigh.R", X, 38 + 4 * math.sin(t))
        add(p, "shin.R", X, -62)
        add(p, "thigh.L", X, -8 - 4 * math.sin(t))
        add(p, "shin.L", X, -38)
        add(p, "foot.R", X, -10)
        add(p, "foot.L", X, -20)
        add(p, "upperarm.R", Y, -38 + 5 * math.sin(t))
        add(p, "upperarm.L", Y, 38 - 5 * math.sin(t))
        add(p, "upperarm.R", X, 18)
        add(p, "upperarm.L", X, -10)
        add(p, "forearm.R", X, 30)
        add(p, "forearm.L", X, 30)
        add(p, "spine", X, -6)
        add(p, "head", X, 6)
        key_pose(rig, f, p)
    crouch = bpy.data.actions.new("crouch")
    rig.animation_data.action = crouch
    n = 60
    for f in range(0, n + 1, 10):
        t = f / n * 2 * math.pi
        breath = math.sin(t)
        p = base_pose()
        for sd, sgn in (("R", 1), ("L", -1)):
            add(p, "thigh." + sd, X, 74)
            add(p, "thigh." + sd, Y, -9 * sgn)
            add(p, "shin." + sd, X, -112)
            add(p, "foot." + sd, X, 36)
        add(p, "spine", X, -26 - 1.5 * breath)
        add(p, "chest", X, -6)
        add(p, "neck", X, 14)
        add(p, "head", X, 16)
        add(p, "upperarm.R", X, 34)
        add(p, "upperarm.L", X, 26)
        add(p, "forearm.R", X, 48)
        add(p, "forearm.L", X, 54)
        p["_hips_loc"] = (0, -0.4, 0.13)
        key_pose(rig, f, p)
    slide = bpy.data.actions.new("slide")
    rig.animation_data.action = slide
    n = 30
    for f in range(0, n + 1, 5):
        t = f / n * 2 * math.pi
        p = base_pose()
        add(p, "thigh.R", X, 62)
        add(p, "shin.R", X, -18)
        add(p, "foot.R", X, -12)
        add(p, "thigh.L", X, 30)
        add(p, "thigh.L", Y, 18)
        add(p, "shin.L", X, -118)
        add(p, "foot.L", X, 20)
        add(p, "spine", X, 18 + 1.5 * math.sin(t))
        add(p, "chest", X, 6)
        add(p, "neck", X, -10)
        add(p, "head", X, -14)
        add(p, "upperarm.L", Y, 52)
        add(p, "upperarm.L", X, -16)
        add(p, "forearm.L", X, 20)
        add(p, "upperarm.R", X, 40)
        add(p, "upperarm.R", Y, -14)
        add(p, "forearm.R", X, 50)
        p["_hips_loc"] = (0, -0.5, 0.05)
        key_pose(rig, f, p)
    for act in (idle, walk, run, fall, crouch, slide):
        for fc in act.fcurves:
            for kp in fc.keyframe_points:
                kp.interpolation = "BEZIER"
    rig.animation_data.action = idle


# --- main ------------------------------------------------------------------------

def main_fp():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for name, (mat, _, _) in FP_PARTS.items():
        PARTS[name] = (mat, "box", None)
        obj = load_part(name)
        box_uvs(obj)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(OUT), export_format="GLB", export_materials="EXPORT",
                              export_image_format="NONE", export_yup=True)
    print("exported", OUT)


def main():
    if FP:
        main_fp()
        return
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rig = make_armature()
    objs = []
    for name, (mat, uvmode, rule) in PARTS.items():
        if not (PARTS_DIR / f"{name}.npz").exists():
            print("missing part", name)
            continue
        obj = load_part(name)
        if name == "hair":
            hair_tip_colors(obj)
        if rule == "head":
            enlarge_head(obj)
        (face_uvs if uvmode == "face" else box_uvs)(obj)
        skin(obj, rig, rule)
        objs.append(obj)
        print(name, len(obj.data.polygons), "faces", flush=True)
    for eye in make_eyes():
        skin(eye, rig, "head")
        objs.append(eye)
    make_actions(rig)
    total = sum(len(o.data.polygons) for o in objs)
    print("total faces", total)
    if PREVIEW:
        preview(rig)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(OUT), export_format="GLB", export_animations=True,
                              export_animation_mode="ACTIONS", export_skins=True,
                              export_materials="EXPORT", export_image_format="NONE",
                              export_yup=True, export_apply=False, export_colors=True)
    print("exported", OUT)


def preview(rig):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_cavity = True
    scene.render.resolution_x = 700
    scene.render.resolution_y = 1000
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("w")
    scene.world = world
    cam_data = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    rig.animation_data.action = bpy.data.actions["idle"]
    scene.frame_set(0)
    shots = {
        "front": ((0, 3.2, 0.9), (0, 0, 0.86), 30),
        "q34": ((1.9, 2.6, 1.0), (0, 0, 0.86), 30),
        "side": ((3.2, 0, 0.9), (0, 0, 0.86), 30),
        "back": ((0, -3.2, 0.9), (0, 0, 0.86), 30),
        "face": ((0.12, 0.62, 1.58), (0, 0, 1.555), 22),
        "face34": ((0.38, 0.5, 1.6), (0, 0, 1.56), 22),
        "hand": ((0.75, 0.55, 0.95), (0.22, 0.0, 0.9), 26),
    }
    for name, (loc, target, lens_deg) in shots.items():
        cam.location = loc
        d = Vector(target) - Vector(loc)
        cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
        cam_data.angle = math.radians(lens_deg)
        scene.render.filepath = f"{PREVIEW}_{name}.png"
        bpy.ops.render.render(write_still=True)
    for act, f, name in (("walk", 8, "walk8"), ("walk", 24, "walk24"), ("run", 6, "run6"),
                         ("fall", 0, "fall"), ("crouch", 0, "crouch"), ("slide", 0, "slide")):
        rig.animation_data.action = bpy.data.actions[act]
        scene.frame_set(f)
        cam.location = (2.6, 2.0, 1.0)
        cam.rotation_euler = (Vector((0, 0, 0.86)) - Vector(cam.location)).to_track_quat("-Z", "Y").to_euler()
        cam_data.angle = math.radians(30)
        scene.render.filepath = f"{PREVIEW}_{name}.png"
        bpy.ops.render.render(write_still=True)
    rig.animation_data.action = bpy.data.actions["idle"]
    scene.frame_set(0)


main()
