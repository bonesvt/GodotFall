extends "res://scripts/run/story/level_story.gd"
## Level 4, The Boneyard (levels.gd): where Dad went down. The colony sent
## his titan home without its left arm (hub_builder.gd, the wreck in the
## temple); the arm is still out here in the crater, and so is his flight
## recorder, thrown clear with the seat. Eco takes both home: the recorder
## says he opened his canopy for a friendly signal, and the arm is the first
## part of the late-game repair. The way out is back where she came in.
## By Marrow's Hold (level_story.gd stage):
##   CLEAN   find the recorder and the arm.
##   HOOKED  the same, but his words come in over dead grunts' radios across
##           the boneyard (trigger_words.gd fire, a few times a run).
##   HIS     she comes to at the crater with no memory of the drive out, and
##           the recorder's already in her pack. Who put it there is a
##           question for later. Take the arm and walk back out.

const Z := preload("res://scripts/run/zone_kit.gd")

## Dad's titan's paint (armory.gd "dads": white shell, blue, an orange stripe).
const DAD_BLUE := Color(0.62, 0.74, 0.92)
const STRIPE := Color(1.0, 0.6, 0.25)
## A dead grunt's radio within this far (m) can carry his words; a few a run.
const RADIO_RANGE := 30.0
const RADIO_MAX := 3
const RADIO_GAP := 25.0
const RECORDER_LINES := [
	"RECORDER: \"Starling to Solace. Coming home the long way, over the boneyard.\"",
	"RECORDER: [a chime] \"Friendly on the colony band. Pilot code checks out.\" [a laugh] \"You? Out here?\"",
	"RECORDER: \"Hang on, I'll open up. It's been too long.\" [the canopy servos whine]",
	"RECORDER: [one shot, then static]",
	"Eco: \"He opened the canopy. For somebody he knew.\"",
]

var recorder := false
var arm := false
var _radios := 0
var _radio_wait := 0.0
var _blink: MeshInstance3D
var _t := 0.0


func build(gen, plan, info: Dictionary, keep_out: Array, s: Dictionary, c: float, side: float,
		squad: Array, zone_index: int, _dress: RandomNumberGenerator) -> void:
	var at := Vector2(c + side * 8.5, float(s["z1"]) + 17.0)
	position = gen._on(plan, at.x, at.y)
	gen._occupy(info, keep_out, at, Vector2(12.0, 30.0))
	# The crater, scorched black, and the wreckage round it.
	var crater := box(Vector3(0, 0.02, 0), Vector3(9.0, 0.04, 14.0), Color(0.08, 0.07, 0.07))
	crater.name = "Crater"
	Z.titan_arm(self, Vector3(side * 1.5, 0.0, 2.5), 75.0, DAD_BLUE)
	box(Vector3(side * 1.5, 1.9, 2.5), Vector3(0.25, 0.08, 2.4), STRIPE)   # his stripe down the forearm
	Z.scrap_pile(self, Vector3(-side * 2.5, 0.0, -5.0), 30.0, DAD_BLUE)
	Z.scrap_pile(self, Vector3(side * 3.0, 0.0, -8.5), 200.0, Color(0.7, 0.7, 0.72))
	# The seat, thrown clear and on its side, the recorder still strapped in
	# under it with its light blinking.
	var seat := Node3D.new()
	seat.name = "PilotSeat"
	add_child(seat)
	seat.position = Vector3(-side * 1.8, 0.0, -1.5)
	seat.rotation_degrees = Vector3(0, 30, 80)
	box(Vector3(0, 0.5, 0), Vector3(0.7, 1.0, 0.7), Color(0.2, 0.2, 0.22), seat)
	box(Vector3(0, 1.1, -0.3), Vector3(0.7, 0.9, 0.12), Color(0.2, 0.2, 0.22), seat)
	var rec := box(Vector3(-side * 1.2, 0.2, -1.2), Vector3(0.4, 0.25, 0.3), STRIPE)
	rec.name = "FlightRecorder"
	_blink = box(Vector3(-side * 1.2, 0.35, -1.05), Vector3(0.06, 0.04, 0.04), Color(1, 0.2, 0.1))
	_blink.material_override = Kit.glow(Color(1.0, 0.2, 0.1))
	spots["recorder"] = {"at": Vector3(-side * 1.2, 0.0, -1.2), "prompt": "[F] Pull the flight recorder"}
	spots["arm"] = {"at": Vector3(-side * 0.3, 0.0, 2.5), "prompt": "[F] Hook the arm for the dropship"}
	sign_text(Vector3(side * 1.5, 3.2, 2.5), "S-7  STARLING", 40, Color(0.85, 0.9, 1.0)).billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# Scavengers picking the crater over.
	squad.append(gen._grunt(get_parent(), info, to_global(Vector3(-side * 3.0, 0.0, 4.0)), zone_index, 1.2, Vector3(-side, 0, 0)))
	squad.append(gen._grunt(get_parent(), info, to_global(Vector3(-side * 3.5, 0.0, -6.0)), zone_index, 1.2, Vector3(-side, 0, 0)))


func _begin() -> void:
	if stage == HIS:
		# She comes to here. The recorder's already in her pack.
		recorder = true
		_hide_recorder()
		rm.place_player(to_global(Vector3(-spots["arm"]["at"].x * 3.0, 0.5, 6.0)))
		say([
			"Eco comes to on her knees in a crater. She doesn't remember the drive out. Any of it.",
			"Her pack's heavier. Dad's flight recorder is in it, wrapped in a violet cloth that smells like the Halo.",
			"Eco: \"...Who packed this?\"",
		])
	else:
		say(["The Boneyard. Dad went down out here. The colony sent his titan home, but not all of it.",
			"Find the crater. His arm's still out there, and maybe whatever was in the cockpit with him."])
	for g in rm.zone_info.get("grunts", []):
		if g.has_signal("died"):
			g.died.connect(_on_grunt_died)


func tick(delta: float) -> void:
	_t += delta
	_radio_wait = maxf(_radio_wait - delta, 0.0)
	if _blink != null and is_instance_valid(_blink):
		_blink.visible = fmod(_t, 1.2) < 0.25


func _usable(id: String) -> bool:
	return not recorder if id == "recorder" else not arm


func _use(id: String) -> void:
	match id:
		"recorder":
			recorder = true
			_hide_recorder()
			SFX.play(rm.player, "pickup_part", -2.0)
			say(RECORDER_LINES, 3.6)
		"arm":
			arm = true
			SFX.play_at(self, to_global(spots["arm"]["at"]), "titan_clang", -2.0, 0.8)
			var flare := OmniLight3D.new()
			flare.light_color = Color(1.0, 0.3, 0.2)
			flare.omni_range = 8.0
			flare.light_energy = 2.5
			add_child(flare)
			flare.position = spots["arm"]["at"] + Vector3(0, 2.5, 0)
			say(["She clips the winch line round his forearm and pops a flare. The dropship can lift it on the way home.",
				"Eco: \"Coming home, Dad. One piece at a time.\""])


func _hide_recorder() -> void:
	var rec := find_child("FlightRecorder", false, false)
	if rec != null:
		rec.visible = false
	if _blink != null:
		_blink.queue_free()
		_blink = null


## HOOKED: his words over a dead grunt's radio, when one falls near her.
func _on_grunt_died(grunt: Node) -> void:
	if stage != HOOKED or _radios >= RADIO_MAX or _radio_wait > 0.0 or rm == null or rm.phase != rm.Phase.ZONE:
		return
	if (grunt as Node3D).global_position.distance_to(rm.player.global_position) > RADIO_RANGE:
		return
	_radios += 1
	_radio_wait = RADIO_GAP
	get_tree().create_timer(1.2, false).timeout.connect(_radio)


func _radio() -> void:
	if rm == null or rm.phase != rm.Phase.ZONE or rm.hush_pull.busy():
		return
	rm.hush_pull.triggers.fire(true, false, "A dead grunt's radio crackles: \"...%s...\"")


func can_leave() -> bool:
	return recorder and arm


func leave_nag() -> String:
	if not recorder:
		return "Not yet. Dad's crater is still out there."
	return "Not without his arm. It's in the crater."


func finish() -> String:
	if stage == HIS:
		return "His arm's coming home. So is the recorder, and she doesn't know how."
	return "His arm's coming home, and the recorder. He opened up for someone he knew."
