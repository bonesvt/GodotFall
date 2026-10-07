extends Node
## Chest and glute jiggle for the people in the hub and town (Mom, Ophelia and
## anyone else whose model has the bones), the same
## spring bones as Eco's (scripts/ps2/eco_model.gd): each J_Sec_* bone's tip
## lags behind where the pose puts it, springs back and settles, so turning,
## breathing and talking set them bouncing. hub_npc.gd adds one when the
## model has the bones (tools/npc/build_npc.py adds the glute ones). Brushing
## past Eco, their soft parts are pushed aside by her (_off_eco).

## Per person: chest, glutes. Mom is fuller, so a little looser and further.
const SPRINGS := {
	"mom": {
		"bust": {"stiffness": 0.12, "drag": 0.07, "gravity": 0.18, "limit": 26.0, "inertia": 0.2},
		"glute": {"stiffness": 0.15, "drag": 0.08, "gravity": 0.15, "limit": 20.0, "inertia": 0.2},
	},
	"ophelia": {
		"bust": {"stiffness": 0.15, "drag": 0.08, "gravity": 0.15, "limit": 22.0, "inertia": 0.2},
		"glute": {"stiffness": 0.18, "drag": 0.09, "gravity": 0.15, "limit": 18.0, "inertia": 0.2},
	},
}
## Anyone else whose model has the bones (the stylist, the townsfolk).
const DEFAULT := {
	"bust": {"stiffness": 0.15, "drag": 0.08, "gravity": 0.15, "limit": 22.0, "inertia": 0.2},
	"glute": {"stiffness": 0.18, "drag": 0.09, "gravity": 0.15, "limit": 18.0, "inertia": 0.2},
}
## Brushing past Eco presses them aside: her body as a capsule round the
## player (group "eco_player") from LOW to HIGH above her feet, RADIUS wide,
## and how far from it a spring's tip stays.
const ECO_LOW := 0.35
const ECO_HIGH := 1.45
const ECO_RADIUS := 0.14
const TOUCH := 0.04
const BONES := {
	"J_Sec_L_Bust1": "bust", "J_Sec_R_Bust1": "bust",
	"J_Sec_L_Glute1": "glute", "J_Sec_R_Glute1": "glute",
}

var skeleton: Skeleton3D
var springs: Array[Dictionary] = []
var _last_origin := Vector3.ZERO


## A spring node for `who`'s skeleton, or null when they have no springs.
static func make(who: String, p_skeleton: Skeleton3D) -> Node:
	if p_skeleton == null:
		return null
	var node: Node = load("res://scripts/hub/npc_springs.gd").new()
	node.name = "Springs"
	node.skeleton = p_skeleton
	for bone_name: String in BONES:
		var i := p_skeleton.find_bone(bone_name)
		if i < 0:
			continue
		var s: Dictionary = SPRINGS.get(who, DEFAULT)[BONES[bone_name]].duplicate()
		s["bone"] = i
		s["parent"] = p_skeleton.get_bone_parent(i)
		var children := p_skeleton.get_bone_children(i)
		s["aim"] = p_skeleton.get_bone_rest(children[0]).origin if children.size() > 0 else Vector3.UP * 0.1
		s["ready"] = false
		node.springs.append(s)
	if node.springs.is_empty():
		node.free()
		return null
	return node


func _ready() -> void:
	process_priority = 10   # after the AnimationPlayer, so the springs follow this frame's pose
	_last_origin = skeleton.global_position


func _process(delta: float) -> void:
	var to_world := skeleton.global_transform
	var to_skel := to_world.affine_inverse()
	var steps := clampf(delta * 60.0, 0.25, 3.0)
	var moved := to_world.origin - _last_origin
	_last_origin = to_world.origin
	var eco: Node3D = get_tree().get_first_node_in_group("eco_player") as Node3D
	if eco != null and eco.global_position.distance_to(to_world.origin) > 1.5:
		eco = null
	for s in springs:
		var i: int = s["bone"]
		var parent_pose := skeleton.get_bone_global_pose(s["parent"])
		var rest_pose := parent_pose * skeleton.get_bone_rest(i)
		var aim_skel: Vector3 = rest_pose.basis * (s["aim"] as Vector3)
		var aim_world := to_world.basis * aim_skel
		var length := maxf(aim_world.length(), 0.02)
		var origin := to_world * rest_pose.origin
		var rest_dir := aim_world / length
		var limit := deg_to_rad(float(s["limit"]))
		var target := origin + rest_dir * length
		if not s["ready"] or (s["tip"] as Vector3).distance_to(target) > 1.0:
			s["tip"] = target
			s["prev"] = target
			s["ready"] = true
		elif moved.length() < 1.0:
			var carry := moved * (1.0 - float(s["inertia"]))
			s["tip"] += carry
			s["prev"] += carry
		var tip: Vector3 = s["tip"]
		var prev: Vector3 = s["prev"]
		var next: Vector3 = tip + (tip - prev) * (1.0 - float(s["drag"]))
		next += (target - tip) * minf(float(s["stiffness"]) * steps, 1.0)
		next += Vector3.DOWN * float(s["gravity"]) * 0.01 * steps * length
		if eco != null:
			next = _off_eco(next, eco.global_position)
		var dir: Vector3 = (next - origin).normalized()
		var angle: float = dir.angle_to(rest_dir)
		if angle > limit:
			dir = rest_dir.slerp(dir, limit / angle).normalized()
		s["prev"] = tip
		s["tip"] = origin + dir * length
		var from_skel := aim_skel.normalized()
		var to_dir: Vector3 = (to_skel.basis * dir).normalized()
		if from_skel.dot(to_dir) > 0.99999:
			skeleton.set_bone_pose_rotation(i, skeleton.get_bone_rest(i).basis.get_rotation_quaternion())
			continue
		var swing := Basis(Quaternion(from_skel, to_dir))
		var local := parent_pose.basis.inverse() * swing * rest_pose.basis
		skeleton.set_bone_pose_rotation(i, local.get_rotation_quaternion())


## How far (degrees) the spring bones sit from their rest pose now, the most
## of any (for tests).
func swing_deg() -> float:
	var most := 0.0
	for s in springs:
		var i: int = s["bone"]
		var q := skeleton.get_bone_pose_rotation(i)
		most = maxf(most, rad_to_deg(q.angle_to(skeleton.get_bone_rest(i).basis.get_rotation_quaternion())))
	return most


## A spring tip pushed out of Eco's body, standing at `feet`.
static func _off_eco(tip: Vector3, feet: Vector3) -> Vector3:
	var on := Vector3(feet.x, clampf(tip.y, feet.y + ECO_LOW, feet.y + ECO_HIGH), feet.z)
	var out := tip - on
	var d := out.length()
	var r := ECO_RADIUS + TOUCH
	if d >= r or d < 1e-4:
		return tip
	return on + out / d * r
