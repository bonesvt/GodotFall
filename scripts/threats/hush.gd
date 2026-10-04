extends "res://scripts/threats/choir_unit.gd"
## HUSH: the Choir's rank and file. 2.3 m of porcelain over black sinew with a
## needle rifle: slow, precise shots that hit hard. It never charges. Once it
## has seen Eco it works round to her side at long range and waits there for
## a clean shot, so standing still behind one piece of cover gets you flanked.

const NEEDLE := Color(0.6, 0.97, 1.0, 0.95)
const RIFLE_MUZZLE := Vector3(0.78, 0.89, -1.12)

## Degrees round the pilot it tries to stand at, from straight in front of her
## cover (it picks left or right once alerted).
@export var flank_angle := 70.0

var _flank_side := 1.0


func _init() -> void:
	model_name = "hush"
	body_radius = 0.38
	body_height = 2.3
	head_y = 1.95
	max_health = 90.0
	move_speed = 3.2
	sight_range = 48.0
	preferred_range = 22.0
	fire_interval = 2.6
	windup = 0.9
	damage = 22.0
	base_hit_chance = 0.8
	speed_dodge = 0.05
	range_dodge = 0.004
	view_cone = 55.0
	notice_rate_near = 2.4


func alert(callout := true) -> void:
	if not alerted:
		_flank_side = 1.0 if rng.randf() < 0.5 else -1.0
	super(callout)


## Circles to a spot off to the pilot's side at long range and holds there.
func _movement(dir: Vector3, dist: float, _delta: float) -> Vector3:
	var away := -dir  # from the pilot towards this Hush
	var spot := target.global_position + away.rotated(Vector3.UP, deg_to_rad(flank_angle) * _flank_side) * preferred_range
	var to := spot - global_position
	to.y = 0.0
	if to.length() < 1.5:
		return Vector3.ZERO  # in place: wait for the shot
	var step := to.normalized()
	if dist < preferred_range * 0.5:
		step = (step + away).normalized()  # too close: open the distance first
	return step * (0.8 if has_sight else 1.0)


func _shoot() -> void:
	var from := global_transform * RIFLE_MUZZLE
	var chest := target.global_position + Vector3.UP * 1.1
	var end := chest
	if rng.randf() < hit_chance():
		target.take_damage(damage, global_position)
	else:
		var dir := (chest - from).normalized()
		var side := dir.cross(Vector3.UP).normalized()
		var miss := side * rng.randf_range(0.5, 1.1) * (1.0 if rng.randf() < 0.5 else -1.0)
		end = from + ((chest + miss) - from).normalized() * (from.distance_to(chest) + 20.0)
		var query := PhysicsRayQueryParameters3D.create(from, end)
		query.exclude = [get_rid(), target.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			end = hit.position
	FX.tracer(get_parent(), from, end, NEEDLE, 0.012, 0.22)
	FX.spark(get_parent(), from, CYAN, 0.08, 0.08)
	SFX.play_at(get_parent(), from, "choir_needle", -2.0, SFX.vary(0.06))
