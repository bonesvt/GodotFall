extends RefCounted
## Shape helpers for building the hub (temple and grounds) out of boxes with
## its own materials: temple stone, carvings, wood, metal, glow, lights, and the
## look-at spots Eco can comment on.

const Kit := preload("res://scripts/run/level_kit.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")

const STONE := Color(0.62, 0.55, 0.45)

## What stone() and carved() build in: "stone" (the ruins), "timber" (old
## hardwood) or "alloy" (the precursors' pale metal). The temple sets it while
## it builds itself; the grounds stay stone.
static var style := "stone"
const STYLES := {
	"stone": ["temple_stone", "temple_carving", "stone"],
	"timber": ["timber", "timber_carving", "wood"],
	"alloy": ["alloy", "alloy_inlay", "metal"],
}


static func stone(parent: Node, pos: Vector3, size: Vector3, rot := Vector3.ZERO, tint := Color.WHITE) -> StaticBody3D:
	return _styled(Kit.box(parent, pos, size, STONE, rot, Art.material(STYLES[style][0], tint)))


static func carved(parent: Node, pos: Vector3, size: Vector3, rot := Vector3.ZERO, tint := Color.WHITE) -> StaticBody3D:
	return _styled(Kit.box(parent, pos, size, STONE, rot, Art.material(STYLES[style][1], tint)))


static func _styled(body: StaticBody3D) -> StaticBody3D:
	if STYLES[style][2] != "":
		body.set_meta("surface", STYLES[style][2])  # footstep sounds (player.gd)
	return body


static func wood(parent: Node, pos: Vector3, size: Vector3, rot := Vector3.ZERO) -> StaticBody3D:
	var body := Kit.box(parent, pos, size, STONE, rot, Art.material("wood"))
	body.set_meta("surface", "wood")  # footstep sounds (player.gd)
	return body


static func metal(parent: Node, pos: Vector3, size: Vector3, rot := Vector3.ZERO) -> StaticBody3D:
	var body := Kit.box(parent, pos, size, STONE, rot, Art.material("gunmetal"))
	body.set_meta("surface", "metal")
	return body


## A patch of floor that sounds different underfoot (a rug, a dirt path)
## without being its own collider: player.gd checks the "surface_patch" group.
static func patch(parent: Node, pos: Vector3, size: Vector2, surface: String, yaw := 0.0) -> Node3D:
	var p := Node3D.new()
	p.position = pos
	p.rotation_degrees = Vector3(0, yaw, 0)
	p.set_meta("surface", surface)
	p.set_meta("half", size * 0.5)
	p.add_to_group("surface_patch")
	parent.add_child(p)
	return p


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


## A looping sound that comes from here, loudest within `size` metres
## (an ambience bed's id; soundscape.gd spot() plays it).
static func sound(info: Dictionary, id: String, pos: Vector3, db := -6.0, size := 4.0) -> void:
	if not info.has("sound_spots"):
		info["sound_spots"] = []
	info["sound_spots"].append({"id": id, "pos": pos, "db": db, "size": size})
