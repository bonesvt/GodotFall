extends Node3D
## The animated smoke on the Halo's back step, a Mature date ([date smoke m] in
## dialogue/npc/ophelia.txt): Eco and Ophelia share her last cigarette, Eco
## takes the last drag, and Ophelia kisses her before she can breathe out,
## stealing the smoke. run_manager.gd date_at() stages it for the "smoke" date;
## the "@beat" moods in the dialogue (npc_talk.gd's beat signal) move it on,
## and tools/npc/smoke_shots.gd renders it on its own.
##
## Eco here is a stand-in model of her (dressed like the player's, which hides
## for the scene); Ophelia is the hub NPC herself. Both are posed on top of
## their idle loops: arms by two-bone IK reaching for points on either of them
## (lips, a cheek, a hip), bodies and heads by turns about the model's axes
## (they face -Z, their right is +X), like eco_model.gd's strut. A beat is a
## few keys over time; a key sets any of the controls (held, then eased into
## the key's value over its last EASE seconds) and the rest carry on. What they
## show trails those values on a soft spring (LAG), quicker for eyes and heads
## than for arms and bodies, so moves overlap and settle instead of stopping
## dead; under it all they breathe, sway and blink.
##
## Controls, per person ("e." Eco, "o." Ophelia):
##   step    metres forward from where they started
##   lean    degrees bowed forward (spine and chest)
##   twist   degrees the chest turns to their left
##   look    0..1 how much the head turns to the other's face
##   tilt    degrees the head tips toward their right shoulder
##   nod     degrees the head drops (negative: chin up)
##   breath  degrees the chest lifts (a drag in; the ember glows with it)
##   eyes    0..1 shut
##   grind   degrees the right leg twists (a stub under her toe)
##   r, l    0..1 how much the right / left hand reaches for its target
##   r_at, l_at  where: a target spec (_where())
##   lips    0..1 the cigarette sits at their lips (held by them)
## and for both: burn (how much cigarette is left, 1 to 0), ember (glow 0..1),
## kiss (0..1: Ophelia closes whatever gap is left between their lips).
## Key events ("do"): ["cig", holder] "e"/"o"/"drop"/"", ["lighter", on],
## ["flame", on], ["puff", who, strength, side], ["wisp", on],
## ["mood", who, [moods]], ["cam", shot].

signal done

const ECO := preload("res://assets/models/eco.tscn")
const Wardrobe := preload("res://scripts/hub/wardrobe.gd")

## Eco's feet from Ophelia's to start (metres).
const GAP := 0.62
const HEAD := "J_Bip_C_Head"
const ARM := {"r": ["J_Bip_R_UpperArm", "J_Bip_R_LowerArm", "J_Bip_R_Hand", "J_Bip_R_Index2", 1.0],
	"l": ["J_Bip_L_UpperArm", "J_Bip_L_LowerArm", "J_Bip_L_Hand", "J_Bip_L_Index2", -1.0]}
## Their lips from the head joint, in the model's rest axes (measured on the
## Face meshes: Eco's lips ~0.09 m in front of it, level with it).
const LIPS := Vector3(0.0, -0.002, -0.088)
const SECONDS_TO_SETTLE := 0.25
## How far behind its keys each control trails (the spring's time constant, in
## seconds; it settles in about four of these). Not listed: no trail.
const LAG := {"look": 0.06, "nod": 0.06, "tilt": 0.07, "eyes": 0.03, "r": 0.08, "l": 0.08,
	"lean": 0.11, "twist": 0.11, "step": 0.12, "breath": 0.1, "grind": 0.045, "lips": 0.08,
	"kiss": 0.1, "ember": 0.06}
## How far behind its target a reaching hand trails (seconds, as LAG).
const HAND_LAG := 0.09
## A cigarette changing hands slides from one grip to the other over this long.
const HANDOFF := 0.4
## Fingers the cigarette sits between (right hand), and how much of it pokes
## out on the palm side (metres).
const GRIP := ["J_Bip_R_Index1", "J_Bip_R_Index2", "J_Bip_R_Middle1", "J_Bip_R_Middle2"]
const FILTER_IN := 0.016
## Where a hand takes the cigarette from another's: this far along it from the
## filter (metres).
const TAKE := ["cig", 0.035]
## Longest a control takes to ease into a key's value (it holds before that).
const EASE := 0.75
## How fast the beats play: key seconds per real second (under 1: slower,
## unhurried; everything eases over EASE / TEMPO real seconds).
const TEMPO := 0.72

## Camera shots, in the stage's space: Eco at +Z, Ophelia at -Z, both on the
## Z axis, Eco's right toward -X. [camera position, where it looks].
const SHOTS := {
	"two": [Vector3(1.75, 1.42, 0.05), Vector3(0.0, 1.3, 0.0)],
	"ophelia": [Vector3(0.75, 1.5, 0.6), Vector3(0.0, 1.36, -0.3)],
	"eco": [Vector3(0.75, 1.52, -0.55), Vector3(0.0, 1.4, 0.3)],
	"hand": [Vector3(0.75, 1.38, 0.35), Vector3(0.0, 1.27, -0.05)],
	"kiss": [Vector3(0.8, 1.47, -0.14), Vector3(0.0, 1.43, 0.03)],
	"exhale": [Vector3(0.7, 1.28, -0.05), Vector3(0.0, 1.5, -0.25)],
	"feet": [Vector3(0.55, 0.55, 0.85), Vector3(0.0, 0.05, 0.25)],
}

## The beats ("@name" in the dialogue): keys, and "loop" (seconds) or "next".
## Positions: ["stage", Vector3] in the stage's space; ["body", who,
## Vector3(right, up, forward)] from their feet; ["head", who, Vector3] from
## their head joint and ["lips", who, Vector3] from their lips, in their own
## axes; ["hand", who, "r"/"l"] where that hand is. Three aim what the hand
## holds rather than the wrist: ["lips", ...] puts the cigarette's filter
## there (the right hand) and ["ember", Vector3] the lighter's flame (the left),
## ["cig", metres] the right hand's grip on the cigarette that far along it.
const MID := ["stage", Vector3(-0.04, 1.1, 0.0)]
const BEATS := {
	"arrive": {"keys": [
		{"t": 0.0, "do": [["cam", "two"], ["cig", ""]]},
		{"t": 1.2, "e.look": 1.0, "o.look": 0.8, "e.step": 0.0, "o.step": 0.0, "e.r": 0.0, "e.l": 0.0, "o.r": 0.0, "o.l": 0.0,
			"e.lean": 0.0, "o.lean": 0.0, "e.tilt": 0.0, "o.tilt": 0.0, "e.nod": 0.0, "o.nod": 0.0, "burn": 1.0, "ember": 0.0},
	]},
	"pack": {"keys": [
		{"t": 0.0, "do": [["cam", "two"]]},
		{"t": 0.5, "do": [["cig", "o"]]},
		{"t": 0.9, "o.r": 1.0, "o.r_at": ["body", "o", Vector3(0.12, 1.26, 0.26)], "o.look": 0.5, "o.tilt": 6.0},
	]},
	"light": {"keys": [
		{"t": 0.0, "do": [["cam", "ophelia"], ["cig", "o"]]},
		{"t": 0.3, "do": [["lighter", true]]},
		{"t": 0.9, "o.r": 1.0, "o.r_at": ["lips", "o", Vector3(0.0, -0.004, 0.002)], "o.lips": 1.0, "o.look": 0.0,
			"o.l": 1.0, "o.l_at": ["ember", Vector3(0.0, -0.014, 0.0)], "o.nod": 10.0},
		{"t": 1.2, "do": [["flame", true]]},
		{"t": 1.9, "ember": 1.0, "o.breath": 5.0, "o.eyes": 0.6},
		{"t": 2.1, "do": [["flame", false]]},
		{"t": 2.6, "o.l": 0.0, "do": [["lighter", false]]},
		{"t": 3.0, "o.breath": 0.0},
		{"t": 3.3, "o.r_at": ["body", "o", Vector3(0.2, 1.22, 0.24)], "o.lips": 0.0, "o.nod": 0.0, "o.eyes": 0.0},
		{"t": 3.4, "do": [["puff", "o", 0.8, -1.0]]},
		{"t": 4.6, "o.r_at": MID, "o.look": 1.0, "o.tilt": 8.0, "do": [["cam", "two"]]},
	]},
	"first": {"keys": [
		{"t": 0.0, "do": [["cam", "two"]]},
		{"t": 0.7, "o.r_at": MID},
		{"t": 0.9, "e.r": 1.0, "e.r_at": TAKE},
		{"t": 1.05, "do": [["cig", "e"]]},
		{"t": 1.6, "o.r": 0.0},
		{"t": 1.7, "e.r_at": ["lips", "e", Vector3(0.0, -0.004, 0.002)], "e.lips": 1.0, "e.look": 0.2},
		{"t": 2.5, "e.breath": 6.0, "e.eyes": 0.5, "do": [["burn", 0.82]]},
		{"t": 2.8, "e.r_at": ["body", "e", Vector3(0.2, 1.12, 0.22)], "e.lips": 0.0, "e.breath": 0.0},
		# the cough: a little forward jerk, eyes screwed shut, smoke everywhere
		{"t": 2.95, "e.lean": 12.0, "e.eyes": 1.0, "do": [["puff", "e", 0.5, 0.0], ["mood", "o", ["joy"]]]},
		{"t": 3.15, "e.lean": 2.0},
		{"t": 3.35, "e.lean": 10.0, "do": [["puff", "e", 0.3, 0.0]]},
		{"t": 3.6, "e.lean": 0.0},
		{"t": 4.0, "e.eyes": 0.0, "e.look": 1.0},
		# Ophelia fixes her grip
		{"t": 4.6, "o.r": 1.0, "o.r_at": ["hand", "e", "r"], "o.lean": 6.0},
		{"t": 5.6, "o.r_at": ["hand", "e", "r"]},
		{"t": 6.2, "o.r": 0.0, "o.lean": 0.0, "do": [["mood", "o", ["smile"]]]},
	], "next": "pass"},
	"pass": {"loop": 7.0, "keys": [
		{"t": 0.0, "e.r": 1.0, "e.r_at": ["body", "e", Vector3(0.2, 1.12, 0.22)]},
		{"t": 0.7, "e.r_at": MID},
		{"t": 0.9, "o.r": 1.0, "o.r_at": TAKE},
		{"t": 1.05, "do": [["cig", "o"]]},
		{"t": 1.6, "e.r": 0.0},
		{"t": 2.0, "o.r_at": ["lips", "o", Vector3(0.0, -0.004, 0.002)], "o.lips": 1.0, "o.look": 0.3},
		{"t": 2.7, "o.breath": 5.0, "do": [["burn", -0.12]]},
		{"t": 3.1, "o.r_at": ["body", "o", Vector3(0.2, 1.2, 0.24)], "o.lips": 0.0, "o.breath": 0.0, "o.look": 1.0},
		{"t": 3.3, "do": [["puff", "o", 0.6, -1.0]]},
		{"t": 4.0, "o.r_at": MID},
		{"t": 4.2, "e.r": 1.0, "e.r_at": TAKE},
		{"t": 4.35, "do": [["cig", "e"]]},
		{"t": 4.9, "o.r": 0.0, "e.r_at": ["lips", "e", Vector3(0.0, -0.004, 0.002)], "e.lips": 1.0, "e.look": 0.3},
		{"t": 5.6, "e.breath": 5.0, "do": [["burn", -0.12]]},
		{"t": 6.0, "e.r_at": ["body", "e", Vector3(0.2, 1.12, 0.22)], "e.lips": 0.0, "e.breath": 0.0, "e.look": 1.0},
		{"t": 6.2, "do": [["puff", "e", 0.6, 1.0]]},
		{"t": 7.0, "e.r_at": ["body", "e", Vector3(0.2, 1.12, 0.22)]},
	]},
	"short": {"keys": [
		{"t": 0.0, "do": [["cam", "hand"]]},
		{"t": 0.5, "e.r_at": MID},
		{"t": 0.7, "o.r": 1.0, "o.r_at": TAKE},
		{"t": 0.85, "do": [["cig", "o"]]},
		{"t": 1.3, "e.r": 0.0},
		{"t": 1.8, "o.r_at": ["body", "o", Vector3(0.1, 1.28, 0.3)], "o.look": 0.0, "o.nod": 22.0, "burn": 0.14},
	]},
	"hand_last": {"keys": [
		{"t": 0.0, "do": [["cam", "two"]]},
		{"t": 0.7, "o.r_at": MID, "o.nod": 0.0, "o.look": 1.0, "o.tilt": 10.0},
		{"t": 0.9, "e.r": 1.0, "e.r_at": TAKE},
		{"t": 1.05, "do": [["cig", "e"]]},
		{"t": 1.6, "o.r": 0.0, "e.r_at": ["body", "e", Vector3(0.22, 1.2, 0.2)], "e.tilt": -6.0},
	]},
	"last_drag": {"keys": [
		{"t": 0.0, "do": [["cam", "eco"]]},
		{"t": 0.7, "e.r_at": ["lips", "e", Vector3(0.0, -0.004, 0.002)], "e.lips": 1.0, "e.look": 0.6, "e.tilt": 0.0},
		{"t": 1.0, "ember": 1.0},
		{"t": 2.1, "e.breath": 9.0, "e.eyes": 0.7, "burn": 0.0},
		{"t": 2.6, "e.r_at": ["body", "e", Vector3(0.24, 0.98, 0.14)], "e.lips": 0.0, "e.look": 1.0, "e.eyes": 0.0},
		{"t": 2.7, "do": [["cig", "drop"], ["cam", "feet"]]},
		{"t": 3.0, "e.r": 0.0, "e.grind": 0.0},
		{"t": 3.3, "e.grind": 16.0},
		{"t": 3.6, "e.grind": -10.0},
		{"t": 3.9, "e.grind": 12.0},
		{"t": 4.3, "e.grind": 0.0, "do": [["cig", ""], ["cam", "two"]]},
	]},
	"kiss": {"keys": [
		{"t": 0.0, "do": [["cam", "kiss"]]},
		# she looks at her mouth, tips her head, and only then leans in
		{"t": 0.7, "o.look": 1.0, "o.tilt": 7.0, "o.nod": 6.0, "o.lean": 5.0, "e.look": 1.0, "e.nod": 0.0},
		{"t": 1.5, "kiss": 1.0, "o.step": 0.04, "o.lean": 20.0, "o.r": 1.0, "o.r_at": ["head", "e", Vector3(-0.075, -0.045, -0.02)],
			"o.l": 1.0, "o.l_at": ["body", "e", Vector3(0.13, 1.06, 0.06)], "o.look": 1.0, "o.tilt": 14.0, "o.nod": 3.0,
			"e.step": 0.0, "e.lean": 18.0, "e.tilt": -10.0, "e.look": 1.0, "e.nod": 0.0, "e.breath": 4.0},
		{"t": 1.4, "do": [["mood", "o", ["closed", "blush"]]]},
		{"t": 1.8, "e.eyes": 1.0, "do": [["wisp", true]]},
		{"t": 2.3, "e.l": 1.0, "e.l_at": ["body", "o", Vector3(0.15, 1.0, -0.02)]},
	]},
	"kiss_hold": {"keys": [
		{"t": 0.0, "do": [["cam", "kiss"]]},
		{"t": 1.4, "o.tilt": 17.0, "e.tilt": -12.0, "e.breath": 0.0, "o.breath": 3.0},
		{"t": 2.4, "o.breath": 0.0},
		{"t": 3.0, "o.tilt": 14.0, "e.tilt": -10.0},
	]},
	"exhale": {"keys": [
		{"t": 0.0, "do": [["cam", "exhale"], ["wisp", false]]},
		{"t": 0.6, "kiss": 0.0, "o.step": 0.07, "o.lean": 0.0, "o.nod": -20.0, "o.look": 0.2, "o.r": 0.0,
			"e.step": 0.0, "e.lean": 0.0, "e.tilt": -4.0},
		{"t": 0.75, "do": [["puff", "o", 1.4, 0.0]]},
		{"t": 1.2, "e.eyes": 0.0},
		{"t": 1.8, "o.nod": 0.0, "o.look": 0.6, "do": [["mood", "o", ["smile", "blush"]]]},
	]},
	"after": {"keys": [
		{"t": 0.0, "do": [["cam", "two"]]},
		# she finds Eco's hand and holds it
		{"t": 0.9, "e.l": 0.0, "e.r": 1.0, "e.r_at": ["body", "e", Vector3(0.14, 0.97, 0.21)], "e.look": 1.0, "e.tilt": 6.0},
		{"t": 1.4, "o.step": 0.1, "o.l": 1.0, "o.l_at": ["hand", "e", "r"], "o.look": 1.0, "o.tilt": 8.0},
	]},
}

var eco: Node3D
var oph: Node3D
var cam: Camera3D
var now := {}
var beat_name := ""
var _keys: Array = []
var _from := {}
var _t := 0.0
var _loop := 0.0
var _next := ""
var _fired := {}
var _actors := {}
var _cig: Node3D
var _cig_paper: MeshInstance3D
var _ember: MeshInstance3D
var _ember_light: OmniLight3D
var _cig_smoke: CPUParticles3D
var _lighter: Node3D
var _flame: Node3D
var _wisp: CPUParticles3D
var _holder := ""
var _dropped := false
var _drop_at := Vector3.ZERO
var _shot := "two"
var _player_body: Node3D
var _cam_ready := false
var _kiss_reach := 0.0
## What's on show: the controls trailing `now` on their springs.
var _shown := {}
var _vel := {}
var _clock := 0.0
var _shot_t := 0.0
var _cut := true
var _handoff := 1.0
var _giver := ""
var _rng := RandomNumberGenerator.new()
var _spring_vel: Variant = 0.0


## Stages it at `anchor` (Eco's feet, facing `face_toward`, a point Ophelia
## should stand toward). `player_body` (the player's EcoBody) hides meanwhile.
func setup(ophelia: Node3D, anchor: Vector3, toward: Vector3, player_body: Node3D = null, outfit := "") -> void:
	oph = ophelia
	var d := toward - anchor
	d.y = 0.0
	d = d.normalized() if d.length() > 0.01 else Vector3.FORWARD
	# the stage: its -Z points from Eco to Ophelia, Eco at +GAP/2
	global_position = anchor - d * (-GAP * 0.5)
	global_basis = Basis.looking_at(d, Vector3.UP)
	eco = ECO.instantiate()
	eco.name = "EcoStandIn"
	add_child(eco)
	var wear := outfit if outfit != "" else Wardrobe.eco_now if Wardrobe.eco_now != "" else Wardrobe.choice("eco")
	if eco.has_method("wear"):
		eco.wear(wear)
	_player_body = player_body
	if _player_body != null:
		_player_body.visible = false
	oph.posed = true
	oph.spot = ""
	for p in oph.find_children("*", "Node3D", true, false):
		if p.has_meta("idle_prop"):
			p.get_parent().remove_child(p)
			p.queue_free()
	if oph._anim != null and oph._anim.has_animation("idle"):
		oph._anim.play("idle", 0.3)
	_rng.seed = 7
	_actors["e"] = _actor(eco, "e")
	_actors["o"] = _actor(oph, "o")
	_build_props()
	cam = Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	_place_people()
	_aim_camera(1.0)
	play("arrive")


func _actor(model: Node3D, key: String) -> Dictionary:
	var skel := model.find_child("Skeleton3D", true, false) as Skeleton3D
	var a := {"model": model, "skel": skel, "key": key, "ik": {}, "target": {}, "pole": {}, "hand": {}, "hand_vel": {},
		"blink_in": 1.0 + (0.0 if key == "e" else 1.3), "blink": 0.0, "eyes_base": 0.0}
	var pose := Puppet.new()
	pose.scene = self
	pose.key = key
	pose.name = "SmokeDatePose"
	skel.add_child(pose)
	a["pose"] = pose
	for side in ARM:
		var target := Node3D.new()
		var pole := Node3D.new()
		add_child(target)
		add_child(pole)
		var ik := TwoBoneIK3D.new()
		ik.name = "SmokeDateIK_" + side
		skel.add_child(ik)
		ik.set_setting_count(1)
		ik.set_root_bone_name(0, ARM[side][0])
		ik.set_middle_bone_name(0, ARM[side][1])
		ik.set_end_bone_name(0, ARM[side][2])
		ik.set_target_node(0, ik.get_path_to(target))
		ik.set_pole_node(0, ik.get_path_to(pole))
		ik.influence = 0.0
		a["ik"][side] = ik
		a["target"][side] = target
		a["pole"][side] = pole
	# last on the skeleton: notes where everything ended up (the bone poses
	# read anywhere else are from before the modifiers)
	var rec := Recorder.new()
	rec.scene = self
	rec.key = key
	rec.name = "SmokeDateRecorder"
	skel.add_child(rec)
	a["rec"] = rec
	a["at"] = {}
	# her lips from her head joint, in the head bone's own rest axes
	var head := skel.find_bone(HEAD)
	a["head"] = head
	a["lips"] = skel.get_bone_global_rest(head).basis.orthonormalized().inverse() * LIPS
	# which way the back of the hand faces (up, palms down, in the rest pose)
	var g: Array = []
	for bone in GRIP:
		g.append(skel.get_bone_global_rest(skel.find_bone(bone)).origin)
	a["grip_sign"] = 1.0
	a["grip_sign"] = 1.0 if _grip(g, 1.0).basis.y.y > 0.0 else -1.0
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh != null and m.find_blend_shape_by_name("Fcl_EYE_Close") >= 0:
			a["face"] = m
	return a


# --- beats ------------------------------------------------------------------------

## Starts a beat ("@name" in the dialogue), easing in from wherever they are.
func play(name: String) -> void:
	if not BEATS.has(name):
		return
	beat_name = name
	var b: Dictionary = BEATS[name]
	_keys = b["keys"]
	_loop = float(b.get("loop", 0.0))
	_next = String(b.get("next", ""))
	_t = 0.0
	_fired = {}
	# targets mid-ease are pinned where they are now
	_from = now.duplicate()
	for k in _from:
		if _from[k] is Array:
			_from[k] = _pin(k, _from[k])
	_tick(0.0)


## Whether the beat on now has played out (and isn't a loop).
func beat_done() -> bool:
	return _loop <= 0.0 and _next == "" and (_keys.is_empty() or _t >= float(_keys.back()["t"]))


func _process(delta: float) -> void:
	if eco == null:
		return
	if not _cam_ready:
		cam.make_current()
		_cam_ready = true
	_tick(delta)


func _tick(delta: float) -> void:
	var prev := _t
	_t += delta * TEMPO
	var end := float(_keys.back()["t"]) if not _keys.is_empty() else 0.0
	for i in _keys.size():
		var k: Dictionary = _keys[i]
		if not _fired.has(i) and float(k["t"]) <= _t and (float(k["t"]) > prev or delta == 0.0 or prev == 0.0):
			_fired[i] = true
			for ev in k.get("do", []):
				_event(ev)
	_evaluate()
	_smooth(delta)
	if _t >= end:
		if _next != "":
			play(_next)
			return
		if _loop > 0.0 and _t >= _loop:
			_t = 0.0
			_fired = {}
			_from = now.duplicate()
			for k in _from:
				if _from[k] is Array:
					_from[k] = _pin(k, _from[k])
	_clock += delta
	_place_people(delta)
	_dress_props(delta)
	_aim_camera(delta)


## Moves what's shown toward `now`: a critically damped spring per control.
func _smooth(delta: float) -> void:
	for c: String in now:
		var v: Variant = now[c]
		if v is Array:
			continue
		var lag: float = LAG.get(c.get_slice(".", 1) if c.contains(".") else c, 0.0)
		if lag <= 0.0 or not _shown.has(c):
			_shown[c] = float(v)
			_vel[c] = 0.0
			continue
		var x: float = _shown[c]
		var vel: float = _vel[c]
		var to := float(v)
		_shown[c] = _spring(x, vel, to, lag, delta)
		_vel[c] = _spring_vel


## One step of a critically damped spring (stable for any step): returns the
## new position and leaves the new velocity in _spring_vel.
func _spring(x: Variant, vel: Variant, to: Variant, lag: float, delta: float) -> Variant:
	if delta <= 0.0:
		_spring_vel = vel
		return x
	var w := 1.0 / lag
	var f := 1.0 + 2.0 * delta * w
	var hoo := delta * w * w
	var inv := 1.0 / (f + delta * hoo)
	_spring_vel = (vel + (to - x) * hoo) * inv
	return (x * f + vel * delta + to * (delta * hoo)) * inv


## Every control's value now: eased between the keys that set it.
func _evaluate() -> void:
	var names := {}
	for k: Dictionary in _keys:
		for c in k:
			if c != "t" and c != "do":
				names[c] = true
	for c in names:
		var t0 := 0.0
		var v0: Variant = _from.get(c, _default(c))
		var done := false
		for k: Dictionary in _keys:
			if not k.has(c):
				continue
			var t1 := float(k["t"])
			if _t < t1:
				# hold, then ease in over the last moments before the key
				var start := maxf(t0, t1 - EASE)
				var s := smoothstep(0.0, 1.0, (_t - start) / maxf(t1 - start, 0.001))
				now[c] = _blend(v0, k[c], s)
				done = true
				break
			t0 = t1
			v0 = k[c]
		if not done:
			now[c] = v0


func _default(c: String) -> Variant:
	if c.ends_with("_at"):
		return ["body", c.substr(0, 1), Vector3(0.2, 1.0, 0.1)]
	match c:
		"burn":
			return 1.0
		"e.look", "o.look":
			return 1.0
	return 0.0


## A reach pinned where its wrist is aimed right now (a new beat eases on
## from there).
func _pin(c: String, v: Variant) -> Variant:
	var a: Dictionary = _actors.get(c.substr(0, 1), {})
	var side := c.substr(2, 1)
	if not a.is_empty() and a["hand"].has(side):
		return ["world", a["hand"][side]]
	return ["world", _where(v)]


func _blend(a: Variant, b: Variant, s: float) -> Variant:
	if b is Array:
		if s >= 1.0:
			return b
		return ["mix", a, b, s] if a is Array else b
	return lerpf(float(a), float(b), s)


func get_value(c: String) -> float:
	if _shown.has(c):
		return _shown[c]
	var v: Variant = now.get(c, _default(c))
	return float(v) if not v is Array else 0.0


## A target spec to a point in the world.
func _where(spec: Variant) -> Vector3:
	if not spec is Array or spec.is_empty():
		return global_position
	match String(spec[0]):
		"world":
			return spec[1]
		"stage":
			return global_transform * (spec[1] as Vector3)
		"body":
			var m: Node3D = _actors[spec[1]]["model"]
			var o: Vector3 = spec[2]
			return m.global_transform * Vector3(o.x, o.y, -o.z)
		"head":
			var a: Dictionary = _actors[spec[1]]
			var o: Vector3 = spec[2]
			var at := head_point(a)
			var b: Basis = (a["model"] as Node3D).global_basis
			return at + b * Vector3(o.x, o.y, -o.z)
		"lips":
			var a: Dictionary = _actors[spec[1]]
			var o: Vector3 = spec[2]
			var b: Basis = (a["model"] as Node3D).global_basis
			return lips_point(a) + b * Vector3(o.x, o.y, -o.z)
		"hand":
			return finger_point(_actors[spec[1]], String(spec[2]))
		"ember":
			return _ember.global_position + (spec[1] as Vector3)
		"cig":
			return _cig.global_transform * Vector3(0.0, float(spec[1]), 0.0)
		"mix":
			return _where(spec[1]).lerp(_where(spec[2]), float(spec[3]))
	return global_position


## Where the Recorder saw a bone last frame (world), with its basis.
func _seen(a: Dictionary, bone: String) -> Transform3D:
	var at: Dictionary = a["at"]
	if at.has(bone):
		return at[bone]
	var skel: Skeleton3D = a["skel"]
	return skel.global_transform * skel.get_bone_global_pose(skel.find_bone(bone))


func _record(key: String, skel: Skeleton3D) -> void:
	var a: Dictionary = _actors.get(key, {})
	if a.is_empty():
		return
	var at: Dictionary = a["at"]
	for bone in [HEAD, ARM["r"][0], ARM["l"][0], ARM["r"][2], ARM["l"][2], ARM["r"][3], ARM["l"][3]]:
		var i := skel.find_bone(bone)
		if i >= 0:
			at[bone] = skel.global_transform * skel.get_bone_global_pose(i)
	# the cigarette rides in her fingers as they are this very frame, so it
	# never trails her hand
	var g: Array = []
	for bone in GRIP:
		g.append(skel.global_transform * skel.get_bone_global_pose(skel.find_bone(bone)).origin)
	a["grip"] = _grip(g, a["grip_sign"])
	a["knuckles"] = (g[0] + g[1] + g[2] + g[3]) * 0.25
	_hold_cig()
	if key == "o":
		_hold_lighter()


## Between the index and middle fingers, through the gap and out the back of
## the hand: the cigarette's own transform there (its +Y runs filter to ember).
static func _grip(g: Array, sign: float) -> Transform3D:
	var base: Vector3 = (g[0] + g[2]) * 0.5
	var tip: Vector3 = (g[1] + g[3]) * 0.5
	var along := (tip - base).normalized()
	var across: Vector3 = ((g[1] as Vector3) - (g[3] as Vector3)).normalized()
	var out := along.cross(across).normalized() * sign
	var x := along - out * along.dot(out)
	var b := Basis(x.normalized(), out, x.normalized().cross(out))
	return Transform3D(b, base.lerp(tip, 0.65) - out * FILTER_IN)


## Ophelia's lighter in her left fingers, as they are this frame.
func _hold_lighter() -> void:
	if not _lighter.visible or not _actors.has("o"):
		return
	var o: Dictionary = _actors["o"]
	var m: Node3D = o["model"]
	_lighter.global_transform = Transform3D(m.global_basis, finger_point(o, "l") + m.global_basis * Vector3(0.0, 0.0, -0.01))


func _hold_cig() -> void:
	if _holder != "e" and _holder != "o":
		return
	var a: Dictionary = _actors[_holder]
	if not a.has("grip"):
		return
	var xf: Transform3D = a["grip"]
	if _handoff < 1.0 and _actors.has(_giver) and _actors[_giver].has("grip"):
		xf = (_actors[_giver]["grip"] as Transform3D).interpolate_with(xf, smoothstep(0.0, 1.0, _handoff))
	_cig.global_transform = xf


func head_point(a: Dictionary) -> Vector3:
	return _seen(a, HEAD).origin


func lips_point(a: Dictionary) -> Vector3:
	var g := _seen(a, HEAD)
	return g.origin + g.basis.orthonormalized() * (a["lips"] as Vector3)


func finger_point(a: Dictionary, side: String) -> Vector3:
	return _seen(a, ARM[side][3]).origin


func _event(ev: Array) -> void:
	match String(ev[0]):
		"cig":
			var was := _holder
			_holder = String(ev[1])
			if was in ["e", "o"] and _holder in ["e", "o"] and was != _holder:
				_handoff = 0.0   # slides from one grip into the other
				_giver = was
			if _holder == "drop":
				_dropped = true
				_drop_at = _cig.global_position
			else:
				_dropped = false
			_cig.visible = _holder != ""
		"lighter":
			_lighter.visible = bool(ev[1])
		"flame":
			_flame.visible = bool(ev[1])
		"burn":
			var v := float(ev[1])
			now["burn"] = clampf(get_value("burn") + v, 0.2, 1.0) if v < 0.0 else v
			_from["burn"] = now["burn"]
			_shown["burn"] = now["burn"]
		"puff":
			puff(_actors[ev[1]], float(ev[2]), float(ev[3]))
		"wisp":
			_wisp.emitting = bool(ev[1])
		"mood":
			if ev[1] == "o" and oph.has_method("mood"):
				oph.mood(ev[2])
		"cam":
			if String(ev[1]) != _shot:
				_shot = String(ev[1])
				_shot_t = 0.0
				_cut = true


# --- people -------------------------------------------------------------------------

func _place_people(delta := 0.0) -> void:
	var e_step := get_value("e.step")
	var o_step := get_value("o.step")
	eco.global_transform = global_transform * Transform3D(Basis(), Vector3(0, 0, GAP * 0.5 - e_step))
	# the kiss: Ophelia closes what's left between their lips (last frame's)
	var kiss := get_value("kiss")
	if kiss > 0.01 and _actors.has("e"):
		var gap := (global_transform.affine_inverse() * lips_point(_actors["e"])).z - (global_transform.affine_inverse() * lips_point(_actors["o"])).z
		_kiss_reach = clampf(_kiss_reach + (gap - 0.012) * 0.35, -0.08, 0.22)
	else:
		_kiss_reach = move_toward(_kiss_reach, 0.0, 0.01)
	var o_at := global_transform * Vector3(0, 0, -GAP * 0.5 + o_step + _kiss_reach * kiss)
	oph.global_position = o_at
	oph.home_yaw = global_rotation.y + PI
	oph.rotation.y = oph.home_yaw
	for key in _actors:
		var a: Dictionary = _actors[key]
		var m: Node3D = a["model"]
		var skel: Skeleton3D = a["skel"]
		for side in ARM:
			var ik: TwoBoneIK3D = a["ik"][side]
			ik.influence = clampf(get_value(key + "." + side), 0.0, 1.0)
			var spec: Variant = now.get(key + "." + side + "_at", _default(key + "." + side + "_at"))
			var want := _aim(a, side, spec)
			if ik.influence <= 0.001 or not a["hand"].has(side):
				# a reach starts from wherever the hand hangs
				a["hand"][side] = _seen(a, ARM[side][2]).origin if ik.influence <= 0.001 else want
				a["hand_vel"][side] = Vector3.ZERO
			else:
				a["hand"][side] = _spring(a["hand"][side], a["hand_vel"][side], want, HAND_LAG, delta)
				a["hand_vel"][side] = _spring_vel
			(a["target"][side] as Node3D).global_position = a["hand"][side]
			# elbows down and out, a little behind
			var s: float = ARM[side][4]
			var shoulder := _seen(a, ARM[side][0]).origin
			(a["pole"][side] as Node3D).global_position = shoulder + m.global_basis * Vector3(0.35 * s, -0.45, 0.15)
		_blink(a, delta)


## Where the wrist goes for a hand to reach `spec`. Lips, ember and cig specs
## aim what the hand holds (the filter in its grip, the lighter's flame), so
## the wrist goes there plus wherever it sits from that thing right now.
func _aim(a: Dictionary, side: String, spec: Variant) -> Vector3:
	if spec is Array and not spec.is_empty() and spec[0] == "mix":
		return _aim(a, side, spec[1]).lerp(_aim(a, side, spec[2]), float(spec[3]))
	var want := _where(spec)
	if not spec is Array or spec.is_empty() or not String(spec[0]) in ["lips", "ember", "cig"]:
		return want
	var held: Variant = null
	if side == "r" and a.has("grip"):
		if String(spec[0]) == "cig" and _holder == a["key"]:
			return _seen(a, ARM[side][2]).origin   # it's hers already: stay put
		held = (a["grip"] as Transform3D).origin
	elif side == "l" and a["key"] == "o" and _lighter.visible:
		held = _flame.global_position
	if held == null:
		return want
	return want + (_seen(a, ARM[side][2]).origin - (held as Vector3))


## Every few seconds a blink. Eco's eyes are the scene's ("e.eyes");
## Ophelia's belong to her moods, so a blink only shuts them a moment and
## gives back what they were.
func _blink(a: Dictionary, delta: float) -> void:
	var face: MeshInstance3D = a.get("face")
	if face == null:
		return
	var i := face.find_blend_shape_by_name("Fcl_EYE_Close")
	a["blink_in"] -= delta
	if a["blink_in"] <= 0.0 and a["blink"] <= 0.0:
		a["blink"] = 0.16
		a["blink_in"] = _rng.randf_range(2.4, 5.2)
		a["eyes_base"] = face.get_blend_shape_value(i)
	var shut := 0.0
	if a["blink"] > 0.0:
		a["blink"] -= delta
		shut = sin(clampf(1.0 - a["blink"] / 0.16, 0.0, 1.0) * PI)
	if a["key"] == "e":
		face.set_blend_shape_value(i, maxf(get_value("e.eyes"), shut))
	elif a["blink"] > 0.0:
		face.set_blend_shape_value(i, maxf(a["eyes_base"], shut))
	elif shut == 0.0 and a.get("blinked", false):
		face.set_blend_shape_value(i, a["eyes_base"])
	a["blinked"] = a["blink"] > 0.0


func _shape(mi: MeshInstance3D, shape: String, v: float) -> void:
	var i := mi.find_blend_shape_by_name(shape)
	if i >= 0:
		mi.set_blend_shape_value(i, v)


## Last on each skeleton: hands the scene where the bones ended up.
class Recorder extends SkeletonModifier3D:
	var scene
	var key := ""

	func _process_modification() -> void:
		if scene != null and get_skeleton() != null:
			scene._record(key, get_skeleton())


## Rotations laid over their animation, from the scene's controls: lean,
## twist and breath in the spine and chest, the head turned to the other's
## face, tipped and nodded, and the right leg's grind.
class Puppet extends SkeletonModifier3D:
	var scene
	var key := ""

	func _process_modification() -> void:
		var skel := get_skeleton()
		if skel == null or scene == null or scene.eco == null:
			return
		var v := func(c: String) -> float: return scene.get_value(key + "." + c)
		# alive underneath: a slow breath, a sway, the head drifting (less so
		# mid-kiss, where their lips have to stay put)
		var t: float = scene._clock + (0.0 if key == "e" else 1.7)
		var still: float = 1.0 - 0.8 * clampf(scene.get_value("kiss"), 0.0, 1.0)
		_turn(skel, "J_Bip_C_UpperChest", Vector3.RIGHT, sin(t * TAU / 3.8) * 1.1)
		_turn(skel, "J_Bip_C_Spine", Vector3.BACK, sin(t * TAU / 6.3) * 0.8 * still)
		_turn(skel, "J_Bip_C_Head", Vector3.UP, (sin(t * TAU / 4.7) + 0.5 * sin(t * TAU / 2.3 + 1.0)) * 1.3 * still)
		var lean: float = v.call("lean")
		_turn(skel, "J_Bip_C_Spine", Vector3.RIGHT, -lean * 0.5)
		_turn(skel, "J_Bip_C_Chest", Vector3.RIGHT, -lean * 0.5 + float(v.call("breath")) * 0.4)
		_turn(skel, "J_Bip_C_UpperChest", Vector3.RIGHT, float(v.call("breath")) * 0.4)
		_turn(skel, "J_Bip_C_Chest", Vector3.UP, v.call("twist"))
		_turn(skel, "J_Bip_R_UpperLeg", Vector3.UP, v.call("grind"))
		# the head turns to the other's face
		var head := skel.find_bone("J_Bip_C_Head")
		var look: float = v.call("look")
		var other: Dictionary = scene._actors["o" if key == "e" else "e"]
		if look > 0.001 and head >= 0:
			var g := skel.get_bone_global_pose(head)
			var r0 := skel.get_bone_global_rest(head).basis.orthonormalized()
			var facing := (g.basis.orthonormalized() * r0.inverse()) * Vector3.FORWARD
			var at: Vector3 = skel.global_transform.affine_inverse() * (scene.head_point(other) + Vector3(0, 0.03, 0))
			var want := (at - g.origin).normalized()
			var q := Quaternion(facing.normalized(), want).slerp(Quaternion.IDENTITY, 1.0 - clampf(look, 0.0, 1.0))
			_turn_q(skel, "J_Bip_C_Neck", Quaternion.IDENTITY.slerp(q, 0.35))
			_turn_q(skel, "J_Bip_C_Head", Quaternion.IDENTITY.slerp(q, 0.65))
		_turn(skel, "J_Bip_C_Head", Vector3.RIGHT, -float(v.call("nod")))
		_turn(skel, "J_Bip_C_Head", Vector3.BACK, -float(v.call("tilt")))

	## Turns a bone about a skeleton-space axis through its joint.
	func _turn(skel: Skeleton3D, bone: String, axis: Vector3, deg: float) -> void:
		if absf(deg) < 0.01:
			return
		_turn_q(skel, bone, Quaternion(axis, deg_to_rad(deg)))

	func _turn_q(skel: Skeleton3D, bone: String, q: Quaternion) -> void:
		var i := skel.find_bone(bone)
		if i < 0:
			return
		var parent := skel.get_bone_parent(i)
		var pb := skel.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
		var before := skel.get_bone_pose_rotation(i)
		skel.set_bone_pose_rotation(i, (pb.inverse() * Basis(q) * pb * Basis(before)).get_rotation_quaternion())


# --- the cigarette, the lighter, the smoke ----------------------------------------------

func _build_props() -> void:
	_cig = Node3D.new()
	_cig.name = "Cigarette"
	add_child(_cig)
	_cig.visible = false
	# built along +Y from the filter end (its origin) to the ember
	var filter := MeshInstance3D.new()
	filter.mesh = _rod(0.0042, 0.02)
	filter.position.y = 0.01
	filter.material_override = _flat(Color(0.12, 0.1, 0.08))
	_cig.add_child(filter)
	var band := MeshInstance3D.new()
	band.mesh = _rod(0.0044, 0.003)
	band.position.y = 0.021
	band.material_override = _flat(Color(0.85, 0.66, 0.25))
	_cig.add_child(band)
	_cig_paper = MeshInstance3D.new()
	_cig_paper.mesh = _rod(0.0041, 1.0)
	_cig_paper.material_override = _flat(Color(0.08, 0.08, 0.09))   # Night Owls: black paper
	_cig.add_child(_cig_paper)
	_ember = MeshInstance3D.new()
	_ember.mesh = _rod(0.0043, 0.004)
	var hot := StandardMaterial3D.new()
	hot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hot.albedo_color = Color(1.0, 0.35, 0.1)
	_ember.material_override = hot
	_cig.add_child(_ember)
	_ember_light = OmniLight3D.new()
	_ember_light.light_color = Color(1.0, 0.45, 0.2)
	_ember_light.omni_range = 0.35
	_ember.add_child(_ember_light)
	_cig_smoke = _smoke_emitter(46, 2.6, 0.25, 0.55, 0.22)
	_cig_smoke.gravity = Vector3(0.0, 0.12, 0.0)
	_ember.add_child(_cig_smoke)
	_cig_smoke.emitting = false
	# Ophelia's steel lighter, and its flame
	_lighter = Node3D.new()
	_lighter.visible = false
	add_child(_lighter)
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.024, 0.04, 0.012)
	body.mesh = box
	body.material_override = _flat(Color(0.75, 0.76, 0.8))
	_lighter.add_child(body)
	_flame = Node3D.new()
	_flame.position = Vector3(0, 0.032, 0)
	_flame.visible = false
	_lighter.add_child(_flame)
	var tongue := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.006
	s.height = 0.022
	tongue.mesh = s
	var fire := StandardMaterial3D.new()
	fire.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fire.albedo_color = Color(1.0, 0.75, 0.3)
	tongue.material_override = fire
	_flame.add_child(tongue)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.65, 0.3)
	glow.light_energy = 0.35
	glow.omni_range = 0.6
	_flame.add_child(glow)
	# smoke slipping out between them while they kiss
	_wisp = _smoke_emitter(16, 2.2, 0.2, 0.6)
	_wisp.emitting = false
	add_child(_wisp)


## A soft round blot for each bit of smoke.
static func _puff_texture() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 0.55))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t


func _rod(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 8
	c.rings = 1
	return c


func _flat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.7
	return m


func _smoke_emitter(amount: int, life: float, size_min: float, size_max: float, alpha := 0.3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 25.0
	p.gravity = Vector3(0.0, 0.1, 0.0)
	p.initial_velocity_min = 0.01
	p.initial_velocity_max = 0.04
	var quad := QuadMesh.new()
	quad.size = Vector2(0.06, 0.06)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	# (no vertex colour: a fresh burst can draw black for a frame before its
	# colour ramp kicks in; the puffs swell and then shrink away instead)
	mat.albedo_color = Color(0.74, 0.74, 0.78, alpha)   # grey: white smoke blooms into solid discs
	mat.albedo_texture = _puff_texture()
	quad.material = mat
	p.mesh = quad
	p.scale_amount_min = size_min
	p.scale_amount_max = size_max
	var grow := Curve.new()
	grow.max_value = 2.5
	grow.add_point(Vector2(0, 0.3))
	grow.add_point(Vector2(0.55, 2.0))
	grow.add_point(Vector2(1, 0.0))
	p.scale_amount_curve = grow
	return p


## Where the cigarette sits: between the holder's fingers, or (lips) with its
## filter at their lips; pointing out and away from their face. On the
## ground once dropped.
func _dress_props(delta: float) -> void:
	var burn := clampf(get_value("burn"), 0.0, 1.0)
	var paper := 0.008 + 0.055 * burn
	_cig_paper.scale = Vector3(1, paper, 1)
	_cig_paper.position.y = 0.0225 + paper * 0.5
	_ember.position.y = 0.0225 + paper + 0.002
	var glow := clampf(get_value("ember"), 0.0, 1.0)
	var drag := 0.0
	for key in ["e", "o"]:
		drag = maxf(drag, get_value(key + ".lips") * clampf(get_value(key + ".breath") / 5.0, 0.0, 1.0))
	var hot := glow * (0.55 + 0.45 * drag)
	(_ember.material_override as StandardMaterial3D).albedo_color = Color(0.25, 0.22, 0.2).lerp(Color(1.0, 0.4 + 0.3 * drag, 0.12), hot)
	_ember_light.light_energy = 0.12 * hot + 0.2 * drag * glow
	_cig_smoke.emitting = _cig.visible and glow > 0.1 and burn > 0.01
	if _handoff < 1.0:
		_handoff = minf(_handoff + delta / HANDOFF, 1.0)
	if _holder == "e" or _holder == "o":
		_hold_cig()   # (and again as each skeleton finishes posing)
	elif _holder == "drop":
		_drop_at = _drop_at.move_toward(Vector3(_drop_at.x, global_position.y + 0.005, _drop_at.z), delta * 2.5)
		_cig.global_transform = Transform3D(Basis(Vector3.BACK, PI * 0.5), _drop_at)
	_hold_lighter()
	if _wisp.emitting:
		_wisp.global_position = (lips_point(_actors["e"]) + lips_point(_actors["o"])) * 0.5 + Vector3(0, -0.01, 0)


## A breath of smoke out of their mouth: `strength` 0..1.5, `side` -1 their
## left, 0 ahead and up, 1 their right.
func puff(a: Dictionary, strength: float, side: float) -> void:
	var m: Node3D = a["model"]
	var p := _smoke_emitter(int(18 + 34 * strength), 1.6 + strength, 0.3, 0.85, 0.2)
	p.one_shot = true
	p.explosiveness = 0.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.01
	p.direction = (m.global_basis * Vector3(0.8 * side, 0.6 + 0.4 * (1.0 if side == 0.0 else 0.0), -1.0 + absf(side) * 0.5)).normalized()
	p.spread = 20.0
	p.initial_velocity_min = 0.08 * strength
	p.initial_velocity_max = 0.32 * strength
	p.damping_min = 0.1
	p.damping_max = 0.2
	add_child(p)
	p.global_position = lips_point(a)
	p.emitting = true
	p.finished.connect(p.queue_free)


# --- camera --------------------------------------------------------------------------

## Cuts straight to a new shot, then creeps in on it, a touch sideways, like
## a hand-held camera that's settled.
func _aim_camera(delta: float) -> void:
	_shot_t += delta
	var shot: Array = SHOTS.get(_shot, SHOTS["two"])
	var from := shot[0] as Vector3
	var to := shot[1] as Vector3
	var push := minf(_shot_t * 0.014, 0.09)
	var side := (to - from).cross(Vector3.UP).normalized() * minf(_shot_t * 0.012, 0.08)
	var want_at := global_transform * (from.lerp(to, push) + side)
	var want_look := global_transform * to
	var k := 1.0 - exp(-delta / SECONDS_TO_SETTLE * 2.0) if delta < 1.0 and not _cut else 1.0
	_cut = false
	cam.global_position = cam.global_position.lerp(want_at, k)
	var look_now: Vector3 = cam.get_meta("look", want_look)
	look_now = look_now.lerp(want_look, k)
	cam.set_meta("look", look_now)
	cam.look_at(look_now)


# --- the end -----------------------------------------------------------------------

## Puts everyone back: Ophelia free to stand at her spot again, the player's
## Eco shown, the stand-in and the props gone.
func finish() -> void:
	if eco == null:
		return
	for key in _actors:
		var a: Dictionary = _actors[key]
		for n in [a["pose"], a["ik"]["r"], a["ik"]["l"]]:
			if is_instance_valid(n):
				n.queue_free()
	if is_instance_valid(oph):
		oph.posed = false
		if oph.has_method("calm"):
			oph.calm()
	if is_instance_valid(_player_body):
		_player_body.visible = true
	eco = null
	done.emit()
	queue_free()
