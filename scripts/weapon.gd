extends Node3D
## Starter sidearm: a weak semi-auto pistol that rewards accuracy.
## Low body damage, a big headshot multiplier, damage falloff with range,
## and bloom that punishes spamming. Shooting during a wallrun or slide
## is as accurate as standing still, so good movement keeps you accurate.

const Pilot := preload("res://scripts/player.gd")
const FX := preload("res://scripts/fx.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")

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
var kick := 0.0


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
		if reload_timer <= 0.0:
			ammo = magazine_size
	elif Input.is_action_just_pressed("reload") and ammo < magazine_size:
		start_reload()

	if Input.is_action_just_pressed("fire"):
		buffer_timer = fire_buffer
	if buffer_timer > 0.0 and cooldown <= 0.0 and reload_timer <= 0.0:
		buffer_timer = 0.0
		if ammo > 0:
			fire()
		else:
			start_reload()


func _process(delta: float) -> void:
	kick = lerpf(kick, 0.0, 1.0 - exp(-18.0 * delta))
	var lowered := 1.0 if is_reloading() else 0.0
	viewmodel.position = Vector3(0.22, -0.2 - 0.12 * lowered, -0.42 + kick * 0.06)
	viewmodel.rotation = Vector3(kick * 0.12 - lowered * 0.6, 0.0, lowered * 0.3)
	flash_timer -= delta
	flash.visible = flash_timer > 0.0


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
	get_tree().call_group("enemies", "hear_gunshot", player.global_position)
	var cam: Camera3D = player.camera
	var basis := cam.global_basis
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
			hit_confirmed.emit("kill" if killed else ("head" if head else "body"))
		else:
			FX.spark(fx_parent, end, Color(1.0, 0.9, 0.6), 0.06, 0.2)

	FX.tracer(fx_parent, muzzle.global_position, end, Color(1.0, 0.85, 0.4, 0.9), 0.015, 0.06)
	bloom = minf(bloom + bloom_per_shot, max_bloom)
	var k := deg_to_rad(recoil_kick)
	player.head.rotation.x = clampf(player.head.rotation.x + k, -1.55, 1.55)
	recoil_pending += k * recoil_recovery
	kick = 1.0
	flash_timer = 0.04


func damage_at(distance: float) -> float:
	var t := clampf((distance - falloff_start) / (falloff_end - falloff_start), 0.0, 1.0)
	return damage * lerpf(1.0, falloff_min, t)


func start_reload() -> void:
	if reload_timer > 0.0 or ammo >= magazine_size:
		return
	reload_timer = reload_time


func is_reloading() -> bool:
	return reload_timer > 0.0


func refill() -> void:
	ammo = magazine_size
	reload_timer = 0.0
	bloom = 0.0
	recoil_pending = 0.0


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
