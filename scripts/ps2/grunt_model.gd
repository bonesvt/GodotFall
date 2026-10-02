extends "res://scripts/ps2/ps2_model.gd"
## The grunt's puppet (assets/models/grunt/grunt.glb). On top of the leg swing
## from ps2_model.gd it bends the knees, bobs and twists the torso while
## walking, and when standing around he swaggers (rocks on his heels, chest
## out, chin up) and every few seconds taunts you with a gesture: points and
## laughs, beckons with one finger, winks on his LED face, or slowly looks
## you up and down. During the shot wind-up he drops the act and squares up.
## (Positive X rotation tips a part forward/up; positive Z swings the left arm
## in across his body.)

const GESTURES := {
	"point": 1.8, "beckon": 2.0, "wink": 0.9, "ogle": 2.2,
}

var _knees: Array[Node3D] = []
var _torso: Node3D
var _head: Node3D
var _hips: Node3D
var _arm: Node3D
var _elbow: Node3D
var _wink: Node3D
var _eye_l: Node3D
var _rest := {}
var _t := 0.0
var _swagger := 0.0
var _gesture := ""
var _gesture_t := 0.0
var _gesture_wait := 0.0


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
	_wink = find_child("VisorWink", true, false) as Node3D
	_eye_l = find_child("VisorEyeL", true, false) as Node3D
	if _wink != null:
		_wink.visible = false
	for n in [_torso, _head, _hips]:
		if n != null:
			_rest[n] = n.position
	_t = randf() * 10.0  # squads don't swagger in step
	_gesture_wait = randf_range(1.0, 4.0)


## Starts a taunt now ("point", "beckon", "wink" or "ogle"); the showcase uses it.
func play_gesture(gesture: String) -> void:
	_gesture = gesture
	_gesture_t = 0.0


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
	var g := 0.0  # gesture envelope, eases in and out
	if _gesture != "":
		g = sin(PI * clampf(_gesture_t / GESTURES[_gesture], 0.0, 1.0)) * _swagger
		g = minf(g * 1.6, 1.0)
	var pointing := g if _gesture == "point" else 0.0
	var beckoning := g if _gesture == "beckon" else 0.0
	var ogling := g if _gesture == "ogle" else 0.0
	var winking := g if _gesture == "wink" else 0.0

	# knees bend while that leg swings back
	if _knees.size() == 2 and _legs.size() == 2:
		for i in 2:
			var back := maxf(-_legs[i].rotation.x, 0.0)
			_knees[i].rotation.x = lerpf(_knees[i].rotation.x, -(back * 1.4 + 0.05 * walk), k)

	# walk: bob twice per stride and counter-twist the shoulders
	var bob := absf(sin(_phase)) * 0.03 * walk
	var twist := sin(_phase) * 0.12 * walk
	# idle swagger: rock on the heels, chest out, shoulders rolling
	var rock := sin(_t * 1.3) * 0.05 * _swagger
	var roll := sin(_t * 0.65) * 0.06 * _swagger
	var puff := (0.5 + 0.5 * sin(_t * 1.3)) * 0.03 * _swagger
	# laughing at you: shoulders and head shake
	var laugh := sin(_t * 22.0) * pointing

	_hips.position = _rest[_hips] + Vector3(0, bob, 0)
	_torso.position = _rest[_torso] + Vector3(0, bob + absf(laugh) * 0.012, 0)
	_torso.rotation.x = lerpf(_torso.rotation.x,
			rock + 0.04 * _swagger - 0.06 * aiming - 0.07 * ogling + 0.08 * pointing, k)
	_torso.rotation.y = lerpf(_torso.rotation.y, twist + 0.15 * pointing, k)
	_torso.rotation.z = lerpf(_torso.rotation.z, roll, k)
	_torso.scale = Vector3(1.0 + puff, 1.0 + puff * 0.5, 1.0 + puff)

	var nod := sin(_t * 2.6) * 0.03 * _swagger
	_head.rotation.x = lerpf(_head.rotation.x,
			0.15 * _swagger + nod - 0.5 * ogling + 0.2 * pointing + laugh * 0.05, k)
	_head.rotation.z = lerpf(_head.rotation.z, 0.06 * _swagger + 0.06 * ogling + 0.2 * winking, k)

	# left arm: hangs loose, raises to point, curls a finger to beckon
	var wag := sin(_t * 9.0) * 0.35 * beckoning
	_arm.rotation.x = lerpf(_arm.rotation.x, 0.85 * pointing + 0.55 * beckoning, k)
	_arm.rotation.z = lerpf(_arm.rotation.z, 0.12 * pointing - 0.25 * beckoning, k)
	_elbow.rotation.x = lerpf(_elbow.rotation.x, 0.15 * pointing + (1.2 * beckoning + wag), k)

	if _wink != null and _eye_l != null:
		_wink.visible = winking > 0.3
		_eye_l.visible = not _wink.visible


func _update_gesture(delta: float) -> void:
	if _gesture != "":
		_gesture_t += delta
		if _gesture_t >= GESTURES[_gesture]:
			_gesture = ""
		return
	if _swagger < 0.8:
		return
	_gesture_wait -= delta
	if _gesture_wait <= 0.0:
		_gesture_wait = randf_range(3.0, 7.0)
		play_gesture(GESTURES.keys().pick_random())
