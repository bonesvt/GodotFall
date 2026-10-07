"""Builds Eco's Hush courier suit (eco_model.gd "suit_hush", her reward for
Marrow's Hold reaching full: vices.gd) from her shade catsuit's textures
(numpy + pillow, no Blender): the same cut and cowl, the black fabric dyed a
deep violet-black with a faint plum sheen, and the crimson piping turned to
the Hush's violet glow. Her skin (outside the mask's green) is left alone.

    python3 tools/eco/build_hush_suit.py

Reads  assets/textures/eco/v_body_shade.png, v_body_mask_shade.png, v_body_glow_shade.png
Writes assets/textures/eco/v_body_hush.png, v_body_glow_hush.png
"""
from pathlib import Path

import numpy as np
from PIL import Image

TEX = Path(__file__).resolve().parents[2] / "assets" / "textures" / "eco"
# the fabric's new colour at full brightness (multiplied by the shade suit's
# own brightness, lifted so the black reads as violet at all)
VIOLET = np.array([0.42, 0.20, 0.62])
LIFT = np.array([0.045, 0.018, 0.075])
# the Hush's glow (eco_toon.gdshaderinc HUSH_VIOLET)
GLOW = np.array([0.72, 0.32, 1.0])


def main() -> None:
    body = np.asarray(Image.open(TEX / "v_body_shade.png").convert("RGB")).astype(np.float32) / 255.0
    mask = Image.open(TEX / "v_body_mask_shade.png").convert("RGB").resize(body.shape[1::-1], Image.BILINEAR)
    fabric = (np.asarray(mask).astype(np.float32)[..., 1:2] / 255.0)
    lum = body @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    dyed = np.clip(lum[..., None] * VIOLET * 2.2 + LIFT, 0.0, 1.0)
    out = body * (1.0 - fabric) + dyed * fabric
    Image.fromarray((out * 255.0 + 0.5).astype(np.uint8)).save(TEX / "v_body_hush.png", optimize=True)

    glow = np.asarray(Image.open(TEX / "v_body_glow_shade.png").convert("RGB")).astype(np.float32) / 255.0
    strength = glow.max(axis=2, keepdims=True)
    Image.fromarray((np.clip(strength * GLOW, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)).save(
        TEX / "v_body_glow_hush.png", optimize=True)
    print("wrote v_body_hush.png, v_body_glow_hush.png")


if __name__ == "__main__":
    main()
