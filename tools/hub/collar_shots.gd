extends SceneTree
## The detention collar's fitting (fitting_scene.gd): Eco on her own (top row,
## the close-up on her throat), then with Ophelia across from her (bottom row,
## through Eco's eyes).
##   godot --path . --resolution 1280x720 -s res://tools/hub/collar_shots.gd -- <out_dir>
## Needs a renderer (not --headless). Writes <out_dir>/collar.png.

const Vices := preload("res://scripts/hub/vices.gd")
const Hymn := preload("res://scripts/hub/hymn.gd")
const HubGrip := preload("res://scripts/hub/hub_grip.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")
const CELL := Vector2i(640, 360)
const TIMES := [[3.6, 6.2, 7.9], [1.6, 5.6, 7.9]]

var out := "user://collar_shots"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		out = a
	DirAccess.make_dir_recursive_absolute(out)
	preload("res://scripts/run/tutorial.gd").settings_path = "user://shots_settings.cfg"
	ContentRating.set_rating("M", false)
	var run_node: Node = load("res://scenes/run.tscn").instantiate()
	run_node.armory_path = "user://shots_collar_armory.cfg"
	run_node.npc_path = "user://shots_collar_npcs.cfg"
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
	HubGrip.reset()
	run_node.hush_pull.triggers._next = INF
	for c in root.find_children("*", "Control", true, false):
		if c.get_script() != null and String(c.get_script().resource_path).ends_with("whisper_caption.gd"):
			c.visible = false
	var sheet := Image.create(CELL.x * 3, CELL.y * 2, false, Image.FORMAT_RGBA8)
	var scene: Node = run_node.fitting_scene
	for row in 2:
		Hymn.gear = ["headphones", "cuff", "bell", "collar"]
		if row == 0:
			scene.play("collar")
		else:
			HubGrip.gear = {"ophelia": ["headphones", "bell", "collar"]}
			scene.play("collar", "ophelia", "collar")
		for col in 3:
			while scene.t < TIMES[row][col]:
				await process_frame
			var img := root.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			img.resize(CELL.x, CELL.y)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * col, CELL.y * row))
		while scene.busy():
			await process_frame
	sheet.save_png(out.path_join("collar.png"))
	print("wrote collar.png")
	Hymn.reset()
	Hymn.save()
	HubGrip.reset()
	HubGrip.save()
	quit()