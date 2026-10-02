extends RefCounted
## Props for the forest run level: the Blender models in assets/models/forest
## (made by tools/forest/build_props.py) plus the hub's broadleaf trees, bushes,
## ferns, grass and rocks. Meshes are named "<part>__<material>" and get the
## game's materials like the hub props do (hub_props.gd).
## The structure helpers place a model and give it invisible box colliders sized
## to match, so gameplay never depends on mesh detail.

const Kit := preload("res://scripts/run/level_kit.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")
const HubProps := preload("res://scripts/hub/hub_props.gd")

const SCENES := {
	"pine_a": preload("res://assets/models/forest/pine_a.glb"),
	"pine_b": preload("res://assets/models/forest/pine_b.glb"),
	"pine_c": preload("res://assets/models/forest/pine_c.glb"),
	"snag": preload("res://assets/models/forest/snag.glb"),
	"log_fallen": preload("res://assets/models/forest/log_fallen.glb"),
	"stump": preload("res://assets/models/forest/stump.glb"),
	"wall_slab": preload("res://assets/models/forest/wall_slab.glb"),
	"gate": preload("res://assets/models/forest/gate.glb"),
	"watchtower": preload("res://assets/models/forest/watchtower.glb"),
	"hut": preload("res://assets/models/forest/hut.glb"),
	"sandbags": preload("res://assets/models/forest/sandbags.glb"),
	"crate_stack": preload("res://assets/models/forest/crate_stack.glb"),
	"floodlight": preload("res://assets/models/forest/floodlight.glb"),
	"antenna": preload("res://assets/models/forest/antenna.glb"),
	"fuel_tank": preload("res://assets/models/forest/fuel_tank.glb"),
	"log_pile": preload("res://assets/models/forest/log_pile.glb"),
	"sawmill": preload("res://assets/models/forest/sawmill.glb"),
	"bridge_stub": preload("res://assets/models/forest/bridge_stub.glb"),
	"pylon": preload("res://assets/models/forest/pylon.glb"),
	"wreck_truck": preload("res://assets/models/forest/wreck_truck.glb"),
	"evac_pad": preload("res://assets/models/forest/evac_pad.glb"),
	"dropship": preload("res://assets/models/forest/dropship.glb"),
	"log_bridge": preload("res://assets/models/forest/log_bridge.glb"),
	"tall_grass": preload("res://assets/models/forest/tall_grass.glb"),
	"barrels": preload("res://assets/models/forest/barrels.glb"),
	"pallet": preload("res://assets/models/forest/pallet.glb"),
	"generator": preload("res://assets/models/forest/generator.glb"),
	"camo_net": preload("res://assets/models/forest/camo_net.glb"),
	"deer_stand": preload("res://assets/models/forest/deer_stand.glb"),
	"culvert": preload("res://assets/models/forest/culvert.glb"),
	"tent": preload("res://assets/models/hub/tent.glb"),
	"tree_a": preload("res://assets/models/hub/tree_a.glb"),
	"tree_b": preload("res://assets/models/hub/tree_b.glb"),
	"tree_c": preload("res://assets/models/hub/tree_c.glb"),
	"bush_a": preload("res://assets/models/hub/bush_a.glb"),
	"bush_b": preload("res://assets/models/hub/bush_b.glb"),
	"fern": preload("res://assets/models/hub/fern.glb"),
	"grass_tuft": preload("res://assets/models/hub/grass_tuft.glb"),
	"rock_a": preload("res://assets/models/hub/rock_a.glb"),
	"rock_b": preload("res://assets/models/hub/rock_b.glb"),
	"rock_c": preload("res://assets/models/hub/rock_c.glb"),
	"hill_a": preload("res://assets/models/hub/hill_a.glb"),
	"hill_b": preload("res://assets/models/hub/hill_b.glb"),
}

## Physics layer (bit value) for things that only block grunts' sight: dense
## foliage you can walk through. Bodies, the player and grunts stay on layer 1,
## so nothing collides with it; vision raycasts include it. Areas marking
## foliage you can hide in sit on the same layer, in group "stealth_cover".
const SIGHT_LAYER := 16
## Enemy lamps and windows: cold work-light white with a hint of blue.
const LAMP := Color(0.85, 0.92, 1.0)
## Needles a little darker and bluer than the hub's jungle leaves.
const NEEDLE_TINTS := [Color(0.42, 0.6, 0.5), Color(0.36, 0.54, 0.46), Color(0.5, 0.66, 0.48)]
const LEAF_TINTS := [Color(0.62, 0.76, 0.52), Color(0.78, 0.76, 0.5), Color(0.56, 0.7, 0.58)]
const TREE_IDS := ["pine_a", "pine_b", "pine_c", "pine_a", "pine_b", "tree_a", "tree_b", "snag"]


static func spawn(parent: Node, id: String, pos: Vector3, yaw_deg := 0.0, scale := 1.0, tints := {}, lamp := LAMP) -> Node3D:
	var node: Node3D = SCENES[id].instantiate()
	node.position = pos
	node.rotation_degrees.y = yaw_deg
	node.scale = Vector3.ONE * scale
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var kind := _kind(mi)
		mi.material_override = HubProps.material(kind, tints.get(kind, Color.WHITE))
		if kind == "light":
			mi.set_instance_shader_parameter("paint", lamp)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif kind == "grass_blade":
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


## Many copies of one prop in a single draw per mesh (grass, ferns, far trees).
static func scatter(parent: Node, id: String, transforms: Array, tints := {}, shadows := true) -> void:
	if transforms.is_empty():
		return
	var proto: Node3D = SCENES[id].instantiate()
	for mi in proto.find_children("*", "MeshInstance3D", true, false):
		var kind := _kind(mi)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mi.mesh
		mm.instance_count = transforms.size()
		for i in transforms.size():
			mm.set_instance_transform(i, transforms[i] * mi.transform)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = HubProps.material(kind, tints.get(kind, Color.WHITE))
		if kind == "grass_blade" or not shadows:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mmi)
	proto.free()


static func _kind(mi: Node) -> String:
	var parts := String(mi.name).split("__")
	# glTF import can append digits to repeated names ("leaves_001"); strip them.
	var kind := parts[1] if parts.size() > 1 else "rock"
	var under := kind.find("_0")
	return kind.substr(0, under) if under > 0 else kind


## An invisible box collider. `yaw_deg` turns it about Y round `pos`.
static func solid(parent: Node, pos: Vector3, size: Vector3, yaw_deg := 0.0, tilt := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation_degrees = Vector3(tilt.x, yaw_deg, tilt.z)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	parent.add_child(body)
	return body


## Boxes given in the model's local frame (centre, size), turned with it.
static func _solids(parent: Node, at: Vector3, yaw_deg: float, boxes: Array) -> void:
	var basis := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	for b in boxes:
		solid(parent, at + basis * (b[0] as Vector3), b[1], yaw_deg)


# --- vegetation ---------------------------------------------------------------

## A tree with a trunk collider. Returns the model.
static func tree(parent: Node, pos: Vector3, rng: RandomNumberGenerator, scale := 1.0, id := "") -> Node3D:
	if id == "":
		id = TREE_IDS[rng.randi() % TREE_IDS.size()]
	var s := scale * rng.randf_range(0.85, 1.25)
	var node := spawn(parent, id, pos, rng.randf_range(0, 360), s, _tree_tints(id, rng))
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.45 if id.begins_with("pine") or id == "snag" else 0.5
	shape.height = 7.0
	col.shape = shape
	col.position.y = 3.5
	body.add_child(col)
	node.add_child(body)
	return node


static func _tree_tints(id: String, rng: RandomNumberGenerator) -> Dictionary:
	if id.begins_with("pine"):
		return {"leaves": NEEDLE_TINTS[rng.randi() % NEEDLE_TINTS.size()]}
	return {"leaves": LEAF_TINTS[rng.randi() % LEAF_TINTS.size()]}


## A felled trunk along its local X with a collider you can vault or hide behind.
static func fallen_log(parent: Node, pos: Vector3, yaw_deg: float) -> void:
	spawn(parent, "log_fallen", pos, yaw_deg, 1.0, {"leaves": NEEDLE_TINTS[0]})
	_solids(parent, pos, yaw_deg, [[Vector3(0.3, 0.5, 0), Vector3(8.4, 1.0, 1.0)]])


static func rock(parent: Node, id: String, pos: Vector3, yaw_deg: float, scale: float, solid_rock := true) -> void:
	var node := spawn(parent, id, pos, yaw_deg, scale)
	if not solid_rock:
		return
	var aabb := AABB()
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		aabb = mi.get_aabb() if first else aabb.merge(mi.get_aabb())
		first = false
	var size := aabb.size * scale * 0.85
	solid(parent, pos + Vector3(0, aabb.get_center().y * scale, 0), size, yaw_deg)


# --- enemy outpost kit (sizes match tools/forest/build_props.py) -------------

## Prefab wall panel, 4 W x 6 H x 0.8 D.
static func wall_slab(parent: Node, pos: Vector3, yaw_deg := 0.0) -> void:
	spawn(parent, "wall_slab", pos, yaw_deg)
	_solids(parent, pos, yaw_deg, [[Vector3(0, 3.0, 0), Vector3(4.0, 6.0, 0.8)]])


## Closed gate, 8 W x 6.9 H x 1.2 D.
static func gate(parent: Node, pos: Vector3, yaw_deg := 0.0) -> void:
	spawn(parent, "gate", pos, yaw_deg, 1.0, {}, Color(1.0, 0.5, 0.3))
	_solids(parent, pos, yaw_deg, [[Vector3(0, 3.45, 0), Vector3(8.0, 6.9, 1.2)]])


## Watchtower: deck top 7 m up. Returns the deck's top centre (where a lookout stands).
static func watchtower(parent: Node, pos: Vector3, yaw_deg := 0.0) -> Vector3:
	spawn(parent, "watchtower", pos, yaw_deg)
	var boxes := [
		[Vector3(0, 6.85, 0), Vector3(4.4, 0.3, 4.4)],
		[Vector3(0, 7.45, 2.15), Vector3(4.4, 0.9, 0.12)],
		[Vector3(-2.15, 7.45, 0.6), Vector3(0.12, 0.9, 3.2)],
		[Vector3(2.15, 7.45, 0.6), Vector3(0.12, 0.9, 3.2)],
		[Vector3(0, 9.65, 0), Vector3(5.0, 0.25, 5.0)],
	]
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			boxes.append([Vector3(sx * 2.15, 3.4, sz * 2.15), Vector3(0.3, 6.8, 0.3)])
	_solids(parent, pos, yaw_deg, boxes)
	var l := OmniLight3D.new()
	l.light_color = LAMP
	l.light_energy = 1.2
	l.omni_range = 9.0
	l.position = pos + Basis(Vector3.UP, deg_to_rad(yaw_deg)) * Vector3(1.4, 8.0, 3.0)
	parent.add_child(l)
	return pos + Vector3(0, 7.0, 0)


## Prefab barracks, 8 W x 3.4 H x 5 D, flat roof you can stand on. Returns the roof's top centre.
static func hut(parent: Node, pos: Vector3, yaw_deg := 0.0) -> Vector3:
	spawn(parent, "hut", pos, yaw_deg)
	_solids(parent, pos, yaw_deg, [[Vector3(0, 1.75, 0), Vector3(8.2, 3.5, 5.2)]])
	return pos + Vector3(0, 3.5, 0)


## Low cover, 2.2 W x 1.2 H x 0.6 D.
static func sandbags(parent: Node, pos: Vector3, yaw_deg := 0.0) -> void:
	spawn(parent, "sandbags", pos, yaw_deg, 1.0, {"canvas": Color(0.55, 0.5, 0.36)})
	_solids(parent, pos, yaw_deg, [[Vector3(0, 0.6, 0), Vector3(2.2, 1.2, 0.6)]])


## Tall cover, 1.4 x 2.6 x 1.4.
static func crate_stack(parent: Node, pos: Vector3, yaw_deg := 0.0) -> void:
	spawn(parent, "crate_stack", pos, yaw_deg, 1.0, {"wood": Color(0.7, 0.8, 0.6)})
	_solids(parent, pos, yaw_deg, [[Vector3(0, 1.3, 0), Vector3(1.4, 2.6, 1.4)]])


## Cut logs, 5 W x 1.8 H x 2.4 D. Climbable, and good tall cover.
static func log_pile(parent: Node, pos: Vector3, yaw_deg := 0.0) -> void:
	spawn(parent, "log_pile", pos, yaw_deg)
	_solids(parent, pos, yaw_deg, [[Vector3(0, 0.9, 0), Vector3(5.0, 1.8, 2.4)]])


## Open sawmill shed, 12 W x 8 D, roof top at 5 m. Returns the roof's top centre.
static func sawmill(parent: Node, pos: Vector3, yaw_deg := 0.0) -> Vector3:
	spawn(parent, "sawmill", pos, yaw_deg)
	var boxes := [
		[Vector3(0, 4.88, 0), Vector3(12.4, 0.24, 8.4)],
		[Vector3(0, 0.5, 0), Vector3(7.0, 1.0, 1.4)],
	]
	for x in [-5.8, 0.0, 5.8]:
		for z in [-3.8, 3.8]:
			boxes.append([Vector3(x, 2.4, z), Vector3(0.35, 4.8, 0.35)])
	_solids(parent, pos, yaw_deg, boxes)
	return pos + Vector3(0, 5.0, 0)


static func floodlight(parent: Node, pos: Vector3, yaw_deg := 0.0) -> void:
	spawn(parent, "floodlight", pos, yaw_deg)
	_solids(parent, pos, yaw_deg, [[Vector3(0, 3.0, 0), Vector3(0.3, 6.0, 0.3)]])
	var l := OmniLight3D.new()
	l.light_color = LAMP
	l.light_energy = 1.6
	l.omni_range = 12.0
	l.omni_attenuation = 1.2
	l.position = pos + Basis(Vector3.UP, deg_to_rad(yaw_deg)) * Vector3(0, 5.2, 1.2)
	parent.add_child(l)


## Comms mast, 14 m: something to grapple.
static func antenna(parent: Node, pos: Vector3) -> void:
	spawn(parent, "antenna", pos, 0.0, 1.0, {}, Color(1.0, 0.3, 0.25))
	_solids(parent, pos, 0.0, [[Vector3(0, 0.2, 0), Vector3(2.4, 0.4, 2.4)], [Vector3(0, 7.0, 0), Vector3(1.0, 14.0, 1.0)]])


static func fuel_tank(parent: Node, pos: Vector3, yaw_deg := 0.0) -> void:
	spawn(parent, "fuel_tank", pos, yaw_deg, 1.0, {"titan_armor": Color(0.75, 0.82, 0.75)})
	_solids(parent, pos, yaw_deg, [[Vector3(0, 1.5, 0), Vector3(6.0, 3.0, 2.6)]])


## One end of the blown bridge. Origin is the deck's top centre; the broken end
## faces -Z at yaw 0. Deck 6 W x 10 L.
static func bridge_stub(parent: Node, pos: Vector3, yaw_deg := 0.0) -> void:
	spawn(parent, "bridge_stub", pos, yaw_deg)
	_solids(parent, pos, yaw_deg, [[Vector3(0, -0.6, 0), Vector3(6.0, 1.2, 10.0)]])


## Crane pylon whose arm reaches 8.5 m toward +Z at yaw 0, underside 12 m up.
static func pylon(parent: Node, pos: Vector3, yaw_deg := 0.0) -> void:
	spawn(parent, "pylon", pos, yaw_deg)
	_solids(parent, pos, yaw_deg, [[Vector3(0, 6.0, 0), Vector3(2.0, 12.0, 2.0)], [Vector3(0, 12.6, 4.0), Vector3(1.2, 1.2, 10.0)]])


## Burnt-out truck, 7 x 3 x 3 (long along local X). Titan-height cover it is not; pilot cover it is.
static func wreck_truck(parent: Node, pos: Vector3, yaw_deg := 0.0) -> void:
	spawn(parent, "wreck_truck", pos, yaw_deg, 1.0, {"titan_armor": Color(0.55, 0.5, 0.45)})
	_solids(parent, pos, yaw_deg, [[Vector3(0, 1.4, 0), Vector3(7.0, 2.8, 2.6)]])


# --- route pieces and clutter -------------------------------------------------

## A giant fallen pine spanning a gap along its local X (26 m). Walk along the top.
static func log_bridge(parent: Node, pos: Vector3, yaw_deg: float) -> void:
	spawn(parent, "log_bridge", pos, yaw_deg, 1.0, {"leaves": NEEDLE_TINTS[0]})
	_solids(parent, pos, yaw_deg, [[Vector3(0, -0.2, 0), Vector3(26.0, 1.0, 1.5)]])


## Drainage culvert through a wall, 4 W, origin at the bottom of its 2.2 m opening.
static func culvert(parent: Node, pos: Vector3, yaw_deg := 0.0) -> void:
	spawn(parent, "culvert", pos, yaw_deg)
	_solids(parent, pos, yaw_deg, [
		[Vector3(0, 4.85, 0), Vector3(4.0, 5.7, 0.8)],
		[Vector3(-1.65, 1.1, 0), Vector3(0.7, 2.2, 1.0)],
		[Vector3(1.65, 1.1, 0), Vector3(0.7, 2.2, 1.0)],
	])


static func barrels(parent: Node, pos: Vector3, yaw_deg := 0.0) -> void:
	spawn(parent, "barrels", pos, yaw_deg, 1.0, {"titan_armor": Color(0.55, 0.62, 0.5)})
	_solids(parent, pos, yaw_deg, [[Vector3(0, 0.45, 0), Vector3(1.8, 0.9, 1.6)]])


static func pallet(parent: Node, pos: Vector3, yaw_deg := 0.0) -> void:
	spawn(parent, "pallet", pos, yaw_deg, 1.0, {"canvas": Color(0.5, 0.55, 0.4)})
	_solids(parent, pos, yaw_deg, [[Vector3(0, 0.75, 0), Vector3(2.4, 1.5, 1.6)]])


static func generator(parent: Node, pos: Vector3, yaw_deg := 0.0) -> void:
	spawn(parent, "generator", pos, yaw_deg, 1.0, {"titan_armor": Color(0.6, 0.62, 0.5)}, Color(0.4, 1.0, 0.5))
	_solids(parent, pos, yaw_deg, [[Vector3(0, 0.7, 0), Vector3(2.0, 1.4, 1.2)]])


## Camouflage netting on poles, 8 x 6. Shade, and nothing you collide with but the poles.
static func camo_net(parent: Node, pos: Vector3, yaw_deg := 0.0) -> void:
	spawn(parent, "camo_net", pos, yaw_deg, 1.0, {"leaves": Color(0.45, 0.5, 0.36)})
	var boxes := []
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			boxes.append([Vector3(sx * 4.0, 1.5, sz * 3.0), Vector3(0.15, 3.0, 0.15)])
	_solids(parent, pos, yaw_deg, boxes)


## Hunter's blind on stilts. Returns its floor's top centre (3 m up).
static func deer_stand(parent: Node, pos: Vector3, yaw_deg := 0.0) -> Vector3:
	spawn(parent, "deer_stand", pos, yaw_deg, 1.0, {"leaves": NEEDLE_TINTS[1]})
	var boxes := [
		[Vector3(0, 2.95, 0), Vector3(2.4, 0.1, 2.4)],
		[Vector3(0, 3.35, 1.15), Vector3(2.4, 0.7, 0.1)],
		[Vector3(-1.15, 3.7, 0), Vector3(0.1, 1.4, 2.4)],
		[Vector3(1.15, 3.7, 0), Vector3(0.1, 1.4, 2.4)],
		[Vector3(0, 4.55, -0.1), Vector3(2.8, 0.12, 2.8)],
	]
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			boxes.append([Vector3(sx, 1.5, sz), Vector3(0.16, 3.0, 0.16)])
	_solids(parent, pos, yaw_deg, boxes)
	return pos + Vector3(0, 3.0, 0)


static func tent(parent: Node, pos: Vector3, yaw_deg := 0.0) -> void:
	spawn(parent, "tent", pos, yaw_deg, 1.0, {"canvas": Color(0.55, 0.58, 0.42)})
	_solids(parent, pos, yaw_deg, [[Vector3(0, 0.95, 0), Vector3(2.6, 1.9, 4.2)]])


## Foliage you can hide in: an Area3D in group "stealth_cover" filling `size`
## (box centred at `pos`). The stealth system decides what being inside means.
static func stealth_cover(parent: Node, pos: Vector3, size: Vector3, yaw_deg := 0.0) -> Area3D:
	var area := Area3D.new()
	area.name = "StealthCover"
	area.add_to_group("stealth_cover")
	area.collision_layer = SIGHT_LAYER
	area.collision_mask = 0
	area.monitoring = false
	area.position = pos
	area.rotation_degrees.y = yaw_deg
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	area.add_child(col)
	parent.add_child(area)
	return area


## Foliage that blocks grunts' sight but not movement (see SIGHT_LAYER).
static func sight_blocker(parent: Node, pos: Vector3, size: Vector3, yaw_deg := 0.0) -> StaticBody3D:
	var body := solid(parent, pos, size, yaw_deg)
	body.name = "SightBlocker"
	body.add_to_group("sight_blocker")
	body.collision_layer = SIGHT_LAYER
	body.collision_mask = 0
	return body


## A patch of tall grass and ferns centred at `center` (x, z), `size` across,
## following the ground via `ground` (a Callable(x, z) -> y). Adds the hiding
## area; a `dense` patch also blocks sight. Returns grass transforms to batch.
static func grass_patch(parent: Node, ground: Callable, center: Vector2, size: Vector2, rng: RandomNumberGenerator, dense := false, yaw_deg := 0.0) -> Array:
	var made := []
	var basis_yaw := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	var count := int(size.x * size.y / (1.6 if dense else 2.4))
	for i in count:
		var local := Vector3(rng.randf_range(-0.5, 0.5) * size.x, 0, rng.randf_range(-0.5, 0.5) * size.y)
		var w := basis_yaw * local
		var p := Vector3(center.x + w.x, 0, center.y + w.z)
		p.y = ground.call(p.x, p.z) - 0.05
		var b := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * rng.randf_range(0.9, 1.3))
		made.append(Transform3D(b, p))
	var mid_y: float = ground.call(center.x, center.y)
	stealth_cover(parent, Vector3(center.x, mid_y + 0.8, center.y), Vector3(size.x, 2.4, size.y), yaw_deg)
	if dense:
		sight_blocker(parent, Vector3(center.x, mid_y + 0.9, center.y), Vector3(size.x * 0.8, 1.6, size.y * 0.8), yaw_deg)
	return made
