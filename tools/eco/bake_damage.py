"""Bakes Eco's battle damage maps from assets/models/eco/eco.glb (numpy + pillow,
no Blender): for every texel of her body and face textures, where on her that
texel sits in rest space, and from that when (how far into a run) it gets dirty,
scuffed, torn or scarred. The shader (assets/shaders/eco_toon.gdshaderinc,
damage_kind) compares the run's levels (scripts/ps2/battle_damage.gd) with them.

    python3 tools/eco/bake_damage.py            # writes the two maps
    python3 tools/eco/bake_damage.py --preview out_dir   # plus UV-space previews

Each channel holds the level (0..1, as 0..255) at which that texel turns:
    R  grime  (dirt from the ground up, soot, sweat smears)
    G  torn   (the suit rips open, showing skin; Mature only)
    B  scuffed (abraded, paler fabric: knees, elbows, hips, shoulders)
    A  scarred (fresh cuts and scratches on skin; Mature only)
255 means never. The face map uses R and A only. A third, one-channel map
(v_damage_slide.png) is where sliding wears her suit through: the outsides of
her thighs, the outer parts of her glutes and her hips (SLIDE_TEARS, SLIDE_OK).

Tears and scars can only land where TEAR_OK allows: her arms, legs below
mid-thigh, shoulders, upper back, flanks and a strip of stomach. Everything
round her chest and between her hips and thighs is locked out, a long way
clear of the always-covered zones (memory vesper-limits: a 2.2 cm disc round
each bust apex, the groin, between the legs, the back cleft). check_zones()
fails the bake if any texel near those zones could ever tear.

Rest space is the build's (tools/eco/build_eco_vroid.py): metres before she
was scaled to her height, z up, she faces -y, +x her left. The glb is that
turned to face the other way and scaled by K, in glTF axes.
"""

import json
import os
import struct
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GLB = os.path.join(ROOT, "assets/models/eco/eco.glb")
OUT_BODY = os.path.join(ROOT, "assets/textures/eco/v_damage.png")
OUT_FACE = os.path.join(ROOT, "assets/textures/eco/v_damage_face.png")
OUT_SLIDE = os.path.join(ROOT, "assets/textures/eco/v_damage_slide.png")

# glb metres per rest metre (face_forward_and_scale's k: her bust apex, rest
# z 1.0468, sits at 1.237 in the glb)
K = 1.1817
NEVER = 1.0

# the always-covered zones (vesper-limits), rest space
APEXES = [(0.057, 1.047), (-0.057, 1.047)]
APEX_R = 0.022


# --- glb ----------------------------------------------------------------------

_CT = {5126: np.float32, 5123: np.uint16, 5125: np.uint32, 5121: np.uint8}
_NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def load_glb(path):
    data = open(path, "rb").read()
    n = struct.unpack("<I", data[12:16])[0]
    return json.loads(data[20:20 + n]), data[20 + n + 8:]


def accessor(j, buf, i):
    a = j["accessors"][i]
    v = j["bufferViews"][a["bufferView"]]
    dt, n = _CT[a["componentType"]], _NC[a["type"]]
    off = v.get("byteOffset", 0) + a.get("byteOffset", 0)
    size = np.dtype(dt).itemsize * n
    stride = v.get("byteStride", 0)
    if stride and stride != size:
        raw = np.frombuffer(buf, np.uint8, count=stride * a["count"], offset=off).reshape(a["count"], stride)
        return np.frombuffer(raw[:, :size].tobytes(), dt).reshape(a["count"], n)
    return np.frombuffer(buf, dt, count=a["count"] * n, offset=off).reshape(a["count"], n)


def primitive(j, buf, node, material):
    """Rest-space positions and normals, UVs and triangles of one surface."""
    names = [m["name"] for m in j["materials"]]
    for nd in j["nodes"]:
        if nd.get("name") != node:
            continue
        for p in j["meshes"][nd["mesh"]]["primitives"]:
            if names[p["material"]] == material:
                at = p["attributes"]
                pos = accessor(j, buf, at["POSITION"]).astype(np.float64)
                nrm = accessor(j, buf, at["NORMAL"]).astype(np.float64)
                return (to_rest(pos) / K, to_rest(nrm), accessor(j, buf, at["TEXCOORD_0"]).astype(np.float64),
                        accessor(j, buf, p["indices"]).reshape(-1, 3).astype(np.int64))
    raise SystemExit("no %s/%s in %s" % (node, material, GLB))


def to_rest(v):
    # glTF (X, Y, Z) of the turned model -> rest (x, y, z): x = -X, y = Z, z = Y
    return np.stack([-v[:, 0], v[:, 2], v[:, 1]], axis=1)


def rasterize(pos, nrm, uv, tris, size):
    """Per texel: rest position, normal and whether any triangle covers it."""
    P = np.zeros((size, size, 3))
    N = np.zeros((size, size, 3))
    cover = np.zeros((size, size), bool)
    for t in tris:
        q = uv[t] * size
        x0, y0 = np.maximum(np.floor(q.min(0)).astype(int), 0)
        x1, y1 = np.minimum(np.ceil(q.max(0)).astype(int) + 1, size)
        if x1 <= x0 or y1 <= y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1) + 0.5, np.arange(y0, y1) + 0.5)
        a, b, c = q
        d = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(d) < 1e-12:
            continue
        l1 = ((b[1] - c[1]) * (xs - c[0]) + (c[0] - b[0]) * (ys - c[1])) / d
        l2 = ((c[1] - a[1]) * (xs - c[0]) + (a[0] - c[0]) * (ys - c[1])) / d
        l3 = 1.0 - l1 - l2
        e = -0.6 / max(abs(d), 1.0) ** 0.5   # a hair of overlap so edges have no cracks
        m = (l1 >= e) & (l2 >= e) & (l3 >= e)
        if not m.any():
            continue
        iy, ix = ys[m].astype(int), xs[m].astype(int)
        w = np.stack([l1[m], l2[m], l3[m]], axis=1)
        P[iy, ix] = w @ pos[t]
        N[iy, ix] = w @ nrm[t]
        cover[iy, ix] = True
    N /= np.maximum(np.linalg.norm(N, axis=2, keepdims=True), 1e-9)
    return P, N, cover


# --- noise --------------------------------------------------------------------

def _hash(ix, iy, iz, seed):
    h = (ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791) ^ (seed * 2654435761)
    h = (h ^ (h >> 13)) * 1274126177
    return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0


def value_noise(p, seed=0):
    f = np.floor(p)
    i = f.astype(np.int64)
    t = p - f
    t = t * t * (3.0 - 2.0 * t)
    out = 0.0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (t[..., 0] if dx else 1 - t[..., 0]) * (t[..., 1] if dy else 1 - t[..., 1]) * (t[..., 2] if dz else 1 - t[..., 2])
                out = out + w * _hash(i[..., 0] + dx, i[..., 1] + dy, i[..., 2] + dz, seed)
    return out


def fbm(p, octaves=4, seed=0):
    out, amp, total = 0.0, 1.0, 0.0
    for o in range(octaves):
        out = out + amp * value_noise(p * (2.0 ** o), seed + o * 17)
        total += amp
        amp *= 0.5
    return out / total


def ss(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


# --- where tears may go ---------------------------------------------------------

def tear_ok(P, N):
    """Where the suit may tear and scars may show: well clear of her chest and
    of everything between her hips and mid-thigh."""
    x, z = P[..., 0], P[..., 2]
    ax = np.abs(x)
    back = N[..., 1] > 0.5   # facing straight behind her
    ok = np.ones(x.shape, bool)
    # chest: the whole bust band, front and sides, up to the collarbones
    ok &= ~((z > 0.96) & (z < 1.17) & (ax < 0.17) & ~back)
    # front of her torso below the bust, except a strip of stomach either side of her navel
    stomach = (z > 0.865) & (z < 0.955) & (ax < 0.10)
    ok &= ~((z > 0.60) & (z < 0.98) & (ax < 0.15) & ~back & ~stomach)
    # hips, groin and inner thighs all round, and her glutes and lower back behind
    ok &= ~((z > 0.58) & (z < 0.86) & (ax < 0.15))
    ok &= ~((z > 0.58) & (z < 0.96) & (ax < 0.15) & back)
    # and never within 8 cm of a bust apex (seen from the front or behind)
    for sx, sz in APEXES:
        ok &= np.hypot(x - sx, z - sz) > APEX_R + 0.08
    return ok


def slide_ok(P, N):
    """Where sliding may wear the suit through: like tear_ok, but her upper
    thighs and glutes open up wherever they're 7 cm or more from a covered
    zone (the inside of her thighs and the middle of her glutes stay shut)."""
    x, z = P[..., 0], P[..., 2]
    ax = np.abs(x)
    back = N[..., 1] > 0.3
    ok = ~zone_mask(P, 0.07)
    ok &= ~((z > 0.96) & (z < 1.17) & (ax < 0.17) & ~back)        # chest
    ok &= ~((z > 0.60) & (z < 0.98) & (ax < 0.12) & ~back)        # front of her hips and belly
    for sx, sz in APEXES:
        ok &= np.hypot(x - sx, z - sz) > APEX_R + 0.08
    return ok


def zone_mask(P, pad):
    """The always-covered zones (vesper-limits), grown by `pad` metres."""
    x, y, z = P[..., 0], P[..., 1], P[..., 2]
    ax = np.abs(x)
    m = np.zeros(x.shape, bool)
    for sx, sz in APEXES:
        m |= (np.hypot(x - sx, z - sz) < APEX_R + pad) & (y < 0.02)
    m |= (ax < 0.012 + 0.45 * (z - 0.70) + pad) & (z > 0.712 - pad) & (z < 0.79 + pad) & (y < 0.0)
    m |= (ax < 0.014 + pad) & (z > 0.712 - pad) & (z < 0.74 + pad)
    m |= (ax < 0.012 + pad) & (z > 0.712 - pad) & (z < 0.81 + pad) & (y > 0.0)
    return m


# --- spots ----------------------------------------------------------------------

def spot_level(P, N, centre, normal, axis, r_long, r_short, appear, grow, jag, seed):
    """Level at which each texel is reached by a spot that opens at its centre
    at `appear` and spreads out (over `grow` more level) to an ellipse
    r_long along `axis` and r_short across, on the side `normal` faces."""
    c = np.asarray(centre, float)
    a = np.asarray(axis, float)
    a /= np.linalg.norm(a)
    nrm = np.asarray(normal, float)
    nrm /= np.linalg.norm(nrm)
    d = P - c
    along = d @ a
    across = np.linalg.norm(d - along[..., None] * a, axis=-1)
    r = np.sqrt((along / r_long) ** 2 + (across / r_short) ** 2)
    r = r + jag * (fbm(P * 60.0, 3, seed) - 0.5)
    facing = (N @ nrm) > 0.25
    lvl = appear + grow * r
    return np.where((r < 1.0) & facing, lvl, NEVER)


def scar_level(P, N, p0, p1, normal, width, appear):
    """A thin cut from p0 to p1 (rest space) on the side `normal` faces: drawn
    as seen looking along -normal, so the ends needn't sit exactly on her."""
    nrm = np.asarray(normal, float)
    nrm /= np.linalg.norm(nrm)
    p0, p1 = np.asarray(p0, float), np.asarray(p1, float)
    flat = lambda v: v - (v @ nrm)[..., None] * nrm
    seg = flat(p1 - p0)
    rel = P - p0
    depth = rel @ nrm
    rel = flat(rel)
    t = np.clip((rel @ seg) / (seg @ seg), 0.0, 1.0)
    d = np.linalg.norm(rel - t[..., None] * seg, axis=-1)
    taper = width * (0.35 + 0.65 * np.sin(np.pi * t))  # thin at both ends
    facing = ((N @ nrm) > 0.3) & (np.abs(depth) < 0.04)
    return np.where((d < taper) & facing, appear, NEVER)


FRONT, BACK, LEFT, RIGHT, UP = (0, -1, 0), (0, 1, 0), (1, 0, 0), (-1, 0, 0), (0, 0, 1)
LEG, ARM_L, ARM_R = (0, 0, 1), (1, 0, 0), (-1, 0, 0)

# (centre, facing, long axis, r_long, r_short, appears at, grows over, jag)
TEARS = [
    ((0.069, -0.055, 0.455), FRONT, LEG, 0.050, 0.035, 0.18, 0.30, 0.35),     # left knee
    ((-0.300, 0.000, 1.185), UP, ARM_R, 0.040, 0.026, 0.26, 0.30, 0.35),      # right elbow, outside
    ((-0.075, -0.040, 0.230), FRONT, LEG, 0.045, 0.026, 0.36, 0.30, 0.40),    # right shin
    ((-0.110, 0.000, 0.520), RIGHT, LEG, 0.065, 0.032, 0.42, 0.35, 0.40),     # right outer thigh, low
    ((0.200, 0.000, 1.185), UP, ARM_L, 0.045, 0.028, 0.48, 0.30, 0.35),       # left upper arm, top
    ((-0.069, -0.055, 0.455), FRONT, LEG, 0.040, 0.030, 0.55, 0.30, 0.35),    # right knee
    ((0.130, 0.060, 1.135), BACK, (1, 0, 0.3), 0.045, 0.026, 0.58, 0.30, 0.40),  # left shoulder blade
    ((-0.050, -0.095, 0.905), FRONT, (1, 0, -0.25), 0.040, 0.016, 0.66, 0.25, 0.30),  # stomach slash, right of her navel
    ((0.360, -0.020, 1.135), FRONT, ARM_L, 0.050, 0.022, 0.70, 0.30, 0.40),   # left forearm
    ((0.150, 0.000, 0.700), LEFT, LEG, 0.050, 0.025, 0.76, 0.25, 0.35),       # left flank of her hip (outside only)
    ((0.075, 0.050, 0.300), BACK, LEG, 0.055, 0.028, 0.82, 0.25, 0.40),       # left calf
]

# worn through by sliding (opened by the slide level, not hits)
SLIDE_TEARS = [
    ((0.140, -0.020, 0.690), (1, -0.3, 0), LEG, 0.085, 0.040, 0.10, 0.35, 0.40),     # left outer thigh
    ((-0.140, -0.020, 0.700), (-1, -0.3, 0), LEG, 0.075, 0.038, 0.22, 0.35, 0.40),   # right outer thigh
    ((0.115, 0.060, 0.790), (0.45, 1, 0), (1, 0, 0.35), 0.050, 0.034, 0.32, 0.35, 0.40),   # left glute, outer half
    ((0.155, 0.000, 0.840), LEFT, LEG, 0.050, 0.030, 0.42, 0.30, 0.40),             # left hip
    ((-0.115, 0.060, 0.780), (-0.45, 1, 0), (-1, 0, 0.35), 0.045, 0.030, 0.52, 0.35, 0.40),  # right glute, outer half
    ((0.105, -0.060, 0.580), (0.4, -1, 0), LEG, 0.055, 0.032, 0.60, 0.30, 0.40),     # left thigh, front outer
]

# scuffs: bigger, earlier, and only pale the fabric
SCUFFS = [
    ((0.069, -0.055, 0.455), FRONT, LEG, 0.080, 0.055, 0.05, 0.40, 0.45),
    ((-0.069, -0.055, 0.455), FRONT, LEG, 0.080, 0.055, 0.10, 0.40, 0.45),
    ((0.290, 0.000, 1.170), UP, ARM_L, 0.070, 0.045, 0.15, 0.40, 0.45),
    ((-0.290, 0.000, 1.170), UP, ARM_R, 0.070, 0.045, 0.08, 0.40, 0.45),
    ((0.150, 0.000, 0.780), LEFT, LEG, 0.090, 0.050, 0.20, 0.45, 0.50),
    ((-0.150, 0.000, 0.780), RIGHT, LEG, 0.090, 0.050, 0.25, 0.45, 0.50),
    ((0.120, 0.020, 1.170), UP, ARM_L, 0.070, 0.050, 0.30, 0.40, 0.45),
    ((-0.120, 0.020, 1.170), UP, ARM_R, 0.070, 0.050, 0.35, 0.40, 0.45),
    ((0.075, -0.050, 0.200), FRONT, LEG, 0.080, 0.040, 0.32, 0.40, 0.45),
    ((-0.075, -0.050, 0.200), FRONT, LEG, 0.080, 0.040, 0.40, 0.40, 0.45),
    ((0.000, 0.090, 1.020), BACK, (1, 0, 0), 0.100, 0.060, 0.45, 0.40, 0.50),
    ((0.400, 0.000, 1.140), BACK, ARM_L, 0.060, 0.030, 0.55, 0.35, 0.45),
]

# (from, to, facing, half width, appears at): most sit where the suit tears,
# so they show through it; a few cross bare skin (her arms in some kits)
SCARS = [
    ((0.050, -0.062, 0.475), (0.088, -0.060, 0.440), FRONT, 0.0022, 0.30),     # left knee
    ((-0.315, 0.015, 1.188), (-0.282, 0.012, 1.192), UP, 0.0020, 0.40),        # right elbow
    ((-0.090, -0.040, 0.250), (-0.062, -0.042, 0.205), FRONT, 0.0020, 0.50),   # right shin
    ((-0.070, -0.098, 0.912), (-0.030, -0.102, 0.900), FRONT, 0.0018, 0.80),   # under the stomach slash
    ((0.345, -0.025, 1.130), (0.385, -0.022, 1.140), FRONT, 0.0020, 0.72),     # left forearm
    ((0.355, -0.024, 1.123), (0.380, -0.022, 1.130), FRONT, 0.0016, 0.86),
    ((0.190, 0.010, 1.190), (0.215, 0.005, 1.180), UP, 0.0018, 0.60),          # left upper arm
    ((-0.400, -0.010, 1.150), (-0.430, -0.015, 1.140), FRONT, 0.0018, 0.55),   # right forearm (bare in the mechanic kit)
    ((-0.405, -0.012, 1.160), (-0.432, -0.016, 1.152), FRONT, 0.0014, 0.68),
    ((0.118, 0.068, 1.142), (0.145, 0.064, 1.126), BACK, 0.0020, 0.66),        # left shoulder blade
]


def snap(verts, centre, facing):
    """The point on her surface seen at `centre` when looking along -facing:
    the outermost vertex within 1.5 cm of that line of sight."""
    f = np.asarray(facing, float)
    f /= np.linalg.norm(f)
    rel = verts - np.asarray(centre, float)
    out = rel @ f
    side = np.linalg.norm(rel - out[:, None] * f, axis=1)
    near = side < 0.015
    if not near.any():
        raise SystemExit("bake_damage: nothing of her at %s" % (centre,))
    i = np.where(near)[0][np.argmax(out[near])]
    return verts[i]


def body_maps(P, N, cover, verts):
    x, y, z = P[..., 0], P[..., 1], P[..., 2]
    ax = np.abs(x)
    # grime: from the boots up, then her hands and forearms, elbows and knees,
    # in blotches; sweat and soot last on her chest and back
    n1 = fbm(P * 9.0, 4, 1)
    n2 = fbm(P * 28.0, 3, 5)
    rise = ss(0.05, 1.25, z)
    hands = ss(0.30, 0.47, ax) * (z > 1.0)
    joints = np.exp(-((ax - 0.069) ** 2 + (z - 0.455) ** 2) / 0.004) + np.exp(-((ax - 0.286) ** 2 + (z - 1.145) ** 2) / 0.003)
    grime = 0.12 + 0.62 * rise - 0.30 * hands - 0.18 * joints + 0.55 * (n1 - 0.5) + 0.22 * (n2 - 0.5)
    grime = np.clip(grime, 0.02, 0.97)

    ok = tear_ok(P, N)
    tear = np.full(x.shape, NEVER)
    for i, (c, f, a, rl, rs, ap, gr, jag) in enumerate(TEARS):
        tear = np.minimum(tear, spot_level(P, N, snap(verts, c, f), f, a, rl, rs, ap, gr, jag, 40 + i))
    tear = np.where(ok & (tear < 0.98), tear, NEVER)   # the shader reads 0.99+ as never

    scuff = np.full(x.shape, NEVER)
    for i, (c, f, a, rl, rs, ap, gr, jag) in enumerate(SCUFFS):
        scuff = np.minimum(scuff, spot_level(P, N, snap(verts, c, f), f, a, rl, rs, ap, gr, jag, 80 + i))
    # scratchy streaks through each scuff
    streak = fbm(P * np.array([90.0, 90.0, 12.0]), 2, 9)
    scuff = np.where(scuff < NEVER, np.clip(scuff + 0.25 * (streak - 0.5), 0.0, 0.99), NEVER)

    scar = np.full(x.shape, NEVER)
    for p0, p1, f, w, ap in SCARS:
        scar = np.minimum(scar, scar_level(P, N, p0, p1, f, w, ap))
    scar = np.where(ok, scar, NEVER)

    out = np.stack([grime, tear, scuff, scar], axis=-1)
    out[~cover] = NEVER
    return out


def face_maps(P, N, cover, eyes, mouth):
    x, y, z = P[..., 0], P[..., 1], P[..., 2]
    # keep clear of her eyes and lips
    clear = np.ones(x.shape, bool)
    for e in eyes:
        clear &= np.linalg.norm(P - e, axis=-1) > 0.016
    clear &= np.linalg.norm(P - mouth, axis=-1) > 0.012
    clear &= y < 0.0   # the front of her face only
    n1 = fbm(P * 70.0, 3, 21)
    lvl = np.full(x.shape, NEVER)
    smudges = [  # (centre, rx, rz, appears at)
        ((0.042, -0.070, 1.262), 0.016, 0.009, 0.25),   # left cheek smear
        ((-0.020, -0.082, 1.222), 0.016, 0.008, 0.45),  # chin
        ((-0.035, -0.080, 1.328), 0.020, 0.010, 0.60),  # right side of her forehead
        ((-0.050, -0.065, 1.255), 0.012, 0.008, 0.75),  # right cheek
    ]
    for c, rx, rz, ap in smudges:
        r = np.hypot((x - c[0]) / rx, (z - c[2]) / rz) + 0.5 * (n1 - 0.5)
        lvl = np.minimum(lvl, np.where(r < 1.0, ap + 0.3 * r, NEVER))
    grime = np.where(clear, np.clip(lvl, 0.0, NEVER), NEVER)
    scar = np.full(x.shape, NEVER)
    for p0, p1, w, ap in [
        ((0.048, -0.075, 1.318), (0.062, -0.068, 1.308), 0.0011, 0.45),   # through her left brow's outer end
        ((-0.058, -0.064, 1.268), (-0.044, -0.070, 1.262), 0.0010, 0.75),  # right cheekbone
    ]:
        scar = np.minimum(scar, scar_level(P, N, p0, p1, FRONT, w, ap))
    scar = np.where(clear, scar, NEVER)
    out = np.stack([grime, np.full(x.shape, NEVER), np.full(x.shape, NEVER), scar], axis=-1)
    out[~cover] = NEVER
    return out


def pad(img, cover, iters=4):
    """Grows each island's edge values out into the gap round it, so filtering
    at an island's edge only ever mixes in its own values."""
    img, cover = img.copy(), cover.copy()
    for _ in range(iters):
        grown = cover.copy()
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            src = np.roll(np.roll(cover, dy, 0), dx, 1)
            fill = src & ~grown
            img[fill] = np.roll(np.roll(img, dy, 0), dx, 1)[fill]
            grown |= fill
        cover = grown
    return img


def slide_map(P, N, cover, verts):
    lvl = np.full(P.shape[:2], NEVER)
    for i, (c, f, a, rl, rs, ap, gr, jag) in enumerate(SLIDE_TEARS):
        lvl = np.minimum(lvl, spot_level(P, N, snap(verts, c, f), f, a, rl, rs, ap, gr, jag, 120 + i))
    lvl = np.where(slide_ok(P, N) & (lvl < 0.98) & cover, lvl, NEVER)
    return lvl


def check_zones(P, cover, maps, slide=None):
    """The bake fails if anything within 6 cm of an always-covered zone could
    ever tear or scar."""
    near = zone_mask(P, 0.06) & cover
    bad = near & ((maps[..., 1] < NEVER) | (maps[..., 3] < NEVER))
    if slide is not None:
        bad |= near & (slide < NEVER)
    if bad.any():
        raise SystemExit("bake_damage: %d texels near a covered zone could tear" % int(bad.sum()))
    return int(near.sum())


def save(maps, path):
    img = np.clip(np.round(maps * 255.0), 0, 255).astype(np.uint8)
    Image.fromarray(img, "RGBA").save(path, optimize=True)
    print("wrote", os.path.relpath(path, ROOT))


def preview(maps, P, cover, out_dir, name):
    os.makedirs(out_dir, exist_ok=True)
    for lvl in (0.25, 0.5, 0.75, 1.0):
        rgb = np.full(maps.shape[:2] + (3,), 40, np.uint8)
        rgb[cover] = (150, 150, 165)
        rgb[maps[..., 2] < lvl] = (205, 205, 215)
        rgb[maps[..., 0] < lvl] = (rgb[maps[..., 0] < lvl] * 0.55).astype(np.uint8)
        rgb[maps[..., 1] < lvl] = (240, 200, 180)
        rgb[maps[..., 3] < lvl] = (200, 30, 40)
        rgb[zone_mask(P, 0.0) & cover] = (0, 0, 0)
        Image.fromarray(rgb).save(os.path.join(out_dir, "%s_%03d.png" % (name, int(lvl * 100))))


def main():
    j, buf = load_glb(GLB)
    pos, nrm, uv, tris = primitive(j, buf, "Body", "eco_v_body")
    P, N, cover = rasterize(pos, nrm, uv, tris, 1024)
    body = body_maps(P, N, cover, pos)
    slide = slide_map(P, N, cover, pos)
    near = check_zones(P, cover, body, slide)
    print("body: %d texels, %d near the covered zones (none can tear)" % (int(cover.sum()), near))
    save(pad(body, cover), OUT_BODY)
    img = np.clip(np.round(pad(slide[..., None], cover)[..., 0] * 255.0), 0, 255).astype(np.uint8)
    Image.fromarray(img, "L").save(OUT_SLIDE, optimize=True)
    print("wrote", os.path.relpath(OUT_SLIDE, ROOT))

    fpos, fnrm, fuv, ftris = primitive(j, buf, "Face", "eco_v_face")
    eyes = []
    epos, _, _, _ = primitive(j, buf, "Face", "eco_v_eye_white")
    for side in (1, -1):
        pts = epos[epos[:, 0] * side > 0]
        eyes.append(pts.mean(0))
    mpos, _, _, _ = primitive(j, buf, "Face", "eco_v_mouth")
    front = mpos[mpos[:, 1] < np.percentile(mpos[:, 1], 30)]   # her lips, not the inside of her mouth
    FP, FN, fcover = rasterize(fpos, fnrm, fuv, ftris, 512)
    face = face_maps(FP, FN, fcover, eyes, front.mean(0))
    save(pad(face, fcover), OUT_FACE)

    if "--preview" in sys.argv:
        out = sys.argv[sys.argv.index("--preview") + 1]
        preview(body, P, cover, out, "body")
        preview(face, FP, fcover, out, "face")


if __name__ == "__main__":
    main()
