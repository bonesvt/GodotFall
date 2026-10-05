extends SceneTree
## Close-ups of Eco's extras from Solace (scripts/hub/eco_extras.gd): her
## piercings, tattoos and accessories.
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/ink/ink_shots.gd -- <out_dir>
##       [--outfit=date] [--pierce=lobes,septum] [--ink=all] [--wear=shades] [--only=face,arms]
## Writes <out_dir>/ink_<outfit>_<view>.png. --ink=all / --pierce=all puts everything on.

const ECO := preload("res://assets/models/eco.tscn")
const Extras := preload("res://scripts/hub/eco_extras.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")

## view: [camera position, look at] (model space; she faces -Z, her left is -X)
const VIEWS := {
	"face": [Vector3(0.0, 1.52, -0.42), Vector3(0, 1.5, 0)],
	"face_l": [Vector3(-0.32, 1.53, -0.28), Vector3(-0.02, 1.5, 0)],
	"face_r": [Vector3(0.32, 1.53, -0.28), Vector3(0.02, 1.5, 0)],
	"full": [Vector3(0.6, 1.2, -2.3), Vector3(0, 0.95, 0)],
	"arm_l": [Vector3(-0.42, 1.75, -0.18), Vector3(-0.42, 1.34, 0.0)],
	"arm_l_under": [Vector3(-0.42, 0.95, -0.12), Vector3(-0.42, 1.34, 0.0)],
	"arm_r": [Vector3(0.36, 1.75, -0.2), Vector3(0.36, 1.34, 0.0)],
	"chest": [Vector3(-0.05, 1.36, -0.45), Vector3(-0.05, 1.33, 0)],
	"back": [Vector3(0.05, 1.3, 0.55), Vector3(0.05, 1.28, 0)],
	"mouth": [Vector3(0.08, 1.49, -0.26), Vector3(0, 1.48, 0)],
	"neck": [Vector3(0.1, 1.44, -0.4), Vector3(0, 1.42, 0)],
	"navel": [Vector3(0.08, 1.1, -0.42), Vector3(0, 1.06, 0)],
	"small_back": [Vector3(0.0, 1.1, 0.6), Vector3(0, 1.04, 0)],
	"hip_l": [Vector3(-0.6, 1.08, -0.15), Vector3(-0.08, 1.04, 0)],
	"thigh_r": [Vector3(0.7, 0.7, -0.15), Vector3(0.1, 0.62, 0)],
}

var out := "user://ink_shots"
var outfit := "y2k"
var worn := {"piercings": [], "tattoos": [], "accessories": []}
var only: Array[String] = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--outfit="):
			outfit = a.trim_prefix("--outfit=")
		elif a.begins_with("--pierce="):
			worn["piercings"] = _ids(a.trim_prefix("--pierce="), Extras.PIERCINGS)
		elif a.begins_with("--ink="):
			worn["tattoos"] = _ids(a.trim_prefix("--ink="), Extras.TATTOOS)
		elif a.begins_with("--wear="):
			worn["accessories"] = _ids(a.trim_prefix("--wear="), Extras.ACCESSORIES)
		elif a.begins_with("--only="):
			only.assign(a.trim_prefix("--only=").split(","))
		elif not a.begins_with("--"):
			out = a
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(900, 900)
	_go.call_deferred()


func _ids(arg: String, catalog: Dictionary) -> Array:
	return catalog.keys() if arg == "all" else Array(arg.split(",", false))


func _go() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	Art.environment(stage, Color(0.22, 0.2, 0.24), Color(0.5, 0.46, 0.5))
	for node in stage.get_children():
		if node is WorldEnvironment:
			node.environment.fog_enabled = false
		if node is DirectionalLight3D:
			node.rotation_degrees = Vector3(-35, 160, 0)
	var eco: Node3D = ECO.instantiate()
	eco.idle_motion = false
	eco.springs_enabled = false
	stage.add_child(eco)
	eco.outfit = outfit
	Extras.apply(eco, worn)
	var cam := Camera3D.new()
	cam.fov = 30.0
	stage.add_child(cam)
	cam.current = true
	for view: String in VIEWS:
		if not only.is_empty() and not only.has(view):
			continue
		cam.look_at_from_position(VIEWS[view][0], VIEWS[view][1])
		cam.fov = 45.0 if view == "full" else 30.0
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/ink_%s_%s.png" % [out, outfit, view]
		root.get_texture().get_image().save_png(path)
		print("saved ", path)
	quit()
