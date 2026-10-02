extends CharacterBody3D
## Basic grunt. Starts unaware and has to notice the pilot first: it only
## sees inside a forward cone, out to its sight range, with cover blocking the
## view, and a detection meter fills while it can see (faster up close, when
## the pilot moves fast, and slower for a crouched pilot or one peeking over
## cover). Footsteps and gunshots can be heard from behind. Half full it turns
## to look ("?"), full it is alerted ("!") and calls its squad in.
## Once alerted it holds a mid range, strafes, and fires slow single shots
## after a visible wind-up (the visor glows red). Its aim gets worse the faster
## the pilot moves, so wallrunning and sliding are your best armour.

const Pilot := preload("res://scripts/player.gd")
const FX := preload("res://scripts/fx.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")

signal died(grunt: Node)
signal awareness_changed(grunt: Node, awareness: int)

enum Awareness { UNAWARE, SUSPICIOUS, ALERTED }

@export var max_health := 60.0
@export var move_speed := 3.5
@export var sight_range := 40.0
@export var preferred_range := 12.0
@export var fire_interval := 1.4
@export var windup := 0.4
@export var damage := 8.0
## Chance to hit a pilot standing still at close range.
@export var base_hit_chance := 0.65
## Hit chance lost per m/s of pilot speed.
@export var speed_dodge := 0.045
## Extra hit chance lost while the pilot is off the ground.
@export var air_dodge := 0.1
## Hit chance lost per metre beyond 10 m.
@export var range_dodge := 0.01
@export var min_hit_chance := 0.05
@export var gravity := 20.0
## When true the grunt just stands there (used by tests and target practice).
@export var passive := false
## When above 0 the grunt holds near its post (behind its cover) instead of
## chasing, wandering at most this far from it.
@export var leash := 0.0

@export_group("Stealth")
## Half-angle of the vision cone, in degrees. Outside it the grunt sees nothing.
@export var view_cone := 60.0
## Detection gained per second for a standing pilot in plain view, from the
## edge of sight range up to point-blank.
@export var notice_rate_far := 0.3
@export var notice_rate_near := 3.0
## Detection multiplier for a crouched pilot (not sliding).
@export var crouch_notice := 0.45
## Detection multiplier when only the pilot's head or body shows past cover.
@export var partial_notice := 0.6
## Footsteps carry this many metres per m/s of pilot speed (a sprint is ~7 m,
## a crouch walk ~1 m). Airborne pilots and grapples make no footsteps.
@export var footstep_range := 0.7
## Anything this close gets noticed, seen or not.
@export var touch_range := 1.5
## Gunshots are heard this far away; within the first third they alert outright.
@export var gunshot_range := 30.0
## Detection lost per second once the pilot has been gone for calm_delay.
@export var calm_rate := 0.15
@export var calm_delay := 2.0
## Detection at which the grunt turns to look.
@export var suspicious_at := 0.35
## Squadmates this close hear an alerted grunt's callout.
@export var callout_range := 16.0
## Alerted grunts that lose sight of the pilot this long go back to searching.
@export var lose_track_time := 10.0

const HEAD_Y := 1.5  # hits higher than this above the feet are headshots
const EYE := Vector3(0, 1.6, 0)
const MUZZLE := Vector3(0.3, 1.2, -0.6)

var health := 0.0
var target: CharacterBody3D
## True while alerted (fighting); kept alongside `awareness` for older callers.
var alerted := false
var awareness := Awareness.UNAWARE
## Detection meter, 0 to 1. Reaching 1 alerts the grunt.
var detection := 0.0
## Where the grunt last saw or heard something; it looks there when suspicious.
var last_known := Vector3.ZERO
var since_stimulus := 99.0
var since_seen := 0.0
var home_yaw := NAN
var scan_time := 0.0
var has_sight := false
var sight_timer := 0.0
var fire_timer := 0.0
var windup_timer := -1.0
var strafe_dir := 1.0
var strafe_timer := 0.0
var dead := false
var post := Vector3.ZERO
var rng := RandomNumberGenerator.new()

var model: Node3D
var hurt_timer := 0.0
var indicator: Label3D
var indicator_pop := 0.0


func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	post = global_position
	fire_timer = rng.randf_range(0.5, fire_interval)
	strafe_dir = 1.0 if rng.randf() < 0.5 else -1.0
	scan_time = rng.randf() * TAU
	_build_body()


func _physics_process(delta: float) -> void:
	if dead:
		return
	velocity.y -= gravity * delta
	var hvel := Vector3(velocity.x, 0.0, velocity.z)
	var want := Vector3.ZERO

	if is_nan(home_yaw):
		home_yaw = rotation.y  # spawners set the facing after _ready
	if not passive and target != null:
		_update_sight(delta)
		var to := target.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if alerted:
			since_seen = 0.0 if has_sight else since_seen + delta
			if dist > sight_range * 1.5 or since_seen > lose_track_time:
				lose_track()
		else:
			_unaware_look(delta)
		if alerted and dist > 0.1:
			var dir := to / dist
			rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-8.0 * delta))
			want = _movement(dir, dist, delta)
			_combat(delta)

	if leash > 0.0:
		var home := post - global_position
		home.y = 0.0
		if home.length() > leash:
			want = home.normalized()
		elif want != Vector3.ZERO and (home - want).length() > leash:
			want = Vector3.ZERO  # that step would leave the post
	if want != Vector3.ZERO and not _ground_ahead(want):
		want = Vector3.ZERO
		strafe_dir = -strafe_dir

	hvel = hvel.move_toward(want * move_speed, 20.0 * delta)
	velocity.x = hvel.x
	velocity.z = hvel.z
	move_and_slide()
	if is_on_wall():
		strafe_dir = -strafe_dir


func _process(delta: float) -> void:
	hurt_timer -= delta
	if model == null:
		return
	model.set_param("flash", 0.7 if hurt_timer > 0.0 else 0.0)
	var glow := 0.0 if windup_timer < 0.0 else 1.0 - windup_timer / windup
	model.set_param("paint", Color(0.9, 0.7, 0.2).lerp(Color(1.0, 0.1, 0.05), glow), "Visor")
	model.set_param("glow", 0.5 + glow * 4.0, "Visor")
	_update_indicator(delta)


## "?" that fills in yellow to orange while the grunt is noticing the pilot,
## "!" in red once it's alerted. Drawn over cover so you can read it hiding.
func _update_indicator(delta: float) -> void:
	indicator_pop = maxf(indicator_pop - delta * 4.0, 0.0)
	if dead or passive or (awareness == Awareness.UNAWARE and detection < 0.02):
		indicator.visible = false
		return
	indicator.visible = true
	var scale_up := 1.0 + indicator_pop * 0.6
	if awareness == Awareness.ALERTED:
		indicator.text = "!"
		indicator.modulate = Color(1.0, 0.15, 0.1)
	else:
		indicator.text = "?"
		indicator.modulate = Color(1.0, 0.9, 0.3).lerp(Color(1.0, 0.45, 0.1), detection)
		indicator.modulate.a = lerpf(0.35, 1.0, clampf(detection / suspicious_at, 0.0, 1.0))
		scale_up *= lerpf(0.7, 1.0, detection)
	indicator.scale = Vector3.ONE * scale_up


## True when there is floor a short step in this direction (keeps grunts on platforms).
func _ground_ahead(dir: Vector3) -> bool:
	if not is_on_floor():
		return true
	var from := global_position + dir * 0.9 + Vector3.UP * 0.5
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 2.0)
	query.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


const SIGHT_TICK := 0.2


func _update_sight(delta: float) -> void:
	since_stimulus += delta
	sight_timer -= delta
	if sight_timer > 0.0:
		return
	sight_timer = SIGHT_TICK
	var from := global_position + EYE
	if alerted:
		# Already fighting: it tracks the pilot wherever it can see them.
		has_sight = _visible_points(from) > 0
		if has_sight:
			last_known = target.global_position
		return
	has_sight = false
	var gain := _sight_gain(from) + _hearing_gain()
	if gain > 0.0:
		detection += gain * SIGHT_TICK
		since_stimulus = 0.0
		last_known = target.global_position
	elif since_stimulus > calm_delay:
		detection -= calm_rate * SIGHT_TICK
	detection = clampf(detection, 0.0, 1.0)
	if detection >= 1.0:
		alert()
	else:
		_set_awareness(Awareness.SUSPICIOUS if detection >= suspicious_at else Awareness.UNAWARE)


## Detection per second from seeing the pilot right now (0 when it can't).
func _sight_gain(from: Vector3) -> float:
	var to := target.global_position - global_position
	var dist := to.length()
	if dist > sight_range:
		return 0.0
	var flat := Vector3(to.x, 0.0, to.z)
	var facing := -global_basis.z
	var angle: float = rad_to_deg(facing.angle_to(flat)) if flat.length() > 0.01 else 0.0
	if angle > view_cone:
		return 0.0
	var points := _visible_points(from)
	if points == 0:
		return 0.0
	has_sight = true
	var near := 1.0 - dist / sight_range
	var rate := lerpf(notice_rate_far, notice_rate_near, near * near)
	rate *= lerpf(1.0, 0.5, angle / view_cone)  # slower at the edge of vision
	if points == 1:
		rate *= partial_notice
	if target.crouching and target.state != Pilot.State.SLIDE:
		rate *= crouch_notice
	rate *= 1.0 + clampf(target.horizontal_speed() / target.sprint_speed, 0.0, 2.0)
	return rate


## Detection per second from footsteps (and bumping into the grunt).
func _hearing_gain() -> float:
	var dist := global_position.distance_to(target.global_position)
	if dist < touch_range:
		return 4.0
	var r := 0.0
	match target.state:
		Pilot.State.GROUND, Pilot.State.SLIDE, Pilot.State.WALLRUN:
			r = target.horizontal_speed() * footstep_range
			if target.crouching and target.state == Pilot.State.GROUND:
				r *= 0.4
	if dist >= r:
		return 0.0
	return 0.6 + 1.6 * (1.0 - dist / r)


## How many of the pilot's head and chest this grunt has a clear line to (0-2).
func _visible_points(from: Vector3) -> int:
	var eye := 0.8 if target.crouching else 1.55
	var count := 0
	for h in [eye, eye * 0.6]:
		var query := PhysicsRayQueryParameters3D.create(from, target.global_position + Vector3.UP * h)
		query.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.collider == target:
			count += 1
	return count


## Unaware grunts sweep their gaze around their post; suspicious ones turn to
## face whatever they noticed.
func _unaware_look(delta: float) -> void:
	var want := home_yaw
	if awareness == Awareness.SUSPICIOUS:
		var d := last_known - global_position
		if Vector2(d.x, d.z).length() > 0.5:
			want = atan2(-d.x, -d.z)
	else:
		scan_time += delta
		want += sin(scan_time * 0.6) * deg_to_rad(35.0)
	var speed := 5.0 if awareness == Awareness.SUSPICIOUS else 1.5
	rotation.y = lerp_angle(rotation.y, want, 1.0 - exp(-speed * delta))


## Spots the pilot outright. With callout, nearby squadmates are alerted too
## (they don't pass it on further).
func alert(callout := true) -> void:
	if dead or passive:
		return
	detection = 1.0
	since_seen = 0.0
	if target != null:
		last_known = target.global_position
	var was := alerted
	alerted = true
	_set_awareness(Awareness.ALERTED)
	if was or not callout:
		return
	for g in get_tree().get_nodes_in_group("enemies"):
		if g != self and g.has_method("alert") and not g.alerted \
				and g.global_position.distance_to(global_position) <= callout_range:
			g.alert(false)


## Lost the pilot: back to searching where they were last seen.
func lose_track() -> void:
	alerted = false
	windup_timer = -1.0
	detection = 0.6
	since_stimulus = 0.0
	_set_awareness(Awareness.SUSPICIOUS)


## A gunshot went off at this position (the pilot's weapon calls this).
func hear_gunshot(pos: Vector3) -> void:
	if dead or passive or alerted:
		return
	var dist := global_position.distance_to(pos)
	if dist > gunshot_range:
		return
	last_known = pos
	since_stimulus = 0.0
	if dist < gunshot_range / 3.0:
		alert()
		return
	detection = maxf(detection, 0.5 + 0.4 * (1.0 - dist / gunshot_range))
	_set_awareness(Awareness.SUSPICIOUS)


func _set_awareness(a: Awareness) -> void:
	if a == awareness:
		return
	if a > awareness:
		indicator_pop = 1.0
	awareness = a
	awareness_changed.emit(self, a)


func _movement(dir: Vector3, dist: float, delta: float) -> Vector3:
	strafe_timer -= delta
	if strafe_timer <= 0.0:
		strafe_timer = rng.randf_range(1.0, 2.5)
		strafe_dir = -strafe_dir
	var side := Vector3(-dir.z, 0.0, dir.x) * strafe_dir
	if not has_sight or dist > preferred_range + 4.0:
		return (dir + side * 0.3).normalized()
	if dist < preferred_range - 5.0:
		return (-dir + side * 0.5).normalized()
	return side * 0.6


func _combat(delta: float) -> void:
	if windup_timer >= 0.0:
		windup_timer -= delta
		if windup_timer < 0.0:
			if has_sight:
				_shoot()
			fire_timer = fire_interval + rng.randf() * 0.5
		return
	if not has_sight:
		return
	fire_timer -= delta
	if fire_timer <= 0.0:
		windup_timer = windup


## Chance this grunt's next shot lands on the target, from 0 to 1.
func hit_chance() -> float:
	var c: float = base_hit_chance - target.horizontal_speed() * speed_dodge
	if target.state != Pilot.State.GROUND and target.state != Pilot.State.SLIDE:
		c -= air_dodge
	c -= maxf(global_position.distance_to(target.global_position) - 10.0, 0.0) * range_dodge
	return clampf(c, min_hit_chance, base_hit_chance)


func _shoot() -> void:
	var from := global_transform * MUZZLE
	var chest := target.global_position + Vector3.UP * 1.1
	var end := chest
	if rng.randf() < hit_chance():
		target.take_damage(damage, global_position)
	else:
		# Miss: aim at a point beside the pilot and let the round fly past.
		var dir := (chest - from).normalized()
		var side := dir.cross(Vector3.UP).normalized()
		var miss := side * rng.randf_range(0.7, 1.4) * (1.0 if rng.randf() < 0.5 else -1.0)
		miss.y = rng.randf_range(-0.6, 0.8)
		end = from + ((chest + miss) - from).normalized() * (from.distance_to(chest) + 15.0)
		var query := PhysicsRayQueryParameters3D.create(from, end)
		query.exclude = [get_rid(), target.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			end = hit.position
	FX.tracer(get_parent(), from, end, Color(1.0, 0.3, 0.2, 0.9), 0.03, 0.12)
	FX.spark(get_parent(), from, Color(1.0, 0.6, 0.2), 0.1, 0.06)


func is_headshot(pos: Vector3) -> bool:
	return pos.y - global_position.y > HEAD_Y


## Returns true when this hit killed the grunt.
func take_damage(amount: float, _pos: Vector3, _head := false) -> bool:
	if dead:
		return false
	health -= amount
	hurt_timer = 0.06
	alert()
	if health > 0.0:
		return false
	_die()
	return true


func _die() -> void:
	dead = true
	windup_timer = -1.0
	indicator.visible = false
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0
	died.emit(self)
	var tween := create_tween()
	tween.tween_property(self, "rotation:x", -PI / 2.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_interval(3.0)
	tween.tween_callback(queue_free)


func _build_body() -> void:
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	var col := CollisionShape3D.new()
	col.shape = cap
	col.position.y = 0.9
	add_child(col)

	model = Art.model("grunt")
	add_child(model)

	indicator = Label3D.new()
	indicator.name = "Awareness"
	indicator.position.y = 2.4
	indicator.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	indicator.no_depth_test = true
	indicator.fixed_size = true
	indicator.pixel_size = 0.0022
	indicator.font_size = 64
	indicator.outline_size = 16
	indicator.outline_modulate = Color(0, 0, 0, 0.8)
	indicator.render_priority = 10
	indicator.visible = false
	add_child(indicator)
