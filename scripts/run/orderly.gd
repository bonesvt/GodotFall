extends Node3D
## A colony orderly (assets/models/npc/orderly.glb, built by
## tools/npc/build_npc.py "orderly"): a white suit, gloves and a faceless
## helmet with a black visor.
##
## Moved the way the trial intro (trial_intro.gd) moves its orderlies: it
## swings LegL and LegR (rotation.x, + forward), bobs Body (position.y) and
## lifts Body/Arm, the arm toward Ophelia (rotation.x, 0 hanging, PI straight
## up). Those are empty pivots here; each frame the model's legs and arms are
## aimed the way they point, its knees folding as a leg comes back.

const MODEL := "res://assets/models/npc/orderly.glb"
## Where the pivots sit (the capsule stand-ins' layout).
const HIP := Vector3(0.08, 0.88, 0.0)
const SHOULDER := Vector3(0.2, 1.42, 0.0)
## How far the hanging arms sit out from its sides (rad), and the elbows' bend.
const SPLAY := 0.12
const ELBOW := 0.25

var side := 1.0
var _skel: Skeleton3D
var _model: Node3D
var _arm: Node3D
var _other: Node3D


## One orderly; `s` -1 or 1, which side of her it walks on (its arm toward
## her is the one on the other side of it).
static func create(s: float) -> Node3D:
	var o: Node3D = load("res://scripts/run/orderly.gd").new()
	o.side = s
	o.name = "Orderly"
	return o


func _init() -> void:
	process_priority = 100   # after the cutscene has moved the pivots


func _ready() -> void:
	for leg in [["LegL", -HIP.x], ["LegR", HIP.x]]:
		var hip := Node3D.new()
		hip.name = leg[0]
		hip.position = Vector3(leg[1], HIP.y, 0)
		add_child(hip)
	var body := Node3D.new()
	body.name = "Body"
	add_child(body)
	_arm = Node3D.new()
	_arm.name = "Arm"
	_arm.position = Vector3(SHOULDER.x * -side, SHOULDER.y, 0)
	body.add_child(_arm)
	_other = Node3D.new()
	_other.name = "OtherArm"
	_other.position = Vector3(SHOULDER.x * side, SHOULDER.y, 0)
	_other.rotation.x = 0.1
	body.add_child(_other)
	if ResourceLoader.exists(MODEL):
		_model = (load(MODEL) as PackedScene).instantiate()
		_model.name = "Model"
		add_child(_model)
		_skel = _model.find_child("Skeleton3D", true, false) as Skeleton3D
	_pose()


func _process(_delta: float) -> void:
	_pose()


func _pose() -> void:
	if _skel == null:
		return
	_model.position.y = ($Body as Node3D).position.y
	var down := Vector3.DOWN
	for s in ["L", "R"]:
		var swing := (get_node("Leg" + s) as Node3D).rotation.x
		var thigh := down.rotated(Vector3.RIGHT, swing)
		var fold := 0.08 + 0.7 * maxf(0.0, -swing)   # the leg behind folds at the knee
		_aim("J_Bip_%s_UpperLeg" % s, "J_Bip_%s_LowerLeg" % s, thigh)
		_aim("J_Bip_%s_LowerLeg" % s, "J_Bip_%s_Foot" % s, thigh.rotated(Vector3.RIGHT, -fold))
		_aim("J_Bip_%s_Foot" % s, "J_Bip_%s_ToeBase" % s, Vector3.FORWARD.rotated(Vector3.RIGHT, -0.35))
	# its right is +x: the arm toward her is its right on side -1, its left on 1
	var toward := "R" if side < 0.0 else "L"
	var away := "L" if side < 0.0 else "R"
	_arm_to(toward, _arm.rotation.x)
	_arm_to(away, _other.rotation.x)


func _arm_to(s: String, lift: float) -> void:
	var out := SPLAY * (1.0 if s == "R" else -1.0) * (1.0 - clampf(lift / 1.5, 0.0, 1.0))
	var upper := Vector3.DOWN.rotated(Vector3.FORWARD, -out).rotated(Vector3.RIGHT, lift)
	_aim("J_Bip_%s_UpperArm" % s, "J_Bip_%s_LowerArm" % s, upper)
	var bend := ELBOW * (1.0 - clampf(lift / 2.0, 0.0, 0.8))
	_aim("J_Bip_%s_LowerArm" % s, "J_Bip_%s_Hand" % s, upper.rotated(Vector3.RIGHT, bend))


## Turns `bone` (from its rest) so the way to `child` points along `dir`
## (skeleton space).
func _aim(bone: String, child: String, dir: Vector3) -> void:
	var b := _skel.find_bone(bone)
	var c := _skel.find_bone(child)
	if b < 0 or c < 0:
		return
	var parent := _skel.get_bone_parent(b)
	var pg := _skel.get_bone_global_pose(parent) if parent >= 0 else Transform3D()
	var rest_g := pg * _skel.get_bone_rest(b)
	var from := (rest_g.basis * _skel.get_bone_rest(c).origin).normalized()
	var want := Basis(Quaternion(from, dir.normalized())) * rest_g.basis
	_skel.set_bone_pose_rotation(b, (pg.basis.inverse() * want).get_rotation_quaternion())
