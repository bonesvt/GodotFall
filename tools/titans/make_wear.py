#!/usr/bin/env python3
"""Paints the titan paint-wear mask, assets/textures/titans/paint_wear.png.

One tileable RGB mask the titan_paint shader reads by box projection:
  R  paint chips: where the paint has flaked off to bare metal. The shader
     cuts it at a per-material threshold, so the same mask gives a fresh
     machine a few nicks and a wreck whole bald patches.
  G  grime: soft dirt blotches plus rain streaks running down the sides.
  B  fine scratches and grain, for a little life in the bare metal.

    python3 tools/titans/make_wear.py      (needs pillow and numpy)
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from make_textures import blur, noise  # noqa: E402

OUT = Path(__file__).resolve().parent.parent.parent / "assets" / "textures" / "titans" / "paint_wear.png"
SIZE = 1024
K = SIZE // 256  # the mask was first painted at 256 px


def chips():
    # Ragged blobs: mid-frequency noise, sharpened, gated by a slow noise so
    # chips cluster in patches instead of spreading evenly.
    n = noise(SIZE, 8, 6, seed=11)
    patch = noise(SIZE, 3, 2, seed=12)
    v = n * 0.75 + patch * 0.45
    v = (v - v.min()) / (v.max() - v.min())
    return np.clip(v, 0, 1)


def grime():
    blotch = noise(SIZE, 4, 3, seed=21)
    r = np.random.default_rng(22)
    streak = np.zeros((SIZE, SIZE))
    for _ in range(90):
        x = r.integers(0, SIZE)
        y = r.integers(0, SIZE)
        length = r.integers(20, 110) * K
        w = r.uniform(0.3, 1.0)
        ys = (y + np.arange(length)) % SIZE
        fade = np.linspace(1, 0, length) * w
        for dx in range(K):
            xs = (x + dx) % SIZE
            streak[ys, xs] = np.maximum(streak[ys, xs], fade)
    streak = blur(streak, K)
    v = blotch * 0.7 + streak * 0.9
    return np.clip((v - 0.35) * 1.6, 0, 1)


def scratches():
    r = np.random.default_rng(31)
    img = noise(SIZE, 32, 4, seed=32) * 0.5
    for _ in range(160 * K):
        x, y = r.integers(0, SIZE, 2)
        ang = r.uniform(0, np.pi)
        length = r.integers(4, 18) * K
        for t in range(length):
            px = int(x + np.cos(ang) * t) % SIZE
            py = int(y + np.sin(ang) * t) % SIZE
            img[py, px] = 1.0
    return np.clip(img, 0, 1)


def main():
    rgb = np.stack([chips(), grime(), scratches()], axis=-1)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray((rgb * 255).astype(np.uint8), "RGB").save(OUT)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
