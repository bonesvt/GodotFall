extends SkeletonModifier3D
## Redline's changes to Eco's body (redline.gd), on her own skeleton so they
## move with her: a modifier that runs after her animation every frame and
## reshapes the bones, plus the parts she didn't have before, hung on her bones
## like the Shepherd's gear (colony_gear.gd _root):
##   ears   cat ears through her hair on top of her head, on backwards (their
##          openings to the back), twitching now and then
##   body   all of her BODY times as big, evenly: her skeleton scaled from the floor
##   neck   her head's bone pushed up its neck (NECK times as long)
##   arms   her upper arms and forearms lengthened (ARM_UPPER, ARM_FORE)
##   legs   her shins lengthened (SHIN), her whole skeleton lifted so her feet
##          still meet the floor
##   posture  her spine and neck held at their rest (no slouch, no sway from her
##          animation), leaning back a touch, her chin lifted (POSTURE_*)
##   tail   a thin red tail from the base of her spine, swaying
##   head   her head scaled down (HEAD)
## (Her eyes are eco_model.gd's, a red swirl.) On the copy in her gun's
## first-person arms her size and arms are left alone, so she still holds it.
## apply() puts it on (or updates it on) a model of her.

const Redline := preload("res://scripts/hub/redline.gd")
const ColonyGear := preload("res://scripts/hub/colony_gear.gd")

const NODE := "RedlineBody"
const BODY := 1.15
const NECK := 2.4
const ARM_UPPER := 1.25
const ARM_FORE := 1.5
const SHIN := 1.3
const HEAD := 0.74
## Forced posture: her spine leaned back this many degrees, her chin up this
## many (about her bones' X: negative lifts, her rig facing +Z).
const POSTURE_LEAN := -4.0
const POSTURE_CHIN := -16.0
const SPINE := ["J_Bip_C_Spine", "J_Bip_C_Chest", "J_Bip_C_UpperChest", "J_Bip_C_Neck"]
const EAR_RED := Color(0.16, 0.06, 0.07)
const EAR_PINK := Color(0.95, 0.5, 0.55)
const TAIL_RED := Color(0.55, 0.06, 0.08)
## The tail's first segment (straight out behind her, a little down) and how
## much each after it curls up.
const TAIL_BASE := Vector3(-72, 0, 0)
const TAIL_CURL := Vector3(-11, 0, 0)
const TAIL_SEGMENTS := 12

## The changes this model shows (a copy of Redline.changes when applied).
var shown: Array = []
## The copy in her gun's first-person arms: hands and arms stay as they are.
var gun_arms := false
var _t := 0.0
var _base_y := NAN
var _base_scale := Vector3.ONE
var _ears: Array = []
var _tail: Array = []
var _twitch := 0.0
var _twitch_at := 2.0


## Puts the changes on `model` (an eco_model.gd), or takes them off if there
## are none. Called from her apply_suit().
static func apply(model: Node) -> void:
	var skel := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		return
	for child in skel.get_children():
		if String(child.name).begins_with(NODE):
			if child.get("_base_y") != null and not is_nan(child._base_y):  # her size and height back
				skel.scale = child._base_scale
				skel.position.y = child._base_y
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
	if "ears" in shown and skel.find_bone(ColonyGear.HEAD) >= 0:
		var head := ColonyGear._root(skel, ColonyGear.HEAD, NODE + "_Ears")
		for s in [-1.0, 1.0]:
			_ears.append(_ear(head, s))
		ColonyGear._match_layers(model, head, "Face")
	if "tail" in shown and skel.find_bone("J_Bip_C_Hips") >= 0:
		_tail_on(model, skel)


## A cat ear on her head, side `s`, on backwards: its pivot at the base, the
## open side toward her back.
func _ear(head: Node3D, s: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(0.062 * s, 1.655, 0.035)
	pivot.rotation_degrees = Vector3(-28, 18 * s, 12 * s)  # leaning back, splayed out
	head.add_child(pivot)
	var outer := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.002
	cone.bottom_radius = 0.042
	cone.height = 0.085
	cone.radial_segments = 16
	outer.mesh = cone
	outer.material_override = _toon(EAR_RED)
	outer.position = Vector3(0, 0.04, 0)
	outer.scale = Vector3(1.0, 1.0, 0.45)
	pivot.add_child(outer)
	var inner := MeshInstance3D.new()
	var cone2 := CylinderMesh.new()
	cone2.top_radius = 0.001
	cone2.bottom_radius = 0.028
	cone2.height = 0.06
	cone2.radial_segments = 16
	inner.mesh = cone2
	inner.material_override = _toon(EAR_PINK)
	inner.position = Vector3(0, 0.032, 0.012)  # the opening, facing back
	inner.scale = Vector3(1.0, 1.0, 0.3)
	pivot.add_child(inner)
	return pivot


## The tail: a chain of shrinking red segments from the base of her spine,
## each a pivot under the last so it can sway.
func _tail_on(model: Node, skel: Skeleton3D) -> void:
	var hips := ColonyGear._root(skel, "J_Bip_C_Hips", NODE + "_Tail")
	var at := skel.get_bone_global_rest(skel.find_bone("J_Bip_C_Hips")).origin + Vector3(0, 0.06, 0.1)  # the small of her back
	var parent: Node3D = hips
	var mat := _toon(TAIL_RED)
	for i in TAIL_SEGMENTS:
		var seg := Node3D.new()
		seg.position = at if i == 0 else Vector3(0, -0.075, 0.0)
		seg.rotation_degrees = TAIL_BASE if i == 0 else TAIL_CURL  # out behind her, then curling up
		parent.add_child(seg)
		var r := lerpf(0.024, 0.009, float(i) / TAIL_SEGMENTS)
		var mi := MeshInstance3D.new()
		var c := CapsuleMesh.new()
		c.radius = r
		c.height = maxf(0.095, r * 2.0)
		mi.mesh = c
		mi.material_override = mat
		mi.position = Vector3(0, -0.0375, 0)
		seg.add_child(mi)
		_tail.append(seg)
		parent = seg
	ColonyGear._match_layers(model, hips, "Body")


func _toon(c: Color) -> Material:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	return m


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
		_base_scale = skel.scale
	var size := BODY if "body" in shown and not gun_arms else 1.0
	skel.scale = _base_scale * size
	last["body:scale"] = size
	if not gun_arms:
		for side in ["L", "R"]:
			if "arms" in shown:
				_stretch(skel, "J_Bip_%s_LowerArm" % side, ARM_UPPER)
				_stretch(skel, "J_Bip_%s_Hand" % side, ARM_FORE)
	if "neck" in shown:
		_stretch(skel, ColonyGear.HEAD, NECK)
	if "head" in shown:
		_scale(skel, ColonyGear.HEAD, HEAD)
	if "posture" in shown and not gun_arms:
		_posture(skel)
	var lift := 0.0
	if "legs" in shown:
		for side in ["L", "R"]:
			var i := _stretch(skel, "J_Bip_%s_Foot" % side, SHIN)
			if i >= 0:
				lift = skel.get_bone_rest(i).origin.length() * (SHIN - 1.0)
	skel.position.y = _base_y + lift * size
	_animate_parts()


## Forced posture: her spine and neck straight (their rest, whatever her
## animation wants), leaned back a little, and her chin lifted.
func _posture(skel: Skeleton3D) -> void:
	for k in SPINE.size():
		var i := skel.find_bone(SPINE[k])
		if i < 0:
			continue
		var rest := skel.get_bone_rest(i).basis.get_rotation_quaternion()
		var tilt := POSTURE_LEAN if k == 0 else 0.0
		skel.set_bone_pose_rotation(i, rest * Quaternion(Vector3.RIGHT, deg_to_rad(tilt)))
	var h := skel.find_bone(ColonyGear.HEAD)
	if h >= 0:
		var rest := skel.get_bone_rest(h).basis.get_rotation_quaternion()
		skel.set_bone_pose_rotation(h, rest * Quaternion(Vector3.RIGHT, deg_to_rad(POSTURE_CHIN)))
	last["posture:chin"] = -POSTURE_CHIN


## The bone `name`'s own scale, s times.
func _scale(skel: Skeleton3D, bone: String, s: float) -> void:
	var i := skel.find_bone(bone)
	if i >= 0:
		skel.set_bone_pose_scale(i, Vector3.ONE * s)
		last[bone + ":scale"] = s


## The segment that ends at bone `name` (its offset from its parent), k times
## as long. Returns the bone's index (-1 if there's none).
func _stretch(skel: Skeleton3D, bone: String, k: float) -> int:
	var i := skel.find_bone(bone)
	if i >= 0:
		skel.set_bone_pose_position(i, skel.get_bone_rest(i).origin * k)
		last[bone + ":length"] = k
	return i


## The ears' twitch now and then, and the tail's sway.
func _animate_parts() -> void:
	if not _ears.is_empty():
		if _t >= _twitch_at:
			_twitch = 1.0
			_twitch_at = _t + randf_range(1.5, 4.0)
		_twitch = maxf(_twitch - 0.08, 0.0)
		for k in _ears.size():
			var ear: Node3D = _ears[k]
			if is_instance_valid(ear):
				var s := -1.0 if k == 0 else 1.0
				ear.rotation_degrees = Vector3(-28 - 14 * _twitch * sin(_t * 40.0), 18 * s, 12 * s)
	for k in _tail.size():
		var seg: Node3D = _tail[k]
		if is_instance_valid(seg):
			var base := TAIL_BASE if k == 0 else TAIL_CURL
			seg.rotation_degrees = base + Vector3(0, 0, 9.0 * sin(_t * 1.7 - k * 0.5))
