extends SceneTree
## Close-ups of a hub person's moods (blush, faces, head gestures from
## hub_npc.gd mood()), one shot each, on a plain backdrop.
##   xvfb-run -a godot --audio-driver Dummy --path . -s res://tools/npc/mood_shots.gd -- [who] [out_dir]
## Needs a renderer (not --headless).

const HubNpc := preload("res://scripts/hub/hub_npc.gd")
const SHOTS := [
	["1-plain", []],
	["2-blush-smile", ["blush", "smile"]],
	["3-fluster-joy", ["fluster", "joy"]],
	["4-shy", ["shy"]],
	["5-sad-down", ["sad", "down"]],
	["6-tilt", ["smile", "tilt"]],
	["7-angry", ["angry"]],
	["8-surprised", ["fluster", "surprised"]],
]

var who := "ophelia"
var out := "user://mood_shots"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		who = args[0]
	if args.size() > 1:
		out = args[1]
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(900, 900)
	_go.call_deferred()


func _go() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.16, 0.13, 0.18)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.5, 0.55)
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 25, 0)
	root.add_child(sun)
	var npc: Node3D = HubNpc.create(who, Vector3.ZERO, 0.0)
	root.add_child(npc)
	var cam := Camera3D.new()
	cam.fov = 22.0
	root.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.5, -1.25), Vector3(0, 1.43, 0))
	cam.current = true
	await _frames(10)
	for shot in SHOTS:
		npc.calm()
		npc.blush = 0.0
		npc.mood(shot[1])
		await _frames(50)
		root.get_viewport().get_texture().get_image().save_png(out.path_join("%s.png" % shot[0]))
		print("shot ", shot[0])
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame
