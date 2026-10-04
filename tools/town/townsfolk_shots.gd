extends SceneTree
## Pictures of the people of Solace (scripts/hub/townsfolk.gd).
##   godot --path . -s res://tools/town/townsfolk_shots.gd -- [out_dir] [--lineup] [--only=bench,...] [--small]
## --lineup: everyone side by side on a plain stage (front, back, sitting,
## walking). Otherwise views around town with them going about their day.
## Needs a renderer (not --headless). Writes <out_dir>/folk_<view>.png.

const Townsfolk := preload("res://scripts/hub/townsfolk.gd")
const Townsperson := preload("res://scripts/hub/townsperson.gd")

var out := "user://townsfolk_shots"
var only: Array[String] = []
var small := false
var lineup := false

## name: [eye position (feet), look-at point, seconds to wait first]
const VIEWS := {
	"bench": [Vector3(-6.5, 0.1, 168.5), Vector3(-11.5, 1.0, 166.0), 4.0],
	"stall": [Vector3(3.0, 0.1, 169.0), Vector3(6.5, 1.3, 164.5), 6.0],
	"scoops": [Vector3(-8.0, 0.1, 180.0), Vector3(-12.0, 1.3, 183.0), 8.0],
	"row": [Vector3(-1.0, 0.1, 132.5), Vector3(0.5, 1.5, 150.0), 3.0],
	"plaza": [Vector3(4.0, 0.1, 160.5), Vector3(-2.0, 2.0, 178.0), 10.0],
	"lowrow": [Vector3(0.5, 0.1, 213.0), Vector3(0.0, 1.5, 192.0), 12.0],
}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only.assign(a.trim_prefix("--only=").split(","))
		elif a == "--small":
			small = true
		elif a == "--lineup":
			lineup = true
		elif not a.begins_with("--"):
			out = a
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(960, 540) if small else Vector2i(1600, 900)
	if lineup:
		_lineup.call_deferred()
	else:
		_town.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _save(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(out.path_join("folk_%s.png" % name))
	print("shot ", name)


func _lineup() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.42, 0.45, 0.5)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	env.environment.ambient_light_energy = 0.6
	stage.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 25, 0)
	sun.light_energy = 1.2
	stage.add_child(sun)
	var floor_ := MeshInstance3D.new()
	floor_.mesh = PlaneMesh.new()
	floor_.mesh.size = Vector2(40, 20)
	stage.add_child(floor_)
	var names: Array = []
	for spec: Dictionary in Townsfolk.PEOPLE:
		names.append(spec["who"])
	var gap := 1.0
	var x0 := -gap * (names.size() - 1) / 2.0
	var folk := []
	for i in names.size():
		var p := Townsperson.create_town(names[i], Vector3(x0 + i * gap, 0, 0), 0.0, "stand")
		stage.add_child(p)
		folk.append(p)
	var cam := Camera3D.new()
	cam.fov = 40.0
	stage.add_child(cam)
	cam.make_current()
	await _frames(10)
	var width := gap * names.size()
	for view in [["front", 1.0], ["back", -1.0]]:
		cam.position = Vector3(0, 1.0, view[1] * -(width * 1.25))
		cam.look_at(Vector3(0, 0.95, 0))
		# the models face -Z: the front view looks from -Z
		await _frames(30)
		_save("lineup_" + view[0])
	# faces, half at a time
	for half in 2:
		var mid: float = x0 + (half * 5 + 2) * gap
		cam.position = Vector3(mid, 1.5, -3.6)
		cam.look_at(Vector3(mid, 1.45, 0))
		await _frames(20)
		_save("faces_%d" % half)
	for p in folk:
		var anim := p.find_child("AnimationPlayer", true, false) as AnimationPlayer
		anim.play("walk")
		anim.seek(0.27, true)
	cam.position = Vector3(-width * 0.9, 1.1, -width * 0.9)
	cam.look_at(Vector3(0, 0.9, 0))
	await _frames(20)
	_save("lineup_walk")
	for p in folk:
		var anim := p.find_child("AnimationPlayer", true, false) as AnimationPlayer
		anim.play("sit")
		anim.seek(0.0, true)
		var seat := MeshInstance3D.new()
		seat.mesh = BoxMesh.new()
		seat.mesh.size = Vector3(0.8, 0.45, 0.45)
		seat.position = p.position + Vector3(0, 0.225, 0.12)
		stage.add_child(seat)
	cam.position = Vector3(-width * 0.6, 1.0, -width * 0.8)
	cam.look_at(Vector3(0, 0.6, 0))
	await _frames(20)
	_save("lineup_sit")
	quit()


func _town() -> void:
	preload("res://scripts/run/tutorial.gd").settings_path = "user://shots_settings.cfg"
	var run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 1234
	root.add_child(run_node)
	await _frames(2)
	run_node.tutorial.set_enabled(false)
	await _frames(18)
	for n in ["hud", "pilot_hud"]:
		if n in run_node and run_node.get(n) != null:
			run_node.get(n).visible = false
	var player = run_node.player
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var cam: Camera3D = player.get_node("Head/Camera3D")
	for child in cam.get_children():
		if child is Node3D:
			child.visible = false
	for view in VIEWS:
		if not only.is_empty() and not view in only:
			continue
		var at: Vector3 = VIEWS[view][0]
		var look: Vector3 = VIEWS[view][1]
		player.global_position = at
		var eye := at + Vector3(0, 1.6, 0)
		var d := look - eye
		player.rotation.y = atan2(-d.x, -d.z)
		player.get_node("Head").rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
		var end := Time.get_ticks_msec() + int(float(VIEWS[view][2]) * 1000.0)
		while Time.get_ticks_msec() < end:
			await process_frame
		_save(view)
	quit()
