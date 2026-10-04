extends SceneTree
## Screenshots of Solace, Eco's hometown past the hub's front gate (town.gd).
##   xvfb-run -a godot --path . -s res://tools/hub/town_shots.gd -- [out_dir] [--only=gate,row,...] [--small]
## Needs a renderer (not --headless). Writes <out_dir>/town_<view>.png.

var run_node
var out := "user://town_shots"
var only: Array[String] = []
## --small renders at 960x540 (much quicker on a software renderer).
var small := false

## name: [eye position (feet), look-at point]
const VIEWS := {
	"road": [Vector3(1.5, 0.1, 99), Vector3(0, 6, 140)],
	"gate": [Vector3(-2, 0.1, 118), Vector3(0, 7, 136)],
	"row": [Vector3(-2.5, 0.1, 138), Vector3(0.5, 4.5, 160)],
	"noodles": [Vector3(-3.5, 0.1, 145), Vector3(6.5, 3.0, 139)],
	"plaza": [Vector3(3, 0.1, 161), Vector3(-2, 6, 178)],
	"scoops": [Vector3(-9, 0.1, 179.5), Vector3(-15.5, 3.5, 187.5)],
	"gifts": [Vector3(10.5, 0.1, 180.0), Vector3(15.5, 2.2, 187.5)],
	"gift_shelves": [Vector3(15.5, 0.1, 183.2), Vector3(15.5, 1.3, 189.0)],
	"recruitment": [Vector3(-6, 0.1, 172), Vector3(-22, 4, 176)],
	"cafe": [Vector3(8, 0.1, 168), Vector3(24, 3, 176)],
	"lowrow": [Vector3(2.5, 0.1, 195), Vector3(-1, 4.5, 214)],
	"flat": [Vector3(3, 0.1, 205), Vector3(-7, 3, 209)],
	"garden": [Vector3(-6, 5.2, 229), Vector3(10, 5, 300)],
	"overhead": [Vector3(0, 150, 176), Vector3(0, 0, 176.1)],
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
		player.global_position = at
		var eye := at + Vector3(0, 1.6, 0)
		var d := look - eye
		player.rotation.y = atan2(-d.x, -d.z)
		player.get_node("Head").rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
		cam.far = 1200.0
		if view == "overhead":
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			cam.size = 170.0
		else:
			cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		# Long enough for the dusk under the canopy (town_mood.gd) to settle.
		await _frames(120)
		root.get_viewport().get_texture().get_image().save_png(out.path_join("town_%s.png" % view))
		print("shot ", view)
	quit()
