extends SceneTree
## Stills of Eco's rest poses (scripts/ps2/eco_rest.gd) on stand-in furniture
## the size of the hub's: asleep on the bed, sitting and lounging on the couch,
## sitting on a log by the fire.
##   xvfb-run -a godot --path . --fixed-fps 30 -s res://tools/eco/rest_shots.gd -- [out_dir] [--only=sleep,sit,...]
## Needs a renderer (not --headless). Writes <pose>_<view>.png.

const ECO := preload("res://assets/models/eco.tscn")

var out := "user://rest_shots"
var only: Array = []

## pose, seat height, furniture boxes [centre, size] (model origin = floor under her hips),
## cameras [name, from, look at].
var SETUPS := [
	["sleep", 0.6, [[Vector3(0.25, 0.3, -0.2), Vector3(2.15, 0.6, 1.28)], [Vector3(-0.55, 0.62, -0.2), Vector3(0.45, 0.16, 0.85)]],
		[["front", Vector3(0.3, 1.5, -2.6), Vector3(-0.2, 0.7, -0.1)], ["above", Vector3(0.0, 2.8, -1.2), Vector3(-0.2, 0.6, -0.1)]]],
	["sit", 0.49, [[Vector3(0.0, 0.245, 0.2), Vector3(2.5, 0.49, 0.95)], [Vector3(0.0, 0.8, 0.67), Vector3(2.5, 0.8, 0.22)]],
		[["front", Vector3(-1.0, 1.1, -2.4), Vector3(0.0, 0.7, 0.0)], ["side", Vector3(-2.6, 0.9, -0.3), Vector3(0.0, 0.7, 0.0)]]],
	["lounge", 0.49, [[Vector3(0.0, 0.245, -0.45), Vector3(0.95, 0.49, 2.5)], [Vector3(-0.47, 0.8, -0.45), Vector3(0.22, 0.8, 2.5)],
			[Vector3(0.0, 0.6, 0.85), Vector3(1.0, 0.4, 0.16)], [Vector3(0.0, 0.6, -1.75), Vector3(1.0, 0.4, 0.16)],
			[Vector3(-0.15, 0.65, 0.5), Vector3(0.4, 0.3, 0.5)]],
		[["front", Vector3(1.8, 1.4, -1.4), Vector3(0.0, 0.6, -0.2)], ["side", Vector3(2.4, 1.0, -0.2), Vector3(0.0, 0.6, -0.2)]]],
	["sit", 0.44, [[Vector3(0.0, 0.22, 0.06), Vector3(1.1, 0.44, 0.45)]],
		[["fire", Vector3(-1.0, 1.0, -2.4), Vector3(0.0, 0.7, 0.0)]]],
]


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.get_slice("=", 1).split(",")
		elif not a.begins_with("--"):
			out = a
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(900, 700)
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
	sun.rotation_degrees = Vector3(-50, 150, 0)
	root.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 50
	root.add_child(cam)
	var done := {}
	for setup: Array in SETUPS:
		var pose: String = setup[0]
		if not only.is_empty() and not only.has(pose):
			continue
		var stage := Node3D.new()
		root.add_child(stage)
		var floor_mesh := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(8, 8)
		floor_mesh.mesh = plane
		stage.add_child(floor_mesh)
		for box: Array in setup[2]:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = box[1]
			mi.mesh = bm
			mi.position = box[0]
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.55, 0.45, 0.35)
			mi.material_override = mat
			stage.add_child(mi)
		var eco := ECO.instantiate()
		stage.add_child(eco)
		eco.rest_seat_height = setup[1]
		await _frames(2)
		eco.rest_pose = pose
		await _frames(2)
		eco._rest.weight = 1.0  # straight into the pose; a few frames for her hair to hang
		await _frames(24)
		for shot: Array in setup[3]:
			cam.look_at_from_position(shot[1], shot[2])
			await _frames(3)
			var name := "%s_%s" % [pose, shot[0]]
			root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
			print("wrote ", name)
		stage.queue_free()
		await _frames(2)
	quit()
