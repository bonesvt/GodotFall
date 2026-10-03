extends SceneTree
## Screenshots of Biggie's gym and every workout scene's three shots, at the
## deepest point of a rep in each, for checking the poses and framing.
##   xvfb-run -a godot --audio-driver Dummy --fixed-fps 30 --path . -s res://tools/hub/gym_shots.gd -- [out_dir] [--fit=<0..1>] [--only=squat,bag] [--partner=mom|ophelia] [--date]
## Needs a renderer (not --headless). Uses its own save file.

const Gym := preload("res://scripts/hub/gym.gd")
const GymRoom := preload("res://scripts/hub/gym_room.gd")
const GymWorkout := preload("res://scripts/hub/gym_workout.gd")

var run_node
var out := "user://gym_shots"
var fit := -1.0
var only: PackedStringArray = []
var partner := ""
var date := false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fit="):
			fit = float(arg.trim_prefix("--fit="))
		elif arg.begins_with("--partner="):
			partner = arg.trim_prefix("--partner=")
		elif arg == "--date":
			date = true
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",")
		else:
			out = arg
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280, 720)
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 1234
	run_node.armory_path = "user://shots_gym_armory.cfg"
	run_node.npc_path = "user://shots_gym_npcs.cfg"
	for path in [run_node.armory_path, run_node.npc_path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	root.add_child(run_node)
	_go.call_deferred()


func _go() -> void:
	await _frames(30)
	if fit >= 0.0:
		for part in Gym.PARTS:
			run_node.armory.fitness[part] = int(fit * Gym.MAX_POINTS)
			if partner != "":
				run_node.armory.fitness_of(partner)[part] = int(fit * Gym.MAX_POINTS)
		run_node.equip_loadout()
		run_node.dress_hub()
	for layer in root.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	# software rendering in the cloud is slow: skip the screen-space extras
	for env_node in root.find_children("*", "WorldEnvironment", true, false):
		var env: Environment = env_node.environment
		env.ssao_enabled = false
		env.ssil_enabled = false
		env.sdfgi_enabled = false
	var gun: Node3D = run_node.player.get_node_or_null("Head/Camera3D/Weapon")
	if gun != null:
		gun.visible = false
	if partner != "":
		run_node.gym_partner = partner
		run_node.gym_date = date
		run_node._wait_in_gym(partner)
	var f := 1.2
	if only.is_empty():
		# The room from the door in Biggie's den, and from the far corner.
		await _shot("0-gym-from-door", Vector3(GymRoom.DOOR_X, f, -37.6), Vector3(8.0, f + 0.9, -43.5))
		await _shot("0-gym-corner", Vector3(5.2, f, -44.8), Vector3(11.5, f + 0.8, -39.5))
	for id: String in Gym.WORKOUTS:
		if not only.is_empty() and not id in only:
			continue
		run_node.gym_done.clear()
		var spot := {}
		for s in run_node.zone_info["interactables"]:
			if s.get("workout") == id:
				spot = s
		run_node.player.global_position = spot["pos"] + Vector3(0, 0.1, 0)
		await _frames(3)
		run_node.start_workout(id)
		var w = run_node.workout
		for layer in w.find_children("*", "CanvasLayer", true, false):
			layer.visible = true   # the captions are part of the scene
		for k in GymWorkout.SHOTS[id].size():
			w.time = _deepest(w, k)
			w.shot = k - 1
			w._next_shot()
			await _frames(1)
			w.time = _deepest(w, k)
			await _frames(3)
			await _save("%s-%d" % [id, k + 1])
		w._finish()
		await _frames(3)
	print("gym shots in ", ProjectSettings.globalize_path(out))
	quit()


## The time in shot `k` (past its first second) where the rep is deepest.
func _deepest(w, k: int) -> float:
	var t0: float = k * GymWorkout.SHOT_TIME + 0.8
	if w.workout == "bag":
		return floor(t0) + 0.6   # the cross landing
	var best := t0
	var t := t0
	while t < (k + 1) * GymWorkout.SHOT_TIME - 0.1:
		if w.depth(t) > w.depth(best):
			best = t
		t += 0.02
	return best


func _shot(shot_name: String, from: Vector3, look: Vector3) -> void:
	var cam := Camera3D.new()
	cam.fov = 62
	root.add_child(cam)
	cam.look_at_from_position(from + Vector3(0, 1.6, 0), look)
	cam.make_current()
	await _frames(4)
	await _save(shot_name)
	cam.queue_free()


func _save(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out.path_join(shot_name + ".png"))
	print("saved ", shot_name)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
