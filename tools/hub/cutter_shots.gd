extends SceneTree
## Cutter (cutter.gd, cutter_model.gd) and his scenes (cutter_scene.gd) in the
## hub: Cutter front, three-quarter and side (top row); the catch: his hand at
## her head, through her eyes as the needle comes in, the red, and the change
## coming on (her second catch: the wiring) (middle row); and the crash, the
## colour going, down on the floor, shaking (bottom row).
##   godot --path . --resolution 1280x720 -s res://tools/hub/cutter_shots.gd -- <out_dir>
## Needs a renderer (not --headless). Writes <out_dir>/cutter.png.

const Vices := preload("res://scripts/hub/vices.gd")
const Redline := preload("res://scripts/hub/redline.gd")
const CutterModel := preload("res://scripts/hub/cutter_model.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")
const CELL := Vector2i(640, 360)

var out := "user://cutter_shots"
var run_node: Node


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		out = a
	DirAccess.make_dir_recursive_absolute(out)
	preload("res://scripts/run/tutorial.gd").settings_path = "user://shots_settings.cfg"
	ContentRating.set_rating("M", false)
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.armory_path = "user://shots_cutter_armory.cfg"
	root.add_child(run_node)
	_go.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _grab(sheet: Image, i: int) -> void:
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.convert(Image.FORMAT_RGBA8)
	img.resize(CELL.x, CELL.y)
	sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * (i % 4), CELL.y * (i / 4)))


func _go() -> void:
	await _frames(90)
	Vices.reset()
	Redline.reset()
	run_node.hush_pull.triggers._next = INF
	for c in root.find_children("*", "Control", true, false):
		if c.get_script() != null and String(c.get_script().resource_path).ends_with("whisper_caption.gd"):
			c.visible = false
	var p: Node3D = run_node.player
	var sheet := Image.create(CELL.x * 4, CELL.y * 3, false, Image.FORMAT_RGBA8)
	# Cutter on his own, on the puppet, in the open
	var c := preload("res://scripts/hub/cutter.gd").create(run_node, p.global_position + Vector3(0, 0, -6))
	run_node.zone_root.add_child(c)
	c.set_physics_process(false)
	await _frames(5)
	run_node.hud.visible = false
	run_node.pilot_hud.visible = false
	var cam := Camera3D.new()
	run_node.add_child(cam)
	cam.make_current()
	var at := c.global_position + Vector3(0, 1.0, 0)
	var fwd := -c.global_basis.z
	var right := fwd.cross(Vector3.UP)
	var views := [fwd * 3.2, (fwd + right).normalized() * 3.2, right * 3.2, fwd * 1.1 + Vector3(0, 0.65, 0)]
	for i in 4:
		cam.fov = 40 if i < 3 else 30
		cam.look_at_from_position(at + views[i] + Vector3(0, 0.25, 0), at + (Vector3(0, 0.62, 0) if i == 3 else Vector3.ZERO))
		await _frames(8)
		_grab(sheet, i)
	c.queue_free()
	cam.queue_free()
	run_node.hud.visible = true
	run_node.pilot_hud.visible = true
	await _frames(3)
	# the catch: her second, so the wiring comes on
	Redline.catches = 1
	var scene: Node = run_node.cutter_scene
	run_node.cutter_now()
	var times := [1.0, 2.9, 3.75, 6.6]
	for i in 4:
		while scene.t < times[i]:
			await process_frame
		_grab(sheet, 4 + i)
	while scene.busy():
		await process_frame
	# the crash
	Redline.high_left = 0.05
	while not scene.busy():
		await process_frame
	var crash_times := [0.6, 2.4, 4.2, 6.4]
	for i in 4:
		while scene.t < crash_times[i]:
			await process_frame
		_grab(sheet, 8 + i)
	while scene.busy():
		await process_frame
	sheet.save_png(out.path_join("cutter.png"))
	print("wrote cutter.png")
	Redline.reset()
	Redline.save()
	quit()