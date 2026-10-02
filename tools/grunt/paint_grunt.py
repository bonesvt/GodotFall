#!/usr/bin/env python3
"""Paints the grunt's small tiling textures into assets/textures/grunt/:
skin.png (ruddy, blotchy) and stubble.png (five o'clock shadow speckle).
The rest of the grunt reuses the game's shared textures (fabric, armor,
glove, gunmetal). Needs numpy and Pillow.

    python3 tools/grunt/paint_grunt.py"""
from pathlib import Path

import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parents[2] / "assets/textures/grunt"
N = 64
rng = np.random.default_rng(7)


def blur_noise(scale):
    """Tiling value noise: random grid, bilinear upsampled with wrap."""
    g = rng.random((scale, scale))
    x = np.arange(N) * scale / N
    i0 = np.floor(x).astype(int)
    t = x - i0
    t = t * t * (3 - 2 * t)
    i1 = (i0 + 1) % scale
    a = g[i0] * (1 - t)[:, None] + g[i1] * t[:, None]
    return a[:, i0] * (1 - t)[None, :] + a[:, i1] * t[None, :]


def save(name, rgb):
    OUT.mkdir(parents=True, exist_ok=True)
    Image.fromarray(np.clip(rgb * 255, 0, 255).astype(np.uint8)).save(OUT / name)
    print("wrote", OUT / name)


def skin():
    n = 0.6 * blur_noise(4) + 0.4 * blur_noise(16)
    base = np.array([1.0, 0.97, 0.95])
    flush = np.array([1.0, 0.86, 0.84])  # ruddy blotches
    t = np.clip((n - 0.45) * 2.5, 0, 1)[..., None]
    return base * (1 - t) + flush * t


def stubble():
    n = 0.5 * blur_noise(8) + 0.5
    rgb = np.ones((N, N, 3)) * n[..., None] * 0.15 + 0.85
    dots = rng.random((N, N)) < 0.22
    rgb[dots] *= 0.55
    return rgb


save("skin.png", skin())
save("stubble.png", stubble())
