extends Node3D
## Starter sidearm: a weak semi-auto pistol that rewards accuracy.
## Low body damage, a big headshot multiplier, damage falloff with range,
## and bloom that punishes spamming. Shooting during a wallrun or slide
## is as accurate as standing still, so good movement keeps you accurate.
##
## Personality: this is Eco's late father's smart pistol, auto-lock long dead,
## kept alive with tape and know-how. It kicks hard and rings like bent metal,
## the dead lock module spits sparks (more as the mag runs dry) and still tries
## to lock onto enemies before throwing an error, and every reload ends with
## Eco smacking the slide to get it running again. None of this changes the
## numbers above; it is all feel.

const Pilot := preload("res://scripts/player.gd")
const FX := preload("res://scripts/fx.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")
const SFX := preload("res://scripts/sfx.gd")

## Emitted on every shot that hits an enemy: "body", "head" or "kill".
signal hit_confirmed(kind: String)

@export_group("Damage")
@export var damage := 20.0
@export var headshot_multiplier := 2.25
## Full damage up to this distance (m)...
@export var falloff_start := 15.0
## ...dropping linearly to falloff_min of full damage at this distance.
@export var falloff_end := 35.0
@export var falloff_min := 0.6
@export var max_range := 150.0

@export_group("Handling")
## Semi-auto: one click, one shot. Minimum seconds between shots.
@export var fire_interval := 0.16
## A click this soon before the gun is ready still fires when it is.
@export var fire_buffer := 0.06
@export var magazine_size := 8
@export var reload_time := 1.5

@export_group("Accuracy (degrees)")
@export var base_spread := 0.25
@export var bloom_per_shot := 1.1
## Bloom starts shrinking this long after the last shot...
@export var bloom_recovery_delay := 0.25
## ...at this many degrees per second. Paced shots stay accurate, spam does not.
@export var bloom_recovery := 6.0
@export var max_bloom := 4.5
## Added at full sprint speed on the ground.
@export var move_spread := 0.9
## Added while airborne or grappling (not while wallrunning or sliding).
@export var air_spread := 1.2
@export var recoil_kick := 1.4
## Share of each kick the camera drifts back down on its own.
@export var recoil_recovery := 0.75

@export_group("Feel")
## Visual-only camera punch per shot (degrees); does not move your aim.
@export var camera_punch := 1.6
## FOV dip per shot, springs back with the movement FOV.
@export var fov_kick := 2.5
## Real seconds the game slows to a crawl on a kill.
@export var hitstop := 0.045
## Chance the dead smart-lock sparks on a shot, full mag to empty mag.
@export var spark_chance := Vector2(0.15, 0.6)

var player: CharacterBody3D
var ammo := 0
var cooldown := 0.0
var buffer_timer := 0.0
var reload_timer := 0.0
var bloom := 0.0
var since_shot := 10.0
var recoil_pending := 0.0
var shots_fired := 0
var rng := RandomNumberGenerator.new()

var viewmodel: Node3D
var muzzle: Node3D
var flash: MeshInstance3D
var flash_timer := 0.0

# Viewmodel springs and sway
var _kick_pos := Vector3.ZERO
var _kick_vel := Vector3.ZERO
var _kick_rot := Vector3.ZERO
var _kick_rot_vel := Vector3.ZERO
var _sway := Vector2.ZERO
var _bob_phase := 0.0
var _last_look := Vector2.ZERO
var _move_pose := Vector3.ZERO  # x roll, y drop, z lift
var _punch := Vector2.ZERO
var _slide_back := 0.0
var _parts := {}  # animated pistol pieces -> rest position
var _reload_events := 0
var _pistol: Node3D

## The enemy the broken smart-lock is currently trying to lock onto, for the HUD.
var lock_target: Node3D
## Seconds spent trying to lock the current target.
var lock_time := 0.0
## 0..1 flicker of the busted lock module (HUD reticle glitches with it).
var glitch := 0.0
var _lock_scan := 0.0
var _lock_beep := 0.0


func _ready() -> void:
	var n: Node = get_parent()
	while n != null and not (n is CharacterBody3D):
		n = n.get_parent()
	player = n
	ammo = magazine_size
	_build_viewmodel()
	if player.has_signal("respawned"):
		player.respawned.connect(refill)


func _physics_process(delta: float) -> void:
	cooldown -= delta
	buffer_timer -= delta
	since_shot += delta
	if since_shot > bloom_recovery_delay:
		bloom = maxf(bloom - bloom_recovery * delta, 0.0)
	_recover_recoil(delta)

	if reload_timer > 0.0:
		reload_timer -= delta
		_reload_choreography()
		if reload_timer <= 0.0:
			ammo = magazine_size
	elif Input.is_action_just_pressed("reload") and ammo < magazine_size:
		start_reload()
	_scan_lock(delta)

	if Input.is_action_just_pressed("fire"):
		buffer_timer = fire_buffer
	if buffer_timer > 0.0 and cooldown <= 0.0 and reload_timer <= 0.0:
		buffer_timer = 0.0
		if ammo > 0:
			fire()
		else:
			SFX.play(self, "dry_click", -4.0, SFX.vary())
			start_reload()


func _process(delta: float) -> void:
	_animate_viewmodel(delta)
	_apply_punch(delta)
	flash_timer -= delta
	flash.visible = flash_timer > 0.0
	glitch = maxf(glitch - delta * 3.0, 0.0)
	if rng.randf() < delta * 0.4:
		glitch = rng.randf_range(0.3, 1.0)  # the old module never quite settles
	if _pistol != null and _pistol.has_method("set_param"):
		# The dead lens flickers when the module glitches or hunts for a lock.
		var hunt := 0.6 if lock_target != null and fmod(lock_time, 0.25) < 0.12 else 0.0
		_pistol.set_param("glow", 1.0 + glitch * 2.5 + hunt, "SensorLens")


## Current cone half-angle in degrees.
func current_spread() -> float:
	var s := base_spread + bloom
	match player.state:
		Pilot.State.GROUND:
			s += move_spread * clampf(player.horizontal_speed() / player.sprint_speed, 0.0, 1.0)
		Pilot.State.AIR, Pilot.State.GRAPPLE:
			s += air_spread
	return s


func fire() -> void:
	ammo -= 1
	shots_fired += 1
	cooldown = fire_interval
	since_shot = 0.0
	var cam: Camera3D = player.camera
	# Aim comes from the head, so the visual camera punch never moves the shot.
	var basis: Basis = player.head.global_basis
	var r := tan(deg_to_rad(current_spread())) * sqrt(rng.randf())
	var a := rng.randf() * TAU
	var dir := (-basis.z + basis.x * cos(a) * r + basis.y * sin(a) * r).normalized()
	var from := cam.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * max_range)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var end: Vector3 = from + dir * max_range
	var fx_parent: Node = player.get_parent()

	if not hit.is_empty():
		end = hit.position
		var target: Object = hit.collider
		if target.has_method("take_damage"):
			var head: bool = target.is_headshot(end)
			var dmg := damage_at(from.distance_to(end)) * (headshot_multiplier if head else 1.0)
			var killed: bool = target.take_damage(dmg, end, head)
			var kind := "kill" if killed else ("head" if head else "body")
			hit_confirmed.emit(kind)
			_hit_fx(fx_parent, end, hit.normal, dir, kind)
		else:
			_impact_fx(fx_parent, end, hit.normal)

	FX.tracer(fx_parent, muzzle.global_position, end, Color(1.0, 0.85, 0.4, 0.9), 0.015, 0.06)
	bloom = minf(bloom + bloom_per_shot, max_bloom)
	var k := deg_to_rad(recoil_kick)
	player.head.rotation.x = clampf(player.head.rotation.x + k, -1.55, 1.55)
	recoil_pending += k * recoil_recovery
	flash_timer = 0.04
	_shot_feel(fx_parent)


## Everything a shot does that you see, hear and feel but that doesn't score.
func _shot_feel(fx_parent: Node) -> void:
	var last := ammo == 0
	SFX.play(self, "pistol_last" if last else "pistol", 0.0, SFX.vary())
	# Viewmodel: snaps back and up, rolls a little to a random side.
	_kick_vel += Vector3(rng.randf_range(-0.15, 0.15), 0.25, 1.6)
	_kick_rot_vel += Vector3(14.0, rng.randf_range(-3.0, 3.0), rng.randf_range(-6.0, 6.0))
	_slide_back = 1.0
	# Camera: a punch that springs back on its own, plus a FOV dip.
	_punch += Vector2(deg_to_rad(camera_punch), deg_to_rad(rng.randf_range(-0.5, 0.5) * camera_punch))
	player.camera.fov -= fov_kick
	# Muzzle: a star that faces you, a puff of smoke and a flash of light.
	FX.star(muzzle, muzzle.global_position, Color(1.0, 0.75, 0.3, 0.95), 0.11, 0.05, 6)
	FX.star(muzzle, muzzle.global_position, Color(1.0, 1.0, 0.85), 0.05, 0.04, 4)
	FX.light(fx_parent, muzzle.global_position, Color(1.0, 0.7, 0.35), 1.6, 5.0, 0.06)
	FX.puff(fx_parent, muzzle.global_position, Color(0.75, 0.72, 0.68, 0.35), 0.03, 0.35, player.velocity * 0.9 + Vector3(0, 0.4, 0))
	var port: Vector3 = viewmodel.global_transform * Vector3(0.03, 0.04, -0.05)
	var right: Vector3 = player.head.global_basis.x
	FX.casing(fx_parent, port, player.velocity + right * 2.2 + Vector3.UP * 2.0)
	# The dead smart-lock module coughs sparks, more often as the mag runs dry.
	var empty_frac := 1.0 - float(ammo) / magazine_size
	if rng.randf() < lerpf(spark_chance.x, spark_chance.y, empty_frac) or last:
		_module_sparks(3 if not last else 6)


func _hit_fx(fx_parent: Node, pos: Vector3, normal: Vector3, dir: Vector3, kind: String) -> void:
	match kind:
		"body":
			FX.star(fx_parent, pos, Color(1.0, 0.85, 0.5), 0.22, 0.06)
			FX.debris(fx_parent, pos, normal, Color(0.42, 0.45, 0.4), 3, 3.0, 0.04, 0.35)
			SFX.play(self, "hit_body", -3.0, SFX.vary(0.1))
		"head":
			FX.star(fx_parent, pos, Color(1.0, 0.8, 0.15), 0.45, 0.09, 8)
			FX.debris(fx_parent, pos, normal + Vector3.UP, Color(0.85, 0.65, 0.2), 5, 4.5, 0.05, 0.45)
			SFX.play(self, "hit_head", -1.0, SFX.vary(0.04))
		"kill":
			FX.star(fx_parent, pos, Color(1.0, 0.3, 0.15), 0.55, 0.1, 8)
			FX.blast(fx_parent, pos, Color(1.0, 0.45, 0.2), 0.9, 0.25)
			FX.debris(fx_parent, pos, dir + Vector3.UP * 0.5, Color(0.4, 0.42, 0.38), 7, 5.0, 0.06, 0.55)
			SFX.play(self, "kill", -1.0)
			_hitstop()


func _impact_fx(fx_parent: Node, pos: Vector3, normal: Vector3) -> void:
	FX.star(fx_parent, pos + normal * 0.02, Color(1.0, 0.9, 0.6), 0.14, 0.05)
	FX.puff(fx_parent, pos + normal * 0.08, Color(0.78, 0.7, 0.58, 0.55), 0.06, 0.45, normal * 0.8)
	FX.debris(fx_parent, pos, normal, Color(0.6, 0.55, 0.48), 3, 3.5, 0.035, 0.4)
	if rng.randf() < 0.3:
		SFX.play_at(fx_parent, pos, "ricochet", -2.0, SFX.vary(0.15))
	else:
		SFX.play_at(fx_parent, pos, "impact", -4.0, SFX.vary(0.15))


func _module_sparks(count: int) -> void:
	var at: Vector3 = viewmodel.global_transform * Vector3(-0.025, 0.035, -0.02)
	for part in ["SensorLens", "SensorHousing"]:
		if _parts.has(part):
			at = _parts[part][0].global_position + player.head.global_basis.y * 0.012
			break
	for i in count:
		FX.star(viewmodel, at + Vector3(rng.randf_range(-0.01, 0.01), rng.randf_range(0.0, 0.02), 0), Color(0.55, 0.85, 1.0), 0.025, 0.08, 4)
	FX.debris(viewmodel, at, Vector3.UP, Color(0.7, 0.9, 1.0), count, 0.6, 0.006, 0.18)
	SFX.play(self, "spark", -9.0, SFX.vary(0.2))
	glitch = 1.0


## A beat of slow motion on a kill, measured in real time.
func _hitstop() -> void:
	if hitstop <= 0.0 or not is_inside_tree():
		return
	Engine.time_scale = 0.05
	await get_tree().create_timer(hitstop, true, false, true).timeout
	Engine.time_scale = 1.0


## The broken smart-lock still searches for targets under the crosshair,
## brackets them for a moment, then errors out. Purely cosmetic.
func _scan_lock(delta: float) -> void:
	_lock_beep -= delta
	_lock_scan -= delta
	if lock_target != null:
		lock_time += delta
		if not is_instance_valid(lock_target) or not lock_target.is_in_group("enemies"):
			lock_target = null
	if _lock_scan > 0.0:
		return
	_lock_scan = 0.1
	var cam: Camera3D = player.camera
	var from := cam.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - player.head.global_basis.z * 60.0)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var found: Node3D = null
	if not hit.is_empty() and hit.collider is Node3D and hit.collider.is_in_group("enemies"):
		found = hit.collider
	if found != lock_target:
		lock_target = found
		lock_time = 0.0
		if found != null and _lock_beep <= 0.0:
			_lock_beep = 1.5
			SFX.play(self, "lock_err", -14.0)


func damage_at(distance: float) -> float:
	var t := clampf((distance - falloff_start) / (falloff_end - falloff_start), 0.0, 1.0)
	return damage * lerpf(1.0, falloff_min, t)


func start_reload() -> void:
	if reload_timer > 0.0 or ammo >= magazine_size:
		return
	reload_timer = reload_time
	_reload_events = 0


func is_reloading() -> bool:
	return reload_timer > 0.0


func refill() -> void:
	ammo = magazine_size
	reload_timer = 0.0
	bloom = 0.0
	recoil_pending = 0.0
	_set_part_visible("MagBase", true)


## 0 at the start of a reload, 1 at the end.
func reload_progress() -> float:
	return 1.0 - reload_timer / reload_time if is_reloading() else 0.0


## Mag out, fresh mag in, then Eco smacks the slide to wake the old gun up.
func _reload_choreography() -> void:
	var p := reload_progress()
	var fx_parent: Node = player.get_parent()
	if _reload_events == 0 and p >= 0.14:
		_reload_events = 1
		SFX.play(self, "reload_out", -3.0, SFX.vary())
		var mag_at: Vector3 = viewmodel.global_transform * Vector3(0.0, -0.09, 0.06)
		FX.debris(fx_parent, mag_at, Vector3.DOWN, Color(0.28, 0.28, 0.3), 1, 0.5, 0.05, 0.5)
		_set_part_visible("MagBase", false)
	elif _reload_events == 1 and p >= 0.52:
		_reload_events = 2
		SFX.play(self, "reload_in", -2.0, SFX.vary())
		_set_part_visible("MagBase", true)
		_kick_vel += Vector3(0.0, 0.5, 0.0)
	elif _reload_events == 2 and p >= 0.76:
		_reload_events = 3
		SFX.play(self, "whack", 0.0, SFX.vary(0.05))
		_kick_rot_vel += Vector3(-8.0, 0.0, 22.0)
		_kick_vel += Vector3(-0.4, -0.6, 0.0)
		_module_sparks(5)


func _recover_recoil(delta: float) -> void:
	if recoil_pending <= 0.0:
		return
	var step := minf(recoil_pending, deg_to_rad(12.0) * delta)
	recoil_pending -= step
	player.head.rotation.x = clampf(player.head.rotation.x - step, -1.55, 1.55)


func _build_viewmodel() -> void:
	viewmodel = Node3D.new()
	add_child(viewmodel)
	var pistol := Art.model("pistol")
	viewmodel.add_child(pistol)
	for mi in pistol.find_children("*", "GeometryInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	muzzle = pistol.get_node("Muzzle")
	# Pieces are looked up by name so this works with the P-08 and with the
	# smart pistol model (Upper/Nose/Stripe slide, SensorLens lock module).
	_pistol = pistol
	for part in ["Slide", "SlideTop", "Upper", "Nose", "Stripe", "Hammer", "MagBase", "SensorLens", "SensorHousing"]:
		var node := pistol.get_node_or_null(part) as Node3D
		if node != null:
			_parts[part] = [node, node.position, node.rotation]

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.8, 0.35)
	var sphere := SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.1
	sphere.material = mat
	flash = MeshInstance3D.new()
	flash.mesh = sphere
	flash.visible = false
	muzzle.add_child(flash)


func _set_part_visible(part: String, on: bool) -> void:
	if _parts.has(part):
		_parts[part][0].visible = on


## Springs, sway, bob, movement poses, reload pose and the cycling slide.
func _animate_viewmodel(delta: float) -> void:
	delta = minf(delta, 0.05)
	# Springs (stiff, a little underdamped so the gun settles with a wobble).
	_kick_vel += (-_kick_pos * 260.0 - _kick_vel * 22.0) * delta
	_kick_pos += _kick_vel * delta
	_kick_rot_vel += (-_kick_rot * 240.0 - _kick_rot_vel * 20.0) * delta
	_kick_rot += _kick_rot_vel * delta

	# Sway: the gun lags behind where you look.
	var look := Vector2(player.rotation.y, player.head.rotation.x)
	var dlook := (look - _last_look) / maxf(delta, 0.001)
	_last_look = look
	_sway = _sway.lerp(dlook.clamp(Vector2(-8, -8), Vector2(8, 8)), 1.0 - exp(-10.0 * delta))

	# Movement poses: bob while running, cant while sliding, lean off walls,
	# float up a touch in the air.
	var target_pose := Vector3.ZERO
	var speed: float = player.horizontal_speed()
	match player.state:
		Pilot.State.GROUND:
			_bob_phase += delta * (4.0 + speed * 0.75)
		Pilot.State.SLIDE:
			target_pose = Vector3(0.45, 0.03, 0.0)
		Pilot.State.WALLRUN:
			target_pose = Vector3(-signf(player.wall_normal.dot(player.global_basis.x)) * 0.25, 0.0, 0.0)
		_:
			target_pose = Vector3(0.0, 0.0, clampf(-player.velocity.y * 0.003, -0.03, 0.03))
	_move_pose = _move_pose.lerp(target_pose, 1.0 - exp(-8.0 * delta))
	var run := clampf(speed / player.sprint_speed, 0.0, 1.0) if player.state == Pilot.State.GROUND else 0.0
	var bob := Vector3(cos(_bob_phase) * 0.012, -absf(sin(_bob_phase)) * 0.014, 0.0) * run

	# Reload pose: tip the gun in, hold, bring it back.
	var p := reload_progress()
	var r := smoothstep(0.0, 0.14, p) * (1.0 - smoothstep(0.86, 1.0, p))

	var pos := Vector3(0.22, -0.2, -0.42)
	pos += Vector3(-_sway.x * 0.006, _sway.y * 0.006, 0.0)
	pos += bob + Vector3(0.0, -_move_pose.y + _move_pose.z, 0.0)
	pos += Vector3(_kick_pos.x * 0.02, _kick_pos.y * 0.02, _kick_pos.z * 0.04)
	pos += Vector3(-0.06, -0.08, 0.04) * r
	viewmodel.position = pos
	viewmodel.rotation = Vector3(
		deg_to_rad(_kick_rot.x) + _sway.y * 0.02 + 0.35 * r,
		deg_to_rad(_kick_rot.y) + _sway.x * 0.025 - 0.25 * r,
		deg_to_rad(_kick_rot.z) + _move_pose.x + _sway.x * 0.02 + 0.7 * r)

	# Slide cycles back on each shot and locks open on an empty mag.
	_slide_back = maxf(_slide_back - delta * 14.0, 0.0)
	var slide := 1.0 if ammo == 0 and not is_reloading() else _slide_back
	for part in ["Slide", "SlideTop", "Upper", "Nose", "Stripe"]:
		if _parts.has(part):
			_parts[part][0].position = _parts[part][1] + Vector3(0, 0, 0.035 * slide)
	if _parts.has("Hammer"):
		_parts["Hammer"][0].rotation = _parts["Hammer"][2] + Vector3(0.9 * slide, 0, 0)


## Camera punch: a visual kick on the camera that springs back to zero.
func _apply_punch(delta: float) -> void:
	_punch = _punch.lerp(Vector2.ZERO, 1.0 - exp(-16.0 * delta))
	player.camera.rotation.x = _punch.x
	player.camera.rotation.y = _punch.y
