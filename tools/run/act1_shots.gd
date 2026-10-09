extends SceneTree
## Stills of the act 1 story yards (scripts/run/story/): Blackwater Line's
## barge, valve and sealed crates, then the crates and the line burning; the
## Boneyard's crater with Dad's arm, and his seat with the recorder.
##   godot --path . --resolution 1280x720 -s res://tools/run/act1_shots.gd -- <out_dir>
## Needs a renderer (not --headless). Writes <out_dir>/act1_story.png.

const CELL := Vector2i(960, 540)

var out := "user://act1_shots"
var sheet: Image
var shot := 0
var cam: Camera3D
var run_node


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		out = a
	DirAccess.make_dir_recursive_absolute(out)
	preload("res://scripts/run/tutorial.gd").settings_path = "user://shots_settings.cfg"
	_go.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _grab() -> void:
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(CELL.x, CELL.y)
	sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * (shot % 3), CELL.y * (shot / 3)))
	shot += 1


## A still from a point in the story node's own space.
func _look(story: Node3D, from: Vector3, at: Vector3, fov := 55.0) -> void:
	cam.make_current()
	cam.fov = fov
	cam.look_at_from_position(story.to_global(from), story.to_global(at))
	await _frames(10)
	_grab()


func _level(id: String) -> Node3D:
	run_node.start_run(4242, 0, id)
	await _frames(20)
	run_node.tutorial.set_enabled(false)
	for g in run_node.zone_info["grunts"]:
		g.passive = true
		g.alerted = false
	run_node.hud.visible = false
	cam = Camera3D.new()
	run_node.add_child(cam)
	return run_node.zone_info["story"]


func _go() -> void:
	sheet = Image.create(CELL.x * 3, CELL.y * 2, false, Image.FORMAT_RGBA8)
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.armory_path = "user://shots_armory.cfg"
	run_node.npc_path = "user://shots_npcs.cfg"
	root.add_child(run_node)
	await _frames(10)
	var bw: Node3D = await _level("level3")
	var side := signf(bw.spots["valve"]["at"].x) * -1.0
	await _look(bw, Vector3(-side * 9.0, 6.0, 10.0), Vector3(side * 1.0, 1.0, -3.0), 60.0)   # the line out to the barge
	await _look(bw, Vector3(-side * 4.5, 1.8, 6.5), Vector3(-side * 0.8, 1.0, 3.5), 50.0)     # the crates and their label
	bw._cut_fuel()
	bw._burn_crates()
	await _frames(20)
	await _look(bw, Vector3(-side * 6.0, 3.0, 1.0), Vector3(0, 1.0, 0), 65.0)                # both burning
	run_node.end_run("RUN OVER", "shots")
	await _frames(10)
	cam.queue_free()
	var by: Node3D = await _level("level4")
	side = signf(by.spots["recorder"]["at"].x) * -1.0
	await _look(by, Vector3(-side * 8.0, 7.0, 11.0), Vector3(0, 0.5, 0), 60.0)               # the crater
	await _look(by, Vector3(-side * 3.0, 2.4, 6.5), Vector3(side * 1.5, 1.2, 2.5), 50.0)      # his arm, the stripe
	await _look(by, Vector3(-side * 3.5, 1.4, 1.5), Vector3(-side * 1.4, 0.4, -1.3), 50.0)    # the seat and the recorder
	sheet.save_png(out.path_join("act1_story.png"))
	print("saved ", out.path_join("act1_story.png"))
	quit()
