extends Node3D
## Grunt showcase: a turntable for the colony grunt in the game's PS2 look.
## Open scenes/grunt_showcase.tscn and press F6.
##   Left / Right   turn him         Space   pause the turntable
##   1  full body   2  face   3  squad (idle swagger, walking, winding up a shot)
##   Q / E          play the previous / next taunt
## Renders the reference sheet shots when run with
##   godot res://scenes/grunt_showcase.tscn -- --shots=<folder> [--clean]

const Art := preload("res://scripts/ps2/ps2_assets.gd")
const GRUNT := preload("res://scripts/grunt.gd")

## [name, yaw (deg), camera position, look-at point, fov]
const SHOTS := [
	["front", 0.0, Vector3(0, 1.05, -3.4), Vector3(0, 0.95, 0), 34.0],
	["three_quarter", -35.0, Vector3(0, 1.05, -3.4), Vector3(0, 0.95, 0), 34.0],
	["side", -90.0, Vector3(0, 1.05, -3.4), Vector3(0, 0.95, 0), 34.0],
	["back", 160.0, Vector3(0, 1.05, -3.4), Vector3(0, 0.95, 0), 34.0],
	["face", -25.0, Vector3(0, 1.62, -0.85), Vector3(0, 1.6, 0), 30.0],
	["squad", 0.0, Vector3(0.9, 1.45, -4.3), Vector3(0.2, 1.0, 1.0), 42.0],
	["point", 28.0, Vector3(0, 1.3, -2.4), Vector3(0, 1.15, 0), 40.0],
	["beckon", -20.0, Vector3(0, 1.3, -2.4), Vector3(0, 1.15, 0), 40.0],
	["bird", -20.0, Vector3(0, 1.3, -2.4), Vector3(0, 1.15, 0), 40.0],
	["crotch", -15.0, Vector3(0, 1.3, -2.4), Vector3(0, 1.05, 0), 40.0],
	["thrust", 60.0, Vector3(0, 1.3, -2.4), Vector3(0, 1.05, 0), 40.0],
	["flex", -10.0, Vector3(0, 1.3, -2.4), Vector3(0, 1.2, 0), 40.0],
	["scratch", 150.0, Vector3(0, 1.3, -2.4), Vector3(0, 1.05, 0), 40.0],
	["wink", -10.0, Vector3(0, 1.6, -0.85), Vector3(0, 1.58, 0), 30.0],
	["ogle", -10.0, Vector3(0, 1.6, -0.85), Vector3(0, 1.58, 0), 30.0],
]


## A body that walks on the spot, so the model plays its walk.
class Treadmill extends CharacterBody3D:
	var home: Vector3

	func _physics_process(_delta: float) -> void:
		velocity = -transform.basis.z * 3.0 + Vector3.DOWN
		move_and_slide()
		position = home


var grunt: Node3D
var squad: Array[Node3D] = []
var cam: Camera3D
var turntable := true
var _taunt := -1


func _ready() -> void:
	Art.environment(self, Color(0.42, 0.58, 0.85), Color(0.98, 0.8, 0.62))
	for light in find_children("*", "DirectionalLight3D", true, false):
		(light as DirectionalLight3D).rotation_degrees = Vector3(-35, 160, 0)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = BoxShape3D.new()
	floor_shape.shape.size = Vector3(40, 0.2, 40)
	floor_body.add_child(floor_shape)
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(40, 0.2, 40)
	floor_mesh.material = Art.surface(Color(0.5, 0.46, 0.42), floor_mesh.size)
	var floor_node := MeshInstance3D.new()
	floor_node.mesh = floor_mesh
	floor_body.add_child(floor_node)
	floor_body.position.y = -0.1
	add_child(floor_body)

	grunt = _grunt(Vector3.ZERO)
	# squad behind him: one walking, one winding up a shot
	var walker := Treadmill.new()
	var cap := CollisionShape3D.new()
	cap.shape = CapsuleShape3D.new()
	cap.shape.radius = 0.35
	cap.position.y = 0.9
	walker.add_child(cap)
	walker.home = Vector3(1.6, 0.05, 2.2)
	walker.position = walker.home
	walker.rotation_degrees.y = 20.0
	walker.add_child(Art.model("grunt"))
	add_child(walker)
	squad.append(walker)
	var aimer := _grunt(Vector3(-1.4, 0.0, 1.6))
	aimer.rotation_degrees.y = -15.0
	aimer.windup_timer = 0.05
	squad.append(aimer)
	for g in squad:
		g.visible = false

	cam = Camera3D.new()
	add_child(cam)
	_set_view(0)
	for arg in OS.get_cmdline_user_args():
		if arg == "--clean":  # full resolution, no PS2 filter or haze
			get_node("/root/PS2").set_enabled(false)
			for env_node in find_children("*", "WorldEnvironment", true, false):
				var env: Environment = (env_node as WorldEnvironment).environment
				env.fog_enabled = false
				env.glow_enabled = false
		if arg.begins_with("--shots="):
			_render_shots(arg.trim_prefix("--shots="))


func _grunt(pos: Vector3) -> Node3D:
	var g := CharacterBody3D.new()
	g.set_script(GRUNT)
	g.passive = true
	g.position = pos
	add_child(g)
	return g


func _set_view(i: int) -> void:
	var shot: Array = SHOTS[[0, 4, 5][i]]
	for g in squad:
		g.visible = shot[0] == "squad"
	cam.fov = shot[4]
	cam.look_at_from_position(shot[2], shot[3])


func _process(delta: float) -> void:
	if turntable:
		grunt.rotation.y += delta * 0.5


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	match event.keycode:
		KEY_SPACE:
			turntable = not turntable
		KEY_LEFT:
			grunt.rotation.y -= 0.3
		KEY_RIGHT:
			grunt.rotation.y += 0.3
		KEY_1, KEY_2, KEY_3:
			_set_view(event.keycode - KEY_1)
		KEY_Q, KEY_E:
			var names: Array = grunt.model.TAUNTS.keys()
			_taunt = wrapi(_taunt + (1 if event.keycode == KEY_E else -1), 0, names.size())
			grunt.model.play_gesture(names[_taunt])


func _render_shots(folder: String) -> void:
	turntable = false
	grunt.model._gesture_wait = 1e9  # no random taunts in the stills
	DirAccess.make_dir_recursive_absolute(folder)
	for shot in SHOTS:
		var is_squad: bool = shot[0] == "squad"
		for g in squad:
			g.visible = is_squad
		grunt.rotation_degrees.y = shot[1]
		cam.fov = shot[4]
		cam.look_at_from_position(shot[2], shot[3])
		for i in 40:
			await get_tree().process_frame
		if grunt.model.TAUNTS.has(shot[0]):
			grunt.model.play_gesture(shot[0])
			await get_tree().create_timer(grunt.model.TAUNTS[shot[0]].time * 0.4).timeout
		var img := get_viewport().get_texture().get_image()
		img.save_png(folder.path_join("%s.png" % shot[0]))
		print("shot ", shot[0])
	get_tree().quit()
