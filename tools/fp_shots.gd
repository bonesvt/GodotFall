extends SceneTree
## Screenshots of Eco in first person (scripts/eco_fp_arms.gd, scripts/eco_fp_body.gd):
## her arm on the gun, looking down at her body, and her chest bouncing on a
## jump and a landing.
##   xvfb-run -a godot --path . --fixed-fps 60 -s res://tools/fp_shots.gd -- [out_dir] [--only=name]
## Needs a renderer (not --headless).

var out := "user://fp_shots"
var only := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
		elif not a.begins_with("--"):
			out = a
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280, 720)
	_go.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _save(shot_name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(out.path_join(shot_name + ".png"))
	print("shot ", shot_name)


func _go() -> void:
	var level = load("res://scenes/test_level.tscn").instantiate()
	root.add_child(level)
	await _frames(10)
	var player = level.get_node("Player")
	var head: Node3D = player.get_node("Head")
	var body = player.get_node("EcoBody")
	player.global_position = Vector3(0, 0.1, 6)
	player.rotation.y = 0.0
	await _frames(20)
	if only == "" or only == "arm":
		head.rotation.x = 0.0
		await _frames(3)
		_save("1_arm")
		for tier in [[5, "heavy"]]:
			body.set_suit(tier[0], tier[1])
			await _frames(20)
			_save("2_arm_t%d_%s" % tier)
		body.set_suit(0, "medium")
		await _frames(20)
	if only == "" or only == "down":
		head.rotation.x = deg_to_rad(-40)
		await _frames(30)
		_save("3_look_down")
		head.rotation.x = deg_to_rad(-60)
		await _frames(30)
		_save("4_look_down_more")
	if only == "" or only == "jump":
		head.rotation.x = deg_to_rad(-50)
		await _frames(20)
		Input.action_press("jump")
		await _frames(2)
		Input.action_release("jump")
		for f in 60:
			await process_frame
			if f % 6 == 0:
				_save("5_jump_%02d" % f)
	quit()
