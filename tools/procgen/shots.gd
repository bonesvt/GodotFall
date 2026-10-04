extends SceneTree
## Screenshots of a generated zone, for checking the look.
##   godot --path . -s res://tools/procgen/shots.gd -- <out_dir> [seed] [--lanes=N] [--biome=forest|marsh|boneyard] [--level=level1]
## Needs a renderer (not --headless). Writes <out_dir>/<seed>-<n>-<name>.png:
## the view from the spawn, each lane as you come up to the first yard, the
## road, gullies and ridges at the first chasm, the wall, and one from above
## looking down the valley. With --level, a real level (levels.gd) instead:
## the spawn, the salvage depot and its titan part (or the holding block and
## the prisoner's cell), and the finale's clearing.

const LevelPlan := preload("res://scripts/run/procgen/level_plan.gd")
const ZoneGenerator := preload("res://scripts/run/procgen/zone_generator.gd")
const Loot := preload("res://scripts/run/loot.gd")
const Levels := preload("res://scripts/run/levels.gd")

var out := "user://procgen_shots"
var seed_value := 101
var lanes := 0
var biome := ""
var level := ""
## In a big zone (a level), software renderers run out of per-instance shader
## slots (4096), so each shot only keeps what is within CULL m of the camera
## or what it looks at, plus the ground, sky and multimeshes.
const CULL := 140.0
var _parked: Array = []
var run_node
var cam: Camera3D


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lanes="):
			lanes = int(a.substr(8))
		elif a.begins_with("--biome="):
			biome = a.substr(8)
		elif a.begins_with("--level="):
			level = a.substr(8)
		elif a.is_valid_int():
			seed_value = int(a)
		else:
			out = a
	DirAccess.make_dir_recursive_absolute(out)
	preload("res://scripts/run/tutorial.gd").settings_path = "user://shots_settings.cfg"
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 1234
	run_node.start_in_hub = false
	run_node.armory_path = "user://shots_armory.cfg"
	root.add_child(run_node)
	_go.call_deferred()


func _go() -> void:
	await process_frame
	run_node.tutorial.set_enabled(false)
	var plan = LevelPlan.make(seed_value, 3, lanes, biome) if level == "" else LevelPlan.make_level(seed_value, Levels.spec(level))
	run_node._fresh_level("Zone")
	if level != "":
		# Built out of the tree, so no piece takes a shader slot until a shot
		# brings it in (see _cull).
		run_node.remove_child(run_node.zone_root)
	run_node.zone_info = ZoneGenerator.build_from_plan(run_node.zone_root, plan, plan.zone_index)
	var info: Dictionary = run_node.zone_info
	if level != "":
		for n in run_node.zone_root.get_children():
			run_node.zone_root.remove_child(n)
			_parked.append(n)
		run_node.add_child(run_node.zone_root)
	else:
		var loot_rng := RandomNumberGenerator.new()
		loot_rng.seed = seed_value
		Loot.scatter(run_node.zone_root, info, loot_rng, 3)
	run_node.hud.visible = false
	run_node.pilot_hud.visible = false
	for layer in run_node.find_children("*", "CanvasLayer", true, false):
		layer.visible = false  # Eco's whispers and the rest
	run_node.player.process_mode = Node.PROCESS_MODE_DISABLED
	run_node.player.global_position = Vector3(0, -500, 0)
	run_node.set_physics_process(false)
	for g in info["grunts"]:
		g.passive = true
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.far = 900.0
	run_node.zone_root.add_child(cam)
	cam.make_current()
	print(plan.describe())

	var loud: int = plan.lane_of("loud")
	var at := func(lane: int, z: float, up := 1.7) -> Vector3:
		return Vector3(plan.lane_x(lane, z), plan.ground(plan.lane_x(lane, z), z) + up, z)
	var n := 1
	if level != "":
		await _level_shots(plan, info, at)
		quit()
		return
	await _shot("%d-spawn" % n, at.call(loud, plan.spawn_z + 4.0), at.call(loud, plan.spawn_z - 40.0, 0.0))
	n += 1
	# Each lane as you come into the first yard.
	var yard: Dictionary = plan.sections.filter(func(s): return s["kind"] in ["outpost", "camp"])[0]
	for i in plan.lanes.size():
		var kind: String = plan.lanes[i]["kind"]
		var z0: float = yard["z0"] + 10.0
		var eye: Vector3 = at.call(i, z0)
		if kind == "high" and plan.ridge_on(z0) > 0.5:
			eye.y = plan.base_height(z0) + LevelPlan.RIDGE_H + 1.7
		await _shot("%d-%s-lane%d-into-%s" % [n, kind, i, yard["kind"]], eye, at.call(i, yard["mid"], 1.0))
		n += 1
	# The first chasm from the near lip: the bridge, and each lane's way over.
	var chasm: Dictionary = plan.sections_of("chasm")[0]
	var lip: float = chasm["near_lip"] + 9.0
	await _shot("%d-chasm-road" % n, at.call(loud, lip, 3.0), at.call(loud, chasm["far_lip"] - 6.0, 0.0))
	n += 1
	for i in plan.lanes.size():
		if i == loud:
			continue
		var kind: String = plan.lanes[i]["kind"]
		var eye: Vector3 = at.call(i, lip)
		if kind == "high":
			eye.y = chasm["level"] + LevelPlan.RIDGE_H + 1.7
		var look: Vector3 = at.call(i, chasm["far_lip"] - 6.0, 0.0)
		if kind == "high":
			look.y = chasm["level"] + LevelPlan.RIDGE_H
		await _shot("%d-chasm-%s-lane%d" % [n, kind, i], eye, look)
		n += 1
	# The wall from the road.
	var wall: Dictionary = plan.sections_of("wall")[0]
	await _shot("%d-wall" % n, at.call(loud, wall["wall_z"] + 18.0, 2.0), at.call(loud, wall["wall_z"], 3.0))
	n += 1
	# From above, down the valley, without the haze.
	for env in run_node.zone_root.find_children("*", "WorldEnvironment", true, false):
		env.environment.fog_enabled = false
		env.environment.volumetric_fog_enabled = false
	var mid_z: float = plan.spawn_z - 30.0
	await _shot("%d-overview" % n, Vector3(plan.center_x(mid_z), 70.0, plan.spawn_z + 40.0), Vector3(plan.center_x(mid_z - 120.0), 0.0, mid_z - 120.0))
	quit()


## A real level's beats: the way in, the depot and its crate, the clearing.
func _level_shots(plan, info: Dictionary, at: Callable) -> void:
	var loud: int = plan.lane_of("loud")
	await _shot("1-spawn", at.call(loud, plan.spawn_z + 4.0), at.call(loud, plan.spawn_z - 40.0, 0.0))
	if not plan.sections_of("holding").is_empty():
		await _holding_shots(plan, info, at)
	else:
		var depot: Dictionary = plan.sections_of("depot")[0]
		await _shot("2-depot-from-the-road", at.call(loud, depot["z0"] + 12.0, 2.2), at.call(loud, depot["mid"], 1.0))
		var crate: Vector3 = info["depot_cache"].position
		var c: float = plan.lane_x(loud, depot["mid"])
		var side := signf(crate.x - c) if absf(crate.x - c) > 0.5 else 1.0
		await _shot("3-depot-titan-part", crate + Vector3(-side * 7.0, 3.0, 9.0), crate + Vector3(0, 1.0, 0))
		await _shot("4-depot-from-above", Vector3(c - side * 30.0, plan.ground(c, depot["mid"]) + 26.0, depot["z0"] + 20.0), Vector3(c, plan.ground(c, depot["mid"]), depot["mid"]))
	var arena: Dictionary = info["arena"]
	var boss: Vector3 = info["boss"].position
	await _shot("5-clearing-out-of-the-trees", at.call(loud, arena["enter_z"] + 10.0, 1.7), boss + Vector3(0, 5.0, 0))
	for env in run_node.zone_root.find_children("*", "WorldEnvironment", true, false):
		env.environment.fog_enabled = false
		env.environment.volumetric_fog_enabled = false
	var mid: Vector3 = arena["center"]
	await _shot("6-clearing-from-above", mid + Vector3(-40.0, 55.0, 60.0), mid)
	await _shot("7-valley-overview", Vector3(plan.center_x(plan.spawn_z), 80.0, plan.spawn_z + 50.0), Vector3(plan.center_x(plan.spawn_z - 150.0), 0.0, plan.spawn_z - 150.0))


## A rescue level's holding block: up the street to it, Ophelia in her cell
## through the screen, and the block from above.
func _holding_shots(plan, info: Dictionary, at: Callable) -> void:
	var loud: int = plan.lane_of("loud")
	var block: Dictionary = plan.sections_of("holding")[0]
	await _shot("2-holding-from-the-road", at.call(loud, block["z0"] + 12.0, 2.2), at.call(loud, block["mid"], 1.0))
	var cell: Node3D = info["holding_cell"]
	var xf: Transform3D = cell.transform
	await _shot("3-ophelia-in-her-cell", xf * Vector3(1.2, 1.7, 4.2), xf * Vector3(0.3, 0.7, -2.0))
	await _shot("4-holding-cell-wide", xf * Vector3(-5.0, 3.0, 11.0), xf * Vector3(0, 1.5, -1.0))
	var c: float = plan.lane_x(loud, block["mid"])
	var side := signf(cell.position.x - c)
	await _shot("4b-holding-from-above", Vector3(c - side * 30.0, plan.ground(c, block["mid"]) + 26.0, block["z0"] + 20.0), Vector3(c, plan.ground(c, block["mid"]), block["mid"]))


func _shot(shot_name: String, eye: Vector3, look: Vector3) -> void:
	if level != "":
		await _cull(eye, look)
	cam.global_position = eye
	cam.look_at(look, Vector3.UP)
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := out.path_join("%d-%s.png" % [seed_value, shot_name])
	root.get_viewport().get_texture().get_image().save_png(path)
	print("shot ", path)


## Takes everything out of the zone, then puts back only what's near this shot.
func _cull(eye: Vector3, look: Vector3) -> void:
	var zr: Node3D = run_node.zone_root
	for n in zr.get_children():
		if n == cam:
			continue
		zr.remove_child(n)
		_parked.append(n)
	await process_frame
	var keep := []
	for n in _parked:
		if not n is Node3D or n is WorldEnvironment or n is Light3D or n is MultiMeshInstance3D or String(n.name) == "Ground":
			keep.append(n)
			continue
		var p: Vector3 = (n as Node3D).position
		var flat := Vector2(p.x, p.z)
		if flat.distance_to(Vector2(eye.x, eye.z)) < CULL or flat.distance_to(Vector2(look.x, look.z)) < CULL * 0.6:
			keep.append(n)
	for n in keep:
		_parked.erase(n)
		zr.add_child(n)
	await process_frame
	# Slots are free now: hand each piece its paint again (the first time round
	# many sets were refused).
	for n in keep:
		var stack: Array = [n]
		while not stack.is_empty():
			var g: Node = stack.pop_back()
			stack.append_array(g.get_children())
			if g is GeometryInstance3D:
				for prop in g.get_property_list():
					var pn: String = prop["name"]
					if pn.begins_with("instance_shader_parameters/"):
						var key := pn.substr(27)
						g.set_instance_shader_parameter(key, g.get_instance_shader_parameter(key))
