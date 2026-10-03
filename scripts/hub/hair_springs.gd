extends Node
## Hair physics for the people who get haircuts besides Eco (Ophelia for now;
## hair.gd adds one to their model): the VRoid hair spring bones swing, lag
## behind when they turn and settle, as Eco's do (scripts/ps2/eco_model.gd
## SPRINGS, same tuning). Covers every cut: their own hair and the salon's,
## which hang from the same bones (the long braids and the ponytail from the
## back hair chains). Only hair bones: chest and glutes are npc_springs.gd's.

const HAIR := {"stiffness": 0.14, "drag": 0.2, "gravity": 0.7, "limit": 30.0, "inertia": 0.6}
const HAIR_TIP := {"stiffness": 0.12, "drag": 0.2, "gravity": 0.6, "limit": 20.0, "inertia": 0.6}
# the fringe hangs over the face: it may lift off it, but swinging far back would go into the head
const FRINGE := {"stiffness": 0.16, "drag": 0.22, "gravity": 0.5, "limit": 12.0, "inertia": 0.35}
const FRINGE_TIP := {"stiffness": 0.14, "drag": 0.22, "gravity": 0.5, "limit": 10.0, "inertia": 0.35}
const BRAID := {"stiffness": 0.1, "drag": 0.16, "gravity": 0.9, "limit": 28.0, "inertia": 0.5}
const SPRINGS := {
	# locks 01-02 hang at the back, 03-04 at the sides, 05-09 are the fringe;
	# the back chains carry on down (Hair2-4_01/02) for the long cuts
	"J_Sec_Hair1_01": HAIR, "J_Sec_Hair1_02": HAIR, "J_Sec_Hair1_03": HAIR, "J_Sec_Hair1_04": HAIR,
	"J_Sec_Hair2_03": HAIR_TIP, "J_Sec_Hair2_04": HAIR_TIP,
	"J_Sec_Hair1_05": FRINGE, "J_Sec_Hair1_06": FRINGE, "J_Sec_Hair1_07": FRINGE, "J_Sec_Hair1_08": FRINGE,
	"J_Sec_Hair1_09": FRINGE,
	"J_Sec_Hair2_05": FRINGE_TIP, "J_Sec_Hair2_06": FRINGE_TIP, "J_Sec_Hair2_07": FRINGE_TIP,
	"J_Sec_Hair2_08": FRINGE_TIP, "J_Sec_Hair2_09": FRINGE_TIP,
	"J_Sec_Hair2_01": BRAID, "J_Sec_Hair2_02": BRAID, "J_Sec_Hair3_01": BRAID, "J_Sec_Hair3_02": BRAID,
	"J_Sec_Hair4_01": BRAID, "J_Sec_Hair4_02": BRAID,
}

var skeleton: Skeleton3D
var springs: Array[Dictionary] = []
var _last_origin := Vector3.ZERO


## A hair spring node for a skeleton, or null when it has no hair bones.
static func make(p_skeleton: Skeleton3D) -> Node:
	if p_skeleton == null:
		return null
	var node: Node = load("res://scripts/hub/hair_springs.gd").new()
	node.name = "HairSprings"
	node.skeleton = p_skeleton
	for bone_name: String in SPRINGS:
		var i := p_skeleton.find_bone(bone_name)
		if i < 0:
			continue
		var s: Dictionary = SPRINGS[bone_name].duplicate()
		s["bone"] = i
		s["parent"] = p_skeleton.get_bone_parent(i)
		# a spring points from its bone to its first child (VRoid bones don't point along their own axes)
		var children := p_skeleton.get_bone_children(i)
		s["aim"] = p_skeleton.get_bone_rest(children[0]).origin if children.size() > 0 else Vector3.UP * 0.1
		s["ready"] = false
		node.springs.append(s)
	if node.springs.is_empty():
		node.free()
		return null
	# parents before children, so a lock's lower joints follow its root
	node.springs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["bone"] < b["bone"])
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
	for s in springs:
		var i: int = s["bone"]
		var parent_pose := skeleton.get_bone_global_pose(s["parent"])
		if absf(parent_pose.basis.determinant()) < 1e-6:
			continue
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
			# carry the spring along with the part of their movement it shouldn't feel
			var carry := moved * (1.0 - float(s["inertia"]))
			s["tip"] += carry
			s["prev"] += carry
		var tip: Vector3 = s["tip"]
		var prev: Vector3 = s["prev"]
		var next: Vector3 = tip + (tip - prev) * (1.0 - float(s["drag"]))
		next += (target - tip) * minf(float(s["stiffness"]) * steps, 1.0)
		next += Vector3.DOWN * float(s["gravity"]) * 0.01 * steps * length
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


## How far (degrees) the hair bones sit from their rest pose now, the most of
## any (for tests).
func swing_deg() -> float:
	var most := 0.0
	for s in springs:
		var i: int = s["bone"]
		var q := skeleton.get_bone_pose_rotation(i)
		most = maxf(most, rad_to_deg(q.angle_to(skeleton.get_bone_rest(i).basis.get_rotation_quaternion())))
	return most
