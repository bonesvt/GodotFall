extends SceneTree
## Leaving Marrow's storeroom (hush_den.gd, leave_pull.gd), in first person:
## the room as she comes to and the whole room (the cuffs on their hook, violet
## under the door, the empty vial), then holding [F] to leave with his pull low (her view pulled
## partway to the glow) and deep (stopped short, his voice through the door).
##   godot --path . --resolution 1280x720 -s res://tools/hub/store_leave_shots.gd -- <out_dir>
## Needs a renderer (not --headless). Writes <out_dir>/store_leave.png.

const HushDen := preload("res://scripts/hub/hush_den.gd")
const Vices := preload("res://scripts/hub/vices.gd")
const LeavePull := preload("res://scripts/hub/leave_pull.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")
const CELL := Vector2i(640, 360)

var out := "user://store_leave_shots"
var run_node: Node


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		out = a
	DirAccess.make_dir_recursive_absolute(out)
	preload("res://scripts/run/tutorial.gd").settings_path = "user://shots_settings.cfg"
	ContentRating.set_rating("M", false)
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.armory_path = "user://shots_store_armory.cfg"
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
	sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * (i % 2), CELL.y * (i / 2)))


func _go() -> void:
	await _frames(90)
	run_node.hush_pull.triggers._next = INF
	for c in root.find_children("*", "Control", true, false):
		if c.get_script() != null and String(c.get_script().resource_path).ends_with("whisper_caption.gd"):
			c.visible = false
	Vices.hold = 50.0
	var p: Node3D = run_node.player
	var door := HushDen.STORE_DOOR_OUT
	run_node.place_player(HushDen.STORE_WAKE)
	await _frames(5)
	var to := door - p.global_position
	p.rotation.y = atan2(-to.x, -to.z) + 0.25
	p.head.rotation.x = -0.1
	run_node.hud.toast(HushDen.STORE_LINE, 30.0)
	var sheet := Image.create(CELL.x * 2, CELL.y * 2, false, Image.FORMAT_RGBA8)
	await _frames(20)
	_grab(sheet, 0)
	# the room from the shelves' corner: the door, the glow under it, the cuffs, the vial
	var cam := Camera3D.new()
	cam.fov = 70
	run_node.add_child(cam)
	cam.look_at_from_position(HushDen.STORE_ROOM + Vector3(-1.3, 2.1, 0.55), door + Vector3(0.3, 0.7, 0.2))
	cam.make_current()
	run_node.hud.visible = false
	await _frames(10)
	_grab(sheet, 1)
	run_node.hud.visible = true
	cam.queue_free()
	p.camera.make_current()
	p.rotation.y -= 0.25
	p.head.rotation.x = -0.1
	await _frames(5)
	for i in 2:
		Vices.hold = 40.0 if i == 0 else 90.0
		var lp := LeavePull.new(run_node)
		run_node.add_child(lp)
		await _frames(2)
		lp.set_process(false)
		lp.progress = 0.55 if i == 0 else lp.CANT_REACH
		var pull := clampf(lp.progress * (0.6 + Vices.hold / 100.0 * 0.6), 0.0, 1.0)
		lp._aim(pull, 0.016)
		(lp._rect.material as ShaderMaterial).set_shader_parameter("pull", pull)
		var w: Vector2 = root.get_visible_rect().size
		lp._bar.size = Vector2(320.0 * lp.progress, 6)
		lp._bar.position = Vector2(w.x * 0.5 - 160.0, w.y - 120.0)
		run_node.hud.toast(HushDen.STORE_THROUGH_DOOR if i == 1 else "Her hand's on the key.", 30.0)
		await _frames(8)
		_grab(sheet, 2 + i)
		lp.cancel()
		await _frames(2)
	sheet.save_png(out.path_join("store_leave.png"))
	print("wrote store_leave.png")
	Vices.reset()
	Vices.save()
	quit()