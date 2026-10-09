extends SceneTree
## Stills of Trial Bay 7, Ophelia's cell in Level 2 (holding_cell.gd): the bay
## from the street through the screen, her in the frame with the trial's gear
## on, the cart with the films and Marrow's Glass case, the wall screen, and
## the bay dark after Eco shorts it, the visor off her and the cuff left on.
##   godot --path . --resolution 1280x720 -s res://tools/run/trial_bay_shots.gd -- <out_dir>
## Needs a renderer (not --headless). Writes <out_dir>/trial_bay.png.

const HoldingCell := preload("res://scripts/run/holding_cell.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")
const CELL := Vector2i(960, 540)

var out := "user://trial_bay_shots"
var sheet: Image
var shot := 0
var cam: Camera3D


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		out = a
	DirAccess.make_dir_recursive_absolute(out)
	ContentRating.set_rating("M", false)
	_go.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _grab() -> void:
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(CELL.x, CELL.y)
	sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * (shot % 3), CELL.y * (shot / 3)))
	shot += 1


func _look(from: Vector3, at: Vector3, fov := 50.0) -> void:
	cam.fov = fov
	cam.look_at_from_position(from, at)
	await _frames(8)
	_grab()


func _go() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.03, 0.04, 0.07)
	env.environment.ambient_light_color = Color(0.25, 0.28, 0.35)
	env.environment.ambient_light_energy = 0.6
	env.environment.glow_enabled = true
	world.add_child(env)
	# the street outside, at night
	var street := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	street.mesh = plane
	world.add_child(street)
	var cell: Node3D = HoldingCell.new()
	world.add_child(cell)
	cam = Camera3D.new()
	world.add_child(cam)
	cam.make_current()
	sheet = Image.create(CELL.x * 3, CELL.y * 2, false, Image.FORMAT_RGBA8)
	await _frames(40)
	cell._hold()
	await _frames(30)
	var c: Vector3 = HoldingCell.COLUMN
	await _look(Vector3(0.4, 1.6, 4.2), Vector3(0, 1.3, -2.2), 55.0)                 # from the street
	await _look(c + Vector3(1.5, 1.3, 0.5), c + Vector3(0, 1.0, 0.1), 50.0)          # her in the frame, clamped, the screen in her face
	await _look(c + Vector3(0.15, 1.65, -0.25), c + Vector3(0, 1.5, 0.55), 60.0)     # over her shoulder: what it shows her
	await _look(Vector3(0.6, 1.8, -1.0), Vector3(-2.5, 1.95, -1.6), 50.0)            # the wall screen
	cell.release()
	await _frames(70)   # the visor comes off her
	await _look(Vector3(0.4, 1.6, 3.2), Vector3(0, 1.2, -2.2), 55.0)                 # shorted, dark
	await _look(c + Vector3(1.2, 1.5, 0.8), c + Vector3(0, 1.3, 0), 40.0)            # visor off, clamps open, cuff on
	sheet.save_png(out.path_join("trial_bay.png"))
	print("saved ", out.path_join("trial_bay.png"))
	quit()
