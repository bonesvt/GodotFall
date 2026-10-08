extends SceneTree
## Stills from the fittings in the dispensary's back room (fitting_scene.gd):
## for each piece of the Shepherd's gear, the arm coming down, the fitting
## itself and the moment it locks, one row a piece.
##   godot --path . --resolution 1280x720 -s res://tools/hub/fitting_shots.gd -- <out_dir>
## Needs a renderer (not --headless). Writes <out_dir>/fitting_scenes.png.

const Vices := preload("res://scripts/hub/vices.gd")
const Hymn := preload("res://scripts/hub/hymn.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")
const CELL := Vector2i(640, 360)
## When to grab each piece's three stills (seconds into its fitting).
const TIMES := {"headphones": [2.4, 6.0, 7.9], "cuff": [2.4, 5.4, 7.9], "visor": [2.4, 5.9, 8.2],
	"bridge": [2.4, 6.0, 7.9], "film": [3.6, 5.6, 7.9], "gloves": [2.4, 5.6, 7.9], "spine": [2.4, 5.8, 7.9]}

var out := "user://fitting_shots"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		out = a
	DirAccess.make_dir_recursive_absolute(out)
	preload("res://scripts/run/tutorial.gd").settings_path = "user://shots_settings.cfg"
	ContentRating.set_rating("M", false)
	var run_node: Node = load("res://scenes/run.tscn").instantiate()
	run_node.armory_path = "user://shots_fitting_armory.cfg"
	root.add_child(run_node)
	_go.call_deferred(run_node)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _go(run_node: Node) -> void:
	await _frames(90)
	Vices.reset()
	Hymn.reset()
	run_node.hush_pull.triggers._next = INF
	var sheet := Image.create(CELL.x * 3, CELL.y * Hymn.GEAR.size(), false, Image.FORMAT_RGBA8)
	var scene: Node = run_node.fitting_scene
	for row in Hymn.GEAR.size():
		var piece: String = Hymn.GEAR[row]
		Hymn.gear.append(piece)  # as Hymn.processed() does before the fitting
		scene.play(piece)
		for col in 3:
			while scene.t < TIMES[piece][col]:
				await process_frame
			var img := root.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			img.resize(CELL.x, CELL.y)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * col, CELL.y * row))
			print("shot ", piece, " ", col)
		while scene.busy():
			await process_frame
	sheet.save_png(out.path_join("fitting_scenes.png"))
	print("wrote fitting_scenes.png")
	Hymn.reset()
	Hymn.save()
	quit()
