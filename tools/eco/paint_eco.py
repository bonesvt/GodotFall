#!/usr/bin/env python3
"""Paints Eco's textures into assets/textures/eco/ (needs pillow and numpy):
the face (front-projected over the head, see build_eco.py face_uvs), the eyes
(latitude-longitude, iris at the top rows), and tileable outfit fabrics.

    python3 tools/eco/paint_eco.py
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parents[2] / "assets" / "textures" / "eco"
SKIN = (205, 150, 113)


def face_px(x, z, size=512):
    """Head-space metres (before the 1.08 head scale) to face texture pixels."""
    u = (x + 0.1) / 0.2
    v = (z - 1.42) / 0.26
    return u * size, (1.0 - v) * size


def soft(layer, radius):
    return layer.filter(ImageFilter.GaussianBlur(radius))


def paint_over(base, color, mask):
    """Blend a solid colour onto base through an 'L' mask."""
    solid = Image.new("RGB", base.size, color)
    return Image.composite(solid, base, mask)


def face():
    S = 512
    img = Image.new("RGB", (S, S), SKIN)
    # gentle painted shading: warmer cheeks, nose and ears, cooler under the brow
    def blob(cx, cz, rx, rz, color, alpha, blur):
        m = Image.new("L", (S, S), 0)
        x0, y0 = face_px(cx - rx, cz + rz)
        x1, y1 = face_px(cx + rx, cz - rz)
        ImageDraw.Draw(m).ellipse((x0, y0, x1, y1), fill=alpha)
        return soft(m, blur), color

    layers = []
    for s in (1, -1):
        layers.append(blob(s * 0.05, 1.522, 0.022, 0.013, (226, 128, 110), 120, 14))  # blush
        layers.append(blob(s * 0.037, 1.566, 0.025, 0.008, (150, 96, 92), 110, 6))    # lid shadow
        layers.append(blob(s * 0.072, 1.5, 0.016, 0.03, (180, 120, 95), 70, 14))       # jaw shade
    layers.append(blob(0, 1.512, 0.012, 0.008, (222, 135, 112), 110, 6))               # nose tip
    layers.append(blob(0, 1.462, 0.022, 0.012, (180, 122, 96), 60, 10))                # under lip
    for m, c in layers:
        img = paint_over(img, c, m)

    d_mask = Image.new("L", (S, S), 0)
    dd = ImageDraw.Draw(d_mask)
    # lips: muted rose, fuller lower lip with a soft highlight
    lip = Image.new("L", (S, S), 0)
    ld = ImageDraw.Draw(lip)
    pts_top = [face_px(x, z) for x, z in ((-0.02, 1.4805), (-0.008, 1.4855), (0, 1.4835), (0.008, 1.4855), (0.02, 1.4805), (0, 1.4795))]
    pts_bot = [face_px(x, z) for x, z in ((-0.018, 1.4795), (0, 1.4795), (0.018, 1.4795), (0.012, 1.4725), (0, 1.4705), (-0.012, 1.4725))]
    ld.polygon(pts_top, fill=230)
    ld.polygon(pts_bot, fill=210)
    img = paint_over(img, (182, 98, 96), soft(lip, 1.6))
    hl = Image.new("L", (S, S), 0)
    x0, y0 = face_px(-0.007, 1.4765)
    x1, y1 = face_px(0.007, 1.4738)
    ImageDraw.Draw(hl).ellipse((x0, y0, x1, y1), fill=120)
    img = paint_over(img, (230, 168, 160), soft(hl, 2))
    line = Image.new("L", (S, S), 0)
    ImageDraw.Draw(line).line([face_px(x, 1.4795 + 0.0012 * np.cos(x * 120)) for x in np.linspace(-0.02, 0.02, 12)], fill=200, width=2)
    img = paint_over(img, (110, 55, 58), soft(line, 0.8))

    # brows: silver-white like her hair, with a soft lavender underside so they read
    for s in (1, -1):
        pts = [(s * x, 1.578 + 0.0045 * np.sin((x - 0.014) / 0.046 * np.pi) + (x - 0.014) * 0.06)
               for x in np.linspace(0.014, 0.062, 14)]
        shade = Image.new("L", (S, S), 0)
        ImageDraw.Draw(shade).line([face_px(x, z - 0.0016) for x, z in pts], fill=170, width=9)
        img = paint_over(img, (150, 120, 150), soft(shade, 2.5))
        brow = Image.new("L", (S, S), 0)
        bd = ImageDraw.Draw(brow)
        for k in range(len(pts) - 1):
            w = int(round(9 - 6 * k / len(pts)))
            bd.line([face_px(*pts[k]), face_px(*pts[k + 1])], fill=240, width=w, joint="curve")
        img = paint_over(img, (246, 244, 252), soft(brow, 1.0))
        # strokes for hair texture
        sd = ImageDraw.Draw(img)
        for x, z in pts[1::2]:
            px, py = face_px(x, z)
            sd.line((px, py + 2, px + s * 4, py - 3), fill=(255, 255, 255), width=1)

    # lower lash line and a winged liner at the outer corner of each eye
    for s in (1, -1):
        ll = Image.new("L", (S, S), 0)
        pts = [face_px(s * 0.0365 + s * dx, 1.553 - 0.0118 * np.sqrt(max(0.0, 1 - (dx / 0.022) ** 2)) - 0.001)
               for dx in np.linspace(-0.016, 0.02, 10)]
        ImageDraw.Draw(ll).line(pts, fill=150, width=3)
        img = paint_over(img, (90, 50, 50), soft(ll, 1.0))
        wing = Image.new("L", (S, S), 0)
        ImageDraw.Draw(wing).line([face_px(s * 0.056, 1.5555), face_px(s * 0.066, 1.562)], fill=230, width=4)
        img = paint_over(img, (40, 24, 28), soft(wing, 0.8))

    # freckles over the nose and cheeks, and a grease smudge on her left cheek
    rng = np.random.default_rng(3)
    fr = Image.new("L", (S, S), 0)
    fd = ImageDraw.Draw(fr)
    for _ in range(46):
        x = rng.normal(0, 0.03)
        z = 1.532 + rng.normal(0, 0.006)
        if abs(x) < 0.008 and z > 1.54:
            continue
        px, py = face_px(x, z)
        r = rng.uniform(1.0, 2.0)
        fd.ellipse((px - r, py - r, px + r, py + r), fill=int(rng.uniform(90, 150)))
    img = paint_over(img, (160, 92, 70), soft(fr, 0.6))
    smudge = Image.new("L", (S, S), 0)
    ImageDraw.Draw(smudge).line([face_px(-0.071, 1.517), face_px(-0.05, 1.511)], fill=95, width=7)
    img = paint_over(img, (118, 92, 80), soft(smudge, 3))
    img.save(OUT / "face.png")


def eye():
    W, H = 256, 256
    th = (np.arange(H) + 0.5) / H * 180.0          # rows: degrees from the pole (front)
    ph = (np.arange(W) + 0.5) / W * 2 * np.pi       # columns: round the pole
    T, Ph = np.meshgrid(th, ph, indexing="ij")
    rng = np.random.default_rng(5)
    streak = np.repeat(rng.random(64), W // 64)
    streak = np.convolve(np.tile(streak, 3), np.ones(5) / 5, "same")[W:2 * W]
    S = np.broadcast_to(streak, (H, W))
    img = np.zeros((H, W, 3))
    sclera = np.array([246, 246, 250.0]) * (1 - 0.28 * np.clip((T - 45) / 60, 0, 1))[..., None]
    img[:] = sclera
    iris_r, pupil_r = 40.0, 14.0
    t = np.clip((T - pupil_r) / (iris_r - pupil_r), 0, 1)[..., None]
    inner = np.array([255, 236, 150.0])      # gold flecks round the pupil
    mid = np.array([70, 236, 222.0])         # luminous aqua
    outer = np.array([18, 110, 128.0])       # deep teal
    col = np.where(t < 0.25, inner + (mid - inner) * (t / 0.25), mid + (outer - mid) * ((t - 0.25) / 0.75))
    col = col * (0.82 + 0.3 * S[..., None])
    iris = T < iris_r
    img[iris] = col[iris]
    ring = (T >= iris_r - 4) & (T < iris_r + 1)
    img[ring] = img[ring] * 0.35 + np.array([8, 40, 50.0]) * 0.65
    img[T < pupil_r] = np.array([12, 14, 22.0])
    edge = (T >= pupil_r) & (T < pupil_r + 2)
    img[edge] = img[edge] * 0.5 + np.array([12, 14, 22.0]) * 0.5
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.7)).save(OUT / "eye.png")


def _noise(size, cells, seed):
    r = np.random.default_rng(seed)
    g = r.random((cells, cells))
    c = np.arange(size) * cells / size
    i0 = np.floor(c).astype(int)
    f = c - i0
    f = f * f * (3 - 2 * f)
    i1 = (i0 + 1) % cells
    a, b = g[np.ix_(i0, i0)], g[np.ix_(i0, i1)]
    cc, d = g[np.ix_(i1, i0)], g[np.ix_(i1, i1)]
    return (a * (1 - f[None]) + b * f[None]) * (1 - f[:, None]) + (cc * (1 - f[None]) + d * f[None]) * f[:, None]


def canvas():
    """Work canvas (tinted per garment): twill weave, wear, a sewn patch, seams."""
    s = 128
    y, x = np.mgrid[0:s, 0:s]
    n = 0.5 * _noise(s, 4, 11) + 0.3 * _noise(s, 8, 12) + 0.2 * _noise(s, 16, 13)
    base = 210 + 22 * (n - 0.5)
    twill = ((x + y) % 4 < 2) * 10 - 5
    img = np.repeat((base + twill)[..., None], 3, -1).astype(float)
    img *= np.array([1.0, 0.985, 0.95])
    wear = _noise(s, 6, 14)
    img *= (1.0 + 0.05 * np.clip(wear - 0.6, 0, 1) * 4)[..., None]
    seam = (y % 64 == 62) & (x % 6 < 3)
    img[seam] *= 0.7
    img[(y % 64 == 60)] *= 0.9
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(OUT / "canvas.png")


def knit():
    """Fitted shirt: fine rib knit."""
    s = 64
    y, x = np.mgrid[0:s, 0:s]
    n = _noise(s, 4, 21)
    v = 200 + 30 * (n - 0.5) + ((x % 3) == 0) * -14
    img = np.repeat(v[..., None], 3, -1)
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(OUT / "knit.png")


def leather():
    """Worn brown leather with creases, scuffs and stitching."""
    s = 128
    y, x = np.mgrid[0:s, 0:s]
    n = 0.6 * _noise(s, 5, 31) + 0.4 * _noise(s, 12, 32)
    img = np.stack([100 + 34 * n, 70 + 25 * n, 48 + 17 * n], -1)
    crease = np.abs(np.sin((x * 0.11 + _noise(s, 3, 33) * 6.0))) < 0.06
    img[crease] *= 0.86
    scuff = _noise(s, 10, 34) > 0.72
    img[scuff] = img[scuff] * 0.85 + np.array([170, 140, 110]) * 0.15
    st = ((y % 64) == 6) & (x % 6 < 3)
    img[st] = (200, 172, 130)
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(OUT / "leather.png")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for fn in (face, eye, canvas, knit, leather):
        fn()
        print("painted", fn.__name__)
