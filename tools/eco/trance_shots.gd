extends SceneTree
## Eco's trance walk (eco_model.gd _trance_walk, Marrow's pull in vices.gd)
## next to her off-duty strut: a sheet of walk frames from the front and the
## side, left strut, right trance.
##   xvfb-run -a godot --path . --fixed-fps 30 --rendering-driver opengl3 -s res://tools/eco/trance_shots.gd -- [out_dir]
## Needs a renderer (not --headless). Writes <out_dir>/trance_walk.png.

const ECO := preload("res://assets/models/eco.tscn")
const Vices := preload("res://scripts/hub/vices.gd")
const SIZE := Vector2i(500, 450)
const FRAMES := 4

var out := "user://trance_shots"


class Walker extends CharacterBody3D:
	var state := 0  # player.gd State.GROUND
	var crouching := false
	var strolling := true
	var entranced := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			out = a
	DirAccess.make_dir_recursive_absolute(out)
	root.size = SIZE * 2
	_go.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _go() -> void:
	Vices.hold = Vices.MAX_HOLD
	Vices.entranced = true
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.22, 0.18, 0.28)
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
		w.entranced = i == 1
		root.add_child(w)
		w.add_child(ECO.instantiate())
		w.velocity = Vector3(0, 0, -1.2)
		walkers.append(w)
	var cam := Camera3D.new()
	cam.fov = 40
	root.add_child(cam)
	var sheet := Image.create(SIZE.x * FRAMES, SIZE.y * 2, false, Image.FORMAT_RGBA8)
	await _frames(60)
	var anim: AnimationPlayer = walkers[1].get_child(0).find_child("AnimationPlayer", true, false)
	var cycle := anim.current_animation_length / maxf(anim.speed_scale, 0.01)
	for row in 2:
		if row == 0:
			cam.look_at_from_position(Vector3(0.0, 1.0, -4.2), Vector3(0, 0.85, 0))
		else:
			cam.look_at_from_position(Vector3(4.6, 1.0, 0.0), Vector3(0, 0.85, 0))
		for f in FRAMES:
			await _frames(maxi(1, roundi(cycle / FRAMES * 30.0)))
			var img := root.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			img.resize(SIZE.x, SIZE.y)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, SIZE), Vector2i(SIZE.x * f, SIZE.y * row))
			print("row ", row, " frame ", f)
	sheet.save_png(out.path_join("trance_walk.png"))
	print("wrote trance_walk.png")
	quit()
