extends "res://scripts/ps2/ps2_model.gd"
## The grunt's puppet (assets/models/grunt/grunt.glb). On top of the leg swing
## from ps2_model.gd it bends the knees, bobs and twists the torso while
## walking, and when he is standing around he swaggers (rocks on his heels,
## chest out, chin up) and every few seconds plays a crude taunt from TAUNTS:
## points and laughs, beckons, flips the bird, grabs his crotch, thrusts his
## hips, kisses his own bicep, scratches his backside, winks, or looks you up
## and down with a wolf whistle. His LED face, left hand shape and a helmet
## speaker sound go with each one. During the shot wind-up he drops the act
## and squares up.
## (Positive X rotation tips a part forward/up; positive Z swings the left arm
## in across his body.)

const SOUNDS := {
	"whistle": preload("res://assets/sounds/grunt/wolf_whistle.wav"),
	"laugh": preload("res://assets/sounds/grunt/laugh.wav"),
	"kiss": preload("res://assets/sounds/grunt/kiss.wav"),
}

## time: seconds. arm: ArmL x/z and ElbowL x/z rotation at full strength.
## hand: GloveL<hand> shape. eyes: normal / wink / laugh. mouth: grin / kiss /
## tongue / laugh. sound: SOUNDS key, played `sound_at` seconds in.
const TAUNTS := {
	"point": {"time": 2.0, "arm": Vector4(0.85, 0.12, 0.15, 0.0), "hand": "Point",
		"eyes": "laugh", "mouth": "laugh", "sound": "laugh", "sound_at": 0.3},
	"beckon": {"time": 2.2, "arm": Vector4(0.55, -0.25, 1.2, 0.0), "hand": "Point",
		"eyes": "normal", "mouth": "kiss", "sound": "kiss", "sound_at": 1.0},
	"bird": {"time": 2.2, "arm": Vector4(1.0, 0.25, 1.35, 0.0), "hand": "Bird",
		"eyes": "normal", "mouth": "grin", "sound": "laugh", "sound_at": 1.1},
	"crotch": {"time": 2.2, "arm": Vector4(0.2, 0.6, 0.55, 0.0), "hand": "Fist",
		"eyes": "wink", "mouth": "tongue", "sound": "", "sound_at": 0.0},
	"thrust": {"time": 2.0, "arm": Vector4(0.5, -0.35, 1.4, 0.0), "hand": "Fist",
		"eyes": "normal", "mouth": "tongue", "sound": "whistle", "sound_at": 0.1},
	"flex": {"time": 2.4, "arm": Vector4(0.0, -1.35, 0.0, -1.6), "hand": "Fist",
		"eyes": "normal", "mouth": "kiss", "sound": "kiss", "sound_at": 1.2},
	"scratch": {"time": 2.4, "arm": Vector4(-0.55, 0.2, 0.45, 0.0), "hand": "Fist",
		"eyes": "normal", "mouth": "grin", "sound": "", "sound_at": 0.0},
	"wink": {"time": 1.1, "arm": Vector4.ZERO, "hand": "Point",
		"eyes": "wink", "mouth": "kiss", "sound": "kiss", "sound_at": 0.2},
	"ogle": {"time": 2.4, "arm": Vector4.ZERO, "hand": "Point",
		"eyes": "normal", "mouth": "tongue", "sound": "whistle", "sound_at": 0.2},
}

var _knees: Array[Node3D] = []
var _torso: Node3D
var _head: Node3D
var _hips: Node3D
var _arm: Node3D
var _elbow: Node3D
var _parts := {}  # LED faces and hand shapes by node name
var _rest := {}
var _speaker: AudioStreamPlayer3D
var _t := 0.0
var _swagger := 0.0
var _gesture := ""
var _gesture_t := 0.0
var _gesture_wait := 0.0
var _sound_done := false


func _ready() -> void:
	super()
	for n in ["KneeL", "KneeR"]:
		var k := find_child(n, true, false) as Node3D
		if k != null:
			_knees.append(k)
	_torso = find_child("Torso", true, false) as Node3D
	_head = find_child("Head", true, false) as Node3D
	_hips = find_child("Hips", true, false) as Node3D
	_arm = find_child("ArmL", true, false) as Node3D
	_elbow = find_child("ElbowL", true, false) as Node3D
	for n in ["VisorEyeL", "VisorEyeR", "VisorWink", "VisorLaughR", "VisorGrin", "VisorKiss",
			"VisorTongue", "VisorLaughMouth", "GloveLPoint", "GloveLBird", "GloveLFist"]:
		var node := find_child(n, true, false) as Node3D
		if node != null:
			_parts[n] = node
	for n in [_torso, _head, _hips] + _legs:
		if n != null:
			_rest[n] = n.position
	_speaker = AudioStreamPlayer3D.new()
	_speaker.position = Vector3(0, 1.6, 0)
	_speaker.unit_size = 6.0
	_speaker.max_distance = 45.0
	add_child(_speaker)
	_set_face("normal", "grin", "Point")
	_t = randf() * 10.0  # squads don't swagger in step
	_gesture_wait = randf_range(1.0, 4.0)


## Starts a taunt from TAUNTS now; the showcase uses it.
func play_gesture(gesture: String) -> void:
	_gesture = gesture
	_gesture_t = 0.0
	_sound_done = false


func _process(delta: float) -> void:
	super(delta)
	if _torso == null or _head == null or _arm == null:
		return
	_t += delta
	var speed := Vector2(_body.velocity.x, _body.velocity.z).length()
	var walk := clampf(speed / 3.0, 0.0, 1.0)
	var aiming := 0.0
	if "windup_timer" in _body and _body.windup_timer >= 0.0:
		aiming = 1.0
	_swagger = lerpf(_swagger, (1.0 - walk) * (1.0 - aiming), minf(delta * 4.0, 1.0))
	var k := minf(delta * 12.0, 1.0)

	_update_gesture(delta)
	var taunt: Dictionary = TAUNTS.get(_gesture, {})
	var g := 0.0  # taunt envelope, eases in and out
	if not taunt.is_empty():
		g = minf(sin(PI * clampf(_gesture_t / taunt.time, 0.0, 1.0)) * 1.6, 1.0) * _swagger
		if g > 0.3:
			_set_face(taunt.eyes, taunt.mouth, taunt.hand)
		else:
			_set_face("normal", "grin", "Point")
		if not _sound_done and _gesture_t >= taunt.sound_at:
			_sound_done = true
			if taunt.sound != "" and _swagger > 0.5:
				_speaker.stream = SOUNDS[taunt.sound]
				_speaker.pitch_scale = randf_range(0.92, 1.08)
				_speaker.play()
	var is_on := func(name: String) -> float: return g if _gesture == name else 0.0
	var pointing: float = is_on.call("point")
	var ogling: float = is_on.call("ogle")
	var winking: float = is_on.call("wink")
	var thrusting: float = is_on.call("thrust")
	var flexing: float = is_on.call("flex")
	var flipping: float = is_on.call("bird")
	var grabbing: float = is_on.call("crotch")
	var scratching: float = is_on.call("scratch")

	# knees bend while that leg swings back
	if _knees.size() == 2 and _legs.size() == 2:
		for i in 2:
			var back := maxf(-_legs[i].rotation.x, 0.0)
			_knees[i].rotation.x = lerpf(_knees[i].rotation.x,
					-(back * 1.4 + 0.05 * walk + 0.25 * thrusting + 0.12 * grabbing), k)

	# walk: bob twice per stride and counter-twist the shoulders
	var bob := absf(sin(_phase)) * 0.03 * walk
	var twist := sin(_phase) * 0.12 * walk
	# idle swagger: rock on the heels, chest out, shoulders rolling
	var rock := sin(_t * 1.3) * 0.05 * _swagger
	var roll := sin(_t * 0.65) * 0.06 * _swagger
	var puff := (0.5 + 0.5 * sin(_t * 1.3)) * 0.03 * _swagger + 0.04 * flexing
	var laugh := sin(_t * 22.0) * pointing
	# hip thrusts: pelvis pumps forward (-Z), shoulders lean back
	var pump := maxf(sin(_t * 11.0), 0.0) * thrusting
	var hip_shift := Vector3(0, -0.04 * thrusting, -0.07 * pump)

	_hips.position = _rest[_hips] + Vector3(0, bob, 0) + hip_shift
	for leg in _legs:
		leg.position = _rest[leg] + hip_shift
	_torso.position = _rest[_torso] + Vector3(0, bob + absf(laugh) * 0.012, 0) + hip_shift
	_torso.rotation.x = lerpf(_torso.rotation.x, rock + 0.04 * _swagger - 0.06 * aiming
			- 0.07 * ogling + 0.08 * pointing + 0.2 * thrusting + 0.06 * flipping
			- 0.1 * grabbing - 0.08 * scratching, k)
	_torso.rotation.y = lerpf(_torso.rotation.y, twist + 0.15 * pointing - 0.25 * flexing
			+ 0.2 * scratching, k)
	_torso.rotation.z = lerpf(_torso.rotation.z, roll + 0.08 * scratching, k)
	_torso.scale = Vector3(1.0 + puff, 1.0 + puff * 0.5, 1.0 + puff)

	var nod := sin(_t * 2.6) * 0.03 * _swagger
	_head.rotation.x = lerpf(_head.rotation.x, 0.15 * _swagger + nod - 0.5 * ogling
			+ 0.2 * pointing + laugh * 0.05 + 0.15 * thrusting - 0.25 * flexing + 0.1 * scratching, k)
	_head.rotation.y = lerpf(_head.rotation.y, 0.75 * flexing, k)
	_head.rotation.z = lerpf(_head.rotation.z, 0.06 * _swagger + 0.06 * ogling + 0.2 * winking
			+ 0.12 * flipping, k)

	# left arm: taunt pose plus its rhythm (wag, jab, squeeze, scratch)
	var pose: Vector4 = taunt.get("arm", Vector4.ZERO) * g
	var wiggle := 0.0
	match _gesture:
		"beckon":
			wiggle = sin(_t * 9.0) * 0.35 * g
		"bird":
			pose.x += sin(_t * 7.0) * 0.06 * g
		"crotch":
			wiggle = sin(_t * 8.0) * 0.12 * g
		"scratch":
			wiggle = sin(_t * 16.0) * 0.18 * g
		"thrust":
			wiggle = pump * 0.4
	_arm.rotation.x = lerpf(_arm.rotation.x, pose.x, k)
	_arm.rotation.z = lerpf(_arm.rotation.z, pose.y, k)
	_elbow.rotation.x = lerpf(_elbow.rotation.x, pose.z + wiggle, k)
	_elbow.rotation.z = lerpf(_elbow.rotation.z, pose.w, k)


func _set_face(eyes: String, mouth: String, hand: String) -> void:
	_show("VisorEyeL", eyes == "normal")
	_show("VisorWink", eyes != "normal")
	_show("VisorEyeR", eyes != "laugh")
	_show("VisorLaughR", eyes == "laugh")
	_show("VisorGrin", mouth == "grin" or mouth == "tongue")
	_show("VisorTongue", mouth == "tongue")
	_show("VisorKiss", mouth == "kiss")
	_show("VisorLaughMouth", mouth == "laugh")
	for h in ["Point", "Bird", "Fist"]:
		_show("GloveL" + h, h == hand)


func _show(part: String, on: bool) -> void:
	if _parts.has(part):
		_parts[part].visible = on


func _update_gesture(delta: float) -> void:
	if _gesture != "":
		_gesture_t += delta
		if _gesture_t >= TAUNTS[_gesture].time:
			_gesture = ""
			_set_face("normal", "grin", "Point")
		return
	if _swagger < 0.8:
		return
	_gesture_wait -= delta
	if _gesture_wait <= 0.0:
		_gesture_wait = randf_range(3.0, 7.0)
		play_gesture(TAUNTS.keys().pick_random())
