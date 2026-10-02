extends SceneTree
## Screenshots of the forest level and the forest's edge, for checking the look.
##   xvfb-run -a godot --path . -s res://tools/forest/shots.gd -- [out_dir]
## Needs a renderer (not --headless). Writes <out_dir>/<n>-<name>.png.

const FB := preload("res://scripts/run/forest_builder.gd")

var run_node
var out := "user://forest_shots"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 1234
	run_node.start_in_hub = false
	root.add_child(run_node)
	_go.call_deferred()


func _shot(name: String, at: Vector3, look: Vector3) -> void:
	var player = run_node.player
	player.global_position = at
	player.velocity = Vector3.ZERO
	var eye := at + Vector3(0, 1.6, 0)
	var d := look - eye
	player.rotation.y = atan2(-d.x, -d.z)
	player.get_node("Head").rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
	for i in 12:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	print("shot ", name)


func _p(x_off: float, z: float, up := 0.0) -> Vector3:
	return FB._on(FB.trail_x(z) + x_off, z, up)


func _go() -> void:
	for i in 10:
		await process_frame
	run_node.hud.visible = false
	run_node.pilot_hud.visible = false
	run_node.player.process_mode = Node.PROCESS_MODE_DISABLED
	for g in run_node.zone_info["grunts"]:
		g.passive = true
	await _shot("1-spawn", _p(0, 6), _p(0, -30, 2))
	await _shot("2-picket", _p(-3, -20), _p(0, -36, 1))
	await _shot("3-wall", _p(4, -42), _p(2, -60, 4))
	await _shot("4-breach", _p(16, -52), _p(16, -70, 1))
	await _shot("5-outpost", _p(-6, -66, 7.1), _p(4, -96, 0))
	await _shot("6-ravine", _p(2, -112), _p(0, -140, 1))
	await _shot("7-ravine-side", _p(26, -118), _p(10, -136, -2))
	await _shot("7b-ravine-high", _p(-14, -110, 9.0), _p(0, -138, -4))
	await _shot("8-camp", _p(0, -160), _p(4, -190, 2))
	await _shot("9-camp-roof", _p(6, -192, 5.0), _p(-6, -175, 0))
	await _shot("10-clearing", _p(0, -228), _p(0, -250, 2))
	run_node.load_zone(3)
	run_node.player.process_mode = Node.PROCESS_MODE_DISABLED
	for i in 5:
		await process_frame
	run_node.hud.visible = false
	await _shot("11-edge", Vector3(0, 0, 34), Vector3(0, 3, -20))
	await _shot("12-edge-flank", Vector3(-30, 0, 20), Vector3(10, 2, -30))
	run_node.boss.hp = 1.0
	run_node.boss.active = true
	run_node.boss.take_damage(10.0)
	for i in 300:
		await process_frame
	run_node.hud.visible = false
	await _shot("13-evac", Vector3(24, 0, -8), FB.EVAC + Vector3(0, 9, 0))
	quit()
