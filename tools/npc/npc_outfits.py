"""Real clothes for the hub NPCs, as meshes on their rig (build_npc.py runs this
file into its own globals, so everything there is in scope here):

- the rescue looks (scripts/hub/rescue_looks.gd): what Mom and Ophelia come
  back dressed in after enough visits to whoever has them.
    Outfit_captor_marrow_Coat     Marrow: a long dark coat lined violet, a high
                                  collar, its sleeves down over her hands, the
                                  skirt open a little at the front
    Outfit_captor_colony_Suit     the colony: a white jumpsuit, charcoal side
                                  panels, a belt, cyan strips and a chest seal
    Outfit_captor_cutter_Clothes  Cutter: an oversized grey hoodie with his red
                                  stripes and its hood down at her back, ripped
                                  jeans
- Ophelia's intake suit in Level 2 (hub_npc.gd "colony_m"):
    Outfit_colony_m_Suit          the same torn suit body_colony_m.png paints on
                                  her, as cloth over her: its rips and her
                                  missing sleeve and trouser leg cut out of it
                                  (the texture's alpha), her painted skin
                                  showing through them
- the colony orderlies (assets/models/npc/orderly.glb, scripts/run/orderly.gd):
  the preset under a white suit, gloves, shoe covers and a faceless helmet
  with a black visor.

Each piece is cut from her own body (shell(): her skin's faces, let out from
her and smoothed so the cloth spans the hollows rather than following every
dip, never closer to her than it should be) or hung round her hips and legs
(garment()), keeps her skin weights so it moves with her, gets a thickness
(its inside marked "inner" for the lining), and is unwrapped and baked into
assets/textures/npc/<who>/<part>.png from the same rest-space maths as her
painted clothes (clothes_graph). The game shows Outfit_<outfit>_* only in
that outfit (hub_npc.gd _dress_meshes()); rescue_looks.gd shows
Outfit_captor_<captor>_* while she's in that look.
"""
from mathutils.bvhtree import BVHTree

OUTFIT_TEX = 1024


def _neck_z(ax):
    """The neckline round her (rest space): low at her throat, up the sides."""
    return 1.196 + (1.4 - 1.196) * ss(0.07, 0.095, ax)


def _body_tree(with_index=False):
    """Her skin's surface as it is now (rest pose); with_index also gives each
    of the tree's polygons' index in her mesh."""
    body = bpy.data.objects["Body"]
    me = body.data
    skin = mat_index(body, "Body_00_SKIN")
    idx = [p.index for p in me.polygons if p.material_index in skin]
    tree = BVHTree.FromPolygons([v.co for v in me.vertices], [me.polygons[i].vertices[:] for i in idx])
    return (tree, idx) if with_index else tree


def reskin(bm):
    """Each point of the cloth skinned as her skin is right under it (the
    smoothing slides points along her, away from the vertex they were cut
    from, and the cloth would part from her at the joints)."""
    from mathutils import interpolate
    me_b = bpy.data.objects["Body"].data
    tree, idx = _body_tree(True)
    bw = [{g.group: g.weight for g in v.groups} for v in me_b.vertices]
    dl = bm.verts.layers.deform.verify()
    for v in bm.verts:
        loc, _n, pi, _d = tree.find_nearest(v.co)
        if loc is None:
            continue
        poly = me_b.polygons[idx[pi]]
        w = interpolate.poly_3d_calc([me_b.vertices[i].co for i in poly.vertices], loc)
        acc = {}
        for vi, wi in zip(poly.vertices, w):
            for g, gw in bw[vi].items():
                acc[g] = acc.get(g, 0.0) + gw * wi
        total = sum(acc.values()) or 1.0
        dv = v[dl]
        dv.clear()
        for g, gw in acc.items():
            if gw / total > 0.002:
                dv[g] = gw / total


def shell(name, region, part):
    """A copy of her skin's faces whose rest points all pass region(R) (an (n,3)
    array -> bool array), welded across the UV seams, still skinned exactly as
    she is. Returns (object, bmesh) for fit() and the rest."""
    body = bpy.data.objects["Body"]
    ob = body.copy()
    ob.data = body.data.copy()
    ob.name = ob.data.name = name
    bpy.context.scene.collection.objects.link(ob)
    if ob.data.shape_keys:
        ob.shape_key_clear()
    skin = mat_index(body, "Body_00_SKIN")
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    rl = bm.verts.layers.float_vector.get("rest")
    bm.verts.ensure_lookup_table()
    R = np.array([v[rl][:] for v in bm.verts])
    keep = region(R)
    dead = [f for f in bm.faces if f.material_index not in skin or not all(keep[v.index] for v in f.verts)]
    bmesh.ops.delete(bm, geom=dead, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
    for f in bm.faces:
        f.material_index = 0
        f.smooth = True
    ob.data.materials.clear()
    ob.data.materials.append(new_mat("npc_%s_%s" % (WHO, part)))
    return ob, bm


def _rest_of(bm):
    rl = bm.verts.layers.float_vector.get("rest")
    return np.array([v[rl][:] for v in bm.verts]), rl


def fit(bm, gap, smooth=10, hold=0.75, clear=0.004):
    """Lets the cloth out from her by gap(R, N) metres (R rest points, N
    normals), smoothed `smooth` times so it bridges hollows; every few passes
    anything that has come closer to her than hold * its gap (and never under
    `clear`) is pushed back out along her surface's normal there."""
    bm.verts.ensure_lookup_table()
    bm.normal_update()
    R, _ = _rest_of(bm)
    P = np.array([v.co[:] for v in bm.verts])
    N = np.array([v.normal[:] for v in bm.verts])
    G = gap(R, N) if callable(gap) else np.full(len(P), float(gap))
    X = P + N * G[:, None]
    edges = np.array([(e.verts[0].index, e.verts[1].index) for e in bm.edges])
    tree = _body_tree()
    want = np.maximum(G * hold, clear)

    def push_out(X):
        for i in range(len(X)):
            loc, nrm, _, _ = tree.find_nearest(Vector(X[i]))
            if loc is None:
                continue
            side = (Vector(X[i]) - loc).dot(nrm)
            if side < want[i]:
                X[i] = X[i] + np.array(nrm) * (want[i] - side)
        return X
    for it in range(smooth):
        acc = np.zeros_like(X)
        cnt = np.zeros(len(X))
        np.add.at(acc, edges[:, 0], X[edges[:, 1]])
        np.add.at(acc, edges[:, 1], X[edges[:, 0]])
        np.add.at(cnt, edges[:, 0], 1)
        np.add.at(cnt, edges[:, 1], 1)
        X = 0.5 * X + 0.5 * acc / np.maximum(cnt, 1)[:, None]
        if it % 3 == 2:
            X = push_out(X)
    X = push_out(X)
    for v, p in zip(bm.verts, X):
        v.co = p
    reskin(bm)


def relax(bm, pick, passes=60):
    """Smooths only the points whose rest positions pick(R) chooses, the rest
    held still: irons out what fit() keeps (the preset's nipples)."""
    bm.verts.ensure_lookup_table()
    R, _ = _rest_of(bm)
    move = pick(R)
    X = np.array([v.co[:] for v in bm.verts])
    edges = np.array([(e.verts[0].index, e.verts[1].index) for e in bm.edges])
    for _ in range(passes):
        acc = np.zeros_like(X)
        cnt = np.zeros(len(X))
        np.add.at(acc, edges[:, 0], X[edges[:, 1]])
        np.add.at(acc, edges[:, 1], X[edges[:, 0]])
        np.add.at(cnt, edges[:, 0], 1)
        np.add.at(cnt, edges[:, 1], 1)
        X[move] = 0.5 * X[move] + 0.5 * (acc / np.maximum(cnt, 1)[:, None])[move]
    for v, p in zip(bm.verts, X):
        v.co = p


def extend(ob, bm, pick, step, rings=1, scale=1.0, bone=None):
    """Runs the open edge whose ends all pass pick(rest point) on past where her
    skin ends: `rings` more rings, each moved by `step` and widened by `scale`
    about its middle (a sleeve over her hand, a collar, a hem). With `bone`
    the new rings hang on that bone alone."""
    rl = bm.verts.layers.float_vector.get("rest")
    dl = bm.verts.layers.deform.verify()
    edges = [e for e in bm.edges if e.is_boundary and all(pick(Vector(v[rl])) for v in e.verts)]
    if not edges:
        print("extend: nothing open to extend for", ob.name)
        return
    gi = ob.vertex_groups[bone].index if bone else None
    step = Vector(step)
    for _ in range(rings):
        res = bmesh.ops.extrude_edge_only(bm, edges=edges)
        verts = [g for g in res["geom"] if isinstance(g, bmesh.types.BMVert)]
        c = sum((v.co for v in verts), Vector()) / len(verts)
        for v in verts:
            v.co = c + (v.co - c) * scale + step
            v[rl] = Vector(v[rl]) + step
            if gi is not None:
                v[dl].clear()
                v[dl][gi] = 1.0
        vs = set(verts)
        edges = [g for g in res["geom"] if isinstance(g, bmesh.types.BMEdge) and all(x in vs for x in g.verts)]


def finish(ob, bm, thick=0.003):
    """Faces turned out from her, a thickness inward (the inside's faces marked
    'inner' for the lining), back into the object."""
    tree = _body_tree()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.normal_update()
    score = 0.0
    for f in bm.faces:
        c = f.calc_center_median()
        loc, _, _, _ = tree.find_nearest(c)
        if loc is not None:
            score += f.normal.dot(c - loc)
    if score < 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    _solid(bm, thick)
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()
    return ob


def _solid(bm, thick):
    """A plain thickness: every point copied `thick` in along its normal (no
    shell correction, which spikes at creases), the copies' faces turned
    inward and marked 'inner', and the open edges closed with a rim."""
    bm.normal_update()
    il = bm.faces.layers.float.get("inner") or bm.faces.layers.float.new("inner")
    faces = bm.faces[:]
    rims = [e for e in bm.edges if e.is_boundary]
    twin = {}
    for v in bm.verts[:]:
        n = v.normal if v.normal.length > 1e-6 else Vector((0, 0, 1))
        w = bm.verts.new(v.co - n * thick, v)
        twin[v] = w
    for f in faces:
        f[il] = 0.0
        g = bm.faces.new([twin[v] for v in reversed(f.verts)], f)
        g[il] = 1.0
    for e in rims:
        a, b = e.verts
        f = e.link_faces[0]
        # keep the rim's winding with the face it closes off
        loop = next(l for l in f.loops if l.edge == e)
        if loop.vert == a:
            quad = (b, a, twin[a], twin[b])
        else:
            quad = (a, b, twin[b], twin[a])
        r = bm.faces.new(quad, f)
        r[il] = 0.0
    bm.normal_update()


def tube(name, part, top, hem, rest=True, **kw):
    """garment(), with its inside marked 'inner' and its rest points kept."""
    ob = garment(name, part, top, hem, **kw)
    me = ob.data
    if rest:
        a = me.attributes.new("rest", "FLOAT_VECTOR", "POINT")
        for v in me.vertices:
            a.data[v.index].vector = v.co
    return ob


def blob_mesh(name, part, centre, radii, cut, weights, segs=(24, 14)):
    """An ellipsoid's surface without the faces cut(unit point) picks, given a
    thickness, hung on `weights` ({bone: weight}): the hood, the helmet."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs[0], v_segments=segs[1], radius=1.0)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if cut(f.calc_center_median())], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    for v in bm.verts:
        v.co = Vector((centre[0] + v.co.x * radii[0], centre[1] + v.co.y * radii[1], centre[2] + v.co.z * radii[2]))
    for f in bm.faces:
        f.smooth = True
    bm.normal_update()
    _solid(bm, 0.004)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    a = me.attributes.new("rest", "FLOAT_VECTOR", "POINT")
    for v in me.vertices:
        a.data[v.index].vector = v.co
    me.materials.append(new_mat("npc_%s_%s" % (WHO, part)))
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
    for bone, w in weights.items():
        ob.vertex_groups.new(name=bone).add(list(range(len(me.vertices))), w, "REPLACE")
    ob.parent = arm
    ob.modifiers.new("Armature", "ARMATURE").object = arm
    return ob


def tag(ob, piece):
    """Marks which piece of an outfit these faces are (Paint.piece), before join()."""
    a = ob.data.attributes.new("piece", "FLOAT", "FACE")
    a.data.foreach_set("value", [float(piece)] * len(ob.data.polygons))


def join(parts, name):
    """One object for an outfit: one material, one texture."""
    for o in bpy.data.objects:
        o.select_set(o in parts)
    bpy.context.view_layer.objects.active = parts[0]
    if len(parts) > 1:
        bpy.ops.object.join()
    ob = parts[0]
    ob.name = ob.data.name = name
    me = ob.data
    while len(me.materials) > 1:
        me.materials.pop()
    for p in me.polygons:
        p.material_index = 0
    return ob


def unwrap(ob):
    for o in bpy.data.objects:
        o.select_set(o == ob)
    bpy.context.view_layer.objects.active = ob
    me = ob.data
    while len(me.uv_layers) > 1:
        me.uv_layers.remove(me.uv_layers[-1])
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    me.uv_layers[0].name = "UVMap"
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.006)
    bpy.ops.object.mode_set(mode="OBJECT")


class Paint:
    """The rest-space maths an outfit's texture is worked out from (as
    clothes_graph's): x, y, z, |x|, front (1 on her front), inner (1 on the
    cloth's inside), and the little helpers."""

    def __init__(self, nt):
        self.g = g = NG(nt)
        at = nt.nodes.new("ShaderNodeAttribute")
        at.attribute_name = "rest"
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(at.outputs["Vector"], sep.inputs[0])
        self.x, self.y, self.z = sep.outputs[0], sep.outputs[1], sep.outputs[2]
        self.ax = g.abs(self.x)
        self.front = g.sub(1.0, g.sstep(-0.045, -0.02, self.y))
        inn = nt.nodes.new("ShaderNodeAttribute")
        inn.attribute_name = "inner"
        self.inner = inn.outputs["Fac"]
        pc = nt.nodes.new("ShaderNodeAttribute")
        pc.attribute_name = "piece"
        self.piece = pc.outputs["Fac"]

    def cov(self, d):
        return self.g.sstep(-0.00045, 0.00045, d)

    def edge(self, d, w=0.0008):
        return self.g.band(d, 0.0, w)

    def sine(self, v, period):
        return self.g.op("SINE", self.g.mul(v, 2 * math.pi / period))

    def oval(self, cx, cz, rx, rz, wob=0.2, mirror=False):
        """A ragged oval on the x-z plane: (1 inside, its radius)."""
        g = self.g
        xx = self.ax if mirror else self.x
        r = g.add(g.sqrt(g.add(g.sq(g.div(g.sub(xx, cx), rx)), g.sq(g.div(g.sub(self.z, cz), rz)))),
                  g.mul(wob, self.sine(g.add(self.x, g.mul(self.z, 1.3)), 0.0061)))
        return g.sub(1.0, g.sstep(0.9, 1.0, r)), r


def bake(ob, part, paint, size=OUTFIT_TEX, alpha_from=None):
    """Bakes paint(Paint) (an albedo socket) over ob's UVs into
    assets/textures/npc/<who>/<part>.png and gives ob the plain material
    npc_<who>_<part> the importer builds the toon one from. alpha_from:
    (paint_a, paint_b), the same outfit with two different colours under it;
    wherever they differ the cloth isn't there (alpha 0)."""
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 4
    sc.cycles.device = "CPU"
    sc.cycles.use_denoising = False
    sc.render.bake.margin = 6
    m = bpy.data.materials.new("bake_" + part)
    m.use_nodes = True
    ob.data.materials.clear()
    ob.data.materials.append(m)
    for o in bpy.data.objects:
        o.select_set(o == ob)
    bpy.context.view_layer.objects.active = ob

    def once(fn, name):
        nt = m.node_tree
        nt.nodes.clear()
        P = Paint(nt)
        em = nt.nodes.new("ShaderNodeEmission")
        out = nt.nodes.new("ShaderNodeOutputMaterial")
        nt.links.new(em.outputs[0], out.inputs[0])
        nt.links.new(fn(P), em.inputs[0])
        img = bpy.data.images.new(name, size, size, alpha=False)
        node = nt.nodes.new("ShaderNodeTexImage")
        node.image = img
        nt.nodes.active = node
        bpy.ops.object.bake(type="EMIT")
        return np.array(img.pixels[:], np.float32).reshape(size, size, 4)
    px = once(paint, part)
    if alpha_from:
        a = once(alpha_from[0], part + "_a")
        b = once(alpha_from[1], part + "_b")
        diff = np.abs(a[..., :3] - b[..., :3]).max(-1)
        px[..., 3] = 1.0 - ss(0.15, 0.6, diff)
    else:
        px[..., 3] = 1.0
    write_png(px, part)
    ob.data.materials.clear()
    ob.data.materials.append(new_mat("npc_%s_%s" % (WHO, part)))
    print("baked", part)


# --- the rescue looks -------------------------------------------------------------------

SKIN_PAINT = {"mom": (0.95, 0.76, 0.66), "ophelia": (0.97, 0.845, 0.79)}
WRIST = 0.458   # where her sleeves end (rest |x|), the hand bones start at 0.482


def _arms_torso(lo, wrist=WRIST, neck_drop=0.004):
    """Her torso from `lo` up to the neckline, and her arms to `wrist`."""
    def region(R):
        ax = np.abs(R[:, 0])
        return (R[:, 2] > lo) & (R[:, 2] < _neck_z(ax) - neck_drop) & (ax < wrist)
    return region


def _sleeves(ob, bm, step, rings, scale, bone=True):
    for s, side in ((1, "L"), (-1, "R")):
        extend(ob, bm, lambda r, s=s: r.x * s > WRIST - 0.03, (s * step, 0, 0), rings, scale,
               "J_Bip_%s_Hand" % side if bone else None)


def _collar(ob, bm, step, rings, scale):
    extend(ob, bm, lambda r: r.z > 1.15 and abs(r.x) < 0.11, (0, 0, step), rings, scale)


def captor_marrow():
    """Marrow's: a long coat in near-black wool, lined violet, a high collar
    standing up round her neck, its sleeves down past her wrists over her
    hands, and its skirt to her calves, open a little up the front."""
    part = "captor_marrow"
    ob, bm = shell("Outfit_captor_marrow_Coat", _arms_torso(0.755), part)
    fit(bm, lambda R, N: 0.016 + 0.006 * ss(0.15, 0.35, np.abs(R[:, 0])), smooth=16)
    _sleeves(ob, bm, 0.034, 4, 1.08)
    _collar(ob, bm, 0.017, 3, 1.07)
    finish(ob, bm, 0.0035)
    skirt = tube("Outfit_captor_marrow_Skirt", part, 0.8, 0.26, gap=0.036, gap_top=0.012, flare=0.11,
                 follow=(0.3, 0.7), rows=22, open_front=0.2)
    return join([ob, skirt], "Outfit_captor_marrow_Coat")


def paint_marrow(P):
    g = P.g
    COAT, COAT_D, LINING, LINING_D, BUTTON = (0.022, 0.019, 0.028), (0.008, 0.007, 0.011), (0.16, 0.02, 0.3), (0.07, 0.008, 0.14), (0.42, 0.4, 0.46)
    # a fine twill and long soft folds down the skirt
    twill = g.mul(g.sstep(0.55, 0.95, P.sine(g.add(P.x, g.mul(P.z, 0.7)), 0.004)), 0.25)
    folds = g.mul(g.sstep(0.3, 1.0, P.sine(g.add(P.x, g.mul(P.y, 1.4)), 0.06)), g.mul(0.5, g.sstep(0.8, 0.7, P.z)))
    col = g.mixc(COAT, COAT_D, g.mx(twill, folds))
    # buttoned from her waist to her collar, the edge of the front panel just off-centre
    placket = g.mul(g.mul(g.band(P.x, -0.02, -0.016), P.front), g.sstep(0.78, 0.8, P.z))
    buttons = g.mul(g.mul(g.sub(1.0, g.sstep(0.005, 0.0065, g.sqrt(g.add(g.sq(g.sub(P.x, -0.03)), g.sq(g.sub(g.op("FRACT", g.div(P.z, 0.07)), 0.5)))))), P.front),
                    g.mul(g.sstep(0.8, 0.82, P.z), g.sstep(1.17, 1.15, P.z)))
    col = g.mixc(col, COAT_D, placket)
    col = g.mixc(col, BUTTON, buttons)
    # a belt of the same cloth at her waist
    col = g.mixc(col, COAT_D, g.mul(g.band(P.z, 0.86, 0.9), g.sstep(0.4, 0.3, P.ax)))
    # violet piping where the lining turns: the cuffs, collar and hem
    pipe = g.mx(g.mx(g.band(P.ax, WRIST + 0.12, WRIST + 0.14), g.band(P.z, 1.25, 1.27)), g.band(P.z, 0.26, 0.275))
    col = g.mixc(col, LINING, pipe)
    # inside: violet satin with a soft sheen
    sheen = g.mul(g.sstep(0.2, 1.0, P.sine(g.add(P.z, g.mul(P.x, 0.5)), 0.05)), 0.5)
    lining = g.mixc(LINING, LINING_D, sheen)
    return g.mixc(col, lining, P.inner)


def captor_colony():
    """The colony's: a seamless white jumpsuit from her neck to her ankles and
    wrists, a mock neck, a grey belt."""
    part = "captor_colony"

    def region(R):
        ax = np.abs(R[:, 0])
        return (R[:, 2] > 0.1) & (R[:, 2] < _neck_z(ax) - 0.002) & (ax < WRIST)
    ob, bm = shell("Outfit_captor_colony_Suit", region, part)
    fit(bm, 0.008, smooth=8)
    _collar(ob, bm, 0.012, 2, 1.0)
    _sleeves(ob, bm, 0.012, 1, 0.95, bone=False)
    finish(ob, bm, 0.0025)
    belt = tube("Outfit_captor_colony_Belt", part, 0.812, 0.772, gap=0.012, rows=3)
    return join([ob, belt], "Outfit_captor_colony_Suit")


def paint_colony(P):
    g = P.g
    WHITE, WHITE_D, PANEL, GLOW, GREY = (0.8, 0.82, 0.86), (0.55, 0.58, 0.64), (0.05, 0.055, 0.07), (0.15, 0.95, 1.0), (0.3, 0.33, 0.38)
    col = g.mixc(WHITE, WHITE_D, g.mul(g.sstep(0.6, 1.0, P.sine(g.add(P.x, g.mul(P.z, 0.2)), 0.08)), 0.18))
    # charcoal side panels down her sides and along her arms (not her legs,
    # where her rest y wanders across the front), a cyan strip in them
    upper = g.sstep(0.79, 0.81, P.z)
    side = g.mul(g.band(P.y, -0.017, 0.017), upper)
    col = g.mixc(col, PANEL, side)
    strip = g.mul(g.mul(g.band(P.y, -0.0025, 0.0025), upper), g.sstep(0.22, 0.24, P.ax))
    col = g.mixc(col, GLOW, strip)
    # knee plates
    knee, _ = P.oval(0.07, 0.48, 0.035, 0.04, wob=0.0, mirror=True)
    col = g.mixc(col, GREY, g.mul(knee, P.front))
    # a grey yoke over her shoulders, the belt with its lit buckle, the mock neck
    col = g.mixc(col, GREY, g.sstep(1.13, 1.14, g.add(P.z, g.mul(P.ax, 0.25))))
    col = g.mixc(col, GREY, g.band(P.z, 0.772, 0.812))
    col = g.mixc(col, GLOW, g.mul(g.mul(g.band(P.x, -0.016, 0.016), g.band(P.z, 0.782, 0.802)), P.front))
    col = g.mixc(col, GREY, g.sstep(1.2, 1.21, P.z))
    # the seal over her heart: a lit ring, and the front seam
    r = g.sqrt(g.add(g.sq(g.sub(P.x, 0.075)), g.sq(g.sub(P.z, 1.07))))
    col = g.mixc(col, GLOW, g.mul(g.band(r, 0.011, 0.016), P.front))
    col = g.mixc(col, WHITE_D, g.mul(g.mul(g.band(P.x, -0.0008, 0.0008), P.front), g.sstep(0.8, 0.81, P.z)))
    # cuffs and ankles in grey
    col = g.mixc(col, GREY, g.mx(g.sstep(WRIST - 0.02, WRIST - 0.015, P.ax), g.sstep(0.135, 0.13, P.z)))
    return g.mixc(col, WHITE_D, P.inner)


def captor_cutter():
    """Cutter's: his oversized grey hoodie down over her hips, baggy sleeves
    pushed to her wrists, its hood down at her back; ripped jeans."""
    part = "captor_cutter"
    ob, bm = shell("Outfit_captor_cutter_Hoodie", _arms_torso(0.79), part)
    fit(bm, lambda R, N: 0.026 + 0.012 * ss(0.12, 0.3, np.abs(R[:, 0])), smooth=22, hold=0.6)
    _sleeves(ob, bm, 0.012, 1, 0.9, bone=False)
    extend(ob, bm, lambda r: r.z < 0.85, (0, 0, -0.035), 3, 1.015)   # the hem, down over her hips
    _collar(ob, bm, 0.008, 1, 1.04)
    finish(ob, bm, 0.004)

    def legs(R):
        return (R[:, 2] < 0.81) & (R[:, 2] > 0.105)
    jeans, bm = shell("Outfit_captor_cutter_Jeans", legs, part)
    fit(bm, lambda R, N: 0.008 + 0.008 * ss(0.6, 0.3, R[:, 2]), smooth=8)
    finish(jeans, bm, 0.003)
    # the hood, down between her shoulder blades
    co = np.array([v.co[:] for v in bpy.data.objects["Body"].data.vertices])
    back = co[(np.abs(co[:, 0]) < 0.04) & (np.abs(co[:, 2] - 1.14) < 0.03)][:, 1].max()
    tag(ob, 0)
    tag(jeans, 1)
    hood = blob_mesh("Outfit_captor_cutter_Hood", part, (0.0, back + 0.075, 1.15), (0.11, 0.045, 0.085),
                     lambda c: c.z > 0.35 and c.y < 0.55, {"J_Bip_C_UpperChest": 0.75, "J_Bip_C_Neck": 0.25})
    tag(hood, 0)
    return join([ob, jeans, hood], "Outfit_captor_cutter_Clothes")


def paint_cutter(P, skin):
    g = P.g
    GREY, GREY_D, RED, DENIM, DENIM_L, THREAD = (0.16, 0.155, 0.17), (0.08, 0.078, 0.088), (0.6, 0.03, 0.03), (0.035, 0.055, 0.14), (0.12, 0.17, 0.3), (0.75, 0.75, 0.72)
    knit = g.mul(g.sstep(0.0, 1.0, P.sine(g.add(P.z, g.mul(P.ax, 0.4)), 0.11)), 0.18)   # soft bands of fold
    grey = g.mixc(GREY, GREY_D, knit)
    # his two red stripes along the top of each sleeve and down the hood
    arm_top = g.sub(P.z, 1.145)
    stripes = g.mul(g.mx(g.band(arm_top, 0.044, 0.052), g.band(arm_top, 0.058, 0.066)), g.sstep(0.12, 0.14, P.ax))
    hood_st = g.mul(g.mx(g.band(P.x, -0.022, -0.014), g.band(P.x, 0.014, 0.022)), g.mul(g.sstep(0.05, 0.08, P.y), g.sstep(1.08, 1.1, P.z)))
    grey = g.mixc(grey, RED, g.mx(stripes, hood_st))
    # the kangaroo pocket and drawstrings
    pocket = g.mul(g.mul(g.band(P.ax, 0.0, 0.085), g.band(P.z, 0.79, 0.9)), P.front)
    pocket_edge = g.mul(g.sub(1.0, g.band(P.ax, 0.0, 0.082)), pocket)
    grey = g.mixc(grey, GREY_D, pocket_edge)
    strings = g.mul(g.mul(g.mx(g.band(P.x, -0.028, -0.024), g.band(P.x, 0.024, 0.028)), g.band(P.z, 1.04, 1.17)), P.front)
    grey = g.mixc(grey, (0.7, 0.7, 0.7), strings)
    grey = g.mixc(grey, GREY_D, g.mx(g.sstep(WRIST - 0.03, WRIST - 0.02, P.ax), g.band(P.z, 0.69, 0.715)))
    # jeans: twill, faded down the thighs, seams, rips at both knees and her left thigh
    twill = g.mul(g.sstep(0.4, 1.0, P.sine(g.add(P.z, g.mul(P.x, 0.9)), 0.003)), 0.3)
    fade = g.mul(g.mul(g.sstep(0.75, 0.55, P.z), g.sstep(0.4, 0.5, P.z)), g.mul(P.front, 0.6))
    jeans = g.mixc(g.mixc(DENIM, DENIM_L, fade), DENIM, twill)
    # the waistband and its brass button
    jeans = g.mixc(jeans, DENIM, g.band(P.z, 0.775, 0.81))
    jeans = g.mixc(jeans, (0.45, 0.32, 0.12), g.mul(g.mul(g.band(P.x, -0.007, 0.007), g.band(P.z, 0.785, 0.8)), P.front))
    r1, rr1 = P.oval(0.069, 0.47, 0.035, 0.022, mirror=True)
    r2, rr2 = P.oval(0.085, 0.62, 0.022, 0.04)
    rips = g.mul(g.mx(r1, r2), P.front)
    threads = g.mul(g.mul(g.sstep(0.2, 0.9, P.sine(P.z, 0.006)), rips), 0.85)
    jeans = g.mixc(jeans, skin, rips)
    jeans = g.mixc(jeans, THREAD, threads)
    jeans = g.mixc(jeans, THREAD, g.mul(g.mul(g.mx(g.band(rr1, 0.95, 1.08), g.band(rr2, 0.95, 1.08)), P.front), 0.7))
    col = g.mixc(grey, jeans, P.piece)   # tag(): the jeans are piece 1
    return g.mixc(col, g.mixc(col, (0, 0, 0), 0.4), P.inner)


def captor_outfits(arm):
    """Builds all three looks; returns [(object, part, paint)] for bake_outfits()."""
    skin = SKIN_PAINT[WHO]
    return [
        (captor_marrow(), "captor_marrow", paint_marrow),
        (captor_colony(), "captor_colony", paint_colony),
        (captor_cutter(), "captor_cutter", lambda P: paint_cutter(P, skin)),
    ]


# --- Ophelia's intake suit in Level 2 ----------------------------------------------------

def _ragged(base, amp, p1, p2, v, y):
    return base + amp * np.sin(v * 2 * math.pi / p1) + amp * 0.4 * np.sin((v - y * 1.3) * 2 * math.pi / p2)


def prison_suit(arm):
    """Ophelia's torn intake suit (colony_outfit(), "colony_m") as cloth: where
    body_colony_m.png paints the suit, a little in from its edges (the paint
    under it carries on to them). The rips come out of its texture."""
    part = "colony_m_suit"

    def region(R):
        x, y, z = R[:, 0], R[:, 1], R[:, 2]
        ax = np.abs(x)
        cuff = np.where(x > 0, _ragged(0.452, 0.01, 0.023, 0.0091, y + z, y), _ragged(0.205, 0.012, 0.029, 0.0111, y + z, y)) - 0.012
        leg_cut = _ragged(0.6, 0.012, 0.027, 0.0101, y + x, y) + 0.012
        torn_leg = (x > 0.0) & (z < leg_cut)
        return (z < _neck_z(ax) - 0.006) & (z > 0.118) & (ax < cuff) & ~torn_leg
    ob, bm = shell("Outfit_colony_m_Suit", region, part)
    fit(bm, 0.0045, smooth=4, hold=0.8)
    finish(ob, bm, 0.0022)
    belt = tube("Outfit_colony_m_Belt", part, 0.808, 0.772, gap=0.01, rows=3)
    return join([ob, belt], "Outfit_colony_m_Suit")


def paint_prison(skin):
    def paint(P):
        global OUTFIT
        OUTFIT = "colony_m"
        neck_r = P.g.sqrt(P.g.add(P.g.sq(P.x), P.g.sq(P.g.sub(P.y, 0.022))))
        col = colony_outfit(P.g, skin, P.x, P.y, P.z, P.ax, P.front, P.cov, P.edge, P.sine, neck_r)
        return P.g.mixc(col, P.g.mixc(col, (0, 0, 0), 0.35), P.inner)
    return paint


def bake_outfits(made):
    global OUTFIT
    for ob, part, paint, *alpha in made:
        unwrap(ob)
        bake(ob, part, paint, alpha_from=alpha[0] if alpha else None)
    OUTFIT = OUTFITS.get(WHO, ["default"])[0]


# --- the colony orderlies ------------------------------------------------------------------

def body_orderly():
    """Lean and square: no bust, narrower hips, a little more shoulder."""
    def amount(P, N):
        z = P[:, 2]
        out = N[:, 0] * np.sign(P[:, 0])
        bust = -0.05 * gauss(P, 0.06, -0.11, 1.03, 0.07, 0.07, 0.07) * ss(-0.02, -0.06, P[:, 1])
        hips = -0.02 * np.exp(-((z - 0.74) / 0.1) ** 2) * np.clip(out, 0, 1)
        glute = -0.012 * np.exp(-((np.abs(P[:, 0]) - 0.064) / 0.06) ** 2 - ((z - 0.755) / 0.08) ** 2) * ss(-0.02, 0.04, P[:, 1])
        shoulder = 0.008 * np.exp(-((np.abs(P[:, 0]) - 0.12) / 0.05) ** 2 - ((z - 1.15) / 0.06) ** 2)
        nip = -0.01 * gauss(P, 0.056, -0.12, 1.049, 0.015, 0.03, 0.015)
        return bust + hips + glute + shoulder + nip
    print("orderly body: up to %.1f mm" % (push(bpy.data.objects["Body"], amount, passes=8) * 1000))


def orderly_suit(arm):
    """Everything of the preset under a loose white suit, belted: gloves, shoe
    covers, and a faceless helmet with a black visor over its head."""
    part = "suit"
    ob, bm = shell("Suit", lambda R: np.ones(len(R), bool), part)
    # loose: most of all over the chest and seat, where it hangs straight
    fit(bm, lambda R, N: 0.011 + 0.02 * ss(0.62, 0.8, R[:, 2]) * ss(1.2, 1.1, R[:, 2]) * ss(0.2, 0.12, np.abs(R[:, 0])), smooth=36, hold=0.5)
    relax(bm, lambda R: (np.abs(R[:, 0]) < 0.13) & (np.abs(R[:, 2] - 1.04) < 0.08) & (R[:, 1] < -0.03))
    finish(ob, bm, 0.003)
    belt = tube("Belt", part, 0.82, 0.785, gap=0.026, rows=3)
    tag(ob, 0)
    tag(belt, 2)
    face = bpy.data.objects["Face"]
    fc = np.array([v.co[:] for v in face.data.vertices])
    hair = bpy.data.objects.get("Hair")
    lo, hi = fc.min(0), fc.max(0)
    c = (lo + hi) / 2
    r = (hi - lo) / 2 * 1.08 + 0.012
    helmet = blob_mesh("Helmet", part, (0.0, c[1], c[2] + 0.004), (r[0], r[1], r[2]), lambda q: q.z < -0.82,
                       {"J_Bip_C_Head": 1.0}, segs=(32, 18))
    for o in [face] + ([hair] if hair else []):
        bpy.data.objects.remove(o)
    tag(helmet, 0)
    return join([ob, belt, helmet], "Suit")


def paint_orderly(P):
    g = P.g
    WHITE, WHITE_D, GREY, PANEL, VISOR, GLOW = (0.78, 0.8, 0.84), (0.5, 0.53, 0.58), (0.28, 0.3, 0.34), (0.08, 0.085, 0.1), (0.008, 0.008, 0.012), (0.15, 0.95, 1.0)
    col = g.mixc(WHITE, WHITE_D, g.mul(g.sstep(0.6, 1.0, P.sine(g.add(P.x, g.mul(P.z, 0.2)), 0.08)), 0.15))
    col = g.mixc(col, GREY, g.band(P.y, -0.012, 0.012))                       # side seams
    belt = g.sstep(1.5, 1.6, P.piece)                                         # tag(): the belt is 2
    col = g.mixc(col, PANEL, belt)
    col = g.mixc(col, GLOW, g.mul(g.mul(g.band(P.x, -0.016, 0.016), belt), P.front))
    col = g.mixc(col, GREY, g.sstep(0.44, 0.45, P.ax))                        # gloves
    col = g.mixc(col, PANEL, g.sstep(0.125, 0.115, P.z))                      # shoe covers
    col = g.mixc(col, GREY, g.mul(g.band(P.z, 1.19, 1.215), g.sstep(1.25, 1.2, P.z)))   # helmet seal
    # the visor: a black band round the front of the helmet, no face behind it
    visor = g.mul(g.mul(g.band(P.z, 1.235, 1.33), g.sstep(-0.03, -0.06, P.y)), g.sstep(1.18, 1.2, P.z))
    col = g.mixc(col, VISOR, visor)
    col = g.mixc(col, GLOW, g.mul(g.mul(g.band(P.z, 1.229, 1.234), g.sstep(-0.03, -0.06, P.y)), 0.8))
    # a colony ring on the back
    br = g.sqrt(g.add(g.sq(P.x), g.sq(g.sub(P.z, 1.02))))
    col = g.mixc(col, PANEL, g.mul(g.band(br, 0.04, 0.048), g.sstep(0.012, 0.04, P.y)))
    return g.mixc(col, WHITE_D, P.inner)


def main_orderly():
    os.makedirs(TEX_OUT, exist_ok=True)
    E["HEIGHT"], E["HEAD_SCALE"], E["LEG_SCALE"] = SPEC["height"], SPEC["head"], SPEC["legs"]
    arm = E["setup_scene"]()
    E["remove_fox_parts"]()
    boots = strip_clothes()
    bpy.data.objects.remove(boots)
    body_orderly()
    suit = orderly_suit(arm)
    bpy.data.objects.remove(bpy.data.objects["Body"])
    bake_outfits([(suit, "suit", paint_orderly)])
    objs = [suit]
    prune_bones(arm)
    E["proportions"](arm, objs)
    E["face_forward_and_scale"](arm, objs)
    make_actions(arm)
    if CONCEPT:
        concept(arm, objs)
    if EXPORT:
        if "rest" in suit.data.attributes:
            suit.data.attributes.remove(suit.data.attributes["rest"])
        for o in bpy.data.objects:
            o.select_set(o == arm or o in objs)
        bpy.ops.export_scene.gltf(filepath=GLB_OUT, export_format="GLB", use_selection=True,
                                  export_animations=True, export_animation_mode="ACTIONS", export_skins=True,
                                  export_morph=False, export_materials="EXPORT", export_image_format="NONE",
                                  export_yup=True, export_apply=False)
        print("exported", GLB_OUT)
