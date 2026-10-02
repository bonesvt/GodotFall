extends CharacterBody3D
## Titanfall-style pilot controller.
## Abilities: sprint, slide (with slide-hop momentum), double jump,
## wallrun, wall jump, and a grapple hook.
## Every tuning value is exported, so it can be tweaked live in the Inspector.

enum State { GROUND, AIR, SLIDE, WALLRUN, GRAPPLE }

signal died
signal respawned
signal damaged(amount: float, from: Vector3)

@export_group("Ground")
@export var run_speed := 7.0
@export var sprint_speed := 10.5
@export var crouch_speed := 3.5
@export var ground_accel := 70.0
@export var ground_decel := 50.0
## How fast you bleed speed above sprint speed while on the ground.
@export var overspeed_decel := 14.0
## Seconds after landing before ground friction applies, so slide-hops keep speed.
@export var bhop_grace := 0.12
## Sprint automatically when moving forward (hold Shift to sprint when off).
@export var auto_sprint := true

@export_group("Air")
@export var gravity := 20.0
@export var jump_velocity := 7.0
@export var air_jumps := 1
@export var double_jump_velocity := 7.0
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

@export_group("Wallrun")
@export var wallrun_min_speed := 4.0
@export var wallrun_speed := 11.0
@export var wallrun_accel := 15.0
@export var wallrun_gravity := 3.5
@export var wallrun_max_time := 1.8
@export var wallrun_entry_lift := 2.5
@export var wall_jump_push := 7.5
@export var wall_jump_up := 7.0
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

@export_group("Health")
@export var max_health := 100.0
## Seconds without taking damage before health starts coming back.
@export var regen_delay := 3.0
@export var regen_rate := 30.0

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
var wallrun_timer := 0.0
var wall_normal := Vector3.ZERO
var last_wall_normal := Vector3.ZERO
var wall_block_timer := 0.0
var wall_coyote_timer := 0.0
var grapple_point := Vector3.ZERO
var grapple_cooldown_timer := 0.0
var crouching := false
var cam_roll := 0.0
var input_dir := Vector2.ZERO
var wish_dir := Vector3.ZERO
var rope: Node3D
var health := 100.0
var regen_timer := 0.0


static func ensure_input_actions() -> void:
	var keys := {
		"move_forward": [KEY_W], "move_back": [KEY_S],
		"move_left": [KEY_A], "move_right": [KEY_D],
		"jump": [KEY_SPACE], "crouch": [KEY_C, KEY_CTRL],
		"sprint": [KEY_SHIFT], "grapple": [KEY_Q, KEY_E], "reset": [KEY_T],
		"reload": [KEY_R], "reset_arena": [KEY_G], "fire": [],
	}
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	var rmb := InputEventMouseButton.new()
	rmb.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("grapple", rmb)
	var lmb := InputEventMouseButton.new()
	lmb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("fire", lmb)


func _ready() -> void:
	ensure_input_actions()
	# Own copy of the shape so crouching never edits the shared scene resource.
	collision.shape = collision.shape.duplicate()
	spawn_transform = global_transform
	air_jumps_left = air_jumps
	health = max_health
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_build_rope()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * mouse_sensitivity, -1.55, 1.55)
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
	regen_timer -= delta
	if regen_timer <= 0.0 and health < max_health:
		health = minf(health + regen_rate * delta, max_health)

	input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	wish_dir = (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer
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
	var target := crouch_speed if crouching else (sprint_speed if sprinting else run_speed)
	var speed := hvel.length()
	if wish_dir != Vector3.ZERO:
		if speed > target:
			# Keep carried momentum briefly after landing, then bleed it off.
			if ground_time > bhop_grace:
				hvel = hvel.move_toward(wish_dir * target, overspeed_decel * delta)
		else:
			hvel = hvel.move_toward(wish_dir * target, ground_accel * delta)
	elif ground_time > bhop_grace:
		hvel = hvel.move_toward(Vector3.ZERO, ground_decel * delta)

	velocity.x = hvel.x
	velocity.z = hvel.z
	velocity.y -= gravity * delta

	if jump_buffer_timer > 0.0:
		_jump()
	move_and_slide()
	if not is_on_floor() and state == State.GROUND:
		state = State.AIR


func _air_state(delta: float) -> void:
	coyote_timer -= delta
	ground_time = 0.0
	_set_crouch(Input.is_action_pressed("crouch"))
	velocity.y -= gravity * delta
	_air_strafe(delta)

	if jump_buffer_timer > 0.0:
		if wall_coyote_timer > 0.0:
			_wall_jump()
		elif coyote_timer > 0.0:
			_jump()
		elif air_jumps_left > 0:
			_double_jump()

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
	elif not Input.is_action_pressed("crouch"):
		state = State.GROUND
		_set_crouch(false)
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
	air_jumps_left = air_jumps
	var hspeed := Vector3(velocity.x, 0.0, velocity.z).length()
	if Input.is_action_pressed("crouch") and hspeed >= slide_min_speed:
		_start_slide()
	else:
		state = State.GROUND


func _start_slide() -> void:
	state = State.SLIDE
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
	regen_timer = 0.0
	_set_crouch(false)
	respawned.emit()


func take_damage(amount: float, from := Vector3.ZERO) -> void:
	if health <= 0.0:
		return
	health -= amount
	regen_timer = regen_delay
	damaged.emit(amount, from)
	if health <= 0.0:
		health = 0.0
		died.emit()


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
	head.position.y = lerpf(head.position.y, eye, 1.0 - exp(-14.0 * delta))

	var target_roll := 0.0
	if state == State.WALLRUN:
		target_roll = -signf(wall_normal.dot(transform.basis.x)) * deg_to_rad(wallrun_camera_tilt)
	cam_roll = lerpf(cam_roll, target_roll, 1.0 - exp(-10.0 * delta))
	camera.rotation.z = cam_roll

	var t := clampf((horizontal_speed() - run_speed) / (22.0 - run_speed), 0.0, 1.0)
	camera.fov = lerpf(camera.fov, base_fov + speed_fov_bonus * t, 1.0 - exp(-6.0 * delta))


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
	var dir := grapple_point - from
	var length := dir.length()
	if length < 0.01:
		return
	var up := Vector3.UP if absf(dir.normalized().y) < 0.99 else Vector3.FORWARD
	var b := Basis.looking_at(dir, up)
	rope.global_transform = Transform3D(Basis(b.x, b.y, b.z * length), from)


# --- Info for the HUD ---------------------------------------------------------

func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func state_name() -> String:
	return State.keys()[state]


func grapple_ready_in() -> float:
	return maxf(grapple_cooldown_timer, 0.0)
