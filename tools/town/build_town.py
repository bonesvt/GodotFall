"""Models Solace, Eco's hometown (scripts/hub/town.gd), in Blender and exports glTF.

    blender -b --python tools/town/build_town.py

Writes assets/models/town/<name>.glb. Same conventions as tools/hub/build_props.py:
meshes are named "<part>__<material>" and the game swaps in its own material for
each suffix (scripts/hub/town_props.gd), so no textures or UVs ship; origins
sit on the ground. Materials: wall / trim (the building's pale render, tinted
per building), base (dark ground-floor cladding), metal, dark (black gloss),
panel (solar glass), glass, leaves, moss, bark, wood, canvas (awnings, tinted),
stone (white plaza stone), water, and glow_* (unshaded light: warm, cool, shop
and neon take the shop's colour, red, cyan, lime).

Shop buildings are authored with the street front facing -Y (Godot +Z) and the
origin on the kerb line, centred along the frontage: the ground floor's front
is at y = +0.6 (set back), the upper floors' at y = -0.6 (overhanging the
pavement), and the building runs back to y = DEPTH - 0.6.

Seeded, so re-running gives the same meshes.
"""
import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "hub"))
import build_props as bp  # noqa: E402  (scene helpers shared with the hub props)

OUT = Path(__file__).resolve().parent.parent.parent / "assets" / "models" / "town"

GF = 4.4
UF = 3.4
DEPTH = 12.0


# --- a model under construction: one bmesh per material --------------------------

class Model:
    def __init__(self, name, seed=0):
        self.name = name
        self.bms = {}
        self.rng = random.Random(seed)

    def bm(self, mat):
        if mat not in self.bms:
            self.bms[mat] = bmesh.new()
        return self.bms[mat]

    def box(self, mat, center, size, rot=(0, 0, 0), bevel=0.0):
        tmp = bmesh.new()
        res = bmesh.ops.create_cube(tmp, size=1.0)
        bmesh.ops.scale(tmp, vec=Vector(size), verts=res["verts"])
        if bevel > 0.0:
            bmesh.ops.bevel(tmp, geom=list(tmp.edges), offset=min(bevel, min(size) * 0.45), segments=2, affect="EDGES")
        if any(rot):
            bmesh.ops.rotate(tmp, verts=list(tmp.verts), cent=Vector((0, 0, 0)), matrix=Euler(rot, "XYZ").to_matrix())
        bmesh.ops.translate(tmp, vec=Vector(center), verts=list(tmp.verts))
        bp.merge(self.bm(mat), tmp)

    def rounded(self, mat, center, size, radius, segments=4):
        """A box with only its vertical edges rounded (soft solarpunk corners)."""
        tmp = bmesh.new()
        res = bmesh.ops.create_cube(tmp, size=1.0)
        bmesh.ops.scale(tmp, vec=Vector(size), verts=res["verts"])
        vertical = [e for e in tmp.edges if abs(e.verts[0].co.z - e.verts[1].co.z) > 1e-4]
        bmesh.ops.bevel(tmp, geom=vertical, offset=min(radius, min(size[0], size[1]) * 0.45), segments=segments, affect="EDGES")
        bmesh.ops.translate(tmp, vec=Vector(center), verts=list(tmp.verts))
        bp.merge(self.bm(mat), tmp)

    def cyl(self, mat, center, radius, height, sides=12, rot=(0, 0, 0)):
        tmp = bmesh.new()
        res = bmesh.ops.create_cone(tmp, cap_ends=True, segments=sides, radius1=radius, radius2=radius, depth=height)
        if any(rot):
            bmesh.ops.rotate(tmp, verts=res["verts"], cent=Vector((0, 0, 0)), matrix=Euler(rot, "XYZ").to_matrix())
        bmesh.ops.translate(tmp, vec=Vector(center), verts=res["verts"])
        bp.merge(self.bm(mat), tmp)

    def tube(self, mat, points, radii, sides=6):
        bp.tapered_tube(self.bm(mat), [Vector(p) for p in points], radii, sides=sides)

    def blob(self, mat, center, size, subdiv=1, wobble=0.22):
        bp.blob(self.bm(mat), center, size, self.rng, subdiv=subdiv, wobble=wobble, seed=self.rng.random() * 10)

    def prism(self, mat, pts, z0, z1):
        """A flat polygon (x, y points, anticlockwise from above) extruded from z0 to z1."""
        tmp = bmesh.new()
        bot = [tmp.verts.new((x, y, z0)) for x, y in pts]
        top = [tmp.verts.new((x, y, z1)) for x, y in pts]
        tmp.faces.new(list(reversed(bot)))
        tmp.faces.new(top)
        n = len(pts)
        for i in range(n):
            j = (i + 1) % n
            tmp.faces.new((bot[i], bot[j], top[j], top[i]))
        bp.merge(self.bm(mat), tmp)

    def panel(self, mat, corners):
        """A double-sided quad (glass, leaves cards)."""
        bp.face2(self.bm(mat), corners)

    def sag(self, mat, a, b, drop, radius=0.03, segments=6):
        """A cable hanging between a and b."""
        a, b = Vector(a), Vector(b)
        pts = [a.lerp(b, t / segments) - Vector((0, 0, drop * 4 * (t / segments) * (1 - t / segments))) for t in range(segments + 1)]
        self.tube(mat, pts, [radius] * len(pts), sides=4)

    def export(self):
        for mat, bm in self.bms.items():
            bp.part(bm, mat, mat)
        bpy.ops.object.select_all(action="SELECT")
        OUT.mkdir(parents=True, exist_ok=True)
        bpy.ops.export_scene.gltf(
            filepath=str(OUT / f"{self.name}.glb"), export_format="GLB", export_apply=True,
            export_yup=True, export_materials="PLACEHOLDER", export_normals=True,
            export_texcoords=False, export_colors=False,
        )
        print("wrote", self.name)
        bp.clear()


# --- shared bits ----------------------------------------------------------------

def planter(m, c, length, along_x=True, h=0.5):
    """A box planter overflowing with leaves."""
    sx, sy = (length, 0.6) if along_x else (0.6, length)
    m.box("trim", (c[0], c[1], c[2] + h * 0.5), (sx, sy, h), bevel=0.04)
    n = max(2, int(length / 0.7))
    for i in range(n):
        t = (i + 0.5) / n - 0.5
        p = (c[0] + (t * length if along_x else 0), c[1] + (0 if along_x else t * length), c[2] + h + 0.15)
        m.blob("leaves", p, (0.45, 0.4, 0.35))
    if m.rng.random() < 0.7:
        # Trailing vines over the front edge.
        for i in range(m.rng.randint(1, 3)):
            x = c[0] + (m.rng.uniform(-0.4, 0.4) * length if along_x else 0)
            y = c[1] - 0.32 if along_x else c[1] + m.rng.uniform(-0.4, 0.4) * length
            ln = m.rng.uniform(0.8, 2.2)
            m.box("moss", (x, y, c[2] + h - ln * 0.5), (0.25, 0.08, ln))


def solar_array(m, c, w, d, tilt=0.42, legs=True):
    """Rows of tilted solar panels on a frame, facing -Y (the street side)."""
    rows = max(1, int(d / 1.8))
    for r in range(rows):
        y = c[1] - d * 0.5 + (r + 0.5) * d / rows
        z = c[2] + 0.7
        m.box("panel", (c[0], y, z), (w, 1.5, 0.06), rot=(tilt, 0, 0))
        m.box("metal", (c[0], y, z - 0.05), (w + 0.1, 1.55, 0.04), rot=(tilt, 0, 0))
        if legs:
            for x in (-w * 0.45, 0.0, w * 0.45):
                m.box("metal", (c[0] + x, y - 0.5, c[2] + 0.22), (0.06, 0.06, 0.44))
                m.box("metal", (c[0] + x, y + 0.5, c[2] + 0.55), (0.06, 0.06, 1.1))


def ac_unit(m, c, facing=-1.0):
    m.box("metal", c, (0.9, 0.6, 0.7), bevel=0.03)
    m.cyl("dark", (c[0], c[1] + facing * 0.31, c[2]), 0.24, 0.02, sides=10, rot=(math.pi / 2, 0, 0))
    m.box("metal", (c[0], c[1] - facing * 0.45, c[2] - 0.35), (0.06, 0.4, 0.06))


# --- shop buildings ---------------------------------------------------------------

def shop(name, width, floors, seed, roof="solar", awning=True, boarded=False):
    m = Model(name, seed)
    rng = m.rng
    w = width
    hw = w * 0.5
    top = GF + floors * UF
    gy = 0.6          # ground floor front (set back)
    uy = -0.6         # upper floors front (overhang)
    back = DEPTH - 0.6

    # Ground floor: dark cladding with a recessed shopfront.
    m.box("base", (0, (gy + 3.5 + back) * 0.5, GF * 0.5), (w, back - gy - 3.5, GF))
    for s in (-1, 1):
        m.box("base", (s * (hw - 0.4), gy + 1.75, GF * 0.5), (0.8, 3.5, GF), bevel=0.05)  # piers
    m.box("base", (0, gy + 1.75, GF - 0.45), (w - 1.6, 3.5, 0.9))  # fascia over the shopfront
    m.box("trim", (0, gy - 0.05, GF - 0.45), (w - 1.4, 0.1, 0.95), bevel=0.03)
    door_x = hw - 2.2
    if boarded:
        m.box("dark", (0, gy + 1.0, (GF - 0.9) * 0.5), (w - 1.6, 0.1, GF - 0.9))
        for i in range(7):
            m.box("wood", (rng.uniform(-0.6, 0.6), gy + 0.9, 0.5 + i * 0.5), (w - 2.0, 0.08, 0.32), rot=(0, rng.uniform(-0.07, 0.07), 0))
    else:
        # Shop interior seen through the glass: a lit back wall, shelves, a counter.
        m.box("glow_shop", (0, gy + 3.4, (GF - 0.9) * 0.5 + 0.2), (w - 1.8, 0.1, GF - 1.3))
        for i in range(3):
            m.box("dark", (-hw * 0.35, gy + 3.2, 0.9 + i * 0.85), (w * 0.4, 0.4, 0.06))
            for k in range(5):
                m.box(rng.choice(["glow_warm", "trim", "glow_cool", "metal"]), (-hw * 0.35 - w * 0.17 + k * w * 0.085, gy + 3.15, 1.05 + i * 0.85), (0.25, 0.25, 0.26))
        m.box("dark", (hw * 0.15, gy + 2.2, 0.55), (w * 0.3, 0.7, 1.1), bevel=0.04)
        for s in (-1, 1):
            m.box("base", (s * (hw - 0.85), gy + 1.9, (GF - 0.9) * 0.5), (0.1, 3.0, GF - 0.9))
        m.box("base", (0, gy + 1.9, 0.05), (w - 1.6, 3.0, 0.1))
        m.box("base", (0, gy + 1.9, GF - 0.95), (w - 1.6, 3.0, 0.1))
        # Glass with mullions, a kickplate, the door.
        m.panel("glass", [(-hw + 0.8, gy + 0.1, 0.45), (door_x - 0.9, gy + 0.1, 0.45), (door_x - 0.9, gy + 0.1, GF - 0.95), (-hw + 0.8, gy + 0.1, GF - 0.95)])
        m.box("metal", (0, gy + 0.08, 0.22), (w - 1.6, 0.14, 0.44))
        mull = int((door_x - 0.9 + hw - 0.8) / 1.6)
        for i in range(mull + 1):
            x = -hw + 0.8 + i * (door_x - 0.9 + hw - 0.8) / mull
            m.box("metal", (x, gy + 0.08, (GF - 0.95 + 0.45) * 0.5), (0.08, 0.12, GF - 1.4))
        m.box("metal", (0, gy + 0.08, 2.75), (w - 1.6, 0.1, 0.08))
        m.box("dark", (door_x, gy + 0.12, 1.25), (1.4, 0.08, 2.5))
        m.box("glow_shop", (door_x, gy + 0.1, 1.35), (0.9, 0.06, 1.6))
        m.box("metal", (door_x, gy + 0.07, 2.58), (1.6, 0.14, 0.16))
        m.box("glow_cool", (door_x, gy + 0.05, 2.7), (1.0, 0.04, 0.05))
        # A rolled-up shutter over the glass.
        m.cyl("metal", (-hw * 0.2, gy + 0.1, GF - 1.1), 0.18, w - 4.0, sides=8, rot=(0, math.pi / 2, 0))
        # Neon tube round the shopfront.
        for z in (0.3, GF - 1.05):
            m.box("neon", (-0.4, gy - 0.02, z), (w - 2.4, 0.05, 0.05))
        for x in (-hw + 0.85, door_x - 0.95):
            m.box("neon", (x, gy - 0.02, (0.3 + GF - 1.05) * 0.5), (0.05, 0.05, GF - 1.35))
    if awning:
        m.box("canvas", (-0.8, gy - 1.0, GF - 1.35), (w - 3.6, 2.2, 0.06), rot=(-0.33, 0, 0))
        m.box("metal", (-0.8, gy - 2.03, GF - 1.72), (w - 3.5, 0.06, 0.06))
        for s in (-1, 1):
            m.tube("metal", [(-0.8 + s * (w - 3.6) * 0.5, gy - 2.0, GF - 1.72), (-0.8 + s * (w - 3.6) * 0.5, gy, GF - 0.95)], [0.025, 0.025], 4)

    # Upper floors: a pale mass overhanging the pavement, softened edges.
    m.rounded("wall", (0, (uy + back) * 0.5, GF + floors * UF * 0.5), (w, back - uy, floors * UF), 1.1)
    # Sign board over the soffit for the shop's name (the text goes on in Godot).
    m.box("dark", (-0.8, uy - 0.12, GF + 0.75), (w * 0.6, 0.2, 0.9), bevel=0.05)
    for z in (GF + 0.27, GF + 1.23):
        m.box("neon", (-0.8, uy - 0.23, z), (w * 0.6 + 0.1, 0.05, 0.05))
    for x in (-0.8 - w * 0.3 - 0.05, -0.8 + w * 0.3 + 0.05):
        m.box("neon", (x, uy - 0.23, GF + 0.75), (0.05, 0.05, 1.0))
    # Ivy climbing from the pavement up one corner.
    ivy_x = rng.choice([-1, 1]) * (hw - 0.6)
    for k in range(int((GF + floors * UF * 0.6) / 0.7)):
        m.blob("leaves", (ivy_x + rng.uniform(-0.35, 0.35), uy - 0.15 + (0.0 if k * 0.7 > GF else 1.3), 0.4 + k * 0.7), (0.45, 0.25, 0.45))
    m.box("trim", (0, uy + 0.4, GF + 0.1), (w + 0.1, 1.0, 0.3), bevel=0.05)  # soffit band over the shopfront
    m.box("glow_warm", (0, uy + 0.5, GF - 0.07), (w - 1.0, 0.25, 0.04))      # soffit downlight strip
    style = rng.choice(["grid", "bands", "bays"])
    for f in range(floors):
        z0 = GF + f * UF
        if f > 0:
            m.rounded("trim", (0, (uy + back) * 0.5 - 0.06, z0), (w + 0.14, back - uy + 0.14, 0.18), 1.15)
        n = max(2, int(w / 2.7))
        for i in range(n):
            x = -hw + (i + 0.5) * w / n
            lit = rng.random() < 0.55
            pane = rng.choice(["glow_warm", "glow_warm", "glow_cool", "glow_shop"]) if lit else "glass_dark"
            if style == "bands":
                ww = w / n - 0.3
            else:
                ww = min(1.6, w / n - 0.8)
            wz = z0 + UF * 0.55
            m.box(pane, (x, uy - 0.03, wz), (ww, 0.06, 1.5))
            m.box("dark", (x, uy - 0.07, wz), (0.07, 0.04, 1.5))           # mullion
            m.box("dark", (x, uy - 0.07, wz + 0.25), (ww, 0.04, 0.06))     # transom
            for js in (-1, 1):
                m.box("trim", (x + js * (ww * 0.5 + 0.06), uy - 0.08, wz), (0.12, 0.16, 1.62))
            if lit and rng.random() < 0.6:
                # A blind half down, or a plant on the sill, so lit panes aren't flat colour.
                if rng.random() < 0.5:
                    m.box("canvas", (x, uy - 0.065, wz + 0.75 - 0.35), (ww - 0.05, 0.02, 0.7))
                else:
                    m.blob("leaves", (x + rng.uniform(-0.3, 0.3), uy - 0.15, wz - 0.55), (0.25, 0.15, 0.3))
            m.box("trim", (x, uy - 0.12, wz - 0.82), (ww + 0.3, 0.3, 0.12))  # sill
            m.box("trim", (x, uy - 0.08, wz + 0.8), (ww + 0.2, 0.2, 0.1))
            if style == "bands":
                for k in range(int(ww / 0.45)):
                    m.box("wood", (x - ww * 0.5 + 0.2 + k * 0.45, uy - 0.3, wz), (0.08, 0.35, 1.7))
            if style == "grid" and lit and rng.random() < 0.4:
                # A curtain half drawn.
                m.box("canvas", (x - ww * 0.25, uy - 0.065, wz + 0.1), (ww * 0.45, 0.02, 1.2))
            if style == "bays" and i % 2 == 0 and f % 2 == 0:
                # Little glazed bay sticking out.
                m.box("trim", (x, uy - 0.55, wz - 0.85), (ww + 0.5, 1.0, 0.14), bevel=0.04)
                m.box("trim", (x, uy - 0.55, wz + 0.85), (ww + 0.5, 1.0, 0.14), bevel=0.04)
                m.panel("glass", [(x - ww * 0.5, uy - 1.0, wz - 0.78), (x + ww * 0.5, uy - 1.0, wz - 0.78), (x + ww * 0.5, uy - 1.0, wz + 0.78), (x - ww * 0.5, uy - 1.0, wz + 0.78)])
                for s in (-1, 1):
                    m.box("metal", (x + s * (ww * 0.5 + 0.05), uy - 0.55, wz), (0.08, 1.0, 1.6))
        # Balconies on alternate floors: rounded slab, glass rail, planters.
        if f % 2 == (1 if floors > 1 else 0) or (floors == 1):
            bw = w - 2.0 if rng.random() < 0.6 else w * 0.5
            bx = 0.0 if bw > w * 0.6 else rng.choice([-1, 1]) * (hw - bw * 0.5 - 0.6)
            r = 0.6
            pts = []
            for k in range(7):  # rounded front corners
                a = math.pi + k * (math.pi / 2) / 6
                pts.append((bx - bw * 0.5 + r + r * math.cos(a), uy - 1.4 + r + r * math.sin(a)))
            for k in range(7):
                a = 1.5 * math.pi + k * (math.pi / 2) / 6
                pts.append((bx + bw * 0.5 - r + r * math.cos(a), uy - 1.4 + r + r * math.sin(a)))
            pts += [(bx + bw * 0.5, uy + 0.05), (bx - bw * 0.5, uy + 0.05)]
            m.prism("trim", pts, z0 - 0.02, z0 + 0.16)
            m.panel("glass", [(bx - bw * 0.5 + 0.1, uy - 1.38, z0 + 0.16), (bx + bw * 0.5 - 0.1, uy - 1.38, z0 + 0.16),
                              (bx + bw * 0.5 - 0.1, uy - 1.38, z0 + 1.1), (bx - bw * 0.5 + 0.1, uy - 1.38, z0 + 1.1)])
            m.box("metal", (bx, uy - 1.38, z0 + 1.12), (bw - 0.2, 0.08, 0.06))
            planter(m, (bx - bw * 0.25, uy - 1.0, z0 + 0.16), bw * 0.3)
            if rng.random() < 0.5:
                planter(m, (bx + bw * 0.28, uy - 1.0, z0 + 0.16), bw * 0.25)
            else:
                m.box("wood", (bx + bw * 0.3, uy - 0.6, z0 + 0.6), (0.8, 0.5, 0.08))  # little table
                m.box("metal", (bx + bw * 0.3, uy - 0.6, z0 + 0.38), (0.06, 0.06, 0.44))
            if rng.random() < 0.6:
                # String lights along the rail.
                for k in range(int(bw / 0.6)):
                    m.box("glow_warm", (bx - bw * 0.5 + 0.3 + k * 0.6, uy - 1.36, z0 + 1.0 - 0.1 * math.sin(k * 1.3)), (0.08, 0.08, 0.1))
            # Vines hanging under the slab.
            for k in range(rng.randint(2, 5)):
                ln = rng.uniform(0.6, 2.0)
                m.box("moss", (bx + rng.uniform(-bw * 0.45, bw * 0.45), uy - 1.25, z0 - ln * 0.5), (0.3, 0.1, ln))
    # Side wall vertical garden and grime: pipes, AC units, a cable bundle.
    if rng.random() < 0.6:
        s = rng.choice([-1, 1])
        m.box("moss", (s * (hw + 0.05), 2.5, GF + floors * UF * 0.45), (0.12, 3.0, floors * UF * 0.8))
        for k in range(floors * 2):
            m.blob("leaves", (s * (hw + 0.25), 1.5 + rng.uniform(0, 2), GF + 0.8 + k * UF * 0.45), (0.35, 0.5, 0.4))
    px = rng.choice([-1, 1]) * (hw - 0.35)
    m.tube("metal", [(px, uy - 0.15, 0.0), (px, uy - 0.15, top + 0.4)], [0.07, 0.07], 6)
    m.tube("dark", [(px + 0.2, uy - 0.12, GF), (px + 0.2, uy - 0.12, top)], [0.04, 0.04], 5)
    for k in range(rng.randint(1, floors)):
        ac_unit(m, (rng.uniform(-hw + 1.2, hw - 1.2), uy - 0.35, GF + (k + 1) * UF - 0.45))
    # Roof: parapet, then panels or a garden, a water tank, a mast.
    m.rounded("trim", (0, (uy + back) * 0.5, top + 0.1), (w + 0.2, back - uy + 0.2, 0.2), 1.2)
    m.box("metal", (0, uy + 0.3, top + 1.0), (w - 2.0, 0.05, 0.05))  # safety rail
    for x in (-hw + 1.2, 0.0, hw - 1.2):
        m.box("metal", (x, uy + 0.3, top + 0.6), (0.05, 0.05, 0.8))
    if roof == "solar":
        solar_array(m, (0, 4.0, top), w - 1.6, 6.0)
    else:
        for k in range(3):
            planter(m, (-hw + 1.6 + k * (w - 3.2) / 2, 3.0 + (k % 2), top), 2.4, along_x=False, h=0.6)
        bp_tree = rng.random()
        if bp_tree < 0.7:
            m.tube("bark", [(1.0, 5.5, top), (1.3, 5.6, top + 2.5)], [0.15, 0.1], 6)
            m.blob("leaves", (1.3, 5.6, top + 3.0), (1.3, 1.2, 0.9), subdiv=2)
        # A shade sail on three poles and a vertical-axis wind turbine.
        poles = [(-hw + 1.5, 5.0, 3.2), (-0.5, 4.2, 2.4), (-hw + 2.5, 8.5, 2.6)]
        for x, y, h in poles:
            m.tube("metal", [(x, y, top), (x, y, top + h)], [0.05, 0.04], 5)
        m.panel("canvas", [(x, y, top + h) for x, y, h in poles])
        tx, ty = hw - 2.5, 7.0
        m.tube("metal", [(tx, ty, top), (tx, ty, top + 3.4)], [0.06, 0.05], 6)
        for b in range(3):
            pts = [(tx + 0.5 * math.cos(b * 2.1 + t * 0.35), ty + 0.5 * math.sin(b * 2.1 + t * 0.35), top + 1.2 + t * 0.2) for t in range(11)]
            m.tube("wall", pts, [0.06] * 11, 4)
    m.cyl("metal", (hw - 1.6, back - 2.0, top + 1.2), 0.9, 2.4, sides=12)
    m.cyl("trim", (hw - 1.6, back - 2.0, top + 2.45), 0.95, 0.1, sides=12)
    for a in range(4):
        m.box("metal", (hw - 1.6 + 0.7 * math.cos(a * math.pi / 2), back - 2.0 + 0.7 * math.sin(a * math.pi / 2), top + 0.3), (0.08, 0.08, 0.6))
    if rng.random() < 0.6:
        mx = -hw + 1.0
        m.tube("metal", [(mx, back - 1.5, top), (mx, back - 1.5, top + 4.5)], [0.05, 0.03], 4)
        m.box("glow_red", (mx, back - 1.5, top + 4.55), (0.14, 0.14, 0.14))
        m.box("metal", (mx, back - 1.5, top + 3.6), (0.8, 0.04, 0.04))
    m.export()


def militia_office():
    """Brutalist grey block: slit windows, armoured door, sandbags, cameras.
    Front faces -Y; 16 wide (x), 12 deep, 9 tall. Origin at the front's foot."""
    m = Model("militia_office", 7)
    w, d, h = 16.0, 12.0, 9.0
    m.box("wall", (0, d * 0.5, h * 0.5), (w, d, h), bevel=0.05)
    m.box("trim", (0, -0.2, h - 0.4), (w + 0.6, 0.6, 0.8))           # heavy brow
    m.box("trim", (0, -0.15, 0.3), (w + 0.3, 0.3, 0.6))
    for s in (-1, 1):
        m.box("trim", (s * (w * 0.5 - 0.3), -0.3, h * 0.5), (0.8, 0.8, h), bevel=0.05)  # buttresses
        for k in range(3):
            x = s * (2.8 + k * 1.6)
            m.box("dark", (x, -0.02, 5.4), (0.35, 0.06, 2.2))           # slit windows
            m.box("glow_red", (x, -0.03, 4.4), (0.3, 0.04, 0.05))
    # Door: armoured with a canopy and a red lamp.
    m.box("dark", (0, -0.02, 1.6), (2.4, 0.08, 3.2))
    m.box("metal", (0, -0.06, 1.6), (2.2, 0.06, 3.0))
    for z in (0.6, 1.4, 2.2):
        m.box("dark", (0, -0.1, z), (2.0, 0.04, 0.06))
    m.box("metal", (0, -0.8, 3.4), (4.0, 1.6, 0.18))
    m.box("glow_red", (0, -0.2, 3.25), (0.4, 0.1, 0.1))
    # Sandbag walls either side of the door.
    for s in (-1, 1):
        for row in range(3):
            for k in range(4):
                m.blob("canvas", (s * (2.4 + k * 0.6 + (row % 2) * 0.3), -1.6, 0.18 + row * 0.3), (0.32, 0.22, 0.16), subdiv=1, wobble=0.1)
    # Cameras, floodlights, antenna farm on the roof.
    for s in (-1, 1):
        cam = (s * (w * 0.5 - 0.6), -0.7, h - 1.4)
        m.box("metal", cam, (0.3, 0.6, 0.25))
        m.box("glow_red", (cam[0], cam[1] - 0.31, cam[2]), (0.06, 0.02, 0.06))
        m.box("metal", (s * 3.5, -0.4, h - 0.9), (0.6, 0.5, 0.35), rot=(0.4, 0, 0))
        m.box("glow_warm", (s * 3.5, -0.66, h - 1.0), (0.5, 0.04, 0.25), rot=(0.4, 0, 0))
    for k in range(4):
        x = -5 + k * 3.3
        m.tube("metal", [(x, 6.0, h), (x, 6.0, h + 3 + k % 2 * 2)], [0.06, 0.03], 4)
    m.box("metal", (3.0, 8.0, h + 0.8), (2.4, 2.4, 1.6))
    m.cyl("metal", (-3.5, 8.0, h + 1.2), 1.2, 0.2, sides=14, rot=(0.8, 0, 0))  # dish
    # Razor wire coil along the parapet.
    for k in range(int(w / 0.5)):
        x = -w * 0.5 + 0.25 + k * 0.5
        m.cyl("metal", (x, 0.3, h + 0.3), 0.25, 0.04, sides=6, rot=(0, math.pi / 2, 0))
    m.export()


def greenhouse():
    """The greenhouse cafe: a glass hall on white ribs with a pitched roof, front
    open to -Y... authored facing -Y, 12 wide (x), 16 deep. Origin front middle."""
    m = Model("greenhouse", 11)
    w, d, h = 12.0, 16.0, 6.0
    m.box("wood", (0, d * 0.5, 0.06), (w, d, 0.12))
    ribs = 5
    for i in range(ribs):
        y = i * d / (ribs - 1)
        for s in (-1, 1):
            m.box("trim", (s * w * 0.5, y, h * 0.5), (0.18, 0.18, h), bevel=0.03)
            a = math.atan2(1.6, w * 0.5)
            m.box("trim", (s * w * 0.25, y, h + 0.8), (w * 0.56, 0.16, 0.16), rot=(0, s * a, 0))
    m.box("trim", (0, d * 0.5, h + 1.6), (0.2, d, 0.2))
    for s in (-1, 1):
        m.box("trim", (s * w * 0.5, d * 0.5, h), (0.2, d, 0.2))
        m.box("trim", (s * w * 0.5, d * 0.5, 0.4), (0.2, d, 0.8))
    # Glass: sides, back, front with a door gap, roof.
    for s in (-1, 1):
        m.panel("glass", [(s * w * 0.5, 0, 0.8), (s * w * 0.5, d, 0.8), (s * w * 0.5, d, h), (s * w * 0.5, 0, h)])
        m.panel("glass", [(s * w * 0.5, 0, h), (s * w * 0.5, d, h), (0, d, h + 1.6), (0, 0, h + 1.6)])
        m.panel("glass", [(s * 1.4, 0, 0), (s * w * 0.5, 0, 0), (s * w * 0.5, 0, h), (s * 1.4, 0, h)])
    m.panel("glass", [(-w * 0.5, d, 0), (w * 0.5, d, 0), (w * 0.5, d, h), (-w * 0.5, d, h)])
    m.panel("glass", [(-1.4, 0, 3.2), (1.4, 0, 3.2), (1.4, 0, h), (-1.4, 0, h)])
    m.panel("glass", [(-w * 0.5, 0, h), (w * 0.5, 0, h), (0, 0, h + 1.6)])
    for s in (-1, 1):
        m.box("trim", (s * 1.4, 0, 1.6), (0.14, 0.14, 3.2))
    m.box("trim", (0, 0, 3.2), (2.9, 0.14, 0.14))
    # Inside: beds of plants, a big fig, tables with candles, a counter, lights.
    for s in (-1, 1):
        planter(m, (s * (w * 0.5 - 0.6), d * 0.5, 0.12), d - 2.0, along_x=False, h=0.7)
    m.tube("bark", [(2.5, 12.0, 0.1), (2.2, 12.2, 2.5), (2.6, 12.0, 4.0)], [0.25, 0.18, 0.1], 7)
    m.blob("leaves", (2.4, 12.0, 4.6), (2.0, 1.8, 1.2), subdiv=2)
    m.blob("leaves", (1.5, 11.5, 3.8), (1.2, 1.0, 0.8), subdiv=2)
    for x, y in ((-2.5, 3.5), (1.5, 5.0), (-2.0, 8.5), (1.0, 9.0)):
        m.cyl("wood", (x, y, 0.85), 0.55, 0.06, sides=12)
        m.cyl("metal", (x, y, 0.45), 0.05, 0.8, sides=6)
        m.box("glow_warm", (x, y, 0.95), (0.08, 0.08, 0.14))
        for a in (0.0, math.pi):
            m.cyl("wood", (x + 0.8 * math.cos(a), y + 0.8 * math.sin(a), 0.45), 0.22, 0.06, sides=8)
            m.cyl("metal", (x + 0.8 * math.cos(a), y + 0.8 * math.sin(a), 0.22), 0.03, 0.44, sides=5)
    m.box("wood", (-3.6, 14.2, 0.55), (4.0, 1.0, 1.1), bevel=0.05)
    m.box("trim", (-3.6, 14.2, 1.12), (4.2, 1.1, 0.06))
    for k in range(5):
        m.box(["glow_warm", "trim", "glass_dark"][k % 3], (-5.0 + k * 0.6, 14.3, 1.3), (0.25, 0.25, 0.3))
    for i in range(6):
        y = 1.5 + i * 2.6
        m.sag("dark", (-w * 0.5, y, h - 0.2), (w * 0.5, y, h - 0.2), 0.5, 0.02)
        for k in range(5):
            t = (k + 0.5) / 5
            m.box("glow_warm", (-w * 0.5 + t * w, y, h - 0.2 - 2.0 * t * (1 - t) - 0.1), (0.12, 0.12, 0.16))
    # Hanging baskets.
    for x, y in ((-3, 4), (3, 7), (-2.5, 11)):
        m.tube("metal", [(x, y, h + 0.8), (x, y, h - 0.6)], [0.01, 0.01], 3)
        m.blob("leaves", (x, y, h - 0.9), (0.5, 0.5, 0.4))
    m.export()


def gate_pylon():
    """One of the two town gate pylons: a tapering white tower with a vertical
    garden on its inner (+X) face and solar petals fanned out on top."""
    m = Model("gate_pylon", 13)
    m.box("wall", (0, 0, 5.0), (2.6, 2.6, 10.0), bevel=0.2)
    m.box("wall", (0, 0, 10.8), (2.0, 2.0, 1.6), bevel=0.2)
    m.box("trim", (0, 0, 0.4), (3.0, 3.0, 0.8), bevel=0.08)
    m.box("trim", (0, 0, 10.0), (2.9, 2.9, 0.25), bevel=0.05)
    m.box("moss", (1.33, 0, 5.0), (0.1, 2.0, 8.0))
    for k in range(9):
        m.blob("leaves", (1.55, m.rng.uniform(-0.8, 0.8), 1.5 + k * 0.95), (0.4, 0.55, 0.45))
    # Solar petals fanned out on arms from a mast on top.
    m.tube("metal", [(0, 0, 11.6), (0, 0, 13.0)], [0.12, 0.08], 6)
    for k in range(5):
        a = math.radians(-72 + k * 36)
        d = Vector((0.0, math.sin(a), math.cos(a)))
        c = Vector((0, 0, 12.8)) + d * 1.5
        rot = (math.pi / 2 - a, 0, 0)
        m.tube("metal", [(0, 0, 12.6), c - d * 0.9], [0.06, 0.05], 5)
        m.box("panel", c, (1.4, 1.9, 0.06), rot=rot)
        m.box("metal", c - Vector((0, 0, 0)), (1.5, 2.0, 0.03), rot=rot)
        m.box("glow_cyan", c + d * 0.97, (1.4, 0.06, 0.06), rot=rot)
    m.box("glow_cyan", (0, -1.32, 6.0), (0.12, 0.04, 6.0))
    m.box("glow_cyan", (0, 1.32, 6.0), (0.12, 0.04, 6.0))
    m.export()


def gate_arch():
    """The beam between the pylons, 19 m long (x), with hanging lanterns."""
    m = Model("gate_arch", 17)
    m.box("dark", (0, 0, 0), (19.0, 1.0, 1.2), bevel=0.1)
    m.box("trim", (0, 0, 0.7), (19.4, 1.3, 0.2), bevel=0.05)
    m.box("trim", (0, 0, -0.7), (19.4, 1.3, 0.2), bevel=0.05)
    for k in range(7):
        x = -7.5 + k * 2.5
        if abs(x) < 4.5:
            continue
        m.tube("metal", [(x, 0, -0.8), (x, 0, -1.8)], [0.015, 0.015], 3)
        m.cyl("glow_warm", (x, 0, -2.1), 0.22, 0.5, sides=8)
    for k in range(6):
        ln = m.rng.uniform(0.6, 1.8)
        m.box("moss", (m.rng.uniform(-9, 9), 0.45, -0.8 - ln * 0.5), (0.4, 0.12, ln))
    m.export()


def checkpoint():
    """Army checkpoint booth (the town's own army, not the colony) with a raised boom, a flagpole and a barrier."""
    m = Model("checkpoint", 19)
    m.box("base", (0, 0, 1.4), (2.6, 2.6, 2.8), bevel=0.06)
    m.box("glass_dark", (-1.31, 0, 1.9), (0.04, 2.0, 0.9))
    m.box("glow_warm", (-1.28, 0.5, 1.7), (0.02, 0.6, 0.5))
    m.box("metal", (0, 0, 2.95), (3.0, 3.0, 0.2), bevel=0.04)
    m.box("glow_red", (0.8, 0.8, 3.15), (0.2, 0.2, 0.2))
    m.box("metal", (-1.9, -1.0, 0.6), (0.4, 0.4, 1.2))
    m.box("trim", (-1.9, -1.0 - 2.0 * math.cos(1.2), 1.15 + 2.0 * math.sin(1.2)), (0.14, 4.0, 0.14), rot=(1.2, 0, 0))
    for k in range(4):
        m.box("glow_red", (-1.9, -1.0 - (0.6 + k) * math.cos(1.2), 1.15 + (0.6 + k) * math.sin(1.2)), (0.16, 0.3, 0.16), rot=(1.2, 0, 0))
    m.tube("metal", [(1.0, 1.0, 0), (1.0, 1.0, 7.0)], [0.06, 0.04], 6)
    for k in range(3):  # concrete barriers
        x = 2.4 + k * 1.3
        m.box("trim", (x, -1.6, 0.4), (1.2, 0.6, 0.8), bevel=0.08)
        m.box("glow_red", (x, -1.92, 0.65), (0.8, 0.02, 0.06))
    m.export()


def sun_tree():
    """The Sun Tree: twisting white ribs rising from a round fountain, branching
    into leaf-shaped solar panels edged in light. Origin at the fountain's centre."""
    m = Model("sun_tree", 23)
    rng = m.rng
    # Fountain basin: a ring of white stone, the water, a lip.
    ring = [(math.cos(a) * 5.2, math.sin(a) * 5.2) for a in [k * 2 * math.pi / 32 for k in range(32)]]
    inner = [(math.cos(a) * 4.6, math.sin(a) * 4.6) for a in [k * 2 * math.pi / 32 for k in range(32)]]
    bm = m.bm("stone")
    outer_b = [bm.verts.new((x, y, 0)) for x, y in ring]
    outer_t = [bm.verts.new((x, y, 0.7)) for x, y in ring]
    inner_t = [bm.verts.new((x, y, 0.7)) for x, y in inner]
    inner_b = [bm.verts.new((x, y, 0.3)) for x, y in inner]
    n = 32
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((outer_b[i], outer_b[j], outer_t[j], outer_t[i]))
        bm.faces.new((outer_t[i], outer_t[j], inner_t[j], inner_t[i]))
        bm.faces.new((inner_t[i], inner_t[j], inner_b[j], inner_b[i]))
    m.prism("water", inner, 0.3, 0.45)
    # Trunk: ribs spiralling up round a core.
    m.cyl("wall", (0, 0, 5.0), 0.7, 10.0, sides=10)
    for r in range(7):
        pts, radii = [], []
        for k in range(13):
            t = k / 12
            a = r * 2 * math.pi / 7 + t * 2.2
            rad = 1.6 - 1.0 * math.sin(t * math.pi * 0.85) + (0.9 if t > 0.85 else 0)
            pts.append((math.cos(a) * rad, math.sin(a) * rad, 0.3 + t * 10.5))
            radii.append(0.22 - 0.08 * t)
        m.tube("wall", pts, radii, 6)
    # Vines climbing the trunk.
    for k in range(10):
        a = rng.uniform(0, 2 * math.pi)
        z = rng.uniform(1.0, 9.0)
        m.blob("leaves", (math.cos(a) * 1.0, math.sin(a) * 1.0, z), (0.5, 0.5, 0.7))
    # Branches and panel leaves.
    for i in range(11):
        a = i * 2 * math.pi / 11 + rng.uniform(-0.1, 0.1)
        h = 8.6 + (i % 3) * 1.5
        r = 4.0 + (i % 2) * 1.6
        base = Vector((math.cos(a) * 0.9, math.sin(a) * 0.9, h - 1.8))
        tip = Vector((math.cos(a) * r, math.sin(a) * r, h + 0.6))
        mid = base.lerp(tip, 0.5) + Vector((0, 0, 0.6))
        m.tube("wall", [base, mid, tip], [0.2, 0.14, 0.09], 6)
        # The leaf: a pointed hexagon of solar glass, tilted up and out.
        out = Vector((math.cos(a), math.sin(a), 0))
        side = Vector((-math.sin(a), math.cos(a), 0))
        L, W = 3.4, 1.4
        shape = [(0, 0), (L * 0.3, W), (L * 0.8, W * 0.8), (L, 0), (L * 0.8, -W * 0.8), (L * 0.3, -W)]
        tilt = 0.35
        def at(u, v, lift=0.0):
            return tip - out * L * 0.35 + out * u * math.cos(tilt) + side * v + Vector((0, 0, u * math.sin(tilt) + lift))
        bm = m.bm("panel")
        top = [bm.verts.new(at(u, v, 0.05)) for u, v in shape]
        bot = [bm.verts.new(at(u, v, -0.03)) for u, v in shape]
        bm.faces.new(top)
        bm.faces.new(list(reversed(bot)))
        for k in range(len(shape)):
            j = (k + 1) % len(shape)
            bm.faces.new((bot[k], bot[j], top[j], top[k]))
        # Glowing rim and a midrib.
        for k in range(len(shape)):
            j = (k + 1) % len(shape)
            m.tube("glow_cyan", [at(*shape[k], 0.07), at(*shape[j], 0.07)], [0.035, 0.035], 4)
        m.tube("trim", [at(0, 0, 0.08), at(L, 0, 0.08)], [0.05, 0.03], 4)
        if rng.random() < 0.5:
            m.blob("leaves", tip - Vector((0, 0, 0.6)), (0.5, 0.5, 0.7))
    # Crown: a glowing seed pod.
    m.blob("glow_lime", (0, 0, 11.2), (0.9, 0.9, 1.1), subdiv=2, wobble=0.1)
    m.export()


def canopy_bay():
    """One bay of the solar canopy over the street: 16 m across (x), 4 m along
    (y), a steel frame with two cell-gridded panels, a cool downlight strip
    and cables hanging under it. Origin at the bay's centre, at frame height."""
    m = Model("canopy_bay", 73)
    for y in (-2.0, 2.0):
        m.box("metal", (0, y, 0), (16.0, 0.2, 0.35))
    for x in (-8.0, -4.0, 0.0, 4.0, 8.0):
        m.box("metal", (x, 0, 0.05), (0.18, 4.0, 0.25))
    for sx in (-1, 1):
        cx = sx * 3.9
        m.box("panel", (cx, 0, 0.32), (7.6, 4.0, 0.06), rot=(0, sx * 0.08, 0))
        for k in range(1, 8):
            m.box("metal", (cx - 3.7 + k * 7.4 / 8, 0, 0.36 + sx * 0.0), (0.03, 3.6, 0.02), rot=(0, sx * 0.08, 0))
        for k in range(1, 4):
            m.box("metal", (cx, -1.8 + k * 0.9, 0.36), (7.4, 0.03, 0.02), rot=(0, sx * 0.08, 0))
    m.box("base", (0, 0, 0.17), (16.0, 4.05, 0.04))  # closed underside, so it shades the street
    m.box("glow_cool", (0, 0, -0.2), (12.0, 0.08, 0.05))
    for x in (-5.5, 1.0, 6.0):
        m.sag("dark", (x - 1.5, -2.0, -0.1), (x + 1.5, 2.0, -0.1), 0.8, 0.03)
    for k in range(3):
        ln = m.rng.uniform(0.8, 2.2)
        m.box("moss", (m.rng.uniform(-7, 7), m.rng.choice([-2.0, 2.0]), -ln * 0.5), (0.4, 0.12, ln))
    m.export()


def lantern():
    """A paper lantern on a drop: dark cap and base, ribs, a glowing paper body (glow_paper)."""
    m = Model("lantern", 79)
    m.tube("metal", [(0, 0, 0), (0, 0, -0.3)], [0.012, 0.012], 3)
    m.cyl("dark", (0, 0, -0.33), 0.12, 0.06, sides=8)
    m.tube("glow_paper", [(0, 0, -0.36), (0, 0, -0.5), (0, 0, -0.68), (0, 0, -0.8)], [0.14, 0.2, 0.2, 0.14], 10)
    for k in range(6):
        a = k * math.pi / 3
        m.tube("dark", [(0.15 * math.cos(a), 0.15 * math.sin(a), -0.38), (0.205 * math.cos(a), 0.205 * math.sin(a), -0.58),
                        (0.15 * math.cos(a), 0.15 * math.sin(a), -0.78)], [0.012] * 3, 3)
    m.cyl("dark", (0, 0, -0.83), 0.1, 0.06, sides=8)
    m.box("canvas", (0, 0, -0.95), (0.03, 0.03, 0.2))
    m.export()


def market_stall():
    """A plaza market stall: a timber frame, a striped canvas roof, a counter of
    crates of fruit and greens, a lamp. Faces -Y, 3 m wide."""
    m = Model("market_stall", 83)
    for x in (-1.4, 1.4):
        for y in (-0.8, 0.8):
            m.box("wood", (x, y, 1.25 if y < 0 else 1.05), (0.1, 0.1, 2.5 if y < 0 else 2.1))
    for k in range(6):
        m.box("canvas" if k % 2 == 0 else "trim", (-1.25 + k * 0.5, 0, 2.4), (0.5, 2.1, 0.04), rot=(-0.22, 0, 0))
    m.box("wood", (0, -0.6, 0.45), (2.9, 0.7, 0.9), bevel=0.03)
    for k in range(5):
        x = -1.1 + k * 0.55
        m.box("wood", (x, -0.65, 1.0), (0.48, 0.5, 0.2))
        for j in range(4):
            m.blob(["leaves", "glow_shop", "canvas"][k % 3] if k % 3 != 1 else "trim", (x + m.rng.uniform(-0.15, 0.15), -0.65 + m.rng.uniform(-0.15, 0.15), 1.15), (0.09, 0.09, 0.09), wobble=0.1)
    m.box("wood", (0, 0.6, 0.9), (2.6, 0.4, 0.05))
    for k in range(4):
        m.blob("leaves", (-0.9 + k * 0.6, 0.6, 1.05), (0.22, 0.18, 0.15))
    m.tube("metal", [(1.3, -0.9, 2.2), (1.3, -1.2, 2.0)], [0.02, 0.02], 3)
    m.cyl("glow_warm", (1.3, -1.2, 1.85), 0.1, 0.25, sides=8)
    m.export()


def cafe_table():
    """An outdoor cafe table with a parasol and two chairs."""
    m = Model("cafe_table", 89)
    m.cyl("trim", (0, 0, 0.74), 0.45, 0.04, sides=14)
    m.cyl("metal", (0, 0, 0.37), 0.04, 0.74, sides=6)
    m.cyl("metal", (0, 0, 0.02), 0.25, 0.04, sides=10)
    m.cyl("metal", (0, 0, 1.4), 0.025, 1.4, sides=5)
    tmp = bmesh.new()
    res = bmesh.ops.create_cone(tmp, cap_ends=False, segments=8, radius1=1.2, radius2=0.02, depth=0.45)
    bmesh.ops.translate(tmp, vec=Vector((0, 0, 2.2)), verts=res["verts"])
    bp.merge(m.bm("canvas"), tmp)
    m.box("glow_warm", (0, 0, 0.82), (0.07, 0.07, 0.12))
    for a in (0.3, math.pi + 0.3):
        x, y = 0.75 * math.cos(a), 0.75 * math.sin(a)
        m.box("wood", (x, y, 0.45), (0.4, 0.4, 0.05), rot=(0, 0, a))
        m.box("wood", (x + 0.22 * math.cos(a), y + 0.22 * math.sin(a), 0.7), (0.05, 0.4, 0.5), rot=(0, 0, a))
        for dx in (-0.15, 0.15):
            for dy in (-0.15, 0.15):
                m.box("metal", (x + dx, y + dy, 0.22), (0.03, 0.03, 0.44))
    m.export()


def solar_lamp():
    m = Model("solar_lamp", 29)
    m.tube("wall", [(0, 0, 0), (0, 0, 2.0), (0.05, 0, 4.0)], [0.1, 0.08, 0.06], 8)
    m.cyl("trim", (0, 0, 0.12), 0.22, 0.24, sides=8)
    m.box("panel", (0.05, 0, 4.3), (1.0, 0.7, 0.05), rot=(0.4, 0, 0))
    m.box("metal", (0.05, 0, 4.26), (1.05, 0.75, 0.03), rot=(0.4, 0, 0))
    m.tube("wall", [(0.05, 0, 3.9), (0.5, 0, 3.75)], [0.04, 0.03], 5)
    m.cyl("glow_shop", (0.55, 0, 3.45), 0.16, 0.5, sides=8)
    m.cyl("trim", (0.55, 0, 3.72), 0.2, 0.06, sides=8)
    m.blob("leaves", (0, 0, 0.5), (0.35, 0.35, 0.3))
    m.export()


def turbine_tower():
    m = Model("turbine_tower", 31)
    m.tube("wall", [(0, 0, 0), (0, 0, 28.0)], [0.9, 0.45], 12)
    m.box("wall", (0, -0.4, 28.0), (1.2, 3.0, 1.2), bevel=0.4)
    m.cyl("trim", (0, 0, 0.3), 1.4, 0.6, sides=12)
    m.box("glow_red", (0, 0.8, 28.7), (0.25, 0.25, 0.2))
    m.export()


def turbine_rotor():
    """Three blades round a hub, spinning about Blender -Y (Godot +Z)."""
    m = Model("turbine_rotor", 37)
    m.cyl("trim", (0, 0, 0), 0.5, 1.0, sides=10, rot=(math.pi / 2, 0, 0))
    m.blob("trim", (0, -0.6, 0), (0.45, 0.6, 0.45), subdiv=2, wobble=0.0)
    for k in range(3):
        a = k * 2 * math.pi / 3
        bm = m.bm("wall")
        tmp = bmesh.new()
        prof = [(0.0, 0.0), (0.7, 0.1), (0.5, 10.0), (0.0, 10.4), (-0.2, 9.8), (-0.3, 0.1)]
        f = [tmp.verts.new((x, 0.08, y + 0.4)) for x, y in prof]
        b = [tmp.verts.new((x, -0.08, y + 0.4)) for x, y in prof]
        tmp.faces.new(f)
        tmp.faces.new(list(reversed(b)))
        for i in range(len(prof)):
            j = (i + 1) % len(prof)
            tmp.faces.new((b[i], b[j], f[j], f[i]))
        bmesh.ops.rotate(tmp, verts=list(tmp.verts), cent=Vector((0, 0, 0)), matrix=Matrix.Rotation(a, 3, "Y"))
        bp.merge(bm, tmp)
    m.export()


def noodle_stall():
    """Street counter with stools, a pass-through window, steaming pots, paper
    lanterns, and a menu board. Faces -Y, 5 long (x). Origin at the counter front."""
    m = Model("noodle_stall", 41)
    m.box("wood", (0, 0.4, 0.55), (5.0, 0.8, 1.1), bevel=0.04)
    m.box("dark", (0, 0.35, 1.13), (5.2, 1.0, 0.06))
    for k in range(4):
        x = -1.8 + k * 1.2
        m.cyl("metal", (x, -0.7, 0.4), 0.04, 0.8, sides=6)
        m.cyl("canvas", (x, -0.7, 0.82), 0.24, 0.08, sides=10)
        m.cyl("metal", (x, -0.7, 0.03), 0.18, 0.06, sides=8)
    for k in range(3):
        x = -1.4 + k * 1.4
        m.cyl("metal", (x, 0.6, 1.3), 0.25, 0.32, sides=10)
        m.cyl("dark", (x, 0.6, 1.47), 0.26, 0.03, sides=10)
    for k in range(5):  # bowls on the counter
        m.cyl("trim", (-2.0 + k * 1.0, 0.0, 1.2), 0.14, 0.08, sides=8)
    m.sag("dark", (-2.6, -0.1, 3.5), (2.6, -0.1, 3.5), 0.3, 0.015)
    for k in range(6):
        t = (k + 0.5) / 6
        z = 3.5 - 1.2 * t * (1 - t) - 0.35
        m.tube("glow_shop", [(-2.6 + t * 5.2, -0.1, z - 0.22), (-2.6 + t * 5.2, -0.1, z), (-2.6 + t * 5.2, -0.1, z + 0.22)], [0.12, 0.2, 0.12], 8)
    m.box("dark", (2.2, 0.9, 2.6), (0.9, 0.06, 1.3))
    for k in range(5):
        m.box("glow_warm", (2.2, 0.86, 3.0 - k * 0.22), (0.6, 0.02, 0.06))
    m.export()


def ice_cream_kiosk():
    """A rounded pastel kiosk with a serving window, chest freezers, a striped
    awning, a menu board and a giant neon cone on the roof. Faces -Y, 4 wide (x),
    2.6 deep. Origin at the counter front."""
    m = Model("ice_cream_kiosk", 97)
    m.rounded("wall", (0, 1.3, 1.5), (4.0, 2.6, 3.0), 0.35)
    m.box("trim", (0, 1.3, 3.08), (4.2, 2.8, 0.16), bevel=0.04)
    # Serving hatch: a lit pink back wall, a glass case of glowing flavour tubs.
    m.box("glow_shop", (0, 0.35, 1.75), (3.0, 0.06, 1.0))
    for x in (-1.55, 1.55):
        m.box("trim", (x, -0.02, 1.75), (0.12, 0.4, 1.1))
    m.box("trim", (0, -0.02, 2.3), (3.2, 0.4, 0.12))
    m.box("dark", (0, -0.02, 1.2), (3.2, 0.08, 0.1))
    flavours = ["glow_red", "glow_lime", "glow_warm", "glow_cyan", "glow_shop", "canvas"]
    for k in range(6):
        m.box("metal", (-1.2 + k * 0.48, 0.1, 1.27), (0.4, 0.3, 0.06))
        m.blob(flavours[k], (-1.2 + k * 0.48, 0.1, 1.36), (0.17, 0.13, 0.09), wobble=0.12)
    m.box("glass", (0, -0.05, 1.5), (3.0, 0.04, 0.5), rot=(0.5, 0, 0))
    m.box("trim", (0, -0.2, 1.12), (3.4, 0.45, 0.08), bevel=0.02)       # counter
    for x in (-0.8, 0.8):                                                # freezers out front
        m.box("wall", (x, -0.55, 0.42), (1.2, 0.6, 0.84), bevel=0.04)
        m.box("glass", (x, -0.55, 0.86), (1.1, 0.5, 0.04))
        for k in range(3):
            m.blob(flavours[(k + (2 if x > 0 else 0)) % 6], (x - 0.35 + k * 0.35, -0.55, 0.8), (0.13, 0.13, 0.08), wobble=0.1)
    for k in range(8):                                                   # striped awning
        m.box("canvas" if k % 2 == 0 else "trim", (-1.75 + k * 0.5, -0.45, 2.55), (0.5, 0.95, 0.04), rot=(0.3, 0, 0))
    m.box("dark", (1.55, -0.05, 2.1), (0.7, 0.05, 0.6))                  # menu board
    for k in range(4):
        m.box("glow_warm", (1.55, -0.08, 2.3 - k * 0.13), (0.5, 0.02, 0.04))
    # The giant cone on the roof: waffle cone, three neon scoops, a cherry.
    tmp = bmesh.new()
    res = bmesh.ops.create_cone(tmp, cap_ends=True, segments=12, radius1=0.06, radius2=0.8, depth=2.0)
    bmesh.ops.translate(tmp, vec=Vector((0, 1.3, 4.2)), verts=res["verts"])
    bp.merge(m.bm("glow_warm"), tmp)
    for k, (dx, dz, r, mat) in enumerate([(0, 5.45, 0.88, "glow_shop"), (-0.2, 6.3, 0.7, "glow_lime"), (0.14, 7.0, 0.56, "glow_shop")]):
        m.blob(mat, (dx, 1.3, dz), (r, r, r * 0.85), subdiv=2, wobble=0.06)
    m.blob("glow_red", (0.14, 1.3, 7.62), (0.16, 0.16, 0.16), subdiv=2, wobble=0.0)
    # Bunting along the awning's edge.
    for k in range(9):
        x = -1.9 + k * 0.475
        m.box("canvas" if k % 2 == 0 else "trim", (x, -0.95, 2.18), (0.26, 0.02, 0.26), rot=(0, math.pi / 4, 0))
    for x in (-1.5, 1.5):                                                # stools
        m.cyl("metal", (x, -1.1, 0.35), 0.04, 0.7, sides=6)
        m.cyl("canvas", (x, -1.1, 0.72), 0.2, 0.07, sides=10)
    m.export()


def scooter():
    m = Model("scooter", 43)
    m.blob("trim", (0, 0, 0.6), (0.3, 0.8, 0.25), subdiv=2, wobble=0.0)
    m.box("dark", (0, 0.25, 0.85), (0.32, 0.6, 0.1), bevel=0.04)
    for y in (-0.62, 0.62):
        m.cyl("dark", (0, y, 0.25), 0.25, 0.14, sides=12, rot=(0, math.pi / 2, 0))
    m.tube("metal", [(0, -0.62, 0.25), (0, -0.7, 1.1)], [0.04, 0.04], 5)
    m.box("metal", (0, -0.7, 1.12), (0.6, 0.05, 0.05))
    m.box("glow_cyan", (0, -0.78, 0.9), (0.2, 0.04, 0.1))
    m.box("glow_red", (0, 0.82, 0.62), (0.2, 0.04, 0.06))
    m.export()


def vending():
    m = Model("vending", 47)
    m.box("dark", (0, 0, 1.0), (1.0, 0.8, 2.0), bevel=0.04)
    m.box("glow_shop", (-0.12, -0.41, 1.2), (0.62, 0.02, 1.3))
    for r in range(4):
        for c in range(3):
            m.box(["trim", "glow_warm", "metal"][(r + c) % 3], (-0.32 + c * 0.2, -0.43, 0.7 + r * 0.32), (0.12, 0.03, 0.2))
    m.box("glow_cyan", (0.35, -0.41, 1.6), (0.18, 0.02, 0.3))
    m.box("metal", (0, -0.41, 0.3), (0.8, 0.04, 0.25))
    m.export()


def bench():
    m = Model("bench", 53)
    for k in range(4):
        m.box("wood", (0, -0.25 + k * 0.17, 0.45), (2.4, 0.14, 0.06), bevel=0.02)
    for k in range(2):
        m.box("wood", (0, 0.32, 0.62 + k * 0.17), (2.4, 0.06, 0.12), rot=(0.15, 0, 0), bevel=0.02)
    for s in (-1, 1):
        m.prism("metal", [(s * 1.0 - 0.05, -0.3), (s * 1.0 + 0.05, -0.3), (s * 1.0 + 0.05, 0.35), (s * 1.0 - 0.05, 0.35)], 0, 0.42)
    m.export()


def planter_box():
    m = Model("planter", 59)
    m.box("trim", (0, 0, 0.4), (2.4, 2.4, 0.8), bevel=0.15)
    m.box("moss", (0, 0, 0.81), (2.1, 2.1, 0.04))
    for k in range(5):
        m.blob("leaves", (m.rng.uniform(-0.7, 0.7), m.rng.uniform(-0.7, 0.7), 1.0), (0.5, 0.5, 0.4))
    m.export()


def crates():
    m = Model("crates", 61)
    for spec in (((0, 0, 0.4), 0.8, 0.0), ((0.85, 0.1, 0.35), 0.7, 0.3), ((0.3, 0.05, 1.1), 0.6, -0.2)):
        c, s, r = spec
        m.box("wood", c, (s, s, s), rot=(0, 0, r), bevel=0.03)
        m.box("metal", (c[0], c[1], c[2] + s * 0.3), (s + 0.02, s + 0.02, 0.05), rot=(0, 0, r))
    m.cyl("dark", (-0.9, 0.2, 0.45), 0.3, 0.9, sides=10)
    m.cyl("metal", (-0.9, 0.2, 0.92), 0.31, 0.04, sides=10)
    m.export()


def blade_sign(name, lines):
    """Vertical sign frame sticking out from a wall: dark box, neon border, bracket.
    Text goes on in Godot. Its plane is Blender XZ, 1.8 wide, `lines` tall."""
    m = Model(name, 67)
    h = 1.4 + lines * 1.1
    m.box("dark", (0, 0, h * 0.5), (1.8, 0.3, h), bevel=0.06)
    for x in (-0.86, 0.86):
        m.box("neon", (x, 0, h * 0.5), (0.06, 0.34, h - 0.1))
    for z in (0.06, h - 0.06):
        m.box("neon", (0, 0, z), (1.7, 0.34, 0.06))
    m.box("metal", (1.05, 0, h - 0.4), (0.4, 0.1, 0.1))
    m.box("metal", (1.05, 0, 0.4), (0.4, 0.1, 0.1))
    m.export()


def pergola():
    m = Model("pergola", 71)
    for x in (-4.0, 4.0):
        for y in (-2.5, 2.5):
            m.box("wood", (x, y, 1.5), (0.22, 0.22, 3.0), bevel=0.03)
    for y in (-2.5, 2.5):
        m.box("wood", (0, y, 3.05), (8.6, 0.2, 0.25))
    for k in range(9):
        m.box("wood", (-4.0 + k, 0, 3.25), (0.12, 5.6, 0.16))
    for k in range(12):
        m.blob("leaves", (m.rng.uniform(-4, 4), m.rng.uniform(-2.6, 2.6), 3.45), (0.7, 0.7, 0.3))
    for k in range(5):
        ln = m.rng.uniform(0.6, 1.6)
        m.box("moss", (m.rng.uniform(-4, 4), -2.6, 3.0 - ln * 0.5), (0.3, 0.08, ln))
    m.sag("dark", (-4.0, 2.6, 2.9), (4.0, 2.6, 2.9), 0.35, 0.012)
    for k in range(12):
        t = (k + 0.5) / 12
        m.box("glow_warm", (-4.0 + 8 * t, 2.6, 2.9 - 1.4 * t * (1 - t) - 0.08), (0.1, 0.1, 0.13))
    m.export()


def city_tower(name, seed, h, w):
    """A dark arcology tower for the horizon: stepped setbacks, lit window bands,
    a red beacon."""
    m = Model(name, seed)
    z = 0.0
    tiers = 3
    for t in range(tiers):
        th = h / tiers
        ww = w * (1 - t * 0.2)
        m.box("dark", (0, 0, z + th * 0.5), (ww, ww, th))
        for k in range(int(th / 6)):
            if m.rng.random() < 0.6:
                m.box(m.rng.choice(["glow_warm", "glow_shop", "glow_cool"]), (0, -ww * 0.5 - 0.05, z + 3 + k * 6), (ww * m.rng.uniform(0.3, 0.9), 0.1, 0.5))
        z += th
    m.tube("metal", [(0, 0, z), (0, 0, z + h * 0.15)], [0.6, 0.2], 6)
    m.box("glow_red", (0, 0, z + h * 0.15), (1.2, 1.2, 1.2))
    m.export()


def main():
    bp.clear()
    shop("shop_w13_f3", 13.0, 3, 101, roof="solar")
    shop("shop_w13_f3b", 13.0, 3, 103, roof="garden")
    shop("shop_w13_f2", 13.0, 2, 107, roof="garden")
    shop("shop_w11_f4", 11.0, 4, 109, roof="garden", awning=False)
    shop("shop_w11_f3", 11.0, 3, 113, roof="solar")
    shop("shop_w9_f3", 9.0, 3, 127, roof="solar", awning=False, boarded=True)
    shop("shop_w9_f2", 9.0, 2, 131, roof="garden", awning=False)
    militia_office()
    greenhouse()
    gate_pylon()
    gate_arch()
    checkpoint()
    sun_tree()
    canopy_bay()
    lantern()
    market_stall()
    cafe_table()
    solar_lamp()
    turbine_tower()
    turbine_rotor()
    noodle_stall()
    ice_cream_kiosk()
    scooter()
    vending()
    bench()
    planter_box()
    crates()
    blade_sign("blade_sign_2", 2)
    blade_sign("blade_sign_3", 3)
    pergola()
    city_tower("city_tower_a", 201, 110.0, 20.0)
    city_tower("city_tower_b", 203, 70.0, 16.0)


if __name__ == "__main__":
    main()
