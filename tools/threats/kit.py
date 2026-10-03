"""Tiny modelling kit for the new-threats concept sheets (Blender 4.0, Z up,
characters face -Y, their right is +X)."""
import math
import bpy
from mathutils import Vector, Quaternion, Euler

V = Vector

# Game export (build_threats.py): coarser primitives, and every object made
# while PIVOT is set is tagged with it (the rigid part it hangs on).
GAME = False
PIVOT = None
RES_MULT = 1.0


def _seg(seg, lo):
    return max(lo, seg // 3) if GAME else seg


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


# ---------------------------------------------------------------- materials
def mat(name, color, rough=0.5, metal=0.0, emit=None, strength=0.0, coat=0.0,
        sss=0.0, trans=0.0, noise=None, bump=0.0, bump_scale=30.0, ior=1.45):
    """Principled material. noise=(color2, scale) mottles the base colour;
    bump adds a fine noise bump for skin/hide."""
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    b.inputs["Coat Weight"].default_value = coat
    b.inputs["Subsurface Weight"].default_value = sss
    if sss:
        b.inputs["Subsurface Radius"].default_value = (0.3, 0.12, 0.08)
        b.inputs["Subsurface Scale"].default_value = 0.05
    b.inputs["Transmission Weight"].default_value = trans
    b.inputs["IOR"].default_value = ior
    if emit:
        b.inputs["Emission Color"].default_value = (*emit, 1)
        b.inputs["Emission Strength"].default_value = strength
    m.diffuse_color = (*color, 1)
    if noise or bump:
        tc = nt.nodes.new("ShaderNodeTexCoord")
    if noise:
        c2, sc = noise
        n = nt.nodes.new("ShaderNodeTexNoise")
        n.inputs["Scale"].default_value = sc
        n.inputs["Detail"].default_value = 6
        nt.links.new(tc.outputs["Object"], n.inputs["Vector"])
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].position = 0.35
        ramp.color_ramp.elements[0].color = (*color, 1)
        ramp.color_ramp.elements[1].position = 0.65
        ramp.color_ramp.elements[1].color = (*c2, 1)
        nt.links.new(n.outputs["Fac"], ramp.inputs["Fac"])
        nt.links.new(ramp.outputs["Color"], b.inputs["Base Color"])
    if bump:
        n2 = nt.nodes.new("ShaderNodeTexNoise")
        n2.inputs["Scale"].default_value = bump_scale
        n2.inputs["Detail"].default_value = 8
        nt.links.new(tc.outputs["Object"], n2.inputs["Vector"])
        bn = nt.nodes.new("ShaderNodeBump")
        bn.inputs["Strength"].default_value = bump
        nt.links.new(n2.outputs["Fac"], bn.inputs["Height"])
        nt.links.new(bn.outputs["Normal"], b.inputs["Normal"])
    return m


def stripes(name, c1, c2, axis="Z", scale=8.0, rough=0.6, bump=0.0, warp=1.5):
    """Wavy banded hide (tiger-ish) along an object axis."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Roughness"].default_value = rough
    tc = nt.nodes.new("ShaderNodeTexCoord")
    w = nt.nodes.new("ShaderNodeTexWave")
    w.wave_type = "BANDS"
    w.bands_direction = axis
    w.inputs["Scale"].default_value = scale
    w.inputs["Distortion"].default_value = warp * 6
    w.inputs["Detail"].default_value = 3
    nt.links.new(tc.outputs["Object"], w.inputs["Vector"])
    r = nt.nodes.new("ShaderNodeValToRGB")
    r.color_ramp.elements[0].position = 0.55
    r.color_ramp.elements[0].color = (*c1, 1)
    r.color_ramp.elements[1].position = 0.7
    r.color_ramp.elements[1].color = (*c2, 1)
    nt.links.new(w.outputs["Fac"], r.inputs["Fac"])
    nt.links.new(r.outputs["Color"], b.inputs["Base Color"])
    if bump:
        n2 = nt.nodes.new("ShaderNodeTexNoise")
        n2.inputs["Scale"].default_value = 60
        nt.links.new(tc.outputs["Object"], n2.inputs["Vector"])
        bn = nt.nodes.new("ShaderNodeBump")
        bn.inputs["Strength"].default_value = bump
        nt.links.new(n2.outputs["Fac"], bn.inputs["Height"])
        nt.links.new(bn.outputs["Normal"], b.inputs["Normal"])
    m.diffuse_color = (*c1, 1)
    return m


# ---------------------------------------------------------------- primitives
def _finish(o, m, smooth=True, parent=None):
    if m:
        o.data.materials.append(m)
    if smooth and o.type == "MESH":
        for p in o.data.polygons:
            p.use_smooth = True
    if parent:
        o.parent = parent
    if PIVOT:
        o["pivot"] = PIVOT
    return o


def look_quat(d, up="Z"):
    return V(d).normalized().to_track_quat(up, "Y" if up != "Y" else "Z")


def ell(loc, size, m, rot=(0, 0, 0), seg=40, parent=None, name="ell"):
    """Ellipsoid with radii `size`, rotation in degrees (XYZ)."""
    seg = _seg(seg, 10)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=seg // 2, location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = size
    o.rotation_euler = Euler([math.radians(a) for a in rot])
    return _finish(o, m, parent=parent)


def rod(a, b, r1, r2, m, seg=24, caps=True, parent=None, name="rod"):
    """Tapered cylinder from a to b, optionally capped with balls."""
    a, b = V(a), V(b)
    d = b - a
    seg = _seg(seg, 6)
    bpy.ops.mesh.primitive_cone_add(vertices=seg, radius1=r1, radius2=r2, depth=d.length,
                                    location=(a + b) / 2)
    o = bpy.context.object
    o.name = name
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = look_quat(d)
    _finish(o, m, parent=parent)
    if caps:
        ell(a, (r1, r1, r1), m, seg=seg, parent=parent)
        if r2 > 0.002:
            ell(b, (r2, r2, r2), m, seg=seg, parent=parent)
    return o


def box(loc, size, m, rot=(0, 0, 0), bevel=0.01, parent=None, name="box"):
    bpy.ops.mesh.primitive_cube_add(location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = [s / 2 for s in size]
    o.rotation_euler = Euler([math.radians(a) for a in rot])
    if bevel:
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        md = o.modifiers.new("bev", "BEVEL")
        md.width = bevel
        md.segments = 3
    return _finish(o, m, smooth=False, parent=parent)


def torus(loc, R, r, m, rot=(0, 0, 0), parent=None, name="torus", seg=64):
    bpy.ops.mesh.primitive_torus_add(location=loc, major_radius=R, minor_radius=r,
                                     major_segments=_seg(seg, 16), minor_segments=6 if GAME else 16)
    o = bpy.context.object
    o.name = name
    o.rotation_euler = Euler([math.radians(a) for a in rot])
    return _finish(o, m, parent=parent)


def cone(a, b, r, m, seg=24, parent=None, name="cone"):
    return rod(a, b, r, 0.0, m, seg=seg, caps=False, parent=parent, name=name)


def spike(a, b, r, m, curve=0.0, steps=6, parent=None, side=V((0, 0, 1))):
    """Curved horn: chain of tapered rods bending toward `side` by `curve`."""
    a, b = V(a), V(b)
    pts = []
    for i in range(steps + 1):
        t = i / steps
        p = a.lerp(b, t) + V(side) * curve * math.sin(math.pi * t) * 0.5 + V(side) * curve * t * t * 0.5
        pts.append(p)
    for i in range(steps):
        r1 = r * (1 - i / steps)
        r2 = r * (1 - (i + 1) / steps)
        rod(pts[i], pts[i + 1], r1, max(r2, 0.0), m, seg=12, caps=i < steps - 1, parent=parent)


# ---------------------------------------------------------------- metaballs
class Blob:
    """Metaball body: add balls/lines, then .mesh() fuses them into one smooth mesh."""

    def __init__(self, name, res=0.02, thresh=0.6):
        self.mb = bpy.data.metaballs.new(name)
        res *= RES_MULT
        self.mb.resolution = res
        self.mb.render_resolution = res
        self.mb.threshold = thresh
        self.o = bpy.data.objects.new(name, self.mb)
        bpy.context.collection.objects.link(self.o)

    def ball(self, co, r, stiff=2.0, neg=False):
        e = self.mb.elements.new()
        e.type = "BALL"
        e.co = co
        e.radius = r
        e.stiffness = stiff
        e.use_negative = neg
        return e

    def ellip(self, co, r, size, rot=(0, 0, 0), stiff=2.0, neg=False):
        e = self.mb.elements.new()
        e.type = "ELLIPSOID"
        e.co = co
        e.radius = r
        e.size_x, e.size_y, e.size_z = size
        e.rotation = Euler([math.radians(a) for a in rot]).to_quaternion()
        e.stiffness = stiff
        e.use_negative = neg
        return e

    def line(self, a, b, r1, r2, n=None, stiff=2.0):
        a, b = V(a), V(b)
        n = n or max(2, int((b - a).length / (min(r1, r2) * 0.6)) + 1)
        for i in range(n):
            t = i / (n - 1)
            self.ball(a.lerp(b, t), r1 + (r2 - r1) * t, stiff)

    def path(self, pts, radii, per=None, stiff=2.0):
        for i in range(len(pts) - 1):
            self.line(pts[i], pts[i + 1], radii[i], radii[i + 1], per, stiff)

    def mesh(self, m, parent=None, name=None):
        bpy.ops.object.select_all(action="DESELECT")
        bpy.context.view_layer.objects.active = self.o
        self.o.select_set(True)
        bpy.ops.object.convert(target="MESH")
        o = bpy.context.object
        if name:
            o.name = name
        return _finish(o, m, parent=parent)


def mirror_x(fn):
    """Call fn(sign) for the right (+1) and left (-1) side."""
    fn(1)
    fn(-1)


def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = bpy.context.object
    o.name = name
    return o


# ---------------------------------------------------------------- staging
def stage(sky=(0.2, 0.27, 0.32), horizon=(0.72, 0.7, 0.64), ground=(0.17, 0.18, 0.15), size=80):
    w = bpy.data.worlds.new("w")
    bpy.context.scene.world = w
    w.use_nodes = True
    nt = w.node_tree
    bg = nt.nodes["Background"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Window"], sep.inputs[0])
    r = nt.nodes.new("ShaderNodeValToRGB")
    r.color_ramp.elements[0].position = 0.45
    r.color_ramp.elements[0].color = (*horizon, 1)
    r.color_ramp.elements[1].position = 1.0
    r.color_ramp.elements[1].color = (*sky, 1)
    nt.links.new(sep.outputs["Y"], r.inputs["Fac"])
    nt.links.new(r.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 0.9
    g = mat("ground", ground, rough=0.95, noise=((ground[0] * 0.75, ground[1] * 0.72, ground[2] * 0.7), 1.2))
    bpy.ops.mesh.primitive_plane_add(size=size)
    bpy.context.object.data.materials.append(g)
    # back wall haze card so the horizon reads like the grunt sheet
    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = 3.2
    sun.color = (1.0, 0.9, 0.78)
    sun.angle = math.radians(4)
    so = bpy.data.objects.new("sun", sun)
    so.rotation_euler = Euler((math.radians(50), 0, math.radians(-35)))
    bpy.context.collection.objects.link(so)
    rim = bpy.data.lights.new("rim", "SUN")
    rim.energy = 2.0
    rim.color = (0.7, 0.8, 1.0)
    ro = bpy.data.objects.new("rim", rim)
    ro.rotation_euler = Euler((math.radians(70), 0, math.radians(160)))
    bpy.context.collection.objects.link(ro)


def setup_render(engine="CYCLES", samples=64, w=640, h=880):
    s = bpy.context.scene
    s.render.engine = engine
    s.render.resolution_x = w
    s.render.resolution_y = h
    s.render.resolution_percentage = 100
    s.view_settings.view_transform = "AgX"
    s.view_settings.look = "AgX - Base Contrast"
    if engine == "CYCLES":
        s.cycles.samples = samples
        s.cycles.use_denoising = False
        s.cycles.max_bounces = 6
        s.cycles.device = "CPU"
    else:
        s.eevee.taa_render_samples = samples
        s.eevee.use_gtao = True
        s.eevee.use_soft_shadows = True
        s.eevee.use_bloom = True
        s.eevee.bloom_intensity = 0.04
        s.eevee.shadow_cube_size = "2048"
        s.eevee.shadow_cascade_size = "4096"
        s.eevee.use_ssr = True


def shot(path, target, dist, yaw, pitch=8.0, lens=60, w=None, h=None):
    """Camera orbiting `target`; yaw 0 = in front (-Y), 90 = their right side."""
    s = bpy.context.scene
    if w:
        s.render.resolution_x = w
    if h:
        s.render.resolution_y = h
    cam = s.camera
    if cam is None:
        cd = bpy.data.cameras.new("cam")
        cam = bpy.data.objects.new("cam", cd)
        bpy.context.collection.objects.link(cam)
        s.camera = cam
    cam.data.lens = lens
    t = V(target)
    y, p = math.radians(yaw), math.radians(pitch)
    off = V((math.sin(y) * math.cos(p), -math.cos(y) * math.cos(p), math.sin(p))) * dist
    cam.location = t + off
    cam.rotation_mode = "QUATERNION"
    cam.rotation_quaternion = (t - cam.location).to_track_quat("-Z", "Y")
    s.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def silhouette(glb, loc=(0, 0, 0), color=(0.05, 0.05, 0.06), yaw=180):
    """Import a glb (Eco) as a flat dark scale figure, feet on the ground at loc."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(glb))
    new = set(bpy.data.objects) - before
    m = mat("silhouette", color, rough=0.9)
    for o in list(new):
        if o.type == "MESH" and o.name.startswith("Icosphere"):
            bpy.data.objects.remove(o)
            new.discard(o)
    for o in new:
        if o.type == "MESH":
            o.data.materials.clear()
            o.data.materials.append(m)
            for ms in o.material_slots:
                ms.material = m
    roots = [o for o in new if o.parent is None]
    for r in roots:
        r.rotation_euler.z += math.radians(yaw)
    bpy.context.view_layer.update()
    zmin = min((o.matrix_world @ V(c)).z for o in new if o.type == "MESH" for c in o.bound_box)
    for r in roots:
        r.location = V(loc) + V((0, 0, -zmin))
    bpy.context.view_layer.update()
    zmax = max((o.matrix_world @ V(c)).z for o in new if o.type == "MESH" for c in o.bound_box)
    return zmax - (-zmin) if False else zmax


def ell_between(a, b, rx, ry, m, over=1.0, roll=0.0, parent=None, name="plate", seg=32):
    """Ellipsoid stretched from a to b (local Z along a->b), widths rx, ry."""
    a, b = V(a), V(b)
    d = b - a
    seg = _seg(seg, 10)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=seg // 2, location=(a + b) / 2)
    o = bpy.context.object
    o.name = name
    o.scale = (rx, ry, d.length / 2 * over)
    o.rotation_mode = "QUATERNION"
    q = d.normalized().to_track_quat("Z", "Y")
    if roll:
        q = q @ Quaternion((0, 0, 1), math.radians(roll))
    o.rotation_quaternion = q
    return _finish(o, m, parent=parent)


def strip(top, width, length, m, bulge=0.03, tilt=0.0, seed=0, cols=9, rows=14, taper=0.85,
          yaw=0.0, parent=None, name="cloth"):
    """Hanging cloth strip: top edge centred at `top`, hangs down -Z, ragged torn hem.
    tilt (deg) swings the bottom forward (-Y) / back; yaw turns it about Z."""
    import random
    import bmesh
    rnd = random.Random(seed)
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    hem = [length * rnd.uniform(0.72, 1.0) for _ in range(cols)]
    grid = []
    for j in range(rows):
        row = []
        for i in range(cols):
            u = i / (cols - 1) - 0.5
            t = j / (rows - 1)
            L = hem[i] if j == rows - 1 else length * t
            if j == rows - 1:
                t = hem[i] / length
            w = width * (1 - (1 - taper) * t)
            x = u * w
            z = -L if j == rows - 1 else -length * t
            y = -bulge * math.cos(u * math.pi) + math.sin(math.radians(tilt)) * -z * -1
            y += 0.01 * math.sin(i * 1.7 + j * 0.9 + seed)
            row.append(bm.verts.new((x, y, z)))
        grid.append(row)
    for j in range(rows - 1):
        for i in range(cols - 1):
            bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
    bm.to_mesh(me)
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    o.location = V(top)
    o.rotation_euler = Euler((0, 0, math.radians(yaw)))
    sd = o.modifiers.new("thick", "SOLIDIFY")
    sd.thickness = 0.008
    if not GAME:
        o.modifiers.new("sub", "SUBSURF").levels = 1
    return _finish(o, m, parent=parent)


def slab(loc, outline, thick, m, rot=(0, 0, 0), bevel=0.02, parent=None, name="slab"):
    """Flat plate from a 2D outline [(x, z), ...] in the XZ plane, thickness along Y."""
    import bmesh
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    front = [bm.verts.new((x, -thick / 2, z)) for x, z in outline]
    f = bm.faces.new(front)
    ext = bmesh.ops.extrude_face_region(bm, geom=[f])
    for v in [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]:
        v.co.y += thick
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    o.location = V(loc)
    o.rotation_euler = Euler([math.radians(a) for a in rot])
    if bevel:
        md = o.modifiers.new("bev", "BEVEL")
        md.width = bevel
        md.segments = 4
        md.limit_method = "NONE"
    return _finish(o, m, smooth=False, parent=parent)


# ================================================================ toon look
# Eco's in-game shading (assets/shaders/eco_toon.gdshaderinc): two flat tones
# with a crisp edge, the shadow side is the colour times a tint (never black),
# a thin rim of light on the silhouette, a thin hard sheen on glossy parts,
# glowing trims; plus ink outlines (Freestyle here, an inverted hull in game).
_plain_mat = mat
SHADE = (0.66, 0.62, 0.8)


def _toon_tree(m, base_socket_fn, shade=SHADE, sheen=0.0, rim=0.22, emit=None, strength=0.0):
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    N = nt.nodes.new
    L = nt.links.new
    out = N("ShaderNodeOutputMaterial")
    base = base_socket_fn(nt)  # socket giving the flat base colour
    dif = N("ShaderNodeBsdfDiffuse")
    s2r = N("ShaderNodeShaderToRGB")
    L(dif.outputs[0], s2r.inputs[0])
    bw = N("ShaderNodeRGBToBW")
    L(s2r.outputs[0], bw.inputs[0])
    lit = N("ShaderNodeMapRange")  # crisp terminator
    lit.inputs["From Min"].default_value = 0.16
    lit.inputs["From Max"].default_value = 0.2
    L(bw.outputs[0], lit.inputs["Value"])
    shaded = N("ShaderNodeMix")
    shaded.data_type = "RGBA"
    shaded.blend_type = "MULTIPLY"
    shaded.inputs["Factor"].default_value = 1.0
    L(base, shaded.inputs[6])
    shaded.inputs[7].default_value = (*shade, 1)
    mix = N("ShaderNodeMix")
    mix.data_type = "RGBA"
    L(lit.outputs[0], mix.inputs["Factor"])
    L(shaded.outputs[2], mix.inputs[6])
    L(base, mix.inputs[7])
    col = mix.outputs[2]
    # rim: thin bright edge on the lit silhouette
    lw = N("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.5
    rr = N("ShaderNodeMapRange")
    rr.inputs["From Min"].default_value = 0.78
    rr.inputs["From Max"].default_value = 0.84
    rr.inputs["To Max"].default_value = rim
    L(lw.outputs["Facing"], rr.inputs["Value"])
    rmul = N("ShaderNodeMath")
    rmul.operation = "MULTIPLY"
    L(rr.outputs[0], rmul.inputs[0])
    L(lit.outputs[0], rmul.inputs[1])
    radd = N("ShaderNodeMix")
    radd.data_type = "RGBA"
    radd.blend_type = "ADD"
    L(rmul.outputs[0], radd.inputs["Factor"])
    L(col, radd.inputs[6])
    radd.inputs[7].default_value = (1, 0.97, 0.92, 1)
    col = radd.outputs[2]
    if sheen:  # thin, hard specular band
        gl = N("ShaderNodeBsdfGlossy")
        gl.inputs["Roughness"].default_value = 0.18
        s2 = N("ShaderNodeShaderToRGB")
        L(gl.outputs[0], s2.inputs[0])
        b2 = N("ShaderNodeRGBToBW")
        L(s2.outputs[0], b2.inputs[0])
        sr = N("ShaderNodeMapRange")
        sr.inputs["From Min"].default_value = 1.2
        sr.inputs["From Max"].default_value = 1.3
        sr.inputs["To Max"].default_value = sheen
        L(b2.outputs[0], sr.inputs["Value"])
        sadd = N("ShaderNodeMix")
        sadd.data_type = "RGBA"
        sadd.blend_type = "ADD"
        L(sr.outputs[0], sadd.inputs["Factor"])
        L(col, sadd.inputs[6])
        sadd.inputs[7].default_value = (0.95, 0.96, 1.0, 1)
        col = sadd.outputs[2]
    em = N("ShaderNodeEmission")
    L(col, em.inputs["Color"])
    if emit and strength:
        em.inputs["Strength"].default_value = 1.0
        g = N("ShaderNodeEmission")
        g.inputs["Color"].default_value = (*emit, 1)
        g.inputs["Strength"].default_value = min(1.6, max(1.1, strength * 0.06))
        L(g.outputs[0], out.inputs["Surface"])
        return m
    L(em.outputs[0], out.inputs["Surface"])
    return m


def mat(name, color, rough=0.5, metal=0.0, emit=None, strength=0.0, coat=0.0,
        sss=0.0, trans=0.0, noise=None, bump=0.0, bump_scale=30.0, ior=1.45, shade=None, sheen=None,
        rim=0.22):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.diffuse_color = (*color, 1)
    if sheen is None:
        sheen = 0.55 if (metal or coat >= 0.3 or rough <= 0.3) else 0.0
    if shade is None:
        shade = (0.8, 0.62, 0.42) if metal else SHADE

    def base(nt):
        rgb = nt.nodes.new("ShaderNodeRGB")
        rgb.outputs[0].default_value = (*color, 1)
        return rgb.outputs[0]

    return _toon_tree(m, base, shade=shade, sheen=sheen, rim=rim, emit=emit, strength=strength)


def stripes(name, c1, c2, axis="Z", scale=8.0, rough=0.6, bump=0.0, warp=1.5, shade=None, sheen=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.diffuse_color = (*c1, 1)

    def base(nt):
        tc = nt.nodes.new("ShaderNodeTexCoord")
        w = nt.nodes.new("ShaderNodeTexWave")
        w.wave_type = "BANDS"
        w.bands_direction = axis
        w.inputs["Scale"].default_value = scale
        w.inputs["Distortion"].default_value = warp * 6
        w.inputs["Detail"].default_value = 1
        nt.links.new(tc.outputs["Object"], w.inputs["Vector"])
        r = nt.nodes.new("ShaderNodeValToRGB")
        r.color_ramp.interpolation = "CONSTANT"
        r.color_ramp.elements[0].position = 0.0
        r.color_ramp.elements[0].color = (*c1, 1)
        r.color_ramp.elements[1].position = 0.62
        r.color_ramp.elements[1].color = (*c2, 1)
        nt.links.new(w.outputs["Fac"], r.inputs["Fac"])
        return r.outputs["Color"]

    return _toon_tree(m, base, shade=shade or SHADE, sheen=sheen)


def stage(bg=(0.36, 0.37, 0.41), floor=True, **_):
    """Flat studio grey like Eco's turnarounds. The world lights nothing (camera
    rays see the backdrop) so the sun alone decides lit vs shade."""
    w = bpy.data.worlds.new("w")
    bpy.context.scene.world = w
    w.use_nodes = True
    nt = w.node_tree
    bgn = nt.nodes["Background"]
    lp = nt.nodes.new("ShaderNodeLightPath")
    mx = nt.nodes.new("ShaderNodeMix")
    mx.data_type = "RGBA"
    nt.links.new(lp.outputs["Is Camera Ray"], mx.inputs["Factor"])
    mx.inputs[6].default_value = (0, 0, 0, 1)
    mx.inputs[7].default_value = (*bg, 1)
    nt.links.new(mx.outputs[2], bgn.inputs["Color"])
    bgn.inputs["Strength"].default_value = 1.0
    if floor:  # floor in the backdrop colour that still takes the toon shadow
        g = mat("floor", bg, sheen=0.0, shade=(0.8, 0.8, 0.84), rim=0.0)
        bpy.ops.mesh.primitive_plane_add(size=400)
        fl = bpy.context.object
        fl.data.materials.append(g)
        fl.name = "floor"
        col = bpy.data.collections.new("no_ink")
        bpy.context.scene.collection.children.link(col)
        for c in list(fl.users_collection):
            c.objects.unlink(fl)
        col.objects.link(fl)
    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = 4.0
    sun.angle = math.radians(1.5)
    so = bpy.data.objects.new("sun", sun)
    so.rotation_euler = Euler((math.radians(42), 0, math.radians(-38)))
    bpy.context.collection.objects.link(so)


def setup_render(engine="BLENDER_EEVEE", samples=64, w=640, h=880, line=1.6):
    s = bpy.context.scene
    s.render.engine = "BLENDER_EEVEE"
    s.render.resolution_x = w
    s.render.resolution_y = h
    s.render.resolution_percentage = 100
    s.view_settings.view_transform = "Standard"
    s.view_settings.look = "None"
    s.eevee.taa_render_samples = samples
    s.eevee.use_gtao = False
    s.eevee.use_soft_shadows = False
    s.eevee.shadow_cube_size = "2048"
    s.eevee.shadow_cascade_size = "4096"
    s.eevee.use_bloom = True
    s.eevee.bloom_intensity = 0.03
    s.eevee.bloom_threshold = 1.2
    s.render.use_freestyle = True
    s.render.line_thickness_mode = "ABSOLUTE"
    s.render.line_thickness = line
    vl = s.view_layers[0]
    vl.use_freestyle = True
    fs = vl.freestyle_settings
    fs.crease_angle = math.radians(120)
    ls = fs.linesets[0] if fs.linesets else fs.linesets.new("ink")
    ls.select_by_visibility = True
    ls.select_by_edge_types = True
    ls.select_silhouette = True
    ls.select_border = True
    ls.select_crease = False
    ls.select_contour = True
    ls.select_external_contour = True
    nc = bpy.data.collections.get("no_ink")
    ls.select_by_collection = nc is not None
    if nc:
        ls.collection = nc
        ls.collection_negation = "EXCLUSIVE"
    if ls.linestyle is None:
        ls.linestyle = bpy.data.linestyles.new("ink")
    ls.linestyle.color = (0.07, 0.055, 0.08)
    ls.linestyle.thickness = line
    ls.linestyle.chaining = "PLAIN"


def no_ink(o):
    """Move an object into the collection Freestyle skips (floors, water)."""
    col = bpy.data.collections.get("no_ink")
    for c in list(o.users_collection):
        c.objects.unlink(o)
    col.objects.link(o)
