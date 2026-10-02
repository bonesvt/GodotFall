extends RefCounted
## The hub's modelled props (assets/models/hub/*.glb, made by
## tools/hub/build_props.py in Blender). Each mesh in a model is named
## "<part>__<material>"; spawning one swaps in the game material for that suffix,
## optionally tinted, so the props pick up the PS2 surface shader like the rest
## of the level.

const Art := preload("res://scripts/ps2/ps2_assets.gd")

const SCENES := {
	"tree_a": preload("res://assets/models/hub/tree_a.glb"),
	"tree_b": preload("res://assets/models/hub/tree_b.glb"),
	"tree_c": preload("res://assets/models/hub/tree_c.glb"),
	"palm_a": preload("res://assets/models/hub/palm_a.glb"),
	"palm_b": preload("res://assets/models/hub/palm_b.glb"),
	"bush_a": preload("res://assets/models/hub/bush_a.glb"),
	"bush_b": preload("res://assets/models/hub/bush_b.glb"),
	"fern": preload("res://assets/models/hub/fern.glb"),
	"grass_tuft": preload("res://assets/models/hub/grass_tuft.glb"),
	"rock_a": preload("res://assets/models/hub/rock_a.glb"),
	"rock_b": preload("res://assets/models/hub/rock_b.glb"),
	"rock_c": preload("res://assets/models/hub/rock_c.glb"),
	"hill_a": preload("res://assets/models/hub/hill_a.glb"),
	"hill_b": preload("res://assets/models/hub/hill_b.glb"),
	"idol": preload("res://assets/models/hub/idol.glb"),
	"tent": preload("res://assets/models/hub/tent.glb"),
	"gunsmith_bench": preload("res://assets/models/hub/gunsmith_bench.glb"),
	"weapon_rack": preload("res://assets/models/hub/weapon_rack.glb"),
	"titan_workshop": preload("res://assets/models/hub/titan_workshop.glb"),
}

const MATERIALS := {
	"bark": preload("res://assets/materials/bark.tres"),
	"leaves": preload("res://assets/materials/leaves.tres"),
	"grass_blade": preload("res://assets/materials/grass_blade.tres"),
	"hill_forest": preload("res://assets/materials/hill_forest.tres"),
	"rock": preload("res://assets/materials/rock.tres"),
	"idol": preload("res://assets/materials/idol.tres"),
	"rope": preload("res://assets/materials/rope.tres"),
	"shadow": preload("res://assets/materials/shadow.tres"),
	"canvas": preload("res://assets/materials/canvas.tres"),
	"gunmetal": preload("res://assets/materials/gunmetal.tres"),
}

const TREES := ["tree_a", "tree_b", "tree_c", "palm_a", "palm_b"]
const LEAF_TINTS := [Color(1, 1, 1), Color(0.85, 1.0, 0.82), Color(1.08, 1.04, 0.78), Color(0.8, 0.95, 0.9)]

static var _tinted := {}


## The material for a mesh suffix, tinted (cached per tint).
static func material(kind: String, tint := Color.WHITE) -> Material:
	var base: Material = MATERIALS[kind] if MATERIALS.has(kind) else Art.material(kind)
	if tint == Color.WHITE:
		return base
	var key := kind + tint.to_html()
	if not _tinted.has(key):
		var mat: ShaderMaterial = base.duplicate()
		var albedo: Color = mat.get_shader_parameter("albedo") if mat.get_shader_parameter("albedo") != null else Color.WHITE
		mat.set_shader_parameter("albedo", albedo * tint)
		_tinted[key] = mat
	return _tinted[key]


## Places a prop. `tints` maps a material suffix to a tint (e.g. {"leaves": ...}).
## `solid` gives trees a trunk collider and rocks/tents a box collider.
static func spawn(parent: Node, id: String, pos: Vector3, yaw_deg := 0.0, scale := 1.0, tints := {}, solid := false) -> Node3D:
	var node: Node3D = SCENES[id].instantiate()
	node.position = pos
	node.rotation_degrees.y = yaw_deg
	node.scale = Vector3.ONE * scale
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var parts := String(mi.name).split("__")
		var kind := parts[1] if parts.size() > 1 else "rock"
		mi.material_override = material(kind, tints.get(kind, Color.WHITE))
		if kind == "grass_blade" or kind == "rope":
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	if solid:
		_collider(node, id)
	return node


static func _collider(node: Node3D, id: String) -> void:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	if id.begins_with("tree") or id.begins_with("palm"):
		var shape := CylinderShape3D.new()
		shape.radius = 0.45
		shape.height = 6.0
		col.shape = shape
		col.position.y = 3.0
	elif id == "tent":
		var shape := BoxShape3D.new()
		shape.size = Vector3(2.6, 1.9, 4.2)
		col.shape = shape
		col.position.y = 0.95
	else:
		var aabb := AABB()
		var first := true
		for mi in node.find_children("*", "MeshInstance3D", true, false):
			var box: AABB = mi.get_aabb()
			aabb = box if first else aabb.merge(box)
			first = false
		var shape := BoxShape3D.new()
		shape.size = aabb.size * 0.9
		col.shape = shape
		col.position = aabb.get_center()
	body.add_child(col)
	node.add_child(body)


## A random tree (broadleaf or palm) with a random leaf tint.
static func tree(parent: Node, pos: Vector3, rng: RandomNumberGenerator, scale := 1.0, solid := true) -> Node3D:
	var id: String = TREES[rng.randi() % TREES.size()]
	return spawn(parent, id, pos, rng.randf_range(0, 360), scale * rng.randf_range(0.85, 1.2),
			{"leaves": LEAF_TINTS[rng.randi() % LEAF_TINTS.size()]}, solid)


## Many copies of one prop's mesh in a single draw (grass, ferns, far trees).
## Returns one MultiMeshInstance3D per mesh in the prop.
static func scatter(parent: Node, id: String, transforms: Array, tint := Color.WHITE) -> Array:
	var made := []
	var proto: Node3D = SCENES[id].instantiate()
	for mi in proto.find_children("*", "MeshInstance3D", true, false):
		var parts := String(mi.name).split("__")
		var kind := parts[1] if parts.size() > 1 else "rock"
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mi.mesh
		mm.instance_count = transforms.size()
		for i in transforms.size():
			mm.set_instance_transform(i, transforms[i] * mi.transform)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = material(kind, tint)
		if kind == "grass_blade":
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mmi)
		made.append(mmi)
	proto.free()
	return made
