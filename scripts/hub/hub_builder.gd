extends RefCounted
## Builds the hub: the small abandoned temple Eco uses as her secret base.
##
## A lost civilization built it for their precursor god, a seated stone figure
## with one great eye at the back of the hall. The roof has fallen in over the
## nave, so a shaft of sun lands on the idol. Eco has moved in: her bedroll and
## lantern by the door, a workbench where she keeps her father's broken smart
## pistol, the wreck of his titan slumped in the right aisle, and a map table
## in the nave where runs start. A gallery along the left wall (reached up the
## rubble and a fallen pillar) gives room to climb. Outside, the grounds
## (hub_grounds.gd) have her camp, a shooting range, a movement course and a
## titan yard, all walled in by ruins, trees and mountains.
##
## The hall runs along -Z from the door: you spawn inside the door looking down
## the nave at the idol.

const Kit := preload("res://scripts/run/level_kit.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")
const K := preload("res://scripts/hub/hub_kit.gd")
const Grounds := preload("res://scripts/hub/hub_grounds.gd")
const Props := preload("res://scripts/hub/hub_props.gd")
const Ambience := preload("res://scripts/ambience.gd")

## Floor height inside the temple (top of its plinth).
const F := 1.2
## Inner half width of the hall, wall height, and the hall's far (back) and near (door) ends.
const HALF := 11.0
const WALL_H := 9.0
const WALL_T := 1.2
const BACK_Z := -30.0
const FRONT_Z := 7.4
const DOOR_HALF := 2.5
const DOOR_H := 6.0
## The hole in the roof over the nave.
const HOLE := Rect2(-4.0, -26.0, 8.0, 14.0)
const GALLERY_H := 4.5
## The fallen pillar drum that ramps from the nave floor up to the gallery's edge.
const RAMP_FROM := Vector3(-4.6, F, -6.5)
const RAMP_TO := Vector3(-HALF + 3.1, F + GALLERY_H + 0.05, -12.5)

const SKY_TOP := Color(0.28, 0.5, 0.72)
const SKY_HORIZON := Color(0.78, 0.84, 0.86)
const EYE := Color(0.35, 1.0, 0.85)
const FIRE := Color(1.0, 0.55, 0.18)
const LAMP := Color(1.0, 0.78, 0.45)
## The idol is carved from a darker, cooler stone than the temple.
const IDOL := Color(0.5, 0.64, 0.6)
## Her benches are old, oiled timber, darker than the crates.
const BENCH_WOOD := Color(0.72, 0.6, 0.52)


## Returns {spawn, floor_y, interactables, map_table, eco_spot, half_size}.
## Each interactable is {id, pos, range, prompt, lines}; "map_table" is the one that
## starts a run (no lines). eco_spot is a Marker3D by her workbench for her model.
static func build(root: Node3D) -> Dictionary:
	Kit.environment(root, SKY_TOP, SKY_HORIZON)
	Ambience.start(root, {"temple_interior": -15.0, "temple_drips": -20.0, "wind_soft": -20.0, "forest_birds": -24.0})
	# Darker ambient than the zones, so the roofed hall falls into shadow and
	# the sun shaft, fire bowls and lamps carry the light.
	for node in root.get_children():
		if node is WorldEnvironment:
			node.environment.ambient_light_energy = 0.3
			node.environment.fog_density = 0.0028
			node.environment.fog_light_color = Color(0.7, 0.8, 0.84)
			node.environment.fog_aerial_perspective = 0.35
			node.environment.adjustment_saturation = 1.1
		elif node is DirectionalLight3D:
			node.rotation_degrees = Vector3(-62, 20, 0)
			node.light_energy = 1.35
			node.directional_shadow_max_distance = 90.0
			node.shadow_opacity = 1.0
	var info := {
		"spawn": Vector3(0, F + 0.1, 4.5),
		"floor_y": 0.0,
		"interactables": [],
		"half_size": Grounds.WALL_X,
	}
	_plinth(root)
	Grounds.build(root, info)
	_shell(root)
	_pillars(root)
	_gallery(root)
	_idol(root, info)
	_eco_corner(root, info)
	_workbench(root, info)
	_suit_locker(root, info)
	_fathers_titan(root, info)
	_map_table(root, info)
	_overgrowth(root)
	return info


# --- the site -------------------------------------------------------------------

## The plinth the temple stands on, its front steps, the broken colonnade in
## front of it and the ledge outside the breach. The grounds around it are
## hub_grounds.gd.
static func _plinth(root: Node3D) -> void:
	K.stone(root, Vector3(0, F * 0.5 - 1.0, (BACK_Z - WALL_T + FRONT_Z + WALL_T) * 0.5), Vector3(HALF * 2 + WALL_T * 2 + 1, F + 2.0, FRONT_Z - BACK_Z + WALL_T * 2))
	var yard_z := FRONT_Z + WALL_T
	# Front steps up to the door. You walk up them on a hidden ramp.
	for i in 3:
		var step_top := F * (i + 1) / 3.0
		K.mesh(root, Vector3(0, step_top - 0.3, yard_z + 0.4 + (2 - i) * 0.8), Vector3(9 - i, 0.6, 0.8), Art.material("temple_stone"))
	var ramp := StaticBody3D.new()
	var ramp_shape := CollisionShape3D.new()
	ramp_shape.shape = BoxShape3D.new()
	ramp_shape.shape.size = Vector3(9, 0.4, sqrt(2.4 * 2.4 + F * F))
	ramp.add_child(ramp_shape)
	ramp.position = Vector3(0, F * 0.5 - 0.2, yard_z + 1.2)
	ramp.rotation = Vector3(atan2(F, 2.4), 0, 0)
	root.add_child(ramp)
	# Broken colonnade lining the courtyard.
	for x in [-13.0, 13.0]:
		for z in [12.0, 19.0, 26.0]:
			var h: float = 6.0 if int(z + x) % 3 == 0 else 2.6 + absf(x) * 0.05 + z * 0.04
			K.stone(root, Vector3(x, h * 0.5, z), Vector3(1.4, h, 1.4))
	# A toppled drum by the courtyard edge.
	K.stone(root, Vector3(-8, 0.7, 26.5), Vector3(1.4, 1.4, 4.0), Vector3(0, 30, 0))
	# Ledge outside the breach in the right wall, with rubble steps down to the grass.
	K.stone(root, Vector3(HALF + 4.0, F - 0.8, -17.5), Vector3(6, 1.6, 9))
	K.stone(root, Vector3(HALF + 7.6, 0.2, -17.5), Vector3(1.6, 0.8, 7))


## Walls, door, broken roof.
static func _shell(root: Node3D) -> void:
	var y := F + WALL_H * 0.5
	var length := FRONT_Z - BACK_Z
	var mid_z := (FRONT_Z + BACK_Z) * 0.5
	var x_out := HALF + WALL_T * 0.5
	# Left wall, whole.
	K.stone(root, Vector3(-x_out, y, mid_z), Vector3(WALL_T, WALL_H, length + WALL_T * 2))
	# Right wall with a breach onto the lookout ledge.
	var breach := Vector2(-21.0, -15.0)
	K.stone(root, Vector3(x_out, y, (BACK_Z - WALL_T + breach.x) * 0.5), Vector3(WALL_T, WALL_H, breach.x - BACK_Z + WALL_T))
	K.stone(root, Vector3(x_out, y, (breach.y + FRONT_Z + WALL_T) * 0.5), Vector3(WALL_T, WALL_H, FRONT_Z + WALL_T - breach.y))
	K.stone(root, Vector3(x_out, F + 0.6, breach.x + 1.0), Vector3(WALL_T, 1.2, 2.0), Vector3(0, 0, 8))
	K.stone(root, Vector3(x_out, F + WALL_H - 1.5, (breach.x + breach.y) * 0.5), Vector3(WALL_T, 3.0, breach.y - breach.x))
	# Rubble spilled from the breach.
	K.stone(root, Vector3(HALF - 1.2, F + 0.4, -19.8), Vector3(1.6, 0.8, 1.4), Vector3(0, 25, 10))
	K.stone(root, Vector3(HALF - 2.4, F + 0.3, -16.0), Vector3(1.0, 0.6, 1.2), Vector3(0, -15, 0))
	# Back wall, with a carved frieze behind the idol.
	K.stone(root, Vector3(0, y, BACK_Z - WALL_T * 0.5), Vector3(HALF * 2 + WALL_T * 2, WALL_H, WALL_T))
	K.carved(root, Vector3(0, F + 7.0, BACK_Z + 0.05), Vector3(HALF * 2, 2.0, 0.2))
	# Front wall around the door, and the lintel.
	var side_w := HALF + WALL_T - DOOR_HALF
	for s in [-1.0, 1.0]:
		K.stone(root, Vector3(s * (DOOR_HALF + side_w * 0.5), y, FRONT_Z + WALL_T * 0.5), Vector3(side_w, WALL_H, WALL_T))
	K.carved(root, Vector3(0, F + DOOR_H + (WALL_H - DOOR_H) * 0.5, FRONT_Z + WALL_T * 0.5), Vector3(DOOR_HALF * 2, WALL_H - DOOR_H, WALL_T))
	# Carved friezes running down both long walls.
	for s in [-1.0, 1.0]:
		K.carved(root, Vector3(s * (HALF - 0.05), F + 7.0, mid_z), Vector3(0.2, 2.0, length))
	# Roof, open over the nave where it fell in.
	var roof_y := F + WALL_H + 0.5
	var full_w := HALF * 2 + WALL_T * 2
	var hole_front := HOLE.position.y + HOLE.size.y
	K.stone(root, Vector3(0, roof_y, (hole_front + FRONT_Z + WALL_T) * 0.5), Vector3(full_w, 1.0, FRONT_Z + WALL_T - hole_front))
	K.stone(root, Vector3(0, roof_y, (BACK_Z - WALL_T + HOLE.position.y) * 0.5), Vector3(full_w, 1.0, HOLE.position.y - BACK_Z + WALL_T))
	var strip_w := HALF + WALL_T + HOLE.position.x
	for s in [-1.0, 1.0]:
		K.stone(root, Vector3(s * (HALF + WALL_T - strip_w * 0.5), roof_y, HOLE.get_center().y), Vector3(strip_w, 1.0, HOLE.size.y))
	# What fell in: slabs leaning and lying under the hole.
	K.stone(root, Vector3(-2.2, F + 0.9, -14.0), Vector3(3.5, 0.7, 2.5), Vector3(18, 20, 0))
	K.stone(root, Vector3(2.8, F + 0.35, -20.0), Vector3(2.5, 0.7, 3.0), Vector3(0, -30, 0))
	K.stone(root, Vector3(1.0, F + 0.25, -17.5), Vector3(1.0, 0.5, 1.2), Vector3(0, 40, 0))
	# Bounce light so the aisles under the roof aren't black.
	K.light(root, Vector3(0, F + 3.0, -18.0), Color(1.0, 0.85, 0.6), 1.0, 14.0)
	_facade(root)


## The outside: a stepped crest over the door with the god's eye in it, a shrine
## tower over the idol, and a carved cornice, so the temple reads from the courtyard.
static func _facade(root: Node3D) -> void:
	var top := F + WALL_H + 1.0
	var front := FRONT_Z + WALL_T * 0.5
	for i in 3:
		K.stone(root, Vector3(0, top + 0.6 + i * 1.2, front), Vector3(14.0 - i * 4.5, 1.2, WALL_T + 0.4 - i * 0.2))
	K.carved(root, Vector3(0, top + 1.8, front + 0.35), Vector3(5.0, 1.6, 0.3))
	K.glow(root, Vector3(0, top + 1.8, front + 0.52), Vector3(0.7, 0.3, 0.04), EYE)
	# Shrine tower over the idol, stepped in twice.
	for i in 2:
		K.stone(root, Vector3(0, top + 1.5 + i * 3.0, BACK_Z + 2.0), Vector3(14.0 - i * 5.0, 3.0, 8.0 - i * 3.0))
	K.carved(root, Vector3(0, top + 1.5, BACK_Z + 6.05), Vector3(14.0, 1.6, 0.2))
	# Cornice: a carved band around the outside of the walls.
	var length := FRONT_Z - BACK_Z + WALL_T * 2
	for s in [-1.0, 1.0]:
		K.carved(root, Vector3(s * (HALF + WALL_T + 0.1), top - 1.6, (FRONT_Z + BACK_Z) * 0.5), Vector3(0.3, 1.4, length))
		K.carved(root, Vector3(s * (HALF * 0.5 + 2.0), top - 1.6, FRONT_Z + WALL_T + 0.1), Vector3(HALF - 1.5, 1.4, 0.3))


## Two rows of pillars down the hall. One on the left has broken and fallen
## across the aisle, which makes a ramp up to the gallery.
static func _pillars(root: Node3D) -> void:
	for x in [-6.0, 6.0]:
		for z in [3.0, -3.0, -9.0, -15.0, -21.0]:
			if x < 0.0 and z == -9.0:
				# Snapped off near the base; its capital rolled into the nave.
				K.stone(root, Vector3(x, F + 0.5, z), Vector3(1.6, 1.0, 1.6))
				K.carved(root, Vector3(x + 2.0, F + 0.5, z - 1.8), Vector3(2.1, 1.0, 2.1), Vector3(0, 25, 8))
				continue
			K.stone(root, Vector3(x, F + 0.3, z), Vector3(2.1, 0.6, 2.1))
			K.stone(root, Vector3(x, F + WALL_H * 0.5, z), Vector3(1.6, WALL_H, 1.6))
			K.carved(root, Vector3(x, F + WALL_H - 0.5, z), Vector3(2.1, 1.0, 2.1))


## A ledge along the left wall, 4.5 m up. The fallen drum of the broken pillar
## ramps up to it from the nave, and a rubble stack by the door is a double-jump
## climb. Eco keeps her stash and a lookout slit up here.
static func _gallery(root: Node3D) -> void:
	var y := F + GALLERY_H
	K.stone(root, Vector3(-HALF + 1.6, y - 0.3, -13.5), Vector3(3.2, 0.6, 23.0))
	# Corbels under the ledge.
	for z in [-22.0, -16.0, -10.0, -4.0]:
		K.stone(root, Vector3(-HALF + 0.6, y - 1.1, z), Vector3(1.2, 1.0, 1.0))
	# The fallen pillar drum, from the nave floor up onto the ledge.
	var from := RAMP_FROM
	var to := RAMP_TO
	var mid := (from + to) * 0.5
	var run := Vector2(to.x - from.x, to.z - from.z)
	var slope := rad_to_deg(atan2(to.y - from.y, run.length()))
	var yaw := rad_to_deg(atan2(-run.x, -run.y))
	K.stone(root, mid + Vector3(0, -0.5, 0), Vector3(1.6, 1.0, (to - from).length() + 0.6), Vector3(slope, yaw, 0))
	# Rubble steps in front of the ledge's near end: 0.9, 1.9, 2.9 m, then a double jump up.
	K.stone(root, Vector3(-HALF + 2.0, F + 0.45, 3.0), Vector3(1.8, 0.9, 1.8), Vector3(0, 10, 0))
	K.stone(root, Vector3(-HALF + 1.4, F + 0.95, 1.2), Vector3(1.6, 1.9, 1.6), Vector3(0, -8, 0))
	K.wood(root, Vector3(-HALF + 1.6, F + 2.9 - 0.6, -0.6), Vector3(1.2, 1.2, 1.2), Vector3(0, 20, 0))
	K.stone(root, Vector3(-HALF + 1.6, F + 1.1, -0.6), Vector3(1.4, 1.1, 1.4))
	# Her stash up top: crates of sorted scrap and a coil of cable.
	K.wood(root, Vector3(-HALF + 0.9, y + 0.5, -18.0), Vector3(1.2, 1.0, 1.2))
	K.wood(root, Vector3(-HALF + 0.9, y + 0.4, -19.4), Vector3(1.0, 0.8, 1.0), Vector3(0, 15, 0))
	K.metal(root, Vector3(-HALF + 0.9, y + 1.25, -18.0), Vector3(0.6, 0.5, 0.9), Vector3(0, 30, 0))
	K.metal(root, Vector3(-HALF + 2.2, y + 0.15, -20.5), Vector3(0.8, 0.3, 0.8))


# --- the god --------------------------------------------------------------------

## The precursor god: a seated stone figure on a stepped dais, hands open on its
## knees, with one great eye still glowing in its brow.
static func _idol(root: Node3D, info: Dictionary) -> void:
	var z0 := BACK_Z
	K.stone(root, Vector3(0, F + 0.25, z0 + 4.0), Vector3(14, 0.5, 8))
	K.stone(root, Vector3(0, F + 0.75, z0 + 3.0), Vector3(11, 0.5, 6))
	# The seated god (modelled in Blender, hub_props.gd), facing the door.
	var statue := Props.spawn(root, "idol", Vector3(0, F + 1.0, z0 + 4.4), 0.0, 0.75)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	col.shape = BoxShape3D.new()
	col.shape.size = Vector3(7.8, 8.0, 5.0)
	col.position = Vector3(0, 4.0, -2.0)
	body.add_child(col)
	statue.add_child(body)
	# The eye: a bright core in the dark socket on its brow.
	var marker := statue.find_child("EyeMarker", true, false) as Node3D
	var eye := statue.transform * (marker.transform.origin if marker else Vector3(0, 8.35, 0.04))
	K.glow(root, eye + Vector3(0, 0, 0.02), Vector3(1.0, 0.45, 0.06), EYE)
	K.light(root, eye + Vector3(0, 0, 1.5), EYE, 0.9, 7.0)
	# Glowing channels down the front of the dais.
	for x in [-4.2, -2.1, 2.1, 4.2]:
		K.glow(root, Vector3(x, F + 0.5, z0 + 6.02), Vector3(0.1, 0.4, 0.04), EYE.darkened(0.3))
	# Fire bowls either side of the dais.
	for s in [-1.0, 1.0]:
		var bowl := Vector3(s * 5.4, F + 0.5, z0 + 7.6)
		K.stone(root, bowl + Vector3(0, 0.5, 0), Vector3(0.8, 1.0, 0.8))
		K.stone(root, bowl + Vector3(0, 1.15, 0), Vector3(1.4, 0.3, 1.4), Vector3(0, 45, 0))
		K.glow(root, bowl + Vector3(0, 1.55, 0), Vector3(0.7, 0.5, 0.7), FIRE, Vector3(0, 20, 0))
		K.glow(root, bowl + Vector3(0, 1.9, 0), Vector3(0.35, 0.4, 0.35), Color(1.0, 0.85, 0.4), Vector3(0, 60, 0))
		K.light(root, bowl + Vector3(0, 2.2, 0), FIRE, 1.8, 9.0)
	K.interactable(info, "idol", Vector3(0, F + 1.0, z0 + 8.0), "[F] Look at the idol", [
		"Whoever built this place prayed to something with one big eye.",
		"The eye still glows. No wiring, no power cell. I checked.",
		"Some nights I swear it's watching the scrap pile.",
	], 3.5)


# --- Eco's things ---------------------------------------------------------------

## Left of the door: her bedroll, a lantern, and the pilot program's rejection
## letter pinned to the wall.
static func _eco_corner(root: Node3D, info: Dictionary) -> void:
	var c := Vector3(-HALF + 2.5, F, 5.2)
	K.mesh(root, c + Vector3(0, 0.12, 0), Vector3(2.2, 0.24, 1.1), Art.material("fabric", Color(0.75, 0.55, 0.5)))
	K.mesh(root, c + Vector3(-0.85, 0.3, 0), Vector3(0.5, 0.2, 0.8), Art.material("fabric", Color(0.9, 0.85, 0.75)))
	K.wood(root, c + Vector3(1.8, 0.35, -0.2), Vector3(0.8, 0.7, 0.8))
	# Lantern on the crate.
	K.metal(root, c + Vector3(1.8, 0.75, -0.2), Vector3(0.3, 0.1, 0.3))
	K.glow(root, c + Vector3(1.8, 0.95, -0.2), Vector3(0.2, 0.3, 0.2), LAMP)
	K.light(root, c + Vector3(1.8, 1.4, -0.2), LAMP, 1.2, 7.0)
	# The letter on the wall above the bed.
	var letter := K.mesh(root, Vector3(c.x - 1.4, F + 1.8, FRONT_Z - 0.05), Vector3(0.6, 0.8, 0.04), Art.material("light"))
	letter.set_instance_shader_parameter("paint", Color(0.55, 0.5, 0.42))
	K.glow(root, Vector3(c.x - 1.4, F + 1.95, FRONT_Z - 0.08), Vector3(0.4, 0.08, 0.02), Color(0.7, 0.15, 0.1))
	K.interactable(info, "bedroll", c + Vector3(0.4, 0.1, 0), "[F] Look at your bedroll", [
		"Nobody knows I'm out here. That's the whole point.",
	], 2.5)
	K.interactable(info, "letter", Vector3(c.x - 1.4, F + 0.1, FRONT_Z - 1.4), "[F] Read the letter", [
		"MILITIA PILOT PROGRAM: APPLICATION DENIED.",
		"'Insufficient combat aptitude.' They never even let me take the test.",
		"Fine. I'll build my own titan.",
	], 2.2)


## Right of the door: her gunsmith bench (tools/hub/build_benches.py), where
## the gun in her hand lies on the mat (the run manager puts it there), and
## the weapon rack on the wall beside it. Both open workbench screens
## (bench_screen.gd). eco_spot marks where she stands at the bench.
static func _workbench(root: Node3D, info: Dictionary) -> void:
	var b := Vector3(HALF - 0.72, F, 1.0)
	var bench := Props.spawn(root, "gunsmith_bench", b, -90.0, 1.0, {"wood": BENCH_WOOD})
	_solid(root, b + Vector3(0, 0.5, 0), Vector3(1.25, 1.0, 3.45))
	info["gun_marker"] = bench.find_child("GunMarker", true, false)
	var lamp: Node3D = bench.find_child("LampMarker", true, false)
	K.light(root, lamp.global_position if lamp.is_inside_tree() else b + Vector3(-0.02, 1.95, -0.8), LAMP, 1.4, 6.0)
	var spot := Marker3D.new()
	spot.name = "EcoSpot"
	spot.position = b + Vector3(-1.4, 0.0, 0.6)
	spot.rotation_degrees = Vector3(0, -90, 0)
	root.add_child(spot)
	info["eco_spot"] = spot
	K.interactable(info, "gunsmith", b + Vector3(-1.3, 0.1, 0), "[F] Work on your gun (upgrades, attachments)", [], 2.5)
	info["interactables"].back()["screen"] = "gunsmith"
	# The rack on the wall past the bench, toward the battery bank.
	var r := Vector3(HALF - 0.08, F, -3.4)
	var rack := Props.spawn(root, "weapon_rack", r, -90.0, 1.0, {"wood": BENCH_WOOD})
	_solid(root, r + Vector3(-0.3, 0.35, 0), Vector3(0.6, 0.7, 2.6))
	info["rack_slots"] = []
	for i in 3:
		info["rack_slots"].append(rack.find_child("Slot%dMarker" % i, true, false))
	K.light(root, r + Vector3(-1.2, 2.6, 0), LAMP, 0.9, 4.5)
	K.interactable(info, "weapon_rack", r + Vector3(-1.5, 0.1, 0), "[F] Pick a sidearm", [], 2.3)
	info["interactables"].back()["screen"] = "rack"


## On the left wall, past the rubble: the scavenged armour locker where Eco
## upgrades her suit (bench_screen.gd "suit").
static func _suit_locker(root: Node3D, info: Dictionary) -> void:
	var l := Vector3(-HALF + 0.42, F, -3.6)
	K.metal(root, l + Vector3(0, 1.05, 0), Vector3(0.62, 2.1, 1.3))
	# two doors, one hanging open on a broken hinge, and the glow of a charge strip
	K.metal(root, l + Vector3(0.33, 1.05, 0.33), Vector3(0.05, 1.9, 0.6))
	K.metal(root, l + Vector3(0.62, 1.05, -0.62), Vector3(0.05, 1.9, 0.6), Vector3(0, 55, 0))
	K.glow(root, l + Vector3(0.32, 1.95, -0.3), Vector3(0.02, 0.05, 0.5), Color(0.0, 0.8, 0.75))
	K.wood(root, l + Vector3(0.75, 0.25, 0.9), Vector3(0.5, 0.5, 0.5), Vector3(0, 18, 0))
	K.light(root, l + Vector3(1.2, 2.4, 0), LAMP, 0.9, 4.5)
	K.interactable(info, "suit_locker", l + Vector3(1.3, 0.1, 0), "[F] Upgrade your suit (armour, passives)", [], 2.4)
	info["interactables"].back()["screen"] = "suit"


## An invisible box collider (for modelled props).
static func _solid(root: Node3D, center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	body.add_child(shape)
	body.position = center
	root.add_child(body)


## Her father's titan, or what came back of it: slumped against the right wall
## of the aisle, left arm torn off and lying beside it, core dark. Cables run
## from it to a bank of salvaged batteries: she's been trying.
static func _fathers_titan(root: Node3D, info: Dictionary) -> void:
	var pos := Vector3(HALF - 2.6, F - 1.75, -12.0)
	var titan := Art.titan("atlas", "xo16")
	titan.name = "FathersTitan"
	# Sitting on the floor facing the nave, legs out, slumped back against the
	# wall and listing to one side. Its gun was never found.
	titan.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(90)) * Basis(Vector3.RIGHT, deg_to_rad(16)) * Basis(Vector3.BACK, deg_to_rad(-7)), pos)
	titan.scale = Vector3.ONE * 0.9
	titan.find_child("LegL", true, false).rotation_degrees = Vector3(84, 0, -6)
	titan.find_child("LegR", true, false).rotation_degrees = Vector3(70, 0, 8)
	titan.find_child("WeaponMount", true, false).visible = false
	root.add_child(titan)
	titan.set_param("glow", 0.0)
	titan.set_param("paint", Color(0.72, 0.7, 0.66))
	titan.find_child("ArmL", true, false).visible = false
	# The torn arm, taken off a second copy and laid on the floor.
	var donor := Art.titan("atlas", "xo16")
	var arm: Node3D = donor.find_child("ArmL", true, false)
	arm.get_parent().remove_child(arm)
	donor.free()
	arm.name = "TornArm"
	arm.position = Vector3(HALF - 3.0, F + 0.7, -6.4)
	arm.rotation_degrees = Vector3(0, 15, -90)
	arm.scale = Vector3.ONE * 0.9
	root.add_child(arm)
	for mesh in arm.find_children("*", "GeometryInstance3D", true, false):
		mesh.set_instance_shader_parameter("glow", 0.0)
		mesh.set_instance_shader_parameter("paint", Color(0.72, 0.7, 0.66))
	# Collision for the wreck so you can't walk through it.
	var hull := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(5.0, 4.0, 3.6)
	hull.add_child(shape)
	hull.position = Vector3(HALF - 2.5, F + 2.0, -12.0)
	root.add_child(hull)
	# Battery bank and cables.
	var bank := Vector3(HALF - 1.0, F, -6.5)
	K.metal(root, bank + Vector3(0, 0.5, 0), Vector3(1.0, 1.0, 1.6))
	K.metal(root, bank + Vector3(0, 1.2, 0.3), Vector3(0.8, 0.4, 0.8), Vector3(0, 12, 0))
	K.glow(root, bank + Vector3(-0.51, 0.75, -0.4), Vector3(0.02, 0.1, 0.1), Color(1.0, 0.4, 0.1))
	for i in 3:
		K.mesh(root, Vector3(HALF - 1.6 - i * 0.25, F + 0.04, -8.9), Vector3(0.08, 0.08, 3.0), Art.material("gunmetal"), Vector3(0, 8 - i * 9, 0))
	K.interactable(info, "titan", Vector3(HALF - 6.4, F + 0.1, -12.0), "[F] Look at Dad's titan", [
		"Dad's titan. They sent back what was left of it. Not him.",
		"Core's cracked and the left arm's gone. I've rebuilt worse.",
		"Every part I find out there, I'm finding for both of us.",
	], 3.2)


## In the nave, just inside the door: a crate table with her hand-drawn map.
## Walking up to it and pressing F heads out on a run.
static func _map_table(root: Node3D, info: Dictionary) -> void:
	var t := Vector3(-3.0, F, 0.5)
	for dx in [-0.9, 0.9]:
		K.wood(root, t + Vector3(dx, 0.45, 0), Vector3(0.8, 0.9, 0.9))
	K.wood(root, t + Vector3(0, 0.96, 0), Vector3(2.8, 0.1, 1.6))
	var map := K.mesh(root, t + Vector3(0, 1.03, 0), Vector3(2.4, 0.02, 1.3), Art.material("light"))
	map.set_instance_shader_parameter("paint", Color(0.62, 0.55, 0.4))
	# Three zones marked in red, and the route between them.
	for i in 3:
		K.glow(root, t + Vector3(-0.8 + i * 0.8, 1.05, -0.3 + (i % 2) * 0.5), Vector3(0.14, 0.02, 0.14), Color(0.9, 0.2, 0.12))
	for i in 2:
		K.mesh(root, t + Vector3(-0.4 + i * 0.8, 1.045, -0.05), Vector3(0.75, 0.01, 0.03), Art.material("gunmetal"), Vector3(0, 30 - i * 60, 0))
	var label := Kit.label(root, t + Vector3(0, 2.0, 0), "HEAD OUT", 48)
	label.modulate = Color(1.0, 0.85, 0.5)
	K.interactable(info, "map_table", t + Vector3(0, 0.1, 0), "[F] Head out on a run", [], 2.6)
	info["map_table"] = t


## Vines hanging from the roof hole and the lintel, and moss on the fallen stone.
static func _overgrowth(root: Node3D) -> void:
	var moss := Art.material("moss")
	var top := F + WALL_H
	for spec in [[-3.6, -13.0, 4.5], [-3.5, -17.5, 6.0], [3.7, -15.0, 3.5], [3.6, -21.0, 5.0],
			[-1.0, -25.6, 3.0], [1.8, -12.4, 4.0], [-9.0, 6.8, 3.5], [8.5, 6.8, 2.5], [-1.6, FRONT_Z + 1.3, 2.0], [1.9, FRONT_Z + 1.3, 3.0]]:
		K.mesh(root, Vector3(spec[0], top - spec[2] * 0.5, spec[1]), Vector3(0.25, spec[2], 0.25), moss)
		K.mesh(root, Vector3(spec[0] + 0.15, top - spec[2] * 0.3, spec[1] + 0.1), Vector3(0.18, spec[2] * 0.6, 0.18), moss)
	# Moss on the roof edges round the hole and on the rubble.
	K.mesh(root, Vector3(-4.2, top + 1.05, HOLE.get_center().y), Vector3(1.2, 0.1, HOLE.size.y), moss)
	K.mesh(root, Vector3(4.2, top + 1.05, HOLE.get_center().y), Vector3(1.2, 0.1, HOLE.size.y), moss)
	K.mesh(root, Vector3(-2.2, F + 1.3, -14.0), Vector3(2.4, 0.08, 1.6), moss, Vector3(18, 20, 0))
