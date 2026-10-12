extends RefCounted
## Eco's rest poses, layered over her animation by scripts/ps2/eco_model.gd
## (rest_pose) when she settles somewhere in the hub:
## - "sleep": curled up on her side, hands tucked under her chin, slow breathing;
## - "sit": sitting up on a seat, hands on her thighs, feet on the floor;
## - "chair": sat upright and still, facing straight ahead, hands flat on her
##   thighs, knees together (the fitting chairs, fitting_scene.gd);
## - "lounge": stretched out along a couch, propped up on one end, one arm
##   behind her head, a knee up;
## - "back": flat on her back, arms loose at her sides, one knee bent;
## - "prone": face down, arms folded up under the pillow, cheek on them, one
##   foot lifted.
## Each pose is authored like tools/eco/build_eco_vroid.py authors her
## animations: turns about skeleton-space axes through each joint (she faces -Z,
## her right is +X), parents first. A pose that lies her down is posed upright
## first and tipped over last, by turning her hips, so the limb turns stay easy
## to read. The model's origin is the floor under her hips; seat_height is the
## top of what she sits or lies on, so her feet find the floor whatever the seat.

const R := Vector3.RIGHT
const F := Vector3.FORWARD
const U := Vector3.UP
const BACK := Vector3.BACK

## Short names (as in the build script) -> the VRoid rig's bones.
const BONES := {
	"hips": "J_Bip_C_Hips", "spine": "J_Bip_C_Spine", "chest": "J_Bip_C_Chest", "neck": "J_Bip_C_Neck",
	"head": "J_Bip_C_Head",
	"thigh.R": "J_Bip_R_UpperLeg", "shin.R": "J_Bip_R_LowerLeg", "foot.R": "J_Bip_R_Foot",
	"thigh.L": "J_Bip_L_UpperLeg", "shin.L": "J_Bip_L_LowerLeg", "foot.L": "J_Bip_L_Foot",
	"upperarm.R": "J_Bip_R_UpperArm", "forearm.R": "J_Bip_R_LowerArm", "hand.R": "J_Bip_R_Hand",
	"upperarm.L": "J_Bip_L_UpperArm", "forearm.L": "J_Bip_L_LowerArm", "hand.L": "J_Bip_L_Hand",
}
const POSES := ["sleep", "sit", "lounge", "back", "prone", "chair"]
## Her leg (metres): hip joint to knee, knee to ankle, ankle above the sole.
const THIGH := 0.383
const SHIN := 0.451
const ANKLE := 0.097

## Arm turns for the sit (upperarm R/L forward, forearm R/L bend, forearm R/L in)
## and sleep (upperarm R/L forward, upperarm R/L in, forearm R/L bend) poses.
const SIT_ARMS := [30.0, 36.0, 18.0, 16.0, 42.0, -58.0]
const SLEEP_ARMS := [78.0, 72.0, 24.0, -6.0, 96.0, 102.0]

## How quickly she settles into a pose, and moves from one pose to another.
const SETTLE_RATE := 1.4
const SHIFT_RATE := 1.1

var skeleton: Skeleton3D
## Top of the seat (or bed) above the floor at her origin, in metres.
var seat_height := 0.5
## The pose shown (the one she is in or settling into), and the one she is
## leaving for it (blend goes 0 -> 1 from that one to this one).
var pose := ""
var from := ""
var blend := 1.0
## Animation -> rest pose, 0..1.
var weight := 0.0
var time := 0.0
var _idx := {}
var _hips_parent := -1
## What the layer wrote last frame (bone -> [before, after]), undone when
## nothing re-posed the bone since (her animation paused).
var _undo := {}


func _init(sk: Skeleton3D) -> void:
	skeleton = sk
	for key: String in BONES:
		_idx[key] = sk.find_bone(BONES[key])
	_hips_parent = sk.get_bone_parent(_idx["hips"])


## Whether her rig has every bone the poses use.
func usable() -> bool:
	return skeleton != null and not _idx.values().has(-1)


## Moves her toward the pose she wants ("" = back to her animation), over the
## pose her animation set this frame.
func step(delta: float, want: String) -> void:
	_restore()
	if want != "" and not POSES.has(want):
		want = ""
	if want != pose and want != "":
		if weight <= 0.0 or pose == "":
			pose = want
			from = ""
			blend = 1.0
		else:
			from = pose
			pose = want
			blend = 0.0
	weight = move_toward(weight, 1.0 if want != "" else 0.0, delta * SETTLE_RATE)
	blend = move_toward(blend, 1.0, delta * SHIFT_RATE)
	if weight <= 0.0:
		pose = ""
		from = ""
		return
	time += delta
	var current := _capture()
	var target := _target(pose)
	if blend < 1.0 and from != "":
		target = _mix(_target(from), target, smoothstep(0.0, 1.0, blend))
	var w := smoothstep(0.0, 1.0, weight)
	var shown := _mix(current, target, w)
	for key: String in BONES:
		var i: int = _idx[key]
		skeleton.set_bone_pose_rotation(i, shown[key])
		_undo[i] = [current[key], shown[key]]
	skeleton.set_bone_pose_position(_idx["hips"], shown["hips_at"])
	_undo[-1] = [current["hips_at"], shown["hips_at"]]


## Whether she is fully settled in a pose.
func settled() -> bool:
	return weight >= 1.0 and blend >= 1.0


func _restore() -> void:
	for i: int in _undo:
		var undo: Array = _undo[i]
		if i == -1:
			var hips: int = _idx["hips"]
			if skeleton.get_bone_pose_position(hips).is_equal_approx(undo[1]):
				skeleton.set_bone_pose_position(hips, undo[0])
		elif skeleton.get_bone_pose_rotation(i).is_equal_approx(undo[1]):
			skeleton.set_bone_pose_rotation(i, undo[0])
	_undo.clear()


func _capture() -> Dictionary:
	var out := {}
	for key: String in BONES:
		out[key] = skeleton.get_bone_pose_rotation(_idx[key])
	out["hips_at"] = skeleton.get_bone_pose_position(_idx["hips"])
	return out


func _mix(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out := {}
	for key: String in BONES:
		out[key] = (a[key] as Quaternion).slerp(b[key], t)
	out["hips_at"] = (a["hips_at"] as Vector3).lerp(b["hips_at"], t)
	return out


## The pose's bone rotations and hips position: built on the rig's rest pose,
## read back, then the skeleton is left as it was.
func _target(pose_name: String) -> Dictionary:
	var keep := _capture()
	for key: String in BONES:
		var i: int = _idx[key]
		skeleton.set_bone_pose_rotation(i, skeleton.get_bone_rest(i).basis.get_rotation_quaternion())
	var hips: int = _idx["hips"]
	skeleton.set_bone_pose_position(hips, skeleton.get_bone_rest(hips).origin)
	var spec: Dictionary = call("_" + pose_name)
	for turn: Array in spec["turns"]:
		_turn(turn[0], turn[1], turn[2])
	var out := _capture()
	var parent := skeleton.get_bone_global_pose(_hips_parent) if _hips_parent >= 0 else Transform3D()
	out["hips_at"] = parent.affine_inverse() * (spec["hips"] as Vector3)
	for key: String in BONES:
		skeleton.set_bone_pose_rotation(_idx[key], keep[key])
	skeleton.set_bone_pose_position(hips, keep["hips_at"])
	return out


## Rotates a bone about a skeleton-space axis through its joint, on top of its
## pose (build_eco_vroid.py turn()).
func _turn(key: String, axis: Vector3, deg: float) -> void:
	var i: int = _idx[key]
	var parent := skeleton.get_bone_parent(i)
	var pb := skeleton.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
	var before := Basis(skeleton.get_bone_pose_rotation(i))
	skeleton.set_bone_pose_rotation(i, (pb.inverse() * Basis(axis, deg_to_rad(deg)) * pb * before).get_rotation_quaternion())


## Her slow breath, -1..1, a breath every `period` seconds.
func _breath(period: float) -> float:
	return sin(time * TAU / period)


## Arms down from the T-pose (build_eco_vroid.py base_pose()).
func _arms_down() -> Array:
	return [["upperarm.R", F, 76.0], ["upperarm.L", F, -76.0], ["forearm.R", R, 14.0], ["forearm.L", R, 14.0]]


func _sit() -> Dictionary:
	var b := _breath(3.8)
	# thighs dip forward off the seat just enough that her feet reach the floor
	# with her shins upright (a low seat raises her knees instead)
	var dip := rad_to_deg(asin(clampf((seat_height + 0.08 - SHIN - ANKLE) / THIGH, -0.8, 0.8)))
	var turns := [
		# back straight and a little arched, shoulders back, head tilted
		["spine", R, 4.0], ["chest", R, 5.0 - 1.5 * b], ["neck", R, -6.0],
		["head", R, -5.0 + 1.0 * b], ["head", BACK, 7.0], ["head", U, 10.0 + 6.0 * sin(time * 0.35)],
	]
	turns.append_array(_arms_down())
	turns.append_array([
		# hands folded together on her top knee
		["upperarm.R", R, SIT_ARMS[0]], ["upperarm.L", R, SIT_ARMS[1]],
		["forearm.R", R, SIT_ARMS[2]], ["forearm.L", R, SIT_ARMS[3]],
		["forearm.R", U, SIT_ARMS[4]], ["forearm.L", U, SIT_ARMS[5]],
		["hand.R", R, 12.0], ["hand.L", R, 12.0],
		# legs crossed, right over left, knees together, toes pointed
		["thigh.L", R, 90.0 - dip], ["thigh.L", U, -5.0],
		["shin.L", R, -(90.0 - dip) + 8.0], ["shin.L", U, 6.0], ["foot.L", R, -8.0],
		["thigh.R", R, 108.0 - dip], ["thigh.R", U, 17.0],
		["shin.R", R, -(93.0 - dip)], ["shin.R", U, -6.0], ["foot.R", R, -32.0],
	])
	return {"turns": turns, "hips": Vector3(0.0, seat_height + 0.08, 0.0)}


func _chair() -> Dictionary:
	var b := _breath(4.6)
	var dip := rad_to_deg(asin(clampf((seat_height + 0.08 - SHIN - ANKLE) / THIGH, -0.8, 0.8)))
	var turns := [
		# upright, head level and straight ahead
		["spine", R, 2.0], ["chest", R, 1.0 - 1.0 * b], ["neck", R, -2.0], ["head", R, 2.0],
	]
	turns.append_array(_arms_down())
	turns.append_array([
		# hands flat on her thighs
		["upperarm.R", R, 8.0], ["upperarm.L", R, 8.0], ["upperarm.R", U, 8.0], ["upperarm.L", U, -8.0],
		["forearm.R", R, 44.0], ["forearm.L", R, 44.0], ["forearm.R", U, 14.0], ["forearm.L", U, -14.0],
		["hand.R", R, -10.0], ["hand.L", R, -10.0],
		# knees together, shins straight down, feet flat
		["thigh.L", R, 90.0 - dip], ["thigh.L", U, 3.0],
		["shin.L", R, -(90.0 - dip)], ["shin.L", U, -3.0],
		["thigh.R", R, 90.0 - dip], ["thigh.R", U, -3.0],
		["shin.R", R, -(90.0 - dip)], ["shin.R", U, 3.0],
	])
	return {"turns": turns, "hips": Vector3(0.0, seat_height + 0.08, 0.0)}


func _lounge() -> Dictionary:
	var b := _breath(4.2)
	var turns := [
		# curled up off the cushion at her end of the couch, head tilted, looking out at the room
		["spine", R, -10.0], ["chest", R, -6.0 - 1.5 * b], ["neck", R, -12.0], ["head", R, -14.0],
		["head", BACK, -8.0], ["head", U, -18.0 + 4.0 * sin(time * 0.3)],
	]
	turns.append_array(_arms_down())
	turns.append_array([
		# right hand behind her head
		["upperarm.R", F, -125.0], ["upperarm.R", R, 35.0], ["forearm.R", F, -14.0], ["forearm.R", F, -120.0],
		# left hand resting on her stomach, wrist soft
		["upperarm.L", R, 0.0], ["upperarm.L", F, 8.0], ["forearm.L", R, 20.0], ["forearm.L", U, -70.0],
		["hand.L", R, 16.0],
		# right knee up and leaning in over her left leg, which lies out along the couch, toes pointed
		["thigh.R", R, 58.0], ["thigh.R", U, 22.0], ["shin.R", R, -64.0], ["foot.R", R, -55.0],
		["thigh.L", R, 18.0], ["thigh.L", U, -3.0], ["shin.L", R, -6.0], ["foot.L", R, -45.0],
		# tip her back
		["hips", R, 72.0],
	])
	return {"turns": turns, "hips": Vector3(0.0, seat_height + 0.1, 0.0)}


func _sleep() -> Dictionary:
	var b := _breath(5.0)
	var turns := [
		["spine", R, -12.0], ["chest", R, -6.0 - 2.0 * b], ["neck", R, -10.0], ["head", R, -12.0],
	]
	turns.append_array(_arms_down())
	turns.append_array([
		# hands together under her cheek
		["upperarm.R", R, SLEEP_ARMS[0]], ["upperarm.L", R, SLEEP_ARMS[1]],
		["upperarm.R", U, SLEEP_ARMS[2]], ["upperarm.L", U, SLEEP_ARMS[3]],
		["forearm.R", R, SLEEP_ARMS[4]], ["forearm.L", R, SLEEP_ARMS[5]],
		["hand.R", R, 20.0], ["hand.L", R, 20.0],
		# knees drawn up together, the top knee resting on the lower one, toes pointed
		["thigh.R", R, 80.0], ["thigh.L", R, 70.0], ["thigh.R", U, 9.0],
		["shin.R", R, -106.0], ["shin.L", R, -96.0],
		["foot.R", R, -35.0], ["foot.L", R, -35.0],
		# over onto her left side (her head goes to -X, she faces -Z), head up on the pillow
		["hips", BACK, 84.0],
	])
	return {"turns": turns, "hips": Vector3(0.0, seat_height + 0.17, 0.0)}


func _back() -> Dictionary:
	var b := _breath(4.6)
	var turns := [
		["spine", R, -2.0], ["chest", R, -1.5 * b], ["neck", R, -6.0], ["head", R, -4.0], ["head", U, 14.0],
	]
	turns.append_array(_arms_down())
	turns.append_array([
		# arms loose at her sides, a little out, palms down
		["upperarm.R", F, -12.0], ["upperarm.L", F, 12.0], ["forearm.R", R, 8.0], ["forearm.L", R, 8.0],
		# right knee bent up a little, toes pointed
		["thigh.R", R, 28.0], ["shin.R", R, -52.0], ["thigh.L", R, 3.0], ["shin.L", R, -4.0],
		["foot.R", R, -20.0], ["foot.L", R, -40.0],
		# tip her onto her back
		["hips", R, 90.0],
	])
	return {"turns": turns, "hips": Vector3(0.0, seat_height + 0.105, 0.0)}


func _prone() -> Dictionary:
	var b := _breath(4.8)
	var turns := [
		# head turned onto her right cheek
		["spine", R, 2.0 * b], ["neck", R, -8.0], ["head", U, -72.0],
		# arms up past her head (from the T-pose), forearms folded in under the pillow
		["upperarm.R", F, -58.0], ["upperarm.L", F, 58.0],
		["upperarm.R", R, -20.0], ["upperarm.L", R, -20.0],
		["forearm.R", F, -95.0], ["forearm.L", F, 95.0],
		# legs out straight, her left foot lifted off the bed, toes pointed
		["thigh.L", R, -4.0], ["shin.L", R, -55.0], ["thigh.R", U, -4.0],
		["foot.R", R, -60.0], ["foot.L", R, -45.0],
		# tip her face down
		["hips", R, -90.0],
	]
	return {"turns": turns, "hips": Vector3(0.0, seat_height + 0.115, 0.0)}
