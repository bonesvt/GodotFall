extends "res://scripts/ps2/ps2_model.gd"
## Root script of assets/models/eco.tscn, the heroine (rigged mesh from
## assets/models/eco/eco.glb). Picks her animation from the CharacterBody3D she
## belongs to (idle, walk, run, fall, crouch, slide; the player's movement state
## when there is one) and runs the spring bones that make her hair swing and
## settle and her chest and glutes jiggle. Drop the scene in anywhere: on her
## own she just idles.

## Play the idle loop (breathing, glancing around) while standing.
@export var idle_motion := true
## Ground speed (m/s) the walk animation is authored at.
@export var walk_speed := 1.3
## Ground speed (m/s) the run animation is authored at.
@export var run_speed := 6.0
## Above this ground speed she runs instead of walking.
@export var run_threshold := 3.2
## Simulate the spring bones (hair, chest and glute jiggle).
@export var springs_enabled := true
## How far her chest and glutes may bounce (1 = as tuned, 0 = not at all).
@export_range(0.0, 2.0) var jiggle := 1.0

## Spring bones (the VRoid rig's J_Sec_* bones; the glute ones are added by
## tools/eco/build_eco_vroid.py): how hard each pulls back to its pose, how
## much speed it keeps per frame (1 - drag), how much gravity pulls its tip,
## the most it may swing away from its pose, and how much of her movement
## through the world it feels (1 = all of it: hair streams back when she runs;
## low = only her own motion: the jiggle bounces with her steps and landings
## without being dragged back by her speed).
const HAIR := {"stiffness": 0.14, "drag": 0.2, "gravity": 0.7, "limit": 30.0, "inertia": 0.6}
const HAIR_TIP := {"stiffness": 0.12, "drag": 0.2, "gravity": 0.6, "limit": 20.0, "inertia": 0.6}
# the fringe hangs over her face: it may lift off it, but swinging far back would go into her head
const FRINGE := {"stiffness": 0.16, "drag": 0.22, "gravity": 0.5, "limit": 12.0, "inertia": 0.35}
const FRINGE_TIP := {"stiffness": 0.14, "drag": 0.22, "gravity": 0.5, "limit": 10.0, "inertia": 0.35}
const BUST := {"stiffness": 0.2, "drag": 0.12, "gravity": 0.15, "limit": 14.0, "inertia": 0.12, "jiggle": true}
const GLUTE := {"stiffness": 0.24, "drag": 0.14, "gravity": 0.15, "limit": 10.0, "inertia": 0.12, "jiggle": true}
const SPRINGS := {
	# locks 01-02 hang at the back, 03-04 at the sides, 05-09 are the fringe;
	# the side and fringe locks bend once more at their second joint
	"J_Sec_Hair1_01": HAIR, "J_Sec_Hair1_02": HAIR, "J_Sec_Hair1_03": HAIR, "J_Sec_Hair1_04": HAIR,
	"J_Sec_Hair2_03": HAIR_TIP, "J_Sec_Hair2_04": HAIR_TIP,
	"J_Sec_Hair1_05": FRINGE, "J_Sec_Hair1_06": FRINGE, "J_Sec_Hair1_07": FRINGE, "J_Sec_Hair1_08": FRINGE,
	"J_Sec_Hair1_09": FRINGE,
	"J_Sec_Hair2_05": FRINGE_TIP, "J_Sec_Hair2_06": FRINGE_TIP, "J_Sec_Hair2_07": FRINGE_TIP,
	"J_Sec_Hair2_08": FRINGE_TIP, "J_Sec_Hair2_09": FRINGE_TIP,
	"J_Sec_L_Bust1": BUST, "J_Sec_R_Bust1": BUST,
	"J_Sec_L_Glute1": GLUTE, "J_Sec_R_Glute1": GLUTE,
}

## Movement states of scripts/player.gd (enum State).
enum PlayerState { GROUND, AIR, SLIDE, WALLRUN, GRAPPLE }

var skeleton: Skeleton3D
var _anim: AnimationPlayer
var _springs: Array[Dictionary] = []
var _last_origin := Vector3.ZERO


func _ready() -> void:
	super()
	process_priority = 10  # after her AnimationPlayer, so the springs follow this frame's pose
	_anim = find_child("AnimationPlayer", true, false) as AnimationPlayer
	skeleton = find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton != null:
		for bone_name: String in SPRINGS:
			var i := skeleton.find_bone(bone_name)
			if i >= 0:
				var s: Dictionary = SPRINGS[bone_name].duplicate()
				s["bone"] = i
				s["parent"] = skeleton.get_bone_parent(i)
				# a spring points from its bone to its first child (VRoid bones
				# don't point along their own axes)
				var children := skeleton.get_bone_children(i)
				s["aim"] = skeleton.get_bone_rest(children[0]).origin if children.size() > 0 else Vector3.UP * 0.1
				s["ready"] = false
				_springs.append(s)
		# parents before children, so a lock's second joint follows its root
		_springs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["bone"] < b["bone"])
		_last_origin = skeleton.global_position
	set_process(_anim != null or not _springs.is_empty())
	if _anim != null and idle_motion:
		_anim.play("idle")


## The animation she should play now, with its playback speed.
func pick_animation() -> Array:
	if _body == null:
		return ["idle", 1.0]
	var speed := Vector2(_body.velocity.x, _body.velocity.z).length()
	var state = _body.get("state")
	if state != null:
		match state:
			PlayerState.SLIDE:
				return ["slide", 1.0]
			PlayerState.AIR, PlayerState.GRAPPLE:
				return ["fall", 1.0]
			PlayerState.WALLRUN:
				return ["run", maxf(speed / run_speed, 0.8)]
		if _body.get("crouching"):
			return ["crouch", 1.0]
	elif not _body.is_on_floor():
		return ["fall", 1.0]
	if speed > run_threshold:
		return ["run", speed / run_speed]
	if speed > 0.3:
		return ["walk", speed / walk_speed]
	return ["idle", 1.0]


func _process(delta: float) -> void:
	if _anim != null:
		_animate()
	if springs_enabled and skeleton != null:
		_step_springs(delta)


func _animate() -> void:
	var pick := pick_animation()
	var anim_name: String = pick[0]
	if anim_name == "idle" and not idle_motion:
		if _anim.is_playing():
			_anim.pause()
		return
	if _anim.current_animation != anim_name:
		var blend := 0.12 if anim_name in ["slide", "fall"] else 0.25
		_anim.play(anim_name, blend)
	_anim.speed_scale = pick[1]


func _step_springs(delta: float) -> void:
	var to_world := skeleton.global_transform
	var to_skel := to_world.affine_inverse()
	var steps := clampf(delta * 60.0, 0.25, 3.0)
	var moved := to_world.origin - _last_origin
	_last_origin = to_world.origin
	for s in _springs:
		var i: int = s["bone"]
		var parent_pose := skeleton.get_bone_global_pose(s["parent"])
		if absf(parent_pose.basis.determinant()) < 1e-6:
			continue  # parent collapsed (first-person body hides the head)
		var rest_pose := parent_pose * skeleton.get_bone_rest(i)
		var aim_skel: Vector3 = rest_pose.basis * (s["aim"] as Vector3)
		var aim_world := to_world.basis * aim_skel
		var length := maxf(aim_world.length(), 0.02)
		var origin := to_world * rest_pose.origin
		var rest_dir := aim_world / length
		var limit: float = deg_to_rad(s["limit"]) * (jiggle if s.get("jiggle", false) else 1.0)
		var target := origin + rest_dir * length
		if limit <= 0.0 or not s["ready"] or (s["tip"] as Vector3).distance_to(target) > 1.0:
			s["tip"] = target
			s["prev"] = target
			s["ready"] = true
			if limit <= 0.0:
				skeleton.set_bone_pose_rotation(i, skeleton.get_bone_rest(i).basis.get_rotation_quaternion())
				continue
		elif moved.length() < 1.0:
			# carry the spring along with the part of her movement it shouldn't feel
			var carry := moved * (1.0 - float(s["inertia"]))
			s["tip"] += carry
			s["prev"] += carry
		var tip: Vector3 = s["tip"]
		var prev: Vector3 = s["prev"]
		var next: Vector3 = tip + (tip - prev) * (1.0 - s["drag"])
		next += (target - tip) * minf(s["stiffness"] * steps, 1.0)
		next += Vector3.DOWN * s["gravity"] * 0.01 * steps * length
		var dir: Vector3 = (next - origin).normalized()
		var angle: float = dir.angle_to(rest_dir)
		if angle > limit:
			dir = rest_dir.slerp(dir, limit / angle).normalized()
		s["prev"] = tip
		s["tip"] = origin + dir * length
		# rotate the bone so its child lies along the simulated direction
		var from_skel := aim_skel.normalized()
		var to_dir: Vector3 = (to_skel.basis * dir).normalized()
		if from_skel.dot(to_dir) > 0.99999:
			skeleton.set_bone_pose_rotation(i, skeleton.get_bone_rest(i).basis.get_rotation_quaternion())
			continue
		var swing := Basis(Quaternion(from_skel, to_dir))
		var local := parent_pose.basis.inverse() * swing * rest_pose.basis
		skeleton.set_bone_pose_rotation(i, local.get_rotation_quaternion())
