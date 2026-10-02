#!/usr/bin/env python3
"""Paints the game's textures into assets/textures/.

The style is hand-painted PS2 (think Jak and Daxter, Shadow of the Colossus):
small textures (64 to 128 px) with soft banded brush strokes, bevelled panel
edges with painted highlights and shadows, warm/cool colour shifts, and no
photo noise. Every texture tiles. Grey textures are tinted in the material,
so one stone texture serves every zone.

    python3 tools/make_textures.py      (needs pillow and numpy)

Re-running overwrites the PNGs. Paint over them by hand if you like; the game
only cares about the file names.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "assets" / "textures"


# --- painting helpers ------------------------------------------------------

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


def blur(a, r=1):
    """Tile-wrapping box blur."""
    out = np.zeros_like(a, dtype=float)
    n = 0
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            out += np.roll(np.roll(a, dy, axis=0), dx, axis=1)
            n += 1
    return out / n


def strokes(size, cells, levels, seed, soften=1):
    """Soft banded 'brush strokes': noise posterized into a few values, then softened."""
    n = noise(size, cells, 2, seed)
    n = (n - n.min()) / (n.max() - n.min() + 1e-6)
    q = np.floor(n * levels) / max(levels - 1, 1)
    return blur(q, soften) if soften else q


def mix(t, c1, c2):
    t = t[..., None]
    return np.array(c1, float) * (1 - t) + np.array(c2, float) * t


def panels(img, rects, hi=1.28, lo=0.62, edge=2, grad=0.12):
    """Bevel each rect (x0, y0, x1, y1): lit top/left edge, shaded bottom/right edge,
    and a soft top-to-bottom gradient inside, like a painted plate."""
    s = img.shape[0]
    y, x = np.mgrid[0:s, 0:s]
    for x0, y0, x1, y1 in rects:
        inside = (x >= x0) & (x < x1) & (y >= y0) & (y < y1)
        t = (y - y0) / max(y1 - y0 - 1, 1)
        img[inside] *= (1.0 + grad - 2 * grad * t[inside])[..., None]
        top = inside & ((y < y0 + edge) | (x < x0 + edge))
        bottom = inside & ((y >= y1 - edge) | (x >= x1 - edge))
        img[top] *= hi
        img[bottom & ~top] *= lo
    return img


def grid_rects(size, cols, rows, gap=0):
    w, h = size // cols, size // rows
    return [(c * w + gap, r * h + gap, (c + 1) * w - gap, (r + 1) * h - gap)
            for r in range(rows) for c in range(cols)]


def dots(img, points, color, r=1):
    s = img.shape[0]
    y, x = np.mgrid[0:s, 0:s]
    for px, py in points:
        m = (np.abs(x - px) <= r) & (np.abs(y - py) <= r)
        img[m] = color
        img[(x == px - r) & (y == py - r)] = np.array(color) * 1.4
    return img


def scratches(img, seed, count, color, length=6):
    r = np.random.default_rng(seed)
    s = img.shape[0]
    for _ in range(count):
        x, y = r.integers(0, s, 2)
        dx, dy = r.choice([-1, 1]), r.choice([-1, 0, 1])
        for i in range(length):
            img[(y + dy * i // 2) % s, (x + dx * i) % s] = color
    return img


def save(name, img):
    img = np.clip(img, 0, 255).astype(np.uint8)
    Image.fromarray(img, "RGB").save(OUT / f"{name}.png")
    print("wrote", name)


# --- level surfaces --------------------------------------------------------

def concrete():
    """Platform sides: big weathered stone blocks, warm light grey (tinted per zone)."""
    s = 128
    st = strokes(s, 4, 4, 1, 2)
    img = mix(st, (150, 146, 138), (196, 192, 182))
    cool = strokes(s, 3, 3, 2, 3)
    img = img * (1 - 0.12 * cool[..., None]) + np.array([-6, 0, 10]) * cool[..., None]
    rows = [(0, 0, 80, 48), (80, 0, 128, 48), (0, 48, 48, 96), (48, 48, 128, 96), (0, 96, 96, 128), (96, 96, 128, 128)]
    img = panels(img, rows, hi=1.22, lo=0.6, edge=3, grad=0.08)
    # a few painted cracks
    r = np.random.default_rng(3)
    for _ in range(4):
        x, y = r.integers(0, s, 2)
        for i in range(14):
            x = (x + r.integers(-1, 2)) % s
            y = (y + 1) % s
            img[y, x] *= 0.55
    save("concrete", img)


def metal_floor():
    """Platform tops: big painted steel plates with bevels and bright rivets."""
    s = 128
    st = strokes(s, 4, 4, 11, 2)
    img = mix(st, (150, 156, 160), (192, 196, 198))
    img = panels(img, grid_rects(s, 2, 2), hi=1.25, lo=0.55, edge=3, grad=0.1)
    pts = [(x, y) for x in (8, 56, 72, 120) for y in (8, 56, 72, 120)]
    img = dots(img, pts, (215, 218, 220), 1)
    # diagonal tread lines on alternating plates
    y, x = np.mgrid[0:s, 0:s]
    tread = ((x + y) % 12 == 0) & (((x // 64) + (y // 64)) % 2 == 0) & (x % 64 > 6) & (x % 64 < 58) & (y % 64 > 6) & (y % 64 < 58)
    img[tread] *= 1.12
    scratches(img, 12, 10, (205, 205, 200), 7)
    save("metal_floor", img)


def wall_panel():
    """Wallrun walls: rich blue plates with a bold white chevron guide stripe."""
    s = 128
    st = strokes(s, 4, 4, 21, 2)
    img = mix(st, (40, 92, 190), (70, 130, 225))
    img = panels(img, grid_rects(s, 2, 2), hi=1.3, lo=0.6, edge=3)
    y, x = np.mgrid[0:s, 0:s]
    stripe = (y >= 52) & (y < 76)
    img[stripe] = mix(st[stripe], (225, 230, 236), (250, 250, 250))
    img[(y == 52) | (y == 53)] = (255, 255, 255)
    img[(y == 74) | (y == 75)] = (150, 160, 180)
    chevron = stripe & (((x + 1.3 * np.abs(y - 63.5)).astype(int) % 32) < 10)
    img[chevron] = (30, 70, 160)
    img[chevron & (((x + 1.3 * np.abs(y - 63.5)).astype(int) % 32) == 0)] = (90, 140, 220)
    scratches(img, 22, 8, (150, 185, 235), 5)
    save("wall_panel", img)


def hazard():
    """Grapple anchors: saturated yellow-orange and charcoal stripes in a bevelled frame."""
    s = 64
    y, x = np.mgrid[0:s, 0:s]
    st = strokes(s, 3, 3, 31, 1)
    stripe = ((x + y) % 32) < 16
    img = np.where(stripe[..., None], mix(st, (240, 150, 30), (255, 196, 60)), mix(st, (36, 34, 40), (60, 58, 66)))
    img = panels(img, [(0, 0, 64, 64)], hi=1.3, lo=0.55, edge=4, grad=0.15)
    save("hazard", img)


def crate():
    """Cover: chunky olive military crate, bevelled planks and a painted stencil."""
    s = 64
    st = strokes(s, 3, 4, 41, 1)
    img = mix(st, (96, 112, 58), (128, 142, 76))
    planks = [(x0, 6, x0 + 13, 58) for x0 in (6, 19, 32, 45)]
    img = panels(img, planks, hi=1.15, lo=0.75, edge=1, grad=0.1)
    img = panels(img, [(0, 0, 64, 64)], hi=1.3, lo=0.55, edge=6, grad=0.0)
    y, x = np.mgrid[0:s, 0:s]
    sten = (y >= 36) & (y < 46) & (x >= 22) & (x < 42) & ~(((x - 22) % 7 == 6) | (y == 40))
    img[sten] = (232, 220, 160)
    img = dots(img, [(3, 3), (60, 3), (3, 60), (60, 60)], (200, 205, 170), 1)
    save("crate", img)


def barrier():
    """Low cover walls: smooth painted stone with a hazard band along the top edge."""
    s = 64
    st = strokes(s, 3, 4, 141, 1)
    img = mix(st, (170, 166, 156), (204, 200, 188))
    y, x = np.mgrid[0:s, 0:s]
    t = y / (s - 1)
    img *= (1.08 - 0.25 * t)[..., None]  # painted grime gathering at the foot
    band = y < 12
    stripe = ((x + y) % 16) < 8
    img[band & stripe] = (250, 196, 40)
    img[band & ~stripe] = (40, 38, 44)
    img[y == 0] *= 1.4
    img[(y == 12) | (y == 13)] *= 0.55
    save("barrier", img)


def lava():
    s = 64
    a = strokes(s, 3, 5, 51, 2)
    b = strokes(s, 6, 3, 52, 1)
    t = np.clip(a * 0.8 + b * 0.4 - 0.2, 0, 1)
    img = mix(t, (150, 20, 10), (255, 190, 60))
    save("lava", img)


# --- character and prop surfaces --------------------------------------------

def gunmetal():
    """Guns and props: blue-black steel with bright painted edge highlights."""
    s = 64
    st = strokes(s, 3, 3, 61, 1)
    img = mix(st, (52, 58, 72), (78, 86, 104))
    img = panels(img, grid_rects(s, 1, 2), hi=1.6, lo=0.6, edge=2, grad=0.2)
    y, x = np.mgrid[0:s, 0:s]
    img[(x % 8 < 2) & (y > 4) & (y < 14)] *= 0.6  # slide serrations
    save("gunmetal", img)


def glove():
    """Gloves and boots: warm brown leather with a painted sheen."""
    s = 64
    st = strokes(s, 3, 4, 71, 2)
    img = mix(st, (70, 50, 36), (112, 82, 58))
    y, x = np.mgrid[0:s, 0:s]
    img *= (1.15 - 0.3 * (y / s))[..., None]
    img[(y % 32 == 16) & (x % 4 < 2)] = (170, 140, 100)  # stitching
    save("glove", img)


def fabric():
    """Grunt fatigues: soft, chunky olive camo blobs, like painted cloth."""
    s = 64
    a = blur(noise(s, 3, 2, 81), 1)
    b = blur(noise(s, 4, 2, 82), 1)
    img = np.ones((s, s, 3)) * np.array([104, 112, 70], float)
    img[a > 0.56] = (78, 88, 52)
    img[(b > 0.6) & (a <= 0.56)] = (134, 128, 88)
    img[a < 0.32] = (60, 64, 44)
    img = np.stack([blur(img[..., c], 1) for c in range(3)], axis=-1)
    y, x = np.mgrid[0:s, 0:s]
    img *= (1.0 + 0.04 * ((x + y) % 2))[..., None]
    save("fabric", img)


def armor():
    """Grunt plates and helmets: sage green ceramic with bevelled edges."""
    s = 64
    st = strokes(s, 3, 4, 91, 1)
    img = mix(st, (108, 124, 98), (142, 156, 126))
    img = panels(img, [(0, 0, 64, 32), (0, 32, 64, 64)], hi=1.35, lo=0.6, edge=2, grad=0.18)
    scratches(img, 92, 5, (190, 200, 175), 4)
    save("armor", img)


def titan_armor():
    """Titan hull: big pale plates (tinted per chassis) with bold bevels, painted
    edge wear, rivet rows and a unit number."""
    s = 128
    st = strokes(s, 4, 4, 101, 2)
    img = mix(st, (176, 176, 172), (214, 214, 208))
    plates = [(0, 0, 88, 64), (88, 0, 128, 64), (0, 64, 40, 128), (40, 64, 128, 96), (40, 96, 128, 128)]
    img = panels(img, plates, hi=1.25, lo=0.5, edge=3, grad=0.14)
    # painted wear: pale chips just inside the lit edges
    wear = (noise(s, 16, 1, 102) > 0.72)
    y, x = np.mgrid[0:s, 0:s]
    near_edge = np.zeros((s, s), bool)
    for x0, y0, x1, y1 in plates:
        near_edge |= ((y >= y0 + 3) & (y < y0 + 6) & (x >= x0) & (x < x1)) | ((x >= x0 + 3) & (x < x0 + 6) & (y >= y0) & (y < y1))
    img[wear & near_edge] = (236, 234, 226)
    rivets = [(xx, yy) for yy in (8, 56, 72, 120) for xx in range(10, s, 16)]
    img = dots(img, rivets, (120, 120, 118), 1)
    digits = (y >= 72) & (y < 88) & (x >= 60) & (x < 84) & ((((x - 60) // 4) % 2 == 0) | ((y - 72) % 8 < 2))
    img[digits] = (250, 250, 240)
    save("titan_armor", img)


def titan_frame():
    """Titan joints and inner frame: dark machinery with lit ribs and hoses."""
    s = 64
    st = strokes(s, 3, 3, 111, 1)
    img = mix(st, (50, 52, 60), (74, 76, 86))
    y, x = np.mgrid[0:s, 0:s]
    img[(y % 8) == 0] *= 1.6
    img[(y % 8) == 7] *= 0.55
    hose = (np.abs(x - 20) < 4)
    img[hose] = mix(np.clip(1 - np.abs(x[hose] - 20) / 4, 0, 1), (60, 44, 30), (130, 96, 60))
    img = dots(img, [(44, 8 + i * 16) for i in range(4)], (170, 170, 180), 1)
    save("titan_frame", img)


def sky():
    """Panorama layers in the red/green/blue channels, tinted per zone by the sky shader:
    R = cloud density (soft, painted), G = far mountain range, B = near ridge."""
    w, h = 512, 128
    clouds = np.zeros((h, w))
    r = np.random.default_rng(121)
    for o, (cx, cy) in enumerate([(12, 3), (24, 6), (48, 12)]):
        grid = r.random((cy + 1, cx))
        ys = np.linspace(0, cy, h)
        xs = np.arange(w) * cx / w
        x0 = np.floor(xs).astype(int)
        y0 = np.floor(ys).astype(int)
        fx = xs - x0
        fy = ys - y0
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
    band = np.clip(1.0 - np.abs(rows - 0.5) * 2.0, 0, 1)
    clouds = np.clip((clouds - 0.42) * 2.6, 0, 1) * band
    clouds = np.round(clouds * 6) / 6  # painted bands, softened below
    for _ in range(2):
        clouds = (clouds + np.roll(clouds, 1, 0) + np.roll(clouds, -1, 0) + np.roll(clouds, 1, 1) + np.roll(clouds, -1, 1)) / 5

    def ridge(seed, base, amp, cells):
        rr = np.random.default_rng(seed)
        pts = rr.random(cells)
        xs = np.arange(w) * cells / w
        i0 = np.floor(xs).astype(int)
        f = xs - i0
        f = f * f * (3 - 2 * f)
        line = pts[i0] * (1 - f) + pts[(i0 + 1) % cells] * f
        fine = rr.random(cells * 6)
        xs2 = np.arange(w) * cells * 6 / w
        j0 = np.floor(xs2).astype(int)
        f2 = xs2 - j0
        line += 0.2 * (fine[j0] * (1 - f2) + fine[(j0 + 1) % (cells * 6)] * f2)
        height = base + amp * line
        y_from_bottom = (h - 1 - np.arange(h))[:, None]
        return (y_from_bottom < height[None, :] * h).astype(float)

    far = ridge(131, 0.10, 0.36, 7)
    near = ridge(132, 0.04, 0.16, 12)
    img = np.stack([clouds, far, near], axis=-1) * 255
    Image.fromarray(img.astype(np.uint8), "RGB").save(OUT / "sky.png")
    print("wrote sky")


# --- temple hub ------------------------------------------------------------

def temple_stone():
    """Temple walls: big weathered sandstone blocks in staggered courses, warm ochre
    with cool shadowed mortar and moss creeping along the joints."""
    s = 128
    st = strokes(s, 4, 4, 161, 2)
    img = mix(st, (168, 138, 98), (212, 182, 134))
    cool = strokes(s, 3, 3, 162, 3)
    img = img * (1 - 0.1 * cool[..., None]) + np.array([-8, -2, 8]) * cool[..., None]
    courses = [(0, 0, 56, 32), (56, 0, 128, 32), (0, 32, 32, 64), (32, 32, 96, 64), (96, 32, 128, 64),
               (0, 64, 72, 96), (72, 64, 128, 96), (0, 96, 40, 128), (40, 96, 104, 128), (104, 96, 128, 128)]
    img = panels(img, courses, hi=1.2, lo=0.55, edge=3, grad=0.1)
    y, x = np.mgrid[0:s, 0:s]
    joint = np.zeros((s, s), bool)
    for x0, y0, x1, y1 in courses:
        joint |= (y >= y1 - 3) & (y < y1) & (x >= x0) & (x < x1)
    moss = joint & (noise(s, 8, 2, 163) > 0.5)
    img[moss] = mix(strokes(s, 6, 3, 164, 0)[moss], (70, 98, 48), (104, 134, 62))
    r = np.random.default_rng(165)
    for _ in range(5):
        cx, cy = r.integers(0, s, 2)
        for i in range(12):
            cx = (cx + r.integers(-1, 2)) % s
            cy = (cy + 1) % s
            img[cy, cx] *= 0.55
    save("temple_stone", img)


def temple_floor():
    """Temple floor and stair tops: worn square flagstones, warm in the middle,
    darker and mossy in the gaps."""
    s = 128
    st = strokes(s, 4, 4, 171, 2)
    img = mix(st, (150, 128, 96), (196, 172, 130))
    img = panels(img, grid_rects(s, 2, 2, 1), hi=1.15, lo=0.62, edge=3, grad=0.06)
    y, x = np.mgrid[0:s, 0:s]
    gap = ((x % 64) < 2) | ((y % 64) < 2)
    img[gap] = mix(noise(s, 8, 1, 172)[gap], (58, 70, 44), (88, 110, 58))
    worn = blur((noise(s, 2, 2, 173) > 0.55).astype(float), 3)
    img *= (1.0 + 0.1 * worn)[..., None]
    scratches(img, 174, 6, (120, 100, 76), 6)
    save("temple_floor", img)


def temple_carving():
    """Friezes and the idol: a carved band of the precursor god's eye glyph between
    rows of step-fret, deep-cut so it reads in the haze."""
    s = 128
    st = strokes(s, 4, 4, 181, 2)
    img = mix(st, (150, 132, 104), (196, 176, 136))
    y, x = np.mgrid[0:s, 0:s]
    lit, shade = 1.25, 0.45
    # step-fret borders top and bottom
    for y0 in (4, 108):
        band = (y >= y0) & (y < y0 + 16)
        fret = band & ((((x // 8) + ((y - y0) // 8)) % 2) == 0)
        img[fret] *= shade
        img[band & (y == y0)] *= lit
    # the eye glyph, one per half tile: almond outline, ring, pupil, rays
    for cx in (32, 96):
        cy = 64
        dx, dy = (x - cx) / 26.0, (y - cy) / 14.0
        almond = np.abs(dy) + dx * dx * 0.9 < 1.0
        outline = almond & ~(np.abs(dy) * 1.25 + dx * dx * 1.1 < 1.0)
        rr = np.sqrt((x - cx) ** 2 + (y - cy) ** 2)
        ring = (rr > 6.5) & (rr < 9.5)
        pupil = rr < 3.5
        rays = (np.abs(x - cx) < 2) & (np.abs(y - cy) > 16) & (np.abs(y - cy) < 26)
        cut = outline | ring | pupil | rays
        img[cut] *= shade
        # light catches the upper lip of each cut
        img[np.roll(cut, 1, axis=0) & ~cut] *= lit
    save("temple_carving", img)


def moss():
    """Overgrowth: vines, hanging moss and the courtyard turf, soft leafy clumps."""
    s = 64
    a = blur(noise(s, 4, 3, 191), 1)
    b = strokes(s, 6, 4, 192, 1)
    img = mix(b, (52, 86, 40), (110, 150, 64))
    img[a > 0.62] = mix(b[a > 0.62], (128, 168, 74), (160, 190, 92))
    img[a < 0.3] *= 0.7
    y, x = np.mgrid[0:s, 0:s]
    img = dots(img, [(9, 14), (40, 6), (52, 44), (20, 50), (30, 28)], (196, 168, 80), 0)
    save("moss", img)


def wood():
    """Her workbench, crates and shelves: warm planks with painted grain."""
    s = 64
    y, x = np.mgrid[0:s, 0:s]
    n = noise(s, 4, 2, 201)
    grain = (np.sin(y * 0.8 + n * 7.0) * 0.5 + 0.5)
    img = mix(np.floor(grain * 3) / 2, (110, 72, 42), (158, 108, 62))
    planks = [(0, y0, 64, y0 + 16) for y0 in (0, 16, 32, 48)]
    img = panels(img, planks, hi=1.2, lo=0.6, edge=1, grad=0.08)
    img = dots(img, [(4, 8), (60, 8), (4, 40), (60, 40)], (70, 66, 62), 0)
    save("wood", img)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for fn in (concrete, metal_floor, wall_panel, hazard, crate, barrier, lava, gunmetal, glove,
               fabric, armor, titan_armor, titan_frame, sky, temple_stone, temple_floor,
               temple_carving, moss, wood):
        # `make_textures.py moss wood` repaints only the named textures.
        if len(sys.argv) < 2 or fn.__name__ in sys.argv[1:]:
            fn()
