extends SceneTree
## Stills from the cheat box's Super Hush scene (super_hush_scene.gd) in the
## hub: the injector coming up, it going in, the close-up, the flood.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 -s res://tools/hub/super_hush_shots.gd -- <out_dir>
## Needs a renderer (not --headless). Writes <out_dir>/super_hush_scene.png.

const Vices := preload("res://scripts/hub/vices.gd")
const TIMES := [1.6, 2.1, 4.0, 6.6]
const SIZE := Vector2i(640, 360)

var out := "user://super_hush_shots"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		out = a
	DirAccess.make_dir_recursive_absolute(out)
	preload("res://scripts/run/tutorial.gd").settings_path = "user://shots_settings.cfg"
	root.size = Vector2i(1280, 720)
	var run_node: Node = load("res://scenes/run.tscn").instantiate()
	run_node.armory_path = "user://shots_armory.cfg"
	root.add_child(run_node)
	_go.call_deferred(run_node)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _go(run_node: Node) -> void:
	await _frames(60)
	Vices.reset()
	run_node.hud.visible = false
	# the town is far off and slow to draw in software GL: off for the stills
	for n in ["Town", "Townsfolk"]:
		var far: Node = run_node.zone_root.get_node_or_null(n)
		if far != null:
			far.queue_free()
	run_node.open_bench("cheats")
	await _frames(2)
	run_node.bench.super_hush()
	await _frames(2)
	var scene: Node = run_node.super_hush_scene
	var sheet := Image.create(SIZE.x * 2, SIZE.y * 2, false, Image.FORMAT_RGBA8)
	for i in TIMES.size():
		while scene.t < TIMES[i]:
			await process_frame
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.resize(SIZE.x, SIZE.y)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, SIZE), Vector2i(SIZE.x * (i % 2), SIZE.y * (i / 2)))
		print("shot ", i)
	sheet.save_png(out.path_join("super_hush_scene.png"))
	print("wrote super_hush_scene.png")
	quit()
