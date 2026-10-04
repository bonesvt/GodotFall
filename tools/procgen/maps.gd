extends SceneTree
## Top-down maps of generated zones (scripts/run/procgen/), one PNG per seed.
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/procgen/maps.gd -- <out_dir> [seed ...] [--plan] [--lanes=N] [--biome=forest|marsh|boneyard]
## By default each zone is built (headless parts of it: grunts, caches, loot)
## and drawn with everything on it; --plan draws the plan alone, which is
## much faster. Writes <out_dir>/zone_<seed>.png.

const LevelPlan := preload("res://scripts/run/procgen/level_plan.gd")
const ZoneGenerator := preload("res://scripts/run/procgen/zone_generator.gd")
const ZoneMap := preload("res://scripts/run/procgen/zone_map.gd")
const Loot := preload("res://scripts/run/loot.gd")

var out := "user://procgen_maps"
var seeds := [101, 202, 303, 404]
var plan_only := false
var lanes := 0
var biome := ""


func _initialize() -> void:
	var given := []
	for a in OS.get_cmdline_user_args():
		if a == "--plan":
			plan_only = true
		elif a.begins_with("--lanes="):
			lanes = int(a.substr(8))
		elif a.begins_with("--biome="):
			biome = a.substr(8)
		elif a.is_valid_int():
			given.append(int(a))
		else:
			out = a
	if not given.is_empty():
		seeds = given
	DirAccess.make_dir_recursive_absolute(out)
	_go.call_deferred()


func _go() -> void:
	for s in seeds:
		var plan = LevelPlan.make(s, 3, lanes, biome)
		var info := {}
		var world: Node3D
		if not plan_only:
			world = Node3D.new()
			root.add_child(world)
			var t := Time.get_ticks_msec()
			info = ZoneGenerator.build_from_plan(world, plan, 3)
			var loot_rng := RandomNumberGenerator.new()
			loot_rng.seed = s
			Loot.scatter(world, info, loot_rng, 3)
			for i in 3:
				await physics_frame  # loot settles onto the ground
			print("built %d in %d ms" % [s, Time.get_ticks_msec() - t])
		var vp := SubViewport.new()
		vp.transparent_bg = false
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		root.add_child(vp)
		var map := ZoneMap.new()
		vp.add_child(map)
		map.setup(plan, info, 3.0)
		vp.size = Vector2i(map.size)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var path := out.path_join("zone_%d.png" % s)
		vp.get_texture().get_image().save_png(path)
		print(plan.describe())
		print("map ", path)
		vp.queue_free()
		if world != null:
			world.queue_free()
		await process_frame
	quit()
