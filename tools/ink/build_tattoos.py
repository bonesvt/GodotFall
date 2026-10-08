"""Bakes the tattoos sold at Ink & Iron in Solace (scripts/hub/eco_ink.gd)
into Eco's body UV space, one transparent PNG each:
assets/textures/eco/tattoos/<id>.png.

Each design is drawn flat (PIL), then projected onto her body in her rest
pose: planar ("decal") from outside the skin, or wrapped round a limb
("band"). The game lays the worn ones over her body texture wherever it shows
skin (eco_toon.gdshaderinc tattoo_tex, masked by the suit mask's green), so a
tattoo only shows where her outfit leaves skin bare.

Needs numpy and pillow, and the body mesh dumped by Godot first:
    godot --headless --path . -s res://tools/ink/dump_body.gd -- /tmp/ink
    python3 tools/ink/build_tattoos.py /tmp/ink [--preview out.png] [--only=tally,hip_moth]
Coordinates are Godot's, model space, rest pose: she faces -Z, her left is -X,
arms out along X at y 1.354 (T-pose, palms down).
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "textures", "eco", "tattoos")
SIZE = 1024          # matches her suit mask (v_body_mask*.png)
DESIGN = 512         # design canvas, square
INK = (22, 26, 40)   # blue-black tattoo ink
TEAL = (40, 170, 165)
RED = (190, 40, 50)
VIOLET = (150, 70, 230)  # Marrow's
FONTS = ["/mnt/skills/examples/canvas-design/canvas-fonts/NothingYouCouldDo-Regular.ttf",
         "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"]


def v3(x, y, z):
    return np.array([x, y, z], dtype=np.float64)


# id: where it goes. decal: c (a point at the skin), n (out of the skin),
# right (the design's +x as you look at the skin), w, h (metres), depth (how
# far from c along n still counts). band: c on the limb's axis, axis, w
# (round the limb, the design's width wraps once), h (along the axis).
PLACES = {
    "precursor": {"mode": "decal", "c": v3(-0.505, 1.37, 0.026), "n": v3(0, 1, 0), "right": v3(0, 0, 1), "w": 0.062, "h": 0.062, "depth": 0.04},
    "cry_anyway": {"mode": "decal", "c": v3(-0.43, 1.335, 0.026), "n": v3(0, -1, 0), "right": v3(-1, 0, 0), "w": 0.14, "h": 0.047, "depth": 0.04},
    "fern_band": {"mode": "band", "c": v3(0.215, 1.354, 0.026), "axis": v3(1, 0, 0), "h": 0.045},
    "swallows": {"mode": "decal", "c": v3(-0.07, 1.345, -0.075), "n": v3(0, 0.25, -1), "right": v3(-1, 0, 0), "w": 0.08, "h": 0.052, "depth": 0.04},
    "sun_tree": {"mode": "decal", "c": v3(0.065, 1.27, 0.07), "n": v3(0, 0, 1), "right": v3(1, 0, 0), "w": 0.08, "h": 0.096, "depth": 0.05},
    "stars": {"mode": "decal", "c": v3(-0.05, 1.43, 0.012), "n": v3(-1, 0, 0.15), "right": v3(0, 0, 1), "w": 0.045, "h": 0.056, "depth": 0.03},
    "heart_bolt": {"mode": "decal", "c": v3(0.16, 1.385, 0.026), "n": v3(0, 1, 0), "right": v3(0, 0, -1), "w": 0.06, "h": 0.06, "depth": 0.04},
    "wrench": {"mode": "decal", "c": v3(0.525, 1.37, 0.026), "n": v3(0, 1, 0), "right": v3(0, 0, -1), "w": 0.056, "h": 0.056, "depth": 0.04},
    # Mature only (eco_extras.gd "mature"): all well clear of the always-covered zones.
    "tally": {"mode": "decal", "c": v3(0.41, 1.372, 0.026), "n": v3(0, 1, 0), "right": v3(1, 0, 0), "w": 0.13, "h": 0.04, "depth": 0.035},
    "lower_back": {"mode": "decal", "c": v3(0.0, 1.06, 0.046), "n": v3(0, 0.3, 1), "right": v3(1, 0, 0), "w": 0.16, "h": 0.056, "depth": 0.035},
    "hip_moth": {"mode": "decal", "c": v3(-0.11, 1.05, 0.0), "n": v3(-1, 0.1, -0.1), "right": v3(0, 0, 1), "w": 0.07, "h": 0.06, "depth": 0.035},
    "thigh_snake": {"mode": "decal", "c": v3(0.125, 0.6, 0.0), "n": v3(1, 0, 0), "right": v3(0, 0, -1), "w": 0.07, "h": 0.17, "depth": 0.04},
    # Hypno looks only (vice_looks.gd "extras", eco_extras.gd LOOK_TATTOOS): not sold
    # big and bold: her thigh's texels are coarse, so the design is averaged down to them ("soften")
    "marrow_swirl": {"mode": "decal", "c": v3(-0.1, 0.6, -0.045), "n": v3(-0.6, 0, -1), "right": v3(-1, 0, 0.6), "w": 0.08, "h": 0.2, "depth": 0.07, "soften": 3.0},
}


# --- designs (RGBA, DESIGN x DESIGN, transparent) ----------------------------

def canvas(w=DESIGN, h=DESIGN):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def precursor():
    """The Precursors' spiral glyph off the temple's walls: rings, a spiral and four notches."""
    img, d = canvas()
    c = DESIGN / 2
    d.ellipse([c - 230, c - 230, c + 230, c + 230], outline=INK + (255,), width=26)
    d.ellipse([c - 170, c - 170, c + 170, c + 170], outline=TEAL + (255,), width=12)
    pts = []
    for i in range(400):
        t = i / 400 * 3.2 * math.pi
        r = 20 + t * 14
        pts.append((c + math.cos(t) * r, c + math.sin(t) * r))
    d.line(pts, fill=INK + (255,), width=18, joint="curve")
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        x0, y0 = c + math.cos(a) * 200, c + math.sin(a) * 200
        d.rectangle([x0 - 14, y0 - 14, x0 + 14, y0 + 14], fill=INK + (255,))
    return img


def cry_anyway():
    """'cry anyway', handwritten: what she tells the recruiters, in ink."""
    w, h = DESIGN, int(DESIGN / 3)
    img, d = canvas(w, h)
    font = None
    for f in FONTS:
        if os.path.exists(f):
            font = ImageFont.truetype(f, 120)
            break
    d.text((w / 2, h / 2 - 4), "cry anyway", font=font, fill=INK + (255,), anchor="mm")
    # a little teardrop after it
    d.ellipse([w - 44, h / 2 - 2, w - 22, h / 2 + 22], fill=TEAL + (255,))
    d.polygon([(w - 41, h / 2 + 4), (w - 33, h / 2 - 26), (w - 25, h / 2 + 4)], fill=TEAL + (255,))
    return img


def fern_band():
    """A band of fern fronds round her arm, Solace's gardens. Wide: it wraps once."""
    w, h = DESIGN * 4, DESIGN
    img, d = canvas(w, h)
    d.line([(0, 70), (w, 70)], fill=INK + (255,), width=20)
    d.line([(0, h - 70), (w, h - 70)], fill=INK + (255,), width=20)
    for k in range(8):
        x0 = k * w / 8 + 40
        # a frond: a curved stem with leaflets
        stem = [(x0 + t * 170, h / 2 + math.sin(t * 2.4) * 50) for t in np.linspace(0, 1, 30)]
        d.line(stem, fill=INK + (255,), width=12)
        for j in range(1, 9):
            sx, sy = stem[j * 3]
            ln = 70 - j * 6
            for sgn in (-1, 1):
                d.polygon([(sx, sy), (sx + 18, sy + sgn * ln * 0.6), (sx + 34, sy + sgn * ln)], fill=(INK if j % 3 else TEAL) + (255,))
    return img


def swallows():
    """Two swallows, one chasing the other: going home."""
    img, d = canvas(DESIGN, int(DESIGN * 0.65))

    def bird(cx, cy, s, col):
        pts = [(0, 0), (60, -18), (110, -70), (90, -10), (130, 10), (60, 20), (20, 60), (35, 15), (-30, 25), (-70, 70),
               (-55, 20), (-90, 10)]
        d.polygon([(cx + x * s, cy + y * s) for x, y in pts], fill=col + (255,))
    bird(160, 190, 1.25, INK)
    bird(370, 120, 0.95, INK)
    d.ellipse([140, 170, 170, 200], fill=TEAL + (255,))
    d.ellipse([355, 105, 378, 128], fill=RED + (255,))
    return img


def sun_tree():
    """The Sun Tree on the plaza: white ribs and leaf panels, the sun behind."""
    img, d = canvas(DESIGN, int(DESIGN * 1.2))
    w, h = img.size
    d.ellipse([w / 2 - 150, 40, w / 2 + 150, 340], outline=TEAL + (255,), width=14)
    d.polygon([(w / 2 - 22, h - 40), (w / 2 + 22, h - 40), (w / 2 + 10, 260), (w / 2 - 10, 260)], fill=INK + (255,))
    for k in range(7):
        a = math.pi * (0.15 + 0.7 * k / 6)
        x1, y1 = w / 2 - math.cos(a) * 190, 250 - math.sin(a) * 170
        d.line([(w / 2, 280), (x1, y1)], fill=INK + (255,), width=12)
        d.polygon([(x1, y1 - 34), (x1 + 26, y1), (x1, y1 + 34), (x1 - 26, y1)], fill=INK + (255,))
    d.line([(w / 2 - 140, h - 40), (w / 2 + 140, h - 40)], fill=INK + (255,), width=14)
    return img


def stars():
    """A little constellation under her ear: the three stars Dad named after her."""
    img, d = canvas(int(DESIGN * 0.8), DESIGN)
    pts = [(90, 420), (180, 300), (150, 160), (280, 80)]
    d.line(pts, fill=INK + (200,), width=6)
    for i, (x, y) in enumerate(pts):
        r = 30 if i in (1, 3) else 20
        star = []
        for k in range(10):
            a = k * math.pi / 5 - math.pi / 2
            rr = r if k % 2 == 0 else r * 0.42
            star.append((x + math.cos(a) * rr, y + math.sin(a) * rr))
        d.polygon(star, fill=(TEAL if i == 3 else INK) + (255,))
    return img


def heart_bolt():
    """A heart split by a lightning bolt."""
    img, d = canvas()
    c = DESIGN / 2
    heart = []
    for i in range(80):
        t = i / 80 * 2 * math.pi
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        heart.append((c + x * 13, c - y * 13 - 10))
    d.polygon(heart, fill=RED + (255,), outline=INK + (255,), width=16)
    d.line(heart + [heart[0]], fill=INK + (255,), width=16)
    bolt = [(c + 20, c - 200), (c - 60, c + 10), (c + 10, c + 10), (c - 40, c + 220), (c + 90, c - 40), (c + 15, c - 40), (c + 70, c - 200)]
    d.polygon(bolt, fill=(240, 220, 120, 255), outline=INK + (255,), width=10)
    return img


def wrench():
    """A spanner through a small heart: mechanic for life."""
    img, d = canvas()
    c = DESIGN / 2
    d.line([(c - 170, c + 170), (c + 140, c - 140)], fill=INK + (255,), width=46)
    for x, y in ((c - 190, c + 190), (c + 160, c - 160)):
        d.ellipse([x - 60, y - 60, x + 60, y + 60], fill=INK + (255,))
        d.polygon([(x, y), (x + 70, y - 10), (x + 10, y - 70)], fill=(0, 0, 0, 0))
    d.ellipse([c - 30 - 40, c - 30 - 10, c - 30 + 40, c - 30 + 70], fill=TEAL + (255,))
    d.ellipse([c + 30 - 40, c - 30 - 10, c + 30 + 40, c - 30 + 70], fill=TEAL + (255,))
    d.polygon([(c - 70, c + 20), (c + 70, c + 20), (c, c + 110)], fill=TEAL + (255,))
    return img


def tally():
    """Five gates of five: one mark for every colony grunt."""
    img, d = canvas(640, 200)
    for g in range(5):
        x0 = 30 + g * 122
        for k in range(4):
            x = x0 + k * 22 + (k % 2) * 3
            d.line([(x, 40 + (k * 7) % 11), (x + 4, 160 - (k * 5) % 9)], fill=INK + (255,), width=11)
        d.line([(x0 - 12, 140), (x0 + 84, 58)], fill=RED + (255,) if g == 4 else INK + (255,), width=11)
    return img


def lower_back():
    """The temple spiral with a wing either side, across the small of her back."""
    img, d = canvas(768, 272)
    c, cy = 384, 136
    d.ellipse([c - 62, cy - 62, c + 62, cy + 62], outline=INK + (255,), width=12)
    pts = []
    for i in range(240):
        t = i / 240 * 2.6 * math.pi
        r = 8 + t * 6.5
        pts.append((c + math.cos(t) * r, cy + math.sin(t) * r))
    d.line(pts, fill=TEAL + (255,), width=9, joint="curve")
    for s in (-1, 1):
        for k in range(6):
            # feathers fanning out and down, longest at the top
            length = 290 - k * 34
            a0 = math.radians(-14 + k * 11)
            x0 = c + s * 74
            y0 = cy - 30 + k * 12
            tip = (x0 + s * math.cos(a0) * length, y0 + math.sin(a0) * length * 0.55)
            mid = (x0 + s * math.cos(a0) * length * 0.55, y0 + math.sin(a0) * length * 0.3 - 26)
            d.line([(x0, y0), mid, tip], fill=INK + (255,), width=12 - k, joint="curve")
            d.ellipse([tip[0] - 6, tip[1] - 6, tip[0] + 6, tip[1] + 6], fill=INK + (255,))
    return img


def hip_moth():
    """A death's-head moth: four wings, a little skull on its back."""
    img, d = canvas(512, 444)
    c, cy = 256, 222
    for s in (-1, 1):
        upper = [(c + s * 18, cy - 20), (c + s * 230, cy - 150), (c + s * 245, cy - 40), (c + s * 30, cy + 10)]
        lower = [(c + s * 22, cy + 10), (c + s * 170, cy + 40), (c + s * 120, cy + 150), (c + s * 16, cy + 60)]
        d.polygon(upper, fill=(60, 52, 64, 255), outline=INK + (255,), width=10)
        d.polygon(lower, fill=(150, 110, 60, 255), outline=INK + (255,), width=10)
        d.line([(c + s * 40, cy - 20), (c + s * 200, cy - 110)], fill=INK + (255,), width=6)
        d.line([(c + s * 8, cy - 70), (c + s * 70, cy - 190)], fill=INK + (255,), width=6)
    d.ellipse([c - 24, cy - 70, c + 24, cy + 140], fill=INK + (255,))
    d.ellipse([c - 18, cy - 50, c + 18, cy - 10], fill=(230, 220, 190, 255))
    for x in (c - 8, c + 8):
        d.ellipse([x - 5, cy - 40, x + 5, cy - 30], fill=INK + (255,))
    return img


def thigh_snake():
    """Sailor flash: a snake winding down a dagger."""
    img, d = canvas(280, 680)
    c = 140
    d.polygon([(c - 22, 170), (c + 22, 170), (c, 640)], fill=(205, 210, 220, 255), outline=INK + (255,), width=9)
    d.line([(c, 180), (c, 600)], fill=INK + (255,), width=4)
    d.rectangle([c - 70, 150, c + 70, 172], fill=INK + (255,))
    d.rectangle([c - 14, 60, c + 14, 150], fill=(120, 60, 40, 255), outline=INK + (255,), width=6)
    d.ellipse([c - 22, 30, c + 22, 72], fill=RED + (255,), outline=INK + (255,), width=6)
    pts = []
    for i in range(200):
        t = i / 200
        pts.append((c + math.sin(t * 3.4 * math.pi) * 62, 120 + t * 470))
    d.line(pts, fill=INK + (255,), width=30, joint="curve")
    d.line(pts, fill=(60, 150, 80, 255), width=16, joint="curve")
    hx, hy = pts[0]
    d.ellipse([hx - 30, hy - 26, hx + 30, hy + 22], fill=(60, 150, 80, 255), outline=INK + (255,), width=7)
    d.line([(hx + 26, hy), (hx + 52, hy - 6), (hx + 60, hy - 14)], fill=RED + (255,), width=5)
    d.ellipse([hx + 4, hy - 12, hx + 14, hy - 2], fill=INK + (255,))
    return img


def marrow_swirl():
    """Marrow's spiral, violet and ink like his suit, with a tendril curling
    down from it to a drop."""
    img, d = canvas(300, 720)
    c, cy = 150, 140
    for band, col, wid in ((0, INK, 34), (1, VIOLET, 30)):
        pts = []
        for i in range(400):
            t = i / 400 * 2.4 * math.pi
            r = 10 + t * 15
            a = t + band * math.pi
            pts.append((c + math.cos(a) * r, cy + math.sin(a) * r))
        d.line(pts, fill=col + (255,), width=wid, joint="curve")
    # the tendril, off the spiral's foot, swinging down her thigh to a drop
    tail = []
    for i in range(200):
        t = i / 200
        tail.append((c + math.sin(t * 2.4 * math.pi) * 60 * (1 - 0.5 * t), cy + 120 + t * 500))
    d.line(tail, fill=INK + (255,), width=30, joint="curve")
    d.line(tail, fill=VIOLET + (255,), width=14, joint="curve")
    x, y = tail[-1]
    d.ellipse([x - 26, y - 10, x + 26, y + 46], fill=VIOLET + (255,), outline=INK + (255,), width=9)
    return img


DESIGNS = {"precursor": precursor, "cry_anyway": cry_anyway, "fern_band": fern_band, "swallows": swallows,
           "sun_tree": sun_tree, "stars": stars, "heart_bolt": heart_bolt, "wrench": wrench,
           "tally": tally, "lower_back": lower_back, "hip_moth": hip_moth, "thigh_snake": thigh_snake,
           "marrow_swirl": marrow_swirl}


# --- projection ------------------------------------------------------------------

def load(dump):
    pos = np.fromfile(os.path.join(dump, "pos.f32"), dtype="<f4").reshape(-1, 3).astype(np.float64)
    nrm = np.fromfile(os.path.join(dump, "nrm.f32"), dtype="<f4").reshape(-1, 3).astype(np.float64)
    uv = np.fromfile(os.path.join(dump, "uv.f32"), dtype="<f4").reshape(-1, 2).astype(np.float64)
    idx = np.fromfile(os.path.join(dump, "idx.i32"), dtype="<i4").reshape(-1, 3)
    return pos, nrm, uv, idx


def unit(v):
    return v / np.linalg.norm(v)


def design_coords(place, p, nrm, w_img, h_img):
    """Where points p (N,3) with normals land on the design (pixel x, y), and
    which of them count (facing the right way, close enough)."""
    if place["mode"] == "band":
        axis = unit(place["axis"])
        rel = p - place["c"]
        along = rel @ axis
        radial = rel - np.outer(along, axis)
        ref = unit(np.cross(axis, v3(0, 0, 1))) if abs(axis[2]) < 0.9 else unit(np.cross(axis, v3(1, 0, 0)))
        ref2 = np.cross(axis, ref)
        ang = np.arctan2(radial @ ref2, radial @ ref)
        x = (ang / (2 * math.pi) + 0.5) * w_img
        y = (0.5 - along / place["h"]) * h_img
        dist = np.linalg.norm(radial, axis=1)
        facing = np.einsum("ij,ij->i", nrm, radial / np.maximum(dist, 1e-6)[:, None]) > 0.2
        ok = facing & (dist < 0.08) & (np.abs(along) < place["h"] / 2)
        return x, y, ok
    n = unit(place["n"])
    right = unit(place["right"] - n * (place["right"] @ n))
    up = np.cross(n, right)
    rel = p - place["c"]
    x = (0.5 + (rel @ right) / place["w"]) * w_img
    y = (0.5 - (rel @ up) / place["h"]) * h_img
    ok = (np.abs(rel @ n) < place["depth"]) & (nrm @ n > 0.25)
    ok &= (x >= 0) & (x < w_img) & (y >= 0) & (y < h_img)
    return x, y, ok


def bake(tid, mesh):
    pos, nrm, uv, idx = mesh
    place = PLACES[tid]
    design = DESIGNS[tid]()
    if place.get("soften"):
        design = design.filter(ImageFilter.GaussianBlur(place["soften"]))
    if place["mode"] == "band":
        # width wraps round once; keep the pixels square on the skin
        pass
    dimg = np.asarray(design, dtype=np.float64) / 255.0
    h_img, w_img = dimg.shape[:2]
    out = np.zeros((SIZE, SIZE, 4), dtype=np.float64)
    # Only triangles near the spot.
    cen = pos[idx].mean(axis=1)
    reach = 0.12 if place["mode"] == "band" else max(place["w"], place["h"]) + 0.03
    near = np.where(np.linalg.norm(cen - place["c"], axis=1) < reach + (0.0 if place["mode"] != "band" else 0.04))[0]
    texels = 0
    for t in near:
        a, b, c = idx[t]
        uvs = uv[[a, b, c]] * SIZE
        x0, y0 = np.floor(uvs.min(axis=0) - 1).astype(int)
        x1, y1 = np.ceil(uvs.max(axis=0) + 1).astype(int)
        x0, y0 = max(x0, 0), max(y0, 0)
        x1, y1 = min(x1, SIZE - 1), min(y1, SIZE - 1)
        if x1 < x0 or y1 < y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        pts = np.stack([xs.ravel(), ys.ravel()], axis=1)
        # barycentrics in UV space
        v0, v1 = uvs[1] - uvs[0], uvs[2] - uvs[0]
        den = v0[0] * v1[1] - v1[0] * v0[1]
        if abs(den) < 1e-9:
            continue
        r = pts - uvs[0]
        l1 = (r[:, 0] * v1[1] - v1[0] * r[:, 1]) / den
        l2 = (v0[0] * r[:, 1] - r[:, 0] * v0[1]) / den
        l0 = 1 - l1 - l2
        eps = 1.2 / max(abs(den) ** 0.5, 1e-6)   # about a texel of slack, so seams close
        inside = (l0 > -eps) & (l1 > -eps) & (l2 > -eps)
        if not inside.any():
            continue
        L = np.stack([l0, l1, l2], axis=1)[inside]
        P = L @ pos[[a, b, c]]
        N = L @ nrm[[a, b, c]]
        N /= np.maximum(np.linalg.norm(N, axis=1), 1e-9)[:, None]
        dx, dy, ok = design_coords(place, P, N, w_img, h_img)
        if place["mode"] == "band":
            ok &= (dy >= 0) & (dy < h_img)
            dx = np.mod(dx, w_img)
        if not ok.any():
            continue
        px = pts[inside][ok].astype(int)
        sx = np.clip(dx[ok].astype(int), 0, w_img - 1)
        sy = np.clip(dy[ok].astype(int), 0, h_img - 1)
        col = dimg[sy, sx]
        cur = out[px[:, 1] - 0, px[:, 0]]
        take = col[:, 3] > cur[:, 3]
        out[px[take, 1], px[take, 0]] = col[take]
        texels += int(ok.sum())
    img = Image.fromarray((out * 255).astype(np.uint8), "RGBA")
    img = img.filter(ImageFilter.GaussianBlur(0.6))   # soften the nearest-texel steps
    os.makedirs(OUT, exist_ok=True)
    img.save(os.path.join(OUT, tid + ".png"))
    print("%-11s %6d texels" % (tid, texels))
    return img


def main():
    dump = sys.argv[1] if len(sys.argv) > 1 else "/tmp/ink"
    mesh = load(dump)
    only = [a.split("=", 1)[1].split(",") for a in sys.argv if a.startswith("--only=")]
    imgs = [bake(t, mesh) for t in PLACES if not only or t in only[0]]
    if "--preview" in sys.argv:
        prev = Image.open(os.path.join(ROOT, "assets", "textures", "eco", "v_body.png")).convert("RGBA").resize((SIZE, SIZE))
        for img in imgs:
            prev.alpha_composite(img)
        prev.save(sys.argv[sys.argv.index("--preview") + 1])


if __name__ == "__main__":
    main()
