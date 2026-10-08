"""Renders the clarity visor's imagery (scripts/ui/visor_screen.gd) in Blender:

    blender -b --factory-startup --python tools/hub/build_visor_fx.py

Writes into assets/textures/visor/:
  spiral_sheet.png  a hypnotic tunnel: white spiral arms and rings winding down
                    into the dark, 32 frames (8 x 4, 256 px each) that loop
                    seamlessly (the arms turn one arm's spacing over the loop),
                    on a transparent ground: the visor plays it behind OBEY
  eye.png           the colony's watching eye: an almond outline, a ringed iris
                    and a spiral for a pupil, rays round it, 512 px, white on
                    transparent
Rendered with Eevee in emission only (white, faded by depth), so the visor
can tint and add them over her view.
"""
import math
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

OUT = Path(__file__).resolve().parent.parent.parent / "assets" / "textures" / "visor"
FRAMES = 32
CELL = 256
COLS, ROWS = 8, 4
ARMS = 4


def clear():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.curves, bpy.data.cameras, bpy.data.images):
        for item in list(block):
            block.remove(item)


def scene_setup(res):
    sc = bpy.context.scene
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    sc.render.resolution_x = res
    sc.render.resolution_y = res
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.get("World") or bpy.data.worlds.new("World")
    sc.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0, 0, 0, 1)
        bg.inputs[1].default_value = 0.0
    return sc


def glow_material(name, strength=4.0, depth_fade=None):
    """White emission; with depth_fade (near, far) it fades with distance down -Z."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (1, 1, 1, 1)
    mix = nt.nodes.new("ShaderNodeMixShader")
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    if depth_fade:
        geo = nt.nodes.new("ShaderNodeNewGeometry")
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        rng = nt.nodes.new("ShaderNodeMapRange")
        rng.inputs["From Min"].default_value = -depth_fade[1]
        rng.inputs["From Max"].default_value = -depth_fade[0]
        rng.inputs["To Min"].default_value = 0.0
        rng.inputs["To Max"].default_value = 1.0
        nt.links.new(geo.outputs["Position"], sep.inputs[0])
        nt.links.new(sep.outputs["Z"], rng.inputs["Value"])
        mul = nt.nodes.new("ShaderNodeMath")
        mul.operation = "MULTIPLY"
        mul.inputs[1].default_value = strength
        nt.links.new(rng.outputs["Result"], mul.inputs[0])
        nt.links.new(mul.outputs[0], em.inputs["Strength"])
        nt.links.new(rng.outputs["Result"], mix.inputs[0])
    else:
        em.inputs["Strength"].default_value = strength
        mix.inputs[0].default_value = 1.0
    nt.links.new(tr.outputs[0], mix.inputs[1])
    nt.links.new(em.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    if hasattr(m, "surface_render_method"):
        m.surface_render_method = "BLENDED"
    elif hasattr(m, "blend_method"):
        m.blend_method = "BLEND"
    return m


def ribbon(points, width, mat, name):
    """A glowing tube through `points`, `width` across."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    sp = cu.splines.new("POLY")
    sp.points.add(len(points) - 1)
    for p, v in zip(sp.points, points):
        p.co = (v.x, v.y, v.z, 1.0)
    cu.bevel_depth = width / 2
    cu.bevel_resolution = 3
    ob = bpy.data.objects.new(name, cu)
    bpy.context.collection.objects.link(ob)
    ob.data.materials.append(mat)
    return ob


def camera(loc, look, lens=18.0, ortho=None):
    cam = bpy.data.cameras.new("cam")
    if ortho:
        cam.type = "ORTHO"
        cam.ortho_scale = ortho
    else:
        cam.lens = lens
    cam.clip_end = 200
    ob = bpy.data.objects.new("cam", cam)
    bpy.context.collection.objects.link(ob)
    ob.location = loc
    d = Vector(look) - Vector(loc)
    ob.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = ob
    return ob


def render_to_array(path):
    sc = bpy.context.scene
    sc.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(str(path))
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    bpy.data.images.remove(img)
    return px.reshape(h, w, 4)


def save_array(arr, path):
    h, w, _ = arr.shape
    img = bpy.data.images.new(path.stem, width=w, height=h, alpha=True)
    img.pixels.foreach_set(arr.astype(np.float32).ravel())
    img.filepath_raw = str(path)
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def spiral():
    clear()
    scene_setup(CELL)
    mat = glow_material("tunnel", 1.25, depth_fade=(0.5, 22.0))
    tunnel = bpy.data.objects.new("tunnel", None)
    bpy.context.collection.objects.link(tunnel)
    # spiral arms winding down the tunnel, wider near the eye
    for k in range(ARMS):
        pts = []
        for i in range(260):
            u = i / 259
            z = -1.0 - u * 26.0
            r = 2.4 - u * 0.4
            a = k * math.tau / ARMS + u * math.tau * 3.2
            pts.append(Vector((math.cos(a) * r, math.sin(a) * r, z)))
        ob = ribbon(pts, 0.2, mat, f"arm{k}")
        ob.parent = tunnel
    # rings down the tunnel
    for j in range(14):
        z = -2.0 - j * 1.8
        pts = [Vector((math.cos(a) * 2.42, math.sin(a) * 2.42, z)) for a in (math.tau * i / 96 for i in range(97))]
        ob = ribbon(pts, 0.06, mat, f"ring{j}")
        ob.parent = tunnel
    camera((0, 0, 0.6), (0, 0, -10), lens=11.0)
    sheet = np.zeros((CELL * ROWS, CELL * COLS, 4), dtype=np.float32)
    tmp = OUT / "_frame.png"
    for f in range(FRAMES):
        tunnel.rotation_euler = (0, 0, -math.tau / ARMS * f / FRAMES)
        px = render_to_array(tmp)
        col, row = f % COLS, f // COLS
        # Blender's pixel rows run bottom-up; the sheet's frame 0 is top-left
        y0 = (ROWS - 1 - row) * CELL
        sheet[y0:y0 + CELL, col * CELL:(col + 1) * CELL] = px
    tmp.unlink(missing_ok=True)
    save_array(sheet, OUT / "spiral_sheet.png")
    print("wrote spiral_sheet.png")


def eye():
    clear()
    scene_setup(512)
    mat = glow_material("eye", 4.0)
    # almond outline: two arcs meeting at the corners
    for s in (1.0, -1.0):
        pts = [Vector((x, s * 0.62 * (1 - (x / 1.6) ** 2) ** 1.15, 0)) for x in np.linspace(-1.6, 1.6, 80)]
        ribbon(pts, 0.06, mat, "lid")
    # iris rings and a spiral pupil
    for r, w in ((0.58, 0.05), (0.46, 0.025), (0.36, 0.02)):
        pts = [Vector((math.cos(a) * r, math.sin(a) * r, 0)) for a in (math.tau * i / 120 for i in range(121))]
        ribbon(pts, w, mat, "iris")
    pts = [Vector((math.cos(a) * (0.02 + 0.3 * a / (math.tau * 3)), math.sin(a) * (0.02 + 0.3 * a / (math.tau * 3)), 0))
           for a in np.linspace(0, math.tau * 3, 220)]
    ribbon(pts, 0.035, mat, "pupil")
    # rays out from the lids
    for i in range(13):
        a = math.radians(20 + 140 * i / 12)
        for s in (1.0, -1.0):
            p0 = Vector((math.cos(a) * 1.0, s * math.sin(a) * 0.82, 0))
            p1 = Vector((math.cos(a) * 1.25, s * math.sin(a) * 1.08, 0))
            ribbon([p0, p1], 0.04, mat, "ray")
    camera((0, 0, 5), (0, 0, 0), ortho=3.6)
    px = render_to_array(OUT / "eye.png")
    print("wrote eye.png", px.shape)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    spiral()
    eye()


main()
