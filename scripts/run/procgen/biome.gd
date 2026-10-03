extends RefCounted
## How each biome dresses a generated zone (zone_generator.gd): sky, ground,
## trees, cover, the buildings that make up a yard and a rooftop run, and what
## lies across a chasm for the quiet lane. All of it is the handmade zones'
## kit (forest_kit.gd, zone_kit.gd), so generated zones look like they belong
## next to the Pinewoods, Blackwater and the Boneyard.

const Kit := preload("res://scripts/run/level_kit.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")
const F := preload("res://scripts/run/forest_kit.gd")
const Z := preload("res://scripts/run/zone_kit.gd")
const L := preload("res://scripts/run/laid_out.gd")
const Ambience := preload("res://scripts/ambience.gd")

const CONCRETE := Color(0.55, 0.56, 0.55)
const CHAR := Color(0.42, 0.38, 0.36)
## The marsh's water surface.
const WATER_Y := -0.15


static func environment(root: Node3D, biome: String) -> void:
	match biome:
		"marsh":
			L.environment(root, Color(0.3, 0.36, 0.38), Color(0.72, 0.68, 0.54), 0.0085, Color(1.0, 0.76, 0.5), 0.95, -24.0)
			Ambience.start(root, {"swamp_creek": -11.0, "rain": -19.0, "forest_night": -21.0, "wind_soft": -20.0})
		"boneyard":
			L.environment(root, Color(0.34, 0.31, 0.33), Color(0.8, 0.62, 0.48), 0.0065, Color(1.0, 0.7, 0.45), 1.15, -20.0)
			Ambience.start(root, {"wind_soft": -11.0, "forest_wind": -17.0, "radio_static_loop": -32.0})
		_:
			Kit.environment(root, Color(0.3, 0.46, 0.6), Color(0.78, 0.82, 0.7))
			Ambience.start(root, {"forest_day": -10.0, "forest_wind": -17.0, "forest_birds": -19.0})


## [top tint, rock tint, top material, footstep surface] for the terrain.
static func ground_style(biome: String) -> Array:
	match biome:
		"marsh":
			return [Color(0.62, 0.66, 0.42), Color(0.7, 0.68, 0.6), "grass", "grass"]
		"boneyard":
			return [Color(0.6, 0.6, 0.64), Color(0.66, 0.64, 0.64), "dirt", "gravel"]
	return [Color(0.58, 0.72, 0.48), Color(0.8, 0.8, 0.74), "grass", "grass"]


static func road_material(biome: String) -> Material:
	match biome:
		"marsh":
			return Art.material("dirt", Color(0.85, 0.8, 0.7))
		"boneyard":
			return Art.material("dirt", Color(0.58, 0.55, 0.54))
	return Art.material("dirt")


## A tree (or a burnt snag) with a trunk collider.
static func tree(root: Node3D, pos: Vector3, rng: RandomNumberGenerator, scale := 1.0) -> void:
	match biome_of(root):
		"marsh":
			Z.cypress(root, pos - Vector3(0, 0.3, 0), rng, scale)
		"boneyard":
			var s := scale * rng.randf_range(0.85, 1.25)
			F.spawn(root, "snag", pos, rng.randf_range(0, 360), s, {"bark": CHAR})
			Z.column(root, pos, 0.4 * s, 7.0 * s)
		_:
			F.tree(root, pos, rng, scale)


## How thick the trees are between the lanes (0 to 1).
static func tree_density(biome: String) -> float:
	match biome:
		"marsh":
			return 0.42
		"boneyard":
			return 0.14
	return 0.66


## The zone root carries its biome as metadata so dressing helpers can ask.
static func biome_of(root: Node3D) -> String:
	return root.get_meta("biome", "forest")


## Low cover (crouch behind it), about 2 m wide and 1.2 m high.
static func cover_low(root: Node3D, pos: Vector3, yaw: float, rng: RandomNumberGenerator) -> void:
	match biome_of(root):
		"boneyard":
			if rng.randf() < 0.5:
				Z.scrap_pile(root, pos, yaw, Z.HULL_TINTS[rng.randi() % Z.HULL_TINTS.size()])
			else:
				F.sandbags(root, pos, yaw)
		_:
			F.sandbags(root, pos, yaw)


## Tall cover (stand behind it).
static func cover_tall(root: Node3D, pos: Vector3, yaw: float, rng: RandomNumberGenerator) -> void:
	match biome_of(root):
		"boneyard":
			if rng.randf() < 0.5:
				Z.titan_arm(root, pos, yaw, Z.HULL_TINTS[rng.randi() % Z.HULL_TINTS.size()])
			else:
				F.crate_stack(root, pos, yaw)
		_:
			F.crate_stack(root, pos, yaw)


## Cover out in the wilds: a log, a boulder, a wreck.
static func wild_cover(root: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> void:
	var yaw := rng.randf_range(0, 360)
	match biome_of(root):
		"boneyard":
			match rng.randi() % 3:
				0:
					Z.titan_arm(root, pos, yaw, Z.HULL_TINTS[rng.randi() % Z.HULL_TINTS.size()])
				1:
					Z.scrap_pile(root, pos, yaw, Z.HULL_TINTS[rng.randi() % Z.HULL_TINTS.size()])
				_:
					F.rock(root, ["rock_a", "rock_b", "rock_c"][rng.randi() % 3], pos, yaw, rng.randf_range(1.0, 2.2))
		_:
			if rng.randf() < 0.4:
				F.fallen_log(root, pos - Vector3(0, 0.1, 0), yaw)
			else:
				F.rock(root, ["rock_a", "rock_b", "rock_c"][rng.randi() % 3], pos, yaw, rng.randf_range(1.0, 2.4))


## The building a rooftop run is made of, its long side along Z. Returns
## {roof: top centre of its roof, length: along Z, width: along X}.
static func perch(root: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> Dictionary:
	match biome_of(root):
		"marsh":
			# Stilt huts with their posts sunk in: the roof is 3.9 m up.
			var roof := Z.stilt_hut(root, pos - Vector3(0, 1.5, 0), 90.0)
			return {"roof": roof, "length": 6.1, "width": 4.8}
		"boneyard":
			# Two containers stacked: 5.2 m up.
			var tint: Color = Z.CONTAINER_TINTS[rng.randi() % Z.CONTAINER_TINTS.size()]
			var top := Z.container(root, pos, 90.0, tint)
			var roof := Z.container(root, top, 90.0 + rng.randf_range(-3, 3), Z.CONTAINER_TINTS[(rng.randi() + 1) % Z.CONTAINER_TINTS.size()])
			return {"roof": roof, "length": 6.0, "width": 2.4}
	var hut_roof := F.hut(root, pos, 90.0)
	return {"roof": hut_roof, "length": 8.2, "width": 5.2}


## A yard's barracks, broadside to the road (long along X). Returns its footprint size (x, z).
static func barracks(root: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> Vector2:
	match biome_of(root):
		"marsh":
			Z.stilt_hut(root, pos - Vector3(0, 1.5, 0), 0.0)
			return Vector2(6.2, 6.2)
		"boneyard":
			Z.container(root, pos, 0.0, Z.CONTAINER_TINTS[rng.randi() % Z.CONTAINER_TINTS.size()])
			Z.container(root, pos + Vector3(0, 0, 3.0), 0.0, Z.CONTAINER_TINTS[(rng.randi() + 2) % Z.CONTAINER_TINTS.size()])
			return Vector2(6.0, 5.6)
	F.hut(root, pos, 0.0)
	return Vector2(8.2, 5.2)


## A camp's big building. Returns its footprint size (x, z).
static func centrepiece(root: Node3D, pos: Vector3) -> Vector2:
	match biome_of(root):
		"marsh":
			Z.pump_house(root, pos, 90.0)
			return Vector2(11.0, 19.0)
		"boneyard":
			Z.salvage_shed(root, pos, 0.0)
			return Vector2(12.4, 8.4)
	F.sawmill(root, pos, 0.0)
	return Vector2(12.4, 8.4)


## Clutter round a yard: something to hide behind that fits in about 3 x 3 m.
static func yard_clutter(root: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> void:
	var yaw := rng.randf_range(0, 360)
	var pick := rng.randi() % 5
	match pick:
		0:
			F.barrels(root, pos, yaw)
		1:
			F.pallet(root, pos, yaw)
		2:
			F.generator(root, pos, yaw)
		3:
			if biome_of(root) == "forest":
				F.log_pile(root, pos, yaw)
			elif biome_of(root) == "boneyard":
				Z.scrap_pile(root, pos, yaw, Z.HULL_TINTS[rng.randi() % Z.HULL_TINTS.size()])
			else:
				F.barrels(root, pos, yaw)
		_:
			F.crate_stack(root, pos, yaw)


## The big piece in a yard's far corner: a fuel tank, a storage tank, a gantry.
static func landmark(root: Node3D, pos: Vector3) -> Vector2:
	match biome_of(root):
		"marsh":
			Z.storage_tank(root, pos)
			return Vector2(7.4, 7.4)
		"boneyard":
			Z.titan_kneeling(root, pos, 180.0, Z.HULL_TINTS[1])
			return Vector2(8.0, 6.0)
	F.fuel_tank(root, pos, 0.0)
	return Vector2(6.2, 2.8)


## Lies across a chasm along Z for the quiet lane, its walkable top at `top`
## (the lip's height). `z` is the chasm's middle.
static func quiet_crossing(root: Node3D, x: float, top: float, z: float) -> void:
	match biome_of(root):
		"marsh":
			Z.titan_fallen(root, Vector3(x, top + 0.3, z), 90.0, Z.HULL_TINTS[0])
		"boneyard":
			Z.obelisk_fallen(root, Vector3(x, top + 0.3, z), 90.0)
		_:
			F.log_bridge(root, Vector3(x, top - 0.3, z), 90.0)


## Water at the bottom of a chasm, `width` across X.
static func chasm_floor(root: Node3D, center: Vector3, size: Vector2) -> void:
	if biome_of(root) == "boneyard":
		return
	L.water(root, center, size, Color(0.2, 0.42, 0.45, 0.95) if biome_of(root) == "forest" else Color(0.09, 0.12, 0.08, 0.95))


## A wreck to mine for alloy: a titan lying along Z. Returns its footprint (x, z).
static func wreck(root: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> Vector2:
	var tint: Color = Z.HULL_TINTS[rng.randi() % Z.HULL_TINTS.size()]
	if rng.randf() < 0.5:
		Z.titan_fallen(root, pos + Vector3(0, 3.4, 0), 90.0 + rng.randf_range(-12, 12), tint)
		return Vector2(7.0, 26.0)
	Z.titan_kneeling(root, pos, rng.randf_range(0, 360), tint)
	Z.titan_arm(root, pos + Vector3(5.5, 0, 4.0), rng.randf_range(0, 360), tint)
	return Vector2(12.0, 12.0)


## A hiding patch (tall grass, reeds, dead grass); see forest_kit.grass_patch.
static func hide(root: Node3D, ground: Callable, rng: RandomNumberGenerator, info: Dictionary, x: float, z: float,
		size: Vector2, dense := false, yaw := 0.0) -> void:
	L.hide(root, ground, rng, info, x, z, size, dense, yaw)


## Batches everything the zone gathered into info["tall_grass"].
static func finish_grass(root: Node3D, info: Dictionary, grass: Array) -> void:
	match biome_of(root):
		"marsh":
			Z.scatter(root, "reeds", info["tall_grass"], {"grass_blade": Color(0.72, 0.74, 0.5), "bark": Color(0.6, 0.45, 0.35)}, false)
			F.scatter(root, "grass_tuft", grass, {"grass_blade": Color(0.74, 0.74, 0.5)}, false)
		"boneyard":
			F.scatter(root, "tall_grass", info["tall_grass"], {"grass_blade": Color(0.9, 0.78, 0.52)}, false)
			F.scatter(root, "grass_tuft", grass, {"grass_blade": Color(0.82, 0.74, 0.55)}, false)
		_:
			F.scatter(root, "tall_grass", info["tall_grass"], {"grass_blade": Color(0.75, 0.8, 0.55)}, false)
			F.scatter(root, "grass_tuft", grass, {"grass_blade": Color(0.68, 0.8, 0.58)}, false)
	info["tall_grass"] = []


## Trees beyond the hillsides (no collision) and hills on the horizon.
static func far_scenery(root: Node3D, rng: RandomNumberGenerator, plan, ground: Callable) -> void:
	var biome: String = plan.biome
	var ids: Array
	var tints := {}
	match biome:
		"marsh":
			ids = ["cypress_a", "cypress_b", "cypress_dead"]
			tints = {"leaves": Z.CYPRESS_TINTS[0], "grass_blade": Z.MOSS_BEARD}
		"boneyard":
			ids = ["snag", "snag", "pine_a"]
			tints = {"bark": CHAR, "leaves": F.NEEDLE_TINTS[0]}
		_:
			ids = ["pine_a", "pine_b", "pine_c", "tree_a", "snag"]
			tints = {"leaves": F.NEEDLE_TINTS[0]}
	var far := {}
	for id in ids:
		far[id] = []
	var z: float = plan.z_top + 40.0
	while z > plan.z_bottom - 40.0:
		for side in [-1.0, 1.0]:
			var w: float = plan.half_width(z)
			var d := w + 5.0
			while d < w + 70.0:
				var px: float = plan.center_x(z) + side * (d + rng.randf_range(-2.0, 2.0))
				var pz := z + rng.randf_range(-2.5, 2.5)
				var id: String = ids[rng.randi() % ids.size()]
				var basis := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * rng.randf_range(1.0, 1.6))
				far[id].append(Transform3D(basis, Vector3(px, ground.call(px, pz) - 0.3, pz)))
				d += rng.randf_range(4.5, 7.5) * (2.2 if biome == "boneyard" else 1.0)
		z -= 5.0
	# Across both ends of the valley too.
	for band in [[plan.z_top - 6.0, plan.z_top + 40.0], [plan.z_bottom - 40.0, plan.z_bottom + 6.0]]:
		for i in 260:
			var pz := rng.randf_range(band[0], band[1])
			var px: float = plan.center_x(pz) + rng.randf_range(-plan.half_width(pz) - 20.0, plan.half_width(pz) + 20.0)
			var id: String = ids[i % ids.size()]
			far[id].append(Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * rng.randf_range(1.0, 1.5)), Vector3(px, ground.call(px, pz) - 0.3, pz)))
	for id in far:
		Z.scatter(root, id, far[id], tints)
	var mid: float = (plan.z_top + plan.z_bottom) * 0.5
	var reach: float = (plan.z_top - plan.z_bottom) * 0.5 + 120.0
	for i in 16:
		var ang := TAU * i / 16.0
		var base := Vector3(sin(ang) * 240.0, -6.0, mid + cos(ang) * reach)
		F.spawn(root, "hill_a" if i % 2 == 0 else "hill_b", base, rng.randf_range(0, 360), rng.randf_range(1.0, 1.4),
				{"hill_forest": Color(0.7, 0.85, 0.75) if biome != "boneyard" else Color(0.7, 0.62, 0.58)})
