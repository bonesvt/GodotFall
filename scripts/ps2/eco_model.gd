extends "res://scripts/ps2/ps2_model.gd"
## Root script of assets/models/eco.tscn, the heroine (rigged mesh from
## assets/models/eco/eco.glb). Picks her animation from the CharacterBody3D she
## belongs to (idle, walk, run, fall, crouch, slide; the player's movement state
## when there is one) and runs the spring bones that make her hair locks and the
## rag on her hip swing and settle. Drop the scene in anywhere: on her own she
## just idles.

## Play the idle loop (breathing, glancing around) while standing.
@export var idle_motion := true
## Ground speed (m/s) the walk animation is authored at.
@export var walk_speed := 1.3
## Ground speed (m/s) the run animation is authored at.
@export var run_speed := 6.0
## Above this ground speed she runs instead of walking.
@export var run_threshold := 3.2
## Simulate the spring bones (hair locks, hip rag).
@export var springs_enabled := true

## Spring bones: how hard each pulls back to its pose, how much speed it
## keeps per frame (1 - drag), how much gravity pulls its tip, and the most it
## may swing away from its pose.
const SPRINGS := {
	"hair_front": {"stiffness": 0.16, "drag": 0.22, "gravity": 0.6, "limit": 28.0},
	"hair_back": {"stiffness": 0.12, "drag": 0.18, "gravity": 0.8, "limit": 35.0},
	"hair_side.R": {"stiffness": 0.14, "drag": 0.2, "gravity": 0.7, "limit": 32.0},
	"hair_side.L": {"stiffness": 0.14, "drag": 0.2, "gravity": 0.7, "limit": 32.0},
	"rag": {"stiffness": 0.07, "drag": 0.12, "gravity": 1.6, "limit": 55.0},
}
const SPRING_LENGTH := 0.12

## Movement states of scripts/player.gd (enum State).
enum PlayerState { GROUND, AIR, SLIDE, WALLRUN, GRAPPLE }

var skeleton: Skeleton3D
var _anim: AnimationPlayer
var _springs: Array[Dictionary] = []


func _ready() -> void:
	super()
	_anim = find_child("AnimationPlayer", true, false) as AnimationPlayer
	skeleton = find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton != null:
		for bone_name: String in SPRINGS:
			var i := skeleton.find_bone(bone_name)
			if i >= 0:
				var s: Dictionary = SPRINGS[bone_name].duplicate()
				s["bone"] = i
				s["parent"] = skeleton.get_bone_parent(i)
				s["ready"] = false
				_springs.append(s)
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
	for s in _springs:
		var i: int = s["bone"]
		var parent_pose := skeleton.get_bone_global_pose(s["parent"])
		if absf(parent_pose.basis.determinant()) < 1e-6:
			continue  # parent collapsed (first-person body hides the head)
		var rest_pose := parent_pose * skeleton.get_bone_rest(i)
		var origin := to_world * rest_pose.origin
		var rest_dir := (to_world.basis * rest_pose.basis.y).normalized()
		var target := origin + rest_dir * SPRING_LENGTH
		if not s["ready"] or (s["tip"] as Vector3).distance_to(target) > 1.0:
			s["tip"] = target
			s["prev"] = target
			s["ready"] = true
		var tip: Vector3 = s["tip"]
		var prev: Vector3 = s["prev"]
		var next: Vector3 = tip + (tip - prev) * (1.0 - s["drag"])
		next += (target - tip) * minf(s["stiffness"] * steps, 1.0)
		next += Vector3.DOWN * s["gravity"] * 0.01 * steps * SPRING_LENGTH
		var dir: Vector3 = (next - origin).normalized()
		var angle: float = dir.angle_to(rest_dir)
		var limit: float = deg_to_rad(s["limit"])
		if angle > limit:
			dir = rest_dir.slerp(dir, limit / angle).normalized()
		s["prev"] = tip
		s["tip"] = origin + dir * SPRING_LENGTH
		# rotate the bone so it points along the simulated direction
		var from_skel := rest_pose.basis.y.normalized()
		var to_dir: Vector3 = (to_skel.basis * dir).normalized()
		if from_skel.dot(to_dir) > 0.99999:
			skeleton.set_bone_pose_rotation(i, skeleton.get_bone_rest(i).basis.get_rotation_quaternion())
			continue
		var swing := Basis(Quaternion(from_skel, to_dir))
		var local := parent_pose.basis.inverse() * swing * rest_pose.basis
		skeleton.set_bone_pose_rotation(i, local.get_rotation_quaternion())
