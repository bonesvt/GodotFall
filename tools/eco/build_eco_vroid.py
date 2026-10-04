"""Builds the in-game Eco from Bones's VRoid preset (the "anime fox girl" model,
kept in the project files as preset/anime-fox-girl-preset.zip -> Untitled.glb).
Run through Blender 4:

    blender -b --factory-startup -P tools/eco/build_eco_vroid.py -- <Untitled.glb> <repo root> [--preview <png prefix>]

What it does to the preset, in its rest space (she faces -Y there, her left is +X):
- removes the fox ears and tail, the preset's clothes (the boots stay, recoloured)
- cuts the hair to a chin-length bob with a swept fringe and dyes it dark red
- a fiercer, older face: smaller irises and a longer chin (the angry brows and
  narrowed eyes are blend shapes, set on import), mature makeup painted in
- fuller, rounder hips, glutes and thighs
- paints the pilot suit onto her skin: halter bodysuit with a keyhole, side
  cutouts, open back and legs cut high front and back, waist band, gloves,
  thigh-high boots with knee plates, teal glow trims. Baked into v_body.png (+ glow, sheen/suit mask and normal maps)
- goggles on her head, skinned to the head bone
- the suit upgrades' armour (suit_t<tier>[m|h]_* pieces: bracers, belt and pouches,
  shoulder plates, injector, shin guards, hip plates, jump kit, collar,
  crests), hidden in game until she has bought that tier
- glute bones beside the preset's bust bones, for the jiggle springs
- a slightly smaller head and longer legs, 1.69 m tall, turned to face +Y
- idle/walk/run/fall/crouch/slide animations for the VRoid rig
Writes assets/models/eco/eco.glb and assets/textures/eco/v_*.png. The glb's
material names (eco_v_*) are swapped for assets/materials/eco/eco_v_*.tres by
assets/models/eco/eco_import.gd.
"""
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector
from mathutils.bvhtree import BVHTree

argv = sys.argv[sys.argv.index("--") + 1:]
SRC = argv[0]
ROOT = os.path.abspath(argv[1])   # Blender on Windows resolves "." against its own folder
PREVIEW = argv[argv.index("--preview") + 1] if "--preview" in argv else None
TEX_OUT = os.path.join(ROOT, "assets", "textures", "eco")
GLB_OUT = os.path.join(ROOT, "assets", "models", "eco", "eco.glb")

HEIGHT = 1.69
HEAD_SCALE = 0.95
LEG_SCALE = 1.03

# suit colours (linear)
SUIT = (0.032, 0.036, 0.052)
GEAR = (0.016, 0.016, 0.021)
PLATE = (0.085, 0.09, 0.105)
TRIM = (0.0, 0.62, 0.55)
INK = (0.012, 0.009, 0.014)
STRETCH = (0.085, 0.09, 0.115)   # the suit where it stretches thin over her curves
MED_SUIT = (0.03, 0.033, 0.026)   # the medium jumpsuit: charcoal olive
MED_PANEL = (0.11, 0.04, 0.016)   # its rust side panels and sleeve cuff
MED_ZIP = 0.86                    # where the jumpsuit's zip stops, below her belly button (rest-space z)
MED_NAVEL = 0.902                 # her belly button (rest-space z)
MED_SLEEVE = 0.36                 # where the right sleeve is rolled to (rest-space x)
TATTOO = (0.018, 0.024, 0.04)
HVY_SUIT = (0.03, 0.034, 0.045)   # the heavy suit's padded undersuit
CREASE = (0.42, 0.24, 0.22)       # shadowed skin
GLEAM = (0.15, 0.155, 0.195)      # where it stretches thinnest, on the peaks of her bust
CREASE_SKIN = (0.74, 0.52, 0.52)  # multiplies her skin along the fold under her glutes, where the cut bares it
# the base pilot suit: a full stretch bodysuit, charcoal with crimson panels
BASE_RED = (0.24, 0.018, 0.026)   # crimson panels, the red of her hair
BASE_NET = (0.02, 0.022, 0.03)    # the breathable mesh's net
BASE_CORSET = (0.012, 0.011, 0.014)
JACKET = (0.02, 0.09, 0.1)        # the cropped jacket: deep teal
ZIP = (0.42, 0.44, 0.5)           # the back zip's silver teeth
# The base suit's styles, all baked (v_body[_<style>].png) and each with its own
# jacket (base_<style>_jacket); Eco picks one in her wardrobe (eco_model.gd OUTFITS:
# "suit" is gwen, the others "suit_<style>"). Each has its own colours and details:
#   neck     sweetheart or vee: breathable mesh above that line up to the collar
#   panels   sides (panels down her sides and legs, sleeves from `sleeve` out),
#            racer (a sash across her, her left leg and stripes), harness (pilot
#            harness straps), wrap (a wrap top and glowing circuit lines)
#            and three that look nothing like it: shade (a glossy catsuit),
#            patchwork (the suit Mom sewed her) and punk (the one Ophelia made)
#   belt     corset, obi, utility, sash or none
#   vents    ribs (perforated side panels) or spine (mesh strips beside her spine)
#   jacket   cropped, bomber, half, cowl, vest, skirt or None (base_jacket, base_skirt)
#   gloss    how much of the hard sheen shows on the suit (0: none, only her gloves and boots)
BASE_STYLES = {
    "gwen": dict(suit=SUIT, panel=BASE_RED, belt=BASE_CORSET, accent=BASE_RED, net=BASE_NET, stretch=STRETCH,
                 glow=TRIM, neck="sweetheart", panels="sides", sleeve=0.165, lower=True, belt_kind="corset", vents="ribs",
                 jacket="cropped"),
    "ghost": dict(suit=(0.6, 0.62, 0.68), panel=(0.012, 0.012, 0.016), belt=(0.012, 0.012, 0.016), accent=BASE_RED,
                  net=(0.008, 0.008, 0.012), stretch=(0.75, 0.77, 0.84), glow=(0.85, 0.02, 0.04), neck="vee",
                  panels="sides", legs="shins", sleeve=0.27, belt_kind="obi", vents="ribs", jacket="cropped"),
    "racer": dict(suit=(0.016, 0.017, 0.021), panel=(0.55, 0.11, 0.01), belt=(0.05, 0.03, 0.018),
                  accent=(0.55, 0.11, 0.01), net=BASE_NET, stretch=(0.06, 0.06, 0.07), glow=(1.0, 0.4, 0.05),
                  neck=None, panels="racer", belt_kind="utility", vents="spine", spine=(0.905, 0.995), jacket="bomber"),
    "harness": dict(suit=(0.028, 0.04, 0.068), panel=(0.06, 0.063, 0.068), belt=(0.06, 0.063, 0.068),
                    accent=(0.8, 0.22, 0.015), net=BASE_NET, stretch=(0.06, 0.08, 0.12), glow=(1.0, 0.42, 0.04),
                    neck=None, panels="harness", belt_kind="none", vents=None, jacket=None),
    "techwear": dict(suit=(0.02, 0.016, 0.03), panel=(0.4, 0.28, 0.66), belt=(0.02, 0.016, 0.03),
                     accent=(0.2, 0.13, 0.36), net=BASE_NET, stretch=(0.05, 0.045, 0.07), glow=(0.55, 0.22, 1.0),
                     neck=None, panels="wrap", belt_kind="sash", vents="spine", jacket="half"),
    "shade": dict(suit=(0.006, 0.006, 0.008), panel=(0.022, 0.021, 0.025), belt=(0.012, 0.011, 0.013),
                  accent=(0.35, 0.01, 0.03), net=BASE_NET, stretch=(0.03, 0.03, 0.04), glow=(0.9, 0.02, 0.08),
                  neck=None, panels="shade", belt_kind="none", vents=None, jacket="cowl", gloss=0.85),
    "homemade": dict(suit=(0.3, 0.16, 0.022), panel=(0.07, 0.11, 0.05), belt=(0.4, 0.31, 0.18),
                     accent=(0.42, 0.05, 0.07), net=BASE_NET, stretch=(0.38, 0.22, 0.045), glow=(1.0, 0.55, 0.15),
                     neck=None, panels="patchwork", belt_kind="none", vents=None, jacket="vest"),
    "ophelia": dict(suit=(0.008, 0.008, 0.011), panel=(0.13, 0.02, 0.3), belt=(0.012, 0.011, 0.014),
                    accent=(0.72, 0.71, 0.76), net=(0.004, 0.004, 0.006), stretch=(0.035, 0.032, 0.045),
                    glow=(0.55, 0.15, 1.0), neck=None, panels="punk", belt_kind="none", vents=None, jacket="skirt"),
}
# Mom's fabric scraps on the homemade suit (linear)
DENIM = (0.03, 0.06, 0.13)
GINGHAM = (0.42, 0.45, 0.36)
FLORAL = (0.36, 0.1, 0.12)
KNIT = (0.6, 0.53, 0.4)
CORDUROY = (0.08, 0.04, 0.018)
STYLE_NAME = "gwen"   # the style being baked or built (set while each one is)
STYLE = BASE_STYLES[STYLE_NAME]


def use_style(name):
    global STYLE_NAME, STYLE
    STYLE_NAME, STYLE = name, BASE_STYLES[name]

SIDE_CUT = 0.075   # how far the sides of the halter drop beside the bust (rest-space metres)
CHEEKY = 1.6       # how steeply the back leg openings rise toward the hips
# fuller curves (rest-space metres, before she is scaled up by about 1.2)
GLUTES = 0.026
HIPS = 0.014
THIGHS = 0.009
# the suit clinging to her shape (rest-space metres): the peaks of her bust stand
# out, and it sinks into the cleft of her glutes (only where her cheeks are, never
# lower) and the fold under each one
APEX_POS = (0.0567, -0.1207, 1.0468)
APEX = 0.0045
CLEFT = 0.006
FOLD = 0.005
FOLD_Z = 0.733

# the fierce expression, applied as blend shapes on import (eco_import.gd)
EXPRESSION = {"Fcl_BRW_Angry": 1.0, "Fcl_EYE_Angry": 0.55, "Fcl_MTH_Down": 0.1}


def smooth(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def ss(e0, e1, v):
    t = np.clip((v - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


# --- images --------------------------------------------------------------------

def to_lin(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def to_srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def read_px(img):
    """Pixels of a byte image as stored (sRGB values), rows bottom-up."""
    w, h = img.size
    px = np.empty(w * h * 4, np.float32)
    img.pixels.foreach_get(px)
    return px.reshape(h, w, 4)


def write_png(px, name):
    h, w = px.shape[:2]
    img = bpy.data.images.new(name, w, h, alpha=True)
    img.pixels.foreach_set(np.clip(px, 0, 1).astype(np.float32).ravel())
    img.filepath_raw = os.path.join(TEX_OUT, name + ".png")
    img.file_format = "PNG"
    img.save()
    return img


def box_blur(a, r):
    """Mean over a (2r+1)^2 window (edges clamped), via summed-area tables."""
    p = np.pad(a, ((r + 1, r), (r + 1, r)) + ((0, 0),) * (a.ndim - 2), mode="edge")
    c = p.cumsum(0).cumsum(1)
    k = 2 * r + 1
    s = c[k:, k:] - c[:-k, k:] - c[k:, :-k] + c[:-k, :-k]
    return s / (k * k)


def fill_holes(rgb, hole):
    """Fill masked pixels from the surrounding colour, widening the search."""
    out = rgb.copy()
    known = (~hole).astype(np.float32)
    todo = hole.copy()
    for r in (2, 4, 8, 16, 32, 64, 128):
        den = box_blur(known, r)
        num = box_blur(rgb * known[..., None], r)
        ok = todo & (den > 0.08)
        out[ok] = num[ok] / den[ok][:, None]
        todo &= ~ok
    return out


def dilate(mask, n):
    m = mask.copy()
    for _ in range(n):
        g = m.copy()
        g[1:] |= m[:-1]
        g[:-1] |= m[1:]
        g[:, 1:] |= m[:, :-1]
        g[:, :-1] |= m[:, 1:]
        m = g
    return m


def ramp(v, stops):
    """Linear colour ramp; stops = [(pos, (r, g, b)), ...]."""
    pos = np.array([s[0] for s in stops])
    out = np.empty(v.shape + (3,), np.float32)
    for c in range(3):
        out[..., c] = np.interp(v, pos, [s[1][c] for s in stops])
    return out


def lum(lin_rgb):
    return lin_rgb @ np.array([0.2126, 0.7152, 0.0722], np.float32)


HAIR_RAMP = [(0.30, (0.016, 0.001, 0.004)), (0.62, (0.080, 0.004, 0.010)),
             (0.86, (0.18, 0.011, 0.018)), (1.0, (0.40, 0.045, 0.045))]


def dye_hair(px):
    """Dark red from the preset texture's brightness: wine in the shadows,
    crimson through the body, a hot red sheen on the highlights."""
    out = px.copy()
    out[..., :3] = to_srgb(ramp(lum(to_lin(px[..., :3])), HAIR_RAMP))
    return out


def recolour_boots(px):
    out = px.copy()
    t = lum(to_lin(px[..., :3]))[..., None]
    out[..., :3] = to_srgb(np.array((0.006, 0.006, 0.008)) * (1 - t) + np.array((0.07, 0.072, 0.085)) * t)
    return out


# --- scene -----------------------------------------------------------------------

def setup_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=SRC)
    for o in list(bpy.data.objects):
        if o.name.startswith("Icosphere"):
            bpy.data.objects.remove(o)
    body = bpy.data.objects["Body"].data
    a = body.attributes.new("rest", "FLOAT_VECTOR", "POINT")
    for v in body.vertices:
        a.data[v.index].vector = v.co
    return [o for o in bpy.data.objects if o.type == "ARMATURE"][0]


def delete_faces(ob, keep_face):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    dead = [f for f in bm.faces if not keep_face(f)]
    bmesh.ops.delete(bm, geom=dead, context="FACES")
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()
    return len(dead)


def islands(bm):
    bm.faces.ensure_lookup_table()
    seen, out = set(), []
    for f in bm.faces:
        if f.index in seen:
            continue
        stack, comp = [f], []
        seen.add(f.index)
        while stack:
            g = stack.pop()
            comp.append(g)
            for e in g.edges:
                for n in e.link_faces:
                    if n.index not in seen:
                        seen.add(n.index)
                        stack.append(n)
        out.append(comp)
    return out


def mat_index(ob, needle):
    return {i for i, m in enumerate(ob.data.materials) if m and needle in m.name}


def remove_fox_parts():
    # the third hair material only covers the ears (and the fluff at their base)
    delete_faces(bpy.data.objects["Hair"], lambda f: f.material_index != 2)
    body = bpy.data.objects["Body"]
    tail = mat_index(body, "FoxTail")
    delete_faces(body, lambda f: f.material_index not in tail)


def short_hair():
    """The back hair is a short layer from crown to nape plus separate long pieces
    and braids. Drop every piece that doesn't reach above the nape, fold what's
    left below the jaw into a chin-length bob, and lift the fringe off her eyes
    (longer over her right eye)."""
    hair = bpy.data.objects["Hair"]
    bm = bmesh.new()
    bm.from_mesh(hair.data)
    dead = []
    for comp in islands(bm):
        if max(v.co.z for f in comp for v in f.verts) < 1.22:
            dead.extend(comp)
    bmesh.ops.delete(bm, geom=list(set(dead)), context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(hair.data)
    bm.free()
    me = hair.data
    mat_of = {}
    for p in me.polygons:
        for v in p.vertices:
            mat_of[v] = min(mat_of.get(v, 9), p.material_index)
    rules = {0: (1.25, 0.035, 0.15), 1: (1.335, 0.035, 0.0)}   # z0, depth, tuck
    for v in me.vertices:
        p = v.co.copy()
        m = mat_of.get(v.index, 0)
        z0, L, tuck = rules.get(m, rules[0])
        if m == 1:
            z0 -= 0.026 * smooth(0.005, -0.04, p.x)
        d = z0 - p.z
        if d <= 0:
            continue
        w = smooth(z0, z0 - 0.12, p.z) * tuck
        v.co = Vector((p.x * (1 - w), 0.02 + (p.y - 0.02) * (1 - w), z0 - L * (1 - math.exp(-d / L))))


def fierce_face():
    face = bpy.data.objects["Face"]
    me = face.data
    keys = me.shape_keys.key_blocks
    mat_of = {}
    for p in me.polygons:
        for v in p.vertices:
            mat_of.setdefault(v, set()).add(p.material_index)
    for side in (1, -1):   # smaller irises and highlights: a harder stare
        ids = [v.index for v in me.vertices if mat_of.get(v.index, set()) & {1, 2} and v.co.x * side > 0]
        c = sum((me.vertices[i].co for i in ids), Vector()) / len(ids)
        for kb in keys:
            for i in ids:
                p = kb.data[i].co
                kb.data[i].co = Vector((c.x + (p.x - c.x) * 0.88, p.y, c.z + (p.z - c.z) * 0.88))
    for kb in keys:   # a longer, narrower chin (front of the lower face only)
        for v in me.vertices:
            w = smooth(1.262, 1.214, v.co.z) * smooth(-0.025, -0.045, v.co.y)
            if w > 0:
                p = kb.data[v.index].co
                kb.data[v.index].co = Vector((p.x * (1 - 0.04 * w), p.y, p.z - 0.006 * w))
    for v in me.vertices:
        v.co = keys[0].data[v.index].co


def face_position_map(face, W, H):
    """Rest-space position of every face-skin texel, and which texels are skin."""
    me = face.data
    me.calc_loop_triangles()
    uv = me.uv_layers["UVMap"].data
    skin = mat_index(face, "SKIN")
    pos = np.zeros((H, W, 3), np.float32)
    mask = np.zeros((H, W), bool)
    for t in me.loop_triangles:
        if t.material_index not in skin:
            continue
        P = np.array([me.vertices[v].co[:] for v in t.vertices])
        U = np.array([uv[l].uv[:] for l in t.loops]) * (W, H)
        x0, y0 = np.floor(U.min(0)).astype(int)
        x1, y1 = np.ceil(U.max(0)).astype(int)
        x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, W - 1), min(y1, H - 1)
        if x1 < x0 or y1 < y0:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        a, b, c = U
        den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(den) < 1e-12:
            continue
        l0 = ((b[1] - c[1]) * (gx - c[0]) + (c[0] - b[0]) * (gy - c[1])) / den
        l1 = ((c[1] - a[1]) * (gx - c[0]) + (a[0] - c[0]) * (gy - c[1])) / den
        l2 = 1 - l0 - l1
        ins = (l0 > -0.02) & (l1 > -0.02) & (l2 > -0.02)
        p = l0[..., None] * P[0] + l1[..., None] * P[1] + l2[..., None] * P[2]
        sub = pos[y0:y1 + 1, x0:x1 + 1]
        sub[ins] = p[ins]
        mask[y0:y1 + 1, x0:x1 + 1] |= ins
    return pos, mask


def face_texture(face, src_img, glam=False):
    """Face skin: soften the cheek blush, then paint mature makeup in 3D:
    smoky plum lids, a winged liner flick and a berry lip stain. `glam` is her
    date-night face (v_face_date.png): deeper smoky lids with a gold shimmer at
    the inner corners, a longer, sharper wing, contoured cheeks and red lips."""
    px = read_px(src_img).copy()
    H, W = px.shape[:2]
    rgb = px[..., :3] * 255
    # blush: the preset's pink cheek patches (image rows run bottom-up here)
    yy, xx = np.mgrid[0:H, 0:W]
    yy = H - 1 - yy
    w = np.zeros((H, W))
    for cx in (330, 690):
        r = ((xx - cx) / 130.0) ** 2 + ((yy - 625) / 85.0) ** 2
        w = np.maximum(w, np.clip(1.4 - r, 0, 1))
    pink = rgb[..., 0] - (rgb[..., 1] + rgb[..., 2]) / 2
    d = np.clip(pink - 19.0, 0, None) * w * 0.85
    rgb[..., 0] -= d * 2 / 3
    rgb[..., 1] += d / 3
    rgb[..., 2] += d / 3
    px[..., :3] = rgb / 255
    pos, mask = face_position_map(face, W, H)
    x, y, z = np.abs(pos[..., 0]), pos[..., 1], pos[..., 2]

    def tint(col, amount):
        a = (amount * mask)[..., None]
        px[..., :3] = px[..., :3] * (1 - a) + px[..., :3] * np.array(col) * a

    def paint(col, amount):
        a = (amount * mask)[..., None]
        px[..., :3] = px[..., :3] * (1 - a) + np.array(col) * a
    u = (x - 0.041) / 0.029
    v = (z - 1.2905) / 0.0135
    lid = (1 - ss(0.45, 1.0, np.sqrt(u * u + v * v))) * ss(1.276, 1.287, z) * (y < -0.015)
    lid *= 0.55 + 0.45 * ss(0.02, 0.06, x)
    tint((0.55, 0.30, 0.38), 0.75 * lid)
    P0, P1, T = np.array((0.0560, 1.2868)), np.array((0.0575, 1.2925)), np.array((0.0708, 1.2985))
    if glam:
        u2 = (x - 0.043) / 0.034
        v2 = (z - 1.2915) / 0.017
        smoky = (1 - ss(0.4, 1.0, np.sqrt(u2 * u2 + v2 * v2))) * ss(1.274, 1.286, z) * (y < -0.015)
        tint((0.36, 0.16, 0.24), 0.85 * smoky)
        inner = (1 - ss(0.0, 1.0, np.hypot((x - 0.026) / 0.008, (z - 1.288) / 0.005))) * (y < -0.015)
        paint((0.95, 0.78, 0.45), 0.55 * inner)
        cheek = (1 - ss(0.0, 1.0, np.hypot((x - 0.058) / 0.02, (z - 1.255 - 0.3 * (x - 0.058)) / 0.006))) * (y < 0.0)
        tint((0.8, 0.62, 0.62), 0.6 * cheek)
        P0, P1, T = np.array((0.0560, 1.2866)), np.array((0.0580, 1.2930)), np.array((0.0752, 1.3015))

    def edge(a, b, qx, qz):
        n = np.array((b[1] - a[1], -(b[0] - a[0])))
        n /= np.linalg.norm(n)
        return (qx - a[0]) * n[0] + (qz - a[1]) * n[1]
    s = np.sign(edge(P0, T, *P1)), np.sign(edge(T, P1, *P0)), np.sign(edge(P1, P0, *T))
    AA = 0.00025
    wing = (ss(-AA, AA, edge(P0, T, x, z) * s[0]) * ss(-AA, AA, edge(T, P1, x, z) * s[1])
            * ss(-AA, AA, edge(P1, P0, x, z) * s[2]) * (y < -0.005))
    paint((0.17, 0.07, 0.09), 0.9 * wing)
    dz = z - 1.2397
    lips = (pos[..., 0] / 0.0098) ** 2 + (dz / np.where(dz < 0, 0.0036, 0.0021)) ** 2
    if glam:
        paint(to_srgb(np.array(LIP_RED)), 0.85 * (1 - ss(0.45, 1.05, lips)) * (y < -0.04))
    else:
        tint((0.78, 0.42, 0.47), 0.75 * (1 - ss(0.35, 1.0, lips)) * (y < -0.04))
    return px


def strip_clothes():
    """Drop the preset's corset, shorts, belt and choker; the boots become their
    own object (their open cuffs would show the ink outline from inside)."""
    body = bpy.data.objects["Body"]
    mats = body.data.materials
    drop = {i for i, m in enumerate(mats) if m and ("Tops" in m.name or "Onepiece" in m.name
                                                     or "Bottoms_01_CLOTH_0" in m.name)}
    delete_faces(body, lambda f: f.material_index not in drop)
    boot_idx = {i for i, m in enumerate(mats) if m and ("Shoes" in m.name or m.name.endswith("Bottoms_01_CLOTH (Instance)"))}
    boots = body.copy()
    boots.data = body.data.copy()
    boots.name = boots.data.name = "Boots"
    bpy.context.scene.collection.objects.link(boots)
    delete_faces(boots, lambda f: f.material_index in boot_idx)
    delete_faces(body, lambda f: f.material_index not in boot_idx)
    # slimmer: pull each boot in round its own middle (the sole stays put)
    vs = boots.data.vertices
    for side in (1, -1):
        mine = [v for v in vs if v.co.x * side > 0]
        cx = sum(v.co.x for v in mine) / len(mine)
        cy = sum(v.co.y for v in mine) / len(mine)
        for v in mine:
            k = 1.0 - 0.13 * smooth(0.0, 0.04, v.co.z)
            v.co.x = cx + (v.co.x - cx) * k
            v.co.y = cy + (v.co.y - cy) * (1.0 - (1.0 - k) * 0.6)
    return boots


# --- curves ------------------------------------------------------------------------

def curves():
    """Rounder, fuller hips, glutes and thighs. Each point moves out along its
    own surface normal by a smooth, wide falloff (and the result is smoothed
    over the mesh), so the body inflates into round shapes instead of being
    pulled sideways or back into points. Inner thighs grow less, so her legs
    don't merge."""
    body = bpy.data.objects["Body"]
    me = body.data
    n = len(me.vertices)
    P = np.empty(n * 3, np.float32)
    me.vertices.foreach_get("co", P)
    P = P.reshape(n, 3)
    N = np.empty(n * 3, np.float32)
    me.vertices.foreach_get("normal", N)
    N = N.reshape(n, 3)
    # the mesh is split along its UV seams: give every copy of a point the same normal
    groups = {}
    for i, k in enumerate(map(tuple, np.round(P, 5))):
        groups.setdefault(k, []).append(i)
    for ids in groups.values():
        if len(ids) > 1:
            N[ids] = N[ids].sum(0)
    N /= np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-9)
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    ax = np.abs(x)
    out = N[:, 0] * np.sign(x)    # how much the surface faces out to her side
    glute = GLUTES * np.exp(-((ax - 0.062) / 0.055) ** 2 - ((z - 0.765) / 0.065) ** 2) * ss(-0.02, 0.04, y)
    hip = HIPS * np.exp(-((z - 0.75) / 0.065) ** 2) * ss(0.15, 0.7, out)
    thigh = THIGHS * ss(0.47, 0.57, z) * ss(0.78, 0.68, z) * (0.35 + 0.65 * ss(-0.5, 0.5, out))
    D = N * (glute + hip + thigh)[:, None]
    # smooth the push over the surface (welded across the seams)
    me.calc_loop_triangles()
    edges = np.array([e.vertices[:] for e in me.edges])
    for _ in range(6):
        acc = np.zeros_like(D)
        cnt = np.zeros(n)
        np.add.at(acc, edges[:, 0], D[edges[:, 1]])
        np.add.at(acc, edges[:, 1], D[edges[:, 0]])
        np.add.at(cnt, edges[:, 0], 1)
        np.add.at(cnt, edges[:, 1], 1)
        D = 0.5 * D + 0.5 * acc / np.maximum(cnt, 1)[:, None]
        for ids in groups.values():
            if len(ids) > 1:
                D[ids] = D[ids].mean(0)
    # small, sharp shapes the suit clings to, added after the smoothing so they stay crisp
    back = ss(0.2, 0.6, N[:, 1])    # surfaces facing behind her
    d2 = (ax - APEX_POS[0]) ** 2 + (y - APEX_POS[1]) ** 2 + (z - APEX_POS[2]) ** 2
    apex = APEX * np.exp(-d2 / (2 * 0.0065 ** 2))
    cleft = CLEFT * np.exp(-(x / 0.011) ** 2) * ss(0.765, 0.785, z) * ss(0.885, 0.85, z) * back
    fold = FOLD * np.exp(-((z - FOLD_Z) / 0.009) ** 2) * ss(0.012, 0.03, ax) * ss(0.125, 0.09, ax) * back
    D += N * (apex - cleft - fold)[:, None]
    me.vertices.foreach_set("co", (P + D).ravel())
    me.update()
    print("curves: up to %.1f mm" % (np.linalg.norm(D, axis=1).max() * 1000))


# --- goggles ---------------------------------------------------------------------

def new_mat(name, col=(0.5, 0.5, 0.5)):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.diffuse_color = (*col, 1)
    return m


def goggles(arm):
    """Pilot goggles pushed up on her head: a strap around the hair and two lens
    cups over the hairline, one mesh skinned to the head bone."""
    dg = bpy.context.evaluated_depsgraph_get()
    trees = [BVHTree.FromObject(bpy.data.objects[n], dg) for n in ("Hair", "Face", "Body")]
    C = Vector((0.0, 0.03, 1.335))
    up = Vector((0.0, 0.32, 1.0)).normalized()     # the strap tilts: high at the front
    fwd = Vector((0.0, -1.0, 0.0))
    fwd = (fwd - up * fwd.dot(up)).normalized()
    side = fwd.cross(up).normalized()

    def surface(d):
        best = None
        for t in trees:
            hit = t.ray_cast(C + d * 0.3, -d)
            if hit[0] is not None:
                r = (hit[0] - C).length
                best = r if best is None else max(best, r)
        return best or 0.1
    N = 72
    dirs = [(fwd * math.cos(2 * math.pi * k / N) + side * math.sin(2 * math.pi * k / N)).normalized() for k in range(N)]
    ring = [surface(d) for d in dirs]
    for _ in range(4):
        ring = [(ring[k - 1] + 2 * ring[k] + ring[(k + 1) % N]) / 4 for k in range(N)]
    bm = bmesh.new()
    mats = [new_mat("eco_v_goggle_strap", (0.02, 0.02, 0.02)), new_mat("eco_v_goggle_frame", (0.05, 0.05, 0.06)),
            new_mat("eco_v_goggle_glow", TRIM), new_mat("eco_v_goggle_lens", (0.01, 0.05, 0.06))]
    Hh, Tt = 0.016, 0.0035
    rings = []
    for k in range(N):
        p = C + dirs[k] * (ring[k] + 0.0025)
        rings.append([bm.verts.new(p + dirs[k] * o + up * (h * Hh / 2)) for o, h in ((0, -1), (0, 1), (Tt, 1), (Tt, -1))])
    for k in range(N):
        a, b = rings[k], rings[(k + 1) % N]
        for j in range(4):
            f = bm.faces.new((a[j], a[(j + 1) % 4], b[(j + 1) % 4], b[j]))
            f.material_index = 0
    for s in (1, -1):
        a = 0.36 * s
        d = (fwd * math.cos(a) + side * math.sin(a)).normalized()
        k = int(round((a % (2 * math.pi)) / (2 * math.pi) * N)) % N
        base = C + d * (ring[k] + 0.006)
        axis = (d * math.cos(math.radians(35)) + up * math.sin(math.radians(35))).normalized()
        R = Vector((0, 0, 1)).rotation_difference(axis).to_matrix().to_4x4()
        for kind, r, depth, off, mi in (("cyl", 0.0185, 0.014, 0.007, 1), ("torus", 0.0185, 0.0017, 0.0145, 2),
                                        ("cyl", 0.0158, 0.002, 0.0145, 3)):
            M = Matrix.Translation(base + axis * off) @ R
            new = []
            if kind == "cyl":
                res = bmesh.ops.create_cone(bm, cap_ends=True, segments=32, radius1=r, radius2=r, depth=depth, matrix=M)
                new = res["verts"]
            else:
                major, minor = r, depth
                grid = []
                for i in range(32):
                    t = 2 * math.pi * i / 32
                    row = []
                    for j in range(8):
                        u = 2 * math.pi * j / 8
                        q = Vector(((major + minor * math.cos(u)) * math.cos(t), (major + minor * math.cos(u)) * math.sin(t), minor * math.sin(u)))
                        row.append(bm.verts.new(M @ q))
                    grid.append(row)
                for i in range(32):
                    for j in range(8):
                        bm.faces.new((grid[i][j], grid[(i + 1) % 32][j], grid[(i + 1) % 32][(j + 1) % 8], grid[i][(j + 1) % 8]))
                new = [v for row in grid for v in row]
            vs = set(new)
            for f in bm.faces:
                if all(v in vs for v in f.verts):
                    f.material_index = mi
    me = bpy.data.meshes.new("Goggles")
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(m)
    ob = bpy.data.objects.new("Goggles", me)
    bpy.context.scene.collection.objects.link(ob)
    vg = ob.vertex_groups.new(name="J_Bip_C_Head")
    vg.add(list(range(len(me.vertices))), 1.0, "REPLACE")
    ob.parent = arm
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    return ob


# --- suit armour --------------------------------------------------------------------

# armour colours (linear)
ARMOR = (0.11, 0.115, 0.13)       # gunmetal plates
ARMOR_EDGE = (0.3, 0.29, 0.27)    # worn, bright edges
STRAP = (0.02, 0.018, 0.02)
POUCH = (0.11, 0.085, 0.055)      # scavenged canvas
CLOTH = (0.05, 0.045, 0.04)       # the light suit's durable wrap cloth
LEATHER = (0.11, 0.05, 0.025)     # the light suit's leather
CANVAS = (0.11, 0.1, 0.06)        # the medium suit's canvas
RUST = (0.2, 0.06, 0.02)          # its rubber pads
TAPE = (0.36, 0.32, 0.25)         # sticking plaster
LEGACY = (0.62, 0.68, 0.8)        # Dad's colours (the game swaps this in at tier 5)


def _body_bvh():
    dg = bpy.context.evaluated_depsgraph_get()
    return BVHTree.FromObject(bpy.data.objects["Body"], dg)


def _armor_mats(me, names):
    cols = {"eco_v_armor": ARMOR, "eco_v_armor_edge": ARMOR_EDGE, "eco_v_armor_strap": STRAP,
            "eco_v_armor_pouch": POUCH, "eco_v_armor_glow": TRIM, "eco_v_cloth": CLOTH,
            "eco_v_leather": LEATHER, "eco_v_canvas": CANVAS, "eco_v_rust": RUST, "eco_v_tape": TAPE,
            "eco_v_jacket": JACKET, "eco_v_jacket_edge": BASE_RED}
    for n in names:
        me.materials.append(new_mat(n, cols.get(n, (0.5, 0.5, 0.5))))


def shell(name, keep, planes=(), gap=0.004, thick=0.004, plate="eco_v_armor", edge="eco_v_armor_edge", smooth=0,
          smooth_edge=0, border=0):
    """A plate that follows her body: the Body faces `keep(centre, normal)` picks,
    welded, trimmed straight by `planes` ((point, normal): the normal side is cut
    away), lifted `gap` off her skin and given `thick`ness. It keeps the body's
    skin weights, so it moves exactly as she does. Its sides are the bright edge."""
    body = bpy.data.objects["Body"]
    ob = body.copy()
    ob.data = body.data.copy()
    ob.name = ob.data.name = name
    bpy.context.scene.collection.objects.link(ob)
    if "rest" in ob.data.attributes:
        ob.data.attributes.remove(ob.data.attributes["rest"])
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.normal_update()
    skin = {i for i, m in enumerate(ob.data.materials) if m and ("Body_00_SKIN" in m.name or m.name == "eco_v_body")}
    dead = [f for f in bm.faces if f.material_index not in skin or not keep(f.calc_center_median(), f.normal)]
    bmesh.ops.delete(bm, geom=dead, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
    for co, no in planes:
        bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], dist=1e-6,
                               plane_co=Vector(co), plane_no=Vector(no), clear_outer=True)
    # drop slivers the cuts leave behind
    for comp in islands(bm):
        if len(comp) < 6:
            bmesh.ops.delete(bm, geom=comp, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.normal_update()
    for _ in range(smooth_edge):   # round off the stair steps picking whole faces leaves along its edges
        rim = [v for v in bm.verts if v.is_boundary]
        new = {}
        for v in rim:
            nb = [e.other_vert(v) for e in v.link_edges if e.is_boundary]
            if len(nb) == 2:
                new[v] = v.co * 0.5 + (nb[0].co + nb[1].co) * 0.25
        for v, co in new.items():
            v.co = co
        # let the ring inside follow, so no face folds over the moved edge
        ring = {e.other_vert(v) for v in rim for e in v.link_edges} - set(rim)
        bmesh.ops.smooth_vert(bm, verts=list(ring), factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    bm.normal_update()
    for v in bm.verts:
        v.co += v.normal * gap
    if smooth:   # a stiff plate: soften the small dips and peaks under it, borders stay put
        inner = [v for v in bm.verts if not v.is_boundary]
        for _ in range(smooth):
            bmesh.ops.smooth_vert(bm, verts=inner, factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
        for f in bm.faces:
            f.smooth = True
        bm.normal_update()
    if border:
        # cloth: a plain shell `thick` out along the normals (bmesh's solidify spikes
        # where a soft edge turns sharply), the edge material `border` faces wide
        # round its edge on both sides and on its rim
        edge_v = {v for v in bm.verts if v.is_boundary}
        band = set()
        for _ in range(border):
            faces = {f for v in edge_v for f in v.link_faces}
            band |= faces
            edge_v = {v for f in faces for v in f.verts}
        for f in bm.faces:
            f.material_index = 1 if f in band else 0
        rim = [e for e in bm.edges if e.is_boundary]
        normals = {v: v.normal.copy() for v in bm.verts}
        inner = bm.faces[:]
        dup = bmesh.ops.duplicate(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:])
        vmap = dup["vert_map"]
        for v, n in normals.items():
            vmap[v].co += n * thick
        bmesh.ops.reverse_faces(bm, faces=inner)
        for e in rim:
            a, b = e.verts
            f = bm.faces.new((b, a, vmap[a], vmap[b]))
            f.material_index = 1
            f.smooth = True
        bm.normal_update()
    else:
        orig = set(bm.verts)
        bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=thick)
        bm.normal_update()
        for f in bm.faces:
            vs = set(f.verts)
            f.material_index = 1 if (vs & orig) and (vs - orig) else 0
    ob.data.materials.clear()   # before the faces go in: clearing the slots resets their indices
    _armor_mats(ob.data, [plate, edge])
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()
    return ob


def rigid(name, bm, mats, bone):
    """A hard part (pouch, pack, vial) skinned whole to one bone."""
    arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
    me = bpy.data.meshes.new(name)
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    _armor_mats(me, mats)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    vg = ob.vertex_groups.new(name=bone)
    vg.add(list(range(len(me.vertices))), 1.0, "REPLACE")
    ob.parent = arm
    ob.modifiers.new("Armature", "ARMATURE").object = arm
    return ob


def surface(bvh, origin, direction):
    """Where a ray from `origin` along `direction` meets her body, and the normal there."""
    hit = bvh.ray_cast(Vector(origin), Vector(direction).normalized())
    return hit[0], hit[1]


def box(bm, centre, axes, size, mat, bevel=0.004):
    """A bevelled box: `axes` are its unit (x, y, z) directions, `size` full extents."""
    M = Matrix((list(axes[0]) + [0], list(axes[1]) + [0], list(axes[2]) + [0], [0, 0, 0, 1])).transposed()
    M = Matrix.Translation(Vector(centre)) @ M @ Matrix.Diagonal((*size, 1))
    res = bmesh.ops.create_cube(bm, size=1.0, matrix=M)
    vs = res["verts"]
    faces = list({f for v in vs for f in v.link_faces})
    if bevel > 0:
        edges = list({e for v in vs for e in v.link_edges})
        out = bmesh.ops.bevel(bm, geom=edges + vs, offset=bevel, segments=2, affect="EDGES", profile=0.5)
        faces = list(set(faces) | set(out["faces"]))
    for f in faces:
        if f.is_valid:
            f.material_index = mat
    return faces


def cylinder(bm, base, axis, radius, depth, mat, segments=16, radius2=None):
    R = Vector((0, 0, 1)).rotation_difference(Vector(axis).normalized()).to_matrix().to_4x4()
    M = Matrix.Translation(Vector(base) + Vector(axis).normalized() * depth / 2) @ R
    res = bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=radius,
                                radius2=radius if radius2 is None else radius2, depth=depth, matrix=M)
    vs = set(res["verts"])
    for f in bm.faces:
        if all(v in vs for v in f.verts):
            f.material_index = mat


def frame_at(p, n, up=(0, 0, 1)):
    """Axes for a part sitting on the surface at p with normal n: x along the
    surface (sideways), y = out of the surface, z up the surface."""
    n = Vector(n).normalized()
    z = (Vector(up) - n * n.dot(Vector(up))).normalized()
    x = z.cross(n).normalized()
    return x, n, z


def torus(bm, centre, axis, major, minor, mat, segs=(16, 6)):
    R = Vector((0, 0, 1)).rotation_difference(Vector(axis).normalized()).to_matrix().to_4x4()
    M = Matrix.Translation(Vector(centre)) @ R
    grid = []
    for i in range(segs[0]):
        t = 2 * math.pi * i / segs[0]
        grid.append([bm.verts.new(M @ Vector(((major + minor * math.cos(u)) * math.cos(t), (major + minor * math.cos(u)) * math.sin(t),
                                               minor * math.sin(u)))) for u in (2 * math.pi * j / segs[1] for j in range(segs[1]))])
    for i in range(segs[0]):
        for j in range(segs[1]):
            f = bm.faces.new((grid[i][j], grid[(i + 1) % segs[0]][j], grid[(i + 1) % segs[0]][(j + 1) % segs[1]], grid[i][(j + 1) % segs[1]]))
            f.material_index = mat


def base_jackets():
    """Every style's jacket (base_<style>_jacket) or skirt (base_<style>_skirt)."""
    out = []
    for name in BASE_STYLES:
        use_style(name)
        ob = base_skirt() if STYLE["jacket"] == "skirt" else base_jacket()
        if ob is not None:
            out.append(ob)
    use_style("gwen")
    return out


def base_skirt():
    """Ophelia's pick for Eco's suit: a pleated violet and black plaid mini skirt
    over it, riding just under her belts (texture tartan.png, from tartan())."""
    tartan()
    return skirt("base_%s_skirt" % STYLE_NAME, 0.892, 0.72, ["eco_v_tartan"], gap=0.012, flare=0.035,
                 follow=(0.6, 0.92), rows=10, pleats=28)


def base_jacket():
    """The base suit's fashion piece (base_*, shown by eco_model.gd only with no
    suit upgrade), by STYLE["jacket"]:
      cropped  a cropped jacket, short sleeves, open at the front so the suit's
               neckline shows, its hem above her ribs at the back, an edge in
               the second colour all round ("gwen": deep teal, crimson edge)
      bomber   the same with sleeves to her forearms and a longer back
      half     the cropped jacket's left half only: one sleeve, its edge down her back
      cowl     a hooded shroud's cowl over her shoulders, up round her neck, its
               hem tattered, short at the front and down her shoulder blades at the back
      vest     a knitted sleeveless vest: no sleeves, the fronts stopping above her
               bust, down to her waist at the back (Mom knitted it)
    None of them for a style without one. Its materials are eco_v_jacket[_<style>]
    and ..._edge."""
    shape = STYLE["jacket"]
    if not shape:
        return None
    hem, cuff = (1.0, 0.33) if shape == "bomber" else (0.95, 0.2) if shape == "vest" else (1.035, 0.25)

    def keep(c, n):
        ax = abs(c.x)
        if shape == "cowl":
            if c.z > 1.203 or ax > 0.2:
                return False   # up to the top of her collar, over her shoulders only
            a = math.atan2(c.y, c.x)
            tatter = 0.018 * abs((a * 6 / math.pi) % 2 - 1)   # a zigzag hem, twelve points round her
            t = min(1.0, max(0.0, (c.y + 0.03) / 0.06))     # 0 at the front, 1 at the back
            return c.z > (1.105 + 0.12 * ax) * (1 - t) + 1.0 * t + tatter
        if c.z > 1.215 or (c.z > 1.165 and math.hypot(c.x, c.y - 0.022) < 0.075):
            return False   # her neck, under the collar, and anything of the body up inside her head
        if shape == "vest" and ax > 0.15:
            return False   # no sleeves
        if shape == "half" and c.x < -0.03:
            return False   # (no cutting plane: a bisected edge leaves a ragged border)
        if ax > 0.15:
            return c.z > 1.0   # the sleeves
        if c.z < hem or (c.y < -0.04 and (c.z < 1.065 or n.z < -0.3)):
            return False   # the fronts stop above the underside of her bust
        return not (c.y < 0 and ax < 0.07 + 0.2 * max(0.0, 1.12 - c.z))   # open front, curving away
    planes = [((0, 0, hem), (0, 0, -1)), ((cuff, 0, 0), (1, 0, 0)), ((-cuff, 0, 0), (-1, 0, 0))]
    if shape == "cowl":
        planes = []   # its ragged hem is its own
    mat = "eco_v_jacket" + ("" if STYLE_NAME == "gwen" else "_" + STYLE_NAME)
    thick = 0.009 if shape == "vest" else 0.006   # chunky knit
    ob = shell("base_%s_jacket" % STYLE_NAME, keep, planes=planes, gap=0.006, thick=thick, plate=mat, edge=mat + "_edge",
               smooth=2, smooth_edge=2 if shape == "cowl" else 5, border=1)
    # nothing may stand off her: a stray vertex here once made spikes behind her head
    bvh = _body_bvh()
    far = max((bvh.find_nearest(ob.matrix_world @ v.co)[3] or 0.0) for v in ob.data.vertices)
    top = max(v.co.z for v in ob.data.vertices)
    print("base_%s_jacket: furthest point %.3f m off her, top at z %.3f" % (STYLE_NAME, far, top))
    assert top < 1.23, "base_jacket reaches up into her head"
    assert far < 0.03, "base_jacket has a spike"
    return ob


def light_suit(bvh):
    """The light suit (suit_t<tier>l_*): cloth and leather instead of plates.
      1  a durable cloth wrap: an underbust band that supports her chest and
         panels over the sides of her waist (the baked light suit closes its
         side cutouts and opens across the top of her chest instead), a
         leather choker with Dad's dog tag, a nose ring, wrapped forearms,
         one pouch on the belt
      2  a leather guard on her left shoulder
      3  leather knee pads, shin wraps, her stiletto's sheath on a right thigh garter
      4  a band round her left arm with a status light
      5  Dad's crest on the shoulder guard"""
    out = []
    # --- tier 1: the wrap. Underbust band, then a panel down each side of the waist.
    out.append(shell("suit_t1l_wrap_band", lambda c, n: 0.95 < c.z < 1.06,
                     planes=[((0, 0, 0.972), (0, 0, -1)), ((0, 0, 1.026), (0, 0, 1))],
                     gap=0.003, thick=0.003, plate="eco_v_cloth", edge="eco_v_armor_strap"))
    for s, side in ((1, "l"), (-1, "r")):
        out.append(shell("suit_t1l_wrap_side_" + side, lambda c, n: c.x * s > 0.03 and 0.85 < c.z < 0.99,
                         planes=[((0, 0, 0.865), (0, 0, -1)), ((0, 0, 0.978), (0, 0, 1)),
                                 ((s * 0.052, 0, 0), (-s, 0, 0)), ((0, -0.07, 0), (0, -1, 0)), ((0, 0.06, 0), (0, 1, 0))],
                         gap=0.002, thick=0.002, plate="eco_v_cloth", edge="eco_v_armor_strap"))
        # forearm wraps: three overlapping bands round the forearm, over the glove tops
        for k, (a, b) in enumerate(((0.37, 0.392), (0.388, 0.41), (0.406, 0.43))):
            out.append(shell("suit_t1l_armwrap%d_%s" % (k, side),
                             lambda c, n: c.x * s > 0.33 and abs(c.z - 1.145) < 0.06 and abs(c.y - 0.022) < 0.06,
                             planes=[((s * a, 0, 0), (-s, 0, 0)), ((s * b, 0, 0), (s, 0, 0))],
                             gap=0.0025 + 0.0015 * k, thick=0.002, plate="eco_v_cloth", edge="eco_v_cloth"))
    # choker high on her neck, a ring at the front and Dad's tag hanging from it
    out.append(shell("suit_t1l_choker", lambda c, n: 1.18 < c.z < 1.24 and math.hypot(c.x, c.y - 0.022) < 0.07,
                     planes=[((0, 0, 1.206), (0, 0, -1)), ((0, 0, 1.222), (0, 0, 1))],
                     gap=0.002, thick=0.003, plate="eco_v_armor_strap", edge="eco_v_leather"))
    bm = bmesh.new()
    p, n = surface(bvh, (0, -0.5, 1.214), (0, 1, 0))
    fwd = Vector((0, -1, 0))
    torus(bm, p + fwd * 0.007 + Vector((0, 0, -0.004)), fwd, 0.006, 0.0012, 0)
    tag = p + fwd * 0.012 + Vector((0, 0, -0.024))
    box(bm, tag, (Vector((1, 0, 0)), fwd, Vector((0, 0, 1))), (0.014, 0.002, 0.022), 0, bevel=0.003)
    out.append(rigid("suit_t1l_tag", bm, ["eco_v_armor_edge"], "J_Bip_C_Neck"))
    # a small hoop through her left nostril (the nose tip is at (0, -0.0705, 1.2606))
    bm = bmesh.new()
    torus(bm, (0.0042, -0.0666, 1.2556), Vector((1, 0.25, 0)), 0.0035, 0.0007, 0, segs=(14, 5))
    out.append(rigid("suit_t1l_nose_ring", bm, ["eco_v_armor_edge"], "J_Bip_C_Head"))
    # one pouch on the belt, right hip
    bm = bmesh.new()
    p, n = surface(bvh, (-0.5, -0.015, 0.93), (1, 0, 0))
    x, y, z = frame_at(p, n)
    box(bm, p + y * 0.02 + z * -0.006, (x, y, z), (0.055, 0.03, 0.05), 0)
    box(bm, p + y * 0.022 + z * 0.018, (x, y, z), (0.058, 0.034, 0.014), 1, bevel=0.003)
    out.append(rigid("suit_t1l_pouch", bm, ["eco_v_leather", "eco_v_armor_strap"], "J_Bip_C_Hips"))
    # --- tier 2: a leather guard on her left shoulder only
    out.append(shell("suit_t2l_shoulder_l",
                     lambda c, n: 0.06 < c.x < 0.2 and c.z > 1.1,
                     planes=[((0.085, 0, 0), (-1, 0, 0)), ((0.175, 0, 0), (1, 0, 0)), ((0, 0, 1.135), (0, 0, -1))],
                     gap=0.008, thick=0.005, plate="eco_v_leather", edge="eco_v_armor_strap"))
    for s, side in ((1, "l"), (-1, "r")):
        # --- tier 3: leather knee pads, shin wraps
        out.append(shell("suit_t3l_knee_" + side,
                         lambda c, n: c.y < 0.06 and 0.4 < c.z < 0.56 and c.x * s > 0.0,
                         planes=[((0, 0, 0.44), (0, 0, -1)), ((0, 0, 0.505), (0, 0, 1)), ((0, -0.012, 0), (0, 1, 0))],
                         gap=0.008, thick=0.005, plate="eco_v_leather", edge="eco_v_armor_strap"))
        for k, (a, b) in enumerate(((0.2, 0.225), (0.22, 0.245), (0.24, 0.265))):
            out.append(shell("suit_t3l_shinwrap%d_%s" % (k, side), lambda c, n: 0.15 < c.z < 0.3 and c.x * s > 0.0,
                             planes=[((0, 0, a), (0, 0, -1)), ((0, 0, b), (0, 0, 1))],
                             gap=0.0025 + 0.0015 * k, thick=0.002, plate="eco_v_cloth", edge="eco_v_cloth"))
    # the stiletto's sheath on a garter round her right thigh
    out.append(shell("suit_t3l_garter", lambda c, n: c.x < 0.0 and 0.6 < c.z < 0.68,
                     planes=[((0, 0, 0.62), (0, 0, -1)), ((0, 0, 0.636), (0, 0, 1))],
                     gap=0.003, thick=0.003, plate="eco_v_armor_strap"))
    bm = bmesh.new()
    p, n = surface(bvh, (-0.5, -0.01, 0.6), (1, 0, 0))
    x, y, z = frame_at(p, n)
    box(bm, p + y * 0.011 - z * 0.01, (x, y, z), (0.022, 0.012, 0.11), 0, bevel=0.004)
    cylinder(bm, p + y * 0.011 + z * 0.044, z, 0.0055, 0.04, 1, segments=10)      # grip
    cylinder(bm, p + y * 0.011 + z * 0.042, z, 0.011, 0.004, 1, segments=10)      # guard
    out.append(rigid("suit_t3l_sheath", bm, ["eco_v_leather", "eco_v_armor_strap"], "J_Bip_R_UpperLeg"))
    # --- tier 4: a band round her left upper arm with a status light
    out.append(shell("suit_t4l_armband", lambda c, n: 0.15 < c.x < 0.27,
                     planes=[((0.2, 0, 0), (-1, 0, 0)), ((0.222, 0, 0), (1, 0, 0))],
                     gap=0.003, thick=0.003, plate="eco_v_armor_strap", edge="eco_v_leather"))
    bm = bmesh.new()
    p, n = surface(bvh, (0.211, 0.022, 1.5), (0, 0, -1))
    box(bm, p + Vector((0, 0, 0.007)), (Vector((1, 0, 0)), Vector((0, 0, 1)), Vector((0, -1, 0))), (0.016, 0.004, 0.01), 0, bevel=0.001)
    out.append(rigid("suit_t4l_armlight", bm, ["eco_v_armor_glow"], "J_Bip_L_UpperArm"))
    # --- tier 5: Dad's crest on the shoulder guard
    bm = bmesh.new()
    p, n = surface(bvh, (0.13, 0.022, 1.6), (0, 0, -1))
    x, y, z = frame_at(p, n, up=(0, -1, 0))
    cylinder(bm, p + y * 0.0135, y, 0.014, 0.003, 0, segments=6)
    cylinder(bm, p + y * 0.0155, y, 0.007, 0.002, 1, segments=6)
    out.append(rigid("suit_t5l_crest", bm, ["eco_v_armor_edge", "eco_v_armor_glow"], "J_Bip_L_UpperArm"))
    return out


def heavy_extras(bvh):
    """The heavy suit's own pieces beyond the gunmetal plates in suit_armor:
      1  a breastplate cut from Dad's titan's hull, a comm earpiece with a mic
      4  the titan's old core light set in the breastplate"""
    out = []
    # a plate shaped to her chest, lifted clear of the suit and smoothed so it reads as one stiff piece
    plate = shell("suit_t1h_breastplate",
                  lambda c, n: c.y < 0.0 and 0.94 < c.z < 1.14 and abs(c.x) < 0.14,
                  planes=[((0, 0, 0.978), (0, 0, -1)), ((0, 0, 1.118), (0, 0, 1)), ((0.112, 0, 0), (1, 0, 0)),
                          ((-0.112, 0, 0), (-1, 0, 0)), ((0, -0.02, 0), (0, 1, 0))],
                  gap=0.012, thick=0.007, smooth=12)
    out.append(plate)
    # comm earpiece over her left ear, a mic boom to the corner of her mouth
    bm = bmesh.new()
    ear = Vector((0.079, 0.012, 1.29))
    cylinder(bm, ear - Vector((0.004, 0, 0)), Vector((1, 0, 0)), 0.013, 0.012, 0, segments=14)
    cylinder(bm, ear + Vector((0.008, 0, 0)), Vector((1, 0, 0)), 0.006, 0.003, 1, segments=10)    # status light
    tip = Vector((0.034, -0.062, 1.238))
    d = tip - ear
    cylinder(bm, ear, d, 0.0022, d.length, 0, segments=6)
    cylinder(bm, tip - d.normalized() * 0.004, d, 0.0045, 0.009, 0, segments=8)
    out.append(rigid("suit_t1h_comm", bm, ["eco_v_armor", "eco_v_armor_glow"], "J_Bip_C_Head"))
    # --- tier 4: the core light in the middle of the breastplate
    dg = bpy.context.evaluated_depsgraph_get()
    hit, _n = surface(BVHTree.FromObject(plate, dg), (0, -0.5, 1.066), (0, 1, 0))
    p = hit if hit is not None else Vector((0, -0.11, 1.066))
    n = Vector((0, -1, 0))
    bm = bmesh.new()
    cylinder(bm, p - n * 0.003, n, 0.019, 0.007, 1, segments=16)
    cylinder(bm, p + n * 0.003, n, 0.012, 0.003, 0, segments=16)
    out.append(rigid("suit_t4h_core", bm, ["eco_v_armor_glow", "eco_v_armor_edge"], "J_Bip_C_Chest"))
    return out


def medium_suit(bvh):
    """The medium suit (suit_t<tier>m_*): a mechanic's rig of canvas, rubber and
    tools over her jumpsuit (suit_graph's medium cut).
      1  a canvas scarf knotted at her neck, a crossed plaster on her right
         cheek, a tool pouch on her left hip with a spanner and a screwdriver
      2  a canvas yoke over her shoulders, a rubber pad on her right elbow
      3  rubber knee caps on straps, a cargo pocket on her right thigh
      4  a wrist computer strapped to her bare left forearm
      5  Dad's crest on a patch on the yoke"""
    out = []
    dg = bpy.context.evaluated_depsgraph_get()
    face_bvh = BVHTree.FromObject(bpy.data.objects["Face"], dg)
    # --- tier 1: the scarf round her neck, knotted at the front left
    out.append(shell("suit_t1m_scarf", lambda c, n: 1.15 < c.z < 1.24 and math.hypot(c.x, c.y - 0.022) < 0.075,
                     planes=[((0, 0, 1.166), (0, 0, -1)), ((0, 0, 1.204), (0, 0, 1))],
                     gap=0.007, thick=0.005, plate="eco_v_canvas", edge="eco_v_canvas"))
    bm = bmesh.new()
    p, n = surface(bvh, (0.032, -0.5, 1.18), (0, 1, 0))
    x, y, z = frame_at(p, n)
    k = p + y * 0.014
    box(bm, k, (x, y, z), (0.022, 0.016, 0.02), 0, bevel=0.006)
    for t, ang in ((-1, 0.35), (1, -0.15)):   # two tails falling over her collarbone
        tz = (z * math.cos(ang) + x * math.sin(ang)).normalized()
        box(bm, k + x * (t * 0.006) - tz * 0.03 + y * 0.002, (tz.cross(y).normalized(), y, tz), (0.016, 0.005, 0.045), 0, bevel=0.0025)
    out.append(rigid("suit_t1m_scarf_knot", bm, ["eco_v_canvas"], "J_Bip_C_Neck"))
    # a crossed plaster high on her right cheek
    bm = bmesh.new()
    p, n = surface(face_bvh, (-0.03, -0.5, 1.262), (0, 1, 0))
    if p is not None:
        x, y, z = frame_at(p, n)
        for ang in (0.6, -0.6):
            ax_ = (x * math.cos(ang) + z * math.sin(ang)).normalized()
            box(bm, p + y * 0.0012, (ax_, y, y.cross(ax_).normalized()), (0.016, 0.0012, 0.005), 0, bevel=0.0008)
    out.append(rigid("suit_t1m_plaster", bm, ["eco_v_tape"], "J_Bip_C_Head"))
    # the tool pouch on her left hip, a spanner and a screwdriver standing in it
    bm = bmesh.new()
    p, n = surface(bvh, (0.5, -0.01, 0.9), (-1, 0, 0))
    x, y, z = frame_at(p, n)
    c = p + y * 0.022 - z * 0.02
    box(bm, c, (x, y, z), (0.06, 0.03, 0.065), 0)
    box(bm, c + y * 0.016 - z * 0.004, (x, y, z), (0.05, 0.004, 0.045), 1, bevel=0.002)    # strap across it
    box(bm, c + x * -0.012 + z * 0.05, (x, y, z), (0.008, 0.005, 0.05), 2, bevel=0.002)   # spanner handle
    torus(bm, c + x * -0.012 + z * 0.08, y, 0.008, 0.0028, 2, segs=(12, 5))               # its ring end
    cylinder(bm, c + x * 0.014 + z * 0.03, z, 0.006, 0.035, 3, segments=8)                # screwdriver handle
    cylinder(bm, c + x * 0.014 + z * 0.065, z, 0.0022, 0.012, 2, segments=6)
    out.append(rigid("suit_t1m_toolpouch", bm, ["eco_v_canvas", "eco_v_armor_strap", "eco_v_armor_edge", "eco_v_rust"],
                     "J_Bip_C_Hips"))
    # --- tier 2: a canvas yoke over her shoulders, low on the back, at the collarbone in front
    out.append(shell("suit_t2m_yoke",
                     lambda c, n: 1.05 < c.z < 1.25 and abs(c.x) < 0.2 and (math.hypot(c.x, c.y - 0.022) > 0.06 or c.z < 1.16),
                     planes=[((0, 0, 1.12), Vector((0, -0.5, -1)).normalized()), ((0.15, 0, 0), (1, 0, 0)), ((-0.15, 0, 0), (-1, 0, 0))],
                     gap=0.009, thick=0.006, plate="eco_v_canvas", edge="eco_v_armor_strap"))
    out.append(shell("suit_t2m_elbow_r",
                     lambda c, n: -0.34 < c.x < -0.24 and c.z > 1.1,
                     planes=[((-0.268, 0, 0), (1, 0, 0)), ((-0.308, 0, 0), (-1, 0, 0)), ((0, 0, 1.13), (0, 0, -1))],
                     gap=0.008, thick=0.008, plate="eco_v_rust", edge="eco_v_rust"))
    # --- tier 3: rubber knee caps on two straps; a cargo pocket on her right thigh
    for s, side in ((1, "l"), (-1, "r")):
        bm = bmesh.new()
        p, n = surface(bvh, (s * 0.069, -0.5, 0.478), (0, 1, 0))
        cylinder(bm, p - n * 0.004, n, 0.03, 0.02, 0, segments=14, radius2=0.019)
        out.append(rigid("suit_t3m_kneecap_" + side, bm, ["eco_v_rust"], "J_Bip_%s_LowerLeg" % side.upper()))
        for a, b in ((0.425, 0.437), (0.515, 0.527)):
            out.append(shell("suit_t3m_kneestrap%d_%s" % (int(a > 0.5), side), lambda c, n: 0.38 < c.z < 0.58 and c.x * s > 0.0,
                             planes=[((0, 0, a), (0, 0, -1)), ((0, 0, b), (0, 0, 1))],
                             gap=0.004, thick=0.003, plate="eco_v_armor_strap"))
    out.append(shell("suit_t3m_thighstrap", lambda c, n: c.x < 0.0 and 0.66 < c.z < 0.74,
                     planes=[((0, 0, 0.7), (0, 0, -1)), ((0, 0, 0.714), (0, 0, 1))],
                     gap=0.003, thick=0.003, plate="eco_v_armor_strap"))
    bm = bmesh.new()
    p, n = surface(bvh, (-0.5, -0.005, 0.67), (1, 0, 0))
    x, y, z = frame_at(p, n)
    box(bm, p + y * 0.016, (x, y, z), (0.062, 0.026, 0.075), 0)
    box(bm, p + y * 0.018 + z * 0.03, (x, y, z), (0.066, 0.03, 0.02), 0, bevel=0.003)     # flap
    box(bm, p + y * 0.034 + z * 0.018, (x, y, z), (0.01, 0.004, 0.012), 1, bevel=0.001)   # press stud
    out.append(rigid("suit_t3m_cargo", bm, ["eco_v_canvas", "eco_v_armor_edge"], "J_Bip_R_UpperLeg"))
    # --- tier 4: a wrist computer on her bare left forearm
    out.append(shell("suit_t4m_wriststrap", lambda c, n: 0.3 < c.x < 0.42 and abs(c.z - 1.145) < 0.06,
                     planes=[((0.338, 0, 0), (-1, 0, 0)), ((0.392, 0, 0), (1, 0, 0))],
                     gap=0.003, thick=0.004, plate="eco_v_armor_strap", edge="eco_v_canvas"))
    bm = bmesh.new()
    p, n = surface(bvh, (0.365, 0.022, 1.5), (0, 0, -1))
    X, Y, Z = Vector((1, 0, 0)), Vector((0, 0, 1)), Vector((0, -1, 0))
    box(bm, p + Y * 0.011, (X, Y, Z), (0.05, 0.014, 0.036), 0, bevel=0.003)
    box(bm, p + Y * 0.0185, (X, Y, Z), (0.034, 0.002, 0.024), 1, bevel=0.0008)            # screen
    for t in (-1, 1):
        cylinder(bm, p + Y * 0.016 + X * (t * 0.021) + Z * 0.012, Y, 0.0025, 0.004, 2, segments=8)   # dials
    out.append(rigid("suit_t4m_wristcomp", bm, ["eco_v_armor", "eco_v_armor_glow", "eco_v_rust"], "J_Bip_L_LowerArm"))
    # --- tier 5: Dad's crest on a patch on the yoke's right shoulder
    bm = bmesh.new()
    p, n = surface(bvh, (-0.12, 0.022, 1.6), (0, 0, -1))
    x, y, z = frame_at(p, n, up=(0, -1, 0))
    box(bm, p + y * 0.0165, (x, y, z), (0.036, 0.002, 0.036), 0, bevel=0.002)
    cylinder(bm, p + y * 0.0175, y, 0.013, 0.003, 1, segments=6)
    cylinder(bm, p + y * 0.0195, y, 0.0065, 0.002, 2, segments=6)
    out.append(rigid("suit_t5m_crest", bm, ["eco_v_rust", "eco_v_armor_edge", "eco_v_armor_glow"], "J_Bip_R_UpperArm"))
    return out


def suit_armor():
    """Eco's suit upgrades (scripts/hub/armory.gd SUIT_TIERS), modelled on her in
    rest space (she faces -Y, her left is +X, T-pose). Every piece is named
    suit_t<tier><weight>_<part>; the game shows the pieces of every tier she has
    bought (eco_model.gd suit_tier). <weight> is the suit weights that wear the
    piece (armory.gd SUIT_WEIGHTS): none for all three (the belt, the seal
    injector, the jump pack), "l" light only (light_suit), "m" medium only
    (medium_suit), "h" heavy only: the gunmetal plates here. Each tier adds to the last:
      1 Scav rig      forearm bracers, a belt with hip pouches
      2 Seal weave    layered shoulder plates, a thigh strap with a seal injector
      3 Dampers       shin guards and knee cops, hip plates
      4 Jump kit      a jump pack low on her back, an armoured collar
      5 Dad's colours crests on her shoulders (the game repaints the plates white
                      and turns every trim gold)"""
    bvh = _body_bvh()
    out = []
    for s, side in ((1, "l"), (-1, "r")):
        S = Vector((s, 1, 1))

        def m(v):
            return Vector(v) * S if isinstance(v, Vector) else Vector((v[0] * s, v[1], v[2]))
        # --- tier 1: bracers over the glove tops (the arm runs along X at z 1.145)
        out.append(shell("suit_t1h_bracer_" + side,
                         lambda c, n: c.x * s > 0.3 and abs(c.z - 1.145) < 0.06 and abs(c.y - 0.022) < 0.06,
                         planes=[(m((0.335, 0, 0)), m((-1, 0, 0))), (m((0.455, 0, 0)), m((1, 0, 0))),
                                 ((0, 0, 1.128), (0, 0, -1))],
                         gap=0.005, thick=0.005))
        # --- tier 2: shoulder plates, two lames
        out.append(shell("suit_t2h_pauldron_" + side,
                         lambda c, n: 0.06 < c.x * s < 0.2 and c.z > 1.1,
                         planes=[(m((0.07, 0, 0)), m((-1, 0, 0))), (m((0.165, 0, 0)), m((1, 0, 0))),
                                 ((0, 0, 1.13), (0, 0, -1))],
                         gap=0.012, thick=0.006))
        out.append(shell("suit_t2h_pauldron_lame_" + side,
                         lambda c, n: 0.1 < c.x * s < 0.25 and c.z > 1.1,
                         planes=[(m((0.15, 0, 0)), m((-1, 0, 0))), (m((0.215, 0, 0)), m((1, 0, 0))),
                                 ((0, 0, 1.128), (0, 0, -1))],
                         gap=0.007, thick=0.005))
        # --- tier 3: shin guards and knee cops (knee at z 0.467, leg centre x 0.069)
        out.append(shell("suit_t3h_shin_" + side,
                         lambda c, n: c.y < 0.06 and 0.1 < c.z < 0.5 and c.x * s > 0.0,
                         planes=[((0, 0, 0.17), (0, 0, -1)), ((0, 0, 0.425), (0, 0, 1)), ((0, 0.012, 0.467), (0, 0.998, 0.06))],
                         gap=0.006, thick=0.006))
        out.append(shell("suit_t3h_knee_" + side,
                         lambda c, n: c.y < 0.06 and 0.4 < c.z < 0.56 and c.x * s > 0.0,
                         planes=[((0, 0, 0.43), (0, 0, -1)), ((0, 0, 0.52), (0, 0, 1)), ((0, -0.006, 0), (0, 1, 0))],
                         gap=0.009, thick=0.006))
        out.append(shell("suit_t3h_hip_" + side,
                         lambda c, n: c.x * s > 0.06 and 0.7 < c.z < 0.93,
                         planes=[((0, 0, 0.745), (0, 0, -1)), ((0, 0, 0.9), (0, 0, 1)), (m((0.085, 0, 0)), m((-1, 0, 0))),
                                 ((0, -0.05, 0), (0, -1, 0)), ((0, 0.05, 0), (0, 1, 0))],
                         gap=0.009, thick=0.005))
        out.append(shell("suit_t3h_hip_lame_" + side,
                         lambda c, n: c.x * s > 0.06 and 0.66 < c.z < 0.8,
                         planes=[((0, 0, 0.705), (0, 0, -1)), ((0, 0, 0.755), (0, 0, 1)), (m((0.09, 0, 0)), m((-1, 0, 0))),
                                 ((0, -0.042, 0), (0, -1, 0)), ((0, 0.042, 0), (0, 1, 0))],
                         gap=0.007, thick=0.004))
        # --- heavy only: elbow cops, upper-arm plates, thigh plates (cuisses)
        out.append(shell("suit_t1h_elbow_" + side,
                         lambda c, n: 0.24 < c.x * s < 0.34 and c.z > 1.1,
                         planes=[(m((0.266, 0, 0)), m((-1, 0, 0))), (m((0.31, 0, 0)), m((1, 0, 0))),
                                 ((0, 0, 1.132), (0, 0, -1))],
                         gap=0.009, thick=0.006))
        out.append(shell("suit_t2h_rerebrace_" + side,
                         lambda c, n: 0.17 < c.x * s < 0.29 and c.z > 1.1,
                         planes=[(m((0.205, 0, 0)), m((-1, 0, 0))), (m((0.262, 0, 0)), m((1, 0, 0))),
                                 ((0, 0, 1.126), (0, 0, -1))],
                         gap=0.006, thick=0.005))
        out.append(shell("suit_t3h_cuisse_" + side,
                         lambda c, n: c.y < 0.04 and 0.5 < c.z < 0.66 and c.x * s > 0.0,
                         planes=[((0, 0, 0.535), (0, 0, -1)), ((0, 0, 0.612), (0, 0, 1)), ((0, 0.0, 0), (0, 1, 0))],
                         gap=0.007, thick=0.006))
    # --- tier 1: the belt, sitting on the suit's waist band, and two hip pouches
    out.append(shell("suit_t1_belt", lambda c, n: 0.89 < c.z < 0.97 and abs(c.x) < 0.25,
                     planes=[((0, 0, 0.913), (0, 0, -1)), ((0, 0, 0.947), (0, 0, 1))],
                     gap=0.004, thick=0.004, plate="eco_v_armor_strap"))
    bm = bmesh.new()
    for s in (1, -1):
        p, n = surface(bvh, (s * 0.5, -0.015, 0.93), (-s, 0, 0))
        x, y, z = frame_at(p, n)
        box(bm, p + y * 0.022 + z * -0.008, (x, y, z), (0.07, 0.036, 0.06), 0)
        box(bm, p + y * 0.024 + z * 0.02, (x, y, z), (0.074, 0.042, 0.016), 1, bevel=0.003)   # flap
    out.append(rigid("suit_t1h_pouches", bm, ["eco_v_armor_pouch", "eco_v_armor_strap"], "J_Bip_C_Hips"))
    # --- tier 2: strap round her left thigh with the seal injector on the outside
    out.append(shell("suit_t2_thigh_strap", lambda c, n: c.x > 0.0 and 0.6 < c.z < 0.68,
                     planes=[((0, 0, 0.622), (0, 0, -1)), ((0, 0, 0.642), (0, 0, 1))],
                     gap=0.003, thick=0.003, plate="eco_v_armor_strap"))
    bm = bmesh.new()
    p, n = surface(bvh, (0.5, -0.01, 0.632), (-1, 0, 0))
    x, y, z = frame_at(p, n)
    box(bm, p + y * 0.012, (x, y, z), (0.03, 0.014, 0.05), 0, bevel=0.003)
    cylinder(bm, p + y * 0.026 - z * 0.03, z, 0.009, 0.06, 1)        # the vial (glows)
    cylinder(bm, p + y * 0.026 - z * 0.036, z, 0.0105, 0.008, 2)     # caps
    cylinder(bm, p + y * 0.026 + z * 0.028, z, 0.0105, 0.008, 2)
    cylinder(bm, p + y * 0.026 + z * 0.036, z, 0.004, 0.014, 2)      # needle housing
    out.append(rigid("suit_t2_injector", bm, ["eco_v_armor_strap", "eco_v_armor_glow", "eco_v_armor_edge"],
                     "J_Bip_L_UpperLeg"))
    # --- tier 4: jump pack low on her back, nozzles angled down and out
    bm = bmesh.new()
    p, n = surface(bvh, (0, 0.5, 0.95), (0, -1, 0))
    n = Vector((0, 1, 0))
    x, y, z = Vector((1, 0, 0)), n, Vector((0, 0, 1))
    c = p + y * 0.03
    box(bm, c, (x, y, z), (0.15, 0.045, 0.085), 0, bevel=0.008)
    box(bm, c + y * 0.024 + z * 0.012, (x, y, z), (0.11, 0.01, 0.04), 1, bevel=0.003)   # vent plate
    for s in (1, -1):
        d = (Vector((s * 0.35, 0.35, -1))).normalized()
        base = c + x * (s * 0.05) - z * 0.035
        cylinder(bm, base, d, 0.016, 0.035, 1, radius2=0.021)
        cylinder(bm, base + d * 0.034, d, 0.017, 0.004, 2)
    box(bm, c + y * 0.026 + z * 0.012, (x, y, z), (0.08, 0.004, 0.006), 2, bevel=0)      # status strip
    out.append(rigid("suit_t4_jumpkit", bm, ["eco_v_armor", "eco_v_armor_edge", "eco_v_armor_glow"], "J_Bip_C_Spine"))
    out.append(shell("suit_t4h_backplate",
                     lambda c, n: c.y > 0.0 and 0.98 < c.z < 1.16 and abs(c.x) < 0.11,
                     planes=[((0, 0, 1.03), (0, 0, -1)), ((0, 0, 1.125), (0, 0, 1)), ((0.078, 0, 0), (1, 0, 0)),
                             ((-0.078, 0, 0), (-1, 0, 0)), ((0, 0.02, 0), (0, -1, 0))],
                     gap=0.008, thick=0.006))
    out.append(shell("suit_t4h_collar",
                     lambda c, n: 1.13 < c.z < 1.24 and math.hypot(c.x, c.y - 0.022) < 0.075,
                     planes=[((0, 0, 1.165), (0, 0, -1)), ((0, 0, 1.2), (0, 0, 1))],
                     gap=0.006, thick=0.005))
    # --- tier 5: Dad's crest on each shoulder plate
    for s, side in ((1, "l"), (-1, "r")):
        bm = bmesh.new()
        p, n = surface(bvh, (s * 0.115, 0.022, 1.6), (0, 0, -1))
        x, y, z = frame_at(p, n, up=(0, -1, 0))
        cylinder(bm, p + y * 0.0175, y, 0.016, 0.003, 0, segments=6)
        cylinder(bm, p + y * 0.0195, y, 0.008, 0.002, 1, segments=6)
        out.append(rigid("suit_t5h_crest_" + side, bm, ["eco_v_armor_edge", "eco_v_armor_glow"],
                         "J_Bip_%s_UpperArm" % side.upper()))
    out += heavy_extras(bvh)
    out += light_suit(bvh)
    out += medium_suit(bvh)
    print("suit armour: %d pieces" % len(out))
    return out


# --- rig: glute bones, proportions ------------------------------------------------

def glute_bones(arm):
    """Two short chains behind the hips (root inside the pelvis, tip at the glute)
    for the jiggle springs, with the glutes weighted to them."""
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones
    for s, side in ((1, "L"), (-1, "R")):
        b1 = eb.new("J_Sec_%s_Glute1" % side)
        b1.head, b1.tail = (s * 0.058, 0.01, 0.785), (s * 0.058, 0.01, 0.835)
        b1.parent = eb["J_Bip_C_Hips"]
        b2 = eb.new("J_Sec_%s_Glute2" % side)
        b2.head, b2.tail = (s * 0.058, 0.075, 0.765), (s * 0.058, 0.075, 0.815)
        b2.parent = b1
    bpy.ops.object.mode_set(mode="OBJECT")
    body = bpy.data.objects["Body"]
    rest = body.data.attributes["rest"].data
    for s, side in ((1, "L"), (-1, "R")):
        vg = body.vertex_groups.new(name="J_Sec_%s_Glute1" % side)
        for v in body.data.vertices:
            x, y, z = rest[v.index].vector
            if x * s <= 0:
                continue
            w = 0.75 * math.exp(-(((abs(x) - 0.058) / 0.042) ** 2 + ((z - 0.762) / 0.045) ** 2)) * smooth(0.0, 0.05, y)
            if w < 0.01:
                continue
            for g in v.groups:
                g.weight *= 1 - w
            vg.add([v.index], w, "REPLACE")


def descendants(bone):
    out = [bone]
    for c in bone.children:
        out += descendants(c)
    return out


def proportions(arm, objs):
    """A slightly smaller head (scaled about the top of the neck, weighted by how
    much each vertex follows the head) and 3% longer legs (below the hip joints)."""
    head = arm.data.bones["J_Bip_C_Head"]
    c = head.head_local.copy()
    head_set = {b.name for b in descendants(head)}
    zh = arm.data.bones["J_Bip_L_UpperLeg"].head_local.z

    def head_map(p, w):
        return c + (p - c) * (1 - (1 - HEAD_SCALE) * w)

    def leg_map(p):
        return Vector((p.x, p.y, zh - (zh - p.z) * LEG_SCALE)) if p.z < zh else p
    for ob in objs:
        names = {g.index: g.name for g in ob.vertex_groups}
        me = ob.data
        ws = [sum(g.weight for g in v.groups if names.get(g.group) in head_set) for v in me.vertices]
        if me.shape_keys:
            for kb in me.shape_keys.key_blocks:
                for i, w in enumerate(ws):
                    kb.data[i].co = leg_map(head_map(kb.data[i].co.copy(), min(w, 1.0)))
        for v, w in zip(me.vertices, ws):
            v.co = leg_map(head_map(v.co.copy(), min(w, 1.0)))
    leg_set = set()
    for s in "LR":
        leg_set |= {b.name for b in descendants(arm.data.bones["J_Bip_%s_UpperLeg" % s])}
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for e in arm.data.edit_bones:
        if e.name in head_set and e.name != "J_Bip_C_Head":
            e.head, e.tail = head_map(e.head.copy(), 1.0), head_map(e.tail.copy(), 1.0)
        elif e.name in leg_set:
            off = e.tail - e.head
            e.head = leg_map(e.head.copy())
            e.tail = e.head + off
    bpy.ops.object.mode_set(mode="OBJECT")


def prune_bones(arm):
    """Bones for things she no longer has: the skirt, the tail and the fox ears."""
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones
    dead = [e for e in eb if "Skirt" in e.name or "FoxTail" in e.name or "Tail" in e.name
            or any(e.name == "J_Sec_Hair%d_%d" % (i, j) for i in range(1, 5) for j in (10, 11))]
    for e in dead:
        eb.remove(e)
    bpy.ops.object.mode_set(mode="OBJECT")
    names = {b.name for b in arm.data.bones}
    for ob in arm.children:
        for g in list(ob.vertex_groups):
            if g.name.startswith(("J_Sec_", "J_Opt_")) and g.name not in names:
                ob.vertex_groups.remove(g)
    print("pruned %d bones" % len(dead))


def face_forward_and_scale(arm, objs):
    """Turn her to face +Y (the old Eco's facing, so the game's -Z forward) and
    scale to her height, then apply both so the rig is in metres."""
    dg = bpy.context.evaluated_depsgraph_get()
    top = 0.0
    for ob in objs:
        if ob.name == "Goggles":
            continue
        me = ob.evaluated_get(dg).to_mesh()
        top = max(top, max(v.co.z for v in me.vertices))
        ob.evaluated_get(dg).to_mesh_clear()
    k = HEIGHT / top
    arm.rotation_mode = "QUATERNION"
    arm.rotation_quaternion = Quaternion((0, 0, 1), math.pi)
    arm.scale = (k, k, k)
    bpy.context.view_layer.update()
    for o in bpy.data.objects:
        o.select_set(o == arm or o in objs)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    print("scaled by %.3f to %.2f m, facing +Y" % (k, HEIGHT))


# --- suit bake ----------------------------------------------------------------------

class NG:
    """Tiny node-graph builder so shader maths reads like maths."""

    def __init__(self, nt):
        self.nt = nt

    def put(self, sock, v):
        if isinstance(v, (int, float)):
            sock.default_value = v
        else:
            self.nt.links.new(v, sock)

    def op(self, operation, a, b=None):
        n = self.nt.nodes.new("ShaderNodeMath")
        n.operation = operation
        self.put(n.inputs[0], a)
        if b is not None:
            self.put(n.inputs[1], b)
        return n.outputs[0]

    def _f(self, a, b, py, op):
        return py(a, b) if isinstance(a, (int, float)) and isinstance(b, (int, float)) else self.op(op, a, b)

    def add(self, a, b):
        return self._f(a, b, lambda p, q: p + q, "ADD")

    def sub(self, a, b):
        return self._f(a, b, lambda p, q: p - q, "SUBTRACT")

    def mul(self, a, b):
        return self._f(a, b, lambda p, q: p * q, "MULTIPLY")

    def div(self, a, b):
        return self.op("DIVIDE", a, b)

    def mn(self, a, b):
        return self.op("MINIMUM", a, b)

    def mx(self, a, b):
        return self.op("MAXIMUM", a, b)

    def abs(self, a):
        return self.op("ABSOLUTE", a)

    def sqrt(self, a):
        return self.op("SQRT", a)

    def sq(self, a):
        return self.op("MULTIPLY", a, a)

    def neg(self, a):
        return self.mul(a, -1.0)

    def lerp(self, a, b, t):
        return self.add(a, self.mul(self.sub(b, a), t))

    def sstep(self, e0, e1, x):
        n = self.nt.nodes.new("ShaderNodeMapRange")
        n.interpolation_type = "SMOOTHSTEP"
        n.clamp = True
        self.put(n.inputs[0], x)
        n.inputs[1].default_value, n.inputs[2].default_value = e0, e1
        n.inputs[3].default_value, n.inputs[4].default_value = 0.0, 1.0
        return n.outputs[0]

    def band(self, x, lo, hi, aa=0.00035):
        return self.mul(self.sstep(lo - aa, lo + aa, x), self.sub(1.0, self.sstep(hi - aa, hi + aa, x)))

    def mixc(self, a, b, t, blend="MIX"):
        n = self.nt.nodes.new("ShaderNodeMix")
        n.data_type = "RGBA"
        n.blend_type = blend
        self.put(n.inputs[0], t)
        for sock, v in ((n.inputs[6], a), (n.inputs[7], b)):
            if isinstance(v, tuple):
                sock.default_value = v if len(v) == 4 else (*v, 1)
            else:
                self.nt.links.new(v, sock)
        return n.outputs[2]


def crease_lines(g, x, y, z, width):
    """The crease between her glutes (from the top of her cheeks down to where
    they end, never lower) and the fold under each one, as soft lines 'width'
    wide, in rest space."""
    ax = g.abs(x)
    back = g.sstep(0.025, 0.045, y)
    cleft = g.mul(g.mul(g.op("EXPONENT", g.neg(g.sq(g.div(x, width)))), g.sstep(0.772, 0.792, z)), g.sstep(0.862, 0.835, z))
    fold = g.op("EXPONENT", g.neg(g.sq(g.div(g.sub(z, FOLD_Z), width))))
    fold = g.mul(g.mul(fold, g.sstep(0.014, 0.032, ax)), g.sstep(0.105, 0.065, ax))
    return g.mul(g.mx(cleft, fold), back)


def base_details(g, x, y, z, skin, col, c_suit, c_gear, front, AA):
    """The base pilot suit's look over the plain bodysuit, in the STYLE picked
    (BASE_STYLES). The game's style, "gwen": a full stretch suit built to move and
    breathe, with some fashion on it.
      - a sweetheart line over her bust, solid below it and breathable black mesh
        above it up to the collar, piped in teal
      - crimson panels down her sides and the outside of her legs (perforated
        over her ribs to breathe), and crimson sleeves down to her gloves
      - a black corset belt cinched round her waist, laced up the front in crimson
      - a zip down her back, collar to the small of her back, so she can get in
      - no knee plates, and her ankle boots with no painted shafts above them
    Returns (colour, ink line, glowing trim, gloss: where the sheen shows)."""
    S = STYLE
    ax = g.abs(x)
    on = g.mul(c_suit, g.sub(1.0, c_gear))
    back = g.sstep(0.02, 0.04, y)
    ink = g.mul(on, 0.0)
    trim = g.mul(on, 0.0)
    matte = g.mul(on, 0.0)   # where a glossy suit (STYLE gloss) has matte parts

    # the suit stretches paler over her bust and glutes (under the panels, so a
    # pale suit's stretch never lands on a dark panel)
    def bell(cx, cy, cz, r):
        d2 = g.add(g.add(g.sq(g.sub(ax, cx)), g.sq(g.sub(y, cy))), g.sq(g.sub(z, cz)))
        return g.op("EXPONENT", g.mul(d2, -1.0 / (2 * r * r)))
    stretch = g.mx(bell(0.057, -0.105, 1.045, 0.03), bell(0.062, 0.06, 0.775, 0.042))
    col = g.mixc(col, S["stretch"], g.mul(g.mul(stretch, 0.35), on))

    def lines(v, step):
        f = g.op("FRACT", g.div(v, step))
        return g.mx(g.sub(1.0, g.sstep(0.0, 0.2, f)), g.sstep(0.8, 1.0, f))

    def frac(v, step):
        return g.sub(g.op("FRACT", g.div(v, step)), 0.5)

    def fill(d):   # inside a signed distance, on the suit
        return g.mul(g.sstep(-AA, AA, d), on)

    def edge(d, m=None):   # its ink line and the glowing piping just inside it
        nonlocal ink, trim
        k = on if m is None else g.mul(on, m)
        ink = g.mx(ink, g.mul(g.band(d, -0.0004, 0.0006), k))
        trim = g.mx(trim, g.mul(g.band(d, 0.0008, 0.0018), k))

    def box(cx, cz, hw, hh, side=front):   # a small rectangle (buckles, pouches) at |x| = cx
        return g.mul(g.mul(g.band(ax, cx - hw, cx + hw), g.band(z, cz - hh, cz + hh)), g.mul(side, on))

    def stripe(v, lo, hi):
        return g.band(v, lo, hi, 0.0003)

    # breathable mesh above the neckline, up to the collar
    if S["neck"]:
        if S["neck"] == "sweetheart":   # two arcs over her bust dipping between them
            dip = g.op("EXPONENT", g.neg(g.sq(g.div(ax, 0.013))))
            zs = g.sub(g.sub(1.088, g.mul(2.2, g.sq(g.sub(ax, 0.06)))), g.mul(0.024, dip))
        else:   # a V, its point above her bust
            zs = g.add(1.062, g.mul(0.9, ax))
        d_yoke = g.mn(g.mn(g.sub(z, zs), g.sub(1.163, z)), g.sub(0.15, ax))
        yoke = g.mul(fill(d_yoke), front)
        net = g.mx(lines(g.add(x, z), 0.0065), lines(g.sub(x, z), 0.0065))
        col = g.mixc(col, g.mixc(g.mixc(skin, S["suit"], 0.55), S["net"], net), yoke)
        ink = g.mx(ink, g.mul(g.mul(g.band(d_yoke, -0.0008, 0.0), front), on))
        trim = g.mx(trim, g.mul(g.mul(g.band(d_yoke, -0.0024, -0.0012), front), on))

    torso = g.mul(g.sub(1.0, g.sstep(0.16, 0.17, ax)), g.sstep(0.82, 0.84, z))   # not her arms or legs
    if S["panels"] == "sides":
        # panels down her sides and the outsides of her legs, and her sleeves
        th = g.lerp(0.108, 0.084, g.sstep(0.76, 0.8, z))
        th = g.mul(th, g.sstep(0.42, 0.52, z))   # below her knees it wraps all the way round (no seam ringing her calf)
        below_arm = g.sub(1.0, g.sstep(0.985, 0.995, z))
        d_panel = g.sub(ax, th)
        if S.get("legs") == "shins":   # her thighs stay the suit's colour: the sides of her body, and her legs below the knee
            d_panel = g.mx(g.mn(d_panel, g.sub(z, 0.8)), g.sub(0.47, z))
        panel = g.mul(fill(d_panel), below_arm)
        d_sleeve = g.mn(g.sub(ax, S["sleeve"]), g.sub(z, 1.0))   # her arms only (out sideways at rest), never her hips
        if S.get("lower"):   # and everything below her bust in the panel colour too (gwen's crimson leggings)
            d_sleeve = g.mx(d_sleeve, g.sub(1.0, z))
        col = g.mixc(col, S["panel"], g.mx(panel, fill(d_sleeve)))
        if S["vents"] == "ribs":   # perforated over her ribs so it breathes
            hole = g.sqrt(g.add(g.sq(frac(y, 0.0085)), g.sq(frac(z, 0.0085))))
            vent = g.mul(g.mul(g.sub(1.0, g.sstep(0.22, 0.3, hole)), g.band(z, 0.952, 0.982, 0.004)), g.mul(panel, g.sstep(0.004, 0.008, d_panel)))
            col = g.mixc(col, g.mixc(skin, INK, 0.45), vent)
        edge(d_panel, below_arm)
        edge(d_sleeve)
    elif S["panels"] == "racer":
        # a broad sash from her right shoulder across to her left hip, front and back
        d_sash = g.sub(0.022, g.abs(g.div(g.sub(g.mul(g.add(x, 0.13), -0.33), g.mul(g.sub(z, 1.17), 0.25)), 0.414)))
        d_sash = g.mn(d_sash, g.sub(0.17, ax))
        col = g.mixc(col, S["panel"], fill(d_sash))
        edge(d_sash, torso)
        # her left leg in colour, two racing stripes down the front of her right
        # a diagonal from her outer hip down to the inside of her thigh, well clear of her crotch (and never her arm)
        d_leg = g.mn(g.mn(g.sub(x, 0.0), g.sub(g.add(0.56, g.mul(2.0, g.sub(x, 0.03))), z)), g.sub(0.85, z))
        col = g.mixc(col, S["panel"], fill(d_leg))
        edge(d_leg)
        # and a stripe down the outside of each arm, shoulder to glove
        d_arm = g.mn(g.sub(ax, 0.18), g.sub(z, 1.163))
        col = g.mixc(col, S["panel"], fill(d_arm))
        edge(d_arm)
    elif S["panels"] == "harness":
        # a pilot's harness: straps over her shoulders down past her chest to a
        # belt, a strap across her upper chest, and a loop round each thigh tied
        # to the belt; orange stitching, silver buckles, chevrons on her left arm
        webs = []
        webs.append(g.mn(g.mn(g.sub(ax, 0.08), g.sub(0.098, ax)), g.mn(g.sub(z, 0.885), g.sub(1.21, z))))   # clear of her arms
        webs.append(g.mn(g.mn(g.sub(z, 1.104), g.sub(1.12, z)), g.mn(g.sub(0.098, ax), g.sub(0.5, back))))
        webs.append(g.mn(g.sub(z, 0.885), g.sub(0.915, z)))
        webs.append(g.mn(g.mn(g.sub(ax, 0.069), g.sub(0.085, ax)), g.mn(g.mn(g.sub(z, 0.635), g.sub(0.885, z)), g.sub(0.5, back))))
        webs.append(g.mn(g.mn(g.sub(z, 0.635), g.sub(0.652, z)), g.sub(0.2, ax)))
        d_web = webs[0]
        for w in webs[1:]:
            d_web = g.mx(d_web, w)
        col = g.mixc(col, S["panel"], fill(d_web))
        col = g.mixc(col, S["accent"], g.mul(g.band(d_web, 0.0011, 0.0017), on))   # stitching
        ink = g.mx(ink, g.mul(g.band(d_web, -0.0004, 0.0006), on))
        bk = g.mx(g.mx(box(0.089, 1.112, 0.012, 0.011), box(0.0, 0.9, 0.016, 0.017)), box(0.077, 0.6435, 0.011, 0.011))
        col = g.mixc(col, ZIP, bk)
        lamp = g.sqrt(g.add(g.sq(g.div(x, 0.004)), g.sq(g.div(g.sub(z, 0.9), 0.004))))
        trim = g.mx(trim, g.mul(g.mul(g.sub(1.0, g.sstep(0.8, 1.0, lamp)), front), on))
        chev = g.sub(1.0, g.sstep(0.4, 0.45, g.op("FRACT", g.div(g.add(x, g.mul(g.abs(g.sub(y, 0.022)), 1.2)), 0.016))))
        chev = g.mul(g.mul(chev, g.band(x, 0.19, 0.24)), g.sstep(1.14, 1.15, z))
        col = g.mixc(col, S["accent"], g.mul(chev, on))
    elif S["panels"] == "wrap":
        # a wrap top over the front of the suit, its lapel crossing from her
        # right collarbone to her left hip, tied there; glowing circuit lines
        # down her left arm and right leg; two straps round her right thigh
        wrap = g.mul(g.mul(g.band(z, 0.88, 1.17, 0.0004), g.sub(1.0, g.sstep(0.155, 0.165, ax))), front)
        col = g.mixc(col, S["accent"], g.mul(wrap, on))
        d_lap = g.sub(x, g.add(-0.03, g.mul(g.sub(1.17, z), 0.48)))
        lap = g.mul(g.sstep(-AA, AA, d_lap), wrap)
        col = g.mixc(col, S["panel"], g.mul(lap, on))
        ink = g.mx(ink, g.mul(g.mul(g.band(d_lap, -0.0004, 0.0008), wrap), on))
        ink = g.mx(ink, g.mul(g.mul(g.band(z, 0.8795, 0.8812), g.sub(1.0, g.sstep(0.155, 0.165, ax))), g.mul(front, on)))
        knot = g.sqrt(g.add(g.sq(g.div(g.sub(x, 0.105), 0.018)), g.sq(g.div(g.sub(z, 0.884), 0.014))))
        tails = g.mx(g.mul(g.band(g.sub(x, g.mul(g.sub(0.884, z), 0.25)), 0.088, 0.1), g.band(z, 0.8, 0.884)),
                     g.mul(g.band(g.add(x, g.mul(g.sub(0.884, z), 0.2)), 0.108, 0.12), g.band(z, 0.81, 0.884)))
        tie = g.mul(g.mx(g.sub(1.0, g.sstep(0.9, 1.0, knot)), tails), front)
        col = g.mixc(col, S["panel"], g.mul(tie, on))
        ink = g.mx(ink, g.mul(g.mul(g.band(knot, 0.92, 1.05), front), on))
        def trace(u, v, step, lo, hi):
            """A circuit trace running along u: it jogs between v = lo and v = hi
            every half step, with a node at each jog."""
            f = g.op("FRACT", g.div(u, step))
            high = g.sstep(0.49, 0.51, f)
            run = g.band(g.sub(v, g.lerp(lo, hi, high)), -0.0013, 0.0013, 0.0003)
            jog = g.mul(g.mx(g.band(f, 0.49, 0.51, 0.002), g.band(f, 0.0, 0.02, 0.002)), g.band(v, lo - 0.0013, hi + 0.0013))
            node = g.mul(g.mx(g.band(f, 0.47, 0.53, 0.002), g.band(f, 0.97, 1.0, 0.002)),
                         g.mx(g.band(v, lo - 0.0028, lo + 0.0028), g.band(v, hi - 0.0028, hi + 0.0028)))
            return g.mx(g.mx(run, jog), node)
        larm = g.mul(g.mul(g.sstep(0.17, 0.18, x), g.sstep(1.155, 1.165, z)), trace(x, y, 0.06, 0.012, 0.03))
        rleg = g.mul(g.mul(g.band(z, 0.22, 0.8), front), trace(z, x, 0.09, -0.082, -0.058))
        trim = g.mx(trim, g.mul(g.mx(larm, rleg), on))
        straps = g.mul(g.mx(g.band(z, 0.62, 0.632), g.band(z, 0.66, 0.672)), g.sstep(-0.02, -0.03, x))
        col = g.mixc(col, BASE_CORSET, g.mul(straps, on))
        col = g.mixc(col, ZIP, g.mul(g.mul(g.band(z, 0.62, 0.672), g.band(x, -0.125, -0.112)), on))
    elif S["panels"] == "shade":
        # a glossy black catsuit (STYLE gloss: the hard sheen shows on it), matte
        # where she grips and kneels: long gloves past her elbows and sleeves on
        # her lower legs, each topped with a glowing band; a fine glowing seam
        # down each side from under her arm to her knee; a belt slung low on her
        # right hip and her knife in a holster strapped to her right thigh
        th = g.lerp(0.108, 0.084, g.sstep(0.76, 0.8, z))
        below_arm = g.sub(1.0, g.sstep(0.985, 0.995, z))
        seam = g.mul(g.mul(g.band(g.sub(ax, th), -0.0007, 0.0007), below_arm), g.sstep(0.5, 0.52, z))
        trim = g.mx(trim, g.mul(seam, on))
        long = g.mx(fill(g.sub(ax, 0.3)), fill(g.sub(0.5, z)))   # (her arms reach past |x| 0.3, nothing else does)
        col = g.mixc(col, S["panel"], long)
        matte = g.mx(matte, long)
        trim = g.mx(trim, g.mul(g.mx(g.band(ax, 0.3, 0.3045), g.band(z, 0.4955, 0.5)), on))
        zb = g.add(0.872, g.mul(0.12, x))   # lower on her right
        d_belt = g.mn(g.sub(z, g.sub(zb, 0.007)), g.sub(g.add(zb, 0.007), z))
        strap = g.mn(g.mn(g.sub(z, 0.655), g.sub(0.668, z)), g.sub(-0.02, x))
        holster = g.mn(g.mn(g.sub(-0.1, x), g.sub(0.022, g.abs(g.add(y, 0.005)))), g.mn(g.sub(z, 0.6), g.sub(0.75, z)))
        gear_ = g.mx(g.mx(d_belt, strap), holster)
        col = g.mixc(col, S["belt"], fill(gear_))
        matte = g.mx(matte, fill(gear_))
        ink = g.mx(ink, g.mul(g.band(gear_, -0.0004, 0.0006), on))
        col = g.mixc(col, ZIP, g.mul(g.mul(g.mul(g.band(x, 0.048, 0.067), g.band(z, 0.872, 0.886)), front), on))   # buckle
        hilt = g.mul(g.mul(g.sstep(0.104, 0.112, g.neg(x)), g.band(y, -0.012, 0.002)), g.band(z, 0.75, 0.785))
        col = g.mixc(col, (0.05, 0.05, 0.06), g.mul(hilt, on))
        pommel = g.sqrt(g.add(g.sq(g.div(g.add(y, 0.005), 0.007)), g.sq(g.div(g.sub(z, 0.789), 0.005))))
        trim = g.mx(trim, g.mul(g.mul(g.sub(1.0, g.sstep(0.7, 1.0, pommel)), g.sstep(0.104, 0.112, g.neg(x))), on))
    elif S["panels"] == "patchwork":
        # the suit Mom sewed her: mustard twill with sage knit sleeves, cream
        # ribbed cuffs and a turtleneck, brown corduroy from her knees down, and
        # scraps of whatever she had sewn on with big running stitches: denim
        # with a little red heart embroidered on it, gingham, a rose floral (a
        # heart-shaped one on her right knee), knit; corduroy elbow patches, a
        # braided rope belt tied in a bow
        def dashes(step=0.0048):
            return g.sstep(0.3, 0.6, g.op("FRACT", g.div(g.add(g.add(x, z), g.mul(y, 0.6)), step)))

        def patch(d, colour, side=None):
            nonlocal col, ink
            if side is not None:
                d = g.mn(d, g.mul(g.sub(side, 0.5), 0.02))
            c = fill(d)
            col = g.mixc(col, colour, c)
            ink = g.mx(ink, g.mul(g.band(d, -0.0004, 0.0006), on))
            col = g.mixc(col, KNIT, g.mul(g.mul(g.band(d, 0.0016, 0.0027), dashes()), on))   # cream thread
            return c

        def rect(x0, x1, z0, z1):
            return g.mn(g.mn(g.sub(x, x0), g.sub(x1, x)), g.mn(g.sub(z, z0), g.sub(z1, z)))

        def oval(cx, cz, rx, rz, xv=None):
            q = g.sqrt(g.add(g.sq(g.div(g.sub(x if xv is None else xv, cx), rx)), g.sq(g.div(g.sub(z, cz), rz))))
            return g.mul(g.sub(1.0, q), min(rx, rz))

        def heart(cx, cz, s):
            u, v = g.div(g.sub(x, cx), s), g.div(g.sub(z, cz), s)
            lobe = g.sub(0.5, g.sqrt(g.add(g.sq(g.sub(g.abs(u), 0.45)), g.sq(g.sub(v, 0.2)))))
            tri = g.mn(g.mul(g.sub(g.add(v, 1.0), g.mul(1.333, g.abs(u))), 0.6), g.sub(0.3, v))
            return g.mul(g.mx(lobe, tri), s)

        def checks(step):   # gingham: darker where its stripes cross
            a = g.sstep(0.45, 0.55, g.op("FRACT", g.div(x, step)))
            b = g.sstep(0.45, 0.55, g.op("FRACT", g.div(z, step)))
            return g.mul(g.add(a, b), 0.5)

        def dots(step):     # little cream flowers
            r = g.sqrt(g.add(g.sq(frac(g.add(x, g.mul(y, 0.5)), step)), g.sq(frac(z, step))))
            return g.sub(1.0, g.sstep(0.16, 0.26, r))
        # sleeves, cuffs, turtleneck, corduroy legs
        d_sl = g.mn(g.sub(ax, 0.17), g.sub(z, 1.0))
        c = fill(d_sl)
        col = g.mixc(col, S["panel"], c)
        col = g.mixc(col, g.mixc(S["panel"], INK, 0.35), g.mul(g.mul(lines(ax, 0.006), 0.6), c))
        ink = g.mx(ink, g.mul(g.band(d_sl, -0.0004, 0.0006), on))
        d_cuff = g.mn(g.mn(g.sub(ax, 0.335), g.sub(z, 1.0)), g.sub(0.41, ax))
        rib = g.mul(lines(g.add(y, z), 0.0034), 0.45)
        c = fill(d_cuff)
        col = g.mixc(g.mixc(col, KNIT, c), g.mixc(KNIT, INK, 0.3), g.mul(rib, c))
        c = fill(g.sub(z, 1.163))
        col = g.mixc(g.mixc(col, KNIT, c), g.mixc(KNIT, INK, 0.3), g.mul(g.mul(lines(g.add(x, y), 0.003), 0.45), c))
        c = fill(g.sub(0.462, z))
        col = g.mixc(g.mixc(col, CORDUROY, c), g.mixc(CORDUROY, INK, 0.5), g.mul(g.mul(lines(g.add(x, y), 0.004), 0.7), c))
        ink = g.mx(ink, g.mul(g.band(z, 0.4615, 0.4625), on))
        col = g.mixc(col, KNIT, g.mul(g.mul(g.band(z, 0.465, 0.4665), dashes()), on))
        # running stitches down her sides
        th = g.lerp(0.108, 0.084, g.sstep(0.76, 0.8, z))
        below_arm = g.sub(1.0, g.sstep(0.985, 0.995, z))
        col = g.mixc(col, S["accent"], g.mul(g.mul(g.mul(g.band(g.sub(ax, th), -0.0006, 0.0006), dashes()), below_arm),
                                            g.mul(g.sstep(0.462, 0.47, z), on)))
        # the scraps
        c = patch(rect(0.072, 0.142, 1.085, 1.152), DENIM, front)
        col = g.mixc(col, g.mixc(DENIM, INK, 0.45), g.mul(g.mul(lines(g.add(x, g.mul(z, 2.0)), 0.003), 0.6), c))
        col = g.mixc(col, S["accent"], g.mul(g.mul(g.sstep(-AA, AA, heart(0.107, 1.118, 0.011)), front), on))
        c = patch(rect(-0.125, -0.05, 0.83, 0.896), GINGHAM, front)
        col = g.mixc(col, (0.08, 0.13, 0.06), g.mul(checks(0.011), c))
        c = patch(heart(-0.075, 0.478, 0.03), FLORAL, front)
        col = g.mixc(col, KNIT, g.mul(dots(0.009), c))
        c = patch(rect(0.045, 0.112, 0.58, 0.66), KNIT, front)
        col = g.mixc(col, g.mixc(KNIT, INK, 0.3), g.mul(g.mul(lines(g.add(z, g.mul(ax, 0.6)), 0.006), 0.5), c))
        c = patch(rect(0.03, 0.1, 1.03, 1.11), GINGHAM, back)
        col = g.mixc(col, (0.08, 0.13, 0.06), g.mul(checks(0.011), c))
        c = patch(rect(-0.12, -0.035, 0.93, 0.99), FLORAL, back)
        col = g.mixc(col, KNIT, g.mul(dots(0.009), c))
        for sd in (1.0, -1.0):
            c = patch(g.mn(oval(0.3 * sd, 1.145, 0.035, 0.04), g.sub(y, 0.03)), CORDUROY)
            col = g.mixc(col, g.mixc(CORDUROY, INK, 0.5), g.mul(g.mul(lines(g.add(y, z), 0.004), 0.6), c))
        # the braided rope belt, tied in a bow at her left hip
        d_rope = g.mn(g.sub(z, 0.903), g.sub(0.918, z))
        c = fill(d_rope)
        col = g.mixc(col, S["belt"], c)
        col = g.mixc(col, g.mixc(S["belt"], INK, 0.45), g.mul(g.mul(lines(g.add(g.add(x, y), g.mul(z, 2.5)), 0.006), 0.7), c))
        ink = g.mx(ink, g.mul(g.band(d_rope, -0.0004, 0.0006), on))
        loops = g.mx(oval(0.088, 0.918, 0.013, 0.009), oval(0.12, 0.918, 0.013, 0.009))
        tails = g.mx(g.mul(g.band(g.sub(x, g.mul(g.sub(0.91, z), 0.3)), 0.096, 0.104), g.band(z, 0.85, 0.91)),
                     g.mul(g.band(g.add(x, g.mul(g.sub(0.91, z), 0.2)), 0.108, 0.116), g.band(z, 0.86, 0.91)))
        bow = g.mul(g.mx(g.sstep(-AA, AA, loops), tails), g.mul(front, on))
        col = g.mixc(col, S["belt"], bow)
        ink = g.mx(ink, g.mul(g.mul(g.band(loops, -0.0004, 0.0006), front), on))
    elif S["panels"] == "punk":
        # the suit Ophelia made her: black, the sleeves striped black and violet,
        # fishnet across her shoulders, torn open on her thighs and right knee
        # over fishnet (safety pins across the tears), a broken heart and drips
        # hand-painted in white on her back, doodled stars on her left thigh,
        # an X-eyed smiley patch, two studded belts; a plaid skirt over it (base_skirt)
        def fishnet(c):
            nonlocal col
            net = g.mx(lines(g.add(x, z), 0.0062), lines(g.sub(x, z), 0.0062))
            col = g.mixc(col, g.mixc(g.mixc(skin, S["suit"], 0.2), S["net"], net), c)

        def ragged(cx, cz, rx, rz, teeth=9.0):
            u, v = g.sub(x, cx), g.sub(z, cz)
            q = g.sqrt(g.add(g.sq(g.div(u, rx)), g.sq(g.div(v, rz))))
            wob = g.mul(g.op("SINE", g.mul(g.op("ARCTAN2", v, u), teeth)), 0.0035)
            return g.add(g.mul(g.sub(1.0, q), min(rx, rz)), wob)

        def star(cx, cz, s):
            u, v = g.sub(x, cx), g.sub(z, cz)
            r = g.sqrt(g.add(g.sq(u), g.sq(v)))
            return g.sub(g.mul(g.add(0.55, g.mul(0.45, g.op("COSINE", g.mul(g.op("ARCTAN2", u, v), 5.0)))), s), r)
        d_yoke = g.mn(g.mn(g.sub(z, 1.105), g.sub(1.163, z)), g.sub(0.17, ax))
        fishnet(fill(d_yoke))
        ink = g.mx(ink, g.mul(g.band(d_yoke, -0.0004, 0.0006), on))
        d_arm = g.mn(g.sub(ax, 0.17), g.sub(z, 1.0))
        stripes = g.sstep(0.46, 0.54, g.op("FRACT", g.div(ax, 0.026)))
        col = g.mixc(col, S["panel"], g.mul(fill(d_arm), stripes))
        tears = [(0.075, 0.6, 0.026, 0.036, front), (-0.07, 0.468, 0.022, 0.02, front), (-0.085, 0.64, 0.018, 0.024, front),
                 (0.07, 0.33, 0.02, 0.03, back)]
        for cx, cz, rx, rz, side in tears:
            d = g.mn(ragged(cx, cz, rx, rz), g.mul(g.sub(side, 0.5), 0.02))
            fishnet(fill(d))
            ink = g.mx(ink, g.mul(g.band(d, -0.0006, 0.0008), on))
            pin = g.mul(g.band(z, cz - 0.0011, cz + 0.0011), g.band(x, cx - 0.6 * rx, cx + 0.6 * rx))
            head_ = g.sqrt(g.add(g.sq(g.div(g.sub(x, cx + 0.6 * rx), 0.003)), g.sq(g.div(g.sub(z, cz), 0.003))))
            col = g.mixc(col, ZIP, g.mul(g.mul(g.mx(pin, g.sub(1.0, g.sstep(0.7, 1.0, head_))), side), on))
        # her graffiti: a broken heart outlined in white on her back, paint running from it
        u, v = g.div(x, 0.05), g.div(g.sub(z, 1.06), 0.05)
        lobe = g.sub(0.5, g.sqrt(g.add(g.sq(g.sub(g.abs(u), 0.45)), g.sq(g.sub(v, 0.2)))))
        tri = g.mn(g.mul(g.sub(g.add(v, 1.0), g.mul(1.333, g.abs(u))), 0.6), g.sub(0.3, v))
        d_heart = g.mul(g.mx(lobe, tri), 0.05)
        paint_ = g.band(d_heart, 0.0, 0.0032)
        crack = g.mul(g.band(g.sub(x, g.mul(g.abs(frac(z, 0.016)), 0.016)), -0.0012, 0.0012), g.sstep(0.0, 0.002, d_heart))
        drips = 0.0
        for dx, end in ((-0.032, 0.985), (0.014, 0.955), (0.036, 0.995)):
            run = g.mul(g.band(x, dx - 0.0014, dx + 0.0014), g.band(z, end, 1.04))
            drop = g.sub(1.0, g.sstep(0.6, 1.0, g.sqrt(g.add(g.sq(g.div(g.sub(x, dx), 0.0028)), g.sq(g.div(g.sub(z, end), 0.0034))))))
            drips = g.mx(drips, g.mx(run, drop))
        col = g.mixc(col, S["accent"], g.mul(g.mul(g.mx(g.mx(paint_, crack), g.mul(drips, g.sstep(0.0, 0.003, g.neg(d_heart)))), back), on))
        for cx, cz, s in ((0.095, 0.55, 0.012), (0.058, 0.515, 0.009), (0.105, 0.5, 0.007)):
            col = g.mixc(col, S["accent"], g.mul(g.mul(g.sstep(-AA, AA, star(cx, cz, s)), front), on))
        # the X-eyed smiley patch on her right thigh
        r = g.sqrt(g.add(g.sq(g.add(x, 0.075)), g.sq(g.sub(z, 0.58))))
        c = g.mul(fill(g.sub(0.019, r)), front)
        col = g.mixc(col, S["panel"], c)
        ink = g.mx(ink, g.mul(g.mul(g.band(r, 0.0186, 0.0198), front), on))
        for ex in (-0.082, -0.068):
            du, dv = g.sub(x, ex), g.sub(z, 0.585)
            xx = g.mx(g.band(g.add(du, dv), -0.0009, 0.0009), g.band(g.sub(du, dv), -0.0009, 0.0009))
            col = g.mixc(col, S["accent"], g.mul(g.mul(xx, g.mul(g.band(du, -0.004, 0.004), g.band(dv, -0.004, 0.004))), c))
        mouth = g.mul(g.band(g.sub(z, g.add(0.5715, g.mul(g.abs(frac(x, 0.004)), 0.004))), -0.0007, 0.0007), g.band(x, -0.086, -0.064))
        col = g.mixc(col, S["accent"], g.mul(mouth, c))
        # two studded belts, one straight, one slung across it
        for zc, tilt in ((0.899, 0.0), (0.914, 0.06)):
            zz = g.add(zc, g.mul(tilt, x))
            d_b = g.mn(g.sub(z, g.sub(zz, 0.0065)), g.sub(g.add(zz, 0.0065), z))
            col = g.mixc(col, S["belt"], fill(d_b))
            ink = g.mx(ink, g.mul(g.band(d_b, -0.0004, 0.0006), on))
            stud = g.sub(1.0, g.sstep(0.18, 0.3, g.sqrt(g.add(g.sq(frac(g.add(x, y), 0.011)), g.sq(g.div(g.sub(z, zz), 0.011))))))
            col = g.mixc(col, ZIP, g.mul(g.mul(stud, fill(d_b)), 0.9))
    if S["vents"] == "spine":   # mesh strips either side of her spine, below the jacket's hem
        vlo, vhi = S.get("spine", (0.98, 1.15))
        vs = g.mul(g.mul(g.band(ax, 0.02, 0.045), g.band(z, vlo, vhi)), back)
        net = g.mx(lines(g.add(x, z), 0.005), lines(g.sub(x, z), 0.005))
        col = g.mixc(col, g.mixc(g.mixc(skin, S["suit"], 0.55), BASE_NET, net), g.mul(vs, on))
        ink = g.mx(ink, g.mul(g.mul(g.band(ax, 0.0195, 0.0205), g.band(z, vlo, vhi)), g.mul(back, on)))
        ink = g.mx(ink, g.mul(g.mul(g.band(ax, 0.0445, 0.0455), g.band(z, vlo, vhi)), g.mul(back, on)))

    # how she gets in: a zip down her spine from the collar to the small of her
    # back (the belt goes over it), its pull glowing at the top
    zip_ = g.mul(g.mul(g.band(x, -0.0019, 0.0019, 0.0002), g.band(z, 0.86, 1.2)), g.mul(back, on))
    col = g.mixc(col, ZIP, zip_)   # silver, so it reads down her spine
    teeth = g.mul(g.sstep(0.4, 0.6, g.op("FRACT", g.div(z, 0.0022))), zip_)
    col = g.mixc(col, INK, g.mul(teeth, 0.6))
    ink = g.mx(ink, g.mul(g.mul(g.band(ax, 0.0019, 0.0025, 0.0002), g.band(z, 0.86, 1.2)), g.mul(back, on)))
    pull = g.sqrt(g.add(g.sq(g.div(x, 0.0035)), g.sq(g.div(g.sub(z, 1.19), 0.007))))
    trim = g.mx(trim, g.mul(g.sub(1.0, g.sstep(0.85, 1.0, pull)), g.mul(back, on)))

    if S["belt_kind"] == "corset":
        # a corset belt, its top rising to a point at the front, laced up the front
        top = g.sub(0.978, g.mul(0.3, ax))
        bot = g.add(0.872, g.mul(0.18, ax))
        d_cor = g.mn(g.sub(top, z), g.sub(z, bot))
        cor = fill(d_cor)
        col = g.mixc(col, S["belt"], cor)
        col = g.mixc(col, S["suit"], g.mul(g.mul(g.sstep(-AA, AA, g.sub(0.007, ax)), front), cor))
        lace = g.mx(lines(g.add(z, ax), 0.011), lines(g.sub(z, ax), 0.011))
        lace = g.mul(g.mul(lace, g.sstep(-AA, AA, g.sub(0.011, ax))), g.mul(front, cor))
        col = g.mixc(col, S["accent"], lace)
        ink = g.mx(ink, g.mul(g.band(d_cor, -0.0006, 0.0003), on))
        trim = g.mx(trim, g.mul(g.band(d_cor, 0.0012, 0.0022), on))
    elif S["belt_kind"] == "obi":
        # a wide obi sash with a cord round its middle, knotted at her left hip
        d_obi = g.mn(g.sub(z, 0.885), g.sub(0.965, z))
        col = g.mixc(col, S["belt"], fill(d_obi))
        edge(d_obi)
        col = g.mixc(col, S["accent"], g.mul(g.band(z, 0.922, 0.93), on))
        knot = g.sqrt(g.add(g.sq(g.div(g.sub(x, 0.1), 0.018)), g.sq(g.div(g.sub(z, 0.926), 0.014))))
        tails = g.mx(g.mul(g.band(g.sub(x, g.mul(g.sub(0.926, z), 0.25)), 0.084, 0.096), g.band(z, 0.83, 0.926)),
                     g.mul(g.band(g.add(x, g.mul(g.sub(0.926, z), 0.2)), 0.104, 0.116), g.band(z, 0.84, 0.926)))
        tie = g.mul(g.mul(g.mx(g.sub(1.0, g.sstep(0.9, 1.0, knot)), tails), front), on)
        col = g.mixc(col, S["accent"], tie)
        ink = g.mx(ink, g.mul(g.mul(g.band(knot, 0.92, 1.06), front), on))
    elif S["belt_kind"] == "utility":
        # a belt with a silver buckle and a pouch on each hip
        d_belt = g.mn(g.sub(z, 0.875), g.sub(0.9, z))
        col = g.mixc(col, S["belt"], fill(d_belt))
        ink = g.mx(ink, g.mul(g.band(d_belt, -0.0004, 0.0006), on))
        col = g.mixc(col, ZIP, box(0.0, 0.8875, 0.013, 0.014))
        pouch = box(0.095, 0.855, 0.02, 0.019)
        col = g.mixc(col, S["belt"], pouch)
        ink = g.mx(ink, g.mul(g.mx(g.band(ax, 0.0745, 0.0755), g.band(ax, 0.1145, 0.1155)), g.mul(g.band(z, 0.836, 0.874), g.mul(front, on))))
        ink = g.mx(ink, g.mul(g.band(z, 0.8355, 0.8365), g.mul(g.band(ax, 0.075, 0.115), g.mul(front, on))))
    elif S["belt_kind"] == "sash":   # a thin sash at the waist under the wrap's tie
        d_s = g.mn(g.sub(z, 0.873), g.sub(0.887, z))
        col = g.mixc(col, S["panel"], fill(d_s))
        ink = g.mx(ink, g.mul(g.band(d_s, -0.0004, 0.0006), on))
    gloss = g.mul(g.mul(on, g.sub(1.0, matte)), S["gloss"]) if S.get("gloss") else 0.0
    return col, ink, trim, gloss


def suit_graph(nt, skin, cut="base"):
    """The pilot suit, worked out per pixel from each point's rest position (the
    'rest' attribute) so its edges are smooth curves whatever the mesh does.
    `cut` is the bodysuit for a suit weight (armory.gd SUIT_WEIGHTS):
      base    the halter bodysuit (before any suit tier)
      light   her cloth wrap supports her chest and covers the sides, so the side
              cutouts close, the high collar goes (her choker sits on bare neck)
              and the keyhole becomes a wider opening across the top of her chest
      heavy   a padded undersuit quilted in diamonds, neck to gloves to boots,
              under a high collar (the plates and breastplate go over it)
      medium  a mechanic's jumpsuit: crew neck unzipped in a wide V between her
              breasts and on past her belly button, a heart window low on her back over the top of her glute crease, full
              legs, the left arm bare to the shoulder (a cog and wrench tattoo on
              it), the right sleeve rolled to the forearm, rust panels down the sides
    The light and medium cuts have no stretch shading over the bust.
    Returns (albedo colour, glow amount, cover amount, ink line, gloves and
    boots, gloss) sockets."""
    light, medium, heavy, base = cut == "light", cut == "medium", cut == "heavy", cut == "base"
    g = NG(nt)
    at = nt.nodes.new("ShaderNodeAttribute")
    at.attribute_name = "rest"
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(at.outputs["Vector"], sep.inputs[0])
    x, y, z = sep.outputs[0], sep.outputs[1], sep.outputs[2]
    ax = g.abs(x)
    tb = g.sstep(-0.025, 0.045, y)                    # 0 at the front, 1 at the back
    front = g.sub(1.0, g.sstep(-0.045, -0.025, y))
    AA = 0.00045
    suit_col = MED_SUIT if medium else HVY_SUIT if heavy else STYLE["suit"] if base else SUIT
    if heavy or base:
        # neck to gloves to boots, under a high collar (heavy: a padded undersuit;
        # base: the stretch bodysuit)
        d_suit = g.sub(1.205, z)
        r = g.sqrt(g.add(g.sq(x), g.sq(g.sub(y, 0.022))))
        d_collar = g.mn(g.mn(g.sub(z, 1.166), g.sub(1.205, z)), g.sub(0.062, r))
    elif medium:
        # crew neck, rising a little round the sides and back of her neck
        zn = g.add(g.lerp(1.155, 1.172, tb), g.mul(1.5, g.sq(ax)))
        d_neck = g.sub(zn, z)
        # left armhole: a strap over the shoulder, rounded into the armpit
        d_arm = g.sub(g.sqrt(g.add(g.sq(g.mx(g.sub(0.09, ax), 0.0)), g.sq(g.mx(g.sub(1.102, z), 0.0)))), 0.012)
        # right sleeve, rolled up to the middle of her forearm
        d_sleeve = g.mn(g.sub(MED_SLEEVE, ax), g.neg(x))
        d_suit = g.mn(d_neck, g.mx(d_arm, d_sleeve))
        # unzipped past her belly button: the edges part a little down her stomach
        # (the belt crosses the gap) and open into a wide V between her breasts,
        # stopping short of the shoulder strap
        w_gap = g.mx(g.mul(g.sub(z, MED_ZIP), 0.19), 0.0)
        w_vee = g.mn(g.mx(g.mul(g.sub(z, 1.0), 0.6), w_gap), 0.064)   # narrow where her bust is fullest
        d_vee = g.mx(g.sub(ax, w_vee), g.sub(MED_ZIP + 0.004, z))
        d_suit = g.mn(d_suit, g.mx(d_vee, g.mul(g.sub(0.5, front), 0.1)))
        # a heart-shaped window low on her back, its point over the top of her glute crease
        lobe = g.sub(g.sqrt(g.add(g.sq(g.sub(ax, 0.024)), g.sq(g.sub(z, 0.85)))), 0.026)
        wedge = g.mul(g.sub(ax, g.mul(g.sub(z, 0.778), 0.8)), 0.781)   # its sides meet the lobes tangentially
        wedge = g.mx(wedge, g.sub(z, 0.834))
        d_win = g.mn(lobe, wedge)
        d_suit = g.mn(d_suit, g.mx(d_win, g.mul(g.sub(0.5, tb), 0.1)))
        d_collar = None
    else:
        # neckline: a halter at the front, open back down to the waist. Beside the
        # bust the sides are cut low (side cutouts), only where the surface turns
        # to face sideways, so the cups still cover her front
        zf = g.sub(1.17, g.mul(1.34, g.mx(g.sub(ax, 0.028), 0.0)))
        side_cut = g.mul(g.op("EXPONENT", g.neg(g.sq(g.div(g.sub(ax, 0.10), 0.036)))), g.sstep(-0.105, -0.065, y))
        zf = g.sub(zf, g.mul(side_cut, 0.0 if light else SIDE_CUT))
        zb = g.mn(g.add(0.90, g.mul(0.17, g.sq(g.div(ax, 0.11)))), 1.065)
        d_top = g.mul(g.sub(g.lerp(zf, zb, tb), z), g.lerp(0.6, 1.0, tb))
        # high-cut legs: steep up over the hip at the front, fuller cover behind
        lx = g.mx(g.sub(ax, 0.02), 0.0)
        zlf = g.add(0.655, g.mul(1.4, lx))
        zlb = g.add(0.665, g.mul(CHEEKY, lx))   # cut high at the back too: the bottom of the glutes shows
        d_leg = g.mul(g.sub(z, g.lerp(zlf, zlb, tb)), g.lerp(0.54, 0.88, tb))
        d_torso = g.mn(d_top, d_leg)
        if light:   # an opening across the top of her chest, a thin strap left under the neckline
            q = g.sqrt(g.add(g.sq(g.div(x, 0.06)), g.sq(g.div(g.sub(z, 1.118), 0.034))))
        else:
            q = g.sqrt(g.add(g.sq(g.div(x, 0.017)), g.sq(g.div(g.sub(z, 1.115), 0.03))))
        d_key = g.sub(g.mul(g.sub(1.0, q), 0.02), g.sub(1.0, front))
        d_suit = g.mn(d_torso, g.neg(d_key))
        d_collar = None
        if not light:
            r = g.sqrt(g.add(g.sq(x), g.sq(g.sub(y, 0.022))))
            d_collar = g.mn(g.mn(g.sub(z, 1.166), g.sub(1.205, z)), g.sub(0.062, r))
            d_suit = g.mx(d_suit, d_collar)
    # gloves and boots: knee-high, or just her ankle boots on the sleek base suit
    d_gear = g.mx(g.sub(ax, 0.40), g.sub(0.2 if base else 0.575, z))
    kq = g.sqrt(g.add(g.sq(g.div(g.sub(ax, 0.069), 0.036)), g.sq(g.div(g.sub(z, 0.478), 0.05))))
    d_knee = g.sub(g.mul(g.sub(1.0, kq), 0.036), g.sstep(-0.012, 0.004, y))
    if base:   # no knee plates on the base suit
        d_knee = g.sub(g.mul(kq, 0.0), 1.0)
    c_suit = g.sstep(-AA, AA, d_suit)
    c_gear = g.sstep(-AA, AA, d_gear)
    c_knee = g.mul(g.sstep(-AA, AA, d_knee), c_gear)
    col = skin
    if medium:
        # Dad's cog with a wrench through it, on the outside of her bare left upper arm
        u, v = g.sub(x, 0.175), g.sub(y, 0.022)
        rho = g.sqrt(g.add(g.sq(u), g.sq(v)))
        teeth = g.sstep(0.2, 0.5, g.op("COSINE", g.mul(g.op("ARCTAN2", v, u), 8.0)))
        cog = g.mul(g.sstep(0.0049, 0.0055, rho), g.sstep(-0.0003, 0.0003, g.sub(g.add(0.0115, g.mul(teeth, 0.0035)), rho)))
        a_, b_ = g.mul(g.add(u, v), 0.7071), g.mul(g.sub(u, v), 0.7071)
        bar = g.mul(g.sstep(-0.0003, 0.0003, g.sub(0.0013, g.abs(b_))), g.sstep(-0.0003, 0.0003, g.sub(0.019, g.abs(a_))))
        bar = g.mul(bar, g.sstep(0.0035, 0.0045, rho))
        jr = g.sqrt(g.add(g.sq(g.sub(g.abs(a_), 0.021)), g.sq(b_)))
        jaw = g.mul(g.band(jr, 0.0022, 0.0038, 0.0003), g.sstep(-0.0003, 0.0003, g.sub(g.abs(b_), 0.0011)))
        tat = g.mul(g.mx(g.mx(cog, bar), jaw), g.mul(g.sstep(1.155, 1.162, z), g.sstep(0.0, 0.004, x)))
        col = g.mixc(col, TATTOO, g.mul(tat, 0.85))
        # and her belly button, a soft dimple of shadow showing through the open zip
        dimple = g.sqrt(g.add(g.sq(g.div(x, 0.0026)), g.sq(g.div(g.sub(z, MED_NAVEL), 0.0042))))
        col = g.mixc(col, CREASE, g.mul(g.mul(g.sub(1.0, g.sstep(0.4, 1.0, dimple)), front), 0.7))
    col = g.mixc(col, suit_col, c_suit)
    if base:
        col, ink_b, trim_b, gloss = base_details(g, x, y, z, skin, col, c_suit, c_gear, front, AA)
    if medium:
        # rust panels down her sides and the outside of her legs, a stitched seam beside each
        th = g.lerp(0.113, 0.084, g.sstep(0.76, 0.8, z))
        below_arm = g.sub(1.0, g.sstep(0.985, 0.995, z))   # stops under her ribs
        d_panel = g.sub(ax, th)
        panel = g.mul(g.mul(g.sstep(-AA, AA, d_panel), below_arm), c_suit)
        col = g.mixc(col, MED_PANEL, panel)
        col = g.mixc(col, PLATE, g.mul(g.mul(g.band(d_panel, -0.0042, -0.0032), below_arm), c_suit))
        # the rolled cuff of the right sleeve
        cuff = g.mul(g.mul(g.band(ax, MED_SLEEVE - 0.026, MED_SLEEVE), g.sstep(0.0, 0.004, g.neg(x))), c_suit)
        col = g.mixc(col, MED_PANEL, cuff)
    if heavy:
        # diamond quilting stitched into the padding
        def quilt(v):
            f = g.op("FRACT", g.div(v, 0.034))
            return g.mx(g.sub(1.0, g.sstep(0.0, 0.07, f)), g.sstep(0.93, 1.0, f))
        q = g.mx(quilt(g.add(x, z)), quilt(g.sub(x, z)))
        col = g.mixc(col, PLATE, g.mul(g.mul(q, 0.6), g.mul(c_suit, g.sub(1.0, c_gear))))
    col = g.mixc(col, GEAR, c_gear)
    col = g.mixc(col, PLATE, c_knee)
    ink = g.mx(g.mx(g.band(d_suit, 0.0, 0.0008), g.band(d_gear, 0.0, 0.0008)), g.band(d_knee, -0.0002, 0.0007))
    trim = g.mx(g.band(d_suit, 0.0012, 0.0028), g.band(d_gear, 0.0012, 0.0034))
    if d_collar is not None:
        trim = g.mx(trim, g.mul(g.band(z, 1.1845, 1.1865), g.sstep(-AA, AA, d_collar)))
    trim = g.mx(trim, g.mul(g.band(d_knee, 0.004, 0.0052), c_gear))
    if medium:
        ink = g.mx(ink, g.mul(g.band(ax, MED_SLEEVE - 0.027, MED_SLEEVE - 0.025), g.mul(g.sstep(0.0, 0.004, g.neg(x)), c_suit)))
        # the front zip, from the neck to the waist band, its pull glowing at the top
        zip_ = g.mul(g.mul(g.band(x, -0.0011, 0.0011, 0.0002), g.band(z, 0.79, MED_ZIP)), g.mul(front, c_suit))
        col = g.mixc(col, PLATE, zip_)
        ink = g.mx(ink, g.mul(g.mul(g.band(g.abs(x), 0.0011, 0.0017, 0.0002), g.band(z, 0.79, MED_ZIP)), g.mul(front, c_suit)))
        pull = g.sqrt(g.add(g.sq(g.div(x, 0.0035)), g.sq(g.div(g.sub(z, MED_ZIP - 0.004), 0.006))))
        trim = g.mx(trim, g.mul(g.sub(1.0, g.sstep(0.85, 1.0, pull)), g.mul(front, c_suit)))
    if base:
        ink, trim = g.mx(ink, ink_b), g.mx(trim, trim_b)
    if not base:
        band_ = g.mul(g.band(z, 0.905, 0.955, 0.0004), c_suit)
        col = g.mixc(col, PLATE, g.mul(band_, 0.55))
    if not base:
        trim = g.mx(trim, g.mul(g.mx(g.band(z, 0.9045, 0.9058), g.band(z, 0.9542, 0.9555)), c_suit))
    seam = g.mul(g.mul(g.band(y, 0.012, 0.0135), g.sstep(0.05, 0.06, ax)), c_suit)
    if medium:   # the back seam would cut across the panels; one down her spine instead
        seam = g.mul(g.mul(g.band(x, -0.0007, 0.0007, 0.0002), tb), c_suit)
    col = g.mixc(col, PLATE, seam)
    suit_only = g.mul(c_suit, g.sub(1.0, c_gear))
    if not (medium or heavy or base):   # (base_details does its own, under its panels)
        # the thin suit stretches paler over her bust and glutes: painted on, nothing under it
        def bell(cx, cy, cz, r):
            d2 = g.add(g.add(g.sq(g.sub(ax, cx)), g.sq(g.sub(y, cy))), g.sq(g.sub(z, cz)))
            return g.op("EXPONENT", g.mul(d2, -1.0 / (2 * r * r)))
        stretch = bell(0.062, 0.06, 0.775, 0.042)
        if not light:
            stretch = g.mx(bell(0.057, -0.105, 1.045, 0.03), stretch)
        col = g.mixc(col, STYLE["stretch"] if base else STRETCH, g.mul(g.mul(stretch, 0.35 if base else 0.55), suit_only))
        if not (light or base):   # the base suit's fabric is thicker: no peaks drawn through it   # the light wrap holds her bust: no peaks drawn through it
            # drawn the anime way: a soft gleam on each peak of her bust with a small shadow under it
            col = g.mixc(col, INK, g.mul(g.mul(bell(APEX_POS[0], APEX_POS[1] + 0.0015, APEX_POS[2] - 0.0048, 0.0032), 0.8), suit_only))
            col = g.mixc(col, GLEAM, g.mul(g.mul(bell(APEX_POS[0], APEX_POS[1], APEX_POS[2] + 0.0016, 0.0024), 0.75), suit_only))
    # a crease between her glutes and a fold under each one: a warm shade where
    # the suit bares her skin, dark on the thin suit (not on the jumpsuit or padding)
    crease = crease_lines(g, x, y, z, 0.0015)
    col = g.mixc(col, CREASE_SKIN, g.mul(g.mul(crease, 0.85), g.sub(1.0, c_suit)), "MULTIPLY")
    if not (medium or heavy):
        col = g.mixc(col, INK, g.mul(g.mul(crease, 0.85), c_suit))
    col = g.mixc(col, INK, ink)
    col = g.mixc(col, STYLE["glow"] if base else TRIM, trim)
    return col, trim, g.mx(c_suit, c_gear), ink, c_gear, gloss if base else 0.0


# --- clothes (eco_model.gd outfit) --------------------------------------------------------

# Her clothes off duty, each in two versions for the content rating
# (scripts/radio/content_rating.gd): <outfit>_t for Teen, <outfit>_m for Mature.
# Each bakes v_body*_<kind>.png; its loose parts are outfit_<outfit>_<t|m|any>_* meshes.
OUTFITS = ("casual_t", "casual_m", "date_t", "date_m")
OUTFIT_GLOW = TRIM
TEE = (0.48, 0.47, 0.45)              # the casual tee: soft white
TEE_PRINT = (0.0, 0.33, 0.3)          # its teal stripe
JEANS = (0.025, 0.04, 0.085)
CUTOFF = (0.05, 0.085, 0.16)          # bleached denim cutoffs
LINING = (0.55, 0.55, 0.52)           # their pocket linings
SOCK = (0.55, 0.53, 0.5)
BELT = (0.07, 0.035, 0.015)
LEG_SKIN = (0.99, 0.86, 0.77)         # her thigh skin, sampled from the preset
SATIN = (0.004, 0.06, 0.04)           # the date dress: deep emerald satin
GOLD_PAINT = (0.55, 0.36, 0.08)
LIP_RED = (0.42, 0.02, 0.05)


def _hull(pts):
    """Convex hull (counter-clockwise) of 2D points, monotone chain."""
    pts = sorted(set(pts))

    def half(seq):
        h = []
        for p in seq:
            while len(h) >= 2 and (h[-1][0] - h[-2][0]) * (p[1] - h[-2][1]) - (h[-1][1] - h[-2][1]) * (p[0] - h[-2][0]) <= 0:
                h.pop()
            h.append(p)
        return h
    lo, hi = half(pts), half(reversed(pts))
    return lo[:-1] + hi[:-1]


def _ray_hull(hull, c, d):
    """How far from c along direction d the hull's edge is."""
    best = 0.0
    for i in range(len(hull)):
        a, b = Vector(hull[i]), Vector(hull[i - 1])
        e = b - a
        den = d.x * e.y - d.y * e.x
        if abs(den) < 1e-9:
            continue
        w = a - c
        t = (w.x * e.y - w.y * e.x) / den
        u = (w.x * d.y - w.y * d.x) / den
        if t > 0 and -1e-6 <= u <= 1 + 1e-6:
            best = max(best, t)
    return best


def skirt(name, top, hem, mats, gap=0.006, flare=0.0, slit=None, trim=False, follow=(0.25, 0.65), rows=16, pleats=0):
    """A loose hanging skirt: rings round the convex hull of her hips and thighs
    from `top` down to `hem`, so it bridges between her legs instead of wrapping
    each one like paint would. `flare` pushes the hem out, `slit` (angle deg,
    half width deg at the hem, top z) opens it from that height down (the angle
    runs from her left, +x, toward her back), `trim` makes the bottom row the
    second material, `pleats` folds it into that many knife pleats. Its UVs run
    round it (u) and down it (v 0 at the hem), for a printed fabric. Skinned
    half to her hips, half to the nearest body vertex's bones further down
    (`follow` from top to hem), so it swings with her legs."""
    from mathutils.kdtree import KDTree
    body = bpy.data.objects["Body"]
    co = np.array([v.co[:] for v in body.data.vertices])
    cols = 56
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    grid = []
    zs = []
    us = []
    widest = [0.0] * cols   # cloth hangs straight down from her hips, it never tucks back in
    for r in range(rows + 1):
        t = r / rows
        z = top + (hem - top) * t
        keep = (co[:, 2] > z - 0.012) & (co[:, 2] < z + 0.012) & (np.abs(co[:, 0]) < 0.25)
        hull = _hull([(round(p[0], 5), round(p[1], 5)) for p in co[keep]])
        c = Vector((float(np.mean([h[0] for h in hull])), float(np.mean([h[1] for h in hull]))))
        ring = []
        ring_u = []
        # with a slit the ring opens: its ends sit either side of the slit, which
        # widens smoothly from its top to the hem (a clean V, not grid steps)
        w = 0.0
        if slit is not None and z < slit[2]:
            w = slit[1] * (slit[2] - z) / (slit[2] - hem)
        for k in range(cols + (1 if slit is not None else 0)):
            frac_k = (w + (360.0 - 2 * w) * k / cols) / 360.0 if slit is not None else k / cols
            a = math.radians(slit[0]) + 2 * math.pi * frac_k if slit is not None else 2 * math.pi * frac_k
            kk = k % cols
            d = Vector((math.cos(a), math.sin(a)))
            raw = _ray_hull(hull, c, d) + gap
            widest[kk] = max(widest[kk], raw)
            rad = widest[kk] + flare * t * t
            if pleats:
                rad += 0.005 * abs((frac_k * pleats) % 1.0 * 2 - 1) * min(1.0, t * 3)
            ring.append(bm.verts.new((c.x + d.x * rad, c.y + d.y * rad, z)))
            ring_u.append(frac_k)
        grid.append(ring)
        zs.append(z)
        us.append(ring_u)
    for r in range(rows):
        for k in range(cols):
            k1 = k + 1 if slit is not None else (k + 1) % cols
            f = bm.faces.new((grid[r][k], grid[r][k1], grid[r + 1][k1], grid[r + 1][k]))
            f.smooth = True
            f.material_index = 1 if trim and r == rows - 1 else 0
            u1 = us[r][k1] if k1 else 1.0
            for loop, (uu, vv) in zip(f.loops, ((us[r][k], r), (u1, r), (u1, r + 1), (us[r][k], r + 1))):
                loop[uv].uv = (uu, (zs[vv] - hem) / (top - hem))
    if slit is not None:   # close the seam where the slit hasn't opened yet
        bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
    bm.normal_update()
    f0 = next(iter(bm.faces))
    cm = f0.calc_center_median()
    if f0.normal.dot(Vector((cm.x, cm.y, 0))) < 0:   # face outwards
        bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.004)
    bm.normal_update()
    me = bpy.data.meshes.new(name)
    _armor_mats(me, mats)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
    kd = KDTree(len(co))
    for i, p in enumerate(co):
        if abs(p[0]) < 0.25 and p[2] < top + 0.03:
            kd.insert(Vector(p), i)
    kd.balance()
    names = {gr.index: gr.name for gr in body.vertex_groups}
    groups = {}
    for v in me.vertices:
        t = min(1.0, max(0.0, (top - v.co.z) / (top - hem)))
        f = follow[0] + (follow[1] - follow[0]) * t   # how much it follows the nearest bit of her
        _, i, _ = kd.find(v.co)
        w = {"J_Bip_C_Hips": 1.0 - f}
        for ge in body.data.vertices[i].groups:
            w[names[ge.group]] = w.get(names[ge.group], 0.0) + f * ge.weight
        for gname, wt in w.items():
            if wt > 0.001:
                if gname not in groups:
                    groups[gname] = ob.vertex_groups.new(name=gname)
                groups[gname].add([v.index], wt, "REPLACE")
    ob.parent = arm
    ob.modifiers.new("Armature", "ARMATURE").object = arm
    return ob


def _plaid(name, base, bands, line, reps, size=256):
    """A woven plaid texture (assets/textures/eco/<name>.png), sRGB colours:
    `bands` darkens or tints where the warp and weft stripes cross, `line`
    the thin overcheck; `reps` (round, down) repeats."""
    vv, uu = np.mgrid[0:size, 0:size] / size
    a = (np.sin(uu * 2 * math.pi * reps[0]) > 0.3).astype(np.float32)
    b = (np.sin(vv * 2 * math.pi * reps[1]) > 0.3).astype(np.float32)
    thin = ((np.abs(np.sin(uu * 2 * math.pi * reps[0] * 2)) < 0.07) | (np.abs(np.sin(vv * 2 * math.pi * reps[1] * 2)) < 0.07))
    col = np.array(base) + (a + b)[..., None] * np.array(bands)
    col = col * (1 - thin[..., None]) + np.array(line) * thin[..., None]
    px = np.ones((size, size, 4), np.float32)
    px[..., :3] = np.clip(col, 0, 1)
    write_png(px, name)


def tartan():
    """Ophelia's violet and black tartan (base_ophelia_skirt)."""
    _plaid("tartan", (0.05, 0.04, 0.07), (0.11, 0.03, 0.17), (0.5, 0.45, 0.55), (12, 2.5))


def outfit_pieces():
    """The clothes' loose parts (outfit_<outfit>_<t|m|any>_*, shown by
    eco_model.gd in that outfit at that rating, or at any):
      casual  her red flannel shirt tied round her waist by its sleeves
      date    the dress's satin skirt (Teen: to just below her knees, a small
              slit above her left knee; Mature: a mini, slit up her left
              thigh), its gold hem; gold hoops and bangles"""
    out = []
    _plaid("flannel", (0.42, 0.04, 0.04), (-0.17, -0.02, -0.02), (0.05, 0.03, 0.03), (14, 2.5))
    out.append(skirt("outfit_casual_any_flannel", 0.905, 0.74, ["eco_v_flannel"], gap=0.012, flare=0.02,
                     slit=(-90.0, 70.0, 0.905), follow=(0.5, 0.85), rows=10))
    body = bpy.data.objects["Body"]
    co = np.array([v.co[:] for v in body.data.vertices])
    yf = float(co[(np.abs(co[:, 0]) < 0.02) & (np.abs(co[:, 2] - 0.9) < 0.01), 1].min())
    bm = bmesh.new()
    box(bm, (0.0, yf - 0.016, 0.9), ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (0.034, 0.02, 0.024), 0, bevel=0.007)
    for sd in (1, -1):   # the sleeves hanging from the knot
        t = Vector((0.25 * sd, 0, -1)).normalized()
        box(bm, Vector((0.011 * sd, yf - 0.014, 0.888)) + t * 0.04, (t.cross(Vector((0, 1, 0))).normalized(), Vector((0, 1, 0)), t),
            (0.022, 0.012, 0.085), 0, bevel=0.004)
    out.append(rigid("outfit_casual_any_knot", bm, ["eco_v_flannel_knot"], "J_Bip_C_Hips"))
    out.append(skirt("outfit_date_t_skirt", 0.92, 0.42, ["eco_v_satin", "eco_v_gold"], gap=0.012, flare=0.06,
                     slit=(-60.0, 9.0, 0.56), trim=True, follow=(0.6, 0.92), rows=18))
    out.append(skirt("outfit_date_m_skirt", 0.92, 0.645, ["eco_v_satin", "eco_v_gold"], gap=0.014, flare=0.012,
                     slit=(-35.0, 18.0, 0.78), trim=True, follow=(0.88, 0.97), rows=10))
    face = bpy.data.objects["Face"]
    bm = bmesh.new()
    for sd in (1, -1):
        lobe = [v.co for v in face.data.vertices if v.co.x * sd > 0.066 and abs(v.co.y - 0.012) < 0.022 and 1.25 < v.co.z < 1.3]
        p = min(lobe, key=lambda c: c.z) if lobe else Vector((0.076 * sd, 0.01, 1.268))
        torus(bm, p + Vector((0.002 * sd, 0, -0.013)), (1, 0, 0), 0.012, 0.0013, 0, segs=(20, 6))
    out.append(rigid("outfit_date_any_hoops", bm, ["eco_v_gold"], "J_Bip_C_Head"))
    for sd, nm in ((1, "l"), (-1, "r")):
        bm = bmesh.new()
        for k, xw in enumerate((0.455, 0.468, 0.477)):
            sl = co[(np.abs(co[:, 0] - xw * sd) < 0.004) & (np.abs(co[:, 2] - 1.145) < 0.06)]
            c = Vector((xw * sd, float(sl[:, 1].mean()), float(sl[:, 2].mean())))
            r = float(np.max(np.hypot(sl[:, 1] - c.y, sl[:, 2] - c.z)))
            torus(bm, c, (1, 0, 0), r + 0.004 + 0.002 * k, 0.0016, 0, segs=(20, 6))
        out.append(rigid("outfit_date_any_bangles_" + nm, bm, ["eco_v_gold"], "J_Bip_%s_LowerArm" % nm.upper()))
    print("outfit pieces: %d" % len(out))
    return out


def outfit_graph(nt, skin, kind):
    """Her clothes off duty, painted on per pixel from the rest position like the
    suit (see suit_graph for the landmarks). Each garment is a signed distance
    (positive = covered) laid over the last, with an ink line round its edge.
    Two versions of each, for the content rating:
      casual_t  a white tee with a teal stripe, short sleeves, tucked into
                high-waisted jeans ripped at the knees, a belt (and the flannel
                tied round her waist, outfit_casual_any_*)
      casual_m  the tee cut down: a wide scoop neck, cap sleeves, cropped under
                her bust; low-rise frayed cutoff shorts (pocket linings
                peeking below), slouchy socks over her boots
      date_t    an emerald satin dress off the shoulders: straight across above
                her bust, short sleeves round her upper arms, back covered, a
                thin gold belt; the skirt to below her knees; strappy sandals
      date_m    the same dress as a halter: a deep V to her sternum (always well
                over where she is fullest), her back bare to the waist, a mini
                skirt; a gold choker chain with a drop, a waist chain, an arm band
    Returns (albedo colour, glow amount, cover amount, ink line, gloves and
    boots, gloss)."""
    g = NG(nt)
    at = nt.nodes.new("ShaderNodeAttribute")
    at.attribute_name = "rest"
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(at.outputs["Vector"], sep.inputs[0])
    x, y, z = sep.outputs[0], sep.outputs[1], sep.outputs[2]
    ax = g.abs(x)
    tb = g.sstep(-0.025, 0.045, y)
    front = g.sub(1.0, g.sstep(-0.045, -0.025, y))
    AA = 0.00045
    mature = kind.endswith("_m")

    def ellipse(cx, cz, rx, rz):   # distance-ish, positive inside
        q = g.sqrt(g.add(g.sq(g.div(g.sub(x, cx), rx)), g.sq(g.div(g.sub(z, cz), rz))))
        return g.mul(g.sub(1.0, q), min(rx, rz))

    # the preset's skin texture still has white stockings and gold bands on her
    # lower legs (the suit always covered them): bare legs get plain skin
    state = {"col": g.mixc(skin, LEG_SKIN, g.sub(1.0, g.sstep(0.585, 0.6, z))), "ink": 0.0, "cover": 0.0, "gloss": 0.0}

    def wear(d, colour, ink=True, gloss=0.0):
        c = g.sstep(-AA, AA, d)
        state["col"] = g.mixc(state["col"], colour, c)
        state["cover"] = g.mx(state["cover"], c)
        if ink:
            state["ink"] = g.mx(state["ink"], g.band(d, 0.0, 0.0008))
        if gloss:
            state["gloss"] = g.mx(state["gloss"], g.mul(c, gloss))
        return c

    def paint(amount, colour):
        state["col"] = g.mixc(state["col"], colour, amount)

    if kind.startswith("casual"):
        if mature:   # a wide scoop neck rising to her shoulders, cap sleeves, cropped under her bust
            zn = g.add(g.lerp(1.088, 1.172, tb), g.mul(1.3, g.sq(ax)))
            d_tee = g.mn(g.mn(g.sub(zn, z), g.sub(0.172, ax)), g.sub(z, 0.985))
        else:        # crew neck, short sleeves, tucked into her jeans
            d_tee = g.mn(g.mn(g.sub(g.lerp(1.165, 1.178, tb), z), g.sub(0.225, ax)), g.sub(z, 0.9))
        c = wear(d_tee, TEE)
        stripe = g.band(z, 0.985, 0.996) if mature else g.band(z, 1.075, 1.088)
        paint(g.mul(stripe, c), TEE_PRINT)
        if mature:
            # low-rise cutoffs: frayed hems cut high over her hips, her seat covered
            zt = g.sub(0.884, g.mul(0.35, g.sq(ax)))
            zl = g.lerp(g.add(0.655, g.mul(0.45, g.mx(g.sub(ax, 0.03), 0.0))), g.add(0.675, g.mul(0.15, ax)), tb)
            d_sh = g.mn(g.sub(zt, z), g.sub(z, zl))
            c_s = wear(d_sh, CUTOFF)
            threads = g.mul(g.band(g.sub(z, zl), -0.007, 0.0), g.band(g.op("FRACT", g.div(g.add(x, g.mul(y, 0.7)), 0.005)), 0.0, 0.25))
            paint(g.mul(threads, 0.9), (0.4, 0.45, 0.55))
            d_lin = g.mn(g.mn(g.sub(ax, 0.058), g.sub(0.098, ax)), g.mn(g.sub(z, g.sub(zl, 0.013)), g.sub(g.add(zl, 0.001), z)))
            wear(g.mn(d_lin, g.mul(g.sub(front, 0.5), 0.02)), LINING)                     # pocket linings
            pocket = g.mul(g.band(g.sub(z, g.add(0.82, g.mul(0.4, g.sub(ax, 0.05)))), -0.0005, 0.0005), g.band(ax, 0.05, 0.12))
            state["ink"] = g.mx(state["ink"], g.mul(g.mul(pocket, front), c_s))
            wear(g.mn(g.sub(z, g.sub(zt, 0.016)), g.sub(zt, z)), BELT)
            paint(g.mul(g.mul(g.band(ax, 0.0, 0.009), g.band(z, 0.86, 0.878)), front), (0.3, 0.27, 0.2))   # buckle
            wear(g.mn(g.sub(z, 0.17), g.sub(0.235, z)), SOCK)                                # slouchy socks
            paint(g.mul(g.band(g.op("FRACT", g.div(z, 0.008)), 0.0, 0.3), g.band(z, 0.17, 0.235)), (0.45, 0.43, 0.4))
        else:
            # high-waisted jeans, small rips at the knees with threads across them
            d_jeans = g.mn(g.sub(0.93, z), g.sub(z, 0.115))
            rip = g.mul(ellipse(-0.075, 0.475, 0.016, 0.011), front)
            rip2 = g.mul(ellipse(0.07, 0.49, 0.012, 0.008), front)
            d_rip = g.sub(g.mx(rip, rip2), g.mul(g.sub(1.0, front), 0.004))
            c_j = wear(g.mn(d_jeans, g.neg(d_rip)), JEANS)
            threads = g.mul(g.mul(g.sstep(0.0, 0.002, d_rip), g.band(g.op("FRACT", g.div(z, 0.006)), 0.0, 0.18)), front)
            paint(g.mul(threads, 0.9), (0.4, 0.42, 0.45))
            state["ink"] = g.mx(state["ink"], g.mul(g.mul(g.band(ax, 0.0, 0.0008), c_j), front))
            wear(g.mn(g.sub(0.945, z), g.sub(z, 0.928)), BELT)
            paint(g.mul(g.mul(g.band(ax, 0.0, 0.012), g.band(z, 0.929, 0.944)), front), (0.3, 0.27, 0.2))   # buckle
    elif kind.startswith("date"):
        if mature:
            # halter: a deep V to her sternum, narrow where she is fullest, the
            # cups wide past her nipples; bare sides above her waist and her back
            # bare to it; straps up round her neck
            w_v = g.mul(0.32, g.mx(g.sub(z, 0.99), 0.0))
            d_front = g.mn(g.mn(g.sub(g.sub(1.125, g.mul(0.3, ax)), z), g.sub(ax, w_v)), g.sub(0.122, ax))
            d_front = g.mn(d_front, g.mul(g.sub(0.5, tb), 0.02))
            d_lower = g.mn(g.sub(z, 0.65), g.sub(g.lerp(1.0, 0.93, tb), z))
            u = g.div(g.sub(z, 1.1), 0.09)
            d_strap = g.mn(g.mn(g.sub(0.0075, g.abs(g.sub(ax, g.lerp(0.05, 0.026, u)))), g.mn(g.sub(z, 1.1), g.sub(1.19, z))),
                           g.mul(g.sub(0.5, tb), 0.02))
            d_neck = g.mn(g.sub(z, 1.183), g.sub(1.195, z))
            d_dress = g.mx(g.mx(d_front, d_lower), g.mx(d_strap, d_neck))
        else:
            # off the shoulders: straight across above her bust (her back covered
            # as high), short sleeves round her upper arms
            d_bod = g.mn(g.mn(g.sub(g.lerp(1.108, 1.118, tb), z), g.sub(z, 0.65)), g.sub(0.165, ax))
            d_slv = g.mn(g.mn(g.sub(ax, 0.165), g.sub(0.225, ax)), g.sub(z, 1.0))
            d_dress = g.mx(d_bod, d_slv)
            d_neck = None
        c = wear(d_dress, SATIN, gloss=0.6)
        paint(g.mul(g.band(d_dress, 0.001, 0.0028), c), GOLD_PAINT)                         # gold piping
        wear(g.mn(g.sub(z, 0.912), g.sub(0.922, z)), GOLD_PAINT)                            # a thin gold belt
        if mature:
            # a fine gold chain with a drop in the V, the choker, a waist chain, an arm band
            zc = g.sub(1.17, g.mul(0.055, g.sub(1.0, g.sq(g.div(g.mn(ax, 0.05), 0.05)))))
            chain = g.mul(g.mul(g.band(g.sub(z, zc), -0.0011, 0.0011), g.sub(1.0, g.sstep(0.048, 0.052, ax))), front)
            pend = g.mul(g.sub(1.0, g.sstep(0.8, 1.0, g.sqrt(g.add(g.sq(g.div(x, 0.004)), g.sq(g.div(g.sub(z, 1.106), 0.0075)))))), front)
            paint(g.mx(g.mx(chain, pend), g.sstep(-AA, AA, d_neck)), GOLD_PAINT)
            wear(g.mn(g.mn(g.sub(z, 1.1), g.sub(0.008, g.abs(g.sub(x, 0.168)))), g.sub(1.2, z)), GOLD_PAINT)   # arm band
        paint(g.band(z, 0.128, 0.134), GOLD_PAINT)                                            # anklet
        # strappy sandals: soles and thin straps over bare feet
        wear(g.mn(g.sub(z, 0.0), g.sub(0.012, z)), SATIN, ink=False)
        paint(g.mx(g.band(z, 0.098, 0.106), g.mul(g.band(z, 0.04, 0.047), front)), SATIN)
    col = g.mixc(state["col"], INK, state["ink"])
    return col, 0.0, state["cover"], state["ink"], 0.0, state["gloss"]


def bake_body(body, skin_img, cut="base"):
    """Bake the suit into four textures: albedo, glow (teal trims), a mask
    (red: where a thin sheen may show, green: suit or skin) and a normal map.
    The weight cuts (suit_graph) are v_body*_light.png, v_body*_medium.png and
    v_body*_heavy.png, without a normal map; the base suit's styles other than
    gwen (STYLE_NAME) are v_body*_<style>.png and share gwen's normal map."""
    sfx = ("" if STYLE_NAME == "gwen" else "_" + STYLE_NAME) if cut == "base" else "_" + cut
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 4
    sc.cycles.device = "CPU"
    sc.cycles.use_denoising = False   # this build has no denoiser, and with it on bakes come out black
    sc.render.bake.margin = 8
    skin_slot = mat_index(body, "Body_00_SKIN") | mat_index(body, "bake_body")
    m = bpy.data.materials.new("bake_body")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    uv = nt.nodes.new("ShaderNodeUVMap")
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = skin_img
    nt.links.new(uv.outputs[0], t.inputs[0])
    if cut in OUTFITS:
        col, trim, cover, ink, gear, gloss = outfit_graph(nt, t.outputs["Color"], cut)
    else:
        col, trim, cover, ink, gear, gloss = suit_graph(nt, t.outputs["Color"], cut)
    g = NG(nt)
    # only the gloves and boots shine: on the bodysuit a sheen reads as blotches
    # and hot spots, so its cling shows in the shading alone (but for a glossy
    # catsuit or a satin dress: gloss)
    sheen = g.mul(g.mx(gear, gloss), g.sub(1.0, ink))
    comb = nt.nodes.new("ShaderNodeCombineColor")
    g.put(comb.inputs[0], sheen)
    g.put(comb.inputs[1], cover)
    em = nt.nodes.new("ShaderNodeEmission")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(em.outputs[0], out.inputs[0])
    for i in skin_slot:
        body.material_slots[i].material = m
    for o in bpy.data.objects:
        o.select_set(o == body)
    bpy.context.view_layer.objects.active = body
    results = {}
    glow_col = STYLE["glow"] if cut == "base" else OUTFIT_GLOW if cut in OUTFITS else TRIM
    for name, size, src in (("v_body", 2048, col), ("v_body_glow", 1024, g.mixc((0, 0, 0, 1), glow_col, trim)),
                            ("v_body_mask", 1024, comb.outputs[0])):
        img = bpy.data.images.new(name, size, size, alpha=False)
        img.colorspace_settings.name = "sRGB" if name != "v_body_mask" else "Non-Color"
        node = nt.nodes.new("ShaderNodeTexImage")
        node.image = img
        nt.nodes.active = node
        nt.links.new(src, em.inputs[0])
        bpy.ops.object.bake(type="EMIT")
        img.filepath_raw = os.path.join(TEX_OUT, name + sfx + ".png")
        img.file_format = "PNG"
        img.save()
        results[name] = img
        print("baked", name)
    if cut != "base" or STYLE_NAME != "gwen":
        return results   # the wrap, the jumpsuit or the padding holds her chest: no cling normal map (other styles share gwen's)
    # normal map: crisp detail on top of the shapes curves() gave the mesh, the
    # peaks of her bust under the suit (nothing under it) and the creases of her glutes
    at = nt.nodes.new("ShaderNodeAttribute")
    at.attribute_name = "rest"
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(at.outputs["Vector"], sep.inputs[0])
    x, y, z = sep.outputs[0], sep.outputs[1], sep.outputs[2]
    h = 0.0
    for sx in (APEX_POS[0], -APEX_POS[0]):
        d2 = g.add(g.add(g.sq(g.sub(x, sx)), g.sq(g.sub(y, APEX_POS[1]))), g.sq(g.sub(z, APEX_POS[2])))
        h = g.add(h, g.op("EXPONENT", g.mul(d2, -1.0 / (2 * 0.0045 ** 2))))
    h = g.sub(g.mul(g.mul(h, cover), 0.0014), g.mul(crease_lines(g, x, y, z, 0.003), 0.0008))
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 1.0
    bump.inputs["Distance"].default_value = 1.0
    g.put(bump.inputs["Height"], h)
    bsdf = nt.nodes.new("ShaderNodeBsdfDiffuse")
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    nt.links.new(bsdf.outputs[0], out.inputs[0])
    img = bpy.data.images.new("v_body_n", 1024, 1024, alpha=False)
    img.colorspace_settings.name = "Non-Color"
    node = nt.nodes.new("ShaderNodeTexImage")
    node.image = img
    nt.nodes.active = node
    sc.render.bake.normal_space = "TANGENT"
    bpy.ops.object.bake(type="NORMAL")
    img.filepath_raw = os.path.join(TEX_OUT, "v_body_n.png")
    img.file_format = "PNG"
    img.save()
    results["v_body_n"] = img
    print("baked v_body_n")
    return results


# --- materials and textures ------------------------------------------------------------

def tex_of(m):
    return next((n.image for n in m.node_tree.nodes if n.type == "TEX_IMAGE"), None) if m and m.use_nodes else None


def textures_and_materials(objs, boots):
    """Write each surface's texture to assets/textures/eco/ and give the glb
    plain materials named after the game's eco_v_* materials."""
    face = bpy.data.objects["Face"]
    body = bpy.data.objects["Body"]
    hair = bpy.data.objects["Hair"]
    plan = []   # (object, material name needle, game name, texture fn)
    face_tex = None
    for i, m in enumerate(face.data.materials):
        img = tex_of(m)
        if "Face_00_SKIN" in m.name:
            face_tex = face_texture(face, img)
            write_png(face_tex, "v_face")
            write_png(face_texture(face, img, glam=True), "v_face_date")
            plan.append((face, i, "eco_v_face"))
        elif "FaceBrow" in m.name:
            px = read_px(img).copy()
            px[..., :3] = to_srgb(np.array((0.07, 0.008, 0.012)))
            px[..., 3] = ss(0.12, 0.45, px[..., 3])
            write_png(px, "v_brow")
            plan.append((face, i, "eco_v_brow"))
        elif "FaceEyeline" in m.name or "FaceEyelash" in m.name:
            px = read_px(img).copy()
            px[..., :3] = to_srgb(to_lin(px[..., :3]) * np.array((0.32, 0.2, 0.24)))
            name = "v_eyeline" if "Eyeline" in m.name else "v_lash"
            write_png(px, name)
            plan.append((face, i, "eco_" + name))
        else:
            name = {"FaceMouth": "v_mouth", "EyeIris": "v_iris", "EyeHighlight": "v_eye_glint",
                    "EyeWhite": "v_eye_white"}[next(k for k in ("FaceMouth", "EyeIris", "EyeHighlight", "EyeWhite") if k in m.name)]
            write_png(read_px(img), name)
            plan.append((face, i, "eco_" + name))
    for i, m in enumerate(hair.data.materials):
        if "HAIR_01" in m.name:
            write_png(dye_hair(read_px(tex_of(m))), "v_hair")
            plan.append((hair, i, "eco_v_hair"))
        elif "HAIR_02" in m.name:
            write_png(dye_hair(read_px(tex_of(m))), "v_hair_fringe")
            plan.append((hair, i, "eco_v_hair_fringe"))
    for i, m in enumerate(body.data.materials):
        if m and "HairBack" in m.name:
            write_png(dye_hair(read_px(tex_of(m))), "v_hair_cap")
            plan.append((body, i, "eco_v_hair_cap"))
    for i, m in enumerate(boots.data.materials):
        if m and "Shoes" in m.name:
            write_png(recolour_boots(read_px(tex_of(m))), "v_boots")
            plan.append((boots, i, "eco_v_boots"))
        elif m and m.name.endswith("Bottoms_01_CLOTH (Instance)"):
            write_png(recolour_boots(read_px(tex_of(m))), "v_boots_cuff")
            plan.append((boots, i, "eco_v_boots_cuff"))
    # the body: underwear filled with skin, then the suit baked on
    skin_m = body.data.materials[next(iter(mat_index(body, "Body_00_SKIN")))]
    px = read_px(tex_of(skin_m)).copy()
    hole = dilate(px[..., :3].mean(-1) < 150 / 255, 5)
    px[..., :3] = fill_holes(px[..., :3], hole)
    clean = write_png(px, "v_body_skin_src")
    bake_body(body, clean, "light")
    bake_body(body, clean, "medium")
    bake_body(body, clean, "heavy")
    for kind in OUTFITS:
        bake_body(body, clean, kind)
    for name in BASE_STYLES:
        if name != "gwen":
            use_style(name)
            bake_body(body, clean)
    use_style("gwen")
    bake_body(body, clean)
    os.remove(os.path.join(TEX_OUT, "v_body_skin_src.png"))
    plan.append((body, next(iter(mat_index(body, "bake_body"))), "eco_v_body"))
    for ob, i, name in plan:
        ob.material_slots[i].material = new_mat(name)
    for ob in objs:
        bpy.context.view_layer.objects.active = ob
        for o in bpy.data.objects:
            o.select_set(o == ob)
        bpy.ops.object.material_slot_remove_unused()


# --- animation -------------------------------------------------------------------------

def turn(arm, bone, world_axis, deg):
    """Rotate a pose bone about a world-space axis through its head."""
    pb = arm.pose.bones[bone]
    axis = Vector(world_axis).normalized()
    head = pb.head.copy()
    R = Matrix.Translation(head) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-head)
    pb.matrix = R @ pb.matrix
    bpy.context.view_layer.update()


X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)
# old rig name -> VRoid bone, in the order poses are applied (parents first)
BONE = {
    "hips": "J_Bip_C_Hips", "spine": "J_Bip_C_Spine", "chest": "J_Bip_C_Chest", "neck": "J_Bip_C_Neck",
    "head": "J_Bip_C_Head",
}
for _s in "RL":
    BONE.update({"thigh." + _s: "J_Bip_%s_UpperLeg" % _s, "shin." + _s: "J_Bip_%s_LowerLeg" % _s,
                 "foot." + _s: "J_Bip_%s_Foot" % _s, "upperarm." + _s: "J_Bip_%s_UpperArm" % _s,
                 "forearm." + _s: "J_Bip_%s_LowerArm" % _s, "hand." + _s: "J_Bip_%s_Hand" % _s})
ORDER = ["hips", "spine", "chest", "neck", "head", "thigh.R", "shin.R", "foot.R", "thigh.L", "shin.L", "foot.L",
         "upperarm.R", "forearm.R", "hand.R", "upperarm.L", "forearm.L", "hand.L"]
FINGERS = ("Index", "Middle", "Ring", "Little")


def base_pose():
    """Arms down from the T-pose to a relaxed stance, hands just clear of her
    hips (she faces +Y, her right is +X)."""
    return {"upperarm.R": [(Y, 76)], "upperarm.L": [(Y, -76)],
            "forearm.R": [(X, 14)], "forearm.L": [(X, 14)]}


def add(pose, bone, axis, deg):
    pose.setdefault(bone, []).append((axis, deg))


def key_pose(arm, frame, pose, keyed):
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = Quaternion()
        pb.location = (0, 0, 0)
    bpy.context.view_layer.update()
    off = pose.get("_hips_loc")
    if off:
        hb = arm.pose.bones["J_Bip_C_Hips"]
        hb.matrix = Matrix.Translation(Vector(off)) @ hb.matrix
        bpy.context.view_layer.update()
    for name in ORDER:
        for axis, deg in pose.get(name, []):
            turn(arm, BONE[name], axis, deg)
    # relaxed fingers, curled about each hand's own cross axis
    for s, sign in (("R", 1), ("L", -1)):
        for f in FINGERS:
            for j, a in ((1, 22), (2, 30), (3, 18)):
                b = arm.pose.bones["J_Bip_%s_%s%d" % (s, f, j)]
                ax = (b.matrix @ b.bone.matrix_local.inverted()).to_3x3() @ Vector(Y)
                turn(arm, b.name, ax, sign * a * pose.get("_grip", 1.0))
        # the thumb folds down toward the palm and across to the index knuckle
        # (in the T-pose rest the palms face down)
        bones = arm.data.bones
        t1, t3 = bones["J_Bip_%s_Thumb1" % s].head_local, bones["J_Bip_%s_Thumb3" % s].head_local
        tip_dir = (t3 - t1).normalized()
        toward = (Vector((0, 0, -1)) + (bones["J_Bip_%s_Index1" % s].head_local - t1).normalized() * 0.7).normalized()
        rest_axis = tip_dir.cross(toward).normalized()
        for j, a in ((1, 16), (2, 22), (3, 18)):
            b = arm.pose.bones["J_Bip_%s_Thumb%d" % (s, j)]
            ax = (b.matrix @ b.bone.matrix_local.inverted()).to_3x3() @ rest_axis
            turn(arm, b.name, ax, a * min(pose.get("_grip", 1.0), 1.6))
    for name in keyed:
        pb = arm.pose.bones[name]
        pb.keyframe_insert("rotation_quaternion", frame=frame)
    arm.pose.bones["J_Bip_C_Hips"].keyframe_insert("location", frame=frame)


def hips_loc(ly, lz):
    """The old rig's hips offset (local Y up, local Z back) in world terms."""
    return (0.0, -lz, ly)


def make_actions(arm):
    arm.animation_data_create()
    bpy.context.scene.render.fps = 30
    keyed = [BONE[n] for n in ORDER] + ["J_Bip_%s_%s%d" % (s, f, j) for s in "RL" for f in FINGERS + ("Thumb",) for j in (1, 2, 3)]
    acts = []

    def action(name):
        a = bpy.data.actions.new(name)
        arm.animation_data.action = a
        acts.append(a)
        return a
    # idle: 4 s breathing loop with a slow look around
    action("idle")
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
        p["_hips_loc"] = hips_loc(0.0025 * breath, 0)
        key_pose(arm, f, p, keyed)
    # walk: one stride cycle (two steps) in 32 frames, about 1.3 m
    action("walk")
    n = 32
    for f in range(0, n + 1, 2):
        t = f / n * 2 * math.pi
        p = base_pose()
        add(p, "upperarm.R", Y, -4)   # a little out from her sides, so the hands clear her hips
        add(p, "upperarm.L", Y, 4)
        sw = math.sin(t)
        add(p, "thigh.R", X, 26 * sw)
        add(p, "thigh.L", X, -26 * sw)
        add(p, "shin.R", X, -38 * max(0.0, math.sin(t - 1.2)) - 6)
        add(p, "shin.L", X, -38 * max(0.0, math.sin(t + math.pi - 1.2)) - 6)
        add(p, "foot.R", X, 10 * math.cos(t))
        add(p, "foot.L", X, -10 * math.cos(t))
        add(p, "upperarm.R", X, -20 * sw)
        add(p, "upperarm.L", X, 20 * sw)
        add(p, "forearm.R", X, 8 * max(0.0, -sw))
        add(p, "forearm.L", X, 8 * max(0.0, sw))
        add(p, "hips", Z, 6 * sw)
        add(p, "chest", Z, -8 * sw)
        add(p, "head", Z, 2 * sw)
        add(p, "spine", X, 3)
        p["_hips_loc"] = hips_loc(-0.018 * abs(math.cos(t)), 0)
        key_pose(arm, f, p, keyed)
    # run: one stride (two steps) in 22 frames, about 4.4 m: authored at 6 m/s
    action("run")
    n = 22
    for f in range(0, n + 1):
        t = f / n * 2 * math.pi
        p = base_pose()
        add(p, "upperarm.R", Y, -11)   # out from her sides, so the hands clear her hips
        add(p, "upperarm.L", Y, 11)
        sw = math.sin(t)
        add(p, "thigh.R", X, 44 * sw + 6)
        add(p, "thigh.L", X, -44 * sw + 6)
        add(p, "shin.R", X, -95 * max(0.0, math.sin(t - 1.4)) - 14)
        add(p, "shin.L", X, -95 * max(0.0, math.sin(t + math.pi - 1.4)) - 14)
        add(p, "foot.R", X, 16 * math.cos(t))
        add(p, "foot.L", X, -16 * math.cos(t))
        add(p, "upperarm.R", X, -34 * sw)
        add(p, "upperarm.L", X, 34 * sw)
        add(p, "forearm.R", X, 50 + 12 * max(0.0, -sw))
        add(p, "forearm.L", X, 50 + 12 * max(0.0, sw))
        add(p, "spine", X, -9)
        add(p, "head", X, 7)
        add(p, "hips", Z, 9 * sw)
        add(p, "chest", Z, -13 * sw)
        add(p, "head", Z, 4 * sw)
        p["_hips_loc"] = hips_loc(-0.035 + 0.03 * abs(math.sin(t)), 0)
        p["_grip"] = 1.8
        key_pose(arm, f, p, keyed)
    # poses held while airborne, crouched and sliding (gentle motion so they loop)
    action("fall")
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
        add(p, "forearm.R", X, 16)
        add(p, "forearm.L", X, 16)
        add(p, "spine", X, -6)
        add(p, "head", X, 6)
        key_pose(arm, f, p, keyed)
    action("crouch")
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
        add(p, "forearm.R", X, 34)
        add(p, "forearm.L", X, 40)
        p["_hips_loc"] = hips_loc(-0.4, 0.13)
        key_pose(arm, f, p, keyed)
    action("slide")
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
        add(p, "forearm.L", X, 6)
        add(p, "upperarm.R", X, 40)
        add(p, "upperarm.R", Y, -14)
        add(p, "forearm.R", X, 36)
        p["_hips_loc"] = hips_loc(-0.5, 0.05)
        key_pose(arm, f, p, keyed)
    for a in acts:
        for fc in a.fcurves:
            for kp in fc.keyframe_points:
                kp.interpolation = "BEZIER"
    arm.animation_data.action = bpy.data.actions["idle"]


# --- preview ---------------------------------------------------------------------------

def preview(arm):
    """Workbench stills of a few animation frames, textures on."""
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "TEXTURE"
    sc.render.resolution_x, sc.render.resolution_y = 700, 1000
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.location = (1.6, 4.0, 1.0)
    cam.rotation_euler = (Vector((0, 0, 0.88)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 45
    for act, f in (("idle", 0), ("walk", 8), ("run", 6), ("fall", 0), ("crouch", 0), ("slide", 0)):
        arm.animation_data.action = bpy.data.actions[act]
        sc.frame_set(f)
        sc.render.filepath = "%s_%s.png" % (PREVIEW, act)
        bpy.ops.render.render(write_still=True)
    arm.animation_data.action = bpy.data.actions["idle"]
    sc.frame_set(0)


def main():
    os.makedirs(TEX_OUT, exist_ok=True)
    arm = setup_scene()
    remove_fox_parts()
    short_hair()
    fierce_face()
    boots = strip_clothes()
    curves()
    gog = goggles(arm)
    objs = [bpy.data.objects[n] for n in ("Body", "Face", "Hair")] + [boots, gog]
    textures_and_materials(objs, boots)
    objs += suit_armor()
    objs += base_jackets()
    objs += outfit_pieces()
    glute_bones(arm)
    prune_bones(arm)
    proportions(arm, objs)
    face_forward_and_scale(arm, objs)
    face = bpy.data.objects["Face"]
    for k, v in EXPRESSION.items():   # preview only; the game sets these on import
        face.data.shape_keys.key_blocks[k].value = v
    make_actions(arm)
    if PREVIEW:
        preview(arm)
    for k in EXPRESSION:
        face.data.shape_keys.key_blocks[k].value = 0.0
    if "rest" in bpy.data.objects["Body"].data.attributes:
        bpy.data.objects["Body"].data.attributes.remove(bpy.data.objects["Body"].data.attributes["rest"])
    for o in bpy.data.objects:
        o.select_set(o == arm or o in objs)
    bpy.ops.export_scene.gltf(filepath=GLB_OUT, export_format="GLB", use_selection=True,
                              export_animations=True, export_animation_mode="ACTIONS", export_skins=True,
                              export_morph=True, export_materials="EXPORT", export_image_format="NONE",
                              export_yup=True, export_apply=False)
    print("exported", GLB_OUT)


main()
