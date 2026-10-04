extends SceneTree
## Eco standing in each of the given outfits (eco_model.gd OUTFITS), from the
## front, three-quarter and back, side by side, for checking a look.
##   xvfb-run -a godot --path . -s res://tools/eco/outfit_shots.gd -- [out_dir] [--outfits=suit_vesper,suit_vesper_open] [--close]
## Needs a renderer (not --headless). Writes <out_dir>/<outfit>.png.

const ECO := preload("res://assets/models/eco.tscn")

var out := "user://outfit_shots"
var outfits := ["suit_vesper", "suit_vesper_open"]
## --close: the middle (three-quarter) one from the hips up, for checking necklines and cuts
var close := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--outfits="):
			outfits = Array(a.get_slice("=", 1).split(","))
		elif a == "--close":
			close = true
		elif not a.begins_with("--"):
			out = a
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1200, 900)
	_go.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _go() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.32, 0.34, 0.38)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.75)
	env.environment.ambient_light_energy = 0.6
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 150, 0)
	root.add_child(sun)
	# three of her, turned to show the front, three-quarter and back to one camera
	var ecos := []
	for i in 3:
		var eco := ECO.instantiate()
		eco.position = Vector3(1.0 - 1.0 * i, 0, 0)   # the camera looks down +Z: +X is on the left
		eco.rotation_degrees.y = [0.0, 35.0, 180.0][i]
		root.add_child(eco)
		ecos.append(eco)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 1.0, -4.6), Vector3(0, 0.9, 0))
	cam.fov = 38
	if close:
		cam.look_at_from_position(Vector3(0.0, 1.15, -4.6), Vector3(0, 1.15, 0))
		cam.fov = 13
	await _frames(10)
	for outfit in outfits:
		for eco in ecos:
			eco.wear(outfit)
		await _frames(20)
		var path := out.path_join("%s%s.png" % [outfit, "_close" if close else ""])
		root.get_texture().get_image().save_png(path)
		print("wrote ", ProjectSettings.globalize_path(path))
	quit()
