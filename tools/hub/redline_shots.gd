extends SceneTree
## Redline's changes on Eco (redline_body.gd), one panel each, then all of
## them at once: wrong ears, a heavy body, red eyes, a stretched neck, arms too
## long, long legs, forced posture, a tail, a head too small, and everything.
##   godot --path . --resolution 1280x720 -s res://tools/hub/redline_shots.gd -- <out_dir>
## Needs a renderer (not --headless). Writes <out_dir>/redline_changes.png.

const Redline := preload("res://scripts/hub/redline.gd")
const RedlineBody := preload("res://scripts/hub/redline_body.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")
const ECO := preload("res://assets/models/eco.tscn")
const CELL := Vector2i(400, 560)
## [changes, camera offset from her, look-at height, fov]
const PANELS := [
	[["ears"], Vector3(0.55, 0.25, -0.9), 1.55, 30],
	[["body"], Vector3(1.1, -0.2, -3.2), 0.95, 42],
	[["eyes"], Vector3(0.12, 0.0, -0.6), 1.52, 20],
	[["neck"], Vector3(0.9, 0.0, -2.2), 1.3, 38],
	[["arms"], Vector3(0.9, -0.1, -2.6), 1.0, 42],
	[["legs"], Vector3(1.0, -0.3, -3.0), 0.95, 42],
	[["posture"], Vector3(2.2, -0.05, -1.2), 1.15, 36],
	[["tail"], Vector3(1.0, -0.2, 1.9), 0.9, 40],
	[["head"], Vector3(0.5, 0.05, -1.25), 1.42, 26],
	[Redline.CHANGES, Vector3(1.4, -0.2, -3.4), 1.0, 44],
]

var out := "user://redline_shots"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		out = a
	DirAccess.make_dir_recursive_absolute(out)
	ContentRating.set_rating("M", false)
	_go.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _go() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.2, 0.17, 0.19)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.55, 0.58)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	world.add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(8, 8)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.3, 0.26, 0.27)
	floor_mi.material_override = fm
	world.add_child(floor_mi)
	var eco: Node3D = ECO.instantiate()
	world.add_child(eco)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.make_current()
	await _frames(20)
	var sheet := Image.create(CELL.x * 5, CELL.y * 2, false, Image.FORMAT_RGBA8)
	var win := Vector2(root.get_texture().get_size())
	var cw := int(win.y * CELL.x / CELL.y)
	for i in PANELS.size():
		Redline.changes = (PANELS[i][0] as Array).duplicate()
		RedlineBody.apply(eco)
		await _frames(8)
		cam.fov = PANELS[i][3]
		cam.look_at_from_position(Vector3(0, PANELS[i][2], 0) + PANELS[i][1], Vector3(0, PANELS[i][2], 0))
		await _frames(6)
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.convert(Image.FORMAT_RGBA8)
		img = img.get_region(Rect2i(int((win.x - cw) * 0.5), 0, cw, int(win.y)))
		img.resize(CELL.x, CELL.y)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * (i % 5), CELL.y * (i / 5)))
	sheet.save_png(out.path_join("redline_changes.png"))
	print("wrote redline_changes.png")
	Redline.reset()
	quit()