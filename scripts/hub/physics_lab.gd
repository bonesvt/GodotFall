extends RefCounted
## Eco's physics lab: a sealed test room built under the temple (LAB), reached
## by a hatch in the nave beside the glass panel (both ways teleport). Every
## kind of thing she can press into stands round it, labelled: a row of wall
## materials from hard stone to a soft cushion (softness meta, player.gd
## soft_press), a sharp corner, a round column, a thin post, glass the camera
## sees through, squeeze gaps of a few widths, and a bench and a mat to sit and
## lie on (her soft parts squash on what holds her up, eco_model.gd _support_y),
## a blast button, a wading tank and a fan. A console by the door steps
## the "Press into things" setting (Prefs press_strength) so the same walls can
## be tried hard, normal or soft.

const K := preload("res://scripts/hub/hub_kit.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")
const LaidOut := preload("res://scripts/run/laid_out.gd")

## The room's floor centre, and its size.
const LAB := Vector3(0.0, -10.0, 60.0)
const ROOM := Vector3(20.0, 4.0, 14.0)
## The hatch in the nave (just off the glass panel) and where it lands her.
const HATCH := Vector3(5.6, 1.2, 2.6)
const ARRIVE := LAB + Vector3(0, 0, 5.2)
const CONSOLE := LAB + Vector3(1.6, 0, 5.8)
## The materials along the back wall: [name, colour, softness (0 hard .. 1 cushion), camera sees through].
const WALLS := [
	["Stone", Color(0.55, 0.53, 0.5), 0.0, false],
	["Metal", Color(0.45, 0.48, 0.52), 0.0, false],
	["Wood", Color(0.55, 0.4, 0.28), 0.1, false],
	["Glass", Color(0.6, 0.85, 1.0, 0.18), 0.0, true],
	["Rubber mat", Color(0.18, 0.18, 0.2), 0.35, false],
	["Padded wall", Color(0.7, 0.25, 0.3), 0.7, false],
	["Cushion", Color(0.85, 0.75, 0.6), 1.0, false],
]
const WALL_W := 2.4
## How far a snag juts out into its gap (m).
const JUT := 0.06
## Squeeze gaps on the east side, each a passage 1.2 m long she shuffles
## through side-on: [width (m), how many spots jut out into it]. The gap
## itself only drags on her; the jutting spots are where she gets stuck and
## has to wriggle (mash jump) past.
const GAPS := [[0.30, 0], [0.27, 2], [0.25, 3]]


static func build(root: Node3D, info: Dictionary) -> void:
	_shell(root)
	_walls(root)
	_shapes(root)
	_gaps(root, info)
	_rests(root, info)
	_weather(root, info)
	K.light(root, LAB + Vector3(-5, 3.4, 0), Color(1.0, 0.95, 0.9), 1.2, 12.0)
	K.light(root, LAB + Vector3(5, 3.4, 0), Color(0.9, 0.95, 1.0), 1.2, 12.0)
	# the hatch in the nave, and the door back up
	K.mesh(root, HATCH + Vector3(0, 0.02, 0), Vector3(0.9, 0.04, 0.9), Art.material("gunmetal", Color(0.4, 0.42, 0.45)))
	K.glow(root, HATCH + Vector3(0, 0.05, 0), Vector3(0.7, 0.01, 0.06), Color(0.4, 0.9, 1.0))
	K.interactable(info, "physics_lab", HATCH, "[F] Physics lab", ["A hatch down to the room where Eco tests what she presses into."], 1.6)
	info["interactables"].back()["teleport"] = ARRIVE
	info["interactables"].back()["open"] = true
	var door := LAB + Vector3(0, 0, ROOM.z * 0.5 - 0.3)
	K.mesh(root, door + Vector3(0, 1.05, 0.1), Vector3(1.0, 2.1, 0.08), Art.material("gunmetal", Color(0.35, 0.36, 0.38)))
	K.interactable(info, "physics_lab_exit", door + Vector3(0, 0, -0.5), "[F] Back up to the temple", ["Back up the ladder."], 1.6)
	info["interactables"].back()["teleport"] = HATCH + Vector3(-0.9, 0, 0)
	info["interactables"].back()["open"] = true
	K.mesh(root, CONSOLE + Vector3(0, 0.5, 0), Vector3(0.6, 1.0, 0.4), Art.material("gunmetal", Color(0.3, 0.32, 0.35)))
	K.glow(root, CONSOLE + Vector3(0, 0.95, -0.18), Vector3(0.45, 0.25, 0.02), Color(0.3, 0.9, 1.0))
	K.interactable(info, "press_console", CONSOLE + Vector3(0, 0, -0.6), "[F] Change how much she can press", ["The lab console."], 1.4)
	info["interactables"].back()["press_console"] = true
	# a button that sets off a charge in a blast pit by the west wall, to feel its shock
	var button := LAB + Vector3(-8.0, 0, 5.6)
	K.mesh(root, button + Vector3(0, 0.5, 0), Vector3(0.4, 1.0, 0.4), Art.material("gunmetal", Color(0.3, 0.32, 0.35)))
	K.glow(root, button + Vector3(0, 1.02, 0), Vector3(0.2, 0.04, 0.2), Color(1.0, 0.3, 0.2))
	K.interactable(info, "lab_blast", button + Vector3(0.5, 0, 0), "[F] Set off a blast", ["Fire in the hole!"], 1.3)
	info["interactables"].back()["lab_blast"] = true
	info["interactables"].back()["blast_at"] = LAB + Vector3(-8.0, 0.5, 2.6)
	K.glow(root, LAB + Vector3(-8.0, 0.01, 2.6), Vector3(1.4, 0.01, 1.4), Color(0.6, 0.2, 0.1, 0.6))
	_label(root, button + Vector3(0, 1.6, 0), "Blast", 0.0)
	info["lab"] = {"arrive": ARRIVE, "floor": LAB}
	_label(root, LAB + Vector3(0, 3.3, ROOM.z * 0.5 - 0.2), "PHYSICS LAB", 0.0)


static func _shell(root: Node3D) -> void:
	var hw := ROOM.x * 0.5
	var hd := ROOM.z * 0.5
	var wall := Color(0.4, 0.42, 0.45)
	K.carved(root, LAB + Vector3(0, -0.25, 0), Vector3(ROOM.x + 0.6, 0.5, ROOM.z + 0.6), Vector3.ZERO, Color(0.35, 0.37, 0.4))
	K.carved(root, LAB + Vector3(0, ROOM.y + 0.25, 0), Vector3(ROOM.x + 0.6, 0.5, ROOM.z + 0.6), Vector3.ZERO, Color(0.3, 0.31, 0.33))
	for side in [-1.0, 1.0]:
		K.carved(root, LAB + Vector3(side * (hw + 0.15), ROOM.y * 0.5, 0), Vector3(0.3, ROOM.y, ROOM.z), Vector3.ZERO, wall)
		K.carved(root, LAB + Vector3(0, ROOM.y * 0.5, side * (hd + 0.15)), Vector3(ROOM.x, ROOM.y, 0.3), Vector3.ZERO, wall)
	# a grid on the floor, half a metre a square, for judging distances in clips
	for i in range(-int(hw), int(hw) + 1):
		K.glow(root, LAB + Vector3(i, 0.005, 0), Vector3(0.01, 0.002, ROOM.z), Color(0.5, 0.55, 0.6, 0.5))
	for j in range(-int(hd), int(hd) + 1):
		K.glow(root, LAB + Vector3(0, 0.005, j), Vector3(ROOM.x, 0.002, 0.01), Color(0.5, 0.55, 0.6, 0.5))


## The back wall, in panels of each material, labelled.
static func _walls(root: Node3D) -> void:
	var z := -ROOM.z * 0.5 + 0.2
	var x0 := -WALL_W * (WALLS.size() - 1) * 0.5
	for i in WALLS.size():
		var m: Array = WALLS[i]
		var c := LAB + Vector3(x0 + i * WALL_W, ROOM.y * 0.5, z)
		var body := _box(root, c, Vector3(WALL_W - 0.05, ROOM.y, 0.4), m[1])
		body.name = "LabWall_%s" % String(m[0]).replace(" ", "")
		body.set_meta("softness", m[2])
		if m[3]:
			body.add_to_group("camera_clear")
		_label(root, c + Vector3(0, -0.4, 0.3), "%s\n%s" % [m[0], "hard" if m[2] <= 0.0 else "softness %d%%" % roundi(m[2] * 100)], 0.0)


## A sharp corner, a round column and a thin post, out in the room.
static func _shapes(root: Node3D) -> void:
	var corner := _box(root, LAB + Vector3(-6.5, ROOM.y * 0.5, -1.0), Vector3(0.8, ROOM.y, 0.8), Color(0.55, 0.53, 0.5))
	corner.rotation.y = PI * 0.25
	_label(root, LAB + Vector3(-6.5, 2.4, -0.3), "Corner", 0.0)
	_column(root, LAB + Vector3(-3.5, 0, -1.0), 0.3, Color(0.6, 0.58, 0.55))
	_label(root, LAB + Vector3(-3.5, 2.4, -0.5), "Column", 0.0)
	_column(root, LAB + Vector3(-1.0, 0, -1.0), 0.05, Color(0.4, 0.42, 0.45))
	_label(root, LAB + Vector3(-1.0, 2.4, -0.8), "Thin post", 0.0)


## Squeeze gaps on the east side: pairs of walls with a narrow passage
## between, and knobs of rock jutting into some of them at chest and hip height.
static func _gaps(root: Node3D, info: Dictionary) -> void:
	info["lab_gaps"] = []
	for i in GAPS.size():
		var w: float = GAPS[i][0]
		var juts: int = GAPS[i][1]
		var c := LAB + Vector3(2.5 + i * 2.6, 0, -0.5)
		for side in [-1.0, 1.0]:
			var b := _box(root, c + Vector3(side * (w * 0.5 + 0.45), ROOM.y * 0.5, 0), Vector3(0.9, ROOM.y, 1.2), Color(0.5, 0.5, 0.48))
			b.add_to_group("squeeze_gap")
		var spots := []
		for j in juts:
			# alternate sides along the passage, at chest then hip height
			var side := -1.0 if j % 2 == 0 else 1.0
			var z := -0.45 + 0.9 * (j + 0.5) / juts
			var at := c + Vector3(side * (w * 0.5 - JUT * 0.5), 1.25 if j % 2 == 0 else 0.95, z)
			var knob := _box(root, at, Vector3(JUT, 0.22, 0.16), Color(0.42, 0.4, 0.38))
			knob.add_to_group("squeeze_snag")
			spots.append(at)
		_label(root, c + Vector3(0, 2.4, 0.7), "Gap %d cm%s" % [roundi(w * 100), "" if juts == 0 else "\n%d snags" % juts], 0.0)
		info["lab_gaps"].append({"centre": c, "width": w, "snags": spots})


## A wading tank (waist-deep water: her soft parts and hair float in it) and a
## big fan blowing down the room beside it (a wind_zone, eco_model.gd _weather).
static func _weather(root: Node3D, info: Dictionary) -> void:
	var tank := LAB + Vector3(4.0, 0, 3.2)
	var size := Vector2(2.0, 1.8)
	var water := LaidOut.water(root, tank + Vector3(0, 0.95, 0), size, Color(0.25, 0.55, 0.7, 0.45))
	water.name = "LabWater"
	# the water's body, see-through, so she shows wading in it
	var body := MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	(body.mesh as BoxMesh).size = Vector3(size.x, 0.94, size.y)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.45, 0.6, 0.22)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	(body.mesh as BoxMesh).material = mat
	body.position = tank + Vector3(0, 0.47, 0)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(body)
	_label(root, tank + Vector3(0, 2.0, 0), "Wading tank", 0.0)
	var fan_at := LAB + Vector3(9.4, 0, 3.2)
	K.mesh(root, fan_at + Vector3(0, 1.1, 0), Vector3(0.3, 2.0, 2.0), Art.material("gunmetal", Color(0.3, 0.32, 0.35)))
	K.glow(root, fan_at + Vector3(-0.16, 1.1, 0), Vector3(0.02, 1.6, 1.6), Color(0.6, 0.8, 0.9))
	var zone := Node3D.new()
	zone.name = "LabFan"
	zone.position = fan_at + Vector3(-1.9, 1.1, 0)
	zone.set_meta("half", Vector3(1.7, 1.1, 1.0))
	zone.set_meta("wind", Vector3(-9.0, 0, 0))
	zone.add_to_group("wind_zone")
	root.add_child(zone)
	_label(root, fan_at + Vector3(0, 2.4, 0), "Fan", 0.0)
	info["lab_weather"] = {"tank": tank, "water_y": tank.y + 0.95, "fan": zone.position}


## A hard bench to sit or lie along, and a low mat to lie on: back, face down or side.
static func _rests(root: Node3D, info: Dictionary) -> void:
	var bench := LAB + Vector3(-6.5, 0, 3.4)
	_box(root, bench + Vector3(0, 0.225, 0), Vector3(1.9, 0.45, 0.5), Color(0.5, 0.45, 0.4))
	_label(root, bench + Vector3(0, 1.6, 0), "Bench", 0.0)
	K.interactable(info, "lab_bench", bench + Vector3(0, 0, 0.7), "[F] Sit on the bench", ["A hard bench."], 1.4)
	info["interactables"].back()["rest"] = {
		"pose": "sit", "at": Transform3D(Basis(Vector3.UP, PI), bench + Vector3(0, 0, 0.12)), "seat": 0.45, "label": "Sit up",
		"more": [
			{"pose": "back", "at": Transform3D(Basis(Vector3.UP, PI / 2.0), bench + Vector3(0.25, 0, 0)), "label": "Lie on your back"},
			{"pose": "prone", "at": Transform3D(Basis(Vector3.UP, -PI / 2.0), bench + Vector3(0.25, 0, 0)), "label": "Lie face down"},
		],
	}
	var mat := LAB + Vector3(-3.5, 0, 3.4)
	var pad := _box(root, mat + Vector3(0, 0.2, 0), Vector3(2.1, 0.4, 1.0), Color(0.2, 0.3, 0.45))
	pad.set_meta("softness", 0.6)
	_label(root, mat + Vector3(0, 1.6, 0), "Mat", 0.0)
	K.interactable(info, "lab_mat", mat + Vector3(0, 0, 0.9), "[F] Lie on the mat", ["A gym mat."], 1.4)
	info["interactables"].back()["rest"] = {
		"pose": "back", "at": Transform3D(Basis(Vector3.UP, PI / 2.0), mat + Vector3(0.2, 0, 0)), "seat": 0.4, "label": "Lie on your back",
		"more": [
			{"pose": "prone", "at": Transform3D(Basis(Vector3.UP, -PI / 2.0), mat + Vector3(0.2, 0, 0)), "label": "Lie face down"},
			{"pose": "sleep", "at": Transform3D(Basis(), mat + Vector3(0.2, 0, 0)), "label": "Curl up on your side"},
		],
		"bed": false,
	}
	info["lab_rests"] = {"bench": bench, "mat": mat}


static func _box(root: Node3D, c: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = size
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	(mesh.mesh as BoxMesh).size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.8
	mesh.material_override = mat
	body.add_child(mesh)
	body.position = c
	root.add_child(body)
	return body


static func _column(root: Node3D, at: Vector3, r: float, color: Color) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = CylinderShape3D.new()
	(shape.shape as CylinderShape3D).radius = r
	(shape.shape as CylinderShape3D).height = ROOM.y
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.mesh = CylinderMesh.new()
	(mesh.mesh as CylinderMesh).top_radius = r
	(mesh.mesh as CylinderMesh).bottom_radius = r
	(mesh.mesh as CylinderMesh).height = ROOM.y
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material_override = mat
	body.add_child(mesh)
	body.position = at + Vector3(0, ROOM.y * 0.5, 0)
	root.add_child(body)


static func _label(root: Node3D, at: Vector3, text: String, yaw: float) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 48
	l.pixel_size = 0.004
	l.outline_size = 10
	l.modulate = Color(0.95, 0.97, 1.0)
	l.position = at
	l.rotation.y = yaw
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	root.add_child(l)
