extends SkeletonModifier3D
## Eco's third person combat movement, layered on her full model between the
## world reactions (scripts/ps2/eco_react.gd) and the gun stance
## (scripts/ps2/eco_gun_stance.gd). Added by scripts/eco_fp_body.gd; Godot
## undoes it before the next frame, so it never builds up. What it does, and
## how much, is set by the third person feel preset (scripts/tp_feel.gd, F7).
## - Her legs run where she goes while her chest stays on the aim: strafing,
##   her hips turn toward the side she runs to and her spine twists back;
##   running backwards her legs face forward and the stride plays in reverse
##   (eco_model.gd stride_reverse), so she backpedals instead of moonwalking.
## - Standing, her feet stay planted while you turn a little, and she steps
##   round once you've turned far enough.
## - She leans into sideways starts and stops.
## - Each shot rocks her shoulders back.
## - Taking a hit jolts her upper body away from where it came from.
## In her skeleton's space she faces -Z, her right is +X, her feet are at y = 0.

const PlayerState := preload("res://scripts/ps2/eco_model.gd").PlayerState

## Turn her legs toward where she runs (0 = off, 1 = all the way).
@export_range(0.0, 1.0) var leg_twist := 0.0
## The furthest her hips turn from her chest, degrees.
@export var max_twist := 75.0
## Standing, how far you may turn before her feet step round (0 = off: her
## whole body turns with you, as before).
@export var turn_in_place := 0.0
## How quickly her feet catch up once she steps round.
@export var step_rate := 9.0
## Leaning into sideways speed changes: degrees per m/s², and the cap.
@export var strafe_lean := 0.0
@export var max_strafe_lean := 9.0
## Degrees her shoulders rock back per shot.
@export var shot_rock := 0.0
## Degrees her upper body jolts per hit.
@export var flinch := 0.0

var body: CharacterBody3D
## The model this skeleton belongs to (eco_model.gd), for the reversed stride.
var model: Node

## What it is doing now, for tests and tuning: her hips' turn from her chest
## (radians, + = toward her left), backpedalling, and the sideways lean.
var twist := 0.0
var backpedal := false
var lean := 0.0

var _bones := {}
var _feet_yaw := NAN
var _stepping := false
var _lat_speed := 0.0
var _lat_accel := 0.0
var _flinch := Vector3.ZERO
var _flinch_vel := Vector3.ZERO
var _weapon: Node


func _ready() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for b in ["Hips", "Spine", "Chest", "UpperChest", "Neck", "Head"]:
		_bones[b] = sk.find_bone("J_Bip_C_" + b)
	if body != null and body.has_signal("damaged"):
		body.damaged.connect(_on_damaged)


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or body == null or _bones.get("Hips", -1) < 0:
		return
	var delta := get_process_delta_time()
	if delta <= 0.0:
		return
	var on: bool = body.get("third_person") == true and body.get("strolling") != true \
		and body.get("resting") != true
	_sense(delta, on)
	if not on:
		return
	var to_skel := sk.global_basis.orthonormalized().inverse()

	# legs one way, chest back onto the aim
	if absf(twist) > 0.0005:
		_rotate(sk, "Hips", Vector3.UP, twist)
		_rotate(sk, "Spine", Vector3.UP, -twist * 0.4)
		_rotate(sk, "Chest", Vector3.UP, -twist * 0.35)
		_rotate(sk, "UpperChest", Vector3.UP, -twist * 0.25)
	# sideways lean, pivoting over her feet
	if absf(lean) > 0.0005:
		var hips: int = _bones["Hips"]
		var hp := sk.get_bone_global_pose(hips)
		var pivot := Vector3(hp.origin.x, 0.0, hp.origin.z)
		var r := Basis(Vector3.BACK, lean)
		_set_global(sk, hips, Transform3D(r * hp.basis, pivot + r * (hp.origin - pivot)))
	# a shot rocks her shoulders back, her head stays on the sights
	var since := _since_shot()
	if shot_rock > 0.0 and since < 0.6:
		var rock := deg_to_rad(shot_rock) * exp(-since * 11.0) * clampf(since * 60.0, 0.0, 1.0)
		_rotate(sk, "Chest", Vector3.RIGHT, rock * 0.4)
		_rotate(sk, "UpperChest", Vector3.RIGHT, rock * 0.6)
		_rotate(sk, "Head", Vector3.RIGHT, -rock * 0.7)
	# a hit throws her upper body away from it
	if _flinch.length() > 0.001:
		var f := to_skel * _flinch
		var axis := Vector3.UP.cross(f)
		if axis.length() > 0.0001:
			axis = axis.normalized()
			var ang := f.length()
			_rotate(sk, "Spine", axis, ang * 0.35)
			_rotate(sk, "Chest", axis, ang * 0.35)
			_rotate(sk, "UpperChest", axis, ang * 0.3)
			_rotate(sk, "Head", axis, -ang * 0.3)


## Reads where she's going against where she's facing.
func _sense(delta: float, on: bool) -> void:
	var facing_yaw := body.global_rotation.y
	var v := body.velocity
	var hv := Vector3(v.x, 0.0, v.z)
	var speed := hv.length()
	var state = body.get("state")
	var grounded: bool = state == PlayerState.GROUND

	var want := 0.0
	var back := false
	if on and leg_twist > 0.0 and grounded and speed > 0.8 and not body.get("crouching"):
		# angle of travel from her facing, + = to her left
		var local := body.global_basis.inverse() * hv
		var a := atan2(-local.x, -local.z)
		if absf(a) > deg_to_rad(105.0):
			back = true
			a -= signf(a) * PI
		want = clampf(a, -deg_to_rad(max_twist), deg_to_rad(max_twist)) * leg_twist
		_feet_yaw = facing_yaw + want
		_stepping = false
	elif on and turn_in_place > 0.0 and grounded and speed <= 0.8:
		# standing: feet stay put until she's turned far enough, then step round
		if is_nan(_feet_yaw):
			_feet_yaw = facing_yaw
		var rel := wrapf(_feet_yaw - facing_yaw, -PI, PI)
		if absf(rel) > deg_to_rad(turn_in_place):
			_stepping = true
		if _stepping:
			_feet_yaw = facing_yaw + rel * exp(-step_rate * delta)
			if absf(rel) < deg_to_rad(4.0):
				_stepping = false
		want = clampf(wrapf(_feet_yaw - facing_yaw, -PI, PI), -deg_to_rad(max_twist), deg_to_rad(max_twist))
	else:
		_feet_yaw = facing_yaw
		_stepping = false
	if back != backpedal:
		backpedal = back
		twist = want  # the stride flips, so the legs swap ends in one go
	if model != null:
		model.set("stride_reverse", backpedal)
	twist = lerpf(twist, want, 1.0 - exp(-14.0 * delta))

	# sideways acceleration, in her frame (+ = toward her right)
	var lat := hv.dot(body.global_basis.x)
	_lat_accel = lerpf(_lat_accel, (lat - _lat_speed) / delta, 1.0 - exp(-8.0 * delta))
	_lat_speed = lat
	var lean_want := 0.0
	if on and grounded and strafe_lean > 0.0:
		lean_want = clampf(-_lat_accel * deg_to_rad(strafe_lean), -deg_to_rad(max_strafe_lean), deg_to_rad(max_strafe_lean))
	lean = lerpf(lean, lean_want, 1.0 - exp(-9.0 * delta))

	# flinch: a stiff spring back to upright
	_flinch_vel += (-_flinch * 170.0 - _flinch_vel * 14.0) * delta
	_flinch += _flinch_vel * delta


func _on_damaged(amount: float, from: Vector3) -> void:
	if flinch <= 0.0 or body == null:
		return
	var away := body.global_position - from
	away.y = 0.0
	if from == Vector3.ZERO or away.length() < 0.01:
		away = body.global_basis.z  # no source: rocked back
	var kick := deg_to_rad(flinch) * clampf(0.5 + amount / 30.0, 0.5, 1.5)
	_flinch_vel += away.normalized() * kick * 14.0


func _since_shot() -> float:
	if _weapon == null or not is_instance_valid(_weapon):
		_weapon = body.get_node_or_null("Head/Camera3D/Weapon")
	if _weapon == null:
		return INF
	var s = _weapon.get("since_shot")
	return s if s != null else INF


## Turns a bone about a skeleton-space axis through its joint.
func _rotate(sk: Skeleton3D, key: String, axis: Vector3, angle: float) -> void:
	var i: int = _bones.get(key, -1)
	if i < 0 or absf(angle) < 0.0001:
		return
	var g := sk.get_bone_global_pose(i)
	_set_global(sk, i, Transform3D(Basis(axis, angle) * g.basis, g.origin))


func _set_global(sk: Skeleton3D, i: int, g: Transform3D) -> void:
	var parent := sk.get_bone_parent(i)
	var local := (sk.get_bone_global_pose(parent).affine_inverse() * g) if parent >= 0 else g
	sk.set_bone_pose_position(i, local.origin)
	sk.set_bone_pose_rotation(i, local.basis.orthonormalized().get_rotation_quaternion())
