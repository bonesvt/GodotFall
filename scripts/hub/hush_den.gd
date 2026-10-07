extends RefCounted
## Marrow's corner of Solace (vices.gd Hush, Mature only):
##   - the alley gap between the Glowbox Arcade and Eco's old flat on Low Row,
##     where Marrow sells Hush (F opens hush_screen.gd),
##   - a cellar door by the Holo-Cinema, down to his basement,
##   - the basement itself, where Eco comes to after a run on Hush (or when his
##     Hold on her is deep enough), and the stairs back up,
##   - her own room off it: a store room she welded a lock onto, that he can't
##     get into. While his Hold is shallow (OWN_ROOM_BELOW) she makes it there
##     and wakes up locked in, safe; deeper, she wakes in his armchair.
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
## Her room: a separate sealed room (doors between them teleport), her cot,
## and her steel door's two sides.
const HER_ROOM := BASEMENT + Vector3(10.0, 0, 0)
const HER_SIZE := Vector3(3.6, 2.6, 3.6)
const HER_WAKE := HER_ROOM + Vector3(-0.9, 0, 0.6)
const HER_DOOR_IN := BASEMENT + Vector3(-2.9, 0, -0.6)
const HER_DOOR_OUT := HER_ROOM + Vector3(1.2, 0, -1.2)
## Under this Hold she still makes it to her own room.
const OWN_ROOM_BELOW := 30.0
## Where his pull walks her in, at the foot of the stairs facing his table.
const ARRIVE := BASEMENT + Vector3(0.3, 0, 0.7)
## How his pull walks her down Solace to the cellar door (hush_pull.gd):
## street points north to south, round the west side of the Sun Tree.
const PULL_ROUTE := [
	Vector3(-3.0, 0, 158.0), Vector3(-3.0, 0, 165.5), Vector3(-9.5, 0, 165.5),
	Vector3(-9.5, 0, 184.5), Vector3(-3.0, 0, 190.5), Vector3(0.0, 0, 200.0),
	Vector3(3.5, 0, 210.5), CELLAR,
]
## Where she picks up his pull's walk if it takes her outside town.
const PULL_TOWN_START := Vector3(0.0, 0, 140.0)

## Marrow's errands, earned doses at full Hold (vices.gd): somewhere in Solace
## he sends her, what he says, the spot's prompt and what she finds there.
## Small dirty jobs for a dealer; nothing she can't walk away from.
const ERRANDS := {
	"arcade_bin": {
		"pos": Vector3(-6.2, 0, 195.5),
		"task": "Marrow: \"Before you get another, you work. Take this packet to the bin behind the Glowbox Arcade. Don't open it.\"",
		"short": "leave his packet in the arcade's bin",
		"prompt": "[F] Leave Marrow's packet in the bin",
		"done": "Eco drops the packet in the bin. It's warm. She doesn't want to know why. Back to Marrow.",
	},
	"sal_crates": {
		"pos": Vector3(6.2, 0, 147.5),
		"task": "Marrow: \"Sal owes me. There's a tin under the crates by his shop. Bring it to me and you'll get yours.\"",
		"short": "fetch the tin from under Sal's crates",
		"prompt": "[F] Dig the tin out from under Sal's crates",
		"done": "Eco finds the tin under Sal's crates. It rattles like loose screws. Sal would kill her. Back to Marrow.",
	},
	"gate_watch": {
		"pos": Vector3(-5.0, 0, 134.0),
		"task": "Marrow: \"Go and count the soldiers on the town gate for me. Every one. Then come back and tell me.\"",
		"short": "count the soldiers at the town gate",
		"prompt": "[F] Count the soldiers on the gate",
		"done": "Six soldiers. Two asleep. She hates that she's counting them for him. Back to Marrow.",
	},
	"okoro_house": {
		"pos": Vector3(-6.2, 0, 146.3),
		"task": "Marrow: \"The Okoros, between the tailor and the clinic. They keep a ledger with my name in it. Get in, get it, get out. Nobody home till dark.\"",
		"short": "break into the Okoro house for the ledger",
		"prompt": "[F] Pick the Okoros' lock",
		"done": "The lock gives on the third try. Kids' drawings on the fridge. Eco finds the ledger and doesn't look at anything else. Back to Marrow.",
	},
	"clinic_cabinet": {
		"pos": Vector3(-6.2, 0, 157.5),
		"task": "Marrow: \"Doc Imani's back room. Second cabinet, the blue vials. She trusts you, so she won't be looking.\"",
		"short": "steal the blue vials from Mercy Clinic's back room",
		"prompt": "[F] Slip into the clinic's back room",
		"done": "Doc Imani is humming out front. Eco pockets the vials. The doc stitched Dad up for free, more than once. Back to Marrow.",
	},
	"outfitter_till": {
		"pos": Vector3(-6.2, 0, 142.6),
		"task": "Marrow: \"Stitch & Steel empties the till at closing and leaves the tin under the counter. Take the tin.\"",
		"short": "lift the cash tin from Stitch & Steel",
		"prompt": "[F] Reach under Stitch & Steel's counter",
		"done": "The tin's heavier than she thought. The bell over the door doesn't ring. Back to Marrow.",
	},
	"recruiter_window": {
		"pos": Vector3(-16.4, 0, 179.6),
		"task": "Marrow: \"The recruiters who turned you away keep their duty roster in the back office. Climb in the window and bring it to me. You'll enjoy this one.\"",
		"short": "climb into the recruitment office for the roster",
		"prompt": "[F] Jimmy the recruitment office's back window",
		"done": "In through the window, the roster off the desk, out again. Her old application is still pinned to the corkboard. Back to Marrow.",
	},
	"lantern_shelf": {
		"pos": Vector3(15.5, 0, 188.0),
		"task": "Marrow: \"The Lucky Lantern has a jade cat on the top shelf. Old. Real. Bring it here. Don't buy it.\"",
		"short": "pocket the jade cat from the Lucky Lantern",
		"prompt": "[F] Palm the jade cat off the Lucky Lantern's shelf",
		"done": "Eco palms the jade cat while the old man wraps someone's gift. He waves at her on the way out. Back to Marrow.",
	},
}

## Withdrawal mid-run (vices.gd episode, hush_pull.gd): she walks off the job
## to beg him for another errand. What she comes to at his place.
const BEG_LINES := [
	"Eco: \"I walked off the job. I couldn't think, I... Marrow, please. Give me work. Any errand.\" Marrow: \"Another chance? Fine. Don't waste it.\"",
	"Marrow: \"You left the fight to come crawling down my stairs. That's how bad it's got. Good. Here's what you'll do.\"",
	"Eco's hands won't stop shaking. \"One more errand. Please.\" Marrow smiles like he's been waiting all day.",
]


## One of his errands, at random.
static func pick_errand() -> String:
	var ids := ERRANDS.keys()
	return ids[randi() % ids.size()]

## Coming to in her own locked room (his Hold still shallow).
const OWN_ROOM_LINES := [
	"Eco wakes on her cot behind her own welded door. Lock's still shut. Nice work, Eco. You made it.",
	"She comes to in her room off his basement, curled up with her wrench. He knocked twice in the night. She didn't answer.",
	"Her room. Her lock. Her head's pounding, but nobody got in. She checks the weld anyway.",
]
## Coming to in his armchair, by how deep his Hold is (hooked, his).
const DEEP_LINES := [
	"Eco wakes in his armchair, not her room. She doesn't remember walking past her own door. Marrow does. He's smiling.",
	"Marrow: \"You didn't even try for your little room this time. That's all right. This chair's yours now.\"",
	"She comes to with her key in his hand. He gives it back slowly. \"You won't need it. But keep it, if it helps.\"",
]
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
	_her_room(root, info)
	info["hush"] = {"wake": WAKE, "own_room": HER_WAKE, "street": CELLAR + Vector3(-1.2, 0, 0)}
	for id: String in ERRANDS:
		K.interactable(info, "errand_" + id, ERRANDS[id]["pos"], ERRANDS[id]["prompt"], [ERRANDS[id]["done"]], 2.0)
		info["interactables"].back()["errand"] = id  # only there while it's her errand (run_manager.gd)


## Which room she comes to in and what she finds, for his Hold `hold` and her
## `n`th trance: {pos, line, his} (his: she's in his armchair, he takes a tab).
static func wake(hold: float, n: int) -> Dictionary:
	if hold < OWN_ROOM_BELOW:
		return {"pos": HER_WAKE, "line": OWN_ROOM_LINES[n % OWN_ROOM_LINES.size()], "his": false}
	if hold >= 60.0:
		return {"pos": WAKE, "line": DEEP_LINES[n % DEEP_LINES.size()], "his": true}
	return {"pos": WAKE, "line": WAKE_LINES[n % WAKE_LINES.size()], "his": true}


## Her room: walls she patched, a cot, her tools, Dad's photo, a warm lamp,
## and the inside of the steel door she welded the lock onto.
static func _her_room(root: Node3D, info: Dictionary) -> void:
	var r := HER_ROOM
	var hw := HER_SIZE.x * 0.5
	var hd := HER_SIZE.z * 0.5
	var wall := Color(0.55, 0.52, 0.48)
	K.carved(root, r + Vector3(0, -0.25, 0), Vector3(HER_SIZE.x + 0.6, 0.5, HER_SIZE.z + 0.6), Vector3.ZERO, Color(0.5, 0.47, 0.44))
	K.carved(root, r + Vector3(0, HER_SIZE.y + 0.25, 0), Vector3(HER_SIZE.x + 0.6, 0.5, HER_SIZE.z + 0.6), Vector3.ZERO, Color(0.4, 0.38, 0.36))
	for side in [-1.0, 1.0]:
		K.carved(root, r + Vector3(side * (hw + 0.15), HER_SIZE.y * 0.5, 0), Vector3(0.3, HER_SIZE.y, HER_SIZE.z), Vector3.ZERO, wall)
		K.carved(root, r + Vector3(0, HER_SIZE.y * 0.5, side * (hd + 0.15)), Vector3(HER_SIZE.x, HER_SIZE.y, 0.3), Vector3.ZERO, wall)
	# Cot with a blanket, a crate for a table, her toolbox, Dad's photo.
	K.mesh(root, HER_WAKE + Vector3(-0.2, 0.25, 0.2), Vector3(0.9, 0.12, 1.9), Art.material("canvas", Color(0.45, 0.5, 0.4)))
	K.mesh(root, HER_WAKE + Vector3(-0.2, 0.33, 0.45), Vector3(0.85, 0.06, 1.1), Art.material("fabric", Color(0.75, 0.4, 0.3)))
	for x in [-0.6, 0.2]:
		for z in [-0.7, 1.1]:
			K.mesh(root, HER_WAKE + Vector3(x, 0.1, z), Vector3(0.05, 0.2, 0.05), Art.material("gunmetal"))
	K.mesh(root, r + Vector3(0.9, 0.3, 1.1), Vector3(0.6, 0.6, 0.6), Art.material("wood", Color(0.6, 0.5, 0.38)))
	K.mesh(root, r + Vector3(0.9, 0.75, 1.1), Vector3(0.18, 0.24, 0.03), Art.material("canvas", Color(0.85, 0.8, 0.7)))
	K.mesh(root, r + Vector3(1.1, 0.15, 0.2), Vector3(0.5, 0.3, 0.25), Art.material("gunmetal", Color(0.8, 0.25, 0.2)))
	K.light(root, r + Vector3(0.6, 1.6, 0.8), Color(1.0, 0.75, 0.5), 0.9, 4.5)
	# The steel door from inside: a fat bead of weld round a padlock plate.
	K.mesh(root, HER_DOOR_OUT + Vector3(0.45, 1.05, 0), Vector3(0.08, 2.1, 1.0), Art.material("gunmetal", Color(0.35, 0.36, 0.38)))
	K.mesh(root, HER_DOOR_OUT + Vector3(0.4, 1.1, -0.3), Vector3(0.06, 0.3, 0.2), Art.material("alloy", Color(1.0, 0.8, 0.5)))
	K.interactable(info, "her_room_door", HER_DOOR_OUT, "[F] Unlock your door", [
		"Her door. She welded the lock on herself.",
	], 1.8)
	var spot: Dictionary = info["interactables"].back()
	spot["teleport"] = HER_DOOR_IN + Vector3(0.9, 0, 0)
	# Its outside, on the basement's west wall.
	K.mesh(root, HER_DOOR_IN + Vector3(-0.4, 1.05, 0), Vector3(0.08, 2.1, 1.0), Art.material("gunmetal", Color(0.35, 0.36, 0.38)))
	K.mesh(root, HER_DOOR_IN + Vector3(-0.35, 1.1, 0.3), Vector3(0.06, 0.3, 0.2), Art.material("alloy", Color(1.0, 0.8, 0.5)))
	K.interactable(info, "her_room", HER_DOOR_IN, "[F] Your room", [
		"A steel door with a lock she welded on herself. Only her key fits. He's tried.",
	], 1.6)
	spot = info["interactables"].back()
	spot["teleport"] = HER_DOOR_OUT + Vector3(-0.9, 0, 0)


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
