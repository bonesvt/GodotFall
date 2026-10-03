extends Node3D
## Starter sidearm: a weak semi-auto pistol that rewards accuracy.
## Low body damage, a big headshot multiplier, damage falloff with range,
## and bloom that punishes spamming. Shooting during a wallrun or slide
## is as accurate as standing still, so good movement keeps you accurate.
##
## Personality: this is Eco's late father's smart pistol. Its auto-tracking
## screen is smashed, so she aims with the holo sight like anyone else. The
## ammo screen on the back of the slide counts her rounds, the broken tracker
## spits sparks (more as the mag runs dry) and still tries to lock onto
## enemies before throwing an error.
##
## Eco has been building on it ever since, and it shows off: an integrated
## suppressor whose vents glow hotter the faster she shoots, a strip of LEDs
## on the slide that doubles as an ammo bar and races toward the muzzle on
## every shot, a holo sight that pulses, her father's dog tag swinging off
## the rail, and a twirl on every reload. None of this changes the numbers
## above; it is all feel.
##
## Smart rounds: the gunsmith's upgrades rebuild the lock one eighth of the mag
## at a time (`smart_fraction`). Those rounds sit at the top of every fresh mag,
## so they fire first. While one is chambered the lock works again: it picks the
## grunt nearest the crosshair inside LOCK_CONE, closes in LOCK_TIME, and the
## round flies to its chest whatever the spread. Never its head: headshots are
## still Eco's own work. With no smart rounds left the module is the broken
## thing it always was.
##
## The hub's workbenches (scripts/hub/armory.gd) can swap this for another
## sidearm, upgrade it and bolt attachments on: equip() takes the profile they
## build and rebuilds the stats and the viewmodel. Without one the defaults
## below are the smart pistol, untouched.

const Pilot := preload("res://scripts/player.gd")
const FX := preload("res://scripts/fx.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")
const SFX := preload("res://scripts/sfx.gd")

## Emitted on every shot that hits an enemy: "body", "head" or "kill".
signal hit_confirmed(kind: String)
## Emitted when an inspect starts, with what Eco says about the gun.
signal inspected(line: String)

## Inspect: Eco twirls her father's pistol, turns it over to show the smashed
## tracking screen, taps it (it sparks and errors), checks the holo sight,
## then twirls it back into her grip.
## Keyframes: [seconds, position offset (m), rotation offset (degrees x/y/z)].
const INSPECT_KEYS := [
	[0.0, Vector3.ZERO, Vector3.ZERO],
	[0.4, Vector3(-0.15, 0.08, 0.15), Vector3(10, 58, 22)],
	[1.15, Vector3(-0.16, 0.09, 0.15), Vector3(14, 64, 26)],
	[1.5, Vector3(-0.05, 0.05, 0.05), Vector3(-4, -16, -60)],
	[2.15, Vector3(-0.05, 0.06, 0.05), Vector3(-6, -20, -64)],
	[2.45, Vector3(-0.07, 0.06, 0.1), Vector3(24, -8, -8)],
	[2.9, Vector3(-0.07, 0.07, 0.1), Vector3(26, -5, -6)],
	[3.3, Vector3.ZERO, Vector3.ZERO],
]
## When in the inspect Eco taps the dead sensor.
const INSPECT_TAP := 0.95
## The inspect's twirls: [start time, direction].
const INSPECT_TWIRLS := [[0.0, -1.0], [2.9, 1.0]]
## Seconds a full twirl of the gun round Eco's trigger finger takes.
const TWIRL_TIME := 0.42
## The point the gun spins round, in the gun's own space (her trigger finger).
const TWIRL_PIVOT := Vector3(0.0, -0.035, -0.004)
## Reload beats, as a share of the reload: mag out, mag in, twirl, screen boots.
const RELOAD_BEATS := [0.12, 0.42, 0.5, 0.82]
const LED_COUNT := 6
const LED_CYAN := Color(0.3, 0.95, 1.0)
const LED_AMBER := Color(1.0, 0.6, 0.15)
const LED_RED := Color(1.0, 0.18, 0.12)
## Where attachments mount, in the gun's own space: the grip's centre and angle
## (every gun shares the smart pistol's grip so Eco's glove fits), and how far
## down the grip each gun's magazine ends.
const GRIP_XFORM := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-16.0)), Vector3(0.0, -0.088, 0.072))
const MAG_BOTTOM := {"pistol": -0.07, "rivet_cannon": -0.07, "machine_pistol": -0.11}
## How much further down the smart pistol's mag reaches from upgrade tier 3.
const PISTOL_LONG_MAG := -0.03
const ATTACHMENT_MODELS := {
	"long_barrel": preload("res://assets/models/sidearms/att_muzzle_long.glb"),
	"compensator": preload("res://assets/models/sidearms/att_muzzle_comp.glb"),
	"extended": preload("res://assets/models/sidearms/att_mag_ext.glb"),
	"speed": preload("res://assets/models/sidearms/att_mag_speed.glb"),
	"wrap": preload("res://assets/models/sidearms/att_grip_wrap.glb"),
	"skeleton": preload("res://assets/models/sidearms/att_grip_skeleton.glb"),
}
## Paint slots a finish recolours, by material file name.
const FINISH_SLOTS := {"pistol_shell": "shell", "pistol_blue": "blue", "pistol_stripe": "stripe"}
const INSPECT_LINES := [
	"Dad's. The lock-on died with him.",
	"Tracker screen's smashed. Holo sight it is.",
	"Tape's holding. Mostly.",
	"Still pulls a hair left. I'll fix it. Someday.",
	"Smart pistol. Not so smart anymore.",
]

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
@export var base_spread := 0.17
@export var bloom_per_shot := 0.75
## Bloom starts shrinking this long after the last shot...
@export var bloom_recovery_delay := 0.25
## ...at this many degrees per second. Paced shots stay accurate, spam does not.
@export var bloom_recovery := 6.0
@export var max_bloom := 3.0
## Added at full sprint speed on the ground.
@export var move_spread := 0.6
## Added while airborne or grappling (not while wallrunning or sliding).
@export var air_spread := 0.8
@export var recoil_kick := 1.4
## Share of each kick the camera drifts back down on its own.
@export var recoil_recovery := 0.75

@export_group("Upgrades")
## Which smart pistol model to show: 0 is Dad's broken pistol, 1-5 are Eco's
## upgrades (tools/pistol/build_pistol.py --tier). Looks only; set_tier()
## swaps it at runtime.
@export_range(0, 5) var tier := 0

@export_group("Feel")
## Visual-only camera punch per shot (degrees); does not move your aim.
@export var camera_punch := 1.6
## FOV dip per shot, springs back with the movement FOV.
@export var fov_kick := 2.5
## Real seconds the game slows to a crawl on a kill.
@export var hitstop := 0.045
## Chance the dead smart-lock sparks on a shot, full mag to empty mag.
@export var spark_chance := Vector2(0.15, 0.6)

## Which gun this is (armory.gd WEAPONS id), and how it behaves.
var weapon_id := "smart_pistol"
var model_id := "pistol"
## The dead smart-lock module: lock brackets, errors and sparks.
var smart := true
## Hold to fire instead of one click per shot.
var automatic := false
var suppressed := true
var shot_sound := "pistol"
var shot_sound_last := "pistol_last"
var tracer_color := Color(0.75, 0.97, 1.0, 0.85)
var inspect_lines: Array = INSPECT_LINES
## slot -> attachment id, and the finish's colours (empty: as modelled).
var attachments := {}
var finish := {}

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
var inspect_time := -1.0
var _inspect_tapped := false
var _inspect_line := -1
var _pistol: Node3D
var _ammo_label: Label3D
var _gun: Node3D  # the gun alone, without Eco's arm: this is what twirls
var _gun_rest := Transform3D.IDENTITY
var _twirl := -1.0  # seconds into the current twirl, or -1
var _twirl_dir := -1.0
var _leds: Array[GeometryInstance3D] = []
var _vents: GeometryInstance3D
var _holo: GeometryInstance3D
## 0..1 how hot the suppressor is; every shot adds some, it cools off quickly.
var heat := 0.0
var _since_fx := 10.0  # seconds since the last shot, for the LED race
var _holo_pulse := 0.0
var _ammo_pop := 0.0
var _boot := -1.0  # seconds into the ammo screen booting after a reload
# Dog tag pendulum (angles in radians around the charm pivot's x and z)
var _charm: Node3D
var _drum: Node3D
var _drum_turn := 0.0
var _hammer: Node3D
var _charm_angle := Vector2.ZERO
var _charm_vel := Vector2.ZERO
var _charm_last_pos := Vector3.ZERO
var _charm_last_vel := Vector3.ZERO

## Smart rounds: what share of a fresh mag is smart, and how many are left at
## the top of this one.
var smart_fraction := 0.0
var smart_left := 0

## Gun-specific upgrades (armory.gd UPGRADES), 0 on a stock gun.
## Heavy revolver: bodies a round goes through after the first, and how long
## a hit knocks a grunt off their aim (seconds).
var pierce := 0.0
var stagger := 0.0
## Auto handgun: extra damage per hit in a row (up to STREAK_MAX), lost on a
## miss or a pause in fire.
var streak_bonus := 0.0
var streak := 0
const STREAK_MAX := 10
const STREAK_DROP := 0.45
## Damage kept by each body a punch-through round goes on into.
const PIERCE_KEEP := 0.75
const STREAK_TRACER := Color(1.0, 0.45, 0.15, 0.95)
## The working lock: cone half-angle (degrees), range (m), seconds to lock.
const LOCK_CONE := 11.0
const LOCK_RANGE := 40.0
const LOCK_TIME := 0.3
const SMART_TRACER := Color(1.0, 0.45, 0.75, 0.95)
## What rounds and the lock can hit: everything but the foliage that only
## blocks grunts' sight (forest_kit.gd SIGHT_LAYER), which you walk through.
const SHOT_MASK := 0xFFFFFFFF & ~16

## The enemy the broken smart-lock is currently trying to lock onto, for the HUD.
## True while the knife has Eco's hands: the pistol drops out of the way and
## can't fire.
var holstered := false
var _holster := 0.0

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


## Becomes the gun a workbench profile describes (armory.gd weapon_profile()):
## stats by property name, behaviour flags, model, attachments and finish.
## Reloads it full.
func equip(profile: Dictionary) -> void:
	weapon_id = profile.get("id", weapon_id)
	model_id = profile.get("model", model_id)
	smart = profile.get("smart", smart)
	automatic = profile.get("automatic", automatic)
	suppressed = profile.get("suppressed", suppressed)
	shot_sound = profile.get("sound", shot_sound)
	shot_sound_last = profile.get("sound_last", shot_sound_last)
	tracer_color = profile.get("tracer", tracer_color)
	inspect_lines = profile.get("lines", inspect_lines)
	attachments = profile.get("attachments", {})
	finish = profile.get("finish", {})
	tier = profile.get("tier", 0)
	var stats: Dictionary = profile.get("stats", {})
	for key in stats:
		set(key, int(stats[key]) if key == "magazine_size" else float(stats[key]))
	if not smart:
		lock_target = null
		glitch = 0.0
	streak = 0
	if viewmodel != null:
		viewmodel.free()
		viewmodel = null
		_build_viewmodel()
	refill()


func _physics_process(delta: float) -> void:
	cooldown -= delta
	buffer_timer -= delta
	since_shot += delta
	if since_shot > STREAK_DROP:
		streak = 0
	if since_shot > bloom_recovery_delay:
		bloom = maxf(bloom - bloom_recovery * delta, 0.0)
	_recover_recoil(delta)

	if reload_timer > 0.0:
		reload_timer -= delta
		_reload_choreography()
		if reload_timer <= 0.0:
			ammo = magazine_size
			smart_left = smart_capacity()
	elif Input.is_action_just_pressed("reload") and ammo < magazine_size:
		start_reload()
	elif Input.is_action_just_pressed("inspect") and not is_inspecting() and not holstered:
		inspect()
	_update_inspect(delta)
	if smart:
		_scan_lock(delta)

	if Input.is_action_just_pressed("fire") or (automatic and Input.is_action_pressed("fire") and ammo > 0):
		buffer_timer = fire_buffer
		stop_inspect()  # shooting always wins over showing off
	if buffer_timer > 0.0 and cooldown <= 0.0 and reload_timer <= 0.0 and not holstered:
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
	if smart and rng.randf() < delta * 0.4:
		glitch = rng.randf_range(0.3, 1.0)  # the old module never quite settles
	if _pistol != null and _pistol.has_method("set_param"):
		# The smashed tracker screen flickers when the module glitches or
		# hunts for a lock it will never get.
		var hunt := 3.0 if lock_target != null and fmod(lock_time, 0.25) < 0.12 else 0.0
		_pistol.set_param("glow", 1.0 + glitch * 4.0 + hunt, "TrackerGlass")
	_update_ammo_screen()
	_update_lights(delta)
	_update_twirl(delta)
	_swing_charm(delta)


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
	var homing := is_locked()
	var smart_shot := smart_left > 0
	ammo -= 1
	if smart_shot:
		smart_left -= 1
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
	if homing:
		# A smart round with a lock flies to the target's chest, spread or not.
		dir = (lock_point(lock_target) - from).normalized()
	var fx_parent: Node = player.get_parent()
	var end := _trace_shot(from, dir, fx_parent)
	# Heard after the round lands, so the first shot still catches its target unaware.
	get_tree().call_group("enemies", "hear_gunshot", player.global_position)

	# In third person the view-model is hidden: tracers leave Eco's own gun.
	var tracer_from: Vector3 = muzzle.global_position
	if player.get("third_person") and player.has_node("ViewCam"):
		tracer_from = player.get_node("ViewCam").muzzle_position()
	if smart_shot:
		FX.tracer(fx_parent, tracer_from, end, SMART_TRACER, 0.016, 0.09)
		if homing:
			FX.star(fx_parent, end, Color(1.0, 0.5, 0.8), 0.3, 0.08, 6)
	else:
		# A hot streak runs the tracer from its own colour to orange.
		var heat_t := float(streak) / STREAK_MAX if streak_bonus > 0.0 else 0.0
		FX.tracer(fx_parent, tracer_from, end, tracer_color.lerp(STREAK_TRACER, heat_t), 0.012 + 0.008 * heat_t, 0.06)
	bloom = minf(bloom + bloom_per_shot, max_bloom)
	var k := deg_to_rad(recoil_kick)
	player.head.rotation.x = clampf(player.head.rotation.x + k, -1.55, 1.55)
	recoil_pending += k * recoil_recovery
	flash_timer = 0.04
	_shot_feel(fx_parent)


## Casts one round along `dir` and deals its damage. A punch-through round
## goes on through each body it hits, `pierce` times, losing a quarter of its
## damage each time. Returns where it stopped (for the tracer).
func _trace_shot(from: Vector3, dir: Vector3, fx_parent: Node) -> Vector3:
	var exclude: Array[RID] = [player.get_rid()]
	var start := from
	var mult := 1.0 + streak_bonus * streak
	var bodies := 0
	var landed := false
	while true:
		var query := PhysicsRayQueryParameters3D.create(start, from + dir * max_range, SHOT_MASK)
		query.exclude = exclude
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			break
		var end: Vector3 = hit.position
		var target: Object = hit.collider
		if not target.has_method("take_damage"):
			_impact_fx(fx_parent, end, hit.normal)
			_end_streak(landed)
			return end
		var head: bool = target.is_headshot(end)
		var dmg := damage_at(from.distance_to(end)) * (headshot_multiplier if head else 1.0) * mult
		var killed: bool = target.take_damage(dmg, end, head)
		if stagger > 0.0 and not killed and target.has_method("stagger"):
			target.stagger(stagger)
		var kind := "kill" if killed else ("head" if head else "body")
		hit_confirmed.emit(kind)
		_hit_fx(fx_parent, end, hit.normal, dir, kind)
		landed = true
		bodies += 1
		if bodies > int(pierce):
			_end_streak(landed)
			return end
		# On through: past this body, a bit weaker.
		exclude.append(hit.rid)
		start = end
		mult *= PIERCE_KEEP
		FX.puff(fx_parent, end + dir * 0.3, Color(1.0, 0.8, 0.5, 0.6), 0.25)
	_end_streak(landed)
	return from + dir * max_range


## A hit carries the streak on; a miss ends it.
func _end_streak(landed: bool) -> void:
	streak = mini(streak + 1, STREAK_MAX) if landed else 0


## Everything a shot does that you see, hear and feel but that doesn't score.
func _shot_feel(fx_parent: Node) -> void:
	var last := ammo == 0
	SFX.play(self, shot_sound_last if last else shot_sound, 1.0, SFX.vary(0.04))
	# Viewmodel: snaps back and up, rolls a little to a random side.
	_kick_vel += Vector3(rng.randf_range(-0.15, 0.15), 0.25, 1.6)
	_kick_rot_vel += Vector3(14.0, rng.randf_range(-3.0, 3.0), rng.randf_range(-6.0, 6.0))
	_slide_back = 1.0
	# Camera: a punch that springs back on its own, plus a FOV dip.
	_punch += Vector2(deg_to_rad(camera_punch), deg_to_rad(rng.randf_range(-0.5, 0.5) * camera_punch))
	player.camera.fov -= fov_kick
	# Muzzle: suppressed, so no fireball. A small white star, a ring of light
	# snapping out round the barrel, and gas curling out of the hot vents.
	var forward: Vector3 = -muzzle.global_basis.z
	if not suppressed:
		# An open muzzle: a proper fireball and a flash that lights the room.
		FX.star(muzzle, muzzle.global_position, Color(1.0, 0.75, 0.35, 0.95), 0.09, 0.05, 8)
		FX.light(fx_parent, muzzle.global_position, Color(1.0, 0.7, 0.35), 2.0, 5.0, 0.05)
	if _drum != null:
		_drum_turn += TAU / 6.0
	if _hammer != null:
		_hammer.rotation.x = deg_to_rad(-40.0)
	FX.star(muzzle, muzzle.global_position, Color(0.85, 0.97, 1.0, 0.9), 0.045, 0.04, 6)
	FX.shock_ring(fx_parent, muzzle.global_position + forward * 0.01, forward, Color(0.6, 0.95, 1.0, 0.9), 0.06, 0.1)
	FX.light(fx_parent, muzzle.global_position, Color(0.55, 0.9, 1.0), 0.9, 3.0, 0.05)
	FX.puff(fx_parent, muzzle.global_position, Color(0.8, 0.85, 0.9, 0.22), 0.02, 0.3, player.velocity * 0.9 + forward * 0.4)
	if _vents != null:
		for i in 2:
			var at := _vents.global_position + forward * rng.randf_range(-0.03, 0.03)
			FX.puff(fx_parent, at, Color(0.9, 0.9, 0.92, 0.18 + heat * 0.2), 0.008, 0.45, player.velocity * 0.9 + Vector3(0, 0.25, 0))
	heat = minf(heat + 0.22, 1.0)
	_since_fx = 0.0
	_holo_pulse = 1.0
	_ammo_pop = 1.0
	var port: Vector3 = viewmodel.global_transform * Vector3(0.03, 0.04, -0.05)
	var right: Vector3 = player.head.global_basis.x
	FX.casing(fx_parent, port, player.velocity + right * 2.2 + Vector3.UP * 2.0)
	# The dead smart-lock module coughs sparks, more often as the mag runs dry.
	var empty_frac := 1.0 - float(ammo) / magazine_size
	if smart and smart_left == 0 and (rng.randf() < lerpf(spark_chance.x, spark_chance.y, empty_frac) or last):
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
	if _parts.has("TrackerImpact"):
		at = _parts["TrackerImpact"][0].global_position
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


## Smart rounds this gun loads at the top of a fresh mag.
func smart_capacity() -> int:
	return clampi(roundi(smart_fraction * magazine_size), 0, magazine_size)


## True while a smart round is chambered: the lock really works.
func smart_ready() -> bool:
	return smart and smart_left > 0 and ammo > 0


## True when the next shot will home in on lock_target.
func is_locked() -> bool:
	return smart_ready() and is_instance_valid(lock_target) and lock_time >= LOCK_TIME


## 0..1 how far the working lock has closed on lock_target.
func lock_progress() -> float:
	return clampf(lock_time / LOCK_TIME, 0.0, 1.0) if lock_target != null else 0.0


## Where a smart round aims on a target: centre mass, below the head line.
static func lock_point(target: Node3D) -> Vector3:
	return target.global_position + Vector3.UP * 1.0


## The working lock: the living grunt nearest the crosshair inside the cone,
## in range and in sight.
func _find_lock() -> Node3D:
	var from: Vector3 = player.camera.global_position
	var forward: Vector3 = -player.head.global_basis.z
	var best: Node3D = null
	var best_angle := deg_to_rad(LOCK_CONE)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node3D) or not e.has_method("is_headshot") or e.get("dead") == true:
			continue
		var to: Vector3 = lock_point(e) - from
		if to.length() > LOCK_RANGE:
			continue
		var angle := forward.angle_to(to)
		# Keep the current target a little longer, so the lock doesn't flick.
		if e == lock_target:
			angle -= deg_to_rad(2.0)
		if angle >= best_angle:
			continue
		var query := PhysicsRayQueryParameters3D.create(from, lock_point(e), SHOT_MASK)
		query.exclude = [player.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.collider != e:
			continue
		best = e
		best_angle = angle
	return best


## With a smart round chambered the lock works (see _find_lock). Otherwise the
## broken module still searches for targets under the crosshair, brackets them
## for a moment, then errors out: purely cosmetic.
func _scan_lock(delta: float) -> void:
	_lock_beep -= delta
	_lock_scan -= delta
	if lock_target != null:
		var was_locked := lock_time >= LOCK_TIME
		lock_time += delta
		if not is_instance_valid(lock_target) or not lock_target.is_in_group("enemies") or lock_target.get("dead") == true:
			lock_target = null
		elif smart_ready() and not was_locked and lock_time >= LOCK_TIME:
			SFX.play(self, "lock_on", -8.0)
	if _lock_scan > 0.0:
		return
	_lock_scan = 0.05 if smart_ready() else 0.1
	if smart_ready():
		var target := _find_lock()
		if target != lock_target:
			lock_target = target
			lock_time = 0.0
		return
	var cam: Camera3D = player.camera
	var from := cam.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - player.head.global_basis.z * 60.0, SHOT_MASK)
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
	stop_inspect()


## Swaps the pistol for another upgrade tier's model (0-5), keeping ammo.
func set_tier(new_tier: int) -> void:
	tier = clampi(new_tier, 0, 5)
	if viewmodel == null:
		return
	viewmodel.free()
	viewmodel = null
	_parts.clear()
	_leds.clear()
	_twirl = -1.0
	_build_viewmodel()


func is_reloading() -> bool:
	return reload_timer > 0.0


func refill() -> void:
	ammo = magazine_size
	smart_left = smart_capacity()
	reload_timer = 0.0
	bloom = 0.0
	recoil_pending = 0.0
	_set_part_visible("MagBase", true)
	stop_inspect()


func is_inspecting() -> bool:
	return inspect_time > -1.0


func inspect() -> void:
	if is_reloading():
		return
	inspect_time = 0.0
	_inspect_tapped = false
	# Never the same line twice in a row.
	var pick := rng.randi_range(0, maxi(inspect_lines.size() - 2, 0))
	if pick >= _inspect_line and inspect_lines.size() > 1:
		pick += 1
	_inspect_line = pick
	inspect_time = -0.001  # so the opening twirl fires on the first update
	inspected.emit(inspect_lines[pick])


func stop_inspect() -> void:
	inspect_time = -1.0
	if _twirl >= 0.0 and not is_reloading():
		_twirl = -1.0  # snap back into the grip to shoot


func _update_inspect(delta: float) -> void:
	if not is_inspecting():
		return
	var before := inspect_time
	inspect_time += delta
	for tw in INSPECT_TWIRLS:
		if before < tw[0] + 0.001 and inspect_time >= tw[0]:
			twirl(tw[1])
	if before < 2.45 and inspect_time >= 2.45:
		_holo_pulse = 1.0  # she checks the sight; it flares for her
	if not _inspect_tapped and inspect_time >= INSPECT_TAP:
		_inspect_tapped = true
		SFX.play(self, "whack", -8.0, 1.5)
		_kick_rot_vel += Vector3(-6.0, 0.0, 10.0)
		if smart:
			SFX.play(self, "lock_err", -12.0)
			_module_sparks(4)
	if inspect_time >= INSPECT_KEYS.back()[0]:
		inspect_time = -1.0  # done; the closing twirl finishes on its own


## Position and rotation (degrees) offsets of the inspect at time t.
func _inspect_pose(t: float) -> Array:
	if t < 0.0:
		return [Vector3.ZERO, Vector3.ZERO]
	for i in range(1, INSPECT_KEYS.size()):
		var b: Array = INSPECT_KEYS[i]
		if t <= b[0]:
			var a: Array = INSPECT_KEYS[i - 1]
			var w := smoothstep(0.0, 1.0, (t - a[0]) / (b[0] - a[0]))
			return [a[1].lerp(b[1], w), a[2].lerp(b[2], w)]
	return [Vector3.ZERO, Vector3.ZERO]


## 0 at the start of a reload, 1 at the end.
func reload_progress() -> float:
	return 1.0 - reload_timer / reload_time if is_reloading() else 0.0


## Mag kicks out, fresh mag in, Eco twirls the gun round her finger, and the
## ammo screen boots back up counting the new rounds in.
func _reload_choreography() -> void:
	var p := reload_progress()
	var fx_parent: Node = player.get_parent()
	if _reload_events == 0 and p >= RELOAD_BEATS[0]:
		_reload_events = 1
		SFX.play(self, "reload_out", -3.0, SFX.vary())
		var down: Vector3 = -viewmodel.global_basis.y
		if _drum != null:
			# A revolver: the spent rivets tip out of the cylinder.
			var at: Vector3 = _drum.global_position
			for i in magazine_size - ammo:
				FX.casing(fx_parent, at, player.velocity + down * 1.5 + player.head.global_basis.x * randf_range(-0.6, 0.6))
		else:
			var mag_at: Vector3 = _parts["MagBase"][0].global_position if _parts.has("MagBase") else viewmodel.global_transform * Vector3(0.0, -0.09, 0.06)
			FX.chunk(fx_parent, mag_at, Vector3(0.034, 0.1, 0.048), Color(0.82, 0.85, 0.9), player.velocity + down * 2.5 + player.head.global_basis.x * 0.6, 0.6)
		_set_part_visible("MagBase", false)
		_kick_vel += Vector3(0.0, 0.8, 0.0)
		_kick_rot_vel += Vector3(-10.0, 0.0, 0.0)
	elif _reload_events == 1 and p >= RELOAD_BEATS[1]:
		_reload_events = 2
		SFX.play(self, "reload_in", -2.0, SFX.vary())
		_set_part_visible("MagBase", true)
		_kick_vel += Vector3(0.0, 0.6, 0.0)
		_kick_rot_vel += Vector3(12.0, 0.0, -6.0)
	elif _reload_events == 2 and p >= RELOAD_BEATS[2]:
		_reload_events = 3
		twirl(-1.0)
	elif _reload_events == 3 and p >= RELOAD_BEATS[3]:
		_reload_events = 4
		_boot = 0.0
		_holo_pulse = 1.0
		SFX.play(self, "boot", -9.0)
		SFX.play(self, "flourish", -12.0, SFX.vary(0.05))
		if _holo != null:
			FX.star(viewmodel, _holo.global_position, Color(0.7, 1.0, 1.0, 0.9), 0.03, 0.12, 4)


## Spins the gun once round Eco's trigger finger. `direction` -1 dips the
## muzzle first, 1 flips it up and back.
func twirl(direction := -1.0) -> void:
	_twirl = 0.0
	_twirl_dir = direction
	SFX.play(self, "twirl", -6.0, SFX.vary(0.08))


func is_twirling() -> bool:
	return _twirl >= 0.0


func _update_twirl(delta: float) -> void:
	if _gun == null:
		return
	if _twirl < 0.0:
		_gun.transform = _gun_rest
		return
	_twirl += delta
	var u := clampf(_twirl / TWIRL_TIME, 0.0, 1.0)
	# Fast off the finger, slowing as it comes round, a little overshoot to settle.
	var turn := 1.0 - pow(1.0 - u, 3.0)
	turn += sin(u * PI) * 0.04 * (1.0 - u)
	var angle := TAU * turn * _twirl_dir
	var spin := Transform3D(Basis(Vector3.RIGHT, angle), Vector3.ZERO)
	_gun.transform = _gun_rest * Transform3D(Basis.IDENTITY, TWIRL_PIVOT) * spin * Transform3D(Basis.IDENTITY, -TWIRL_PIVOT)
	# Light trails off the muzzle and the LEDs while it spins.
	if u < 0.85:
		FX.star(viewmodel, muzzle.global_position, Color(LED_CYAN, 0.7), 0.012, 0.14, 4)
		if not _leds.is_empty():
			FX.star(viewmodel, _leds[LED_COUNT - 1].global_position, Color(LED_CYAN, 0.5), 0.008, 0.1, 4)
	if u >= 1.0:
		_twirl = -1.0
		_gun.transform = _gun_rest
		_kick_rot_vel += Vector3(8.0 * _twirl_dir, 0.0, 0.0)  # caught: a little bounce


## Vents, LEDs, holo sight: everything on the gun that lights up.
func _update_lights(delta: float) -> void:
	_since_fx += delta
	if _since_fx > 0.12:
		heat = maxf(heat - delta * 0.9, 0.0)
	_holo_pulse = maxf(_holo_pulse - delta * 5.0, 0.0)
	_ammo_pop = maxf(_ammo_pop - delta * 9.0, 0.0)
	if _boot >= 0.0:
		_boot += delta
	if not is_reloading() and _boot > 0.4:
		_boot = -1.0
	var now := Time.get_ticks_msec() / 1000.0

	if _vents != null:
		# Cold vents barely show; hot ones glow orange and shimmer.
		var shimmer := 1.0 + sin(now * 37.0) * 0.12 * heat
		_vents.set_instance_shader_parameter("glow", (0.12 + heat * heat * 7.0) * shimmer)
		_vents.set_instance_shader_parameter("paint", Color(1.0, 0.6, 0.4).lerp(Color(1.0, 0.85, 0.6), heat))
	if _holo != null:
		_holo.set_instance_shader_parameter("pulse", _holo_pulse)
		_holo.set_instance_shader_parameter("glitch", glitch * 0.5)

	if _leds.is_empty():
		return
	# The LEDs are an ammo bar: one goes dark from the front for every
	# 1/6 of the mag spent. Amber when low, red and blinking when empty.
	var lit := ceili(float(ammo) / magazine_size * LED_COUNT)
	var color := LED_CYAN
	if ammo == 0:
		color = LED_RED
	elif ammo <= 2:
		color = LED_AMBER
	var breathe := 0.85 + 0.15 * sin(now * 2.2)
	for i in LED_COUNT:
		var level := breathe if i < lit else 0.06
		if ammo == 0 and not is_reloading():
			level = 1.2 if fmod(now, 0.5) < 0.3 and i == 0 else 0.06
		# A pulse races from the back of the slide to the muzzle on each shot.
		level += 7.0 * exp(-pow((_since_fx / 0.022 - i) / 1.3, 2.0))
		if is_reloading():
			color = LED_CYAN
			if _boot < 0.0:
				level = 0.05 + 0.4 * float(i == int(now * 14.0) % LED_COUNT)  # waiting: a lone scanner
			else:
				level = 2.5 * float(_boot * 30.0 > i) + 4.0 * exp(-pow((_boot / 0.03 - i) / 1.0, 2.0))
		if is_inspecting():
			level += 2.0 * exp(-pow(fmod(now * 10.0, LED_COUNT + 3.0) - i, 2.0))  # showing off: a chase
		if glitch > 0.6 and rng.randf() < 0.3:
			level *= 0.2
		_leds[i].set_instance_shader_parameter("glow", level)
		_leds[i].set_instance_shader_parameter("paint", color)


## Her father's dog tag hangs off the rail and swings with everything the gun
## does: shots, landings, turns and twirls.
func _swing_charm(delta: float) -> void:
	if _charm == null or delta <= 0.0:
		return
	delta = minf(delta, 0.05)
	var pos := _charm.global_position
	var vel := (pos - _charm_last_pos) / delta
	var accel := ((vel - _charm_last_vel) / delta).limit_length(60.0)
	_charm_last_pos = pos
	_charm_last_vel = vel
	# Which way is "down" for the tag right now: gravity minus how the gun is
	# being thrown around, in the space the tag swings in.
	var pull: Vector3 = _charm.get_parent().global_basis.inverse() * (Vector3.DOWN * 9.8 - accel)
	if pull.length() < 0.5:
		return
	var target := Vector2(atan2(-pull.z, -pull.y), atan2(pull.x, -pull.y))
	var err := Vector2(wrapf(target.x - _charm_angle.x, -PI, PI), wrapf(target.y - _charm_angle.y, -PI, PI))
	_charm_vel += (err * 90.0 - _charm_vel * 3.5) * delta
	_charm_angle += _charm_vel * delta
	_charm.rotation = Vector3(_charm_angle.x, 0.0, _charm_angle.y)


func _recover_recoil(delta: float) -> void:
	if recoil_pending <= 0.0:
		return
	var step := minf(recoil_pending, deg_to_rad(12.0) * delta)
	recoil_pending -= step
	player.head.rotation.x = clampf(player.head.rotation.x - step, -1.55, 1.55)


func _build_viewmodel() -> void:
	_parts.clear()
	_leds.clear()
	_ammo_label = null
	viewmodel = Node3D.new()
	add_child(viewmodel)
	var pistol := Art.model(_model_name(model_id, tier))
	viewmodel.add_child(pistol)
	_fit_attachments(pistol, model_id, attachments, tier)
	_apply_finish(pistol, finish)
	for mi in pistol.find_children("*", "GeometryInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	muzzle = pistol.find_child("Muzzle", true, false)
	# Animated pieces of the smart pistol (tools/pistol/build_pistol.py), by name.
	_pistol = pistol
	for part in ["Slide", "MagBase", "TrackerImpact", "AmmoReadout"]:
		var node := pistol.find_child(part, true, false) as Node3D
		if node != null:
			_parts[part] = [node, node.position, node.rotation]
	_gun = pistol.get_node_or_null("Gun") as Node3D
	if _gun != null:
		_gun_rest = _gun.transform
	for i in LED_COUNT:
		var led := pistol.find_child("Led%d" % i, true, false) as GeometryInstance3D
		if led != null:
			_leds.append(led)
	if _leds.size() != LED_COUNT:
		_leds.clear()
	_vents = pistol.find_child("Vents", true, false) as GeometryInstance3D
	_holo = pistol.find_child("HoloGlass", true, false) as GeometryInstance3D
	_charm = pistol.find_child("Charm", true, false) as Node3D
	if _charm != null:
		_charm_last_pos = _charm.global_position
	_drum = pistol.find_child("Drum", true, false) as Node3D
	_hammer = pistol.find_child("Hammer", true, false) as Node3D
	_drum_turn = 0.0
	_build_ammo_screen()

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.85, 0.97, 1.0)
	var sphere := SphereMesh.new()
	sphere.radius = 0.018
	sphere.height = 0.036
	sphere.material = mat
	flash = MeshInstance3D.new()
	flash.mesh = sphere
	flash.visible = false
	muzzle.add_child(flash)


## The gun model a profile describes, attachments on and painted, without
## Eco's arm: what the workbenches show.
static func gun_model(profile: Dictionary) -> Node3D:
	var model := Art.model(_model_name(profile.get("model", "pistol"), profile.get("tier", 0)))
	model.get_node("Arm").free()
	_fit_attachments(model, profile.get("model", "pistol"), profile.get("attachments", {}), profile.get("tier", 0))
	_apply_finish(model, profile.get("finish", {}))
	return model


## Bolts the fitted attachments onto the gun: muzzle pieces at the Muzzle
## (which moves to the end of them), mag pieces under the magazine (so they
## drop out with it on a reload), grip pieces round the grip.
## The model to show for a gun at an upgrade tier: the smart pistol has a
## model per tier (Art.pistol_model), the other sidearms one each.
static func _model_name(p_model_id: String, p_tier: int) -> String:
	return Art.pistol_model(p_tier) if p_model_id == "pistol" else p_model_id


static func _fit_attachments(model: Node3D, p_model_id: String, p_attachments: Dictionary, p_tier := 0) -> void:
	var gun: Node3D = model.get_node_or_null("Gun")
	if gun == null:
		return
	for slot in p_attachments:
		var id: String = p_attachments[slot]
		if not ATTACHMENT_MODELS.has(id):
			continue
		var piece: Node3D = ATTACHMENT_MODELS[id].instantiate()
		piece.name = "Attachment_" + slot
		match slot:
			"muzzle":
				var tip_at := gun.find_child("Muzzle", true, false) as Node3D
				tip_at.get_parent().add_child(piece)
				piece.transform = tip_at.transform
				var tip := piece.find_child("Tip", true, false) as Node3D
				if tip != null:
					tip_at.transform = tip_at.transform * tip.transform
			"mag":
				var mag := gun.find_child("MagBase", true, false) as Node3D
				var parent: Node3D = mag if mag != null else gun
				parent.add_child(piece)
				var bottom: float = MAG_BOTTOM.get(p_model_id, -0.07)
				if p_model_id == "pistol" and p_tier >= 3:
					bottom += PISTOL_LONG_MAG  # the upgraded pistol's longer mag
				piece.transform = GRIP_XFORM * Transform3D(Basis.IDENTITY, Vector3(0, bottom, 0))
			"grip":
				gun.add_child(piece)
				piece.transform = GRIP_XFORM
		for mi in piece.find_children("*", "GeometryInstance3D", true, false):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static var _finish_cache := {}


## Repaints the gun's shell, accent and stripe in the finish's colours.
static func _apply_finish(model: Node3D, p_finish: Dictionary) -> void:
	if p_finish.is_empty():
		return
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var mat := mesh.surface_get_material(i)
			if mat == null or not mat is ShaderMaterial:
				continue
			var slot_name: String = mat.resource_path.get_file().get_basename()
			if not FINISH_SLOTS.has(slot_name):
				continue
			var key := "%s/%s" % [p_finish.get("id", ""), slot_name]
			if not _finish_cache.has(key):
				var painted: ShaderMaterial = mat.duplicate()
				painted.set_shader_parameter("albedo", p_finish[FINISH_SLOTS[slot_name]])
				_finish_cache[key] = painted
			(mi as MeshInstance3D).set_surface_override_material(i, _finish_cache[key])


## Digits on the sloped screen at the back of the slide.
func _build_ammo_screen() -> void:
	if not _parts.has("AmmoReadout"):
		return
	_ammo_label = Label3D.new()
	_ammo_label.font_size = 64
	_ammo_label.pixel_size = 0.00018
	_ammo_label.outline_size = 0
	_ammo_label.shaded = false
	_ammo_label.double_sided = false
	_ammo_label.render_priority = 2
	_ammo_label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_parts["AmmoReadout"][0].add_child(_ammo_label)


func _update_ammo_screen() -> void:
	if _ammo_label == null:
		return
	_ammo_label.scale = Vector3.ONE * (1.0 + _ammo_pop * 0.3)
	if is_reloading():
		if _boot >= 0.0:
			# Booting: counts the fresh rounds in.
			_ammo_label.text = "%02d" % mini(int(_boot / 0.022), magazine_size)
			_ammo_label.modulate = Color(0.4, 0.95, 1.0).lerp(Color.WHITE, 0.5)
		else:
			_ammo_label.text = "--" if fmod(reload_timer, 0.3) < 0.18 else ""
			_ammo_label.modulate = Color(0.4, 0.95, 1.0)
		return
	_ammo_label.text = "%02d" % ammo
	if ammo == 0:
		_ammo_label.modulate = Color(1.0, 0.25, 0.2) if fmod(Time.get_ticks_msec() / 1000.0, 0.5) < 0.3 else Color(0.4, 0.08, 0.06)
	elif ammo <= 2:
		_ammo_label.modulate = Color(1.0, 0.65, 0.2)
	else:
		_ammo_label.modulate = Color(0.4, 0.95, 1.0)
	_ammo_label.modulate = _ammo_label.modulate.lerp(Color.WHITE, _ammo_pop * 0.7)


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

	_holster = move_toward(_holster, 1.0 if holstered else 0.0, delta * 7.0)
	var h := smoothstep(0.0, 1.0, _holster)

	var pos := Vector3(0.22, -0.2, -0.42)
	pos += Vector3(0.05, -0.2, 0.08) * h
	pos += Vector3(-_sway.x * 0.006, _sway.y * 0.006, 0.0)
	pos += bob + Vector3(0.0, -_move_pose.y + _move_pose.z, 0.0)
	pos += Vector3(_kick_pos.x * 0.02, _kick_pos.y * 0.02, _kick_pos.z * 0.04)
	pos += Vector3(-0.06, -0.08, 0.04) * r
	var inspect_pose := _inspect_pose(inspect_time)
	var ir: Vector3 = inspect_pose[1]
	pos += inspect_pose[0]
	viewmodel.position = pos
	viewmodel.rotation = Vector3(
		deg_to_rad(_kick_rot.x + ir.x) + _sway.y * 0.02 + 0.35 * r - 0.5 * h,
		deg_to_rad(_kick_rot.y + ir.y) + _sway.x * 0.025 - 0.25 * r,
		deg_to_rad(_kick_rot.z + ir.z) + _move_pose.x + _sway.x * 0.02 + 0.7 * r)

	# Slide cycles back on each shot and locks open on an empty mag.
	_slide_back = maxf(_slide_back - delta * 14.0, 0.0)
	var slide := 1.0 if ammo == 0 and not is_reloading() else _slide_back
	for part in ["Slide"]:
		if _parts.has(part):
			_parts[part][0].position = _parts[part][1] + Vector3(0, 0, 0.035 * slide)
	# The rivet cannon's drum indexes round a chamber per shot; its hammer falls and resets.
	if _drum != null:
		_drum.rotation.z = lerp_angle(_drum.rotation.z, _drum_turn, 1.0 - exp(-30.0 * delta))
	if _hammer != null:
		_hammer.rotation.x = lerpf(_hammer.rotation.x, 0.0, 1.0 - exp(-12.0 * delta))


## Camera punch: a visual kick on the camera that springs back to zero.
func _apply_punch(delta: float) -> void:
	_punch = _punch.lerp(Vector2.ZERO, 1.0 - exp(-16.0 * delta))
	player.camera.rotation.x = _punch.x
	player.camera.rotation.y = _punch.y
