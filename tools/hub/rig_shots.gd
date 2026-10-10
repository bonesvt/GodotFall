extends SceneTree
## The Rig (rig_screen.gd) in Biggie's den: the chair under its arm, close
## and from across the den, and sat in it with its screen up.
##   godot --path . --resolution 1280x720 -s res://tools/hub/rig_shots.gd -- <out_dir>
## Needs a renderer (not --headless). Writes <out_dir>/rig.png.

const Redline := preload("res://scripts/hub/redline.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")
const CELL := Vector2i(640, 360)

var out := "user://rig_shots"
var run_node: Node
var sheet: Image


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		out = a
	DirAccess.make_dir_recursive_absolute(out)
	preload("res://scripts/run/tutorial.gd").settings_path = "user://shots_settings.cfg"
	ContentRating.set_rating("M", false)
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.armory_path = "user://shots_rig_armory.cfg"
	root.add_child(run_node)
	_go.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _grab(i: int) -> void:
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.convert(Image.FORMAT_RGBA8)
	img.resize(CELL.x, CELL.y)
	sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * (i % 2), CELL.y * (i / 2)))


func _go() -> void:
	await _frames(90)
	run_node.hush_pull.triggers._next = INF
	for c in root.find_children("*", "Control", true, false):
		if c.get_script() != null and String(c.get_script().resource_path).ends_with("whisper_caption.gd"):
			c.visible = false
	sheet = Image.create(CELL.x * 2, CELL.y * 2, false, Image.FORMAT_RGBA8)
	var spot := {}
	for s in run_node.zone_info["interactables"]:
		if s["id"] == "redline_rig":
			spot = s
	var chair: Vector3 = spot["pos"] - Vector3(0, 0, 0.85)
	var p: Node3D = run_node.player
	run_node.place_player(chair + Vector3(1.6, 0.1, 3.5))
	run_node.hud.visible = false
	run_node.pilot_hud.visible = false
	var cam := Camera3D.new()
	run_node.add_child(cam)
	cam.make_current()
	cam.fov = 50
	cam.look_at_from_position(chair + Vector3(-1.1, 1.6, 2.6), chair + Vector3(0, 0.9, 0))
	await _frames(12)
	_grab(0)
	cam.fov = 36
	cam.look_at_from_position(chair + Vector3(0.9, 1.4, 1.4), chair + Vector3(0, 1.0, -0.1))
	await _frames(8)
	_grab(1)
	# Eco sat in it, the arm over her (third person, as the screen opens)
	run_node._rig_sit(true)
	p.get_node("ViewCam").set_third_person(true)
	cam.fov = 44
	cam.look_at_from_position(chair + Vector3(1.4, 1.5, 2.4), chair + Vector3(0, 1.0, 0.3))
	await _frames(10)
	_grab(2)
	# the Rig's screen, a few charges in her
	cam.queue_free()
	Redline.reset()
	Redline.charges = 3
	Redline.mods = ["cat_ears", "tail"]
	run_node.open_bench("rig")
	await _frames(20)
	_grab(3)
	run_node.close_bench()
	sheet.save_png(out.path_join("rig.png"))
	print("wrote rig.png")
	Redline.reset()
	Redline.save()
	quit()
