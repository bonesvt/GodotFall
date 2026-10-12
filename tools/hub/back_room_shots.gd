extends SceneTree
## The back room Marrow had made up for her (hush_den.gd _back_room): the cot,
## the water and his note, the IV stand with its bag of Hush glowing violet.
## Top row: the line capped and coiled on the blanket (his Hold lower), wide
## and close. Bottom row: the line run down to where her arm lay, the tape on
## its end (his Hold deep), wide and close.
##   godot --path . --resolution 1280x720 -s res://tools/hub/back_room_shots.gd -- <out_dir>
## Needs a renderer (not --headless). Writes <out_dir>/back_room.png.

const HushDen := preload("res://scripts/hub/hush_den.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")
const CELL := Vector2i(640, 360)

var out := "user://back_room_shots"
var run_node: Node


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		out = a
	DirAccess.make_dir_recursive_absolute(out)
	preload("res://scripts/run/tutorial.gd").settings_path = "user://shots_settings.cfg"
	ContentRating.set_rating("M", false)
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.armory_path = "user://shots_back_room_armory.cfg"
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
	run_node.place_player(HushDen.BACK_ROOM + Vector3(0, 0, 60))
	var iv: Dictionary = run_node.zone_info["hush"]["iv"]
	var cot := HushDen.BACK_WAKE + Vector3(-0.35, 0, 0.1)
	var r := HushDen.BACK_ROOM
	var views := [[r + Vector3(1.35, 1.75, -1.35), cot + Vector3(-0.1, 0.55, 0.3)], [cot + Vector3(0.55, 1.15, -0.35), cot + Vector3(-0.2, 0.55, 0.15)]]
	var cam := Camera3D.new()
	cam.fov = 60
	run_node.add_child(cam)
	cam.make_current()
	var sheet := Image.create(CELL.x * 2, CELL.y * 2, false, Image.FORMAT_RGBA8)
	for row in 2:
		HushDen.show_iv(iv, "capped" if row == 0 else "taped")
		for col in 2:
			cam.look_at_from_position(views[col][0], views[col][1])
			await _frames(10)
			var img := root.get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			img.convert(Image.FORMAT_RGBA8)
			img.resize(CELL.x, CELL.y)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * col, CELL.y * row))
	sheet.save_png(out.path_join("back_room.png"))
	print("wrote back_room.png")
	quit()