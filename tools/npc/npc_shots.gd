extends SceneTree
## Screenshots of the hub people (Mom, Ophelia, Biggie) and their rooms, for
## checking the look.
##   xvfb-run -a godot --audio-driver Dummy --path . -s res://tools/npc/npc_shots.gd -- [out_dir]
## Needs a renderer (not --headless). Uses its own save files.

const Rooms := preload("res://scripts/hub/hub_rooms.gd")

var run_node
var out := "user://npc_shots"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1600, 900)
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 1234
	run_node.armory_path = "user://shots_npc_armory.cfg"
	run_node.npc_path = "user://shots_npcs.cfg"
	for p in [run_node.armory_path, run_node.npc_path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	root.add_child(run_node)
	_go.call_deferred()


func _go() -> void:
	await _frames(30)
	run_node.hud.help_label.visible = false
	var f := Rooms.F
	# The hall, with the new doors.
	await _shot("1-hall-back-doors", Vector3(0, f, -17), Vector3(0, f + 1.8, -31))
	await _shot("2-hall-mom-door", Vector3(-6.5, f, -17), Vector3(-12.2, f + 1.5, -12))
	# Each room from its doorway, then its person up close, talking.
	var wide := {
		"mom": [Vector3(-12.7, f, -8.6), Vector3(-15.2, f + 1.0, -15.5)],
		"ophelia": [Vector3(-5.0, f, -31.7), Vector3(-12.5, f + 1.0, -37.5)],
		"biggie": [Vector3(13.9, f, -31.7), Vector3(6.0, f + 1.0, -37.5)],
	}
	var i := 3
	for who in ["mom", "ophelia", "biggie"]:
		var npc: Node3D = run_node.hub_npcs[who]
		var w: Array = wide[who]
		await _shot("%d-%s-room" % [i, who], w[0], w[1])
		# Stand a couple of metres off toward the doorway and let them turn.
		var away: Vector3 = (w[0] - npc.global_position)
		away.y = 0.0
		var at: Vector3 = npc.global_position + away.normalized() * 1.9
		var head: Vector3 = npc.global_position + Vector3(0, 1.45 if who != "biggie" else 1.62, 0)
		await _shot("%d-%s-face" % [i, who], at, head, 60)
		run_node.talk_to(who)
		await _frames(40)
		await _save("%d-%s-talk" % [i, who])
		run_node.npc_talk.stop()
		await _shot("%d-%s-full" % [i, who], npc.global_position + away.normalized() * 3.2, npc.global_position + Vector3(0, 1.0, 0), 30)
		i += 1
	quit()


func _shot(name: String, at: Vector3, look: Vector3, settle := 14) -> void:
	var player = run_node.player
	player.global_position = at
	player.velocity = Vector3.ZERO
	var eye := at + Vector3(0, 1.6, 0)
	var d := look - eye
	player.rotation.y = atan2(-d.x, -d.z)
	player.get_node("Head").rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
	await _frames(settle)
	await _save(name)


func _save(name: String) -> void:
	await _frames(2)
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("shot ", name)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
