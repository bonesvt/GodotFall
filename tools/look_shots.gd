extends SceneTree
## Side-by-side screenshots of the PS3 look and the old PS2 look (F9) in the
## hub, the forest and the forest's edge, for checking texture and lighting work.
##   xvfb-run -a godot --path . -s res://tools/look_shots.gd -- [out_dir] [--ps3-only] [--only=hub,forest,edge]
## Needs a renderer (not --headless). Writes <out_dir>/<view>_ps3.png and _ps2.png.

const FB := preload("res://scripts/run/forest_builder.gd")

var run_node
var out := "user://look_shots"
var looks := [false, true]
## Sections to shoot (hub, forest, edge); empty = all.
var only: Array[String] = []
var ps2: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a == "--ps3-only":
			looks = [false]
		elif a.begins_with("--only="):
			only.assign(a.trim_prefix("--only=").split(","))
		elif not a.begins_with("--"):
			out = a
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1600, 900)
	ps2 = root.get_node_or_null("PS2")
	if ps2 == null:
		ps2 = load("res://scripts/ps2/ps2_screen.gd").new()
		ps2.name = "PS2"
		root.add_child(ps2)
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 1234
	root.add_child(run_node)
	_go.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String, at: Vector3, look: Vector3) -> void:
	var player = run_node.player
	player.global_position = at
	player.velocity = Vector3.ZERO
	var eye := at + Vector3(0, 1.6, 0)
	var d := look - eye
	player.rotation.y = atan2(-d.x, -d.z)
	player.get_node("Head").rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
	for on in looks:
		ps2.set_enabled(on)
		await _frames(6)
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(out.path_join("%s_%s.png" % [name, "ps2" if on else "ps3"]))
		print("shot ", name, " ps2" if on else " ps3")
	ps2.set_enabled(false)


func _hide_hud() -> void:
	for n in ["hud", "pilot_hud"]:
		if n in run_node and run_node.get(n) != null:
			run_node.get(n).visible = false
	run_node.player.process_mode = Node.PROCESS_MODE_DISABLED


func _p(x_off: float, z: float, up := 0.0) -> Vector3:
	return FB._on(FB.trail_x(z) + x_off, z, up)


func _go() -> void:
	await _frames(20)
	_hide_hud()
	if only.is_empty() or "hub" in only:
		await _hub()
	if only.is_empty() or "forest" in only:
		await _forest()
	if only.is_empty() or "edge" in only:
		await _edge()
	quit()


func _hub() -> void:
	await _shot("hub-temple", Vector3(0, 0.1, 4.5), Vector3(0, 3, -20))
	await _shot("hub-bench", Vector3(8.2, 1.2, 1.2), Vector3(11, 2.0, 0.4))
	await _shot("hub-yard", Vector3(-13, 0.2, 33), Vector3(-16, 3.5, 47))


func _forest() -> void:
	run_node.start_run(1234)
	await _frames(20)
	_hide_hud()
	for g in run_node.zone_info.get("grunts", []):
		g.passive = true
	await _shot("forest-spawn", _p(0, 6), _p(0, -30, 2))
	await _shot("forest-wall", _p(4, -42), _p(2, -60, 4))
	await _shot("forest-outpost", _p(-6, -66, 7.1), _p(4, -96, 0))
	await _shot("forest-camp", _p(0, -160), _p(4, -190, 2))


func _edge() -> void:
	if run_node.run == null:
		run_node.start_run(1234)
	run_node.load_zone(3)
	await _frames(10)
	_hide_hud()
	await _shot("edge", Vector3(0, 0, 34), Vector3(0, 3, -20))
