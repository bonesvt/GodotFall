extends CharacterBody3D
## The titan you assembled this run. It drops from orbit, you embark, you fight.
## Chassis sets armor, speed and dashes; weapon sets damage; the core is a
## charged ability; the kit tweaks the rest (see titan_parts.gd).
## How the weapon fires (rhythm, FX, sound, recoil) lives in titan_gun.gd;
## damage still comes from the weapon part's damage per second.

signal landed
signal destroyed

const Art := preload("res://scripts/ps2/ps2_assets.gd")
const TitanGun := preload("res://scripts/run/titan_gun.gd")
const FX := preload("res://scripts/fx.gd")
const SFX := preload("res://scripts/sfx.gd")

const GRAVITY := 30.0
const ACCEL := 40.0
const DASH_SPEED := 28.0
const DASH_TIME := 0.25
const DASH_RECHARGE := 5.0
const DROP_SPEED := 70.0
## Seconds for the core to charge from time alone; dealing damage speeds it up.
const CORE_TIME := 35.0
const CORE_PER_DAMAGE := 1.0 / 4000.0
const FIRE_RANGE := 200.0
const HEIGHT := 7.0
const EYE := 6.2

var stats := {}
## The installed parts (slot -> part, see titan_parts.gd); picks the model.
var parts := {}
var model: Node3D
var hp := 0.0
var max_hp := 0.0
var dashes := 0
var dash_recharge := 0.0
var dash_timer := 0.0
var dash_dir := Vector3.ZERO
var core_charge := 0.0
var overdrive_timer := 0.0
var ramp_bonus := 0.0
var on_target := false
var dropping := true
## While piloted the hull is hidden so it doesn't fill the cockpit view;
## the arms and weapon stay visible.
var piloted := false:
	set(value):
		piloted = value
		if model != null:
			for part in model.get_children():
				if part is Node3D and not String(part.name).begins_with("Arm"):
					part.visible = not value
var dead := false
var boss: Node
var head: Node3D
var camera: Camera3D
var mouse_sensitivity := 0.0022
var gun: TitanGun
## Camera shake; shots and impacts add to it, it decays on its own.
var shake := 0.0
var _shake_t := 0.0


func setup(p_stats: Dictionary) -> void:
	stats = p_stats
	max_hp = stats["hp"]
	hp = max_hp
	dashes = stats["dashes"]


func _ready() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = 1.4
	shape.height = HEIGHT
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = HEIGHT * 0.5
	add_child(col)
	model = Art.titan(parts.get("chassis", {}).get("id", "scrap"), parts.get("weapon", {}).get("id", "scrap"))
	add_child(model)
	head = Node3D.new()
	head.position.y = EYE
	add_child(head)
	camera = Camera3D.new()
	camera.fov = 85.0
	camera.near = 0.1
	head.add_child(camera)
	gun = TitanGun.new()
	gun.name = "Gun"
	gun.setup(self, parts.get("weapon", {}).get("id", "scrap"))
	add_child(gun)


func _process(delta: float) -> void:
	# Shake is visual only; aim comes from the head, not the camera.
	shake = minf(maxf(shake - delta * 2.2, 0.0), 1.0)
	_shake_t += delta * 40.0
	var s := shake * shake
	camera.position = Vector3(sin(_shake_t * 1.3), sin(_shake_t * 1.7 + 1.0), 0.0) * s * 0.12
	camera.rotation = Vector3(sin(_shake_t * 1.1 + 2.0) * 0.02, sin(_shake_t * 0.9) * 0.02, sin(_shake_t * 1.5) * 0.015) * s
	camera.fov = lerpf(camera.fov, 85.0, 1.0 - exp(-8.0 * delta))


func _unhandled_input(event: InputEvent) -> void:
	if not piloted:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * mouse_sensitivity, -1.2, 1.2)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if dropping:
		velocity = Vector3(0, -DROP_SPEED, 0)
		move_and_slide()
		if is_on_floor():
			dropping = false
			velocity = Vector3.ZERO
			landed.emit()
		return
	if not piloted or dead:
		velocity = Vector3(0, velocity.y - GRAVITY * delta, 0)
		move_and_slide()
		return

	_move(delta)
	_recharge(delta)
	_fire(delta)
	model.set_param("glow", 0.4 + core_charge * 1.6, "Core")
	if Input.is_action_just_pressed("titan_core"):
		use_core()


func _move(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
	if Input.is_action_just_pressed("titan_dash") and dashes > 0 and dash_timer <= 0.0:
		dashes -= 1
		dash_timer = DASH_TIME
		dash_dir = wish if wish != Vector3.ZERO else -transform.basis.z
	var h := Vector3(velocity.x, 0.0, velocity.z)
	if dash_timer > 0.0:
		dash_timer -= delta
		h = dash_dir * DASH_SPEED
	else:
		h = h.move_toward(wish * float(stats["speed"]), ACCEL * delta)
	velocity = Vector3(h.x, 0.0 if is_on_floor() else velocity.y - GRAVITY * delta, h.z)
	move_and_slide()


func _recharge(delta: float) -> void:
	overdrive_timer -= delta
	if dashes < int(stats["dashes"]):
		dash_recharge += delta * float(stats["dash_rate"])
		if dash_recharge >= DASH_RECHARGE:
			dash_recharge = 0.0
			dashes += 1
	core_charge = minf(core_charge + delta / CORE_TIME * float(stats["core_rate"]), 1.0)


func _fire(delta: float) -> void:
	var firing := Input.is_action_pressed("titan_fire")
	gun.update(delta, firing)
	on_target = firing and not gun.jammed() and aimed_target() != null
	if not on_target:
		ramp_bonus = 0.0
		return
	ramp_bonus = minf(ramp_bonus + delta * 0.5, float(stats["ramp"]))


## A shot from the gun hit `target` (the enemy titan, or a practice dummy in
## the hub) for `base` damage, before the ramp and overdrive bonuses.
func hit_enemy(target: Node, base: float) -> void:
	if target == null:
		return
	var dmg := base * (1.0 + ramp_bonus)
	if overdrive_timer > 0.0:
		dmg *= 2.0
	target.take_damage(dmg)
	core_charge = minf(core_charge + dmg * CORE_PER_DAMAGE * float(stats["core_rate"]), 1.0)


## What's under the crosshair that can take titan fire (the enemy titan, or a
## practice dummy in the hub), or null.
func aimed_target() -> Node:
	var from := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - head.global_basis.z * FIRE_RANGE)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit.collider.is_in_group("titan_target"):
		return null
	var node: Node = hit.collider
	while node != null and not node.has_method("take_damage"):
		node = node.get_parent()
	return node


func use_core() -> bool:
	if core_charge < 1.0 or stats["core"] == "none":
		return false
	core_charge = 0.0
	match stats["core"]:
		"laser":
			if boss != null:
				boss.take_damage(float(stats["core_power"]))
				var to: Vector3 = boss.global_position + Vector3.UP * 5.0
				var from := gun._muzzle()
				FX.tracer(get_parent(), from, to, Color(1.0, 0.3, 0.25, 0.95), 1.4, 0.6)
				FX.tracer(get_parent(), from, to, Color(1.0, 1.0, 0.9), 0.5, 0.5)
				FX.blast(get_parent(), to, Color(1.0, 0.35, 0.2), 6.0, 0.6)
				SFX.play(self, "tracker_boom", 4.0, 0.6)
				shake = 1.0
		"shield":
			hp = minf(hp + max_hp * float(stats["core_power"]), max_hp)
		"overdrive":
			overdrive_timer = float(stats["core_power"])
			dashes = int(stats["dashes"])
	return true


func take_damage(amount: float) -> void:
	if dead:
		return
	hp -= amount
	shake += minf(amount / 300.0, 0.6)
	if hp <= 0.0:
		hp = 0.0
		dead = true
		destroyed.emit()
