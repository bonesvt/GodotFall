extends SkeletonModifier3D
## Eco's gunfighter stance in third person, layered on her full model after
## scripts/ps2/eco_react.gd (added by scripts/eco_fp_body.gd; Godot undoes it
## before the next frame, so it never builds up).
## She is smooth, methodical and likes to show off:
## - one-handed, arm out along the aim with the elbow soft and the pistol
##   canted a touch, so the barrel points exactly where the shot goes;
## - standing, she blades her body (gun shoulder forward), cocks her hip onto
##   her back leg, tips her chin and parks her off hand on her hip;
## - on the move the gun drops to a low ready by her hip, and comes up the
##   moment she fires;
## - each shot kicks the gun up and she settles it straight back;
## - she spins the pistol round her trigger finger after a kill, after a
##   reload, and now and then when she's standing about.
## The pistol (a copy of the equipped gun, made by scripts/view_camera.gd)
## sits in her right palm with her fingers wrapped round the grip.
## In her skeleton's space she faces -Z, her right is +X, her feet are at y = 0.

const EcoReact := preload("res://scripts/ps2/eco_react.gd")
const PlayerState := preload("res://scripts/ps2/eco_model.gd").PlayerState

## Where the pistol's grip is in its own space (centre of the grip), and the
## trigger pivot it spins round.
const GRIP := Vector3(0.0, -0.08, 0.07)
const TWIRL_PIVOT := Vector3(0.0, -0.03, -0.01)
## Finger curl round the grip, degrees per joint: the trigger finger stays
## straighter, along the frame.
const CURL := {
	"Index": [20.0, 25.0, 15.0], "Middle": [75.0, 85.0, 45.0],
	"Ring": [80.0, 85.0, 45.0], "Little": [85.0, 85.0, 45.0], "Thumb": [15.0, 25.0, 20.0],
}

## How far her arm reaches out along the aim (share of its full length).
@export_range(0.5, 1.0) var reach := 0.93
## Pistol cant, degrees (top tipped in toward her).
@export var cant := 18.0
## Standing, how far she turns her body side-on, degrees (gun shoulder forward).
@export var blade := 30.0
## Recoil: degrees the gun kicks up per shot, and how fast she settles it.
@export var kick := 11.0
@export var settle := 14.0
## Seconds standing still before she twirls the gun to pass the time.
@export var idle_twirl_after := 7.0

var body: CharacterBody3D
## The pistol node in her hand (a child of a BoneAttachment3D on her right hand).
var gun: Node3D:
	set(value):
		gun = value
		_twirl = 0.0

## 0..1: in combat at all (third person, off-duty strolling excluded), gun up
## along the aim (vs low ready), standing stance, and how far through a twirl.
var combat := 0.0
var aim := 0.0
var stance := 0.0
var twirling := false

var _bones := {}
## The gun's transform in her right hand's space, and the frames that orient
## each hand (fingers, palm).
var _calib := Transform3D()
var _hand_frame := {}
var _twirl := 0.0
var _idle := 0.0
var _was_reloading := false
var _weapon: Node


func _ready() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for b in ["Spine", "Chest", "UpperChest", "Neck", "Head", "Hips"]:
		_bones[b] = sk.find_bone("J_Bip_C_" + b)
	for side in ["L", "R"]:
		for b in ["UpperArm", "LowerArm", "Hand"]:
			_bones[b + "." + side] = sk.find_bone("J_Bip_%s_%s" % [side, b])
		for f: String in CURL:
			for j in 3:
				_bones["%s%d.%s" % [f, j + 1, side]] = sk.find_bone("J_Bip_%s_%s%d" % [side, f, j + 1])
	_calibrate(sk)


## Works out, from her rest pose, which way each hand's fingers and palm point
## in the hand's own space, and where the pistol sits in her right palm.
func _calibrate(sk: Skeleton3D) -> void:
	for side in ["L", "R"]:
		var h: int = _bones["Hand." + side]
		var m: int = _bones["Middle1." + side]
		var ix: int = _bones["Index1." + side]
		var lt: int = _bones["Little1." + side]
		if h < 0 or m < 0 or ix < 0 or lt < 0:
			return
		var hr := sk.get_bone_global_rest(h)
		var f := (sk.get_bone_global_rest(m).origin - hr.origin).normalized()
		var k := (sk.get_bone_global_rest(ix).origin - sk.get_bone_global_rest(lt).origin).normalized()
		var n := k.cross(f).normalized()  # out of the palm
		if side == "L":
			n = -n  # mirrored hand
		var inv := hr.basis.orthonormalized().inverse()
		_hand_frame[side] = [inv * f, inv * n, inv * k]
	# the pistol in her right palm: grip up along the knuckles (index at the top),
	# barrel along her fingers tipped up a little, grip pressed into the palm
	var fr: Array = _hand_frame["R"]
	var f_l: Vector3 = fr[0]
	var n_l: Vector3 = fr[1]
	var up := (fr[2] as Vector3)
	up = (up - f_l * up.dot(f_l)).normalized()
	var barrel := (f_l * cos(deg_to_rad(10.0)) + up * sin(deg_to_rad(10.0))).normalized()
	up = (up - barrel * up.dot(barrel)).normalized()
	var z := -barrel
	var g := Basis(up.cross(z), up, z)
	var grip_at := f_l * 0.05 + n_l * 0.03 - up * 0.015
	_calib = Transform3D(g, grip_at - g * GRIP)


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or body == null or _hand_frame.size() < 2:
		return
	var delta := get_process_delta_time()
	if delta <= 0.0:
		return
	_sense(delta)
	_place_gun(delta)
	if combat <= 0.001:
		return
	var to_skel := sk.global_transform.affine_inverse()

	# standing: side-on, hip cocked onto the back leg, chin tipped
	var s := stance * combat
	var a := aim * combat
	var turn := deg_to_rad(blade) * maxf(s, a * 0.6)
	_rotate(sk, "Hips", Vector3.UP, turn * 0.35)
	_rotate(sk, "Hips", Vector3.BACK, deg_to_rad(-6.0) * s)
	_rotate(sk, "Spine", Vector3.UP, turn * 0.25)
	_rotate(sk, "Chest", Vector3.UP, turn * 0.2)
	_rotate(sk, "UpperChest", Vector3.UP, turn * 0.2)
	# eyes back on the target, chin down a touch and cocked
	_rotate(sk, "Neck", Vector3.UP, -turn * 0.45)
	_rotate(sk, "Head", Vector3.UP, -turn * 0.55)
	_rotate(sk, "Head", Vector3.BACK, deg_to_rad(5.0) * s)
	_rotate(sk, "Head", Vector3.RIGHT, deg_to_rad(-4.0) * s)

	# gun arm: along the aim, or down at low ready
	var shoulder := sk.get_bone_global_pose(_bones["UpperArm.R"]).origin
	var target := to_skel * _aim_point()
	var aim_dir := (target - shoulder).normalized()
	var ready_dir := Vector3(-0.15, -0.75, -0.65).normalized()
	var since := _since_shot()
	var recoil := exp(-since * settle) if since < 1.0 else 0.0
	var dir := ready_dir.slerp(aim_dir, aim).normalized()
	dir = (dir + Vector3.UP * tan(deg_to_rad(kick)) * recoil).normalized()
	var length := _arm_length(sk, "R")
	var wrist_aim := shoulder + aim_dir * length * reach - aim_dir * 0.03 * recoil
	var wrist_ready := shoulder + Vector3(0.03, -0.36, -0.2)
	var wrist := wrist_ready.lerp(wrist_aim, aim)
	var up := Basis(dir, deg_to_rad(cant) * aim) * Vector3.UP
	var gun_basis := _look(dir, up)
	var hand_basis := gun_basis * _calib.basis.inverse()
	_arm(sk, "R", wrist, Vector3(0.5, -1.0, 0.4), hand_basis, combat)
	_curl(sk, "R", combat)

	# off hand on her hip while she stands
	if s > 0.01:
		var hips := sk.get_bone_global_pose(_bones["Hips"])
		var hip := hips.origin + Vector3(-0.16, 0.04, 0.03)
		var fl: Array = _hand_frame["L"]
		var want := _frame(Vector3(0.1, -0.55, -0.8), Vector3(1.0, 0.0, 0.0))
		var have := _frame(fl[0], fl[1])
		_arm(sk, "L", hip, Vector3(-1.0, -0.2, 0.7), want * have.inverse(), s)
		_curl(sk, "L", s * 0.4)


## Reads what she's doing: in combat at all, aiming or at low ready, standing.
func _sense(delta: float) -> void:
	if _weapon == null or not is_instance_valid(_weapon):
		_weapon = body.get_node_or_null("Head/Camera3D/Weapon")
		if _weapon != null and _weapon.has_signal("hit_confirmed"):
			_weapon.hit_confirmed.connect(func(kind: String) -> void:
				if kind == "kill":
					start_twirl())
	var on: bool = body.get("third_person") == true and body.get("strolling") != true and gun != null
	var state = body.get("state")
	var grounded: bool = state == PlayerState.GROUND
	var speed := Vector2(body.velocity.x, body.velocity.z).length()
	var firing := _since_shot() < 1.4
	var reloading: bool = _weapon != null and _weapon.has_method("is_reloading") and _weapon.is_reloading()
	var want_aim: bool = firing or reloading or (grounded and speed < 4.0) \
		or (state == PlayerState.AIR and speed < 6.0)
	var standing: bool = grounded and speed < 1.0 and not body.get("crouching")
	combat = move_toward(combat, 1.0 if on else 0.0, delta * 4.0)
	aim = lerpf(aim, 1.0 if want_aim else 0.0, 1.0 - exp(-(14.0 if want_aim else 6.0) * delta))
	stance = lerpf(stance, 1.0 if standing else 0.0, 1.0 - exp(-5.0 * delta))
	# show off: a twirl after a reload, after a kill (on_kill), or idling
	if _was_reloading and not reloading:
		start_twirl()
	_was_reloading = reloading
	_idle = _idle + delta if standing and not firing else 0.0
	if _idle > idle_twirl_after:
		_idle = -idle_twirl_after * 0.5
		start_twirl()


## Spins the pistol twice round her trigger finger.
func start_twirl() -> void:
	if not twirling:
		_twirl = 0.0
		twirling = true


## Puts the pistol in her palm (spinning it if she's twirling), and hides it
## off duty.
func _place_gun(delta: float) -> void:
	if gun == null or not is_instance_valid(gun):
		return
	gun.visible = body.get("strolling") != true
	var t := _calib
	if twirling:
		_twirl += delta / 0.65
		if _twirl >= 1.0:
			twirling = false
		else:
			# eased: whips round, slows into the catch
			var turns := 2.0 * (1.0 - pow(1.0 - _twirl, 3.0))
			var spin := Transform3D(Basis(Vector3.RIGHT, -turns * TAU), Vector3.ZERO)
			t = _calib * Transform3D(Basis(), TWIRL_PIVOT) * spin * Transform3D(Basis(), -TWIRL_PIVOT)
	gun.transform = t


## Where the shot goes: what the camera's centre ray hits, or far down it.
func _aim_point() -> Vector3:
	var cam: Camera3D = body.get("camera")
	var head := body.get_node_or_null("Head") as Node3D
	if cam == null or head == null:
		return body.global_position - body.global_basis.z * 30.0
	var from := cam.global_position
	var to := from - head.global_basis.z * 60.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [body.get_rid()]
	var hit: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or from.distance_to(hit.position) < 2.5:
		return to
	return hit.position


func _since_shot() -> float:
	if _weapon == null or not is_instance_valid(_weapon):
		return INF
	var s = _weapon.get("since_shot")
	return s if s != null else INF


func _arm_length(sk: Skeleton3D, side: String) -> float:
	var a := sk.get_bone_global_pose(_bones["UpperArm." + side]).origin
	var b := sk.get_bone_global_pose(_bones["LowerArm." + side]).origin
	var c := sk.get_bone_global_pose(_bones["Hand." + side]).origin
	return a.distance_to(b) + b.distance_to(c)


## Two-bone IK for an arm: the wrist to target, the elbow toward the pole,
## the hand to a skeleton-space orientation; blended with the animation by w.
func _arm(sk: Skeleton3D, side: String, target: Vector3, pole: Vector3, hand_basis: Basis, w: float) -> void:
	var up_i: int = _bones["UpperArm." + side]
	var lo_i: int = _bones["LowerArm." + side]
	var h_i: int = _bones["Hand." + side]
	if up_i < 0 or lo_i < 0 or h_i < 0 or w <= 0.0:
		return
	var ug := sk.get_bone_global_pose(up_i)
	var lg := sk.get_bone_global_pose(lo_i)
	var hg := sk.get_bone_global_pose(h_i)
	var a := ug.origin
	var la := a.distance_to(lg.origin)
	var lb := lg.origin.distance_to(hg.origin)
	var goal := hg.origin.lerp(target, w)
	var to_t := goal - a
	var d := clampf(to_t.length(), absf(la - lb) + 0.001, la + lb - 0.001)
	var dir := to_t.normalized()
	var p := pole - dir * pole.dot(dir)
	if p.length() < 0.0001:
		p = Vector3.DOWN
	p = p.normalized()
	var cos_a := clampf((la * la + d * d - lb * lb) / (2.0 * la * d), -1.0, 1.0)
	var elbow := a + dir * (la * cos_a) + p * (la * sqrt(1.0 - cos_a * cos_a))
	var r1 := EcoReact._between(lg.origin - a, elbow - a)
	var r2 := EcoReact._between(r1 * (hg.origin - lg.origin), a + dir * d - elbow)
	_set_global(sk, up_i, Transform3D(r1 * ug.basis, a))
	_set_global(sk, lo_i, Transform3D(r2 * r1 * lg.basis, elbow))
	var hq := (r2 * r1 * hg.basis).orthonormalized().get_rotation_quaternion()
	var wanted := Basis(hq.slerp(hand_basis.orthonormalized().get_rotation_quaternion(), w))
	_set_global(sk, h_i, Transform3D(wanted.scaled(hg.basis.get_scale()), a + dir * d))


## Wraps a hand's fingers round the grip (w = how far).
func _curl(sk: Skeleton3D, side: String, w: float) -> void:
	var h_i: int = _bones["Hand." + side]
	var hb := sk.get_bone_global_pose(h_i).basis.orthonormalized()
	var fr: Array = _hand_frame[side]
	var f: Vector3 = hb * (fr[0] as Vector3)
	var n: Vector3 = hb * (fr[1] as Vector3)
	# fingers fold from pointing along the hand toward the palm side
	var axis := f.cross(-n).normalized()
	for finger: String in CURL:
		var angles: Array = CURL[finger]
		for j in 3:
			var i: int = _bones.get("%s%d.%s" % [finger, j + 1, side], -1)
			if i >= 0:
				var g := sk.get_bone_global_pose(i)
				_set_global(sk, i, Transform3D(Basis(axis, deg_to_rad(angles[j]) * w) * g.basis, g.origin))


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


## A basis whose -Z looks along forward with +Y as close to up as it can.
static func _look(forward: Vector3, up: Vector3) -> Basis:
	var z := -forward.normalized()
	var x := up.cross(z)
	if x.length() < 0.0001:
		x = Vector3.RIGHT
	x = x.normalized()
	return Basis(x, z.cross(x), z)


## An orthonormal frame from a fingers direction and a palm direction.
static func _frame(f: Vector3, n: Vector3) -> Basis:
	var fx := f.normalized()
	var ny := (n - fx * n.dot(fx)).normalized()
	return Basis(fx, ny, fx.cross(ny))
