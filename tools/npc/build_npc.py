"""Builds the hub NPCs from the same VRoid preset as Eco (the "anime fox girl"
model, kept in the project files as preset/anime-fox-girl-preset.zip ->
Untitled.glb), so they share her anime toon look. Run through Blender 4:

    blender -b --factory-startup -P tools/npc/build_npc.py -- <Untitled.glb> <repo root> <mom|ophelia|biggie> [--concept <png prefix>] [--no-export]

It reuses the helpers in tools/eco/build_eco_vroid.py (loaded without running
its main()), then gives each character their own hair, face, body and painted
clothes:
- mom: Eco twenty-odd years on. Her long hair and braids kept and dyed Eco's
  red, gone soft; a softer, worried face with faint lines; a sage cardigan
  over a cream shirt, work trousers, and her late husband's dog tags.
- ophelia: twenties, emo. Choppy black hair with a fringe over her right eye
  and a violet streak, pale skin, heavy liner, dark lips, a lip ring; band tee,
  striped arm warmers, studded belt, ripped black jeans over fishnets, choker.
- biggie: an old militia veteran gone soft. The preset rebuilt as a big man:
  flat chest, broad shoulders, a gut, thick limbs, a grey buzz cut and a big
  grey beard, a scar over his left eye; his faded field jacket (too tight now)
  over a grey tee, ribbons on his chest, cargo trousers and a knee brace.
Writes assets/models/npc/<who>.glb and assets/textures/npc/<who>/*.png. The
glb's material names (npc_<who>_*) are swapped for toon materials on import
by assets/models/npc/npc_import.gd. --concept renders cel-shaded concept
pictures in Eevee instead of (or as well as) exporting.
"""
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, ROOT, WHO = argv[0], argv[1], argv[2]
CONCEPT = argv[argv.index("--concept") + 1] if "--concept" in argv else None
EXPORT = "--no-export" not in argv

# Eco's builder: every helper, without running it.
_eco_path = os.path.join(ROOT, "tools", "eco", "build_eco_vroid.py")
_src = open(_eco_path).read()
_src = _src[:_src.rindex("\nmain()")]
_saved = sys.argv
sys.argv = ["blender", "--", SRC, ROOT]
E = {"__name__": "eco_vroid"}
exec(compile(_src, _eco_path, "exec"), E)
sys.argv = _saved

TEX_OUT = os.path.join(ROOT, "assets", "textures", "npc", WHO)
GLB_OUT = os.path.join(ROOT, "assets", "models", "npc", WHO + ".glb")
E["TEX_OUT"] = TEX_OUT

ss, smooth, NG = E["ss"], E["smooth"], E["NG"]
read_px, write_png, to_lin, to_srgb = E["read_px"], E["write_png"], E["to_lin"], E["to_srgb"]
ramp, lum, mat_index, delete_faces, islands = E["ramp"], E["lum"], E["mat_index"], E["delete_faces"], E["islands"]
X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)
INK = (0.012, 0.009, 0.014)

# per character: height, head scale, leg scale, the blend shapes their resting
# face is made of (set on import), and the hair colour ramp
SPEC = {
    "mom": {
        "height": 1.66, "head": 0.94, "legs": 1.02,
        "face": {"Fcl_BRW_Sorrow": 0.55, "Fcl_EYE_Natural": 0.2, "Fcl_MTH_Up": 0.15},
        # Eco's red, softer and browner, with a little grey in the highlights
        "hair": [(0.30, (0.022, 0.004, 0.004)), (0.62, (0.085, 0.012, 0.010)),
                 (0.86, (0.17, 0.035, 0.028)), (1.0, (0.36, 0.25, 0.23))],
    },
    "ophelia": {
        "height": 1.62, "head": 0.96, "legs": 1.03,
        "face": {"Fcl_EYE_Sorrow": 0.3, "Fcl_BRW_Sorrow": 0.3, "Fcl_MTH_Down": 0.25},
        "hair": [(0.30, (0.004, 0.004, 0.007)), (0.62, (0.013, 0.012, 0.02)),
                 (0.86, (0.035, 0.034, 0.055)), (1.0, (0.12, 0.12, 0.18))],
        "streak": [(0.30, (0.04, 0.004, 0.09)), (0.62, (0.14, 0.02, 0.32)),
                   (0.86, (0.30, 0.06, 0.55)), (1.0, (0.55, 0.25, 0.85))],
    },
    "biggie": {
        "height": 1.78, "head": 0.92, "legs": 0.96,
        "face": {"Fcl_BRW_Joy": 0.6, "Fcl_EYE_Joy": 0.45, "Fcl_MTH_Fun": 0.3},
        # silver-white
        "hair": [(0.30, (0.22, 0.21, 0.2)), (0.62, (0.42, 0.41, 0.39)),
                 (0.86, (0.62, 0.61, 0.59)), (1.0, (0.85, 0.84, 0.82))],
    },
}[WHO]


def dye(px, stops):
    out = px.copy()
    out[..., :3] = to_srgb(ramp(lum(to_lin(px[..., :3])), stops))
    return out


def strip_clothes():
    """All of the preset's clothes go except the ankle boots (their own object)."""
    body = bpy.data.objects["Body"]
    mats = body.data.materials
    boot_idx = {i for i, m in enumerate(mats) if m and "Shoes" in m.name}
    keep_body = {i for i, m in enumerate(mats) if m and ("SKIN" in m.name or "HairBack" in m.name)}
    boots = body.copy()
    boots.data = body.data.copy()
    boots.name = boots.data.name = "Boots"
    bpy.context.scene.collection.objects.link(boots)
    delete_faces(boots, lambda f: f.material_index in boot_idx)
    delete_faces(body, lambda f: f.material_index in keep_body)
    return boots


def all_keys(ob):
    """The basis positions and every shape key, so edits move them together."""
    me = ob.data
    return [kb.data for kb in me.shape_keys.key_blocks] if me.shape_keys else []


def move_verts(ob, fn):
    """Apply fn(index, co) -> new co to the mesh and all its shape keys."""
    me = ob.data
    keys = all_keys(ob)
    base = [v.co.copy() for v in me.vertices]
    new = [fn(i, p) for i, p in enumerate(base)]
    for kd in keys:
        for i in range(len(base)):
            kd[i].co = kd[i].co + (new[i] - base[i])
    for v, p in zip(me.vertices, new):
        v.co = p


# --- hair ------------------------------------------------------------------------------

def fold_hair(rules, drop_below=None):
    """Fold every hair point below its piece's cut height up into a soft end
    (as Eco's bob does). rules(p, material) -> (cut z, end length, tuck)."""
    hair = bpy.data.objects["Hair"]
    if drop_below is not None:
        bm = bmesh.new()
        bm.from_mesh(hair.data)
        dead = [f for comp in islands(bm) if max(v.co.z for f in comp for v in f.verts) < drop_below for f in comp]
        bmesh.ops.delete(bm, geom=list(set(dead)), context="FACES")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        bm.to_mesh(hair.data)
        bm.free()
    me = hair.data
    mat_of = {}
    for p in me.polygons:
        for v in p.vertices:
            mat_of[v] = min(mat_of.get(v, 9), p.material_index)

    def fold(i, p):
        z0, L, tuck = rules(p, mat_of.get(i, 0))
        d = z0 - p.z
        if d <= 0:
            return p
        w = smooth(z0, z0 - 0.12, p.z) * tuck
        return Vector((p.x * (1 - w), 0.02 + (p.y - 0.02) * (1 - w), z0 - L * (1 - math.exp(-d / L))))
    move_verts(hair, fold)


def hair_mom():
    """Her hair stays long: the preset's shoulder-length layers and both braids
    down her back. Only the fringe is lifted off her eyes, swept to her left."""
    def rules(p, m):
        if m == 1:
            return 1.322 - 0.02 * smooth(0.0, -0.05, p.x), 0.03, 0.0
        return -1.0, 0.03, 0.0
    fold_hair(rules)


def hair_ophelia():
    """Choppy, jaw-length black hair, ragged at the back; the fringe falls long
    over her right eye and is cut short on her left. A violet streak in the
    fringe (its own material, see textures())."""
    def rules(p, m):
        if m == 1:
            if p.x < -0.004:   # her right: left long (stretched below)
                return -1.0, 0.02, 0.0
            return 1.33, 0.03, 0.0
        # ragged: alternating lengths around the head
        jag = 0.012 * math.sin(math.atan2(p.y - 0.02, p.x) * 9.0)
        return 1.215 + jag, 0.035, 0.12
    fold_hair(rules, drop_below=1.22)
    hair = bpy.data.objects["Hair"]
    me = hair.data
    fringe = {v for p in me.polygons if p.material_index == 1 for v in p.vertices}

    def long_side(i, p):   # her right side of the fringe falls over the eye
        if i not in fringe:
            return p
        w = smooth(-0.002, -0.014, p.x)
        top = 1.40
        z = top - (top - p.z) * (1 + 0.3 * w)
        if z < 1.268:   # ends at the cheekbone, clear of her mouth
            z = 1.268 - (1.268 - z) * 0.3
        return Vector((p.x, p.y - 0.009 * w * smooth(1.32, 1.27, z), z))
    move_verts(hair, long_side)
    streak = len(me.materials)
    me.materials.append(me.materials[1])   # same texture, dyed violet later
    for p in me.polygons:
        if p.material_index == 1:
            c = p.center
            if -0.032 < c.x < -0.012:
                p.material_index = streak


def hair_biggie():
    """No hair object: the preset's scalp shell (the body's HairBack material)
    dyed silver and cut back to an old man's horseshoe, bald over the crown
    and forehead, grey round the sides and back, with a strip pulled back from
    the crown to his topknot (topknot())."""
    bpy.data.objects.remove(bpy.data.objects["Hair"])
    body = bpy.data.objects["Body"]
    cap = mat_index(body, "HairBack")

    def bald(c):
        strip = abs(c.x) < 0.018 and c.y > 0.0   # pulled back to the knot
        return (c.z > 1.325 + 0.035 * smooth(-0.02, 0.07, c.y) and not strip) or (c.y < -0.035 and c.z > 1.29)
    delete_faces(body, lambda f: not (f.material_index in cap and bald(f.calc_center_median())))


# --- face -----------------------------------------------------------------------------

def face_mats(face):
    mat_of = {}
    for p in face.data.polygons:
        for v in p.vertices:
            mat_of.setdefault(v, set()).add(p.material_index)
    return mat_of


def scale_eyes(face, k):
    """Scale the irises and highlights about each eye's centre."""
    me = face.data
    mat_of = face_mats(face)
    eye_mats = mat_index(face, "EyeIris") | mat_index(face, "EyeHighlight")
    for side in (1, -1):
        ids = [v.index for v in me.vertices if mat_of.get(v.index, set()) & eye_mats and v.co.x * side > 0]
        c = sum((me.vertices[i].co for i in ids), Vector()) / len(ids)
        idset = set(ids)
        move_verts(face, lambda i, p: Vector((c.x + (p.x - c.x) * k, p.y, c.z + (p.z - c.z) * k)) if i in idset else p)


def face_mom():
    """Eco's bones, older and softer: a touch of her longer chin, irises a bit
    smaller than the preset's (calm, not hard)."""
    face = bpy.data.objects["Face"]
    scale_eyes(face, 0.94)

    def chin(i, p):
        w = smooth(1.262, 1.214, p.z) * smooth(-0.025, -0.045, p.y)
        return Vector((p.x * (1 - 0.03 * w), p.y, p.z - 0.004 * w))
    move_verts(face, chin)


def face_ophelia():
    face = bpy.data.objects["Face"]
    scale_eyes(face, 0.9)


def face_biggie():
    """A heavier, squarer face: smaller irises, no lashes, a wider jaw and a
    broader nose, thick brows."""
    face = bpy.data.objects["Face"]
    scale_eyes(face, 0.78)
    delete_faces(face, lambda f: f.material_index not in mat_index(face, "FaceEyelash"))
    brow = mat_index(face, "FaceBrow")
    mat_of = face_mats(face)
    ids = {v.index for v in face.data.vertices if mat_of.get(v.index, set()) & brow}

    def shape(i, p):
        if i in ids:   # bushier brows: taller and lower
            s = 1 if p.x > 0 else -1
            cz = 1.308
            return Vector((p.x * 1.05, p.y - 0.002, cz + (p.z - cz) * 2.3 - 0.003 + 0.002 * smooth(0.02, 0.05, p.x * s)))
        jaw = smooth(1.27, 1.22, p.z)
        nose = math.exp(-((p.x / 0.012) ** 2 + ((p.z - 1.258) / 0.01) ** 2)) * smooth(-0.03, -0.06, p.y)
        cheek = math.exp(-(((abs(p.x) - 0.034) / 0.02) ** 2 + ((p.z - 1.243) / 0.016) ** 2)) * smooth(-0.015, -0.045, p.y)
        return Vector((p.x * (1 + 0.1 * jaw + 0.35 * nose + 0.07 * cheek), p.y - 0.004 * nose - 0.003 * cheek, p.z - 0.006 * jaw * smooth(-0.02, -0.05, p.y)))
    move_verts(face, shape)


# --- body -----------------------------------------------------------------------------

def push(ob, amount_fn, passes=6):
    """Move every point along its own normal by amount_fn(P, N) (arrays), the
    push smoothed over the surface and welded across UV seams (as Eco's curves)."""
    me = ob.data
    n = len(me.vertices)
    P = np.empty(n * 3, np.float32)
    me.vertices.foreach_get("co", P)
    P = P.reshape(n, 3)
    N = np.empty(n * 3, np.float32)
    me.vertices.foreach_get("normal", N)
    N = N.reshape(n, 3)
    groups = {}
    for i, k in enumerate(map(tuple, np.round(P, 5))):
        groups.setdefault(k, []).append(i)
    multi = [ids for ids in groups.values() if len(ids) > 1]
    for ids in multi:
        N[ids] = N[ids].sum(0)
    N /= np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-9)
    D = N * amount_fn(P, N)[:, None]
    edges = np.array([e.vertices[:] for e in me.edges])
    for _ in range(passes):
        acc = np.zeros_like(D)
        cnt = np.zeros(n)
        np.add.at(acc, edges[:, 0], D[edges[:, 1]])
        np.add.at(acc, edges[:, 1], D[edges[:, 0]])
        np.add.at(cnt, edges[:, 0], 1)
        np.add.at(cnt, edges[:, 1], 1)
        D = 0.5 * D + 0.5 * acc / np.maximum(cnt, 1)[:, None]
        for ids in multi:
            D[ids] = D[ids].mean(0)
    me.vertices.foreach_set("co", (P + D).ravel())
    me.update()
    return np.linalg.norm(D, axis=1).max()


def gauss(P, cx, cy, cz, rx, ry, rz, mirror=True):
    x = np.abs(P[:, 0]) if mirror else P[:, 0]
    return np.exp(-(((x - cx) / rx) ** 2 + ((P[:, 1] - cy) / ry) ** 2 + ((P[:, 2] - cz) / rz) ** 2))


def body_mom():
    """Where Eco gets her figure from, and a mother's: fuller, rounder glutes,
    hips and thighs than Eco's (the same normal pushes as her curves(), pushed
    further), a fuller, slightly lower bust, a soft waist and the little pooch
    of a lower belly that carried children, softer upper arms."""
    def amount(P, N):
        x, y, z = P[:, 0], P[:, 1], P[:, 2]
        ax = np.abs(x)
        out = N[:, 0] * np.sign(x)
        # well past Eco's (glutes 0.026, hips 0.014, thighs 0.009): Bones wants her plainly thicker
        glute = 0.052 * np.exp(-((ax - 0.064) / 0.064) ** 2 - ((z - 0.755) / 0.08) ** 2) * ss(-0.02, 0.04, y)
        hip = 0.034 * np.exp(-((z - 0.76) / 0.085) ** 2) * ss(0.1, 0.65, out)
        thigh = 0.03 * ss(0.4, 0.55, z) * ss(0.8, 0.68, z) * (0.35 + 0.65 * ss(-0.5, 0.5, out))
        calf = 0.007 * ss(0.2, 0.28, z) * ss(0.4, 0.33, z)
        bust = 0.026 * gauss(P, 0.062, -0.105, 1.035, 0.052, 0.055, 0.055) * ss(-0.03, -0.07, y)
        waist = 0.01 * np.exp(-((z - 0.9) / 0.06) ** 2) * (0.3 + 0.7 * np.clip(out, 0, 1)) * (ax < 0.2)
        belly = 0.015 * gauss(P, 0.0, -0.08, 0.835, 0.075, 0.06, 0.045) * ss(-0.02, -0.06, y)
        arms = 0.008 * ss(0.11, 0.15, ax) * ss(0.33, 0.27, ax) * (np.abs(z - 1.145) < 0.07) * ss(-0.3, 0.3, -N[:, 2])
        return glute + hip + thigh + calf + bust + waist + belly + arms
    print("mom body: up to %.1f mm" % (push(bpy.data.objects["Body"], amount, passes=7) * 1000))


def body_ophelia():
    """Slight: narrower hips and thighs than the preset."""
    def amount(P, N):
        z = P[:, 2]
        out = N[:, 0] * np.sign(P[:, 0])
        # the piercings lift the fabric a touch
        nip = 0.0034 * gauss(P, NIP[0], -0.12, NIP[1], 0.006, 0.012, 0.006) * ss(-0.08, -0.11, P[:, 1])
        return nip - 0.006 * np.exp(-((z - 0.74) / 0.08) ** 2) * np.clip(out, 0, 1) - 0.004 * ss(0.5, 0.6, z) * ss(0.75, 0.68, z)
    print("ophelia body: up to %.1f mm" % (push(bpy.data.objects["Body"], amount) * 1000))


# Biggie's build, worked out as cross-sections (rest space, before scaling):
# the torso's half-width, depth in front of and behind its centre line at each
# height. A barrel: round all over, widest at the belly, a broad flat back
# and seat, no waist. Legs: thick round columns.
TORSO = [   # z, half-width, front, back
    (0.70, 0.150, 0.080, 0.080),
    (0.76, 0.162, 0.105, 0.084),
    (0.82, 0.176, 0.140, 0.086),
    (0.88, 0.184, 0.160, 0.088),
    (0.94, 0.184, 0.158, 0.092),
    (1.00, 0.178, 0.140, 0.096),
    (1.06, 0.166, 0.118, 0.094),
    (1.11, 0.140, 0.090, 0.082),
]
LEGS = [    # z, radius
    (0.14, 0.044), (0.24, 0.062), (0.34, 0.070), (0.46, 0.064),
    (0.56, 0.078), (0.64, 0.088), (0.72, 0.096),
]


def profile(table, z):
    zs = np.array([t[0] for t in table])
    return [np.interp(z, zs, np.array([t[k] for t in table])) for k in range(1, len(table[0]))]


def reshape(ob, target_fn, passes=8):
    """Move every point to target_fn(P) -> (new P, weight), the move smoothed
    over the surface and welded across UV seams (as push())."""
    me = ob.data
    n = len(me.vertices)
    P = np.empty(n * 3, np.float32)
    me.vertices.foreach_get("co", P)
    P = P.reshape(n, 3)
    Q, w = target_fn(P)
    D = (Q - P) * w[:, None]
    groups = {}
    for i, k in enumerate(map(tuple, np.round(P, 5))):
        groups.setdefault(k, []).append(i)
    multi = [ids for ids in groups.values() if len(ids) > 1]
    for ids in multi:
        D[ids] = D[ids].mean(0)
    edges = np.array([e.vertices[:] for e in me.edges])
    for _ in range(passes):
        acc = np.zeros_like(D)
        cnt = np.zeros(n)
        np.add.at(acc, edges[:, 0], D[edges[:, 1]])
        np.add.at(acc, edges[:, 1], D[edges[:, 0]])
        np.add.at(cnt, edges[:, 0], 1)
        np.add.at(cnt, edges[:, 1], 1)
        D = 0.5 * D + 0.5 * acc / np.maximum(cnt, 1)[:, None]
        for ids in multi:
            D[ids] = D[ids].mean(0)
    me.vertices.foreach_set("co", (P + D).ravel())
    me.update()
    return np.linalg.norm(D, axis=1).max()


def body_biggie(arm):
    """Biggie from scratch, not the preset with a gut on: a stout, round old
    man (think a kindly retired general). His torso and legs are rebuilt to
    cross-sections (TORSO, LEGS): every point keeps its direction from the
    centre line but moves out to the barrel's surface, so her waist, hips,
    bust and seat are gone, not padded over. Then a thick neck, sloping heavy
    shoulders, soft heavy arms, broader shoulders and big hands."""
    body = bpy.data.objects["Body"]

    def torso(P):
        x, y, z = P[:, 0], P[:, 1], P[:, 2]
        A, F, B = profile(TORSO, z)
        cy = -0.02
        dx, dy = x, y - cy
        D = np.where(dy < 0, F, B)
        n = 2.4   # a little boxy: a barrel, not a ball
        k = 1.0 / np.maximum((np.abs(dx / A) ** n + np.abs(dy / D) ** n) ** (1 / n), 1e-6)
        Q = P.copy()
        Q[:, 0] = dx * k
        Q[:, 1] = cy + dy * k
        ax = np.abs(x)
        w = ss(0.70, 0.78, z) * ss(1.13, 1.09, z)
        w *= 1 - ss(1.06, 1.1, z) * ss(0.1, 0.14, ax)     # not the arms
        return Q, w

    def legs(P):
        x, y, z = P[:, 0], P[:, 1], P[:, 2]
        (R,) = profile(LEGS, z)
        s = np.sign(x)
        cx = s * (0.0686 + 0.012 * ss(0.45, 0.72, z))
        cy = 0.012
        dx, dy = x - cx, y - cy
        r = np.maximum(np.hypot(dx, dy), 1e-6)
        inner = (dx * s) < 0
        # never past the middle: the thighs meet, they don't pass through
        lim = np.abs(cx) - 0.003
        Rx = np.where(inner, np.minimum(R, lim), R)
        Rt = np.hypot(Rx * dx / r, R * 0.92 * dy / r)
        k = Rt / r
        Q = P.copy()
        Q[:, 0] = cx + dx * k
        Q[:, 1] = cy + dy * k
        w = ss(0.12, 0.18, z) * ss(0.78, 0.7, z)
        return Q, w

    print("biggie torso: up to %.1f mm" % (reshape(body, torso) * 1000))
    print("biggie legs: up to %.1f mm" % (reshape(body, legs, passes=6) * 1000))

    def amount(P, N):
        x, y, z = P[:, 0], P[:, 1], P[:, 2]
        ax = np.abs(x)
        neck = 0.026 * ss(1.11, 1.15, z) * ss(1.26, 1.21, z) * (ax < 0.07)
        jowl = 0.012 * ss(1.18, 1.21, z) * ss(1.26, 1.23, z) * (ax < 0.05) * ss(-0.0, -0.03, y)
        traps = 0.03 * gauss(P, 0.08, 0.01, 1.15, 0.06, 0.05, 0.035)
        arms = (0.03 + 0.012 * np.exp(-((ax - 0.2) / 0.06) ** 2)) * ss(0.1, 0.14, ax) * ss(0.5, 0.44, ax) * (np.abs(z - 1.145) < 0.08)
        return neck + jowl + traps + arms
    print("biggie arms, neck: up to %.1f mm" % (push(body, amount, passes=8) * 1000))

    # broader shoulders and bigger hands: move points (and bones) outward
    WIDEN, HAND = 0.058, 1.25
    wrist = arm.data.bones["J_Bip_L_Hand"].head_local.x

    def widen(p):
        ax, s = abs(p.x), (1 if p.x >= 0 else -1)
        w = smooth(1.02, 1.12, p.z) * smooth(0.03, 0.09, ax) * smooth(1.3, 1.2, p.z)
        q = Vector((p.x + s * WIDEN * w, p.y, p.z))
        if ax > wrist - 0.01 and abs(p.z - 1.145) < 0.08:
            c = Vector((s * (wrist + WIDEN), 0.022, 1.145))
            k = 1 + (HAND - 1) * smooth(wrist - 0.01, wrist + 0.02, ax)
            q = c + (q - c) * k
        return q
    for ob in (body,):
        move_verts(ob, lambda i, p: widen(p))
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for e in arm.data.edit_bones:
        e.head, e.tail = widen(e.head.copy()), widen(e.tail.copy())
    bpy.ops.object.mode_set(mode="OBJECT")


def beard(arm):
    """A big grey beard: the lower face (jaw, chin, cheeks up to the ears, the
    lip) copied, pushed out and hung down into a full, rounded beard with a
    ragged edge, skinned to the head. Thick moustache over the mouth."""
    face = bpy.data.objects["Face"]
    skin = mat_index(face, "Face_00_SKIN")
    bm = bmesh.new()
    bm.from_mesh(face.data)
    bm.normal_update()

    def top(ax, y=-1.0):
        side = smooth(-0.03, -0.005, y)   # sideburns only toward the ears
        return 1.2505 - 0.004 * smooth(0.012, 0.03, ax) + 0.006 * smooth(0.03, 0.05, ax) + 0.055 * smooth(0.05, 0.075, ax) * side

    def in_beard(c):
        ax = abs(c.x)
        if c.y > 0.035 - 0.05 * smooth(0.06, 0.09, ax) or c.z < 1.17:
            return False
        return c.z < top(ax, c.y)   # it hides his mouth: he talks through it
    dead = [f for f in bm.faces if f.material_index not in skin or not in_beard(f.calc_center_median())]
    bmesh.ops.delete(bm, geom=dead, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.normal_update()
    rng = np.random.default_rng(7)
    for v in bm.verts:
        p = v.co.copy()
        ax = abs(p.x)
        chin = math.exp(-((p.x / 0.05) ** 2 + ((p.z - 1.205) / 0.04) ** 2))
        stache = math.exp(-((p.x / 0.024) ** 2 + ((p.z - 1.2455) / 0.004) ** 2)) * smooth(-0.03, -0.05, p.y)
        edge = smooth(top(ax, p.y) - 0.005, top(ax, p.y), p.z)   # thin out toward the top edge
        t = (0.005 + 0.018 * chin + 0.005 * stache) * (1 - 0.75 * edge)
        q = p + v.normal * t
        # the chin's hair hangs down and forward, rounded at the bottom
        hang = chin * smooth(1.235, 1.19, p.z)
        q += Vector((0, -0.016 * hang, -0.075 * hang))
        v.co = q
    # a few soft points along the bottom edge
    for v in bm.verts:
        if v.co.z < 1.2:
            v.co.z -= 0.006 * max(0.0, math.cos(v.co.x * 260)) * smooth(1.2, 1.17, v.co.z)
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=-0.003)
    me = bpy.data.meshes.new("Beard")
    bm.to_mesh(me)
    bm.free()
    while me.materials:
        me.materials.pop()
    me.materials.append(new_mat("npc_biggie_beard", (0.45, 0.44, 0.42)))
    for p in me.polygons:
        p.material_index = 0
    # the strand texture runs down the beard
    uv = me.uv_layers.new(name="UVMap")
    for loop in me.loops:
        co = me.vertices[loop.vertex_index].co
        uv.data[loop.index].uv = (0.5 + math.atan2(co.x, -co.y) / math.pi, (co.z - 1.12) / 0.2)
    for p in me.polygons:
        p.use_smooth = True
    ob = bpy.data.objects.new("Beard", me)
    bpy.context.scene.collection.objects.link(ob)
    vg = ob.vertex_groups.new(name="J_Bip_C_Head")
    vg.add(list(range(len(me.vertices))), 1.0, "REPLACE")
    ob.parent = arm
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    return ob


def topknot(arm):
    """His hair pulled back into a small knot high on the back of his head,
    with a dark band round its base, skinned to the head."""
    bm = bmesh.new()
    C = Vector((0.0, 0.048, 1.4))
    bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=1.0)
    for v in bm.verts:
        v.co = C + Vector((v.co.x * 0.026, v.co.y * 0.026, v.co.z * 0.032))
    knot = len(bm.verts)
    made = bmesh.ops.create_cone(bm, cap_ends=True, segments=16, radius1=0.016, radius2=0.016, depth=0.008)["verts"]
    for v in made:
        v.co = C + Vector((v.co.x, v.co.y, v.co.z - 0.03))
    me = bpy.data.meshes.new("Topknot")
    bm.to_mesh(me)
    bm.free()
    me.materials.append(bpy.data.materials["npc_biggie_beard"])
    me.materials.append(new_mat("npc_biggie_metal", (0.05, 0.035, 0.02)))
    for p in me.polygons:
        p.material_index = 1 if all(v >= knot for v in p.vertices) else 0
        p.use_smooth = True
    uv = me.uv_layers.new(name="UVMap")
    for loop in me.loops:
        co = me.vertices[loop.vertex_index].co - C
        uv.data[loop.index].uv = (0.5 + math.atan2(co.x, co.y) / math.pi, 0.5 + co.z * 10)
    ob = bpy.data.objects.new("Topknot", me)
    bpy.context.scene.collection.objects.link(ob)
    vg = ob.vertex_groups.new(name="J_Bip_C_Head")
    vg.add(list(range(len(me.vertices))), 1.0, "REPLACE")
    ob.parent = arm
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    return ob


def beanie(arm):
    """An old knit watch cap pulled down to his brows, with a turned-up cuff:
    a dome fitted over his head by casting rays in from outside (as Eco's
    goggles strap), skinned to the head."""
    from mathutils.bvhtree import BVHTree
    dg = bpy.context.evaluated_depsgraph_get()
    trees = [BVHTree.FromObject(bpy.data.objects[n], dg) for n in ("Face", "Body")]
    C = Vector((0.0, 0.025, 1.318))
    # the cap's rim: low over the brows at the front, over the ears, nape behind
    def rim_z(a):   # a = angle round the head, 0 at the front
        return 1.322 - 0.035 * (0.5 - 0.5 * math.cos(a))

    def surface(d):
        best = 0.06
        for t in trees:
            hit = t.ray_cast(C + d * 0.3, -d)
            if hit[0] is not None:
                best = max(best, (hit[0] - C).length)
        return best
    NA, NR = 48, 14
    bm = bmesh.new()
    rows = []
    for j in range(NR + 1):
        row = []
        f = j / NR   # 0 at the rim, 1 at the crown
        for i in range(NA):
            a = 2 * math.pi * i / NA
            horiz = Vector((math.sin(a), -math.cos(a), 0))
            z0 = rim_z(a) - C.z
            # elevation from the rim's height up to the crown
            el0 = math.atan2(z0, 0.09)
            el = el0 + (math.pi / 2 - el0) * f
            d = (horiz * math.cos(el) + Vector((0, 0, 1)) * math.sin(el)).normalized()
            r = surface(d) + 0.009 + 0.006 * f * f
            p = C + d * r + Vector((0, 0.012 * f * f, 0.012 * f * f))   # slouches back at the top
            row.append(bm.verts.new(p))
        rows.append(row)
    for j in range(NR):
        for i in range(NA):
            bm.faces.new((rows[j][i], rows[j][(i + 1) % NA], rows[j + 1][(i + 1) % NA], rows[j + 1][i]))
    cap = bm.verts.new(sum((v.co for v in rows[NR]), Vector()) / NA)
    for i in range(NA):
        bm.faces.new((rows[NR][i], rows[NR][(i + 1) % NA], cap))
    # the cuff: a thicker band round the rim
    cuff = []
    for k, (up, out) in enumerate(((-0.002, 0.004), (0.028, 0.006))):
        ring = []
        for i in range(NA):
            p0 = rows[0][i].co
            outward = (p0 - Vector((C.x, C.y, p0.z))).normalized()
            ring.append(bm.verts.new(p0 + outward * out + Vector((0, 0, up))))
        cuff.append(ring)
    for i in range(NA):
        n = (i + 1) % NA
        bm.faces.new((cuff[0][i], cuff[0][n], cuff[1][n], cuff[1][i]))
        bm.faces.new((rows[0][i], rows[0][n], cuff[0][n], cuff[0][i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new("Beanie")
    bm.to_mesh(me)
    bm.free()
    me.materials.append(new_mat("npc_biggie_beanie", (0.06, 0.07, 0.045)))
    for p in me.polygons:
        p.use_smooth = True
    ob = bpy.data.objects.new("Beanie", me)
    bpy.context.scene.collection.objects.link(ob)
    vg = ob.vertex_groups.new(name="J_Bip_C_Head")
    vg.add(list(range(len(me.vertices))), 1.0, "REPLACE")
    ob.parent = arm
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    return ob


def lip_ring(arm):
    """A small silver ring through the left of her lower lip."""
    bm = bmesh.new()
    c = Vector((0.0075, -0.0505, 1.2368))
    M = Matrix.Translation(c) @ Matrix.Rotation(math.radians(90), 4, "Y") @ Matrix.Rotation(math.radians(-15), 4, "X")
    major, minor = 0.0034, 0.0006
    grid = []
    for i in range(20):
        t = 2 * math.pi * i / 20
        row = []
        for j in range(6):
            u = 2 * math.pi * j / 6
            q = Vector(((major + minor * math.cos(u)) * math.cos(t), (major + minor * math.cos(u)) * math.sin(t), minor * math.sin(u)))
            row.append(bm.verts.new(M @ q))
        grid.append(row)
    for i in range(20):
        for j in range(6):
            bm.faces.new((grid[i][j], grid[(i + 1) % 20][j], grid[(i + 1) % 20][(j + 1) % 6], grid[i][(j + 1) % 6]))
    me = bpy.data.meshes.new("LipRing")
    bm.to_mesh(me)
    bm.free()
    me.materials.append(new_mat("npc_ophelia_metal", (0.7, 0.7, 0.75)))
    ob = bpy.data.objects.new("LipRing", me)
    bpy.context.scene.collection.objects.link(ob)
    vg = ob.vertex_groups.new(name="J_Bip_C_Head")
    vg.add(list(range(len(me.vertices))), 1.0, "REPLACE")
    ob.parent = arm
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    return ob


def nipple_bars(arm, bars=True, r=0.0052, h=0.005):
    """Nipples that show through their clothes as real shape: on each side a
    rounded nub (Ophelia's with her bar's two balls either side of it; Mom's
    bigger, no bars), sitting on the body
    and skinned exactly as the body under them (so they bounce with her chest).
    They wear the body's own material, each point taking the texture of the
    body just under it, so whatever outfit she has on stretches over them
    (painted shading from ophelia_outfit's pierce() on top)."""
    from mathutils import interpolate
    from mathutils.bvhtree import BVHTree
    body = bpy.data.objects["Body"]
    me_b = body.data
    tree = BVHTree.FromPolygons([v.co for v in me_b.vertices], [p.vertices[:] for p in me_b.polygons])
    uv_b = me_b.uv_layers.active.data
    bm = bmesh.new()

    def blob(c, n, t, r, h, sink, rows=6, segs=14):
        """A dome of radius r and height h on the plane through c (normal n),
        its rim pushed `sink` into the body so no gap shows."""
        b = n.cross(t).normalized()
        top = bm.verts.new(c + n * (h - sink))
        rings = []
        for i in range(1, rows + 1):
            a = (math.pi / 2) * i / rows
            ring = [bm.verts.new(c + n * (h * math.cos(a) - sink) + (t * math.cos(u) + b * math.sin(u)) * r * math.sin(a))
                    for u in (2 * math.pi * k / segs for k in range(segs))]
            rings.append(ring)
        for k in range(segs):
            bm.faces.new((top, rings[0][k], rings[0][(k + 1) % segs]))
        for i in range(rows - 1):
            for k in range(segs):
                bm.faces.new((rings[i][k], rings[i + 1][k], rings[i + 1][(k + 1) % segs], rings[i][(k + 1) % segs]))

    for s in (1, -1):
        hit = tree.ray_cast(Vector((s * NIP[0], -0.3, NIP[1])), Vector((0, 1, 0)))
        c, n = hit[0], hit[1].normalized()
        if n.y > 0:
            n = -n
        t = (Vector((1, 0, 0)) - n * n.x).normalized()   # across her chest, along the surface
        blob(c, n, t, r, h, 0.0008)
        for e in (1, -1) if bars else ():
            q = c + t * (0.0088 * e)
            hit2 = tree.find_nearest(q)
            blob(hit2[0], hit2[1].normalized() * (1 if hit2[1].y < 0 else -1), t, 0.0026, 0.0024, 0.0006, rows=4, segs=10)
    me = bpy.data.meshes.new("Piercings")
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    # texture and skin weights from the body just under each point
    uv = me.uv_layers.new(name="UVMap")
    point_uv = {}
    point_w = {}
    for v in me.vertices:
        loc, _n, poly_i, _d = tree.find_nearest(v.co)
        poly = me_b.polygons[poly_i]
        corners = [me_b.vertices[i].co for i in poly.vertices]
        w = interpolate.poly_3d_calc(corners, loc)
        point_uv[v.index] = sum((uv_b[li].uv * wi for li, wi in zip(poly.loop_indices, w)), Vector((0.0, 0.0)))
        groups = {}
        for vi, wi in zip(poly.vertices, w):
            for g in me_b.vertices[vi].groups:
                name = body.vertex_groups[g.group].name
                groups[name] = groups.get(name, 0.0) + g.weight * wi
        point_w[v.index] = groups
    for loop in me.loops:
        uv.data[loop.index].uv = point_uv[loop.vertex_index]
    ob = bpy.data.objects.new("Piercings", me)
    bpy.context.scene.collection.objects.link(ob)
    for vi, groups in point_w.items():
        for name, w in groups.items():
            if w > 0.001:
                vg = ob.vertex_groups.get(name) or ob.vertex_groups.new(name=name)
                vg.add([vi], w, "REPLACE")
    ob.parent = arm
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    me.materials.append(new_mat("npc_%s_piercings_tmp" % WHO))
    return ob


def new_mat(name, col=(0.5, 0.5, 0.5)):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.diffuse_color = (*col, 1)
    return m


# --- face paint -------------------------------------------------------------------------

def face_paint(face, img):
    """Each face's skin texture, recoloured and painted in 3D from rest positions
    (the coordinates are the preset's: eyes about z 1.29, lips z 1.24)."""
    px = read_px(img).copy()
    H, W = px.shape[:2]
    rgb = px[..., :3]
    # the preset's pink cheek blush, toned down for everyone
    yy, xx = np.mgrid[0:H, 0:W]
    yy = H - 1 - yy
    w = np.zeros((H, W))
    for cx in (330, 690):
        r = ((xx - cx) / 130.0) ** 2 + ((yy - 625) / 85.0) ** 2
        w = np.maximum(w, np.clip(1.4 - r, 0, 1))
    pink = (rgb[..., 0] - (rgb[..., 1] + rgb[..., 2]) / 2) * 255
    d = np.clip(pink - 19.0, 0, None) * w * (0.85 if WHO != "mom" else 0.6) / 255
    rgb[..., 0] -= d * 2 / 3
    rgb[..., 1] += d / 3
    rgb[..., 2] += d / 3
    pos, mask = E["face_position_map"](face, W, H)
    x, y, z = np.abs(pos[..., 0]), pos[..., 1], pos[..., 2]
    sx = pos[..., 0]

    def tint(col, amount):
        a = (amount * mask)[..., None]
        px[..., :3] = px[..., :3] * (1 - a) + px[..., :3] * np.array(col) * a

    def paint(col, amount):
        a = (amount * mask)[..., None]
        px[..., :3] = px[..., :3] * (1 - a) + np.array(col) * a

    def line(ax_, az, bx, bz, width, side=None):
        """Distance-to-segment stroke on the face (mirrored unless side given)."""
        qx = x if side is None else sx * side
        a = np.array((ax_, az))
        b = np.array((bx, bz))
        ab = b - a
        t = np.clip(((qx - a[0]) * ab[0] + (z - a[1]) * ab[1]) / ab.dot(ab), 0, 1)
        dx = qx - (a[0] + t * ab[0])
        dz = z - (a[1] + t * ab[1])
        return 1 - ss(width * 0.4, width, np.sqrt(dx * dx + dz * dz))
    front = y < -0.02
    dz = z - 1.2397
    lips = (pos[..., 0] / 0.0098) ** 2 + (dz / np.where(dz < 0, 0.0036, 0.0021)) ** 2
    u = (x - 0.041) / 0.029
    v = (z - 1.2905) / 0.0135
    lid = (1 - ss(0.45, 1.0, np.sqrt(u * u + v * v))) * ss(1.276, 1.287, z) * (y < -0.015)
    if WHO == "mom":
        # warm brown lids, a rose lip, and the lines of someone who worries:
        # under the eyes, at their corners, from nose to mouth
        tint((0.75, 0.55, 0.5), 0.5 * lid)
        tint((0.85, 0.5, 0.52), 0.55 * (1 - ss(0.35, 1.0, lips)) * (y < -0.04))
        lines = (line(0.03, 1.2765, 0.05, 1.279, 0.0012) * 0.25
                 + line(0.0665, 1.289, 0.072, 1.285, 0.0009) * 0.25 + line(0.066, 1.293, 0.0725, 1.292, 0.0008) * 0.2)
        tint((0.72, 0.55, 0.52), np.clip(lines, 0, 1) * front)
    elif WHO == "ophelia":
        # pale and cool, a smudged black ring of liner all round the eye with a
        # flick, shadowed sockets, near-black plum lips
        px[..., :3] = px[..., :3] * 0.82 + np.array((0.95, 0.93, 0.97)) * 0.18
        ring = np.sqrt(((x - 0.043) / 0.03) ** 2 + ((z - 1.2885) / 0.016) ** 2)
        tint((0.62, 0.52, 0.66), 0.4 * (1 - ss(0.85, 1.2, ring)) * (y < -0.015))
        # smudged liner under the eye (the upper line is the preset's, darkened)
        paint((0.05, 0.03, 0.055), 0.6 * (1 - ss(0.03, 0.1, np.abs(ring - 0.9))) * ss(1.2905, 1.2875, z) * (y < -0.02))
        paint((0.03, 0.02, 0.035), 0.9 * line(0.068, 1.29, 0.079, 1.297, 0.0012))
        paint((0.16, 0.04, 0.12), 0.85 * (1 - ss(0.35, 1.0, lips)) * (y < -0.04))
    else:
        # weathered: tanned, ruddy nose and cheeks, forehead lines, crow's feet
        # and a scar down through his left eye
        px[..., :3] = px[..., :3] * np.array((0.9, 0.78, 0.68))
        tint((1.0, 0.75, 0.7), 0.35 * np.exp(-((x / 0.012) ** 2 + ((z - 1.26) / 0.012) ** 2)))
        tint((1.0, 0.82, 0.78), 0.3 * np.exp(-(((x - 0.045) / 0.02) ** 2 + ((z - 1.268) / 0.012) ** 2)))
        lines = (line(0.0, 1.334, 0.035, 1.336, 0.0009) + line(0.0, 1.327, 0.03, 1.3285, 0.0008) * 0.8
                 + line(0.066, 1.288, 0.076, 1.283, 0.0008) + line(0.066, 1.292, 0.077, 1.293, 0.0008)
                 + line(0.03, 1.275, 0.052, 1.277, 0.001) * 0.7)
        tint((0.62, 0.48, 0.42), np.clip(lines, 0, 1) * 0.6 * front)
        scar = line(0.036, 1.318, 0.05, 1.262, 0.0018, side=1)
        paint((0.86, 0.6, 0.58), 0.75 * scar * front)
        tint((0.7, 0.45, 0.45), 0.6 * line(0.036, 1.318, 0.05, 1.262, 0.0007, side=1) * front)
    return px


def skin_tone(px):
    """The body's skin to match the face."""
    if WHO == "ophelia":
        px[..., :3] = px[..., :3] * 0.82 + np.array((0.95, 0.93, 0.97)) * 0.18
    elif WHO == "biggie":
        px[..., :3] = px[..., :3] * np.array((0.9, 0.78, 0.68))
    return px


# --- clothes, painted on (baked like Eco's suit) ----------------------------------------

# Ophelia's outfits: "tee" is the one she's built in (body.png); the others
# bake to body_<outfit>.png and hub_npc.gd swaps them in.
OUTFITS = {"ophelia": ["tee", "hoodie", "night", "bikini", "sheer", "tight", "lingerie"],
           "mom": ["home", "bikini", "sheer", "tight", "lingerie"]}
OUTFIT = "tee"
# where her piercings sit (rest space, mirrored): x, z
NIP = (0.056, 1.049)


def ophelia_outfit(g, skin, x, y, z, ax, front, cov, edge, sine, neck_r):
    """tee: black band tee with a broken pink heart, striped arm warmers,
    studded belt, ripped black jeans over fishnets.
    hoodie: a big charcoal zip hoodie, half open, sleeves down over her
    hands (thumb holes), violet-lined hood band and drawstrings, a pale moth on
    the back; black skinny jeans and a wallet chain.
    night: a black cami under a sheer fishnet long-sleeve, high-waisted black
    shorts with the studded belt, black and violet striped thigh-highs.
    All of them: her choker with its o-ring."""
    BLACK, PURPLE, PINK, DENIM, STUD = (0.012, 0.011, 0.015), (0.12, 0.03, 0.22), (0.7, 0.08, 0.3), (0.02, 0.02, 0.026), (0.6, 0.6, 0.65)
    CHAR, BONE = (0.035, 0.033, 0.04), (0.62, 0.58, 0.6)
    net = g.mx(g.sstep(0.82, 0.92, sine(g.add(x, z), 0.01)), g.sstep(0.82, 0.92, sine(g.sub(x, z), 0.01)))
    choker = g.mul(g.band(z, 1.178, 1.192), g.sub(1.0, g.sstep(0.065, 0.075, neck_r)))
    o_ring = g.mul(g.mul(g.band(g.sqrt(g.add(g.sq(x), g.sq(g.sub(z, 1.174)))), 0.004, 0.0055), front), g.sstep(1.16, 1.165, z))
    # her nipple piercings: small barbells that show through whatever she
    # wears, a raised point catching the light with a bar end either side
    nx = g.sub(ax, NIP[0])
    nz = g.sub(z, NIP[1])
    nub = g.mul(g.sub(1.0, g.sstep(0.0035, 0.0055, g.sqrt(g.add(g.sq(nx), g.sq(nz))))), front)
    ends = g.mul(g.sub(1.0, g.sstep(0.0016, 0.0026, g.sqrt(g.add(g.sq(g.sub(g.abs(nx), 0.0085)), g.sq(nz))))), front)

    def pierce(col, strong=False):
        if strong:   # pressed hard through the thin cami: a bright point, shadow under it, bigger bar ends
            shade = g.mul(g.sub(1.0, g.sstep(0.004, 0.0075, g.sqrt(g.add(g.sq(nx), g.sq(g.add(nz, 0.0035)))))), front)
            col = g.mixc(col, (0.0, 0.0, 0.0), g.mul(shade, 0.6))
            col = g.mixc(col, (0.24, 0.22, 0.26), g.mul(nub, 0.3))   # the fabric stretched thin over her (the shape is mesh: nipple_bars())
            big = g.mul(g.sub(1.0, g.sstep(0.0022, 0.0032, g.sqrt(g.add(g.sq(g.sub(g.abs(nx), 0.0095)), g.sq(nz))))), front)
            return g.mixc(col, (0.62, 0.62, 0.68), big)
        col = g.mixc(col, (0.16, 0.15, 0.18), g.mul(nub, 0.25))
        return g.mixc(col, (0.42, 0.42, 0.46), g.mul(ends, 0.8))
    if OUTFIT == "tee":
        neck_z = g.lerp(g.sub(1.168, g.mul(0.012, front)), 1.4, g.sstep(0.065, 0.09, ax))
        d_tee = g.mn(g.mn(g.sub(neck_z, z), g.sub(z, 0.865)), g.sub(0.175, ax))
        tee = cov(d_tee)
        # a broken pink heart on the chest
        hx = g.div(x, 0.026)
        hz = g.div(g.sub(z, 1.04), 0.026)
        q = g.sub(g.add(g.sq(hx), g.sq(hz)), 1.0)
        heart_f = g.sub(g.mul(g.mul(q, q), q), g.mul(g.sq(hx), g.mul(g.mul(hz, hz), hz)))
        crack = g.band(g.add(x, g.mul(g.abs(g.sub(g.op("FRACT", g.div(z, 0.012)), 0.5)), 0.008)), 0.0, 0.0018)
        heart = g.mul(g.mul(g.sub(1.0, g.sstep(-0.0005, 0.0005, heart_f)), front), g.sub(1.0, crack))
        warmers = g.mul(cov(g.mn(g.sub(ax, 0.3), g.sub(0.475, ax))), g.sstep(-0.1, 0.1, sine(ax, 0.026)))
        warm_all = cov(g.mn(g.sub(ax, 0.3), g.sub(0.475, ax)))
        d_jeans = g.mn(g.sub(0.8, z), g.sub(z, 0.12))
        jeans = cov(d_jeans)
        # rips at the knees and the left thigh: fishnet shows through
        rip = g.mx(g.mul(g.sub(1.0, g.sstep(0.6, 1.0, g.sqrt(g.add(g.sq(g.div(g.sub(ax, 0.069), 0.03)), g.sq(g.div(g.sub(z, 0.48), 0.022)))))), front),
                   g.mul(g.sub(1.0, g.sstep(0.6, 1.0, g.sqrt(g.add(g.sq(g.div(g.sub(x, 0.075), 0.02)), g.sq(g.div(g.sub(z, 0.64), 0.012)))))), front))
        belt = g.mul(g.band(z, 0.78, 0.8), jeans)
        studs = g.mul(g.mul(belt, g.sstep(0.75, 0.85, sine(g.add(x, y), 0.012))), g.band(z, 0.786, 0.794))
        col = g.mixc(skin, BLACK, tee)
        col = g.mixc(col, PINK, g.mul(heart, tee))
        col = g.mixc(col, BLACK, warm_all)
        col = g.mixc(col, PURPLE, warmers)
        col = g.mixc(col, DENIM, g.mul(jeans, g.sub(1.0, rip)))
        col = g.mixc(col, BLACK, g.mul(g.mul(jeans, rip), net))
        col = g.mixc(col, BLACK, belt)
        col = g.mixc(col, STUD, g.mx(studs, o_ring))
        col = g.mixc(col, BLACK, choker)
        ink = g.mx(g.mx(edge(d_tee), edge(d_jeans)), edge(g.mn(g.sub(ax, 0.3), g.sub(0.475, ax))))
        return pierce(g.mixc(col, INK, ink))
    if OUTFIT == "hoodie":
        neck_z = g.lerp(g.sub(1.172, g.mul(0.006, front)), 1.4, g.sstep(0.07, 0.095, ax))
        # sleeves come down over the backs of her hands; the thumb hole is skin
        d_hood = g.mn(g.mn(g.sub(neck_z, z), g.sub(z, 0.745)), g.sub(0.5, ax))
        hood = cov(d_hood)
        band = g.mul(g.mul(g.band(g.sub(z, neck_z), -0.014, 0.0), hood), g.sub(1.0, g.sstep(0.07, 0.095, ax)))
        cuff = g.mul(g.band(ax, 0.45, 0.5), hood)
        hem = g.mul(g.band(z, 0.745, 0.77), hood)
        # zipped up to the bust, open above: her choker and collarbones show
        # only on the front: on the back (front 0) it must stay well outside the opening
        open_ = g.sub(g.mul(front, g.sub(g.mul(g.sstep(1.06, 1.15, z), 0.03), ax)), g.sub(1.0, front))
        top = g.mul(hood, g.sub(1.0, cov(open_)))
        zip_ = g.mul(g.mul(g.band(x, -0.0012, 0.0012), front), g.mul(top, g.sstep(1.07, 1.06, z)))
        pocket = g.mul(g.mul(cov(g.mn(g.sub(0.075, g.add(ax, g.mul(g.sub(z, 0.78), 0.4))), g.sub(g.sub(0.87, z), 0.0))), g.sstep(0.775, 0.78, z)), g.mul(front, top))
        strings = g.mul(g.mul(g.band(ax, 0.022, 0.026), g.mul(g.sstep(1.03, 1.035, z), g.sstep(1.16, 1.15, z))), front)
        tips = g.mul(g.mul(g.band(ax, 0.021, 0.027), g.band(z, 1.025, 1.035)), front)
        moth_x = g.div(ax, 0.05)
        moth_z = g.div(g.sub(z, 1.04), 0.05)
        wing = g.sub(1.0, g.sstep(0.9, 1.0, g.add(g.sq(g.div(g.sub(moth_x, 0.55), 0.55)), g.sq(g.div(g.sub(moth_z, g.mul(moth_x, 0.25)), 0.6)))))
        lower = g.sub(1.0, g.sstep(0.9, 1.0, g.add(g.sq(g.div(g.sub(moth_x, 0.35), 0.35)), g.sq(g.div(g.add(moth_z, 0.55), 0.4)))))
        body_m = g.mul(g.sub(1.0, g.sstep(0.07, 0.1, moth_x)), g.mul(g.sstep(-0.9, -0.8, moth_z), g.sstep(0.6, 0.5, moth_z)))
        moth = g.mul(g.mul(g.mx(g.mx(wing, lower), body_m), g.sub(1.0, front)), top)
        eye = g.mul(g.sub(1.0, g.sstep(0.012, 0.016, g.sqrt(g.add(g.sq(g.sub(ax, 0.028)), g.sq(g.sub(z, 1.05)))))), moth)
        d_jeans = g.mn(g.sub(0.8, z), g.sub(z, 0.12))
        jeans = cov(d_jeans)
        seam = g.mul(g.band(g.abs(g.add(y, 0.0)), 0.0, 0.0012), g.mul(jeans, g.sstep(0.06, 0.08, ax)))
        chain = g.mul(g.band(g.sub(z, g.add(0.74, g.mul(g.sq(g.div(g.add(y, 0.0), 0.06)), 0.05))), -0.0016, 0.0016), g.mul(g.sstep(-0.09, -0.1, x), g.sstep(0.73, 0.75, z)))
        col = g.mixc(skin, BLACK, jeans)
        col = g.mixc(col, (0.04, 0.035, 0.05), seam)
        col = g.mixc(col, STUD, g.mul(chain, g.sub(1.0, hood)))
        col = g.mixc(col, CHAR, top)
        col = g.mixc(col, BLACK, g.mx(g.mx(cuff, hem), g.mul(pocket, 0.6)))
        col = g.mixc(col, PURPLE, g.mx(band, g.mul(strings, top)))
        col = g.mixc(col, STUD, g.mx(zip_, tips))
        col = g.mixc(col, BONE, moth)
        col = g.mixc(col, CHAR, eye)
        col = g.mixc(col, STUD, o_ring)
        col = g.mixc(col, BLACK, choker)
        ink = g.mx(g.mx(edge(d_hood), g.mul(edge(open_), hood)), g.mx(edge(d_jeans), g.mul(edge(g.sub(0.075, g.add(ax, g.mul(g.sub(z, 0.78), 0.4)))), g.mul(pocket, 1.0))))
        return pierce(g.mixc(col, INK, ink))
    # night
    neck_z = g.lerp(1.172, 1.4, g.sstep(0.065, 0.09, ax))
    d_mesh = g.mn(g.mn(g.sub(neck_z, z), g.sub(z, 0.84)), g.sub(0.47, ax))
    mesh = cov(d_mesh)
    # the cami: a straight top edge across the bust, thin straps
    top_z = g.add(1.085, g.mul(g.sub(1.0, front), 0.03))
    d_cami = g.mn(g.sub(top_z, z), g.sub(z, 0.9))
    cami = g.mul(cov(d_cami), g.sstep(0.2, 0.18, ax))
    straps = g.mul(g.mul(g.band(ax, 0.06, 0.068), g.sstep(1.08, 1.09, z)), g.sstep(0.2, 0.18, ax))
    # tiny low-rise shorts: the leg openings cut up high over the hips and
    # cheeky at the back, still covering where they need to
    waist_z = g.add(0.8, g.mul(g.sub(1.0, front), 0.012))
    open_z = g.add(0.702, g.mul(g.sstep(0.02, 0.11, ax), g.add(0.07, g.mul(g.sub(1.0, front), 0.012))))
    d_shorts = g.mn(g.sub(waist_z, z), g.sub(z, open_z))
    shorts = cov(d_shorts)
    belt = g.mul(g.band(g.sub(z, waist_z), -0.014, 0.0), shorts)
    studs = g.mul(g.mul(belt, g.sstep(0.75, 0.85, sine(g.add(x, y), 0.012))), g.band(g.sub(z, waist_z), -0.009, -0.005))
    lace = g.mul(g.mul(g.band(g.abs(g.sub(ax, g.mul(g.abs(g.sub(g.op("FRACT", g.div(z, 0.02)), 0.5)), 0.012))), 0.0, 0.0012), front), g.mul(g.band(ax, 0.0, 0.012), g.band(z, 0.7, 0.82)))
    d_socks = g.mn(g.sub(0.565, z), g.sub(z, 0.12))
    socks = cov(d_socks)
    stripes = g.mul(socks, g.sstep(-0.15, 0.15, sine(z, 0.03)))
    col = g.mixc(skin, BLACK, g.mul(g.mul(mesh, net), 0.85))
    col = g.mixc(col, BLACK, g.mx(cami, straps))
    col = g.mixc(col, BLACK, socks)
    col = g.mixc(col, PURPLE, stripes)
    col = g.mixc(col, BLACK, shorts)
    col = g.mixc(col, (0.06, 0.06, 0.07), belt)
    col = g.mixc(col, STUD, g.mx(g.mx(studs, o_ring), g.mul(lace, shorts)))
    col = g.mixc(col, BLACK, choker)
    ink = g.mx(g.mx(edge(d_cami), edge(d_shorts)), g.mx(g.mul(edge(d_socks), 1.0), g.mul(edge(d_mesh), 0.6)))
    return pierce(g.mixc(col, INK, ink), strong=True)


# The outfits Mom and Ophelia both have, each in their own style (Bones,
# 2026-10-03): a bikini, a sheer layer over solid underwear, a tight thong
# bodysuit cut to show cleavage / underboob / sideboob, and lingerie. The
# line held in all of them: solid fabric always over the nipples (with a margin
# round them) and between the legs; sheer only ever over solid or skin elsewhere.
EXTRA_OUTFITS = ["bikini", "sheer", "tight", "lingerie"]
# plain skin for bare legs (the preset's skin has stockings painted below the
# knee); bake_body samples it from her thighs
LEG_SKIN = (0.6, 0.45, 0.4)


def extra_outfit(g, skin, x, y, z, ax, front, cov, edge, sine, neck_r):
    mom = WHO == "mom"
    if mom:
        MAIN, DARK, TRIM, SHEER_C, METAL = (0.13, 0.19, 0.12), (0.07, 0.1, 0.06), (0.6, 0.55, 0.45), (0.03, 0.02, 0.02), (0.55, 0.45, 0.25)
        LACE_A, LACE_B = (0.16, 0.02, 0.06), (0.06, 0.005, 0.02)   # deep plum lace
    else:
        MAIN, DARK, TRIM, SHEER_C, METAL = (0.012, 0.011, 0.015), (0.005, 0.005, 0.007), (0.12, 0.03, 0.22), (0.01, 0.01, 0.014), (0.6, 0.6, 0.65)
        LACE_A, LACE_B = (0.02, 0.018, 0.025), (0.1, 0.025, 0.18)    # black lace, violet ribbon

    def front_only(d):   # a piece that exists only on her front
        return g.sub(g.mul(front, d), g.sub(1.0, front))

    col = g.mixc(skin, LEG_SKIN, g.sstep(0.63, 0.59, z))
    ink = 0.0
    net = g.mx(g.sstep(0.82, 0.92, sine(g.add(x, z), 0.01)), g.sstep(0.82, 0.92, sine(g.sub(x, z), 0.01)))
    lace = g.mul(g.sstep(0.2, 0.7, sine(g.add(g.mul(x, 1.3), g.mul(z, 0.7)), 0.008)), g.sstep(0.0, 0.6, sine(g.sub(x, z), 0.011)))
    torso = g.sstep(0.135, 0.125, ax)   # not the arms
    if OUTFIT == "bikini":
        # triangle top: each triangle's point at her collarbone, base under the bust
        tri_w = g.mul(0.046, g.sstep(1.1, 1.0, z))
        d_tri = front_only(g.mn(g.sub(tri_w, g.abs(g.sub(ax, 0.058))), g.sub(z, 0.998)))
        tri = cov(d_tri)
        under = g.mul(g.band(z, 0.993, 1.003), torso)
        halter_x = g.lerp(0.058, 0.036, g.sstep(1.09, 1.18, z))
        halter = g.mul(g.mul(g.band(g.sub(ax, halter_x), -0.0018, 0.0018), g.mul(g.sstep(1.08, 1.09, z), g.sstep(1.19, 1.18, z))), front)
        neck_tie = g.mul(g.band(z, 1.172, 1.18), g.mul(g.sub(1.0, front), g.sub(1.0, g.sstep(0.065, 0.075, neck_r))))
        # string bottoms cut high over the hips, cheeky at the back
        waist_z = g.add(0.77, g.mul(g.sub(1.0, front), 0.01))
        back_cut = 0.0 if mom else 0.012
        open_z = g.add(0.701, g.mul(g.sstep(0.016, 0.08, ax), g.add(0.068, g.mul(g.sub(1.0, front), back_cut))))
        d_bot = g.mn(g.sub(waist_z, z), g.sub(z, open_z))
        bot = cov(d_bot)
        strings = g.mul(g.band(g.sub(z, waist_z), -0.004, 0.0), torso)
        col = g.mixc(col, MAIN, g.mx(tri, bot))
        col = g.mixc(col, TRIM if mom else TRIM, g.mx(g.mx(under, halter), g.mx(neck_tie, strings)))
        if mom:   # white piping round each triangle
            col = g.mixc(col, TRIM, g.mul(edge(d_tri, 0.0016), tri))
        else:     # silver o-rings at the hips
            ring = g.mul(g.band(g.sqrt(g.add(g.sq(g.sub(ax, 0.085)), g.sq(g.sub(z, 0.766)))), 0.004, 0.006), front)
            col = g.mixc(col, METAL, ring)
        ink = g.mx(edge(d_tri), edge(d_bot))
    elif OUTFIT in ("sheer", "lingerie"):
        lingerie = OUTFIT == "lingerie"
        # bra: plunging cups that come well up over her (top edge 1.07 at the
        # nipple, 1.054 the top of it), low at the centre gore
        cup_top = g.add(1.038, g.mul(0.034, g.sstep(0.008, 0.046, ax)))
        d_cup = front_only(g.mn(g.mn(g.sub(cup_top, z), g.sub(z, 0.996)), g.sub(0.106, ax)))
        cup = cov(d_cup)
        band_ = g.mul(g.band(z, 0.99, 1.002), torso)
        straps = g.mul(g.mul(g.band(ax, 0.058, 0.066), g.sstep(1.06, 1.07, z)), g.sstep(0.2, 0.18, ax))
        if lingerie:
            # thong: a small front panel, the back a strip widening at the waist
            waist_z = g.sub(0.775, g.mul(front, g.mul(0.012, g.sstep(0.05, 0.0, ax))))
            open_f = g.add(0.701, g.mul(g.sstep(0.014, 0.07, ax), 0.072))
            w_back = g.add(0.011, g.mul(0.05, g.sstep(0.74, 0.79, z)))   # wide enough to show going down between fuller cheeks
            d_bot = g.mn(g.sub(waist_z, z), g.lerp(g.sub(w_back, ax), g.sub(z, open_f), front))
            string = g.mul(g.band(g.sub(z, waist_z), -0.004, 0.0), torso)   # round her hips, holding the back strip
        else:
            waist_z = g.add(0.79, g.mul(g.sub(1.0, front), 0.01))
            open_z = g.add(0.701, g.mul(g.sstep(0.018, 0.085, ax), g.add(0.05, g.mul(g.sub(1.0, front), 0.01))))
            d_bot = g.mn(g.sub(waist_z, z), g.sub(z, open_z))
        bot = cov(d_bot)
        if OUTFIT == "sheer":
            if mom:   # a long sheer black slip on thin straps, to below her knees
                d_veil = g.mn(g.mn(g.sub(g.add(1.075, g.mul(0.33, g.band(ax, 0.056, 0.066))), z), g.sub(z, 0.42)), g.sub(g.add(0.13, g.mul(0.07, g.sstep(0.82, 0.78, z))), ax))
                veil = g.mul(cov(d_veil), 0.62)
                pattern = 0.0
            else:     # a short sheer mesh dress with long sleeves, over the set
                neck_z = g.lerp(1.172, 1.4, g.sstep(0.065, 0.09, ax))
                d_veil = g.mn(g.mn(g.sub(neck_z, z), g.sub(z, 0.665)), g.sub(0.47, ax))
                veil = g.mul(cov(d_veil), 0.5)
                pattern = net
            col = g.mixc(col, MAIN, g.mx(g.mx(cup, band_), bot))
            col = g.mixc(col, DARK, g.mul(straps, g.sub(1.0, cup)))
            col = g.mixc(col, SHEER_C, g.mul(veil, g.sub(1.0, g.mul(g.mx(cup, bot), 0.4))))
            col = g.mixc(col, SHEER_C, g.mul(g.mul(cov(d_veil), pattern), 0.6))
            if not mom:   # striped thigh-highs
                d_socks = g.mn(g.sub(0.58, z), g.sub(z, 0.12))
                socks = cov(d_socks)
                col = g.mixc(col, MAIN, socks)
                col = g.mixc(col, TRIM, g.mul(socks, g.sstep(-0.15, 0.15, sine(z, 0.03))))
                ink = edge(d_socks)
            ink = g.mx(ink, g.mx(g.mx(edge(d_cup), edge(d_bot)), g.mul(edge(d_veil), 0.5)))
        else:
            # garter belt, suspenders, stockings with lace tops
            garter = g.mul(g.band(z, 0.8, 0.835), torso)
            susp = g.mul(g.band(g.abs(g.sub(ax, 0.07)), 0.0, 0.0025), g.band(z, 0.585, 0.8))
            d_stock = g.mn(g.sub(0.6, z), g.sub(z, 0.12))
            stock = cov(d_stock)
            lace_top = g.mul(g.band(z, 0.565, 0.6), stock)
            col = g.mixc(col, SHEER_C, g.mul(stock, 0.6))
            if not mom:
                col = g.mixc(col, MAIN, g.mul(g.mul(stock, net), 0.9))
            col = g.mixc(col, LACE_A, g.mx(g.mx(cup, bot), g.mx(garter, lace_top)))
            col = g.mixc(col, LACE_B, g.mul(lace, g.mx(g.mx(cup, garter), lace_top)))
            col = g.mixc(col, LACE_A, g.mx(g.mx(band_, straps), g.mx(susp, string)))
            if not mom:   # a strappy harness over her chest
                # two straps from her cups slanting in to the choker's o-ring, and one across
                strap_x = g.lerp(0.031, 0.008, g.sstep(1.06, 1.18, z))
                up = g.mul(g.band(g.sub(ax, strap_x), -0.003, 0.003), g.mul(g.sstep(1.05, 1.06, z), g.sstep(1.19, 1.18, z)))
                harness = g.mul(g.mx(g.mul(g.band(z, 1.105, 1.112), front), up), g.mul(g.sstep(0.0, -0.012, y), torso))
                col = g.mixc(col, MAIN, harness)
            ink = g.mx(g.mx(edge(d_cup), edge(d_bot)), edge(d_stock))
    else:   # tight
        # a thong bodysuit: very high cut at the front, a strip at the back
        open_f = g.add(0.701, g.mul(g.sstep(0.016, 0.09, ax), 0.09))
        w_back = g.add(0.008, g.mul(0.06, g.sstep(0.8, 0.86, z)))
        d_legs = g.lerp(g.sub(w_back, ax), g.sub(z, open_f), front)
        if mom:
            # halter neck, plunging V nearly to the navel, open sides, backless
            neck_z = g.lerp(1.17, 1.4, g.sstep(0.05, 0.06, ax))
            v_half = g.add(0.006, g.mul(g.mx(g.sub(z, 0.86), 0.0), 0.15))   # 0.034 at the nipple: 0.017 clear of it
            d_v = front_only(g.mn(g.sub(v_half, ax), g.sub(z, 0.9)))   # down to her navel, no further
            # open from under her arm to her waist into the bare back, and round
            # the outside of her bust (0.017 clear of the nipple)
            # (an oval opening, widest at 1.015, closing in curves above and below)
            side = g.sub(g.mx(g.sub(ax, 0.08), g.add(y, 0.035)), g.mul(0.03, g.sq(g.div(g.sub(z, 1.015), 0.115))))
            backless = g.mul(g.sub(1.0, front), g.sstep(0.855, 0.865, z))
            halter = g.mul(g.band(z, 1.165, 1.178), g.sub(1.0, g.sstep(0.065, 0.075, neck_r)))
            d_suit = g.mn(g.mn(g.sub(neck_z, z), g.sub(0.14, ax)), d_legs)
            suit = g.mul(g.mul(cov(d_suit), g.sub(1.0, cov(d_v))), g.mul(g.sub(1.0, g.sstep(-0.0025, 0.0025, side)), g.sub(1.0, backless)))
            stock = cov(g.mn(g.sub(0.6, z), g.sub(z, 0.12)))
            col = g.mixc(col, SHEER_C, g.mul(stock, 0.55))
            col = g.mixc(col, (0.2, 0.02, 0.03), suit)    # wine red
            col = g.mixc(col, (0.2, 0.02, 0.03), halter)
            sheen = g.mul(g.mul(g.sstep(0.6, 1.0, sine(g.add(x, g.mul(z, 0.2)), 0.07)), 0.25), suit)
            col = g.mixc(col, (0.45, 0.1, 0.12), sheen)
            ink = g.mx(g.mul(edge(d_suit), 1.0), g.mul(g.mx(edge(d_v), edge(side)), suit))
        else:
            # long sleeves and a high neck, a keyhole down her cleavage, the
            # underside of her bust bare below the cups, o-ring at the keyhole
            neck_z = g.lerp(1.176, 1.4, g.sstep(0.065, 0.09, ax))
            key = front_only(g.mn(g.sub(0.016, ax), g.mn(g.sub(z, 1.0), g.sub(1.1, z))))
            under = front_only(g.mn(g.sub(0.04, g.abs(g.sub(ax, 0.058))), g.mn(g.sub(z, 0.972), g.sub(1.0, z))))
            d_suit = g.mn(g.mn(g.sub(neck_z, z), g.sub(0.47, ax)), d_legs)
            suit = g.mul(g.mul(cov(d_suit), g.sub(1.0, cov(key))), g.sub(1.0, cov(under)))
            ring = g.mul(g.band(g.sqrt(g.add(g.sq(x), g.sq(g.sub(z, 1.106)))), 0.005, 0.0075), front)
            seams = g.mul(g.band(g.abs(g.sub(ax, 0.11)), 0.0, 0.0012), suit)
            d_socks = g.mn(g.sub(0.58, z), g.sub(z, 0.12))
            socks = cov(d_socks)
            col = g.mixc(col, MAIN, socks)
            col = g.mixc(col, TRIM, g.mul(socks, g.sstep(-0.15, 0.15, sine(z, 0.03))))
            col = g.mixc(col, MAIN, suit)
            sheen = g.mul(g.mul(g.sstep(0.6, 1.0, sine(g.add(x, g.mul(z, 0.2)), 0.07)), 0.5), suit)
            col = g.mixc(col, (0.06, 0.055, 0.07), sheen)
            col = g.mixc(col, TRIM, seams)
            col = g.mixc(col, METAL, ring)
            ink = g.mx(g.mx(edge(d_suit), g.mul(g.mx(edge(key), edge(under)), suit)), edge(d_socks))
    if not mom:   # her choker, always
        choker = g.mul(g.band(z, 1.178, 1.192), g.sub(1.0, g.sstep(0.065, 0.075, neck_r)))
        col = g.mixc(col, MAIN, choker)
    return g.mixc(col, INK, ink)


def clothes_graph(nt, skin):
    """Each outfit, worked out per pixel from each point's rest position (the
    'rest' attribute). Returns the albedo socket."""
    g = NG(nt)
    at = nt.nodes.new("ShaderNodeAttribute")
    at.attribute_name = "rest"
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(at.outputs["Vector"], sep.inputs[0])
    x, y, z = sep.outputs[0], sep.outputs[1], sep.outputs[2]
    ax = g.abs(x)
    front = g.sub(1.0, g.sstep(-0.045, -0.02, y))
    AA = 0.00045

    def cov(d):
        return g.sstep(-AA, AA, d)

    def edge(d, w=0.0008):
        return g.band(d, 0.0, w)

    def sine(v, period):
        return g.op("SINE", g.mul(v, 2 * math.pi / period))

    def bell(cx, cz, r, mirror=True):
        xx = ax if mirror else x
        return g.op("EXPONENT", g.mul(g.add(g.sq(g.sub(xx, cx)), g.sq(g.sub(z, cz))), -1.0 / (2 * r * r)))
    neck_r = g.sqrt(g.add(g.sq(x), g.sq(g.sub(y, 0.022))))
    if OUTFIT in EXTRA_OUTFITS:
        return extra_outfit(g, skin, x, y, z, ax, front, cov, edge, sine, neck_r)
    # sleeves end at d_cuff = cuff - ax; the upper body starts at d_hem = z - hem
    if WHO == "mom":
        SAGE, SAGE_D, SHIRT, SHEER, SHORTS, BELT, TAG = (0.16, 0.22, 0.14), (0.1, 0.14, 0.09), (0.12, 0.16, 0.24), (0.035, 0.025, 0.02), (0.018, 0.016, 0.018), (0.06, 0.03, 0.015), (0.55, 0.56, 0.58)
        LEG = (0.62, 0.42, 0.35)
        scoop = g.mul(g.mul(0.055, front), g.op("EXPONENT", g.mul(g.sq(g.div(ax, 0.045)), -1.0)))
        neck_z = g.lerp(g.sub(1.168, scoop), 1.4, g.sstep(0.065, 0.09, ax))
        # the shirt and cardigan ride up at the back (4 in. in game, 0.086 here)
        hem_z = g.add(0.755, g.mul(g.sub(1.0, front), 0.086))
        d_top = g.mn(g.mn(g.sub(neck_z, z), g.sub(z, hem_z)), g.sub(0.468, ax))
        top = cov(d_top)
        # the cardigan is open down the front over the shirt
        # only on the front: on the back (front 0) it must stay well outside the opening
        open_ = g.sub(g.mul(front, g.sub(0.024, g.sub(ax, g.mul(g.sub(1.2, z), 0.12)))), g.sub(1.0, front))
        cardi = g.mul(top, g.sub(1.0, cov(open_)))
        rib = g.mul(g.mx(g.band(g.sub(z, hem_z), 0.0, 0.025), g.band(ax, 0.44, 0.468)), cardi)
        knit = g.mul(g.mul(g.sstep(0.6, 0.9, sine(g.add(x, g.mul(z, 0.3)), 0.012)), 0.25), cardi)
        # sheer dark trousers, her skin showing through, over high-cut black
        # shorts (cut higher at the back)
        waist_z = g.add(0.785, g.mul(g.sub(1.0, front), 0.03))   # higher at the back
        d_trousers = g.mn(g.sub(waist_z, z), g.sub(z, 0.12))
        trousers = cov(d_trousers)
        open_z = g.add(0.705, g.mul(g.sub(1.0, front), 0.03))
        d_shorts = g.mn(g.sub(waist_z, z), g.sub(z, open_z))
        shorts = cov(d_shorts)
        belt = g.mul(g.band(g.sub(z, waist_z), -0.02, 0.0), trousers)
        seam = g.mul(g.band(g.abs(y), 0.0, 0.0012), g.mul(trousers, g.sstep(0.055, 0.075, ax)))
        col = g.mixc(skin, SHIRT, top)
        col = g.mixc(col, SAGE, cardi)
        col = g.mixc(col, SAGE_D, g.mx(rib, knit))
        # the preset's skin texture has its stockings painted into the legs:
        # under the sheer fabric her legs are plain skin
        col = g.mixc(col, LEG, g.mul(trousers, g.sstep(0.77, 0.72, z)))
        col = g.mixc(col, SHEER, g.mul(trousers, 0.58))
        col = g.mixc(col, SHEER, g.mul(seam, 0.6))
        col = g.mixc(col, SHORTS, shorts)
        col = g.mixc(col, BELT, belt)
        # his dog tags on a chain, resting on her shirt
        chain = g.mul(g.band(g.sub(z, g.sub(1.16, g.mul(g.sq(g.div(ax, 0.05)), 0.06))), -0.0006, 0.0006), front)
        chain = g.mul(chain, g.sub(1.0, g.sstep(0.045, 0.05, ax)))
        tag = g.mul(g.mul(g.sub(1.0, g.sstep(0.007, 0.008, g.abs(g.sub(x, 0.004)))), g.band(z, 1.075, 1.098)), front)
        tag2 = g.mul(g.mul(g.sub(1.0, g.sstep(0.007, 0.008, g.abs(g.add(x, 0.006)))), g.band(z, 1.071, 1.094)), front)
        col = g.mixc(col, TAG, g.mx(g.mx(chain, tag), tag2))
        ink = g.mx(g.mx(edge(d_top), g.mul(edge(open_), top)), g.mx(g.mul(edge(d_trousers), 0.5), edge(d_shorts)))
        col = g.mixc(col, INK, ink)
        return col
    if WHO == "ophelia":
        return ophelia_outfit(g, skin, x, y, z, ax, front, cov, edge, sine, neck_r)
    # biggie: an old soldier gone gentle. A long rust-red wrap coat crossed
    # left over right with an ochre trim, a cream undershirt in the V, a wide
    # dark sash tied over his belly, his old ribbons still pinned on, loose
    # trousers with the shins wrapped in cloth down into his boots
    RUST, RUST_D, TRIM, UNDER, SASH, TROUSER, WRAP = (0.16, 0.042, 0.026), (0.1, 0.025, 0.016), (0.42, 0.27, 0.07), (0.5, 0.46, 0.37), (0.05, 0.03, 0.022), (0.07, 0.05, 0.034), (0.36, 0.33, 0.27)
    neck_z = g.lerp(1.172, 1.4, g.sstep(0.07, 0.095, ax))
    d_coat = g.mn(g.mn(g.sub(neck_z, z), g.sub(z, 0.70)), g.sub(0.445, ax))
    coat = cov(d_coat)
    # the V: undershirt shows down to where the coat crosses
    v_half = g.mul(g.sub(z, 0.985), 0.28)
    d_v = g.sub(g.mul(front, g.sub(v_half, ax)), g.sub(1.0, front))
    vee = g.mul(cov(d_v), coat)
    v_trim = g.mul(g.mul(g.band(g.sub(ax, v_half), 0.0, 0.009), front), g.mul(g.sstep(0.98, 0.99, z), coat))
    # below the V the right side's edge runs down across him to the sash
    edge_x = g.mul(g.sub(0.985, z), 0.45)
    lap = g.mul(g.mul(g.band(g.sub(x, edge_x), -0.0045, 0.0045), front), g.mul(g.sstep(0.99, 0.98, z), g.sstep(0.70, 0.71, z)))
    cuffs = g.mul(g.band(ax, 0.40, 0.445), coat)
    hem = g.mul(g.band(z, 0.70, 0.722), coat)
    sash = g.mul(g.band(z, 0.825, 0.89), coat)
    knot = g.mul(g.mul(cov(g.sub(0.02, g.sqrt(g.add(g.sq(g.div(g.sub(x, -0.09), 1.0)), g.sq(g.sub(z, 0.857)))))), front), coat)
    tails = g.mul(g.mul(cov(g.mn(g.sub(0.012, g.abs(g.sub(x, -0.095))), g.sub(0.858, z))), g.sstep(0.74, 0.76, z)), front)
    ribbons = g.mul(g.mul(cov(g.mn(g.sub(0.024, g.abs(g.sub(x, 0.075))), g.sub(0.004, g.abs(g.sub(z, 1.06))))), front), coat)
    rib_col = g.mixc(g.mixc((0.5, 0.05, 0.04), (0.04, 0.12, 0.4), g.sstep(0.066, 0.067, x)), (0.6, 0.45, 0.05), g.sstep(0.082, 0.083, x))
    folds = g.mul(g.mul(g.sstep(0.55, 1.0, sine(g.add(x, g.mul(z, 0.15)), 0.05)), 0.35), g.mul(coat, g.sstep(0.89, 0.9, z)))
    d_trousers = g.mn(g.sub(0.75, z), g.sub(z, 0.12))
    trousers = cov(d_trousers)
    wraps = g.mul(cov(g.mn(g.sub(0.33, z), g.sub(z, 0.12))), trousers)
    wrap_lines = g.mul(g.band(g.op("FRACT", g.div(g.add(z, g.mul(x, 0.6)), 0.022)), 0.0, 0.12), wraps)
    col = g.mixc(skin, TROUSER, trousers)
    col = g.mixc(col, WRAP, wraps)
    col = g.mixc(col, g.mixc(WRAP, (0.0, 0.0, 0.0, 1), 0.35), wrap_lines)
    col = g.mixc(col, RUST, coat)
    col = g.mixc(col, RUST_D, folds)
    col = g.mixc(col, UNDER, vee)
    col = g.mixc(col, TRIM, g.mx(g.mx(v_trim, lap), g.mx(cuffs, hem)))
    col = g.mixc(col, SASH, g.mx(sash, g.mx(knot, tails)))
    col = g.mixc(col, rib_col, ribbons)
    ink = g.mx(g.mx(edge(d_coat), g.mul(edge(d_v), coat)), g.mx(edge(d_trousers), g.mul(g.mx(g.band(z, 0.823, 0.827), g.band(z, 0.888, 0.892)), coat)))
    col = g.mixc(col, INK, ink)
    return col


def bake_body(body, skin_img):
    """Bakes the painted clothes over the skin into body.png, and each of the
    character's other outfits (OUTFITS) into body_<outfit>.png."""
    global OUTFIT, LEG_SKIN
    # plain leg skin: the mean of her skin over the thighs (rest z 0.64..0.68)
    px = read_px(skin_img)
    h, w = px.shape[:2]
    rest = body.data.attributes["rest"].data
    uvl = body.data.uv_layers.active.data
    picks = []
    for poly in body.data.polygons:
        for li, vi in zip(poly.loop_indices, poly.vertices):
            if 0.64 < rest[vi].vector.z < 0.68:
                u, v = uvl[li].uv
                picks.append(px[min(h - 1, int(v * h)), min(w - 1, int(u * w)), :3])
    if picks:
        LEG_SKIN = tuple(float(c) for c in to_lin(np.median(np.array(picks), axis=0)))
        print("leg skin", LEG_SKIN)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 4
    sc.cycles.device = "CPU"
    sc.cycles.use_denoising = False
    sc.render.bake.margin = 8
    skin_slot = mat_index(body, "Body_00_SKIN")
    m = bpy.data.materials.new("bake_body")
    m.use_nodes = True
    for i in skin_slot:
        body.material_slots[i].material = m
    for o in bpy.data.objects:
        o.select_set(o == body)
    bpy.context.view_layer.objects.active = body
    outfits = OUTFITS.get(WHO, ["default"])
    for k, outfit in enumerate(outfits):
        OUTFIT = outfit
        nt = m.node_tree
        nt.nodes.clear()
        uv = nt.nodes.new("ShaderNodeUVMap")
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = skin_img
        nt.links.new(uv.outputs[0], t.inputs[0])
        col = clothes_graph(nt, t.outputs["Color"])
        em = nt.nodes.new("ShaderNodeEmission")
        out = nt.nodes.new("ShaderNodeOutputMaterial")
        nt.links.new(em.outputs[0], out.inputs[0])
        nt.links.new(col, em.inputs[0])
        name = "body" if k == 0 else "body_" + outfit
        img = bpy.data.images.new(name, 2048, 2048, alpha=False)
        node = nt.nodes.new("ShaderNodeTexImage")
        node.image = img
        nt.nodes.active = node
        bpy.ops.object.bake(type="EMIT")
        img.filepath_raw = os.path.join(TEX_OUT, name + ".png")
        img.file_format = "PNG"
        img.save()
        print("baked", name)
    OUTFIT = outfits[0]


def textures(objs, boots):
    """Every surface's texture into assets/textures/npc/<who>/, and plain
    materials named npc_<who>_<surface> for the importer."""
    tex_of = E["tex_of"]
    face = bpy.data.objects["Face"]
    body = bpy.data.objects["Body"]
    hair = bpy.data.objects.get("Hair")
    plan = []
    P = "npc_%s_" % WHO
    for i, m in enumerate(face.data.materials):
        img = tex_of(m)
        if "Face_00_SKIN" in m.name:
            write_png(face_paint(face, img), "face")
            plan.append((face, i, "face"))
        elif "FaceBrow" in m.name:
            px = read_px(img).copy()
            px[..., :3] = to_srgb(np.array({"mom": (0.07, 0.016, 0.012), "ophelia": (0.01, 0.01, 0.014), "biggie": (0.5, 0.48, 0.45)}[WHO]))
            px[..., 3] = ss(0.12, 0.45, px[..., 3])
            write_png(px, "brow")
            plan.append((face, i, "brow"))
        elif "FaceEyeline" in m.name or "FaceEyelash" in m.name:
            px = read_px(img).copy()
            px[..., :3] = to_srgb(to_lin(px[..., :3]) * np.array({"mom": (0.4, 0.28, 0.26), "ophelia": (0.3, 0.2, 0.28), "biggie": (0.4, 0.33, 0.3)}[WHO]))
            if WHO == "biggie":   # a lighter, plainer lash line
                px[..., 3] *= 0.55
            name = "eyeline" if "Eyeline" in m.name else "lash"
            write_png(px, name)
            plan.append((face, i, name))
        elif "EyeIris" in m.name:
            px = read_px(img).copy()
            # mom: Eco's pale blue gone a touch grey; ophelia: dull grey-green; biggie: tired brown
            target = {"mom": (0.25, 0.42, 0.55), "ophelia": (0.25, 0.32, 0.28), "biggie": (0.2, 0.12, 0.06)}[WHO]
            L = lum(to_lin(px[..., :3]))[..., None]
            px[..., :3] = to_srgb(np.clip(L * 1.6, 0, 1.4) * np.array(target))
            write_png(px, "iris")
            plan.append((face, i, "iris"))
        else:
            key = next(k for k in ("FaceMouth", "EyeHighlight", "EyeWhite") if k in m.name)
            name = {"FaceMouth": "mouth", "EyeHighlight": "eye_glint", "EyeWhite": "eye_white"}[key]
            px = read_px(img).copy()
            if name == "eye_glint" and WHO == "ophelia":   # dull, flat eyes: no sparkle
                px[..., 3] = 0.0
            write_png(px, name)
            plan.append((face, i, name))
    if hair:
        for i, m in enumerate(hair.data.materials):
            if i >= 3:   # ophelia's streak: a copy of the fringe material
                write_png(dye(read_px(tex_of(m)), SPEC["streak"]), "hair_streak")
                plan.append((hair, i, "hair_streak"))
            elif "HAIR_01" in m.name:
                write_png(dye(read_px(tex_of(m)), SPEC["hair"]), "hair")
                plan.append((hair, i, "hair"))
            elif "HAIR_02" in m.name:
                write_png(dye(read_px(tex_of(m)), SPEC["hair"]), "hair_fringe")
                plan.append((hair, i, "hair_fringe"))
    for i, m in enumerate(body.data.materials):
        if m and "HairBack" in m.name:
            px = dye(read_px(tex_of(m)), SPEC["hair"])
            if WHO == "biggie":   # silver, combed back: a little flatter than the preset's shine
                px[..., :3] = np.clip(px[..., :3] * 0.7 + 0.2, 0, 1)
            write_png(px, "hair_cap")
            plan.append((body, i, "hair_cap"))
    for i, m in enumerate(boots.data.materials):
        if m and "Shoes" in m.name:
            px = read_px(tex_of(m)).copy()
            t = lum(to_lin(px[..., :3]))[..., None]
            lo, hi = {"mom": ((0.02, 0.01, 0.005), (0.2, 0.11, 0.06)), "ophelia": ((0.004, 0.004, 0.006), (0.06, 0.06, 0.075)),
                      "biggie": ((0.012, 0.01, 0.008), (0.12, 0.1, 0.075))}[WHO]
            px[..., :3] = to_srgb(np.array(lo) * (1 - t) + np.array(hi) * t)
            write_png(px, "boots")
            plan.append((boots, i, "boots"))
    if WHO == "biggie":
        # beard strands: grey with darker streaks running down
        rng = np.random.default_rng(5)
        strands = np.repeat(rng.random((1, 256)), 256, axis=0)
        v = 0.6 + 0.05 * strands
        px = np.ones((256, 256, 4), np.float32)
        px[..., :3] = to_srgb(ramp(v, SPEC["hair"]))
        write_png(px, "beard")
    skin_m = body.data.materials[next(iter(mat_index(body, "Body_00_SKIN")))]
    px = read_px(tex_of(skin_m)).copy()
    hole = E["dilate"](px[..., :3].mean(-1) < 150 / 255, 5)
    px[..., :3] = E["fill_holes"](px[..., :3], hole)
    px = skin_tone(px)
    clean = write_png(px, "body_skin_src")
    bake_body(body, clean)
    os.remove(os.path.join(TEX_OUT, "body_skin_src.png"))
    plan.append((body, next(iter(mat_index(body, "bake_body"))), "body"))
    for ob, i, name in plan:
        ob.material_slots[i].material = new_mat(P + name)
    for ob in objs:
        if ob.type != "MESH":
            continue
        bpy.context.view_layer.objects.active = ob
        for o in bpy.data.objects:
            o.select_set(o == ob)
        bpy.ops.object.material_slot_remove_unused()


# --- rig, poses ----------------------------------------------------------------------------

def prune_bones(arm):
    E["prune_bones"](arm)
    if WHO == "biggie":   # no bust to bounce, no hair to swing
        bpy.context.view_layer.objects.active = arm
        bpy.ops.object.mode_set(mode="EDIT")
        eb = arm.data.edit_bones
        for e in [e for e in eb if "Bust" in e.name or e.name.startswith("J_Sec_Hair")]:
            eb.remove(e)
        bpy.ops.object.mode_set(mode="OBJECT")
        names = {b.name for b in arm.data.bones}
        for ob in arm.children:
            for g in list(ob.vertex_groups):
                if g.name.startswith("J_Sec_") and g.name not in names:
                    ob.vertex_groups.remove(g)


def stance():
    """Each character's resting pose, in the rig's final space (facing +Y,
    their right is +X), as Eco's builder's pose dict."""
    p = E["base_pose"]()
    add = E["add"]
    if WHO == "mom":
        # hands clasped in front of her, head tipped to one side: concerned
        add(p, "upperarm.R", X, 14)
        add(p, "upperarm.L", X, 14)
        add(p, "forearm.R", X, 72)
        add(p, "forearm.L", X, 72)
        add(p, "forearm.R", Z, 38)
        add(p, "forearm.L", Z, -38)
        add(p, "head", Y, 6)
        add(p, "head", X, -5)
        add(p, "hips", Y, -2)
    elif WHO == "ophelia":
        # slouched, shoulders in, head down and to the side, weight on one leg
        add(p, "spine", X, -6)
        add(p, "chest", X, -5)
        add(p, "neck", X, -6)
        add(p, "head", X, -8)
        add(p, "head", Y, -9)
        add(p, "hips", Y, 5)
        add(p, "thigh.L", Y, -4)
        add(p, "thigh.R", Y, 3)
        add(p, "shin.R", X, -10)
        add(p, "thigh.R", X, 6)
        add(p, "upperarm.R", Y, 4)
        add(p, "upperarm.L", Y, -4)
        add(p, "forearm.R", X, 10)
        add(p, "forearm.L", X, 10)
    else:
        # at ease: upright, belly out, hands folded on top of it, head tilted
        # a little, the way a man listens who has time for you
        add(p, "upperarm.R", Y, -14)
        add(p, "upperarm.L", Y, 14)
        add(p, "upperarm.R", X, 10)
        add(p, "upperarm.L", X, 10)
        add(p, "forearm.R", X, 70)
        add(p, "forearm.L", X, 70)
        add(p, "forearm.R", Z, 40)
        add(p, "forearm.L", Z, -40)
        add(p, "spine", X, 3)
        add(p, "head", Y, -5)
        add(p, "head", X, -3)
    return p


def make_actions(arm):
    """idle: a slow breathing loop in their own stance; talk: the same with a
    gesture, played while they speak."""
    arm.animation_data_create()
    bpy.context.scene.render.fps = 30
    BONE, ORDER, FINGERS = E["BONE"], E["ORDER"], E["FINGERS"]
    keyed = [BONE[n] for n in ORDER] + ["J_Bip_%s_%s%d" % (s, f, j) for s in "RL" for f in FINGERS + ("Thumb",) for j in (1, 2, 3)]
    add = E["add"]
    for name, n in (("idle", 120), ("talk", 90)):
        a = bpy.data.actions.new(name)
        arm.animation_data.action = a
        for f in range(0, n + 1, 6):
            t = f / n * 2 * math.pi
            p = stance()
            breath = math.sin(t * 2) if name == "idle" else math.sin(t * 3)
            add(p, "chest", X, -1.2 * breath)
            add(p, "head", Z, (5 if name == "idle" else 3) * math.sin(t))
            if name == "talk":
                g = 0.5 - 0.5 * math.cos(t)
                if WHO == "ophelia":   # a lazy shrug
                    add(p, "upperarm.R", Y, 6 * g)
                    add(p, "upperarm.L", Y, -6 * g)
                    add(p, "head", Y, 5 * g)
                else:   # one hand comes up as they explain
                    add(p, "upperarm.L", X, 18 * g)
                    add(p, "upperarm.L", Y, -10 * g)
                    add(p, "forearm.L", X, 40 * g)
                add(p, "head", X, -3 * math.sin(t * 2))
            p["_hips_loc"] = E["hips_loc"](0.002 * breath, 0)
            E["key_pose"](arm, f, p, keyed)
        for fc in a.fcurves:
            for kp in fc.keyframe_points:
                kp.interpolation = "BEZIER"
    arm.animation_data.action = bpy.data.actions["idle"]


# --- concept renders (Eevee, cel-shaded, ink outlines) ------------------------------------

def cel(nt, col, shade_tint, alpha=None, rim=0.22):
    g = NG(nt)
    N, L = nt.nodes.new, nt.links.new
    out = N("ShaderNodeOutputMaterial")
    dif = N("ShaderNodeBsdfDiffuse")
    s2r = N("ShaderNodeShaderToRGB")
    L(dif.outputs[0], s2r.inputs[0])
    bw = N("ShaderNodeRGBToBW")
    L(s2r.outputs["Color"], bw.inputs[0])
    rp = N("ShaderNodeValToRGB")
    L(bw.outputs[0], rp.inputs[0])
    e = rp.color_ramp.elements
    rp.color_ramp.interpolation = "EASE"
    e[0].position, e[0].color = 0.16, (0, 0, 0, 1)
    e[1].position, e[1].color = 0.24, (1, 1, 1, 1)
    mul = N("ShaderNodeMix")
    mul.data_type = "RGBA"
    mul.blend_type = "MULTIPLY"
    mul.inputs[0].default_value = 1.0
    L(col, mul.inputs[6])
    mul.inputs[7].default_value = (*shade_tint, 1)
    lit = g.mixc(mul.outputs[2], col, rp.outputs[0])
    lw = N("ShaderNodeLayerWeight")
    lw.inputs[0].default_value = 0.35
    rr = g.sstep(0.72, 0.9, lw.outputs["Facing"])
    addn = N("ShaderNodeMix")
    addn.data_type = "RGBA"
    addn.blend_type = "ADD"
    L(g.mul(rr, rim), addn.inputs[0])
    L(lit, addn.inputs[6])
    addn.inputs[7].default_value = (1, 0.97, 0.95, 1)
    em = N("ShaderNodeEmission")
    L(addn.outputs[2], em.inputs[0])
    if alpha is not None:
        tr = N("ShaderNodeBsdfTransparent")
        ms = N("ShaderNodeMixShader")
        L(alpha, ms.inputs[0])
        L(tr.outputs[0], ms.inputs[1])
        L(em.outputs[0], ms.inputs[2])
        L(ms.outputs[0], out.inputs[0])
    else:
        L(em.outputs[0], out.inputs[0])


SHADE = {"face": (1.0, 0.93, 0.92), "body": (0.85, 0.7, 0.74), "hair": (0.62, 0.55, 0.7)}
ALPHA = ("brow", "eyeline", "lash", "eye_glint", "hair", "hair_fringe", "hair_streak", "mouth", "iris", "eye_white")


def concept_materials():
    for m in bpy.data.materials:
        if not m.name.startswith("npc_"):
            continue
        part = m.name[len("npc_%s_" % WHO):]
        path = os.path.join(TEX_OUT, part + ".png")
        m.use_nodes = True
        nt = m.node_tree
        nt.nodes.clear()
        if os.path.exists(path):
            t = nt.nodes.new("ShaderNodeTexImage")
            t.image = bpy.data.images.load(path)
            col, alpha = t.outputs["Color"], (t.outputs["Alpha"] if part in ALPHA else None)
        else:
            rgb = nt.nodes.new("ShaderNodeRGB")
            rgb.outputs[0].default_value = (*m.diffuse_color[:3], 1)
            col, alpha = rgb.outputs[0], None
        if alpha is not None:
            m.blend_method = "HASHED"
            m.shadow_method = "HASHED"
        kind = "hair" if part.startswith(("hair", "beard")) else ("face" if part in ("face", "brow", "eyeline", "lash", "iris", "eye_white", "eye_glint", "mouth") else "body")
        cel(nt, col, SHADE[kind], alpha=alpha, rim=0.0 if kind == "face" and part != "face" else 0.22)


def outlines(objs):
    ink = bpy.data.materials.new("ink")
    ink.use_nodes = True
    nt = ink.node_tree
    nt.nodes.clear()
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs[0].default_value = (0.05, 0.03, 0.045, 1)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(em.outputs[0], out.inputs[0])
    ink.use_backface_culling = True
    face = bpy.data.objects["Face"]
    vg = face.vertex_groups.new(name="ink_skin")
    skin_idx = [i for i, m in enumerate(face.data.materials) if m.name.endswith("_face")]
    vg.add([v for p in face.data.polygons if p.material_index in skin_idx for v in p.vertices], 1.0, "REPLACE")
    for o in objs:
        if o.type != "MESH" or o.name in ("Boots", "LipRing"):
            continue
        th, group = {"Body": (0.0014, None), "Hair": (0.0009, None), "Face": (0.0009, "ink_skin"), "Beard": (0.0014, None)}.get(o.name, (0.001, None))
        o.data.materials.append(ink)
        s = o.modifiers.new("ink", "SOLIDIFY")
        s.thickness = th
        s.offset = 1.0
        s.use_flip_normals = True
        s.use_rim = False
        s.material_offset = len(o.data.materials) - 1
        if group:
            s.vertex_group = group
            s.thickness_vertex_group = 0.0


def concept(arm, objs):
    concept_materials()
    outlines(objs)
    face = bpy.data.objects["Face"]
    for k, v in SPEC["face"].items():
        face.data.shape_keys.key_blocks[k].value = v
    arm.animation_data.action = bpy.data.actions["idle"]
    sc = bpy.context.scene
    sc.frame_set(0)
    sc.render.engine = "BLENDER_EEVEE"
    sc.eevee.taa_render_samples = 32
    sc.view_settings.view_transform = "Standard"
    w = bpy.data.worlds.new("w")
    sc.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.16, 0.165, 0.19, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    key = bpy.data.lights.new("key", "SUN")
    key.energy = 3.2
    ko = bpy.data.objects.new("key", key)
    sc.collection.objects.link(ko)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    H = SPEC["height"]
    hb = arm.pose.bones["J_Bip_C_Head"]
    head = arm.matrix_world @ hb.head
    head_up = (arm.matrix_world.to_3x3() @ (hb.tail - hb.head)).normalized()   # follows a bowed head
    # they face +Y here
    shots = []
    for name, d, at, lens, res in (
            ("front", Vector((0, 1, 0.05)), Vector((0, 0, H * 0.52)), 50, (800, 1300)),
            ("q34", Vector((-0.55, 0.85, 0.07)), Vector((0, 0, H * 0.52)), 50, (800, 1300)),
            ("back", Vector((0.35, -0.94, 0.06)), Vector((0, 0, H * 0.52)), 50, (800, 1300)),
            ("face", Vector((-0.25, 1, -0.12 if WHO == "ophelia" else 0.02)), head + head_up * (0.085 * H / 1.66), 85, (1000, 1000))):
        shots.append((name, d, at, lens, res))

    def shoot(name, d, at, lens, res, prefix):
        d = d.normalized()
        if name == "face":
            dist = 0.75 * H / 1.66
        else:
            fov = 2 * math.atan(18 / lens)
            dist = H * 1.1 / 2 / math.tan(fov / 2)
        cam.location = at + d * dist
        cam.data.lens = lens
        cam.rotation_euler = (at - cam.location).to_track_quat("-Z", "Y").to_euler()
        az = math.atan2(d.y, d.x)
        ko.rotation_euler = (math.radians(52), 0, az + math.radians(90 + 35))
        sc.render.resolution_x, sc.render.resolution_y = res
        sc.render.filepath = "%s_%s.png" % (prefix, name)
        bpy.ops.render.render(write_still=True)
    for shot in shots:
        shoot(*shot, CONCEPT)
    # the other outfits: the body texture swapped, full-length shots only
    tex = next((n for n in bpy.data.materials["npc_%s_body" % WHO].node_tree.nodes if n.type == "TEX_IMAGE"), None)
    for outfit in OUTFITS.get(WHO, [])[1:]:
        tex.image = bpy.data.images.load(os.path.join(TEX_OUT, "body_%s.png" % outfit))
        for shot in shots[:3]:
            shoot(*shot, "%s_%s" % (CONCEPT, outfit))


def main():
    os.makedirs(TEX_OUT, exist_ok=True)
    E["HEIGHT"], E["HEAD_SCALE"], E["LEG_SCALE"] = SPEC["height"], SPEC["head"], SPEC["legs"]
    arm = E["setup_scene"]()
    E["remove_fox_parts"]()
    boots = strip_clothes()
    {"mom": hair_mom, "ophelia": hair_ophelia, "biggie": hair_biggie}[WHO]()
    {"mom": face_mom, "ophelia": face_ophelia, "biggie": face_biggie}[WHO]()
    if WHO == "biggie":
        body_biggie(arm)
    else:
        {"mom": body_mom, "ophelia": body_ophelia}[WHO]()
        E["glute_bones"](arm)   # jiggle springs, as Eco's
    extras = []
    if WHO == "biggie":
        extras.append(beard(arm))
        extras.append(topknot(arm))
    if WHO == "ophelia":
        extras.append(lip_ring(arm))
        extras.append(nipple_bars(arm))
    if WHO == "mom":   # fuller than Ophelia's, no bars: they show through everything she wears
        extras.append(nipple_bars(arm, bars=False, r=0.0068, h=0.0066))
    objs = [bpy.data.objects[n] for n in ("Body", "Face", "Hair") if n in bpy.data.objects] + [boots] + extras
    textures(objs, boots)
    if WHO == "biggie":
        beard_m = bpy.data.materials["npc_biggie_beard"]
        bpy.data.objects["Beard"].material_slots[0].material = beard_m
        bpy.data.objects["Topknot"].material_slots[0].material = beard_m
    if WHO in ("ophelia", "mom"):
        bpy.data.objects["Piercings"].material_slots[0].material = bpy.data.materials["npc_%s_body" % WHO]
    prune_bones(arm)
    E["proportions"](arm, objs)
    E["face_forward_and_scale"](arm, objs)
    make_actions(arm)
    if CONCEPT:
        concept(arm, objs)
    if EXPORT:
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
