extends RefCounted
## Full body jiggle (experimental, Settings > Game): soft spring bones for Eco's
## stomach, thighs, upper arms and calves, added to her skeleton at runtime.
##
## The glb has no bones there, so this adds one per region (a child of the
## limb or spine bone, its head at that joint) and moves part of the region's
## skin weight onto it: most at the fleshy middle of the thigh, the calf's
## back, the underside of the upper arm and the front of the belly, none at
## the joints. At rest the new bone sits exactly where its parent does, so
## nothing changes until its spring (eco_model.gd) moves it. Every skinned
## mesh but her face, hair and goggles is reweighted the same way, so suits,
## outfits and armour pieces move with the skin under them.
##
##   EcoFlesh.add_bones(skeleton)      # once per skeleton; returns the springs
##   EcoFlesh.reweight(mi, skeleton)   # [mesh, skin] to put on the instance

## How each region's spring moves (eco_model.gd SPRINGS has the keys). These
## springs slide instead of swing: "reach" is the most the soft part may move
## off its pose (metres, at full weight), in any direction, so a landing
## bounces the flesh up and down as well as side to side. Small, quick and
## well damped: a ripple after a step or landing, not a bounce. "touch": how
## far round the spring's tip (on the limb's axis, or just off the belly) her
## skin reaches, for walls to push on.
const BELLY := {"group": "flesh", "stiffness": 0.2, "drag": 0.12, "gravity": 0.0, "limit": 0.0, "reach": 0.015, "inertia": 0.3, "jiggle": true, "touch": 0.025}
const THIGH := {"group": "flesh", "stiffness": 0.26, "drag": 0.14, "gravity": 0.0, "limit": 0.0, "reach": 0.012, "inertia": 0.3, "jiggle": true, "touch": 0.075}
const ARM := {"group": "flesh", "stiffness": 0.3, "drag": 0.15, "gravity": 0.0, "limit": 0.0, "reach": 0.008, "inertia": 0.3, "jiggle": true, "touch": 0.04}
const CALF := {"group": "flesh", "stiffness": 0.5, "drag": 0.2, "gravity": 0.0, "limit": 0.0, "reach": 0.007, "inertia": 0.3, "jiggle": true, "touch": 0.05}

## name: the new bone; parent: the bone it hangs off (and takes weight from,
## with `from`); a/b: the bones whose heads run along the limb (the spring's
## tip sits `centre` of the way from a to b, so a swinging limb drags it); centre/width: where along a->b
## the soft part peaks and how far it spreads; amount: the most weight moved;
## side: "back" (calf) or "under" (arm) leans it towards that side of the limb.
const REGIONS := [
	{"name": "J_Sec_C_Belly", "parent": "J_Bip_C_Spine", "spring": BELLY, "amount": 0.7,
		"from": ["J_Bip_C_Hips", "J_Bip_C_Spine", "J_Bip_C_Chest"]},
	{"name": "J_Sec_L_Thigh", "parent": "J_Bip_L_UpperLeg", "a": "J_Bip_L_UpperLeg", "b": "J_Bip_L_LowerLeg",
		"centre": 0.4, "width": 0.28, "amount": 0.7, "spring": THIGH},
	{"name": "J_Sec_R_Thigh", "parent": "J_Bip_R_UpperLeg", "a": "J_Bip_R_UpperLeg", "b": "J_Bip_R_LowerLeg",
		"centre": 0.4, "width": 0.28, "amount": 0.7, "spring": THIGH},
	{"name": "J_Sec_L_Calf", "parent": "J_Bip_L_LowerLeg", "a": "J_Bip_L_LowerLeg", "b": "J_Bip_L_Foot",
		"centre": 0.3, "width": 0.18, "amount": 0.55, "side": "back", "spring": CALF},
	{"name": "J_Sec_R_Calf", "parent": "J_Bip_R_LowerLeg", "a": "J_Bip_R_LowerLeg", "b": "J_Bip_R_Foot",
		"centre": 0.3, "width": 0.18, "amount": 0.55, "side": "back", "spring": CALF},
	{"name": "J_Sec_L_UpperArmSoft", "parent": "J_Bip_L_UpperArm", "a": "J_Bip_L_UpperArm", "b": "J_Bip_L_LowerArm",
		"centre": 0.55, "width": 0.25, "amount": 0.5, "side": "under", "spring": ARM},
	{"name": "J_Sec_R_UpperArmSoft", "parent": "J_Bip_R_UpperArm", "a": "J_Bip_R_UpperArm", "b": "J_Bip_R_LowerArm",
		"centre": 0.55, "width": 0.25, "amount": 0.5, "side": "under", "spring": ARM},
]
## The belly: how high (between the spine and chest joints, 0..1 from the
## spine's), how far up/down and sideways it spreads, and how far forward its
## spring points.
const BELLY_HEIGHT := 0.15
const BELLY_SPREAD := Vector2(0.085, 0.075)
const BELLY_REACH := 0.12
## Meshes left alone (nothing soft on them, and the hair is big).
const SKIP := ["Face", "Hair", "Goggles"]

## Reweighted meshes, shared by every Eco: "<mesh id>:<skin id>" -> [original mesh, mesh, skin].
static var _cache := {}


static func bone_names() -> Array:
	return REGIONS.map(func(r: Dictionary) -> String: return r["name"])


## Adds the region bones to `sk` (once; a second call finds them) and returns
## a spring entry per bone for eco_model.gd: {bone, base, aim}.
static func add_bones(sk: Skeleton3D) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: Dictionary in REGIONS:
		var parent := sk.find_bone(r["parent"])
		if parent < 0:
			continue
		var i := sk.find_bone(r["name"])
		if i < 0:
			i = sk.get_bone_count()
			sk.add_bone(r["name"])
			sk.set_bone_parent(i, parent)
			sk.set_bone_rest(i, Transform3D.IDENTITY)
			sk.reset_bone_pose(i)
		out.append({"bone": i, "base": r["spring"], "aim": _aim(sk, r, parent)})
	return out


## Where the spring of region `r` points from its bone, in the bone's own space.
static func _aim(sk: Skeleton3D, r: Dictionary, parent: int) -> Vector3:
	var at := sk.get_bone_global_rest(parent)
	if r.has("a"):
		var a := sk.get_bone_global_rest(sk.find_bone(r["a"])).origin
		var b := sk.get_bone_global_rest(sk.find_bone(r["b"])).origin
		return at.basis.inverse() * ((b - a) * float(r["centre"]))
	return at.basis.inverse() * (Vector3.FORWARD * BELLY_REACH)


static func skipped(mi: MeshInstance3D) -> bool:
	return mi.name in SKIP or mi.mesh == null or mi.skin == null or not mi.mesh is ArrayMesh


## The instance's mesh and skin with the soft regions weighted to their bones
## (which add_bones must have put on `sk`), or [] if nothing on it is soft.
static func reweight(mi: MeshInstance3D, sk: Skeleton3D) -> Array:
	if skipped(mi):
		return []
	var key := "%d:%d" % [mi.mesh.get_instance_id(), mi.skin.get_instance_id()]
	if not _cache.has(key):
		_cache[key] = [mi.mesh] + _build(mi.mesh as ArrayMesh, mi.skin, sk, sk.global_transform.affine_inverse() * mi.global_transform)
	var hit: Array = _cache[key]
	return [] if hit[1] == null else [hit[1], hit[2]]


static func _bind_of(skin: Skin, sk: Skeleton3D, bone: int) -> int:
	var bone_name := sk.get_bone_name(bone)
	for b in skin.get_bind_count():
		if skin.get_bind_name(b) == StringName(bone_name) or (String(skin.get_bind_name(b)) == "" and skin.get_bind_bone(b) == bone):
			return b
	return -1


## [mesh, skin] for `mesh` (in skeleton space through `to_sk`), or [null, null].
static func _build(mesh: ArrayMesh, skin: Skin, sk: Skeleton3D, to_sk: Transform3D) -> Array:
	var named := skin.get_bind_count() > 0 and String(skin.get_bind_name(0)) != ""
	var new_skin := skin.duplicate() as Skin
	var regions := []  # per region: [region, new bind, {source bind: true}, a, b, spine, chest]
	for r: Dictionary in REGIONS:
		var parent := sk.find_bone(r["parent"])
		var bone := sk.find_bone(r["name"])
		if parent < 0 or bone < 0:
			continue
		var from := {}
		for n: String in r.get("from", [r["parent"]]):
			var fb := _bind_of(skin, sk, sk.find_bone(n))
			if fb >= 0:
				from[fb] = true
		if from.is_empty():
			continue
		# the new bone's bind pose: its parent's (its rest is the parent's own)
		var pb := _bind_of(skin, sk, parent)
		var pose := skin.get_bind_pose(pb) if pb >= 0 else sk.get_bone_global_rest(parent).affine_inverse() * to_sk
		if named:
			new_skin.add_named_bind(r["name"], pose)
		else:
			new_skin.add_bind(bone, pose)
		var entry := [r, new_skin.get_bind_count() - 1, from]
		if r.has("a"):
			entry.append(sk.get_bone_global_rest(sk.find_bone(r["a"])).origin)
			entry.append(sk.get_bone_global_rest(sk.find_bone(r["b"])).origin)
		else:
			entry.append(sk.get_bone_global_rest(parent).origin)
			entry.append(sk.get_bone_global_rest(sk.find_bone("J_Bip_C_Chest")).origin)
		regions.append(entry)
	if regions.is_empty():
		return [null, null]

	var out := ArrayMesh.new()
	out.blend_shape_mode = mesh.blend_shape_mode
	for b in mesh.get_blend_shape_count():
		out.add_blend_shape(mesh.get_blend_shape_name(b))
	var touched := false
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES] if arrays[Mesh.ARRAY_BONES] != null else PackedInt32Array()
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS] if arrays[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
		if not bones.is_empty() and not verts.is_empty():
			var per := bones.size() / verts.size()
			for v in verts.size():
				var p := to_sk * verts[v]
				var n := (to_sk.basis * normals[v]).normalized() if v < normals.size() else Vector3.ZERO
				for e: Array in regions:
					var f := _softness(e, p, n)
					if f > 0.005 and _move(bones, weights, v * per, per, e[2], e[1], f):
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


## How much of the region's weight at `p` (normal `n`) goes to its soft bone (0..1).
static func _softness(e: Array, p: Vector3, n: Vector3) -> float:
	var r: Dictionary = e[0]
	var a: Vector3 = e[3]
	var b: Vector3 = e[4]
	if not r.has("centre"):
		# the belly: in front of the spine, a little above its joint
		var mid := a.lerp(b, BELLY_HEIGHT)
		var d := Vector2(p.x - mid.x, p.y - mid.y)
		var spread := exp(-pow(d.x / BELLY_SPREAD.x, 2.0) - pow(d.y / BELLY_SPREAD.y, 2.0))
		var front := smoothstep(0.0, 0.05, mid.z - p.z) * smoothstep(-0.2, 0.5, -n.z)
		return float(r["amount"]) * spread * front
	var ab := b - a
	var t := (p - a).dot(ab) / ab.length_squared()
	var bell := exp(-pow((t - float(r["centre"])) / float(r["width"]), 2.0))
	var lean := 1.0
	if r.has("side"):
		var out_dir := (p - (a + ab * t)).normalized()
		var toward := Vector3.BACK if r["side"] == "back" else Vector3.DOWN
		lean = 0.35 + 0.65 * smoothstep(-0.3, 0.7, out_dir.dot(toward))
	return float(r["amount"]) * bell * lean


## Moves share `f` of the weight a vertex has on the `from` binds to bind `to`.
## Uses a free slot, or the smallest one (its weight goes to the biggest).
static func _move(bones: PackedInt32Array, weights: PackedFloat32Array, at: int, per: int, from: Dictionary, to: int, f: float) -> bool:
	var src := 0.0
	for k in per:
		if from.has(bones[at + k]):
			src += weights[at + k]
	if src < 0.02:
		return false
	var slot := -1
	var smallest := INF
	var biggest := at
	for k in per:
		var w := weights[at + k]
		if w <= 0.0:
			slot = at + k
			break
		if w < smallest:
			smallest = w
			slot = at + k
		if w > weights[biggest]:
			biggest = at + k
	var give := src * f
	if weights[slot] > 0.0:
		if slot == biggest:
			return false
		weights[biggest] += weights[slot]
		bones[slot] = to
		weights[slot] = 0.0
	# take the share from the source slots (recount: the freed slot may have been one)
	src = 0.0
	for k in per:
		if from.has(bones[at + k]):
			src += weights[at + k]
	if src < 0.02:
		return false
	give = minf(give, src)
	for k in per:
		if from.has(bones[at + k]):
			weights[at + k] *= 1.0 - give / src
	bones[slot] = to
	weights[slot] = give
	return true
