extends SceneTree
## Eco in first person wearing all the Shepherd's gear (colony_gear.gd), to
## check none of it hangs in front of the camera: looking ahead, looking down,
## and from outside, the same moment, to see it on her.
##   godot --path . --resolution 1280x720 -s res://tools/hub/gear_fp_shots.gd -- <out_dir>
## Needs a renderer (not --headless). Writes <out_dir>/gear_fp.png.

const Vices := preload("res://scripts/hub/vices.gd")
const Hymn := preload("res://scripts/hub/hymn.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")
const CELL := Vector2i(640, 360)

var out := "user://gear_fp_shots"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		out = a
	DirAccess.make_dir_recursive_absolute(out)
	preload("res://scripts/run/tutorial.gd").settings_path = "user://shots_settings.cfg"
	ContentRating.set_rating("M", false)
	var run_node: Node = load("res://scenes/run.tscn").instantiate()
	run_node.armory_path = "user://shots_gear_fp_armory.cfg"
	root.add_child(run_node)
	_go.call_deferred(run_node)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _go(run_node: Node) -> void:
	await _frames(90)
	Vices.reset()
	Hymn.reset()
	Hymn.gear = Hymn.GEAR.filter(func(g): return g != "visor")  # the visor's clutter would hide the view
	run_node.hush_pull.triggers._next = INF
	run_node.hud.visible = false
	run_node.pilot_hud.visible = false
	var player: Node3D = run_node.player
	run_node.Wardrobe.dress_eco(player, true)
	var sheet := Image.create(CELL.x * 3, CELL.y, false, Image.FORMAT_RGBA8)
	var head: Node3D = player.get_node("Head")
	for i in 3:
		var view: Node = player.get_node_or_null("ViewCam")
		if view != null:
			view.set_third_person(i == 2)
		head.rotation.x = [0.0, -1.0, 0.0][i]
		await _frames(20)
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.resize(CELL.x, CELL.y)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * i, 0))
	sheet.save_png(out.path_join("gear_fp.png"))
	print("wrote gear_fp.png")
	Hymn.reset()
	Hymn.save()
	quit()
