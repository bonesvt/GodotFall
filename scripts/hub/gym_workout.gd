extends Node3D
## One workout in Biggie's gym (gym.gd WORKOUTS) as a short scene: the hub
## pauses, Eco does a few reps at the equipment (posed by hand here, on her own
## model, while her springs still bounce), the camera cuts between three set
## shots, and Biggie coaches from the doorway in captions until she says her
## piece. F skips it once it has started. run_manager.gd adds the points when
## `finished` fires.
##
## Poses are built each frame from her rest pose in skeleton space (she faces
## -Z, her right is +X, up is +Y): the hips are moved, the spine bones aimed,
## and arms and legs placed with two-bone IK on hand and foot targets.

signal finished

const ECO := preload("res://assets/models/eco.tscn")
const GymRoom := preload("res://scripts/hub/gym_room.gd")
const Gym := preload("res://scripts/hub/gym.gd")
const Babble := preload("res://scripts/hub/babble.gd")

## Seconds each camera shot holds.
const SHOT_TIME := 3.3
## Seconds before F skips it.
const SKIP_AFTER := 0.6
## How high her back sits over the floor mats when she lies down.
const LYING_Y := 0.11

## The three shots of each workout, in the spot's frame (gym_room.gd SPOTS:
## Eco faces -Z, her right is +X; lying down her head is toward +Z): where the
## camera starts and drifts to, what it looks at, its field of view. The
## squats open on the low rear three-quarter shot from behind her hips.
const SHOTS := {
	"squat": [
		{"from": Vector3(0.75, 0.75, 1.7), "to": Vector3(0.4, 0.8, 1.55), "look": Vector3(0, 0.75, 0), "fov": 42.0},
		{"from": Vector3(2.2, 2.0, 0.2), "to": Vector3(2.25, 2.05, 0.45), "look": Vector3(0, 0.85, -0.1), "fov": 45.0},
		{"from": Vector3(-0.5, 1.35, -1.9), "to": Vector3(-0.3, 1.3, -1.7), "look": Vector3(0, 1.3, 0), "fov": 38.0},
	],
	"bridge": [
		{"from": Vector3(1.9, 0.75, 0.8), "to": Vector3(1.8, 0.7, 1.1), "look": Vector3(0, 0.25, 0.9), "fov": 48.0},
		{"from": Vector3(-1.3, 1.3, 1.9), "to": Vector3(-1.2, 1.25, 1.7), "look": Vector3(0, 0.35, 0.7), "fov": 42.0},
		{"from": Vector3(-0.7, 0.85, 2.4), "to": Vector3(-0.6, 0.8, 2.2), "look": Vector3(0, 0.25, 1.35), "fov": 40.0},
	],
	"crunch": [
		{"from": Vector3(1.8, 0.7, 0.9), "to": Vector3(1.75, 0.75, 1.15), "look": Vector3(0, 0.3, 1.0), "fov": 48.0},
		{"from": Vector3(1.4, 1.9, 0.4), "to": Vector3(1.35, 1.85, 0.6), "look": Vector3(0, 0.3, 1.0), "fov": 45.0},
		{"from": Vector3(1.2, 0.8, 0.3), "to": Vector3(1.1, 0.8, 0.45), "look": Vector3(0, 0.55, 1.3), "fov": 40.0},
	],
	"pullup": [
		{"from": Vector3(0.8, 1.0, 1.5), "to": Vector3(0.6, 1.1, 1.4), "look": Vector3(0, 1.7, -0.25), "fov": 50.0},
		{"from": Vector3(-1.6, 1.5, -1.3), "to": Vector3(-1.5, 1.6, -1.1), "look": Vector3(0, 1.8, -0.25), "fov": 50.0},
		{"from": Vector3(-0.4, 1.9, -2.0), "to": Vector3(-0.3, 2.0, -1.8), "look": Vector3(0, 2.15, -0.25), "fov": 40.0},
	],
	"bag": [
		{"from": Vector3(0.55, 1.65, 1.3), "to": Vector3(0.45, 1.6, 1.15), "look": Vector3(0, 1.35, -0.8), "fov": 45.0},
		{"from": Vector3(2.0, 1.2, -0.5), "to": Vector3(1.9, 1.25, -0.1), "look": Vector3(0, 1.1, -0.3), "fov": 50.0},
		{"from": Vector3(1.4, 1.45, -1.2), "to": Vector3(1.3, 1.45, -1.05), "look": Vector3(0, 1.4, -0.2), "fov": 45.0},
	],
}

## Each rep's length (s) and the share of it held at the top (or bottom).
## How far her wrist sits from a bar she grips: the bar lies in her palm.
const GRIP := 0.07
const REPS := {"squat": [2.4, 0.08], "bridge": [2.2, 0.2], "crunch": [1.8, 0.1], "pullup": [2.6, 0.25], "bag": [1.0, 0.0]}

## Bones posed here (VRoid names), parents first.
const BONES := {
	"hips": "J_Bip_C_Hips", "spine": "J_Bip_C_Spine", "chest": "J_Bip_C_Chest", "upper_chest": "J_Bip_C_UpperChest",
	"neck": "J_Bip_C_Neck", "head": "J_Bip_C_Head",
	"thigh.L": "J_Bip_L_UpperLeg", "shin.L": "J_Bip_L_LowerLeg", "foot.L": "J_Bip_L_Foot", "toe.L": "J_Bip_L_ToeBase",
	"thigh.R": "J_Bip_R_UpperLeg", "shin.R": "J_Bip_R_LowerLeg", "foot.R": "J_Bip_R_Foot", "toe.R": "J_Bip_R_ToeBase",
	"shoulder.L": "J_Bip_L_Shoulder", "upperarm.L": "J_Bip_L_UpperArm", "forearm.L": "J_Bip_L_LowerArm", "hand.L": "J_Bip_L_Hand",
	"shoulder.R": "J_Bip_R_Shoulder", "upperarm.R": "J_Bip_R_UpperArm", "forearm.R": "J_Bip_R_LowerArm", "hand.R": "J_Bip_R_Hand",
}

## Finger joints curled to grip (and the thumb's), per side.
const FINGERS := ["Index", "Middle", "Ring", "Little"]
## How far each finger joint curls (degrees) in a full grip.
const CURL := [48.0, 62.0, 50.0]

var workout := ""
## The spot (gym_room.gd: pos, yaw, and the room's own prop to hide).
var spot := {}
## The gym's floor area (x, z): the camera stays inside it.
var bounds := Rect2()
var eco: Node3D
var camera: Camera3D
## Seconds since the scene started.
var time := 0.0
var shot := -1
var done := false
var _sk: Skeleton3D
var _b := {}
var _rest := {}       # bone -> rest global pose (skeleton space)
var _len := {}        # bone -> distance to its IK child
var _prop: Node3D     # the bar or sandbag she uses, posed with her
var _voice: AudioStreamPlayer
var _caption: Label
var _name: Label
var _panel: PanelContainer


static func create(p_workout: String, p_spot: Dictionary, p_bounds: Rect2, suit: Dictionary, fitness: Dictionary) -> Node3D:
	var w: Node3D = load("res://scripts/hub/gym_workout.gd").new()
	w.workout = p_workout
	w.spot = p_spot
	w.bounds = p_bounds
	w.set_meta("suit", suit)
	w.set_meta("fitness", fitness)
	w.name = "Workout"
	return w


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var suit: Dictionary = get_meta("suit", {})
	eco = ECO.instantiate()
	eco.idle_motion = false
	eco.suit_weight = suit.get("weight", "medium")
	eco.suit_tier = suit.get("tier", 0)
	add_child(eco)
	eco.set_fitness(get_meta("fitness", {}))
	eco.global_transform = _eco_frame(0.0)
	_sk = eco.skeleton
	if _sk != null:
		for key: String in BONES:
			_b[key] = _sk.find_bone(BONES[key])
		for side in ["L", "R"]:
			for finger in FINGERS + ["Thumb"]:
				for j in 3:
					_b["%s%d.%s" % [finger, j + 1, side]] = _sk.find_bone("J_Bip_%s_%s%d" % [side, finger, j + 1])
		for key: String in _b:
			if _b[key] >= 0:
				_rest[key] = _sk.get_bone_global_rest(_b[key])
		for chain in [["thigh", "shin"], ["shin", "foot"], ["upperarm", "forearm"], ["forearm", "hand"]]:
			for side in ["L", "R"]:
				var a: String = chain[0] + "." + side
				var c: String = chain[1] + "." + side
				if _rest.has(a) and _rest.has(c):
					_len[a] = (_rest[c].origin - _rest[a].origin).length()
		eco.posing = _pose
	var room_prop: Node3D = spot.get("prop")
	if room_prop != null:
		room_prop.visible = false
	if workout == "squat":
		_prop = GymRoom.barbell_model()
	elif workout == "bridge":
		_prop = GymRoom.sandbag_model()
	if _prop != null:
		add_child(_prop)
	camera = Camera3D.new()
	camera.near = 0.04
	add_child(camera)
	camera.make_current()
	_voice = AudioStreamPlayer.new()
	add_child(_voice)
	_build_caption()
	_next_shot()


func _exit_tree() -> void:
	var room_prop: Node3D = spot.get("prop")
	if room_prop != null and is_instance_valid(room_prop):
		room_prop.visible = true


func _process(delta: float) -> void:
	if done:
		return
	time += delta
	eco.global_transform = _eco_frame(time)
	if time >= (shot + 1) * SHOT_TIME:
		_next_shot()
		if done:
			return
	var s: Dictionary = SHOTS[workout][shot]
	var k := clampf((time - shot * SHOT_TIME) / SHOT_TIME, 0.0, 1.0)
	var at := _clamped(_world(s["from"].lerp(s["to"], k * k * (3.0 - 2.0 * k))))
	var look := _world(s["look"])
	camera.global_position = at
	camera.look_at(look, Vector3.UP)
	camera.fov = s["fov"]


## F (run_manager.gd): skip to the end, once it has got going.
func skip() -> void:
	if time >= SKIP_AFTER:
		_finish()


func _next_shot() -> void:
	shot += 1
	var shots: Array = SHOTS[workout]
	if shot >= shots.size():
		_finish()
		return
	if shot < shots.size() - 1:
		var lines: Array = Gym.COACHING[workout]
		_say("biggie", lines[shot % lines.size()])
	else:
		_say("eco", Gym.DONE_LINES[workout])


func _finish() -> void:
	if done:
		return
	done = true
	_voice.stop()
	finished.emit()


func _say(speaker: String, text: String) -> void:
	var b := Babble.make(speaker, text)
	_voice.stream = b["stream"]
	_voice.play()
	_name.text = "BIGGIE" if speaker == "biggie" else "ECO"
	_name.add_theme_color_override("font_color", Color(0.95, 0.75, 0.4) if speaker == "biggie" else Color(1.0, 0.45, 0.45))
	_caption.text = text


# --- where things are -------------------------------------------------------------

## The spot's frame: its floor point, turned to its yaw.
func _frame() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(spot.get("yaw", 0.0))), spot.get("pos", Vector3.ZERO))


func _world(local: Vector3) -> Vector3:
	return _frame() * local


func _clamped(p: Vector3) -> Vector3:
	if bounds.size == Vector2.ZERO:
		return p
	var r := bounds.grow(-0.2)
	return Vector3(clampf(p.x, r.position.x, r.end.x), p.y, clampf(p.z, r.position.y, r.end.y))


## Where her model stands (or lies) at `t` seconds. Lying down her back is on
## the mat, her head toward +Z of the spot; on the pull-up bar she hangs and
## rises with each rep.
func _eco_frame(t: float) -> Transform3D:
	var f := _frame()
	match workout:
		"bridge", "crunch":
			return Transform3D(f.basis * Basis(Vector3.RIGHT, PI / 2), f.origin + Vector3(0, LYING_Y, 0))
		"pullup":
			return Transform3D(f.basis, f * Vector3(0, _hang_y() + 0.6 * depth(t), -0.22))
	return f


## How high she hangs from the bar with her arms nearly straight.
func _hang_y() -> float:
	if not _rest.has("upperarm.R"):
		return 0.5
	var shoulder: Vector3 = _rest["upperarm.R"].origin
	var reach: float = (_len.get("upperarm.R", 0.25) + _len.get("forearm.R", 0.25)) * 0.97
	var out := 0.3 - absf(shoulder.x)
	return GymRoom.BAR_H - shoulder.y - sqrt(maxf(reach * reach - out * out, 0.01)) - 0.06 - GRIP


## How far into the rep she is at `t` seconds (0 resting, 1 the bottom of the
## squat, the top of the pull-up). The heavy bag counts punches instead.
func depth(t: float) -> float:
	var r: Array = REPS.get(workout, [2.0, 0.0])
	return _rep(t, r[0], r[1])


## One rep: 0 -> 1 -> 0 over `period` seconds, easing at both ends, pausing
## `hold` of the period at the top.
static func _rep(t: float, period: float, hold := 0.0) -> float:
	var p := fmod(t, period) / period
	var up := (1.0 - hold) * 0.5
	if p < up:
		return smoothstep(0.0, 1.0, p / up)
	if p < up + hold:
		return 1.0
	return smoothstep(1.0, 0.0, (p - up - hold) / up)


# --- posing ---------------------------------------------------------------------

func _pose(_model: Node3D) -> void:
	if _sk == null or _rest.is_empty():
		return
	for key: String in _b:
		var i: int = _b[key]
		if i >= 0:
			_sk.set_bone_pose_rotation(i, _sk.get_bone_rest(i).basis.get_rotation_quaternion())
			_sk.set_bone_pose_position(i, _sk.get_bone_rest(i).origin)
	match workout:
		"squat":
			_pose_squat()
		"bridge":
			_pose_bridge()
		"crunch":
			_pose_crunch()
		"pullup":
			_pose_pullup()
		"bag":
			_pose_bag()


func _pose_squat() -> void:
	var s := depth(time)
	_move_hips(Vector3(0, -0.4 * s, 0.17 * s))
	_turn("hips", Vector3.RIGHT, -16.0 * s)
	_turn("spine", Vector3.RIGHT, -12.0 * s)
	_turn("chest", Vector3.RIGHT, 10.0 * s)
	_turn("neck", Vector3.RIGHT, 10.0 * s)
	_turn("head", Vector3.RIGHT, 14.0 * s)
	for side in ["L", "R"]:
		var x := 1.0 if side == "R" else -1.0
		var ankle: Vector3 = _rest["foot." + side].origin + Vector3(x * 0.06, 0, 0)
		_leg(side, ankle, Vector3(x * 0.35, 0, -1), Vector3(x * 0.25, 0, -1))
	# the bar rests across the top of her back, behind her neck; her hands hold it wide
	var on_back: Vector3 = _rest["neck"].origin + Vector3(0, -0.07, 0.115)
	for side in ["L", "R"]:
		var x := 1.0 if side == "R" else -1.0
		# wrists just under and behind the bar so her fingers close over it
		_arm(side, _follow("upper_chest", on_back + Vector3(x * 0.34, -GRIP, 0.02)), Vector3(x, -1.0, 0.6))
	_place_prop(Transform3D(_turned("upper_chest"), _follow("upper_chest", on_back)))
	_grip("L", 1.0)
	_grip("R", 1.0)


func _pose_bridge() -> void:
	var s := depth(time)
	var lift := 0.24 * s
	_move_hips(Vector3(0, 0, -lift))
	var a := atan2(lift, 0.42)
	_aim("spine", "chest", Vector3(0, cos(a), sin(a)))
	_aim("chest", "upper_chest", Vector3(0, cos(a), sin(a)))
	_aim("upper_chest", "neck", Vector3(0, cos(a * 0.9), sin(a * 0.9)))
	_aim("neck", "head", Vector3(0, 1, 0.12))
	_lying_legs()
	var hips := _pose_of("hips").origin
	var bag := hips + Vector3(0, 0.02, -0.13)
	for side in ["L", "R"]:
		var x := 1.0 if side == "R" else -1.0
		_arm(side, bag + Vector3(x * 0.2, 0, -0.02), Vector3(x, 0, 1))
	_place_prop(Transform3D(Basis(), bag))
	_grip("L", 0.8)
	_grip("R", 0.8)


func _pose_crunch() -> void:
	var c := deg_to_rad(34.0) * depth(time)
	_aim("spine", "chest", Vector3(0, cos(c * 0.5), -sin(c * 0.5)))
	_aim("chest", "upper_chest", Vector3(0, cos(c), -sin(c)))
	_aim("upper_chest", "neck", Vector3(0, cos(c * 1.2), -sin(c * 1.2)))
	_aim("neck", "head", Vector3(0, cos(c * 1.4), -sin(c * 1.4)))
	_lying_legs()
	# hands laced lightly behind her head, elbows out
	var head: Vector3 = _rest["head"].origin
	for side in ["L", "R"]:
		var x := 1.0 if side == "R" else -1.0
		_arm(side, _follow("head", head + Vector3(x * 0.08, 0.09, 0.08)), Vector3(x, 0.2, -0.3))
		_grip(side, 0.35)


## Lying on her back, knees up, feet flat on the mat by her hips.
func _lying_legs() -> void:
	var hip_y: float = _rest["thigh.R"].origin.y
	for side in ["L", "R"]:
		var x := 1.0 if side == "R" else -1.0
		_leg(side, Vector3(x * 0.09, hip_y - 0.5, -0.01), Vector3(0, 0, -1), Vector3(0, -1, -0.12))


func _pose_pullup() -> void:
	var s := depth(time)
	_turn("spine", Vector3.RIGHT, 4.0 + 4.0 * s)
	_turn("neck", Vector3.RIGHT, 6.0 * s)
	var to_skel := _sk.global_transform.affine_inverse()
	for side in ["L", "R"]:
		var x := 1.0 if side == "R" else -1.0
		var grip := to_skel * _world(Vector3(x * 0.3, GymRoom.BAR_H - GRIP, -0.23))
		_arm(side, grip, Vector3(x * 0.6, -1.0, 0.25))
		_grip(side, 1.0)
		# knees bent a little, ankles back
		var ankle: Vector3 = _rest["foot." + side].origin + Vector3(-x * 0.02, 0.1, 0.2)
		_leg(side, ankle, Vector3(0, 0, -1), Vector3(0, -0.6, -1))


func _pose_bag() -> void:
	var beat := fmod(time, 1.0)
	var jab := sin(clampf(beat / 0.32, 0.0, 1.0) * PI)
	var cross := sin(clampf((beat - 0.45) / 0.36, 0.0, 1.0) * PI)
	_move_hips(Vector3(0, -0.05, 0))
	_turn("hips", Vector3.UP, -12.0 + 22.0 * cross)
	_turn("chest", Vector3.UP, 8.0 * jab - 10.0 * cross)
	# boxer's stance: left foot forward, right back
	_leg("L", _rest["foot.L"].origin + Vector3(0.0, 0, -0.17), Vector3(-0.2, 0, -1), Vector3(0.15, 0, -1))
	_leg("R", _rest["foot.R"].origin + Vector3(0.05, 0, 0.19), Vector3(0.3, 0, -1), Vector3(0.45, 0, -1))
	var head: Vector3 = _pose_of("head").origin
	var to_skel := _sk.global_transform.affine_inverse()
	var bag := to_skel * _world(Vector3(0, 1.38, -0.78))
	var face := Vector3(bag.x - head.x, 0, bag.z - head.z).normalized()
	for side in ["L", "R"]:
		var x := 1.0 if side == "R" else -1.0
		var guard := head + Vector3(x * 0.1, -0.13, -0.16)
		var hit := bag - face * 0.12 + Vector3(x * 0.04, 0, 0)
		var ext := jab if side == "L" else cross
		_arm(side, guard.lerp(hit, ext), Vector3(x * 0.6, -1.0, 0.3))
		_grip(side, 1.25)
	var bag_node: Node3D = spot.get("bag")
	if bag_node != null:
		bag_node.rotation = Vector3(0.06 * maxf(jab, cross), 0, 0)


func _pose_of(key: String) -> Transform3D:
	return _global(_b[key])


## A bone's pose in skeleton space, worked out from the local poses just set:
## newer Godot only refreshes the skeleton's global poses once a frame, so
## they would still hold the pose from before this frame's posing.
func _global(i: int) -> Transform3D:
	var t := _sk.get_bone_pose(i)
	var p := _sk.get_bone_parent(i)
	while p >= 0:
		t = _sk.get_bone_pose(p) * t
		p = _sk.get_bone_parent(p)
	return t


## Where a point (skeleton space, in her rest pose) carried by a bone is now.
func _follow(key: String, rest_point: Vector3) -> Vector3:
	var rest: Transform3D = _rest[key]
	return _pose_of(key) * (rest.affine_inverse() * rest_point)


## How far a bone has turned from its rest pose (skeleton space).
func _turned(key: String) -> Basis:
	var rest: Transform3D = _rest[key]
	return _pose_of(key).basis.orthonormalized() * rest.basis.orthonormalized().inverse()


## Moves her hips (and all of her above and below them) in skeleton space.
func _move_hips(offset: Vector3) -> void:
	var i: int = _b["hips"]
	var parent := _sk.get_bone_parent(i)
	var pb := _global(parent).basis if parent >= 0 else Basis()
	_sk.set_bone_pose_position(i, _sk.get_bone_pose_position(i) + pb.inverse() * offset)


## Turns a bone about a skeleton-space axis through its joint, on top of its pose.
func _turn(key: String, axis: Vector3, deg: float) -> void:
	if absf(deg) > 0.01:
		_rotate(_b[key], Basis(axis.normalized(), deg_to_rad(deg)))


func _rotate(i: int, r: Basis) -> void:
	var parent := _sk.get_bone_parent(i)
	var pb := _global(parent).basis.orthonormalized() if parent >= 0 else Basis()
	var local := Basis(_sk.get_bone_pose_rotation(i))
	_sk.set_bone_pose_rotation(i, (pb.inverse() * r * pb * local).get_rotation_quaternion())


## Turns a bone so the way to its child bone points along `dir` (skeleton space).
func _aim(key: String, child: String, dir: Vector3) -> void:
	var i: int = _b[key]
	var from := _pose_of(child).origin - _pose_of(key).origin
	if from.length() < 1e-5 or dir.length() < 1e-5:
		return
	from = from.normalized()
	dir = dir.normalized()
	var axis := from.cross(dir)
	if axis.length() < 1e-6:
		return
	_rotate(i, Basis(axis.normalized(), from.angle_to(dir)))


## Two-bone IK: bends `upper` and its child so the end lands on `target`, the
## middle joint (knee, elbow) toward `pole`.
func _ik(upper: String, lower: String, end: String, target: Vector3, pole: Vector3) -> void:
	var a := _pose_of(upper).origin
	var l1: float = _len[upper]
	var l2: float = _len[lower]
	var to := target - a
	var d := clampf(to.length(), 0.02, (l1 + l2) * 0.999)
	var dir := to.normalized()
	var x := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h := sqrt(maxf(l1 * l1 - x * x, 0.0))
	var p := pole - dir * pole.dot(dir)
	if p.length() < 1e-4:
		p = dir.cross(Vector3.RIGHT)
	var mid := a + dir * x + p.normalized() * h
	_aim(upper, lower, mid - a)
	_aim(lower, end, a + dir * d - _pose_of(lower).origin)


func _leg(side: String, ankle: Vector3, knee_pole: Vector3, toe_dir: Vector3) -> void:
	_ik("thigh." + side, "shin." + side, "foot." + side, ankle, knee_pole)
	_aim("foot." + side, "toe." + side, toe_dir)


func _arm(side: String, hand: Vector3, elbow_pole: Vector3) -> void:
	_ik("upperarm." + side, "forearm." + side, "hand." + side, hand, elbow_pole)


## Curls her fingers round a bar (1 a full grip or a fist, 0 open), the
## thumb across them.
func _grip(side: String, amount: float) -> void:
	var turned := _turned("hand." + side)
	# at rest her hands point out along +-X, palms down: the knuckles hinge about Z
	var hinge := turned * (Vector3.BACK if side == "L" else Vector3.FORWARD)
	for finger in FINGERS:
		for j in 3:
			var key := "%s%d.%s" % [finger, j + 1, side]
			if _b.get(key, -1) >= 0:
				_rotate(_b[key], Basis(hinge.normalized(), deg_to_rad(CURL[j] * amount)))
	var across := turned * Vector3.UP * (1.0 if side == "L" else -1.0)
	for j in 3:
		var key := "Thumb%d.%s" % [j + 1, side]
		if _b.get(key, -1) >= 0:
			_rotate(_b[key], Basis(across.normalized(), deg_to_rad(22.0 * amount)))


## Puts the bar or sandbag (skeleton space) where her pose has it.
func _place_prop(t: Transform3D) -> void:
	if _prop != null:
		_prop.global_transform = _sk.global_transform * Transform3D(t.basis.orthonormalized(), t.origin)


func _build_caption() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 7
	add_child(layer)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.02, 0.05, 0.72)
	style.set_corner_radius_all(10)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 12
	style.content_margin_bottom = 14
	_panel.add_theme_stylebox_override("panel", style)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -340
	_panel.offset_right = 340
	_panel.offset_top = -118
	_panel.offset_bottom = -24
	layer.add_child(_panel)
	var box := VBoxContainer.new()
	_panel.add_child(box)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 17)
	box.add_child(_name)
	_caption = Label.new()
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.add_theme_font_size_override("font_size", 20)
	_caption.custom_minimum_size = Vector2(636, 0)
	box.add_child(_caption)
	var hint := Label.new()
	hint.text = "%s   [F] skip" % Gym.WORKOUTS[workout]["name"].to_upper()
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.7, 0.68, 0.72))
	box.add_child(hint)
