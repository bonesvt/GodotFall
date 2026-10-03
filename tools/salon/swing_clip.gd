extends SceneTree
## Frames of Ophelia turning on the spot with her long cuts, to see her hair
## swing (hair_springs.gd). Fixed 30 fps steps.
##   xvfb-run -a godot --audio-driver Dummy --fixed-fps 30 --path . -s res://tools/salon/swing_clip.gd -- <out_dir>

const Hair := preload("res://scripts/hub/hair.gd")
const HubNpc := preload("res://scripts/hub/hub_npc.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")

var out := "user://swing_clip"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	Hair.save_path = "user://shots_swing.cfg"
	_go.call_deferred()


func _go() -> void:
	root.size = Vector2i(400, 460)
	var stage := Node3D.new()
	root.add_child(stage)
	Art.environment(stage, Color(0.12, 0.08, 0.13), Color(0.32, 0.22, 0.28))
	for node in stage.get_children():
		if node is WorldEnvironment:
			node.environment.fog_enabled = false
	var cam := Camera3D.new()
	cam.fov = 34.0
	stage.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.3, 2.1), Vector3(0, 1.15, 0))
	var npc := HubNpc.create("ophelia", Vector3.ZERO, 0.0)
	stage.add_child(npc)
	await process_frame
	var model: Node = npc.get_node("Model")
	var n := 0
	for style in ["ponytail", "braids"]:
		Hair.apply(model, "ophelia", style)
		for f in 75:
			# a quick look over each shoulder, then back to facing away
			var t := f / 75.0
			npc.rotation.y = 0.9 * sin(t * TAU) * (1.0 - t * 0.3)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out.path_join("f%03d.png" % n))
			n += 1
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Hair.save_path))
	quit()
