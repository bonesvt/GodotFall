"""Modelling helpers for the Blender titan builds (tools/titans/build_titans.py).

Everything is authored in Godot's frame (x right, y up, -z forward, metres)
and converted on the way into Blender, so the numbers match the game code.
Shapes are bmesh primitives with real bevels (rounded, chunky hulls), tubes
are curves turned into meshes (roll cages, exhausts, hoses), and the finished
meshes get ambient occlusion and edge convexity baked into vertex colours for
assets/shaders/titan_paint.gdshader.
"""
import math
import random

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

# Godot (x, y, z) -> Blender (x, -z, y)
G2B = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
B2G = G2B.inverted()


def reset(materials):
	"""Empty scene with one placeholder material per name -> (rgb, emission)."""
	bpy.ops.wm.read_factory_settings(use_empty=True)
	for name, spec in materials.items():
		add_material(name, spec)


def add_material(name, spec):
	rgb = spec[0] if isinstance(spec[0], (tuple, list)) else spec
	m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
	m.diffuse_color = (*rgb, 1.0)
	m.use_nodes = True
	bsdf = m.node_tree.nodes.get("Principled BSDF")
	bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
	if isinstance(spec[0], (tuple, list)) and len(spec) > 1:
		bsdf.inputs["Emission Color"].default_value = (*spec[1], 1.0)
		bsdf.inputs["Emission Strength"].default_value = 1.0
	return m


def xform(pos=(0, 0, 0), rot_deg=(0, 0, 0), scale=(1, 1, 1)):
	"""A Godot-frame transform (rotation X then Y then Z, in degrees)."""
	r = Matrix.Rotation(math.radians(rot_deg[2]), 4, "Z") @ Matrix.Rotation(math.radians(rot_deg[1]), 4, "Y") @ Matrix.Rotation(math.radians(rot_deg[0]), 4, "X")
	return Matrix.Translation(Vector(pos)) @ r @ Matrix.Diagonal((*scale, 1.0))


# --- the part list -------------------------------------------------------------

class Model:
	"""Collects pieces into named groups; each group becomes one object."""

	def __init__(self):
		self.groups = {}

	def add(self, group, bm, mats, local=None, smooth=True):
		"""Adds a bmesh (Godot coords) to `group`. mats: list of material names,
		indexed by the faces' material_index."""
		if isinstance(mats, str):
			mats = [mats]
		if local is not None:
			bmesh.ops.transform(bm, matrix=local, verts=bm.verts)
		for f in bm.faces:
			f.smooth = smooth
		self.groups.setdefault(group, []).append((bm, mats))
		return bm

	def build(self, ao=True):
		"""Turns every group into a Blender object (Godot coords converted)."""
		objs = {}
		for group, pieces in self.groups.items():
			me = bpy.data.meshes.new(group)
			mat_names = []
			out = bmesh.new()
			for bm, mats in pieces:
				remap = []
				for m in mats:
					if m not in mat_names:
						mat_names.append(m)
					remap.append(mat_names.index(m))
				for f in bm.faces:
					f.material_index = remap[min(f.material_index, len(remap) - 1)]
				tmp = bpy.data.meshes.new("tmp")
				bm.to_mesh(tmp)
				bm.free()
				out.from_mesh(tmp)
				bpy.data.meshes.remove(tmp)
			bmesh.ops.transform(out, matrix=G2B, verts=out.verts)
			out.to_mesh(me)
			out.free()
			for m in mat_names:
				me.materials.append(bpy.data.materials[m])
			me.use_auto_smooth = True
			me.auto_smooth_angle = math.radians(38)
			ob = bpy.data.objects.new(group, me)
			bpy.context.collection.objects.link(ob)
			objs[group] = ob
		if ao:
			bake_vertex_colors(list(objs.values()))
		return objs


# --- primitives (all return a fresh bmesh in Godot coords) -------------------------

def rbox(size, center=(0, 0, 0), r=0.1, seg=3, shape=None, rot=(0, 0, 0)):
	"""Rounded box. `shape(v)` may move vertices of the unit-ish box (in local
	coords, before the bevel) to taper or wedge it."""
	bm = bmesh.new()
	bmesh.ops.create_cube(bm, size=1.0)
	bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
	if shape is not None:
		for v in bm.verts:
			shape(v.co, Vector(size) * 0.5)
	r = min(r, min(size) * 0.49)
	if r > 0.0:
		bmesh.ops.bevel(bm, geom=bm.edges[:] + bm.verts[:], offset=r, offset_type="OFFSET",
			segments=seg, profile=0.5, affect="EDGES", clamp_overlap=True)
	bmesh.ops.transform(bm, matrix=xform(center, rot), verts=bm.verts)
	return bm


def smooth(size, center=(0, 0, 0), shape=None, cuts=2, levels=2, rot=(0, 0, 0)):
	"""Sleek subdivision-surface body. A box cage of `size`, split `cuts` times
	per edge, is bent by `shape(co, half)` (local coords) and then smoothed
	Catmull-Clark style, so a handful of moved cage points give flowing,
	car-body curves."""
	bm = bmesh.new()
	bmesh.ops.create_cube(bm, size=1.0)
	if cuts > 0:
		bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=cuts, use_grid_fill=True)
	bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
	if shape is not None:
		half = Vector(size) * 0.5
		for v in bm.verts:
			shape(v.co, half)
	me = bpy.data.meshes.new("cage")
	bm.to_mesh(me)
	bm.free()
	ob = bpy.data.objects.new("cage", me)
	bpy.context.collection.objects.link(ob)
	mod = ob.modifiers.new("Sub", "SUBSURF")
	mod.levels = levels
	mod.render_levels = levels
	dg = bpy.context.evaluated_depsgraph_get()
	out = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
	bm = bmesh.new()
	bm.from_mesh(out)
	bpy.data.objects.remove(ob)
	bpy.data.meshes.remove(me)
	bpy.data.meshes.remove(out)
	bmesh.ops.transform(bm, matrix=xform(center, rot), verts=bm.verts)
	return bm


def cyl(r, depth, center=(0, 0, 0), axis="y", seg=16, bevel=0.0, r2=None, rot=None):
	"""Cylinder (or cone with r2) along a Godot axis, optionally bevelled."""
	bm = bmesh.new()
	bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r,
		radius2=r if r2 is None else r2, depth=depth)
	# create_cone builds along local z; point it along the wanted Godot axis.
	if bevel > 0.0:
		caps = [e for e in bm.edges if all(len(v.link_edges) == 3 for v in e.verts) and abs(e.verts[0].co.z - e.verts[1].co.z) < 1e-6]
		bmesh.ops.bevel(bm, geom=caps, offset=min(bevel, depth * 0.45), offset_type="OFFSET",
			segments=2, profile=0.5, affect="EDGES", clamp_overlap=True)
	base = {"z": (0, 0, 0), "x": (0, 90, 0), "y": (90, 0, 0)}[axis]
	bmesh.ops.transform(bm, matrix=xform((0, 0, 0), base), verts=bm.verts)
	if rot is not None:
		bmesh.ops.transform(bm, matrix=xform((0, 0, 0), rot), verts=bm.verts)
	bmesh.ops.translate(bm, vec=Vector(center), verts=bm.verts)
	return bm


def sphere(r, center=(0, 0, 0), scale=(1, 1, 1), seg=12, rings=8):
	bm = bmesh.new()
	bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=r)
	bmesh.ops.transform(bm, matrix=xform(center, (0, 0, 0), scale), verts=bm.verts)
	return bm


def tire(r, width, center=(0, 0, 0), axis="x", seg=20, tread=0.05):
	"""Chunky treaded tyre: a rounded cylinder with alternate faces pushed out."""
	bm = bmesh.new()
	bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r - tread, radius2=r - tread, depth=width)
	side = [f for f in bm.faces if len(f.verts) == 4]
	res = bmesh.ops.inset_individual(bm, faces=side, thickness=width * 0.08, depth=0.0)
	for i, f in enumerate(side):
		if i % 2 == 0:
			n = f.normal.copy()
			for v in f.verts:
				v.co += n * tread * 2.0
	caps = [e for e in bm.edges if e.is_boundary is False and abs(e.verts[0].co.z - e.verts[1].co.z) < 1e-6 and abs(abs(e.verts[0].co.z) - width * 0.5) < 1e-5]
	try:
		bmesh.ops.bevel(bm, geom=caps, offset=width * 0.18, offset_type="OFFSET", segments=2, profile=0.6, affect="EDGES", clamp_overlap=True)
	except RuntimeError:
		pass
	base = {"z": (0, 0, 0), "x": (0, 90, 0), "y": (90, 0, 0)}[axis]
	bmesh.ops.transform(bm, matrix=xform(center, base), verts=bm.verts)
	return bm


def gear(r, width, teeth=12, center=(0, 0, 0), axis="x"):
	bm = bmesh.new()
	bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=teeth * 2, radius1=r, radius2=r, depth=width)
	side = [f for f in bm.faces if len(f.verts) == 4]
	ext = bmesh.ops.extrude_discrete_faces(bm, faces=side[::2])
	for f in ext["faces"]:
		n = f.normal.copy()
		for v in f.verts:
			v.co += n * r * 0.18
	base = {"z": (0, 0, 0), "x": (0, 90, 0), "y": (90, 0, 0)}[axis]
	bmesh.ops.transform(bm, matrix=xform(center, base), verts=bm.verts)
	return bm


def tube(points, r, seg=8, closed=False, smooth_path=True, res=6):
	"""Tube along Godot-space points (a bent pipe). Returns a bmesh."""
	cu = bpy.data.curves.new("tube", "CURVE")
	cu.dimensions = "3D"
	cu.bevel_depth = r
	cu.bevel_resolution = max(1, seg // 4 - 1)
	cu.use_fill_caps = True
	cu.resolution_u = res
	if smooth_path:
		sp = cu.splines.new("BEZIER")
		sp.bezier_points.add(len(points) - 1)
		for bp, p in zip(sp.bezier_points, points):
			bp.co = G2B @ Vector(p)
			bp.handle_left_type = "AUTO"
			bp.handle_right_type = "AUTO"
	else:
		sp = cu.splines.new("POLY")
		sp.points.add(len(points) - 1)
		for pt, p in zip(sp.points, points):
			pt.co = (*(G2B @ Vector(p)), 1.0)
	sp.use_cyclic_u = closed
	ob = bpy.data.objects.new("tube", cu)
	bpy.context.collection.objects.link(ob)
	dg = bpy.context.evaluated_depsgraph_get()
	me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
	bm = bmesh.new()
	bm.from_mesh(me)
	bmesh.ops.transform(bm, matrix=B2G, verts=bm.verts)
	bpy.data.objects.remove(ob)
	bpy.data.curves.remove(cu)
	bpy.data.meshes.remove(me)
	bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
	return bm


def merge(*bms):
	"""Merges bmeshes into the first one (all single-material)."""
	out = bms[0]
	for b in bms[1:]:
		tmp = bpy.data.meshes.new("tmp")
		b.to_mesh(tmp)
		b.free()
		out.from_mesh(tmp)
		bpy.data.meshes.remove(tmp)
	return out


def rivets(points, r=0.035, normal=(0, 0, -1)):
	"""Flattened domes at each point, squashed along `normal`."""
	n = Vector(normal).normalized()
	rot = n.to_track_quat("Z", "Y").to_matrix().to_4x4()
	out = None
	for p in points:
		b = bmesh.new()
		bmesh.ops.create_uvsphere(b, u_segments=6, v_segments=4, radius=r)
		bmesh.ops.transform(b, matrix=Matrix.Translation(Vector(p)) @ rot @ Matrix.Diagonal((1, 1, 0.45, 1)), verts=b.verts)
		out = b if out is None else merge(out, b)
	return out


def hit(target, p, direction):
	"""Where a ray from `p` (backed off 4 m) along `direction` meets `target`:
	(location, normal), or (None, None) on a miss."""
	d = Vector(direction).normalized()
	loc, n, _, _ = BVHTree.FromBMesh(target).ray_cast(Vector(p) - d * 4.0, d, 8.0)
	return (loc, n) if loc is not None else (None, None)


def studs(target, points, direction, r=0.035):
	"""Rivets stuck onto the surface of `target` (a bmesh already in place):
	each point is pushed along `direction` until it meets the surface, and the
	dome sits flat on it. Points that miss are dropped."""
	tree = BVHTree.FromBMesh(target)
	d = Vector(direction).normalized()
	out = None
	for p in points:
		loc, n, _, _ = tree.ray_cast(Vector(p) - d * 1.5, d, 3.0)
		if loc is None:
			continue
		rot = n.to_track_quat("Z", "Y").to_matrix().to_4x4()
		b = bmesh.new()
		bmesh.ops.create_uvsphere(b, u_segments=6, v_segments=4, radius=r)
		bmesh.ops.transform(b, matrix=Matrix.Translation(loc) @ rot @ Matrix.Diagonal((1, 1, 0.45, 1)), verts=b.verts)
		out = b if out is None else merge(out, b)
	return out if out is not None else bmesh.new()


def row(a, b, n):
	a, b = Vector(a), Vector(b)
	return [a.lerp(b, i / max(1, n - 1)) for i in range(n)]


# --- paint bands -----------------------------------------------------------------

def band(bm, axis, lo, hi, index, where=None):
	"""Paints faces whose centre lies in [lo, hi] along `axis` (0, 1, 2) with
	material `index`, after cutting the mesh at lo and hi so the stripe has a
	clean edge. `where(center, normal)` can limit it to some faces."""
	for cut in (lo, hi):
		no = Vector((0, 0, 0))
		no[axis] = 1.0
		co = Vector((0, 0, 0))
		co[axis] = cut
		geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
		bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-5, plane_co=co, plane_no=no)
	bm.normal_update()
	for f in bm.faces:
		c = f.calc_center_median()
		if lo <= c[axis] <= hi and (where is None or where(c, f.normal)):
			f.material_index = index
	return bm


def dent(bm, center, radius, depth, seed=0):
	"""Pushes vertices near `center` inward (along -normal) with a bit of noise."""
	rnd = random.Random(seed)
	bm.normal_update()
	c = Vector(center)
	for v in bm.verts:
		d = (v.co - c).length
		if d < radius:
			k = (1.0 - d / radius) ** 2
			v.co -= v.normal * depth * k * (0.7 + rnd.random() * 0.6)
	return bm


def jitter(bm, amount, seed=0):
	rnd = random.Random(seed)
	for v in bm.verts:
		v.co += Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1))) * amount
	return bm


# --- hierarchy -------------------------------------------------------------------

def empty(name, pos, parent=None):
	"""Pivot node at a Godot-space world position."""
	e = bpy.data.objects.new(name, None)
	e.empty_display_size = 0.2
	bpy.context.collection.objects.link(e)
	e.matrix_world = G2B @ Matrix.Translation(Vector(pos)) @ B2G
	if parent is not None:
		set_parent(e, parent)
	return e


def set_parent(child, parent):
	"""Parents keeping the world placement, with the offset baked into the
	child's own transform (or mesh data) so glTF gets clean local transforms."""
	world = child.matrix_world.copy()
	child.parent = parent
	child.matrix_parent_inverse = Matrix.Identity(4)
	local = parent.matrix_world.inverted() @ world
	if child.type == "MESH":
		child.data.transform(local)
		child.matrix_basis = Matrix.Identity(4)
	else:
		child.matrix_basis = local


# --- baking ----------------------------------------------------------------------

def _hemisphere(n, count, rnd):
	dirs = []
	t = n.orthogonal().normalized()
	b = n.cross(t)
	for i in range(count):
		u = (i + rnd.random()) / count
		phi = rnd.random() * math.tau
		z = math.sqrt(1.0 - u)
		s = math.sqrt(u)
		dirs.append((t * (math.cos(phi) * s) + b * (math.sin(phi) * s) + n * z).normalized())
	return dirs


def bake_vertex_colors(objs, rays=20, dist=1.4):
	"""R = ambient occlusion against every object; G = edge convexity."""
	rnd = random.Random(3)
	verts, polys = [], []
	for ob in objs:
		me = ob.data
		off = len(verts)
		verts.extend(ob.matrix_world @ v.co for v in me.vertices)
		polys.extend([off + i for i in p.vertices] for p in me.polygons)
	tree = BVHTree.FromPolygons(verts, polys, epsilon=0.0)
	for ob in objs:
		me = ob.data
		bm = bmesh.new()
		bm.from_mesh(me)
		bm.normal_update()
		ao, conv = [], []
		for v in bm.verts:
			n = v.normal
			p = ob.matrix_world @ v.co + n * 0.01
			hit = 0.0
			for d in _hemisphere(n, rays, rnd):
				loc, _, _, h = tree.ray_cast(p, d, dist)
				if loc is not None:
					hit += 1.0 - (h / dist) ** 0.5 * 0.6
			ao.append(1.0 - hit / rays)
			s, k = 0.0, 0
			for e in v.link_edges:
				o = e.other_vert(v)
				dv = o.co - v.co
				if dv.length > 1e-6:
					s += -n.dot(dv.normalized())
					k += 1
			conv.append(max(0.0, min(1.0, (s / max(k, 1)) * 3.0)))
		bm.free()
		attr = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
		for i, (a, c) in enumerate(zip(ao, conv)):
			attr.data[i].color = (a, c, 0.0, 1.0)
		me.color_attributes.active_color = attr
		me.color_attributes.render_color_index = 0


def export(path):
	bpy.ops.object.select_all(action="SELECT")
	bpy.ops.export_scene.gltf(
		filepath=path, export_format="GLB", use_selection=False, export_apply=True,
		export_yup=True, export_texcoords=False, export_normals=True, export_colors=True,
		export_materials="EXPORT",
	)
	dg = bpy.context.evaluated_depsgraph_get()
	tris = sum(len(o.evaluated_get(dg).to_mesh().loop_triangles) for o in bpy.data.objects if o.type == "MESH")
	print("exported", path, "triangles", tris)
