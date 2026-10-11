# Cloth masks for the NPCs' body textures (the hero look's skin/cloth split):
# for every assets/textures/npc/<who>/body[_<outfit>].png, writes
# body_mask[_<outfit>].png beside it, G = their clothes (anything that isn't
# skin), R = 0 (no sheen). npc_import.gd and hub_npc.gd wear() hand it to the
# toon shader (eco_toon.gdshaderinc), so clothes shade with a cooler tint and
# only bare skin gets the warm band where light turns to shade.
#
# Skin is found per texture: VRoid bodies share one UV layout, and the fingers
# (two columns at the bottom of the sheet) are always bare, so their colour is
# this texture's skin; everything near that colour (allowing for the painted
# shading) counts as skin.
#   python3 tools/npc/build_npc_masks.py [who ...]     (default: every NPC)
#   --preview out.jpg   also writes a contact sheet of textures and masks
import os, sys
import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
NPC = os.path.join(ROOT, "assets", "textures", "npc")
SIZE = 1024
# the finger columns, in the shared VRoid body layout (fractions of the sheet)
FINGERS = [(0.252, 0.29, 0.74, 0.97), (0.71, 0.748, 0.74, 0.97)]


def skin_ref(a):
    h, w, _ = a.shape
    px = np.concatenate([a[int(y0 * h):int(y1 * h), int(x0 * w):int(x1 * w)].reshape(-1, 3)
                         for x0, x1, y0, y1 in FINGERS])
    lum = px.mean(1)
    px = px[lum > np.percentile(lum, 40)]          # the lit finger tops, not the dark gaps
    return np.median(px, 0)


def mask_for(path):
    a = np.asarray(Image.open(path).convert("RGB").resize((SIZE, SIZE), Image.BOX), np.float32) / 255
    ref = skin_ref(a)
    lum = a.mean(-1) + 1e-4
    rl = ref.mean()
    chroma = a / lum[..., None] - ref / rl
    skin = (np.linalg.norm(chroma, axis=-1) < 0.085) & (lum > rl * 0.55) & (lum < rl * 1.2)
    m = Image.fromarray((skin * 255).astype(np.uint8))
    # close pinholes in the skin (painted shading), drop specks of "skin" on cloth
    m = m.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.MinFilter(3))
    m = m.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(3))
    cloth = 255 - np.asarray(m)
    out = np.zeros((SIZE, SIZE, 3), np.uint8)
    out[..., 1] = cloth
    img = Image.fromarray(out).filter(ImageFilter.GaussianBlur(0.8))
    return img, ref


def main():
    args = sys.argv[1:]
    preview = None
    if "--preview" in args:
        i = args.index("--preview"); preview = args[i + 1]; del args[i:i + 2]
    whos = args or sorted(d for d in os.listdir(NPC) if os.path.isdir(os.path.join(NPC, d)))
    tiles = []
    for who in whos:
        d = os.path.join(NPC, who)
        for f in sorted(os.listdir(d)):
            if not (f == "body.png" or (f.startswith("body_") and f.endswith(".png") and not f.startswith("body_mask"))):
                continue
            img, ref = mask_for(os.path.join(d, f))
            out = os.path.join(d, f.replace("body", "body_mask", 1))
            img.save(out, optimize=True)
            print(out, "skin", np.round(ref, 3))
            tiles.append((f"{who}/{f}", os.path.join(d, f), out))
    if preview:
        T = 220
        sheet = Image.new("RGB", (T * 4, T * ((len(tiles) + 1) // 2)), (30, 30, 30))
        for k, (name, src, msk) in enumerate(tiles):
            x = (k % 2) * T * 2; y = (k // 2) * T
            s = Image.open(src).convert("RGB").resize((T, T))
            mk = np.asarray(Image.open(msk).convert("RGB").resize((T, T)), np.float32)[..., 1:2] / 255
            over = (np.asarray(s, np.float32) * (1 - 0.6 * mk) + np.array([40, 200, 90]) * 0.6 * mk).astype(np.uint8)
            sheet.paste(s, (x, y)); sheet.paste(Image.fromarray(over), (x + T, y))
        sheet.save(preview, quality=85)


if __name__ == "__main__":
    main()
