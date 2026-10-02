extends SceneTree
## Headless smoke test for the movement abilities.
## Run: godot --headless --path . -s res://tests/movement_test.gd

var player
var failures := 0


func _initialize() -> void:
	var level: Node = load("res://scenes/test_level.tscn").instantiate()
	root.add_child(level)
	_run.call_deferred()


func _run() -> void:
	await _ticks(30)
	player = root.get_node("TestLevel/Player")

	# Sprint
	_place(Vector3(0, 0.1, 0), 0.0)
	Input.action_press("move_forward")
	await _ticks(90)
	_check("sprint reaches sprint speed", player.horizontal_speed() > 10.0, player.horizontal_speed())

	# Slide gives a boost
	var before: float = player.horizontal_speed()
	Input.action_press("crouch")
	await _ticks(3)
	_check("slide starts", player.state_name() == "SLIDE", player.state_name())
	_check("slide boosts speed", player.horizontal_speed() > before + 2.0, player.horizontal_speed())

	# Slide-hop keeps momentum
	await _press("jump")
	Input.action_release("crouch")
	await _ticks(2)
	_check("slide-hop airborne", player.state_name() == "AIR", player.state_name())
	_check("slide-hop keeps speed", player.horizontal_speed() > 11.0, player.horizontal_speed())

	# Double jump
	await _ticks(20)
	var vy_before: float = player.velocity.y
	await _press("jump")
	await _ticks(1)
	_check("double jump fires", player.velocity.y > vy_before + 2.0 and player.air_jumps_left == 0, player.velocity.y)
	Input.action_release("move_forward")
	await _ticks(150)

	# Wallrun in the corridor: airborne, moving forward, drifting into the left wall
	_place(Vector3(-2.8, 3.0, -20), 0.0)
	player.velocity = Vector3(-3, 0, -10)
	Input.action_press("move_forward")
	var saw_wallrun := false
	for i in 60:
		await _ticks(1)
		if player.state_name() == "WALLRUN":
			saw_wallrun = true
			break
	_check("wallrun starts on contact", saw_wallrun, player.state_name())
	await _ticks(60)
	_check("wallrun holds height", player.state_name() == "WALLRUN" and player.global_position.y > 2.5, player.global_position)
	_check("wallrun speed", player.horizontal_speed() > 9.0, player.horizontal_speed())

	# Wall jump pushes away from the wall (+X for the left wall)
	await _press("jump")
	await _ticks(2)
	_check("wall jump pushes off", player.velocity.x > 5.0 and player.velocity.y > 4.0, player.velocity)
	Input.action_release("move_forward")
	await _ticks(200)

	# Grapple: look up at the floating platform behind spawn
	_place(Vector3(0, 0.1, 40), 0.0)
	await _ticks(20)
	player.get_node("Head").rotation.x = deg_to_rad(65)
	Input.action_press("grapple")
	await _ticks(2)
	_check("grapple attaches", player.state_name() == "GRAPPLE", player.state_name())
	var y0: float = player.global_position.y
	await _ticks(60)
	_check("grapple pulls up", player.global_position.y > y0 + 3.0, player.global_position.y)
	Input.action_release("grapple")
	await _ticks(2)
	_check("grapple releases", player.state_name() != "GRAPPLE", player.state_name())

	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(failures)


func _place(pos: Vector3, yaw: float) -> void:
	for a in ["move_forward", "crouch", "jump", "grapple"]:
		Input.action_release(a)
	player.global_position = pos
	player.rotation.y = yaw
	player.get_node("Head").rotation.x = 0.0
	player.velocity = Vector3.ZERO


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
