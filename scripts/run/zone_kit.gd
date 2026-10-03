extends RefCounted
## Props for run zones 2 and 3: the Blender models in assets/models/marsh
## (Blackwater) and assets/models/boneyard (the Boneyard), made by
## tools/zones/build_props.py. They get the game's materials and invisible box
## colliders the same way the forest's props do (forest_kit.gd, whose props
## these zones reuse too).

const F := preload("res://scripts/run/forest_kit.gd")

const SCENES := {
	"cypress_a": preload("res://assets/models/marsh/cypress_a.glb"),
	"cypress_b": preload("res://assets/models/marsh/cypress_b.glb"),
	"cypress_dead": preload("res://assets/models/marsh/cypress_dead.glb"),
	"reeds": preload("res://assets/models/marsh/reeds.glb"),
	"lily_pads": preload("res://assets/models/marsh/lily_pads.glb"),
	"stilt_hut": preload("res://assets/models/marsh/stilt_hut.glb"),
	"boardwalk": preload("res://assets/models/marsh/boardwalk.glb"),
	"dock": preload("res://assets/models/marsh/dock.glb"),
	"pipe_run": preload("res://assets/models/marsh/pipe_run.glb"),
	"pump_house": preload("res://assets/models/marsh/pump_house.glb"),
	"storage_tank": preload("res://assets/models/marsh/storage_tank.glb"),
	"barge": preload("res://assets/models/marsh/barge.glb"),
	"skiff": preload("res://assets/models/marsh/skiff.glb"),
	"titan_fallen": preload("res://assets/models/boneyard/titan_fallen.glb"),
	"titan_kneeling": preload("res://assets/models/boneyard/titan_kneeling.glb"),
	"titan_arm": preload("res://assets/models/boneyard/titan_arm.glb"),
	"revetment": preload("res://assets/models/boneyard/revetment.glb"),
	"barbed_wire": preload("res://assets/models/boneyard/barbed_wire.glb"),
	"container": preload("res://assets/models/boneyard/container.glb"),
	"gantry": preload("res://assets/models/boneyard/gantry.glb"),
	"salvage_shed": preload("res://assets/models/boneyard/salvage_shed.glb"),
	"scrap_pile": preload("res://assets/models/boneyard/scrap_pile.glb"),
	"ruin_pillar": preload("res://assets/models/boneyard/ruin_pillar.glb"),
	"ruin_pillar_short": preload("res://assets/models/boneyard/ruin_pillar_short.glb"),
	"obelisk_fallen": preload("res://assets/models/boneyard/obelisk_fallen.glb"),
	"eye_shrine": preload("res://assets/models/boneyard/eye_shrine.glb"),
}

## Swamp needles: olive and a little yellow, under grey moss beards.
const CYPRESS_TINTS := [Color(0.55, 0.62, 0.4), Color(0.62, 0.64, 0.38), Color(0.48, 0.58, 0.42)]
const MOSS_BEARD := Color(0.72, 0.74, 0.62)
## Dead titans: militia olive and old blue-grey, rusted and sun-bleached.
const HULL_TINTS := [Color(0.62, 0.6, 0.52), Color(0.55, 0.6, 0.66), Color(0.66, 0.55, 0.46)]
## Container paint: rust red, faded blue, militia green, dirty white.
const CONTAINER_TINTS := [Color(0.8, 0.42, 0.32), Color(0.45, 0.58, 0.72), Color(0.5, 0.6, 0.42), Color(0.82, 0.8, 0.72)]
## The precursor's eye glows the same as the idol's in the temple.
const EYE := Color(0.55, 1.0, 0.85)


## Spawns a prop from this table or the forest's.
static func spawn(parent: Node, id: String, pos: Vector3, yaw_deg := 0.0, scale := 1.0, tints := {}, lamp := F.LAMP) -> Node3D:
	var scene: PackedScene = SCENES[id] if SCENES.has(id) else F.SCENES[id]
	return F.place(parent, scene, pos, yaw_deg, scale, tints, lamp)


static func scatter(parent: Node, id: String, transforms: Array, tints := {}, shadows := true) -> void:
	var scene: PackedScene = SCENES[id] if SCENES.has(id) else F.SCENES[id]
	F.scatter_scene(parent, scene, transforms, tints, shadows)


## An invisible upright cylinder collider standing on `pos`.
static func column(parent: Node, pos: Vector3, radius: float, height: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos + Vector3(0, height * 0.5, 0)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	col.shape = shape
	body.add_child(col)
	parent.add_child(body)
	return body


# --- Blackwater ----------------------------------------------------------------

## A swamp cypress with a trunk collider. `id` empty picks one.
static func cypress(parent: Node, pos: Vector3, rng: RandomNumberGenerator, scale := 1.0, id := "") -> Node3D:
	if id == "":
		id = ["cypress_a", "cypress_b", "cypress_a", "cypress_dead"][rng.randi() % 4]
	var s := scale * rng.randf_range(0.85, 1.2)
	var node := spawn(parent, id, pos, rng.randf_range(0, 360), s,
			{"leaves": CYPRESS_TINTS[rng.randi() % CYPRESS_TINTS.size()], "grass_blade": MOSS_BEARD})
	column(parent, pos - Vector3(0, 1.0, 0), 0.75 * s, 9.0 * s)
	return node


## Fishing hut on stilts. Origin in the mud; deck top 2.5 m up, roof top 5.4 m
## up. Returns the roof's top centre.
static func stilt_hut(parent: Node, pos: Vector3, yaw_deg := 0.0) -> Vector3:
	spawn(parent, "stilt_hut", pos, yaw_deg, 1.0, {"wood": Color(0.78, 0.74, 0.66)})
	var boxes := [
		[Vector3(0, 2.42, 0), Vector3(6.0, 0.16, 6.0)],
		[Vector3(0, 3.8, -0.8), Vector3(4.4, 2.6, 3.6)],
		[Vector3(0, 5.3, -0.8), Vector3(6.1, 0.2, 4.8)],
		[Vector3(-0.75, 3.0, 2.95), Vector3(4.5, 1.0, 0.1)],
	]
	for sx in [-2.7, 0.0, 2.7]:
		for sz in [-2.7, 0.0, 2.7]:
			boxes.append([Vector3(sx, 0.45, sz), Vector3(0.28, 3.9, 0.28)])
	F._solids(parent, pos, yaw_deg, boxes)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.8, 0.55)
	l.light_energy = 0.9
	l.omni_range = 7.0
	l.position = pos + Basis(Vector3.UP, deg_to_rad(yaw_deg)) * Vector3(1.2, 3.9, 1.6)
	parent.add_child(l)
	return pos + Vector3(0, 5.4, 0) + Basis(Vector3.UP, deg_to_rad(yaw_deg)) * Vector3(0, 0, -0.8)


## A 2.2 x 6 boardwalk along local Z, origin on the deck's top.
static func boardwalk(parent: Node, pos: Vector3, yaw_deg := 0.0) -> void:
	spawn(parent, "boardwalk", pos, yaw_deg, 1.0, {"wood": Color(0.75, 0.72, 0.64)})
	F._solids(parent, pos, yaw_deg, [[Vector3(0, -0.08, 0), Vector3(2.2, 0.16, 6.0)]])


## A 6 x 6 dock, origin on the deck's top.
static func dock(parent: Node, pos: Vector3, yaw_deg := 0.0) -> void:
	spawn(parent, "dock", pos, yaw_deg, 1.0, {"wood": Color(0.75, 0.72, 0.64)})
	F._solids(parent, pos, yaw_deg, [[Vector3(0, -0.08, 0), Vector3(6.0, 0.16, 6.0)], [Vector3(2.0, 0.75, -2.0), Vector3(0.8, 1.5, 0.7)]])


## 12 m of pipeline along local X on trestles; the pipe's top is 3.6 m up.
static func pipe_run(parent: Node, pos: Vector3, yaw_deg := 0.0) -> void:
	spawn(parent, "pipe_run", pos, yaw_deg, 1.0, {"titan_armor": Color(0.72, 0.7, 0.6)})
	F._solids(parent, pos, yaw_deg, [
		[Vector3(0, 2.9, 0), Vector3(12.0, 1.4, 1.4)],
		[Vector3(-3.0, 1.1, 0), Vector3(0.4, 2.2, 2.0)],
		[Vector3(3.0, 1.1, 0), Vector3(0.4, 2.2, 2.0)],
	])


## The pumping station, 14 x 10, roof top at 6 m. Returns the roof's top centre.
static func pump_house(parent: Node, pos: Vector3, yaw_deg := 0.0) -> Vector3:
	spawn(parent, "pump_house", pos, yaw_deg, 1.0, {"concrete": Color(0.82, 0.84, 0.78)}, Color(1.0, 0.85, 0.55))
	var boxes := [
		[Vector3(0, 3.0, 0), Vector3(14.4, 6.0, 10.4)],
		[Vector3(-3.5, 6.6, -2.5), Vector3(2.0, 1.2, 2.0)],
		[Vector3(3.5, 6.5, -2.0), Vector3(3.0, 0.9, 1.6)],
		[Vector3(-9.3, 1.5, 2.5), Vector3(1.6, 6.0, 1.6)],
		[Vector3(-9.3, 1.5, -2.0), Vector3(1.6, 6.0, 1.6)],
	]
	for x in [-6.8, -2.3, 2.3, 6.8]:
		boxes.append([Vector3(x, 2.6, 5.15), Vector3(0.6, 5.2, 0.5)])
	F._solids(parent, pos, yaw_deg, boxes)
	return pos + Vector3(0, 6.0, 0)


## A storage tank, 7 m across, 6 m tall.
static func storage_tank(parent: Node, pos: Vector3, yaw_deg := 0.0) -> void:
	spawn(parent, "storage_tank", pos, yaw_deg, 1.0, {"titan_armor": Color(0.78, 0.76, 0.66)})
	column(parent, pos, 3.55, 6.4)


## A barge run aground, 17 m along local X, its sheer side (local +Z, 5 m
## high from 1.5 m below the origin) painted for wallrunning.
static func barge(parent: Node, pos: Vector3, yaw_deg := 0.0) -> void:
	spawn(parent, "barge", pos, yaw_deg, 1.0, {"titan_armor": Color(0.62, 0.5, 0.42)})
	F._solids(parent, pos, yaw_deg, [
		[Vector3(0, 0.5, -0.6), Vector3(17.0, 3.0, 4.6)],
		[Vector3(0, 1.0, 1.85), Vector3(17.0, 5.0, 0.3)],
		[Vector3(-6.0, 3.2, -1.4), Vector3(3.0, 2.4, 2.6)],
	])


# --- the Boneyard ------------------------------------------------------------

## A dead titan face down, 24 m from head (local -X) to boots (+X), its back
## a 2.6 m wide walkway at the origin. Lying on flat ground, put the origin
## 3.4 m up; its hand (1 m up) and arm (1.4 m up) are the steps onto it.
static func titan_fallen(parent: Node, pos: Vector3, yaw_deg := 0.0, tint := Color.WHITE) -> void:
	spawn(parent, "titan_fallen", pos, yaw_deg, 1.0, {"titan_armor": tint}, EYE)
	F._solids(parent, pos, yaw_deg, [
		[Vector3(-0.35, -0.25, 0), Vector3(24.1, 0.5, 2.6)],
		[Vector3(-3.5, -2.0, 0), Vector3(12.0, 2.6, 5.2)],
		[Vector3(-12.0, -2.7, 3.2), Vector3(5.0, 1.4, 1.4)],
		[Vector3(-15.0, -2.9, 3.6), Vector3(1.8, 1.0, 2.0)],
		[Vector3(9.0, -1.4, 0), Vector3(7.0, 2.4, 3.6)],
	])


## A dead titan on one knee, facing local +Z, shoulders 8 m up.
static func titan_kneeling(parent: Node, pos: Vector3, yaw_deg := 0.0, tint := Color.WHITE) -> void:
	spawn(parent, "titan_kneeling", pos, yaw_deg, 1.0, {"titan_armor": tint})
	F._solids(parent, pos, yaw_deg, [
		[Vector3(0, 2.9, -0.6), Vector3(3.2, 1.6, 2.4)],
		[Vector3(-1.0, 1.4, 1.4), Vector3(1.5, 1.4, 3.0)],
		[Vector3(-1.0, 0.9, 2.6), Vector3(1.5, 1.8, 1.4)],
		[Vector3(1.2, 1.0, -1.2), Vector3(1.5, 1.2, 2.8)],
		[Vector3(0, 5.6, -0.3), Vector3(5.0, 4.0, 3.4)],
		[Vector3(0, 7.4, 0.8), Vector3(6.4, 1.4, 2.6)],
		[Vector3(-3.6, 7.0, 0.3), Vector3(1.8, 2.0, 2.4)],
		[Vector3(3.6, 7.0, 0.3), Vector3(1.8, 2.0, 2.4)],
		[Vector3(0, 6.5, 1.6), Vector3(1.6, 1.3, 1.6)],
		[Vector3(-3.7, 3.6, 0.8), Vector3(1.2, 4.2, 1.2)],
		[Vector3(-3.8, 0.8, 1.2), Vector3(1.6, 1.4, 1.6)],
		[Vector3(3.8, 5.2, 1.6), Vector3(1.2, 3.0, 1.2)],
	])


## A severed titan arm along local X, 9.6 m long and 1.8 m high: cover.
static func titan_arm(parent: Node, pos: Vector3, yaw_deg := 0.0, tint := Color.WHITE) -> void:
	spawn(parent, "titan_arm", pos, yaw_deg, 1.0, {"titan_armor": tint})
	F._solids(parent, pos, yaw_deg, [[Vector3(-0.2, 0.85, 0), Vector3(9.6, 1.7, 1.8)]])


## Wire on stakes along local X, 4 m: knee-high, jump it.
static func barbed_wire(parent: Node, pos: Vector3, yaw_deg := 0.0) -> void:
	spawn(parent, "barbed_wire", pos, yaw_deg)
	F._solids(parent, pos, yaw_deg, [[Vector3(0, 0.5, 0), Vector3(4.0, 1.0, 0.8)]])


## A shipping container along local X, 6 x 2.6 x 2.4. Returns its roof's top centre.
static func container(parent: Node, pos: Vector3, yaw_deg: float, tint: Color) -> Vector3:
	spawn(parent, "container", pos, yaw_deg, 1.0, {"titan_armor": tint})
	F._solids(parent, pos, yaw_deg, [[Vector3(0, 1.3, 0), Vector3(6.0, 2.6, 2.4)]])
	return pos + Vector3(0, 2.6, 0)


## The salvage gantry: legs 16 m apart along local X, girder underside 12 m up.
static func gantry(parent: Node, pos: Vector3, yaw_deg := 0.0) -> void:
	spawn(parent, "gantry", pos, yaw_deg, 1.0, {"titan_armor": Color(0.9, 0.7, 0.35)})
	F._solids(parent, pos, yaw_deg, [
		[Vector3(-8.0, 6.0, 0), Vector3(0.8, 12.0, 2.4)],
		[Vector3(8.0, 6.0, 0), Vector3(0.8, 12.0, 2.4)],
		[Vector3(0, 12.6, 0), Vector3(17.4, 1.2, 1.2)],
	])
	for x in [-6.0, 6.0]:
		var l := OmniLight3D.new()
		l.light_color = F.LAMP
		l.light_energy = 1.4
		l.omni_range = 14.0
		l.position = pos + Basis(Vector3.UP, deg_to_rad(yaw_deg)) * Vector3(x, 11.6, 0.8)
		parent.add_child(l)


## Open shed, 12 x 8, roof top at 5 m. Returns the roof's top centre.
static func salvage_shed(parent: Node, pos: Vector3, yaw_deg := 0.0) -> Vector3:
	spawn(parent, "salvage_shed", pos, yaw_deg, 1.0, {"canvas": Color(0.55, 0.5, 0.4)}, Color(1.0, 0.6, 0.3))
	var boxes := [
		[Vector3(0, 4.88, 0), Vector3(12.4, 0.24, 8.4)],
		[Vector3(0, 0.5, 0), Vector3(7.0, 1.0, 1.4)],
	]
	for x in [-5.8, 0.0, 5.8]:
		for z in [-3.8, 3.8]:
			boxes.append([Vector3(x, 2.4, z), Vector3(0.35, 4.8, 0.35)])
	F._solids(parent, pos, yaw_deg, boxes)
	return pos + Vector3(0, 5.0, 0)


## Stripped plates and girders, 3 x 1.8 x 2.6: cover.
static func scrap_pile(parent: Node, pos: Vector3, yaw_deg := 0.0, tint := Color.WHITE) -> void:
	spawn(parent, "scrap_pile", pos, yaw_deg, 1.0, {"titan_armor": tint})
	F._solids(parent, pos, yaw_deg, [[Vector3(0, 0.9, 0), Vector3(3.0, 1.8, 2.6)]])


## A precursor column, 8 m (or 4.5 m `short`), eye facing local +Z. Returns its top.
static func ruin_pillar(parent: Node, pos: Vector3, yaw_deg := 0.0, short := false) -> Vector3:
	var h := 4.5 if short else 8.0
	spawn(parent, "ruin_pillar_short" if short else "ruin_pillar", pos, yaw_deg, 1.0, {}, EYE)
	F._solids(parent, pos, yaw_deg, [[Vector3(0, h * 0.5, 0), Vector3(2.2, h, 2.2)], [Vector3(0, 0.3, 0), Vector3(2.6, 0.6, 2.6)]])
	return pos + Vector3(0, h, 0)


## A fallen obelisk along local X, 26.5 m, its top face (walk it) at the origin.
static func obelisk_fallen(parent: Node, pos: Vector3, yaw_deg := 0.0) -> void:
	spawn(parent, "obelisk_fallen", pos, yaw_deg, 1.0, {}, EYE)
	F._solids(parent, pos, yaw_deg, [[Vector3(-0.75, -1.2, 0), Vector3(26.5, 2.4, 2.4)]])


## The eye shrine: a stepped platform, two broken columns and the standing
## stone with the god's eye, facing local +Z.
static func eye_shrine(parent: Node, pos: Vector3, yaw_deg := 0.0) -> void:
	spawn(parent, "eye_shrine", pos, yaw_deg, 1.0, {}, EYE)
	F._solids(parent, pos, yaw_deg, [
		[Vector3(0, 0.3, 0), Vector3(10.0, 0.6, 8.0)],
		[Vector3(0, 0.85, -0.6), Vector3(7.0, 0.5, 5.6)],
		[Vector3(0, 3.6, -1.6), Vector3(3.2, 5.0, 1.4)],
		[Vector3(-4.0, 2.0, 2.6), Vector3(1.4, 2.6, 1.4)],
		[Vector3(4.0, 2.0, 2.6), Vector3(1.4, 4.2, 1.4)],
	])
	var l := OmniLight3D.new()
	l.light_color = EYE
	l.light_energy = 1.5
	l.omni_range = 10.0
	l.position = pos + Basis(Vector3.UP, deg_to_rad(yaw_deg)) * Vector3(0, 4.3, 0.2)
	parent.add_child(l)
