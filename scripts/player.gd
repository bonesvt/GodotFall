extends CharacterBody3D
## Titanfall-style pilot controller.
## Abilities: sprint, slide (with slide-hop momentum), double jump,
## wallrun, wall jump, and a grapple hook.
## Every tuning value is exported, so it can be tweaked live in the Inspector.

enum State { GROUND, AIR, SLIDE, WALLRUN, GRAPPLE }

const SFX := preload("res://scripts/sfx.gd")
const Prefs := preload("res://scripts/game/prefs.gd")
const Vices := preload("res://scripts/hub/vices.gd")
const EcoContactSounds := preload("res://scripts/ps2/eco_contact_sounds.gd")
## Metres between footsteps on the ground and when running along a wall.
const STRIDE := 2.4
const WALL_STRIDE := 1.9

signal died
signal respawned
signal damaged(amount: float, from: Vector3)
## The suit's second wind kept her up.
signal second_winded

@export_group("Ground")
@export var run_speed := 7.0
@export var sprint_speed := 10.5
@export var crouch_speed := 3.5
## Off duty (the hub and the town, away from the training grounds) Eco doesn't
## run: she struts. Ground speed then, and with sprint held.
@export var stroll_speed := 1.9
@export var stroll_brisk_speed := 3.0
## Running is snappy: you hit full speed and stop dead in a few frames.
## Momentum is carried by sliding, wallrunning and the grapple, not by running.
@export var ground_accel := 110.0
@export var ground_decel := 90.0
## How fast sideways or backwards drift is killed when you change direction.
@export var ground_turn_decel := 95.0
## How fast you bleed speed above sprint speed while on the ground.
@export var overspeed_decel := 40.0
## Seconds after landing before carried speed above sprint speed bleeds off,
## so slide-hops and late slide presses keep momentum.
@export var bhop_grace := 0.15
## Sprint automatically when moving forward (hold Shift to sprint when off).
@export var auto_sprint := true

@export_group("Air")
@export var gravity := 28.0
## Extra gravity while falling, so jumps snap down instead of hanging.
@export var fall_gravity_mult := 1.35
@export var max_fall_speed := 45.0
@export var jump_velocity := 8.4
@export var air_jumps := 1
@export var double_jump_velocity := 8.2
@export var air_wish_speed := 8.0
@export var air_accel := 30.0
@export var coyote_time := 0.12
@export var jump_buffer := 0.12

@export_group("Slide")
@export var slide_min_speed := 6.0
@export var slide_boost := 4.0
@export var slide_boost_cooldown := 1.5
@export var slide_friction := 3.0
@export var slide_end_speed := 3.5
@export var slide_steer := 2.5
@export var slide_max_speed := 26.0
## Landing into a slide turns part of a big fall into forward speed.
## Falls slower than slide_land_min_fall (a normal hop) add nothing.
@export var slide_land_min_fall := 10.5
@export var slide_land_boost := 0.35
@export var slide_land_max_boost := 5.0
## Seconds a crouch tap in the air is remembered, so pressing slide just
## before you touch down still lands you in a slide.
@export var slide_land_buffer := 0.25

@export_group("Wallrun")
@export var wallrun_min_speed := 4.0
@export var wallrun_speed := 11.0
@export var wallrun_accel := 15.0
@export var wallrun_gravity := 3.5
@export var wallrun_max_time := 1.8
@export var wallrun_entry_lift := 2.5
@export var wall_jump_push := 7.5
@export var wall_jump_up := 8.0
@export var wall_coyote_time := 0.15
@export var wallrun_camera_tilt := 12.0

@export_group("Grapple")
@export var grapple_range := 45.0
@export var grapple_pull := 38.0
@export var grapple_max_speed := 24.0
@export var grapple_cooldown := 2.5
@export var grapple_release_dist := 2.5

@export_group("Look")
@export var mouse_sensitivity := 0.0022
@export var base_fov := 90.0
@export var speed_fov_bonus := 15.0
## How far the camera dips per m/s of landing speed, and the cap.
@export var land_dip_per_speed := 0.018
@export var land_dip_max := 0.3

@export_group("Health")
@export var max_health := 100.0
## Seconds without taking damage before health starts coming back.
@export var regen_delay := 3.0
@export var regen_rate := 30.0
## Armour from Eco's suit upgrades (armory.gd SUIT_TIERS, set by apply_suit):
## takes hits before health and comes back, after the same pause, once health is full.
@export var max_armor := 0.0
@export var armor_regen_rate := 25.0

## Seconds she can't be hurt after a second wind.
const SECOND_WIND_TIME := 1.5
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.0
const STAND_EYE := 1.6
const CROUCH_EYE := 0.85

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var collision: CollisionShape3D = $Collision

var state: State = State.AIR
var spawn_transform: Transform3D
var air_jumps_left := 0
var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var ground_time := 0.0
var slide_boost_timer := 0.0
var slide_buffer_timer := 0.0
## A buffered landing slide keeps going while crouch is released, until you
## jump, slow down, or press crouch again.
var slide_latched := false
var wallrun_timer := 0.0
var wall_normal := Vector3.ZERO
var last_wall_normal := Vector3.ZERO
var wall_block_timer := 0.0
var wall_coyote_timer := 0.0
var grapple_point := Vector3.ZERO
var grapple_cooldown_timer := 0.0
var crouching := false
## Ground speed multiplier (Eco runs lighter with only the knife out).
var speed_mult := 1.0
## Off duty: she walks at stroll_speed with a strut (eco_model.gd) instead of
## running. The run manager sets it each tick in the hub and town, and clears
## it on the training grounds and on runs.
var strolling := false
var cam_roll := 0.0
var input_dir := Vector2.ZERO
var wish_dir := Vector3.ZERO
var rope: Node3D
var land_dip := 0.0
var fall_speed := 0.0
var health := 100.0
var armor := 0.0
var regen_timer := 0.0
## Suit passives (apply_suit): how far loot flies to her (x the pickup's own
## range), how fast grunts notice her (x their rate), and the second wind.
var suit_tier := 0
var suit_weight := "medium"
## Weight bonuses: ground speed, how fast armour refills, and how much of each hit lands.
var suit_speed := 1.0
var damage_mult := 1.0
var loot_magnet := 1.0
var notice_mult := 1.0
var second_wind := false
## The second wind is ready (the run manager re-arms it each zone).
var second_wind_ready := false
## Seconds she can't be hurt (after a second wind).
var untouchable_timer := 0.0
## Movement values before the suit's passives scaled them.
var _armor_regen_mult := 1.0
var _base_wallrun_time := -1.0
## max_health before any boost from Solace (town_shops.gd: a meal, implants).
var _base_max_health := -1.0
var _base_grapple_cooldown := -1.0
var step_dist := 0.0
## Set by the ViewCam child (scripts/view_camera.gd) while in third person.
var third_person := false
## Set by the ViewCam's orbit camera (hub and town): the keys walk her relative
## to this yaw (the camera's) instead of her facing, and she turns to face
## where she walks. NAN when off.
var move_yaw := NAN
## How quickly she turns to face where she walks under the orbit camera.
var move_turn_rate := 10.0
## Eco is sitting or lying down somewhere (the run manager's rest spots): she
## doesn't move, but you can still look around her.
var resting := false
## Drink in her (vices.gd): the clock her aim drifts on, and the drift (degrees:
## yaw, pitch) already added to her look, so each frame only adds the change.
var _drunk_t := 0.0
var _drunk_sway := Vector2.ZERO


static func ensure_input_actions() -> void:
	var keys := {
		"move_forward": [KEY_W], "move_back": [KEY_S],
		"move_left": [KEY_A], "move_right": [KEY_D],
		"jump": [KEY_SPACE], "crouch": [KEY_C, KEY_CTRL],
		"sprint": [KEY_SHIFT], "grapple": [KEY_Q, KEY_E], "reset": [KEY_T],
		"reload": [KEY_R], "reset_arena": [KEY_G], "inspect": [KEY_I], "melee": [KEY_Z], "fire": [],
		"swap_weapon": [],
		"toggle_view": [KEY_F5], "swap_shoulder": [KEY_X],
		"cam_nudge_up": [KEY_UP], "cam_nudge_down": [KEY_DOWN],
		"cam_nudge_left": [KEY_LEFT], "cam_nudge_right": [KEY_RIGHT],
	}
	var buttons := {"grapple": [MOUSE_BUTTON_RIGHT], "fire": [MOUSE_BUTTON_LEFT], "melee": [MOUSE_BUTTON_XBUTTON1],
		"swap_weapon": [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN],
		"toggle_view": [MOUSE_BUTTON_MIDDLE]}
	# Only actions that don't exist yet get their defaults, so keys rebound in
	# the settings (prefs.gd) stay rebound.
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var events := []
		for key in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			events.append(ev)
		for button in buttons.get(action, []):
			var mb := InputEventMouseButton.new()
			mb.button_index = button
			# the view swap's mouse button comes first: it's the easy one to reach
			if action == "toggle_view":
				events.insert(0, mb)
			else:
				events.append(mb)
		for ev in events:
			InputMap.action_add_event(action, ev)


func _ready() -> void:
	ensure_input_actions()
	# Own copy of the shape so crouching never edits the shared scene resource.
	collision.shape = collision.shape.duplicate()
	spawn_transform = global_transform
	air_jumps_left = air_jumps
	health = max_health
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_build_rope()
	var contact := EcoContactSounds.new()
	contact.name = "ContactSounds"
	add_child(contact)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-Prefs.look_x(event.relative.x) * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x - Prefs.look_y(event.relative.y) * mouse_sensitivity, -1.55, 1.55)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	slide_boost_timer -= delta
	wall_block_timer -= delta
	wall_coyote_timer -= delta
	grapple_cooldown_timer -= delta
	jump_buffer_timer -= delta
	slide_buffer_timer -= delta
	regen_timer -= delta
	untouchable_timer -= delta
	if regen_timer <= 0.0 and health < max_health:
		health = minf(health + regen_rate * Vices.regen_scale() * delta, max_health)
	elif regen_timer <= 0.0 and armor < max_armor:
		armor = minf(armor + armor_regen_rate * _armor_regen_mult * delta, max_armor)
	if resting:
		velocity = Vector3.ZERO
		input_dir = Vector2.ZERO
		wish_dir = Vector3.ZERO
		_update_camera(delta)
		return

	input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	wish_dir = (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	if not is_nan(move_yaw):
		wish_dir = (Basis(Vector3.UP, move_yaw) * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
		if wish_dir != Vector3.ZERO:
			rotation.y = lerp_angle(rotation.y, atan2(-wish_dir.x, -wish_dir.z), 1.0 - exp(-move_turn_rate * delta))
	_drunk(delta)
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer
	if Input.is_action_just_pressed("crouch") and state != State.GROUND and state != State.SLIDE:
		slide_buffer_timer = slide_land_buffer
	if Input.is_action_just_pressed("grapple"):
		_try_grapple()
	if Input.is_action_just_pressed("reset") or global_position.y < -40.0:
		respawn()

	match state:
		State.GROUND:
			_ground_state(delta)
		State.AIR:
			_air_state(delta)
		State.SLIDE:
			_slide_state(delta)
		State.WALLRUN:
			_wallrun_state(delta)
		State.GRAPPLE:
			_grapple_state(delta)

	_footsteps(delta)
	_update_camera(delta)
	_update_rope()


# --- States -----------------------------------------------------------------

func _ground_state(delta: float) -> void:
	ground_time += delta
	coyote_timer = coyote_time
	air_jumps_left = air_jumps
	var want_crouch := Input.is_action_pressed("crouch")
	var hvel := Vector3(velocity.x, 0.0, velocity.z)

	if want_crouch and hvel.length() >= slide_min_speed:
		_start_slide()
		return
	_set_crouch(want_crouch)

	var sprinting := (auto_sprint or Input.is_action_pressed("sprint")) and input_dir.y < -0.3
	var target := (crouch_speed if crouching else (sprint_speed if sprinting else run_speed)) * speed_mult * suit_speed * Vices.speed_scale()
	if strolling:
		# auto sprint doesn't apply; under the orbit camera any direction counts
		var brisk := Input.is_action_pressed("sprint") and (input_dir.y < -0.3 or (not is_nan(move_yaw) and input_dir != Vector2.ZERO))
		target = minf(crouch_speed, stroll_speed) if crouching else (stroll_brisk_speed if brisk else stroll_speed)
	hvel = _ground_move(hvel, target, delta)

	velocity.x = hvel.x
	velocity.z = hvel.z
	velocity.y -= gravity * delta

	if jump_buffer_timer > 0.0:
		_jump()
	move_and_slide()
	if not is_on_floor() and state == State.GROUND:
		state = State.AIR


## Responsive running: the part of your velocity along the keys you hold
## ramps to target fast, and drift in any other direction is braked hard,
## so turns and stops are crisp instead of skating. Speed above target
## (from a slide, wallrun or grapple) is kept for bhop_grace after landing,
## then bled off at overspeed_decel.
func _ground_move(hvel: Vector3, target: float, delta: float) -> Vector3:
	var speed := hvel.length()
	if speed > target and ground_time <= bhop_grace:
		return hvel
	if wish_dir == Vector3.ZERO:
		var brake := ground_decel if speed <= target else maxf(overspeed_decel, ground_decel)
		return hvel.move_toward(Vector3.ZERO, brake * delta)
	var along := hvel.dot(wish_dir)
	var drift := hvel - wish_dir * along
	if along > target:
		along = move_toward(along, target, overspeed_decel * delta)
	elif along < 0.0:
		# Reversing: brake the old direction and push the new one together.
		along = move_toward(along, target, (ground_accel + ground_decel) * delta)
	else:
		along = move_toward(along, target, ground_accel * delta)
	drift = drift.move_toward(Vector3.ZERO, ground_turn_decel * delta)
	return wish_dir * along + drift


func _air_state(delta: float) -> void:
	coyote_timer -= delta
	ground_time = 0.0
	_set_crouch(Input.is_action_pressed("crouch"))
	var g := gravity * (fall_gravity_mult if velocity.y < 0.0 else 1.0)
	velocity.y = maxf(velocity.y - g * delta, -max_fall_speed)
	_air_strafe(delta)

	if jump_buffer_timer > 0.0:
		if wall_coyote_timer > 0.0:
			_wall_jump()
		elif coyote_timer > 0.0:
			_jump()
		elif air_jumps_left > 0:
			_double_jump()

	fall_speed = -velocity.y
	move_and_slide()

	if is_on_floor():
		_land()
	elif _can_wallrun():
		_start_wallrun(get_wall_normal())


func _slide_state(delta: float) -> void:
	var hvel := Vector3(velocity.x, 0.0, velocity.z)
	var speed := hvel.length()
	# Accelerate down slopes: the floor normal's horizontal part points downhill.
	var n := get_floor_normal()
	hvel += Vector3(n.x, 0.0, n.z) * gravity * delta
	hvel = hvel.move_toward(Vector3.ZERO, slide_friction * delta)
	# Light steering that keeps the current speed.
	if wish_dir != Vector3.ZERO and speed > 0.1:
		speed = hvel.length()
		hvel = (hvel + wish_dir * slide_steer * delta * speed).normalized() * speed
	hvel = hvel.limit_length(slide_max_speed)
	velocity.x = hvel.x
	velocity.z = hvel.z
	velocity.y -= gravity * delta

	if jump_buffer_timer > 0.0:
		_jump()  # slide-hop: horizontal speed is kept
		_set_crouch(false)
	move_and_slide()
	if state != State.SLIDE:
		return
	if not is_on_floor():
		state = State.AIR
		coyote_timer = coyote_time
	elif not (Input.is_action_pressed("crouch") or slide_latched):
		state = State.GROUND
		_set_crouch(false)
	elif slide_latched and Input.is_action_just_pressed("crouch"):
		state = State.GROUND  # tap again to cancel a buffered slide
	elif Vector3(velocity.x, 0.0, velocity.z).length() < slide_end_speed:
		state = State.GROUND


func _wallrun_state(delta: float) -> void:
	wallrun_timer += delta
	var hvel := Vector3(velocity.x, 0.0, velocity.z)
	# Run in the direction you look, projected onto the wall.
	var fwd := -transform.basis.z
	var along := fwd - wall_normal * fwd.dot(wall_normal)
	along.y = 0.0
	if along.length() < 0.2:
		along = hvel - wall_normal * hvel.dot(wall_normal)
	along = along.normalized()
	var speed := hvel.length()
	if speed < wallrun_speed:
		speed = minf(speed + wallrun_accel * delta, wallrun_speed)
	var vy := maxf(velocity.y - wallrun_gravity * delta, -3.0)
	# Small push into the wall keeps contact every frame.
	velocity = along * speed - wall_normal * 2.0
	velocity.y = vy

	if jump_buffer_timer > 0.0:
		_wall_jump()
		move_and_slide()
		return
	var give_up := wallrun_timer > wallrun_max_time \
		or input_dir.y > -0.1 \
		or Input.is_action_pressed("crouch")
	if give_up:
		_leave_wall(0.6)
		velocity += wall_normal * 2.0
		move_and_slide()
		return

	move_and_slide()
	if is_on_floor():
		_leave_wall(0.0)
		_land()
	elif is_on_wall() and absf(get_wall_normal().y) < 0.3:
		wall_normal = get_wall_normal()
	else:
		_leave_wall(0.0)


func _grapple_state(delta: float) -> void:
	var to_point := grapple_point - (global_position + Vector3.UP)
	var dist := to_point.length()
	var dir := to_point / maxf(dist, 0.001)
	velocity += dir * grapple_pull * delta
	velocity.y -= gravity * 0.5 * delta
	# Damp sideways swing so the pull feels direct.
	var along := velocity.dot(dir)
	var perp := velocity - dir * along
	velocity = dir * along + perp * clampf(1.0 - 1.5 * delta, 0.0, 1.0)
	velocity += wish_dir * 6.0 * delta
	velocity = velocity.limit_length(grapple_max_speed)

	if jump_buffer_timer > 0.0:
		_release_grapple()
		velocity.y = maxf(velocity.y, jump_velocity)
		jump_buffer_timer = 0.0
	elif not Input.is_action_pressed("grapple") or dist < grapple_release_dist:
		_release_grapple()
	move_and_slide()


func _air_strafe(delta: float) -> void:
	# Quake-style air control: you can steer and strafe, but never push
	# your speed in the held direction past air_wish_speed, so momentum carries.
	if wish_dir == Vector3.ZERO:
		return
	var current := Vector3(velocity.x, 0.0, velocity.z).dot(wish_dir)
	var add := air_wish_speed - current
	if add > 0.0:
		velocity += wish_dir * minf(add, air_accel * delta)


# --- Transitions --------------------------------------------------------------

func _jump() -> void:
	velocity.y = jump_velocity
	state = State.AIR
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	ground_time = 0.0


func _double_jump() -> void:
	# Double jump can redirect your momentum toward the keys you hold.
	var hvel := Vector3(velocity.x, 0.0, velocity.z)
	if wish_dir != Vector3.ZERO:
		hvel = wish_dir * maxf(hvel.length(), run_speed)
	velocity = Vector3(hvel.x, double_jump_velocity, hvel.z)
	air_jumps_left -= 1
	jump_buffer_timer = 0.0


func _wall_jump() -> void:
	var hvel := Vector3(velocity.x, 0.0, velocity.z)
	var along := hvel - wall_normal * hvel.dot(wall_normal)
	velocity = along + wall_normal * wall_jump_push + wish_dir * 2.0
	velocity.y = wall_jump_up
	_leave_wall(0.35)
	wall_coyote_timer = 0.0
	jump_buffer_timer = 0.0


func _land() -> void:
	ground_time = 0.0
	if fall_speed > 3.0:
		var hard := fall_speed > 14.0
		SFX.play(self, "land_heavy" if hard else "land", -16.0 + minf(fall_speed, 20.0) * 0.4, SFX.vary(0.06))
		SFX.play(self, _step_sound(), -14.0 + minf(fall_speed, 20.0) * 0.3, SFX.vary(0.06) * 0.92)
	step_dist = STRIDE * 0.5
	# Camera dips on hard landings so falls have weight.
	land_dip = minf(maxf(fall_speed - 4.0, 0.0) * land_dip_per_speed, land_dip_max)
	air_jumps_left = air_jumps
	var held := Input.is_action_pressed("crouch")
	var buffered := slide_buffer_timer > 0.0
	slide_buffer_timer = 0.0
	if held or buffered:
		var hvel := Vector3(velocity.x, 0.0, velocity.z)
		var bonus := clampf((fall_speed - slide_land_min_fall) * slide_land_boost, 0.0, slide_land_max_boost)
		var dir := hvel.normalized() if hvel.length() > 0.5 else wish_dir
		if hvel.length() + bonus >= slide_min_speed and dir != Vector3.ZERO:
			hvel = dir * (hvel.length() + bonus)
			velocity.x = hvel.x
			velocity.z = hvel.z
			fall_speed = 0.0
			_start_slide()
			slide_latched = not held
			return
	fall_speed = 0.0
	state = State.GROUND


func _start_slide() -> void:
	state = State.SLIDE
	slide_latched = false
	_set_crouch(true)
	var hvel := Vector3(velocity.x, 0.0, velocity.z)
	if slide_boost_timer <= 0.0 and hvel.length() > 0.1:
		hvel += hvel.normalized() * slide_boost
		slide_boost_timer = slide_boost_cooldown
	velocity.x = hvel.x
	velocity.z = hvel.z


func _can_wallrun() -> bool:
	if not is_on_wall() or input_dir.y > -0.1:
		return false
	var n := get_wall_normal()
	if absf(n.y) > 0.3:
		return false
	if wall_block_timer > 0.0 and n.dot(last_wall_normal) > 0.9:
		return false
	return Vector3(velocity.x, 0.0, velocity.z).length() >= wallrun_min_speed


func _start_wallrun(n: Vector3) -> void:
	state = State.WALLRUN
	wall_normal = n
	wallrun_timer = 0.0
	air_jumps_left = air_jumps
	velocity.y = clampf(velocity.y, wallrun_entry_lift * 0.6, wallrun_entry_lift)
	_set_crouch(false)


func _leave_wall(block_time: float) -> void:
	state = State.AIR
	last_wall_normal = wall_normal
	wall_block_timer = block_time
	wall_coyote_timer = wall_coyote_time if block_time == 0.0 else 0.0


func _try_grapple() -> void:
	if state == State.GRAPPLE or grapple_cooldown_timer > 0.0:
		return
	var from := camera.global_position
	var to := from - camera.global_basis.z * grapple_range
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	query.collision_mask = 1  # world geometry only, not sight-blocking foliage
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	grapple_point = hit.position
	state = State.GRAPPLE
	air_jumps_left = air_jumps
	_set_crouch(false)
	if is_on_floor():
		velocity.y = maxf(velocity.y, 4.0)
	rope.visible = true


func _release_grapple() -> void:
	state = State.AIR
	grapple_cooldown_timer = grapple_cooldown
	rope.visible = false


func respawn() -> void:
	if state == State.GRAPPLE:
		rope.visible = false
	global_transform = spawn_transform
	velocity = Vector3.ZERO
	state = State.AIR
	grapple_cooldown_timer = 0.0
	health = max_health
	armor = max_armor
	regen_timer = 0.0
	untouchable_timer = 0.0
	_set_crouch(false)
	respawned.emit()


func take_damage(amount: float, from := Vector3.ZERO) -> void:
	if health <= 0.0 or untouchable_timer > 0.0:
		return
	amount *= damage_mult * Vices.damage_scale()
	var soaked := minf(armor, amount)
	armor -= soaked
	health -= amount - soaked
	regen_timer = regen_delay
	damaged.emit(amount, from)
	if health <= 0.0 and second_wind_ready:
		# Dad's Colours: once per zone she stays up on 1 HP and can't be touched for a moment
		second_wind_ready = false
		health = 1.0
		untouchable_timer = SECOND_WIND_TIME
		second_winded.emit()
	elif health <= 0.0:
		health = 0.0
		died.emit()


## Puts on Eco's suit upgrade (armory.gd suit_profile()): armour and passives.
func apply_suit(profile: Dictionary) -> void:
	if _base_wallrun_time < 0.0:
		_base_wallrun_time = wallrun_max_time
		_base_grapple_cooldown = grapple_cooldown
		_base_max_health = max_health
	max_health = _base_max_health + profile.get("max_health_bonus", 0.0)
	health = max_health
	suit_tier = profile.get("tier", 0)
	suit_weight = profile.get("weight", "medium")
	suit_speed = profile.get("speed_mult", 1.0)
	damage_mult = profile.get("damage_mult", 1.0)
	_armor_regen_mult = profile.get("armor_regen_mult", 1.0)
	max_armor = profile.get("max_armor", 0.0)
	armor = max_armor
	regen_delay = profile.get("regen_delay", 3.0)
	loot_magnet = profile.get("loot_magnet", 1.0)
	notice_mult = profile.get("notice_mult", 1.0)
	wallrun_max_time = _base_wallrun_time * profile.get("wallrun_time_mult", 1.0)
	grapple_cooldown = _base_grapple_cooldown * profile.get("grapple_cooldown_mult", 1.0)
	second_wind = profile.get("second_wind", false)
	second_wind_ready = second_wind
	var body := get_node_or_null("EcoBody")
	if body != null and body.has_method("set_suit"):
		body.set_suit(suit_tier, suit_weight)


## A few drinks in (vices.gd): her aim drifts on its own, and the change in
## drift goes onto her look so the shot drifts with it and the mouse fights it.
## Her steps wander a little off the way she means to go.
func _drunk(delta: float) -> void:
	_drunk_t += delta
	var want := Vices.sway(_drunk_t)
	var step := want - _drunk_sway
	_drunk_sway = want
	if step != Vector2.ZERO and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(deg_to_rad(step.x))
		head.rotation.x = clampf(head.rotation.x + deg_to_rad(step.y), -1.55, 1.55)
	var veer := Vices.stagger(_drunk_t)
	if veer != 0.0 and wish_dir != Vector3.ZERO:
		wish_dir = wish_dir.rotated(Vector3.UP, veer)


# --- Crouch, camera, rope -----------------------------------------------------

func _set_crouch(want: bool) -> void:
	if want == crouching:
		return
	if not want and test_move(global_transform, Vector3.UP * (STAND_HEIGHT - CROUCH_HEIGHT)):
		return  # no headroom to stand up
	crouching = want
	var cap := collision.shape as CapsuleShape3D
	cap.height = CROUCH_HEIGHT if crouching else STAND_HEIGHT
	collision.position.y = cap.height * 0.5


func _update_camera(delta: float) -> void:
	var eye := CROUCH_EYE if crouching else STAND_EYE
	land_dip = lerpf(land_dip, 0.0, 1.0 - exp(-7.0 * delta))
	head.position.y = lerpf(head.position.y, eye - land_dip, 1.0 - exp(-18.0 * delta))

	var target_roll := 0.0
	if state == State.WALLRUN:
		target_roll = -signf(wall_normal.dot(transform.basis.x)) * deg_to_rad(wallrun_camera_tilt)
	cam_roll = lerpf(cam_roll, target_roll, 1.0 - exp(-10.0 * delta))
	camera.rotation.z = cam_roll

	var t := clampf((horizontal_speed() - run_speed) / (22.0 - run_speed), 0.0, 1.0)
	camera.fov = lerpf(camera.fov, base_fov + Prefs.fov_offset() + speed_fov_bonus * t, 1.0 - exp(-6.0 * delta))


func _build_rope() -> void:
	rope = Node3D.new()
	rope.top_level = true
	rope.visible = false
	add_child(rope)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.03
	mesh.bottom_radius = 0.03
	mesh.height = 1.0
	mesh.radial_segments = 6
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.2)
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.rotation.x = PI / 2.0
	mi.position.z = -0.5
	rope.add_child(mi)


func _update_rope() -> void:
	if not rope.visible:
		return
	var from := camera.global_position + camera.global_basis * Vector3(0.3, -0.3, -0.4)
	if third_person and has_node("ViewCam"):
		from = $ViewCam.muzzle_position()
	var dir := grapple_point - from
	var length := dir.length()
	if length < 0.01:
		return
	var up := Vector3.UP if absf(dir.normalized().y) < 0.99 else Vector3.FORWARD
	var b := Basis.looking_at(dir, up)
	rope.global_transform = Transform3D(Basis(b.x, b.y, b.z * length), from)


# --- Footsteps ----------------------------------------------------------------

func _footsteps(delta: float) -> void:
	var on_wall := state == State.WALLRUN
	if not (state == State.GROUND or on_wall):
		return
	var speed := horizontal_speed()
	if speed < 1.0 or crouching:
		return
	step_dist += speed * delta
	var stride := WALL_STRIDE if on_wall else STRIDE
	if step_dist >= stride:
		step_dist -= stride
		SFX.play(self, _step_sound(), -17.0 + minf(speed / sprint_speed, 1.0) * 4.0, SFX.vary(0.08))


## A footstep for what she's on (step_<surface>_N), concrete when that surface
## has no recordings.
func _step_sound() -> String:
	var id := SFX.variant("step_" + _surface())
	return id if id != "" else SFX.variant("step_concrete")


## What Eco is standing or running on: wading in water (laid_out.gd water()),
## a rug or path (hub_kit.gd patch()), then the `surface` meta on the body she
## touched (terrain: grass, mud, gravel; hub props: wood, metal, stone);
## anything else is concrete.
func _surface() -> String:
	var feet := global_position
	for w: Node3D in get_tree().get_nodes_in_group("water"):
		if feet.y < w.global_position.y + 0.05 and _inside(w, feet):
			return "water"
	for p: Node3D in get_tree().get_nodes_in_group("surface_patch"):
		if absf(feet.y - p.global_position.y) < 0.35 and _inside(p, feet):
			return str(p.get_meta("surface"))
	var hit := get_last_slide_collision()
	if hit != null:
		var body := hit.get_collider()
		if body != null and body.has_meta("surface"):
			return str(body.get_meta("surface"))
	return "concrete"


## True when `at` is over a node's flat area (its "half" meta, x/z half sizes).
static func _inside(node: Node3D, at: Vector3) -> bool:
	var half: Vector2 = node.get_meta("half", Vector2.ZERO)
	var local := node.global_transform.affine_inverse() * at
	return absf(local.x) <= half.x and absf(local.z) <= half.y


# --- Info for the HUD ---------------------------------------------------------

func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func state_name() -> String:
	return State.keys()[state]


func grapple_ready_in() -> float:
	return maxf(grapple_cooldown_timer, 0.0)
