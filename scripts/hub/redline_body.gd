extends SkeletonModifier3D
## Redline's changes to Eco's body (redline.gd), on her own skeleton so they
## move with her: a modifier that runs after her animation every frame and
## reshapes the bones, plus her veins, hung on her bones like the Shepherd's
## gear (colony_gear.gd _root):
##   wiring   red veins up her arms and the sides of her neck, glowing with
##            each heartbeat (faster while she's high)
##   heavy    her whole skeleton a size up, evenly (HEAVY each way, about 15%
##            more of her), so her proportions stay her own
##   legs     her shins lengthened (SHIN), her whole skeleton lifted so her
##            feet still meet the floor
##   posture  her spine, neck and head held at rest, straight and level, and
##            her legs (and arms, off the gun) only moving in jerks
##            (PUPPET_STEP s between poses)
## Body horror only: nothing touches her chest, hips or thighs on their own.
## On the copy in her gun's first-person arms her arms are left alone, so she
## still holds it. apply() puts it on (or updates it on) a model of her.

const Redline := preload("res://scripts/hub/redline.gd")
const ColonyGear := preload("res://scripts/hub/colony_gear.gd")

const NODE := "RedlineBody"
const HEAVY := 1.048
const SHIN := 1.3
const VEIN := Color(0.95, 0.08, 0.06)
const VEIN_R := 0.0018
## Seconds between the poses her limbs jerk to under the forced posture.
const PUPPET_STEP := 0.14
const SPINE := ["J_Bip_C_Spine", "J_Bip_C_Chest", "J_Bip_C_UpperChest", "J_Bip_C_Neck", "J_Bip_C_Head"]
const LIMBS := ["UpperLeg", "LowerLeg", "Foot"]
const ARMS := ["Shoulder", "UpperArm", "LowerArm", "Hand"]

## The changes this model shows (a copy of Redline.changes when applied).
var shown: Array = []
## The copy in her gun's first-person arms: hands and arms stay as they are.
var gun_arms := false
var _t := 0.0
var _base_y := NAN
var _veins: StandardMaterial3D
var _beat := 0.0
var _held := {}
var _held_at := -1.0


## Puts the changes on `model` (an eco_model.gd), or takes them off if there
## are none. Called from her apply_suit().
static func apply(model: Node) -> void:
	var skel := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		return
	for child in skel.get_children():
		if String(child.name).begins_with(NODE):
			if child is SkeletonModifier3D:
				# her skeleton back to her own size and height
				skel.scale = Vector3.ONE
				if not is_nan(child.get("_base_y")):
					skel.position.y = child.get("_base_y")
			skel.remove_child(child)
			child.free()
	if not Redline.allowed() or Redline.changes.is_empty():
		return
	var mod: SkeletonModifier3D = load("res://scripts/hub/redline_body.gd").new()
	mod.name = NODE
	mod.shown = Redline.changes.duplicate()
	var p := model.get_parent()
	while p != null:
		if String(p.name) == "Weapon":
			mod.gun_arms = true
			break
		p = p.get_parent()
	skel.add_child(mod)
	mod.active = true
	mod._build(model, skel)


func _build(model: Node, skel: Skeleton3D) -> void:
	if "wiring" in shown:
		_wire(model, skel)


## Veins up each arm and the sides of her neck: thin red lines just over her
## skin, wandering a little, each on the bone it runs along.
func _wire(model: Node, skel: Skeleton3D) -> void:
	_veins = StandardMaterial3D.new()
	_veins.albedo_color = VEIN
	_veins.emission_enabled = true
	_veins.emission = VEIN
	_veins.emission_energy_multiplier = 0.6
	var body := ColonyGear._surface(model, skel)
	var runs: Array = []  # [bone, from, to, angles round it]
	for side in ["L", "R"]:
		var up := "J_Bip_%s_UpperArm" % side
		var low := "J_Bip_%s_LowerArm" % side
		var hand := "J_Bip_%s_Hand" % side
		if [up, low, hand].any(func(b): return skel.find_bone(b) < 0):
			continue
		runs.append([low, _rest(skel, hand), _rest(skel, low), [-0.3, 0.6, 2.4]])  # wrist to elbow
		runs.append([up, _rest(skel, low), _rest(skel, up).lerp(_rest(skel, low), 0.25), [0.2, 2.0]])  # elbow up the arm
	if skel.find_bone("J_Bip_C_Neck") >= 0 and skel.find_bone(ColonyGear.HEAD) >= 0:
		runs.append(["J_Bip_C_Neck", _rest(skel, "J_Bip_C_Neck") - Vector3(0, 0.02, 0), _rest(skel, ColonyGear.HEAD) - Vector3(0, 0.015, 0), [1.25, -1.25]])  # up the sides of her neck
	for run in runs:
		var root := ColonyGear._root(skel, run[0], NODE + "_Veins_" + String(run[0]))
		var a: Vector3 = run[1]
		var b: Vector3 = run[2]
		var axis := (b - a).normalized()
		var side := axis.cross(Vector3.FORWARD if absf(axis.z) < 0.9 else Vector3.UP).normalized()
		var other := axis.cross(side).normalized()
		for ang in run[3]:
			var pts: Array = []
			for i in 6:
				var k := float(i) / 5.0
				var at := a.lerp(b, k)
				var g := ColonyGear._girth(body, at, axis, 0.012, 0.07)
				var mid: Vector3 = g[0] if g.size() == 2 else at
				var r: float = (float(g[1]) if g.size() == 2 else 0.03) + 0.0012
				var wob := float(ang) + 0.18 * sin(k * 7.0 + float(ang) * 3.0)  # wandering, not ruled
				pts.append(mid + (side * cos(wob) + other * sin(wob)) * r)
			for i in pts.size() - 1:
				ColonyGear._line(root, pts[i], pts[i + 1], VEIN_R, _veins, VEIN_R * 0.8)
		ColonyGear._match_layers(model, root, "Body")


func _rest(skel: Skeleton3D, bone: String) -> Vector3:
	return skel.get_bone_global_rest(skel.find_bone(bone)).origin


func _process_modification_with_delta(delta: float) -> void:
	_modify(delta)


func _process_modification() -> void:
	_modify(1.0 / maxf(Engine.get_frames_per_second(), 30.0))


## How many times it's reshaped her, and what it last set (bone: scale or
## length factor; for the tests: Godot only keeps a modifier's pose for the frame).
var runs := 0
var last := {}


func _modify(delta: float) -> void:
	var skel := get_skeleton()
	if skel == null:
		return
	runs += 1
	_t += delta
	if is_nan(_base_y):
		_base_y = skel.position.y
	var size := HEAVY if "heavy" in shown else 1.0
	skel.scale = Vector3.ONE * size
	last["skeleton:scale"] = size
	var lift := 0.0
	if "legs" in shown:
		for side in ["L", "R"]:
			var i := _stretch(skel, "J_Bip_%s_Foot" % side, SHIN)
			if i >= 0:
				lift = skel.get_bone_rest(i).origin.length() * (SHIN - 1.0) * size
	skel.position.y = _base_y + lift
	if "posture" in shown:
		_posture(skel)
	_pulse_veins(delta)


## The segment that ends at bone `name` (its offset from its parent), k times
## as long. Returns the bone's index (-1 if there's none).
func _stretch(skel: Skeleton3D, bone: String, k: float) -> int:
	var i := skel.find_bone(bone)
	if i >= 0:
		skel.set_bone_pose_position(i, skel.get_bone_rest(i).origin * k)
		last[bone + ":length"] = k
	return i


## Her spine and head held straight at rest; her legs (and arms, off the gun)
## held where they were and moved on only every PUPPET_STEP s: a puppet's walk.
func _posture(skel: Skeleton3D) -> void:
	for b in SPINE:
		var i := skel.find_bone(b)
		if i >= 0:
			skel.set_bone_pose_rotation(i, skel.get_bone_rest(i).basis.get_rotation_quaternion())
	last["posture"] = true
	var limbs: Array = []
	for side in ["L", "R"]:
		for b in LIMBS:
			limbs.append("J_Bip_%s_%s" % [side, b])
		if not gun_arms:
			for b in ARMS:
				limbs.append("J_Bip_%s_%s" % [side, b])
	var fresh := _held_at < 0.0 or _t - _held_at >= PUPPET_STEP
	if fresh:
		_held_at = _t
	for b in limbs:
		var i := skel.find_bone(b)
		if i < 0:
			continue
		if fresh or not _held.has(i):
			_held[i] = skel.get_bone_pose_rotation(i)
		else:
			skel.set_bone_pose_rotation(i, _held[i])


## The veins glow with each heartbeat: quick while she's high, slow after.
func _pulse_veins(delta: float) -> void:
	if _veins == null:
		return
	var period := 0.55 if Redline.high() else 1.1
	_beat = fmod(_beat + delta, period)
	var k := exp(-_beat * 7.0)
	_veins.emission_energy_multiplier = 0.4 + 2.2 * k
