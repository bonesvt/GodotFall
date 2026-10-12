extends SceneTree
## Eco's gun stance on a run (eco_gun_stance.gd) without and with the colony's
## comfort gloves (hymn.gd), which lock her hands together on her one-handed
## pistol. Side by side, from the front three-quarter.
##   godot --path . --resolution 1280x720 -s res://tools/hub/glove_grip_shots.gd -- <out_dir>
## Needs a renderer (not --headless). Writes <out_dir>/glove_grip.png.

const Vices := preload("res://scripts/hub/vices.gd")
const Hymn := preload("res://scripts/hub/hymn.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")
const CELL := Vector2i(640, 720)

var out := "user://glove_grip_shots"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		out = a
	DirAccess.make_dir_recursive_absolute(out)
	preload("res://scripts/run/tutorial.gd").settings_path = "user://shots_settings.cfg"
	ContentRating.set_rating("M", false)
	var run_node: Node = load("res://scenes/run.tscn").instantiate()
	run_node.armory_path = "user://shots_glove_armory.cfg"
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
	run_node.start_run(7)
	await _frames(60)
	for g in run_node.get_tree().get_nodes_in_group("enemies"):
		(g as Node3D).process_mode = Node.PROCESS_MODE_DISABLED
		(g as Node3D).global_position += Vector3(0, -500, 0)
	var player: Node3D = run_node.player
	var view: Node = player.get_node_or_null("ViewCam")
	if view != null:
		view.set_third_person(true)
	run_node.hud.visible = false
	run_node.pilot_hud.visible = false
	var cam := Camera3D.new()
	run_node.add_child(cam)
	var sheet := Image.create(CELL.x * 2, CELL.y, false, Image.FORMAT_RGBA8)
	var win := Vector2(root.get_texture().get_size())
	var cw := int(win.y * CELL.x / CELL.y)
	for i in 2:
		Hymn.gear = ["gloves"] if i == 1 else []
		run_node.Wardrobe.dress_eco(player, true)
		await _frames(50)
		var fwd := -player.global_basis.z
		var right := player.global_basis.x
		var at := player.global_position + Vector3(0, 1.25, 0)
		cam.fov = 34
		cam.look_at_from_position(at + fwd * 2.4 + right * 1.3 + Vector3(0, 0.15, 0), at)
		cam.make_current()
		await _frames(8)
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img = img.get_region(Rect2i(int((win.x - cw) * 0.5), 0, cw, int(win.y)))
		img.resize(CELL.x, CELL.y)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * i, 0))
	sheet.save_png(out.path_join("glove_grip.png"))
	print("wrote glove_grip.png")
	Hymn.reset()
	Hymn.save()
	quit()
