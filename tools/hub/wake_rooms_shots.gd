extends SceneTree
## Two of Marrow's wake-up rooms (hush_den.gd): his grimy bathroom, toward the
## toilet and the smoke in the mirror, then her phone on the floor; and his
## storeroom, its shelves of tins, then the cuffs on their hook by the door.
##   godot --path . --resolution 1280x720 -s res://tools/hub/wake_rooms_shots.gd -- <out_dir>
## Needs a renderer (not --headless). Writes <out_dir>/wake_rooms.png.

const HushDen := preload("res://scripts/hub/hush_den.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")
const CELL := Vector2i(640, 360)

var out := "user://wake_rooms_shots"
var run_node: Node


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		out = a
	DirAccess.make_dir_recursive_absolute(out)
	preload("res://scripts/run/tutorial.gd").settings_path = "user://shots_settings.cfg"
	ContentRating.set_rating("M", false)
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.armory_path = "user://shots_wake_rooms_armory.cfg"
	root.add_child(run_node)
	_go.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _go() -> void:
	await _frames(90)
	run_node.hush_pull.triggers._next = INF
	run_node.hud.visible = false
	run_node.pilot_hud.visible = false
	for c in root.find_children("*", "Control", true, false):
		if c.get_script() != null and String(c.get_script().resource_path).ends_with("whisper_caption.gd"):
			c.visible = false
	run_node.place_player(HushDen.BATH_ROOM + Vector3(0, 0, 60))
	var b := HushDen.BATH_ROOM
	var s := HushDen.STORE_ROOM
	var hook := HushDen.STORE_DOOR_OUT + Vector3(0.45, 1.5, 0.75)
	var views := [
		[b + Vector3(0.9, 1.5, -1.1), b + Vector3(-0.1, 0.8, 1.0)],
		[b + Vector3(0.15, 0.55, -0.15), b + Vector3(-0.1, 0.0, 0.3)],
		[s + Vector3(1.1, 1.6, -1.0), s + Vector3(-0.4, 0.9, 1.0)],
		[hook + Vector3(-0.7, 0.05, -0.2), hook + Vector3(0, -0.12, 0)],
	]
	var cam := Camera3D.new()
	cam.fov = 62
	run_node.add_child(cam)
	cam.make_current()
	var sheet := Image.create(CELL.x * 2, CELL.y * 2, false, Image.FORMAT_RGBA8)
	for i in views.size():
		cam.look_at_from_position(views[i][0], views[i][1])
		await _frames(10)
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.convert(Image.FORMAT_RGBA8)
		img.resize(CELL.x, CELL.y)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * (i % 2), CELL.y * (i / 2)))
	sheet.save_png(out.path_join("wake_rooms.png"))
	print("wrote wake_rooms.png")
	quit()