extends Node3D
## Stages Pip's Velvet check-ups (velvet.gd) in the Still behind the dressing
## room (downtown_below.gd): one a day, twelve in all, each its own talk
## ([velvet <n>] in dialogue/npc/pip_M.txt) played as a cutscene. run_manager.gd
## adds one to the hub; its spot by the copper opens the day's check-up, or
## takes the offer back up after Eco said no.
##
## While one plays the pilot is parked and hidden, a camera frames the room,
## Pip is brought down to it (wherever she was working), a posed copy of Eco
## sits on a stool across from her, and the talk runs as usual. The talk's
## stage cues (moods starting with @, CUES) move the camera, pose them both and
## put the effects on: the violet wash of a dose, the black of a drop, the
## shaking, a nosebleed. When the talk ends everything goes back.

const Velvet := preload("res://scripts/hub/velvet.gd")
const Below := preload("res://scripts/hub/downtown_below.gd")
const Poses := preload("res://scripts/hub/family_poses.gd")
const FamilyScene := preload("res://scripts/hub/family_scene.gd")
const NpcIdles := preload("res://scripts/hub/npc_idles.gd")
const K := preload("res://scripts/hub/hub_kit.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")
const SFX := preload("res://scripts/sfx.gd")
const ECO := preload("res://assets/models/eco.tscn")

const SPOT_ID := "velvet_bench"
const SPOT_REACH := 1.3
## The stage cues a [velvet <n>] talk may use (moods starting with @).
const CUES := ["wide", "pip", "eco", "low", "high",
	"pip_sip", "pip_notes", "pip_sit", "pip_down", "pip_kneel",
	"eco_sit", "eco_sip", "eco_slump", "eco_lie", "eco_kneel", "eco_stand",
	"dose", "drop", "shake", "blood"]

const R := Vector3.RIGHT
const B := Vector3.BACK
const U := Vector3.UP

## Held poses (family_poses.gd turns: RIGHT swings a limb forward / leans the
## torso back, BACK tips toward her left, UP turns her left; -Z is forward).
const SIT_LEGS := [
	["J_Bip_R_UpperLeg", R, 88.0], ["J_Bip_R_UpperLeg", U, -6.0],
	["J_Bip_L_UpperLeg", R, 88.0], ["J_Bip_L_UpperLeg", U, 6.0],
	["J_Bip_R_LowerLeg", R, -88.0], ["J_Bip_L_LowerLeg", R, -88.0],
]
const ARMS_ON_KNEES := [
	["J_Bip_R_UpperArm", B, -72.0], ["J_Bip_R_UpperArm", R, 28.0], ["J_Bip_R_LowerArm", R, 40.0],
	["J_Bip_L_UpperArm", B, 72.0], ["J_Bip_L_UpperArm", R, 28.0], ["J_Bip_L_LowerArm", R, 40.0],
]
const SIP_ARM := [
	["J_Bip_L_UpperArm", B, 72.0], ["J_Bip_L_UpperArm", R, 28.0], ["J_Bip_L_LowerArm", R, 40.0],
	["J_Bip_R_UpperArm", "J_Bip_R_LowerArm", Vector3(0.25, -0.5, -0.83)],
	["J_Bip_R_LowerArm", "J_Bip_R_Hand", Vector3(-0.75, 0.45, -0.48)],
]
const SLUMP := [
	["J_Bip_C_Spine", R, -28.0], ["J_Bip_C_Chest", R, -12.0],
	["J_Bip_C_Head", R, -30.0], ["J_Bip_C_Head", B, 8.0],
	["J_Bip_R_UpperArm", B, -80.0], ["J_Bip_R_UpperArm", R, 18.0], ["J_Bip_R_LowerArm", R, 30.0],
	["J_Bip_L_UpperArm", B, 80.0], ["J_Bip_L_UpperArm", R, 18.0], ["J_Bip_L_LowerArm", R, 30.0],
]
## On her back on the floor (the scene lays the whole model down).
const LIE := [
	["J_Bip_C_Spine", R, 6.0],
	["J_Bip_R_UpperArm", B, -70.0], ["J_Bip_L_UpperArm", B, 70.0],
	["J_Bip_R_LowerArm", R, 20.0], ["J_Bip_L_LowerArm", R, 20.0],
	["J_Bip_R_UpperLeg", R, 8.0], ["J_Bip_R_LowerLeg", R, -14.0],
	["J_Bip_C_Head", U, 25.0],
]
## On her knees, leaning over someone on the floor in front of her, hands down to them.
const KNEEL := [
	["J_Bip_R_UpperLeg", R, 10.0], ["J_Bip_L_UpperLeg", R, 10.0],
	["J_Bip_R_LowerLeg", R, -95.0], ["J_Bip_L_LowerLeg", R, -95.0],
	["J_Bip_C_Spine", R, -25.0], ["J_Bip_C_Chest", R, -10.0], ["J_Bip_C_Head", R, -25.0],
	["J_Bip_R_UpperArm", "J_Bip_R_LowerArm", Vector3(0.15, -0.75, -0.65)],
	["J_Bip_R_LowerArm", "J_Bip_R_Hand", Vector3(0.0, -0.6, -0.8)],
	["J_Bip_L_UpperArm", "J_Bip_L_LowerArm", Vector3(-0.15, -0.75, -0.65)],
	["J_Bip_L_LowerArm", "J_Bip_L_Hand", Vector3(0.0, -0.6, -0.8)],
]
const STAND := [
	["J_Bip_R_UpperArm", B, -74.0], ["J_Bip_R_LowerArm", R, 12.0],
	["J_Bip_L_UpperArm", B, 74.0], ["J_Bip_L_LowerArm", R, 12.0],
	["J_Bip_C_Head", R, -8.0],
]
static var eco_poses := {
	"sit": SIT_LEGS + ARMS_ON_KNEES + [["J_Bip_C_Spine", R, -6.0]],
	"sip": SIT_LEGS + SIP_ARM + [["J_Bip_C_Head", R, -6.0]],
	"slump": SIT_LEGS + SLUMP,
	"lie": LIE,
	"kneel": KNEEL,
	"stand": STAND,
}
const ECO_FACES := {
	"sit": {},
	"sip": {"Fcl_ALL_Fun": 0.4, "Fcl_EYE_Close": 0.3},
	"slump": {"Fcl_EYE_Close": 0.8, "Fcl_ALL_Sorrow": 0.4},
	"lie": {"Fcl_EYE_Close": 0.9, "Fcl_ALL_Sorrow": 0.5},
	"kneel": {"Fcl_ALL_Surprised": 0.6},
	"stand": {"Fcl_ALL_Sorrow": 0.3},
}
const FACE_SHAPES := ["Fcl_ALL_Fun", "Fcl_EYE_Close", "Fcl_ALL_Sorrow", "Fcl_ALL_Surprised"]

## Where they are in the Still: Pip's crate chair (her work_high pose sits
## 0.7 m up, like her chair in the high rollers' room), where she stands in
## front of it, Eco's stool across from her, and a crate between them.
const PIP_SEAT := Below.STILL + Vector3(0.95, 0, 0.3)
const PIP_STAND := Below.STILL + Vector3(0.45, 0, 0.3)
const ECO_AT := Below.STILL + Vector3(-0.85, 0, 0.3)
const STOOL_TOP := 0.46
const TABLE := Below.STILL + Vector3(0.0, 0, -1.35)
## On the floor: Pip lying down (day 6, Eco kneeling at her side), Eco lying
## down (day 12, Pip kneeling at hers). Feet at these, heads toward the copper.
const PIP_DOWN := Below.STILL + Vector3(0.35, 0, -0.6)
const ECO_DOWN := Below.STILL + Vector3(-0.55, 0, -0.5)
## Eye heights over their feet, standing.
const ECO_EYES := 1.42
const PIP_EYES := 1.66
const PIP_SEATED_DROP := 0.38
const VIOLET := Color(0.55, 0.15, 0.85)
const BLACK := Color(0.04, 0.0, 0.06)

## The run manager (player, hub_npcs, npc_talk, hud, pilot_hud).
var rm: Node
## The check-up playing (1..12), else 0.
var playing := 0
var eco: Node3D
var _camera: Camera3D
var _props: Array = []
var _stool: Node3D
var _pip_saved := {}
var _pip_hold: SkeletonModifier3D
var _pip_seated := false
var _eco_hold: SkeletonModifier3D
var _blood: Node3D
var _veil: ColorRect
var _flash := Color.TRANSPARENT
var _flash_t := 0.0
var _flash_len := 0.0
var _shake_left := 0.0
var _cam_at := Vector3.ZERO
var _cam_look := Vector3.ZERO
var _eco_base := Vector3.ZERO


## Adds the spot by the copper to the hub's interactables.
func setup(p_rm: Node, info: Dictionary) -> void:
	rm = p_rm
	name = "VelvetScene"
	info["interactables"].append({"id": SPOT_ID, "pos": Below.STILL + Vector3(0.9, 0, 1.15), "range": SPOT_REACH,
		"prompt": "", "lines": [], "velvet": true})
	rm.npc_talk.finished.connect(_on_talk_finished)
	rm.npc_talk.cue.connect(_on_cue)
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	_veil = ColorRect.new()
	_veil.color = Color(VIOLET, 0.0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_veil)


func _pip() -> Node3D:
	return rm.hub_npcs.get("pip")


func busy() -> bool:
	return playing > 0


## What the spot by the copper says now ("" when there's nothing to do there).
func prompt() -> String:
	if not Velvet.allowed() or _pip() == null or playing > 0:
		return ""
	if Velvet.state == "no":
		return "[F] Leave Pip a note: you'll do it"
	if Velvet.checkup_due():
		return "[F] Pip's check-up (day %d of %d)" % [Velvet.next_checkup(), Velvet.CHECKUPS]
	if Velvet.on_trial():
		return "Today's check-up is done. Come back after a run."
	return ""


## F at the copper: the day's check-up, or a note saying she's in after all.
func use() -> bool:
	if not Velvet.allowed() or playing > 0:
		return false
	if Velvet.state == "no":
		Velvet.answer("velvet_yes")
		rm.hud.toast("Eco chalks it under the batch numbers: SAME GLASS. SAME MEASURE. E.  Pip will see it tonight. The first check-up is tomorrow.", 5.0)
		return true
	var pip := _pip()
	if pip == null or not Velvet.checkup_due():
		return false
	var n := Velvet.next_checkup()
	_stage(n)
	if not rm.npc_talk.velvet(pip, n):
		_unstage()
		return false
	Velvet.checkup()
	return true


func _on_talk_finished(_who: String) -> void:
	if playing > 0:
		_unstage()


func _on_cue(cue: String) -> void:
	if playing <= 0:
		return
	match cue:
		"wide", "pip", "eco", "low", "high":
			_shot(cue)
		"pip_sip":
			_pip_anim("work_club", ["velvet"], PIP_STAND, false)
		"pip_notes":
			_pip_anim("work_rooms", ["ledger"], PIP_STAND, false)
		"pip_sit":
			_pip_anim("work_high", ["velvet"], PIP_SEAT, true)
		"pip_down":
			_pip_floor("down")
		"pip_kneel":
			_pip_floor("kneel")
		"dose":
			_wash(VIOLET, 0.45, 2.5)
			SFX.play(rm.player, "titan_hiss_short", -14.0, 1.6)
		"drop":
			_wash(BLACK, 0.92, 2.2)
			SFX.play(rm.player, "heartbeat", -4.0)
		"shake":
			_shake_left = 3.0
		"blood":
			_nosebleed()
		_:
			if cue.begins_with("eco_"):
				_eco_pose(cue.substr(4))


# --- Staging -------------------------------------------------------------------

func _stage(n: int) -> void:
	playing = n
	var pip := _pip()
	var talk = rm.npc_talk
	talk.hold = true
	rm.player.visible = false
	rm.player.process_mode = Node.PROCESS_MODE_DISABLED
	rm.hud.visible = false
	rm.pilot_hud.visible = false
	_pip_saved = {"xform": pip.global_transform, "home_yaw": pip.home_yaw, "look": pip.look_target}
	# Pip's crate chair, Eco's stool, a crate between them with the bottle on it.
	var crate := Art.material("wood", Color(0.36, 0.25, 0.16))
	_props.append(K.mesh(self, PIP_SEAT + Vector3(0, 0.35, 0), Vector3(0.7, 0.7, 0.65), crate))
	_props.append(K.mesh(self, PIP_SEAT + Vector3(0.36, 1.0, 0), Vector3(0.12, 0.6, 0.65), crate))
	_stool = K.mesh(self, ECO_AT + Vector3(0, STOOL_TOP * 0.5, 0), Vector3(0.42, STOOL_TOP, 0.42), crate)
	_props.append(_stool)
	_props.append(K.mesh(self, TABLE + Vector3(0, 0.25, 0), Vector3(0.45, 0.5, 0.45), crate))
	_props.append(K.mesh(self, TABLE + Vector3(0.05, 0.62, 0), Vector3(0.08, 0.24, 0.08), Art.material("alloy", Color(0.2, 0.18, 0.22))))
	_props.append(K.glow(self, TABLE + Vector3(0.05, 0.56, 0), Vector3(0.07, 0.1, 0.07), VIOLET * 1.3))
	eco = ECO.instantiate()
	eco.name = "EcoVelvet"
	eco.set("idle_motion", false)
	add_child(eco)
	eco.set("suit_tier", 0)
	if eco.has_method("wear"):
		eco.call("wear", "skater")
	_camera = Camera3D.new()
	_camera.fov = 55.0
	add_child(_camera)
	pip.look_target = eco
	# Until the talk's first cues say otherwise.
	_pip_anim("work_rooms", ["ledger"], PIP_STAND, false)
	_eco_pose("sit")
	_shot("wide")


func _unstage() -> void:
	var pip := _pip()
	_free_pip_hold()
	if pip != null and not _pip_saved.is_empty():
		pip.rotation = Vector3.ZERO
		pip.global_transform = _pip_saved["xform"]
		pip.home_yaw = _pip_saved["home_yaw"]
		pip.look_target = _pip_saved["look"]
		var work: Array = pip.get_meta("work", ["", []])
		NpcIdles.strike(pip, work[0], work[1])
	_pip_saved = {}
	for p in _props:
		if is_instance_valid(p):
			p.queue_free()
	_props = []
	_stool = null
	_blood = null
	_eco_hold = null
	if eco != null:
		eco.queue_free()
	eco = null
	if _camera != null:
		_camera.queue_free()
	_camera = null
	_shake_left = 0.0
	_flash_len = 0.0
	_veil.color.a = 0.0
	rm.npc_talk.hold = false
	rm.player.visible = true
	rm.player.process_mode = Node.PROCESS_MODE_INHERIT
	var cam := rm.player.get_node_or_null("Head/Camera3D") as Camera3D
	if cam != null:
		cam.make_current()
	rm.hud.visible = true
	rm.pilot_hud.visible = true
	rm.player.refresh_glass()
	var was := playing
	playing = 0
	rm.hud.toast(after_line(was), 5.0)


## What the HUD says as Eco leaves the Still after check-up `n`.
static func after_line(n: int) -> String:
	if Velvet.state == "out":
		return "No more check-ups. Pip keeps her word about Eco's glass. The Velvet's still in her, and it's going to take its time leaving."
	if n >= Velvet.CHECKUPS:
		return "Twelve days. Pip's notes are finished, and so, she says, is Eco's part in them. The last dose goes out on the next run with her."
	if n in Velvet.NO_DOSE:
		return "Day %d of %d. No glass today, just two pairs of shaking hands. One more." % [n, Velvet.CHECKUPS]
	return "Day %d of %d. The Velvet goes out with her on the next run: harder, faster, and it can drop her where she stands." % [n, Velvet.CHECKUPS]


# --- Pip -------------------------------------------------------------------------

## Pip at work in the Still: one of her work loops, facing Eco.
func _pip_anim(anim: String, props: Array, at: Vector3, seated: bool) -> void:
	var pip := _pip()
	_free_pip_hold()
	_pip_seated = seated
	pip.rotation = Vector3.ZERO
	_place(pip, at, _yaw_to(at, ECO_AT))
	pip.look_target = eco
	_strike(pip, anim, props)


## Pip on the floor: collapsed on her back ("down") or on her knees by Eco ("kneel").
func _pip_floor(kind: String) -> void:
	var pip := _pip()
	_strike(pip, "", [])
	_free_pip_hold()
	_pip_seated = false
	pip.rotation = Vector3.ZERO
	pip.look_target = null
	if kind == "down":
		_place(pip, PIP_DOWN + Vector3(0, 0.12, 0), 0.0)
		pip.rotation.x = PI / 2.0
		_pip_hold = _hold(pip, LIE)
	else:
		var at := ECO_DOWN + Vector3(0.55, 0, 1.0)
		_place(pip, at, _yaw_to(at, at + Vector3.LEFT))
		_pip_hold = _hold(pip, KNEEL)
		pip.global_position.y = at.y - _knee_height(pip) + 0.04


## Strikes a pose but keeps the face the line just gave her (the cues come
## after a line's moods, and striking calms her).
func _strike(pip: Node3D, anim: String, props: Array) -> void:
	var face: String = pip.face
	NpcIdles.strike(pip, anim, props)
	pip.face = face


func _free_pip_hold() -> void:
	if _pip_hold != null and is_instance_valid(_pip_hold):
		_pip_hold.queue_free()
	_pip_hold = null


func _pip_eyes() -> Vector3:
	var pip := _pip()
	var eyes: Vector3 = pip.global_transform * Vector3(0, PIP_EYES, 0)
	return eyes - Vector3(0, PIP_SEATED_DROP if _pip_seated else 0.0, 0)


# --- Eco -------------------------------------------------------------------------

func _eco_pose(kind: String) -> void:
	if eco == null or not eco_poses.has(kind):
		return
	if _eco_hold != null and is_instance_valid(_eco_hold):
		_eco_hold.queue_free()
	for p in eco.find_children("*", "Node3D", true, false):
		if p.has_meta("idle_prop"):
			p.get_parent().remove_child(p)
			p.queue_free()
	eco.rotation = Vector3.ZERO
	eco.global_position = ECO_AT
	_stool.visible = true
	match kind:
		"sit", "sip", "slump":
			eco.rotation.y = _yaw_to(ECO_AT, PIP_SEAT)
			eco.global_position.y = ECO_AT.y + STOOL_TOP + 0.06 - _hips_height(eco)
		"stand":
			eco.rotation.y = _yaw_to(ECO_AT, PIP_SEAT)
		"lie":
			# knocked off her stool, on her back on the concrete
			_stool.visible = false
			eco.global_position = ECO_DOWN + Vector3(0, 0.12, 0)
			eco.rotation = Vector3(PI / 2.0, 0.0, 0.0)
		"kneel":
			var at := PIP_DOWN + Vector3(-0.6, 0, 1.0)
			eco.global_position = at
			eco.rotation.y = _yaw_to(at, at + Vector3.RIGHT)
	_eco_hold = _hold(eco, eco_poses[kind])
	if kind == "kneel":
		eco.global_position.y = PIP_DOWN.y - _knee_height(eco) + 0.04
	_eco_base = eco.global_position
	var faces := {}
	for s in FACE_SHAPES:
		faces[s] = 0.0
	faces.merge(ECO_FACES[kind], true)
	FamilyScene._face(eco, faces)
	if kind == "sip":
		NpcIdles._prop(eco, "velvet")


func _eco_eyes() -> Vector3:
	return eco.global_transform * Vector3(0, ECO_EYES, 0) if eco != null else ECO_AT + Vector3(0, 1.1, 0)


## A thin line of red from her nose, for the rest of the day's scene.
func _nosebleed() -> void:
	if eco == null or _blood != null:
		return
	var skel := eco.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null or skel.find_bone("J_Bip_C_Head") < 0:
		return
	var at := BoneAttachment3D.new()
	at.bone_name = "J_Bip_C_Head"
	skel.add_child(at)
	var sc := (skel.global_transform * skel.get_bone_global_pose(skel.find_bone("J_Bip_C_Head"))).basis.get_scale()
	var drip := Node3D.new()
	drip.scale = Vector3(1.0 / sc.x, 1.0 / sc.y, 1.0 / sc.z)
	at.add_child(drip)
	K.glow(drip, Vector3(0.006, 0.04, -0.085), Vector3(0.006, 0.03, 0.004), Color(0.55, 0.02, 0.04))
	_blood = at


# --- Camera and effects ------------------------------------------------------------

func _shot(kind: String) -> void:
	var pip_eyes := _pip_eyes()
	var eco_eyes := _eco_eyes()
	var mid := (pip_eyes + eco_eyes) * 0.5
	var floor_y := Below.STILL.y
	match kind:
		"pip":
			# over Eco's shoulder, onto Pip
			var away := (eco_eyes - pip_eyes) * Vector3(1, 0, 1)
			away = away.normalized() if away.length() > 0.01 else Vector3.LEFT
			_look(eco_eyes + away * 0.55 + away.cross(Vector3.UP) * 0.35 + Vector3(0, 0.12, 0), pip_eyes)
		"eco":
			var away := (pip_eyes - eco_eyes) * Vector3(1, 0, 1)
			away = away.normalized() if away.length() > 0.01 else Vector3.RIGHT
			_look(pip_eyes + away * 0.55 + away.cross(Vector3.UP) * 0.35 + Vector3(0, 0.1, 0), eco_eyes)
		"low":
			_look(Vector3(mid.x - 0.2, floor_y + 0.4, Below.STILL.z - 1.4), mid + Vector3(0, 0.2, 0))
		"high":
			_look(Vector3(mid.x + 0.2, floor_y + 2.45, Below.STILL.z - 0.9), Vector3(mid.x, floor_y + 0.3, mid.z))
		_:
			_look(Below.STILL + Vector3(0.15, 1.7, -2.15), mid)


func _look(from: Vector3, at: Vector3) -> void:
	_cam_at = from
	_cam_look = at
	_camera.global_position = from
	_camera.look_at(at, Vector3.UP)
	_camera.make_current()


## A wash of colour over the view, fading out over `length` seconds.
func _wash(color: Color, peak: float, length: float) -> void:
	_flash = Color(color, peak)
	_flash_t = 0.0
	_flash_len = length


func _process(delta: float) -> void:
	if _flash_len > 0.0:
		_flash_t += delta
		var k := _flash_t / _flash_len
		var a := _flash.a * (minf(_flash_t / 0.25, 1.0) if _flash_t < 0.25 else 1.0 - k)
		_veil.color = Color(_flash, clampf(a, 0.0, 1.0))
		if k >= 1.0:
			_flash_len = 0.0
			_veil.color.a = 0.0
	if _shake_left > 0.0 and _camera != null:
		_shake_left -= delta
		var j := 0.05 * clampf(_shake_left, 0.0, 1.0)
		_camera.global_position = _cam_at + Vector3(randf_range(-j, j), randf_range(-j, j), randf_range(-j, j))
		_camera.look_at(_cam_look, Vector3.UP)
		if eco != null:
			eco.global_position = _eco_base + Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)) * 0.02 * clampf(_shake_left, 0.0, 1.0)
		if _shake_left <= 0.0:
			_camera.global_position = _cam_at
			_camera.look_at(_cam_look, Vector3.UP)
			if eco != null:
				eco.global_position = _eco_base


# --- helpers -------------------------------------------------------------------------

func _place(npc: Node3D, at: Vector3, yaw: float) -> void:
	npc.global_position = at
	npc.home_yaw = yaw
	npc.rotation.y = yaw


## The yaw that faces `from` toward `to` (the models face -Z).
static func _yaw_to(from: Vector3, to: Vector3) -> float:
	return atan2(-(to.x - from.x), -(to.z - from.z))


func _hold(model: Node, turns: Array) -> SkeletonModifier3D:
	var skel := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		return null
	var m := Poses.Hold.new()
	m.name = "VelvetPose"
	m.turns = turns
	skel.add_child(m)
	skel.move_child(m, 0)
	return m


## How far above her feet a bone's joint sits at rest (world metres).
static func _rest_height(model: Node3D, bone: String) -> float:
	var skel := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null or skel.find_bone(bone) < 0:
		return 0.0
	var at: Vector3 = skel.global_transform * skel.get_bone_global_rest(skel.find_bone(bone)).origin
	var feet: Vector3 = model.global_transform.origin
	return (model.global_basis.inverse() * (at - feet)).y


static func _hips_height(model: Node3D) -> float:
	var h := _rest_height(model, "J_Bip_C_Hips")
	return h if h > 0.3 else 0.85


static func _knee_height(model: Node3D) -> float:
	var h := _rest_height(model, "J_Bip_R_LowerLeg")
	return h if h > 0.2 else 0.45
