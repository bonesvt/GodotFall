extends SceneTree
## Frames of Eco's off-duty strut (eco_model.gd _strut) next to her plain walk,
## and her off-duty stance next to her idle, for checking the look.
##   xvfb-run -a godot --path . --fixed-fps 30 -s res://tools/eco/strut_shots.gd -- [out_dir] [--frames=N] [--view=front|side|back]
## Needs a renderer (not --headless). Left: plain walk / idle. Right: strut / stance.

const ECO := preload("res://assets/models/eco.tscn")

var out := "user://strut_shots"
var frames := 16
var view := "front"


class Walker extends CharacterBody3D:
	var state := 0  # player.gd State.GROUND
	var crouching := false
	var strolling := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--frames="):
			frames = int(a.get_slice("=", 1))
		elif a.begins_with("--view="):
			view = a.get_slice("=", 1)
		elif not a.begins_with("--"):
			out = a
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1000, 900)
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
	sun.rotation_degrees = Vector3(-40, 30, 0)
	root.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 12)
	floor_mesh.mesh = plane
	root.add_child(floor_mesh)

	var walkers: Array[Walker] = []
	for i in 2:
		var w := Walker.new()
		w.position = Vector3(-0.55 + 1.1 * i, 0, 0)
		root.add_child(w)
		var eco := ECO.instantiate()
		w.add_child(eco)
		walkers.append(w)
	var cam := Camera3D.new()
	root.add_child(cam)
	match view:
		"side":
			cam.look_at_from_position(Vector3(4.2, 1.0, 0.0), Vector3(0, 0.85, 0))
		"back":
			cam.look_at_from_position(Vector3(0.0, 1.1, 4.0), Vector3(0, 0.85, 0))
		_:
			cam.look_at_from_position(Vector3(0.0, 1.0, -4.2), Vector3(0, 0.85, 0))
	cam.fov = 40

	# walking (in place: the velocity only drives the animation)
	walkers[1].strolling = true
	for w in walkers:
		w.velocity = Vector3(0, 0, -1.9)
	await _frames(40)
	var anim: AnimationPlayer = walkers[1].get_child(0).find_child("AnimationPlayer", true, false)
	var cycle := anim.current_animation_length / maxf(anim.speed_scale, 0.01)
	var step := cycle / frames
	for f in frames:
		root.get_viewport().get_texture().get_image().save_png(out.path_join("walk_%s_%02d.png" % [view, f]))
		await _frames(maxi(1, roundi(step * 30.0)))
	# standing
	for w in walkers:
		w.velocity = Vector3.ZERO
	await _frames(60)
	root.get_viewport().get_texture().get_image().save_png(out.path_join("stand_%s.png" % view))
	print("strut shots in ", ProjectSettings.globalize_path(out))
	quit()
