extends SceneTree
## Screenshots of zones 2 and 3 (Blackwater and the Boneyard), for checking the look.
##   xvfb-run -a godot --path . -s res://tools/zones/shots.gd -- <out_dir> [2|3]
## Needs a renderer (not --headless). Writes <out_dir>/<zone>-<n>-<name>.png,
## including <zone>-0-map.png, a top-down map with the three routes drawn on it
## (loud red, quiet blue, high orange), grunts as red dots and caches as yellow.

const MB := preload("res://scripts/run/marsh_builder.gd")
const BB := preload("res://scripts/run/boneyard_builder.gd")
const Kit := preload("res://scripts/run/level_kit.gd")

var run_node
var out := "user://zone_shots"
var zones := [2, 3]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	if args.size() > 1:
		zones = [int(args[1])]
	DirAccess.make_dir_recursive_absolute(out)
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 1234
	run_node.start_in_hub = false
	root.add_child(run_node)
	_go.call_deferred()


func _shot(name: String, at: Vector3, look: Vector3) -> void:
	var player = run_node.player
	player.global_position = at
	player.velocity = Vector3.ZERO
	var eye := at + Vector3(0, 1.6, 0)
	var d := look - eye
	player.rotation.y = atan2(-d.x, -d.z)
	player.get_node("Head").rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
	for i in 8:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("shot ", name)


func _map(prefix: String, B, labels: Array) -> void:
	var zone: Node3D = run_node.zone_root
	for env in zone.find_children("*", "WorldEnvironment", true, false):
		env.environment.fog_enabled = false
		env.environment.volumetric_fog_enabled = false
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
	for spec in labels:
		var l := Kit.label(overlay, Vector3(B.trail_x(spec[1]) + 48.0, 70, spec[1]), spec[0], 160)
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
	for i in 8:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out.path_join(prefix + "-0-map.png"))
	print("shot map")
	cam.queue_free()
	overlay.queue_free()
	for env in zone.find_children("*", "WorldEnvironment", true, false):
		env.environment.fog_enabled = true
	run_node.player.get_node("Head/Camera3D").make_current()


func _p(B, x_off: float, z: float, up := 0.0) -> Vector3:
	return B._on(B.trail_x(z) + x_off, z, up)


func _load(index: int) -> void:
	run_node.load_zone(index)
	for i in 4:
		await process_frame
	run_node.hud.visible = false
	run_node.pilot_hud.visible = false
	run_node.player.process_mode = Node.PROCESS_MODE_DISABLED
	for g in run_node.zone_info["grunts"]:
		g.passive = true


func _marsh() -> void:
	await _load(1)
	var B = MB
	await _map("2", B, [["START", 6.0], ["ROADBLOCK", B.ROADBLOCK_Z], ["STILT VILLAGE", B.VILLAGE_Z], ["CHANNEL", B.CHANNEL_Z], ["PUMP STATION", B.STATION_Z], ["EXTRACT", B.END_Z]])
	await _shot("2-1-landing", _p(B, 0, 10), _p(B, 0, -30, 2))
	await _shot("2-2-roadblock", _p(B, -2, -22), _p(B, 0, -42, 1))
	await _shot("2-3-pipeline", Vector3(B.PIPE_X, B.PIPE_BERM + 3.7, -20.0), Vector3(B.PIPE_X - 4.0, 3.0, -70.0))
	await _shot("2-4-reeds", B._on(B.trail_x(-40.0) - 22.0, -40.0), B._on(B.trail_x(-80.0) - 18.0, -80.0, 1.0))
	await _shot("2-5-village", _p(B, -1, -72, 0), _p(B, 4, -100, 1))
	await _shot("2-6-rooftops", Vector3(20.0, B.HUT_Y + 5.4, -83.0), Vector3(14.0, 2.0, -110.0))
	var cr: float = B.trail_x(B.CHANNEL_Z)
	await _shot("2-7-channel", Vector3(cr + 1.0, 5.0, -113.0), Vector3(cr, 0.0, -140.0))
	await _shot("2-8-drowned-titan", Vector3(cr + B.LOG_X + 7.0, 4.0, -115.0), Vector3(cr + B.LOG_X, 0.0, -138.0))
	await _shot("2-9-station", _p(B, -2, -150, 0), _p(B, 8, -190, 3))
	await _shot("2-10-pump-roof", Vector3(B.trail_x(-192.0) + 15.0, B.PAD_Y + 6.0, -191.0), _p(B, -6, -170, 0))
	await _shot("2-11-hummock", _p(B, 0, -228), _p(B, 0, -252, 2))


func _boneyard() -> void:
	await _load(2)
	var B = BB
	await _map("3", B, [["START", 8.0], ["TRENCHES", B.FRONT_Z], ["NO-MAN'S LAND", -40.0], ["SALVAGE YARD", B.YARD_Z], ["RIFT", B.RIFT_Z], ["RUINS", B.RUINS_Z], ["EXTRACT", B.END_Z]])
	await _shot("3-1-front-line", _p(B, 0, 10), _p(B, 0, -40, 3))
	await _shot("3-2-trench", B._on(B.trench_x(-10.0), -10.0), B._on(B.trench_x(-30.0), -30.0, 0.5))
	var top: Vector3 = B._fallen_top()
	await _shot("3-3-titan-back", top + Vector3(0, 0.1, 8.0), top + Vector3(-6.0, -1.0, -30.0))
	await _shot("3-4-no-mans-land", _p(B, -3, -30), _p(B, 4, -62, 4))
	await _shot("3-5-yard-gate", _p(B, -2, -70), _p(B, 4, -108, 3))
	await _shot("3-6-yard", _p(B, -6, -94, 0), _p(B, 12, -114, 6))
	var cr: float = B.trail_x(B.RIFT_Z)
	await _shot("3-7-rift", Vector3(cr + 1.0, 4.0, -133.0), Vector3(cr, -2.0, -160.0))
	await _shot("3-8-obelisk", Vector3(cr + B.LOG_X + 7.0, 3.5, -135.0), Vector3(cr + B.LOG_X, -1.0, -158.0))
	await _shot("3-9-ruins", _p(B, 0, -176), _p(B, 0, -222, 4))
	await _shot("3-10-shrine", _p(B, -4, -210), _p(B, 0, -226, 4))
	await _shot("3-11-edge-of-burn", _p(B, 0, -232), _p(B, 0, -262, 3))


func _go() -> void:
	for i in 6:
		await process_frame
	if 2 in zones:
		await _marsh()
	if 3 in zones:
		await _boneyard()
	quit()
