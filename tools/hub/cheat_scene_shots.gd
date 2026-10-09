extends SceneTree
## The cheat box's control items (cheat_scene.gd), one row each: she finds it,
## it takes hold (its close shot), and the voice as the colour comes up.
## TAKE ALL, the colony case, Glass Rush, Ophelia's ECO pack, Mom's dose box,
## the Family Plan, and Biggie's toolkit (on her in all of it).
##   godot --path . --resolution 1280x720 -s res://tools/hub/cheat_scene_shots.gd -- <out_dir>
## Needs a renderer (not --headless). Writes <out_dir>/cheat_scenes.png.

const Vices := preload("res://scripts/hub/vices.gd")
const Hymn := preload("res://scripts/hub/hymn.gd")
const Glass := preload("res://scripts/hub/glass.gd")
const Obsession := preload("res://scripts/hub/obsession.gd")
const HubGrip := preload("res://scripts/hub/hub_grip.gd")
const CELL := Vector2i(640, 360)
const ITEMS := ["hymn", "set", "glass", "keepsake", "dosebox", "family", "toolkit"]
const TIMES := [1.2, 4.2, 6.6]

var out := "user://cheat_scene_shots"
var run_node: Node


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		out = a
	DirAccess.make_dir_recursive_absolute(out)
	preload("res://scripts/run/tutorial.gd").settings_path = "user://shots_settings.cfg"
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.armory_path = "user://shots_cheatscene_armory.cfg"
	run_node.npc_path = "user://shots_cheatscene_npcs.cfg"
	var progress := ConfigFile.new()
	progress.set_value("progress", "cleared", ["level2"])
	progress.save(run_node.armory_path)
	root.add_child(run_node)
	_go.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _go() -> void:
	await _frames(90)
	run_node.hush_pull.triggers._next = INF
	for c in root.find_children("*", "Control", true, false):
		if c.get_script() != null and String(c.get_script().resource_path).ends_with("whisper_caption.gd"):
			c.visible = false
	var scene: Node = run_node.cheat_scene
	var sheet := Image.create(CELL.x * 3, CELL.y * ITEMS.size(), false, Image.FORMAT_RGBA8)
	for row in ITEMS.size():
		Vices.reset()
		Hymn.reset()
		HubGrip.reset()
		Glass.reset()
		Obsession.reset()
		run_node.dress_hub()
		var p: Node3D = run_node.player
		if ITEMS[row] == "toolkit":  # everything on her first, for Biggie to take off
			Hymn.gear = Hymn.GEAR.duplicate()
			Glass.glass = Glass.MAX_GLASS
			Vices.hold = 80.0
		preload("res://scripts/hub/wardrobe.gd").dress_eco(p, true)  # off with the last row's gear
		await _frames(3)
		p.rotation.y = 0.6
		scene.play(ITEMS[row])
		for col in 3:
			while scene.t < TIMES[col]:
				await process_frame
			var img := root.get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			img.convert(Image.FORMAT_RGBA8)
			img.resize(CELL.x, CELL.y)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * col, CELL.y * row))
		while scene.busy():
			await process_frame
		await _frames(5)
	sheet.save_png(out.path_join("cheat_scenes.png"))
	print("wrote cheat_scenes.png")
	Vices.reset()
	Vices.save()
	Hymn.reset()
	Hymn.save()
	HubGrip.reset()
	HubGrip.save()
	Glass.reset()
	Glass.save()
	Obsession.reset()
	Obsession.save()
	quit()