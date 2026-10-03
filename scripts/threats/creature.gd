extends CharacterBody3D
## Base for the wildlife past the border (glassback.gd, lampjaw.gd,
## quillcat.gd, bonepicker.gd, veil_ray.gd). It answers the same calls as a
## grunt so Eco's guns, smart lock and knife treat it like any other target
## (take_damage, is_headshot, stagger, is_unaware, hear_gunshot, died), but it
## has no stealth meter and never shows up on the militia radio. Models are
## assets/models/threats/<name>.glb on a threat_model.gd puppet.
## The pilot is found on its own (the run only hands targets to grunts).

const Pilot := preload("res://scripts/player.gd")
const FX := preload("res://scripts/fx.gd")
const SFX := preload("res://scripts/sfx.gd")
const ThreatModel := preload("res://scripts/threats/threat_model.gd")
const MODELS := "res://assets/models/threats/%s.glb"

signal died(creature: Node)

@export var max_health := 60.0
@export var move_speed := 4.0
@export var gravity := 20.0
## When true it just stands there (tests, showcases).
@export var passive := false

var health := 0.0
var target: CharacterBody3D
var dead := false
## True while it is hunting or fighting the pilot (Eco's whispers go quiet).
var alerted := false
var on_radio := false
var post := Vector3.ZERO
var home_yaw := NAN
var model: Node3D
var hurt_timer := 0.0
var rng := RandomNumberGenerator.new()
var _look_for := 0.0


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("wildlife")
	health = max_health
	if post == Vector3.ZERO:
		post = global_position
	rng.seed = hash(get_instance_id())
	_build()


## Collision and model; subclasses call _body() and _model().
func _build() -> void:
	pass


func _body(shape: Shape3D, offset: Vector3) -> void:
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = offset
	add_child(col)


func _model(model_name: String, gait: String, scale_by := 1.0) -> void:
	model = Node3D.new()
	model.set_script(ThreatModel)
	model.gait = gait
	model.add_child(load(MODELS % model_name).instantiate())
	model.scale = Vector3.ONE * scale_by
	add_child(model)


func _process(delta: float) -> void:
	hurt_timer -= delta
	if model != null and not dead:
		model.hurt = hurt_timer > 0.0
	if target == null and not passive:
		_look_for -= delta
		if _look_for <= 0.0:
			_look_for = 1.0
			target = find_pilot(self)


## Eco's body in the current scene, or null.
static func find_pilot(from: Node) -> CharacterBody3D:
	for b in from.get_tree().root.find_children("*", "CharacterBody3D", true, false):
		if b.get_script() == Pilot:
			return b
	return null


func is_headshot(_pos: Vector3) -> bool:
	return false


## Knife takedowns only work on something that hasn't noticed her.
func is_unaware() -> bool:
	return false


func take_damage(amount: float, pos: Vector3, _head := false) -> bool:
	if dead:
		return false
	health -= amount
	hurt_timer = 0.06
	_hurt(pos)
	if health > 0.0:
		return false
	_die()
	return true


func stagger(_seconds: float) -> void:
	hurt_timer = maxf(hurt_timer, 0.15)


## A gunshot went off at `pos` (Eco's weapon calls this on every "enemies" node).
func hear_gunshot(pos: Vector3) -> void:
	if not dead and not passive:
		_noise(pos)


func _hurt(_pos: Vector3) -> void:
	pass


func _noise(_pos: Vector3) -> void:
	pass


func _die() -> void:
	dead = true
	alerted = false
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0
	died.emit(self)
	if model != null:
		model.set_process(false)
		for g in model.find_children("*", "GeometryInstance3D", true, false):
			(g as GeometryInstance3D).set_instance_shader_parameter("glow", 0.0)
			(g as GeometryInstance3D).set_instance_shader_parameter("flash", 0.0)
	var tween := create_tween()
	tween.tween_property(self, "rotation:z", PI / 2.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_interval(6.0)
	tween.tween_callback(queue_free)


# --- helpers ---------------------------------------------------------------

## Flat vector from this creature to the pilot (zero without one).
func to_pilot() -> Vector3:
	if target == null:
		return Vector3.ZERO
	var d := target.global_position - global_position
	d.y = 0.0
	return d


func face(dir: Vector3, delta: float, rate := 8.0) -> void:
	if Vector2(dir.x, dir.z).length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-rate * delta))


## Gravity, steering toward `want` (a direction times 0-1) and sliding; stops
## at platform edges.
func walk(want: Vector3, delta: float, accel := 20.0) -> void:
	velocity.y -= gravity * delta
	if want != Vector3.ZERO and not ground_ahead(want.normalized()):
		want = Vector3.ZERO
	var h := Vector3(velocity.x, 0.0, velocity.z).move_toward(want * move_speed, accel * delta)
	velocity.x = h.x
	velocity.z = h.z
	move_and_slide()


func ground_ahead(dir: Vector3, reach := 1.2) -> bool:
	if not is_on_floor():
		return true
	var from := global_position + dir * reach + Vector3.UP * 0.5
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 2.5)
	query.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## A wander point within `radius` of the post.
func wander_point(radius: float) -> Vector3:
	var a := rng.randf() * TAU
	return post + Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(radius * 0.3, radius)


func sound(id: String, volume_db := 0.0, height := 1.0) -> void:
	SFX.play_at(get_parent(), global_position + Vector3.UP * height, id, volume_db, SFX.vary(0.07))
