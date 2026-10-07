extends SceneTree
## Marrow's Glass on Eco (glass.gd, eco_toon.gdshaderinc eco_glass): her at a
## third, two thirds and all of it, full body over a close-up of her face.
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/eco/glass_shots.gd -- <out_dir> [outfit]
## Needs a renderer (not --headless). Writes <out_dir>/glass_skin.png.

const ECO := preload("res://assets/models/eco.tscn")
const LEVELS := [0.0, 0.34, 0.67, 1.0]

var out := "user://glass_shots"
var outfit := "suit"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	if args.size() > 1:
		outfit = args[1]
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
	env.environment.background_color = Color(0.2, 0.17, 0.24)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.75)
	env.environment.ambient_light_energy = 0.6
	env.environment.glow_enabled = true
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 150, 0)
	root.add_child(sun)
	var cam := Camera3D.new()
	root.add_child(cam)
	var eco := ECO.instantiate()
	root.add_child(eco)
	eco.rotation_degrees.y = 180.0
	await _frames(10)
	eco.wear(outfit)
	var sheet := Image.create(300 * LEVELS.size(), 900, false, Image.FORMAT_RGBA8)
	for i in LEVELS.size():
		RenderingServer.global_shader_parameter_set("eco_glass", LEVELS[i])
		# full body
		cam.fov = 38
		cam.look_at_from_position(Vector3(0.0, 1.0, 4.6), Vector3(0, 0.9, 0))
		await _frames(12)
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(450, 0, 300, 600), Vector2i(300 * i, 0))
		# her face
		cam.fov = 20
		cam.look_at_from_position(Vector3(0.25, 1.5, 1.4), Vector3(0, 1.45, 0))
		await _frames(12)
		img = root.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.resize(600, 450)
		sheet.blit_rect(img, Rect2i(150, 75, 300, 300), Vector2i(300 * i, 600))
	var path := out.path_join("glass_skin.png")
	sheet.save_png(path)
	print("wrote ", path)
	quit()
