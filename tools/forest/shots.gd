extends SceneTree
## Screenshots of the forest level and the forest's edge, for checking the look.
##   xvfb-run -a godot --path . -s res://tools/forest/shots.gd -- [out_dir]
## Needs a renderer (not --headless). Writes <out_dir>/<n>-<name>.png.

const FB := preload("res://scripts/run/forest_builder.gd")
const Kit := preload("res://scripts/run/level_kit.gd")

var run_node
var out := "user://forest_shots"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	# No tutorial cards in the shots, and none marked seen on your save.
	preload("res://scripts/run/tutorial.gd").settings_path = "user://shots_settings.cfg"
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 1234
	run_node.start_in_hub = false
	root.add_child(run_node)
	run_node.tutorial.set_enabled(false)
	_go.call_deferred()


func _shot(name: String, at: Vector3, look: Vector3) -> void:
	var player = run_node.player
	player.global_position = at
	player.velocity = Vector3.ZERO
	var eye := at + Vector3(0, 1.6, 0)
	var d := look - eye
	player.rotation.y = atan2(-d.x, -d.z)
	player.get_node("Head").rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
	for i in 12:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	print("shot ", name)


func _v(x: float, z: float, up: float) -> Vector3:
	return FB._on(x, z, up)


## Top-down map of zone 1 with the three routes drawn over it, grunts as red
## dots and caches as yellow ones. The valley runs left (start) to right (extract).
func _map() -> void:
	var zone: Node3D = run_node.zone_root
	for env in zone.find_children("*", "WorldEnvironment", true, false):
		env.environment.fog_enabled = false
	var overlay := Node3D.new()
	zone.add_child(overlay)
	var colors := {"loud": Color(1.0, 0.25, 0.2), "quiet": Color(0.3, 0.8, 1.0), "high": Color(1.0, 0.7, 0.15)}
	for route in run_node.zone_info["routes"]:
		var pts: PackedVector3Array = route["points"]
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = colors[route["kind"]]
		for i in pts.size() - 1:
			var a := Vector3(pts[i].x, 60, pts[i].z)
			var b := Vector3(pts[i + 1].x, 60, pts[i + 1].z)
			var mi := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(1.8, 0.2, a.distance_to(b) + 1.8)
			box.material = mat
			mi.mesh = box
			mi.position = (a + b) * 0.5
			mi.rotation.y = atan2(b.x - a.x, b.z - a.z)
			overlay.add_child(mi)
	for g in run_node.zone_info["grunts"]:
		Kit.disc(overlay, Vector3(g.global_position.x, 61, g.global_position.z), 1.6, Color(1, 0.1, 0.1))
	for cache in run_node.zone_info["caches"]:
		Kit.disc(overlay, Vector3(cache.global_position.x, 61, cache.global_position.z), 2.0, Color(1, 0.9, 0.2) if not cache.locked else Color(1, 0.5, 0.1))
	for spec in [["START", 4.0], ["WALL", FB.WALL_Z], ["OUTPOST", FB.OUTPOST_Z - 10.0], ["RAVINE", FB.RAVINE_Z], ["LOGGING CAMP", FB.CAMP_Z], ["EXTRACT", FB.END_Z]]:
		var l := Kit.label(overlay, Vector3(FB.trail_x(spec[1]) + 44.0, 70, spec[1]), spec[0], 160)
		l.pixel_size = 0.05
		l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		l.rotation_degrees = Vector3(-90, 90, 0)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 168.0
	cam.far = 400.0
	cam.transform = Transform3D(Basis(Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)), Vector3(0, 150, -120))
	zone.add_child(cam)
	cam.make_current()
	for i in 12:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out.path_join("0-map.png"))
	print("shot 0-map")
	cam.queue_free()
	overlay.queue_free()
	for env in zone.find_children("*", "WorldEnvironment", true, false):
		env.environment.fog_enabled = true
	run_node.player.get_node("Head/Camera3D").make_current()


func _p(x_off: float, z: float, up := 0.0) -> Vector3:
	return FB._on(FB.trail_x(z) + x_off, z, up)


func _go() -> void:
	for i in 10:
		await process_frame
	run_node.hud.visible = false
	run_node.pilot_hud.visible = false
	run_node.player.process_mode = Node.PROCESS_MODE_DISABLED
	for g in run_node.zone_info["grunts"]:
		g.passive = true
	await _map()
	await _shot("1-spawn", _p(0, 6), _p(0, -30, 2))
	await _shot("1b-creek", _v(FB.creek_x(-20.0), -20.0, 0.0), _v(FB.creek_x(-45.0), -45.0, 0.5))
	await _shot("1c-ridge", _v(FB.ridge_x(-30.0), -30.0, 0.0), _v(FB.ridge_x(-58.0), -60.0, 3.0))
	await _shot("3b-culvert", _v(FB.creek_x(-50.0), -50.0, 0.0), _p(FB.CULVERT_X, -60, 0.0))
	await _shot("5b-tents", _p(-22, -66), _p(-25, -92, 0.5))
	await _shot("2-picket", _p(-3, -20), _p(0, -36, 1))
	await _shot("3-wall", _p(4, -42), _p(2, -60, 4))
	await _shot("4-breach", _p(16, -52), _p(16, -70, 1))
	await _shot("5-outpost", _p(-6, -66, 7.1), _p(4, -96, 0))
	await _shot("6-ravine", _p(2, -112), _p(0, -140, 1))
	await _shot("7-ravine-side", _p(26, -118), _p(10, -136, -2))
	await _shot("7b-ravine-high", _p(-14, -110, 9.0), _p(0, -138, -4))
	var cr := FB.trail_x(FB.RAVINE_Z)
	await _shot("7c-log-bridge", _v(cr + FB.LOG_X, -114.0, 0.0), _v(cr + FB.LOG_X, -150.0, 0.0))
	await _shot("8-camp", _p(0, -160), _p(4, -190, 2))
	var c2 := FB.trail_x(FB.CAMP_Z)
	await _shot("8b-blind", _v(c2 - 26.0, -182.0, 3.0), _v(c2 + 4.0, -186.0, 0.0))
	await _shot("9-camp-roof", _p(6, -192, 5.0), _p(-6, -175, 0))
	await _shot("10-clearing", _p(0, -228), _p(0, -250, 2))
	run_node.load_zone(3)
	run_node.player.process_mode = Node.PROCESS_MODE_DISABLED
	for i in 5:
		await process_frame
	run_node.hud.visible = false
	await _shot("11-edge", Vector3(0, 0, 34), Vector3(0, 3, -20))
	await _shot("12-edge-flank", Vector3(-30, 0, 20), Vector3(10, 2, -30))
	run_node.boss.hp = 1.0
	run_node.boss.active = true
	run_node.boss.take_damage(10.0)
	for i in 300:
		await process_frame
	run_node.hud.visible = false
	await _shot("13-evac", Vector3(24, 0, -8), FB.EVAC + Vector3(0, 9, 0))
	quit()
