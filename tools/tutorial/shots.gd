extends SceneTree
## Screenshots of the tutorial hints in zones 1-3 and the arena.
##   xvfb-run -a godot --path . -s res://tools/tutorial/shots.gd -- <out_dir>
## Needs a renderer (not --headless). Uses its own settings file, so your save's
## hints stay unseen.

const Tutorial := preload("res://scripts/run/tutorial.gd")

var run_node
var tut
var out := "user://tutorial_shots"
## Only shots whose name starts with this (second argument), e.g. "5-".
var only := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	if args.size() > 1:
		only = args[1]
	DirAccess.make_dir_recursive_absolute(out)
	Tutorial.settings_path = "user://shots_tutorial.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Tutorial.settings_path))
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 1234
	run_node.start_in_hub = false
	run_node.armory_path = "user://shots_tutorial_armory.cfg"
	root.add_child(run_node)
	_go.call_deferred()


func _go() -> void:
	tut = run_node.tutorial
	for g in run_node.zone_info["grunts"]:
		g.sight_range = 0.0  # keep them calm for the camera
	await _frames(10)
	var info: Dictionary = run_node.zone_info
	var spawn: Vector3 = info["spawn"]
	var node: Node3D = tut._first_loot(true)
	var crate: Node3D = tut._first_loot(false)
	await _shot("1-welcome", "welcome", spawn, spawn + Vector3(0, 1.0, -20))
	await _shot("2-alloy-node", "alloy_node", spawn + Vector3(1.5, 0, 1.0), node.global_position + Vector3(0, 0.6, 0))
	await _shot("3-supply-crate", "supply_crate", crate.global_position + Vector3(-3.0, 0, 4.0), crate.global_position)
	var g: Node3D = info["grunts"][0]
	await _shot("4-grunt", "grunts", g.global_position + g.global_basis.z * 26.0 + Vector3(0, 0.3, 0), g.global_position + Vector3(0, 1.2, 0))
	var grass: Area3D = tut._closest(info["stealth_cover"], INF)
	for area in info["stealth_cover"]:
		if area.global_position.distance_to(spawn) < 120.0 and area.global_position.distance_to(spawn) > 20.0:
			grass = area
			break
	await _shot("5-tall-grass", "tall_grass", grass.global_position + Vector3(2.0, 0, 7.0), grass.global_position + Vector3(0, -0.8, 0))
	var lip: Vector3 = info["crossing"]["lip"]
	await _shot("6-ravine", "ravine", lip + Vector3(-4.0, 3.0, 6.0), lip + Vector3(-4.0, -2.0, -30.0))
	await _shot("7-extract", "extract_zone0", info["beacon"].global_position + Vector3(0, 0, 22.0), info["beacon"].global_position + Vector3(0, 2, 0))

	run_node.load_zone(1)
	await _frames(10)
	info = run_node.zone_info
	for gg in info["grunts"]:
		gg.sight_range = 0.0
	spawn = info["spawn"]
	await _shot("8-blackwater-routes", "routes", spawn, spawn + Vector3(0, 1.0, -25))
	# A grunt you can walk up behind with nothing in the way.
	var gk: Node3D = info["grunts"][0]
	for cand in info["grunts"]:
		run_node.player.global_position = cand.global_position + cand.global_basis.z * 6.0 + Vector3(0, 0.3, 0)
		_aim(run_node.player.global_position, cand.global_position + Vector3(0, 1.0, 0))
		await physics_frame
		await physics_frame
		if tut._stab_target(12.0) == cand:
			gk = cand
			break
	await _shot("9-stiletto", "knife", gk.global_position + gk.global_basis.z * 6.0 + Vector3(0, 0.3, 0), gk.global_position + Vector3(0, 1.0, 0))
	lip = info["crossing"]["lip"]
	await _shot("10-grapple", "grapple", lip + Vector3(-2.0, 3.0, 6.0), lip + Vector3(4.0, 4.0, -24.0))

	run_node.load_zone(2)
	await _frames(10)
	info = run_node.zone_info
	for gg in info["grunts"]:
		gg.sight_range = 0.0
	spawn = info["spawn"]
	await _shot("11-boneyard-titan", "titan_build", spawn, spawn + Vector3(0, 1.0, -25))
	lip = info["crossing"]["lip"]
	await _shot("12-wallrun", "wallrun", lip + Vector3(-6.0, 3.0, 6.0), lip + Vector3(-4.0, 0.0, -30.0))
	await _shot("13-titanfall-beacon", "extract_zone2", info["beacon"].global_position + Vector3(0, 0, 22.0), info["beacon"].global_position + Vector3(0, 2, 0))

	run_node.load_zone(3)
	await _frames(10)
	run_node.call_titan()
	var t: Node3D = run_node.titan
	var left := 600
	while t.dropping and left > 0:
		await physics_frame
		left -= 1
	await _shot("14-arena-embark", "embark", t.global_position + Vector3(8.0, 0, 10.0), t.global_position + Vector3(0, 3.0, 0))
	quit()


## Shows only `id` (everything else counts as seen), puts the pilot at `at`
## looking at `look`, waits for the card and saves the frame.
func _shot(name: String, id: String, at: Vector3, look: Vector3) -> void:
	if only != "" and not name.begins_with(only):
		return
	tut._finish()
	tut.seen.clear()
	for b in tut.beats:
		if b["id"] != id:
			tut.seen[b["id"]] = true
	var player = run_node.player
	player.global_position = at
	player.velocity = Vector3.ZERO
	_aim(at, look)
	tut.level_time = 5.0
	var left := 60
	while tut.current.get("id", "") != id and left > 0:
		player.global_position = at
		player.velocity = Vector3.ZERO
		await physics_frame
		left -= 1
	await _frames(5)
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("shot ", name, "  card: ", tut.current.get("id", "NONE"), "  t=", Time.get_ticks_msec() / 1000)


func _aim(at: Vector3, look: Vector3) -> void:
	var player = run_node.player
	var d := look - (at + Vector3(0, 1.6, 0))
	player.rotation.y = atan2(-d.x, -d.z)
	player.get_node("Head").rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


func _frames(n: int) -> void:
	for i in n:
		await process_frame
