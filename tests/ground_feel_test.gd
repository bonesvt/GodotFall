extends SceneTree
## Headless test for how running feels: snappy starts, stops and turns on
## foot, with momentum only carried through slides (including slides pressed
## just before landing).
## Run: godot --headless --path . -s res://tests/ground_feel_test.gd

const OPEN := Vector3(45, 0.1, -60)  # flat, empty ground away from the courses

var player
var failures := 0


func _initialize() -> void:
	var level: Node = load("res://scenes/test_level.tscn").instantiate()
	root.add_child(level)
	_run.call_deferred()


func _run() -> void:
	await _ticks(30)
	player = root.get_node("TestLevel/Player")

	# Starting: full sprint in about a tenth of a second.
	await _settle()
	Input.action_press("move_forward")
	await _secs(0.12)
	_check("reaches sprint speed in 0.12 s", player.horizontal_speed() > 10.0, player.horizontal_speed())

	# Stopping: let go and you stop dead, no skating.
	await _secs(0.3)
	Input.action_release("move_forward")
	var p0: Vector3 = player.global_position
	await _secs(0.13)
	_check("stops within 0.13 s", player.horizontal_speed() < 0.1, player.horizontal_speed())
	_check("stopping skid under 0.7 m", player.global_position.distance_to(p0) < 0.7, player.global_position.distance_to(p0))

	# Reversing: sprinting forward, hit back, moving the other way fast.
	await _settle()
	Input.action_press("move_forward")
	await _secs(0.3)
	Input.action_release("move_forward")
	Input.action_press("move_back")
	await _secs(0.15)
	var back: float = player.velocity.dot(player.global_basis.z)
	_check("reverses within 0.15 s", back > 5.0, back)
	Input.action_release("move_back")

	# Strafing: sideways drift dies quickly when you switch keys.
	await _settle()
	Input.action_press("move_right")
	await _secs(0.3)
	Input.action_release("move_right")
	Input.action_press("move_forward")
	await _secs(0.1)
	var side: float = absf(player.velocity.dot(player.global_basis.x))
	_check("sideways drift killed on turn", side < 0.5, side)
	Input.action_release("move_forward")

	# Landing fast without crouching: momentum bleeds back to a run.
	await _settle()
	_drop(0.6, Vector3(0, -2, -18))
	Input.action_press("move_forward")
	await _until_grounded()
	await _secs(0.5)
	_check("landing without slide bleeds speed", player.horizontal_speed() < 11.0, player.horizontal_speed())
	Input.action_release("move_forward")

	# Landing while holding crouch: slide keeps the speed.
	await _settle()
	_drop(0.6, Vector3(0, -2, -18))
	Input.action_press("crouch")
	await _until_grounded()
	_check("held crouch lands in a slide", player.state_name() == "SLIDE", player.state_name())
	_check("landing slide keeps speed", player.horizontal_speed() > 17.0, player.horizontal_speed())
	Input.action_release("crouch")

	# Tapping crouch just before touching down still slides, and it carries.
	await _settle()
	_drop(1.2, Vector3(0, -3, -16))
	await _press("crouch")
	await _until_grounded()
	_check("crouch tap before landing slides", player.state_name() == "SLIDE", player.state_name())
	await _secs(0.25)
	_check("buffered slide carries momentum", player.state_name() == "SLIDE" and player.horizontal_speed() > 14.0, player.horizontal_speed())

	# Big drop into a slide turns some of the fall into speed.
	await _settle()
	player.slide_boost_timer = 99.0  # isolate the landing bonus from the slide boost
	_drop(1.0, Vector3(0, -20, -10))
	Input.action_press("crouch")
	await _until_grounded()
	_check("drop into slide adds speed", player.state_name() == "SLIDE" and player.horizontal_speed() > 12.0, player.horizontal_speed())
	Input.action_release("crouch")

	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(failures)


## Stand still on open ground, facing -Z, with no keys held.
func _settle() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "crouch", "jump", "grapple"]:
		Input.action_release(a)
	player.global_position = OPEN
	player.rotation.y = 0.0
	player.get_node("Head").rotation.x = 0.0
	player.velocity = Vector3.ZERO
	player.slide_boost_timer = 0.0
	await _secs(0.1)


## Put the player in the air above open ground, moving with vel.
func _drop(height: float, vel: Vector3) -> void:
	player.global_position = OPEN + Vector3(0, height, 0)
	player.velocity = vel
	player.state = player.State.AIR


## Wait until the player is on the ground (or sliding), up to two seconds.
func _until_grounded() -> void:
	for i in Engine.physics_ticks_per_second * 2:
		await physics_frame
		if player.state_name() == "GROUND" or player.state_name() == "SLIDE":
			return


func _secs(t: float) -> void:
	await _ticks(roundi(t * Engine.physics_ticks_per_second))


func _press(action: String) -> void:
	await physics_frame
	Input.action_press(action)
	await physics_frame
	Input.action_release(action)


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _check(what: String, ok: bool, value) -> void:
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", what, str(value)])
	if not ok:
		failures += 1
