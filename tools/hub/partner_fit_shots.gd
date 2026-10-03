extends SceneTree
## Mom or Ophelia side by side untrained, half and fully trained in Biggie's
## gym (gym.gd, hub_npc.gd set_fitness), in their gym clothes, for comparing
## what training does to them.
##   xvfb-run -a godot --audio-driver Dummy --path . -s res://tools/hub/partner_fit_shots.gd -- <out_dir> <mom|ophelia> [front,side,back]
## Needs a renderer (not --headless).

const HubNpc := preload("res://scripts/hub/hub_npc.gd")
const GymWorkout := preload("res://scripts/hub/gym_workout.gd")
const Gym := preload("res://scripts/hub/gym.gd")
const LEVELS := [0.0, 0.5, 1.0]
const GAP := 0.95

var out := "user://partner_fit"
var who := "mom"
var views: PackedStringArray = ["front", "side", "back"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	if args.size() > 1:
		who = args[1]
	if args.size() > 2:
		views = args[2].split(",")
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280, 720)
	_go.call_deferred()


func _go() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.2, 0.2, 0.23)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.6)
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 30, 0)
	sun.shadow_enabled = true
	world.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(8, 8)
	floor_mesh.mesh = plane
	world.add_child(floor_mesh)
	var labels := []
	for i in LEVELS.size():
		var npc := HubNpc.create(who, Vector3((i - 1) * GAP, 0, 0), 0.0)
		var fit := {}
		for part in Gym.PARTS:
			fit[part] = LEVELS[i]
		npc.set_fitness(fit)
		world.add_child(npc)
		npc.wear(GymWorkout.GYM_CLOTHES.get(who, ""))
		var label := Label3D.new()
		label.text = ["UNTRAINED", "HALF", "FULLY TRAINED"][i]
		label.font_size = 40
		label.pixel_size = 0.0025
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3((i - 1) * GAP, 1.95, 0)
		world.add_child(label)
	var cam := Camera3D.new()
	cam.fov = 32
	world.add_child(cam)
	cam.make_current()
	await _frames(20)
	for v in views:
		# they face -Z: the front camera stands on -Z
		match v:
			"front":
				cam.look_at_from_position(Vector3(0, 1.05, -5.4), Vector3(0, 0.9, 0))
			"back":
				cam.look_at_from_position(Vector3(0, 1.05, 5.4), Vector3(0, 0.9, 0))
			"side":
				cam.look_at_from_position(Vector3(-4.6, 1.05, -2.8), Vector3(0, 0.9, 0))
		await _frames(4)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join("%s-%s.png" % [who, v]))
		print("saved ", who, "-", v)
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame
