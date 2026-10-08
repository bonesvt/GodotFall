extends SceneTree
## The clarity visor's inductions (visor_screen.gd INDUCTIONS), one panel each,
## caught partway through: the countdown, the stairs, the affirmations, the
## counted breath, the heavy words with her eyelids closing, the repeat.
##   godot --path . --resolution 1280x720 -s res://tools/hub/induction_shots.gd -- <out_dir>
## Needs a renderer (not --headless). Writes <out_dir>/inductions.png.

const Vices := preload("res://scripts/hub/vices.gd")
const Hymn := preload("res://scripts/hub/hymn.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")
const CELL := Vector2i(640, 360)
## Seconds into each induction to catch it.
const AT := [9.5, 6.4, 7.6, 5.5, 9.2, 8.6]

var out := "user://induction_shots"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		out = a
	DirAccess.make_dir_recursive_absolute(out)
	preload("res://scripts/run/tutorial.gd").settings_path = "user://shots_settings.cfg"
	ContentRating.set_rating("M", false)
	var run_node: Node = load("res://scenes/run.tscn").instantiate()
	run_node.armory_path = "user://shots_induction_armory.cfg"
	root.add_child(run_node)
	_go.call_deferred(run_node)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _go(run_node: Node) -> void:
	await _frames(90)
	Vices.reset()
	Hymn.reset()
	Hymn.gear = ["headphones", "cuff", "visor"]
	run_node.hush_pull.triggers._next = INF
	var visor: CanvasLayer = run_node.get_node("VisorScreen")
	for c in root.find_children("*", "Control", true, false):
		if c.get_script() != null and String(c.get_script().resource_path).ends_with("whisper_caption.gd"):
			c.visible = false
	await _frames(10)
	var sheet := Image.create(CELL.x * 3, CELL.y * 2, false, Image.FORMAT_RGBA8)
	for i in 6:
		visor._next_eye = 99.0
		visor._next_tear = 99.0
		visor._t = visor.INDUCTION * i + AT[i]
		await _frames(2)
		visor._glitch = -1.0
		visor._tear = 0.0
		await _frames(1)
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.resize(CELL.x, CELL.y)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * (i % 3), CELL.y * (i / 3)))
	sheet.save_png(out.path_join("inductions.png"))
	print("wrote inductions.png")
	Hymn.reset()
	Hymn.save()
	quit()