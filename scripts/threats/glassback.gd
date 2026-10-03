extends "res://scripts/threats/creature.gd"
## GLASSBACK: a six-legged 5.5 m grazer with two rows of glowing crystal plates
## down its back. It wanders and grazes, head down, and ignores Eco unless she
## spooks it: gunfire nearby, sprinting up close, getting hurt. Then it
## stampedes away from the scare, crystals blazing, and tramples anything in
## its path. It calms down after a while and goes back to grazing.

enum State { GRAZE, STAMPEDE }

@export var spook_range := 45.0
## A pilot moving faster than this (m/s) inside sprint_spook spooks it.
@export var sprint_spook := 7.0
@export var stampede_speed := 9.5
@export var stampede_time := 6.0
@export var trample_damage := 35.0

var state := State.GRAZE
var fear := 0.0
var _goal := Vector3.ZERO
var _wait := 0.0
var _run_dir := Vector3.ZERO
var _run_t := 0.0
var _trampled := 0.0
var _moan := 0.0


func _init() -> void:
	max_health = 600.0
	move_speed = 1.4


func _build() -> void:
	var box := BoxShape3D.new()
	box.size = Vector3(2.6, 3.9, 7.0)
	_body(box, Vector3(0, 1.95, 0.2))
	_model("glassback", "hex")
	model.tell_white = 0.25
	model.stride_len = 3.2
	_goal = global_position
	_moan = rng.randf_range(4.0, 12.0)


func _physics_process(delta: float) -> void:
	if dead:
		return
	if is_nan(home_yaw):
		home_yaw = rotation.y
	fear = maxf(fear - delta * 0.15, 0.0)
	_trampled -= delta
	var want := Vector3.ZERO
	if not passive:
		match state:
			State.GRAZE:
				want = _graze(delta)
				_watch_pilot()
			State.STAMPEDE:
				want = _stampede(delta)
	walk(want, delta, 8.0 if state == State.STAMPEDE else 4.0)
	if model != null:
		model.tell = clampf(fear, 0.0, 1.0)
	_moan -= delta
	if _moan <= 0.0:
		_moan = rng.randf_range(8.0, 16.0)
		sound("glassback_low", -6.0 if state == State.GRAZE else 2.0, 3.0)


func _graze(delta: float) -> Vector3:
	move_speed = 1.4
	if _wait > 0.0:
		_wait -= delta
		return Vector3.ZERO
	var d := _goal - global_position
	d.y = 0.0
	if d.length() < 1.5:
		_wait = rng.randf_range(3.0, 8.0)
		_goal = wander_point(10.0)
		return Vector3.ZERO
	face(d, delta, 1.5)
	return d.normalized() * 0.5


func _watch_pilot() -> void:
	if target == null:
		return
	var d := to_pilot().length()
	if d < 3.0 or (d < 9.0 and target.horizontal_speed() > sprint_spook):
		spook(target.global_position)


## Bolts away from `from`.
func spook(from: Vector3) -> void:
	if dead or passive:
		return
	var away := global_position - from
	away.y = 0.0
	if away.length() < 0.1:
		away = global_basis.z
	_run_dir = away.normalized()
	_run_t = stampede_time
	fear = 1.0
	alerted = true
	if state != State.STAMPEDE:
		sound("glassback_stampede", 3.0, 2.5)
	state = State.STAMPEDE


func _stampede(delta: float) -> Vector3:
	move_speed = stampede_speed
	_run_t -= delta
	fear = 1.0
	if _run_t <= 0.0:
		state = State.GRAZE
		alerted = false
		post = global_position
		_goal = global_position
		_wait = 3.0
		return Vector3.ZERO
	if not ground_ahead(_run_dir, 3.5) or is_on_wall():
		_run_dir = _run_dir.rotated(Vector3.UP, PI * 0.6 * (1.0 if rng.randf() < 0.5 else -1.0))
	face(_run_dir, delta, 3.0)
	_trample()
	return -global_basis.z


func _trample() -> void:
	if target == null or _trampled > 0.0:
		return
	var local := global_basis.inverse() * (target.global_position - global_position)
	if absf(local.x) < 1.8 and local.z > -4.6 and local.z < 3.0 and local.y < 3.0:
		_trampled = 1.0
		target.take_damage(trample_damage, global_position)
		var dir := (target.global_position - global_position)
		dir.y = 0.0
		target.velocity = dir.normalized() * 9.0 + Vector3.UP * 5.0
		sound("cantor_blast", -6.0, 0.5)


func _noise(pos: Vector3) -> void:
	if global_position.distance_to(pos) < spook_range:
		spook(pos)


func _hurt(pos: Vector3) -> void:
	spook(pos if target == null else target.global_position)


func is_headshot(pos: Vector3) -> bool:
	return (global_basis.inverse() * (pos - global_position)).z < -3.2
