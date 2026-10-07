extends RefCounted
## Eco's physics lab: a sealed test room built under the temple (LAB), reached
## by a hatch in the nave beside the glass panel (both ways teleport). Every
## kind of thing she can press into stands round it, labelled: a row of wall
## materials from hard stone to a soft cushion (softness meta, player.gd
## soft_press), a sharp corner, a round column, a thin post, glass the camera
## sees through, and squeeze gaps of a few widths. A console by the door steps
## the "Press into things" setting (Prefs press_strength) so the same walls can
## be tried hard, normal or soft.

const K := preload("res://scripts/hub/hub_kit.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")

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
## Squeeze gaps on the east side: their widths (m), each a passage 1.2 m long.
const GAPS := [0.42, 0.34, 0.28]


static func build(root: Node3D, info: Dictionary) -> void:
	_shell(root)
	_walls(root)
	_shapes(root)
	_gaps(root, info)
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


## Squeeze gaps on the east side: pairs of walls with a narrow passage between.
static func _gaps(root: Node3D, info: Dictionary) -> void:
	info["lab_gaps"] = []
	for i in GAPS.size():
		var w: float = GAPS[i]
		var c := LAB + Vector3(2.5 + i * 2.6, 0, -0.5)
		for side in [-1.0, 1.0]:
			var b := _box(root, c + Vector3(side * (w * 0.5 + 0.45), ROOM.y * 0.5, 0), Vector3(0.9, ROOM.y, 1.2), Color(0.5, 0.5, 0.48))
			b.add_to_group("squeeze_gap")
		_label(root, c + Vector3(0, 2.4, 0.7), "Gap %d cm" % roundi(w * 100), 0.0)
		info["lab_gaps"].append({"centre": c, "width": w})


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
