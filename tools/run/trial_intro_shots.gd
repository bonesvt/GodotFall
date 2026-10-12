extends SceneTree
## Stills of Level 2's opening (trial_intro.gd), twelve moments through it,
## from the bay dark and empty, the orderlies walking her in, the clamp and
## each piece of gear, the screen starting, to day 19 and the wall log. It's
## staged from its clock (_seek()), letterbox and subtitles included.
##   godot --path . --resolution 1280x720 -s res://tools/run/trial_intro_shots.gd -- <out_dir>
## Needs a renderer (not --headless). Writes <out_dir>/trial_intro.png.

const HoldingCell := preload("res://scripts/run/holding_cell.gd")
const TrialIntro := preload("res://scripts/run/trial_intro.gd")
const CELL := Vector2i(960, 540)

var out := "user://trial_intro_shots"
var sheet: Image
var shot := 0
var cam: Camera3D


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		out = a
	DirAccess.make_dir_recursive_absolute(out)
	_go.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _grab() -> void:
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(CELL.x, CELL.y)
	sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * (shot % 4), CELL.y * (shot / 4)))
	shot += 1


const AT := [2.2, 4.6, 8.4, 13.2, 15.4, 18.6, 25.0, 28.4, 30.6, 36.6, 40.4, 43.6]


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
	var street := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	street.mesh = plane
	world.add_child(street)
	var cell: Node3D = HoldingCell.new()
	world.add_child(cell)
	sheet = Image.create(CELL.x * 4, CELL.y * 3, false, Image.FORMAT_RGBA8)
	await _frames(40)
	var intro = TrialIntro.new(null)
	root.add_child(intro)
	intro.stage(cell)
	for at in AT:
		# a few frames run up to it, so she turns and the gear settles
		for k in 6:
			intro._seek(at - 0.5 + k * 0.1)
			await _frames(2)
		await _frames(10)
		_grab()
	sheet.save_png(out.path_join("trial_intro.png"))
	print("saved ", out.path_join("trial_intro.png"))
	quit()
