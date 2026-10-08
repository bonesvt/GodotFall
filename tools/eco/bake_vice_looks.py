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
  cuts     [name...]  where the suit opens on her skin (CUTS below), from
           her shoulders and legs to style windows; the suit's glow and
           sheen stop there, and a thin trim edges each opening
  trim     [r, g, b]  that trim (default: the glow colour)
  from     the outfit texture a look without "pattern" starts from
           (v_body_<from>.png, default "shade")
The cuts are placed by where each texel sits on her (tools/eco/body_pos.png,
from bake_body_pos.py). Each look also gets <look>_mask.png, her suit mask
with the openings taken out.
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


# Her body in metres (bake_body_pos.py): x her side, y forward, z up, T-pose.
POS_RANGE = np.array([[-0.75, 0.75], [-0.15, 0.15], [0.0, 1.7]], dtype=np.float32)


def body_pos(size):
    a = np.asarray(Image.open(REPO / "tools/eco/body_pos.png").resize(size, Image.NEAREST)).astype(np.float32) / 255.0
    p = a[..., :3] * (POS_RANGE[:, 1] - POS_RANGE[:, 0]) + POS_RANGE[:, 0]
    return p[..., 0], p[..., 1], p[..., 2], a[..., 3] > 0.5


def cut_regions(x, y, z, on):
    ax = np.abs(x)
    arm = on & (z > 1.15) & (ax < 0.58)       # her arms out in the T-pose, up to her wrists (gloves stay)
    leg = on & (z > 0.1) & (z < 0.7)           # below her hips (her knees are at ~0.55), down to her ankles
    torso = on & (z > 0.7) & (z < 1.45) & (ax < 0.17)
    return {
        "sleeveless": arm & (ax > 0.17),
        "short_sleeves": arm & (ax > 0.30),
        "sleeve_l": arm & (x > 0.17),            # one sleeve torn off
        "off_shoulder": on & (z > 1.28) & (ax > 0.07) & (ax < 0.32) & ~(torso & (z < 1.33)),
        "collar": on & (z > 1.36) & (ax < 0.17) & (y > -0.03),
        "midriff": torso & (z > 1.02) & (z < 1.15) & (ax < 0.09) & (y > 0.03),
        "back": torso & (z > 1.05) & (z < 1.32) & (ax < 0.09) & (y < -0.02),
        "hips": torso & (z > 0.92) & (z < 1.04) & (ax > 0.1),
        "shorts": leg & (z < 0.68),
        "shorts_r": leg & (z < 0.68) & (x < 0),   # one leg torn off
        "thigh_gap": leg & (z > 0.6) & (z < 0.68),
        "calves": leg & (z < 0.5),
    }


def skin_source(size):
    """Her bare skin: from the outfits that show it, plain skin where none does."""
    src = np.zeros((size[1], size[0], 3), np.float32)
    got = np.zeros((size[1], size[0]), bool)
    for v in ["vesper_open", "date_m", "skater_m", "date_t", "skater_t", "vesper"]:
        b = load(f"v_body_{v}.png", size)[..., :3]
        m = load(f"v_body_mask_{v}.png", size)
        sk = (m[..., 0] < 0.5) & (m[..., 1] < 0.5) & (b[..., 0] > 0.55) & (b[..., 0] > b[..., 2] + 0.03) & ~got
        src[sk] = b[sk]
        got |= sk
    plain = np.median(src[got], axis=0)
    # anything darker than skin is a stocking or seam another outfit drew there
    dark = lum(src) < lum(plain[None, None]) * 0.88
    src[~got | dark] = plain
    return src


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
    px, py, pz, on = body_pos((W, H))
    regions = cut_regions(px, py, pz, on)
    skin_tex = skin_source((W, H))

    def cuts(lk):
        """The look's openings (soft-edged) and the trim round them, both 0..1."""
        cut = np.zeros((H, W), bool)
        for name in lk.get("cuts", []):
            cut |= regions[name]
        if not cut.any():
            return None, None
        im = Image.fromarray((cut * 255).astype(np.uint8))
        grown = np.asarray(im.filter(ImageFilter.MaxFilter(7))).astype(np.float32) / 255.0
        soft = np.asarray(im.filter(ImageFilter.GaussianBlur(1.2))).astype(np.float32) / 255.0
        trim = np.clip(grown - soft, 0, 1) * on
        return soft[..., None], trim[..., None]

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
        cut, trim = cuts(lk)
        skin = np.array(lk.get("skin", [1, 1, 1]), dtype=np.float32)
        gc = np.array(lk.get("glow", [0, 0, 0]), dtype=np.float32)
        if "pattern" in lk:
            pat = pattern(lk["pattern"])
            shaded = np.clip(pat * (0.35 + L * 2.4), 0, 1)
            if lk["pattern"][0] == "veins":  # the seams stay their own bright colour
                seam = np.abs(pat - np.array(lk["pattern"][2])).sum(axis=2, keepdims=True) < 0.05
                shaded = np.where(seam, np.array(lk["pattern"][2]), shaded)
            rgb = body[..., :3] * skin * (1 - fabric) + shaded * fabric
            alpha, glow_lines, mask_from = body[..., 3:], g, "v_body_mask_shade.png"
        elif cut is not None:
            src = lk.get("from", "shade")
            base = load(f"v_body_{src}.png")
            rgb, alpha = base[..., :3], base[..., 3:]
            glow_lines = load(f"v_body_glow_{src}.png")[..., :3]
            glow_lines = glow_lines.max(axis=2, keepdims=True)
            if "glow" not in lk:
                gc = np.ones(3, np.float32)
            mask_from = f"v_body_mask_{src}.png"
        if cut is not None:
            tc = np.array(lk.get("trim", gc if gc.any() else [0.08, 0.07, 0.09]), dtype=np.float32)
            rgb = rgb * (1 - cut) + skin_tex * skin * cut
            rgb = rgb * (1 - trim) + np.clip(tc * (0.55 + L * 1.2), 0, 1) * trim
            gh, gw = glow_lines.shape[:2]
            off = Image.fromarray((np.maximum(cut, trim)[..., 0] * 255).astype(np.uint8)).resize((gw, gh), Image.BILINEAR)
            glow_lines = glow_lines * (1 - np.asarray(off).astype(np.float32)[..., None] / 255.0)
            m = load(mask_from, (W, H))
            m[..., :2] *= 1 - cut
            Image.fromarray((np.clip(m, 0, 1) * 255 + 0.5).astype(np.uint8)).resize((1024, 1024), Image.BILINEAR).save(OUT / f"{k}_mask.png", optimize=True)
        if "pattern" in lk or cut is not None:
            save(np.concatenate([rgb, alpha], axis=2), f"{k}_body.png")
            save(np.concatenate([glow_lines * gc, np.ones_like(glow_lines)], axis=2), f"{k}_glow.png")
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
