extends "res://scripts/ps2/ps2_model.gd"
## The grunt's puppet (assets/models/grunt/grunt.glb): on top of the leg swing
## from ps2_model.gd, bends the knees on the back swing, bobs and twists the
## torso while walking, and when standing puffs his chest, rocks on his heels
## and keeps his chin up. (Positive X rotation tips a part back / up.) During the shot wind-up he squares up to the target.

var _knees: Array[Node3D] = []
var _torso: Node3D
var _head: Node3D
var _hips: Node3D
var _rest := {}
var _t := 0.0
var _swagger := 0.0


func _ready() -> void:
	super()
	for n in ["KneeL", "KneeR"]:
		var k := find_child(n, true, false) as Node3D
		if k != null:
			_knees.append(k)
	_torso = find_child("Torso", true, false) as Node3D
	_head = find_child("Head", true, false) as Node3D
	_hips = find_child("Hips", true, false) as Node3D
	for n in [_torso, _head, _hips]:
		if n != null:
			_rest[n] = n.position
	_t = randf() * 10.0  # squads don't swagger in step


func _process(delta: float) -> void:
	super(delta)
	if _torso == null or _head == null:
		return
	_t += delta
	var speed := Vector2(_body.velocity.x, _body.velocity.z).length()
	var walk := clampf(speed / 3.0, 0.0, 1.0)
	var aiming := 0.0
	if "windup_timer" in _body and _body.windup_timer >= 0.0:
		aiming = 1.0
	_swagger = lerpf(_swagger, (1.0 - walk) * (1.0 - aiming), minf(delta * 4.0, 1.0))
	var k := minf(delta * 12.0, 1.0)

	# knees bend while that leg swings back
	if _knees.size() == 2 and _legs.size() == 2:
		for i in 2:
			var back := maxf(-_legs[i].rotation.x, 0.0)
			_knees[i].rotation.x = lerpf(_knees[i].rotation.x, -(back * 1.4 + 0.05 * walk), k)

	# walk: bob twice per stride and counter-twist the shoulders
	var bob := absf(sin(_phase)) * 0.03 * walk
	var twist := sin(_phase) * 0.12 * walk
	# idle swagger: slow rock on the heels, chest puffed, shoulders rolling
	var rock := sin(_t * 1.3) * 0.05 * _swagger
	var roll := sin(_t * 0.65) * 0.06 * _swagger
	var puff := (0.5 + 0.5 * sin(_t * 1.3)) * 0.03 * _swagger

	_hips.position = _rest[_hips] + Vector3(0, bob, 0)
	_torso.position = _rest[_torso] + Vector3(0, bob, 0)
	_torso.rotation.x = lerpf(_torso.rotation.x, rock + 0.04 * _swagger - 0.06 * aiming, k)
	_torso.rotation.y = lerpf(_torso.rotation.y, twist, k)
	_torso.rotation.z = lerpf(_torso.rotation.z, roll, k)
	_torso.scale = Vector3(1.0 + puff, 1.0 + puff * 0.5, 1.0 + puff)
	# chin up (looking down his nose at you), dropped level to aim
	var nod := sin(_t * 2.6) * 0.03 * _swagger
	_head.rotation.x = lerpf(_head.rotation.x, 0.18 * _swagger + nod, k)
	_head.rotation.z = lerpf(_head.rotation.z, 0.08 * _swagger, k)
