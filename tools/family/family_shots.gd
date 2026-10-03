extends SceneTree
## Shots of the Motherly Love scenes as they play in the hub (family_scene.gd):
## curled up with Mom on her bed, and Mom looking after Eco when she's sick.
##   xvfb-run -a godot --audio-driver Dummy --path . -s res://tools/family/family_shots.gd -- [out_dir] [cuddle|sick]
## Needs a renderer (not --headless). Slow on software Vulkan (~1 min a shot).

const Family := preload("res://scripts/hub/family.gd")

var out := "user://family_shots"
var only := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	if args.size() > 1:
		only = args[1]
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(960, 540)
	_go.call_deferred()


func _go() -> void:
	var run_node = load("res://scenes/run.tscn").instantiate()
	run_node.armory_path = "user://family_shots_armory.cfg"
	run_node.npc_path = "user://family_shots_npcs.cfg"
	for p in [run_node.armory_path, run_node.npc_path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	root.add_child(run_node)
	await _frames(30)
	var talk = run_node.npc_talk
	var fam = run_node.family_scene
	talk.state.set_value("mom", "met", true)
	talk.state.set_value("mom", "bond_run", 0)
	Family.add(talk.state, "mom", 30)
	for at in [10, 25]:
		Family.mark_scene(talk.state, "mom", at)
	if only != "sick":
		fam.cuddle()
		await _shot("1_cuddle", 12)
		fam._camera.look_at_from_position(fam.bed() + Vector3(0.75, 1.2, -0.9), fam.bed() + Vector3(-0.05, 1.2, 0.6))
		await _shot("2_cuddle_close", 4)
		talk.stop()
		await _frames(5)
	if only == "cuddle":
		quit()
		return
	talk.state.set_value("eco", "sick_run", run_node.runs_ended)
	fam.care()
	await _shot("3_sick", 12)
	fam._camera.look_at_from_position(fam.bed() + Vector3(0.4, 2.0, -2.5), fam.bed() + Vector3(0.25, 0.75, 0.3))
	await _shot("4_sick_wide", 4)
	quit()


func _shot(name: String, frames: int) -> void:
	await _frames(frames)
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("shot ", name)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
