extends SceneTree
## Renders titan paint jobs and the garage screen for a reference sheet.
##   xvfb-run godot -s res://tools/titans/paint_showcase.gd -- --out=/tmp/paint
## Writes <out>/paint_<n>.png (a chassis in a styled paint job), garage.png
## and shop.png (the paint shop bench in the hub). Uses its own style file.

const Art := preload("res://scripts/ps2/ps2_assets.gd")
const TitanStyle := preload("res://scripts/run/titan_style.gd")
const Garage := preload("res://scripts/hub/garage.gd")

## chassis, style changes from DEFAULT.
const LOOKS := [
	["atlas", {"livery": "bubblegum", "lights": "pink", "core": "pink"}],
	["atlas", {"livery": "midnight", "canopy": "rose", "lights": "violet", "fenders": "big"}],
	["ogre", {"livery": "mint chip", "core": "green", "antenna": "tall"}],
	["ogre", {"livery": "cherry bomb", "stripe": "none", "stickers": "off", "fenders": "slim"}],
	["stryder", {"livery": "grape soda", "core": "gold", "lights": "amber"}],
	["stryder", {"livery": "snow cone", "lights": "mint", "core": "blue"}],
	["scrap", {"livery": "racing green", "canopy": "amber"}],
	["scrap", {"livery": "sunset", "core": "red", "antenna": "off"}],
]
const WEAPON := {"atlas": "xo16", "ogre": "tracker", "stryder": "splitter", "scrap": "scrap"}

var out := "/tmp/titan_paint"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	TitanStyle.path = "user://titan_style_showcase.cfg"
	DirAccess.remove_absolute(TitanStyle.path)
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(900, 900)
	var stage := Node3D.new()
	root.add_child(stage)
	Art.environment(stage, Color(0.3, 0.45, 0.7), Color(0.85, 0.78, 0.68))
	for node in stage.get_children():
		if node is WorldEnvironment:
			node.environment.fog_enabled = false
		if node is DirectionalLight3D:
			node.rotation_degrees = Vector3(-42, 205, 0)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	ground.mesh = plane
	ground.material_override = Art.material("dirt")
	stage.add_child(ground)
	var cam := Camera3D.new()
	cam.fov = 40.0
	stage.add_child(cam)
	cam.position = Vector3(-5.5, 5.0, -10.5)
	cam.look_at(Vector3(0, 4.0, 0))

	for i in LOOKS.size():
		var style := TitanStyle.DEFAULT.duplicate()
		style.merge(LOOKS[i][1], true)
		var model := Art.titan(LOOKS[i][0], WEAPON[LOOKS[i][0]])
		TitanStyle.apply(model, LOOKS[i][0], style)
		stage.add_child(model)
		await _frames(4)
		root.get_texture().get_image().save_png("%s/paint_%d.png" % [out, i])
		model.free()
	stage.free()

	# The garage screen, on a paint job with a few tweaks.
	root.size = Vector2i(1600, 900)
	var style := TitanStyle.DEFAULT.duplicate()
	style.merge({"livery": "bubblegum", "core": "pink", "lights": "pink", "fenders": "big"}, true)
	TitanStyle.save_style("atlas", style)
	var garage := Garage.new("atlas")
	root.add_child(garage)
	garage.select(1)
	await _frames(30)
	root.get_texture().get_image().save_png("%s/garage.png" % out)
	garage.free()

	# The paint shop bench in the hub.
	# No tutorial cards in the shots, and none marked seen on your save.
	preload("res://scripts/run/tutorial.gd").settings_path = "user://shots_settings.cfg"
	var run_node = load("res://scenes/run.tscn").instantiate()
	root.add_child(run_node)
	run_node.tutorial.set_enabled(false)
	await _frames(40)
	var shop := Vector3(10, 0, 45)
	var player: Node3D = run_node.player
	player.global_position = shop + Vector3(-1.5, 0.3, -5.5)
	player.rotation.y = atan2(-(shop.x - player.global_position.x), -(shop.z - player.global_position.z))
	await _frames(20)
	root.get_texture().get_image().save_png("%s/shop.png" % out)
	DirAccess.remove_absolute(TitanStyle.path)
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame
