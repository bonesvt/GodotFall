extends SceneTree
## Screenshots of a generated zone, for checking the look.
##   godot --path . -s res://tools/procgen/shots.gd -- <out_dir> [seed] [--lanes=N] [--biome=forest|marsh|boneyard]
## Needs a renderer (not --headless). Writes <out_dir>/<seed>-<n>-<name>.png:
## the view from the spawn, each lane as you come up to the first yard, the
## road, gullies and ridges at the first chasm, the wall, and one from above
## looking down the valley.

const LevelPlan := preload("res://scripts/run/procgen/level_plan.gd")
const ZoneGenerator := preload("res://scripts/run/procgen/zone_generator.gd")
const Loot := preload("res://scripts/run/loot.gd")

var out := "user://procgen_shots"
var seed_value := 101
var lanes := 0
var biome := ""
var run_node
var cam: Camera3D


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lanes="):
			lanes = int(a.substr(8))
		elif a.begins_with("--biome="):
			biome = a.substr(8)
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
	var plan = LevelPlan.make(seed_value, 3, lanes, biome)
	run_node._fresh_level("Zone")
	run_node.zone_info = ZoneGenerator.build_from_plan(run_node.zone_root, plan, 3)
	var info: Dictionary = run_node.zone_info
	var loot_rng := RandomNumberGenerator.new()
	loot_rng.seed = seed_value
	Loot.scatter(run_node.zone_root, info, loot_rng, 3)
	run_node.hud.visible = false
	run_node.pilot_hud.visible = false
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


func _shot(shot_name: String, eye: Vector3, look: Vector3) -> void:
	cam.global_position = eye
	cam.look_at(look, Vector3.UP)
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := out.path_join("%d-%s.png" % [seed_value, shot_name])
	root.get_viewport().get_texture().get_image().save_png(path)
	print("shot ", path)
