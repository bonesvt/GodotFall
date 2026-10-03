extends SceneTree
## Pictures of the salon's haircuts (scripts/hub/hair.gd) on Eco and Ophelia,
## front and back, in the game's toon shading; then Juno in front of Cut &
## Chrome in town. For checking the look.
##   xvfb-run -a godot --audio-driver Dummy --path . -s res://tools/salon/salon_shots.gd -- [out_dir] [--no-town]
## Needs a renderer (not --headless). Doesn't touch the real save files.

const Hair := preload("res://scripts/hub/hair.gd")
const HubNpc := preload("res://scripts/hub/hub_npc.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")
const ECO := preload("res://assets/models/eco.tscn")
const Town := preload("res://scripts/hub/town.gd")

var out := "user://salon_shots"
var town := true
var cam: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a == "--no-town":
			town = false
		elif not a.begins_with("--"):
			out = a
	DirAccess.make_dir_recursive_absolute(out)
	Hair.save_path = "user://shots_salon.cfg"
	_go.call_deferred()


func _go() -> void:
	root.size = Vector2i(560, 640)
	var stage := Node3D.new()
	root.add_child(stage)
	Art.environment(stage, Color(0.12, 0.08, 0.13), Color(0.32, 0.22, 0.28))
	for node in stage.get_children():
		if node is WorldEnvironment:
			node.environment.fog_enabled = false
		if node is DirectionalLight3D:
			node.rotation_degrees = Vector3(-38, 200, 0)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.85, 0.9)
	lamp.light_energy = 1.2
	lamp.omni_range = 20.0
	lamp.position = Vector3(0.6, 2.2, 1.8)
	stage.add_child(lamp)
	cam = Camera3D.new()
	cam.fov = 32.0
	stage.add_child(cam)
	cam.make_current()
	for who in ["eco", "ophelia"]:
		var holder := Node3D.new()
		stage.add_child(holder)
		var model: Node3D
		if who == "eco":
			model = ECO.instantiate()
			model.idle_motion = false
			model.springs_enabled = false
			holder.add_child(model)
		else:
			var npc := HubNpc.create(who, Vector3.ZERO, 0.0)
			holder.add_child(npc)
			await _frames(1)
			model = npc.get_node("Model")
			var anim := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
			if anim != null:
				anim.pause()
		var top := 1.38 if who == "eco" else 1.32
		for style in Hair.style_ids(who):
			Hair.apply(model, who, style)
			for view in [["front", PI], ["back", 0.0], ["side", PI * 0.5]]:
				holder.rotation.y = view[1]
				cam.look_at_from_position(Vector3(0, top + 0.06, 2.3), Vector3(0, top - 0.12, 0))
				await _frames(3)
				await _save("%s_%s_%s" % [who, style, view[0]])
		holder.queue_free()
		await _frames(2)
	stage.queue_free()
	if town:
		await _town()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Hair.save_path))
	quit()


## The salon on the plaza: the run scene in the hub, the camera on the plaza.
func _town() -> void:
	root.size = Vector2i(1280, 720)
	var run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 1234
	run_node.armory_path = "user://shots_salon_armory.cfg"
	run_node.npc_path = "user://shots_salon_npcs.cfg"
	root.add_child(run_node)
	await _frames(30)
	for layer in root.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var gun: Node3D = run_node.player.get_node_or_null("Head/Camera3D/Weapon")
	if gun != null:
		gun.visible = false
	var c := Vector3(Town.PLAZA.end.x, 0, Town.SALON_Z)
	await _view(run_node, c + Vector3(-11.0, 1.7, -5.0), c + Vector3(0, 2.2, 0), "town_salon_front")
	await _view(run_node, c + Vector3(-5.2, 1.6, -1.4), c + Vector3(-2.6, 1.2, -1.3), "town_salon_juno")
	run_node.queue_free()


func _view(run_node, eye: Vector3, look: Vector3, name: String) -> void:
	var player = run_node.player
	player.global_position = eye - Vector3(0, 1.6, 0)
	player.velocity = Vector3.ZERO
	var d := look - eye
	player.rotation.y = atan2(-d.x, -d.z)
	player.get_node("Head").rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
	await _frames(20)
	await _save(name)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	print("saved ", name)
