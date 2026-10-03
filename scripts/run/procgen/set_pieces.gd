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
##
## place() notes what it put down in the zone's info, when given one:
##   info["set_pieces"]: [{id, pos, yaw}]
##   info["grapple_spots"]: every hook's world position (orange blocks)
##   info["wallruns"]: [{id, from, to, height}] walls made to run along

const F := preload("res://scripts/run/forest_kit.gd")
const Z := preload("res://scripts/run/zone_kit.gd")
const Shapes := preload("res://scripts/run/procgen/prop_shapes.gd")

## Material tints per biome: the same kit reads as the militia's in the
## Pinewoods, swamp-stained in the marsh, rusted and sun-bleached in the Boneyard.
const TINTS := {
	"forest": {"gunmetal": Color(0.86, 0.95, 0.82), "canvas": Color(0.92, 0.95, 0.82)},
	"marsh": {"concrete": Color(0.82, 0.9, 0.78), "gunmetal": Color(0.8, 0.9, 0.78), "canvas": Color(0.8, 0.86, 0.68), "wood": Color(0.8, 0.82, 0.7)},
	"boneyard": {"concrete": Color(1.02, 0.94, 0.86), "gunmetal": Color(1.08, 0.86, 0.72), "canvas": Color(1.0, 0.86, 0.7)},
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
}

static var _scenes := {}


static func has(id: String) -> bool:
	return Shapes.SHAPES.has(id)


static func scene(id: String) -> PackedScene:
	if not _scenes.has(id):
		_scenes[id] = load("res://assets/models/procgen/%s.glb" % id)
	return _scenes[id]


## Footprint (x, z) before turning.
static func size(id: String) -> Vector2:
	return Shapes.SHAPES[id]["size"]


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
	var basis := Basis(Vector3.UP, deg_to_rad(yaw))
	var shape: Dictionary = Shapes.SHAPES[id]
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
		info["grapple_spots"].append_array(hooks)
		if RUNS.has(id):
			var r: Array = RUNS[id]
			info["wallruns"].append({"id": id, "from": pos + basis * (r[0] as Vector3), "to": pos + basis * (r[1] as Vector3), "height": pos.y + r[2]})
	return {"node": node, "hooks": hooks, "tops": tops}


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
