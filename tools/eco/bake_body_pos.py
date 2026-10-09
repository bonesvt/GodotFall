"""Bakes where each texel of Eco's body texture sits on her (rest pose, metres,
Blender axes: x her side, y forward, z up) into tools/eco/body_pos.npz, which
bake_vice_looks.py cuts her looks' skin windows by: "pos" (1024 x 1024 x 3,
float16) and "on" (where her body is).

    blender -b --factory-startup -P tools/eco/bake_body_pos.py      (from the repo root)
"""
import bpy, os, numpy as np

REPO = os.getcwd()
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=REPO + "/assets/models/eco/eco.glb")
N = 1024
pos = np.zeros((N, N, 3), np.float32)
hit = np.zeros((N, N), bool)
for ob in bpy.data.objects:
    if ob.type != "MESH":
        continue
    me = ob.data
    slots = {i for i, m in enumerate(me.materials) if m and m.name.split(".")[0] == "eco_v_body"}
    if not slots or not me.uv_layers:
        continue
    print("mesh", ob.name, len(me.polygons))
    me.calc_loop_triangles()
    uv = me.uv_layers.active.data
    mw = ob.matrix_world
    co = np.array([tuple(mw @ v.co) for v in me.vertices], np.float32)
    for t in me.loop_triangles:
        if t.material_index not in slots:
            continue
        P = co[list(t.vertices)]
        U = np.array([tuple(uv[l].uv) for l in t.loops], np.float32)
        px = U[:, 0] * N
        py = (1 - U[:, 1]) * N
        x0, x1 = int(max(0, np.floor(px.min()))), int(min(N - 1, np.ceil(px.max())))
        y0, y1 = int(max(0, np.floor(py.min()))), int(min(N - 1, np.ceil(py.max())))
        if x1 < x0 or y1 < y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        d = (py[1] - py[2]) * (px[0] - px[2]) + (px[2] - px[1]) * (py[0] - py[2])
        if abs(d) < 1e-9:
            continue
        a = ((py[1] - py[2]) * (xs - px[2]) + (px[2] - px[1]) * (ys - py[2])) / d
        b = ((py[2] - py[0]) * (xs - px[2]) + (px[0] - px[2]) * (ys - py[2])) / d
        c = 1 - a - b
        e = -0.02
        inside = (a >= e) & (b >= e) & (c >= e)
        if not inside.any():
            continue
        p = a[..., None] * P[0] + b[..., None] * P[1] + c[..., None] * P[2]
        yy, xx = np.nonzero(inside)
        pos[y0 + yy, x0 + xx] = p[yy, xx]
        hit[y0 + yy, x0 + xx] = True
np.savez_compressed(os.path.join(REPO, "tools/eco/body_pos.npz"), pos=pos.astype(np.float16), on=hit)
print("coverage", hit.mean())
