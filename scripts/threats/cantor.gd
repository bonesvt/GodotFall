extends "res://scripts/threats/choir_unit.gd"
## CANTOR: the Choir's 3.7 m siege unit. Headless; a crown of organ pipes on
## its hump sings a rising chord before each blast from the emitter in its gut,
## a sonic cone that hurts, throws Eco back and knocks her off walls. The coffin
## shield on its front stops anything fired into it, so get round it: hits in
## the back land harder, and the lit pipes up top are its weak spot.

## Sonic cone: half-angle in degrees and reach in metres.
@export var cone := 24.0
@export var cone_range := 24.0
@export var blast_damage := 28.0
@export var knockback := 15.0
## Hits from behind deal this much more.
@export var back_mult := 1.6

const EMITTER := Vector3(0, 1.78, -0.4)


func _init() -> void:
	model_name = "cantor"
	body_radius = 0.75
	body_height = 3.4
	head_y = 3.05  # the pipes
	max_health = 420.0
	move_speed = 2.0
	sight_range = 42.0
	preferred_range = 13.0
	fire_interval = 4.0
	windup = 1.4
	damage = blast_damage
	view_cone = 60.0
	callout_range = 24.0


## Lumbers in to blast range, no strafing.
func _movement(dir: Vector3, dist: float, _delta: float) -> Vector3:
	if dist > preferred_range or not has_sight:
		return dir * 0.9
	if dist < 6.0:
		return -dir * 0.5
	return Vector3.ZERO


## The shield takes anything that hits it from the front.
func take_damage(amount: float, pos: Vector3, head := false) -> bool:
	if dead:
		return false
	var local := global_basis.inverse() * (pos - global_position)
	if local.z < -0.35 and local.y < 2.9:
		hurt_timer = 0.03
		alert()
		FX.spark(get_parent(), pos, Color(1.0, 0.85, 0.5), 0.15, 0.08)
		SFX.play_at(get_parent(), pos, "ricochet", -6.0, SFX.vary(0.1))
		return false
	if local.z > 0.2:
		amount *= back_mult
	return super(amount, pos, head)


func _attack() -> void:
	var from := global_transform * EMITTER
	var fwd := -global_basis.z
	FX.shock_ring(get_parent(), from + fwd * 0.4, fwd, CYAN, 0.6, 0.25)
	FX.blast(get_parent(), from + fwd * 3.0, Color(0.7, 0.95, 1.0, 0.5), 2.5, 0.35)
	SFX.play_at(get_parent(), from, "cantor_blast", 2.0, SFX.vary(0.04))
	var to := target.global_position + Vector3.UP - from
	if to.length() > cone_range or rad_to_deg(fwd.angle_to(to)) > cone:
		return
	var query := PhysicsRayQueryParameters3D.create(from, target.global_position + Vector3.UP, 1)
	query.exclude = [get_rid(), target.get_rid()]
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		return  # behind something solid
	var falloff := 1.0 - 0.5 * to.length() / cone_range
	target.take_damage(blast_damage * falloff, global_position)
	push(target, to.normalized(), knockback * falloff)


## Throws the pilot along `dir`, off any wall she's running on.
static func push(pilot: CharacterBody3D, dir: Vector3, strength: float) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z).normalized()
	pilot.velocity = flat * strength + Vector3.UP * strength * 0.35
	if pilot.get("state") == Pilot.State.WALLRUN and pilot.has_method("_leave_wall"):
		pilot._leave_wall(0.5)
	elif pilot.get("state") == Pilot.State.GROUND:
		pilot.state = Pilot.State.AIR
