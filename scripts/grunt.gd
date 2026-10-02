extends CharacterBody3D
## Basic grunt. Spots the pilot by line of sight, holds a mid range,
## strafes, and fires slow single shots after a visible wind-up
## (the visor glows red). Its aim gets worse the faster the pilot moves,
## so wallrunning and sliding are your best armour.

const Pilot := preload("res://scripts/player.gd")
const FX := preload("res://scripts/fx.gd")

signal died(grunt: Node)

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

const HEAD_Y := 1.5  # hits higher than this above the feet are headshots
const EYE := Vector3(0, 1.6, 0)
const MUZZLE := Vector3(0.3, 1.2, -0.6)

var health := 0.0
var target: CharacterBody3D
var alerted := false
var has_sight := false
var sight_timer := 0.0
var fire_timer := 0.0
var windup_timer := -1.0
var strafe_dir := 1.0
var strafe_timer := 0.0
var dead := false
var rng := RandomNumberGenerator.new()

var body_mat: StandardMaterial3D
var visor_mat: StandardMaterial3D
var hurt_timer := 0.0


func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	fire_timer = rng.randf_range(0.5, fire_interval)
	strafe_dir = 1.0 if rng.randf() < 0.5 else -1.0
	_build_body()


func _physics_process(delta: float) -> void:
	if dead:
		return
	velocity.y -= gravity * delta
	var hvel := Vector3(velocity.x, 0.0, velocity.z)
	var want := Vector3.ZERO

	if not passive and target != null:
		_update_sight(delta)
		var to := target.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if alerted and dist > sight_range * 1.5:
			alerted = false
		if alerted and dist > 0.1:
			var dir := to / dist
			rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-8.0 * delta))
			want = _movement(dir, dist, delta)
			_combat(delta)

	hvel = hvel.move_toward(want * move_speed, 20.0 * delta)
	velocity.x = hvel.x
	velocity.z = hvel.z
	move_and_slide()
	if is_on_wall():
		strafe_dir = -strafe_dir


func _process(delta: float) -> void:
	hurt_timer -= delta
	if body_mat == null:
		return
	body_mat.emission_enabled = hurt_timer > 0.0
	var glow := 0.0 if windup_timer < 0.0 else 1.0 - windup_timer / windup
	visor_mat.albedo_color = Color(0.9, 0.7, 0.2).lerp(Color(1.0, 0.1, 0.05), glow)
	visor_mat.emission_energy_multiplier = 0.5 + glow * 4.0


func _update_sight(delta: float) -> void:
	sight_timer -= delta
	if sight_timer > 0.0:
		return
	sight_timer = 0.2
	has_sight = false
	var from := global_position + EYE
	var to := target.global_position + Vector3.UP * 1.2
	if from.distance_to(to) > sight_range and not alerted:
		return
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	has_sight = not hit.is_empty() and hit.collider == target
	if has_sight:
		alerted = true


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
	alerted = true
	if health > 0.0:
		return false
	_die()
	return true


func _die() -> void:
	dead = true
	windup_timer = -1.0
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

	body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.35, 0.38, 0.3)
	body_mat.emission = Color(1, 1, 1)
	body_mat.emission_energy_multiplier = 1.5
	var torso := CapsuleMesh.new()
	torso.radius = 0.33
	torso.height = 1.45
	torso.material = body_mat
	_mesh(torso, Vector3(0, 0.72, 0))

	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.25, 0.27, 0.22)
	var head := SphereMesh.new()
	head.radius = 0.2
	head.height = 0.4
	head.material = head_mat
	_mesh(head, Vector3(0, 1.62, 0))

	visor_mat = StandardMaterial3D.new()
	visor_mat.emission_enabled = true
	visor_mat.emission = Color(1.0, 0.2, 0.1)
	var visor := BoxMesh.new()
	visor.size = Vector3(0.3, 0.08, 0.1)
	visor.material = visor_mat
	_mesh(visor, Vector3(0, 1.65, -0.16))

	var gun_mat := StandardMaterial3D.new()
	gun_mat.albedo_color = Color(0.12, 0.12, 0.12)
	var gun := BoxMesh.new()
	gun.size = Vector3(0.08, 0.12, 0.7)
	gun.material = gun_mat
	_mesh(gun, Vector3(0.3, 1.2, -0.3))


func _mesh(mesh: Mesh, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	add_child(mi)
