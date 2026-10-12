extends SceneTree
## The HUD's corners (hud.gd, run_hud.gd): in the hub with Ophelia and Eco
## together, Marrow's pull clock running, Hymn in her and Keepsake; then out
## on a run, the same corners with the fight panel live.
##   godot --path . --resolution 1280x720 -s res://tools/hub/hud_shots.gd -- <out_dir>
## Needs a renderer (not --headless). Writes <out_dir>/hud.png.

const Vices := preload("res://scripts/hub/vices.gd")
const Hymn := preload("res://scripts/hub/hymn.gd")
const Obsession := preload("res://scripts/hub/obsession.gd")
const Romance := preload("res://scripts/hub/romance.gd")
const CELL := Vector2i(960, 540)

var out := "user://hud_shots"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		out = a
	DirAccess.make_dir_recursive_absolute(out)
	preload("res://scripts/run/tutorial.gd").settings_path = "user://shots_settings.cfg"
	var run_node: Node = load("res://scenes/run.tscn").instantiate()
	run_node.armory_path = "user://shots_hud_armory.cfg"
	run_node.npc_path = "user://shots_hud_npcs.cfg"
	var progress := ConfigFile.new()
	progress.set_value("progress", "cleared", ["level2"])
	progress.save(run_node.armory_path)
	root.add_child(run_node)
	_go.call_deferred(run_node)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _go(run_node: Node) -> void:
	await _frames(90)
	Vices.reset()
	Hymn.reset()
	Obsession.reset()
	run_node.hush_pull.triggers._next = INF
	var state: ConfigFile = run_node.npc_talk.state
	state.set_value("ophelia", "met", true)
	Romance.add(state, "ophelia", 72)
	state.set_value("ophelia", "status", "together")
	Vices.hold = Vices.MAX_HOLD
	run_node.hush_pull.roam = 150.0
	Hymn.level = 34.0
	Hymn.gear = ["headphones", "cuff"]
	Hymn.dosed_today = true
	Obsession.meter = 50.0
	Obsession.keepsake = 24.0
	var sheet := Image.create(CELL.x * 2, CELL.y, false, Image.FORMAT_RGBA8)
	await _frames(40)
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(CELL.x, CELL.y)
	sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i.ZERO)
	run_node.start_run(7)
	await _frames(160)
	img = root.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(CELL.x, CELL.y)
	sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x, 0))
	sheet.save_png(out.path_join("hud.png"))
	print("wrote hud.png")
	Vices.reset()
	Hymn.reset()
	Hymn.save()
	Obsession.reset()
	Obsession.save()
	quit()
