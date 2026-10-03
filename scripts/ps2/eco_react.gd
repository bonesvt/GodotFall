extends SkeletonModifier3D
## Makes Eco's full-body model react to the world, layered on top of her
## animations, the strut and the spring bones (it runs after all of them, and
## Godot undoes it before the next frame, so it never builds up). Added to the
## player's model by scripts/eco_fp_body.gd.
## - Her feet plant on slopes and steps: each leg reaches (two-bone IK) for the
##   ground under its foot, her hips drop to let the lower foot reach, and her
##   soles tilt to the ground.
## - She banks into turns (harder the faster she goes) and leans with speeding
##   up and slowing down, pivoting over her feet.
## - On a wallrun her feet go to the wall and her body tilts out from it.
## - Landings sink her hips by how hard she fell; her feet stay planted, so her
##   knees take it, then she straightens.
## - Her chest and head follow where you aim, up and down.
## In her skeleton's space she faces -Z, her right is +X, her feet are at y = 0.

const PlayerState := preload("res://scripts/ps2/eco_model.gd").PlayerState

## Plant her feet on uneven ground.
@export var foot_ik := true
## Highest step or deepest dip (m) a foot reaches for.
@export var max_step := 0.45
## Most her soles tilt to the ground, in degrees.
@export var max_foot_tilt := 30.0
## Banking into turns: share of the real lean for that turn, and the cap (degrees).
@export var turn_lean := 0.8
@export var max_turn_lean := 16.0
## Leaning with speed changes: degrees per m/s² of forward acceleration, and the cap.
@export var accel_lean := 0.35
@export var max_accel_lean := 7.0
## How far her body tilts out from the wall on a wallrun, in degrees.
@export var wallrun_tilt := 24.0
## Landing: metres her hips sink per m/s of fall speed, the cap, and how long
## (seconds) she takes to straighten.
@export var land_sink_per_speed := 0.012
@export var max_land_sink := 0.2
@export var land_recover := 0.35
## How much of your aim (up and down) her chest and head follow.
@export_range(0.0, 1.0) var look_follow := 0.6

var body: CharacterBody3D

## What it is doing now (world space), for tests and tuning: the bank (a
## horizontal vector toward where her head goes, length = angle in radians),
## the wallrun tilt (same form), how far her hips sink (m), and each foot's
## ground offset (m, + = ground higher than under her body).
var bank := Vector3.ZERO
var wall_tilt := Vector3.ZERO
var sink := 0.0
var foot_offsets := [0.0, 0.0]

var _bones := {}
var _ik_weight := 0.0
var _heading := NAN
var _fwd_speed := 0.0
var _turn_rate := 0.0
var _accel := 0.0
var _was_air := false
var _air_vy := 0.0
var _land := 0.0
var _land_peak := 0.0
var _foot_sink := 0.0

const BONES := {
	"hips": "J_Bip_C_Hips", "spine": "J_Bip_C_Spine", "chest": "J_Bip_C_Chest",
	"upper_chest": "J_Bip_C_UpperChest", "neck": "J_Bip_C_Neck", "head": "J_Bip_C_Head",
	"thigh.L": "J_Bip_L_UpperLeg", "shin.L": "J_Bip_L_LowerLeg", "foot.L": "J_Bip_L_Foot",
	"thigh.R": "J_Bip_R_UpperLeg", "shin.R": "J_Bip_R_LowerLeg", "foot.R": "J_Bip_R_Foot",
}


func _ready() -> void:
	var sk := get_skeleton()
	if sk != null:
		for key: String in BONES:
			_bones[key] = sk.find_bone(BONES[key])


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or body == null or _bones.is_empty() or _bones["hips"] < 0:
		return
	var delta := get_process_delta_time()
	if delta <= 0.0:
		return
	_sense(delta)
	var to_skel := sk.global_basis.orthonormalized().inverse()
	var scale := sk.global_basis.get_scale().y

	# where her animated feet are, before anything moves them
	var feet := []
	for side in ["L", "R"]:
		var i: int = _bones["foot." + side]
		feet.append(sk.get_bone_global_pose(i).origin if i >= 0 else Vector3.ZERO)
	var normals := [Vector3.UP, Vector3.UP]
	_ground_feet(sk, feet, normals, delta)

	# hips: bank and lean over her feet, tilt off the wall, sink
	var hips: int = _bones["hips"]
	var hp := sk.get_bone_global_pose(hips)
	var pivot := Vector3(hp.origin.x, 0.0, hp.origin.z)
	var r_ground := _tilt_basis(to_skel * bank)
	var r_wall := _tilt_basis(to_skel * wall_tilt)
	var drop := (sink + _foot_sink) / maxf(scale, 0.001)
	var origin := pivot + r_ground * (hp.origin - pivot) + Vector3.DOWN * drop
	_set_global(sk, hips, Transform3D(r_wall * r_ground * hp.basis, origin))

	# legs reach back to where the feet should be
	if _ik_weight > 0.001:
		for k in 2:
			var side: String = ["L", "R"][k]
			var off: float = foot_offsets[k] / maxf(scale, 0.001)
			var target: Vector3 = feet[k] + Vector3.UP * off
			var now := sk.get_bone_global_pose(_bones["foot." + side]).origin
			_reach(sk, side, now.lerp(target, _ik_weight), to_skel * normals[k])

	# chest and head follow the aim
	var head := body.get_node_or_null("Head") as Node3D
	if head != null and look_follow > 0.0:
		var pitch := clampf(head.rotation.x, -1.2, 1.2) * look_follow
		for part in [["spine", 0.15], ["chest", 0.2], ["upper_chest", 0.15], ["neck", 0.2], ["head", 0.3]]:
			_rotate(sk, part[0], Vector3.RIGHT, pitch * part[1])


## Reads her movement: turning, speeding up, wallrunning, landing.
func _sense(delta: float) -> void:
	var v := body.velocity
	var hv := Vector2(v.x, v.z)
	var speed := hv.length()
	var state = body.get("state")
	var grounded: bool = body.is_on_floor() if state == null else state == PlayerState.GROUND
	var facing := -body.global_basis.z
	facing.y = 0.0
	facing = facing.normalized()

	# turn rate from how her velocity's heading changes
	var heading := atan2(-hv.x, -hv.y) if speed > 0.5 else NAN
	var rate := 0.0
	if not is_nan(heading) and not is_nan(_heading):
		rate = wrapf(heading - _heading, -PI, PI) / delta
	_heading = heading
	_turn_rate = lerpf(_turn_rate, rate, 1.0 - exp(-8.0 * delta))
	var fwd := Vector3(v.x, 0.0, v.z).dot(facing)
	_accel = lerpf(_accel, (fwd - _fwd_speed) / delta, 1.0 - exp(-6.0 * delta))
	_fwd_speed = fwd

	var want := Vector3.ZERO
	if grounded or state == PlayerState.SLIDE:
		# lean = atan(sideways acceleration / gravity), toward the turn's centre
		var lateral := _turn_rate * speed
		var ang := clampf(atan(lateral / 28.0) * turn_lean, -deg_to_rad(max_turn_lean), deg_to_rad(max_turn_lean))
		var left := Vector3.UP.cross(facing)  # her left
		want += left * ang
		var lean := clampf(_accel * deg_to_rad(accel_lean), -deg_to_rad(max_accel_lean), deg_to_rad(max_accel_lean))
		want += facing * lean
	bank = bank.lerp(want, 1.0 - exp(-7.0 * delta))

	var wall_want := Vector3.ZERO
	if state == PlayerState.WALLRUN:
		var n: Vector3 = body.get("wall_normal")
		n.y = 0.0
		if n.length() > 0.1:
			wall_want = n.normalized() * deg_to_rad(wallrun_tilt)
	wall_tilt = wall_tilt.lerp(wall_want, 1.0 - exp(-9.0 * delta))

	# landing: sink by the fall speed, then straighten
	if not grounded and state != PlayerState.SLIDE:
		_air_vy = v.y
	elif _was_air:
		var hit: float = minf(maxf(-_air_vy, 0.0) * land_sink_per_speed, max_land_sink)
		if hit > _land:
			_land = hit
			_land_peak = hit
		_ik_weight = 1.0  # plant the feet straight away, so the knees take it
	_was_air = not grounded and state != PlayerState.SLIDE
	_land = move_toward(_land, 0.0, _land_peak / maxf(land_recover, 0.01) * delta)
	sink = lerpf(sink, _land, 1.0 - exp(-30.0 * delta))

	var ik_on := foot_ik and grounded
	_ik_weight = move_toward(_ik_weight, 1.0 if ik_on else 0.0, delta * 8.0)


## Finds the ground under each foot: its height against the ground under her
## body (foot_offsets) and its normal; drops her hips for the lower foot.
func _ground_feet(sk: Skeleton3D, feet: Array, normals: Array, delta: float) -> void:
	var floor_y := body.global_position.y
	var space := body.get_world_3d().direct_space_state
	for k in 2:
		var want := 0.0
		if _ik_weight > 0.001:
			var w: Vector3 = sk.global_transform * (feet[k] as Vector3)
			var from := Vector3(w.x, floor_y + max_step + 0.3, w.z)
			var q := PhysicsRayQueryParameters3D.create(from, Vector3(w.x, floor_y - max_step - 0.3, w.z))
			q.exclude = [body.get_rid()]
			var hit := space.intersect_ray(q)
			if hit.is_empty():
				want = -max_step
			else:
				want = clampf(hit.position.y - floor_y, -max_step, max_step)
				var n: Vector3 = hit.normal
				var limit := deg_to_rad(max_foot_tilt)
				if n.angle_to(Vector3.UP) > limit:
					n = Vector3.UP.slerp(n, limit / n.angle_to(Vector3.UP))
				normals[k] = n
		foot_offsets[k] = lerpf(foot_offsets[k], want, 1.0 - exp(-20.0 * delta))
	var lowest: float = minf(foot_offsets[0], foot_offsets[1])
	_foot_sink = maxf(-lowest, 0.0) * _ik_weight


## Two-bone IK: bends her thigh and shin so the foot lands on target (skeleton
## space), keeping the knee pointing the way it did, then tilts the sole to the
## ground normal.
func _reach(sk: Skeleton3D, side: String, target: Vector3, normal: Vector3) -> void:
	var thigh: int = _bones["thigh." + side]
	var shin: int = _bones["shin." + side]
	var foot: int = _bones["foot." + side]
	if thigh < 0 or shin < 0 or foot < 0:
		return
	var tg := sk.get_bone_global_pose(thigh)
	var sg := sk.get_bone_global_pose(shin)
	var fg := sk.get_bone_global_pose(foot)
	var a := tg.origin
	var b := sg.origin
	var c := fg.origin
	var la := a.distance_to(b)
	var lb := b.distance_to(c)
	var to_t := target - a
	var d := clampf(to_t.length(), absf(la - lb) + 0.001, la + lb - 0.001)
	var dir := to_t.normalized()
	# the knee keeps bending the way it was (pole), in the plane through the target
	var pole := (b - a) - dir * (b - a).dot(dir)
	if pole.length() < 0.0001:
		pole = Vector3.FORWARD
	pole = pole.normalized()
	var cos_a := clampf((la * la + d * d - lb * lb) / (2.0 * la * d), -1.0, 1.0)
	var knee := a + dir * (la * cos_a) + pole * (la * sqrt(1.0 - cos_a * cos_a))
	var r1 := _between(b - a, knee - a)
	var thigh_basis := r1 * tg.basis
	var r2 := _between(r1 * (c - b), a + dir * d - knee)
	var shin_basis := r2 * r1 * sg.basis
	# the sole: keep its animated angle, tilted from flat to the ground's slope
	var foot_basis := _between(Vector3.UP, normal) * fg.basis
	_set_global(sk, thigh, Transform3D(thigh_basis, a))
	_set_global(sk, shin, Transform3D(shin_basis, knee))
	_set_global(sk, foot, Transform3D(foot_basis, a + dir * d))


## Turns a bone about a skeleton-space axis through its joint.
func _rotate(sk: Skeleton3D, key: String, axis: Vector3, angle: float) -> void:
	var i: int = _bones.get(key, -1)
	if i < 0 or absf(angle) < 0.0001:
		return
	var g := sk.get_bone_global_pose(i)
	_set_global(sk, i, Transform3D(Basis(axis, angle) * g.basis, g.origin))


## Sets a bone's pose from a skeleton-space transform.
func _set_global(sk: Skeleton3D, i: int, g: Transform3D) -> void:
	var parent := sk.get_bone_parent(i)
	var local := (sk.get_bone_global_pose(parent).affine_inverse() * g) if parent >= 0 else g
	sk.set_bone_pose_position(i, local.origin)
	sk.set_bone_pose_rotation(i, local.basis.get_rotation_quaternion())


## A rotation that tips "up" toward a tilt vector (direction = where the top
## goes, length = angle in radians).
static func _tilt_basis(tilt: Vector3) -> Basis:
	var ang := tilt.length()
	if ang < 0.0001:
		return Basis()
	var axis := Vector3.UP.cross(tilt / ang)
	if axis.length() < 0.0001:
		return Basis()
	return Basis(axis.normalized(), ang)


## The shortest rotation taking direction u onto v.
static func _between(u: Vector3, v: Vector3) -> Basis:
	if u.length() < 0.0001 or v.length() < 0.0001:
		return Basis()
	var un := u.normalized()
	var vn := v.normalized()
	if un.dot(vn) > 0.99999:
		return Basis()
	if un.dot(vn) < -0.99999:
		return Basis(un.cross(Vector3.RIGHT).normalized(), PI)
	return Basis(Quaternion(un, vn))
