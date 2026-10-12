extends SceneTree
## Stills of Eco's battle damage at full (every rip open, Mature) in the poses
## that stretch her suit the most: mid-slide, crouched, at the widest point of
## her running stride and in the air, from behind, the side, low behind, the
## front and close on her chest. The check by eye before the slide and chest
## tears were allowed nearer the covered zones (tools/eco/bake_damage.py
## SLIDE_GAP, CHEST_GAP).
##   xvfb-run -a godot --path . -s res://tools/eco/damage_pose_shots.gd -- [out_dir] [--damage=1.0] [--only=slide,crouch] [--views=chest,chest_34] [--outfits=skater,y2k]
## Needs a renderer (not --headless). Writes [<outfit>_]<pose>_<view>.png.

const ECO := preload("res://assets/models/eco.tscn")
const BattleDamage := preload("res://scripts/ps2/battle_damage.gd")

var out := "user://damage_pose_shots"
var only: Array = []
var views: Array = []
## outfits to dress her in, one after another (eco_model.gd OUTFITS); [""]
## leaves her in her own suit and names the shots without one
var outfits: Array = [""]
var damage := 1.0

## pose name, animation, how far through it (0..1)
const POSES := [["slide", "slide", 0.5], ["crouch", "crouch", 0.5], ["stride", "run", 0.25], ["stride2", "run", 0.75],
		["idle", "idle", 0.0], ["fall", "fall", 0.5]]
## view name, camera position, look at (she faces -Z, her origin at her feet)
const VIEWS := [
	["back", Vector3(0, 0.95, 2.2), Vector3(0, 0.75, 0)],
	["low_back", Vector3(0.0, 0.35, 1.5), Vector3(0, 0.75, 0)],
	["side", Vector3(2.2, 0.85, 0), Vector3(0, 0.7, 0)],
	["front", Vector3(0, 0.95, -2.2), Vector3(0, 0.75, 0)],
	["chest", Vector3(0, 1.2, -1.1), Vector3(0, 1.05, 0)],
	["chest_34", Vector3(0.8, 1.25, -0.8), Vector3(0, 1.05, 0)],
	["chest_high", Vector3(0, 1.75, -0.7), Vector3(0, 1.0, 0)],
	["bust_side", Vector3(0.75, 1.05, -0.55), Vector3(0, 1.0, 0)],
	["bust_low", Vector3(0.15, 0.7, -0.75), Vector3(0, 1.0, 0)],
	["glute_close", Vector3(0, 0.8, 1.0), Vector3(0, 0.72, 0)],
	["glute_low", Vector3(0.2, 0.4, 0.9), Vector3(0, 0.72, 0)],
]


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.get_slice("=", 1).split(",")
		elif a.begins_with("--outfits="):
			outfits = a.get_slice("=", 1).split(",")
		elif a.begins_with("--views="):
			views = a.get_slice("=", 1).split(",")
		elif a.begins_with("--damage="):
			damage = float(a.get_slice("=", 1))
		elif not a.begins_with("--"):
			out = a
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(800, 900)
	_go.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _go() -> void:
	BattleDamage.set_all(damage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.32, 0.34, 0.38)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	env.environment.ambient_light_energy = 0.7
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	root.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 45
	root.add_child(cam)
	var eco = ECO.instantiate()
	eco.idle_motion = false
	eco.springs_enabled = false
	root.add_child(eco)
	await _frames(2)
	eco.set_process(false)  # hold the pose set below
	var anim := eco.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for dress: String in outfits:
		if dress != "":
			eco.wear(dress)
			eco.apply_suit()
		for pose: Array in POSES:
			if not only.is_empty() and not only.has(pose[0]):
				continue
			anim.play(pose[1])
			anim.seek(anim.current_animation_length * float(pose[2]), true)
			anim.pause()
			for view: Array in VIEWS:
				if not views.is_empty() and not views.has(view[0]):
					continue
				cam.look_at_from_position(view[1], view[2])
				await _frames(4)
				var path := out.path_join(("%s_" % dress if dress != "" else "") + "%s_%s.png" % [pose[0], view[0]])
				root.get_texture().get_image().save_png(path)
				print("shot ", path)
	quit()
