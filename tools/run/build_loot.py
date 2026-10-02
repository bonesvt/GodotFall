"""Models the run loot in Blender and exports it as glTF.

    blender -b --python tools/run/build_loot.py

Writes assets/models/loot/<name>.glb, with the conventions of
tools/hub/build_props.py (whose helpers this reuses): low-poly, flat shaded,
objects named "<part>__<material>" so the game swaps in its own materials,
origins on the ground.

  supply_crate   a militia supply crate; press F to pry the lid off
  alloy_node     a titan wreck half sunk in the ground, alloy veins glowing
                 through the cracks; hold F to mine it
  scrap_bundle   pickup: bent plate and a bolt, bound with wire
  alloy_chunk    pickup: a lump of raw titan alloy
  circuit_chip   pickup: a salvaged circuit board
"""
import math
import random
import sys
from pathlib import Path

from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "hub"))
import build_props as bp  # noqa: E402
from build_props import blob, box, new_bm, part, tapered_tube  # noqa: E402

bp.OUT = Path(__file__).resolve().parent.parent.parent / "assets" / "models" / "loot"


def supply_crate():
    body = new_bm()
    box(body, (0, 0, 0.24), (0.9, 0.55, 0.46), bevel=0.02)
    part(body, "body", "wood")
    lid = new_bm()
    box(lid, (0, 0, 0.5), (0.94, 0.59, 0.07), bevel=0.015)
    part(lid, "lid", "wood")
    straps = new_bm()
    for x in (-0.3, 0.3):
        box(straps, (x, 0, 0.27), (0.07, 0.57, 0.5))
    for sx in (-1, 1):
        box(straps, (sx * 0.47, 0, 0.3), (0.03, 0.16, 0.08))
    part(straps, "straps", "gunmetal")
    tag = new_bm()
    box(tag, (0, -0.282, 0.3), (0.3, 0.01, 0.1))
    part(tag, "tag", "light")
    bp.export("supply_crate")


def alloy_node():
    rng = random.Random(5)
    base = new_bm()
    blob(base, (0, 0, 0.15), (1.5, 1.2, 0.55), rng, subdiv=1, wobble=0.2, seed=3)
    for k in range(4):
        a = k * math.pi / 2 + 0.4
        blob(base, (math.cos(a) * 1.0, math.sin(a) * 0.8, 0.05), (0.45, 0.4, 0.3), rng, subdiv=1, wobble=0.25, seed=k)
    part(base, "base", "rock")
    plates = new_bm()
    # Armour shards jutting out of the ground at angles, like a buried titan limb.
    for k, (x, y, h, r) in enumerate(((-0.3, 0.1, 1.3, 0.3), (0.35, -0.15, 1.0, -0.4), (0.0, 0.35, 0.8, 1.2), (0.6, 0.3, 0.6, 0.8))):
        tmp_center = (x, y, h * 0.5)
        box(plates, tmp_center, (0.55, 0.14, h), rot_z=r, bevel=0.04)
    tapered_tube(plates, [(-0.7, -0.3, 0.2), (-0.5, -0.4, 0.9), (-0.2, -0.45, 1.1)], [0.12, 0.1, 0.08], sides=6)
    part(plates, "plates", "titan_armor")
    veins = new_bm()
    for k, (x, y, z, rz) in enumerate(((-0.18, 0.02, 0.75, 0.3), (0.45, -0.25, 0.55, -0.4), (0.1, 0.25, 0.4, 1.2), (-0.5, 0.35, 0.35, 0.2), (0.3, 0.45, 0.25, 0.8))):
        box(veins, (x, y, z), (0.12, 0.16, 0.5 - k * 0.05), rot_z=rz)
        box(veins, (x * 1.1, y * 1.1, 0.3), (0.2, 0.08, 0.1), rot_z=rz + 0.5)
    part(veins, "veins", "light")
    bp.export("alloy_node")


def scrap_bundle():
    m = new_bm()
    box(m, (0, 0, 0.05), (0.22, 0.14, 0.03), rot_z=0.3)
    box(m, (0.02, 0.01, 0.09), (0.18, 0.1, 0.03), rot_z=-0.4)
    tapered_tube(m, [(-0.06, -0.05, 0.03), (-0.06, -0.05, 0.16)], [0.025, 0.025], sides=6)
    part(m, "plates", "gunmetal")
    w = new_bm()
    box(w, (0, 0, 0.07), (0.02, 0.17, 0.09))
    part(w, "wire", "rope")
    bp.export("scrap_bundle")


def alloy_chunk():
    m = new_bm()
    blob(m, (0, 0, 0.08), (0.14, 0.11, 0.1), random.Random(9), subdiv=1, wobble=0.3, seed=2)
    part(m, "chunk", "titan_armor")
    v = new_bm()
    box(v, (0.0, -0.09, 0.09), (0.12, 0.03, 0.04), rot_z=0.3)
    part(v, "vein", "light")
    bp.export("alloy_chunk")


def circuit_chip():
    m = new_bm()
    box(m, (0, 0, 0.02), (0.18, 0.12, 0.012))
    part(m, "board", "moss")
    c = new_bm()
    box(c, (0.02, 0.0, 0.035), (0.06, 0.05, 0.02))
    box(c, (-0.05, 0.03, 0.03), (0.03, 0.03, 0.015))
    part(c, "chips", "gunmetal")
    g = new_bm()
    for k in range(4):
        box(g, (-0.07 + k * 0.035, -0.045, 0.028), (0.012, 0.012, 0.008))
    part(g, "leds", "light")
    bp.export("circuit_chip")


bp.clear()
supply_crate()
alloy_node()
scrap_bundle()
alloy_chunk()
circuit_chip()
