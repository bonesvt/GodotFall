extends "res://scripts/threats/creature.gd"
## QUILLCAT: four-eyed pack hunter, 1.1 m at the shoulder, hunting in threes.
## A pack roams round its den until one of them spots, hears or gets hurt by
## Eco; then the whole pack circles her at a few metres, each one taking a turn
## to commit. The tell is the neck frill: it flares and the four eyes blaze just
## before the pounce, which is the moment to dodge. Unaware cats can be knifed.

enum State { ROAM, STALK, TELL, POUNCE, RECOVER }

@export var sight_range := 24.0
@export var view_cone := 80.0
@export var hear_range := 1.6
@export var circle_radius := 7.5
@export var pounce_speed := 18.0
@export var pounce_damage := 18.0
@export var tell_time := 0.6
## Gives up on a pilot this far away.
@export var give_up := 42.0

## The pack, shared by its cats (threat_spawner.gd sets it).
var pack: Array = []
var state := State.ROAM
var _t := 0.0
var _angle := 0.0
var _goal := Vector3.ZERO
var _struck := false
var _sight_tick := 0.0


func _init() -> void:
	max_health = 70.0
	move_speed = 7.5


func _build() -> void:
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 2.0
	_body(cap, Vector3(0, 0.75, 0.1))
	get_child(0).rotation.x = PI / 2.0
	_model("quillcat", "quad")
	model.stride_len = 2.2
	_goal = global_position
	_angle = rng.randf() * TAU


func is_headshot(pos: Vector3) -> bool:
	return (global_basis.inverse() * (pos - global_position)).z < -0.75


func is_unaware() -> bool:
	return not dead and state == State.ROAM


func _physics_process(delta: float) -> void:
	if dead:
		return
	var want := Vector3.ZERO
	var frill := 0.0
	var tell := 0.0
	_t += delta
	if not passive and target != null:
		var to := to_pilot()
		var dist := to.length()
		match state:
			State.ROAM:
				move_speed = 2.2
				want = _roam(delta)
				_sight_tick -= delta
				if _sight_tick <= 0.0:
					_sight_tick = 0.2
					if _spots(to, dist):
						rouse()
			State.STALK:
				move_speed = 6.0
				if dist > give_up:
					_calm_pack()
				else:
					_angle += delta * 0.6 * (1.0 if get_instance_id() % 2 == 0 else -1.0)
					var spot := target.global_position + Vector3(cos(_angle), 0, sin(_angle)) * circle_radius
					var d := spot - global_position
					d.y = 0.0
					want = d.normalized() * clampf(d.length() / 2.0, 0.0, 1.0)
					face(to, delta, 6.0)
					frill = 0.3
					if _t > 0.0 and _my_turn():
						state = State.TELL
						_t = 0.0
						sound("quillcat_hiss", 0.0, 0.9)
			State.TELL:
				face(to, delta, 12.0)
				frill = 1.0
				tell = 1.0
				if _t >= tell_time:
					state = State.POUNCE
					_t = 0.0
					_struck = false
					# Timed to land on her: up 4 m/s is about 0.4 s in the air.
					velocity = to.normalized() * clampf(dist / 0.4, 6.0, pounce_speed) + Vector3.UP * 4.0
			State.POUNCE:
				frill = 1.0
				var reach := (target.global_position + Vector3.UP) - (global_position + Vector3.UP * 0.7)
				if not _struck and reach.length() < 1.6:
					_struck = true
					target.take_damage(pounce_damage, global_position)
					FX.spark(get_parent(), target.global_position + Vector3.UP, Color(1.0, 0.85, 0.3), 0.2, 0.1)
				if _t > 0.25 and is_on_floor():
					state = State.RECOVER
					_t = 0.0
			State.RECOVER:
				if _t > 0.9:
					state = State.STALK
					_t = -rng.randf_range(2.0, 4.0)
	if model != null:
		model.open = lerpf(model.open, frill, minf(delta * 10.0, 1.0))
		model.tell = tell
	if state == State.POUNCE:
		velocity.y -= gravity * delta
		move_and_slide()
	else:
		walk(want, delta, 25.0)


func _roam(delta: float) -> Vector3:
	var d := _goal - global_position
	d.y = 0.0
	if d.length() < 1.0:
		_goal = wander_point(9.0)
		return Vector3.ZERO
	face(d, delta, 4.0)
	return d.normalized() * 0.6


## Sees (cone and line of sight) or hears (footsteps) the pilot.
func _spots(to: Vector3, dist: float) -> bool:
	if dist < 2.5:
		return true
	match target.state:
		Pilot.State.GROUND, Pilot.State.SLIDE, Pilot.State.WALLRUN:
			var r: float = target.horizontal_speed() * hear_range
			if target.crouching:
				r *= 0.25
			if dist < r:
				return true
	if dist > sight_range:
		return false
	if rad_to_deg((-global_basis.z).angle_to(to)) > view_cone:
		return false
	var mult = target.get("notice_mult")
	if mult != null and dist > sight_range * float(mult):
		return false
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.9,
			target.global_position + Vector3.UP * (0.8 if target.crouching else 1.4), 1 | 16)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == target


## The whole pack turns on the pilot.
func rouse() -> void:
	for c in (pack if not pack.is_empty() else [self]):
		if is_instance_valid(c) and not c.dead and c.state == State.ROAM:
			c.state = State.STALK
			c.alerted = true
			c._t = -c.rng.randf_range(0.5, 3.0)
	sound("quillcat_yowl", 0.0, 0.9)


func _calm_pack() -> void:
	for c in (pack if not pack.is_empty() else [self]):
		if is_instance_valid(c) and not c.dead:
			c.state = State.ROAM
			c.alerted = false
			c.post = c.global_position


## One cat commits at a time.
func _my_turn() -> bool:
	for c in pack:
		if c != self and is_instance_valid(c) and not c.dead and c.state in [State.TELL, State.POUNCE]:
			return false
	return true


func _noise(pos: Vector3) -> void:
	if state == State.ROAM and global_position.distance_to(pos) < 35.0:
		rouse()


func _hurt(_pos: Vector3) -> void:
	if state == State.ROAM:
		rouse()
	for c in pack:  # the rest of the pack gets bolder
		if is_instance_valid(c) and c != self and c.state == State.STALK:
			c._t = maxf(c._t, 0.0)
