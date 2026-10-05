extends SceneTree
## Quick screenshots of Eco's three knives as she holds them (the knife.gd
## viewmodel on a plain backdrop, no level loaded, so it's fast on the CPU
## renderer) and the knife case's screen.
##   xvfb-run -a godot --path . -s res://tools/knife/knife_shots.gd -- [out_dir] [frames|clips]
## Default: per knife, held ready, its two attacks at the hit and three
## moments of its inspect. "frames": each knife's draw, attacks and inspect
## sampled every 1/10 s (knife-<id>-<anim>-NN.png) for strips. "clips": every
## 1/30 s, numbered per knife (clip-<id>-NNNN.png) for ffmpeg.

const KnifeScript := preload("res://scripts/knife.gd")
const Armory := preload("res://scripts/hub/armory.gd")
const BenchScreen := preload("res://scripts/hub/bench_screen.gd")
const PATH := "user://knife_shots_armory.cfg"

var out := "user://knife_shots"
var mode := ""
var knife: Node3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	if args.size() > 1:
		mode = args[1]
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
	knife.out = true  # drawn as her weapon
	knife._ready_blend = 1.0
	for id in Armory.KNIVES:
		knife.set_model(id)
		if mode == "frames":
			for a in ["draw", "attack_a", "attack_b", "inspect"]:
				var n := ceili(knife.anim_length(a) * 10.0)
				for i in n:
					await _pose(a, i * 0.1, "knife-%s-%s-%02d" % [id, a, i])
		elif mode == "clips":
			var f := 0
			for a in ["draw", "attack_a", "attack_b", "attack_a", "inspect"]:
				var n := ceili(knife.anim_length(a) * 30.0)
				for i in n:
					await _pose(a, i / 30.0, "clip-%s-%04d" % [id, f], 1)
					f += 1
		else:
			await _pose("", 0.0, "knife-hand-%s-ready" % id)
			await _pose("draw", 0.2, "knife-hand-%s-draw" % id)
			await _pose("attack_a", knife.hit_time, "knife-hand-%s-attack-a" % id)
			await _pose("attack_b", knife.hit_time, "knife-hand-%s-attack-b" % id)
			for t in [0.5, 1.4, 2.0]:
				await _pose("inspect", t, "knife-hand-%s-inspect-%d" % [id, roundi(t * 10)])
	if mode != "":
		quit()
		return
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


## Freezes the knife in animation `anim` at `t` seconds and saves a picture.
func _pose(anim: String, t: float, name: String, settle := 3) -> void:
	knife.anim = anim
	knife.anim_time = t
	knife._events_done = 1000  # no sounds or sparkles in stills
	knife._process(0.0)
	await _save(name, settle)


func _save(name: String, settle := 4) -> void:
	await _frames(settle)
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("shot ", name)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
