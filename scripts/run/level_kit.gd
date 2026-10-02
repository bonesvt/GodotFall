extends RefCounted
## Shared helpers for building run levels out of boxes, signs and markers.
## Boxes pick their PS2-style material from their colour and size (see ps2_assets.gd).

const Art := preload("res://scripts/ps2/ps2_assets.gd")


## `material` overrides the colour lookup (the temple hub uses its own stone and wood).
static func box(parent: Node, pos: Vector3, size: Vector3, color: Color, rot_deg := Vector3.ZERO, material: Material = null) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation_degrees = rot_deg
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material if material != null else Art.surface(color, size)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	body.add_child(mi)
	parent.add_child(body)
	return body


## A flat glowing disc, used for objective rings and slam telegraphs.
static func disc(parent: Node, pos: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.06
	mesh.material = glow(color)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	parent.add_child(mi)
	return mi


static func glow(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	return mat


static func label(parent: Node, pos: Vector3, text: String, font_size := 96) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.font_size = font_size
	l.pixel_size = 0.01
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.outline_size = 16
	parent.add_child(l)
	return l


static func environment(parent: Node, top: Color, horizon: Color) -> void:
	Art.environment(parent, top, horizon)
