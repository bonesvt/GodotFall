extends RefCounted
## Shape helpers for building the hub (temple and grounds) out of boxes with
## its own materials: temple stone, carvings, wood, metal, glow, lights, and the
## look-at spots Eco can comment on.

const Kit := preload("res://scripts/run/level_kit.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")

const STONE := Color(0.62, 0.55, 0.45)


static func stone(parent: Node, pos: Vector3, size: Vector3, rot := Vector3.ZERO, tint := Color.WHITE) -> StaticBody3D:
	return Kit.box(parent, pos, size, STONE, rot, Art.material("temple_stone", tint))


static func carved(parent: Node, pos: Vector3, size: Vector3, rot := Vector3.ZERO, tint := Color.WHITE) -> StaticBody3D:
	return Kit.box(parent, pos, size, STONE, rot, Art.material("temple_carving", tint))


static func wood(parent: Node, pos: Vector3, size: Vector3, rot := Vector3.ZERO) -> StaticBody3D:
	return Kit.box(parent, pos, size, STONE, rot, Art.material("wood"))


static func metal(parent: Node, pos: Vector3, size: Vector3, rot := Vector3.ZERO) -> StaticBody3D:
	return Kit.box(parent, pos, size, STONE, rot, Art.material("gunmetal"))


## Decoration with no collision.
static func mesh(parent: Node, pos: Vector3, size: Vector3, material: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	box_mesh.material = material
	var mi := MeshInstance3D.new()
	mi.mesh = box_mesh
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


## A glowing, unshaded block (fire, lamp glass, the idol's eye). Blooms.
static func glow(parent: Node, pos: Vector3, size: Vector3, color: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := mesh(parent, pos, size, Art.material("light"), rot)
	mi.set_instance_shader_parameter("paint", color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func light(parent: Node, pos: Vector3, color: Color, energy: float, light_range: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	l.omni_attenuation = 1.4
	parent.add_child(l)
	return l


static func interactable(info: Dictionary, id: String, pos: Vector3, prompt: String, lines: Array, reach := 3.0) -> void:
	info["interactables"].append({"id": id, "pos": pos, "range": reach, "prompt": prompt, "lines": lines})
