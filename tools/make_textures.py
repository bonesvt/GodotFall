#!/usr/bin/env python3
"""Paints the game's PS2-style textures into assets/textures/.

Every texture is small (64 or 128 px), tiles seamlessly, and is reduced to a
16-colour palette like a PS2 CLUT texture. Grey textures are tinted in the
material, so one concrete texture serves every zone.

    python3 tools/make_textures.py      (needs pillow and numpy)

Re-running overwrites the PNGs. Paint over them by hand if you like; the game
only cares about the file names.
"""
from pathlib import Path

import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "assets" / "textures"
rng = np.random.default_rng(7)


def noise(size, cells, octaves=3, seed=0):
    """Tileable value noise in 0..1."""
    r = np.random.default_rng(seed)
    total = np.zeros((size, size))
    amp, norm = 1.0, 0.0
    for o in range(octaves):
        c = cells * (2 ** o)
        grid = r.random((c, c))
        coords = np.arange(size) * c / size
        i0 = np.floor(coords).astype(int)
        f = coords - i0
        f = f * f * (3 - 2 * f)
        i1 = (i0 + 1) % c
        a = grid[np.ix_(i0, i0)]
        b = grid[np.ix_(i0, i1)]
        cc = grid[np.ix_(i1, i0)]
        d = grid[np.ix_(i1, i1)]
        fx = f[None, :]
        fy = f[:, None]
        total += amp * ((a * (1 - fx) + b * fx) * (1 - fy) + (cc * (1 - fx) + d * fx) * fy)
        norm += amp
        amp *= 0.5
    return total / norm


def speckle(size, amount, seed):
    return np.random.default_rng(seed).random((size, size)) < amount


def rgb(arr_or_color, size=None):
    if size is not None:
        return np.ones((size, size, 3)) * np.array(arr_or_color, dtype=float)
    return arr_or_color


def shade(img, factor):
    return img * factor[..., None]


def save(name, img, colors=16):
    img = np.clip(img, 0, 255).astype(np.uint8)
    pic = Image.fromarray(img, "RGB").quantize(colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    pic.convert("RGB").save(OUT / f"{name}.png")
    print("wrote", name)


def panel_lines(size, step, width=1, offset=0):
    """Mask of dark seams on a square grid."""
    m = np.zeros((size, size), bool)
    for k in range(offset, size, step):
        m[:, k:k + width] = True
        m[k:k + width, :] = True
    return m


def rivets(size, step, inset, mask_value=True):
    m = np.zeros((size, size), bool)
    for y in range(inset, size, step):
        for x in range(inset, size, step):
            m[y % size, x % size] = mask_value
    return m


def concrete():
    s = 64
    n = noise(s, 4, 4, 1)
    base = 150 + (n - 0.5) * 70
    img = rgb([1, 1, 1], s) * base[..., None]
    img = shade(img, np.where(speckle(s, 0.06, 2), 0.85, 1.0))
    img = shade(img, np.where(speckle(s, 0.03, 3), 1.12, 1.0))
    seams = panel_lines(s, 32, 1)
    img = shade(img, np.where(seams, 0.62, 1.0))
    # bevel highlight below/right of each seam
    hl = np.roll(seams, 1, axis=0) | np.roll(seams, 1, axis=1)
    img = shade(img, np.where(hl & ~seams, 1.12, 1.0))
    # water stains running down
    stain = noise(s, 2, 2, 4)
    img = shade(img, 0.9 + 0.1 * np.clip(stain * 1.6 - 0.3, 0, 1))
    save("concrete", img)


def metal_floor():
    s = 64
    n = noise(s, 8, 3, 11)
    img = rgb([1, 1, 1], s) * (140 + (n - 0.5) * 40)[..., None]
    y, x = np.mgrid[0:s, 0:s]
    # diamond tread
    tread = ((x + y) % 8 < 2) & ((x - y) % 8 < 2)
    img = shade(img, np.where(tread, 1.25, 1.0))
    tread_shadow = np.roll(tread, 1, axis=0) & ~tread
    img = shade(img, np.where(tread_shadow, 0.8, 1.0))
    seams = panel_lines(s, 32, 2)
    img = shade(img, np.where(seams, 0.5, 1.0))
    r = rivets(s, 32, 4) | rivets(s, 32, 28)
    img = shade(img, np.where(r, 1.4, 1.0))
    wear = noise(s, 3, 3, 12)
    img = shade(img, 0.85 + 0.25 * wear)
    save("metal_floor", img)


def wall_panel():
    """Wallrun walls: blue painted plates with a white guide stripe and chevrons."""
    s = 64
    n = noise(s, 4, 3, 21)
    base = np.array([60, 105, 185])
    img = rgb(base, s) * (0.85 + 0.3 * n)[..., None]
    y, x = np.mgrid[0:s, 0:s]
    stripe = (y >= 28) & (y < 36)
    img[stripe] = np.array([225, 230, 235]) * (0.9 + 0.15 * n[stripe])[..., None]
    chevron = stripe & (((x + np.abs(y - 31.5)).astype(int) % 16) < 5)
    img[chevron] = np.array([35, 60, 120])
    seams = panel_lines(s, 32, 1, 0)
    seams[:, :] = seams & ~stripe
    img = shade(img, np.where(seams, 0.55, 1.0))
    chips = (noise(s, 16, 1, 22) > 0.82)
    img[chips] = np.array([150, 150, 155]) * (0.8 + 0.3 * n[chips])[..., None]
    img = shade(img, np.where(rivets(s, 16, 3) & ~stripe, 1.3, 1.0))
    save("wall_panel", img)


def hazard():
    """Grapple anchors: orange/black hazard stripes over dirty steel."""
    s = 64
    n = noise(s, 6, 3, 31)
    y, x = np.mgrid[0:s, 0:s]
    stripe = ((x + y) % 32) < 16
    img = np.where(stripe[..., None], np.array([235, 140, 40]), np.array([30, 28, 26])).astype(float)
    img = shade(img, 0.75 + 0.4 * n)
    grime = noise(s, 4, 2, 32) > 0.68
    img[grime] = img[grime] * 0.55 + 20
    edge = panel_lines(s, 64, 3)
    img[edge] = np.array([90, 92, 96]) * (0.8 + 0.3 * n[edge])[..., None]
    save("hazard", img)


def crate():
    """Cover blocks: olive drab military crate with a frame and stencil marks."""
    s = 64
    n = noise(s, 6, 3, 41)
    base = np.array([92, 104, 64])
    img = rgb(base, s) * (0.8 + 0.35 * n)[..., None]
    y, x = np.mgrid[0:s, 0:s]
    # vertical planks
    plank = (x % 16) == 0
    img = shade(img, np.where(plank, 0.6, 1.0))
    frame = (x < 4) | (x >= 60) | (y < 4) | (y >= 60)
    img[frame] = np.array([70, 78, 48]) * (0.8 + 0.3 * n[frame])[..., None]
    diag = (np.abs(x - y) < 3) & ~frame
    img[diag] = np.array([80, 90, 55]) * (0.85 + 0.3 * n[diag])[..., None]
    img = shade(img, np.where(rivets(s, 56, 6) | rivets(s, 56, 57), 1.5, 1.0))
    # stencil block
    sten = (y >= 40) & (y < 50) & (x >= 36) & (x < 56) & (((x // 3) + (y // 5)) % 2 == 0)
    img[sten] = np.array([200, 190, 140])
    save("crate", img)


def barrier():
    """Low cover walls: cast concrete with a hazard band along the top edge."""
    s = 64
    n = noise(s, 4, 4, 141)
    img = rgb([1, 1, 1], s) * (165 + (n - 0.5) * 60)[..., None]
    img = shade(img, np.where(speckle(s, 0.08, 142), 0.85, 1.0))
    y, x = np.mgrid[0:s, 0:s]
    band = y < 10
    stripe = ((x + y) % 16) < 8
    img[band & stripe] = np.array([230, 190, 40]) * (0.8 + 0.3 * n[band & stripe])[..., None]
    img[band & ~stripe] = np.array([35, 33, 30])
    img[(y >= 10) & (y < 12)] *= 0.6
    img[y >= 60] *= 0.7  # grime at the foot
    chips = noise(s, 16, 1, 143) > 0.8
    img = shade(img, np.where(chips & ~band, 0.8, 1.0))
    save("barrier", img)


def lava():
    s = 64
    n = noise(s, 4, 4, 51)
    t = np.clip((n - 0.3) * 2.2, 0, 1)
    img = (np.array([90, 10, 5])[None, None, :] * (1 - t[..., None])
           + np.array([255, 150, 30])[None, None, :] * t[..., None])
    save("lava", img)


def gunmetal():
    s = 64
    n = noise(s, 8, 3, 61)
    img = rgb([1, 1, 1], s) * (70 + 50 * n)[..., None] * np.array([0.95, 1.0, 1.08])
    y, x = np.mgrid[0:s, 0:s]
    brushed = noise(s, 32, 1, 62)[:, :1]
    img = shade(img, 0.9 + 0.15 * np.repeat(brushed, s, axis=1))
    edges = noise(s, 12, 2, 63) > 0.75
    img = shade(img, np.where(edges, 1.45, 1.0))
    serr = (x % 4 < 2) & (y < 16)
    img = shade(img, np.where(serr, 0.7, 1.0))
    save("gunmetal", img)


def glove():
    s = 64
    n = noise(s, 8, 3, 71)
    img = rgb([58, 52, 46], s) * (0.75 + 0.45 * n)[..., None]
    y, x = np.mgrid[0:s, 0:s]
    stitch = ((y % 16) == 0) & (x % 4 < 2)
    img = shade(img, np.where(stitch, 1.5, 1.0))
    pad = noise(s, 4, 1, 72) > 0.65
    img[pad] = np.array([34, 34, 36]) * (0.8 + 0.4 * n[pad])[..., None]
    save("glove", img)


def fabric():
    """Grunt fatigues: blotchy olive camo with a weave."""
    s = 64
    a = noise(s, 4, 2, 81)
    b = noise(s, 5, 2, 82)
    img = rgb([78, 84, 60], s)
    img[a > 0.58] = [56, 62, 44]
    img[(b > 0.62) & (a <= 0.58)] = [102, 98, 72]
    img[(a < 0.3)] = [44, 46, 36]
    y, x = np.mgrid[0:s, 0:s]
    weave = ((x + y) % 2 == 0)
    img = shade(img, np.where(weave, 1.06, 0.95))
    save("fabric", img)


def armor():
    """Grunt plates and helmets: grey-green ceramic with scuffs."""
    s = 64
    n = noise(s, 6, 3, 91)
    img = rgb([96, 104, 92], s) * (0.8 + 0.35 * n)[..., None]
    seams = panel_lines(s, 32, 1, 16)
    img = shade(img, np.where(seams, 0.6, 1.0))
    scuff = noise(s, 16, 1, 92) > 0.8
    img = shade(img, np.where(scuff, 1.35, 1.0))
    save("armor", img)


def titan_armor():
    """Titan hull plates, light grey so the chassis paint tints them."""
    s = 128
    n = noise(s, 6, 4, 101)
    img = rgb([1, 1, 1], s) * (170 + (n - 0.5) * 50)[..., None]
    y, x = np.mgrid[0:s, 0:s]
    seams = np.zeros((s, s), bool)
    seams[:, 0:2] = True
    seams[0:2, :] = True
    seams[62:64, :] = True
    seams[64:128, 40:42] = True
    seams[0:64, 88:90] = True
    seams[96:98, 40:128] = True
    img = shade(img, np.where(seams, 0.45, 1.0))
    hl = (np.roll(seams, 2, axis=0) | np.roll(seams, 2, axis=1)) & ~seams
    img = shade(img, np.where(hl, 1.15, 1.0))
    r = np.zeros((s, s), bool)
    for yy in (6, 56, 70, 90, 104, 122):
        for xx in range(6, s, 12):
            r[yy, xx] = True
    img = shade(img, np.where(r, 0.55, 1.0))
    # worn paint at panel edges shows dark metal
    wear = (noise(s, 16, 2, 102) > 0.7) & (np.roll(hl, 3, axis=0) | np.roll(hl, 3, axis=1))
    img[wear] = [70, 70, 74]
    chips = noise(s, 24, 1, 103) > 0.86
    img[chips] = [85, 85, 90]
    # unit number stencil block
    block = (y >= 74) & (y < 90) & (x >= 52) & (x < 76)
    digits = block & ((((x - 52) // 4) % 2 == 0) | ((y - 74) % 8 < 2))
    img[digits] = [235, 235, 225]
    grime = noise(s, 4, 3, 104)
    img = shade(img, 0.8 + 0.25 * grime)
    save("titan_armor", img)


def titan_frame():
    """Titan joints and inner frame: dark machinery with hoses."""
    s = 64
    n = noise(s, 8, 3, 111)
    img = rgb([52, 54, 58], s) * (0.75 + 0.5 * n)[..., None]
    y, x = np.mgrid[0:s, 0:s]
    ribs = (y % 8) < 2
    img = shade(img, np.where(ribs, 0.6, 1.0))
    hose = (np.abs(x - 20) < 3) | (np.abs(x - 46) < 2)
    img[hose] = np.array([40, 36, 30]) * (0.8 + 0.4 * n[hose])[..., None]
    bolts = rivets(s, 16, 8)
    img = shade(img, np.where(bolts, 1.8, 1.0))
    save("titan_frame", img)


def sky():
    """Panorama layers in the red/green/blue channels, tinted per zone by the sky shader:
    R = cloud density, G = far mountain silhouette, B = near ridge silhouette."""
    w, h = 512, 128
    clouds = np.zeros((h, w))
    r = np.random.default_rng(121)
    for o, (cx, cy) in enumerate([(16, 4), (32, 8), (64, 16)]):
        grid = r.random((cy + 1, cx))
        ys = np.linspace(0, cy, h)
        xs = np.arange(w) * cx / w
        x0 = np.floor(xs).astype(int)
        y0 = np.floor(ys).astype(int)
        fx = (xs - x0)
        fy = (ys - y0)
        fx = fx * fx * (3 - 2 * fx)
        fy = fy * fy * (3 - 2 * fy)
        x1 = (x0 + 1) % cx
        y1 = np.minimum(y0 + 1, cy)
        a = grid[np.ix_(y0, x0)]
        b = grid[np.ix_(y0, x1)]
        c = grid[np.ix_(y1, x0)]
        d = grid[np.ix_(y1, x1)]
        v = (a * (1 - fx) + b * fx) * (1 - fy[:, None]) + (c * (1 - fx) + d * fx) * fy[:, None]
        clouds += v * 0.5 ** o
    clouds /= 1.75
    rows = np.linspace(0, 1, h)[:, None]
    # streaky clouds sit above the horizon (horizon is the bottom row)
    band = np.clip(1.0 - np.abs(rows - 0.55) * 2.2, 0, 1)
    clouds = np.clip((clouds - 0.45) * 3.0, 0, 1) * band
    clouds = np.round(clouds * 4) / 4  # banded, painterly

    def ridge(seed, base, amp, cells):
        rr = np.random.default_rng(seed)
        pts = rr.random(cells)
        xs = np.arange(w) * cells / w
        i0 = np.floor(xs).astype(int)
        f = xs - i0
        line = pts[i0] * (1 - f) + pts[(i0 + 1) % cells] * f
        fine = rr.random(cells * 8)
        xs2 = np.arange(w) * cells * 8 / w
        j0 = np.floor(xs2).astype(int)
        f2 = xs2 - j0
        line += 0.25 * (fine[j0] * (1 - f2) + fine[(j0 + 1) % (cells * 8)] * f2)
        height = base + amp * line  # 0 = horizon, measured upward in rows
        y_from_bottom = (h - 1 - np.arange(h))[:, None]
        return (y_from_bottom < height[None, :] * h).astype(float)

    far = ridge(131, 0.10, 0.32, 9)
    near = ridge(132, 0.04, 0.16, 14)
    img = np.stack([clouds, far, near], axis=-1) * 255
    Image.fromarray(img.astype(np.uint8), "RGB").save(OUT / "sky.png")
    print("wrote sky")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for fn in (concrete, metal_floor, wall_panel, hazard, crate, barrier, lava, gunmetal, glove,
               fabric, armor, titan_armor, titan_frame, sky):
        fn()
