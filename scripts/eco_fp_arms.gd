extends Node3D
## Eco's right arm on the first-person gun (scripts/weapon.gd puts it in place of
## the gun scene's old "Arm"). It is her real model (assets/models/eco.tscn) cut
## down to the right arm: every mesh keeps only the triangles skinned to her
## right upper arm, forearm, hand and fingers, so her skin, suit, armour pieces
## and outfit sleeves all come along. The arm is posed once, by two-bone IK,
## with the hand wrapped round the grip and the trigger finger along the guard;
## the gun's sway, bob and kick carry it from there.
##
## follow() points it at the model she is wearing (the player's EcoBody), and it
## keeps her suit tier, weight and outfit in step with that model.

const ECO := preload("res://assets/models/eco.tscn")
const EcoModel := preload("res://scripts/ps2/eco_model.gd")

## Bones whose skin is kept (with their fingers, found by prefix).
const ARM_BONES := ["J_Bip_R_UpperArm", "J_Bip_R_LowerArm", "J_Bip_R_Hand"]
const FINGER_PREFIX := "J_Bip_R_"
const FINGERS := ["Index", "Middle", "Ring", "Little"]

## Where things sit on the gun (the gun scene's own space: barrel down -Z, +Y up,
## the grip under the slide round (0, -0.07, 0.07)).
## Her wrist, just behind and to the right of the grip.
@export var wrist := Vector3(0.024, -0.072, 0.112)
## Wrist to knuckles: forward along the slide, a little up and in.
@export var hand_dir := Vector3(-0.12, 0.06, -1.0)
## The back of her hand faces out to the right, tipped up a little.
@export var hand_back := Vector3(1.0, 0.25, 0.0)
## Her shoulder joint, out of view down and behind the gun.
@export var shoulder := Vector3(0.17, -0.22, 0.5)
## Which way her elbow points: out to the right and down.
@export var elbow_pole := Vector3(0.8, -1.0, 0.1)
## Finger curl, degrees per joint (knuckle, middle, tip): the trigger finger
## lies along the guard, the rest wrap the grip.
@export var trigger_curl := Vector3(4, 22, 12)
@export var grip_curl := Vector3(70, 82, 42)
@export var thumb_curl := Vector3(10, 18, 14)

var model: EcoModel
var skeleton: Skeleton3D
var _source: Node
var _poll := 0.0

## Cut-down meshes, shared by every arm (original mesh -> arm-only mesh, or null
## when it has no part on her right arm).
static var _cut_cache := {}


func _ready() -> void:
	model = ECO.instantiate() as EcoModel
	model.name = "Eco"
	model.springs_enabled = false
	model.idle_motion = false
	var anim := model.find_child("AnimationPlayer", true, false)
	if anim != null:
		anim.free()  # posed by hand, once
	add_child(model)
	skeleton = model.skeleton
	if skeleton == null:
		return
	_cut_meshes()
	pose()


## Keeps the arm dressed like `eco` (an EcoModel, or the player's EcoBody that
## holds one): suit tier, weight and outfit.
func follow(eco: Node) -> void:
	_source = eco
	_sync()


func _process(delta: float) -> void:
	_poll -= delta
	if _poll <= 0.0:
		_poll = 0.25
		_sync()


func _sync() -> void:
	if model == null or _source == null or not is_instance_valid(_source):
		return
	# the player's EcoBody holds her first-person model as `body`
	var eco: Object = _source.get("body") if _source.get("body") is Node else _source
	for prop in ["suit_weight", "suit_tier", "outfit"]:
		var v = eco.get(prop)
		if v != null and model.get(prop) != null and model.get(prop) != v:
			model.set(prop, v)


func _arm_bone(bone_name: String) -> bool:
	if bone_name in ARM_BONES:
		return true
	if not bone_name.begins_with(FINGER_PREFIX):
		return false
	var rest := bone_name.substr(FINGER_PREFIX.length())
	for f in FINGERS + ["Thumb"]:
		if rest.begins_with(f):
			return true
	return false


func _cut_meshes() -> void:
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mi.mesh == null or mi.skin == null:
			mi.mesh = null
			continue
		if not _cut_cache.has(mi.mesh):
			_cut_cache[mi.mesh] = _cut(mi.mesh as ArrayMesh, mi.skin)
		var cut: ArrayMesh = _cut_cache[mi.mesh]
		mi.mesh = cut
		if cut == null:
			mi.visible = false
		else:
			# the posed arm is nowhere near the bind pose's bounds
			mi.custom_aabb = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
	model.apply_suit()


## The part of `mesh` skinned (mostly) to her right arm, or null if none is.
func _cut(mesh: ArrayMesh, skin: Skin) -> ArrayMesh:
	var on_arm := {}
	for b in skin.get_bind_count():
		var bone_name := String(skin.get_bind_name(b))
		if bone_name == "" and skeleton != null:
			bone_name = skeleton.get_bone_name(skin.get_bind_bone(b))
		if _arm_bone(bone_name):
			on_arm[b] = true
	if on_arm.is_empty():
		return null
	var out := ArrayMesh.new()
	for b in mesh.get_blend_shape_count():
		out.add_blend_shape(mesh.get_blend_shape_name(b))
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES] if arrays[Mesh.ARRAY_BONES] != null else PackedInt32Array()
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS] if arrays[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if bones.is_empty() or verts.is_empty():
			continue
		var per := bones.size() / verts.size()
		var keep_vert := PackedByteArray()
		keep_vert.resize(verts.size())
		for v in verts.size():
			var w := 0.0
			for k in per:
				if on_arm.has(bones[v * per + k]):
					w += weights[v * per + k]
			keep_vert[v] = 1 if w >= 0.5 else 0
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if index.is_empty():
			index.resize(verts.size())
			for v in verts.size():
				index[v] = v
		var kept := PackedInt32Array()
		for t in range(0, index.size(), 3):
			if keep_vert[index[t]] and keep_vert[index[t + 1]] and keep_vert[index[t + 2]]:
				kept.append_array([index[t], index[t + 1], index[t + 2]])
		if kept.is_empty():
			continue
		arrays[Mesh.ARRAY_INDEX] = kept
		var flags := mesh.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, mesh.surface_get_blend_shape_arrays(s), {}, flags)
		out.surface_set_material(out.get_surface_count() - 1, mesh.surface_get_material(s))
		out.surface_set_name(out.get_surface_count() - 1, mesh.surface_get_name(s))
	return out if out.get_surface_count() > 0 else null


## Stands her model so her shoulder joint is at `shoulder` facing down the
## barrel, then bends the arm so the hand holds the grip.
func pose() -> void:
	var sk := skeleton
	sk.reset_bone_poses()
	var upper := sk.find_bone("J_Bip_R_UpperArm")
	var lower := sk.find_bone("J_Bip_R_LowerArm")
	var hand := sk.find_bone("J_Bip_R_Hand")
	if upper < 0 or lower < 0 or hand < 0:
		return
	# skeleton space faces -Z with her right along +X, like the gun's own space
	var rel := global_transform.affine_inverse() * sk.global_transform
	model.transform = Transform3D(rel.basis.inverse(), Vector3.ZERO) * model.transform
	rel = global_transform.affine_inverse() * sk.global_transform
	var s_here := rel * _rest_global(upper).origin
	model.position += shoulder - s_here
	var to_sk := (global_transform.affine_inverse() * sk.global_transform).affine_inverse()

	var s := _rest_global(upper).origin
	var e0 := _rest_global(lower).origin
	var h0 := _rest_global(hand).origin
	var a := s.distance_to(e0)
	var b := e0.distance_to(h0)
	var w := to_sk * wrist
	var reach := w - s
	var d := clampf(reach.length(), absf(a - b) + 0.001, a + b - 0.001)
	var n := reach.normalized()
	var along := (a * a - b * b + d * d) / (2.0 * d)
	var up := sqrt(maxf(a * a - along * along, 0.0))
	var pole := to_sk.basis * elbow_pole
	pole = (pole - n * pole.dot(n)).normalized()
	var e := s + n * along + pole * up
	var h := s + n * d
	var hdir := (to_sk.basis * hand_dir).normalized()
	var hback := (to_sk.basis * hand_back)
	hback = (hback - hdir * hback.dot(hdir)).normalized()

	# T-pose: the arm points +X, palm down, elbow bending forward about +Y
	var rest_frame := Basis(Vector3.RIGHT, Vector3.UP, Vector3.BACK)
	var u_dir := (e - s).normalized()
	var f_dir := (h - e).normalized()
	var hinge := u_dir.cross(f_dir)
	hinge = hinge.normalized() if hinge.length() > 1e-4 else hback
	var q_upper := _frame(u_dir, hinge) * rest_frame.inverse()
	# the forearm turns halfway toward the hand, so the wrist doesn't wring
	var f_up := hinge.slerp(hback - f_dir * hback.dot(f_dir), 0.5)
	var q_lower := _frame(f_dir, f_up) * rest_frame.inverse()
	var q_hand := _frame(hdir, hback) * rest_frame.inverse()
	_set_global(upper, q_upper)
	_set_global(lower, q_lower)
	_set_global(hand, q_hand)

	# fingers curl toward the palm: about +Z in the T-pose (palm down, fingers +X)
	for f in FINGERS:
		var curl := trigger_curl if f == "Index" else grip_curl
		var total := 0.0
		for j in 3:
			var i := sk.find_bone("J_Bip_R_%s%d" % [f, j + 1])
			if i < 0:
				continue
			total += curl[j]
			_set_global(i, q_hand * Basis(Vector3.BACK, -deg_to_rad(total)))
	# the thumb folds across toward the index knuckle (in the T-pose it points
	# forward and out, palm down)
	var t1 := sk.find_bone("J_Bip_R_Thumb1")
	var t3 := sk.find_bone("J_Bip_R_Thumb3")
	var i1 := sk.find_bone("J_Bip_R_Index1")
	if t1 >= 0 and t3 >= 0 and i1 >= 0:
		var tdir := (_rest_global(t3).origin - _rest_global(t1).origin).normalized()
		var toward := (Vector3.DOWN + (_rest_global(i1).origin - _rest_global(t1).origin).normalized() * 0.7).normalized()
		var axis := tdir.cross(toward).normalized()
		var total := 0.0
		for j in 3:
			var i := sk.find_bone("J_Bip_R_Thumb%d" % (j + 1))
			total += thumb_curl[j]
			_set_global(i, q_hand * Basis(axis, deg_to_rad(total)))


## An orthonormal frame with x along `x_axis` and y as close to `y_hint` as fits.
static func _frame(x_axis: Vector3, y_hint: Vector3) -> Basis:
	var x := x_axis.normalized()
	var z := x.cross(y_hint).normalized()
	var y := z.cross(x)
	return Basis(x, y, z)


func _rest_global(i: int) -> Transform3D:
	return skeleton.get_bone_global_rest(i)


## Turns bone `i` so its skeleton-space orientation is its rest one turned by
## `q` (i.e. everything it carries turns by q from the T-pose).
func _set_global(i: int, q: Basis) -> void:
	var want := q * _rest_global(i).basis.orthonormalized()
	var parent := skeleton.get_bone_parent(i)
	var parent_basis := skeleton.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
	skeleton.set_bone_pose_rotation(i, (parent_basis.inverse() * want).get_rotation_quaternion())
