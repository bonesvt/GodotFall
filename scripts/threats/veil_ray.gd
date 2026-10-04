extends "res://scripts/threats/creature.gd"
## VEIL RAY: a 4.5 m gliding ray that drifts in slow flocks high over the
## lanes. Harmless and ignored by everything. When something nearby starts a
## fight (a Choir unit or a grunt alerted, a Glassback stampeding, a Quillcat
## pack on the hunt) or one of them is hit, the flock scatters upward, so a
## scattering flock means something is coming.

@export var radius := 22.0
@export var glide_speed := 6.0
@export var scatter_speed := 17.0
## Fights within this distance of the flock's centre scatter it.
@export var alarm_range := 55.0

## Centre of the flock's circle (in the air), shared offsets per ray.
var center := Vector3.ZERO
var flock: Array = []
var _angle := 0.0
var _lift := 0.0
var _scatter := 0.0
var _scatter_dir := Vector3.ZERO
var _check := 0.0


func _init() -> void:
	max_health = 30.0
	gravity = 0.0


func _ready() -> void:
	super()
	remove_from_group("enemies")  # not a target for the smart lock
	collision_mask = 0
	if center == Vector3.ZERO:
		center = global_position
	_angle = rng.randf() * TAU
	_lift = rng.randf_range(-3.0, 3.0)


func _build() -> void:
	var sphere := SphereShape3D.new()
	sphere.radius = 1.0
	_body(sphere, Vector3.ZERO)
	_model("veilray", "glide")
	model.scale = Vector3.ONE * rng.randf_range(0.85, 1.15)


func _physics_process(delta: float) -> void:
	if dead:
		return
	_check -= delta
	if _check <= 0.0 and not passive:
		_check = 0.3
		if _danger_near():
			scatter()
	var vel: Vector3
	if _scatter > 0.0:
		_scatter -= delta
		vel = _scatter_dir * scatter_speed
		if _scatter <= 0.0:
			center = global_position - Vector3(cos(_angle), 0, sin(_angle)) * radius
	else:
		_angle += glide_speed / radius * delta
		var spot := center + Vector3(cos(_angle) * radius, _lift + sin(_angle * 2.0) * 1.5, sin(_angle) * radius)
		vel = (spot - global_position) * 1.5
		vel = vel.limit_length(glide_speed * 1.6)
	global_position += vel * delta
	if vel.length() > 0.1:
		face(vel, delta, 3.0)
	if model != null:
		model.cycle_speed = vel.length() * (2.0 if _scatter > 0.0 else 0.4)


func _danger_near() -> bool:
	if _scatter > 0.0:
		return false
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.get("alerted") == true and e.global_position.distance_to(center) < alarm_range:
			return true
	return false


## The whole flock flees upward and outward.
func scatter() -> void:
	for r in (flock if not flock.is_empty() else [self]):
		if not is_instance_valid(r) or r.dead or r._scatter > 0.0:
			continue
		var out: Vector3 = r.global_position - center
		out.y = 0.0
		if out.length() < 0.1:
			out = Vector3(1, 0, 0)
		r._scatter_dir = (out.normalized() + Vector3.UP * 0.6 + Vector3(r.rng.randf_range(-0.3, 0.3), 0, r.rng.randf_range(-0.3, 0.3))).normalized()
		r._scatter = r.rng.randf_range(5.0, 7.0)
	sound("veilray_call", 0.0, 0.0)


func _hurt(_pos: Vector3) -> void:
	scatter()


func _die() -> void:
	super()
	var tween := create_tween()
	tween.tween_property(self, "global_position:y", global_position.y - 40.0, 2.5) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
