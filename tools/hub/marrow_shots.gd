extends SceneTree
## Marrow the shadow man (hush_den.gd figure(), tools/hub/build_marrow.py) in a
## dim room: standing (full, then his hood and ember up close) and sunk in an
## armchair (full, then from low and in front).
##   godot --path . --resolution 1280x720 -s res://tools/hub/marrow_shots.gd -- <out_dir>
## Needs a renderer (not --headless). Writes <out_dir>/marrow.png.

const HushDen := preload("res://scripts/hub/hush_den.gd")
const CELL := Vector2i(640, 720)
## [camera, look at] for each panel; standing at x -1.5, sitting at x +1.5.
const SHOTS := [
	[Vector3(-0.6, 1.3, -2.9), Vector3(-1.5, 1.05, 0)],
	[Vector3(-1.25, 1.75, -0.85), Vector3(-1.5, 1.6, 0)],
	[Vector3(2.3, 1.1, -2.5), Vector3(1.5, 0.75, -0.1)],
	[Vector3(1.45, 0.55, -1.35), Vector3(1.5, 1.05, 0)],
]

var out := "user://marrow_shots"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		out = a
	DirAccess.make_dir_recursive_absolute(out)
	_go.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _box(world: Node3D, at: Vector3, size: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	mi.material_override = m
	mi.position = at
	world.add_child(mi)


func _go() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.25, 0.24, 0.28)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.3, 0.28, 0.35)
	env.environment.ambient_light_energy = 1.6
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.add_child(env)
	_box(world, Vector3(0, -0.05, 0), Vector3(8, 0.1, 6), Color(0.32, 0.29, 0.27))
	_box(world, Vector3(0, 1.5, 1.6), Vector3(8, 3, 0.1), Color(0.3, 0.27, 0.3))
	# his armchair
	_box(world, Vector3(1.5, 0.22, -0.05), Vector3(0.8, 0.44, 0.75), Color(0.3, 0.1, 0.14))
	_box(world, Vector3(1.5, 0.75, 0.3), Vector3(0.8, 0.9, 0.18), Color(0.3, 0.1, 0.14))
	for s in [-1.0, 1.0]:
		_box(world, Vector3(1.5 + 0.38 * s, 0.6, -0.05), Vector3(0.14, 0.32, 0.75), Color(0.28, 0.09, 0.12))
	var lamp := SpotLight3D.new()
	lamp.position = Vector3(0, 2.8, -1.6)
	lamp.rotation_degrees = Vector3(-60, 0, 0)
	lamp.spot_range = 6.0
	lamp.spot_angle = 50.0
	lamp.light_energy = 4.0
	lamp.light_color = Color(1.0, 0.85, 0.7)
	lamp.shadow_enabled = true
	world.add_child(lamp)
	HushDen.figure(world, Vector3(-1.5, 0, 0), 0.0)
	HushDen.figure(world, Vector3(1.5, 0, 0), 0.0, true)
	var cam := Camera3D.new()
	cam.fov = 40
	world.add_child(cam)
	cam.make_current()
	await _frames(90)  # the smoke up
	var sheet := Image.create(CELL.x * SHOTS.size(), CELL.y, false, Image.FORMAT_RGBA8)
	var win := Vector2(root.get_texture().get_size())
	var cw := int(win.y * CELL.x / CELL.y)
	for i in SHOTS.size():
		cam.fov = 26 if i % 2 == 1 else 40
		cam.look_at_from_position(SHOTS[i][0], SHOTS[i][1])
		await _frames(6)
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)  # what's on screen: no alpha from his see-through edges
		img.convert(Image.FORMAT_RGBA8)
		img = img.get_region(Rect2i(int((win.x - cw) * 0.5), 0, cw, int(win.y)))
		img.resize(CELL.x, CELL.y)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * i, 0))
	sheet.save_png(out.path_join("marrow.png"))
	print("wrote marrow.png")
	quit()