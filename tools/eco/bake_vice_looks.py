"""Bakes the hypno looks' textures (scripts/hub/vice_looks.gd LOOKS) from
tools/eco/vice_looks.json: per look, the re-dyed bodysuit and its glow, hair,
fringe, eye makeup and lips, written to assets/textures/eco/looks/<look>_*.png.
(The hair dye covers the cap of hair painted on her scalp too.) A look
leaves out what it doesn't change (no "pattern": her base outfit's own
bodysuit; no "hair": her own colour).

    python3 tools/eco/bake_vice_looks.py            (from the repo root)

Each entry:
  pattern  [kind, colour, colour...]  the bodysuit's fabric: solid, fade,
           panels, stripes, stripes3, spiral, veins (the second colour is
           the seams), patch
  glow     [r, g, b]  her suit's glow lines re-lit
  hair     [r, g, b, gain, add r, add g, add b]  dye over the hair's shading
  shadow   [r, g, b, amount]  eyeshadow round her lash line
  lips     [r, g, b]
  skin     [r, g, b]  a tint on her bare skin under the suit
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

REPO = Path(__file__).resolve().parents[2]
TEX = REPO / "assets/textures/eco"
OUT = TEX / "looks"


def load(n, size=None):
    im = Image.open(TEX / n).convert("RGBA")
    if size:
        im = im.resize(size, Image.BILINEAR)
    return np.asarray(im).astype(np.float32) / 255.0


def save(a, n):
    Image.fromarray((np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8)).save(OUT / n, optimize=True)


def lum(a):
    return a[..., :3] @ np.array([0.299, 0.587, 0.114], dtype=np.float32)


def main():
    spec = json.load(open(REPO / "tools/eco/vice_looks.json"))
    OUT.mkdir(parents=True, exist_ok=True)
    body = load("v_body_shade.png")
    H, W = body.shape[:2]
    fabric = load("v_body_mask_shade.png", (W, H))[..., 1:2]
    L = lum(body)[..., None]
    glow = load("v_body_glow_shade.png")
    g = glow[..., :3].max(axis=2, keepdims=True)
    v, u = np.mgrid[0:H, 0:W].astype(np.float32)
    u /= W
    v /= H
    rng = np.random.default_rng(3)

    def pattern(p):
        kind, cols = p[0], [np.array(c, dtype=np.float32) for c in p[1:]]
        c1 = cols[0]
        c2 = cols[1] if len(cols) > 1 else c1
        if kind == "solid":
            t = np.zeros_like(u)
        elif kind == "fade":
            t = np.clip(v * 1.4 - 0.1, 0, 1)
        elif kind == "panels":
            t = ((u < 0.25) | (u > 0.75) | (v > 0.55)).astype(np.float32)
        elif kind == "stripes":
            t = (np.sin(v * 90.0) > 0.3).astype(np.float32)
        elif kind == "stripes3":
            k = (np.floor(v * 30.0) % 3).astype(int)
            return np.stack(cols[:3])[k]
        elif kind == "spiral":
            du, dv = (u - 0.5) * 2.0, (v - 0.18) * 2.0
            r = np.sqrt(du * du + dv * dv)
            a = np.arctan2(dv, du)
            t = (np.sin(a * 3.0 + r * 40.0) > 0.2).astype(np.float32)
        elif kind == "veins":
            n = np.sin(u * 37 + np.sin(v * 23) * 2) + np.sin(v * 41 + np.sin(u * 29) * 2) + 0.6 * np.sin((u + v) * 67)
            t = (np.abs(n) < 0.08).astype(np.float32)
        elif kind == "patch":
            gx, gy = np.floor(u * 10).astype(int), np.floor(v * 10).astype(int)
            cells = rng.random((11, 11))
            t = (cells[gy, gx] > 0.55).astype(np.float32)
        else:
            raise ValueError(kind)
        t = t[..., None]
        return c1 * (1 - t) + c2 * t

    for k, lk in spec.items():
        if "pattern" in lk:
            pat = pattern(lk["pattern"])
            shaded = np.clip(pat * (0.35 + L * 2.4), 0, 1)
            if lk["pattern"][0] == "veins":  # the seams stay their own bright colour
                seam = np.abs(pat - np.array(lk["pattern"][2])).sum(axis=2, keepdims=True) < 0.05
                shaded = np.where(seam, np.array(lk["pattern"][2]), shaded)
            skin = np.array(lk.get("skin", [1, 1, 1]), dtype=np.float32)
            rgb = body[..., :3] * skin * (1 - fabric) + shaded * fabric
            save(np.concatenate([rgb, body[..., 3:]], axis=2), f"{k}_body.png")
            gc = np.array(lk.get("glow", [0, 0, 0]))
            save(np.concatenate([g * gc, np.ones_like(g)], axis=2), f"{k}_glow.png")
        if "hair" in lk:
            hc = lk["hair"]
            for src, dst in [("v_hair.png", "hair"), ("v_hair_fringe.png", "fringe"), ("v_hair_cap.png", "cap")]:
                h = load(src)
                hl = lum(h)[..., None]
                save(np.concatenate([np.clip(hl * np.array(hc[:3]) * hc[3] + np.array(hc[4:7]), 0, 1), h[..., 3:]], axis=2), f"{k}_{dst}.png")
        if "shadow" in lk:
            e = load("v_eyeline.png")
            a = e[..., 3:]
            sc = np.array(lk["shadow"][:3])
            amt = lk["shadow"][3]
            soft = Image.fromarray((a[..., 0] * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(6))
            soft = np.asarray(soft).astype(np.float32)[..., None] / 255.0
            line = (lum(e)[..., None] < 0.35) * a  # the dark lash line stays dark
            col = sc * (1 - line) + e[..., :3] * 0.5 * line
            alpha = np.clip(np.maximum(a, soft * amt * 0.9), 0, 1)
            save(np.concatenate([col, alpha], axis=2), f"{k}_eyeline.png")
        if "lips" in lk:
            f = load("v_face.png").copy()
            box = f[700:820, 420:605]
            d = box[..., 0] - box[..., 1]
            mk = np.clip((d - 0.12) * 8.0, 0, 1)
            mk = np.asarray(Image.fromarray((mk * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.5))).astype(np.float32)[..., None] / 255.0
            bl = lum(box)[..., None]
            lip = np.clip(np.array(lk["lips"]) * (0.55 + bl * 0.6), 0, 1)
            box[..., :3] = box[..., :3] * (1 - mk) + lip * mk
            f[700:820, 420:605] = box
            save(f, f"{k}_face.png")
        print("baked", k)


if __name__ == "__main__":
    main()
