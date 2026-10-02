"""Builds the in-game Eco from Bones's VRoid preset (the "anime fox girl" model,
kept in the project files as preset/anime-fox-girl-preset.zip -> Untitled.glb).
Run through Blender 4:

    blender -b --factory-startup -P tools/eco/build_eco_vroid.py -- <Untitled.glb> <repo root> [--preview <png prefix>]

What it does to the preset, in its rest space (she faces -Y there, her left is +X):
- removes the fox ears and tail, the preset's clothes (the boots stay, recoloured)
- cuts the hair to a chin-length bob with a swept fringe and dyes it dark red
- a fiercer, older face: smaller irises and a longer chin (the angry brows and
  narrowed eyes are blend shapes, set on import), mature makeup painted in
- paints the pilot suit onto her skin: halter bodysuit with a keyhole, open back
  and high-cut legs, waist band, gloves, thigh-high boots with knee plates, teal
  glow trims. Baked into v_body.png (+ a glow map and a sheen/suit mask)
- goggles on her head, skinned to the head bone
- glute bones beside the preset's bust bones, for the jiggle springs
- a slightly smaller head and longer legs, 1.69 m tall, turned to face +Y
- idle/walk/run/fall/crouch/slide animations for the VRoid rig
Writes assets/models/eco/eco.glb and assets/textures/eco/v_*.png. The glb's
material names (eco_v_*) are swapped for assets/materials/eco/eco_v_*.tres by
assets/models/eco/eco_import.gd.
"""
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector
from mathutils.bvhtree import BVHTree

argv = sys.argv[sys.argv.index("--") + 1:]
SRC = argv[0]
ROOT = argv[1]
PREVIEW = argv[argv.index("--preview") + 1] if "--preview" in argv else None
TEX_OUT = os.path.join(ROOT, "assets", "textures", "eco")
GLB_OUT = os.path.join(ROOT, "assets", "models", "eco", "eco.glb")

HEIGHT = 1.69
HEAD_SCALE = 0.95
LEG_SCALE = 1.03

# suit colours (linear)
SUIT = (0.032, 0.036, 0.052)
GEAR = (0.016, 0.016, 0.021)
PLATE = (0.085, 0.09, 0.105)
TRIM = (0.0, 0.62, 0.55)
INK = (0.012, 0.009, 0.014)

# the fierce expression, applied as blend shapes on import (eco_import.gd)
EXPRESSION = {"Fcl_BRW_Angry": 1.0, "Fcl_EYE_Angry": 0.55, "Fcl_MTH_Down": 0.1}


def smooth(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def ss(e0, e1, v):
    t = np.clip((v - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


# --- images --------------------------------------------------------------------

def to_lin(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def to_srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def read_px(img):
    """Pixels of a byte image as stored (sRGB values), rows bottom-up."""
    w, h = img.size
    px = np.empty(w * h * 4, np.float32)
    img.pixels.foreach_get(px)
    return px.reshape(h, w, 4)


def write_png(px, name):
    h, w = px.shape[:2]
    img = bpy.data.images.new(name, w, h, alpha=True)
    img.pixels.foreach_set(np.clip(px, 0, 1).astype(np.float32).ravel())
    img.filepath_raw = os.path.join(TEX_OUT, name + ".png")
    img.file_format = "PNG"
    img.save()
    return img


def box_blur(a, r):
    """Mean over a (2r+1)^2 window (edges clamped), via summed-area tables."""
    p = np.pad(a, ((r + 1, r), (r + 1, r)) + ((0, 0),) * (a.ndim - 2), mode="edge")
    c = p.cumsum(0).cumsum(1)
    k = 2 * r + 1
    s = c[k:, k:] - c[:-k, k:] - c[k:, :-k] + c[:-k, :-k]
    return s / (k * k)


def fill_holes(rgb, hole):
    """Fill masked pixels from the surrounding colour, widening the search."""
    out = rgb.copy()
    known = (~hole).astype(np.float32)
    todo = hole.copy()
    for r in (2, 4, 8, 16, 32, 64, 128):
        den = box_blur(known, r)
        num = box_blur(rgb * known[..., None], r)
        ok = todo & (den > 0.08)
        out[ok] = num[ok] / den[ok][:, None]
        todo &= ~ok
    return out


def dilate(mask, n):
    m = mask.copy()
    for _ in range(n):
        g = m.copy()
        g[1:] |= m[:-1]
        g[:-1] |= m[1:]
        g[:, 1:] |= m[:, :-1]
        g[:, :-1] |= m[:, 1:]
        m = g
    return m


def ramp(v, stops):
    """Linear colour ramp; stops = [(pos, (r, g, b)), ...]."""
    pos = np.array([s[0] for s in stops])
    out = np.empty(v.shape + (3,), np.float32)
    for c in range(3):
        out[..., c] = np.interp(v, pos, [s[1][c] for s in stops])
    return out


def lum(lin_rgb):
    return lin_rgb @ np.array([0.2126, 0.7152, 0.0722], np.float32)


HAIR_RAMP = [(0.30, (0.016, 0.001, 0.004)), (0.62, (0.080, 0.004, 0.010)),
             (0.86, (0.18, 0.011, 0.018)), (1.0, (0.40, 0.045, 0.045))]


def dye_hair(px):
    """Dark red from the preset texture's brightness: wine in the shadows,
    crimson through the body, a hot red sheen on the highlights."""
    out = px.copy()
    out[..., :3] = to_srgb(ramp(lum(to_lin(px[..., :3])), HAIR_RAMP))
    return out


def recolour_boots(px):
    out = px.copy()
    t = lum(to_lin(px[..., :3]))[..., None]
    out[..., :3] = to_srgb(np.array((0.006, 0.006, 0.008)) * (1 - t) + np.array((0.07, 0.072, 0.085)) * t)
    return out


# --- scene -----------------------------------------------------------------------

def setup_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=SRC)
    for o in list(bpy.data.objects):
        if o.name.startswith("Icosphere"):
            bpy.data.objects.remove(o)
    body = bpy.data.objects["Body"].data
    a = body.attributes.new("rest", "FLOAT_VECTOR", "POINT")
    for v in body.vertices:
        a.data[v.index].vector = v.co
    return [o for o in bpy.data.objects if o.type == "ARMATURE"][0]


def delete_faces(ob, keep_face):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    dead = [f for f in bm.faces if not keep_face(f)]
    bmesh.ops.delete(bm, geom=dead, context="FACES")
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()
    return len(dead)


def islands(bm):
    bm.faces.ensure_lookup_table()
    seen, out = set(), []
    for f in bm.faces:
        if f.index in seen:
            continue
        stack, comp = [f], []
        seen.add(f.index)
        while stack:
            g = stack.pop()
            comp.append(g)
            for e in g.edges:
                for n in e.link_faces:
                    if n.index not in seen:
                        seen.add(n.index)
                        stack.append(n)
        out.append(comp)
    return out


def mat_index(ob, needle):
    return {i for i, m in enumerate(ob.data.materials) if m and needle in m.name}


def remove_fox_parts():
    # the third hair material only covers the ears (and the fluff at their base)
    delete_faces(bpy.data.objects["Hair"], lambda f: f.material_index != 2)
    body = bpy.data.objects["Body"]
    tail = mat_index(body, "FoxTail")
    delete_faces(body, lambda f: f.material_index not in tail)


def short_hair():
    """The back hair is a short layer from crown to nape plus separate long pieces
    and braids. Drop every piece that doesn't reach above the nape, fold what's
    left below the jaw into a chin-length bob, and lift the fringe off her eyes
    (longer over her right eye)."""
    hair = bpy.data.objects["Hair"]
    bm = bmesh.new()
    bm.from_mesh(hair.data)
    dead = []
    for comp in islands(bm):
        if max(v.co.z for f in comp for v in f.verts) < 1.22:
            dead.extend(comp)
    bmesh.ops.delete(bm, geom=list(set(dead)), context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(hair.data)
    bm.free()
    me = hair.data
    mat_of = {}
    for p in me.polygons:
        for v in p.vertices:
            mat_of[v] = min(mat_of.get(v, 9), p.material_index)
    rules = {0: (1.25, 0.035, 0.15), 1: (1.335, 0.035, 0.0)}   # z0, depth, tuck
    for v in me.vertices:
        p = v.co.copy()
        m = mat_of.get(v.index, 0)
        z0, L, tuck = rules.get(m, rules[0])
        if m == 1:
            z0 -= 0.026 * smooth(0.005, -0.04, p.x)
        d = z0 - p.z
        if d <= 0:
            continue
        w = smooth(z0, z0 - 0.12, p.z) * tuck
        v.co = Vector((p.x * (1 - w), 0.02 + (p.y - 0.02) * (1 - w), z0 - L * (1 - math.exp(-d / L))))


def fierce_face():
    face = bpy.data.objects["Face"]
    me = face.data
    keys = me.shape_keys.key_blocks
    mat_of = {}
    for p in me.polygons:
        for v in p.vertices:
            mat_of.setdefault(v, set()).add(p.material_index)
    for side in (1, -1):   # smaller irises and highlights: a harder stare
        ids = [v.index for v in me.vertices if mat_of.get(v.index, set()) & {1, 2} and v.co.x * side > 0]
        c = sum((me.vertices[i].co for i in ids), Vector()) / len(ids)
        for kb in keys:
            for i in ids:
                p = kb.data[i].co
                kb.data[i].co = Vector((c.x + (p.x - c.x) * 0.88, p.y, c.z + (p.z - c.z) * 0.88))
    for kb in keys:   # a longer, narrower chin (front of the lower face only)
        for v in me.vertices:
            w = smooth(1.262, 1.214, v.co.z) * smooth(-0.025, -0.045, v.co.y)
            if w > 0:
                p = kb.data[v.index].co
                kb.data[v.index].co = Vector((p.x * (1 - 0.04 * w), p.y, p.z - 0.006 * w))
    for v in me.vertices:
        v.co = keys[0].data[v.index].co


def face_position_map(face, W, H):
    """Rest-space position of every face-skin texel, and which texels are skin."""
    me = face.data
    me.calc_loop_triangles()
    uv = me.uv_layers["UVMap"].data
    skin = mat_index(face, "SKIN")
    pos = np.zeros((H, W, 3), np.float32)
    mask = np.zeros((H, W), bool)
    for t in me.loop_triangles:
        if t.material_index not in skin:
            continue
        P = np.array([me.vertices[v].co[:] for v in t.vertices])
        U = np.array([uv[l].uv[:] for l in t.loops]) * (W, H)
        x0, y0 = np.floor(U.min(0)).astype(int)
        x1, y1 = np.ceil(U.max(0)).astype(int)
        x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, W - 1), min(y1, H - 1)
        if x1 < x0 or y1 < y0:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        a, b, c = U
        den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(den) < 1e-12:
            continue
        l0 = ((b[1] - c[1]) * (gx - c[0]) + (c[0] - b[0]) * (gy - c[1])) / den
        l1 = ((c[1] - a[1]) * (gx - c[0]) + (a[0] - c[0]) * (gy - c[1])) / den
        l2 = 1 - l0 - l1
        ins = (l0 > -0.02) & (l1 > -0.02) & (l2 > -0.02)
        p = l0[..., None] * P[0] + l1[..., None] * P[1] + l2[..., None] * P[2]
        sub = pos[y0:y1 + 1, x0:x1 + 1]
        sub[ins] = p[ins]
        mask[y0:y1 + 1, x0:x1 + 1] |= ins
    return pos, mask


def face_texture(face, src_img):
    """Face skin: soften the cheek blush, then paint mature makeup in 3D:
    smoky plum lids, a winged liner flick and a berry lip stain."""
    px = read_px(src_img).copy()
    H, W = px.shape[:2]
    rgb = px[..., :3] * 255
    # blush: the preset's pink cheek patches (image rows run bottom-up here)
    yy, xx = np.mgrid[0:H, 0:W]
    yy = H - 1 - yy
    w = np.zeros((H, W))
    for cx in (330, 690):
        r = ((xx - cx) / 130.0) ** 2 + ((yy - 625) / 85.0) ** 2
        w = np.maximum(w, np.clip(1.4 - r, 0, 1))
    pink = rgb[..., 0] - (rgb[..., 1] + rgb[..., 2]) / 2
    d = np.clip(pink - 19.0, 0, None) * w * 0.85
    rgb[..., 0] -= d * 2 / 3
    rgb[..., 1] += d / 3
    rgb[..., 2] += d / 3
    px[..., :3] = rgb / 255
    pos, mask = face_position_map(face, W, H)
    x, y, z = np.abs(pos[..., 0]), pos[..., 1], pos[..., 2]

    def tint(col, amount):
        a = (amount * mask)[..., None]
        px[..., :3] = px[..., :3] * (1 - a) + px[..., :3] * np.array(col) * a

    def paint(col, amount):
        a = (amount * mask)[..., None]
        px[..., :3] = px[..., :3] * (1 - a) + np.array(col) * a
    u = (x - 0.041) / 0.029
    v = (z - 1.2905) / 0.0135
    lid = (1 - ss(0.45, 1.0, np.sqrt(u * u + v * v))) * ss(1.276, 1.287, z) * (y < -0.015)
    lid *= 0.55 + 0.45 * ss(0.02, 0.06, x)
    tint((0.55, 0.30, 0.38), 0.75 * lid)
    P0, P1, T = np.array((0.0560, 1.2868)), np.array((0.0575, 1.2925)), np.array((0.0708, 1.2985))

    def edge(a, b, qx, qz):
        n = np.array((b[1] - a[1], -(b[0] - a[0])))
        n /= np.linalg.norm(n)
        return (qx - a[0]) * n[0] + (qz - a[1]) * n[1]
    s = np.sign(edge(P0, T, *P1)), np.sign(edge(T, P1, *P0)), np.sign(edge(P1, P0, *T))
    AA = 0.00025
    wing = (ss(-AA, AA, edge(P0, T, x, z) * s[0]) * ss(-AA, AA, edge(T, P1, x, z) * s[1])
            * ss(-AA, AA, edge(P1, P0, x, z) * s[2]) * (y < -0.005))
    paint((0.17, 0.07, 0.09), 0.9 * wing)
    dz = z - 1.2397
    lips = (pos[..., 0] / 0.0098) ** 2 + (dz / np.where(dz < 0, 0.0036, 0.0021)) ** 2
    tint((0.78, 0.42, 0.47), 0.75 * (1 - ss(0.35, 1.0, lips)) * (y < -0.04))
    return px


def strip_clothes():
    """Drop the preset's corset, shorts, belt and choker; the boots become their
    own object (their open cuffs would show the ink outline from inside)."""
    body = bpy.data.objects["Body"]
    mats = body.data.materials
    drop = {i for i, m in enumerate(mats) if m and ("Tops" in m.name or "Onepiece" in m.name
                                                     or "Bottoms_01_CLOTH_0" in m.name)}
    delete_faces(body, lambda f: f.material_index not in drop)
    boot_idx = {i for i, m in enumerate(mats) if m and ("Shoes" in m.name or m.name.endswith("Bottoms_01_CLOTH (Instance)"))}
    boots = body.copy()
    boots.data = body.data.copy()
    boots.name = boots.data.name = "Boots"
    bpy.context.scene.collection.objects.link(boots)
    delete_faces(boots, lambda f: f.material_index in boot_idx)
    delete_faces(body, lambda f: f.material_index not in boot_idx)
    return boots


# --- goggles ---------------------------------------------------------------------

def new_mat(name, col=(0.5, 0.5, 0.5)):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.diffuse_color = (*col, 1)
    return m


def goggles(arm):
    """Pilot goggles pushed up on her head: a strap around the hair and two lens
    cups over the hairline, one mesh skinned to the head bone."""
    dg = bpy.context.evaluated_depsgraph_get()
    trees = [BVHTree.FromObject(bpy.data.objects[n], dg) for n in ("Hair", "Face", "Body")]
    C = Vector((0.0, 0.03, 1.335))
    up = Vector((0.0, 0.32, 1.0)).normalized()     # the strap tilts: high at the front
    fwd = Vector((0.0, -1.0, 0.0))
    fwd = (fwd - up * fwd.dot(up)).normalized()
    side = fwd.cross(up).normalized()

    def surface(d):
        best = None
        for t in trees:
            hit = t.ray_cast(C + d * 0.3, -d)
            if hit[0] is not None:
                r = (hit[0] - C).length
                best = r if best is None else max(best, r)
        return best or 0.1
    N = 72
    dirs = [(fwd * math.cos(2 * math.pi * k / N) + side * math.sin(2 * math.pi * k / N)).normalized() for k in range(N)]
    ring = [surface(d) for d in dirs]
    for _ in range(4):
        ring = [(ring[k - 1] + 2 * ring[k] + ring[(k + 1) % N]) / 4 for k in range(N)]
    bm = bmesh.new()
    mats = [new_mat("eco_v_goggle_strap", (0.02, 0.02, 0.02)), new_mat("eco_v_goggle_frame", (0.05, 0.05, 0.06)),
            new_mat("eco_v_goggle_glow", TRIM), new_mat("eco_v_goggle_lens", (0.01, 0.05, 0.06))]
    Hh, Tt = 0.016, 0.0035
    rings = []
    for k in range(N):
        p = C + dirs[k] * (ring[k] + 0.0025)
        rings.append([bm.verts.new(p + dirs[k] * o + up * (h * Hh / 2)) for o, h in ((0, -1), (0, 1), (Tt, 1), (Tt, -1))])
    for k in range(N):
        a, b = rings[k], rings[(k + 1) % N]
        for j in range(4):
            f = bm.faces.new((a[j], a[(j + 1) % 4], b[(j + 1) % 4], b[j]))
            f.material_index = 0
    for s in (1, -1):
        a = 0.36 * s
        d = (fwd * math.cos(a) + side * math.sin(a)).normalized()
        k = int(round((a % (2 * math.pi)) / (2 * math.pi) * N)) % N
        base = C + d * (ring[k] + 0.006)
        axis = (d * math.cos(math.radians(35)) + up * math.sin(math.radians(35))).normalized()
        R = Vector((0, 0, 1)).rotation_difference(axis).to_matrix().to_4x4()
        for kind, r, depth, off, mi in (("cyl", 0.0185, 0.014, 0.007, 1), ("torus", 0.0185, 0.0017, 0.0145, 2),
                                        ("cyl", 0.0158, 0.002, 0.0145, 3)):
            M = Matrix.Translation(base + axis * off) @ R
            new = []
            if kind == "cyl":
                res = bmesh.ops.create_cone(bm, cap_ends=True, segments=32, radius1=r, radius2=r, depth=depth, matrix=M)
                new = res["verts"]
            else:
                major, minor = r, depth
                grid = []
                for i in range(32):
                    t = 2 * math.pi * i / 32
                    row = []
                    for j in range(8):
                        u = 2 * math.pi * j / 8
                        q = Vector(((major + minor * math.cos(u)) * math.cos(t), (major + minor * math.cos(u)) * math.sin(t), minor * math.sin(u)))
                        row.append(bm.verts.new(M @ q))
                    grid.append(row)
                for i in range(32):
                    for j in range(8):
                        bm.faces.new((grid[i][j], grid[(i + 1) % 32][j], grid[(i + 1) % 32][(j + 1) % 8], grid[i][(j + 1) % 8]))
                new = [v for row in grid for v in row]
            vs = set(new)
            for f in bm.faces:
                if all(v in vs for v in f.verts):
                    f.material_index = mi
    me = bpy.data.meshes.new("Goggles")
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(m)
    ob = bpy.data.objects.new("Goggles", me)
    bpy.context.scene.collection.objects.link(ob)
    vg = ob.vertex_groups.new(name="J_Bip_C_Head")
    vg.add(list(range(len(me.vertices))), 1.0, "REPLACE")
    ob.parent = arm
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    return ob


# --- rig: glute bones, proportions ------------------------------------------------

def glute_bones(arm):
    """Two short chains behind the hips (root inside the pelvis, tip at the glute)
    for the jiggle springs, with the glutes weighted to them."""
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones
    for s, side in ((1, "L"), (-1, "R")):
        b1 = eb.new("J_Sec_%s_Glute1" % side)
        b1.head, b1.tail = (s * 0.058, 0.01, 0.785), (s * 0.058, 0.01, 0.835)
        b1.parent = eb["J_Bip_C_Hips"]
        b2 = eb.new("J_Sec_%s_Glute2" % side)
        b2.head, b2.tail = (s * 0.058, 0.075, 0.765), (s * 0.058, 0.075, 0.815)
        b2.parent = b1
    bpy.ops.object.mode_set(mode="OBJECT")
    body = bpy.data.objects["Body"]
    rest = body.data.attributes["rest"].data
    for s, side in ((1, "L"), (-1, "R")):
        vg = body.vertex_groups.new(name="J_Sec_%s_Glute1" % side)
        for v in body.data.vertices:
            x, y, z = rest[v.index].vector
            if x * s <= 0:
                continue
            w = 0.75 * math.exp(-(((abs(x) - 0.058) / 0.042) ** 2 + ((z - 0.762) / 0.045) ** 2)) * smooth(0.0, 0.05, y)
            if w < 0.01:
                continue
            for g in v.groups:
                g.weight *= 1 - w
            vg.add([v.index], w, "REPLACE")


def descendants(bone):
    out = [bone]
    for c in bone.children:
        out += descendants(c)
    return out


def proportions(arm, objs):
    """A slightly smaller head (scaled about the top of the neck, weighted by how
    much each vertex follows the head) and 3% longer legs (below the hip joints)."""
    head = arm.data.bones["J_Bip_C_Head"]
    c = head.head_local.copy()
    head_set = {b.name for b in descendants(head)}
    zh = arm.data.bones["J_Bip_L_UpperLeg"].head_local.z

    def head_map(p, w):
        return c + (p - c) * (1 - (1 - HEAD_SCALE) * w)

    def leg_map(p):
        return Vector((p.x, p.y, zh - (zh - p.z) * LEG_SCALE)) if p.z < zh else p
    for ob in objs:
        names = {g.index: g.name for g in ob.vertex_groups}
        me = ob.data
        ws = [sum(g.weight for g in v.groups if names.get(g.group) in head_set) for v in me.vertices]
        if me.shape_keys:
            for kb in me.shape_keys.key_blocks:
                for i, w in enumerate(ws):
                    kb.data[i].co = leg_map(head_map(kb.data[i].co.copy(), min(w, 1.0)))
        for v, w in zip(me.vertices, ws):
            v.co = leg_map(head_map(v.co.copy(), min(w, 1.0)))
    leg_set = set()
    for s in "LR":
        leg_set |= {b.name for b in descendants(arm.data.bones["J_Bip_%s_UpperLeg" % s])}
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for e in arm.data.edit_bones:
        if e.name in head_set and e.name != "J_Bip_C_Head":
            e.head, e.tail = head_map(e.head.copy(), 1.0), head_map(e.tail.copy(), 1.0)
        elif e.name in leg_set:
            off = e.tail - e.head
            e.head = leg_map(e.head.copy())
            e.tail = e.head + off
    bpy.ops.object.mode_set(mode="OBJECT")


def prune_bones(arm):
    """Bones for things she no longer has: the skirt, the tail and the fox ears."""
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones
    dead = [e for e in eb if "Skirt" in e.name or "FoxTail" in e.name or "Tail" in e.name
            or any(e.name == "J_Sec_Hair%d_%d" % (i, j) for i in range(1, 5) for j in (10, 11))]
    for e in dead:
        eb.remove(e)
    bpy.ops.object.mode_set(mode="OBJECT")
    names = {b.name for b in arm.data.bones}
    for ob in arm.children:
        for g in list(ob.vertex_groups):
            if g.name.startswith(("J_Sec_", "J_Opt_")) and g.name not in names:
                ob.vertex_groups.remove(g)
    print("pruned %d bones" % len(dead))


def face_forward_and_scale(arm, objs):
    """Turn her to face +Y (the old Eco's facing, so the game's -Z forward) and
    scale to her height, then apply both so the rig is in metres."""
    dg = bpy.context.evaluated_depsgraph_get()
    top = 0.0
    for ob in objs:
        if ob.name == "Goggles":
            continue
        me = ob.evaluated_get(dg).to_mesh()
        top = max(top, max(v.co.z for v in me.vertices))
        ob.evaluated_get(dg).to_mesh_clear()
    k = HEIGHT / top
    arm.rotation_mode = "QUATERNION"
    arm.rotation_quaternion = Quaternion((0, 0, 1), math.pi)
    arm.scale = (k, k, k)
    bpy.context.view_layer.update()
    for o in bpy.data.objects:
        o.select_set(o == arm or o in objs)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    print("scaled by %.3f to %.2f m, facing +Y" % (k, HEIGHT))


# --- suit bake ----------------------------------------------------------------------

class NG:
    """Tiny node-graph builder so shader maths reads like maths."""

    def __init__(self, nt):
        self.nt = nt

    def put(self, sock, v):
        if isinstance(v, (int, float)):
            sock.default_value = v
        else:
            self.nt.links.new(v, sock)

    def op(self, operation, a, b=None):
        n = self.nt.nodes.new("ShaderNodeMath")
        n.operation = operation
        self.put(n.inputs[0], a)
        if b is not None:
            self.put(n.inputs[1], b)
        return n.outputs[0]

    def _f(self, a, b, py, op):
        return py(a, b) if isinstance(a, (int, float)) and isinstance(b, (int, float)) else self.op(op, a, b)

    def add(self, a, b):
        return self._f(a, b, lambda p, q: p + q, "ADD")

    def sub(self, a, b):
        return self._f(a, b, lambda p, q: p - q, "SUBTRACT")

    def mul(self, a, b):
        return self._f(a, b, lambda p, q: p * q, "MULTIPLY")

    def div(self, a, b):
        return self.op("DIVIDE", a, b)

    def mn(self, a, b):
        return self.op("MINIMUM", a, b)

    def mx(self, a, b):
        return self.op("MAXIMUM", a, b)

    def abs(self, a):
        return self.op("ABSOLUTE", a)

    def sqrt(self, a):
        return self.op("SQRT", a)

    def sq(self, a):
        return self.op("MULTIPLY", a, a)

    def neg(self, a):
        return self.mul(a, -1.0)

    def lerp(self, a, b, t):
        return self.add(a, self.mul(self.sub(b, a), t))

    def sstep(self, e0, e1, x):
        n = self.nt.nodes.new("ShaderNodeMapRange")
        n.interpolation_type = "SMOOTHSTEP"
        n.clamp = True
        self.put(n.inputs[0], x)
        n.inputs[1].default_value, n.inputs[2].default_value = e0, e1
        n.inputs[3].default_value, n.inputs[4].default_value = 0.0, 1.0
        return n.outputs[0]

    def band(self, x, lo, hi, aa=0.00035):
        return self.mul(self.sstep(lo - aa, lo + aa, x), self.sub(1.0, self.sstep(hi - aa, hi + aa, x)))

    def mixc(self, a, b, t):
        n = self.nt.nodes.new("ShaderNodeMix")
        n.data_type = "RGBA"
        self.put(n.inputs[0], t)
        for sock, v in ((n.inputs[6], a), (n.inputs[7], b)):
            if isinstance(v, tuple):
                sock.default_value = v if len(v) == 4 else (*v, 1)
            else:
                self.nt.links.new(v, sock)
        return n.outputs[2]


def suit_graph(nt, skin):
    """The pilot suit, worked out per pixel from each point's rest position (the
    'rest' attribute) so its edges are smooth curves whatever the mesh does.
    Returns (albedo colour, glow amount, cover amount, ink line, gloves and
    boots) sockets."""
    g = NG(nt)
    at = nt.nodes.new("ShaderNodeAttribute")
    at.attribute_name = "rest"
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(at.outputs["Vector"], sep.inputs[0])
    x, y, z = sep.outputs[0], sep.outputs[1], sep.outputs[2]
    ax = g.abs(x)
    tb = g.sstep(-0.025, 0.045, y)                    # 0 at the front, 1 at the back
    front = g.sub(1.0, g.sstep(-0.045, -0.025, y))
    # neckline: a halter at the front, open back down to the waist
    zf = g.sub(1.17, g.mul(1.34, g.mx(g.sub(ax, 0.028), 0.0)))
    zb = g.mn(g.add(0.90, g.mul(0.17, g.sq(g.div(ax, 0.11)))), 1.065)
    d_top = g.mul(g.sub(g.lerp(zf, zb, tb), z), g.lerp(0.6, 1.0, tb))
    # high-cut legs: steep up over the hip at the front, fuller cover behind
    lx = g.mx(g.sub(ax, 0.02), 0.0)
    zlf = g.add(0.655, g.mul(1.4, lx))
    zlb = g.add(0.665, g.mul(0.55, lx))
    d_leg = g.mul(g.sub(z, g.lerp(zlf, zlb, tb)), g.lerp(0.54, 0.88, tb))
    d_torso = g.mn(d_top, d_leg)
    r = g.sqrt(g.add(g.sq(x), g.sq(g.sub(y, 0.022))))
    d_collar = g.mn(g.mn(g.sub(z, 1.166), g.sub(1.205, z)), g.sub(0.062, r))
    q = g.sqrt(g.add(g.sq(g.div(x, 0.017)), g.sq(g.div(g.sub(z, 1.115), 0.03))))
    d_key = g.sub(g.mul(g.sub(1.0, q), 0.02), g.sub(1.0, front))
    d_suit = g.mx(g.mn(d_torso, g.neg(d_key)), d_collar)
    d_gear = g.mx(g.sub(ax, 0.40), g.sub(0.575, z))   # gloves and boots
    kq = g.sqrt(g.add(g.sq(g.div(g.sub(ax, 0.069), 0.036)), g.sq(g.div(g.sub(z, 0.478), 0.05))))
    d_knee = g.sub(g.mul(g.sub(1.0, kq), 0.036), g.sstep(-0.012, 0.004, y))
    AA = 0.00045
    c_suit = g.sstep(-AA, AA, d_suit)
    c_gear = g.sstep(-AA, AA, d_gear)
    c_knee = g.mul(g.sstep(-AA, AA, d_knee), c_gear)
    col = g.mixc(skin, SUIT, c_suit)
    col = g.mixc(col, GEAR, c_gear)
    col = g.mixc(col, PLATE, c_knee)
    ink = g.mx(g.mx(g.band(d_suit, 0.0, 0.0008), g.band(d_gear, 0.0, 0.0008)), g.band(d_knee, -0.0002, 0.0007))
    trim = g.mx(g.band(d_suit, 0.0012, 0.0028), g.band(d_gear, 0.0012, 0.0034))
    trim = g.mx(trim, g.mul(g.band(z, 1.1845, 1.1865), g.sstep(-AA, AA, d_collar)))
    trim = g.mx(trim, g.mul(g.band(d_knee, 0.004, 0.0052), c_gear))
    band_ = g.mul(g.band(z, 0.905, 0.955, 0.0004), c_suit)
    col = g.mixc(col, PLATE, g.mul(band_, 0.55))
    trim = g.mx(trim, g.mul(g.mx(g.band(z, 0.9045, 0.9058), g.band(z, 0.9542, 0.9555)), c_suit))
    seam = g.mul(g.mul(g.band(y, 0.012, 0.0135), g.sstep(0.05, 0.06, ax)), c_suit)
    col = g.mixc(col, PLATE, seam)
    col = g.mixc(col, INK, ink)
    col = g.mixc(col, TRIM, trim)
    return col, trim, g.mx(c_suit, c_gear), ink, c_gear


def bake_body(body, skin_img):
    """Bake the suit into three textures: albedo, glow (teal trims) and a mask
    (red: where a thin sheen may show, green: suit or skin)."""
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 4
    sc.cycles.device = "CPU"
    sc.cycles.use_denoising = False   # this build has no denoiser, and with it on bakes come out black
    sc.render.bake.margin = 8
    skin_slot = mat_index(body, "Body_00_SKIN")
    m = bpy.data.materials.new("bake_body")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    uv = nt.nodes.new("ShaderNodeUVMap")
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = skin_img
    nt.links.new(uv.outputs[0], t.inputs[0])
    col, trim, cover, ink, gear = suit_graph(nt, t.outputs["Color"])
    g = NG(nt)
    # only the gloves and boots shine: on the bodysuit a sheen reads as blotches
    # and hot spots, so its cling shows in the shading alone
    sheen = g.mul(gear, g.sub(1.0, ink))
    comb = nt.nodes.new("ShaderNodeCombineColor")
    g.put(comb.inputs[0], sheen)
    g.put(comb.inputs[1], cover)
    em = nt.nodes.new("ShaderNodeEmission")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(em.outputs[0], out.inputs[0])
    for i in skin_slot:
        body.material_slots[i].material = m
    for o in bpy.data.objects:
        o.select_set(o == body)
    bpy.context.view_layer.objects.active = body
    results = {}
    for name, size, src in (("v_body", 2048, col), ("v_body_glow", 1024, g.mixc((0, 0, 0, 1), TRIM, trim)),
                            ("v_body_mask", 1024, comb.outputs[0])):
        img = bpy.data.images.new(name, size, size, alpha=False)
        img.colorspace_settings.name = "sRGB" if name != "v_body_mask" else "Non-Color"
        node = nt.nodes.new("ShaderNodeTexImage")
        node.image = img
        nt.nodes.active = node
        nt.links.new(src, em.inputs[0])
        bpy.ops.object.bake(type="EMIT")
        img.filepath_raw = os.path.join(TEX_OUT, name + ".png")
        img.file_format = "PNG"
        img.save()
        results[name] = img
        print("baked", name)
    return results


# --- materials and textures ------------------------------------------------------------

def tex_of(m):
    return next((n.image for n in m.node_tree.nodes if n.type == "TEX_IMAGE"), None) if m and m.use_nodes else None


def textures_and_materials(objs, boots):
    """Write each surface's texture to assets/textures/eco/ and give the glb
    plain materials named after the game's eco_v_* materials."""
    face = bpy.data.objects["Face"]
    body = bpy.data.objects["Body"]
    hair = bpy.data.objects["Hair"]
    plan = []   # (object, material name needle, game name, texture fn)
    face_tex = None
    for i, m in enumerate(face.data.materials):
        img = tex_of(m)
        if "Face_00_SKIN" in m.name:
            face_tex = face_texture(face, img)
            write_png(face_tex, "v_face")
            plan.append((face, i, "eco_v_face"))
        elif "FaceBrow" in m.name:
            px = read_px(img).copy()
            px[..., :3] = to_srgb(np.array((0.07, 0.008, 0.012)))
            px[..., 3] = ss(0.12, 0.45, px[..., 3])
            write_png(px, "v_brow")
            plan.append((face, i, "eco_v_brow"))
        elif "FaceEyeline" in m.name or "FaceEyelash" in m.name:
            px = read_px(img).copy()
            px[..., :3] = to_srgb(to_lin(px[..., :3]) * np.array((0.32, 0.2, 0.24)))
            name = "v_eyeline" if "Eyeline" in m.name else "v_lash"
            write_png(px, name)
            plan.append((face, i, "eco_" + name))
        else:
            name = {"FaceMouth": "v_mouth", "EyeIris": "v_iris", "EyeHighlight": "v_eye_glint",
                    "EyeWhite": "v_eye_white"}[next(k for k in ("FaceMouth", "EyeIris", "EyeHighlight", "EyeWhite") if k in m.name)]
            write_png(read_px(img), name)
            plan.append((face, i, "eco_" + name))
    for i, m in enumerate(hair.data.materials):
        if "HAIR_01" in m.name:
            write_png(dye_hair(read_px(tex_of(m))), "v_hair")
            plan.append((hair, i, "eco_v_hair"))
        elif "HAIR_02" in m.name:
            write_png(dye_hair(read_px(tex_of(m))), "v_hair_fringe")
            plan.append((hair, i, "eco_v_hair_fringe"))
    for i, m in enumerate(body.data.materials):
        if m and "HairBack" in m.name:
            write_png(dye_hair(read_px(tex_of(m))), "v_hair_cap")
            plan.append((body, i, "eco_v_hair_cap"))
    for i, m in enumerate(boots.data.materials):
        if m and "Shoes" in m.name:
            write_png(recolour_boots(read_px(tex_of(m))), "v_boots")
            plan.append((boots, i, "eco_v_boots"))
        elif m and m.name.endswith("Bottoms_01_CLOTH (Instance)"):
            write_png(recolour_boots(read_px(tex_of(m))), "v_boots_cuff")
            plan.append((boots, i, "eco_v_boots_cuff"))
    # the body: underwear filled with skin, then the suit baked on
    skin_m = body.data.materials[next(iter(mat_index(body, "Body_00_SKIN")))]
    px = read_px(tex_of(skin_m)).copy()
    hole = dilate(px[..., :3].mean(-1) < 150 / 255, 5)
    px[..., :3] = fill_holes(px[..., :3], hole)
    clean = write_png(px, "v_body_skin_src")
    bake_body(body, clean)
    os.remove(os.path.join(TEX_OUT, "v_body_skin_src.png"))
    plan.append((body, next(iter(mat_index(body, "bake_body"))), "eco_v_body"))
    for ob, i, name in plan:
        ob.material_slots[i].material = new_mat(name)
    for ob in objs:
        bpy.context.view_layer.objects.active = ob
        for o in bpy.data.objects:
            o.select_set(o == ob)
        bpy.ops.object.material_slot_remove_unused()


# --- animation -------------------------------------------------------------------------

def turn(arm, bone, world_axis, deg):
    """Rotate a pose bone about a world-space axis through its head."""
    pb = arm.pose.bones[bone]
    axis = Vector(world_axis).normalized()
    head = pb.head.copy()
    R = Matrix.Translation(head) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-head)
    pb.matrix = R @ pb.matrix
    bpy.context.view_layer.update()


X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)
# old rig name -> VRoid bone, in the order poses are applied (parents first)
BONE = {
    "hips": "J_Bip_C_Hips", "spine": "J_Bip_C_Spine", "chest": "J_Bip_C_Chest", "neck": "J_Bip_C_Neck",
    "head": "J_Bip_C_Head",
}
for _s in "RL":
    BONE.update({"thigh." + _s: "J_Bip_%s_UpperLeg" % _s, "shin." + _s: "J_Bip_%s_LowerLeg" % _s,
                 "foot." + _s: "J_Bip_%s_Foot" % _s, "upperarm." + _s: "J_Bip_%s_UpperArm" % _s,
                 "forearm." + _s: "J_Bip_%s_LowerArm" % _s, "hand." + _s: "J_Bip_%s_Hand" % _s})
ORDER = ["hips", "spine", "chest", "neck", "head", "thigh.R", "shin.R", "foot.R", "thigh.L", "shin.L", "foot.L",
         "upperarm.R", "forearm.R", "hand.R", "upperarm.L", "forearm.L", "hand.L"]
FINGERS = ("Index", "Middle", "Ring", "Little")


def base_pose():
    """Arms down from the T-pose to a relaxed stance (she faces +Y, her right is +X)."""
    return {"upperarm.R": [(Y, 79)], "upperarm.L": [(Y, -79)],
            "forearm.R": [(X, 14)], "forearm.L": [(X, 14)]}


def add(pose, bone, axis, deg):
    pose.setdefault(bone, []).append((axis, deg))


def key_pose(arm, frame, pose, keyed):
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = Quaternion()
        pb.location = (0, 0, 0)
    bpy.context.view_layer.update()
    off = pose.get("_hips_loc")
    if off:
        hb = arm.pose.bones["J_Bip_C_Hips"]
        hb.matrix = Matrix.Translation(Vector(off)) @ hb.matrix
        bpy.context.view_layer.update()
    for name in ORDER:
        for axis, deg in pose.get(name, []):
            turn(arm, BONE[name], axis, deg)
    # relaxed fingers, curled about each hand's own cross axis
    for s, sign in (("R", 1), ("L", -1)):
        for f in FINGERS:
            for j, a in ((1, 22), (2, 30), (3, 18)):
                b = arm.pose.bones["J_Bip_%s_%s%d" % (s, f, j)]
                ax = (b.matrix @ b.bone.matrix_local.inverted()).to_3x3() @ Vector(Y)
                turn(arm, b.name, ax, sign * a * pose.get("_grip", 1.0))
    for name in keyed:
        pb = arm.pose.bones[name]
        pb.keyframe_insert("rotation_quaternion", frame=frame)
    arm.pose.bones["J_Bip_C_Hips"].keyframe_insert("location", frame=frame)


def hips_loc(ly, lz):
    """The old rig's hips offset (local Y up, local Z back) in world terms."""
    return (0.0, -lz, ly)


def make_actions(arm):
    arm.animation_data_create()
    bpy.context.scene.render.fps = 30
    keyed = [BONE[n] for n in ORDER] + ["J_Bip_%s_%s%d" % (s, f, j) for s in "RL" for f in FINGERS for j in (1, 2, 3)]
    acts = []

    def action(name):
        a = bpy.data.actions.new(name)
        arm.animation_data.action = a
        acts.append(a)
        return a
    # idle: 4 s breathing loop with a slow look around
    action("idle")
    n = 120
    for f in range(0, n + 1, 6):
        t = f / n * 2 * math.pi
        p = base_pose()
        breath = math.sin(t * 2)
        add(p, "chest", X, -1.2 * breath)
        add(p, "spine", Z, 1.5 * math.sin(t))
        add(p, "neck", Z, 4 * math.sin(t))
        add(p, "head", Z, 10 * math.sin(t) + 3 * math.sin(t * 3))
        add(p, "head", X, 2.5 * math.sin(t * 2 + 1))
        add(p, "upperarm.R", X, 1.5 * math.sin(t * 2 + 0.5))
        add(p, "upperarm.L", X, -1.5 * math.sin(t * 2 + 0.5))
        add(p, "hips", Y, 1.2 * math.sin(t))
        add(p, "thigh.R", Y, -1.2 * math.sin(t))
        add(p, "thigh.L", Y, -1.2 * math.sin(t))
        p["_hips_loc"] = hips_loc(0.0025 * breath, 0)
        key_pose(arm, f, p, keyed)
    # walk: one stride cycle (two steps) in 32 frames, about 1.3 m
    action("walk")
    n = 32
    for f in range(0, n + 1, 2):
        t = f / n * 2 * math.pi
        p = base_pose()
        sw = math.sin(t)
        add(p, "thigh.R", X, 26 * sw)
        add(p, "thigh.L", X, -26 * sw)
        add(p, "shin.R", X, -38 * max(0.0, math.sin(t - 1.2)) - 6)
        add(p, "shin.L", X, -38 * max(0.0, math.sin(t + math.pi - 1.2)) - 6)
        add(p, "foot.R", X, 10 * math.cos(t))
        add(p, "foot.L", X, -10 * math.cos(t))
        add(p, "upperarm.R", X, -20 * sw)
        add(p, "upperarm.L", X, 20 * sw)
        add(p, "forearm.R", X, 8 * max(0.0, -sw))
        add(p, "forearm.L", X, 8 * max(0.0, sw))
        add(p, "hips", Z, 6 * sw)
        add(p, "chest", Z, -8 * sw)
        add(p, "head", Z, 2 * sw)
        add(p, "spine", X, 3)
        p["_hips_loc"] = hips_loc(-0.018 * abs(math.cos(t)), 0)
        key_pose(arm, f, p, keyed)
    # run: one stride (two steps) in 22 frames, about 4.4 m: authored at 6 m/s
    action("run")
    n = 22
    for f in range(0, n + 1):
        t = f / n * 2 * math.pi
        p = base_pose()
        sw = math.sin(t)
        add(p, "thigh.R", X, 44 * sw + 6)
        add(p, "thigh.L", X, -44 * sw + 6)
        add(p, "shin.R", X, -95 * max(0.0, math.sin(t - 1.4)) - 14)
        add(p, "shin.L", X, -95 * max(0.0, math.sin(t + math.pi - 1.4)) - 14)
        add(p, "foot.R", X, 16 * math.cos(t))
        add(p, "foot.L", X, -16 * math.cos(t))
        add(p, "upperarm.R", X, -34 * sw)
        add(p, "upperarm.L", X, 34 * sw)
        add(p, "forearm.R", X, 50 + 12 * max(0.0, -sw))
        add(p, "forearm.L", X, 50 + 12 * max(0.0, sw))
        add(p, "spine", X, -9)
        add(p, "head", X, 7)
        add(p, "hips", Z, 9 * sw)
        add(p, "chest", Z, -13 * sw)
        add(p, "head", Z, 4 * sw)
        p["_hips_loc"] = hips_loc(-0.035 + 0.03 * abs(math.sin(t)), 0)
        p["_grip"] = 1.8
        key_pose(arm, f, p, keyed)
    # poses held while airborne, crouched and sliding (gentle motion so they loop)
    action("fall")
    n = 30
    for f in range(0, n + 1, 5):
        t = f / n * 2 * math.pi
        p = base_pose()
        add(p, "thigh.R", X, 38 + 4 * math.sin(t))
        add(p, "shin.R", X, -62)
        add(p, "thigh.L", X, -8 - 4 * math.sin(t))
        add(p, "shin.L", X, -38)
        add(p, "foot.R", X, -10)
        add(p, "foot.L", X, -20)
        add(p, "upperarm.R", Y, -38 + 5 * math.sin(t))
        add(p, "upperarm.L", Y, 38 - 5 * math.sin(t))
        add(p, "upperarm.R", X, 18)
        add(p, "upperarm.L", X, -10)
        add(p, "forearm.R", X, 16)
        add(p, "forearm.L", X, 16)
        add(p, "spine", X, -6)
        add(p, "head", X, 6)
        key_pose(arm, f, p, keyed)
    action("crouch")
    n = 60
    for f in range(0, n + 1, 10):
        t = f / n * 2 * math.pi
        breath = math.sin(t)
        p = base_pose()
        for sd, sgn in (("R", 1), ("L", -1)):
            add(p, "thigh." + sd, X, 74)
            add(p, "thigh." + sd, Y, -9 * sgn)
            add(p, "shin." + sd, X, -112)
            add(p, "foot." + sd, X, 36)
        add(p, "spine", X, -26 - 1.5 * breath)
        add(p, "chest", X, -6)
        add(p, "neck", X, 14)
        add(p, "head", X, 16)
        add(p, "upperarm.R", X, 34)
        add(p, "upperarm.L", X, 26)
        add(p, "forearm.R", X, 34)
        add(p, "forearm.L", X, 40)
        p["_hips_loc"] = hips_loc(-0.4, 0.13)
        key_pose(arm, f, p, keyed)
    action("slide")
    n = 30
    for f in range(0, n + 1, 5):
        t = f / n * 2 * math.pi
        p = base_pose()
        add(p, "thigh.R", X, 62)
        add(p, "shin.R", X, -18)
        add(p, "foot.R", X, -12)
        add(p, "thigh.L", X, 30)
        add(p, "thigh.L", Y, 18)
        add(p, "shin.L", X, -118)
        add(p, "foot.L", X, 20)
        add(p, "spine", X, 18 + 1.5 * math.sin(t))
        add(p, "chest", X, 6)
        add(p, "neck", X, -10)
        add(p, "head", X, -14)
        add(p, "upperarm.L", Y, 52)
        add(p, "upperarm.L", X, -16)
        add(p, "forearm.L", X, 6)
        add(p, "upperarm.R", X, 40)
        add(p, "upperarm.R", Y, -14)
        add(p, "forearm.R", X, 36)
        p["_hips_loc"] = hips_loc(-0.5, 0.05)
        key_pose(arm, f, p, keyed)
    for a in acts:
        for fc in a.fcurves:
            for kp in fc.keyframe_points:
                kp.interpolation = "BEZIER"
    arm.animation_data.action = bpy.data.actions["idle"]


# --- preview ---------------------------------------------------------------------------

def preview(arm):
    """Workbench stills of a few animation frames, textures on."""
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "TEXTURE"
    sc.render.resolution_x, sc.render.resolution_y = 700, 1000
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.location = (1.6, 4.0, 1.0)
    cam.rotation_euler = (Vector((0, 0, 0.88)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 45
    for act, f in (("idle", 0), ("walk", 8), ("run", 6), ("fall", 0), ("crouch", 0), ("slide", 0)):
        arm.animation_data.action = bpy.data.actions[act]
        sc.frame_set(f)
        sc.render.filepath = "%s_%s.png" % (PREVIEW, act)
        bpy.ops.render.render(write_still=True)
    arm.animation_data.action = bpy.data.actions["idle"]
    sc.frame_set(0)


def main():
    os.makedirs(TEX_OUT, exist_ok=True)
    arm = setup_scene()
    remove_fox_parts()
    short_hair()
    fierce_face()
    boots = strip_clothes()
    gog = goggles(arm)
    objs = [bpy.data.objects[n] for n in ("Body", "Face", "Hair")] + [boots, gog]
    textures_and_materials(objs, boots)
    glute_bones(arm)
    prune_bones(arm)
    proportions(arm, objs)
    face_forward_and_scale(arm, objs)
    face = bpy.data.objects["Face"]
    for k, v in EXPRESSION.items():   # preview only; the game sets these on import
        face.data.shape_keys.key_blocks[k].value = v
    make_actions(arm)
    if PREVIEW:
        preview(arm)
    for k in EXPRESSION:
        face.data.shape_keys.key_blocks[k].value = 0.0
    if "rest" in bpy.data.objects["Body"].data.attributes:
        bpy.data.objects["Body"].data.attributes.remove(bpy.data.objects["Body"].data.attributes["rest"])
    for o in bpy.data.objects:
        o.select_set(o == arm or o in objs)
    bpy.ops.export_scene.gltf(filepath=GLB_OUT, export_format="GLB", use_selection=True,
                              export_animations=True, export_animation_mode="ACTIONS", export_skins=True,
                              export_morph=True, export_materials="EXPORT", export_image_format="NONE",
                              export_yup=True, export_apply=False)
    print("exported", GLB_OUT)


main()
