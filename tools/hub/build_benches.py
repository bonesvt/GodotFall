"""Models the hub's workbenches in Blender and exports them as glTF.

    blender -b --python tools/hub/build_benches.py

Writes assets/models/hub/<name>.glb, with the conventions of build_props.py
(whose helpers this reuses): low-poly, flat shaded, objects named
"<part>__<material>" so scripts/hub/hub_props.gd swaps in game materials,
origins on the ground. The side you stand at faces -Y in Blender (+Z in Godot).
Empties named "*Marker" mark where the game puts things on the benches.

  gunsmith_bench   Eco's workbench in the temple: upgrades and attachments
  weapon_rack      wall rack by the bench: pick the gun you head out with
  titan_workshop   gantry in the titan yard: titan refits and starting parts
"""
import math
import random
import sys
from pathlib import Path

from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_props as bp  # noqa: E402
from build_props import box, marker, new_bm, part, tapered_tube  # noqa: E402


def gunsmith_bench():
    """A heavy plank bench, 3.4 m long: drawer cabinet, vise, a cleaning mat
    where the gun she's working on lies, parts bins, a pegboard of tools and
    an angled work lamp."""
    wood = new_bm()
    box(wood, (0, 0, 0.92), (3.4, 1.2, 0.1), bevel=0.02)
    for sx in (-1.55, 1.55):
        for sy in (-0.48, 0.48):
            box(wood, (sx, sy, 0.44), (0.12, 0.12, 0.88))
    box(wood, (0.5, 0, 0.22), (2.2, 1.0, 0.06))
    box(wood, (0, 0.62, 1.75), (3.3, 0.06, 1.5), bevel=0.01)
    box(wood, (0, 0.6, 2.53), (3.4, 0.14, 0.08))
    part(wood, "bench", "wood")
    metal = new_bm()
    # Drawer cabinet under the left end.
    box(metal, (-1.05, 0.0, 0.46), (0.95, 1.0, 0.8), bevel=0.01)
    for k in range(3):
        box(metal, (-1.05, -0.51, 0.2 + k * 0.26), (0.4, 0.04, 0.04))
    # Vise on the right end.
    box(metal, (1.35, -0.35, 1.02), (0.28, 0.2, 0.12))
    box(metal, (1.35, -0.52, 1.1), (0.28, 0.06, 0.2))
    box(metal, (1.35, -0.25, 1.1), (0.28, 0.06, 0.2))
    tapered_tube(metal, [(1.35, -0.7, 1.08), (1.35, -0.55, 1.08)], [0.015, 0.015], sides=5)
    box(metal, (1.35, -0.72, 1.08), (0.24, 0.03, 0.03))
    # Parts bins along the back of the top.
    for k in range(5):
        box(metal, (-0.9 + k * 0.32, 0.4, 1.02), (0.26, 0.24, 0.1))
    # Tools hanging on the pegboard: wrenches, a saw, a hammer, screwdrivers.
    for k in range(5):
        x = -1.4 + k * 0.17
        box(metal, (x, 0.57, 1.85 - k * 0.04), (0.04, 0.02, 0.32 + k * 0.03))
        box(metal, (x, 0.57, 2.02 - k * 0.02), (0.09, 0.02, 0.05))
    box(metal, (-0.35, 0.57, 1.7), (0.6, 0.02, 0.16))
    box(metal, (0.2, 0.57, 1.95), (0.05, 0.02, 0.4))
    box(metal, (0.2, 0.57, 2.17), (0.18, 0.02, 0.07))
    for k in range(4):
        box(metal, (0.55 + k * 0.1, 0.57, 1.75), (0.025, 0.02, 0.22))
    # Work lamp: post, arm, shade.
    tapered_tube(metal, [(1.45, 0.4, 0.97), (1.45, 0.4, 1.95), (0.85, 0.05, 2.15)], [0.025, 0.025, 0.02], sides=5)
    box(metal, (0.8, 0.02, 2.1), (0.3, 0.3, 0.12), bevel=0.02)
    part(metal, "metal", "gunmetal")
    mat = new_bm()
    box(mat, (-0.05, -0.12, 0.975), (1.3, 0.62, 0.012))
    part(mat, "mat", "canvas")
    bulb = new_bm()
    box(bulb, (0.8, 0.02, 2.03), (0.2, 0.2, 0.04))
    part(bulb, "bulb", "light")
    marker("GunMarker", (-0.05, -0.12, 1.0))
    marker("LampMarker", (0.8, 0.02, 1.95))
    bp.export("gunsmith_bench")


def weapon_rack():
    """A wall rack with three padded gun slots, an ammo crate and boxes under
    it. The guns themselves are placed by the game at Slot0..2Marker."""
    wood = new_bm()
    box(wood, (0, 0.05, 1.5), (2.6, 0.1, 1.8), bevel=0.015)
    box(wood, (0, -0.05, 0.62), (2.6, 0.3, 0.06))
    box(wood, (0.55, -0.25, 0.3), (0.9, 0.55, 0.6), bevel=0.02)
    box(wood, (-0.7, -0.2, 0.22), (0.45, 0.45, 0.44), bevel=0.02)
    part(wood, "rack", "wood")
    metal = new_bm()
    box(metal, (0, 0.0, 2.43), (2.7, 0.14, 0.08))
    box(metal, (0, 0.0, 0.57), (2.7, 0.14, 0.05))
    for x in (-1.32, 1.32):
        box(metal, (x, 0.0, 1.5), (0.06, 0.14, 1.9))
    for k in range(3):
        x = -0.85 + k * 0.85
        for dx in (-0.16, 0.16):
            tapered_tube(metal, [(x + dx, 0.0, 1.32), (x + dx, -0.14, 1.36)], [0.018, 0.016], sides=5)
    for k in range(4):
        box(metal, (0.25 + (k % 2) * 0.32, -0.25 - (k // 2) * 0.05, 0.66 + (k // 2) * 0.13), (0.28, 0.18, 0.12))
    part(metal, "metal", "gunmetal")
    pads = new_bm()
    for k in range(3):
        box(pads, (-0.85 + k * 0.85, -0.01, 1.55), (0.7, 0.04, 0.75), bevel=0.02)
    part(pads, "pads", "canvas")
    for k in range(3):
        marker("Slot%dMarker" % k, (-0.85 + k * 0.85, -0.13, 1.5))
    bp.export("weapon_rack")


def titan_workshop():
    """A gantry over a concrete slab where the titan she's refitting stands,
    with a chain hoist and a hanging core, a big workbench and tool chest,
    a rack of armour plates, oil drums and a terminal on a post."""
    rng = random.Random(41)
    slab = new_bm()
    box(slab, (0, 0.6, 0.08), (10.0, 7.0, 0.16), bevel=0.04)
    part(slab, "slab", "concrete")
    steel = new_bm()
    for x in (-3.8, 3.8):
        for y in (0.0, 2.4):
            box(steel, (x, y, 3.4), (0.3, 0.3, 6.6))
        box(steel, (x, 1.2, 6.6), (0.34, 2.8, 0.3))
        box(steel, (x, 1.2, 1.6), (0.12, 2.4, 0.12))
    box(steel, (0, 1.2, 6.85), (8.0, 0.4, 0.4))
    # Trolley and chain hoist down to the core it's holding.
    box(steel, (1.6, 1.2, 6.55), (0.5, 0.5, 0.25))
    tapered_tube(steel, [(1.6, 1.2, 6.4), (1.6, 1.2, 3.9)], [0.03, 0.03], sides=4)
    box(steel, (1.6, 1.2, 3.85), (0.15, 0.15, 0.15))
    # Rack of plates on the right.
    for z in (0.9, 1.9):
        box(steel, (4.4, -1.4, z), (1.2, 0.8, 0.06))
    for x in (3.85, 4.95):
        for y in (-1.75, -1.05):
            box(steel, (x, y, 1.2), (0.06, 0.06, 2.3))
    # Tool chest and oil drums.
    box(steel, (-2.4, -2.1, 0.55), (0.9, 0.6, 0.8), bevel=0.02)
    for k in range(4):
        box(steel, (-2.4, -2.42, 0.3 + k * 0.17), (0.7, 0.03, 0.03))
    for k, (x, y) in enumerate(((-4.4, 2.8), (-3.8, 3.4), (4.3, 3.1))):
        tapered_tube(steel, [(x, y, 0.16), (x, y, 1.06)], [0.3, 0.3], sides=8)
    # Terminal post with a screen.
    box(steel, (2.2, -2.6, 0.75), (0.12, 0.12, 1.2))
    box(steel, (2.2, -2.6, 1.45), (0.7, 0.12, 0.45), bevel=0.02)
    part(steel, "steel", "gunmetal")
    bench = new_bm()
    box(bench, (-0.6, -2.3, 0.95), (2.8, 1.0, 0.1), bevel=0.02)
    for sx in (-1.9, 0.7):
        for sy in (-2.7, -1.9):
            box(bench, (sx, sy, 0.48), (0.12, 0.12, 0.8))
    part(bench, "bench", "wood")
    armor = new_bm()
    # The core hanging off the hoist.
    box(armor, (1.6, 1.2, 3.35), (0.9, 0.9, 0.9), bevel=0.12)
    # Plates on the rack and leaning on it.
    for k in range(3):
        box(armor, (4.4 + rng.uniform(-0.2, 0.2), -1.4, 1.1 + k * 0.05), (1.0, 0.7, 0.12), rot_z=rng.uniform(-0.2, 0.2), bevel=0.04)
    box(armor, (4.0, -2.3, 0.75), (1.3, 0.15, 1.1), bevel=0.05)
    # A spare fist on the bench, and a knee plate on the slab.
    box(armor, (-1.2, -2.3, 1.2), (0.7, 0.5, 0.4), bevel=0.08)
    box(armor, (-3.2, 0.2, 0.5), (1.2, 0.9, 0.7), rot_z=0.5, bevel=0.1)
    part(armor, "armor", "titan_armor")
    glow = new_bm()
    box(glow, (1.6, 0.74, 3.35), (0.5, 0.04, 0.5))
    box(glow, (2.2, -2.67, 1.45), (0.56, 0.02, 0.32))
    part(glow, "glow", "light")
    cable = new_bm()
    tapered_tube(cable, [(1.6, 1.2, 2.9), (1.2, 0.2, 0.9), (2.2, -2.0, 0.2), (2.2, -2.5, 0.4)], [0.03, 0.03, 0.03, 0.03], sides=4)
    part(cable, "cable", "rope")
    marker("TitanMarker", (0.0, 1.2, 0.16))
    marker("ScreenMarker", (2.2, -2.68, 1.45))
    bp.export("titan_workshop")


bp.clear()
gunsmith_bench()
weapon_rack()
titan_workshop()
