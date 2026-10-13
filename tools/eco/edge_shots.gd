extends SceneTree
## Eco in third person over a real level in the Anime look, for checking her
## edges against the screen pass (assets/shaders/anime_post.gdshader): as is
## (anime.png) and what the pass takes each pixel to be (pixel-classes.png:
## set blue, toon characters green, their own outline red, weapons and titans
## white). --parts adds the view without the pass's paint filter and without
## its ink; --before=<file> shoots the same through another version of the
## pass (before.png, and its parts with --parts).
##   xvfb-run -a godot --audio-driver Dummy --path . -s res://tools/eco/edge_shots.gd -- <out_dir> [--level=level1] [--parts] [--before=<file>]
## Needs a renderer (not --headless). Only what is near the camera stays in
## the level, as in tools/procgen/shots.gd.

const LevelPlan := preload("res://scripts/run/procgen/level_plan.gd")
const ZoneGenerator := preload("res://scripts/run/procgen/zone_generator.gd")
const Levels := preload("res://scripts/run/levels.gd")
const CULL := 140.0

var out := "user://eco_edge_shots"
var level := "level1"
var before := ""
var parts := false
var run_node
var _parked: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--level="):
			level = a.substr(8)
		elif a.begins_with("--before="):
			before = a.substr(9)
		elif a == "--parts":
			parts = true
		else:
			out = a
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1600, 900)
	preload("res://scripts/run/tutorial.gd").settings_path = "user://shots_settings.cfg"
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 1234
	run_node.start_in_hub = false
	run_node.armory_path = "user://shots_edge_armory.cfg"
	root.add_child(run_node)
	# a script error leaves the tree running; don't sit there for good
	create_timer(3600.0).timeout.connect(quit.bind(1))
	_go.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _go() -> void:
	await process_frame
	run_node.tutorial.set_enabled(false)
	var plan = LevelPlan.make_level(101, Levels.spec(level))
	run_node._fresh_level("Zone")
	run_node.remove_child(run_node.zone_root)
	run_node.zone_info = ZoneGenerator.build_from_plan(run_node.zone_root, plan, plan.zone_index)
	var info: Dictionary = run_node.zone_info
	if Levels.spec(level).get("night", false):
		preload("res://scripts/run/procgen/biome.gd").night(run_node.zone_root, info)
	for n in run_node.zone_root.get_children():
		run_node.zone_root.remove_child(n)
		_parked.append(n)
	run_node.add_child(run_node.zone_root)
	run_node.set_physics_process(false)
	for g in info["grunts"]:
		g.passive = true
	run_node.hud.visible = false
	run_node.pilot_hud.visible = false
	for layer in run_node.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var loud: int = plan.lane_of("loud")
	var z: float = plan.spawn_z - 6.0
	var feet := Vector3(plan.lane_x(loud, z), plan.ground(plan.lane_x(loud, z), z), z)
	var ahead := Vector3(plan.lane_x(loud, z - 40.0), feet.y, z - 40.0)
	await _cull(feet, ahead)
	var player: Node3D = run_node.player
	player.global_position = feet + Vector3.UP * 0.2
	# looking a little off the line of the street
	player.look_at(Vector3(ahead.x + 14.0, player.global_position.y, ahead.z), Vector3.UP)
	player.get_node("ViewCam").set_third_person(true)
	await _frames(60)
	var ps2 = root.get_node("PS2")
	var post: ShaderMaterial = ps2._post.material_override
	var now: Shader = post.shader
	if before != "":
		post.shader = _shader(FileAccess.get_file_as_string(before))
		await _shots("before")
		post.shader = now
	await _shots("anime")
	var code := now.code.replace("ALBEDO = clamp(col, 0.0, 1.0);", "ALBEDO = mix(clamp(col, 0.0, 1.0), " + \
			"is_set ? vec3(0.0, 0.0, 1.0) : outline ? vec3(1.0, 0.0, 0.0) : toon ? vec3(0.0, 1.0, 0.0) : vec3(1.0), 0.6);")
	post.shader = _shader(code)
	await _save("pixel-classes")
	post.shader = now
	quit()


## The view through the screen pass as it is, and (--parts) without its
## paint filter and without its ink.
func _shots(tag: String) -> void:
	var post: ShaderMaterial = root.get_node("PS2")._post.material_override
	await _save(tag)
	if not parts:
		return
	post.set_shader_parameter("paint_radius", 0)
	await _save(tag + "-no-paint-filter")
	post.set_shader_parameter("paint_radius", null)
	post.set_shader_parameter("ink", Color(0, 0, 0, 0))
	await _save(tag + "-no-screen-ink")
	post.set_shader_parameter("ink", null)


func _shader(code: String) -> Shader:
	var sh := Shader.new()
	sh.code = code
	return sh


func _save(shot: String) -> void:
	await _frames(6)
	await RenderingServer.frame_post_draw
	var path := out.path_join(shot + ".png")
	root.get_viewport().get_texture().get_image().save_png(path)
	print("shot ", path)


## Puts back only what's near the shot (see tools/procgen/shots.gd).
func _cull(eye: Vector3, look: Vector3) -> void:
	var zr: Node3D = run_node.zone_root
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
