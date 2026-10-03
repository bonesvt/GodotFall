extends SceneTree
## Screenshots of the first / third person views (scripts/view_camera.gd):
## the forest in first and third person, running, and both wallrun shoulders.
##   xvfb-run -a godot --path . --fixed-fps 60 -s res://tools/view_shots.gd -- [out_dir]
## Needs a renderer (not --headless). --fixed-fps keeps 60 fps time steps even
## on slow software renderers, so the camera's smoothing looks as in play.

const FB := preload("res://scripts/run/forest_builder.gd")

var out := "user://view_shots"


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


func _aim(player, at: Vector3, look: Vector3) -> void:
	player.global_position = at
	player.velocity = Vector3.ZERO
	var d := look - (at + Vector3(0, 1.6, 0))
	player.rotation.y = atan2(-d.x, -d.z)
	player.get_node("Head").rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


func _go() -> void:
	var run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 1234
	root.add_child(run_node)
	await _frames(20)
	run_node.start_run(1234)
	await _frames(30)
	for g in run_node.zone_info.get("grunts", []):
		g.passive = true
	var player = run_node.player
	var view = player.get_node("ViewCam")
	var spawn := FB._on(FB.trail_x(6), 6, 0)
	var ahead := FB._on(FB.trail_x(-30), -30, 2)

	player.process_mode = Node.PROCESS_MODE_DISABLED
	view.process_mode = Node.PROCESS_MODE_ALWAYS  # the camera keeps following
	_aim(player, spawn, ahead)
	await _frames(4)
	_save("1_forest_first_person")
	view.set_third_person(true)
	await _frames(20)
	_save("2_forest_third_person")

	# running: let her move for a moment so the camera trails
	player.process_mode = Node.PROCESS_MODE_INHERIT
	Input.action_press("move_forward")
	await _frames(45)
	_save("3_forest_running")
	Input.action_release("move_forward")
	run_node.queue_free()
	await _frames(5)

	# wallruns in the test level corridor
	var level = load("res://scenes/test_level.tscn").instantiate()
	root.add_child(level)
	await _frames(20)
	player = level.get_node("Player")
	view = player.get_node("ViewCam")
	view.set_third_person(true)
	for wall in [["4_wallrun_wall_on_left", -2.8, -3.0], ["5_wallrun_wall_on_right", 2.8, 3.0]]:
		player.global_position = Vector3(wall[1], 3.0, -20)
		player.rotation.y = 0.0
		player.velocity = Vector3(wall[2], 0, -10)
		Input.action_press("move_forward")
		await _frames(40)
		_save(wall[0])
		Input.action_release("move_forward")
		await _frames(30)
	quit()
