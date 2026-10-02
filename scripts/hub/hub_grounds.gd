extends RefCounted
## The temple grounds: a big grassy clearing around the temple, closed in by a
## ruined boundary wall, a band of jungle and mountains, so you never see the void.
##
##   front (+Z) plaza, then the titan yard: open ground, a drop pad, scrap titan
##              dummies to shoot and titan-sized cover to walk around
##   east (+X)  Eco's camp: tents, a campfire, laundry, a salvage tarp, a pond
##   west (-X)  the shooting range: a firing line and pop-up targets out to 40 m
##   back (-Z)  the movement course: jumps, a wallrun, a climb, a grapple and a
##              long slide back down, timed from the start pad to the finish tower
##
## The temple sits in the middle at the origin (hub_builder.gd). Ground is y = 0.

const K := preload("res://scripts/hub/hub_kit.gd")
const Kit := preload("res://scripts/run/level_kit.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")
const PracticeTarget := preload("res://scripts/hub/practice_target.gd")
const TitanDummy := preload("res://scripts/hub/titan_dummy.gd")
const Ambient := preload("res://scripts/hub/ambient.gd")
const Props := preload("res://scripts/hub/hub_props.gd")

## The boundary wall runs at x = +-WALL_X, z = WALL_BACK and z = WALL_FRONT.
const WALL_X := 72.0
const WALL_BACK := -90.0
const WALL_FRONT := 94.0
const WALL_H := 5.0

const TITAN_PAD := Vector3(0, 0, 54)
## Where the titan can be called in and walked around (x, z, width, depth).
const TITAN_YARD := Rect2(-66.0, 40.0, 132.0, 50.0)
## The titan workshop, at the yard's west edge facing the temple.
const WORKSHOP := Vector3(-16, 0, 47)
## Course start pad and finish tower (centre of the top face, half size).
const COURSE_START := Vector3(-36, 1.5, -50)
const COURSE_FINISH := Vector3(50, 11.0, -50)
const COURSE_PAD_HALF := Vector3(3, 1.5, 3)

## The range's firing line runs along x = RANGE_LINE; targets stand downrange in -X.
const RANGE_LINE := -21.0

const BLUE := Color(0.25, 0.5, 0.9)
const ORANGE := Color(0.95, 0.55, 0.2)
const FIRE := Color(1.0, 0.55, 0.18)
const LAMP := Color(1.0, 0.78, 0.45)
const LEAF_TINTS := [Color(1, 1, 1), Color(0.85, 1.0, 0.8), Color(1.1, 1.05, 0.75), Color(0.75, 0.9, 0.85)]


static func build(root: Node3D, info: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_ground(root)
	_boundary(root, rng)
	_plaza(root)
	_camp(root, info)
	_range(root, info)
	_course(root, info)
	_titan_yard(root, info)
	_greenery(root, rng)
	_birds(root)


# --- ground and boundary ----------------------------------------------------------

static func _ground(root: Node3D) -> void:
	Kit.box(root, Vector3(0, -1.0, 0), Vector3(600, 2.0, 600), K.STONE, Vector3.ZERO, Art.material("grass"))
	var dirt := Art.material("dirt")
	# Worn paths from the plaza to each area, and round the temple to the course.
	for spec in [[Vector3(20, 0.02, 16), Vector3(10, 0.04, 4)], [Vector3(-18, 0.02, 16), Vector3(6, 0.04, 4)],
			[Vector3(0, 0.02, 40), Vector3(5, 0.04, 12)], [Vector3(18, 0.02, -18), Vector3(4, 0.04, 54)],
			[Vector3(-18, 0.02, -18), Vector3(4, 0.04, 54)], [Vector3(-28, 0.02, -44), Vector3(22, 0.04, 4)],
			[Vector3(30, 0.02, -2), Vector3(4, 0.04, 10)]]:
		K.mesh(root, spec[0], spec[1], dirt)


## Ruined boundary wall with crenellations and a blocked gate, jungle crowding in
## behind it, mountains past that, and an invisible fence so you stay inside.
static func _boundary(root: Node3D, rng: RandomNumberGenerator) -> void:
	var tint := Color(0.85, 0.9, 0.82)
	var sides := [
		[Vector3(-WALL_X, 0, WALL_BACK), Vector3(-WALL_X, 0, WALL_FRONT)],
		[Vector3(WALL_X, 0, WALL_BACK), Vector3(WALL_X, 0, WALL_FRONT)],
		[Vector3(-WALL_X, 0, WALL_BACK), Vector3(WALL_X, 0, WALL_BACK)],
		[Vector3(-WALL_X, 0, WALL_FRONT), Vector3(-6, 0, WALL_FRONT)],
		[Vector3(6, 0, WALL_FRONT), Vector3(WALL_X, 0, WALL_FRONT)],
	]
	for side in sides:
		var a: Vector3 = side[0]
		var b: Vector3 = side[1]
		var along := (b - a).normalized()
		var length := a.distance_to(b)
		var segs := int(ceil(length / 10.0))
		var seg_len := length / segs
		var yaw := rad_to_deg(atan2(along.x, along.z))
		for i in segs:
			var c := a + along * (seg_len * (i + 0.5))
			var h := WALL_H - (rng.randf_range(0.0, 1.6) if rng.randf() < 0.35 else 0.0)
			K.stone(root, c + Vector3(0, h * 0.5, 0), Vector3(1.6, h, seg_len + 0.05), Vector3(0, yaw, 0), tint)
			# Merlons along the top.
			if h >= WALL_H - 0.01:
				for m in range(-1, 2):
					K.stone(root, c + along * (m * seg_len / 3.0) + Vector3(0, h + 0.5, 0), Vector3(1.8, 1.0, 1.4), Vector3(0, yaw, 0), tint)
			# Buttresses and the odd carved block.
			if i % 2 == 0:
				var inward := Vector3(-signf(c.x), 0, 0) if absf(c.x) >= WALL_X - 0.1 else Vector3(0, 0, -signf(c.z))
				K.stone(root, c + inward * 1.2 + Vector3(0, 1.6, 0), Vector3(1.6, 3.2, 1.6), Vector3(0, yaw, 0), tint)
			elif rng.randf() < 0.5:
				K.carved(root, c + Vector3(0, 2.4, 0), Vector3(1.7, 1.6, 2.0), Vector3(0, yaw, 0))
			# Vines spilling down the wall.
			if rng.randf() < 0.6:
				var v := c + along * rng.randf_range(-seg_len * 0.4, seg_len * 0.4)
				var vh := rng.randf_range(1.5, 4.0)
				var vine_size := Vector3(1.8, vh, 2.0) if absf(along.z) > 0.5 else Vector3(2.0, vh, 1.8)
				K.mesh(root, v + Vector3(0, h - vh * 0.5, 0), vine_size, Art.material("moss"))
	# The old main gate, choked with rubble and a fallen lintel.
	var gate := Vector3(0, 0, WALL_FRONT)
	for s in [-1.0, 1.0]:
		K.stone(root, gate + Vector3(s * 6.5, 4.5, 0), Vector3(3, 9, 3), Vector3.ZERO, tint)
		K.carved(root, gate + Vector3(s * 6.5, 8.0, 1.55), Vector3(2.6, 1.6, 0.2))
	K.stone(root, gate + Vector3(0, 9.6, 0), Vector3(16, 1.6, 3), Vector3.ZERO, tint)
	K.carved(root, gate + Vector3(0, 9.6, -1.55), Vector3(10, 1.4, 0.2))
	K.stone(root, gate + Vector3(-1.5, 1.4, 0), Vector3(6, 2.8, 3), Vector3(0, 10, 4), tint)
	K.stone(root, gate + Vector3(2.5, 1.0, -0.5), Vector3(4, 2.0, 3), Vector3(0, -20, 0), tint)
	K.stone(root, gate + Vector3(0.5, 3.3, 0.3), Vector3(4, 1.6, 2.4), Vector3(0, 30, 8), tint)
	# Jungle outside the wall, thick enough that you only see trees: one batched
	# draw per tree model.
	var jungle := {}
	for id in Props.TREES:
		jungle[id] = []
	for i in 320:
		var p := Vector3.ZERO
		while true:
			p = Vector3(rng.randf_range(-WALL_X - 34, WALL_X + 34), 0, rng.randf_range(WALL_BACK - 34, WALL_FRONT + 34))
			if absf(p.x) > WALL_X + 2.5 or p.z < WALL_BACK - 2.5 or p.z > WALL_FRONT + 2.5:
				break
		var id: String = Props.TREES[i % Props.TREES.size()]
		var basis := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * rng.randf_range(1.0, 1.6))
		jungle[id].append(Transform3D(basis, p))
	for id in jungle:
		Props.scatter(root, id, jungle[id], LEAF_TINTS[Props.TREES.find(id) % LEAF_TINTS.size()])
	# Forested hills ringing the valley with bare rock at the peaks.
	for i in 18:
		var ang := TAU * i / 18.0 + rng.randf_range(-0.06, 0.06)
		var dist := rng.randf_range(175.0, 215.0)
		var base := Vector3(sin(ang) * dist, -3.0, cos(ang) * dist)
		Props.spawn(root, "hill_a" if i % 2 == 0 else "hill_b", base, rng.randf_range(0, 360), rng.randf_range(0.8, 1.15),
				{"hill_forest": LEAF_TINTS[i % LEAF_TINTS.size()]})
	# Invisible fence a few metres outside the wall.
	for spec in [[Vector3(-WALL_X - 5, 0, 0), Vector3(1, 60, 400)], [Vector3(WALL_X + 5, 0, 0), Vector3(1, 60, 400)],
			[Vector3(0, 0, WALL_BACK - 5), Vector3(400, 60, 1)], [Vector3(0, 0, WALL_FRONT + 5), Vector3(400, 60, 1)]]:
		var fence := StaticBody3D.new()
		var col := CollisionShape3D.new()
		col.shape = BoxShape3D.new()
		col.shape.size = spec[1]
		fence.add_child(col)
		fence.position = spec[0] + Vector3(0, 30, 0)
		root.add_child(fence)


## A modelled jungle tree or palm (hub_props.gd), with a trunk collider if `solid`.
static func tree(root: Node3D, p: Vector3, h: float, rng: RandomNumberGenerator, solid := true) -> void:
	Props.tree(root, p, rng, h / 10.0, solid)


static func bush(root: Node3D, p: Vector3, s: float, rng: RandomNumberGenerator) -> void:
	var id: String = ["bush_a", "bush_b", "fern"][rng.randi() % 3]
	Props.spawn(root, id, p, rng.randf_range(0, 360), s * 0.6, {"leaves": LEAF_TINTS[rng.randi() % LEAF_TINTS.size()]})


# --- the plaza --------------------------------------------------------------------

## Paving in front of the temple, a statue of the god on a plinth, lamp posts.
static func _plaza(root: Node3D) -> void:
	K.stone(root, Vector3(0, -0.45, 22), Vector3(32, 1.0, 26), Vector3.ZERO, Color(0.92, 0.94, 0.88))
	# A small likeness of the god on a plinth in the middle of the plaza.
	K.stone(root, Vector3(0, 0.6, 26), Vector3(3, 1.2, 3))
	var god := Props.spawn(root, "idol", Vector3(0, 1.2, 25.6), 0.0, 0.3)
	K.glow(root, god.transform * Vector3(0, 8.35, 0.1), Vector3(0.32, 0.14, 0.04), Color(0.35, 1.0, 0.85))
	for p in [Vector3(-15, 0, 12), Vector3(15, 0, 12), Vector3(-15, 0, 33), Vector3(15, 0, 33)]:
		_lamp_post(root, p)


static func _lamp_post(root: Node3D, p: Vector3) -> void:
	K.wood(root, p + Vector3(0, 1.5, 0), Vector3(0.25, 3.0, 0.25))
	K.mesh(root, p + Vector3(0.35, 2.9, 0), Vector3(0.8, 0.12, 0.12), Art.material("wood"))
	K.glow(root, p + Vector3(0.7, 2.6, 0), Vector3(0.25, 0.35, 0.25), LAMP)


# --- Eco's camp -------------------------------------------------------------------

static func _camp(root: Node3D, info: Dictionary) -> void:
	_tent(root, Vector3(28, 0, 6), 20.0, Color(1, 1, 1), true)
	_tent(root, Vector3(38, 0, 3), -12.0, Color(0.85, 0.95, 1.0), false)
	_tent(root, Vector3(47, 0, 9), 35.0, Color(1.0, 0.85, 0.75), true)
	_tent(root, Vector3(27, 0, 27), 165.0, Color(0.9, 1.0, 0.85), false)
	_tent(root, Vector3(39, 0, 31), 190.0, Color(1, 1, 1), true)
	# Campfire with a ring of stones, logs to sit on, smoke.
	var fire := Vector3(35, 0, 17)
	for i in 9:
		var a := TAU * i / 9.0
		K.stone(root, fire + Vector3(cos(a) * 1.1, 0.18, sin(a) * 1.1), Vector3(0.45, 0.36, 0.4), Vector3(0, rad_to_deg(a), 0), Color(0.8, 0.8, 0.8))
	K.mesh(root, fire + Vector3(0, 0.25, 0), Vector3(1.4, 0.25, 0.25), Art.material("wood"), Vector3(0, 30, 0))
	K.mesh(root, fire + Vector3(0, 0.3, 0), Vector3(1.4, 0.25, 0.25), Art.material("wood"), Vector3(0, -40, 0))
	K.glow(root, fire + Vector3(0, 0.55, 0), Vector3(0.7, 0.55, 0.7), FIRE, Vector3(0, 20, 0))
	K.glow(root, fire + Vector3(0.05, 0.95, 0), Vector3(0.35, 0.5, 0.35), Color(1.0, 0.85, 0.4), Vector3(0, 60, 0))
	var fire_light := K.light(root, fire + Vector3(0, 1.6, 0), FIRE, 2.2, 12.0)
	_animated(fire_light, Vector3.ZERO, Ambient.Mode.FLICKER, 1.0, 1.0)
	_smoke(root, fire + Vector3(0, 1.2, 0))
	for spec in [[Vector3(-2.6, 0, 0.4), 80.0], [Vector3(2.5, 0, -0.6), 100.0], [Vector3(0.3, 0, 2.6), 10.0], [Vector3(-0.6, 0, -2.6), -15.0]]:
		K.wood(root, fire + spec[0] + Vector3(0, 0.3, 0), Vector3(0.5, 0.5, 2.0), Vector3(0, spec[1], 0))
	K.interactable(info, "campfire", fire + Vector3(0, 0, 3.0), "[F] Sit by the fire", [
		"Dad used to say a titan's just a campfire you can walk around in.",
		"Out here nobody tells me what I'm not allowed to be.",
	], 3.5)
	# Laundry line between two poles, cloth swaying.
	var a := Vector3(30, 0, 12.5)
	var b := Vector3(41, 0, 11.5)
	for p in [a, b]:
		K.wood(root, p + Vector3(0, 1.3, 0), Vector3(0.18, 2.6, 0.18))
	var mid := (a + b) * 0.5
	K.mesh(root, mid + Vector3(0, 2.45, 0), Vector3(a.distance_to(b), 0.04, 0.04), Art.material("gunmetal"), Vector3(0, rad_to_deg(atan2(-(b.z - a.z), b.x - a.x)), 0))
	var cloth_tints := [Color(0.9, 0.4, 0.3), Color(0.35, 0.6, 0.85), Color(0.95, 0.9, 0.8), Color(0.5, 0.7, 0.4)]
	for i in 4:
		var pivot := _animated(root, a.lerp(b, 0.2 + i * 0.2) + Vector3(0, 2.45, 0), Ambient.Mode.SWAY, 9.0, 1.0 + i * 0.13)
		pivot.rotation_degrees.y = rad_to_deg(atan2(-(b.z - a.z), b.x - a.x)) + 90.0
		K.mesh(pivot, Vector3(0, -0.45, 0), Vector3(0.04, 0.9, 0.7), Art.material("fabric", cloth_tints[i]))
	# Salvage tarp: canvas roof on four posts over piles of titan scrap.
	var tarp := Vector3(48, 0, 22)
	for dx in [-3.5, 3.5]:
		for dz in [-2.5, 2.5]:
			K.wood(root, tarp + Vector3(dx, 1.6, dz), Vector3(0.2, 3.2, 0.2))
	K.mesh(root, tarp + Vector3(0, 3.3, 0), Vector3(7.6, 0.08, 5.6), Art.material("canvas"), Vector3(4, 0, 3))
	var armor := Art.material("titan_armor")
	K.metal(root, tarp + Vector3(-1.8, 0.5, -0.8), Vector3(1.6, 1.0, 1.2), Vector3(0, 20, 8))
	K.mesh(root, tarp + Vector3(-1.4, 1.2, -0.6), Vector3(1.2, 0.5, 1.0), armor, Vector3(10, 40, 20))
	K.mesh(root, tarp + Vector3(1.6, 0.4, 0.8), Vector3(2.2, 0.8, 1.4), armor, Vector3(0, -15, 0))
	K.mesh(root, tarp + Vector3(1.2, 1.0, 0.6), Vector3(1.0, 0.4, 0.9), armor, Vector3(0, 30, -10))
	K.wood(root, tarp + Vector3(2.5, 0.45, -1.6), Vector3(0.9, 0.9, 0.9))
	K.wood(root, tarp + Vector3(2.5, 1.3, -1.6), Vector3(0.7, 0.8, 0.7), Vector3(0, 25, 0))
	# A titan foot she dragged back, too big to fit inside.
	K.mesh(root, tarp + Vector3(-1.0, 0.6, 2.0), Vector3(2.4, 1.2, 3.0), armor, Vector3(0, -30, 0))
	K.interactable(info, "salvage", tarp + Vector3(-4.6, 0, 0), "[F] Look at the scrap pile", [
		"Half a titan's worth of plating. The other half is still out there.",
		"Sort by alloy, then by how badly it's on fire.",
	], 3.5)
	# Banners on poles by the tents.
	for spec in [[Vector3(24, 0, 14), Color(0.8, 0.25, 0.2)], [Vector3(44, 0, 15), Color(0.25, 0.6, 0.65)], [Vector3(33, 0, 36), Color(0.85, 0.7, 0.3)]]:
		var p: Vector3 = spec[0]
		K.wood(root, p + Vector3(0, 2.5, 0), Vector3(0.18, 5.0, 0.18))
		var pivot := _animated(root, p + Vector3(0, 4.8, 0), Ambient.Mode.SWAY, 6.0, 0.8)
		K.mesh(pivot, Vector3(0.5, -0.8, 0), Vector3(0.9, 1.6, 0.04), Art.material("fabric", spec[1]))
	# Crates and barrels around the tents.
	for spec in [[Vector3(31, 0, 4), 0.9], [Vector3(32.1, 0, 4.3), 0.7], [Vector3(43, 0, 4), 1.0], [Vector3(24, 0, 24), 0.8], [Vector3(44, 0, 32), 0.9]]:
		var s: float = spec[1]
		K.wood(root, spec[0] + Vector3(0, s * 0.5, 0), Vector3(s, s, s), Vector3(0, spec[0].x * 13.0, 0))
	# Pond with reeds and stepping stones.
	var pond := Vector3(58, 0, 30)
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.25, 0.55, 0.6, 0.75)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.1
	water.metallic_specular = 0.8
	K.mesh(root, pond + Vector3(0, 0.06, 0), Vector3(12, 0.04, 9), water, Vector3(0, 15, 0))
	K.mesh(root, pond + Vector3(0, 0.04, 0), Vector3(13.5, 0.04, 10.5), Art.material("dirt"), Vector3(0, 15, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for i in 14:
		var ang := TAU * i / 14.0
		var p := pond + Vector3(cos(ang) * 6.6, 0, sin(ang) * 5.2)
		if i % 3 == 0:
			for j in 4:
				K.mesh(root, p + Vector3(rng.randf_range(-0.6, 0.6), 0.7, rng.randf_range(-0.6, 0.6)), Vector3(0.08, 1.4 + rng.randf() * 0.6, 0.08), Art.material("moss"), Vector3(rng.randf_range(-8, 8), 0, rng.randf_range(-8, 8)))
		else:
			K.stone(root, p + Vector3(0, 0.2, 0), Vector3(0.9, 0.4, 0.8), Vector3(0, rad_to_deg(ang), 0), Color(0.8, 0.82, 0.8))
	# Dust motes drifting in the sun over the camp.
	_motes(root, Vector3(36, 3, 18), Vector3(16, 3, 16))


## A canvas tent (hub_props.gd), door facing local +Z, with a lantern if `lit`.
static func _tent(root: Node3D, p: Vector3, yaw: float, tint: Color, lit: bool) -> void:
	var pivot := Props.spawn(root, "tent", p, yaw, 1.0, {"canvas": tint}, true)
	if lit:
		K.glow(pivot, Vector3(0.9, 1.5, 2.45), Vector3(0.2, 0.28, 0.2), LAMP)
		K.light(pivot, Vector3(0.9, 1.8, 2.9), LAMP, 0.9, 6.0)


# --- the shooting range -----------------------------------------------------------

## A covered firing line facing -X with pop-up targets at 8 to 40 m and an
## earth bank behind them. A board over the bench counts hits.
static func _range(root: Node3D, info: Dictionary) -> void:
	var line := RANGE_LINE
	K.wood(root, Vector3(line, 0.5, 15), Vector3(1.0, 1.0, 22))
	K.wood(root, Vector3(line + 0.2, 1.05, 15), Vector3(1.4, 0.1, 22.4))
	for z in [4.5, 15.0, 25.5]:
		for dx in [-0.8, 2.2]:
			K.wood(root, Vector3(line + dx, 1.8, z), Vector3(0.2, 3.6, 0.2))
	K.mesh(root, Vector3(line + 0.7, 3.7, 15), Vector3(3.6, 0.08, 22.4), Art.material("canvas", Color(0.85, 0.95, 0.85)), Vector3(0, 0, -6))
	# Sandbags at each end of the bench.
	for z in [3.4, 26.6]:
		for i in 3:
			K.mesh(root, Vector3(line, 0.25 + i * 0.35, z), Vector3(0.9, 0.35, 0.6), Art.material("canvas", Color(0.8, 0.75, 0.6)), Vector3(0, i * 15, 0))
	# Lanes.
	for z in [6.0, 12.0, 18.0, 24.0]:
		K.mesh(root, Vector3(line - 22, 0.03, z), Vector3(42, 0.04, 2.4), Art.material("dirt"))
	# Earth bank and stone wall behind the targets.
	K.mesh(root, Vector3(line - 44, 1.2, 15), Vector3(4, 3.0, 30), Art.material("dirt"), Vector3(0, 0, 20))
	K.stone(root, Vector3(line - 46.5, 3.0, 15), Vector3(1.5, 6.0, 32))
	var score := {"hits": 0, "heads": 0}
	var board := Kit.label(root, Vector3(line + 0.2, 4.4, 15), "", 56)
	board.modulate = Color(1.0, 0.9, 0.6)
	var refresh := func(): board.text = "RANGE    HITS %d    HEADSHOTS %d" % [score["hits"], score["heads"]]
	refresh.call()
	info["range_score"] = score
	info["range_targets"] = []
	for spec in [[8.0, 6.0], [24.0, 6.0], [14.0, 12.0], [34.0, 12.0], [10.0, 18.0], [20.0, 18.0], [40.0, 18.0], [17.0, 24.0], [29.0, 24.0]]:
		var target := PracticeTarget.new()
		target.position = Vector3(line - spec[0], 0, spec[1])
		target.rotation_degrees.y = 90.0  # board faces +X, toward the bench
		root.add_child(target)
		target.hit.connect(func(head: bool):
			score["hits"] += 1
			if head:
				score["heads"] += 1
			refresh.call())
		info["range_targets"].append(target)
	K.interactable(info, "range", Vector3(line + 1.6, 0, 15), "[F] Look at the range", [
		"Dad's pistol pulls high and left without the lock. So I aim low and right.",
		"Breathe out, then squeeze. He said it to me before he ever let me hold it.",
	], 4.0)


# --- the movement course ----------------------------------------------------------

## Behind the temple, heading +X: three rising jumps, a wallrun along panels she
## bolted to an old wall, a double-jump climb, a grapple to the finish tower,
## then a long slide back down. Gaps match the zones (see zone_builder.gd GAPS).
static func _course(root: Node3D, info: Dictionary) -> void:
	var z := COURSE_START.z
	var tint := Color(0.9, 0.92, 0.85)
	# Start pad.
	K.stone(root, Vector3(COURSE_START.x, 0.75, z), Vector3(6, 1.5, 6), Vector3.ZERO, tint)
	K.carved(root, Vector3(COURSE_START.x, 0.75, z + 3.05), Vector3(6, 1.5, 0.1))
	var start_label := Kit.label(root, COURSE_START + Vector3(0, 3.0, 0), "COURSE START", 56)
	start_label.modulate = Color(0.6, 1.0, 0.85)
	# Jumps: 4.5 m gaps, each a little higher.
	var x := COURSE_START.x + 3.0
	var top := 1.5
	for i in 3:
		top += 0.5
		var cx := x + 4.5 + 2.0
		K.stone(root, Vector3(cx, top * 0.5, z), Vector3(4, top, 4), Vector3.ZERO, tint)
		x = cx + 2.0
	# Wallrun: a 16 m gap with a panelled wall alongside.
	var gap := 16.0
	Kit.box(root, Vector3(x + gap * 0.5, top, z - 4.5), Vector3(gap, 9, 1), BLUE)
	K.stone(root, Vector3(x + gap * 0.5, top + 5.0, z - 4.5), Vector3(gap + 1, 1.0, 1.4), Vector3.ZERO, tint)
	var wx := x + gap + 3.0
	top += 0.5
	K.stone(root, Vector3(wx, top * 0.5, z), Vector3(6, top, 6), Vector3.ZERO, tint)
	x = wx + 3.0
	# Climb: blocks rising 2 m each with 2 m gaps.
	for i in 3:
		top += 2.0
		var cx := x + 2.0 + 1.5
		K.stone(root, Vector3(cx, top * 0.5, z), Vector3(3, top, 3), Vector3.ZERO, tint)
		x = cx + 1.5
	# Grapple: an anchor over a 17 m gap to the finish tower.
	var fx := COURSE_FINISH.x
	var anchor := Vector3((x + fx - 3.0) * 0.5 + 1.0, COURSE_FINISH.y + 9.0, z)
	Kit.box(root, anchor, Vector3(4, 2, 4), ORANGE)
	Kit.label(root, anchor + Vector3(0, 2.2, 0), "GRAPPLE", 48)
	K.stone(root, Vector3(fx, COURSE_FINISH.y * 0.5, z), Vector3(6, COURSE_FINISH.y, 6), Vector3.ZERO, tint)
	K.carved(root, Vector3(fx, COURSE_FINISH.y - 1.0, z - 3.05), Vector3(6, 2, 0.1))
	var finish_label := Kit.label(root, COURSE_FINISH + Vector3(0, 3.0, 0), "FINISH", 56)
	finish_label.modulate = Color(1.0, 0.85, 0.4)
	var flag := _animated(root, COURSE_FINISH + Vector3(2.2, 3.0, 2.2), Ambient.Mode.SWAY, 8.0, 1.2)
	K.wood(root, COURSE_FINISH + Vector3(2.2, 1.5, 2.2), Vector3(0.15, 3.0, 0.15))
	K.mesh(flag, Vector3(0.5, -0.4, 0), Vector3(1.0, 0.8, 0.04), Art.material("fabric", Color(0.9, 0.3, 0.2)))
	# The slide back down: a long ramp off the tower's far side.
	var ramp_len := 30.0
	var drop := COURSE_FINISH.y
	var ang := atan2(drop, ramp_len)
	K.stone(root, Vector3(fx, drop * 0.5 - 0.3, z - 3.0 - ramp_len * 0.5), Vector3(5, 0.6, sqrt(ramp_len * ramp_len + drop * drop)), Vector3(-rad_to_deg(ang), 0, 0), tint)
	info["course"] = {"start": COURSE_START, "finish": COURSE_FINISH, "half": COURSE_PAD_HALF}
	K.interactable(info, "course", Vector3(COURSE_START.x, 0, COURSE_START.z + 5.0), "[F] Look at the course", [
		"Jump, wallrun, climb, grapple, slide. Leave the pad and the clock starts.",
		"The army has simulators. I have a temple and a lot of bruises.",
	], 2.8)


# --- the titan yard ---------------------------------------------------------------

## Open packed earth past the plaza: a drop pad to call your titan onto, scrap
## titan dummies to shoot, and titan-sized cover to walk around.
static func _titan_yard(root: Node3D, info: Dictionary) -> void:
	var yard := TITAN_YARD
	K.mesh(root, Vector3(yard.get_center().x, 0.02, yard.get_center().y), Vector3(yard.size.x - 10, 0.04, yard.size.y - 6), Art.material("dirt"))
	# Drop pad: a concrete disc ringed with hazard stripes.
	var pad := Kit.disc(root, TITAN_PAD + Vector3(0, 0.05, 0), 6.0, Color(0.55, 0.55, 0.5, 1.0))
	pad.material_override = Art.MATERIALS["concrete"]
	for i in 16:
		var a := TAU * i / 16.0
		K.mesh(root, TITAN_PAD + Vector3(cos(a) * 6.3, 0.06, sin(a) * 6.3), Vector3(2.2, 0.1, 0.6), Art.MATERIALS["anchor"], Vector3(0, -rad_to_deg(a) + 90.0, 0))
	var yard_sign := Kit.label(root, TITAN_PAD + Vector3(0, 4.0, -7.0), "TITAN YARD", 64)
	yard_sign.modulate = Color(1.0, 0.75, 0.35)
	info["titan_pad"] = TITAN_PAD
	info["titan_yard"] = yard
	# Dummies to shoot.
	info["dummies"] = []
	for p in [Vector3(-26, 0, 80), Vector3(0, 0, 84), Vector3(26, 0, 79), Vector3(48, 0, 66)]:
		var dummy := TitanDummy.new()
		dummy.position = p
		dummy.rotation_degrees.y = rad_to_deg(atan2(p.x - TITAN_PAD.x, p.z - TITAN_PAD.z))
		root.add_child(dummy)
		info["dummies"].append(dummy)
	# Cover and ruins at titan scale.
	var tint := Color(0.88, 0.9, 0.84)
	for spec in [[Vector3(-18, 2.5, 68), Vector3(7, 5, 3), 10.0], [Vector3(17, 2.5, 66), Vector3(6, 5, 3), -15.0],
			[Vector3(38, 2.5, 56), Vector3(3, 5, 7), 5.0], [Vector3(-40, 2.5, 60), Vector3(3, 5, 8), -8.0],
			[Vector3(-50, 4.0, 82), Vector3(4, 8, 4), 0.0], [Vector3(55, 3.0, 86), Vector3(4, 6, 4), 0.0]]:
		K.stone(root, spec[0], spec[1], Vector3(0, spec[2], 0), tint)
	# A toppled colossus head half sunk in the yard.
	K.carved(root, Vector3(-30, 2.0, 46), Vector3(6, 5, 6), Vector3(12, 30, 18), Color(0.7, 0.8, 0.76))
	K.glow(root, Vector3(-27.4, 2.6, 44.0), Vector3(0.12, 1.2, 0.6), Color(0.35, 1.0, 0.85).darkened(0.5), Vector3(12, 30, 18))
	_workshop(root, info)
	K.interactable(info, "titan_yard", TITAN_PAD + Vector3(0, 0, -7.5), "[F] Look at the drop pad", [
		"Call your titan with V. Climb in and out with F.",
		"I painted the pad myself. Dad's titan never needed one; it just fell out of the sky.",
	], 3.0)


## The titan workshop at the yard's west edge (tools/hub/build_benches.py): a
## gantry over a slab where the titan you'd start a run with stands (the run
## manager builds it at workshop_titan), a hanging core, a parts rack and a
## bench. Its screen buys starting parts and refits (bench_screen.gd).
static func _workshop(root: Node3D, info: Dictionary) -> void:
	var w := WORKSHOP
	var model := Props.spawn(root, "titan_workshop", w, 180.0)
	# Slab to stand on (its top is 0.16 m up), gantry legs, bench, rack.
	# (The model is turned to face the temple, so Blender's -Y side, the bench, is at -Z here.)
	for spec in [[Vector3(0, 0.08, 0.6), Vector3(10, 0.16, 7)], [Vector3(-3.8, 3.4, 1.2), Vector3(0.4, 6.8, 2.8)],
			[Vector3(3.8, 3.4, 1.2), Vector3(0.4, 6.8, 2.8)], [Vector3(0.6, 0.5, -2.3), Vector3(2.9, 1.0, 1.1)],
			[Vector3(-4.3, 1.2, -1.8), Vector3(1.5, 2.4, 2.0)], [Vector3(2.4, 0.5, -2.1), Vector3(1.0, 1.0, 0.7)]]:
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		col.shape = BoxShape3D.new()
		col.shape.size = spec[1]
		body.add_child(col)
		body.position = w + spec[0]
		root.add_child(body)
	info["workshop_titan"] = model.find_child("TitanMarker", true, false)
	K.light(root, w + Vector3(0, 6.0, 1.2), LAMP, 2.0, 12.0)
	var sign := Kit.label(root, w + Vector3(0, 7.6, 1.2), "WORKSHOP", 56)
	sign.modulate = Color(1.0, 0.75, 0.35)
	K.interactable(info, "titan_workshop", w + Vector3(0.6, 0.1, -3.6), "[F] Work on the titan (starting parts, refits)", [], 2.6)
	info["interactables"].back()["screen"] = "workshop"


# --- trees, rocks, flowers --------------------------------------------------------

## Trees, bushes and rocks scattered round the open ground, kept off the paths
## and the activity areas.
static func _greenery(root: Node3D, rng: RandomNumberGenerator) -> void:
	var keep_clear := [
		Rect2(-18, -36, 36, 74),   # temple and plaza
		Rect2(-68, -2, 52, 36),    # range
		Rect2(18, -2, 50, 40),     # camp and pond
		Rect2(-44, -82, 104, 40),  # course and slide
		Rect2(-66, 38, 132, 54),   # titan yard
		Rect2(-24, 12, 48, 6),     # paths to the range and camp
		Rect2(14, -46, 10, 56), Rect2(-24, -46, 10, 56),
	]
	var placed := 0
	var tries := 0
	while placed < 70 and tries < 2000:
		tries += 1
		var p := Vector3(rng.randf_range(-WALL_X + 4, WALL_X - 4), 0, rng.randf_range(WALL_BACK + 4, WALL_FRONT - 4))
		var clear := true
		for r in keep_clear:
			if r.grow(2.0).has_point(Vector2(p.x, p.z)):
				clear = false
				break
		if not clear:
			continue
		placed += 1
		match placed % 4:
			0, 1:
				tree(root, p, rng.randf_range(7.0, 13.0), rng)
			2:
				bush(root, p, rng.randf_range(1.2, 2.4), rng)
			3:
				Props.spawn(root, ["rock_a", "rock_b", "rock_c"][rng.randi() % 3], p, rng.randf_range(0, 360), rng.randf_range(0.8, 1.6), {}, true)
	# Trees framing the plaza and the camp.
	for p in [Vector3(-12, 0, 38), Vector3(12, 0, 38), Vector3(-22, 0, 2), Vector3(22, 0, -4), Vector3(52, 0, 4), Vector3(24, 0, 34), Vector3(-26, 0, -30), Vector3(26, 0, -32)]:
		tree(root, p, rng.randf_range(8.0, 11.0), rng)
	# Bushes along the inside of the wall.
	for i in 60:
		var t := rng.randf()
		var p: Vector3
		match i % 4:
			0: p = Vector3(-WALL_X + 2.5, 0, lerpf(WALL_BACK, WALL_FRONT, t))
			1: p = Vector3(WALL_X - 2.5, 0, lerpf(WALL_BACK, WALL_FRONT, t))
			2: p = Vector3(lerpf(-WALL_X, WALL_X, t), 0, WALL_BACK + 2.5)
			_: p = Vector3(lerpf(-WALL_X, WALL_X, t), 0, WALL_FRONT - 2.5)
		bush(root, p, rng.randf_range(1.5, 3.0), rng)
	# Grass tufts and ferns over the open ground, off the paving and paths.
	var paved := [Rect2(-17, -34, 34, 70), Rect2(-24, 14, 48, 4), Rect2(-3, 34, 6, 12),
			Rect2(16, -46, 4, 56), Rect2(-20, -46, 4, 56), Rect2(-40, -46, 24, 4)]
	var grass := []
	var ferns := []
	while grass.size() < 5000:
		var p := Vector3(rng.randf_range(-WALL_X + 1.5, WALL_X - 1.5), 0, rng.randf_range(WALL_BACK + 1.5, WALL_FRONT - 1.5))
		var clear := true
		for r in paved:
			if r.has_point(Vector2(p.x, p.z)):
				clear = false
				break
		if not clear:
			continue
		var basis := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * rng.randf_range(0.8, 1.6))
		if rng.randf() < 0.04:
			ferns.append(Transform3D(basis.scaled(Vector3.ONE * 0.8), p))
		else:
			grass.append(Transform3D(basis, p))
	Props.scatter(root, "grass_tuft", grass)
	Props.scatter(root, "fern", ferns, LEAF_TINTS[1])
	# Flowers.
	var petals := [Color(1.0, 0.85, 0.35), Color(0.95, 0.55, 0.65), Color(0.85, 0.85, 1.0)]
	for i in 90:
		var p := Vector3(rng.randf_range(-WALL_X + 3, WALL_X - 3), 0.2, rng.randf_range(WALL_BACK + 3, WALL_FRONT - 3))
		var clear := true
		for r in keep_clear.slice(0, 1):
			if r.has_point(Vector2(p.x, p.z)):
				clear = false
		if clear:
			var flower := K.mesh(root, p, Vector3(0.22, 0.12, 0.22), Art.material("light"))
			flower.set_instance_shader_parameter("paint", petals[i % petals.size()] * 0.8)


# --- life -------------------------------------------------------------------------

## Birds wheeling high over the temple.
static func _birds(root: Node3D) -> void:
	for spec in [[Vector3(0, 32, -10), 18.0, 0.35], [Vector3(10, 38, 0), 26.0, -0.25], [Vector3(-20, 28, 30), 12.0, 0.5]]:
		var orbit := _animated(root, spec[0], Ambient.Mode.ORBIT, 1.0, spec[2])
		var r: float = spec[1]
		var dark := Art.material("fabric", Color(0.25, 0.22, 0.2))
		K.mesh(orbit, Vector3(r, 0, 0), Vector3(0.25, 0.2, 0.6), dark)
		for s in [-1.0, 1.0]:
			var wing := Node3D.new()
			wing.name = "WingL" if s < 0.0 else "WingR"
			wing.position = Vector3(r + s * 0.12, 0.05, 0)
			orbit.add_child(wing)
			K.mesh(wing, Vector3(s * 0.45, 0, 0), Vector3(0.8, 0.04, 0.35), dark)


## A node running ambient.gd (see its modes), added under `parent` at `pos`.
static func _animated(parent: Node, pos: Vector3, mode: int, amount: float, speed: float) -> Node3D:
	var node: Node3D = Ambient.new()
	node.mode = mode
	node.amount = amount
	node.speed = speed
	node.position = pos
	parent.add_child(node)
	return node


static func _smoke(root: Node3D, p: Vector3) -> void:
	var smoke := CPUParticles3D.new()
	smoke.position = p
	smoke.amount = 14
	smoke.lifetime = 4.0
	var quad := QuadMesh.new()
	quad.size = Vector2(0.7, 0.7)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color(0.75, 0.72, 0.7, 0.35)
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	smoke.mesh = quad
	smoke.direction = Vector3.UP
	smoke.spread = 12.0
	smoke.gravity = Vector3(0.3, 0.6, 0)
	smoke.initial_velocity_min = 0.6
	smoke.initial_velocity_max = 1.0
	smoke.scale_amount_min = 0.6
	smoke.scale_amount_max = 1.4
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.8))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	smoke.color_ramp = fade
	root.add_child(smoke)


static func _motes(root: Node3D, p: Vector3, extents: Vector3) -> void:
	var motes := CPUParticles3D.new()
	motes.position = p
	motes.amount = 40
	motes.lifetime = 6.0
	var quad := QuadMesh.new()
	quad.size = Vector2(0.06, 0.06)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color(1.0, 0.95, 0.7)
	quad.material = mat
	motes.mesh = quad
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	motes.emission_box_extents = extents
	motes.gravity = Vector3.ZERO
	motes.direction = Vector3(1, 0.3, 0)
	motes.spread = 180.0
	motes.initial_velocity_min = 0.1
	motes.initial_velocity_max = 0.3
	root.add_child(motes)
