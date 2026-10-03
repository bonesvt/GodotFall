extends SceneTree
## Headless test for Eco's world reactions (scripts/ps2/eco_react.gd) and the
## hub/town orbit camera (scripts/view_camera.gd).
## Run: godot --headless --path . -s res://tests/react_test.gd

var player
var view
var react
var failures := 0


func _initialize() -> void:
	var level: Node = load("res://scenes/test_level.tscn").instantiate()
	root.add_child(level)
	_run.call_deferred()


func _run() -> void:
	await _ticks(30)
	player = root.get_node("TestLevel/Player")
	view = player.get_node("ViewCam")
	react = player.get_node("EcoBody").react
	_check("reaction layer on her model", react != null, react)
	_place(Vector3(0, 0.1, 0), 0.0)
	view.set_third_person(true)
	await _ticks(30)

	# --- Landing: her hips sink by how hard she fell, then she straightens
	_place(Vector3(0, 7.0, 10), 0.0)
	var peak := 0.0
	for i in 150:
		await _ticks(1)
		peak = maxf(peak, react.sink)
	_check("hard landing sinks her hips", peak > 0.08, peak)
	await _ticks(90)
	_check("she straightens after", react.sink < 0.02, react.sink)

	# --- Feet on a slope: standing across the slide ramp, the uphill foot is higher
	var top := _ground_at(Vector3(-25, 20, -30))
	_place(top + Vector3(0, 0.1, 0), deg_to_rad(-90.0))  # facing +X, the slope rises to one side
	await _ticks(90)
	var offs: Array = react.foot_offsets
	_check("her feet find different ground heights", absf(offs[0] - offs[1]) > 0.02, offs)
	_check("the lower foot drops her hips", react.get("_foot_sink") > 0.005, react.get("_foot_sink"))

	# --- Banking into a turn: running while turning left leans her left
	_place(Vector3(10, 0.1, 30), 0.0)
	Input.action_press("move_forward")
	await _ticks(60)
	for i in 50:
		player.rotation.y += 1.6 / 120.0  # turning left
		await _ticks(1)
	var left: Vector3 = -player.global_basis.x
	_check("leans into a left turn", react.bank.dot(left) > deg_to_rad(5.0), rad_to_deg(react.bank.dot(left)))
	Input.action_release("move_forward")
	await _ticks(120)
	_check("stands up straight again", react.bank.length() < deg_to_rad(2.0), rad_to_deg(react.bank.length()))

	# --- Wallrun: her body tilts out from the wall (left wall: tilt toward +X)
	_place(Vector3(-2.8, 3.0, -20), 0.0)
	player.velocity = Vector3(-3, 0, -10)
	Input.action_press("move_forward")
	var ran := false
	for i in 60:
		await _ticks(1)
		if player.state_name() == "WALLRUN":
			ran = true
			break
	await _ticks(30)
	_check("wallrun reached", ran, player.state_name())
	_check("tilts out from the wall", react.wall_tilt.x > deg_to_rad(15.0), rad_to_deg(react.wall_tilt.x))
	Input.action_release("move_forward")
	await _ticks(200)

	# --- Orbit camera while strolling (the hub and town)
	_place(Vector3(0, 0.1, 0), 0.0)
	player.strolling = true
	await _ticks(60)
	_check("orbits while strolling", view.orbiting, view.orbiting)
	var hud = root.get_node("TestLevel").find_child("HUD", true, false)
	if hud != null and hud.get("crosshair") != null:
		_check("no crosshair while orbiting", not hud.crosshair.visible, hud.crosshair.visible)
	var yaw_before: float = player.rotation.y
	view.orbit_yaw = deg_to_rad(90.0)  # swing the camera round to her right
	await _ticks(10)
	_check("swinging the camera doesn't turn her", is_equal_approx(player.rotation.y, yaw_before), player.rotation.y)
	var cam: Camera3D = player.camera
	var to_cam: Vector3 = (cam.global_position - player.global_position)
	var expect := Basis(Vector3.UP, deg_to_rad(90.0)) * Vector3.BACK
	_check("camera sits where it was swung", Vector2(to_cam.x, to_cam.z).normalized().dot(Vector2(expect.x, expect.z)) > 0.95, to_cam)
	# camera looks along -X now: "forward" walks her that way and she turns to face it
	var start: Vector3 = player.global_position
	Input.action_press("move_forward")
	await _ticks(120)
	Input.action_release("move_forward")
	var walked: Vector3 = player.global_position - start
	_check("forward walks where the camera looks", walked.x < -1.0 and absf(walked.z) < 0.3, walked)
	_check("she turns to face where she walks", (-player.global_basis.z).dot(Vector3.LEFT) > 0.95, -player.global_basis.z)
	_check("strolls, not runs", player.horizontal_speed() < 3.5 or walked.length() < 5.0, walked.length())

	# leaving the hub: back to the shoulder camera, facing where the orbit looked
	player.strolling = false
	await _ticks(60)
	_check("shoulder camera off duty ends", not view.orbiting, view.orbiting)
	_check("she faces the orbit's direction", (-player.global_basis.z).dot(Vector3.LEFT) > 0.95, -player.global_basis.z)
	var behind: float = (cam.global_position - player.get_node("Head").global_position).dot(player.global_basis.z)
	_check("camera back behind her shoulder", behind > 1.4 and behind < 2.2, behind)

	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(failures)


func _ground_at(from: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 40.0)
	q.exclude = [player.get_rid()]
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if not hit.is_empty() else from


func _place(pos: Vector3, yaw: float) -> void:
	for a in ["move_forward", "move_right", "crouch", "jump", "grapple"]:
		Input.action_release(a)
	player.global_position = pos
	player.rotation.y = yaw
	player.get_node("Head").rotation.x = 0.0
	player.velocity = Vector3.ZERO


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _check(what: String, ok: bool, value) -> void:
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", what, str(value)])
	if not ok:
		failures += 1
