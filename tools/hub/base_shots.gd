extends SceneTree
## Screenshots of the temple base: the hall downstairs (statue, Precursor
## lore, mission table, benches, rack), the stairs and Eco's loft bedroom,
## the tutorial poster outside with its marker, and the people's tents round
## the campfire, inside and out (hub_builder.gd, hub_rooms.gd).
##   xvfb-run -a godot --path . -s res://tools/hub/base_shots.gd -- [out_dir] [--only=hall,loft,...] [--small]
## Needs a renderer (not --headless). Writes <out_dir>/base_<view>.png.
## A software renderer (llvmpipe) runs out of instance shader parameter slots
## on the whole hub, grounds and town, so each shot only keeps what is within
## CULL m of the camera or what it looks at.

var run_node
var out := "user://base_shots"
var only: Array[String] = []
## --small renders at 960x540 (much quicker on a software renderer).
var small := false

const CULL := 50.0
var _parked: Array = []
const F := 1.2
const UP := 5.7
## name: [eye position (feet), look-at point]
const VIEWS := {
	"hall": [Vector3(1.5, F, 6.0), Vector3(-1.0, F + 2.5, -26)],
	"loft": [Vector3(3.5, F, -3.0), Vector3(-9.0, F + 4.6, -13)],
	"stairs": [Vector3(-3.5, F, 6.2), Vector3(-10.5, F + 2.5, 0.5)],
	"bedroom": [Vector3(-7.4, UP, -5.5), Vector3(-10.0, UP + 0.6, -14)],
	"desk": [Vector3(-7.6, UP, -19.5), Vector3(-10.5, UP + 1.0, -14.5)],
	"armor": [Vector3(-5.5, F, -0.8), Vector3(-10.6, F + 1.3, -2.4)],
	"mission": [Vector3(1.8, F, -3.4), Vector3(-0.3, F + 0.8, -7.6)],
	"lore": [Vector3(3.5, F, -21.5), Vector3(8.6, F + 1.8, -29.8)],
	"lore_left": [Vector3(-3.0, F, -23.5), Vector3(-8.6, F + 2.0, -29.8)],
	"poster": [Vector3(-6.0, 0.05, 20.5), Vector3(-13.2, 2.0, 15.6)],
	"marker": [Vector3(2.0, 0.05, 31.0), Vector3(-9.0, 2.5, 13.0)],
	"camp": [Vector3(37.0, 0.05, 25.0), Vector3(33.0, 2.5, 3.0)],
	"mom_tent": [Vector3(32.0, 0.05, 29.0), Vector3(22.0, 2.5, 23.5)],
	"mom_in": [Vector3(26.8, F, 24.2), Vector3(20.5, F + 1.0, 23.6)],
	"ophelia_in": [Vector3(28.1, F, 8.2), Vector3(26.5, F + 1.0, 0.0)],
	"biggie_in": [Vector3(43.1, F, 8.2), Vector3(41.5, F + 1.0, 0.0)],
	"overhead": [Vector3(14, 120, 4), Vector3(14, 0, 4.1)],
}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only.assign(a.trim_prefix("--only=").split(","))
		elif a == "--small":
			small = true
		elif not a.begins_with("--"):
			out = a
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(960, 540) if small else Vector2i(1600, 900)
	preload("res://scripts/run/tutorial.gd").settings_path = "user://shots_settings.cfg"
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 1234
	root.add_child(run_node)
	_go.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _go() -> void:
	await _frames(2)
	# The run manager makes its tutorial in _ready, after _initialize.
	run_node.tutorial.set_enabled(false)
	await _frames(18)
	for n in ["hud", "pilot_hud"]:
		if n in run_node and run_node.get(n) != null:
			run_node.get(n).visible = false
	var player = run_node.player
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var cam: Camera3D = player.get_node("Head/Camera3D")
	# No gun or its muzzle light in the way.
	for child in cam.get_children():
		if child is Node3D:
			child.visible = false
	for view in VIEWS:
		if not only.is_empty() and not view in only:
			continue
		var at: Vector3 = VIEWS[view][0]
		var look: Vector3 = VIEWS[view][1]
		await _cull(at, look, 200.0 if view == "overhead" else CULL)
		player.global_position = at
		var eye := at + Vector3(0, 1.6, 0)
		var d := look - eye
		player.rotation.y = atan2(-d.x, -d.z)
		player.get_node("Head").rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
		cam.far = 1200.0
		if view == "overhead":
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			cam.size = 95.0
		else:
			cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		await _frames(60)
		root.get_viewport().get_texture().get_image().save_png(out.path_join("base_%s.png" % view))
		print("shot ", view)
	quit()


## Takes everything out of the hub, then puts back only what's near this shot
## and hands each piece its paint again (the first time round many sets were
## refused for want of slots).
func _cull(eye: Vector3, look: Vector3, reach: float) -> void:
	var zr: Node3D = run_node.zone_root
	for n in zr.get_children():
		zr.remove_child(n)
		_parked.append(n)
	await process_frame
	var keep := []
	for n in _parked:
		if not n is Node3D or n is WorldEnvironment or n is DirectionalLight3D or n is MultiMeshInstance3D:
			keep.append(n)
			continue
		var p: Vector3 = (n as Node3D).position
		var flat := Vector2(p.x, p.z)
		if flat.distance_to(Vector2(eye.x, eye.z)) < reach or flat.distance_to(Vector2(look.x, look.z)) < reach * 0.6:
			keep.append(n)
	for n in keep:
		_parked.erase(n)
		zr.add_child(n)
	await process_frame
	for n in keep:
		var stack: Array = [n]
		while not stack.is_empty():
			var g: Node = stack.pop_back()
			stack.append_array(g.get_children())
			if g is GeometryInstance3D:
				for prop in g.get_property_list():
					var pn: String = prop["name"]
					if pn.begins_with("instance_shader_parameters/"):
						var key := pn.substr(27)
						g.set_instance_shader_parameter(key, g.get_instance_shader_parameter(key))
