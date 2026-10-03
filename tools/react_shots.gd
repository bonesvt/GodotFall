extends SceneTree
## Screenshots of Eco's world reactions (scripts/ps2/eco_react.gd) and the
## hub/town orbit camera (scripts/view_camera.gd), all in third person:
## the orbit in the hub and town, her feet across a slope, a landing, banking
## into a turn and tilting off a wallrun.
##   godot --path . --fixed-fps 60 -s res://tools/react_shots.gd -- [out_dir]
## Needs a renderer (not --headless).

var out := "user://react_shots"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			out = a
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1600, 900)
	_go.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _save(shot_name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(out.path_join(shot_name + ".png"))
	print("shot ", shot_name)


func _ground(player, at: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 30.0, at + Vector3.DOWN * 30.0)
	q.exclude = [player.get_rid()]
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if not hit.is_empty() else at


func _place(player, at: Vector3, yaw: float) -> void:
	for a in ["move_forward", "crouch", "jump"]:
		Input.action_release(a)
	player.global_position = at
	player.rotation.y = yaw
	player.velocity = Vector3.ZERO


func _go() -> void:
	# --- the hub and town: the orbit camera
	var run_node = load("res://scenes/run.tscn").instantiate()
	root.add_child(run_node)
	await _frames(30)
	var player = run_node.player
	var view = player.get_node("ViewCam")
	view.set_third_person(true)
	await _frames(20)
	var spawn: Vector3 = player.global_position
	view.orbit_yaw = player.rotation.y + PI * 0.85  # swung round to see her face
	view.orbit_pitch = deg_to_rad(-8.0)
	await _frames(40)
	_save("1_hub_orbit_front")
	view.orbit_yaw = player.rotation.y + PI * 0.5
	view.orbit_pitch = deg_to_rad(-25.0)
	await _frames(40)
	_save("2_hub_orbit_side_high")
	var town := _ground(player, Vector3(0, 0, 150))
	_place(player, town + Vector3.UP * 0.1, PI)
	await _frames(30)
	view.orbit_yaw = PI * 0.25
	view.orbit_pitch = deg_to_rad(-5.0)
	Input.action_press("move_forward")  # walks where the camera looks
	await _frames(50)
	_save("3_town_orbit_walking")
	Input.action_release("move_forward")
	run_node.queue_free()
	await _frames(5)

	# --- reactions in the test level
	var level = load("res://scenes/test_level.tscn").instantiate()
	root.add_child(level)
	await _frames(20)
	player = level.get_node("Player")
	view = player.get_node("ViewCam")
	var react = player.get_node("EcoBody").react
	view.set_third_person(true)

	# feet across the slide ramp, seen from the downhill side (the orbit frames it)
	var ramp := _ground(player, Vector3(-25, 0, -30))
	_place(player, ramp + Vector3.UP * 0.1, deg_to_rad(-90.0))
	player.strolling = true
	await _frames(30)
	view.orbit_yaw = deg_to_rad(-90.0) + PI * 0.5
	view.orbit_pitch = deg_to_rad(-5.0)
	await _frames(40)
	_save("4_slope_feet")

	# a landing from 7 m, from the side, at the deepest point
	_place(player, Vector3(0, 7.0, 10), 0.0)
	view.orbit_yaw = PI * 0.5
	view.orbit_pitch = deg_to_rad(-3.0)
	var deepest := 0.0
	for i in 120:
		await _frames(1)
		if react.sink > 0.1 and react.sink < deepest:
			break  # just past the bottom
		deepest = maxf(deepest, react.sink)
	_save("5_landing_sink")
	player.strolling = false
	await _frames(40)

	# banking into a left turn while running
	_place(player, Vector3(10, 0.1, 30), 0.0)
	Input.action_press("move_forward")
	await _frames(30)
	for i in 40:
		player.rotation.y += 1.6 / 60.0
		await _frames(1)
	_save("6_turn_bank")
	Input.action_release("move_forward")
	await _frames(40)

	# tilting off the wall on a wallrun (wall on her left)
	_place(player, Vector3(-2.8, 3.0, -20), 0.0)
	player.velocity = Vector3(-3, 0, -10)
	Input.action_press("move_forward")
	await _frames(40)
	_save("7_wallrun_tilt")
	Input.action_release("move_forward")
	quit()
