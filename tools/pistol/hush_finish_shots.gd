extends SceneTree
## The Hush finish (armory.gd FINISHES "hush") on each sidearm, side on, at
## three moments as its spirals turn (weapon.gd spin_hush).
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/pistol/hush_finish_shots.gd -- out.png
## Needs a renderer (not --headless).

const Weapon := preload("res://scripts/weapon.gd")
const Armory := preload("res://scripts/hub/armory.gd")
const GUNS := ["smart_pistol", "rivet_cannon", "machine_pistol"]


func _initialize() -> void:
	var out := "user://hush_finish.png"
	if OS.get_cmdline_user_args().size() > 0:
		out = OS.get_cmdline_user_args()[0]
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.13, 0.11, 0.16)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.75)
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -60, 0)
	world.add_child(sun)
	for i in GUNS.size():
		var profile: Dictionary = Armory.WEAPONS[GUNS[i]].duplicate()
		profile["attachments"] = {}
		profile["finish"] = Armory.finish("hush")
		var gun := Weapon.gun_model(profile)
		world.add_child(gun)
		gun.position = Vector3(0, 0.3 - i * 0.3, 0)
		gun.rotation_degrees = Vector3(0, 90, 0)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 0.95
	cam.position = Vector3(0, 0.0, 2)
	world.add_child(cam)
	cam.make_current()
	root.size = Vector2i(700, 700)
	_save.call_deferred(out)


func _save(out: String) -> void:
	var sheet := Image.create(2100, 700, false, Image.FORMAT_RGBA8)
	for f in 3:
		Weapon.spin_hush(0.0, 1.1)
		for i in 6:
			await process_frame
		var img := root.get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(0, 0, 700, 700), Vector2i(700 * f, 0))
	sheet.save_png(out)
	print("wrote ", out)
	quit()
