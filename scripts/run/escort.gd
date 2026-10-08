extends Node
## Getting someone out on foot (Level 2: Ophelia, once she's out of her cell).
## She walks the navmesh a few steps behind Eco, crouches when Eco crouches
## (or when there's shooting close by), runs to catch up when she falls
## behind, and holds where she's told: [F] next to her says wait here or come
## on (run_manager). Grunts can spot her the way they spot Eco (their cone,
## range and line of sight, slower when she's low); one that does is alerted
## to the pair of them. Her moves are her poses (build_poses.py move_*).

const Nav := preload("res://scripts/run/procgen/nav.gd")
const NpcIdles := preload("res://scripts/hub/npc_idles.gd")

## She keeps about this far behind Eco (m).
const FOLLOW := 2.4
## Past this she runs to catch up.
const CATCH_UP := 8.0
## Past this and out of Eco's sight, she finds her own way up to her.
const WARP := 40.0
const WALK_SPEED := 2.2
const CREEP_SPEED := 3.0
const RUN_SPEED := 7.4
## Metres each move covers per second at animation speed 1.
const RATES := {"move_walk": 1.08, "move_crouch_walk": 1.0, "move_run": 4.9}
const REPATH := 0.35
## How much slower grunts notice her than Eco (she keeps low and quiet).
const NOTICE := 0.6
## Shooting within this range makes her keep her head down.
const DANGER_RANGE := 22.0
const TALK_RANGE := 2.6

signal spotted(grunt: Node)

var npc: Node3D
var pilot: CharacterBody3D
var waiting := false
var crouched := false
var speed := 0.0
var _path := PackedVector3Array()
var _i := 0
var _repath := 0.0
var _anim := ""


func _ready() -> void:
	if npc != null:
		npc.posed = true  # she turns herself (no hub head-turning)
		_play("idle")


func in_reach(pos: Vector3) -> bool:
	return npc != null and npc.global_position.distance_to(pos) < TALK_RANGE


func toggle_wait() -> void:
	waiting = not waiting
	_path = PackedVector3Array()


func _physics_process(delta: float) -> void:
	if npc == null or pilot == null or not is_instance_valid(npc):
		return
	var here := npc.global_position
	var to := pilot.global_position - here
	var dist := Vector2(to.x, to.z).length()
	crouched = waiting or pilot.crouching or _danger()
	speed = 0.0
	if dist > WARP and not _on_screen(here):
		_warp_behind()
		return
	if not waiting and dist > FOLLOW:
		_repath -= delta
		if _repath <= 0.0 or _i >= _path.size():
			_repath = REPATH
			_path = Nav.path(npc.get_world_3d(), here, pilot.global_position)
			_i = 1
			# No way round on the navmesh (the cell floor was baked behind its
			# screen, Eco up on a roof): straight for her.
			if _path.size() < 2 or _path[-1].distance_to(pilot.global_position) > 2.5:
				_path = PackedVector3Array()
		var goal := pilot.global_position
		if _i < _path.size():
			goal = _path[_i]
		if dist > CATCH_UP:
			speed = RUN_SPEED if not crouched else CREEP_SPEED * 1.3
		elif crouched:
			speed = CREEP_SPEED
		else:
			speed = clampf(pilot.horizontal_speed(), WALK_SPEED, RUN_SPEED)
		var step := goal - here
		step.y = 0.0
		var d := step.length()
		if d < 0.3:
			_i += 1
		else:
			var move := step / d * minf(speed * delta, d)
			npc.global_position = here + move
			_face(atan2(-step.x, -step.z), delta, 10.0)
		_snap()
	else:
		_face(atan2(-to.x, -to.z), delta, 3.0)
	_animate()
	_watched(delta)


## Turns her body to `yaw`. The model faces -Z at yaw 0 like everything else
## in the zone; hub_npc's own turning is off while she's posed.
func _face(yaw: float, delta: float, rate: float) -> void:
	var g := npc.global_rotation
	g.y = lerp_angle(g.y, yaw, 1.0 - exp(-rate * delta))
	npc.global_rotation = g


func _snap() -> void:
	var p := npc.global_position
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.2, p + Vector3.DOWN * 3.0, 1)
	q.exclude = [pilot.get_rid()]
	var hit := npc.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		p.y = lerpf(p.y, hit["position"].y, 0.5)
		npc.global_position = p


func _animate() -> void:
	var want := "move_crouch" if crouched else "idle"
	if speed > 0.1:
		want = "move_crouch_walk" if crouched else ("move_run" if speed > 4.0 else "move_walk")
	_play(want)
	var anim: AnimationPlayer = npc._anim
	if anim != null:
		anim.speed_scale = speed / RATES[want] if RATES.has(want) else 1.0


func _play(name: String) -> void:
	var anim: AnimationPlayer = npc._anim
	if anim == null or name == _anim:
		return
	NpcIdles._load_poses(npc)
	var full := name if name == "idle" else NpcIdles.LIB + "/" + name
	if anim.has_animation(full):
		anim.play(full, 0.25)
		_anim = name


## Any grunt fighting close by.
func _danger() -> bool:
	for g in npc.get_tree().get_nodes_in_group("enemies"):
		if g.get("alerted") and not g.get("dead") and g.global_position.distance_to(npc.global_position) < DANGER_RANGE:
			return true
	return false


## Grunts that can see her build up detection on her as they would on Eco.
func _watched(delta: float) -> void:
	var at := npc.global_position
	var space := npc.get_world_3d().direct_space_state
	for g in npc.get_tree().get_nodes_in_group("enemies"):
		if not "detection" in g or g.dead or g.alerted or g.passive:
			continue
		var to: Vector3 = at - g.global_position
		var dist := to.length()
		var reach: float = g.sight_range * g.notice_range
		if dist > reach:
			continue
		var flat := Vector3(to.x, 0.0, to.z)
		var angle := rad_to_deg((-g.global_basis.z).angle_to(flat)) if flat.length() > 0.01 else 0.0
		if angle > g.view_cone:
			continue
		var q := PhysicsRayQueryParameters3D.create(g.global_position + g.EYE, at + Vector3.UP * (0.6 if crouched else 1.2), 1 | g.SIGHT_LAYER)
		var skip: Array[RID] = [g.get_rid(), pilot.get_rid()]
		if npc.get("soft_body") != null:
			skip.append(npc.soft_body.get_rid())  # her own body isn't cover
		q.exclude = skip
		if not space.intersect_ray(q).is_empty():
			continue
		var near := 1.0 - dist / reach
		var rate: float = lerpf(g.notice_rate_far, g.notice_rate_near, near * near) * NOTICE
		if crouched:
			rate *= g.crouch_notice
		rate *= 1.0 + clampf(speed / RUN_SPEED, 0.0, 1.0)
		g.detection += rate * delta
		g.last_known = at
		g.since_stimulus = 0.0
		if g.detection >= 1.0:
			spotted.emit(g)


func _on_screen(p: Vector3) -> bool:
	var cam := npc.get_viewport().get_camera_3d()
	return cam != null and cam.is_position_in_frustum(p + Vector3.UP)


## Lost her way round: she turns up on the navmesh a few metres behind Eco.
func _warp_behind() -> void:
	var back := pilot.global_basis.z
	back.y = 0.0
	back = back.normalized() if back.length() > 0.01 else Vector3.BACK
	var want := pilot.global_position + back * 4.0
	var map := npc.get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) > 0:
		want = NavigationServer3D.map_get_closest_point(map, want)
	npc.global_position = want
	_path = PackedVector3Array()
	_snap()
