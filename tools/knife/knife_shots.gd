extends SceneTree
## Quick screenshots of Eco's three knives as she holds them (the knife.gd
## viewmodel on a plain backdrop, no level loaded, so it's fast on the CPU
## renderer) and the knife case's screen.
##   xvfb-run -a godot --path . -s res://tools/knife/knife_shots.gd -- [out_dir]
## Per knife: held ready, mid finger-spin (frozen pointing forward, so the
## Butterfly's swung-open bite handle reads) and shown off on the inspect.

const KnifeScript := preload("res://scripts/knife.gd")
const Armory := preload("res://scripts/hub/armory.gd")
const BenchScreen := preload("res://scripts/hub/bench_screen.gd")
const PATH := "user://knife_shots_armory.cfg"

var out := "user://knife_shots"
var knife: Node3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280, 720)
	var stage := Node3D.new()
	root.add_child(stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.14, 0.15)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.5, 0.48)
	var we := WorldEnvironment.new()
	we.environment = env
	stage.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 150, 0)
	sun.light_energy = 1.2
	stage.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 70.0
	stage.add_child(cam)
	knife = KnifeScript.new()
	cam.add_child(knife)
	_go.call_deferred()


func _go() -> void:
	knife.set_process(false)
	knife.set_physics_process(false)
	knife.set_process_unhandled_input(false)
	knife.readied = true  # held out, as when Z is held
	knife._ready_blend = 1.0
	for id in Armory.KNIVES:
		knife.set_model(id)
		for pose in [["ready", "draw", KnifeScript.DRAW_TIME - 0.001], ["spin", "inspect", 1.02], ["show", "inspect", 0.5]]:
			knife.anim = pose[1]
			knife.anim_time = pose[2]
			knife._process(0.0)
			if pose[0] == "spin":
				knife._blade.rotation = Vector3.ZERO  # freeze the spin pointing forward to show the handle
			await _save("knife-hand-%s-%s" % [id, pose[0]])
	knife.get_parent().remove_child(knife)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	var a = Armory.open(PATH)
	a.set_knife("butterfly")
	var screen := BenchScreen.new(a, "knives")
	root.add_child(screen)
	screen.select(2)
	await _frames(6)
	await _save("knife-case-screen")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	quit()


func _save(name: String) -> void:
	await _frames(4)
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("shot ", name)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
