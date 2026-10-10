extends SceneTree
## The Rig's mods on Eco (redline.gd, redline_body.gd), one panel each in the
## Rig's order, then every one that goes together at once. The size changes
## (heavy, long legs, long arms, compact) stand her beside herself as she is.
##   godot --path . --resolution 1280x720 -s res://tools/hub/redline_shots.gd -- <out_dir>
## Needs a renderer (not --headless). Writes <out_dir>/redline_changes.png.

const Redline := preload("res://scripts/hub/redline.gd")
const RedlineBody := preload("res://scripts/hub/redline_body.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")
const ECO := preload("res://assets/models/eco.tscn")
const CELL := Vector2i(400, 560)
const COLS := 6
## mod -> [camera offset from her, look-at height, fov, beside herself]
const VIEWS := {
	"wiring": [Vector3(0.75, -0.15, -0.8), 1.15, 34, false],
	"heavy": [Vector3(0.2, -0.25, -3.2), 0.95, 32, true],
	"legs": [Vector3(0.2, -0.25, -3.2), 0.95, 32, true],
	"core": [Vector3(2.5, -0.05, -0.5), 1.05, 40, false],
	"cat_ears": [Vector3(0.45, 0.12, -0.72), 1.56, 28, false],
	"tail": [Vector3(1.1, -0.2, 1.9), 0.9, 40, false],
	"red_eyes": [Vector3(0.1, 0.0, -0.52), 1.53, 16, false],
	"long_arms": [Vector3(0.2, -0.25, -3.2), 0.95, 32, true],
	"spurs": [Vector3(0.95, 0.0, -0.75), 1.0, 30, false],
	"vents": [Vector3(0.45, 0.0, -0.4), 1.42, 20, false],
	"freckles": [Vector3(0.2, -0.02, -0.85), 1.44, 26, false],
	"compact": [Vector3(0.2, -0.25, -3.2), 0.95, 32, true],
	"horns": [Vector3(0.5, 0.18, -0.75), 1.6, 28, false],
	"pointed_ears": [Vector3(0.55, 0.06, -0.55), 1.53, 26, false],
	"night_eyes": [Vector3(0.1, 0.0, -0.5), 1.53, 15, false],
	"scales": [Vector3(0.9, -0.5, -1.4), 0.6, 40, false],
	"wings": [Vector3(0.15, 0.25, 1.6), 1.25, 36, false],
	"all": [Vector3(1.4, -0.2, -3.4), 1.0, 44, false],
}

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
	var her_own: Node3D = ECO.instantiate()  # beside herself, as she is
	her_own.position = Vector3(-0.6, 0, 0.0)
	world.add_child(her_own)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.make_current()
	await _frames(20)
	var panels: Array = Redline.ORDER + ["all"]
	var rows := ceili(float(panels.size()) / COLS)
	var sheet := Image.create(CELL.x * COLS, CELL.y * rows, false, Image.FORMAT_RGBA8)
	var win := Vector2(root.get_texture().get_size())
	var cw := int(win.y * CELL.x / CELL.y)
	for i in panels.size():
		var key: String = panels[i]
		var mods: Array = [key]
		if key == "all":
			mods = []
			for m in Redline.ORDER:
				Redline.mods = mods
				Redline.charges = 1
				if Redline.blocked(m) == "":
					mods.append(m)
		RedlineBody.apply_mods(eco, mods)
		var view: Array = VIEWS[key]
		her_own.visible = view[3]
		await _frames(8)
		cam.fov = view[2]
		var at := Vector3(0, view[1], 0)
		cam.look_at_from_position(at + view[0], at)
		await _frames(6)
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.convert(Image.FORMAT_RGBA8)
		img = img.get_region(Rect2i(int((win.x - cw) * 0.5), 0, cw, int(win.y)))
		img.resize(CELL.x, CELL.y)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * (i % COLS), CELL.y * (i / COLS)))
	sheet.save_png(out.path_join("redline_changes.png"))
	print("wrote redline_changes.png")
	Redline.reset()
	quit()
