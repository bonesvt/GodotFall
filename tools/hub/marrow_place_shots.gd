extends SceneTree
## Marrow the shadow man where he is (hush_den.gd): in his alley gap off Low
## Row, from the street and up close, and in his basement armchair, from the
## stairs and from in front.
##   godot --path . --resolution 1280x720 -s res://tools/hub/marrow_place_shots.gd -- <out_dir>
## Needs a renderer (not --headless). Writes <out_dir>/marrow_places.png.

const HushDen := preload("res://scripts/hub/hush_den.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")
const CELL := Vector2i(640, 360)

var out := "user://marrow_place_shots"
var run_node: Node


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		out = a
	DirAccess.make_dir_recursive_absolute(out)
	preload("res://scripts/run/tutorial.gd").settings_path = "user://shots_settings.cfg"
	ContentRating.set_rating("M", false)
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.armory_path = "user://shots_marrow_armory.cfg"
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
	var him := HushDen.ALLEY + Vector3(-0.6, 0, -0.2)
	var views := [
		[him + Vector3(5.5, 1.6, -1.6), him + Vector3(0, 1.2, 0)],
		[him + Vector3(1.3, 1.6, -0.45), him + Vector3(0, 1.5, 0)],
	]
	var seated: Node3D = null
	for n in run_node.find_children("*", "Node3D", true, false):
		if n.get_child_count() > 0 and n.get_children().any(func(c): return c is GPUParticles3D) and n.global_position.y < -5.0:
			seated = n
	if seated != null:
		var at := seated.global_position
		var fwd := -seated.global_basis.z
		views.append([at + fwd * 1.9 + Vector3(1.1, 1.4, 0), at + Vector3(0, 0.8, 0)])
		views.append([at + fwd * 0.9 + Vector3(-0.35, 1.15, 0), at + Vector3(0, 1.2, 0)])
	run_node.place_player(him + Vector3(0, 0, 60))
	var cam := Camera3D.new()
	cam.fov = 50
	run_node.add_child(cam)
	cam.make_current()
	var sheet := Image.create(CELL.x * 2, CELL.y * 2, false, Image.FORMAT_RGBA8)
	for i in views.size():
		cam.look_at_from_position(views[i][0], views[i][1])
		await _frames(30)
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.convert(Image.FORMAT_RGBA8)
		img.resize(CELL.x, CELL.y)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * (i % 2), CELL.y * (i / 2)))
	sheet.save_png(out.path_join("marrow_places.png"))
	print("wrote marrow_places.png ", views.size())
	quit()