extends SceneTree
## The clarity visor's view in the hub (visor_screen.gd): through the curved
## glass with the tunnel behind the orders (top left), the watching eye opening
## (top right), a glitch tearing it (bottom left), and a trigger word gripping
## her (bottom right).
##   godot --path . --resolution 1280x720 -s res://tools/hub/visor_hud_shots.gd -- <out_dir>
## Needs a renderer (not --headless). Writes <out_dir>/visor_hud.png.

const Vices := preload("res://scripts/hub/vices.gd")
const Hymn := preload("res://scripts/hub/hymn.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")
const CELL := Vector2i(960, 540)

var out := "user://visor_hud_shots"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		out = a
	DirAccess.make_dir_recursive_absolute(out)
	preload("res://scripts/run/tutorial.gd").settings_path = "user://shots_settings.cfg"
	ContentRating.set_rating("M", false)
	var run_node: Node = load("res://scenes/run.tscn").instantiate()
	run_node.armory_path = "user://shots_visor_hud_armory.cfg"
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
	var sheet := Image.create(CELL.x * 2, CELL.y * 2, false, Image.FORMAT_RGBA8)
	for i in 4:
		visor._next_eye = 99.0
		visor._next_tear = 99.0
		visor._eye_t = -1.0
		Vices.entranced = i == 3
		match i:
			1:
				visor._eye_t = 1.2
			2:
				visor._glitch = 0.12
		await _frames(2 if i == 2 else 20)
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.resize(CELL.x, CELL.y)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * (i % 2), CELL.y * (i / 2)))
	Vices.entranced = false
	sheet.save_png(out.path_join("visor_hud.png"))
	print("wrote visor_hud.png")
	Hymn.reset()
	Hymn.save()
	quit()