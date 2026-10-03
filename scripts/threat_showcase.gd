extends Node3D
## Showcase for the Choir and the wildlife past the border, in game.
## Open scenes/threat_showcase.tscn and press F6.
##   1-9  look at one (Hush, Hound, Cantor, Seraph, Glassback, Lampjaw,
##        Quillcats, Bonepickers, Veil Rays)   0  everyone in a line
##   T    attack tell on / off      O  jaw / frill open      W  walk
## Renders the stills with
##   godot res://scenes/threat_showcase.tscn -- --shots=<folder> [--clean]

const Art := preload("res://scripts/ps2/ps2_assets.gd")
const ThreatModel := preload("res://scripts/threats/threat_model.gd")

## name: [glb, gait]
const KINDS := {
	"hush": ["hush", "biped"], "hound": ["hound", "quad"], "cantor": ["cantor", "biped"],
	"seraph": ["seraph", "hover"], "glassback": ["glassback", "hex"], "lampjaw": ["lampjaw", "scuttle"],
	"quillcat": ["quillcat", "quad"], "picker": ["picker", "scuttle"], "veilray": ["veilray", "glide"],
}
## [shot, models [[kind, position, yaw, tell, open, walk]], camera, look at, fov]
const SHOTS := [
	["choir_lineup", [["hush", Vector3(-2.2, 0, 0), -20, 0.2, 0, 0], ["hound", Vector3(0.6, 0, -0.6), -35, 0.2, 0, 0],
		["cantor", Vector3(3.6, 0, 0.4), -25, 0.2, 0, 0], ["seraph", Vector3(-4.6, 2.1, 0.6), 10, 0.3, 0, 0],
		["grunt", Vector3(-0.6, 0, 1.4), -10, 0, 0, 0]],
		Vector3(0, 2.2, -10.5), Vector3(0, 1.6, 0), 40.0],
	["hush", [["hush", Vector3.ZERO, -30, 0.15, 0, 0]], Vector3(0, 1.5, -4.6), Vector3(0, 1.2, 0), 36.0],
	["hush_tell", [["hush", Vector3.ZERO, -15, 1.0, 0, 0]], Vector3(0, 2.15, -1.6), Vector3(0, 1.95, 0), 36.0],
	["hound", [["hound", Vector3.ZERO, -40, 0.2, 0, 3.5]], Vector3(0, 1.3, -4.4), Vector3(0, 0.7, 0), 36.0],
	["cantor", [["cantor", Vector3.ZERO, -30, 1.0, 0, 0]], Vector3(0, 2.4, -7.0), Vector3(0, 1.9, 0), 38.0],
	["seraph", [["seraph", Vector3(0, 1.6, 0), -25, 0.6, 0, 0]], Vector3(0, 1.7, -2.4), Vector3(0, 1.5, 0), 38.0],
	["wild_lineup", [["glassback", Vector3(-5.5, 0, 3.0), -60, 0.0, 0, 0], ["lampjaw", Vector3(1.5, 0, -0.5), -30, 0.2, 0.3, 0],
		["quillcat", Vector3(4.6, 0, 0.2), -50, 0.0, 0.2, 0], ["picker", Vector3(0.0, 0, -2.2), -20, 0, 0, 0],
		["picker", Vector3(0.5, 0, -2.6), 40, 0, 0, 0], ["veilray", Vector3(1.0, 6.5, 4.0), -30, 0.2, 0, 0],
		["grunt", Vector3(-1.4, 0, 0.0), -10, 0, 0, 0]],
		Vector3(0, 3.2, -13.0), Vector3(0, 2.2, 0), 44.0],
	["glassback", [["glassback", Vector3.ZERO, -55, 1.0, 0, 3.0]], Vector3(0, 3.4, -15.0), Vector3(0, 2.4, 0), 38.0],
	["lampjaw", [["lampjaw", Vector3.ZERO, -25, 1.0, 1.0, 0]], Vector3(0, 1.5, -4.6), Vector3(0, 0.6, 0), 38.0],
	["quillcats", [["quillcat", Vector3(0, 0, 0), -30, 1.0, 1.0, 0], ["quillcat", Vector3(-2.2, 0, 2.2), 20, 0.0, 0.3, 3.0],
		["quillcat", Vector3(2.4, 0, 2.6), -70, 0.0, 0.3, 3.0]],
		Vector3(0, 1.6, -5.2), Vector3(0, 0.8, 1.0), 42.0],
	["bonepickers", [["hush", Vector3(0, 0.2, 0.3), 0, 0, 0, -1], ["picker", Vector3(-0.6, 0, -0.5), 30, 0, 0, 0],
		["picker", Vector3(0.5, 0, -0.6), -50, 0, 0, 0], ["picker", Vector3(0.9, 0, 0.6), -120, 0, 0, 0],
		["picker", Vector3(-0.9, 0, 0.9), 100, 0, 0, 0], ["picker", Vector3(0.1, 0, 1.6), 180, 0, 0, 0],
		["picker", Vector3(-0.3, 0, -1.1), 10, 0, 0, 0], ["picker", Vector3(0.4, 0.35, 0.2), 60, 0, 0, 0]],
		Vector3(0, 1.6, -3.4), Vector3(0, 0.15, 0.2), 40.0],
	["veilrays", [["veilray", Vector3(0, 7, 6), -20, 0.2, 0, 1.0], ["veilray", Vector3(-6, 9, 11), 30, 0.2, 0, 1.0],
		["veilray", Vector3(5, 10, 13), -50, 0.2, 0, 1.0], ["hush", Vector3(0, 0, 0), 180, 0.0, 0, 0]],
		Vector3(0, 1.7, -4.0), Vector3(0, 7.0, 8.0), 55.0],
]

var cam: Camera3D
var shown: Array[Node3D] = []
var _view := 0


func _ready() -> void:
	Art.environment(self, Color(0.42, 0.55, 0.78), Color(0.95, 0.82, 0.68))
	for light in find_children("*", "DirectionalLight3D", true, false):
		(light as DirectionalLight3D).rotation_degrees = Vector3(-38, 150, 0)
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(120, 0.2, 120)
	floor_mesh.material = Art.surface(Color(0.46, 0.47, 0.4), floor_mesh.size)
	var floor_node := MeshInstance3D.new()
	floor_node.mesh = floor_mesh
	floor_node.position.y = -0.1
	add_child(floor_node)
	cam = Camera3D.new()
	add_child(cam)
	_show(0)
	for arg in OS.get_cmdline_user_args():
		if arg == "--clean":
			get_node("/root/PS2").set_enabled(false)
			for env_node in find_children("*", "WorldEnvironment", true, false):
				var env: Environment = (env_node as WorldEnvironment).environment
				env.fog_enabled = false
		if arg.begins_with("--shots="):
			_render_shots(arg.trim_prefix("--shots="))


func _model(kind: String) -> Node3D:
	if kind == "grunt":
		return Art.model("grunt")
	var m := Node3D.new()
	m.set_script(ThreatModel)
	m.gait = KINDS[kind][1]
	if kind == "glassback":
		m.tell_white = 0.25
		m.stride_len = 3.2
	m.add_child(load("res://assets/models/threats/%s.glb" % KINDS[kind][0]).instantiate())
	return m


func _show(i: int) -> void:
	_view = i
	for n in shown:
		n.queue_free()
	shown.clear()
	var shot: Array = SHOTS[i]
	for spec in shot[1]:
		var m := _model(spec[0])
		add_child(m)
		m.position = spec[1]
		m.rotation_degrees.y = spec[2]
		if spec[5] < 0:  # lying dead
			m.rotation_degrees.x = -90.0
		if m.get_script() == ThreatModel:
			m.tell = spec[3]
			m.open = spec[4]
			m.cycle_speed = maxf(spec[5], 0.0)
		shown.append(m)
	cam.fov = shot[4]
	cam.look_at_from_position(shot[2], shot[3])


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	var keys := {KEY_0: 0, KEY_1: 1, KEY_2: 3, KEY_3: 4, KEY_4: 5, KEY_5: 7, KEY_6: 8, KEY_7: 9, KEY_8: 10, KEY_9: 11}
	if keys.has(event.keycode):
		_show(keys[event.keycode])
		return
	for m in shown:
		if m.get_script() != ThreatModel:
			continue
		match event.keycode:
			KEY_T:
				m.tell = 0.0 if m.tell > 0.5 else 1.0
			KEY_O:
				m.open = 0.0 if m.open > 0.5 else 1.0
			KEY_W:
				m.cycle_speed = 0.0 if m.cycle_speed > 0.0 else 3.0


func _render_shots(folder: String) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	var only := []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",")
	for i in SHOTS.size():
		if not only.is_empty() and not SHOTS[i][0] in only:
			continue
		_show(i)
		for k in 30:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png(folder.path_join("%s.png" % SHOTS[i][0]))
		print("shot ", SHOTS[i][0])
	get_tree().quit()
