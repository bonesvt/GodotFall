"""Models Solace's gift shop and the gifts it sells (scripts/hub/gift_shop.gd)
in Blender and exports glTF.

    blender -b --factory-startup --python tools/town/build_gifts.py

Writes assets/models/town/gift_shop.glb (the kiosk, spawned like the other town
props) and assets/models/gifts/<gift id>.glb, one per gift. Same conventions
as tools/town/build_town.py (its Model helper is reused): meshes are named
"<part>__<material>", origins sit on the ground / shelf. The gifts add a
palette of plain paint colours, "gift_<colour>" (GiftShop.PAINT), on top of
the town's materials (glass, glass_dark, glow_*).

Gifts are modelled at real size (a cassette is 10 cm); the shelves and the
shop screen scale them up to be read.

Seeded, so re-running gives the same meshes.
"""
import math
import sys
from pathlib import Path

import bmesh
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "hub"))
import build_props as bp  # noqa: E402
import build_town as bt  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent.parent / "assets" / "models"

# The kiosk's back shelves: heights (z) of each shelf top, the depth (y) of
# their front edge, and the width they span. gift_shop.gd places the gifts
# from the same numbers.
SHELF_Z = (0.95, 1.5, 2.05)
SHELF_Y = 2.55
SHELF_W = 4.2


def cone(m, mat, center, r1, r2, depth, sides=10):
    tmp = bmesh.new()
    res = bmesh.ops.create_cone(tmp, cap_ends=True, segments=sides, radius1=r1, radius2=r2, depth=depth)
    bmesh.ops.translate(tmp, vec=Vector(center), verts=res["verts"])
    bp.merge(m.bm(mat), tmp)


# --- the kiosk ------------------------------------------------------------------

def gift_shop():
    """A little boutique kiosk, open at the front: rounded pale walls, three
    shelves across the back for the gifts, a glass counter with a till, a
    candy-striped awning, paper lanterns and ribbon bunting, and a neon heart
    tied with a bow on the roof. Faces -Y, 5.2 wide (x), 3.2 deep; origin at the
    middle of the open front."""
    m = bt.Model("gift_shop", 211)
    W, D, H = 5.2, 3.2, 3.0
    # Shell: back, sides, roof slab, floor.
    m.rounded("wall", (0, D - 0.1, H * 0.5), (W, 0.2, H), 0.1)
    for s in (-1, 1):
        m.rounded("wall", (s * (W * 0.5 - 0.1), D * 0.5, H * 0.5), (0.2, D, H), 0.08)
        m.box("trim", (s * (W * 0.5 - 0.1), -0.02, H * 0.5), (0.34, 0.12, H + 0.1), bevel=0.03)
    m.rounded("trim", (0, D * 0.5, H + 0.1), (W + 0.3, D + 0.3, 0.2), 0.2)
    m.box("wood", (0, D * 0.5, 0.03), (W - 0.4, D - 0.2, 0.06))
    m.box("trim", (0, -0.02, H - 0.15), (W, 0.12, 0.3))
    # Lit back wall behind the shelves (takes the shop colour), shelves and brackets.
    m.box("glow_shop", (0, D - 0.21, 1.55), (SHELF_W + 0.2, 0.02, 1.7))
    for z in SHELF_Z:
        m.box("wood", (0, SHELF_Y + 0.22, z - 0.03), (SHELF_W, 0.44, 0.06), bevel=0.01)
        m.box("glow_warm", (0, SHELF_Y + 0.0, z - 0.065), (SHELF_W - 0.1, 0.02, 0.012))
        for x in (-SHELF_W * 0.5 + 0.15, 0, SHELF_W * 0.5 - 0.15):
            m.box("metal", (x, SHELF_Y + 0.38, z - 0.12), (0.04, 0.1, 0.14))
    # Low display table under the shelves (wrapped boxes stacked on it).
    m.box("wood", (0, SHELF_Y + 0.2, 0.3), (SHELF_W, 0.5, 0.6), bevel=0.02)
    wraps = ["canvas", "trim", "glow_shop"]
    for k in range(7):
        x = -1.8 + k * 0.6 + m.rng.uniform(-0.08, 0.08)
        size = (m.rng.uniform(0.22, 0.34), m.rng.uniform(0.18, 0.28), m.rng.uniform(0.12, 0.22))
        m.box(wraps[k % 3] if k % 3 != 2 else "canvas", (x, SHELF_Y + 0.15, 0.6 + size[2] * 0.5), size, rot=(0, 0, m.rng.uniform(-0.3, 0.3)))
        m.box("glow_red" if k % 2 else "glow_warm", (x, SHELF_Y + 0.15, 0.6 + size[2] * 0.5), (0.03, size[1] + 0.01, size[2] + 0.01), rot=(0, 0, 0))
    # Counter on the right with a glass case and a till.
    cx = 1.45
    m.box("trim", (cx, 0.75, 0.5), (1.9, 0.6, 1.0), bevel=0.03)
    m.box("dark", (cx, 0.44, 0.5), (1.7, 0.02, 0.7))
    m.box("glass", (cx, 0.75, 1.15), (1.8, 0.5, 0.3))
    m.box("glow_shop", (cx, 0.75, 1.01), (1.7, 0.45, 0.02))
    m.box("dark", (cx + 0.5, 0.8, 1.4), (0.36, 0.3, 0.2), bevel=0.02)
    m.box("glow_cyan", (cx + 0.5, 0.66, 1.52), (0.26, 0.02, 0.1), rot=(0.4, 0, 0))
    # Ribbon reels on a rod on the left wall.
    m.cyl("metal", (-W * 0.5 + 0.35, 1.4, 1.8), 0.015, 1.6, sides=5, rot=(math.pi / 2, 0, 0))
    for k in range(5):
        m.cyl(["canvas", "glow_red", "trim", "glow_shop", "canvas"][k], (-W * 0.5 + 0.35, 0.8 + k * 0.3, 1.8), 0.11, 0.08, sides=10, rot=(math.pi / 2, 0, 0))
    # Candy-striped awning and bunting.
    for k in range(10):
        m.box("canvas" if k % 2 == 0 else "trim", (-W * 0.5 + 0.26 + k * 0.52, -0.5, H - 0.25), (0.52, 1.0, 0.04), rot=(0.32, 0, 0))
    for k in range(11):
        m.box("canvas" if k % 2 == 0 else "glow_shop", (-2.4 + k * 0.48, -1.0, H - 0.6), (0.24, 0.02, 0.24), rot=(0, math.pi / 4, 0))
    # Paper lanterns hanging inside.
    for x in (-1.3, 0.2):
        m.tube("metal", [(x, 1.3, H - 0.05), (x, 1.3, H - 0.4)], [0.01, 0.01], 3)
        m.tube("glow_paper", [(x, 1.3, H - 0.4), (x, 1.3, H - 0.52), (x, 1.3, H - 0.72), (x, 1.3, H - 0.82)], [0.1, 0.17, 0.17, 0.1], 10)
    # Neon heart on the roof, a ribbon bow on top.
    hz, hy = H + 1.05, D * 0.5
    pts = []
    for k in range(24):
        t = 2 * math.pi * k / 24
        x = 16 * math.sin(t) ** 3
        z = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((x * 0.045, hy, hz + z * 0.045))
    pts.append(pts[0])
    m.tube("neon", pts, [0.06] * len(pts), 6)
    for s in (-1, 1):
        m.blob("glow_red", (s * 0.22, hy, hz + 0.75), (0.2, 0.06, 0.12), wobble=0.05)
        m.tube("glow_red", [(0, hy, hz + 0.72), (s * 0.18, hy, hz + 0.45)], [0.04, 0.03], 5)
    m.blob("glow_red", (0, hy, hz + 0.75), (0.07, 0.07, 0.07), wobble=0.0)
    for s in (-1, 1):
        m.cyl("metal", (s * 0.5, hy, H + 0.35), 0.03, 0.5, sides=5)
    m.export()


# --- the gifts ------------------------------------------------------------------

def candles():
    """Three black pillar candles on a little pewter dish, wax dripping, lit."""
    m = bt.Model("candles", 301)
    m.cyl("gift_silver", (0, 0, 0.008), 0.11, 0.016, sides=14)
    for (x, y, h) in ((-0.045, 0.01, 0.15), (0.04, -0.02, 0.11), (0.02, 0.05, 0.075)):
        m.cyl("gift_black", (x, y, 0.016 + h * 0.5), 0.026, h, sides=10)
        for k in range(3):
            a = k * 2.1 + x * 40
            m.tube("gift_black", [(x + math.cos(a) * 0.026, y + math.sin(a) * 0.026, 0.016 + h), (x + math.cos(a) * 0.027, y + math.sin(a) * 0.027, 0.016 + h * 0.6)], [0.007, 0.004], 4)
        m.tube("gift_cream", [(x, y, 0.016 + h), (x, y, 0.016 + h + 0.012)], [0.002, 0.002], 3)
        m.blob("glow_warm", (x, y, 0.016 + h + 0.024), (0.009, 0.009, 0.018), wobble=0.05)
    m.export()


def tape():
    """A mixtape standing up: black shell, a hand-written label, two reels."""
    m = bt.Model("tape", 303)
    m.box("gift_black", (0, 0, 0.032), (0.1, 0.012, 0.064), bevel=0.003)
    m.box("gift_white", (0, -0.0062, 0.04), (0.086, 0.001, 0.036))
    m.box("gift_red", (0, -0.0065, 0.054), (0.086, 0.001, 0.006))
    m.box("glass_dark", (0, -0.0068, 0.038), (0.04, 0.001, 0.014))
    for x in (-0.022, 0.022):
        m.cyl("gift_white", (x, -0.0068, 0.038), 0.007, 0.002, sides=8, rot=(math.pi / 2, 0, 0))
    m.box("gift_black", (0, -0.006, 0.008), (0.06, 0.003, 0.012))
    # Case lying open behind it.
    m.box("glass", (0, 0.03, 0.004), (0.11, 0.07, 0.008))
    m.box("gift_purple", (0, 0.03, 0.009), (0.1, 0.06, 0.001))
    m.export()


def book():
    """A battered paperback, standing: purple cover, a gold lighthouse on it."""
    m = bt.Model("book", 307)
    m.box("gift_purple", (0, 0, 0.095), (0.13, 0.034, 0.19), bevel=0.003)
    m.box("gift_cream", (0.004, 0, 0.095), (0.126, 0.03, 0.182))
    m.box("gift_purple", (-0.0645, 0, 0.095), (0.004, 0.036, 0.19))
    m.box("gift_gold", (-0.0665, 0, 0.16), (0.002, 0.03, 0.01))
    # The lighthouse: tower, lamp, beams.
    m.box("gift_gold", (0.005, -0.0175, 0.08), (0.016, 0.002, 0.07))
    m.box("gift_gold", (0.005, -0.0175, 0.122), (0.024, 0.002, 0.012))
    m.box("glow_warm", (0.005, -0.018, 0.132), (0.01, 0.002, 0.01))
    for s in (-1, 1):
        m.box("gift_gold", (0.005 + s * 0.03, -0.0175, 0.134), (0.05, 0.001, 0.004), rot=(0, s * 0.18, 0))
    m.export()


def flowers():
    """A bouquet of sun lilies in a paper cone tied with ribbon."""
    m = bt.Model("flowers", 311)
    tmp = bmesh.new()
    res = bmesh.ops.create_cone(tmp, cap_ends=False, segments=10, radius1=0.015, radius2=0.08, depth=0.22)
    bmesh.ops.translate(tmp, vec=Vector((0, 0, 0.11)), verts=res["verts"])
    bp.merge(m.bm("gift_cream"), tmp)
    m.cyl("gift_pink", (0, 0, 0.08), 0.038, 0.02, sides=10)
    for k in range(9):
        a = k * 2.4
        r = 0.03 + 0.03 * (k % 3) / 2
        top = (math.cos(a) * r * 1.4, math.sin(a) * r * 1.4, 0.26 + (k % 3) * 0.03)
        m.tube("gift_green", [(math.cos(a) * 0.01, math.sin(a) * 0.01, 0.05), top], [0.003, 0.003], 4)
        mat = "gift_yellow" if k % 3 else "gift_white"
        for p in range(5):
            b = p * 2 * math.pi / 5 + a
            m.blob(mat, (top[0] + math.cos(b) * 0.018, top[1] + math.sin(b) * 0.018, top[2] + 0.005), (0.016, 0.016, 0.006), wobble=0.1)
        m.blob("gift_gold", (top[0], top[1], top[2] + 0.01), (0.007, 0.007, 0.007), wobble=0.0)
    for k in range(4):
        a = k * 1.6 + 0.4
        m.blob("gift_green", (math.cos(a) * 0.06, math.sin(a) * 0.06, 0.22), (0.03, 0.012, 0.05), wobble=0.1)
    m.export()


def perfume():
    """A pink glass perfume bottle with a gold cap and a squeeze bulb."""
    m = bt.Model("perfume", 313)
    m.rounded("gift_pink", (0, 0, 0.045), (0.07, 0.04, 0.09), 0.015)
    m.box("glass", (0, 0, 0.05), (0.074, 0.044, 0.07))
    m.cyl("gift_gold", (0, 0, 0.1), 0.012, 0.02, sides=10)
    m.tube("gift_gold", [(0, 0, 0.11), (0.03, 0, 0.115), (0.05, 0, 0.1)], [0.003, 0.003, 0.003], 4)
    m.blob("gift_pink", (0.06, 0, 0.09), (0.016, 0.016, 0.02), wobble=0.05)
    m.box("gift_gold", (0, -0.021, 0.045), (0.03, 0.002, 0.02))
    m.export()


def arcade_tokens():
    """Glowbox tokens: a velvet pouch spilling stacks of brass coins."""
    m = bt.Model("arcade_tokens", 317)
    m.blob("gift_purple", (0.03, 0.02, 0.035), (0.045, 0.04, 0.04), subdiv=2, wobble=0.12)
    m.cyl("gift_gold", (0.03, 0.02, 0.08), 0.015, 0.015, sides=8)
    for (x, y, n) in ((-0.04, -0.01, 6), (-0.012, -0.035, 4), (-0.05, -0.045, 2)):
        for k in range(n):
            m.cyl("gift_gold", (x + (k % 2) * 0.001, y, 0.003 + k * 0.0055), 0.012, 0.005, sides=12)
        m.box("glow_cyan", (x, y, 0.0058 * n + 0.0005), (0.008, 0.008, 0.001))
    m.cyl("gift_gold", (0.02, -0.04, 0.012), 0.012, 0.005, sides=12, rot=(1.2, 0, 0))
    m.export()


def cigarettes():
    """A flip-top pack of Night Owls, three sticking out, and a steel lighter."""
    m = bt.Model("cigarettes", 319)
    m.box("gift_black", (0, 0, 0.04), (0.055, 0.022, 0.08))
    m.box("gift_red", (0, -0.0112, 0.05), (0.055, 0.001, 0.014))
    m.box("gift_white", (0, -0.0113, 0.025), (0.03, 0.001, 0.02))
    m.box("gift_black", (0, 0.016, 0.092), (0.055, 0.012, 0.022), rot=(-1.1, 0, 0))   # open lid
    for k, x in enumerate((-0.014, 0.0, 0.014)):
        h = 0.012 + k % 2 * 0.008
        m.cyl("gift_white", (x, 0, 0.08 + h * 0.5), 0.0038, h, sides=6)
        m.cyl("gift_gold", (x, 0, 0.08 + h - 0.003), 0.004, 0.006, sides=6)
    m.box("gift_silver", (0.06, 0.0, 0.028), (0.026, 0.013, 0.056), bevel=0.002)
    m.box("gift_black", (0.06, 0.0, 0.058), (0.012, 0.01, 0.006))
    m.export()


def eyeliner():
    """Two eyeliner pencils on a little pink card, one uncapped."""
    m = bt.Model("eyeliner", 323)
    m.box("gift_pink", (0, 0, 0.002), (0.08, 0.14, 0.004))
    for k, x in enumerate((-0.015, 0.015)):
        m.cyl("gift_black", (x, 0, 0.01), 0.0055, 0.11, sides=8, rot=(math.pi / 2, 0, 0))
        m.cyl("gift_silver", (x, -0.05 if k else 0.05, 0.01), 0.006, 0.012, sides=8, rot=(math.pi / 2, 0, 0))
    m.cyl("gift_silver", (0.015, 0.06, 0.01), 0.0065, 0.03, sides=8, rot=(math.pi / 2, 0, 0))
    m.export()


def records():
    """A vinyl LP standing in its sleeve: a black moon on purple, the record
    half out with a red label."""
    m = bt.Model("records", 329)
    m.cyl("gift_black", (0.07, 0.0, 0.15), 0.15, 0.003, sides=24, rot=(math.pi / 2, 0, 0))
    m.cyl("gift_red", (0.07, -0.002, 0.15), 0.05, 0.002, sides=16, rot=(math.pi / 2, 0, 0))
    m.box("gift_purple", (0, -0.004, 0.155), (0.31, 0.004, 0.31))
    m.cyl("gift_black", (0, -0.0065, 0.18), 0.075, 0.001, sides=20, rot=(math.pi / 2, 0, 0))
    m.cyl("gift_purple", (0.025, -0.0072, 0.195), 0.07, 0.001, sides=20, rot=(math.pi / 2, 0, 0))
    m.box("gift_white", (0, -0.0068, 0.05), (0.2, 0.001, 0.016))
    m.export()


def horror_movie():
    """A holo-reel case for 'Nobody Came': a red eye on black, a glowing disc."""
    m = bt.Model("horror_movie", 331)
    m.box("gift_black", (0, 0, 0.095), (0.135, 0.015, 0.19), bevel=0.003)
    m.box("gift_red", (0, -0.0078, 0.11), (0.12, 0.001, 0.13))
    m.blob("gift_white", (0, -0.0085, 0.12), (0.035, 0.002, 0.018), wobble=0.0)
    m.blob("glow_red", (0, -0.0095, 0.12), (0.012, 0.002, 0.012), wobble=0.0)
    m.box("gift_white", (0, -0.0082, 0.03), (0.1, 0.001, 0.012))
    m.cyl("glow_cyan", (0.06, 0.02, 0.005), 0.04, 0.003, sides=16)
    m.cyl("gift_silver", (0.06, 0.02, 0.0075), 0.01, 0.003, sides=10)
    m.export()


def black_lipstick():
    """A black lipstick twisted up in a silver case, its cap beside it."""
    m = bt.Model("black_lipstick", 337)
    m.cyl("gift_silver", (0, 0, 0.022), 0.012, 0.044, sides=10)
    m.cyl("gift_black", (0, 0, 0.05), 0.009, 0.012, sides=10)
    tmp = bmesh.new()
    res = bmesh.ops.create_cone(tmp, cap_ends=True, segments=10, radius1=0.0075, radius2=0.0075, depth=0.02)
    for v in res["verts"]:
        if v.co.z > 0:
            v.co.z += v.co.x * 0.8
    bmesh.ops.translate(tmp, vec=Vector((0, 0, 0.066)), verts=res["verts"])
    bp.merge(m.bm("gift_black"), tmp)
    m.cyl("gift_black", (0.035, 0.0, 0.012), 0.012, 0.045, sides=10, rot=(math.pi / 2, 0, 0.3))
    m.cyl("gift_silver", (0.035, 0.0, 0.012), 0.0125, 0.006, sides=10, rot=(math.pi / 2, 0, 0.3))
    m.export()


def makeup():
    """An open makeup compact: six dark shades, a mirror in the lid, a brush."""
    m = bt.Model("makeup", 341)
    m.box("gift_black", (0, 0, 0.008), (0.14, 0.09, 0.016), bevel=0.003)
    shades = ["gift_black", "gift_purple", "gift_red", "gift_silver", "gift_teal", "gift_pink"]
    for k, mat in enumerate(shades):
        m.box(mat, (-0.042 + (k % 3) * 0.042, -0.018 + (k // 3) * 0.036, 0.0165), (0.034, 0.03, 0.002))
    # Lid hinged open at the back, mirror inside.
    m.box("gift_black", (0, 0.048, 0.05), (0.14, 0.012, 0.09), rot=(-0.25, 0, 0))
    m.box("glass", (0, 0.04, 0.052), (0.12, 0.002, 0.075), rot=(-0.25, 0, 0))
    m.tube("gift_black", [(0.09, -0.04, 0.004), (0.09, 0.03, 0.004)], [0.003, 0.003], 5)
    m.blob("gift_black", (0.09, -0.05, 0.005), (0.006, 0.012, 0.005), wobble=0.05)
    m.export()


GIFTS = [candles, tape, book, flowers, perfume, arcade_tokens, cigarettes, eyeliner, records, horror_movie, black_lipstick, makeup]


def main():
    bp.clear()
    bt.OUT = ROOT / "town"
    gift_shop()
    bt.OUT = ROOT / "gifts"
    for g in GIFTS:
        g()


if __name__ == "__main__":
    main()
