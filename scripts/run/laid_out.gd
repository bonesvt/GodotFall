extends RefCounted
## Shared pieces for the laid-out zones after the forest (Blackwater and the
## Boneyard): their ground, the path, grunt posts, caches and their guards,
## hiding spots and the invisible fences. Each zone passes its own ground
## height function, a Callable(x, z) -> y.

const Kit := preload("res://scripts/run/level_kit.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")
const F := preload("res://scripts/run/forest_kit.gd")
const Terrain := preload("res://scripts/run/terrain.gd")
const SalvageCache := preload("res://scripts/run/salvage_cache.gd")
const SquadObjective := preload("res://scripts/run/squad_objective.gd")
const GruntScript := preload("res://scripts/grunt.gd")
const ExtractBeacon := preload("res://scripts/run/extract_beacon.gd")


## The dictionary every laid-out zone returns (see ZoneBuilder.build_zone).
static func info(zone_name: String, spawn: Vector3, floor_y: float, kill_y: float) -> Dictionary:
	return {
		"name": zone_name, "spawn": spawn, "platforms": [], "segments": [],
		"caches": [], "objectives": [], "beacon": null, "floor_y": floor_y,
		"kill_y": kill_y, "grunts": [], "checkpoints": [], "routes": [],
		"stealth_cover": [], "tall_grass": [],
	}


## Sky, haze and light, then this zone's own fog and sun on top.
static func environment(root: Node3D, top: Color, horizon: Color, fog_density: float, sun_color: Color, sun_energy: float, sun_pitch := -38.0) -> void:
	Kit.environment(root, top, horizon)
	for node in root.get_children():
		if node is WorldEnvironment:
			var env: Environment = node.environment
			env.fog_density = fog_density
			env.fog_light_color = horizon.lerp(sun_color, 0.25)
			env.volumetric_fog_albedo = env.fog_light_color
		elif node is DirectionalLight3D:
			node.light_color = sun_color
			node.light_energy = sun_energy
			node.rotation_degrees.x = sun_pitch


## Height grid over [x0, x1] x [z0, z1] sampled from `ground`.
static func terrain(root: Node3D, ground: Callable, x_range: Vector2, z_range: Vector2, cell: float,
		top_tint: Color, rock_tint: Color, top_kind := "grass", surface := "grass") -> void:
	var nx := int((x_range.y - x_range.x) / cell) + 1
	var nz := int((z_range.y - z_range.x) / cell) + 1
	var heights := PackedFloat32Array()
	heights.resize(nx * nz)
	for iz in nz:
		var z := z_range.x + iz * cell
		for ix in nx:
			heights[iz * nx + ix] = ground.call(x_range.x + ix * cell, z)
	Terrain.build(root, heights, nx, nz, x_range.x, z_range.x, cell, top_tint, rock_tint, top_kind, surface)


## A flat sheet of water at height `y` over a rectangle (centre x, z; size).
static func water(root: Node3D, center: Vector3, size: Vector2, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.22
	mat.metallic_specular = 0.3
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	plane.material = mat
	mi.mesh = plane
	mi.position = center
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi


## Invisible walls just up the hillsides (`side_x(z)` gives the left and right
## x as a Vector2) and across both ends.
static func fences(root: Node3D, side_x: Callable, z_start: float, z_end: float) -> void:
	var z := z_start
	while z > z_end:
		var z2 := z - 10.0
		var a2: Vector2 = side_x.call(z)
		var b2: Vector2 = side_x.call(z2)
		for k in 2:
			var a := Vector3(a2.x if k == 0 else a2.y, 0, z)
			var b := Vector3(b2.x if k == 0 else b2.y, 0, z2)
			var mid := (a + b) * 0.5
			var yaw := rad_to_deg(atan2(b.x - a.x, b.z - a.z))
			F.solid(root, mid + Vector3(0, 20, 0), Vector3(1, 80, a.distance_to(b) + 1.5), yaw)
		z = z2
	for zz in [z_start, z_end]:
		var s: Vector2 = side_x.call(zz)
		F.solid(root, Vector3((s.x + s.y) * 0.5, 20, zz), Vector3(s.y - s.x + 20.0, 80, 1))


## A strip along `path_x(z)` from z_from to z_to (z_to < z_from), `half` wide,
## draped over `ground`, skipping where `skip(z)` is true. For trails and roads.
static func strip(root: Node3D, ground: Callable, path_x: Callable, z_from: float, z_to: float, half: float,
		material: Material, skip := Callable(), lift := 0.06) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z := z_from
	var any := false
	while z > z_to:
		var z2 := z - 2.0
		if not skip.is_valid() or not (skip.call(z) or skip.call(z2)):
			var quad := []
			for zz in [z, z2]:
				var x: float = path_x.call(zz)
				var wob := 0.3 * sin(zz * 0.3)
				for s in [-1.0, 1.0]:
					var px: float = x + s * (half + wob * s)
					quad.append(Vector3(px, ground.call(px, zz) + lift, zz))
			for i in [0, 2, 1, 1, 2, 3]:
				st.add_vertex(quad[i])
			any = true
		z = z2
	if not any:
		return
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


## A grunt standing at `pos` looking toward `facing`, holding within `leash`.
static func grunt(root: Node3D, info: Dictionary, pos: Vector3, facing: Vector3, zone_index: int, leash := 2.5) -> Node:
	var g := CharacterBody3D.new()
	g.set_script(GruntScript)
	g.leash = leash
	g.sight_range = 35.0 + zone_index * 3.0
	g.damage = 8.0 + zone_index * 2.0
	root.add_child(g)
	g.position = pos + Vector3(0, 0.1, 0)
	g.post = g.position
	g.rotation.y = atan2(-facing.x, -facing.z)
	info["grunts"].append(g)
	return g


static func cache(root: Node3D, info: Dictionary, pos: Vector3) -> Node3D:
	var c := SalvageCache.new()
	root.add_child(c)
	c.position = pos
	info["caches"].append(c)
	return c


## Locks `cache` until every grunt in `squad` is dead.
static func guard(root: Node3D, info: Dictionary, c: Node3D, squad: Array) -> void:
	c.set_locked(true)
	var objective := SquadObjective.new()
	root.add_child(objective)
	objective.position = c.position
	objective.cache = c
	objective.set_squad(squad)
	info["objectives"].append(objective)


static func beacon(root: Node3D, info: Dictionary, pos: Vector3, text := "EXTRACT") -> void:
	var b := ExtractBeacon.new()
	b.text = text
	root.add_child(b)
	b.position = pos
	info["beacon"] = b


## A hiding patch (reeds, dead grass) at (x, z): see forest_kit.grass_patch.
## The clump transforms go on info["tall_grass"] for the zone to batch.
static func hide(root: Node3D, ground: Callable, rng: RandomNumberGenerator, info: Dictionary, x: float, z: float,
		size: Vector2, dense := false, yaw := 0.0) -> void:
	info["tall_grass"].append_array(F.grass_patch(root, ground, Vector2(x, z), size, rng, dense, yaw))


## Collects the zone's stealth_cover areas into info.
static func collect_cover(root: Node3D, info: Dictionary) -> void:
	for area in root.get_children():
		if area is Area3D and area.is_in_group("stealth_cover"):
			info["stealth_cover"].append(area)
