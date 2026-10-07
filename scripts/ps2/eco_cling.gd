extends RefCounted
## Clothes that cling to her: her chest and glutes swing and squash on their
## own spring bones (J_Sec_*Bust*, J_Sec_*Glute*; eco_model.gd), but most of
## her clothes were weighted to the bones under them only (a skirt to her
## hips and thighs), so a bouncing or pressed glute could poke through the
## skirt over it. This copies the skin's soft weights onto every clothing
## mesh (base_*, outfit_*): each cloth vertex takes the bust and glute
## weights of the nearest vertex of her Body within REACH, fading out with
## distance, so the cloth rides every swing and squash of the skin under it.
## Weights a mesh already has on a bone (her jackets' bust) are kept as they are.
##
##   EcoCling.reweight(mi, skeleton)   # [mesh, skin] to put on the instance, or []

## How far from her skin a cloth vertex still follows it (m), and where the
## follow starts fading.
const REACH := 0.06
const FULL := 0.025
const CELL := 0.06
const PREFIXES := ["base_", "outfit_"]

## Reweighted meshes, shared by every Eco: "<mesh id>:<skin id>" -> [mesh, skin] (or [null, null]).
static var _cache := {}
## Her skin's soft vertices: skeleton id -> {cell: [[position, {bone: weight}], ...]}.
static var _skin := {}


static func clothing(mi: MeshInstance3D) -> bool:
	if mi.mesh == null or mi.skin == null or not mi.mesh is ArrayMesh:
		return false
	for p: String in PREFIXES:
		if String(mi.name).begins_with(p):
			return true
	return false


static func reweight(mi: MeshInstance3D, sk: Skeleton3D) -> Array:
	if not clothing(mi):
		return []
	var key := "%d:%d" % [mi.mesh.get_instance_id(), mi.skin.get_instance_id()]
	if not _cache.has(key):
		var grid := _soft_skin(sk)
		_cache[key] = [null, null] if grid.is_empty() else _build(mi.mesh as ArrayMesh, mi.skin, sk, sk.global_transform.affine_inverse() * mi.global_transform, grid)
	var hit: Array = _cache[key]
	return [] if hit[0] == null else hit


static func _soft_bone(sk: Skeleton3D, bone: int) -> bool:
	var n := sk.get_bone_name(bone)
	return n.begins_with("J_Sec_") and ("Bust" in n or "Glute" in n)


## Her Body's vertices that carry soft weight, bucketed by CELL, in skeleton space.
static func _soft_skin(sk: Skeleton3D) -> Dictionary:
	var id := sk.get_instance_id()
	if _skin.has(id):
		return _skin[id]
	var grid := {}
	var body := sk.find_child("Body", false, false) as MeshInstance3D
	if body != null and body.mesh is ArrayMesh and body.skin != null:
		var to_sk := sk.global_transform.affine_inverse() * body.global_transform
		var skin := body.skin
		for s in body.mesh.get_surface_count():
			var arrays := body.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			if arrays[Mesh.ARRAY_BONES] == null:
				continue
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var per := bones.size() / maxi(verts.size(), 1)
			for v in verts.size():
				var soft := {}
				for k in per:
					var w := weights[v * per + k]
					if w <= 0.01:
						continue
					var bone := _bone_of(skin, sk, bones[v * per + k])
					if bone >= 0 and _soft_bone(sk, bone):
						soft[bone] = float(soft.get(bone, 0.0)) + w
				if soft.is_empty():
					continue
				var p := to_sk * verts[v]
				var c := Vector3i((p / CELL).floor())
				if not grid.has(c):
					grid[c] = []
				grid[c].append([p, soft])
	_skin[id] = grid
	return grid


static func _bone_of(skin: Skin, sk: Skeleton3D, bind: int) -> int:
	var n := skin.get_bind_name(bind)
	return sk.find_bone(n) if String(n) != "" else skin.get_bind_bone(bind)


## The soft weights of the skin nearest `p` within REACH, faded by distance ({} if none).
static func _nearest(grid: Dictionary, p: Vector3) -> Dictionary:
	var c := Vector3i((p / CELL).floor())
	var best := REACH
	var found := {}
	for x in range(-1, 2):
		for y in range(-1, 2):
			for z in range(-1, 2):
				for e: Array in grid.get(c + Vector3i(x, y, z), []):
					var d := p.distance_to(e[0])
					if d < best:
						best = d
						found = e[1]
	if found.is_empty():
		return {}
	var fade := 1.0 - smoothstep(FULL, REACH, best)
	var out := {}
	for bone: int in found:
		out[bone] = float(found[bone]) * fade
	return out


static func _build(mesh: ArrayMesh, skin: Skin, sk: Skeleton3D, to_sk: Transform3D, grid: Dictionary) -> Array:
	var named := skin.get_bind_count() > 0 and String(skin.get_bind_name(0)) != ""
	var new_skin := skin.duplicate() as Skin
	var binds := {}  # skeleton bone -> bind in new_skin
	var had := {}  # soft bones the mesh is already weighted to
	for b in skin.get_bind_count():
		var bone := _bone_of(skin, sk, b)
		binds[bone] = b
	var out := ArrayMesh.new()
	out.blend_shape_mode = mesh.blend_shape_mode
	for b in mesh.get_blend_shape_count():
		out.add_blend_shape(mesh.get_blend_shape_name(b))
	var all_arrays := []
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		all_arrays.append(arrays)
		if arrays[Mesh.ARRAY_BONES] == null:
			continue
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		for k in bones.size():
			if weights[k] > 0.01:
				var bone := _bone_of(skin, sk, bones[k])
				if bone >= 0 and _soft_bone(sk, bone):
					had[bone] = true
	var touched := false
	for s in mesh.get_surface_count():
		var arrays: Array = all_arrays[s]
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if arrays[Mesh.ARRAY_BONES] != null and not verts.is_empty():
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var per := bones.size() / verts.size()
			for v in verts.size():
				var soft := _nearest(grid, to_sk * verts[v])
				for bone: int in soft:
					if had.has(bone) or float(soft[bone]) < 0.02:
						continue
					if not binds.has(bone):
						var pose := sk.get_bone_global_rest(bone).affine_inverse() * to_sk
						if named:
							new_skin.add_named_bind(sk.get_bone_name(bone), pose)
						else:
							new_skin.add_bind(bone, pose)
						binds[bone] = new_skin.get_bind_count() - 1
					if _give(bones, weights, v * per, per, binds[bone], float(soft[bone])):
						touched = true
			arrays[Mesh.ARRAY_BONES] = bones
			arrays[Mesh.ARRAY_WEIGHTS] = weights
		var flags := mesh.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		out.add_surface_from_arrays(mesh.surface_get_primitive_type(s), arrays, mesh.surface_get_blend_shape_arrays(s), {}, flags)
		out.surface_set_material(s, mesh.surface_get_material(s))
		out.surface_set_name(s, mesh.surface_get_name(s))
	if not touched:
		return [null, null]
	return [out, new_skin]


## Gives bind `to` share `f` of the vertex's weight (the rest scaled down to
## make room), in a free slot or in place of its smallest.
static func _give(bones: PackedInt32Array, weights: PackedFloat32Array, at: int, per: int, to: int, f: float) -> bool:
	f = clampf(f, 0.0, 0.9)
	var slot := -1
	var smallest := INF
	for k in per:
		if bones[at + k] == to and weights[at + k] > 0.0:
			return false
		if weights[at + k] <= 0.0:
			slot = at + k
			break
		if weights[at + k] < smallest:
			smallest = weights[at + k]
			slot = at + k
	weights[slot] = 0.0
	var rest := 0.0
	for k in per:
		rest += weights[at + k]
	if rest <= 0.0:
		return false
	for k in per:
		weights[at + k] *= (1.0 - f) / rest
	bones[slot] = to
	weights[slot] = f
	return true
