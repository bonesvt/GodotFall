extends RefCounted
## The tents of the three people who live with Eco at the temple, pitched on
## raised timber decks round the campfire in the grounds (hub_grounds.gd):
## big canvas wall tents with a pitched roof, a porch under a fly, lanterns
## and guy ropes. Inside:
## - Mom: a narrow, warm tent west of the fire. Quilted bed, rocking chair,
##   sewing table, dried flowers, Dad's photo on the wall.
## - Ophelia: north of the fire, in black canvas. Black drapes, a mattress on
##   the floor, purple fairy lights, candles, posters, records.
## - Biggie: north of the fire, in army olive. An old soldier's den: cot,
##   footlocker, sandbags, a battle map pinned to the wall, a radio, his tea
##   things on the table, a beer cooler and a dartboard.
## Each tent has its NPC's stand spot (info["npcs"]) and a "[F] Talk" spot.

const Art := preload("res://scripts/ps2/ps2_assets.gd")
const FamilyBed := preload("res://scripts/hub/family_bed.gd")
const K := preload("res://scripts/hub/hub_kit.gd")
const Kit := preload("res://scripts/run/level_kit.gd")
const Props := preload("res://scripts/hub/hub_props.gd")

## Tent doors: half width and height. The tents' deck floors are at F (the
## same height as the temple's floor).
const DOOR_HALF := 1.0
const DOOR_H := 3.0
const F := 1.2
## Mom's door is in her tent's east wall, Ophelia's and Biggie's in the south.
const MOM_DOOR_Z := 24.2
const OPHELIA_DOOR_X := 28.1
const BIGGIE_DOOR_X := 43.1
## Tent footprints (x, z, width, depth) in the grounds, round the campfire at (35, 17).
const MOM_ROOM := Rect2(20.0, 20.0, 5.0, 8.4)
const OPHELIA_ROOM := Rect2(23.0, -1.0, 10.2, 7.2)
const BIGGIE_ROOM := Rect2(38.0, -1.0, 10.2, 7.2)
const ROOM_H := 3.7
const T := 0.3
## How far the deck runs past the walls, the porch's depth, the roof's rise.
const DECK := 0.5
const PORCH := 1.8
const RISE := 1.5

const WARM := Color(1.0, 0.72, 0.45)
const CANDLE := Color(1.0, 0.62, 0.3)
const VIOLET := Color(0.62, 0.3, 1.0)
const BULB := Color(1.0, 0.85, 0.6)


static func build(root: Node3D, info: Dictionary) -> void:
	if not info.has("npcs"):
		info["npcs"] = []
	var prev: String = K.style
	_mom(root, info)
	_ophelia(root, info)
	_biggie(root, info)
	K.style = prev


## Where to stand on each porch to walk in, and which way is in.
static func doorstep(who: String) -> Array:
	match who:
		"mom":
			return [Vector3(MOM_ROOM.end.x + DECK + 0.9, F, MOM_DOOR_Z), Vector3(-1, 0, 0)]
		"ophelia":
			return [Vector3(OPHELIA_DOOR_X, F, OPHELIA_ROOM.end.y + DECK + 0.9), Vector3(0, 0, -1)]
	return [Vector3(BIGGIE_DOOR_X, F, BIGGIE_ROOM.end.y + DECK + 0.9), Vector3(0, 0, -1)]


## A tent over r: a timber deck on a solid footing, canvas walls (the door
## in the `door` side, "east" or "south", centred at `at` along it), a
## pitched roof with gable ends, a porch under a fly with steps down to the
## grass, lanterns and guy ropes.
static func _shell(root: Node3D, r: Rect2, door: String, at: float, wall_tint: Color, floor_tint: Color, roof_tint: Color, accent: Color) -> void:
	var x0 := r.position.x
	var z0 := r.position.y
	var x1 := r.end.x
	var z1 := r.end.y
	var c := Vector3((x0 + x1) * 0.5, 0, (z0 + z1) * 0.5)
	var canvas := Art.material("canvas", wall_tint)
	var dark := Art.material("timber_carving", Color(0.55, 0.48, 0.42))
	var east := door == "east"
	var out := Vector3(1, 0, 0) if east else Vector3(0, 0, 1)
	var along := Vector3(0, 0, 1) if east else Vector3(1, 0, 0)
	var door_pt := Vector3(x1, 0, at) if east else Vector3(at, 0, z1)
	# a size in the door's frame: so across the wall, sa along it
	var sz := func(so: float, sy: float, sa: float) -> Vector3:
		return Vector3(so, sy, sa) if east else Vector3(sa, sy, so)
	# Deck: a solid timber footing up to F, boards on top, and the porch.
	K.style = "timber"
	K.wood(root, Vector3(c.x, (F - 0.2) * 0.5, c.z), Vector3(r.size.x + DECK * 2, F - 0.2, r.size.y + DECK * 2))
	K.stone(root, Vector3(c.x, F - 0.1, c.z), Vector3(r.size.x + DECK * 2, 0.2, r.size.y + DECK * 2), Vector3.ZERO, floor_tint)
	var porch := door_pt + out * (DECK + PORCH * 0.5)
	K.wood(root, porch + Vector3(0, (F - 0.2) * 0.5, 0), sz.call(PORCH, F - 0.2, DOOR_HALF * 2 + 2.4))
	K.stone(root, porch + Vector3(0, F - 0.1, 0), sz.call(PORCH, 0.2, DOOR_HALF * 2 + 2.4), Vector3.ZERO, floor_tint)
	# Posts and a dark skirt board round the footing.
	for p: Vector2 in [Vector2(x0 - DECK, z0 - DECK), Vector2(x1 + DECK, z0 - DECK), Vector2(x0 - DECK, z1 + DECK), Vector2(x1 + DECK, z1 + DECK)]:
		K.mesh(root, Vector3(p.x, F * 0.5 - 0.1, p.y), Vector3(0.3, F, 0.3), dark)
	# Steps off the porch: four treads you see, on a hidden ramp you walk.
	var edge := door_pt + out * (DECK + PORCH)
	var run := 2.4
	for i in 4:
		var top := F * (4 - i) / 5.0
		K.mesh(root, edge + out * (0.3 + i * 0.6) + Vector3(0, top - 0.15, 0), sz.call(0.6, 0.3, DOOR_HALF * 2 + 0.6), Art.material("wood"))
	var ramp := StaticBody3D.new()
	var ramp_shape := CollisionShape3D.new()
	ramp_shape.shape = BoxShape3D.new()
	var slope := sqrt(run * run + F * F)
	var tilt := atan2(F, run)
	ramp_shape.shape.size = sz.call(slope, 0.4, DOOR_HALF * 2 + 0.6)
	ramp.add_child(ramp_shape)
	var normal := Vector3(0, cos(tilt), 0) + out * sin(tilt)
	ramp.position = edge + out * (run * 0.5) + Vector3(0, F * 0.5, 0) - normal * 0.2
	ramp.rotation = Vector3(0, 0, -tilt) if east else Vector3(tilt, 0, 0)
	ramp.set_meta("surface", "wood")
	root.add_child(ramp)
	# Canvas walls, thin, on the outer edge; the door side has its opening.
	var y := F + ROOM_H * 0.5
	var th := 0.14
	var wall := func(pos: Vector3, size: Vector3) -> void:
		var body := Kit.box(root, pos, size, K.STONE, Vector3.ZERO, canvas)
		body.set_meta("surface", "wood")
	if east:
		wall.call(Vector3(x0 + th * 0.5, y, c.z), Vector3(th, ROOM_H, r.size.y))
		wall.call(Vector3(c.x, y, z0 + th * 0.5), Vector3(r.size.x, ROOM_H, th))
		wall.call(Vector3(c.x, y, z1 - th * 0.5), Vector3(r.size.x, ROOM_H, th))
		var a := at - DOOR_HALF
		var b := at + DOOR_HALF
		wall.call(Vector3(x1 - th * 0.5, y, (z0 + a) * 0.5), Vector3(th, ROOM_H, a - z0))
		wall.call(Vector3(x1 - th * 0.5, y, (b + z1) * 0.5), Vector3(th, ROOM_H, z1 - b))
		wall.call(Vector3(x1 - th * 0.5, F + DOOR_H + (ROOM_H - DOOR_H) * 0.5, at), Vector3(th, ROOM_H - DOOR_H, DOOR_HALF * 2))
	else:
		wall.call(Vector3(x0 + th * 0.5, y, c.z), Vector3(th, ROOM_H, r.size.y))
		wall.call(Vector3(x1 - th * 0.5, y, c.z), Vector3(th, ROOM_H, r.size.y))
		wall.call(Vector3(c.x, y, z0 + th * 0.5), Vector3(r.size.x, ROOM_H, th))
		var a := at - DOOR_HALF
		var b := at + DOOR_HALF
		wall.call(Vector3((x0 + a) * 0.5, y, z1 - th * 0.5), Vector3(a - x0, ROOM_H, th))
		wall.call(Vector3((b + x1) * 0.5, y, z1 - th * 0.5), Vector3(x1 - b, ROOM_H, th))
		wall.call(Vector3(at, F + DOOR_H + (ROOM_H - DOOR_H) * 0.5, z1 - th * 0.5), Vector3(DOOR_HALF * 2, ROOM_H - DOOR_H, th))
	# Timber frame: corner posts, a post either side of the door, a plate along the top.
	for p: Vector2 in [Vector2(x0, z0), Vector2(x1, z0), Vector2(x0, z1), Vector2(x1, z1)]:
		K.mesh(root, Vector3(p.x, F + ROOM_H * 0.5, p.y), Vector3(0.22, ROOM_H, 0.22), dark)
	for s: float in [-1.0, 1.0]:
		K.mesh(root, door_pt + along * (s * (DOOR_HALF + 0.08)) + out * 0.04 + Vector3(0, F + DOOR_H * 0.5, 0), Vector3(0.16, DOOR_H, 0.16), dark)
	K.mesh(root, door_pt + out * 0.04 + Vector3(0, F + DOOR_H + 0.06, 0), sz.call(0.16, 0.14, DOOR_HALF * 2 + 0.4), dark)
	# The door flaps, rolled and tied back either side.
	for s: float in [-1.0, 1.0]:
		K.mesh(root, door_pt + along * (s * (DOOR_HALF + 0.35)) + out * 0.12 + Vector3(0, F + DOOR_H * 0.55, 0), sz.call(0.12, DOOR_H * 0.9, 0.36), canvas)
		K.mesh(root, door_pt + along * (s * (DOOR_HALF + 0.35)) + out * 0.2 + Vector3(0, F + DOOR_H * 0.5, 0), sz.call(0.04, 0.08, 0.4), Art.material("canvas", accent))
	# Pitched roof: two canvas slopes over the long axis, gable ends, a ridge pole.
	var long_z := r.size.y >= r.size.x
	var short := r.size.x if long_z else r.size.y
	var length := r.size.y if long_z else r.size.x
	var hs := short * 0.5 + 0.35
	var lean := atan2(RISE, hs)
	var span := sqrt(hs * hs + RISE * RISE)
	var roof := Art.material("canvas", roof_tint)
	var top := F + ROOM_H
	for s: float in [-1.0, 1.0]:
		if long_z:
			var body := Kit.box(root, Vector3(c.x + s * hs * 0.5, top + RISE * 0.5 - 0.1, c.z), Vector3(span, 0.08, length + 0.7), K.STONE, Vector3(0, 0, rad_to_deg(-s * lean)), roof)
			body.set_meta("surface", "wood")
		else:
			var body := Kit.box(root, Vector3(c.x, top + RISE * 0.5 - 0.1, c.z + s * hs * 0.5), Vector3(length + 0.7, 0.08, span), K.STONE, Vector3(rad_to_deg(s * lean), 0, 0), roof)
			body.set_meta("surface", "wood")
		# A scalloped valance along each eave, in the accent colour.
		var eave := Vector3(c.x + s * (hs - 0.05), top - 0.25, c.z) if long_z else Vector3(c.x, top - 0.25, c.z + s * (hs - 0.05))
		K.mesh(root, eave, Vector3(0.04, 0.3, length + 0.6) if long_z else Vector3(length + 0.6, 0.3, 0.04), Art.material("canvas", accent))
	for e: float in [-1.0, 1.0]:
		var prism := PrismMesh.new()
		prism.size = Vector3(short, RISE, 0.06)
		prism.material = canvas
		var gable := MeshInstance3D.new()
		gable.mesh = prism
		if long_z:
			gable.position = Vector3(c.x, top + RISE * 0.5, c.z + e * (length * 0.5 - 0.07))
		else:
			gable.position = Vector3(c.x + e * (length * 0.5 - 0.07), top + RISE * 0.5, c.z)
			gable.rotation_degrees.y = 90.0
		root.add_child(gable)
	var ridge := Vector3(c.x, top + RISE - 0.05, c.z)
	K.mesh(root, ridge, Vector3(0.14, 0.14, length + 1.0) if long_z else Vector3(length + 1.0, 0.14, 0.14), dark)
	for e: float in [-1.0, 1.0]:
		var tip := ridge + (Vector3(0, 0, e * (length * 0.5 + 0.5)) if long_z else Vector3(e * (length * 0.5 + 0.5), 0, 0))
		K.mesh(root, tip + Vector3(0, 0.25, 0), Vector3(0.12, 0.5, 0.12), dark)
		K.glow(root, tip + Vector3(0, 0.55, 0), Vector3(0.14, 0.14, 0.14), accent.lightened(0.3), Vector3(0, 45, 0))
	# The fly over the porch: canvas from over the door out to two poles, a
	# lantern hanging from each.
	var fly_h := F + DOOR_H + 0.2
	var pole_at := DECK + PORCH - 0.15
	for s: float in [-1.0, 1.0]:
		var pole := door_pt + out * pole_at + along * (s * (DOOR_HALF + 1.0))
		K.wood(root, pole + Vector3(0, fly_h * 0.5 + 0.4, 0), Vector3(0.14, fly_h - 0.8, 0.14))
		K.mesh(root, pole + Vector3(0, fly_h - 0.55, 0) - out * 0.25, Vector3(0.02, 0.4, 0.02), Art.material("gunmetal"))
		K.glow(root, pole + Vector3(0, fly_h - 0.85, 0) - out * 0.25, Vector3(0.22, 0.3, 0.22), WARM, Vector3(0, 45, 0))
		K.light(root, pole + Vector3(0, fly_h - 1.2, 0) - out * 0.4, WARM, 0.7, 5.5)
	var fly_lean := atan2(0.6, pole_at)
	var fly_len := sqrt(pole_at * pole_at + 0.36)
	var fly_pos := door_pt + out * (pole_at * 0.5) + Vector3(0, fly_h + 0.3, 0)
	K.mesh(root, fly_pos, sz.call(fly_len, 0.06, DOOR_HALF * 2 + 2.4), roof, Vector3(0, 0, rad_to_deg(-fly_lean)) if east else Vector3(rad_to_deg(fly_lean), 0, 0))
	# Guy ropes from the eaves' corners out to stakes in the grass.
	for p: Vector2 in [Vector2(x0, z0), Vector2(x1, z0), Vector2(x0, z1), Vector2(x1, z1)]:
		var corner := Vector3(p.x, top - 0.1, p.y)
		var away := Vector3(p.x - c.x, 0, p.y - c.z).normalized()
		var stake := Vector3(p.x, 0, p.y) + away * 2.4
		if east and p.x > c.x or not east and p.y > c.z:
			continue  # not across the porch
		_rope(root, corner, stake + Vector3(0, 0.25, 0))
		K.mesh(root, stake + Vector3(0, 0.15, 0), Vector3(0.08, 0.3, 0.08), Art.material("wood"))


static func _rope(root: Node3D, a: Vector3, b: Vector3) -> void:
	var seg := K.mesh(root, (a + b) * 0.5, Vector3(0.025, 0.025, a.distance_to(b)), Art.material("canvas", Color(0.85, 0.8, 0.65)))
	seg.look_at_from_position((a + b) * 0.5, b, Vector3.UP)


static func _npc(info: Dictionary, who: String, name: String, pos: Vector3, yaw: float) -> void:
	info["npcs"].append({"who": who, "pos": pos, "yaw": yaw})
	K.interactable(info, "npc_" + who, pos, "[F] Talk to %s" % name, [], 2.6)
	info["interactables"].back()["npc"] = who


static func _rug(root: Node3D, pos: Vector3, size: Vector2, tint: Color, yaw := 0.0) -> void:
	K.mesh(root, Vector3(pos.x, F + 0.015, pos.z), Vector3(size.x, 0.03, size.y), Art.material("canvas", tint), Vector3(0, yaw, 0))
	K.mesh(root, Vector3(pos.x, F + 0.02, pos.z), Vector3(size.x - 0.3, 0.03, size.y - 0.3), Art.material("canvas", tint.lightened(0.2)), Vector3(0, yaw, 0))


# --- Mom ------------------------------------------------------------------------

## Narrow and warm: her tent west of the campfire, door to the east. Her bed under a
## quilt at the far end, a rocking chair and sewing table, shelves of jars and
## dried flowers, a window, and Dad's photo with a candle under it.
static func _mom(root: Node3D, info: Dictionary) -> void:
	var r := MOM_ROOM
	_shell(root, r, "east", MOM_DOOR_Z, Color(0.98, 0.92, 0.8), Color(0.95, 0.85, 0.75), Color(0.9, 0.82, 0.7), Color(0.85, 0.45, 0.35))
	var xw := r.position.x + T          # inside face of her far wall
	var cz := MOM_DOOR_Z
	# Bed against the back (south) end: frame, mattress, a patchwork quilt, pillows.
	var bed := Vector3(xw + 1.1, F, r.end.y - T - 1.15)
	K.wood(root, bed + Vector3(0, 0.2, 0), Vector3(1.6, 0.4, 2.1))
	K.wood(root, bed + Vector3(0, 0.6, 1.0), Vector3(1.6, 1.2, 0.12))
	# Soft mattress, pillows and a patchwork quilt (family_bed.gd).
	FamilyBed.dress(root, bed)
	# Bedside crate with an oil lamp.
	var side := bed + Vector3(1.15, 0, 0.6)
	K.wood(root, side + Vector3(0, 0.3, 0), Vector3(0.5, 0.6, 0.5))
	K.glow(root, side + Vector3(0, 0.75, 0), Vector3(0.14, 0.22, 0.14), WARM)
	K.light(root, side + Vector3(0, 1.3, 0), WARM, 1.0, 5.5)
	# Shelves on the far wall: jars, folded cloth, dried flowers in a bottle.
	for row in 2:
		var sy := F + 1.5 + row * 0.55
		K.wood(root, Vector3(xw + 0.17, sy, cz + 0.2), Vector3(0.34, 0.06, 2.4))
		for i in 6:
			var tint: Color = [Color(0.85, 0.55, 0.3), Color(0.5, 0.65, 0.35), Color(0.9, 0.85, 0.65), Color(0.75, 0.35, 0.3)][(i + row) % 4]
			K.mesh(root, Vector3(xw + 0.17, sy + 0.15, cz - 0.85 + i * 0.4), Vector3(0.18, 0.24 + (i % 2) * 0.06, 0.18), Art.material("canvas", tint))
	for i in 5:
		var f := K.mesh(root, Vector3(xw + 0.25, F + 2.8, cz - 0.6 + i * 0.3), Vector3(0.12, 0.45, 0.12), Art.material("moss", Color(1.0, 0.8, 0.6)))
		f.rotation_degrees = Vector3(0, i * 30, 180)
	# A window in the far wall: warm light through a curtain.
	K.glow(root, Vector3(xw + 0.02, F + 1.9, cz - 2.4), Vector3(0.04, 0.9, 0.8), Color(1.0, 0.85, 0.6))
	for dz in [-0.55, 0.55]:
		K.mesh(root, Vector3(xw + 0.08, F + 1.9, cz - 2.4 + dz), Vector3(0.05, 1.2, 0.35), Art.material("canvas", Color(0.85, 0.7, 0.6)))
	# Rocking chair and sewing table by the door.
	var chair := Vector3(xw + 0.9, F, r.position.y + T + 1.0)
	K.wood(root, chair + Vector3(0, 0.25, 0), Vector3(0.6, 0.08, 0.6))
	K.wood(root, chair + Vector3(-0.28, 0.65, 0), Vector3(0.08, 0.8, 0.6), Vector3(0, 0, -10))
	for dz in [-0.28, 0.28]:
		K.mesh(root, chair + Vector3(0, 0.08, dz), Vector3(0.9, 0.06, 0.06), Art.material("wood"), Vector3(0, 0, 8))
	K.mesh(root, chair + Vector3(0.0, 0.35, 0), Vector3(0.5, 0.08, 0.5), Art.material("canvas", Color(0.8, 0.45, 0.4)))
	K.mesh(root, chair + Vector3(0.05, 0.42, -0.05), Vector3(0.3, 0.12, 0.25), Art.material("canvas", Color(0.55, 0.65, 0.5)))  # knitting
	var table := Vector3(xw + 2.4, F, r.position.y + T + 0.7)
	K.wood(root, table + Vector3(0, 0.38, 0), Vector3(0.9, 0.06, 0.6))
	K.wood(root, table + Vector3(0, 0.18, 0), Vector3(0.7, 0.36, 0.4))
	K.metal(root, table + Vector3(0.1, 0.5, 0), Vector3(0.36, 0.2, 0.18))  # an old sewing machine
	K.mesh(root, table + Vector3(-0.3, 0.44, 0.1), Vector3(0.25, 0.05, 0.25), Art.material("canvas", Color(0.9, 0.55, 0.4)))
	# Dad's photo on the wall by the bed, a candle and a little vase under it.
	var photo := Vector3(xw + 0.03, F + 1.7, bed.z - 1.6)
	K.mesh(root, photo, Vector3(0.04, 0.5, 0.4), Art.material("wood"))
	var pic := K.mesh(root, photo + Vector3(0.025, 0, 0), Vector3(0.02, 0.4, 0.3), Art.material("light"))
	pic.set_instance_shader_parameter("paint", Color(0.5, 0.44, 0.34))
	K.wood(root, photo + Vector3(0.2, -0.75, 0), Vector3(0.4, 0.06, 0.6))
	K.glow(root, photo + Vector3(0.22, -0.62, 0.12), Vector3(0.06, 0.14, 0.06), CANDLE)
	K.light(root, photo + Vector3(0.6, -0.3, 0), CANDLE, 0.5, 3.0)
	_rug(root, Vector3(xw + 1.7, 0, cz - 0.4), Vector2(2.4, 3.0), Color(0.75, 0.42, 0.32))
	Props.spawn(root, "fern", Vector3(xw + 2.9, F + 0.38, r.end.y - T - 0.4), 20.0, 0.3, {"leaves": Color(0.9, 1.05, 0.85)})
	K.mesh(root, Vector3(xw + 2.9, F + 0.2, r.end.y - T - 0.4), Vector3(0.5, 0.4, 0.5), Art.material("wood"))
	K.light(root, Vector3(xw + 1.8, F + 2.9, cz), WARM, 0.9, 7.0)
	_npc(info, "mom", "Mom", Vector3(xw + 1.6, F, cz - 1.2), -90.0)


# --- Ophelia ------------------------------------------------------------------------

## Dark: her tent north of the fire, in black canvas. Walls hung with black cloth,
## a mattress on the floor in purple sheets, fairy lights, a cluster of
## candles, posters, a record player with a crate of records, notebooks.
static func _ophelia(root: Node3D, info: Dictionary) -> void:
	var r := OPHELIA_ROOM
	_shell(root, r, "south", OPHELIA_DOOR_X, Color(0.3, 0.26, 0.34), Color(0.62, 0.56, 0.62), Color(0.24, 0.2, 0.28), Color(0.6, 0.3, 0.85))
	var zb := r.position.y + T       # inside face of the back wall
	var x0 := r.position.x + T
	var x1 := r.end.x - T
	var drape := Art.material("canvas", Color(0.2, 0.16, 0.24))
	# Black drapes hung over the back and side walls, in folds.
	for i in 12:
		var x := x0 + 0.4 + i * 0.8
		K.mesh(root, Vector3(x, F + 1.75, zb + 0.08 + (i % 2) * 0.05), Vector3(0.82, 3.4, 0.06), drape, Vector3(0, (i % 3 - 1) * 4, 0))
	for z in [zb + 1.2, zb + 2.6, zb + 4.0, zb + 5.4]:
		K.mesh(root, Vector3(x0 + 0.08, F + 1.75, z), Vector3(0.06, 3.4, 1.4), drape)
	# Mattress on the floor in the back corner, purple sheets, a heap of pillows.
	var bed := Vector3(x0 + 1.3, F, zb + 1.2)
	K.mesh(root, bed + Vector3(0, 0.12, 0), Vector3(2.0, 0.24, 1.6), Art.material("canvas", Color(0.25, 0.22, 0.26)))
	K.mesh(root, bed + Vector3(0.15, 0.27, 0.05), Vector3(1.6, 0.08, 1.5), Art.material("canvas", Color(0.38, 0.18, 0.5)), Vector3(0, 6, 0))
	K.mesh(root, bed + Vector3(-0.7, 0.33, -0.2), Vector3(0.5, 0.18, 0.7), Art.material("canvas", Color(0.15, 0.12, 0.18)), Vector3(0, -12, 0))
	K.mesh(root, bed + Vector3(-0.6, 0.38, 0.4), Vector3(0.4, 0.16, 0.5), Art.material("canvas", Color(0.6, 0.3, 0.7)), Vector3(0, 20, 8))
	# Fairy lights along the drapes, purple and pink.
	for i in 30:
		var t := i / 29.0
		var p := Vector3(lerpf(x0 + 0.3, x1 - 0.3, t), F + 3.1 - sin(t * PI * 3.0) * 0.35, zb + 0.18)
		K.glow(root, p, Vector3(0.06, 0.08, 0.06), VIOLET if i % 3 else Color(1.0, 0.4, 0.75))
	K.light(root, Vector3(x0 + 2.5, F + 2.6, zb + 1.0), VIOLET, 2.4, 8.0)
	K.light(root, Vector3(x1 - 2.5, F + 2.6, zb + 1.0), VIOLET, 2.2, 8.0)
	# a soft cold fill from the doorway, so she reads against the drapes
	K.light(root, Vector3(x0 + 4.6, F + 2.4, zb + 5.6), Color(0.75, 0.72, 0.95), 1.6, 7.0)
	# A cluster of candles on a low crate and on the floor.
	var c := Vector3(x0 + 3.2, F, zb + 0.6)
	K.wood(root, c + Vector3(0, 0.2, 0), Vector3(0.7, 0.4, 0.5))
	for spec in [[Vector3(-0.2, 0.5, 0), 0.22], [Vector3(0.05, 0.47, 0.1), 0.16], [Vector3(0.22, 0.45, -0.08), 0.12],
			[Vector3(0.6, 0.06, 0.2), 0.14], [Vector3(0.75, 0.05, 0.0), 0.1], [Vector3(-0.6, 0.06, 0.3), 0.18]]:
		var h: float = spec[1]
		K.mesh(root, c + spec[0] + Vector3(0, h * 0.5 - 0.06, 0), Vector3(0.08, h, 0.08), Art.material("canvas", Color(0.92, 0.9, 0.85)))
		K.glow(root, c + spec[0] + Vector3(0, h - 0.02, 0), Vector3(0.03, 0.06, 0.03), CANDLE)
	K.light(root, c + Vector3(0, 0.9, 0.4), CANDLE, 1.4, 5.0)
	# a low glow by her mattress in the back corner, so it separates from the drapes
	K.light(root, bed + Vector3(0.6, 0.7, 0.9), Color(0.8, 0.55, 1.0), 1.2, 4.0)
	# a violet wash over the far corner, so the back of the room isn't black
	K.light(root, Vector3(x1 - 1.0, F + 2.2, zb + 3.0), VIOLET, 1.8, 7.0)
	# Posters on the side wall: band art, all black, white and blood red.
	var posters := [[Color(0.85, 0.85, 0.85), Color(0.6, 0.05, 0.08)], [Color(0.1, 0.1, 0.1), Color(0.9, 0.9, 0.9)], [Color(0.55, 0.1, 0.5), Color(0.05, 0.05, 0.05)]]
	for i in 3:
		var p := Vector3(x1 - 0.03, F + 1.9 + (i % 2) * 0.25, zb + 1.3 + i * 1.5)
		var a := K.mesh(root, p, Vector3(0.02, 1.0, 0.7), Art.material("light"))
		a.set_instance_shader_parameter("paint", posters[i][0] * 0.7)
		var b := K.mesh(root, p + Vector3(-0.012, 0.1, 0), Vector3(0.01, 0.4, 0.4), Art.material("light"))
		b.set_instance_shader_parameter("paint", posters[i][1] * 0.8)
	# Record player on a crate, a crate of records, notebooks on the floor.
	var rp := Vector3(x1 - 0.6, F, zb + 4.6)
	K.wood(root, rp + Vector3(0, 0.3, 0), Vector3(0.6, 0.6, 0.7))
	K.metal(root, rp + Vector3(0, 0.66, 0), Vector3(0.5, 0.12, 0.5))
	K.mesh(root, rp + Vector3(0, 0.73, 0), Vector3(0.36, 0.02, 0.36), Art.material("canvas", Color(0.05, 0.05, 0.06)), Vector3(0, 30, 0))
	K.wood(root, rp + Vector3(0, 0.22, -0.9), Vector3(0.55, 0.44, 0.6))
	for i in 8:
		var rec := K.mesh(root, rp + Vector3(0, 0.5, -1.15 + i * 0.06), Vector3(0.44, 0.44, 0.02), Art.material("canvas", [Color(0.1, 0.1, 0.1), Color(0.45, 0.1, 0.12), Color(0.3, 0.2, 0.45)][i % 3]))
		rec.rotation_degrees.x = -6
	for i in 4:
		K.mesh(root, Vector3(x0 + 2.6 + i * 0.45, F + 0.03 + i * 0.005, zb + 2.7 - (i % 2) * 0.3), Vector3(0.3, 0.03, 0.4), Art.material("canvas", [Color(0.08, 0.08, 0.1), Color(0.7, 0.68, 0.6)][i % 2]), Vector3(0, i * 35, 0))
	# A full-length mirror, covered with a sheet.
	K.mesh(root, Vector3(x1 - 0.4, F + 0.9, zb + 0.4), Vector3(0.6, 1.8, 0.1), Art.material("canvas", Color(0.75, 0.73, 0.75)), Vector3(4, -30, 0))
	_rug(root, Vector3(x0 + 4.4, 0, zb + 3.3), Vector2(3.2, 2.4), Color(0.22, 0.12, 0.28))
	_npc(info, "ophelia", "Ophelia", Vector3(x0 + 4.6, F, zb + 3.4), 180.0)


# --- Biggie -------------------------------------------------------------------------

## An old soldier's den in army olive canvas, north of the fire: a cot,
## footlocker, sandbags under the walls, a campaign map pinned up with string
## between the pins, a field radio glowing on an ammo crate, a cooler of beer
## with empties round it, a dartboard and a hanging bare bulb.
static func _biggie(root: Node3D, info: Dictionary) -> void:
	var r := BIGGIE_ROOM
	_shell(root, r, "south", BIGGIE_DOOR_X, Color(0.6, 0.64, 0.45), Color(0.8, 0.74, 0.66), Color(0.5, 0.55, 0.38), Color(0.8, 0.7, 0.35))
	var zb := r.position.y + T
	var x0 := r.position.x + T
	var x1 := r.end.x - T
	var olive := Art.material("canvas", Color(0.55, 0.6, 0.4))
	# Sandbags stacked along the back wall.
	for row in 2:
		for i in 11:
			var sb := K.mesh(root, Vector3(x0 + 0.45 + i * 0.86 + row * 0.43, F + 0.18 + row * 0.32, zb + 0.35), Vector3(0.8, 0.32, 0.45), Art.material("canvas", Color(0.75, 0.68, 0.5)))
			sb.rotation_degrees.y = (i * 7 + row * 13) % 9 - 4
	# Cot along the right wall, an army blanket, a lumpy pillow.
	var cot := Vector3(x1 - 0.55, F, zb + 3.0)
	for dz in [-0.9, 0.9]:
		for dx in [-0.3, 0.3]:
			K.mesh(root, cot + Vector3(dx, 0.2, dz), Vector3(0.05, 0.4, 0.05), Art.material("gunmetal"))
	K.mesh(root, cot + Vector3(0, 0.42, 0), Vector3(0.75, 0.06, 2.0), olive)
	K.mesh(root, cot + Vector3(0, 0.48, 0.25), Vector3(0.72, 0.06, 1.4), Art.material("fabric", Color(0.4, 0.42, 0.3)), Vector3(0, 2, 0))
	K.mesh(root, cot + Vector3(0, 0.52, -0.75), Vector3(0.5, 0.12, 0.35), Art.material("canvas", Color(0.8, 0.78, 0.7)))
	# Footlocker at the cot's foot, stencilled.
	K.wood(root, cot + Vector3(-0.1, 0.25, 1.45), Vector3(0.9, 0.5, 0.5))
	K.mesh(root, cot + Vector3(-0.1, 0.51, 1.45), Vector3(0.92, 0.03, 0.52), Art.material("canvas", Color(0.5, 0.55, 0.35)))
	# The map wall: a big campaign map, pins and string, photos.
	var mp := Vector3(x0 + 3.2, F + 2.0, zb + 0.03)
	var sheet := K.mesh(root, mp, Vector3(2.6, 1.5, 0.02), Art.material("light"))
	sheet.set_instance_shader_parameter("paint", Color(0.6, 0.55, 0.42))
	for spec in [[Vector3(-0.8, 0.3, 0.02), Color(0.9, 0.15, 0.1)], [Vector3(-0.2, -0.2, 0.02), Color(0.9, 0.15, 0.1)], [Vector3(0.5, 0.35, 0.02), Color(0.2, 0.4, 0.9)],
			[Vector3(0.9, -0.4, 0.02), Color(0.9, 0.15, 0.1)], [Vector3(0.1, 0.5, 0.02), Color(0.95, 0.8, 0.2)]]:
		K.glow(root, mp + spec[0], Vector3(0.05, 0.05, 0.04), spec[1])
	for seg in [[Vector3(-0.8, 0.3, 0.025), Vector3(-0.2, -0.2, 0.025)], [Vector3(-0.2, -0.2, 0.025), Vector3(0.9, -0.4, 0.025)]]:
		var a: Vector3 = mp + seg[0]
		var b: Vector3 = mp + seg[1]
		var s := K.mesh(root, (a + b) * 0.5, Vector3(a.distance_to(b), 0.012, 0.01), Art.material("canvas", Color(0.8, 0.1, 0.1)))
		s.rotation_degrees.z = rad_to_deg(atan2(b.y - a.y, b.x - a.x))
	for i in 3:
		var ph := K.mesh(root, mp + Vector3(1.6 + (i % 2) * 0.3, 0.4 - i * 0.4, 0.0), Vector3(0.24, 0.3, 0.02), Art.material("light"))
		ph.set_instance_shader_parameter("paint", Color(0.5, 0.46, 0.38))
	# Folding table and two ammo-crate seats under the map; the radio on a crate.
	var t := Vector3(x0 + 3.2, F, zb + 1.5)
	K.wood(root, t + Vector3(0, 0.72, 0), Vector3(1.6, 0.06, 0.8))
	for dx in [-0.7, 0.7]:
		K.mesh(root, t + Vector3(dx, 0.36, 0), Vector3(0.05, 0.72, 0.7), Art.material("gunmetal"))
	K.mesh(root, t + Vector3(-0.3, 0.77, 0.1), Vector3(0.5, 0.02, 0.4), Art.material("light"), Vector3(0, 12, 0))  # a field manual
	# His tea things: a clay pot and two cups, one for whoever drops by.
	var pot := t + Vector3(0.42, 0.75, -0.1)
	var clay := Art.material("canvas", Color(0.55, 0.3, 0.18))
	K.mesh(root, pot + Vector3(0, 0.08, 0), Vector3(0.2, 0.15, 0.2), clay, Vector3(0, 45, 0))
	K.mesh(root, pot + Vector3(0, 0.17, 0), Vector3(0.1, 0.03, 0.1), clay, Vector3(0, 45, 0))
	K.mesh(root, pot + Vector3(0.14, 0.11, 0), Vector3(0.12, 0.03, 0.03), clay, Vector3(0, 0, 30))  # spout
	K.mesh(root, pot + Vector3(-0.12, 0.1, 0), Vector3(0.03, 0.1, 0.06), clay)  # handle
	for i in 2:
		K.mesh(root, pot + Vector3(-0.05 + i * 0.16, 0.03, 0.2), Vector3(0.07, 0.06, 0.07), Art.material("canvas", Color(0.85, 0.8, 0.7)))
	for dz in [0.75]:
		K.wood(root, t + Vector3(0.5, 0.25, dz), Vector3(0.6, 0.5, 0.4))
	var radio := Vector3(x0 + 0.8, F, zb + 1.4)
	K.wood(root, radio + Vector3(0, 0.3, 0), Vector3(0.7, 0.6, 0.5))
	K.metal(root, radio + Vector3(0, 0.82, 0), Vector3(0.6, 0.45, 0.35))
	K.glow(root, radio + Vector3(0, 0.88, -0.18), Vector3(0.3, 0.08, 0.02), Color(1.0, 0.65, 0.2))
	K.mesh(root, radio + Vector3(0.22, 1.35, 0.05), Vector3(0.02, 0.7, 0.02), Art.material("gunmetal"), Vector3(0, 0, -12))
	# Beer cooler and empties.
	var cooler := Vector3(x0 + 0.7, F, zb + 3.6)
	K.metal(root, cooler + Vector3(0, 0.25, 0), Vector3(0.6, 0.5, 0.9))
	K.mesh(root, cooler + Vector3(0, 0.52, 0), Vector3(0.62, 0.06, 0.92), Art.material("canvas", Color(0.7, 0.2, 0.15)))
	for i in 7:
		var b := K.mesh(root, cooler + Vector3(0.6 + (i % 3) * 0.22, 0.11 if i < 5 else 0.05, -0.4 + i * 0.16), Vector3(0.08, 0.22, 0.08), Art.material("canvas", Color(0.35, 0.5, 0.25) if i % 2 else Color(0.5, 0.35, 0.15)))
		if i >= 5:
			b.rotation_degrees.z = 90
	# Dartboard on the side wall with three darts in it, and a helmet on a hook.
	var dart := Vector3(x0 + 0.03, F + 1.8, zb + 5.2)
	K.mesh(root, dart, Vector3(0.04, 0.5, 0.5), Art.material("canvas", Color(0.15, 0.15, 0.12)), Vector3(45, 0, 0))
	K.mesh(root, dart + Vector3(0.02, 0, 0), Vector3(0.02, 0.3, 0.3), Art.material("canvas", Color(0.7, 0.15, 0.1)), Vector3(45, 0, 0))
	K.glow(root, dart + Vector3(0.03, 0, 0), Vector3(0.02, 0.06, 0.06), Color(0.9, 0.85, 0.3))
	K.mesh(root, Vector3(x0 + 0.15, F + 1.9, zb + 3.6), Vector3(0.3, 0.2, 0.34), Art.material("canvas", Color(0.45, 0.5, 0.35)))  # helmet
	K.mesh(root, Vector3(x0 + 0.15, F + 1.4, zb + 4.3), Vector3(0.12, 0.9, 0.5), Art.material("canvas", Color(0.4, 0.45, 0.3)))  # a jacket on a nail
	# A bare bulb on a cord.
	var bulb := Vector3(x0 + 3.6, F + 2.9, zb + 3.2)
	K.mesh(root, bulb + Vector3(0, 0.4, 0), Vector3(0.02, 0.8, 0.02), Art.material("gunmetal"))
	K.glow(root, bulb, Vector3(0.12, 0.16, 0.12), BULB)
	K.light(root, bulb + Vector3(0, -0.2, 0), BULB, 1.3, 8.0)
	_rug(root, Vector3(x0 + 3.6, 0, zb + 4.0), Vector2(2.6, 2.0), Color(0.45, 0.35, 0.25), 6.0)
	_npc(info, "biggie", "Biggie", Vector3(x0 + 3.4, F, zb + 3.6), 180.0)
