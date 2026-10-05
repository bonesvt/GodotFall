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
# --only-styles a,b: bake just those base styles' bodysuit textures (no glb)
ONLY_STYLES = argv[argv.index("--only-styles") + 1].split(",") if "--only-styles" in argv else None
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
                  neck=None, panels="shade", belt_kind="none", vents=None, jacket="cowl"),
    "homemade": dict(suit=(0.3, 0.16, 0.022), panel=(0.07, 0.11, 0.05), belt=(0.4, 0.31, 0.18),
                     accent=(0.42, 0.05, 0.07), net=BASE_NET, stretch=(0.38, 0.22, 0.045), glow=(1.0, 0.55, 0.15),
                     neck=None, panels="patchwork", belt_kind="none", vents=None, jacket="vest"),
    "ophelia": dict(suit=(0.008, 0.008, 0.011), panel=(0.13, 0.02, 0.3), belt=(0.012, 0.011, 0.014),
                    accent=(0.72, 0.71, 0.76), net=(0.004, 0.004, 0.006), stretch=(0.035, 0.032, 0.045),
                    glow=(0.55, 0.15, 1.0), neck=None, panels="punk", belt_kind="none", vents=None, jacket="skirt"),
    # Vesper Kane's look (a concept character, worn by Eco for now): not a bodysuit
    # but clothes painted on her skin (vesper_graph): yellow halter crop top, tube
    # booty shorts, suspenders, red sleeves, lavender thigh-highs. "vesper_open"
    # has the halter unzipped down the middle.
    "vesper": dict(panels="vesper", unzip=False, glow=(0.0, 0.0, 0.0), jacket=None),
    "vesper_open": dict(panels="vesper", unzip=True, glow=(0.0, 0.0, 0.0), jacket=None),
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


def face_texture(face, src_img, glam=False, kit=None):
    """Face skin: soften the cheek blush, then paint mature makeup in 3D:
    smoky plum lids, a winged liner flick and a berry lip stain. `glam` is her
    date-night face (v_face_date.png): deeper smoky lids with a gold shimmer at
    the inner corners, a longer, sharper wing, contoured cheeks and red lips.
    `kit` is her face with a suit weight on (v_face_<kit>.png, armory.gd
    SUIT_WEIGHTS): "light" the long, sharp wing and a dark red lip, "medium" a
    smear of grease across her left cheek, "heavy" a stripe of war paint under
    each eye."""
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
    if kit == "light":
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
    elif kit == "light":
        paint(to_srgb(np.array((0.2, 0.008, 0.02))), 0.85 * (1 - ss(0.45, 1.05, lips)) * (y < -0.04))
    else:
        tint((0.78, 0.42, 0.47), 0.75 * (1 - ss(0.35, 1.0, lips)) * (y < -0.04))
    if kit == "medium":   # a smear of grease across her left cheek, wiped on with the back of a glove
        u = (pos[..., 0] - 0.05) / 0.017
        v = (z - 1.257 - 0.35 * (pos[..., 0] - 0.05)) / 0.0045
        smear = (1 - ss(0.3, 1.0, np.sqrt(u * u + v * v))) * (pos[..., 0] > 0.0) * (y < -0.01)
        paint(to_srgb(np.array((0.05, 0.045, 0.04))), 0.6 * smear)
    elif kit == "heavy":   # war paint: a dark stripe under each eye
        stripe = ss(1.2655, 1.2665, z) * (1 - ss(1.2745, 1.2755, z)) * ss(0.02, 0.022, x) * (1 - ss(0.07, 0.072, x)) * (y < -0.01)
        paint(to_srgb(np.array((0.03, 0.03, 0.04))), 0.9 * stripe)
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
KIT_LEATHER = (0.014, 0.012, 0.014)   # the light kit's black leather (crimson edges: LEATHER_RED)
KIT_CANVAS = (0.5, 0.3, 0.02)         # the medium kit's mustard canvas
KIT_RUBBER = (0.02, 0.02, 0.022)      # its black rubber and webbing
KIT_SCARF = (0.02, 0.2, 0.2)          # its teal scarf
TAPE = (0.36, 0.32, 0.25)             # sticking plaster
LEGACY = (0.62, 0.68, 0.8)        # Dad's colours (the game swaps this in at tier 5)


def _body_bvh():
    dg = bpy.context.evaluated_depsgraph_get()
    return BVHTree.FromObject(bpy.data.objects["Body"], dg)


def _armor_mats(me, names):
    cols = {"eco_v_armor": ARMOR, "eco_v_armor_edge": ARMOR_EDGE, "eco_v_armor_strap": STRAP,
            "eco_v_armor_pouch": POUCH, "eco_v_armor_glow": TRIM, "eco_v_kit_leather": KIT_LEATHER,
            "eco_v_leather_red": LEATHER_RED, "eco_v_steel": STEEL, "eco_v_kit_canvas": KIT_CANVAS,
            "eco_v_kit_rubber": KIT_RUBBER, "eco_v_kit_scarf": KIT_SCARF, "eco_v_tape": TAPE,
            "eco_v_jacket": JACKET, "eco_v_jacket_edge": BASE_RED}
    for n in names:
        me.materials.append(new_mat(n, cols.get(n, (0.5, 0.5, 0.5))))


def _drape(bm):
    """Loose cloth over her torso instead of paint-tight: across her front it
    bridges straight between her breasts and hangs straight down from them,
    and at the back it hangs straight down from her shoulder blades."""
    vs = [v for v in bm.verts if abs(v.co.x) < 0.15 and 0.85 < v.co.z < 1.14]
    if not vs:
        return
    P = np.array([v.co[:] for v in vs])
    y = P[:, 1].copy()
    for i, (px, py, pz) in enumerate(P):
        if py < 0 and abs(px) < 0.06:   # bridged across the cleavage, row by row
            row = (np.abs(P[:, 2] - pz) < 0.004) & (P[:, 1] < 0) & (np.abs(P[:, 0]) < 0.08)
            left, right = P[row & (P[:, 0] > 0), 1], P[row & (P[:, 0] < 0), 1]
            if len(left) and len(right):
                y[i] = min(py, max(left.min(), right.min()))
    out = y.copy()
    for i, (px, py, pz) in enumerate(P):
        above = (np.abs(P[:, 0] - px) < 0.014) & (P[:, 2] > pz) & (np.sign(P[:, 1]) == np.sign(py))
        if above.any():
            out[i] = min(y[i], y[above].min()) if py < 0 else max(y[i], y[above].max())
    for v, ny in zip(vs, out):
        v.co.y = float(ny)


def shell(name, keep, planes=(), gap=0.004, thick=0.004, plate="eco_v_armor", edge="eco_v_armor_edge", smooth=0,
          smooth_edge=0, border=0, drape=False):
    """A plate that follows her body: the Body faces `keep(centre, normal)` picks,
    welded, trimmed straight by `planes` ((point, normal): the normal side is cut
    away), lifted `gap` off her skin and given `thick`ness. It keeps the body's
    skin weights, so it moves exactly as she does. Its sides are the bright edge.
    `drape` hangs it loose over her torso (_drape), for a baggy top."""
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
    if drape:
        _drape(bm)
        for _ in range(6):   # even out the hem, whose verts each found different cloth above them
            rim = [v for v in bm.verts if v.is_boundary and v.co.z < 1.1 and abs(v.co.x) < 0.15]
            ys = {}
            for v in rim:
                nb = [e.other_vert(v) for e in v.link_edges if e.is_boundary]
                if len(nb) == 2:
                    ys[v] = v.co.y * 0.5 + (nb[0].co.y + nb[1].co.y) * 0.25
            for v, ny in ys.items():
                v.co.y = ny
        bm.normal_update()
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
    return skirt("base_%s_skirt" % STYLE_NAME, 0.892, 0.725, ["eco_v_tartan"], gap=0.01, flare=0.018,
                 follow=(0.6, 0.92), rows=10, pleats=28)


def base_jacket(shape=None, name=None, mat=None, cuff=None, pick_cuff=False):
    """The base suit's fashion piece (base_*, shown by eco_model.gd only with no
    suit upgrade), by STYLE["jacket"]:
      cropped  a cropped jacket, short sleeves, open at the front so the suit's
               neckline shows, its hem above her ribs at the back, an edge in
               the second colour all round ("gwen": deep teal, crimson edge)
      bomber   the same with sleeves to her forearms and a longer back
      half     the cropped jacket's left half only: one sleeve, its edge down her back
      cowl     a hooded shroud's cowl over her shoulders, up round her neck, its
               hem tattered, short at the front and down her shoulder blades at the back
      vest     a knitted sleeveless vest down to her waist, open at the front (Mom knitted it)
    None of them for a style without one. Its materials are eco_v_jacket[_<style>]
    and ..._edge. Her clothes use it too: `shape`, `name`, `mat` (and its _edge)
    and `cuff` (how far down her arms the sleeves reach) override the style's;
    `pick_cuff` ends the sleeves on whole faces, rounded, instead of cutting them
    straight (a cut through her forearm's long faces leaves jagged slivers)."""
    shape = shape or STYLE["jacket"]
    if not shape:
        return None
    hem, cuff_ = (1.0, 0.33) if shape == "bomber" else (0.95, 0.2) if shape == "vest" else (1.035, 0.25)
    cuff = cuff or cuff_
    name = name or "base_%s_jacket" % STYLE_NAME

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
        if shape == "half" and c.x < 0.0:
            return False   # down the seam at her middle (no cutting plane: a bisected edge leaves a ragged border)
        if ax > 0.15:
            return c.z > 1.0 and (ax < cuff or not pick_cuff)   # the sleeves
        if shape == "vest":   # down to her waist all round, open at the front
            return c.z > hem and not (c.y < 0 and ax < 0.075)
        if c.z < hem or (c.y < -0.04 and (c.z < 1.065 or n.z < -0.3)):
            return False   # the fronts stop above the underside of her bust
        return not (c.y < 0 and ax < 0.07 + 0.2 * max(0.0, 1.12 - c.z))   # open front, curving away
    planes = [((0, 0, hem), (0, 0, -1))] + ([] if pick_cuff else [((cuff, 0, 0), (1, 0, 0)), ((-cuff, 0, 0), (-1, 0, 0))])
    if shape in ("cowl", "vest"):
        planes = []   # their hems are picked by face (a bisected edge leaves a ragged border)
    mat = mat or "eco_v_jacket" + ("" if STYLE_NAME == "gwen" else "_" + STYLE_NAME)
    thick = 0.009 if shape == "vest" else 0.006   # chunky knit
    ob = shell(name, keep, planes=planes, gap=0.006, thick=thick, plate=mat, edge=mat + "_edge",
               smooth=2, smooth_edge=2 if shape == "cowl" else 5, border=1)
    # nothing may stand off her: a stray vertex here once made spikes behind her head
    bvh = _body_bvh()
    far = max((bvh.find_nearest(ob.matrix_world @ v.co)[3] or 0.0) for v in ob.data.vertices)
    top = max(v.co.z for v in ob.data.vertices)
    print("%s: furthest point %.3f m off her, top at z %.3f" % (name, far, top))
    assert top < 1.23, "base_jacket reaches up into her head"
    assert far < 0.03, "base_jacket has a spike"
    return ob


def light_suit(bvh):
    """The light kit (suit_t<tier>l_*): black leather with crimson edges and
    steel buckles, strapped over whichever suit she wears.
      1  a leather cuff over each glove top with a steel buckle, a studded
         belt slung low on her hips with a crimson pouch at her right hip, a
         steel bar through her left brow
      2  a leather guard on her left shoulder
      3  leather knee pads, two buckled straps round each shin, her stiletto's
         sheath on a garter round her right thigh
      4  a leather choker with Dad's dog tag, a band round her left arm with a
         status light
      5  Dad's crest on the shoulder guard"""
    out = []
    for s, side in ((1, "l"), (-1, "r")):
        # --- tier 1: a cuff over each glove top (the arm runs along X at z 1.145; the gloves start at 0.40)
        out.append(shell("suit_t1l_cuff_" + side,
                         lambda c, n: c.x * s > 0.33 and abs(c.z - 1.145) < 0.06 and abs(c.y - 0.022) < 0.06,
                         planes=[((s * 0.352, 0, 0), (-s, 0, 0)), ((s * 0.398, 0, 0), (s, 0, 0))],
                         gap=0.004, thick=0.004, plate="eco_v_kit_leather", edge="eco_v_leather_red"))
        bm = bmesh.new()
        p, n = surface(bvh, (s * 0.375, 0.022, 1.5), (0, 0, -1))
        X, Y, Z = Vector((1, 0, 0)), Vector((0, 0, 1)), Vector((0, -1, 0))
        box(bm, p + Y * 0.009, (X, Y, Z), (0.014, 0.004, 0.018), 0, bevel=0.0012)
        box(bm, p + Y * 0.0108, (X, Y, Z), (0.005, 0.003, 0.012), 1, bevel=0.0008)   # the strap through it
        out.append(rigid("suit_t1l_buckle_" + side, bm, ["eco_v_steel", "eco_v_kit_leather"], "J_Bip_%s_LowerArm" % side.upper()))
    # a studded belt slung low on her hips, under the stomach window, a pouch on it at her right hip
    out.append(shell("suit_t1l_belt", lambda c, n: 0.82 < c.z < 0.9 and abs(c.x) < 0.25,
                     planes=[((0, 0, 0.846), (0, 0, -1)), ((0, 0, 0.868), (0, 0, 1))],
                     gap=0.004, thick=0.004, plate="eco_v_kit_leather", edge="eco_v_leather_red"))
    bm = bmesh.new()
    p, n = surface(bvh, (-0.5, -0.015, 0.862), (1, 0, 0))
    x, y, z = frame_at(p, n)
    box(bm, p + y * 0.02 + z * -0.006, (x, y, z), (0.055, 0.03, 0.05), 0)
    box(bm, p + y * 0.022 + z * 0.018, (x, y, z), (0.058, 0.034, 0.014), 1, bevel=0.003)
    box(bm, p + y * 0.039 + z * 0.012, (x, y, z), (0.01, 0.003, 0.012), 2, bevel=0.001)    # its stud
    out.append(rigid("suit_t1l_pouch", bm, ["eco_v_leather_red", "eco_v_kit_leather", "eco_v_steel"], "J_Bip_C_Hips"))
    # a steel bar through the outer end of her left brow, a ball above and below it
    dg = bpy.context.evaluated_depsgraph_get()
    p, n = surface(BVHTree.FromObject(bpy.data.objects["Face"], dg), (0.052, -0.5, 1.302), (0, 1, 0))
    bm = bmesh.new()
    if p is not None:
        n = Vector(n).normalized()
        for t in (-1, 1):
            cylinder(bm, p + n * 0.0012 + Vector((0, 0, t * 0.0042 - 0.0011)), n, 0.0011, 0.0022, 0, segments=8)
    out.append(rigid("suit_t1l_brow", bm, ["eco_v_steel"], "J_Bip_C_Head"))
    # --- tier 2: a leather guard on her left shoulder only
    out.append(shell("suit_t2l_shoulder_l",
                     lambda c, n: 0.06 < c.x < 0.2 and c.z > 1.1,
                     planes=[((0.085, 0, 0), (-1, 0, 0)), ((0.175, 0, 0), (1, 0, 0)), ((0, 0, 1.135), (0, 0, -1))],
                     gap=0.008, thick=0.005, plate="eco_v_kit_leather", edge="eco_v_leather_red"))
    for s, side in ((1, "l"), (-1, "r")):
        # --- tier 3: leather knee pads, two buckled straps round each shin
        out.append(shell("suit_t3l_knee_" + side,
                         lambda c, n: c.y < 0.06 and 0.4 < c.z < 0.56 and c.x * s > 0.0,
                         planes=[((0, 0, 0.44), (0, 0, -1)), ((0, 0, 0.505), (0, 0, 1)), ((0, -0.012, 0), (0, 1, 0))],
                         gap=0.008, thick=0.005, plate="eco_v_kit_leather", edge="eco_v_leather_red"))
        bm = bmesh.new()
        for k, (a, b) in enumerate(((0.25, 0.264), (0.33, 0.344))):
            out.append(shell("suit_t3l_shinstrap%d_%s" % (k, side), lambda c, n: 0.2 < c.z < 0.4 and c.x * s > 0.0,
                             planes=[((0, 0, a), (0, 0, -1)), ((0, 0, b), (0, 0, 1))],
                             gap=0.003, thick=0.003, plate="eco_v_kit_leather", edge="eco_v_kit_leather"))
            p, n = surface(bvh, (s * 0.5, -0.005, (a + b) / 2), (-s, 0, 0))
            x, y, z = frame_at(p, n)
            box(bm, p + y * 0.0065, (x, y, z), (0.012, 0.003, 0.017), 0, bevel=0.001)
        out.append(rigid("suit_t3l_shinbuckles_" + side, bm, ["eco_v_steel"], "J_Bip_%s_LowerLeg" % side.upper()))
    # the stiletto's sheath on a garter round her right thigh
    out.append(shell("suit_t3l_garter", lambda c, n: c.x < 0.0 and 0.6 < c.z < 0.68,
                     planes=[((0, 0, 0.62), (0, 0, -1)), ((0, 0, 0.636), (0, 0, 1))],
                     gap=0.003, thick=0.003, plate="eco_v_kit_leather", edge="eco_v_leather_red"))
    bm = bmesh.new()
    p, n = surface(bvh, (-0.5, -0.01, 0.6), (1, 0, 0))
    x, y, z = frame_at(p, n)
    box(bm, p + y * 0.011 - z * 0.01, (x, y, z), (0.022, 0.012, 0.11), 0, bevel=0.004)
    cylinder(bm, p + y * 0.011 + z * 0.044, z, 0.0055, 0.04, 1, segments=10)      # grip
    cylinder(bm, p + y * 0.011 + z * 0.042, z, 0.011, 0.004, 2, segments=10)      # guard
    out.append(rigid("suit_t3l_sheath", bm, ["eco_v_kit_leather", "eco_v_leather_red", "eco_v_steel"], "J_Bip_R_UpperLeg"))
    # --- tier 4: a choker high on her neck, a ring at the front and Dad's tag hanging from it
    out.append(shell("suit_t4l_choker", lambda c, n: 1.18 < c.z < 1.24 and math.hypot(c.x, c.y - 0.022) < 0.07,
                     planes=[((0, 0, 1.206), (0, 0, -1)), ((0, 0, 1.222), (0, 0, 1))],
                     gap=0.002, thick=0.003, plate="eco_v_kit_leather", edge="eco_v_leather_red"))
    bm = bmesh.new()
    p, n = surface(bvh, (0, -0.5, 1.214), (0, 1, 0))
    fwd = Vector((0, -1, 0))
    torus(bm, p + fwd * 0.007 + Vector((0, 0, -0.004)), fwd, 0.006, 0.0012, 0)
    tag = p + fwd * 0.012 + Vector((0, 0, -0.024))
    box(bm, tag, (Vector((1, 0, 0)), fwd, Vector((0, 0, 1))), (0.014, 0.002, 0.022), 0, bevel=0.003)
    out.append(rigid("suit_t4l_tag", bm, ["eco_v_armor_edge"], "J_Bip_C_Neck"))
    # a band round her left upper arm with a status light
    out.append(shell("suit_t4l_armband", lambda c, n: 0.15 < c.x < 0.27,
                     planes=[((0.2, 0, 0), (-1, 0, 0)), ((0.222, 0, 0), (1, 0, 0))],
                     gap=0.003, thick=0.003, plate="eco_v_kit_leather", edge="eco_v_leather_red"))
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
    """The heavy kit's own pieces beyond the gunmetal plates in suit_armor:
      1  a breastplate cut from Dad's titan's hull, a comm earpiece with a mic
      5  the titan's old core light set in the breastplate"""
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
    # --- tier 5: the core light in the middle of the breastplate
    dg = bpy.context.evaluated_depsgraph_get()
    hit, _n = surface(BVHTree.FromObject(plate, dg), (0, -0.5, 1.066), (0, 1, 0))
    p = hit if hit is not None else Vector((0, -0.11, 1.066))
    n = Vector((0, -1, 0))
    bm = bmesh.new()
    cylinder(bm, p - n * 0.003, n, 0.019, 0.007, 1, segments=16)
    cylinder(bm, p + n * 0.003, n, 0.012, 0.003, 0, segments=16)
    out.append(rigid("suit_t5h_core", bm, ["eco_v_armor_glow", "eco_v_armor_edge"], "J_Bip_C_Chest"))
    return out


def medium_suit(bvh):
    """The medium kit (suit_t<tier>m_*): a mechanic's rig of mustard canvas,
    black rubber and webbing, steel and teal, over whichever suit she wears.
      1  a tool pouch on her left hip with a spanner and a screwdriver standing
         in it, a wrist computer strapped to her left forearm
      2  a teal scarf knotted at her neck, a crossed plaster on her right
         cheek, a canvas yoke over her shoulders, a rubber pad on her right elbow
      3  rubber knee caps on straps, a cargo pocket on a strap round her right thigh
      4  a canvas bedroll strapped across her back, over the jump pack
      5  Dad's crest on a patch on the yoke"""
    out = []
    dg = bpy.context.evaluated_depsgraph_get()
    face_bvh = BVHTree.FromObject(bpy.data.objects["Face"], dg)
    # --- tier 1: the tool pouch on her left hip, a spanner and a screwdriver standing in it
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
    out.append(rigid("suit_t1m_toolpouch", bm, ["eco_v_kit_canvas", "eco_v_kit_rubber", "eco_v_steel", "eco_v_kit_scarf"],
                     "J_Bip_C_Hips"))
    # the wrist computer on her left forearm
    out.append(shell("suit_t1m_wriststrap", lambda c, n: 0.3 < c.x < 0.42 and abs(c.z - 1.145) < 0.06,
                     planes=[((0.338, 0, 0), (-1, 0, 0)), ((0.392, 0, 0), (1, 0, 0))],
                     gap=0.003, thick=0.004, plate="eco_v_kit_rubber", edge="eco_v_kit_canvas"))
    bm = bmesh.new()
    p, n = surface(bvh, (0.365, 0.022, 1.5), (0, 0, -1))
    X, Y, Z = Vector((1, 0, 0)), Vector((0, 0, 1)), Vector((0, -1, 0))
    box(bm, p + Y * 0.011, (X, Y, Z), (0.05, 0.014, 0.036), 0, bevel=0.003)
    box(bm, p + Y * 0.0185, (X, Y, Z), (0.034, 0.002, 0.024), 1, bevel=0.0008)            # screen
    for t in (-1, 1):
        cylinder(bm, p + Y * 0.016 + X * (t * 0.021) + Z * 0.012, Y, 0.0025, 0.004, 2, segments=8)   # dials
    out.append(rigid("suit_t1m_wristcomp", bm, ["eco_v_kit_canvas", "eco_v_armor_glow", "eco_v_steel"], "J_Bip_L_LowerArm"))
    # --- tier 2: the scarf round her neck, knotted at the front left
    out.append(shell("suit_t2m_scarf", lambda c, n: 1.15 < c.z < 1.24 and math.hypot(c.x, c.y - 0.022) < 0.075,
                     planes=[((0, 0, 1.166), (0, 0, -1)), ((0, 0, 1.204), (0, 0, 1))],
                     gap=0.007, thick=0.005, plate="eco_v_kit_scarf", edge="eco_v_kit_scarf"))
    bm = bmesh.new()
    p, n = surface(bvh, (0.032, -0.5, 1.18), (0, 1, 0))
    x, y, z = frame_at(p, n)
    k = p + y * 0.014
    box(bm, k, (x, y, z), (0.022, 0.016, 0.02), 0, bevel=0.006)
    for t, ang in ((-1, 0.35), (1, -0.15)):   # two tails falling over her collarbone
        tz = (z * math.cos(ang) + x * math.sin(ang)).normalized()
        box(bm, k + x * (t * 0.006) - tz * 0.03 + y * 0.002, (tz.cross(y).normalized(), y, tz), (0.016, 0.005, 0.045), 0, bevel=0.0025)
    out.append(rigid("suit_t2m_scarf_knot", bm, ["eco_v_kit_scarf"], "J_Bip_C_Neck"))
    # a crossed plaster high on her right cheek
    bm = bmesh.new()
    p, n = surface(face_bvh, (-0.03, -0.5, 1.262), (0, 1, 0))
    if p is not None:
        x, y, z = frame_at(p, n)
        for ang in (0.6, -0.6):
            ax_ = (x * math.cos(ang) + z * math.sin(ang)).normalized()
            box(bm, p + y * 0.0012, (ax_, y, y.cross(ax_).normalized()), (0.016, 0.0012, 0.005), 0, bevel=0.0008)
    out.append(rigid("suit_t2m_plaster", bm, ["eco_v_tape"], "J_Bip_C_Head"))
    # a canvas yoke over her shoulders, low on the back, at the collarbone in front
    out.append(shell("suit_t2m_yoke",
                     lambda c, n: 1.05 < c.z < 1.25 and abs(c.x) < 0.2 and (math.hypot(c.x, c.y - 0.022) > 0.06 or c.z < 1.16),
                     planes=[((0, 0, 1.12), Vector((0, -0.5, -1)).normalized()), ((0.15, 0, 0), (1, 0, 0)), ((-0.15, 0, 0), (-1, 0, 0))],
                     gap=0.009, thick=0.006, plate="eco_v_kit_canvas", edge="eco_v_kit_rubber"))
    out.append(shell("suit_t2m_elbow_r",
                     lambda c, n: -0.34 < c.x < -0.24 and c.z > 1.1,
                     planes=[((-0.268, 0, 0), (1, 0, 0)), ((-0.308, 0, 0), (-1, 0, 0)), ((0, 0, 1.13), (0, 0, -1))],
                     gap=0.008, thick=0.008, plate="eco_v_kit_rubber", edge="eco_v_kit_canvas"))
    # --- tier 3: rubber knee caps on two straps; a cargo pocket on her right thigh
    for s, side in ((1, "l"), (-1, "r")):
        bm = bmesh.new()
        p, n = surface(bvh, (s * 0.069, -0.5, 0.478), (0, 1, 0))
        cylinder(bm, p - n * 0.004, n, 0.03, 0.02, 0, segments=14, radius2=0.019)
        out.append(rigid("suit_t3m_kneecap_" + side, bm, ["eco_v_kit_rubber"], "J_Bip_%s_LowerLeg" % side.upper()))
        for a, b in ((0.425, 0.437), (0.515, 0.527)):
            out.append(shell("suit_t3m_kneestrap%d_%s" % (int(a > 0.5), side), lambda c, n: 0.38 < c.z < 0.58 and c.x * s > 0.0,
                             planes=[((0, 0, a), (0, 0, -1)), ((0, 0, b), (0, 0, 1))],
                             gap=0.004, thick=0.003, plate="eco_v_kit_rubber", edge="eco_v_kit_canvas"))
    out.append(shell("suit_t3m_thighstrap", lambda c, n: c.x < 0.0 and 0.66 < c.z < 0.74,
                     planes=[((0, 0, 0.7), (0, 0, -1)), ((0, 0, 0.714), (0, 0, 1))],
                     gap=0.003, thick=0.003, plate="eco_v_kit_rubber", edge="eco_v_kit_rubber"))
    bm = bmesh.new()
    p, n = surface(bvh, (-0.5, -0.005, 0.67), (1, 0, 0))
    x, y, z = frame_at(p, n)
    box(bm, p + y * 0.016, (x, y, z), (0.062, 0.026, 0.075), 0)
    box(bm, p + y * 0.018 + z * 0.03, (x, y, z), (0.066, 0.03, 0.02), 0, bevel=0.003)     # flap
    box(bm, p + y * 0.034 + z * 0.018, (x, y, z), (0.01, 0.004, 0.012), 1, bevel=0.001)   # press stud
    out.append(rigid("suit_t3m_cargo", bm, ["eco_v_kit_canvas", "eco_v_steel"], "J_Bip_R_UpperLeg"))
    # --- tier 4: a canvas bedroll strapped across her back, above the jump pack
    bm = bmesh.new()
    p, n = surface(bvh, (0, 0.5, 1.04), (0, -1, 0))
    X = Vector((1, 0, 0))
    c = p + Vector((0, 0.03, 0))
    cylinder(bm, c - X * 0.085, X, 0.026, 0.17, 0, segments=14)
    for t in (-1, 1):   # two rubber straps round it
        cylinder(bm, c + X * (t * 0.05 - 0.004), X, 0.0275, 0.008, 1, segments=14)
    out.append(rigid("suit_t4m_bedroll", bm, ["eco_v_kit_canvas", "eco_v_kit_rubber"], "J_Bip_C_Chest"))
    # --- tier 5: Dad's crest on a patch on the yoke's right shoulder
    bm = bmesh.new()
    p, n = surface(bvh, (-0.12, 0.022, 1.6), (0, 0, -1))
    x, y, z = frame_at(p, n, up=(0, -1, 0))
    box(bm, p + y * 0.0165, (x, y, z), (0.036, 0.002, 0.036), 0, bevel=0.002)
    cylinder(bm, p + y * 0.0175, y, 0.013, 0.003, 1, segments=6)
    cylinder(bm, p + y * 0.0195, y, 0.0065, 0.002, 2, segments=6)
    out.append(rigid("suit_t5m_crest", bm, ["eco_v_kit_rubber", "eco_v_armor_edge", "eco_v_armor_glow"], "J_Bip_R_UpperArm"))
    return out


def suit_armor():
    """Eco's suit upgrades (scripts/hub/armory.gd SUIT_TIERS), modelled on her in
    rest space (she faces -Y, her left is +X, T-pose). Every piece is named
    suit_t<tier><weight>_<part>; the game shows the pieces of every tier she has
    bought (eco_model.gd suit_tier). <weight> is the suit weights that wear the
    piece (armory.gd SUIT_WEIGHTS): none for all three (the belt, the seal
    injector, the jump pack), "l" light only (light_suit), "m" medium only
    (medium_suit), "h" heavy only: the gunmetal plates here and heavy_extras.
    Every kit goes over whichever suit style she wears. Each tier adds to the last
    (the heavy kit's plates; the shared pieces for every weight):
      1 Scav rig      bracers, elbow cops, a belt with hip pouches
      2 Seal weave    layered shoulder plates, upper-arm plates; a thigh strap
                      with a seal injector (every weight)
      3 Dampers       shin guards, knee cops, thigh and hip plates
      4 Jump kit      a back plate, an armoured collar; a jump pack low on her
                      back (every weight)
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
    # --- tier 1: the belt on her waist (medium and heavy; light slings its own
    # low on her hips, under the stomach window), and two hip pouches
    for w in "mh":
        out.append(shell("suit_t1%s_belt" % w, lambda c, n: 0.89 < c.z < 0.97 and abs(c.x) < 0.25,
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
        # its shine painted on (a real sheen blotches): soft streaks down the
        # fronts of her thighs and shins, along the tops of her arms, down her sides
        def streak(v, c, w):
            return g.op("EXPONENT", g.neg(g.sq(g.div(g.sub(v, c), w))))
        shine = g.mul(g.mul(streak(ax, 0.095, 0.009), g.band(z, 0.53, 0.8, 0.03)), front)
        shine = g.mx(shine, g.mul(g.mul(streak(z, 1.172, 0.006), g.band(ax, 0.19, 0.29, 0.01)), g.sub(1.0, back)))
        shine = g.mx(shine, g.mul(g.mul(streak(ax, 0.118, 0.006), g.band(z, 0.88, 0.98, 0.02)), front))
        col = g.mixc(col, (0.1, 0.1, 0.125), g.mul(g.mul(shine, 0.7), on))
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
        c = patch(rect(0.19, 0.255, 1.1, 1.2), DENIM, front)   # on her left upper arm
        col = g.mixc(col, g.mixc(DENIM, INK, 0.45), g.mul(g.mul(lines(g.add(x, g.mul(z, 2.0)), 0.003), 0.6), c))
        col = g.mixc(col, S["accent"], g.mul(g.mul(g.sstep(-AA, AA, heart(0.2225, 1.143, 0.011)), front), on))
        c = patch(rect(-0.125, -0.05, 0.8, 0.87), GINGHAM, front)
        col = g.mixc(col, (0.08, 0.13, 0.06), g.mul(checks(0.011), c))
        c = patch(heart(-0.075, 0.478, 0.03), FLORAL, front)
        col = g.mixc(col, KNIT, g.mul(dots(0.009), c))
        c = patch(rect(0.045, 0.112, 0.58, 0.66), KNIT, front)
        col = g.mixc(col, g.mixc(KNIT, INK, 0.3), g.mul(g.mul(lines(g.add(z, g.mul(ax, 0.6)), 0.006), 0.5), c))
        c = patch(rect(-0.11, -0.04, 0.55, 0.64), GINGHAM, back)
        col = g.mixc(col, (0.08, 0.13, 0.06), g.mul(checks(0.011), c))
        c = patch(rect(0.04, 0.11, 0.6, 0.68), FLORAL, back)
        col = g.mixc(col, KNIT, g.mul(dots(0.009), c))
        for sd in (1.0, -1.0):
            c = patch(g.mn(oval(0.3 * sd, 1.145, 0.035, 0.04), g.sub(y, 0.03)), CORDUROY)
            col = g.mixc(col, g.mixc(CORDUROY, INK, 0.5), g.mul(g.mul(lines(g.add(y, z), 0.004), 0.6), c))
        # the braided rope belt
        d_rope = g.mn(g.sub(z, 0.903), g.sub(0.918, z))
        c = fill(d_rope)
        col = g.mixc(col, S["belt"], c)
        col = g.mixc(col, g.mixc(S["belt"], INK, 0.45), g.mul(g.mul(lines(g.add(g.add(x, y), g.mul(z, 2.5)), 0.006), 0.7), c))
        ink = g.mx(ink, g.mul(g.band(d_rope, -0.0004, 0.0006), on))
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


# Vesper's colours (linear)
V_YELLOW = (0.88, 0.52, 0.02)
V_YELLOW_DK = (0.55, 0.26, 0.0)
V_RED = (0.50, 0.012, 0.014)
V_STRAP = (0.035, 0.004, 0.008)
V_STOCKING = (0.42, 0.28, 0.72)
V_HEM = 1.022          # the halter's hem: at the bottom of her bust (its apex is ~1.047)
V_FRONT_TOP = 0.83     # the shorts' waistband at the front, low on her hips (navel ~0.93)
V_BACK_TOP = 0.80      # the tube shorts' band at the centre back: the top of her cheeks shows
V_LEG = 0.71           # the leg line where it passes between her legs (low enough to cover the crotch)


def vesper_graph(nt, skin):
    """Vesper Kane's look (BASE_STYLES "vesper"/"vesper_open"), worked out per pixel
    from the rest position like the suits, but as clothes over bare skin:
      - a skin-tight yellow halter crop top: high collar, a narrow V at the front
        (unzipped: open down the middle to the hem, showing the inner curve of her
        bust, the cups still over the front of each), its hem at the bottom of her
        bust, a low band round her back
      - yellow tube booty shorts: low-rise and high-cut at the front, the back band
        dipping low over her cheeks and cut cheeky below; dark suspenders hanging
        loose from the waistband down her thighs
      - red sleeves from mid upper arm to the wrist (her jacket slung down her
        arms), black cuffs; lavender thigh-highs down into her ankle boots
    Returns the same sockets as suit_graph."""
    unzip = STYLE["unzip"]
    g = NG(nt)
    at = nt.nodes.new("ShaderNodeAttribute")
    at.attribute_name = "rest"
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(at.outputs["Vector"], sep.inputs[0])
    x, y, z = sep.outputs[0], sep.outputs[1], sep.outputs[2]
    ax = g.abs(x)
    tb = g.sstep(-0.025, 0.045, y)                    # 0 at the front, 1 at the back
    front = g.sub(1.0, tb)
    AA = 0.00045
    # the top: up to the collar at the front, cut away over the shoulders, a low band behind
    zf = g.sub(1.175, g.mul(1.7, g.mx(g.sub(ax, 0.04), 0.0)))
    hem = g.add(V_HEM, g.mul(0.0 if unzip else 0.01, g.op("EXPONENT", g.mul(g.sq(g.div(x, 0.022)), -1.0))))
    d_top = g.mn(g.sub(g.lerp(zf, 1.05, tb), z), g.sub(z, g.add(hem, g.mul(0.012, tb))))
    r = g.sqrt(g.add(g.sq(x), g.sq(g.sub(y, 0.022))))
    d_collar = g.mn(g.mn(g.sub(z, 1.15), g.sub(1.2, z)), g.sub(0.064, r))
    d_top = g.mx(d_top, d_collar)
    # the V: a narrow one below the collar, or unzipped to the hem and straight up
    # past her bust, leaving halter straps to the collar. Unzipped, it also never
    # comes nearer than 1 cm to the covered zone round each tip (vesper-limits: a
    # 2.2 cm disc): a line tangent to that zone plus 1 cm bounds it
    v0, slope = (V_HEM + 0.004, 2.0) if unzip else (1.075, 0.32)
    w_v = g.mul(g.mx(g.sub(z, v0), 0.0), slope)
    if unzip:
        w_v = g.mn(g.mn(w_v, 0.043), g.add(0.014, g.mul(0.9, g.sub(z, APEX_POS[2]))))
    d_v = g.sub(w_v, ax)
    d_v = g.mn(d_v, g.mul(g.sub(front, 0.5), 0.1))   # (front only)
    d_top = g.mn(d_top, g.neg(d_v))
    # the shorts: low-rise front, the back band dipping over her cheeks, cheeky legs
    lx = g.mx(g.sub(ax, 0.028), 0.0)
    zt = g.lerp(g.add(V_FRONT_TOP, g.mul(1.5, g.sq(ax))), g.add(V_BACK_TOP, g.mul(3.2, g.sq(ax))), tb)
    zl = g.lerp(g.add(V_LEG, g.mul(2.0, lx)), g.add(V_LEG, lx), tb)
    zl = g.mn(zl, g.sub(zt, 0.025))                  # a band over her hips
    d_shorts = g.mn(g.sub(zt, z), g.sub(z, zl))
    d_sleeve = g.mn(g.mn(g.sub(ax, 0.27), g.sub(0.528, ax)), g.sub(1.30, z))
    cuff = g.sstep(0.507 - AA, 0.507 + AA, ax)
    d_stock = g.mn(g.sub(0.62, z), g.sub(z, 0.15))
    d_gear = g.sub(0.2, z)                            # her ankle boots
    c_top = g.sstep(-AA, AA, d_top)
    c_sh = g.sstep(-AA, AA, d_shorts)
    c_sl = g.sstep(-AA, AA, d_sleeve)
    c_st = g.sstep(-AA, AA, d_stock)
    c_gear = g.sstep(-AA, AA, d_gear)
    # suspenders from the front of the waistband, hanging loose down her thighs
    fr = g.sub(1.0, g.sstep(-0.03, 0.0, y))
    zs = V_FRONT_TOP + 1.5 * 0.079 ** 2
    hang = g.mul(g.band(z, 0.60, zs + 0.015, 0.0006), fr)
    loop = g.mul(g.mul(g.band(ax, 0.072, 0.086, 0.0006), g.band(z, zs + 0.01, zs + 0.025, 0.0006)), fr)
    c_strap = g.mx(g.mul(g.band(ax, 0.072, 0.086, 0.0006), hang), loop)
    col = g.mixc(skin, V_YELLOW, c_top)
    col = g.mixc(col, V_YELLOW, c_sh)
    col = g.mixc(col, V_STOCKING, c_st)
    col = g.mixc(col, V_RED, c_sl)
    col = g.mixc(col, INK, g.mul(c_sl, cuff))
    col = g.mixc(col, V_STRAP, c_strap)
    # the waistband, and a stitched seam down the front of the top
    col = g.mixc(col, V_YELLOW_DK, g.mul(g.mul(g.band(g.sub(zt, z), -0.015, 0.003, 0.0004), c_sh), 0.6))
    col = g.mixc(col, V_YELLOW_DK, g.mul(g.mul(g.mul(g.band(x, -0.0012, 0.0012, 0.0003), c_top), front), 0.7))
    # where the top clings: a soft shadow under each curve and a gleam across the
    # top of it (painted; nothing drawn at the apex)
    under, gleam = 0.0, 0.0
    for sx in (APEX_POS[0], -APEX_POS[0]):
        du = g.add(g.sq(g.div(g.sub(x, sx), 0.03)), g.sq(g.div(g.sub(z, V_HEM + 0.008), 0.010)))
        under = g.mx(under, g.sub(1.0, g.sstep(0.4, 1.0, du)))
        dg = g.add(g.sq(g.div(g.sub(x, sx * 1.12), 0.012)), g.sq(g.div(g.sub(z, 1.066), 0.007)))
        gleam = g.mx(gleam, g.sub(1.0, g.sstep(0.55, 1.0, dg)))
    col = g.mixc(col, V_YELLOW_DK, g.mul(g.mul(g.mul(under, c_top), front), 0.45))
    col = g.mixc(col, (1.0, 0.86, 0.45), g.mul(g.mul(g.mul(gleam, c_top), front), 0.55))
    if unzip:   # zipper teeth down each edge of the opening, the pull at the bottom
        col = g.mixc(col, (0.45, 0.42, 0.38), g.mul(g.mul(g.band(d_v, -0.0026, -0.0010, 0.0003), c_top), front))
        pull = g.mul(g.band(ax, -0.001, 0.0035, 0.0004), g.band(z, V_HEM, V_HEM + 0.006, 0.0004))
        col = g.mixc(col, (0.7, 0.66, 0.6), g.mul(pull, c_top))
    col = g.mixc(col, GEAR, c_gear)
    cover = g.mx(g.mx(g.mx(c_top, c_sh), c_st), g.mx(c_sl, c_gear))
    crease = crease_lines(g, x, y, z, 0.0015)
    col = g.mixc(col, CREASE_SKIN, g.mul(g.mul(crease, 0.85), g.sub(1.0, cover)), "MULTIPLY")
    col = g.mixc(col, INK, g.mul(g.mul(crease, 0.85), c_sh))
    ink = g.mx(g.mx(g.band(d_top, 0.0, 0.0008), g.band(d_shorts, 0.0, 0.0008)), g.band(d_stock, 0.0, 0.0008))
    ink = g.mx(ink, g.mx(g.band(d_sleeve, 0.0, 0.0008), g.band(d_gear, 0.0, 0.0008)))
    ink = g.mx(ink, g.mul(g.mx(g.band(ax, 0.071, 0.0725, 0.0004), g.band(ax, 0.0855, 0.087, 0.0004)), hang))
    col = g.mixc(col, INK, ink)
    return col, g.mul(cover, 0.0), cover, ink, c_gear, 0.0


def suit_graph(nt, skin):
    """The pilot suit in STYLE, worked out per pixel from each point's rest
    position (the 'rest' attribute) so its edges are smooth curves whatever the
    mesh does: neck to gloves to her ankle boots under a high collar, its panels
    and trims from base_details (or vesper_graph for a Vesper style). The suit
    upgrades (suit_armor) go over it, whichever style she wears.
    Returns (albedo colour, glow amount, cover amount, ink line, gloves and
    boots, gloss) sockets."""
    if STYLE["panels"] == "vesper":
        return vesper_graph(nt, skin)
    g = NG(nt)
    at = nt.nodes.new("ShaderNodeAttribute")
    at.attribute_name = "rest"
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(at.outputs["Vector"], sep.inputs[0])
    x, y, z = sep.outputs[0], sep.outputs[1], sep.outputs[2]
    ax = g.abs(x)
    front = g.sub(1.0, g.sstep(-0.045, -0.025, y))
    AA = 0.00045
    # neck to gloves to boots, under a high collar
    d_suit = g.sub(1.205, z)
    r = g.sqrt(g.add(g.sq(x), g.sq(g.sub(y, 0.022))))
    d_collar = g.mn(g.mn(g.sub(z, 1.166), g.sub(1.205, z)), g.sub(0.062, r))
    # gloves, and her ankle boots
    d_gear = g.mx(g.sub(ax, 0.40), g.sub(0.2, z))
    c_suit = g.sstep(-AA, AA, d_suit)
    c_gear = g.sstep(-AA, AA, d_gear)
    col = g.mixc(skin, STYLE["suit"], c_suit)
    col, ink_b, trim_b, gloss = base_details(g, x, y, z, skin, col, c_suit, c_gear, front, AA)
    col = g.mixc(col, GEAR, c_gear)
    ink = g.mx(g.band(d_suit, 0.0, 0.0008), g.band(d_gear, 0.0, 0.0008))
    trim = g.mx(g.band(d_suit, 0.0012, 0.0028), g.band(d_gear, 0.0012, 0.0034))
    trim = g.mx(trim, g.mul(g.band(z, 1.1845, 1.1865), g.sstep(-AA, AA, d_collar)))
    ink, trim = g.mx(ink, ink_b), g.mx(trim, trim_b)
    seam = g.mul(g.mul(g.band(y, 0.012, 0.0135), g.sstep(0.05, 0.06, ax)), c_suit)
    col = g.mixc(col, PLATE, seam)
    # a crease between her glutes and a fold under each one: a warm shade where
    # the suit bares her skin, dark on the suit
    crease = crease_lines(g, x, y, z, 0.0015)
    col = g.mixc(col, CREASE_SKIN, g.mul(g.mul(crease, 0.85), g.sub(1.0, c_suit)), "MULTIPLY")
    col = g.mixc(col, INK, g.mul(g.mul(crease, 0.85), c_suit))
    col = g.mixc(col, INK, ink)
    col = g.mixc(col, STYLE["glow"], trim)
    return col, trim, g.mx(c_suit, c_gear), ink, c_gear, gloss

# --- clothes (eco_model.gd outfit) --------------------------------------------------------

# Her clothes off duty, each in two versions for the content rating
# (scripts/radio/content_rating.gd): <outfit>_t for Teen, <outfit>_m for Mature.
# Each bakes v_body*_<kind>.png; its loose parts are outfit_<outfit>_<t|m|any>_* meshes.
OUTFITS = ("skater_t", "skater_m", "y2k_t", "y2k_m", "date_t", "date_m")
BAKES = OUTFITS + ("skater_hoodie",)   # (the hoodie's own texture, in her body's UVs)
OUTFIT_GLOW = TRIM
TEE_PRINT = (0.0, 0.33, 0.3)          # teal print and stripes
HOODIE = (0.42, 0.24, 0.025)          # skater: her mustard hoodie
HOODIE_DARK = (0.25, 0.13, 0.012)
CREAM = (0.62, 0.58, 0.47)
SHORTS = (0.012, 0.012, 0.016)        # black bike shorts
SOCK_WHITE = (0.62, 0.6, 0.56)
SOCK_RED = (0.35, 0.02, 0.03)
PINK = (0.7, 0.2, 0.32)               # y2k: baby pink
KHAKI = (0.28, 0.22, 0.12)            # her cargo mini (cargo.png)
LEG_SKIN = (0.99, 0.86, 0.77)         # her thigh skin, sampled from the preset
CORSET = (0.01, 0.009, 0.012)         # black leather
LEATHER_RED = (0.2, 0.024, 0.016)     # rust-red leather, the red of her hair
STEEL = (0.38, 0.39, 0.42)
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


def skirt(name, top, hem, mats, gap=0.006, flare=0.0, slit=None, trim=False, follow=(0.25, 0.65), rows=16, pleats=0,
          back_hem=None):
    """A loose hanging skirt: rings round the convex hull of her hips and thighs
    from `top` down to `hem`, so it bridges between her legs instead of wrapping
    each one like paint would. `flare` pushes the hem out, `slit` (angle deg,
    half width deg at the hem, top z) opens it from that height down (the angle
    runs from her left, +x, toward her back; with no top z it is open its full
    width from top to hem), `back_hem` raises the hem toward her back (each
    ring stays as wide as the widest above it, so lifting it never tucks it
    into her), `trim` makes the bottom row the
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
        # widens smoothly from its top to the hem (a clean V, not grid steps);
        # a slit with no top is open the same width all the way down
        w = 0.0
        if slit is not None and len(slit) == 2:
            w = slit[1]
        elif slit is not None and z < slit[2]:
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
            zv = z
            if back_hem is not None:
                w = smooth(-0.2, 0.8, d.y)   # 0 at her front, 1 at her back
                zv = top + (hem + (back_hem - hem) * w - top) * t
            ring.append(bm.verts.new((c.x + d.x * rad, c.y + d.y * rad, zv)))
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
    # the grid before it gets thickness: both its layers take their weights from it
    cloth = [(r, k, Vector(v.co)) for r, ring in enumerate(grid) for k, v in enumerate(ring) if v.is_valid]
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
    # weights per grid point: half her hips, half the nearest bit of her
    # (`follow`), less at her back so it doesn't split over her glutes when she
    # crouches, then smoothed round each ring so the hem bends evenly
    wts = {}
    mid_y = sum(q.y for _, _, q in cloth) / len(cloth)
    for r, k, p in cloth:
        t = min(1.0, max(0.0, (top - p.z) / (top - hem)))
        f = follow[0] + (follow[1] - follow[0]) * t
        f *= 1.0 - 0.45 * smooth(0.0, 0.06, p.y - mid_y)
        _, i, _ = kd.find(p)
        w = {"J_Bip_C_Hips": 1.0 - f}
        for ge in body.data.vertices[i].groups:
            w[names[ge.group]] = w.get(names[ge.group], 0.0) + f * ge.weight
        wts[(r, k)] = w
    for _ in range(2):
        new = {}
        for (r, k), w in wts.items():
            nb = [wts.get((r, k - 1)), w, w, wts.get((r, k + 1))]
            if slit is None:
                nb[0], nb[3] = wts.get((r, (k - 1) % cols)), wts.get((r, (k + 1) % cols))
            nb = [n for n in nb if n]
            acc = {}
            for n in nb:
                for gname, wt in n.items():
                    acc[gname] = acc.get(gname, 0.0) + wt / len(nb)
            new[(r, k)] = acc
        wts = new
    gkd = KDTree(len(cloth))
    for j, (_, _, p) in enumerate(cloth):
        gkd.insert(p, j)
    gkd.balance()
    groups = {}
    for v in me.vertices:
        _, j, _ = gkd.find(v.co)
        r, k, _ = cloth[j]
        for gname, wt in wts[(r, k)].items():
            if wt > 0.001:
                if gname not in groups:
                    groups[gname] = ob.vertex_groups.new(name=gname)
                groups[gname].add([v.index], wt, "REPLACE")
    ob.parent = arm
    ob.modifiers.new("Armature", "ARMATURE").object = arm
    return ob


def _plaid(name, sett, reps, size=512):
    """A woven tartan texture (assets/textures/eco/<name>.png): `sett` is its
    stripes ((sRGB colour, width), ...), repeated `reps` (round, down) times;
    the warp and weft cross in a twill, so where two stripes meet the colour
    alternates along diagonals like real cloth."""
    widths = np.array([w for _, w in sett], np.float32)
    edges = np.cumsum(widths) / widths.sum()
    cols = np.array([c for c, _ in sett], np.float32)

    def stripe(t):
        return cols[np.searchsorted(edges, t % 1.0, side="right").clip(0, len(sett) - 1)]
    vv, uu = np.mgrid[0:size, 0:size] / size
    warp, weft = stripe(uu * reps[0]), stripe(vv * reps[1])
    twill = (((np.arange(size)[:, None] + np.arange(size)[None, :]) // 2) % 2).astype(np.float32)[..., None]
    col = warp * (0.35 + 0.3 * twill) + weft * (0.65 - 0.3 * twill)
    px = np.ones((size, size, 4), np.float32)
    px[..., :3] = np.clip(col, 0, 1)
    write_png(px, name)


def tartan():
    """Ophelia's violet and black tartan (base_ophelia_skirt)."""
    black, violet, plum, lilac = (0.04, 0.035, 0.05), (0.34, 0.12, 0.5), (0.16, 0.06, 0.22), (0.72, 0.62, 0.82)
    _plaid("tartan", [(black, 6), (violet, 4), (black, 1), (lilac, 0.6), (black, 1), (violet, 4), (black, 6),
                      (plum, 2.5), (black, 1.5), (plum, 2.5)], (9, 2))


def _skin_to_body(ob):
    """Skin a loose part like the nearest bit of her (weights copied off the
    nearest Body vertex), so it moves with her as one piece of cloth."""
    from mathutils.kdtree import KDTree
    body = bpy.data.objects["Body"]
    kd = KDTree(len(body.data.vertices))
    for v in body.data.vertices:
        kd.insert(v.co, v.index)
    kd.balance()
    names = {gr.index: gr.name for gr in body.vertex_groups}
    for vg in list(ob.vertex_groups):
        ob.vertex_groups.remove(vg)
    groups = {}
    for v in ob.data.vertices:
        _, i, _ = kd.find(v.co)
        for ge in body.data.vertices[i].groups:
            gname = names[ge.group]
            if gname not in groups:
                groups[gname] = ob.vertex_groups.new(name=gname)
            groups[gname].add([v.index], ge.weight, "REPLACE")


def hoodie(name, hem, mat):
    """Her oversized hoodie: long sleeves to her wrists, a round neck, hanging
    loose off her bust and shoulder blades (shell drape) down to `hem`. It keeps
    her body's UVs, so its texture is baked like hers (outfit_graph
    "skater_hoodie"); its ribbing (cuffs, hem, neck) is `mat`_edge."""
    def keep(c, n):
        ax = abs(c.x)
        if c.z > 1.18 or (c.z > 1.14 and math.hypot(c.x, c.y - 0.022) < 0.07):
            return False   # her neck
        if ax > 0.15:
            return c.z > 1.0 and ax < 0.395   # the sleeves (cuffs on whole faces: a cut leaves slivers)
        return c.z > hem - 0.02
    planes = [((0, 0, hem), (0, 0, -1))]
    ob = shell(name, keep, planes=planes, gap=0.012, thick=0.006, plate=mat, edge=mat + "_edge",
               smooth=2, smooth_edge=5, border=2, drape=True)
    bvh = _body_bvh()
    far = max((bvh.find_nearest(ob.matrix_world @ v.co)[3] or 0.0) for v in ob.data.vertices)
    top = max(v.co.z for v in ob.data.vertices)
    print("%s: furthest point %.3f m off her, top at z %.3f" % (name, far, top))
    assert top < 1.23 and far < 0.09, "hoodie has a spike"
    return ob


def hood(name, mat):
    """The hoodie's hood, down, bunched on her upper back."""
    body = bpy.data.objects["Body"]
    co = np.array([v.co[:] for v in body.data.vertices])
    yb = float(co[(np.abs(co[:, 0]) < 0.06) & (co[:, 2] > 1.12) & (co[:, 2] < 1.2), 1].max())
    bm = bmesh.new()
    box(bm, (0.0, yb + 0.02 + 0.024, 1.163), ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (0.15, 0.048, 0.07), 0, bevel=0.02)
    ob = rigid(name, bm, [mat], "J_Bip_C_Chest")
    _skin_to_body(ob)
    return ob


def sneakers(name, upper, sole, top=0.078, sole_h=0.024, flare=1.08):
    """Chunky sneakers cut from her boots: everything below `top`, puffed out a
    little, the bottom `sole_h` (and the padded collar) a sole in the second
    material, flared out round each foot (platforms when tall and wide)."""
    src = bpy.data.objects["Boots"]
    ob = src.copy()
    ob.data = src.data.copy()
    ob.name = ob.data.name = name
    bpy.context.scene.collection.objects.link(ob)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().z > top], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    z0 = min(v.co.z for v in bm.verts)
    for zc in (z0 + sole_h, top - 0.008):   # split the faces on the sole and collar lines, so they run straight
        bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], dist=1e-6,
                               plane_co=Vector((0, 0, zc)), plane_no=Vector((0, 0, 1)))
    bm.normal_update()
    lines = {f: f.calc_center_median().z for f in bm.faces}
    normals = {v: v.normal.copy() for v in bm.verts}
    for v, n in normals.items():
        v.co += n * 0.004
    for side in (1, -1):
        mine = [v for v in bm.verts if v.co.x * side > 0]
        cx = sum(v.co.x for v in mine) / len(mine)
        cy = sum(v.co.y for v in mine) / len(mine)
        z0 = min(v.co.z for v in mine)
        for v in mine:
            k = 1.0 + (flare - 1.0) * (1.0 - smooth(z0 + sole_h * 0.6, z0 + sole_h * 1.2, v.co.z))
            v.co.x = cx + (v.co.x - cx) * k
            v.co.y = cy + (v.co.y - cy) * k
    bm.normal_update()
    for f, cz in lines.items():
        f.material_index = 1 if cz < z0 + sole_h or cz > top - 0.008 else 0
    ob.data.materials.clear()
    _armor_mats(ob.data, [upper, sole])
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()
    return ob


def warmers(name, top, mat):
    """Slouchy leg warmers from her ankles (over her sneakers' collars) up to
    `top`, bunched in soft rolls."""
    def keep(c, n):   # whole faces, rounded (a cut leaves slivers along the edge)
        return 0.086 < c.z < top and abs(c.x) > 0.01
    ob = shell(name, keep, gap=0.013, thick=0.007, plate=mat, edge=mat + "_edge", smooth=2, smooth_edge=3, border=1)
    normals = [v.normal.copy() for v in ob.data.vertices]
    for v, n in zip(ob.data.vertices, normals):
        v.co += n * 0.0028 * (0.5 + 0.5 * math.sin(v.co.z * 2 * math.pi / 0.028))
    ob.data.update()
    return ob


def buns(name):
    """Space buns on top of her head, tied with teal bands."""
    dg = bpy.context.evaluated_depsgraph_get()
    hb = BVHTree.FromObject(bpy.data.objects["Hair"], dg)
    bm = bmesh.new()
    for sd in (1, -1):
        hit, n = surface(hb, (0.062 * sd, 0.035, 1.7), (0, 0, -1))
        if hit is None:
            hit, n = Vector((0.062 * sd, 0.035, 1.4)), Vector((0.4 * sd, 0, 1)).normalized()
        n = (Vector(n) + Vector((0, 0, 0.6))).normalized()
        c = hit + n * 0.02
        before = set(bm.faces)
        bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=0.03, matrix=Matrix.Translation(c))
        for f in set(bm.faces) - before:
            f.material_index = 0
            f.smooth = True
        torus(bm, hit + n * 0.003, n, 0.022, 0.0035, 1)
    return rigid(name, bm, ["eco_v_bun", "eco_v_hair_tie"], "J_Bip_C_Head")


def clips(name):
    """Snap clips in her fringe: two on her left, one on her right."""
    dg = bpy.context.evaluated_depsgraph_get()
    hb = BVHTree.FromObject(bpy.data.objects["Hair"], dg)
    bm = bmesh.new()
    for px, pz, tilt, mat in ((0.045, 1.38, 30, 0), (0.058, 1.36, 30, 1), (-0.05, 1.372, -30, 0)):
        hit, n = surface(hb, (px, -0.3, pz), (0, 1, 0))
        if hit is None:
            continue
        sx, ny, uz = frame_at(hit, n)
        t = math.radians(tilt)
        sx, uz = sx * math.cos(t) + uz * math.sin(t), uz * math.cos(t) - sx * math.sin(t)
        box(bm, hit + ny * 0.003, (sx, ny, uz), (0.022, 0.004, 0.006), mat, bevel=0.0015)
    return rigid(name, bm, ["eco_v_clip_pink", "eco_v_hair_tie"], "J_Bip_C_Head")


def _cargo(name, size=512):
    """Her cargo mini's texture (assets/textures/eco/<name>.png), u round her
    from her left side toward her back, v up from the hem: khaki twill, a
    waistband with belt loops, a fly at the front, a flapped pocket on each
    side, stitching along the hem."""
    vv, uu = np.mgrid[0:size, 0:size] / size
    base = np.array((0.57, 0.51, 0.38), np.float32)
    twill = ((((np.arange(size)[:, None] + np.arange(size)[None, :]) // 2) % 2) * 0.04 - 0.02).astype(np.float32)
    col = np.broadcast_to(base, (size, size, 3)) + twill[..., None]
    dark = np.array((0.42, 0.37, 0.26), np.float32)
    stitch = np.array((0.78, 0.72, 0.55), np.float32)
    ink = np.array((0.12, 0.1, 0.07), np.float32)

    def du(c):   # distance round her from u = c
        return np.abs((uu - c + 0.5) % 1.0 - 0.5)
    band = vv > 0.88
    col[band] = dark
    col[(np.abs(vv - 0.88) < 0.006)] = ink
    for c in np.arange(0.0, 1.0, 0.125):   # belt loops
        col[band & (du(c + 0.0625) < 0.012)] = base
    col[(du(0.75) < 0.003) & (vv > 0.45)] = ink                              # the fly
    col[(np.abs(du(0.75) - 0.02) < 0.0025) & (vv > 0.5) & (vv < 0.86) & ((vv * 80) % 1 < 0.6)] = stitch
    for c in (0.0, 0.5):   # side pockets with flaps
        pk = (du(c) < 0.05) & (vv > 0.22) & (vv < 0.68)
        col[pk] = col[pk] * 0.93
        edge = pk & ((du(c) > 0.045) | (vv < 0.23))
        col[edge] = ink
        flap = (du(c) < 0.055) & (vv > 0.6) & (vv < 0.7)
        col[flap] = dark
        col[flap & ((du(c) > 0.05) | (vv < 0.605))] = ink
        col[(du(c) < 0.006) & (np.abs(vv - 0.63) < 0.012)] = np.array((0.75, 0.75, 0.78), np.float32)   # its snap
    col[(np.abs(vv - 0.04) < 0.003) & ((uu * 160) % 1 < 0.6)] = stitch       # hem stitching
    px = np.ones((size, size, 4), np.float32)
    px[..., :3] = np.clip(col, 0, 1)
    write_png(px, name)


def outfit_pieces():
    """The clothes' loose parts (outfit_<outfit>_<t|m|any>_*, shown by
    eco_model.gd in that outfit at that rating, or at any):
      skater  her oversized mustard hoodie (Mature: cropped high under her
              bust), its hood down on her back, chunky sneakers, space buns
      y2k     her khaki cargo mini (Mature: micro), lilac leg warmers (Mature:
              up her thighs), white platform sneakers, snap clips in her fringe
      date    her black leather moto jacket (Mature: only its left half, slipped
              off her right shoulder), her red leather micro skirt (Mature), small
              steel hoops"""
    out = []
    out.append(hoodie("outfit_skater_t_hoodie", 0.955, "eco_v_hoodie_skater"))
    out.append(hoodie("outfit_skater_m_hoodie", 1.0, "eco_v_hoodie_skater"))
    out.append(hood("outfit_skater_any_hood", "eco_v_hoodie_skater_hood"))
    out.append(sneakers("outfit_skater_any_shoes", "eco_v_sneaker_skater", "eco_v_sneaker_skater_sole"))
    out.append(buns("outfit_skater_any_buns"))
    _cargo("cargo")
    out.append(skirt("outfit_y2k_t_skirt", 0.875, 0.645, ["eco_v_cargo"], gap=0.006, flare=0.02, follow=(0.8, 0.97), rows=10))
    # Mature: as short as it goes, low on her hips: its front hem right at her
    # crotch line (any higher and the briefs under it show their shape), the
    # back riding up to just under her glute fold (z 0.733)
    out.append(skirt("outfit_y2k_m_skirt", 0.835, 0.69, ["eco_v_cargo"], gap=0.005, flare=0.006, follow=(0.85, 0.97), rows=10,
                     back_hem=0.725))
    out.append(warmers("outfit_y2k_t_warmers", 0.42, "eco_v_warmers"))
    out.append(warmers("outfit_y2k_m_warmers", 0.6, "eco_v_warmers"))
    out.append(sneakers("outfit_y2k_any_shoes", "eco_v_sneaker_y2k", "eco_v_sneaker_y2k_sole", sole_h=0.04, flare=1.14))
    out.append(clips("outfit_y2k_any_clips"))
    # date: her black leather moto jacket (Mature: slipped off her right
    # shoulder, only its left half on), her red leather micro skirt
    out.append(base_jacket("cropped", "outfit_date_t_jacket", "eco_v_jacket_date", cuff=0.37, pick_cuff=True))
    out.append(base_jacket("half", "outfit_date_m_jacket", "eco_v_jacket_date", cuff=0.37, pick_cuff=True))
    out.append(skirt("outfit_date_m_skirt", 0.876, 0.69, ["eco_v_leather_red", "eco_v_jacket_date"], gap=0.005, flare=0.005,
                     trim=True, follow=(0.85, 0.97), rows=10))
    face = bpy.data.objects["Face"]
    bm = bmesh.new()
    for sd in (1, -1):
        lobe = [v.co for v in face.data.vertices if v.co.x * sd > 0.066 and abs(v.co.y - 0.012) < 0.022 and 1.25 < v.co.z < 1.3]
        p = min(lobe, key=lambda c: c.z) if lobe else Vector((0.076 * sd, 0.01, 1.268))
        torus(bm, p + Vector((0.002 * sd, 0, -0.011)), (1, 0, 0), 0.008, 0.0016, 0, segs=(20, 6))
    out.append(rigid("outfit_date_any_hoops", bm, ["eco_v_steel"], "J_Bip_C_Head"))
    print("outfit pieces: %d" % len(out))
    return out


def outfit_graph(nt, skin, kind):
    """Her clothes off duty, painted on per pixel from the rest position like the
    suit (see suit_graph for the landmarks). Each garment is a signed distance
    (positive = covered) laid over the last, with an ink line round its edge.
    Two versions of each, for the content rating:
      skater_t  skater brat: black bike shorts to mid-thigh with a teal side
                stripe, white knee socks striped red and teal (her mustard
                hoodie, outfit_skater_t_hoodie, painted under it)
      skater_m  the hoodie cropped high under her bust (outfit_skater_m_hoodie,
                well over where she is fullest), tiny low-rise bike shorts,
                cheeky at the back, striped thigh-high socks
      skater_hoodie  not a look: the hoodie's own texture, a kangaroo pocket,
                drawstrings and a chibi titan she drew in marker on the back
      y2k_t     y2k pop: a fitted baby pink tee, cap sleeves, a ringer trim and a
                glittering silver star, cropped above her navel; a belly-button
                ring; khaki under her cargo mini (outfit_y2k_t_skirt)
      y2k_m     a glittering pink tube top (always well over where she is
                fullest), the shortest micro cargo skirt (outfit_y2k_m_skirt)
                low on her hips, riding up at the back; under it tiny low-rise pink briefs, cheeky at
                the back, flat and opaque at the crotch, and fishnet tights
                over them down into her leg warmers
      date_t    Eco dressed up her way: a black leather corset with a sweetheart
                top, teal glowing lacing up the front and teal piping; rust-red
                leather trousers to her waist, laced up the outer leg over
                fishnet; a cropped black moto jacket (outfit_date_t_jacket)
      date_m    the corset cropped and cut low; a red leather micro skirt
                (outfit_date_m_skirt); a harness strap from a steel ring at her
                navel to her hips; fishnet thigh-highs on garter straps; the
                jacket worn off one shoulder (outfit_date_m_jacket)
    Both: her own chain-and-hex-bolt belt, Dad's dog tag on a choker, fingerless
    gloves, her boots laced up, steel hoop earrings (outfit_date_any_hoops).
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

    # the preset's skin texture still has white stockings and gold bands on her
    # lower legs (the suit always covered them): bare legs get plain skin
    state = {"col": g.mixc(skin, LEG_SKIN, g.sub(1.0, g.sstep(0.585, 0.6, z))), "ink": 0.0, "cover": 0.0, "gloss": 0.0, "glow": 0.0}

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

    def ell(px, cx, cz, rx, rz):   # an ellipse on px (x, or ax for a pair) and z
        q = g.sqrt(g.add(g.sq(g.div(g.sub(px, cx), rx)), g.sq(g.div(g.sub(z, cz), rz))))
        return g.mul(g.sub(1.0, q), min(rx, rz))

    def rect(px, cx, cz, hw, hh):
        return g.mn(g.sub(hw, g.abs(g.sub(px, cx))), g.sub(hh, g.abs(g.sub(z, cz))))

    def heart(cx, cz, s):
        lobes = g.mx(ell(x, cx - 0.45 * s, cz + 0.25 * s, 0.5 * s, 0.5 * s), ell(x, cx + 0.45 * s, cz + 0.25 * s, 0.5 * s, 0.5 * s))
        tip = g.mn(g.mul(g.sub(g.sub(z, cz - 0.95 * s), g.mul(1.05, g.abs(g.sub(x, cx)))), 0.6), g.sub(cz + 0.3 * s, z))
        return g.mx(lobes, tip)

    def glitter():
        h = g.op("FRACT", g.mul(g.op("SINE", g.add(g.add(g.mul(x, 1271.3), g.mul(z, 3117.7)), g.mul(y, 911.1))), 43758.5))
        return g.sstep(0.86, 0.95, h)

    if kind == "skater_hoodie":
        # the hoodie's own texture (outfit_skater_*_hoodie keep her body's UVs):
        # mustard all over, a kangaroo pocket and drawstrings at the front, and
        # on the back a titan she drew in marker, chibi, one big teal eye
        paint(1.0, HOODIE)
        back = g.sstep(0.0, 0.03, y)
        # a titan in marker: a small head with one big eye, huge shoulder pads, a
        # chest core, long arms to big fists, thick legs planted wide, an antenna
        parts = [rect(x, 0.0, 1.128, 0.018, 0.014),                       # head
                 rect(x, 0.0, 1.075, 0.034, 0.036),                       # torso
                 rect(ax, 0.05, 1.108, 0.024, 0.014),                     # shoulder pads
                 rect(ax, 0.06, 1.06, 0.01, 0.034),                       # arms
                 ell(ax, 0.062, 1.018, 0.015, 0.013),                     # fists
                 rect(ax, 0.02, 1.022, 0.011, 0.018),                     # legs
                 rect(ax, 0.026, 1.0, 0.017, 0.006),                      # feet
                 rect(x, 0.012, 1.152, 0.0012, 0.012)]                    # antenna
        d_t = parts[0]
        for d_ in parts[1:]:
            d_t = g.mx(d_t, d_)
        paint(g.mul(g.sstep(-AA, AA, d_t), back), HOODIE_DARK)
        eye = ell(x, 0.0, 1.128, 0.012, 0.006)
        paint(g.mul(g.sstep(-AA, AA, eye), back), TRIM)                                       # its eye
        core = ell(x, 0.0, 1.078, 0.009, 0.009)
        paint(g.mul(g.sstep(-AA, AA, core), back), SOCK_RED)                                  # its core
        lines = g.band(d_t, -0.0022, 0.0)
        for d_ in parts[1:4]:   # the seams where its parts meet, drawn over
            lines = g.mx(lines, g.band(d_, -0.0011, 0.0011))
        lines = g.mx(lines, g.mx(g.band(eye, -0.0014, 0.0), g.band(core, -0.0014, 0.0)))
        lines = g.mx(lines, g.mul(g.band(g.sub(z, g.add(0.99, g.mul(0.003, g.op("SINE", g.mul(x, 300.0))))), -0.001, 0.001),
                                  g.sub(1.0, g.sstep(0.07, 0.08, ax))))                     # the ground, a scribble
        d_h = heart(0.082, 1.14, 0.011)
        paint(g.mul(g.sstep(-AA, AA, d_h), back), SOCK_RED)
        lines = g.mx(lines, g.band(d_h, -0.0016, 0.0))
        state["ink"] = g.mx(state["ink"], g.mul(lines, back))
        # the kangaroo pocket (above the cropped hoodie's hem) and its drawstrings
        d_p = g.mn(g.mn(g.sub(z, 0.962), g.sub(0.995, z)), g.sub(g.sub(0.075, g.mul(0.5, g.sub(z, 0.962))), ax))
        paint(g.mul(g.sstep(-AA, AA, d_p), front), HOODIE_DARK)
        state["ink"] = g.mx(state["ink"], g.mul(g.band(d_p, -0.0008, 0.0), front))
        d_s = g.mn(g.sub(0.0022, g.abs(g.sub(ax, 0.02))), g.mn(g.sub(z, 1.11), g.sub(1.178, z)))
        wear(g.mn(d_s, g.mul(g.sub(front, 0.5), 0.02)), CREAM)
        wear(g.mn(g.sub(0.0028, g.abs(g.sub(ax, 0.02))), g.mn(g.sub(z, 1.104), g.sub(1.114, z))), STEEL)
        # a little teal heart on the front of her left sleeve
        paint(g.mul(g.mul(g.sstep(-AA, AA, heart(0.27, 1.145, 0.009)), g.sstep(0.0, 0.01, x)), g.sub(1.0, g.sstep(-0.02, -0.01, y))), TEE_PRINT)
    elif kind.startswith("skater"):
        # skater brat: her mustard hoodie (outfit_skater_*_hoodie, Mature
        # cropped high under her bust), black bike shorts with a teal stripe,
        # striped socks, chunky sneakers, her hair up in space buns
        wear(g.sub(0.17, z), SOCK_WHITE, ink=False)   # under her sneakers
        hem = 1.0 if mature else 0.955
        # under the hoodie (seen only past its edges): the hoodie's own colour
        wear(g.mn(g.mn(g.sub(z, hem + 0.004), g.sub(0.39, ax)), g.sub(1.17, z)), HOODIE_DARK, ink=False)
        if mature:   # tiny low-rise bike shorts, cheeky at the back, always covered between her legs
            zt = g.sub(0.866, g.mul(0.35, g.sq(ax)))
            zl = g.lerp(g.add(0.68, g.mul(0.9, g.mx(g.sub(ax, 0.03), 0.0))), g.add(0.70, g.mul(0.62, ax)), tb)
        else:        # high-waisted, to the middle of her thighs
            zt, zl = 0.935, 0.6
        c_s = wear(g.mn(g.sub(zt, z), g.sub(z, zl)), SHORTS)
        side = g.mul(g.sstep(-AA, AA, g.sub(0.0035, g.abs(g.add(y, 0.005)))), g.sstep(0.07, 0.075, ax))
        paint(g.mul(g.mx(side, g.band(g.sub(zt, z), 0.003, 0.0055)), c_s), TEE_PRINT)
        top = 0.6 if mature else 0.45   # (Mature: thigh-highs)
        c_so = wear(g.sub(top, z), SOCK_WHITE)
        stripes = g.mx(g.band(z, top - 0.026, top - 0.018), g.band(z, top - 0.05, top - 0.042))
        paint(g.mul(g.band(z, top - 0.038, top - 0.03), c_so), TEE_PRINT)
        paint(g.mul(stripes, c_so), SOCK_RED)
    elif kind.startswith("y2k"):
        # y2k pop: a glittery baby pink top (Teen: a baby tee with a ringer trim
        # and a silver star; Mature: a tube top), her khaki cargo mini
        # (outfit_y2k_*_skirt; Mature: micro), lilac leg warmers (Mature: to
        # her thighs), platform sneakers, a belly-button ring, hair clips
        wear(g.sub(0.12, z), SOCK_WHITE, ink=False)   # under her platforms
        if mature:   # a tube top: well over where she is fullest (apex z 1.047), her shoulders bare
            d_top = g.mn(g.mn(g.sub(g.lerp(1.095, 1.075, tb), z), g.sub(z, g.lerp(0.99, 1.0, tb))), g.sub(0.16, ax))
        else:        # a fitted baby tee, cap sleeves, cropped just above her navel
            zn = g.lerp(g.sub(1.165, g.mul(1.5, g.sq(ax))), 1.178, tb)
            d_neck = g.mx(g.sub(zn, z), g.sub(ax, 0.072))   # the scoop round her neck, her shoulders covered
            d_top = g.mn(g.mn(d_neck, g.sub(z, 0.94)), g.sub(0.21, ax))
        c = wear(d_top, PINK)
        rim = g.mul(g.band(d_top, 0.0008, 0.0045), c)
        paint(rim, CREAM if not mature else STEEL)
        sparkle = g.mul(glitter(), c)
        if not mature:   # a silver star on her chest, glittering
            r = g.sqrt(g.add(g.sq(x), g.sq(g.sub(z, 1.112))))
            ang = g.op("ARCTAN2", x, g.sub(z, 1.112))
            d_star = g.sub(g.mul(0.017, g.add(0.62, g.mul(0.38, g.op("COSINE", g.mul(ang, 5.0))))), r)
            c_star = g.mul(g.sstep(-AA, AA, d_star), front)
            paint(c_star, STEEL)
            state["ink"] = g.mx(state["ink"], g.mul(g.band(d_star, -0.0008, 0.0), front))
            sparkle = g.mx(g.mul(sparkle, 0.4), g.mul(glitter(), c_star))
        else:
            sparkle = g.mx(g.mul(sparkle, 0.4), g.mul(g.mul(glitter(), rim), 2.0))
        state["glow"] = g.mx(state["glow"], g.mul(sparkle, 0.8))
        # under her skirt: the same khaki (never skin below its hem)
        if mature:
            # tiny low-rise briefs: a narrow strip over her hips, cut high over
            # her legs, cheeky at the back; always full and opaque between her
            # legs (flat colour, nothing drawn there), then fishnet tights over all
            zt = g.sub(0.826, g.mul(0.3, g.sq(ax)))
            zl = g.lerp(g.add(0.688, g.mul(1.5, g.mx(g.sub(ax, 0.022), 0.0))), g.add(0.70, g.mul(0.95, ax)), tb)   # (covers the agreed limit zones)
            wear(g.mn(g.sub(zt, z), g.sub(z, zl)), PINK)
            d_ft = g.mn(g.sub(z, 0.585), g.sub(0.834, z))
            net = g.mx(g.band(g.op("FRACT", g.div(g.add(x, z), 0.0062)), 0.0, 0.18), g.band(g.op("FRACT", g.div(g.sub(x, z), 0.0062)), 0.0, 0.18))
            c_ft = g.sstep(-AA, AA, d_ft)
            paint(g.mul(c_ft, 0.3), SHORTS)
            paint(g.mul(c_ft, net), SHORTS)
            wear(g.mn(g.sub(z, 0.826), g.sub(0.834, z)), SHORTS)   # the tights' waistband, just under the skirt
        else:   # khaki shorts under her skirt (never skin below its hem)
            wear(g.mn(g.sub(z, 0.62), g.sub(0.872, z)), KHAKI, ink=False)
        # her belly-button ring, a teal gem
        ring = ell(x, 0.0, 0.896, 0.0032, 0.0032)
        paint(g.mul(g.band(ring, -0.001, 0.0), front), STEEL)
        gem = g.mul(g.sstep(-AA, AA, ell(x, 0.0, 0.89, 0.0025, 0.0025)), front)
        paint(gem, TRIM)
        state["glow"] = g.mx(state["glow"], gem)
    elif kind.startswith("date"):
        # Eco dressed up her way: a black corset top laced up the front in her
        # teal, piped in glowing teal; rust-red leather (Teen: high-waisted
        # trousers laced up the outside of each leg over fishnet; Mature: the
        # micro skirt, outfit_date_m_skirt), a belt of chain links and hex bolts
        # she made, Dad's dog tag on a choker, fingerless gloves, her boots
        # laced up (and her leather jacket over it all, outfit_date_*_jacket).
        # Mature: the corset cropped above her navel and cut lower, a harness
        # strap across her bare waist from a steel ring, fishnet thigh-highs on
        # garter straps
        wear(g.sub(0.17, z), GEAR, ink=False)   # under her boots
        dip = g.op("EXPONENT", g.neg(g.sq(g.div(ax, 0.013))))
        if mature:
            top = g.lerp(g.sub(g.sub(1.08, g.mul(2.2, g.sq(g.sub(ax, 0.06)))), g.mul(0.03, dip)), 1.04, tb)
            bot = g.sub(0.975, g.mul(0.02, g.op("EXPONENT", g.neg(g.sq(g.div(ax, 0.03))))))
        else:
            top = g.lerp(g.sub(g.sub(1.1, g.mul(2.2, g.sq(g.sub(ax, 0.06)))), g.mul(0.014, dip)), 1.1, tb)
            bot = 0.9
        d_cor = g.mn(g.mn(g.sub(top, z), g.sub(z, bot)), g.sub(0.16, ax))
        c = wear(d_cor, CORSET)
        bone = g.mul(g.mul(g.band(g.op("FRACT", g.div(ax, 0.032)), 0.0, 0.06), c), 0.7)
        paint(bone, (0.035, 0.035, 0.04))                                                      # boning
        lace = g.mx(g.band(g.op("FRACT", g.div(g.add(z, ax), 0.011)), 0.0, 0.2), g.band(g.op("FRACT", g.div(g.sub(z, ax), 0.011)), 0.0, 0.2))
        lace = g.mul(g.mul(g.mul(lace, g.sstep(-AA, AA, g.sub(0.011, ax))), front), c)
        paint(lace, TRIM)
        pipe = g.mul(g.band(d_cor, 0.0009, 0.0024), c)
        paint(pipe, TRIM)
        state["glow"] = g.mx(state["glow"], g.mx(pipe, g.mul(lace, 0.6)))
        if mature:
            # the micro skirt's leather under it (never below its hem), a chain belt above it
            wear(g.mn(g.sub(z, 0.7), g.sub(0.876, z)), LEATHER_RED, ink=False)
            zb = 0.884
            # the harness: a strap round her waist and two down to her hips from a steel ring
            ring = g.sqrt(g.add(g.sq(g.div(x, 0.0075)), g.sq(g.div(g.sub(z, 0.912), 0.0075))))
            d_h = g.mn(g.sub(0.0025, g.abs(g.sub(z, g.sub(0.912, g.mul(0.36, ax))))), g.sub(0.1, ax))
            d_h = g.mx(g.mul(d_h, 1.0), g.mn(g.sub(z, 0.935), g.sub(0.941, z)))
            wear(g.mn(d_h, g.mul(g.sub(front, 0.5), 0.02)), CORSET)
            wear(g.mn(g.sub(z, 0.935), g.sub(0.941, z)), CORSET)
            paint(g.mul(g.band(ring, 0.65, 1.0), front), STEEL)
            # fishnet thigh-highs on garter straps up under the skirt
            d_st = g.mn(g.sub(z, 0.17), g.sub(0.6, z))
            c_st = g.sstep(-AA, AA, d_st)
            net = g.mx(g.band(g.op("FRACT", g.div(g.add(x, z), 0.0062)), 0.0, 0.18), g.band(g.op("FRACT", g.div(g.sub(x, z), 0.0062)), 0.0, 0.18))
            paint(g.mul(c_st, 0.35), CORSET)
            paint(g.mul(c_st, net), CORSET)
            wear(g.mn(g.sub(z, 0.582), g.sub(0.6, z)), CORSET)
            for gx in (0.05, 0.105):
                wear(g.mn(g.mn(g.sub(0.0028, g.abs(g.sub(ax, gx))), g.sub(z, 0.6)), g.sub(0.71, z)), CORSET)
        else:
            # high-waisted red leather trousers, laced up the outside of each leg over fishnet
            d_tr = g.mn(g.sub(0.935, z), g.sub(z, 0.17))
            win = g.mn(g.mn(g.sub(0.011, g.abs(g.add(y, 0.005))), g.sub(ax, 0.085)), g.mn(g.sub(z, 0.3), g.sub(0.86, z)))
            c_t = wear(g.mn(d_tr, g.neg(win)), LEATHER_RED)
            c_w = g.sstep(-AA, AA, win)
            net = g.mx(g.band(g.op("FRACT", g.div(g.add(y, z), 0.0055)), 0.0, 0.18), g.band(g.op("FRACT", g.div(g.sub(y, z), 0.0055)), 0.0, 0.18))
            paint(g.mul(c_w, net), CORSET)
            laces = g.mx(g.band(g.op("FRACT", g.div(g.add(z, g.mul(2.0, g.add(y, 0.005))), 0.016)), 0.0, 0.12),
                         g.band(g.op("FRACT", g.div(g.sub(z, g.mul(2.0, g.add(y, 0.005))), 0.016)), 0.0, 0.12))
            paint(g.mul(laces, c_w), CORSET)
            zb = 0.926
        # her belt: a black strap studded with steel hex bolts, steel-edged
        d_belt = g.mn(g.sub(z, zb - 0.008), g.sub(zb + 0.008, z))
        c_b = wear(d_belt, CORSET)
        paint(g.mul(g.band(d_belt, 0.0006, 0.0018), c_b), STEEL)
        u = g.op("FRACT", g.div(g.add(x, g.mul(y, 0.8)), 0.022))
        hexd = g.mx(g.abs(g.mul(g.sub(u, 0.5), 0.022)), g.mul(g.abs(g.sub(z, zb)), 1.15))
        bolt = g.mul(g.sub(1.0, g.sstep(0.0036, 0.0042, hexd)), c_b)
        paint(bolt, STEEL)
        paint(g.mul(g.mul(bolt, g.sub(1.0, g.sstep(0.0012, 0.0016, hexd))), 0.8), (0.08, 0.08, 0.09))   # its socket
        # Dad's dog tag on a choker, fingerless gloves
        wear(g.mn(g.sub(z, 1.183), g.sub(1.195, z)), CORSET)
        chain = g.mn(g.sub(0.0008, g.abs(g.sub(ax, g.mul(0.35, g.sub(1.184, z))))), g.mn(g.sub(z, 1.168), g.sub(1.184, z)))
        wear(g.mn(chain, g.mul(g.sub(front, 0.5), 0.02)), STEEL, ink=False)
        tag = g.mn(g.sub(0.0085, ax), g.mn(g.sub(z, 1.142), g.sub(1.17, z)))
        c_tag = wear(g.mn(tag, g.mul(g.sub(front, 0.5), 0.02)), (0.1, 0.1, 0.115))       # dark gunmetal, so it reads on her skin
        paint(g.mul(g.band(tag, 0.0004, 0.0014), c_tag), STEEL)
        state["glow"] = g.mx(state["glow"], g.mul(g.mul(g.band(z, 1.152, 1.156), g.band(ax, 0.0, 0.005)), c_tag))   # its stamped line, glowing
        wear(g.mn(g.sub(ax, 0.39), g.sub(0.475, ax)), CORSET)   # fingerless gloves to her knuckles
        paint(g.band(ax, 0.39, 0.397), TRIM)   # their teal cuffs
    col = g.mixc(state["col"], INK, state["ink"])
    col = g.mixc(col, OUTFIT_GLOW, state["glow"])
    return col, state["glow"], state["cover"], state["ink"], 0.0, state["gloss"]


def bake_body(body, skin_img, cut="base"):
    """Bake the suit into four textures: albedo, glow (teal trims), a mask
    (red: where a thin sheen may show, green: suit or skin) and a normal map.
    The suit's styles other than gwen (STYLE_NAME) are v_body*_<style>.png and
    share gwen's normal map; her clothes (`cut` in BAKES) are v_body*_<cut>.png."""
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
    if cut in BAKES:
        col, trim, cover, ink, gear, gloss = outfit_graph(nt, t.outputs["Color"], cut)
    else:
        col, trim, cover, ink, gear, gloss = suit_graph(nt, t.outputs["Color"])
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
        if cut not in OUTFITS and cut in BAKES and name != "v_body":
            continue   # a garment's own texture: colour only
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
        return results   # her clothes have no cling normal map; the other styles share gwen's
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


# --- suit kits: what each weight changes on the suit itself ----------------------------

KITS = ("light", "medium", "heavy")
KIT_GLOSS = (0.006, 0.006, 0.008)   # light: glossy black compression bands and boots
KIT_BROWN = (0.1, 0.045, 0.018)     # medium: work boots
KIT_SOCK = (0.45, 0.4, 0.3)
KIT_GREASE = (0.05, 0.045, 0.04)
KIT_PAD = (0.04, 0.045, 0.055)      # heavy: quilted padding
KIT_MAG = (0.07, 0.075, 0.09)       # heavy: mag boots


def kit_graph(nt, skin, weight):
    """What a suit weight (armory.gd SUIT_WEIGHTS) changes on the suit itself,
    painted over whichever style she wears (eco_model.gd body_material lays it
    over her style's bodysuit once she has a suit tier):
      light   the collar cut away to bare her neck; a window over her stomach,
              between her ribs and her belly button and well clear of her chest,
              piped in teal; glossy black compression bands round her thighs and
              upper arms; tight, glossy knee-high boots with a crimson top
      medium  the right sleeve torn off at the shoulder, a grease smear on that
              forearm; brown work boots laced up the front over a rolled sock; a
              mustard canvas patch on her left thigh, a teal one on her left arm
      heavy   quilted padding over her shoulders, down her sides and round her
              knees, a thick padded collar; gunmetal mag boots to mid-shin with a
              glowing coil round each ankle
    Returns (colour, sheen, suit shade, cover, glow colour) sockets: cover is
    how much of the kit shows over the style, shade 0 where it bares her skin."""
    g = NG(nt)
    at = nt.nodes.new("ShaderNodeAttribute")
    at.attribute_name = "rest"
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(at.outputs["Vector"], sep.inputs[0])
    x, y, z = sep.outputs[0], sep.outputs[1], sep.outputs[2]
    ax = g.abs(x)
    front = g.sub(1.0, g.sstep(-0.045, -0.025, y))
    AA = 0.00045
    out = {"col": skin, "sheen": 0.0, "shade": 1.0, "cover": 0.0, "glow": (0, 0, 0, 1)}

    def put(region, colour, sheen=0.0, shade=1.0, glow=(0, 0, 0)):
        out["col"] = g.mixc(out["col"], colour, region)
        out["sheen"] = g.lerp(out["sheen"], sheen, region)
        out["shade"] = g.lerp(out["shade"], shade, region)
        out["cover"] = g.mx(out["cover"], region) if not isinstance(out["cover"], float) else g.mul(region, 1.0)
        out["glow"] = g.mixc(out["glow"], glow, region)

    def inside(d):   # inside a signed distance
        return g.sstep(-AA, AA, d)

    def ink(d, lo=-0.0004, hi=0.0006):
        put(g.band(d, lo, hi), INK)

    def lines(v, step, width=0.12):
        f = g.op("FRACT", g.div(v, step))
        return g.mx(g.sub(1.0, g.sstep(0.0, width, f)), g.sstep(1.0 - width, 1.0, f))

    legs = g.sub(1.0, g.sstep(0.6, 0.62, z))       # nothing above her thighs (her hands are at z 1.145)
    if weight == "light":
        # the collar cut away: bare neck down to a crew line
        r = g.sqrt(g.add(g.sq(x), g.sq(g.sub(y, 0.022))))
        d_neck = g.mn(g.sub(z, 1.162), g.sub(0.074, r))
        put(inside(d_neck), skin, shade=0.0)
        put(g.mul(g.band(z, 1.162, 1.1645), inside(g.sub(0.074, r))), INK)
        # a window over her stomach, piped in teal (the belt is slung below it)
        q = g.sqrt(g.add(g.sq(g.div(ax, 0.046)), g.sq(g.div(g.sub(z, 0.93), 0.054))))
        d_win = g.mul(g.sub(1.0, q), 0.045)
        win = g.mul(inside(d_win), front)
        put(win, skin, shade=0.0)
        put(g.mul(g.band(d_win, -0.0028, -0.0012), front), TRIM, glow=TRIM)
        put(g.mul(g.band(d_win, -0.0012, 0.0), front), INK)
        # glossy compression bands round her thighs and upper arms
        d_thigh = g.mn(g.sub(z, 0.55), g.sub(0.655, z))
        put(inside(d_thigh), KIT_GLOSS, sheen=1.0)
        d_arm = g.mn(g.mn(g.sub(ax, 0.19), g.sub(0.262, ax)), g.sub(z, 1.0))
        put(inside(d_arm), KIT_GLOSS, sheen=1.0)
        for d in (d_thigh, d_arm):
            ink(d)
        # knee-high boots, peaked a little over the front of each knee, a crimson band round the top
        peak = g.mul(g.op("EXPONENT", g.neg(g.sq(g.div(g.sub(ax, 0.069), 0.02)))), front)
        zb = g.add(0.462, g.mul(0.02, peak))
        d_boot = g.sub(zb, z)
        put(g.mul(inside(d_boot), legs), KIT_GLOSS, sheen=1.0)
        put(g.mul(g.band(d_boot, 0.0, 0.011), legs), LEATHER_RED, sheen=0.4)
        ink(g.sub(d_boot, 0.011), -0.0003, 0.0005)
        ink(d_boot)
    elif weight == "medium":
        # the right sleeve torn off at the shoulder, a ragged edge round her arm
        ang = g.op("ARCTAN2", g.sub(y, 0.022), g.sub(z, 1.145))
        rag = g.mul(g.abs(g.sub(g.op("FRACT", g.mul(ang, 7.0 / (2 * math.pi))), 0.5)), 0.014)
        d_torn = g.mn(g.mn(g.sub(ax, g.add(0.178, rag)), g.sub(0.4, ax)), g.neg(x))
        d_torn = g.mn(d_torn, g.sub(z, 1.0))
        put(inside(d_torn), skin, shade=0.0)
        right_arm = g.mul(g.sstep(0.0, 0.004, g.neg(x)), g.sstep(1.0, 1.01, z))
        put(g.mul(g.band(g.sub(g.add(0.178, rag), ax), 0.0, 0.0012), right_arm), INK)
        # and a smear of grease along that forearm
        smear = g.sqrt(g.add(g.sq(g.div(g.sub(ax, 0.33), 0.035)), g.sq(g.div(g.sub(z, 1.17), 0.012))))
        put(g.mul(g.mul(g.sub(1.0, g.sstep(0.5, 1.0, smear)), right_arm), 0.55), KIT_GREASE, shade=0.0)
        # work boots laced up the front, a rolled sock over the top
        d_boot = g.sub(0.262, z)
        put(inside(d_boot), KIT_BROWN, sheen=0.3)
        laces = g.mul(g.mul(lines(z, 0.013, 0.18), g.band(g.abs(g.sub(ax, 0.066)), 0.0, 0.011)),
                      g.sub(1.0, g.sstep(-0.03, -0.015, y)))
        put(g.mul(g.mul(laces, inside(d_boot)), g.sstep(0.19, 0.2, z)), INK)
        sock = g.band(z, 0.262, 0.282)
        put(sock, KIT_SOCK)
        put(g.mul(sock, lines(g.op("ARCTAN2", y, g.sub(ax, 0.066)), 0.12, 0.2)), g.mixc(KIT_SOCK, INK, 0.35))
        ink(d_boot)
        ink(g.sub(z, 0.282), -0.0004, 0.0004)
        # a mustard canvas patch on her left thigh, a teal one on her left upper arm, stitched on
        d_p1 = g.mn(g.mn(g.sub(0.024, g.abs(g.sub(z, 0.6))), g.sub(0.022, g.abs(g.sub(y, -0.004)))), g.sub(x, 0.085))
        d_p2 = g.mn(g.mn(g.sub(0.016, g.abs(g.sub(x, 0.212))), g.sub(0.014, g.abs(g.sub(y, 0.022)))), g.sub(z, 1.15))
        for d, c in ((d_p1, KIT_CANVAS), (d_p2, TRIM)):
            put(inside(d), c)
            put(g.mul(g.band(d, 0.002, 0.0028), lines(g.add(g.add(x, y), z), 0.004, 0.5)), INK)
            ink(d)
    else:
        # quilted padding: shoulders, down her sides, round her knees, and a thick collar
        def quilt(v):
            return lines(v, 0.026, 0.08)
        q = g.mx(quilt(g.add(x, z)), quilt(g.sub(x, z)))
        r = g.sqrt(g.add(g.sq(x), g.sq(g.sub(y, 0.022))))
        d_sh = g.mn(g.mn(g.sub(z, 1.12), g.sub(ax, 0.07)), g.sub(0.21, ax))
        d_side = g.mn(g.mn(g.sub(z, 0.88), g.sub(1.0, z)), g.mn(g.sub(ax, 0.085), g.sub(0.035, g.abs(y))))
        d_knee = g.mn(g.sub(z, 0.425), g.sub(0.535, z))
        d_col = g.mn(g.mn(g.sub(z, 1.15), g.sub(1.205, z)), g.sub(0.082, r))
        for d in (d_sh, d_side, d_knee, d_col):
            put(inside(d), KIT_PAD)
            put(g.mul(inside(d), g.mul(q, 0.7)), INK)
            ink(d)
        # mag boots to mid-shin, a glowing coil round each ankle above her boots
        d_boot = g.sub(0.3, z)
        put(inside(d_boot), KIT_MAG, sheen=0.5)
        put(g.band(z, 0.205, 0.213), TRIM, glow=TRIM)
        put(g.mul(lines(z, 0.022, 0.08), inside(g.sub(0.29, z))), INK)
        ink(d_boot)
    return out["col"], out["sheen"], out["shade"], out["cover"], out["glow"]


def bake_kit(body, skin_img, weight):
    """Bake a suit weight's changes (kit_graph) into v_kit_<weight>.png (colour),
    v_kit_<weight>_mask.png (red: sheen, green: suit shade, blue: cover) and
    v_kit_<weight>_glow.png, in her body's UVs."""
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 4
    sc.cycles.device = "CPU"
    sc.cycles.use_denoising = False
    sc.render.bake.margin = 8
    skin_slot = mat_index(body, "Body_00_SKIN") | mat_index(body, "bake_body")
    m = bpy.data.materials.new("bake_body_kit")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    uv = nt.nodes.new("ShaderNodeUVMap")
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = skin_img
    nt.links.new(uv.outputs[0], t.inputs[0])
    col, sheen, shade, cover, glow = kit_graph(nt, t.outputs["Color"], weight)
    g = NG(nt)
    comb = nt.nodes.new("ShaderNodeCombineColor")
    g.put(comb.inputs[0], sheen)
    g.put(comb.inputs[1], shade)
    g.put(comb.inputs[2], cover)
    em = nt.nodes.new("ShaderNodeEmission")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(em.outputs[0], out.inputs[0])
    for i in skin_slot:
        body.material_slots[i].material = m
    for o in bpy.data.objects:
        o.select_set(o == body)
    bpy.context.view_layer.objects.active = body
    for name, size, src in (("v_kit_%s" % weight, 2048, col), ("v_kit_%s_mask" % weight, 1024, comb.outputs[0]),
                            ("v_kit_%s_glow" % weight, 1024, glow)):
        img = bpy.data.images.new(name, size, size, alpha=False)
        img.colorspace_settings.name = "Non-Color" if name.endswith("_mask") else "sRGB"
        node = nt.nodes.new("ShaderNodeTexImage")
        node.image = img
        nt.nodes.active = node
        nt.links.new(src, em.inputs[0])
        bpy.ops.object.bake(type="EMIT")
        img.filepath_raw = os.path.join(TEX_OUT, name + ".png")
        img.file_format = "PNG"
        img.save()
        print("baked", name)


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
            for kit in KITS:
                write_png(face_texture(face, img, kit=kit), "v_face_" + kit)
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
    for kind in BAKES:
        bake_body(body, clean, kind)
    for weight in KITS:
        bake_kit(body, clean, weight)
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


def bake_styles(names):
    """Bake just these base styles' bodysuit textures (--only-styles), from the
    same cleaned skin as a full build."""
    body = bpy.data.objects["Body"]
    skin_m = body.data.materials[next(iter(mat_index(body, "Body_00_SKIN")))]
    px = read_px(tex_of(skin_m)).copy()
    hole = dilate(px[..., :3].mean(-1) < 150 / 255, 5)
    px[..., :3] = fill_holes(px[..., :3], hole)
    clean = write_png(px, "v_body_skin_src")
    for name in names:
        use_style(name)
        bake_body(body, clean)
    use_style("gwen")
    os.remove(os.path.join(TEX_OUT, "v_body_skin_src.png"))


def main():
    os.makedirs(TEX_OUT, exist_ok=True)
    arm = setup_scene()
    remove_fox_parts()
    short_hair()
    fierce_face()
    boots = strip_clothes()
    curves()
    if ONLY_STYLES:
        bake_styles(ONLY_STYLES)
        return
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
