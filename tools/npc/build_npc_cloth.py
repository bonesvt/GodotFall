"""Real cloth for the hub NPCs: the clothes painted on their body, cut out of
it as meshes of their own (the real-cloth pass of the strinova-look model
sheets, brought into the game). Each garment follows the edge of its paint,
so prints, stripes and rips stay where they were painted; then it is lifted
off the skin and given real thickness with a heavier rolled hem, hung (a tee
falls straight from the bust instead of clinging under it) and folded (drape
folds, bunching behind the knee and over the boots, knit ribs). Run through
Blender 4:

    blender -b --factory-startup -P tools/npc/build_npc_cloth.py -- <repo root> <who>

Reads assets/models/npc/<who>.glb (tools/npc/build_npc.py) and its body
texture, and writes:
- assets/models/npc/<who>_cloth.glb: their skeleton and the garments, named
  Outfit_<outfit>_<garment> so they show only in the outfit they were painted
  for (hub_npc.gd _dress_meshes()), in the body's rest space and skinned with
  the body's own weights. hub_npc.gd puts them on the NPC's own skeleton.
- assets/textures/npc/<who>/cloth.png: the body texture with the cloth's
  colour carried out over the skin next to it, so a hem's rolled edge (whose
  UVs sit right on the paint line) never picks up skin.
"""
import heapq
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, kdtree

argv = sys.argv[sys.argv.index("--") + 1:]
ROOT, WHO = argv[0], argv[1]
GLB_IN = os.path.join(ROOT, "assets", "models", "npc", WHO + ".glb")
GLB_OUT = os.path.join(ROOT, "assets", "models", "npc", WHO + "_cloth.glb")
TEX = os.path.join(ROOT, "assets", "textures", "npc", WHO)
S = 2048

# who: the outfit their body texture is (hub_npc.gd OUTFITS[who][0]) and their
# garments: the texture channel each is cut from (garment_masks()), how far it
# sits off the skin and how thick it is (m), and how it hangs and folds.
CLOTH = {
    "ophelia": {"outfit": "tee", "garments": [
        {"name": "Tee", "ch": 0, "offset": 0.0026, "thick": 0.0014, "drape": 0.85, "folds": 0.003, "sleeve": 0.006},
        {"name": "Jeans", "ch": 1, "offset": 0.002, "thick": 0.0018, "folds": 0.0016, "knee": 0.0018, "ankle": 0.0025,
         "waist": True},
        {"name": "Warmers", "ch": 2, "offset": 0.0016, "thick": 0.0026, "ribs": 0.0009, "slouch": 0.0022},
    ]},
}


# ---------------------------------------------------------------- images (numpy, rows top-down)
def box(a, k):
    """Mean over a (2k+1)^2 window, edges clamped."""
    a = a.astype(np.float32)
    for ax in (0, 1):
        n = a.shape[ax]
        p = np.pad(a, [(k + 1, k) if i == ax else (0, 0) for i in range(a.ndim)], mode="edge")
        c = np.cumsum(p, axis=ax, dtype=np.float64)
        a = ((np.take(c, np.arange(2 * k + 1, 2 * k + 1 + n), axis=ax) - np.take(c, np.arange(n), axis=ax))
             / (2 * k + 1)).astype(np.float32)
    return a


def blur(a, r):
    """About a Gaussian of radius r: three box passes."""
    k = max(1, int(r))
    for _ in range(3):
        a = box(a, k)
    return a


def grow(m, px):
    return box(m, px) > 1e-4


def shrink(m, px):
    return box(m, px) > 1 - 1e-4


def down(a):
    h, w = a.shape[:2]
    return a.reshape(h // 2, 2, w // 2, 2, *a.shape[2:]).astype(np.float32).mean((1, 3))


def up(a, n):
    """Bilinear resize of a square image to n x n."""
    for ax in (0, 1):
        h = a.shape[ax]
        x = np.clip((np.arange(n) + 0.5) * h / n - 0.5, 0, h - 1)
        i0 = np.floor(x).astype(int); i1 = np.minimum(i0 + 1, h - 1); f = (x - i0).astype(np.float32)
        sh = [1] * a.ndim; sh[ax] = n; f = f.reshape(sh)
        a = np.take(a, i0, axis=ax) * (1 - f) + np.take(a, i1, axis=ax) * f
    return a


def fill_from(img, keep, rounds=40):
    """Push colours from `keep` pixels into the rest (simple push-pull inpaint)."""
    out = img.copy(); known = keep.copy()
    for _ in range(rounds):
        if known.all():
            break
        acc = np.zeros_like(out); n = np.zeros(known.shape, np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
            k = np.roll(np.roll(known, dy, 0), dx, 1)
            c = np.roll(np.roll(out, dy, 0), dx, 1)
            acc += c * k[..., None]; n += k
        new = (~known) & (n > 0)
        out[new] = acc[new] / n[new][:, None]
        known = known | new
    return out


def load_rgb(path):
    im = bpy.data.images.load(path, check_existing=False)
    im.colorspace_settings.name = "Non-Color"
    w, h = im.size
    px = np.empty(w * h * 4, np.float32); im.pixels.foreach_get(px)
    a = px.reshape(h, w, 4)[::-1, :, :3].copy()
    bpy.data.images.remove(im)
    if w != S:
        a = up(a, S)
    return a


def save_rgb(a, path):
    h, w = a.shape[:2]
    rgba = np.concatenate([np.clip(a, 0, 1), np.ones((h, w, 1), np.float32)], -1)[::-1]
    im = bpy.data.images.new(os.path.basename(path), w, h, alpha=False)
    im.pixels.foreach_set(rgba.astype(np.float32).ravel())
    im.filepath_raw = path; im.file_format = "PNG"
    im.save()
    bpy.data.images.remove(im)


def coverage(me, mat_i):
    """The body's UV islands, rasterised."""
    me.calc_loop_triangles()
    uv = me.uv_layers.active.data
    cov = np.zeros((S, S), bool)
    for t in me.loop_triangles:
        if t.material_index != mat_i:
            continue
        P = np.array([uv[l].uv[:] for l in t.loops]) * S
        P[:, 1] = S - P[:, 1]
        x0, y0 = np.maximum(np.floor(P.min(0)).astype(int), 0)
        x1, y1 = np.minimum(np.ceil(P.max(0)).astype(int), S - 1)
        if x1 < x0 or y1 < y0:
            continue
        X, Y = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        (ax, ay), (bx, by), (cx, cy) = P
        d = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(d) < 1e-12:
            continue
        l0 = ((by - cy) * (X - cx) + (cx - bx) * (Y - cy)) / d
        l1 = ((cy - ay) * (X - cx) + (ax - cx) * (Y - cy)) / d
        cov[y0:y1 + 1, x0:x1 + 1] |= (l0 >= -1e-3) & (l1 >= -1e-3) & (1 - l0 - l1 >= -1e-3)
    return cov


def garment_masks(a, cov):
    """Where each garment is painted (R top, G trousers, B arm warmers), cleaned so its cut runs
    smooth, and the garments' own albedo (cloth carried out over the skin beside it)."""
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    lum = 0.3 * r + 0.59 * g + 0.11 * b
    skin = cov & (r > 0.55) & (r - b > 0.03) & (lum > 0.5) & (r - g < 0.35)
    gold = cov & (r > 0.45) & (g > 0.33) & (b < 0.4) & (r - b > 0.22) & (r - g < 0.3)
    skin &= ~gold
    cloth = cov & ~skin & ~gold
    Y = np.arange(S)[:, None] / S; Xn = np.arange(S)[None, :] / S
    upper = Y < 0.5; arms = (Xn < 0.24) | (Xn > 0.76)
    gm = np.zeros((S, S, 3), bool)
    holes = np.zeros((S, S, 3), bool)   # painted holes that stay open (rips)
    if WHO == "ophelia":
        knit = cloth & upper & arms & (Y > 0.27)
        gm[..., 0] = cloth & upper & ~knit
        rip = cov & (lum > 0.26) & (Y > 0.56)
        gm[..., 1] = cloth & ~upper & ~rip
        holes[..., 1] = rip
        gm[..., 2] = knit
    out = np.zeros((S, S, 3), np.float32)
    for c in range(3):
        m = gm[..., c]
        if not m.any():
            continue
        m = m | ((blur(m, 10) > 0.02) & ~cov)     # past the island edges, so a seam never opens
        m = blur(blur(m, 5) > 0.12, 5) > 0.88      # close small notches
        if holes[..., c].any():                    # but not the rips, however small
            m &= ~(blur(blur(holes[..., c], 1.5) > 0.85, 1.5) > 0.15)
        m = blur(blur(m, 1.5) > 0.85, 1.5) > 0.15  # drop specks
        out[..., c] = blur(m, 3.0)
    known = cloth | gold
    ks = shrink(down(known) > 0.98, 3)
    sc = fill_from(down(a), ks, 120)
    albedo = np.where(shrink(known, 1)[..., None], a, up(sc, S))
    return out, albedo


def sample_px(px, uv):
    """Bilinear samples of an image (rows top-down) at uvs (v up)."""
    h, w = px.shape[:2]
    x = np.clip(uv[:, 0] * w - 0.5, 0, w - 1.001); y = np.clip((1 - uv[:, 1]) * h - 0.5, 0, h - 1.001)
    x0 = x.astype(int); y0 = y.astype(int); fx = (x - x0)[:, None]; fy = (y - y0)[:, None]
    p, q = px[y0, x0], px[y0, x0 + 1]; s, t = px[y0 + 1, x0], px[y0 + 1, x0 + 1]
    return (p * (1 - fx) + q * fx) * (1 - fy) + (s * (1 - fx) + t * fx) * fy


# ---------------------------------------------------------------- noise
def _hash3(ix, iy, iz):
    h = (ix * 374761393 + iy * 668265263 + iz * 1274126177) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return (h & 0xFFFF) / 65535.0


def vnoise(p):
    """Value noise 0..1 at points p (N,3), lattice spacing 1."""
    f = np.floor(p); t = p - f; i = f.astype(np.int64)
    t = t * t * (3 - 2 * t)
    out = np.zeros(len(p))
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (t[:, 0] if dx else 1 - t[:, 0]) * (t[:, 1] if dy else 1 - t[:, 1]) * (t[:, 2] if dz else 1 - t[:, 2])
                out += w * _hash3(i[:, 0] + dx, i[:, 1] + dy, i[:, 2] + dz)
    return out


def fbm(p, octaves=3):
    a, s, tot = 1.0, 1.0, 0.0
    out = np.zeros(len(p))
    for _ in range(octaves):
        out += a * vnoise(p * s + 17.1 * s); tot += a; a *= 0.5; s *= 2.0
    return out / tot


def ridge(n):
    return 1.0 - np.abs(2.0 * n - 1.0)


def smooth01(x, a, b):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


# ---------------------------------------------------------------- cutting
def cut_garment(body, ch, gpx, field=None):
    """The body (rest pose, world space) cut along the 0.5 line of garment channel `ch`; it keeps
    the body's uvs and bone weights. `field(P, m, armw)` may reshape the per-vertex mask first."""
    bm = bmesh.new(); bm.from_mesh(body.data)
    bmesh.ops.transform(bm, matrix=body.matrix_world, verts=bm.verts)
    bm.verts.ensure_lookup_table()
    uvl = bm.loops.layers.uv.active
    vi, uvs = [], []
    for f in bm.faces:
        for l in f.loops:
            vi.append(l.vert.index); uvs.append(l[uvl].uv[:])
    vals = sample_px(gpx, np.array(uvs))[:, ch]
    m = np.zeros(len(bm.verts)); np.maximum.at(m, np.array(vi), vals)
    if field is not None:
        P = np.array([v.co[:] for v in bm.verts])
        dl = bm.verts.layers.deform.active
        armi = {i for i, g in enumerate(body.vertex_groups)
                if any(k in g.name for k in ("Arm", "Hand", "Thumb", "Index", "Middle", "Ring", "Little"))}
        armw = np.array([sum(wt for gi, wt in v[dl].items() if gi in armi) if dl else 0.0 for v in bm.verts])
        m = field(P, m, armw)
    lay = bm.verts.layers.float.new("m")
    for v in bm.verts:
        v[lay] = float(m[v.index])
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    # a crossing right next to a vertex would leave a sliver (and slivers spike under the
    # thickness): snap that vertex onto the line instead
    for _ in range(2):
        snap = set()
        for e in bm.edges:
            v0, v1 = e.verts; a, b = v0[lay], v1[lay]
            if (a - 0.5) * (b - 0.5) < 0:
                t = (0.5 - a) / (b - a)
                if t < 0.15:
                    snap.add(v0)
                elif t > 0.85:
                    snap.add(v1)
        for v in snap:
            v[lay] = 0.5
    # split every edge the 0.5 line crosses, then join the splits: the cut follows the paint
    for e in [e for e in bm.edges if (e.verts[0][lay] - 0.5) * (e.verts[1][lay] - 0.5) < 0]:
        v0, v1 = e.verts; a, b = v0[lay], v1[lay]
        _, nv = bmesh.utils.edge_split(e, v0, (0.5 - a) / (b - a))
        nv[lay] = 0.5
    for f in list(bm.faces):
        if not f.is_valid:
            continue
        mids = [v for v in f.verts if abs(v[lay] - 0.5) < 1e-6]
        if len(mids) == 2 and not any(e for e in mids[0].link_edges if e.other_vert(mids[0]) is mids[1]):
            try:
                bmesh.ops.connect_verts(bm, verts=mids)
            except Exception:
                pass
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if min(v[lay] for v in f.verts) < 0.5 - 1e-5], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    # drop specks (a choker band, a strap line): they stay painted on the skin
    bm.verts.ensure_lookup_table()
    seen = set(); comps = []
    for v in bm.verts:
        if v.index in seen:
            continue
        stack = [v]; comp = []; seen.add(v.index)
        while stack:
            x = stack.pop(); comp.append(x)
            for e in x.link_edges:
                o = e.other_vert(x)
                if o.index not in seen:
                    seen.add(o.index); stack.append(o)
        comps.append(comp)
    n = len(bm.verts)
    drop = [v for c in comps if len(c) < 0.03 * n for v in c]
    if drop:
        bmesh.ops.delete(bm, geom=drop, context="VERTS")
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
    bmesh.ops.dissolve_degenerate(bm, dist=2e-4, edges=bm.edges[:])
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    return bm


def waist_field(bm0, centre, fwd, nh=3, zone=0.09):
    """Fit the trousers' top edge (its painted line, stepped where uv islands meet) with a smooth
    curve round the hips, z(theta) as a short Fourier series, and return a mask field that cuts there."""
    bm0.verts.ensure_lookup_table()
    pts = np.array([v.co[:] for v in bm0.verts if v.is_boundary and v.co.z > centre[2] - 0.12])
    e1 = np.array([fwd[0], fwd[1]]); e1 /= np.linalg.norm(e1); e2 = np.array([-e1[1], e1[0]])

    def theta(P):
        d = P[:, :2] - centre[:2]
        return np.arctan2(d @ e2, d @ e1), np.linalg.norm(d, axis=1)
    th, _ = theta(pts)
    nb = 48; bi = ((th + np.pi) / (2 * np.pi) * nb).astype(int) % nb
    zt, at = [], []
    for k in range(nb):
        sel = bi == k
        if sel.any():
            zt.append(np.max(pts[sel, 2])); at.append(-np.pi + (k + 0.5) * 2 * np.pi / nb)
    at = np.array(at); zt = np.array(zt)

    def basis(t):
        return np.stack([np.ones_like(t)] + [f(j * t) for j in range(1, nh + 1) for f in (np.cos, np.sin)], 1)
    coef, *_ = np.linalg.lstsq(basis(at), zt, rcond=None)
    # lift the curve over the highest painted point, so no painted cloth is left showing above it
    coef[0] += float(np.max(zt - basis(at) @ coef)) + 0.006

    def field(P, m, armw):
        t, r = theta(P)
        z_w = basis(t) @ coef
        s_ = np.clip(0.5 + (z_w - P[:, 2]) * 60.0, 0, 1)
        inzone = (P[:, 2] > z_w - zone) & (r < 0.3) & (armw < 0.3)
        return np.where(inzone, s_, m)
    return field


def boundary_dist(bm):
    bm.verts.ensure_lookup_table()
    D = np.full(len(bm.verts), 1e9)
    pq = []
    for v in bm.verts:
        if v.is_boundary:
            D[v.index] = 0.0; pq.append((0.0, v.index))
    heapq.heapify(pq)
    while pq:
        d, i = heapq.heappop(pq)
        if d > D[i] or d > 0.2:
            continue
        v = bm.verts[i]
        for e in v.link_edges:
            o = e.other_vert(v); nd = d + e.calc_length()
            if nd < D[o.index]:
                D[o.index] = nd; heapq.heappush(pq, (nd, o.index))
    return D


# ---------------------------------------------------------------- limb frames
def chain_coords(P, pts, ref):
    """Closest point on a bone chain: s (0..1 by length), the radial vector, its angle round the chain."""
    segs = [(pts[i], pts[i + 1]) for i in range(len(pts) - 1)]
    lens = np.array([np.linalg.norm(b - a) for a, b in segs]); L = lens.sum(); acc = np.concatenate([[0], np.cumsum(lens)])
    best_d = np.full(len(P), 1e9); Sx = np.zeros(len(P)); RAD = np.zeros_like(P); TAN = np.zeros_like(P)
    for k, (a, b) in enumerate(segs):
        ab = b - a; t = np.clip(((P - a) @ ab) / (ab @ ab), 0, 1)
        q = a + t[:, None] * ab; d = np.linalg.norm(P - q, axis=1)
        sel = d < best_d
        best_d[sel] = d[sel]; Sx[sel] = (acc[k] + t[sel] * lens[k]) / L; RAD[sel] = (P - q)[sel]
        TAN[sel] = ab / lens[k]
    e1 = ref[None, :] - TAN * (TAN @ ref)[:, None]; e1 /= np.linalg.norm(e1, axis=1)[:, None] + 1e-9
    e2 = np.cross(TAN, e1)
    th = np.arctan2((RAD * e2).sum(1), (RAD * e1).sum(1))
    return Sx, RAD, th, best_d, L


def hang_profile(Sx, th, r, nb_s=60, nb_t=48, decay=0.05, L=1.0, start=0.0):
    """Cloth hangs from the widest point above: per angle, the running max of the body's radius
    down the limb (or torso), narrowing by `decay` metres per metre."""
    si = np.clip((Sx * nb_s).astype(int), 0, nb_s - 1); ti = ((th + np.pi) / (2 * np.pi) * nb_t).astype(int) % nb_t
    env = np.zeros((nb_t, nb_s)); np.maximum.at(env, (ti, si), r)
    for k in range(nb_t):   # fill empty bins from their neighbours along the limb
        row = env[k]; good = row > 0
        if good.any():
            env[k] = np.interp(np.arange(nb_s), np.nonzero(good)[0], row[good])
    for k in range(3):
        env = (np.roll(env, 1, 0) + 2 * env + np.roll(env, -1, 0)) / 4
    out = env.copy()
    for i in range(max(int(start * nb_s), 1), nb_s):
        out[:, i] = np.maximum(env[:, i], out[:, i - 1] - decay * L / nb_s)
    return out, si, ti


def smooth_field(bm, F, iters=4):
    """Average a per-vertex field over the mesh edges (keeps the drape free of bin steps)."""
    E = np.array([(e.verts[0].index, e.verts[1].index) for e in bm.edges])
    cnt = np.zeros(len(F)); np.add.at(cnt, E[:, 0], 1); np.add.at(cnt, E[:, 1], 1)
    cnt = np.maximum(cnt, 1)
    for _ in range(iters):
        acc = np.zeros_like(F); np.add.at(acc, E[:, 0], F[E[:, 1]]); np.add.at(acc, E[:, 1], F[E[:, 0]])
        F = 0.5 * F + 0.5 * acc / (cnt[:, None] if F.ndim == 2 else cnt)
    return F


def gsum(W, groups, names):
    cols = [i for i, n in enumerate(groups) if any(k in n for k in names)]
    return W[:, cols].sum(1) if cols else np.zeros(len(W))


# ---------------------------------------------------------------- garments
def shape_garment(g, bm, body, CB, WB, groups, B, fwd):
    """Hang, drape and fold one cut garment, in place. CB/WB: the body's points and bone weights."""
    bm.normal_update(); bm.verts.ensure_lookup_table()
    P = np.array([v.co[:] for v in bm.verts]); Nn = np.array([v.normal[:] for v in bm.verts])
    D = boundary_dist(bm)
    dl = bm.verts.layers.deform.active
    W = np.zeros((len(P), len(groups)), np.float32)
    for v in bm.verts:
        for gi, wt in v[dl].items():
            if gi < len(groups):
                W[v.index, gi] = wt
    legL = gsum(W, groups, ("L_UpperLeg", "L_LowerLeg", "L_Foot")); legR = gsum(W, groups, ("R_UpperLeg", "R_LowerLeg", "R_Foot"))
    armL = gsum(W, groups, ("L_UpperArm", "L_LowerArm", "L_Hand")); armR = gsum(W, groups, ("R_UpperArm", "R_LowerArm", "R_Hand"))
    disp = np.zeros(len(P))          # along the normal
    radial = np.zeros_like(P)        # drape, in the torso's frame
    ref = fwd / np.linalg.norm(fwd)
    if g.get("knee") or g.get("ankle") or g.get("folds") and not g.get("drape"):
        for side, wleg in (("L", legL), ("R", legR)):
            sel = wleg > 0.5
            if not sel.any():
                continue
            chain = [B[f"{side}_UpperLeg"], B[f"{side}_LowerLeg"], B[f"{side}_Foot"]]
            Sx, RAD, th, r, L = chain_coords(P[sel], chain, ref)
            q3 = np.stack([th * 2.0, Sx * 4.0, np.full(len(Sx), 5.0 if side == "L" else 11.0)], 1)
            disp[sel] += g.get("folds", 0) * ridge(fbm(q3, 3)) ** 3
            if g.get("knee"):
                # bunching behind the knee
                back = np.clip(-(RAD / (r[:, None] + 1e-9) * ref).sum(1), 0, 1)
                disp[sel] += g["knee"] * (0.5 + 0.5 * np.sin(Sx * L / 0.018 * 2 * np.pi + th)) \
                    * smooth01(Sx, 0.4, 0.47) * (1 - smooth01(Sx, 0.55, 0.62)) * back
            if g.get("ankle"):
                # stacked folds where the hem meets the boot
                disp[sel] += g["ankle"] * (0.5 + 0.5 * np.sin(Sx * L / 0.024 * 2 * np.pi + 1.7 * np.sin(th * 2))) \
                    * smooth01(Sx, 0.82, 0.95)
    if g.get("drape"):
        # the tee hangs straight down from the bust and shoulder blades
        torso = (1 - np.clip(armL + armR + legL + legR, 0, 1)) > 0.5
        ax = np.array([B[n] for n in ("C_Hips", "C_Spine", "C_Chest", "C_UpperChest", "C_Neck")])
        ax = ax[np.argsort(ax[:, 2])]
        z_top = B["L_UpperArm"][2] - 0.07

        def frame(Q):
            axx = np.interp(Q[:, 2], ax[:, 2], ax[:, 0]); axy = np.interp(Q[:, 2], ax[:, 2], ax[:, 1])
            d = Q[:, :2] - np.stack([axx, axy], 1)
            return np.arctan2(d[:, 1], d[:, 0]), np.linalg.norm(d, axis=1), d
        CBt = CB[gsum(WB, groups, ("Arm", "Hand", "Leg", "Foot", "Shoulder")) < 0.3]
        z0 = P[torso, 2].min() - 0.02
        zsel = (CBt[:, 2] > z0) & (CBt[:, 2] < z_top)
        thb, rb, _ = frame(CBt[zsel])
        nb_z = 60; zz = (CBt[zsel][:, 2] - z0) / (z_top - z0)
        # bins run top (0) to bottom (1) so the running max carries downward
        env, _, _ = hang_profile(1 - zz, thb, rb, nb_s=nb_z, nb_t=72, decay=0.15, L=z_top - z0)
        Pt = P[torso]
        th, r, d2 = frame(Pt)
        zz_t = np.clip((Pt[:, 2] - z0) / (z_top - z0), 0, 1)
        si = np.clip(((1 - zz_t) * nb_z).astype(int), 0, nb_z - 1); ti = ((th + np.pi) / (2 * np.pi) * 72).astype(int) % 72
        extra = np.maximum(env[ti, si] - r, 0) * g["drape"] * (Pt[:, 2] < z_top)
        rn = np.concatenate([d2 / (r[:, None] + 1e-9), np.zeros((len(r), 1))], 1)
        radial[torso] += rn * extra[:, None]
        loose = np.clip(extra / 0.015, 0, 1)
        q3 = np.stack([th * 3.0, Pt[:, 2] * 3.0, np.full(len(th), 2.0)], 1)
        disp[torso] += g.get("folds", 0) * ridge(fbm(q3, 3)) ** 2 * loose
        # a few soft creases across the waist at the sides
        side = np.abs(np.sin(th - math.atan2(ref[1], ref[0])))
        disp[torso] += 0.0012 * (0.5 + 0.5 * np.sin(Pt[:, 2] / 0.022 * 2 * np.pi + fbm(q3 * 2, 2) * 4)) * side * (1 - loose)
    if g.get("sleeve"):
        arm = np.clip(armL + armR, 0, 1) > 0.5
        disp[arm] += g["sleeve"] * np.clip(1 - D[arm] / 0.035, 0, 1) ** 1.5 + 0.0015
    if g.get("ribs"):
        for side, wa in (("L", armL), ("R", armR)):
            sel = wa > 0.5
            if not sel.any():
                continue
            Sx, RAD, th, r, L = chain_coords(P[sel], [B[f"{side}_LowerArm"], B[f"{side}_Hand"]], ref)
            disp[sel] += g["ribs"] * np.abs(np.sin(th * 26))
            q3 = np.stack([th * 1.5, Sx * 6.0, np.full(len(Sx), 7.0)], 1)
            disp[sel] += g["slouch"] * ridge(fbm(q3, 2)) ** 2
    # lift off the skin; folds fade out at the hem so the edge stays clean
    hem = np.clip(D / 0.012, 0, 1)
    radial = smooth_field(bm, radial, 6)
    rl = np.linalg.norm(radial, axis=1)
    radial *= (np.minimum(rl, 0.06) / (rl + 1e-9))[:, None]
    newP = P + radial + Nn * (g["offset"] + disp * (0.4 + 0.6 * hem))[:, None]
    for v, c in zip(bm.verts, newP):
        v.co = c
    print("garment", g["name"], "drape max %.1f mm, folds max %.1f mm" % (rl.max() * 1000, np.abs(disp).max() * 1000))
    return D


def apply_mod(o, mod):
    bpy.context.view_layer.objects.active = o
    with bpy.context.temp_override(object=o, active_object=o):
        bpy.ops.object.modifier_apply(modifier=mod.name)


def base_name(s):
    return s.rsplit(".", 1)[0] if s[-4:-3] == "." and s[-3:].isdigit() else s


def main():
    spec = CLOTH[WHO]
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.import_scene.gltf(filepath=GLB_IN)
    objs = list(bpy.context.scene.objects)
    arm = next(o for o in objs if o.type == "ARMATURE")
    arm.data.pose_position = "REST"

    def mat_i(o, part):
        return next((i for i, m in enumerate(o.data.materials) if m and base_name(m.name) == f"npc_{WHO}_{part}"), -1)
    body = next(o for o in objs if o.type == "MESH" and mat_i(o, "body") >= 0)
    face = next(o for o in objs if o.type == "MESH" and mat_i(o, "face") >= 0)
    bi = mat_i(body, "body")

    # textures: where each garment is painted, and its albedo
    a = load_rgb(os.path.join(TEX, "body.png"))
    gpx, albedo = garment_masks(a, coverage(body.data, bi))
    save_rgb(albedo, os.path.join(TEX, "cloth.png"))

    # the body alone (no head, no shape keys), its faces split once so the cut runs finer
    src = body.copy(); src.data = body.data.copy(); bpy.context.scene.collection.objects.link(src)
    src.modifiers.clear(); src.parent = None; src.matrix_world = body.matrix_world.copy()
    if src.data.shape_keys:
        src.shape_key_clear()
    bm = bmesh.new(); bm.from_mesh(src.data)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index != bi], context="FACES")
    bm.to_mesh(src.data); bm.free()
    sd = src.modifiers.new("split", "SUBSURF"); sd.subdivision_type = "SIMPLE"; sd.levels = 1
    apply_mod(src, sd)
    groups = [vg.name for vg in src.vertex_groups]
    CB = np.array([src.matrix_world @ v.co for v in src.data.vertices])
    WB = np.zeros((len(CB), len(groups)), np.float32)
    for v in src.data.vertices:
        for ge in v.groups:
            WB[v.index, ge.group] = ge.weight

    # where the bones are (rest pose, world) and which way they face
    B = {}
    for bn in arm.data.bones:
        if bn.name.startswith("J_Bip_"):
            B[bn.name[len("J_Bip_"):]] = np.array(arm.matrix_world @ bn.head_local)
    fi = mat_i(face, "face")
    fn = np.array([face.matrix_world.to_3x3() @ v.normal for p in face.data.polygons if p.material_index == fi
                   for v in (face.data.vertices[k] for k in p.vertices)])
    fwd = fn.mean(0); fwd[2] = 0; fwd /= np.linalg.norm(fwd)

    mat = bpy.data.materials.new(f"npc_{WHO}_cloth")
    made = []
    for g in spec["garments"]:
        if g.get("waist"):
            bm0 = cut_garment(src, g["ch"], gpx)
            field = waist_field(bm0, B["C_Hips"], fwd); bm0.free()
            bm = cut_garment(src, g["ch"], gpx, field)
        else:
            bm = cut_garment(src, g["ch"], gpx)
        D = shape_garment(g, bm, src, CB, WB, groups, B, fwd)
        # back into the body's own space (its rest space in the game)
        bmesh.ops.transform(bm, matrix=body.matrix_world.inverted(), verts=bm.verts)
        name = f"Outfit_{spec['outfit']}_{g['name']}"
        me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
        ob = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(ob)
        ob.matrix_world = body.matrix_world.copy()
        for gname in groups:    # the same order as the body's, so its weights keep their bones
            ob.vertex_groups.new(name=gname)
        for p in me.polygons:
            p.use_smooth = True
        me.materials.append(mat)
        # thickness, heavier at the hem (a rolled, stitched edge)
        hem = ob.vertex_groups.new(name="hem")
        for i, d in enumerate(D):
            hem.add([i], float(0.45 + 0.55 * (1 - min(d / 0.008, 1.0))), "REPLACE")
        so = ob.modifiers.new("thick", "SOLIDIFY"); so.thickness = g["thick"] * 2.2; so.offset = 1.0
        so.use_rim = True; so.use_even_offset = False; so.use_quality_normals = True
        so.vertex_group = "hem"
        apply_mod(ob, so)
        ob.vertex_groups.remove(ob.vertex_groups["hem"])
        ob.parent = arm; ob.matrix_parent_inverse = arm.matrix_world.inverted()
        ob.modifiers.new("Armature", "ARMATURE").object = arm
        made.append(ob)
        print("garment", name, len(me.vertices), "verts", len(me.polygons), "faces")
    bpy.data.objects.remove(src, do_unlink=True)

    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    for ob in made:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(filepath=GLB_OUT, export_format="GLB", use_selection=True,
                              export_animations=False, export_skins=True, export_morph=False,
                              export_materials="EXPORT", export_image_format="NONE",
                              export_yup=True, export_apply=False)
    print("exported", GLB_OUT)


main()
