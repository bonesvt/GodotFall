extends RefCounted
## The rooms of the three people who live in the temple with Eco, built onto
## the outside of the hall (hub_builder.gd cuts their doors):
## - Mom: a narrow, warm room through the left wall by the kitchen. Quilted
##   bed, rocking chair, sewing table, dried flowers, Dad's photo on the wall.
## - Ophelia: behind the back wall, left of the idol. Black drapes, a
##   mattress on the floor, purple fairy lights, candles, posters, records.
## - Biggie: behind the back wall, right of the idol. An old soldier's den:
##   cot, footlocker, sandbags, a battle map pinned to the wall, a radio, his
##   tea things on the table, a beer cooler and a dartboard.
## Each room has its NPC's stand spot (info["npcs"]) and a "[F] Talk" spot.

const Art := preload("res://scripts/ps2/ps2_assets.gd")
const K := preload("res://scripts/hub/hub_kit.gd")
const Props := preload("res://scripts/hub/hub_props.gd")

## Room doors: half width and height. The hall's floor is at F.
const DOOR_HALF := 1.0
const DOOR_H := 3.0
const F := 1.2
const MOM_DOOR_Z := -12.0
const OPHELIA_DOOR_X := -9.5
const BIGGIE_DOOR_X := 9.5
## Room footprints (x, z, width, depth) on the outside of the hall walls
## (left wall's outer face x = -12.2, back wall's z = -31.2).
const MOM_ROOM := Rect2(-16.0, -16.2, 3.8, 8.4)
const OPHELIA_ROOM := Rect2(-14.6, -38.4, 10.2, 7.2)
const BIGGIE_ROOM := Rect2(4.4, -38.4, 10.2, 7.2)
const ROOM_H := 3.7
const T := 0.3

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


## Floor, foundation, walls (skipping the side against the hall, `open`:
## "east" is the +x side, "south" the +z side) and a roof, in the given tints.
static func _shell(root: Node3D, r: Rect2, open: String, wall_tint: Color, floor_tint: Color, roof_tint := Color(0.7, 0.62, 0.55)) -> void:
	var x0 := r.position.x
	var z0 := r.position.y
	var x1 := r.end.x
	var z1 := r.end.y
	var c := Vector3((x0 + x1) * 0.5, 0, (z0 + z1) * 0.5)
	# Stone footing up to the hall's floor, boards on top.
	K.style = "stone"
	K.stone(root, Vector3(c.x, F * 0.5 - 0.4, c.z), Vector3(r.size.x + 0.4, F + 0.8, r.size.y + 0.4))
	K.style = "timber"
	K.stone(root, Vector3(c.x, F - 0.095, c.z), Vector3(r.size.x, 0.2, r.size.y), Vector3.ZERO, floor_tint)
	var y := F + ROOM_H * 0.5
	if open != "west":
		K.stone(root, Vector3(x0 + T * 0.5, y, c.z), Vector3(T, ROOM_H, r.size.y), Vector3.ZERO, wall_tint)
	if open != "east":
		K.stone(root, Vector3(x1 - T * 0.5, y, c.z), Vector3(T, ROOM_H, r.size.y), Vector3.ZERO, wall_tint)
	if open != "south":
		K.stone(root, Vector3(c.x, y, z1 - T * 0.5), Vector3(r.size.x, ROOM_H, T), Vector3.ZERO, wall_tint)
	else:   # where the room runs past the corner of the hall, close it off
		var hall := 12.2
		if x0 < -hall:
			K.stone(root, Vector3((x0 - hall) * 0.5, y, z1 - T * 0.5), Vector3(-hall - x0, ROOM_H, T), Vector3.ZERO, wall_tint)
		if x1 > hall:
			K.stone(root, Vector3((x1 + hall) * 0.5, y, z1 - T * 0.5), Vector3(x1 - hall, ROOM_H, T), Vector3.ZERO, wall_tint)
	if open != "north":
		K.stone(root, Vector3(c.x, y, z0 + T * 0.5), Vector3(r.size.x, ROOM_H, T), Vector3.ZERO, wall_tint)
	# A plank roof with a lip, and dark posts at the corners outside.
	K.stone(root, Vector3(c.x, F + ROOM_H + 0.15, c.z), Vector3(r.size.x + 0.6, 0.3, r.size.y + 0.6), Vector3.ZERO, roof_tint)
	var dark := Art.material("timber_carving", Color(0.55, 0.48, 0.42))
	for p in [Vector2(x0, z0), Vector2(x1, z0), Vector2(x0, z1), Vector2(x1, z1)]:
		K.mesh(root, Vector3(p.x, F + ROOM_H * 0.5 - 0.3, p.y), Vector3(0.36, ROOM_H + 1.2, 0.36), dark)


static func _npc(info: Dictionary, who: String, name: String, pos: Vector3, yaw: float) -> void:
	info["npcs"].append({"who": who, "pos": pos, "yaw": yaw})
	K.interactable(info, "npc_" + who, pos, "[F] Talk to %s" % name, [], 2.6)
	info["interactables"].back()["npc"] = who


static func _rug(root: Node3D, pos: Vector3, size: Vector2, tint: Color, yaw := 0.0) -> void:
	K.mesh(root, Vector3(pos.x, F + 0.015, pos.z), Vector3(size.x, 0.03, size.y), Art.material("canvas", tint), Vector3(0, yaw, 0))
	K.mesh(root, Vector3(pos.x, F + 0.02, pos.z), Vector3(size.x - 0.3, 0.03, size.y - 0.3), Art.material("canvas", tint.lightened(0.2)), Vector3(0, yaw, 0))


# --- Mom ------------------------------------------------------------------------

## Narrow and warm: through the left wall by the kitchen. Her bed under a
## quilt at the far end, a rocking chair and sewing table, shelves of jars and
## dried flowers, a window, and Dad's photo with a candle under it.
static func _mom(root: Node3D, info: Dictionary) -> void:
	var r := MOM_ROOM
	_shell(root, r, "east", Color(1.05, 0.92, 0.8), Color(0.95, 0.85, 0.75))
	var xw := r.position.x + T          # inside face of her far wall
	var cz := MOM_DOOR_Z
	# Bed against the back (south) end: frame, mattress, a patchwork quilt, pillows.
	var bed := Vector3(xw + 1.1, F, r.end.y - T - 1.15)
	K.wood(root, bed + Vector3(0, 0.2, 0), Vector3(1.6, 0.4, 2.1))
	K.wood(root, bed + Vector3(0, 0.6, 1.0), Vector3(1.6, 1.2, 0.12))
	K.mesh(root, bed + Vector3(0, 0.48, -0.05), Vector3(1.5, 0.18, 1.95), Art.material("canvas", Color(0.95, 0.92, 0.86)))
	var quilt := [Color(0.8, 0.45, 0.35), Color(0.55, 0.65, 0.5), Color(0.9, 0.75, 0.45), Color(0.5, 0.55, 0.7), Color(0.85, 0.6, 0.55)]
	for i in 5:
		K.mesh(root, bed + Vector3(0, 0.6, -0.95 + i * 0.3), Vector3(1.56, 0.07, 0.3), Art.material("canvas", quilt[i]))
	for dx in [-0.38, 0.38]:
		K.mesh(root, bed + Vector3(dx, 0.68, 0.75), Vector3(0.6, 0.16, 0.36), Art.material("canvas", Color(1.0, 0.97, 0.92)))
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

## Dark: behind the back wall, left of the idol. Walls hung with black cloth,
## a mattress on the floor in purple sheets, fairy lights, a cluster of
## candles, posters, a record player with a crate of records, notebooks.
static func _ophelia(root: Node3D, info: Dictionary) -> void:
	var r := OPHELIA_ROOM
	_shell(root, r, "south", Color(0.6, 0.55, 0.62), Color(0.62, 0.56, 0.62), Color(0.5, 0.45, 0.5))
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

## An old soldier's den behind the back wall, right of the idol: a cot,
## footlocker, sandbags under the walls, a campaign map pinned up with string
## between the pins, a field radio glowing on an ammo crate, a cooler of beer
## with empties round it, a dartboard and a hanging bare bulb.
static func _biggie(root: Node3D, info: Dictionary) -> void:
	var r := BIGGIE_ROOM
	_shell(root, r, "south", Color(0.82, 0.8, 0.72), Color(0.8, 0.74, 0.66), Color(0.6, 0.6, 0.55))
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
