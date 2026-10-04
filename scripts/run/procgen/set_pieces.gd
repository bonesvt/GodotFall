extends RefCounted
## The generated zones' own set pieces: the Blender models in
## assets/models/procgen (tools/procgen/build_props.py) placed with the
## colliders, grapple hooks and standing tops that script wrote alongside them
## (prop_shapes.gd), tinted for the biome they stand in.
##
##   buildings: bunker, blockhouse, garage, warehouse, silo, water_tower,
##     scaffold, ruin_house, ruin_shell, tower_crane
##   movement: billboard_s / _m / _l (wallrun), blast_wall (in rows), kick_slot
##     (wall-jump up between two walls), lean_slab, grapple_mast (+ _short),
##     hook_bracket
##   props: jersey_barrier, tank_trap, tire_stack, cable_reel, jeep,
##     fire_barrel, pipe_stack, supply_pod, warning_sign, sandbag_nest
##   round two (the PC version's ideas, rebuilt in Blender):
##     buildings: cabin, quonset, radio_hut (hook on its mast), blockhouse_low
##     walls: panel_wall, container_wall, hull_wall (12 m, wallrun)
##     climbs: corner_kick (wallrun into a corner, kick, over onto a deck),
##       pillar_ledge (hop a pillar onto a block), scaffold_roost (grapple up
##       onto a deck 7 m up), hook_pole (behind a wall), shield_towers (a
##       chasm's blast shield hung between lattice towers)
##     props: ammo_crates, comms_dish, lamp_post, tarp_shelter, field_table,
##       and each biome's own: lumber_stack, woodpile (forest); rowboat,
##       net_rack, buoy (marsh); rib_arch, hull_plate, engine_block (boneyard)
##
## place() notes what it put down in the zone's info, when given one:
##   info["set_pieces"]: [{id, pos, yaw}]
##   info["grapple_spots"]: every hook's world position (orange blocks)
##   info["wallruns"]: [{id, from, to, height}] walls made to run along
##   info["reward_spots"]: the tops of climbs and towers, where a supply crate
##     waits for whoever gets up there

const F := preload("res://scripts/run/forest_kit.gd")
const Z := preload("res://scripts/run/zone_kit.gd")
const Shapes := preload("res://scripts/run/procgen/prop_shapes.gd")
## The city and military kits (tools/procgen/build_kits.py): models in
## assets/models/city and assets/models/military, same form as Shapes.
const KitShapes := preload("res://scripts/run/procgen/kit_shapes.gd")

## Material tints per biome: the same kit reads as the colony's in the
## Pinewoods, swamp-stained in the marsh, rusted and sun-bleached in the Boneyard.
const TINTS := {
	"forest": {"gunmetal": Color(0.86, 0.95, 0.82), "canvas": Color(0.92, 0.95, 0.82)},
	"marsh": {"concrete": Color(0.82, 0.9, 0.78), "gunmetal": Color(0.8, 0.9, 0.78), "canvas": Color(0.8, 0.86, 0.68), "wood": Color(0.8, 0.82, 0.7)},
	"boneyard": {"concrete": Color(1.02, 0.94, 0.86), "gunmetal": Color(1.08, 0.86, 0.72), "canvas": Color(1.0, 0.86, 0.7)},
	"city": {"concrete": Color(0.8, 0.84, 0.9), "gunmetal": Color(0.86, 0.9, 1.0), "canvas": Color(0.62, 0.66, 0.76), "wood": Color(0.7, 0.66, 0.66)},
	"military": {"concrete": Color(0.94, 0.94, 0.88), "gunmetal": Color(0.9, 0.94, 0.84), "canvas": Color(0.9, 0.9, 0.74)},
}
## Neon colours, by the suffix on a "<part>_<colour>__neon" mesh.
const NEON := {
	"cyan": Color(0.25, 0.95, 1.0), "pink": Color(1.0, 0.3, 0.75), "amber": Color(1.0, 0.68, 0.2),
	"red": Color(1.0, 0.18, 0.15), "green": Color(0.35, 1.0, 0.45), "white": Color(0.92, 0.96, 1.0),
}
## A fire barrel's flames.
const FIRE := Color(1.0, 0.5, 0.15)
## The wall pieces meant to run along: their run, in local x/z, and how high
## their face reaches.
const RUNS := {
	"billboard_s": [Vector3(-3.0, 0, 0), Vector3(3.0, 0, 0), 4.4],
	"billboard_m": [Vector3(-5.0, 0, 0), Vector3(5.0, 0, 0), 5.0],
	"billboard_l": [Vector3(-8.0, 0, 0), Vector3(8.0, 0, 0), 5.6],
	"lean_slab": [Vector3(-4.0, 0, 0), Vector3(4.0, 0, 0), 4.9],
	"kick_slot": [Vector3(0, 0, 6.0), Vector3(0, 0, -6.0), 4.6],
	"ruin_house": [Vector3(4.0, 0, 3.0), Vector3(4.0, 0, -3.0), 6.0],
	"panel_wall": [Vector3(-6.0, 0, 0), Vector3(6.0, 0, 0), 4.4],
	"container_wall": [Vector3(-6.0, 0, 0), Vector3(6.0, 0, 0), 5.2],
	"hull_wall": [Vector3(-6.0, 0, 0), Vector3(6.0, 0, 0), 5.0],
	"corner_kick": [Vector3(3.0, 0, 3.5), Vector3(3.0, 0, -3.0), 3.2],
	"shield_towers": [Vector3(0, 0, 8.0), Vector3(0, 0, -8.0), 6.0],
	# The city and military kits' walls (tools/procgen/build_kits.py).
	"city_holo_wall": [Vector3(-6.4, 0, 0), Vector3(6.4, 0, 0), 5.8],
	"city_security_wall": [Vector3(-5.8, 0, 0), Vector3(5.8, 0, 0), 4.6],
	"mil_hesco_wall": [Vector3(-6.0, 0, 0), Vector3(6.0, 0, 0), 4.5],
	"mil_t_wall": [Vector3(-6.0, 0, 0), Vector3(6.0, 0, 0), 4.8],
}
## Pieces with a supply crate waiting on top.
const REWARDS := ["kick_slot", "corner_kick", "pillar_ledge", "scaffold_roost", "water_tower",
		"city_tower", "city_apartment", "city_monorail", "city_billboard_tower", "mil_guard_tower", "mil_command", "mil_radar"]

static var _scenes := {}


static func has(id: String) -> bool:
	return Shapes.SHAPES.has(id) or KitShapes.SHAPES.has(id)


## A piece's colliders, columns, hooks, tops and footprint.
static func shape_of(id: String) -> Dictionary:
	return Shapes.SHAPES[id] if Shapes.SHAPES.has(id) else KitShapes.SHAPES[id]


static func scene(id: String) -> PackedScene:
	if not _scenes.has(id):
		var dir: String = KitShapes.SHAPES[id]["kit"] if KitShapes.SHAPES.has(id) else "procgen"
		_scenes[id] = load("res://assets/models/%s/%s.glb" % [dir, id])
	return _scenes[id]


## Footprint (x, z) before turning.
static func size(id: String) -> Vector2:
	return shape_of(id)["size"]


## Footprint (x, z) once turned by `yaw` degrees (quarter turns swap the sides).
static func turned_size(id: String, yaw: float) -> Vector2:
	var s := size(id)
	var a := deg_to_rad(yaw)
	return Vector2(absf(cos(a)) * s.x + absf(sin(a)) * s.y, absf(sin(a)) * s.x + absf(cos(a)) * s.y)


## Puts `id` down at `pos` (its origin, on the ground) turned `yaw` degrees.
## Returns {node, hooks, tops} with hooks and tops in world space.
static func place(root: Node3D, id: String, pos: Vector3, yaw := 0.0, info = null, biome := "") -> Dictionary:
	if biome == "":
		biome = root.get_meta("biome", "forest")
	var node := F.place(root, scene(id), pos, yaw, 1.0, TINTS.get(biome, {}), FIRE if id == "fire_barrel" else F.LAMP)
	node.name = id.capitalize().replace(" ", "")
	_light_neon(node)
	var basis := Basis(Vector3.UP, deg_to_rad(yaw))
	var shape: Dictionary = shape_of(id)
	for b in shape["boxes"]:
		F.solid(root, pos + basis * (b[0] as Vector3), b[1], yaw + b[2], Vector3(b[3], 0, 0))
	for c in shape["columns"]:
		Z.column(root, pos + basis * (c[0] as Vector3), c[1], c[2])
	var hooks := []
	for h in shape["hooks"]:
		hooks.append(pos + basis * (h as Vector3))
	var tops := []
	for t in shape["tops"]:
		tops.append(pos + basis * (t as Vector3))
	if info != null:
		if not info.has("set_pieces"):
			info["set_pieces"] = []
			info["grapple_spots"] = []
			info["wallruns"] = []
		info["set_pieces"].append({"id": id, "pos": pos, "yaw": yaw})
		if id in REWARDS and not tops.is_empty():
			if not info.has("reward_spots"):
				info["reward_spots"] = []
			info["reward_spots"].append((tops[0] as Vector3) + Vector3(0, 0.2, 0))
		info["grapple_spots"].append_array(hooks)
		if RUNS.has(id):
			var r: Array = RUNS[id]
			info["wallruns"].append({"id": id, "from": pos + basis * (r[0] as Vector3), "to": pos + basis * (r[1] as Vector3), "height": pos.y + r[2]})
	return {"node": node, "hooks": hooks, "tops": tops}


## Many copies of a piece, one draw per mesh and no colliders: far scenery.
static func scatter(root: Node3D, id: String, transforms: Array, biome := "") -> void:
	if transforms.is_empty():
		return
	var tints: Dictionary = TINTS.get(biome if biome != "" else root.get_meta("biome", "forest"), {})
	var proto: Node3D = scene(id).instantiate()
	for mi in proto.find_children("*", "MeshInstance3D", true, false):
		var kind := F._kind(mi)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mi.mesh
		mm.instance_count = transforms.size()
		for i in transforms.size():
			mm.set_instance_transform(i, transforms[i] * mi.transform)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = F.HubProps.material(kind, tints.get(kind, Color.WHITE))
		if kind == "neon" or kind == "light":
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.set_instance_shader_parameter("paint", _neon_colour(mi) if kind == "neon" else F.LAMP)
		root.add_child(mmi)
	proto.free()


static func _neon_colour(mi: Node) -> Color:
	var part := String(mi.name).split("__")[0]
	return NEON.get(part.get_slice("_", part.get_slice_count("_") - 1), NEON["cyan"])


## Lights every "<part>_<colour>__neon" mesh in its colour.
static func _light_neon(node: Node3D) -> void:
	for mi in node.find_children("*__neon*", "MeshInstance3D", true, false):
		mi.set_instance_shader_parameter("paint", _neon_colour(mi))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A row of blast-wall sections from `a` to `b` (on the ground, y from
## `ground`), facing across the row. Returns how many went up.
static func blast_row(root: Node3D, ground: Callable, a: Vector2, b: Vector2, info = null) -> int:
	var d := b - a
	var n := maxi(1, int(d.length() / 1.6))
	var yaw := rad_to_deg(atan2(-d.y, d.x))
	for k in n:
		var p := a + d * ((k + 0.5) / n)
		var y: float = minf(ground.call(p.x - 0.8, p.y), ground.call(p.x + 0.8, p.y))
		place(root, "blast_wall", Vector3(p.x, y - 0.05, p.y), yaw, null)
	if info != null:
		if not info.has("wallruns"):
			info["set_pieces"] = []
			info["grapple_spots"] = []
			info["wallruns"] = []
		var y0: float = ground.call(a.x, a.y)
		info["set_pieces"].append({"id": "blast_wall", "pos": Vector3(a.x, y0, a.y), "yaw": yaw, "count": n})
		info["wallruns"].append({"id": "blast_wall", "from": Vector3(a.x, y0, a.y), "to": Vector3(b.x, ground.call(b.x, b.y), b.y), "height": y0 + 4.2})
	return n
