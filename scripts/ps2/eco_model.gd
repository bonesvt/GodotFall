extends "res://scripts/ps2/ps2_model.gd"
## Root script of assets/models/eco.tscn, the heroine. On top of the base
## model (shader knobs, leg swing while her body walks) it swings her arms
## against her legs, and while she stands she breathes and glances around.
## Drop the scene in anywhere: under a CharacterBody3D she walks with it,
## on her own she just idles.

## Idle breathing and looking around.
@export var idle_motion := true

var _arms: Array[Node3D] = []
var _upper: Node3D
var _head: Node3D
var _time := 0.0


func _ready() -> void:
	super()
	for arm_name in ["ArmL", "ArmR"]:
		var arm := find_child(arm_name, true, false) as Node3D
		if arm != null:
			_arms.append(arm)
	_upper = find_child("Upper", true, false) as Node3D
	_head = find_child("Head", true, false) as Node3D
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	var speed := 0.0
	if _body != null and _body.is_on_floor():
		speed = Vector2(_body.velocity.x, _body.velocity.z).length()
	_phase = fmod(_phase + speed * delta / stride * TAU, TAU)
	var amount := clampf(speed / 3.0, 0.0, 1.0)
	var swing := sin(_phase) * deg_to_rad(swing_degrees) * amount
	var k := minf(delta * 12.0, 1.0)
	if _legs.size() == 2:
		_legs[0].rotation.x = lerpf(_legs[0].rotation.x, swing, k)
		_legs[1].rotation.x = lerpf(_legs[1].rotation.x, -swing, k)
	if _arms.size() == 2:
		_arms[0].rotation.x = lerpf(_arms[0].rotation.x, -swing * 0.8, k)
		_arms[1].rotation.x = lerpf(_arms[1].rotation.x, swing * 0.8, k)
	if not idle_motion:
		return
	var still := 1.0 - amount
	if _upper != null:
		_upper.position.y = sin(_time * 1.9) * 0.004 * still
	if _head != null:
		var look := sin(_time * 0.37) * 0.35 + sin(_time * 0.91) * 0.08
		_head.rotation.y = lerpf(_head.rotation.y, look * still, k * 0.2)
		_head.rotation.x = sin(_time * 0.53) * 0.04 * still
