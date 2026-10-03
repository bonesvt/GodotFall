extends RefCounted
## Biggie's gym: a room built onto the back of his den (hub_rooms.gd), through
## a door in his den's back wall. Rubber mats on old boards, a squat rack he
## welded out of titan strut, a pull-up frame, a heavy bag on a chain, two
## floor mats (one with a sandbag for hip thrusts), a dumbbell rack, a water
## jug and towels, and his chalkboard keeping score of what Eco has trained.
##
## Each piece of equipment is a workout (gym.gd WORKOUTS): an interactable
## with "workout", and in info["gym"][workout] where Eco stands for its scene
## (gym_workout.gd) and the prop the scene borrows (hidden while it plays).

const Art := preload("res://scripts/ps2/ps2_assets.gd")
const K := preload("res://scripts/hub/hub_kit.gd")
const Gym := preload("res://scripts/hub/gym.gd")

## The room (x, z, width, depth): behind Biggie's den (hub_rooms.gd BIGGIE_ROOM),
## sharing its back wall, where the door is (at DOOR_X).
const ROOM := Rect2(4.4, -45.4, 10.2, 7.0)
const DOOR_X := 12.6
const T := 0.3
const BULB := Color(1.0, 0.85, 0.6)
const RUBBER := Color(0.28, 0.27, 0.27)
const IRON := Color(0.2, 0.2, 0.22)

## Where Eco does each workout: her feet (lying down: her feet end, with her
## head toward +Z of the spot), and which way she faces (degrees about Y, 0
## faces -Z).
const SPOTS := {
	"squat": {"pos": Vector3(6.6, 0, -43.0), "yaw": 0.0},
	"pullup": {"pos": Vector3(11.4, 0, -43.3), "yaw": 90.0},
	"bag": {"pos": Vector3(6.5, 0, -39.7), "yaw": 90.0},
	"crunch": {"pos": Vector3(8.4, 0, -40.6), "yaw": 90.0},
	"bridge": {"pos": Vector3(11.0, 0, -41.2), "yaw": 90.0},
}
## Heights (m above the floor) of the squat rack's hooks and the pull-up bar.
const RACK_H := 1.42
const BAR_H := 2.18


static func build(root: Node3D, info: Dictionary, floor_y: float) -> void:
	var F := floor_y
	var gym := {}
	info["gym"] = gym
	info["gym_bounds"] = Rect2(ROOM.position + Vector2(T, T), ROOM.size - Vector2(T * 2, T))
	if info.has("training_areas"):
		info["training_areas"].append(ROOM)
	else:
		info["training_areas"] = [ROOM]
	var x0 := ROOM.position.x + T
	var x1 := ROOM.end.x - T
	var zb := ROOM.position.y + T
	var zf := ROOM.end.y
	# Rubber mats laid over the boards.
	K.mesh(root, Vector3((x0 + x1) * 0.5, F + 0.012, (zb + zf) * 0.5 - 0.1), Vector3(x1 - x0 - 0.4, 0.024, zf - zb - 0.6), Art.material("canvas", RUBBER))
	for spot: String in SPOTS:
		var s: Dictionary = SPOTS[spot].duplicate()
		s["pos"] = s["pos"] + Vector3(0, F, 0)
		gym[spot] = s
	_squat_rack(root, gym["squat"], F)
	_pullup(root, gym["pullup"], F)
	_bag(root, gym["bag"], F)
	_mat(root, gym["crunch"], Color(0.3, 0.42, 0.55))
	_mat(root, gym["bridge"], Color(0.55, 0.3, 0.25))
	var sandbag := sandbag_model()
	sandbag.position = _local(gym["bridge"], Vector3(0.35, 0.08, 1.3))
	sandbag.rotation.y = deg_to_rad(gym["bridge"]["yaw"])
	root.add_child(sandbag)
	gym["bridge"]["prop"] = sandbag
	# A dumbbell rack along the east wall, a water jug and towels on a crate.
	K.metal(root, Vector3(x1 - 0.3, F + 0.35, zb + 1.4), Vector3(0.45, 0.7, 1.6))
	for i in 5:
		var db := dumbbell_model(0.6 + i * 0.12)
		db.position = Vector3(x1 - 0.3, F + 0.78, zb + 0.8 + i * 0.3)
		db.rotation_degrees = Vector3(0, 90, 0)
		root.add_child(db)
	var crate := Vector3(x0 + 0.5, F, zb + 0.5)
	K.wood(root, crate + Vector3(0, 0.3, 0), Vector3(0.7, 0.6, 0.6))
	K.mesh(root, crate + Vector3(0.12, 0.8, 0), Vector3(0.24, 0.4, 0.24), Art.material("light"))
	K.mesh(root, crate + Vector3(-0.18, 0.64, 0.05), Vector3(0.3, 0.08, 0.4), Art.material("canvas", Color(0.9, 0.85, 0.75)))
	K.mesh(root, crate + Vector3(-0.18, 0.7, 0.05), Vector3(0.3, 0.06, 0.4), Art.material("canvas", Color(0.75, 0.3, 0.25)))
	# A cracked mirror on the back wall in front of the squat rack, and a
	# poster of a titan curling an APC.
	var mirror := K.mesh(root, Vector3(7.6, F + 1.5, zb + 0.03), Vector3(2.4, 1.8, 0.04), Art.material("light"))
	mirror.set_instance_shader_parameter("paint", Color(0.3, 0.34, 0.38))
	K.mesh(root, Vector3(7.6, F + 1.5, zb + 0.01), Vector3(2.55, 1.95, 0.03), Art.material("wood"))
	K.mesh(root, Vector3(7.6, F + 1.5, zb + 0.06), Vector3(0.02, 1.7, 0.02), Art.material("canvas", Color(0.2, 0.2, 0.22)), Vector3(0, 0, 25))
	var poster := K.mesh(root, Vector3(11.3, F + 2.2, zb + 0.03), Vector3(1.0, 0.7, 0.02), Art.material("light"))
	poster.set_instance_shader_parameter("paint", Color(0.55, 0.42, 0.3))
	# Biggie's chalkboard on the west wall: what she's trained, in tally marks.
	var board_at := Vector3(x0 + 0.04, F + 1.7, zf - 1.9)
	K.mesh(root, board_at, Vector3(0.05, 1.1, 1.5), Art.material("wood"))
	K.mesh(root, board_at + Vector3(0.03, 0, 0), Vector3(0.02, 0.96, 1.36), Art.material("canvas", Color(0.12, 0.16, 0.14)))
	var board := Label3D.new()
	board.name = "GymBoard"
	board.position = board_at + Vector3(0.05, 0, 0)
	board.rotation_degrees = Vector3(0, 90, 0)
	board.font_size = 36
	board.pixel_size = 0.0028
	board.modulate = Color(0.92, 0.92, 0.86)
	board.outline_size = 0
	board.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	board.shaded = false
	board.text = Gym.board_text(Gym.fresh())
	root.add_child(board)
	info["gym_board"] = board
	K.interactable(info, "gym_board", board_at + Vector3(0.9, -0.6, 0), "[F] Read Biggie's chalkboard", [
		"He keeps score. Of course he keeps score.",
		"Tally marks. Like a prison wall, but for glutes.",
	], 1.8)
	# Two bare bulbs and a high window.
	for p in [Vector3(7.5, F + 3.0, zb + 2.6), Vector3(11.6, F + 3.0, zb + 3.6)]:
		K.mesh(root, p + Vector3(0, 0.35, 0), Vector3(0.02, 0.7, 0.02), Art.material("gunmetal"))
		K.glow(root, p, Vector3(0.12, 0.16, 0.12), BULB)
		K.light(root, p + Vector3(0, -0.2, 0), BULB, 1.5, 9.0)
	K.glow(root, Vector3(x1 - 0.02, F + 2.7, zb + 3.6), Vector3(0.04, 0.6, 1.6), Color(0.85, 0.92, 1.0))
	K.light(root, Vector3(x1 - 1.2, F + 2.4, zb + 3.6), Color(0.85, 0.9, 1.0), 0.8, 6.0)
	# Each workout's spot.
	for id: String in SPOTS:
		var s: Dictionary = gym[id]
		var at: Vector3 = s["pos"] + _basis(s) * Vector3(0, 0, 0.9 if id in ["crunch", "bridge"] else 0.6)
		var w: Dictionary = Gym.WORKOUTS[id]
		var trains: Array = w["gains"].keys().map(func(p: String) -> String: return p)
		K.interactable(info, "gym_" + id, at, "[F] %s (%s)" % [w["name"], ", ".join(trains)], [], 1.4)
		info["interactables"].back()["workout"] = id


## The frame of a workout spot: Eco faces -Z of it.
static func _basis(spot: Dictionary) -> Basis:
	return Basis(Vector3.UP, deg_to_rad(spot["yaw"]))


static func _local(spot: Dictionary, offset: Vector3) -> Vector3:
	return spot["pos"] + _basis(spot) * offset


## Two uprights welded from old titan strut, J-hooks, safety arms, and the
## loaded bar resting on the hooks.
static func _squat_rack(root: Node3D, spot: Dictionary, F: float) -> void:
	# she walks the bar out: the rack stands in front of her, the hooks just
	# ahead of where she squats
	var b := _basis(spot)
	for side in [-1.0, 1.0]:
		for dz in [-1.25, -0.5]:
			K.metal(root, _local(spot, Vector3(side * 0.62, 1.1, dz)), Vector3(0.08, 2.2, 0.08), Vector3(0, spot["yaw"], 0))
		K.metal(root, _local(spot, Vector3(side * 0.62, 2.18, -0.875)), Vector3(0.08, 0.06, 0.83), Vector3(0, spot["yaw"], 0))
		K.mesh(root, _local(spot, Vector3(side * 0.62, RACK_H - 0.06, -0.45)), Vector3(0.1, 0.04, 0.12), Art.material("gunmetal"), Vector3(0, spot["yaw"], 0))
		K.mesh(root, _local(spot, Vector3(side * 0.62, 0.62, -0.85)), Vector3(0.06, 0.06, 0.8), Art.material("gunmetal"), Vector3(0, spot["yaw"], 0))
	var bar := barbell_model()
	bar.position = _local(spot, Vector3(0, RACK_H, -0.47))
	bar.basis = b
	root.add_child(bar)
	spot["prop"] = bar
	# A plate tree beside it.
	var tree := _local(spot, Vector3(-1.3, 0, -0.2))
	K.metal(root, tree + Vector3(0, 0.55, 0), Vector3(0.08, 1.1, 0.08))
	for i in 3:
		var plate := _disc(0.2 - i * 0.03, 0.05, IRON)
		plate.position = tree + Vector3(0.12, 0.3 + i * 0.3, 0)
		plate.rotation_degrees = Vector3(0, 0, 90)
		root.add_child(plate)


## Two posts and a cross bar at BAR_H, braced to the floor.
static func _pullup(root: Node3D, spot: Dictionary, F: float) -> void:
	for side in [-1.0, 1.0]:
		K.metal(root, _local(spot, Vector3(side * 0.75, BAR_H * 0.5 + 0.05, -0.25)), Vector3(0.09, BAR_H + 0.1, 0.09), Vector3(0, spot["yaw"], 0))
		K.mesh(root, _local(spot, Vector3(side * 0.75, 0.04, -0.25)), Vector3(0.12, 0.08, 1.0), Art.material("gunmetal"), Vector3(0, spot["yaw"], 0))
	var bar := _rod(1.6, 0.017, Color(0.55, 0.55, 0.58))
	bar.position = _local(spot, Vector3(0, BAR_H, -0.25))
	bar.basis = _basis(spot) * Basis(Vector3.BACK, PI / 2)
	root.add_child(bar)


## A heavy bag of patched canvas on a chain from a roof beam.
static func _bag(root: Node3D, spot: Dictionary, F: float) -> void:
	var at := _local(spot, Vector3(0, 0, -0.78))
	var bag := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.2
	cyl.bottom_radius = 0.2
	cyl.height = 1.05
	cyl.material = Art.material("canvas", Color(0.5, 0.3, 0.22))
	bag.mesh = cyl
	bag.position = at + Vector3(0, 1.25, 0)
	root.add_child(bag)
	K.mesh(root, at + Vector3(0, 1.25, 0), Vector3(0.42, 0.1, 0.42), Art.material("canvas", Color(0.75, 0.68, 0.5)))  # a patch of tape
	K.mesh(root, at + Vector3(0, 2.55, 0), Vector3(0.03, 1.6, 0.03), Art.material("gunmetal"))   # chain
	K.mesh(root, at + Vector3(0, 3.42, 0), Vector3(0.18, 0.18, 2.4), Art.material("wood"))      # roof beam
	spot["bag"] = bag


static func _mat(root: Node3D, spot: Dictionary, tint: Color) -> void:
	K.mesh(root, _local(spot, Vector3(0, 0.04, 0.85)), Vector3(0.8, 0.05, 2.0), Art.material("canvas", tint), Vector3(0, spot["yaw"], 0))


## A barbell: a long bar with two iron plates each end. Along X, centred.
static func barbell_model() -> Node3D:
	var n := Node3D.new()
	n.name = "Barbell"
	var rod := _rod(2.0, 0.015, Color(0.62, 0.62, 0.65))
	rod.rotation.z = PI / 2
	n.add_child(rod)
	for side in [-1.0, 1.0]:
		for i in 2:
			var plate := _disc(0.22 - i * 0.05, 0.045, IRON)
			plate.position = Vector3(side * (0.72 + i * 0.05), 0, 0)
			plate.rotation.z = PI / 2
			n.add_child(plate)
	return n


## A short iron dumbbell along X, `size` scaling its bells.
static func dumbbell_model(size := 1.0) -> Node3D:
	var n := Node3D.new()
	var rod := _rod(0.34, 0.013, Color(0.6, 0.6, 0.62))
	rod.rotation.z = PI / 2
	n.add_child(rod)
	for side in [-1.0, 1.0]:
		var bell := _disc(0.055 * size, 0.07, IRON)
		bell.position = Vector3(side * 0.14, 0, 0)
		bell.rotation.z = PI / 2
		n.add_child(bell)
	return n


## A sandbag with handles, along X.
static func sandbag_model() -> Node3D:
	var n := Node3D.new()
	n.name = "Sandbag"
	var bag := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.12
	cap.height = 0.7
	cap.material = Art.material("canvas", Color(0.72, 0.65, 0.45))
	bag.mesh = cap
	bag.rotation.z = PI / 2
	n.add_child(bag)
	for side in [-1.0, 1.0]:
		K.mesh(n, Vector3(side * 0.16, 0.12, 0), Vector3(0.04, 0.03, 0.12), Art.material("canvas", Color(0.3, 0.3, 0.22)))
	return n


static func _rod(length: float, radius: float, tint: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = length
	cyl.radial_segments = 10
	cyl.material = Art.material("gunmetal", tint)
	mi.mesh = cyl
	return mi


static func _disc(radius: float, thick: float, tint: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = thick
	cyl.radial_segments = 16
	cyl.material = Art.material("gunmetal", tint)
	mi.mesh = cyl
	return mi
