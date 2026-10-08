extends SceneTree
## The Shepherd's gear up close on Eco, all eight pieces on her: the old
## primitive build (top row) and the Blender models (bottom row,
## tools/hub/build_colony_gear.py). Her head three-quarter, her head in profile,
## the band from the front, her left wrist and glove, her back, the Crown.
##   godot --path . --resolution 1280x720 -s res://tools/hub/gear_closeups.gd -- <out_dir>
## Needs a renderer (not --headless). Writes <out_dir>/gear_closeups.png.

const Hymn := preload("res://scripts/hub/hymn.gd")
const ColonyGear := preload("res://scripts/hub/colony_gear.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")
const ECO := preload("res://assets/models/eco.tscn")
const CELL := Vector2i(480, 480)
## [camera offset from the spot, the spot] in her rest model space (she faces -Z).
const SHOTS := [
	[Vector3(-0.32, 0.06, -0.42), Vector3(0, 1.52, -0.01)],
	[Vector3(-0.5, 0.02, -0.02), Vector3(0, 1.52, 0.0)],
	[Vector3(-0.06, -0.02, -0.3), Vector3(0, 1.38, -0.02)],
	[Vector3(-0.32, 0.1, -0.38), Vector3(-0.2, 0.86, -0.02)],
	[Vector3(0.25, 0.1, 0.62), Vector3(0, 1.15, 0.08)],
	[Vector3(0.2, 0.32, -0.36), Vector3(0, 1.6, 0.0)],
]

var out := "user://gear_closeups"


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
	env.environment.background_color = Color(0.16, 0.17, 0.2)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.58, 0.65)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	world.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, 150, 0)
	fill.light_energy = 0.5
	world.add_child(fill)
	var eco: Node3D = ECO.instantiate()
	world.add_child(eco)
	eco.rotation.y = 0.0
	var cam := Camera3D.new()
	cam.fov = 30
	world.add_child(cam)
	cam.make_current()
	await _frames(20)
	Hymn.gear = Hymn.GEAR.duplicate()
	var sheet := Image.create(CELL.x * SHOTS.size(), CELL.y * 2, false, Image.FORMAT_RGBA8)
	var win := Vector2(root.get_texture().get_size())
	var cw := int(win.y)
	for row in 2:
		ColonyGear.use_models = row == 1
		ColonyGear.apply(eco)
		await _frames(6)
		for col in SHOTS.size():
			var at: Vector3 = SHOTS[col][1]
			cam.look_at_from_position(at + SHOTS[col][0], at)
			await _frames(4)
			var img := root.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			img = img.get_region(Rect2i(int((win.x - cw) * 0.5), 0, cw, cw))
			img.resize(CELL.x, CELL.y)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * col, CELL.y * row))
	sheet.save_png(out.path_join("gear_closeups.png"))
	print("wrote gear_closeups.png")
	quit()