extends Node3D
## Eco showcase: a turntable to look at the heroine model in the game's PS2 look.
## Open scenes/eco_showcase.tscn and press F6.
##   Left / Right   turn her        Space   pause the turntable
##   1              full body        2       face close-up
##   3              first-person pistol and glove
##   S              next suit upgrade tier (0-5)
## Also renders the character sheet shots when run with
##   godot res://scenes/eco_showcase.tscn -- --shots=<folder> [--clean] [--suit=<tier>] [--only=front,back]

const Art := preload("res://scripts/ps2/ps2_assets.gd")

## [name, eco yaw (deg), camera position, look-at point, fov]
const SHOTS := [
	["front", 0.0, Vector3(0, 1.0, -3.1), Vector3(0, 0.88, 0), 34.0],
	["three_quarter", -35.0, Vector3(0, 1.0, -3.1), Vector3(0, 0.88, 0), 34.0],
	["side", -90.0, Vector3(0, 1.0, -3.1), Vector3(0, 0.88, 0), 34.0],
	["back", 180.0, Vector3(0, 1.0, -3.1), Vector3(0, 0.88, 0), 34.0],
	["face", -20.0, Vector3(0, 1.54, -0.72), Vector3(0, 1.515, 0), 30.0],
	["face_front", 0.0, Vector3(0, 1.54, -0.72), Vector3(0, 1.515, 0), 30.0],
	["first_person", 0.0, Vector3.ZERO, Vector3.ZERO, 75.0],
]

var eco: Node3D
var cam: Camera3D
var pistol: Node3D
var turntable := true
var _view := 0
## Shot names to render (empty: all of them).
var _only: PackedStringArray = []


func _ready() -> void:
	Art.environment(self, Color(0.42, 0.58, 0.85), Color(0.98, 0.8, 0.62))
	for light in find_children("*", "DirectionalLight3D", true, false):
		(light as DirectionalLight3D).rotation_degrees = Vector3(-30, 155, 0)  # key light on her face
	for env_node in find_children("*", "WorldEnvironment", true, false):
		var env: Environment = (env_node as WorldEnvironment).environment
		env.ambient_light_energy = 0.4
		env.fog_density = 0.002
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(30, 0.2, 30)
	floor_mesh.material = Art.surface(Color(0.5, 0.46, 0.42), floor_mesh.size)
	var floor_node := MeshInstance3D.new()
	floor_node.mesh = floor_mesh
	floor_node.position.y = -0.1
	add_child(floor_node)

	eco = Art.model("eco")
	add_child(eco)
	cam = Camera3D.new()
	add_child(cam)
	pistol = Art.model("pistol")
	cam.add_child(pistol)
	pistol.position = Vector3(0.22, -0.2, -0.42)
	_set_view(0)

	for arg in OS.get_cmdline_user_args():
		if arg == "--clean":  # full resolution, no PS2 filter or haze: a clear reference
			get_node("/root/PS2").set_enabled(false)
			for env_node in find_children("*", "WorldEnvironment", true, false):
				var env: Environment = (env_node as WorldEnvironment).environment
				env.fog_enabled = false
				env.glow_enabled = false
				env.ambient_light_energy = 0.32
		if arg.begins_with("--suit="):
			eco.suit_tier = int(arg.trim_prefix("--suit="))
		if arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=").split(",")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_render_shots(arg.trim_prefix("--shots="))


func _set_view(i: int) -> void:
	_view = i
	var shot: Array = SHOTS[[0, 4, 6][i]]
	pistol.visible = shot[0] == "first_person"
	eco.visible = not pistol.visible
	cam.fov = shot[4]
	if pistol.visible:
		cam.position = Vector3(0, 1.6, 2.0)
		cam.rotation = Vector3(-0.08, 0.0, 0.0)
	else:
		cam.position = shot[2]
		cam.look_at_from_position(shot[2], shot[3])


func _process(delta: float) -> void:
	if turntable and _view != 2:
		eco.rotation.y += delta * 0.5


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	match event.keycode:
		KEY_SPACE:
			turntable = not turntable
		KEY_LEFT:
			eco.rotation.y -= 0.3
		KEY_RIGHT:
			eco.rotation.y += 0.3
		KEY_S:
			eco.suit_tier = (eco.suit_tier + 1) % (eco.SUIT_TIERS + 1)
		KEY_1, KEY_2, KEY_3:
			_set_view(event.keycode - KEY_1)


func _render_shots(folder: String) -> void:
	turntable = false
	set_process(false)
	# hold her idle pose still (head facing forward) for the sheet
	eco.set_process(false)
	var anim := eco.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim != null:
		anim.play("idle")
		anim.seek(0.0, true)
		anim.pause()
	DirAccess.make_dir_recursive_absolute(folder)
	for shot in SHOTS:
		if not _only.is_empty() and not shot[0] in _only:
			continue
		var fp: bool = shot[0] == "first_person"
		pistol.visible = fp
		eco.visible = not fp
		eco.rotation_degrees.y = shot[1]
		cam.fov = shot[4]
		if fp:
			cam.position = Vector3(0, 1.6, 2.0)
			cam.rotation = Vector3(-0.08, 0.0, 0.0)
			pistol.position = Vector3(0.17, -0.13, -0.36)  # closer than in game, to show her hand
		else:
			cam.look_at_from_position(shot[2], shot[3])
		for i in 20:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png(folder.path_join("%s.png" % shot[0]))
		print("shot ", shot[0])
	get_tree().quit()
