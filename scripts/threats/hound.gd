extends "res://scripts/threats/choir_unit.gd"
## HOUND: the Choir's eyeless hunter. It can't see you at all: the glowing
## vanes on its skull listen. Sprinting, hard landings, wallruns and gunfire
## carry a long way to it, and it goes to where it heard them. Crouch-walking
## is close to silent, and a Hound that stops hearing you loses you, so the
## knife and the crouch walk beat it. Once on you it runs you down and
## pounces with its scythe forelegs after a short tell (vanes flare white,
## head drops).

## Footsteps carry this many metres per m/s of pilot speed (a grunt: 0.5).
@export var hear_range := 2.2
## Hunting, it keeps track of a pilot this close whatever the noise.
@export var close_sense := 5.0
@export var pounce_range := 4.5
@export var pounce_speed := 13.0
@export var pounce_damage := 24.0
@export var pounce_cooldown := 1.8
## Points it prowls round in a loop while it hasn't heard anything (straight
## lines between them; it stops at edges).
@export var route := PackedVector3Array()

var _route_i := 0
var _route_wait := 0.0

var _cooldown := 0.0
var _leaping := 0.0
var _struck := false


func _init() -> void:
	model_name = "hound"
	gait = "quad"
	body_radius = 0.45
	body_height = 1.3
	head_y = 0.8
	max_health = 75.0
	move_speed = 7.0
	sight_range = 40.0
	preferred_range = 0.0
	windup = 0.45
	damage = pounce_damage
	gunshot_range = 45.0
	touch_range = 2.0
	lose_track_time = 4.0
	view_cone = 180.0
	calm_rate = 0.12


## Eyeless: sight gives nothing except bumping into the pilot.
func _sight_gain(_from: Vector3) -> float:
	return 0.0


## Hears footsteps far further than a grunt; a crouch walk barely registers.
func _hearing_gain() -> float:
	var dist := global_position.distance_to(target.global_position)
	if dist < touch_range:
		return 4.0
	var r := _noise_radius()
	if dist >= r:
		return 0.0
	return 0.5 + 2.0 * (1.0 - dist / r)


## How far the pilot's movement can be heard right now (metres).
func _noise_radius() -> float:
	var r := 0.0
	match target.state:
		Pilot.State.GROUND, Pilot.State.SLIDE, Pilot.State.WALLRUN:
			r = target.horizontal_speed() * hear_range
			if target.crouching and target.state == Pilot.State.GROUND:
				r *= 0.12
	return r


## Hunting: it "sees" the pilot while it can hear them, or they're right there.
func _visible_points(_from: Vector3) -> int:
	var dist := global_position.distance_to(target.global_position)
	return 2 if dist < close_sense or dist < _noise_radius() else 0


func hear_gunshot(pos: Vector3) -> void:
	if dead or passive:
		return
	if alerted:
		if global_position.distance_to(pos) < gunshot_range:
			last_known = pos
			since_seen = 0.0
		return
	super(pos)


func _physics_process(delta: float) -> void:
	if dead:
		return
	velocity.y -= gravity * delta
	_cooldown -= delta
	if is_nan(home_yaw):
		home_yaw = rotation.y
	if _leaping > 0.0:
		_leap(delta)
		return
	var want := Vector3.ZERO
	if not passive and target != null:
		_update_sight(delta)
		var to := target.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if alerted:
			since_seen = 0.0 if has_sight else since_seen + delta
			if since_seen > lose_track_time:
				lose_track()
		if alerted:
			var goal := target.global_position if has_sight else last_known
			want = _head_for(goal, delta)
			_combat_hound(dist, delta)
		elif awareness == Awareness.SUSPICIOUS:
			# Goes to listen where the noise came from.
			want = _head_for(last_known, delta) * 0.45
			if want == Vector3.ZERO:
				_unaware_look(delta)
		elif route.size() >= 2:
			want = _prowl(delta)
		else:
			_unaware_look(delta)
	if leash > 0.0 and not alerted and awareness == Awareness.UNAWARE:
		var home := post - global_position
		home.y = 0.0
		if home.length() > leash:
			want = home.normalized() * 0.5
	if want != Vector3.ZERO and not _ground_ahead(want.normalized()):
		want = Vector3.ZERO
	var hvel := Vector3(velocity.x, 0.0, velocity.z).move_toward(want * move_speed, 30.0 * delta)
	velocity.x = hvel.x
	velocity.z = hvel.z
	move_and_slide()
	if model != null:
		model.look = Vector2(0.0, -0.35 if windup_timer >= 0.0 else (0.15 if awareness == Awareness.SUSPICIOUS else 0.0))


func _prowl(delta: float) -> Vector3:
	if _route_wait > 0.0:
		_route_wait -= delta
		_unaware_look(delta)
		return Vector3.ZERO
	var step := _head_for(route[_route_i % route.size()], delta)
	if step == Vector3.ZERO:
		_route_i = (_route_i + 1) % route.size()
		_route_wait = rng.randf_range(1.0, 3.0)
		return Vector3.ZERO
	home_yaw = rotation.y
	return step * 0.3


func _head_for(goal: Vector3, delta: float) -> Vector3:
	var d := goal - global_position
	d.y = 0.0
	if d.length() < 1.2:
		return Vector3.ZERO
	var dir := d.normalized()
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-10.0 * delta))
	return dir


func _combat_hound(dist: float, delta: float) -> void:
	if windup_timer >= 0.0:
		windup_timer -= delta
		if windup_timer < 0.0:
			_pounce()
		return
	if has_sight and dist < pounce_range and _cooldown <= 0.0:
		windup_timer = windup
		_start_tell()


func _pounce() -> void:
	var d := target.global_position - global_position
	d.y = 0.0
	var dir := d.normalized() if d.length() > 0.1 else -global_basis.z
	velocity = dir * pounce_speed + Vector3.UP * 4.5
	_leaping = 0.6
	_struck = false
	_cooldown = pounce_cooldown
	SFX.play_at(get_parent(), global_position + Vector3.UP, "hound_screech", -2.0, SFX.vary(0.08))


func _leap(delta: float) -> void:
	_leaping -= delta
	move_and_slide()
	if not _struck and target != null:
		var reach := (target.global_position + Vector3.UP) - (global_position + Vector3.UP * 0.8)
		if reach.length() < 1.7:
			_struck = true
			target.take_damage(pounce_damage, global_position)
			FX.spark(get_parent(), target.global_position + Vector3.UP * 1.1, CYAN, 0.25, 0.12)
			SFX.play_at(get_parent(), target.global_position, "knife_hit", -4.0, SFX.vary(0.1))
	if _leaping <= 0.0 or (is_on_floor() and _leaping < 0.45):
		_leaping = 0.0
		velocity.x *= 0.2
		velocity.z *= 0.2


func stagger(seconds: float) -> void:
	super(seconds)
	_cooldown = maxf(_cooldown, seconds)
