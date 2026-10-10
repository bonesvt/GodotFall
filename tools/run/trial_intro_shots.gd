extends SceneTree
## Stills of Level 2's opening (trial_intro.gd), day one of Ophelia's trial in
## Trial Bay 7: the bay dark and her frame empty, the orderlies bringing her
## in, her arms clamped up, the band going on, the visor, the screen starting
## once the bay powers up, then day 19: her hung in the frame with the bridge
## and gloves on, close on her face, and the wall log. Its shots, staged on
## the cell directly.
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
	sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * (shot % 3), CELL.y * (shot / 3)))
	shot += 1


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
	sheet = Image.create(CELL.x * 3, CELL.y * 3, false, Image.FORMAT_RGBA8)
	await _frames(40)
	cell.begin_intake()
	var intro = TrialIntro.new(null)
	intro.cell = cell
	intro._cam = Camera3D.new()
	cell.add_child(intro._cam)
	cam = intro._cam
	intro._build_orderlies()
	cell.ophelia.visible = false
	await _frames(20)
	await _still(intro, "empty")
	cell.ophelia.visible = true
	for o in intro._orderlies:
		o.visible = true
	await _frames(10)
	await _still(intro, "her")
	cell.intake_arms(1.0)
	for o in intro._orderlies:
		o.get_node("Arm").rotation.x = 2.6
	await _frames(20)
	await _still(intro, "arms")
	for o in intro._orderlies:
		o.get_node("Arm").rotation.x = 0.4
	cell.intake_gear(["band"], "band", 1.0)
	await _frames(10)
	await _still(intro, "neck")
	cell.intake_gear(["band", "cuff", "headphones", "visor"], "visor", 0.5)
	await _frames(10)
	await _still(intro, "close")
	cell.intake_gear(["band", "cuff", "headphones", "visor"], "visor", 1.0)
	for o in intro._orderlies:
		o.visible = false
	cell.power(true)
	cell.ophelia.mood(["closed"])
	await _frames(30)
	await _still(intro, "feed")
	cell.end_intake()
	await _frames(30)
	await _still(intro, "wide19")
	await _still(intro, "close19")
	await _still(intro, "log")
	sheet.save_png(out.path_join("trial_intro.png"))
	print("saved ", out.path_join("trial_intro.png"))
	quit()


func _still(intro, shot: String) -> void:
	intro._set_shot(shot)
	await _frames(8)
	_grab()
