#!/usr/bin/env python3
"""Paints the game's textures into assets/textures/.

The style is stylized PS3 (think Jak 3, Ratchet & Clank Future, Uncharted's
painted ruins): the same warm, saturated palette and chunky shapes as the old
PS2 set, but at 512 to 1024 px with real surface detail. Every texture is
built from a height field, so each one comes as two files:

  <name>.png     RGB albedo, A roughness (0 glossy .. 255 matte)
  <name>_n.png   RG tangent normal (OpenGL, green up), B dielectric mask
                 (255 paint/stone/cloth, 0 bare metal; the material's
                 `metal_mask` says how much it counts)

Every texture tiles. Grey textures are tinted in the material, so one stone
texture serves every zone. The shader (assets/shaders/ps2_surface.gdshader)
reads both; with the PS2 look on (F9) it drops the normal map and samples a
low mip so the old blurry look comes back.

    python3 tools/make_textures.py            (needs pillow and numpy)
    python3 tools/make_textures.py moss wood  (repaints only those)
    python3 tools/make_textures.py --half     (half size, for quick looks)

Re-running overwrites the PNGs. Paint over them by hand if you like; the game
only cares about the file names.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent.parent / "assets" / "textures"
BIG = 1024
SMALL = 512


# --- noise and filters (tileable) ------------------------------------------

def noise(size, cells, octaves=3, seed=0, cells_y=None, gain=0.5):
    """Tileable value noise in 0..1. `cells_y` stretches it (streaks, grain)."""
    r = np.random.default_rng(seed)
    total = np.zeros((size, size))
    amp, norm = 1.0, 0.0
    cy0 = cells if cells_y is None else cells_y
    for o in range(octaves):
        cx, cy = cells * (2 ** o), cy0 * (2 ** o)
        grid = r.random((cy, cx))
        ax = np.arange(size) * cx / size
        ay = np.arange(size) * cy / size
        ix0, iy0 = np.floor(ax).astype(int), np.floor(ay).astype(int)
        fx, fy = ax - ix0, ay - iy0
        fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
        ix1, iy1 = (ix0 + 1) % cx, (iy0 + 1) % cy
        a = grid[np.ix_(iy0, ix0)]
        b = grid[np.ix_(iy0, ix1)]
        c = grid[np.ix_(iy1, ix0)]
        d = grid[np.ix_(iy1, ix1)]
        fx, fy = fx[None, :], fy[:, None]
        total += amp * ((a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy)
        norm += amp
        amp *= gain
    return total / norm


def norm01(a):
    return (a - a.min()) / (a.max() - a.min() + 1e-9)


def blur(a, r=1):
    """Tile-wrapping blur. Small radii are a box blur (as the old painter had),
    bigger ones a gaussian of about that radius done in frequency space."""
    if r <= 0:
        return a.astype(float)
    if r <= 2:
        out = np.zeros_like(a, dtype=float)
        n = 0
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                out += np.roll(np.roll(a, dy, axis=0), dx, axis=1)
                n += 1
        return out / n
    return gauss(a, r * 0.6)


def gauss(a, sigma):
    if a.ndim == 3:
        return np.stack([gauss(a[..., c], sigma) for c in range(a.shape[2])], axis=-1)
    h, w = a.shape
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.rfftfreq(w)[None, :]
    k = np.exp(-2 * (np.pi * sigma) ** 2 * (fx * fx + fy * fy))
    return np.fft.irfft2(np.fft.rfft2(a) * k, s=a.shape)


def worley(size, cells, seed, jitter=0.9):
    """Tileable cellular noise: distance to nearest and second-nearest point
    (in cell units) and the id of the nearest cell."""
    r = np.random.default_rng(seed)
    pts = 0.5 + (r.random((cells, cells, 2)) - 0.5) * jitter
    y, x = np.mgrid[0:size, 0:size] * (cells / size)
    ix, iy = np.floor(x).astype(int), np.floor(y).astype(int)
    d1 = np.full((size, size), 9.0)
    d2 = np.full((size, size), 9.0)
    ids = np.zeros((size, size), int)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            cx, cy = (ix + dx) % cells, (iy + dy) % cells
            px = ix + dx + pts[cy, cx, 0]
            py = iy + dy + pts[cy, cx, 1]
            d = np.hypot(x - px, y - py)
            closer = d < d1
            d2 = np.where(closer, d1, np.minimum(d2, d))
            ids = np.where(closer, cy * cells + cx, ids)
            d1 = np.where(closer, d, d1)
    return d1, d2, ids


def warp(a, amount, seed, cells=4):
    """Domain-warps a map by tileable noise (in pixels)."""
    s = a.shape[0]
    wx = (noise(s, cells, 3, seed) - 0.5) * 2 * amount
    wy = (noise(s, cells, 3, seed + 1) - 0.5) * 2 * amount
    y, x = np.mgrid[0:s, 0:s]
    return a[(y + wy).astype(int) % s, (x + wx).astype(int) % s]


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def mix(t, c1, c2):
    t = np.asarray(t, float)[..., None]
    return np.array(c1, float) * (1 - t) + np.array(c2, float) * t


def strokes(size, cells, levels, seed, soften=1):
    """Soft banded 'brush strokes': noise posterized into a few values, then
    softened. Keeps the painted feel under the new detail."""
    n = norm01(noise(size, cells, 2, seed))
    q = np.floor(n * levels) / max(levels - 1, 1)
    return gauss(q, soften * size / 128.0) if soften else q


def coords(s):
    y, x = np.mgrid[0:s, 0:s]
    return x, y


# --- shapes ------------------------------------------------------------------

def rects_px(s, rects, base=128):
    """Scales a layout drawn on a `base` px tile to `s` px."""
    k = s / base
    return [tuple(int(round(v * k)) for v in r) for r in rects]


def grid_rects(size, cols, rows, gap=0):
    w, h = size // cols, size // rows
    return [(c * w + gap, r * h + gap, (c + 1) * w - gap, (r + 1) * h - gap)
            for r in range(rows) for c in range(cols)]


def plates(s, rects, bevel, seed=0, chip=0.0, round_=True):
    """Height of raised plates: 1 on the face, rolling off over `bevel` px to 0
    in the seams. `chip` (px) roughens the bevel so edges look knocked about.
    Returns (height, id map, edge distance in px)."""
    x, y = coords(s)
    h = np.zeros((s, s))
    ids = np.full((s, s), -1)
    dist = np.zeros((s, s))
    rough = (noise(s, 24, 3, seed + 900) - 0.5) * 2 * chip if chip else 0.0
    for i, (x0, y0, x1, y1) in enumerate(rects):
        inside = (x >= x0) & (x < x1) & (y >= y0) & (y < y1)
        d = np.minimum(np.minimum(x - x0, x1 - 1 - x), np.minimum(y - y0, y1 - 1 - y)).astype(float)
        d = d + rough
        t = np.clip(d / bevel, 0, 1)
        prof = 1 - (1 - t) ** 2 if round_ else t
        h = np.where(inside, prof, h)
        ids = np.where(inside, i, ids)
        dist = np.where(inside, d, dist)
    return h, ids, dist


def per_id(ids, seed, lo=-1.0, hi=1.0):
    """A random value per plate id (for tone variation between plates)."""
    r = np.random.default_rng(seed)
    vals = r.uniform(lo, hi, ids.max() + 2)
    return vals[ids + 1]


def lines_mask(s, segs, width):
    """Anti-aliased lines (tile-wrapped). segs: list of point lists in px."""
    im = Image.new("L", (s * 3, s * 3), 0)
    dr = ImageDraw.Draw(im)
    for pts in segs:
        for ox in (0, s, 2 * s):
            for oy in (0, s, 2 * s):
                dr.line([(px + ox, py + oy) for px, py in pts], fill=255, width=max(1, int(width)), joint="curve")
    a = np.asarray(im, float) / 255.0
    a = a.reshape(3, s, 3, s).max(axis=(0, 2))
    return gauss(a, max(width * 0.25, 0.6))


def walks(s, count, length, step, seed, wander=0.6, down=True):
    """Random-walk polylines (cracks, scratches)."""
    r = np.random.default_rng(seed)
    out = []
    for _ in range(count):
        px, py = r.uniform(0, s, 2)
        ang = r.uniform(0, np.pi * 2) if not down else np.pi / 2 + r.uniform(-0.6, 0.6)
        pts = [(px, py)]
        for _ in range(length):
            ang += r.uniform(-wander, wander)
            px += np.cos(ang) * step
            py += np.sin(ang) * step
            pts.append((px, py))
        out.append(pts)
    return out


def scratch_segs(s, count, seed, length=0.08):
    r = np.random.default_rng(seed)
    out = []
    for _ in range(count):
        x, y = r.uniform(0, s, 2)
        a = r.uniform(0, np.pi)
        l = s * length * r.uniform(0.4, 1.0)
        out.append([(x, y), (x + np.cos(a) * l, y + np.sin(a) * l)])
    return out


def dome(s, points, radius):
    """Round bumps (rivets, bolts, pebbles) at px points, tile-wrapped."""
    x, y = coords(s)
    h = np.zeros((s, s))
    for px, py in points:
        dx = (x - px + s / 2) % s - s / 2
        dy = (y - py + s / 2) % s - s / 2
        d = np.sqrt(dx * dx + dy * dy) / radius
        h = np.maximum(h, np.sqrt(np.clip(1 - d * d, 0, 1)))
    return h


def text_mask(s, text, cx, cy, size, font_px=None, stencil=True):
    """Stencilled lettering, centred at px (cx, cy)."""
    font = ImageFont.load_default(size=font_px or size)
    im = Image.new("L", (s, s), 0)
    dr = ImageDraw.Draw(im)
    dr.text((cx, cy), text, fill=255, font=font, anchor="mm")
    a = np.asarray(im, float) / 255.0
    if stencil:
        # stencil bridges: thin horizontal gaps through the letters
        _, y = coords(s)
        a *= ~((np.abs(y - cy) < size * 0.04))
    return a


def cavity(h, r):
    """How far a point sits below its neighbourhood (grooves, seams, pits)."""
    return np.clip(gauss(h, r) - h, 0, None)


def convex(h, r):
    """How far a point stands above its neighbourhood (edges, bumps)."""
    return np.clip(h - gauss(h, r), 0, None)


def grime(s, seed, amount=0.25, cells=3):
    """Low, soft dirt blotches (multiply)."""
    g = norm01(noise(s, cells, 4, seed))
    return 1.0 - amount * smooth(0.45, 0.9, g)


def rain_streaks(s, seed, amount=0.15):
    """Vertical dirt runs down a wall face (multiply)."""
    st = norm01(noise(s, 24, 3, seed, cells_y=2))
    return 1.0 - amount * smooth(0.55, 0.95, st)


def grain(s, seed, amount=6.0, cells=128):
    """Fine colour grain so close-ups never look flat."""
    return (noise(s, cells, 2, seed) - 0.5)[..., None] * 2 * amount


# --- output --------------------------------------------------------------------

def save(name, img, height=None, rough=None, depth=4.0, metal=None, ao=0.6, ao_radius=None):
    """Writes <name>.png (RGB albedo + A roughness) and <name>_n.png (normal +
    dielectric mask). `depth` is how many pixels tall a height of 1 is: bigger
    is bumpier. Seams and pits are darkened by `ao`."""
    s = img.shape[0]
    img = np.asarray(img, float)
    if height is not None:
        h = height * depth
        if ao > 0:
            r = ao_radius or max(s / 128.0, 2.0)
            occ = np.clip(cavity(h, r) / max(depth * 0.35, 1e-3), 0, 1)
            img = img * (1 - ao * occ)[..., None]
        gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5
        gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5
        n = np.stack([-gx, gy, np.ones_like(h)], axis=-1)
        n /= np.linalg.norm(n, axis=-1, keepdims=True)
    else:
        n = np.zeros((s, s, 3))
        n[..., 2] = 1
    rough = np.full((s, s), 0.8) if rough is None else np.broadcast_to(rough, (s, s))
    metal = np.zeros((s, s)) if metal is None else np.broadcast_to(metal, (s, s))
    rgba = np.concatenate([np.clip(img, 0, 255), np.clip(rough, 0, 1)[..., None] * 255], axis=-1)
    Image.fromarray(rgba.astype(np.uint8), "RGBA").save(OUT / f"{name}.png", optimize=True)
    nm = np.stack([n[..., 0] * 0.5 + 0.5, n[..., 1] * 0.5 + 0.5, 1 - np.clip(metal, 0, 1)], axis=-1)
    Image.fromarray((nm * 255 + 0.5).astype(np.uint8), "RGB").save(OUT / f"{name}_n.png", optimize=True)
    print("wrote", name, s)


# --- level surfaces --------------------------------------------------------

def concrete():
    """Platform sides and rocks: big weathered stone blocks, warm light grey
    (tinted per zone), chipped edges, pitting, cracks and rain streaks."""
    s = BIG
    rects = rects_px(s, [(0, 0, 80, 48), (80, 0, 128, 48), (0, 48, 48, 96), (48, 48, 128, 96), (0, 96, 96, 128), (96, 96, 128, 128)])
    h, ids, _ = plates(s, rects, s * 0.03, seed=1, chip=s * 0.012)
    tone = per_id(ids, 2, -0.06, 0.06)
    st = strokes(s, 4, 4, 1, 2)
    img = mix(st, (150, 146, 138), (192, 188, 178))
    cool = strokes(s, 3, 3, 2, 3)
    img = img * (1 - 0.1 * cool[..., None]) + np.array([-6, 0, 10]) * cool[..., None]
    img *= (1 + tone)[..., None]
    # surface: soft lumps, pits and fine grit
    lumps = noise(s, 8, 5, 4)
    d1, _, _ = worley(s, 24, 5)
    pits = smooth(0.1, 0.0, d1) * smooth(0.6, 0.7, noise(s, 6, 2, 6))
    hh = h + (lumps - 0.5) * 0.25 - pits * 0.25 + (noise(s, 128, 2, 7) - 0.5) * 0.06
    crack = lines_mask(s, walks(s, 7, 40, s / 160, 3), s / 340)
    hh -= crack * 0.6
    img *= (1 - 0.3 * crack)[..., None]
    img *= rain_streaks(s, 8, 0.12)[..., None] * grime(s, 9, 0.18)[..., None]
    img *= (1 + 0.12 * np.clip(convex(hh, s / 200) * 6, 0, 1))[..., None]  # dusty lit edges
    img += grain(s, 10, 5)
    rough = 0.85 + 0.1 * pits - 0.08 * convex(hh, s / 200)
    save("concrete", img, hh, rough, depth=s / 90)


def metal_floor():
    """Platform tops: big painted steel plates, raised diamond tread on every
    other plate, domed rivets, scuffed bare steel where boots wear it down."""
    s = BIG
    rects = grid_rects(s, 2, 2)
    h, ids, dist = plates(s, rects, s * 0.02, seed=11, chip=s * 0.004)
    tone = per_id(ids, 12, -0.05, 0.05)
    st = strokes(s, 4, 4, 11, 2)
    img = mix(st, (146, 152, 156), (184, 188, 190))
    img *= (1 + tone)[..., None]
    x, y = coords(s)
    half = s // 2
    alt = (((x // half) + (y // half)) % 2 == 0) & (dist > s * 0.04)
    # diamond plate: two crossing sets of short raised lozenges
    p = s / 32
    u, v = (x % p) / p - 0.5, (y % p) / p - 0.5
    lz1 = np.clip(1 - (np.abs(u + v) * 4.5 + np.abs(u - v) * 1.4), 0, 1)
    u2, v2 = ((x + p / 2) % p) / p - 0.5, ((y + p / 2) % p) / p - 0.5
    lz2 = np.clip(1 - (np.abs(u2 - v2) * 4.5 + np.abs(u2 + v2) * 1.4), 0, 1)
    tread = np.where(alt, np.maximum(lz1, lz2) ** 0.6, 0)
    hh = h + tread * 0.18
    off = s * 0.035
    pts = [(cx, cy) for cx in (off, half - off, half + off, s - off) for cy in (off, half - off, half + off, s - off)]
    pts += [(cx, cy) for cy in (off, half - off, half + off, s - off) for cx in np.linspace(off, s - off, 9)[1:-1:2]]
    riv = dome(s, pts, s * 0.009)
    hh = np.maximum(hh, h + riv * 0.35)
    # wear: bare steel on raised tread, rivets and the most-walked middle
    walk = smooth(0.4, 0.75, noise(s, 3, 3, 13))
    wear = np.clip(tread * 1.2 * walk + riv * 0.8 + convex(hh, s / 300) * 8, 0, 1)
    wear = np.clip(wear * (noise(s, 64, 2, 14) * 1.6), 0, 1)
    bare = mix(noise(s, 96, 2, 15), (170, 172, 176), (210, 212, 214))
    img = img * (1 - wear[..., None]) + bare * wear[..., None]
    sc = lines_mask(s, scratch_segs(s, 90, 16, 0.05), s / 700)
    img = img * (1 - 0.35 * sc[..., None]) + np.array([215, 215, 212]) * 0.35 * sc[..., None]
    img *= grime(s, 17, 0.2)[..., None]
    seam = np.clip(1 - h, 0, 1)
    img *= (1 - 0.3 * seam)[..., None]
    img += grain(s, 18, 4)
    rough = 0.55 - 0.25 * wear - 0.15 * sc + 0.2 * seam
    save("metal_floor", img, hh, rough, depth=s / 110, metal=np.clip(wear + sc, 0, 1))


def wall_panel():
    """Wallrun walls: rich blue enamel plates with a bold white chevron guide
    stripe, bolted seams, and paint flaked back to steel at the edges."""
    s = BIG
    rects = grid_rects(s, 2, 2)
    h, ids, dist = plates(s, rects, s * 0.025, seed=21, chip=s * 0.006)
    tone = per_id(ids, 22, -0.05, 0.05)
    st = strokes(s, 4, 4, 21, 2)
    img = mix(st, (36, 88, 186), (62, 124, 220)) * (1 + tone)[..., None]
    x, y = coords(s)
    k = s / 128
    stripe = (y >= 52 * k) & (y < 76 * k)
    img = np.where(stripe[..., None], mix(st, (222, 228, 236), (246, 248, 250)), img)
    phase = ((x + 1.3 * np.abs(y - 63.5 * k)) % (32 * k))
    chevron = stripe & (phase < 10 * k)
    img = np.where(chevron[..., None], np.array([28, 66, 156], float), img)
    # the stripe is a raised decal strip with a lip
    strip_h = smooth(52 * k, 53.5 * k, y) * smooth(76 * k, 74.5 * k, y) * 0.12
    hh = h + strip_h
    bolts = [(cx, cy) for cx in np.arange(s / 16, s, s / 8) for cy in (s * 0.03, s * 0.47, s * 0.53, s * 0.97)]
    b = dome(s, bolts, s * 0.008)
    hh = np.maximum(hh, h + b * 0.3)
    # chipped paint
    chip_mask = smooth(0.74, 0.77, noise(s, 24, 4, 23) + np.clip(1 - dist / (s * 0.03), 0, 1) ** 2 * 0.3)
    chip_mask = np.clip(chip_mask + b * 0.8, 0, 1)
    steel = mix(noise(s, 96, 2, 24), (150, 156, 164), (196, 200, 206))
    img = img * (1 - chip_mask[..., None]) + steel * chip_mask[..., None]
    hh -= chip_mask * 0.05
    img *= rain_streaks(s, 25, 0.14)[..., None] * grime(s, 26, 0.12)[..., None]
    img *= (1 - 0.35 * np.clip(1 - h, 0, 1))[..., None]
    img += grain(s, 27, 4)
    rough = 0.38 + 0.15 * noise(s, 8, 3, 28) + 0.2 * chip_mask
    save("wall_panel", img, hh, rough, depth=s / 120, metal=chip_mask)


def hazard():
    """Grapple anchors: saturated yellow-orange and charcoal stripes on a heavy
    steel plate, paint worn through on the edges."""
    s = SMALL
    x, y = coords(s)
    st = strokes(s, 3, 3, 31, 1)
    stripe = ((x + y) % (s / 2)) < (s / 4)
    img = np.where(stripe[..., None], mix(st, (238, 148, 28), (255, 192, 56)), mix(st, (34, 32, 38), (58, 56, 64)))
    h, _, dist = plates(s, [(0, 0, s, s)], s * 0.07, seed=31, chip=s * 0.01)
    edge_wear = smooth(0.72, 0.76, noise(s, 16, 4, 32) + np.clip(1 - dist / (s * 0.09), 0, 1) ** 2 * 0.35)
    steel = mix(noise(s, 64, 2, 33), (140, 142, 148), (190, 192, 196))
    img = img * (1 - edge_wear[..., None]) + steel * edge_wear[..., None]
    hh = h + (noise(s, 16, 4, 34) - 0.5) * 0.06 - edge_wear * 0.04
    img *= grime(s, 35, 0.2)[..., None]
    img += grain(s, 36, 5, 64)
    rough = 0.5 + 0.15 * noise(s, 8, 2, 37) - 0.15 * edge_wear
    save("hazard", img, hh, rough, depth=s / 60, metal=edge_wear)


def crate():
    """Cover: chunky olive militia crate, painted planks with grain showing
    through, steel corner brackets and a stencilled marking."""
    s = SMALL
    k = s / 64
    planks = [(int(x0 * k), int(6 * k), int((x0 + 13) * k), int(58 * k)) for x0 in (6, 19, 32, 45)]
    frame, _, _ = plates(s, [(0, 0, s, s)], 6 * k, seed=41)
    ph, ids, _ = plates(s, planks, 1.5 * k, seed=42, chip=k * 0.6)
    x, y = coords(s)
    inner = (x >= 6 * k) & (x < 58 * k) & (y >= 6 * k) & (y < 58 * k)
    # the frame is proud of the planks
    hh = np.where(inner, 0.55 * ph, 0.55 + 0.45 * frame)
    gr = warp(np.sin(x / s * 2 * np.pi * 3 + noise(s, 4, 3, 43) * 8) * 0.5 + 0.5, 6 * k, 44)
    grain_v = warp(norm01(noise(s, 4, 4, 45, cells_y=1)), 3 * k, 46)
    wood_grain = np.clip(0.6 * grain_v + 0.4 * gr, 0, 1)
    st = strokes(s, 3, 4, 41, 1)
    img = mix(st, (92, 108, 56), (124, 138, 72))
    img *= (1 - 0.18 * wood_grain + per_id(ids, 47, -0.05, 0.05) * inner)[..., None]
    hh += wood_grain * 0.04 * inner
    sten = text_mask(s, "MIL-07", 32 * k, 41 * k, 9 * k)
    img = img * (1 - 0.85 * sten[..., None]) + np.array([228, 216, 156]) * 0.85 * sten[..., None]
    # steel corner brackets with bolts
    c = 12 * k
    corner = ((x < c) | (x >= s - c)) & ((y < c) | (y >= s - c))
    bolts = dome(s, [(4 * k, 4 * k), (s - 4 * k, 4 * k), (4 * k, s - 4 * k), (s - 4 * k, s - 4 * k)], 1.8 * k)
    hh = np.where(corner, 1.05, hh) + bolts * 0.15
    steel = mix(noise(s, 48, 2, 48), (84, 86, 82), (128, 130, 124))
    img = np.where(corner[..., None], steel, img)
    wear = smooth(0.62, 0.7, noise(s, 20, 4, 49) + convex(hh, 2 * k) * 6)
    img = img * (1 - 0.5 * wear[..., None]) + np.array([150, 140, 110]) * 0.5 * wear[..., None]
    img *= grime(s, 50, 0.22)[..., None]
    img += grain(s, 51, 5, 64)
    metal = np.clip(corner * 1.0, 0, 1)
    rough = np.where(corner, 0.45, 0.75 + 0.1 * wood_grain)
    save("crate", img, hh, rough, depth=s / 45, metal=metal)


def barrier():
    """Low cover walls: smooth cast concrete with a hazard band along the top,
    form-work lines, grime gathering at the foot."""
    s = SMALL
    x, y = coords(s)
    st = strokes(s, 3, 4, 141, 1)
    img = mix(st, (168, 164, 154), (202, 198, 186))
    t = y / (s - 1)
    img *= (1.06 - 0.25 * t)[..., None]
    band = y < s * 0.19
    stripe = ((x + y) % (s / 4)) < (s / 8)
    img = np.where((band & stripe)[..., None], np.array([248, 192, 36], float), img)
    img = np.where((band & ~stripe)[..., None], np.array([40, 38, 44], float), img)
    paint_wear = band & (noise(s, 24, 4, 142) > 0.62)
    img = np.where(paint_wear[..., None], mix(st, (150, 146, 138), (180, 176, 166)), img)
    # form-work tie holes and a seam
    holes = dome(s, [(s * 0.25, s * 0.6), (s * 0.75, s * 0.6)], s * 0.025)
    seam = lines_mask(s, [[(0, s * 0.62), (s, s * 0.62)]], s / 200)
    lump = noise(s, 8, 5, 143)
    hh = (lump - 0.5) * 0.3 - holes * 0.8 - seam * 0.5 - paint_wear * 0.04
    hh += smooth(s * 0.19, s * 0.18, y) * 0.06  # band is painted on a cap
    pits = smooth(0.2, 0.0, worley(s, 30, 144)[0]) * 0.4
    hh -= pits
    img *= rain_streaks(s, 145, 0.12)[..., None]
    img += grain(s, 146, 5, 64)
    rough = np.where(band & ~paint_wear, 0.55, 0.88)
    save("barrier", img, hh, rough, depth=s / 60)


def lava():
    """Molten rock: cooling black crust plates floating on glowing orange melt."""
    s = SMALL
    d1, d2, ids = worley(s, 7, 51)
    edge = d2 - d1
    heat = smooth(0.18, 0.0, edge)
    flow = norm01(noise(s, 4, 4, 52))
    heat = np.clip(heat + smooth(0.6, 0.95, flow) * 0.6, 0, 1)
    crust = mix(noise(s, 32, 3, 53), (46, 20, 14), (86, 36, 22))
    melt = mix(norm01(noise(s, 6, 3, 54)), (220, 60, 12), (255, 200, 70))
    img = crust * (1 - heat[..., None]) + melt * heat[..., None]
    hh = smooth(0.0, 0.2, edge) * 0.6 + (noise(s, 32, 3, 55) - 0.5) * 0.2
    save("lava", img, hh, 0.9 - 0.5 * heat, depth=s / 50, ao=0.0)


# --- character and prop surfaces --------------------------------------------

def gunmetal():
    """Guns and props: blue-black steel, finely brushed, bevelled panel lines,
    slide serrations, bright worn edges."""
    s = SMALL
    rects = grid_rects(s, 1, 2)
    h, _, dist = plates(s, rects, s * 0.025, seed=61)
    st = strokes(s, 3, 3, 61, 1)
    img = mix(st, (56, 62, 76), (70, 78, 94))
    x, y = coords(s)
    brushed = norm01(noise(s, 256, 2, 62, cells_y=4))
    img *= (0.92 + 0.16 * brushed)[..., None]
    serr = (x % (s / 32) < s / 64) & (y > s * 0.06) & (y < s * 0.22)
    hh = h - serr * 0.25 + (brushed - 0.5) * 0.02
    edge = np.clip(1 - dist / (s * 0.03), 0, 1) * (dist > 0)
    wear = np.clip(edge * smooth(0.4, 0.6, noise(s, 32, 3, 63)) + convex(hh, 2) * 4, 0, 1)
    img = img * (1 - 0.6 * wear[..., None]) + np.array([150, 160, 176]) * 0.6 * wear[..., None]
    sc = lines_mask(s, scratch_segs(s, 40, 64, 0.06), 1)
    img = img + sc[..., None] * 40
    img += grain(s, 65, 3, 64)
    rough = 0.42 - 0.12 * wear - 0.06 * brushed + 0.2 * serr
    save("gunmetal", img, hh, rough, depth=s / 120, metal=wear)


def glove():
    """Gloves, boots, brass and dark straps: warm brown leather with a pebbled
    grain, creases and raised stitching."""
    s = SMALL
    st = strokes(s, 3, 4, 71, 2)
    img = mix(st, (70, 50, 36), (112, 82, 58))
    x, y = coords(s)
    img *= (1.12 - 0.24 * (y / s))[..., None]
    d1, _, _ = worley(s, 90, 72)
    pebble = 1 - smooth(0.0, 0.55, d1)
    crease = lines_mask(s, walks(s, 14, 12, s / 60, 73, 0.3, down=False), s / 300)
    stitch_row = (np.abs(y % (s / 2) - s / 4) < s / 120) & (x % (s / 16) < s / 26)
    stitch = gauss(stitch_row.astype(float), 1)
    hh = pebble * 0.25 - crease * 0.6 + stitch * 0.6 + (noise(s, 6, 3, 74) - 0.5) * 0.3
    img = img * (1 - 0.2 * crease[..., None])
    img = img * (1 - stitch[..., None]) + np.array([176, 146, 104]) * stitch[..., None]
    img *= (1 + 0.12 * convex(hh, 3)[..., None] * 4)
    img += grain(s, 75, 4, 96)
    rough = 0.55 + 0.15 * (1 - pebble) - 0.15 * convex(hh, 3) * 4
    save("glove", img, hh, rough, depth=s / 120)


def fabric():
    """Fatigues, tape, grips and suits: soft olive camo blobs on a twill weave."""
    s = SMALL
    a = gauss(noise(s, 3, 3, 81), s / 128)
    b = gauss(noise(s, 4, 3, 82), s / 128)
    a, b = warp(a, s / 40, 83), warp(b, s / 40, 84)
    img = np.ones((s, s, 3)) * np.array([102, 110, 68], float)
    img = np.where((a > 0.56)[..., None], np.array([76, 86, 50], float), img)
    img = np.where(((b > 0.6) & (a <= 0.56))[..., None], np.array([132, 126, 86], float), img)
    img = np.where((a < 0.32)[..., None], np.array([58, 62, 42], float), img)
    img = gauss(img, s / 256)
    x, y = coords(s)
    p = s / 96
    twill = np.sin((x + y) / p * np.pi) * 0.5 + 0.5
    weft = np.sin(y / (p * 0.5) * np.pi) * 0.5 + 0.5
    weave = twill * 0.7 + weft * 0.3
    fuzz = noise(s, 128, 2, 85)
    hh = weave * 0.5 + fuzz * 0.2 + (noise(s, 4, 3, 86) - 0.5) * 0.6
    img *= (0.92 + 0.12 * weave)[..., None]
    img += grain(s, 87, 4, 128)
    save("fabric", img, hh, 0.9, depth=s / 200, ao=0.3)


def armor():
    """Grunt plates and helmets: sage ceramic armour, bevelled, with scuffs."""
    s = SMALL
    h, ids, dist = plates(s, [(0, 0, s, s // 2), (0, s // 2, s, s)], s * 0.04, seed=91, chip=s * 0.008)
    st = strokes(s, 3, 4, 91, 1)
    img = mix(st, (106, 122, 96), (140, 154, 124)) * (1 + per_id(ids, 92, -0.04, 0.04))[..., None]
    sc = lines_mask(s, scratch_segs(s, 30, 93, 0.08), 1.5)
    edge = np.clip(1 - dist / (s * 0.04), 0, 1) * smooth(0.5, 0.65, noise(s, 24, 3, 94))
    img = img * (1 - 0.5 * sc[..., None]) + np.array([196, 204, 180]) * 0.5 * sc[..., None]
    img = img * (1 - 0.5 * edge[..., None]) + np.array([200, 204, 190]) * 0.5 * edge[..., None]
    hh = h - sc * 0.1 + (noise(s, 8, 4, 95) - 0.5) * 0.05
    img *= grime(s, 96, 0.15)[..., None]
    img += grain(s, 97, 3, 64)
    save("armor", img, hh, 0.38 + 0.25 * sc + 0.1 * edge, depth=s / 80)


def titan_armor():
    """Titan hull and gun shrouds: big pale plates (tinted per chassis) with
    deep seams, domed rivet rows, chipped edges back to steel and a unit
    number."""
    s = BIG
    rects = rects_px(s, [(0, 0, 88, 64), (88, 0, 128, 64), (0, 64, 40, 128), (40, 64, 128, 96), (40, 96, 128, 128)])
    h, ids, dist = plates(s, rects, s * 0.025, seed=101, chip=s * 0.005)
    st = strokes(s, 4, 4, 101, 2)
    img = mix(st, (176, 176, 172), (212, 212, 206)) * (1 + per_id(ids, 103, -0.04, 0.04))[..., None]
    k = s / 128
    rivets = [(xx * k, yy * k) for yy in (6, 58, 70, 122) for xx in range(10, 128, 16)]
    riv = dome(s, rivets, 1.6 * k)
    hh = np.maximum(h, riv * 1.15)
    near = np.clip(1 - dist / (s * 0.035), 0, 1) * (dist > 0)
    chip = smooth(0.74, 0.77, noise(s, 20, 4, 102) + near ** 2 * 0.3)
    steel = mix(noise(s, 96, 2, 104), (128, 132, 138), (180, 184, 190))
    img = img * (1 - chip[..., None]) + steel * chip[..., None]
    hh -= chip * 0.04
    digits = text_mask(s, "07", 72 * k, 80 * k, 14 * k, stencil=True)
    img = img * (1 - 0.9 * digits[..., None]) + np.array([248, 246, 236]) * 0.9 * digits[..., None]
    img *= rain_streaks(s, 105, 0.1)[..., None] * grime(s, 106, 0.12)[..., None]
    img *= (1 - 0.3 * np.clip(1 - h, 0, 1))[..., None]
    img += grain(s, 107, 3)
    rough = 0.4 + 0.12 * noise(s, 8, 3, 108) + 0.15 * chip
    save("titan_armor", img, hh, rough, depth=s / 110, metal=chip)


def titan_frame():
    """Titan joints and inner frame: dark machinery ribs, a braided hose and
    bolt heads."""
    s = SMALL
    st = strokes(s, 3, 3, 111, 1)
    img = mix(st, (48, 50, 58), (72, 74, 84))
    x, y = coords(s)
    rib = (np.cos((y % (s / 8)) / (s / 8) * 2 * np.pi) * 0.5 + 0.5) ** 2
    hh = rib * 0.6
    hc, hr = s * 0.31, s * 0.065
    dx = np.abs(x - hc)
    hose = np.sqrt(np.clip(1 - (dx / hr) ** 2, 0, 1))
    braid = (np.sin((y + dx * 0.8) / (s / 64) * np.pi) * np.sin((y - dx * 0.8) / (s / 64) * np.pi)) * 0.5 + 0.5
    hh = np.where(dx < hr, 0.6 + hose * 0.9 + braid * 0.08 * hose, hh)
    hose_col = mix(hose * (0.6 + 0.4 * braid), (56, 40, 28), (138, 102, 64))
    img = np.where((dx < hr)[..., None], hose_col, img * (0.8 + 0.4 * rib)[..., None])
    bolts = dome(s, [(s * 0.69, s / 8 + i * s / 4) for i in range(4)], s * 0.025)
    hh = np.maximum(hh, bolts * 1.0)
    img = img * (1 - bolts[..., None]) + np.array([168, 168, 178]) * bolts[..., None]
    img *= grime(s, 112, 0.2)[..., None]
    img += grain(s, 113, 3, 64)
    metal = np.where(dx < hr, 0.0, 1.0)
    rough = np.where(dx < hr, 0.7, 0.45 - 0.15 * bolts)
    save("titan_frame", img, hh, rough, depth=s / 60, metal=metal)


def sky():
    """Panorama layers in the red/green/blue channels, tinted per zone by the sky shader:
    R = cloud density (soft, billowing), G = far mountain range, B = near ridge."""
    w, h = 2048, 512
    clouds = np.zeros((h, w))
    r = np.random.default_rng(121)
    for o, (cx, cy) in enumerate([(12, 3), (24, 6), (48, 12), (96, 24), (192, 48)]):
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
    clouds /= 1.94
    rows = np.linspace(0, 1, h)[:, None]
    band = np.clip(1.0 - np.abs(rows - 0.5) * 2.0, 0, 1)
    clouds = np.clip((clouds - 0.42) * 2.6, 0, 1) * band
    clouds = clouds ** 0.85

    def ridge(seed, base, amp, cells):
        rr = np.random.default_rng(seed)
        xs = np.arange(w) / w
        line = np.zeros(w)
        a = 1.0
        for o in range(6):
            c = cells * 2 ** o
            pts = rr.random(c)
            p = xs * c
            i0 = np.floor(p).astype(int)
            f = p - i0
            f = f * f * (3 - 2 * f)
            line += a * (pts[i0 % c] * (1 - f) + pts[(i0 + 1) % c] * f)
            a *= 0.45
        line /= 1.8
        height = base + amp * line
        y_from_bottom = (h - 1 - np.arange(h))[:, None]
        edge = (height[None, :] * h - y_from_bottom)
        return np.clip(edge / 1.5, 0, 1)

    far = ridge(131, 0.10, 0.36, 7)
    near = ridge(132, 0.04, 0.16, 12)
    img = np.stack([clouds, far, near], axis=-1) * 255
    Image.fromarray(img.astype(np.uint8), "RGB").save(OUT / "sky.png", optimize=True)
    print("wrote sky")


# --- Eco (the heroine) and shared skin --------------------------------------

def skin():
    """Skin: smooth warm tone with soft blush and very fine pores (tinted in the material)."""
    s = SMALL
    st = strokes(s, 2, 3, 141, 2)
    img = mix(st, (226, 206, 192), (244, 228, 216))
    warm = gauss(noise(s, 3, 2, 142), s / 32)
    img[..., 0] += 10 * warm
    d1, _, _ = worley(s, 160, 143)
    pores = smooth(0.25, 0.0, d1)
    img *= (1 - 0.03 * pores)[..., None]
    img += grain(s, 144, 2, 128)
    hh = -pores * 0.4 + (noise(s, 32, 3, 145) - 0.5) * 0.2
    save("skin", img, hh, 0.55 + 0.1 * pores, depth=s / 400, ao=0.1)


def hair():
    """Hair: white strands with soft lavender shadows; the shader adds the colour waves."""
    s = SMALL
    r = np.random.default_rng(151)
    cols = np.repeat(r.random(128), s // 128)
    cols = gauss(np.tile(cols, (s, 1)), 1.0)
    fine = norm01(noise(s, 256, 2, 152, cells_y=2))
    bands = strokes(s, 2, 3, 152, 1)
    t = np.clip(cols * 0.55 + fine * 0.25 + bands * 0.3, 0, 1)
    img = mix(t, (194, 194, 214), (252, 252, 255))
    hh = cols * 0.6 + fine * 0.4
    save("hair", img, hh, 0.45, depth=s / 200, ao=0.2)


# --- temple hub ------------------------------------------------------------

TEMPLE_COURSES = [(0, 0, 56, 32), (56, 0, 128, 32), (0, 32, 32, 64), (32, 32, 96, 64), (96, 32, 128, 64),
                  (0, 64, 72, 96), (72, 64, 128, 96), (0, 96, 40, 128), (40, 96, 104, 128), (104, 96, 128, 128)]


def temple_stone():
    """Temple walls: big weathered sandstone blocks in staggered courses, warm
    ochre, worn round at the corners, eroded in layers, moss in the joints."""
    s = BIG
    rects = rects_px(s, TEMPLE_COURSES)
    h, ids, dist = plates(s, rects, s * 0.04, seed=161, chip=s * 0.02)
    st = strokes(s, 4, 4, 161, 2)
    img = mix(st, (166, 136, 96), (208, 178, 130)) * (1 + per_id(ids, 166, -0.07, 0.07))[..., None]
    cool = strokes(s, 3, 3, 162, 3)
    img = img * (1 - 0.1 * cool[..., None]) + np.array([-8, -2, 8]) * cool[..., None]
    x, y = coords(s)
    # sandstone bedding: horizontal erosion layers
    layers = np.sin(y / s * 2 * np.pi * 22 + noise(s, 6, 3, 167) * 6) * 0.5 + 0.5
    erosion = norm01(noise(s, 10, 5, 168))
    hh = h + (erosion - 0.5) * 0.35 + layers * 0.06
    d1, _, _ = worley(s, 50, 169)
    pits = smooth(0.1, 0.0, d1) * smooth(0.6, 0.7, noise(s, 5, 2, 170))
    hh -= pits * 0.3
    crack = lines_mask(s, walks(s, 8, 30, s / 140, 165), s / 300)
    hh -= crack * 0.5
    img *= (1 - 0.22 * crack - 0.06 * pits + 0.05 * layers)[..., None]
    # moss settles in the joints and on the upper faces of blocks
    joint = np.clip(1 - h, 0, 1)
    mossy = smooth(0.25, 0.6, gauss(joint, s / 120)) * smooth(0.58, 0.7, noise(s, 8, 4, 163))
    mortar = smooth(0.2, 0.6, joint)
    img = img * (1 - 0.35 * mortar[..., None]) + np.array([120, 104, 82]) * 0.35 * mortar[..., None]
    moss_col = mix(noise(s, 64, 3, 164), (64, 92, 44), (108, 140, 64))
    img = img * (1 - mossy[..., None]) + moss_col * mossy[..., None]
    hh = np.maximum(hh, mossy * (0.55 + noise(s, 96, 2, 171) * 0.2))
    img *= rain_streaks(s, 172, 0.12)[..., None] * grime(s, 173, 0.15)[..., None]
    img += grain(s, 174, 5)
    rough = 0.88 + 0.07 * mossy
    save("temple_stone", img, hh, rough, depth=s / 80)


def temple_floor():
    """Temple floor and stair tops: worn square flagstones, smoothed in the
    middle by centuries of feet, mossy in the gaps."""
    s = BIG
    rects = grid_rects(s, 2, 2, s // 128)
    h, ids, _ = plates(s, rects, s * 0.035, seed=171, chip=s * 0.015)
    st = strokes(s, 4, 4, 171, 2)
    img = mix(st, (148, 126, 94), (194, 170, 128)) * (1 + per_id(ids, 175, -0.06, 0.06))[..., None]
    worn = gauss((noise(s, 2, 2, 173) > 0.55).astype(float), s / 40)
    lumps = noise(s, 8, 5, 176)
    hh = h * (1 - 0.1 * worn) + (lumps - 0.5) * 0.2 * (1 - worn)
    crack = lines_mask(s, walks(s, 6, 34, s / 150, 177, 0.5, down=False), s / 320)
    hh -= crack * 0.5
    img *= (1 + 0.1 * worn - 0.22 * crack)[..., None]
    gap = np.clip(1 - h, 0, 1)
    mossy = smooth(0.25, 0.6, gauss(gap, s / 200)) * smooth(0.55, 0.68, noise(s, 12, 3, 172))
    grout = smooth(0.2, 0.6, gap)
    img = img * (1 - 0.4 * grout[..., None]) + np.array([96, 84, 66]) * 0.4 * grout[..., None]
    moss_col = mix(noise(s, 64, 3, 178), (56, 70, 42), (90, 112, 58))
    img = img * (1 - mossy[..., None]) + moss_col * mossy[..., None]
    hh = np.maximum(hh, mossy * 0.45 * (0.8 + noise(s, 96, 2, 179) * 0.4))
    sc = lines_mask(s, scratch_segs(s, 40, 174, 0.05), 1.5)
    img *= (1 - 0.15 * sc)[..., None]
    img += grain(s, 180, 5)
    rough = 0.82 - 0.2 * worn + 0.1 * mossy
    save("temple_floor", img, hh, rough, depth=s / 90)


def temple_carving():
    """Friezes and the idol: a carved band of the precursor god's eye glyph
    between rows of step-fret, cut deep so it reads in the haze."""
    s = BIG
    k = s / 128
    st = strokes(s, 4, 4, 181, 2)
    img = mix(st, (150, 132, 104), (194, 174, 134))
    x, y = coords(s)
    cut = np.zeros((s, s))
    for y0 in (4, 108):
        band = (y >= y0 * k) & (y < (y0 + 16) * k)
        fret = band & ((((x // (8 * k)) + ((y - y0 * k) // (8 * k))) % 2) == 0)
        cut = np.maximum(cut, fret.astype(float))
        rim = (np.abs(y - y0 * k) < k * 0.8) | (np.abs(y - (y0 + 16) * k) < k * 0.8)
        cut = np.maximum(cut, rim * 0.7)
    for cx in (32 * k, 96 * k):
        cy = 64 * k
        dx, dy = (x - cx) / (26 * k), (y - cy) / (14 * k)
        almond = np.abs(dy) + dx * dx * 0.9 < 1.0
        outline = almond & ~(np.abs(dy) * 1.25 + dx * dx * 1.1 < 1.0)
        rr = np.sqrt((x - cx) ** 2 + (y - cy) ** 2)
        ring = (rr > 6.5 * k) & (rr < 9.5 * k)
        pupil = rr < 3.5 * k
        rays = (np.abs(x - cx) < 2 * k) & (np.abs(y - cy) > 16 * k) & (np.abs(y - cy) < 26 * k)
        cut = np.maximum(cut, (outline | ring | pupil | rays).astype(float))
    # chiselled: the cut walls slope, and the stone around is weathered
    cut_s = gauss(cut, k * 0.7)
    weather = noise(s, 10, 5, 182)
    hh = 1 - cut_s * 0.9 + (weather - 0.5) * 0.25
    d1, _, _ = worley(s, 50, 183)
    hh -= smooth(0.22, 0.0, d1) * 0.2
    img *= (1 - 0.35 * cut_s)[..., None]
    dirt = gauss(cut, k * 2.5) * smooth(0.3, 0.8, noise(s, 8, 3, 184))
    img = img * (1 - 0.4 * dirt[..., None]) + np.array([76, 90, 52]) * 0.4 * dirt[..., None]
    img *= rain_streaks(s, 185, 0.1)[..., None]
    img += grain(s, 186, 5)
    save("temple_carving", img, hh, 0.85, depth=s / 50, ao=0.7, ao_radius=k * 3)


def moss():
    """Overgrowth, leaves, hill forests: leafy clumps with lit tips and deep
    shadows between them, a few yellow flowers."""
    s = SMALL
    d1, d2, ids = worley(s, 28, 191)
    clump = np.clip(1 - d1 * 1.35, 0, 1) ** 0.7
    d1b, _, _ = worley(s, 70, 193)
    leaf = np.clip(1 - d1b * 1.5, 0, 1)
    hh = clump * 0.7 + leaf * 0.3 + (noise(s, 8, 3, 194) - 0.5) * 0.3
    b = strokes(s, 6, 4, 192, 1)
    tone = per_id(ids, 195, -0.12, 0.12)
    img = mix(np.clip(b * 0.5 + hh * 0.7 + tone, 0, 1), (44, 76, 34), (138, 178, 78))
    img *= (0.7 + 0.4 * hh)[..., None]
    r = np.random.default_rng(196)
    fl = dome(s, [tuple(r.uniform(0, s, 2)) for _ in range(14)], s / 160)
    img = img * (1 - fl[..., None]) + np.array([214, 188, 86]) * fl[..., None]
    img += grain(s, 197, 4, 96)
    save("moss", img, hh, 0.75 - 0.2 * leaf, depth=s / 60, ao=0.5)


def wood():
    """Workbench, crates, shelves, rope: warm planks with flowing grain, knots
    and dark nail heads."""
    s = SMALL
    x, y = coords(s)
    knots = [(s * 0.3, s * 0.12), (s * 0.78, s * 0.62), (s * 0.12, s * 0.86)]
    ky = y.astype(float)
    for cx, cy in knots:
        dx, dy = x - cx, (y - cy) * 2.5
        d = np.sqrt(dx * dx + dy * dy) + 1
        ky = ky + (s * 0.02) * np.exp(-d / (s * 0.04)) * np.sign(dy) * 4
    n = noise(s, 3, 4, 201)
    rings = np.sin(ky / s * 2 * np.pi * 14 + n * 10) * 0.5 + 0.5
    rings = warp(rings, s / 60, 207, 8)
    streak = norm01(noise(s, 2, 4, 208, cells_y=48))
    fibre = norm01(noise(s, 8, 3, 203, cells_y=128))
    grain_t = np.clip(rings * 0.35 + streak * 0.4 + fibre * 0.25, 0, 1)
    img = mix(grain_t, (118, 80, 50), (156, 110, 68))
    planks = [(0, int(y0), s, int(y0 + s / 4)) for y0 in np.arange(0, s, s / 4)]
    h, ids, _ = plates(s, planks, s * 0.012, seed=204, chip=s * 0.004)
    img *= (1 + per_id(ids, 205, -0.08, 0.08))[..., None]
    knot = np.zeros((s, s))
    for cx, cy in knots:
        knot = np.maximum(knot, np.exp(-((x - cx) ** 2 + ((y - cy) * 1.6) ** 2) / (s * 0.012) ** 2))
    img *= (1 - 0.5 * knot)[..., None]
    nails = dome(s, [(s * 0.03, y0 + s / 8) for y0 in np.arange(0, s, s / 4)] +
                 [(s * 0.97, y0 + s / 8) for y0 in np.arange(0, s, s / 4)], s * 0.01)
    img = img * (1 - nails[..., None]) + np.array([62, 60, 58]) * nails[..., None]
    hh = h + (grain_t - 0.5) * 0.12 - knot * 0.1 + nails * 0.2
    img += grain(s, 206, 4, 96)
    save("wood", img, hh, 0.7 - 0.2 * nails, depth=s / 80, metal=nails)


def grass():
    """Ground grass: dense painted blades in clumps, sun-bleached tips, dark
    roots, a few flowers."""
    s = BIG
    a = strokes(s, 4, 4, 211, 2)
    img = mix(a, (80, 122, 48), (122, 162, 66))
    r = np.random.default_rng(212)
    n = 2600
    segs = []
    px, py = r.uniform(0, s, n), r.uniform(0, s, n)
    ang = -np.pi / 2 + r.uniform(-0.9, 0.9, n)
    ln = r.uniform(s * 0.012, s * 0.03, n)
    for i in range(n):
        segs.append([(px[i], py[i]), (px[i] + np.cos(ang[i]) * ln[i], py[i] + np.sin(ang[i]) * ln[i])])
    blades = lines_mask(s, segs, max(s / 512, 1.5))
    clump = smooth(0.35, 0.75, noise(s, 8, 3, 213))
    hh = blades * 0.6 + clump * 0.4 + (noise(s, 6, 3, 214) - 0.5) * 0.3
    lit = mix(clump, (128, 168, 72), (166, 196, 92))
    img = img * (1 - 0.6 * blades[..., None]) + lit * 0.6 * blades[..., None]
    img *= (0.72 + 0.4 * hh)[..., None]
    dry = smooth(0.62, 0.8, noise(s, 5, 3, 215))
    img = img * (1 - 0.35 * dry[..., None]) + np.array([150, 150, 74]) * 0.35 * dry[..., None]
    fl = [tuple(r.uniform(0, s, 2)) for _ in range(30)]
    f1 = dome(s, fl[:15], s / 260)
    f2 = dome(s, fl[15:], s / 260)
    img = img * (1 - f1[..., None]) + np.array([236, 224, 116]) * f1[..., None]
    img = img * (1 - f2[..., None]) + np.array([226, 148, 168]) * f2[..., None]
    img += grain(s, 216, 5)
    save("grass", img, hh, 0.82, depth=s / 120, ao=0.55)


def dirt():
    """Paths, the titan yard, grass sides: packed earth, pebbles, tread ruts
    and dried cracks."""
    s = BIG
    a = strokes(s, 4, 4, 221, 2)
    img = mix(a, (116, 90, 62), (156, 124, 86))
    lumps = noise(s, 10, 5, 223)
    x, y = coords(s)
    rut_c = (y % (s / 2)) - s * 0.165
    ruts = np.exp(-(rut_c / (s * 0.035)) ** 2)
    tread = ruts * (np.sin(x / (s / 48) * np.pi) * 0.5 + 0.5)
    d1, d2, ids = worley(s, 64, 222)
    d1 = warp(d1, s / 300, 232, 32)
    pebble = smooth(0.42, 0.18, d1) * (per_id(ids, 224, 0, 1) > 0.8)
    d1s, _, ids_s = worley(s, 110, 225)
    grit = np.clip(1 - d1s * 2.6, 0, 1) ** 0.6 * (per_id(ids_s, 226, 0, 1) > 0.6)
    crack_cells = worley(s, 9, 227)
    dry = smooth(0.06, 0.0, crack_cells[1] - crack_cells[0]) * smooth(0.5, 0.75, noise(s, 4, 3, 228))
    hh = (lumps - 0.5) * 0.5 - ruts * 0.35 + tread * 0.08 + pebble * 0.5 + grit * 0.2 - dry * 0.4
    peb_col = mix(per_id(ids, 229, 0, 1), (132, 118, 98), (176, 162, 138))
    img = img * (1 - 0.8 * pebble[..., None]) + peb_col * 0.8 * pebble[..., None]
    img *= (1 - 0.12 * ruts - 0.3 * dry + 0.12 * grit)[..., None]
    img *= grime(s, 230, 0.15)[..., None]
    img += grain(s, 231, 6)
    rough = 0.92 - 0.25 * pebble
    save("dirt", img, hh, rough, depth=s / 90, ao=0.55)


def canvas():
    """Tents, tarps, grunt gold and chrome base: weathered tan canvas weave,
    stitched seams and a couple of patches."""
    s = SMALL
    a = strokes(s, 3, 4, 231, 1)
    img = mix(a, (174, 154, 110), (204, 186, 140))
    x, y = coords(s)
    p = s / 128
    warp_t = np.sin(x / p * np.pi) * 0.5 + 0.5
    weft = np.sin(y / p * np.pi) * 0.5 + 0.5
    weave = np.where(((x // p + y // p) % 2) == 0, warp_t, weft)
    seam_x = (x % (s / 4)) < s / 128
    seam = gauss(seam_x.astype(float), 2)
    stitch = gauss(((np.abs((x % (s / 4)) - s / 64) < s / 400) & (y % (s / 32) < s / 64)).astype(float), 0.8)
    k = s / 64
    p1, _, _ = plates(s, [(int(36 * k), int(10 * k), int(54 * k), int(26 * k))], 1.0 * k, seed=232)
    p2, _, _ = plates(s, [(int(6 * k), int(40 * k), int(20 * k), int(56 * k))], 1.0 * k, seed=233)
    img = np.where((p1 > 0)[..., None], img * np.array([0.8, 0.95, 1.1]), img)
    img = np.where((p2 > 0)[..., None], img * np.array([1.1, 0.85, 0.75]), img)
    hh = weave * 0.3 + p1 * 0.4 + p2 * 0.4 - seam * 0.5 + stitch * 0.4 + (noise(s, 4, 3, 234) - 0.5) * 0.6
    img *= (0.93 + 0.1 * weave)[..., None] * (1 - 0.25 * seam)[..., None]
    img *= grime(s, 235, 0.2)[..., None] * rain_streaks(s, 236, 0.12)[..., None]
    img += grain(s, 237, 4, 96)
    save("canvas", img, hh, 0.88, depth=s / 150, ao=0.4)


def bark():
    """Tree trunks and tent poles: deep vertical furrows in warm brown bark,
    plated ridges, moss low in the cracks."""
    s = SMALL
    n = noise(s, 4, 3, 241)
    # irregular vertical furrows: thin dark cracks along ridged noise,
    # stretched up the trunk, between broad raised bark plates
    furrow = norm01(noise(s, 16, 4, 248, cells_y=2))
    ridge = 1 - np.abs(furrow * 2 - 1)
    ridge = warp(ridge, s / 60, 249, 6)
    crevice = smooth(0.7, 0.96, ridge)
    fibre = norm01(noise(s, 32, 3, 243, cells_y=4))
    plate = 1 - crevice
    hh = plate * 0.8 + fibre * 0.15 + n * 0.2
    img = mix(np.clip(plate * 0.7 + fibre * 0.3, 0, 1), (44, 30, 22), (138, 102, 70))
    mossy = smooth(0.62, 0.75, noise(s, 3, 3, 242)) * (1 - plate * 0.6)
    img = img * (1 - mossy[..., None]) + np.array([84, 110, 52]) * mossy[..., None]
    img += grain(s, 247, 4, 96)
    save("bark", img, hh, 0.9, depth=s / 40, ao=0.6)


# --- the home: old timber or precursor alloy ---------------------------------------

def glyph_band(s, k):
    """The god's eye glyph between two rows of step-fret (1 = cut), as on the
    temple frieze, laid out on a 128 px tile scaled by k."""
    x, y = coords(s)
    cut = np.zeros((s, s))
    for y0 in (4, 108):
        band = (y >= y0 * k) & (y < (y0 + 16) * k)
        fret = band & ((((x // (8 * k)) + ((y - y0 * k) // (8 * k))) % 2) == 0)
        cut = np.maximum(cut, fret.astype(float))
        rim = (np.abs(y - y0 * k) < k * 0.8) | (np.abs(y - (y0 + 16) * k) < k * 0.8)
        cut = np.maximum(cut, rim * 0.7)
    for cx in (32 * k, 96 * k):
        cy = 64 * k
        dx, dy = (x - cx) / (26 * k), (y - cy) / (14 * k)
        almond = np.abs(dy) + dx * dx * 0.9 < 1.0
        outline = almond & ~(np.abs(dy) * 1.25 + dx * dx * 1.1 < 1.0)
        rr = np.sqrt((x - cx) ** 2 + (y - cy) ** 2)
        ring = (rr > 6.5 * k) & (rr < 9.5 * k)
        pupil = rr < 3.5 * k
        rays = (np.abs(x - cx) < 2 * k) & (np.abs(y - cy) > 16 * k) & (np.abs(y - cy) < 26 * k)
        cut = np.maximum(cut, (outline | ring | pupil | rays).astype(float))
    return cut


def wood_grain(s, seed, rings=14, vertical=False):
    """Flowing plank grain 0..1 (along x, or along y when `vertical`)."""
    x, y = coords(s)
    along = (x if vertical else y).astype(float)
    n = noise(s, 3, 4, seed)
    r = np.sin(along / s * 2 * np.pi * rings + n * 10) * 0.5 + 0.5
    r = warp(r, s / 60, seed + 1, 8)
    if vertical:
        streak = norm01(noise(s, 48, 4, seed + 2, cells_y=2))
        fibre = norm01(noise(s, 128, 3, seed + 3, cells_y=8))
    else:
        streak = norm01(noise(s, 2, 4, seed + 2, cells_y=48))
        fibre = norm01(noise(s, 8, 3, seed + 3, cells_y=128))
    return np.clip(r * 0.35 + streak * 0.4 + fibre * 0.25, 0, 1)


def timber_wall():
    """Old temple timber: tall weathered boards of a dark tropical hardwood,
    silvered where the weather got at them, pegged to a cross rail."""
    s = BIG
    g = wood_grain(s, 301, 9, vertical=True)
    boards = [(int(x0), 0, int(x0 + s / 6), s) for x0 in np.arange(0, s, s / 6)]
    h, ids, _ = plates(s, boards, s * 0.01, seed=302, chip=s * 0.006)
    img = mix(g, (82, 54, 36), (138, 96, 62)) * (1 + per_id(ids, 303, -0.1, 0.1))[..., None]
    # silver weathering in broad vertical streaks
    silver = smooth(0.45, 0.8, norm01(noise(s, 6, 4, 304, cells_y=2))) * 0.55
    img = img * (1 - silver[..., None]) + np.array([150, 140, 126]) * silver[..., None]
    x, y = coords(s)
    # a cross rail with wooden pegs, two thirds up
    rail = smooth(s * 0.012, 0, np.abs(y - s * 0.32) - s * 0.035)
    img = img * (1 - 0.25 * rail[..., None])
    pegs = dome(s, [(x0 + s / 12, s * 0.32) for x0 in np.arange(0, s, s / 6)], s * 0.012)
    img = img * (1 - pegs[..., None]) + np.array([60, 40, 28]) * pegs[..., None]
    crack = lines_mask(s, walks(s, 5, 14, s / 160, 305, 0.1), s / 500) * 0.5
    hh = h * 0.9 + rail * 0.15 + pegs * 0.2 + (g - 0.5) * 0.18 - crack * 0.4
    img *= (1 - 0.3 * crack)[..., None] * grime(s, 306, 0.15)[..., None]
    img += grain(s, 307, 5)
    save("timber_wall", img, hh, 0.78 - 0.1 * pegs, depth=s / 90)


def timber_floor():
    """Floorboards: warm honey planks, staggered butt joints, worn paler down
    the middle where she walks."""
    s = BIG
    g = wood_grain(s, 311, 16)
    rows = 6
    boards = []
    r = np.random.default_rng(312)
    for i in range(rows):
        y0, y1 = int(i * s / rows), int((i + 1) * s / rows)
        cut = int(r.uniform(0.2, 0.8) * s)
        boards += [(0, y0, cut, y1), (cut, y0, s, y1)]
    h, ids, _ = plates(s, boards, s * 0.008, seed=313, chip=s * 0.004)
    img = mix(g, (120, 78, 44), (176, 124, 74)) * (1 + per_id(ids, 314, -0.12, 0.12))[..., None]
    worn = smooth(0.5, 0.75, noise(s, 2, 2, 315))
    img = img * (1 + 0.12 * worn)[..., None]
    sc = lines_mask(s, scratch_segs(s, 50, 316, 0.06), 1.5)
    nails = dome(s, [(bx + s * 0.02, (by0 + by1) / 2) for bx, by0, _, by1 in boards], s * 0.007)
    img = img * (1 - 0.12 * sc - nails)[..., None] + np.array([50, 48, 46]) * nails[..., None]
    hh = h + (g - 0.5) * 0.1 + nails * 0.15
    img += grain(s, 317, 4)
    save("timber_floor", img, hh, 0.55 - 0.15 * worn, depth=s / 110, metal=nails)


def timber_carving():
    """Carved and painted hardwood frieze: the eye glyph and step-fret cut into
    dark wood, the cuts still holding flecks of old teal and red paint."""
    s = BIG
    k = s / 128
    g = wood_grain(s, 321, 10)
    img = mix(g, (78, 50, 32), (128, 86, 54))
    cut = gauss(glyph_band(s, k), k * 0.6)
    paint = smooth(0.4, 0.6, noise(s, 12, 3, 322))
    flake = np.where(paint[..., None] > 0.5, np.array([62, 128, 118]), np.array([150, 56, 40]))
    left = cut * smooth(0.35, 0.55, noise(s, 24, 3, 323))
    img = img * (1 - 0.45 * cut[..., None])
    img = img * (1 - 0.7 * left[..., None]) + flake * 0.7 * left[..., None]
    hh = 1 - cut * 0.8 + (g - 0.5) * 0.15
    img *= grime(s, 324, 0.15)[..., None]
    img += grain(s, 325, 4)
    save("timber_carving", img, hh, 0.7, depth=s / 50, ao=0.6, ao_radius=k * 3)


def alloy_panel():
    """Precursor alloy walls: pale pearl-white ceramic metal in big soft-edged
    panels with fine seams, a faint hex weave in the surface and teal traces
    running along some of the seams. Old, but it never rusted."""
    s = BIG
    rects = rects_px(s, [(0, 0, 80, 48), (80, 0, 128, 48), (0, 48, 48, 128), (48, 48, 128, 92), (48, 92, 128, 128)])
    h, ids, dist = plates(s, rects, s * 0.03, seed=331)
    x, y = coords(s)
    # hex weave
    hx = s / 64
    q = (x / (hx * 1.732))
    r = (y / hx - (x / (hx * 1.732)) * 0.5)
    fq, fr = q - np.round(q), r - np.round(r)
    hexd = np.maximum(np.abs(fq), np.maximum(np.abs(fr), np.abs(fq + fr)))
    weave = smooth(0.44, 0.5, hexd) * 0.5
    tone = norm01(noise(s, 3, 3, 332))
    img = mix(tone, (196, 204, 198), (228, 230, 222)) * (1 + per_id(ids, 333, -0.04, 0.04))[..., None]
    # pearly sheen: a slight cool/warm shift across each panel
    sheen = norm01(noise(s, 2, 2, 334))
    img += (np.array([-6, 4, 10]) * sheen[..., None] + np.array([8, 2, -6]) * (1 - sheen[..., None]))
    img *= (1 - 0.05 * weave)[..., None]
    seam = np.clip(1 - h, 0, 1)
    trace = smooth(0.5, 0.9, seam) * (per_id(ids, 335, 0, 1) > 0.45)
    img = img * (1 - 0.45 * seam[..., None])
    img = img * (1 - trace[..., None]) + np.array([70, 200, 180]) * trace[..., None]
    dust = grime(s, 336, 0.2)
    img *= dust[..., None]
    img += grain(s, 337, 3)
    hh = h - weave * 0.04
    save("alloy_panel", img, hh, 0.35 + 0.15 * seam + 0.1 * (1 - dust), depth=s / 120, metal=0.35 * (1 - seam))


def alloy_floor():
    """Precursor floor: big octagonal alloy tiles with small dark diamond
    keys between them, dusty, with fine seams."""
    s = BIG
    x, y = coords(s)
    t = s / 2
    fx, fy = (x % t) / t - 0.5, (y % t) / t - 0.5
    octd = np.maximum(np.maximum(np.abs(fx), np.abs(fy)), (np.abs(fx) + np.abs(fy)) * 0.72)
    h = smooth(0.49, 0.46, octd)
    ids = ((x // t) * 2 + (y // t)).astype(int)
    key = (np.abs(fx) + np.abs(fy)) > 0.76
    img = mix(norm01(noise(s, 4, 3, 341)), (172, 178, 172), (206, 208, 200)) * (1 + per_id(ids, 342, -0.05, 0.05))[..., None]
    img = img * (1 - 0.45 * (1 - h)[..., None])
    img = np.where(key[..., None], np.array([66, 92, 90]) * (0.8 + 0.4 * noise(s, 16, 2, 347))[..., None], img)
    worn = smooth(0.55, 0.8, noise(s, 2, 2, 343))
    img *= (1 + 0.06 * worn)[..., None] * grime(s, 344, 0.22)[..., None]
    sc = lines_mask(s, scratch_segs(s, 40, 345, 0.05), 1.5)
    img *= (1 - 0.1 * sc)[..., None]
    img += grain(s, 346, 3)
    hh = np.where(key, 0.7, h)
    save("alloy_floor", img, hh, 0.45 - 0.1 * worn, depth=s / 140, metal=0.3 * h)


def alloy_inlay():
    """Precursor frieze: the eye glyph and step-fret inlaid in teal crystal
    channels across a pearl alloy band."""
    s = BIG
    k = s / 128
    img = mix(norm01(noise(s, 3, 3, 351)), (200, 206, 200), (228, 230, 222))
    cut = gauss(glyph_band(s, k), k * 0.4)
    img = img * (1 - cut[..., None]) + np.array([60, 196, 176]) * cut[..., None]
    img *= grime(s, 352, 0.12)[..., None]
    img += grain(s, 353, 3)
    save("alloy_inlay", img, 1 - cut * 0.4, 0.3 + 0.1 * cut, depth=s / 80, metal=0.4 * (1 - cut))


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if "--half" in sys.argv:
        BIG, SMALL = BIG // 2, SMALL // 2
    OUT.mkdir(parents=True, exist_ok=True)
    for fn in (concrete, metal_floor, wall_panel, hazard, crate, barrier, lava, gunmetal, glove,
               fabric, armor, titan_armor, titan_frame, sky, temple_stone, temple_floor,
               temple_carving, moss, wood, grass, dirt, canvas, bark, skin, hair,
               timber_wall, timber_floor, timber_carving, alloy_panel, alloy_floor, alloy_inlay):
        if not args or fn.__name__ in args:
            fn()
