extends SceneTree
## Close-ups of Eco's face at a few of Marrow's Hold levels (vices.gd: violet
## spirals in her irises), side by side in one picture.
##   xvfb-run -a godot --path . -s res://tools/eco/eye_shots.gd -- [out_dir]
## Needs a renderer (not --headless). Writes <out_dir>/eye_swirl.png.

const ECO := preload("res://assets/models/eco.tscn")
const Vices := preload("res://scripts/hub/vices.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")
const HOLDS := [0.0, 30.0, 60.0, 100.0]
const SIZE := Vector2i(600, 450)

var out := "user://eye_shots"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			out = a
	DirAccess.make_dir_recursive_absolute(out)
	root.size = SIZE
	_go.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _go() -> void:
	ContentRating.set_rating("M", false)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.2, 0.18, 0.24)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.75)
	env.environment.ambient_light_energy = 0.6
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 165, 0)
	root.add_child(sun)
	var eco := ECO.instantiate()
	root.add_child(eco)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 1.5, -1.3), Vector3(0, 1.49, 0))
	cam.fov = 11
	await _frames(10)
	var sheet := Image.create(SIZE.x * HOLDS.size(), SIZE.y, false, Image.FORMAT_RGBA8)
	for i in HOLDS.size():
		Vices.hold = HOLDS[i]
		await _frames(25)
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.resize(SIZE.x, SIZE.y)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, SIZE), Vector2i(SIZE.x * i, 0))
		print("hold ", HOLDS[i])
	sheet.save_png(out.path_join("eye_swirl.png"))
	print("wrote eye_swirl.png")
	quit()
