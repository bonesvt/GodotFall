extends SceneTree
## The clarity visor on a run (visor_friends.gd): first person, grunts drawn as
## Ophelia, Mom and Biggie with FRIEND tags; then the same grunt torn back to
## itself for a moment by a hit.
##   godot --path . --resolution 1280x720 -s res://tools/hub/visor_friends_shots.gd -- <out_dir>
## Needs a renderer (not --headless). Writes <out_dir>/visor_friends.png.

const Vices := preload("res://scripts/hub/vices.gd")
const Hymn := preload("res://scripts/hub/hymn.gd")
const CELL := Vector2i(960, 540)

var out := "user://visor_friends_shots"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		out = a
	DirAccess.make_dir_recursive_absolute(out)
	preload("res://scripts/run/tutorial.gd").settings_path = "user://shots_settings.cfg"
	var run_node: Node = load("res://scenes/run.tscn").instantiate()
	run_node.armory_path = "user://shots_visor_armory.cfg"
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
	run_node.start_run(7)
	await _frames(60)
	var player: Node3D = run_node.player
	var grunts: Array = run_node.get_tree().get_nodes_in_group("enemies").filter(func(g): return g.get("model") != null)
	# line three of them up in front of her, facing her
	var fwd := -player.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var side := fwd.cross(Vector3.UP)
	for i in mini(3, grunts.size()):
		var g: Node3D = grunts[i]
		g.set_physics_process(false)
		g.process_mode = Node.PROCESS_MODE_DISABLED
		g.global_position = player.global_position + fwd * (3.2 + i * 0.6) + side * (float(i) - 1.0) * 1.3 + Vector3(0, -0.05, 0)
		g.look_at(Vector3(player.global_position.x, g.global_position.y, player.global_position.z), Vector3.UP)
	for i in range(3, grunts.size()):
		(grunts[i] as Node3D).global_position += Vector3(0, -500, 0)  # the rest out of the shot
	var sheet := Image.create(CELL.x * 2, CELL.y, false, Image.FORMAT_RGBA8)
	await _frames(40)
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(CELL.x, CELL.y)
	sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i.ZERO)
	if not grunts.is_empty():
		grunts[1 if grunts.size() > 1 else 0].set_meta("visor_tear", 5.0)
	await _frames(6)
	img = root.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(CELL.x, CELL.y)
	sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x, 0))
	sheet.save_png(out.path_join("visor_friends.png"))
	print("wrote visor_friends.png")
	Hymn.reset()
	Hymn.save()
	quit()
