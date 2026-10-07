extends RefCounted
## Marrow's corner of Solace (vices.gd Hush, Mature only):
##   - the alley gap between the Glowbox Arcade and Eco's old flat on Low Row,
##     where Marrow sells Hush (F opens hush_screen.gd),
##   - a cellar door by the Holo-Cinema, down to his basement,
##   - the basement itself, where Eco comes to in his armchair after a run on
##     Hush (or when his Hold on her is deep enough), and the stairs back up.
## The basement is a sealed room built under the town (BASEMENT), so it never
## shows from the street. Under Teen the alley is empty talk and the cellar
## door stays chained (the run manager checks the rating).
## Marrow is a primitive placeholder figure until a proper model is built.

const K := preload("res://scripts/hub/hub_kit.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")

const STREET_HALF := 7.0
## The alley gap on Low Row's west side, and the cellar door on its east.
const ALLEY := Vector3(-STREET_HALF + 0.9, 0, 203.75)
const CELLAR := Vector3(STREET_HALF - 1.1, 0, 213.3)
## The basement room's floor centre, under the town.
const BASEMENT := Vector3(-80.0, -10.0, 210.0)
const ROOM := Vector3(7.0, 3.0, 7.0)
## Where Eco comes to (his armchair) and where the stairs up are.
const WAKE := BASEMENT + Vector3(-1.9, 0, 1.4)
const STAIRS := BASEMENT + Vector3(2.4, 0, -2.6)
const VIOLET := Color(0.7, 0.35, 1.0)

## What she comes to, in his chair. One per trance, in turn.
const WAKE_LINES := [
	"...Eco comes to in a sagging armchair. Violet light. Hours gone. Marrow is watching her from across the table.",
	"Marrow: \"Welcome back. You walked here on your own, you know. You always do.\" Her pockets are lighter.",
	"Her father's dog tags are on his table. Marrow slides them back to her with a smile. \"Careful. You'll lose those.\"",
	"Marrow: \"Mom thinks you're at the temple. Ophelia thinks you're avoiding her. Only I know where you are.\"",
	"Eco comes to with a dose already pressed into her hand. She doesn't remember asking. Marrow does.",
]


## Builds the alley, the cellar door and the basement into the town, and adds
## their spots to info["interactables"]; info["hush"] gets {wake, street}.
static func build(root: Node3D, info: Dictionary) -> void:
	_alley(root, info)
	_cellar(root, info)
	_basement(root, info)
	info["hush"] = {"wake": WAKE, "street": CELLAR + Vector3(-1.2, 0, 0)}


static func _alley(root: Node3D, info: Dictionary) -> void:
	# A dim violet lamp over the gap, trash and Marrow leaning in the dark.
	K.light(root, ALLEY + Vector3(-0.6, 2.6, 0), VIOLET, 0.7, 3.5)
	K.mesh(root, ALLEY + Vector3(-0.85, 0.35, 0.35), Vector3(0.6, 0.7, 0.5), Art.material("corrugated", Color(0.3, 0.32, 0.3)))
	figure(root, ALLEY + Vector3(-0.6, 0, -0.2), 90.0)
	K.interactable(info, "hush_alley", ALLEY + Vector3(0.6, 0, 0), "[F] Someone's leaning in the alley", [
		"Some guy in a long coat in the gap by the arcade. He looks at me like he already knows my name.",
		"He's still there. He's always there.",
	], 2.4)
	info["interactables"].back()["shop"] = "hush"


static func _cellar(root: Node3D, info: Dictionary) -> void:
	# A slanted steel cellar door in the pavement, chained when it's not his.
	K.mesh(root, CELLAR + Vector3(0.45, 0.18, 0), Vector3(1.0, 0.08, 1.4), Art.material("gunmetal", Color(0.2, 0.22, 0.24)), Vector3(0, 0, -18))
	K.light(root, CELLAR + Vector3(0.6, 1.2, 0), VIOLET, 0.35, 2.0)
	K.interactable(info, "cinema_cellar", CELLAR, "[F] Cellar door under the Holo-Cinema", [
		"A cellar door under the cinema. Chained. There's a faint purple glow through the gap.",
	], 2.2)
	var spot: Dictionary = info["interactables"].back()
	spot["shop"] = "cellar"
	spot["teleport"] = STAIRS + Vector3(-0.8, 0, 0.6)


static func _basement(root: Node3D, info: Dictionary) -> void:
	var b := BASEMENT
	var hw := ROOM.x * 0.5
	var hd := ROOM.z * 0.5
	var concrete := Art.material("concrete", Color(0.42, 0.4, 0.44))
	# Floor, ceiling and four walls, all solid, so it's sealed.
	K.carved(root, b + Vector3(0, -0.25, 0), Vector3(ROOM.x + 0.6, 0.5, ROOM.z + 0.6), Vector3.ZERO, Color(0.5, 0.48, 0.52))
	K.carved(root, b + Vector3(0, ROOM.y + 0.25, 0), Vector3(ROOM.x + 0.6, 0.5, ROOM.z + 0.6), Vector3.ZERO, Color(0.35, 0.33, 0.38))
	for side in [-1.0, 1.0]:
		K.carved(root, b + Vector3(side * (hw + 0.15), ROOM.y * 0.5, 0), Vector3(0.3, ROOM.y, ROOM.z), Vector3.ZERO, Color(0.45, 0.43, 0.47))
		K.carved(root, b + Vector3(0, ROOM.y * 0.5, side * (hd + 0.15)), Vector3(ROOM.x, ROOM.y, 0.3), Vector3.ZERO, Color(0.45, 0.43, 0.47))
	# A rug, his table with the resin jars glowing, his chair, her armchair.
	K.mesh(root, b + Vector3(0, 0.02, 0.3), Vector3(3.2, 0.03, 2.4), Art.material("fabric", Color(0.35, 0.12, 0.2)))
	K.mesh(root, b + Vector3(0.3, 0.75, -0.6), Vector3(1.6, 0.08, 0.9), Art.material("wood", Color(0.4, 0.3, 0.25)))
	for x in [-0.35, 1.0]:
		for z in [-0.95, -0.25]:
			K.mesh(root, b + Vector3(x + 0.0, 0.37, z), Vector3(0.07, 0.74, 0.07), Art.material("gunmetal"))
	for i in 4:
		_glow(root, b + Vector3(-0.1 + i * 0.25, 0.88, -0.75 + (i % 2) * 0.2), Vector3(0.1, 0.18, 0.1))
	K.light(root, b + Vector3(0.3, 1.3, -0.6), VIOLET, 1.4, 6.0)
	K.light(root, b + Vector3(-2.2, 2.6, 2.0), Color(1.0, 0.7, 0.45), 0.35, 4.0)
	# His chair behind the table, him in it, facing her armchair.
	K.mesh(root, b + Vector3(0.6, 0.45, -1.5), Vector3(0.6, 0.9, 0.6), Art.material("fabric", Color(0.15, 0.13, 0.16)))
	figure(root, b + Vector3(0.6, 0.0, -1.45), 0.0, true)
	# Her armchair: low, sagging, facing his table.
	var arm := Art.material("fabric", Color(0.35, 0.3, 0.22))
	K.mesh(root, WAKE + Vector3(0, 0.25, 0.1), Vector3(1.0, 0.5, 0.9), arm)
	K.mesh(root, WAKE + Vector3(0, 0.75, 0.5), Vector3(1.0, 0.9, 0.2), arm, Vector3(-12, 0, 0))
	for side in [-1.0, 1.0]:
		K.mesh(root, WAKE + Vector3(side * 0.45, 0.6, 0.1), Vector3(0.18, 0.35, 0.85), arm)
	# Clutter: crates, a hanging bulb, posters of old films peeling off the walls.
	K.mesh(root, b + Vector3(-2.7, 0.4, -2.6), Vector3(0.9, 0.8, 0.9), Art.material("wood", Color(0.55, 0.45, 0.35)))
	K.mesh(root, b + Vector3(-2.7, 1.05, -2.6), Vector3(0.6, 0.5, 0.6), Art.material("wood", Color(0.5, 0.42, 0.33)))
	K.mesh(root, b + Vector3(-hw + 0.02, 1.6, -0.5), Vector3(0.02, 1.2, 0.8), Art.material("canvas", Color(0.7, 0.4, 0.35)))
	K.mesh(root, b + Vector3(-hw + 0.02, 1.7, 1.2), Vector3(0.02, 1.0, 0.7), Art.material("canvas", Color(0.4, 0.45, 0.7)))
	# Stairs up in the corner (the way out, to the cellar door).
	for k in 5:
		K.mesh(root, STAIRS + Vector3(0.6, 0.15 + k * 0.3, 0.5 - k * 0.32), Vector3(1.2, 0.3, 0.5), concrete)
	K.interactable(info, "cellar_stairs", STAIRS, "[F] Stairs up to the street", [
		"The stairs up to the cinema's cellar door.",
	], 2.0)
	var spot: Dictionary = info["interactables"].back()
	spot["teleport"] = CELLAR + Vector3(-1.2, 0, 0)
	K.interactable(info, "marrow", b + Vector3(0.6, 0, -0.4), "[F] Marrow", [
		"Marrow: \"Sit. Stay as long as you like. You always do.\"",
	], 2.0)
	info["interactables"].back()["shop"] = "hush"


## Marrow: a tall figure in a long dark coat and a deep hood, a violet ember at
## his hand. `sitting` folds him into his chair.
static func figure(root: Node3D, pos: Vector3, yaw: float, sitting := false) -> Node3D:
	var f := Node3D.new()
	f.position = pos
	f.rotation_degrees.y = yaw
	root.add_child(f)
	var coat := Art.material("fabric", Color(0.1, 0.09, 0.12))
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.24
	cap.height = 1.2 if sitting else 1.55
	body.mesh = cap
	body.material_override = coat
	body.position.y = (0.75 if sitting else 0.8)
	f.add_child(body)
	var hood := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.17
	sph.height = 0.38
	hood.mesh = sph
	hood.material_override = coat
	hood.position = Vector3(0, (1.45 if sitting else 1.72), 0.02)
	f.add_child(hood)
	var face := MeshInstance3D.new()
	var fs := SphereMesh.new()
	fs.radius = 0.11
	fs.height = 0.22
	face.mesh = fs
	face.material_override = Art.material("fabric", Color(0.02, 0.02, 0.03))
	face.position = hood.position + Vector3(0, -0.02, -0.09)
	f.add_child(face)
	_glow(f, Vector3(0.22, (0.95 if sitting else 1.05), -0.18), Vector3(0.04, 0.04, 0.04))
	return f


static func _glow(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = VIOLET
	mat.emission_enabled = true
	mat.emission = VIOLET
	mat.emission_energy_multiplier = 3.0
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
