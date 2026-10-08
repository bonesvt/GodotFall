extends SceneTree
## The Shepherd's model (shepherd_model.gd) on its puppet (threat_model.gd),
## turned round on a plain stage: front, three-quarter mid-stride, side
## mid-stride, back, and its head close with the slit flared (tell).
##   godot --path . --resolution 1280x720 -s res://tools/hub/shepherd_model_shots.gd -- <out_dir>
## Needs a renderer (not --headless). Writes <out_dir>/shepherd_model.png.

const ThreatModel := preload("res://scripts/threats/threat_model.gd")
const ShepherdModel := preload("res://scripts/hub/shepherd_model.gd")
const CELL := Vector2i(384, 640)

var out := "user://shepherd_model_shots"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		out = a
	DirAccess.make_dir_recursive_absolute(out)
	_go.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _go() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.36, 0.38, 0.43)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.environment.ambient_light_energy = 0.6
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, 150, 0)
	root.add_child(sun)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	floor.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.3, 0.32, 0.36)
	floor.material_override = fm
	root.add_child(floor)
	var puppet := Node3D.new()
	puppet.set_script(ThreatModel)
	puppet.gait = "biped"
	puppet.stride_len = 1.9
	puppet.swing = 22.0
	puppet.add_child(ShepherdModel.build())
	root.add_child(puppet)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.fov = 34
	var win := Vector2(root.get_texture().get_size())
	var cw := int(win.y * CELL.x / CELL.y)
	var sheet := Image.create(CELL.x * 5, CELL.y, false, Image.FORMAT_RGBA8)
	# [yaw of the model, walking?, close on the head?]
	var shots := [[0.0, false, false], [35.0, true, false], [90.0, true, false], [180.0, false, false], [20.0, false, true]]
	for i in shots.size():
		puppet.rotation_degrees.y = shots[i][0]
		puppet.cycle_speed = 3.2 if shots[i][1] else 0.0
		puppet.tell = 1.0 if shots[i][2] else 0.0
		if shots[i][2]:
			cam.fov = 18
			cam.look_at_from_position(Vector3(0, 2.0, -1.6), Vector3(0, 1.95, 0))
		else:
			cam.fov = 34
			cam.look_at_from_position(Vector3(0, 1.15, -4.6), Vector3(0, 1.1, 0))
		await _frames(24 if shots[i][1] else 10)
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img = img.get_region(Rect2i(int((win.x - cw) * 0.5), 0, cw, int(win.y)))
		img.resize(CELL.x, CELL.y)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * i, 0))
	sheet.save_png(out.path_join("shepherd_model.png"))
	print("wrote shepherd_model.png")
	quit()
