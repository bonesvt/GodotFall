extends SceneTree
## Ophelia in each of her hang-out spots and scene poses (npc_idles.gd), shot
## in her room, for checking the poses.
##   xvfb-run -a godot --audio-driver Dummy --path . -s res://tools/npc/idle_shots.gd -- [out_dir] [spot,spot,...]
## Needs a renderer (not --headless).

const NpcIdles := preload("res://scripts/hub/npc_idles.gd")
const Rooms := preload("res://scripts/hub/hub_rooms.gd")

var out := "user://idle_shots"
var only: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	if args.size() > 1:
		only = Array(args[1].split(","))
	DirAccess.make_dir_recursive_absolute(out)
	var run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 3
	run_node.armory_path = "user://shots_idle_armory.cfg"
	run_node.npc_path = "user://shots_idle_npcs.cfg"
	for p in [run_node.armory_path, run_node.npc_path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	root.add_child(run_node)
	_go.call_deferred(run_node)


func _go(run_node) -> void:
	await _frames(20)
	for layer in root.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var oph: Node3D = run_node.hub_npcs["ophelia"]
	var cam := Camera3D.new()
	cam.fov = 50.0
	root.add_child(cam)
	cam.current = true
	run_node.player.global_position = Vector3(0, -50, 0)
	run_node.player.process_mode = Node.PROCESS_MODE_DISABLED
	for spot in ["lounge", "smoke", "read", "sway", "yoga", "sit", "mirror", "shy"]:
		if not only.is_empty() and not only.has(spot):
			continue
		NpcIdles.take(oph, spot)
		await _frames(30)
		var face := -oph.global_basis.z
		var head: Vector3 = oph.head_position()
		var side := face.cross(Vector3.UP)
		# from the front and a little to her side; lying down, from her side
		var at: Vector3 = face * 2.2 + side * 0.9
		if spot == "lounge" or spot == "sit":
			at = face * 0.9 + side * 2.3
		cam.global_position = head + at + Vector3(0, 0.25, 0)
		cam.look_at(head - Vector3(0, 0.45, 0))
		# the yoga flow at each stretch it holds
		var stops := [0.0]
		if spot == "yoga":
			var flow: float = oph._anim.current_animation_length
			stops = [flow * 0.175, flow * 0.425, flow * 0.675, flow * 0.925]
		for i in stops.size():
			if spot == "yoga":
				oph._anim.seek(stops[i], true)
			await _frames(4)
			var shot: String = spot if stops.size() == 1 else "%s%d" % [spot, i + 1]
			root.get_viewport().get_texture().get_image().save_png(out.path_join(shot + ".png"))
			print("shot ", shot)
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame
