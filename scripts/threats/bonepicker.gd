extends "res://scripts/threats/creature.gd"
## BONEPICKER: a 30 cm scavenger in a bone shell. They live in swarms and
## strip anything that dies (grunts, the Choir, each other), so a swarm on the
## move means something just died. One alone is harmless and runs from Eco;
## when enough of the swarm is close by they turn on her together and nibble.

enum State { FORAGE, SWARM, FLEE }

## Swarm members this close (including itself) make it brave.
@export var brave_count := 4
@export var brave_range := 7.0
@export var notice := 6.0
@export var bite_damage := 3.0
@export var bite_every := 0.7

## Shared by the swarm: {"members": [...], "food": Vector3 or null}.
var swarm := {}
var state := State.FORAGE
var _goal := Vector3.ZERO
var _bite := 0.0
var _flee_t := 0.0
var _chitter := 0.0


func _init() -> void:
	max_health = 6.0
	move_speed = 4.5


func _build() -> void:
	var sphere := SphereShape3D.new()
	sphere.radius = 0.18
	_body(sphere, Vector3(0, 0.15, 0))
	_model("picker", "scuttle", rng.randf_range(0.9, 1.25))
	model.stride_len = 0.35
	_goal = global_position
	_chitter = rng.randf_range(1.0, 6.0)


func _physics_process(delta: float) -> void:
	if dead:
		return
	_bite -= delta
	var want := Vector3.ZERO
	if not passive:
		var to := to_pilot()
		var dist := to.length() if target != null else INF
		match state:
			State.FORAGE:
				alerted = false
				move_speed = 2.5
				want = _forage(delta)
				if dist < notice:
					if _brave():
						_call_swarm()
					else:
						state = State.FLEE
						_flee_t = 2.0
			State.SWARM:
				alerted = true
				move_speed = 5.0
				if dist > notice * 2.5 or not _brave():
					state = State.FLEE
					_flee_t = 1.5
				else:
					face(to, delta, 12.0)
					want = to.normalized() if dist > 0.6 else Vector3.ZERO
					if dist < 1.0 and _bite <= 0.0:
						_bite = bite_every * rng.randf_range(0.8, 1.2)
						target.take_damage(bite_damage, global_position)
			State.FLEE:
				move_speed = 5.5
				_flee_t -= delta
				want = -to.normalized() if to.length() > 0.1 else Vector3.ZERO
				face(want, delta, 10.0)
				if _flee_t <= 0.0:
					state = State.FORAGE
	_chitter -= delta
	if _chitter <= 0.0:
		_chitter = rng.randf_range(4.0, 10.0) if state == State.FORAGE else rng.randf_range(0.6, 1.5)
		sound("picker_chitter", -14.0 if state == State.FORAGE else -6.0, 0.2)
	walk(want, delta, 30.0)


func _forage(delta: float) -> Vector3:
	var d := _goal - global_position
	d.y = 0.0
	if d.length() < 0.4:
		var food = swarm.get("food")
		var around: Vector3 = food if food != null else post
		var a := rng.randf() * TAU
		_goal = around + Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.3, 1.2 if food != null else 3.0)
		return Vector3.ZERO
	face(d, delta, 10.0)
	return d.normalized() * (1.0 if d.length() > 3.0 else 0.4)


func _brave() -> bool:
	var n := 0
	for p in swarm.get("members", [self]):
		if is_instance_valid(p) and not p.dead and p.global_position.distance_to(global_position) < brave_range:
			n += 1
	return n >= brave_count


func _call_swarm() -> void:
	for p in swarm.get("members", [self]):
		if is_instance_valid(p) and not p.dead and p.global_position.distance_to(global_position) < brave_range * 1.5:
			p.state = State.SWARM


## Something died at `pos`: the swarm goes to strip it.
func food_at(pos: Vector3) -> void:
	swarm["food"] = pos
	if state == State.FORAGE:
		_goal = pos


func _hurt(_pos: Vector3) -> void:
	if state == State.FORAGE:
		if _brave():
			_call_swarm()
		else:
			state = State.FLEE
			_flee_t = 2.0


func _die() -> void:
	super()
	for p in swarm.get("members", []):
		if is_instance_valid(p) and not p.dead:
			p.food_at(global_position)
			break
