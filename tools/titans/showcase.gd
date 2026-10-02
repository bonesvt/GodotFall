extends SceneTree
## Renders the titans for a reference sheet, in the game's lighting.
##   xvfb-run godot -s res://tools/titans/showcase.gd -- --out=/tmp/shots
## Writes <out>/<chassis>_<view>.png for every chassis (with its usual weapon)
## plus the four weapons on their own and the hub wreck.

const Art := preload("res://scripts/ps2/ps2_assets.gd")

const LINEUP := [
	["atlas", "xo16"], ["ogre", "tracker"], ["stryder", "splitter"],
	["scrap", "scrap"], ["enemy", "tracker"], ["wreck", ""],
]
## view -> camera position relative to the titan, and look-at height.
const VIEWS := {
	"front": [Vector3(-5.5, 5.0, -10.5), 4.0],
	"back": [Vector3(6.5, 6.0, 9.5), 4.2],
	"side": [Vector3(-11.0, 4.5, -1.5), 4.0],
}

var out := "/tmp/titan_shots"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(900, 900)
	var stage := Node3D.new()
	root.add_child(stage)
	Art.environment(stage, Color(0.3, 0.45, 0.7), Color(0.85, 0.78, 0.68))
	# No haze: the sheet is about the models.
	for node in stage.get_children():
		if node is WorldEnvironment:
			node.environment.fog_enabled = false
		# Light from over the camera's shoulder so the fronts aren't in shade.
		if node is DirectionalLight3D:
			node.rotation_degrees = Vector3(-42, 205, 0)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	ground.mesh = plane
	ground.material_override = Art.material("dirt")
	stage.add_child(ground)
	var cam := Camera3D.new()
	cam.fov = 40.0
	stage.add_child(cam)

	for pair in LINEUP:
		var model: Node3D
		if pair[0] == "wreck":
			model = Art.model("titan_wreck")
			model.find_child("WeaponMount", true, false).visible = false
		else:
			model = Art.titan(pair[0], pair[1])
		stage.add_child(model)
		for view in VIEWS:
			var v: Array = VIEWS[view]
			cam.position = v[0]
			cam.look_at(Vector3(0, v[1], 0))
			for i in 4:
				await process_frame
			root.get_texture().get_image().save_png("%s/%s_%s.png" % [out, pair[0], view])
		if pair[0] != "wreck":
			# The pilot's view: hull hidden as in titan.gd, camera at EYE.
			for part in model.get_children():
				if part is Node3D and not String(part.name).begins_with("Arm"):
					part.visible = false
			cam.fov = 85.0
			cam.position = Vector3(0, 6.2, 0)
			cam.look_at(Vector3(0, 5.6, -10))
			for i in 4:
				await process_frame
			root.get_texture().get_image().save_png("%s/%s_cockpit.png" % [out, pair[0]])
			cam.fov = 40.0
		model.free()

	for id in ["xo16", "tracker", "splitter", "scrap"]:
		var gun := Art.model("titan_weapon_" + id)
		gun.position = Vector3(0, 1.5, 0)
		stage.add_child(gun)
		cam.position = Vector3(4.6, 2.9, -3.2)
		cam.look_at(Vector3(0, 1.5, -1.3))
		for i in 4:
			await process_frame
		root.get_texture().get_image().save_png("%s/gun_%s.png" % [out, id])
		gun.free()
	quit()
