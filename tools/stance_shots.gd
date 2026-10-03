extends SceneTree
## Screenshots of Eco's third person gun stance (scripts/ps2/eco_gun_stance.gd):
## standing stance from the front and side, a close-up of her grip, the game's
## own shoulder view, low ready on the run, mid-twirl and a shot's kick.
##   godot --path . --fixed-fps 60 -s res://tools/stance_shots.gd -- [out_dir] [--only=1,3]
## Needs a renderer (not --headless).

var out := "user://stance_shots"
var player
var shot_cam: Camera3D


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only.assign(a.trim_prefix("--only=").split(","))
		elif not a.begins_with("--"):
			out = a
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1600, 900)
	_go.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## --only=3,4 renders just those shots (the rest still pose, unsaved).
var only: Array[String] = []


func _save(shot_name: String) -> void:
	if not only.is_empty() and not shot_name.get_slice("_", 0) in only:
		return
	root.get_viewport().get_texture().get_image().save_png(out.path_join(shot_name + ".png"))
	print("shot ", shot_name)


## Looks at her from an offset in her own frame (x right, y up, z behind).
func _from(offset: Vector3, look_height: float, fov := 50.0) -> void:
	var at: Vector3 = player.global_position + player.global_basis * offset
	var target: Vector3 = player.global_position + Vector3.UP * look_height
	shot_cam.fov = fov
	shot_cam.look_at_from_position(at, target)
	shot_cam.make_current()


func _go() -> void:
	var level = load("res://scenes/test_level.tscn").instantiate()
	root.add_child(level)
	await _frames(20)
	player = level.get_node("Player")
	var view = player.get_node("ViewCam")
	var stance = player.get_node("EcoBody").stance
	var weapon = player.get_node("Head/Camera3D/Weapon")
	shot_cam = Camera3D.new()
	level.add_child(shot_cam)
	view.set_third_person(true)
	player.global_position = Vector3(0, 0.1, 0)
	player.rotation.y = 0.0
	player.velocity = Vector3.ZERO
	stance.idle_twirl_after = 1000.0  # no idle twirls mid-shot
	await _frames(40)

	_from(Vector3(1.6, 1.5, -2.0), 1.2)
	await _frames(2)
	_save("1_stance_front_three_quarter")
	_from(Vector3(2.4, 1.3, -0.3), 1.15)
	await _frames(2)
	_save("2_stance_side")
	var hold: Node3D = player.get_node("EcoBody").shadow.find_child("GunHold", true, false)
	var grip: Vector3 = hold.global_position
	shot_cam.fov = 40.0
	shot_cam.look_at_from_position(grip + player.global_basis * Vector3(0.45, 0.12, 0.25), grip + player.global_basis * Vector3(0, 0, -0.1))
	await _frames(2)
	_save("3_grip_closeup")
	player.camera.make_current()
	await _frames(2)
	_save("4_game_shoulder_view")

	# shot kick
	weapon.since_shot = 0.02
	_from(Vector3(2.4, 1.3, -0.3), 1.15)
	await _frames(1)
	_save("5_shot_kick")
	await _frames(60)

	# mid-twirl
	stance.start_twirl()
	_from(Vector3(1.6, 1.5, -2.0), 1.2)
	await _frames(12)
	_save("6_twirl")
	await _frames(60)

	# low ready on the run
	Input.action_press("move_forward")
	await _frames(50)
	_from(Vector3(2.8, 1.3, -1.0), 1.0)
	await _frames(1)
	_save("7_low_ready_running")
	Input.action_release("move_forward")
	quit()
