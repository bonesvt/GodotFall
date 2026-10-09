extends RefCounted
## Pip's own secrets (downtown.gd), Mature only: what the Undertow keeps out
## of sight, and what Eco can find out about her sister by looking.
##   - a roped stair beside the Undertow's door, down to the Underfloor:
##     a corridor of private rooms with just a bed and mood lighting each,
##   - the gold door at the end of it, into the high rollers' room: a stage
##     with poles, a private table, and Pip's chair watching all of it,
##   - the stage door beside it, into the dancers' dressing room, where the
##     women who work down here leave notes for each other.
## Each room hides some of her DIRT: the rooms are how she gets leverage on
## the colony officers who use them. Found pieces are saved with the rest of
## Downtown (Downtown.find_dirt). Both rooms are sealed boxes built under the
## town, like Marrow's basement (hush_den.gd); doors between them teleport.
## Under Teen the bouncer keeps the rope shut (the run manager checks).
## The rooms are empty after hours: nobody is in them, only what they leave.

const K := preload("res://scripts/hub/hub_kit.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")

const GOLD := Color(1.0, 0.72, 0.25)
const RED := Color(1.0, 0.18, 0.25)
const VIOLET := Color(0.75, 0.3, 1.0)
const BLUE := Color(0.25, 0.5, 1.0)

## The roped stair down, on the street beside the Undertow's door.
const ROPE := Vector3(35.6, 0, 219.0)
## The Underfloor's origin (corridor centre), under the town, sealed.
const UNDER := Vector3(-80.0, -10.0, 250.0)
const UNDER_HALF := 6.0
const ROOM_XS := [-4.0, 0.0, 4.0]
const ROOM_COLORS := [RED, VIOLET, BLUE]
const UNDER_STAIRS := UNDER + Vector3(-5.2, 0, -0.2)
const GOLD_DOOR_IN := UNDER + Vector3(5.5, 0, 0)
## The high rollers' room, its floor centre.
const HIGH := Vector3(-80.0, -10.0, 275.0)
const HIGH_SIZE := Vector3(10.0, 3.6, 8.0)
const GOLD_DOOR_OUT := HIGH + Vector3(0, 0, -3.4)
## The dancers' dressing room, through the stage door in the high rollers'
## room's west wall (sealed, under the town; the doors teleport).
const DRESSING := Vector3(-80.0, -10.0, 300.0)
const DRESSING_SIZE := Vector3(8.0, 3.0, 6.0)
const STAGE_DOOR := HIGH + Vector3(-4.5, 0, 0.9)
const STAGE_DOOR_BACK := DRESSING + Vector3(3.5, 0, 0)

## Her dirt: where it's hidden, what Eco finds. In the order the rooms run.
const DIRT := {
	"mirror": {"prompt": "[F] The mirror over the bed",
		"text": "The mirror's warm to the touch. Behind it, a lens and a little red light. Every room down here has one. Pip doesn't rent beds. She rents out the room and keeps the film."},
	"guestbook": {"prompt": "[F] Something under the mattress",
		"text": "A guest book, in Pip's handwriting. Rank, unit, date, room, how long. Half the colony's officers are in it. The quartermaster has a whole page."},
	"reels": {"prompt": "[F] The nightstand",
		"text": "A drawer of tape reels, each labelled with a name and a price. Some prices are crossed out and written over with 'PAID'. Some say 'NOT YET'."},
	"markers": {"prompt": "[F] The card table",
		"text": "A cigar box full of markers. IOUs, signed by men who don't have that kind of scrap. Pip never calls them in. She just lets them know she's still holding them."},
	"safe": {"prompt": "[F] The safe behind the bar",
		"text": "The safe's open. Inside: a resignation letter from the recruiters' captain, signed, undated. She can end his career any night she likes. He knows it."},
	"chair": {"prompt": "[F] Pip's chair",
		"text": "Her chair, up on a step, facing the stage and the door at once. A notebook on the arm: who watched which dancer, who drank what, who talked. Nobody looks at the woman in the chair. That's the point."},
}
const DIRT_ORDER := ["mirror", "guestbook", "reels", "markers", "safe", "chair"]

## What the rooms are for, said plainly by what's lying about (nothing is
## ever shown: the rooms are empty after hours). Not dirt, just looking:
## [id, room ("under" or "high"), offset from its origin, prompt, lines in turn].
const HINTS := [
	["rate_board", "under", Vector3(-4.4, 0, -1.0), "[F] The board by the stairs", [
		"A chalkboard by the stairs. ROOMS BY THE HOUR. ALL NIGHT ON REQUEST. COMPANY ARRANGED AT THE BAR. Someone has drawn a little heart next to 'company'.",
		"Under the prices, in Pip's handwriting: 'No names at the door. Names cost extra.'"]],
	["timers", "under", Vector3(-2.8, 0, -0.9), "[F] The desk with the timers", [
		"Three egg timers on a little desk, one for each room. When one rings, somebody knocks twice. After that Pip charges by the quarter hour.",
		"A notepad by the timers: 'Lt. Varga, red room, two hours. Asked for Liesl again. Liesl says no more.' Pip has underlined it twice."]],
	["foil_bowl", "under", Vector3(0.9, 0, 0.9), "[F] A bowl by the door", [
		"A glass bowl by every door, full of little foil packets. Restocked every night, the way a hotel leaves mints on the pillow.",
		"Eco leaves them exactly where they are and decides she was never here."]],
	["linen_cart", "under", Vector3(2.2, 0, -0.8), "[F] The laundry cart", [
		"A laundry cart heaped with sheets, none of them clean. The rooms are changed between guests. That's a lot of guests for one night.",
		"There's a lipstick kiss on a pillowcase. Not Pip's shade."]],
	["door_tags", "under", Vector3(4.0, 0, 0.9), "[F] The tags on the handles", [
		"Each door has a tag on its handle: VACANT on one side, a red silk tassel on the other. Tassel out means don't knock, whatever you hear.",
		"The blue room's tassel is out. Nobody's in there. Somebody paid for it anyway, so nobody else can be."]],
	# a guest's review pinned inside each room's door, and the replies under it
	["review_red", "under", Vector3(-5.3, 0, 1.5), "[F] A comment card by the door", [
		"A comment card, red room: 'Five stars. Paid for an hour, got my money's worth twice. She didn't laugh at me once, and I gave her plenty of reasons to. Back Thursday. The wife thinks I'm on patrol.' Signed 'A Grateful Sergeant'.",
		"Under it, another hand: 'Bed creaks. Loudly. Rhythmically. The whole corridor knew.' Under that, in Pip's: 'The bed creaks so the lady with the timers knows you're still alive. Judging by the noise, you were very alive. Working as intended.'"]],
	["review_violet", "under", Vector3(-1.3, 0, 1.5), "[F] A comment card by the door", [
		"A comment card, violet room: 'Four stars. Lovely lighting, very forgiving, and she was more than worth the price. One star off because somebody knocked twice right at the best part.' Pip, underneath: 'That was the timer, sir. You were forty minutes over. The best part is billed by the quarter hour.'",
		"Another: 'Booked the all-night rate with two of the women from the bar. Got no sleep whatsoever. Couldn't walk straight to muster. Worth every scrap.' No name, just a captain's pin pushed through the card."]],
	["review_blue", "under", Vector3(2.7, 0, 1.5), "[F] A comment card by the door", [
		"A comment card, blue room: 'Three stars. The walls aren't as thick as advertised. Neither of us was quiet, and the room next door sent a note asking us to keep it down.' Pip, below: 'You got two notes. The second one asked if you take bookings.'",
		"Another, in very careful handwriting: 'My first time down here. My first time anywhere, if I'm honest. She was patient, and kind, and showed me what I'd been doing wrong. Thank you, Vell.' Pip has added: 'Vell says you're welcome, and that it was nothing she hadn't fixed before. Vell also says tip.'"]],
	# the dressing room: the women who work down here, in their own words
	["staff_rules", "dress", Vector3(-1.5, 0, -2.5), "[F] The board on the wall", [
		"PIP'S RULES FOR STAFF, in her hand. You choose who, and you can change your mind at any point. Cash before the door shuts. Anyone who argues meets Tomas in the alley. Nobody leaves with a guest. Ever. I walk you home if you ask.",
		"A pay sheet pinned under it: the house keeps thirty in every hundred. Someone has written 'The Velvet Ace takes sixty off its dealers.' Someone else has added '...and doesn't walk them home.'"]],
	["staff_vell", "dress", Vector3(0.5, 0, 2.2), "[F] Lipstick on the mirror", [
		"Lipstick on the mirror, Vell's: 'JOB REVIEW. Four stars. Pay's good, the boss is terrifying, the beds are nicer than mine. One star off for the captain: pays for two hours, needs ten minutes, spends the rest talking about his mother.'",
		"Under it, in another colour: 'He tips double if you let him finish the story about his mother. L.'"]],
	["staff_liesl", "dress", Vector3(-2.2, 0, 2.2), "[F] A card in the mirror frame", [
		"A card in a mirror frame, Liesl's: 'Three stars this month. Varga keeps asking for me. Told Pip I'm done with him. She didn't argue. She moved him to the blue room, tripled his rate and sent Dove in, and Dove charges him extra every time he says my name.'",
		"Dove's reply, below: 'Eleven times on Thursday. Bought new shoes. Thanks, Varga.'"]],
	["staff_dove", "dress", Vector3(0.0, 0, -1.6), "[F] A note on the couch", [
		"A note on a couch cushion, Dove's: 'Five stars. Best-paid job in the valley that doesn't come with a gun. The men think they're paying for us. They're paying Pip for what they say while they're with us. We just listen, and smile, and remember.'",
		"Folded in with it: a list of officers and what each one let slip, between one thing and another. It goes to Pip on Fridays. That's the real job."]],
	["staff_lockers", "dress", Vector3(3.2, 0, -1.8), "[F] The lockers", [
		"Lockers with names on tape. One has a photo of a little boy taped inside the door, and a tally of scrap saved towards 'his school'. The tally is nearly at the bottom of the page.",
		"Another has a colony recruitment notice taped up with a face circled. Next to it, in lipstick: 'NOT MY BROTHER. NOT EVER.'"]],
	["staff_rack", "dress", Vector3(-3.2, 0, -0.4), "[F] The costume rack", [
		"A rack of costumes. A lot of them are colony dress uniforms, every rank, perfectly pressed. The officers love the uniforms. The women find that very funny.",
		"A tag on the captain's-rank jacket: 'For the captain. He likes being the one taking orders, for once.'"]],
	["staff_kettle", "dress", Vector3(1.8, 0, -2.3), "[F] The table with the kettle", [
		"A kettle, a tin of the good tea, a first aid kit, ice packs for sore feet, and a jar of hand cream with a note: 'You're all worth more than they pay. Keep your hands soft and your rates high. P.'",
		"A rota under the kettle: who's on, who's off, who's walking whom home. 'P' is down for every night."]],
	["stage_card", "high", Vector3(-2.8, 0, 1.3), "[F] A card on the stage steps", [
		"A price list for the stage, gold on black. A DANCE. A PRIVATE DANCE. THE GOLD DOOR, CLOSED. The last line has no price. You ask Pip.",
		"On the back, small: 'Dancers choose. Guests who argue leave by the alley, and they don't come back down.'"]],
	["tip_glass", "high", Vector3(1.0, 0, 1.3), "[F] The glass by the middle pole", [
		"A brandy glass stuffed with folded scrip by the middle pole. Rank pins are pushed through some of the notes, so the dancers know exactly who tipped.",
		"Most of the pins are officers'. The biggest wad has the recruiters' captain's pin through it."]],
	["house_rules", "high", Vector3(-1.2, 0, -3.5), "[F] The plaque by the door", [
		"A brass plaque by the door. HOUSE RULES: Look all you like. Touch only what you've paid for. What happens here, the house remembers.",
		"The last rule is newer than the others. The brass is shinier."]],
]
## Eco, once she's found all of it.
const ALL_FOUND := "Eco thought her sister sold secrets. She doesn't. She makes them: she builds rooms for men to be weak in, and keeps the receipts."


static func build(root: Node3D, info: Dictionary) -> void:
	var below := Node3D.new()
	below.name = "DowntownBelow"
	root.add_child(below)
	_rope(below, info)
	_underfloor(below, info)
	_high_rollers(below, info)
	_dressing(below, info)
	_hints(below, info)


## The velvet rope on the street and the stair behind it.
static func _rope(root: Node3D, info: Dictionary) -> void:
	var brass := Art.material("gunmetal", Color(0.9, 0.7, 0.3))
	for dx: float in [-0.7, 0.7]:
		K.mesh(root, ROPE + Vector3(dx, 0.5, -0.6), Vector3(0.08, 1.0, 0.08), brass)
	K.mesh(root, ROPE + Vector3(0, 0.82, -0.6), Vector3(1.4, 0.05, 0.05), Art.material("canvas", Color(0.5, 0.03, 0.12)))
	K.mesh(root, ROPE + Vector3(0, 0.12, 0.2), Vector3(1.3, 0.04, 1.2), Art.material("gunmetal", Color(0.12, 0.1, 0.12)))
	K.light(root, ROPE + Vector3(0, 0.6, 0.3), RED, 0.6, 2.5)
	K.interactable(info, "undertow_down", ROPE, "[F] The roped stair beside the Undertow", [
		"A bouncer in front of a velvet rope and a stair going down. \"Members.\" He doesn't move.",
		"Still roped off. Whatever's down there, Pip doesn't want her little sister seeing it.",
	], 2.0)
	info["interactables"].back()["teleport"] = UNDER_STAIRS + Vector3(0.9, 0, 0)


static func _box(root: Node3D, centre: Vector3, size: Vector3, tint: Color) -> void:
	var hw := size.x * 0.5
	var hd := size.z * 0.5
	K.carved(root, centre + Vector3(0, -0.25, 0), Vector3(size.x + 0.6, 0.5, size.z + 0.6), Vector3.ZERO, tint)
	K.carved(root, centre + Vector3(0, size.y + 0.25, 0), Vector3(size.x + 0.6, 0.5, size.z + 0.6), Vector3.ZERO, tint.darkened(0.3))
	for side in [-1.0, 1.0]:
		K.carved(root, centre + Vector3(side * (hw + 0.15), size.y * 0.5, 0), Vector3(0.3, size.y, size.z), Vector3.ZERO, tint)
		K.carved(root, centre + Vector3(0, size.y * 0.5, side * (hd + 0.15)), Vector3(size.x, size.y, 0.3), Vector3.ZERO, tint)


## A corridor along x (z -1.2..1.2) with three rooms off its north side
## (z 1.2..4.4), each just a bed and a coloured light.
static func _underfloor(root: Node3D, info: Dictionary) -> void:
	var u := UNDER
	var h := 2.8
	var wall := Color(0.16, 0.1, 0.14)
	_box(root, u + Vector3(0, 0, 1.6), Vector3(UNDER_HALF * 2, h, 5.6), wall)
	# Partitions between the rooms, and the corridor wall with a doorway each.
	for x: float in [-2.0, 2.0]:
		K.carved(root, u + Vector3(x, h * 0.5, 2.8), Vector3(0.2, h, 3.2), Vector3.ZERO, wall)
	for seg: Vector2 in [Vector2(-6.0, -4.55), Vector2(-3.45, -0.55), Vector2(0.55, 3.45), Vector2(4.55, 6.0)]:
		K.carved(root, u + Vector3((seg.x + seg.y) * 0.5, h * 0.5, 1.2), Vector3(seg.y - seg.x, h, 0.2), Vector3.ZERO, wall)
	# A long runner of carpet, dim sconces.
	K.mesh(root, u + Vector3(0, 0.02, 0), Vector3(11.0, 0.03, 1.2), Art.material("fabric", Color(0.3, 0.04, 0.1)))
	for x: float in [-3.0, 1.0, 5.0]:
		K.glow(root, u + Vector3(x, 1.9, -1.15), Vector3(0.3, 0.12, 0.05), GOLD * 1.2)
		K.light(root, u + Vector3(x, 1.9, -0.8), GOLD, 0.35, 3.5)
	var dirt_ids := ["mirror", "guestbook", "reels"]
	for i in ROOM_XS.size():
		var c := u + Vector3(ROOM_XS[i], 0, 2.8)
		var col: Color = ROOM_COLORS[i]
		# The bed against the back wall, its sheets, a nightstand, the light.
		K.mesh(root, c + Vector3(0, 0.22, 0.6), Vector3(1.8, 0.44, 1.9), Art.material("fabric", Color(0.12, 0.08, 0.1)))
		K.mesh(root, c + Vector3(0, 0.47, 0.6), Vector3(1.74, 0.08, 1.84), Art.material("fabric", col.darkened(0.55)))
		K.mesh(root, c + Vector3(0, 0.56, 1.35), Vector3(1.4, 0.12, 0.35), Art.material("fabric", col.darkened(0.3)))
		K.mesh(root, c + Vector3(1.25, 0.28, 1.2), Vector3(0.45, 0.56, 0.4), Art.material("wood", Color(0.2, 0.12, 0.1)))
		K.mesh(root, c + Vector3(0, 1.6, 1.58), Vector3(1.2, 0.8, 0.03), Art.material("alloy", Color(0.75, 0.75, 0.82)))
		K.glow(root, c + Vector3(0, 2.7, 0.6), Vector3(1.6, 0.04, 0.06), col * 1.6)
		K.light(root, c + Vector3(0, 2.2, 0.4), col, 1.1, 4.0)
		var at := c + Vector3(0, 0, -0.6)
		match dirt_ids[i]:
			"mirror":
				at = c + Vector3(-0.6, 0, 0.0)
			"reels":
				at = c + Vector3(1.0, 0, 0.2)
		_dirt(info, dirt_ids[i], at)
	# The stair up at the west end, the gold door at the east end.
	var concrete := Art.material("concrete", Color(0.25, 0.22, 0.25))
	for k in 4:
		K.mesh(root, UNDER_STAIRS + Vector3(-0.4 - k * 0.1, 0.15 + k * 0.3, -0.6 + k * 0.0), Vector3(0.8, 0.3, 1.0), concrete)
	K.interactable(info, "undertow_up", UNDER_STAIRS, "[F] Stairs up to the street", ["The stair back up beside the Undertow."], 2.0)
	info["interactables"].back()["teleport"] = ROPE + Vector3(0, 0, -1.6)
	K.mesh(root, GOLD_DOOR_IN + Vector3(0.4, 1.1, 0), Vector3(0.08, 2.2, 1.1), Art.material("alloy", GOLD))
	K.glow(root, GOLD_DOOR_IN + Vector3(0.35, 2.3, 0), Vector3(0.04, 0.06, 1.1), GOLD * 2.0)
	K.interactable(info, "gold_door", GOLD_DOOR_IN, "[F] The gold door", ["A gold door at the end of the corridor. Music on the other side."], 1.8)
	info["interactables"].back()["teleport"] = GOLD_DOOR_OUT + Vector3(0, 0, 0.9)


## The high rollers' room: a stage with three brass poles, low sofas, a
## private card table, a bar with a safe, and Pip's chair on a step.
static func _high_rollers(root: Node3D, info: Dictionary) -> void:
	var r := HIGH
	_box(root, r, HIGH_SIZE, Color(0.12, 0.05, 0.08))
	K.mesh(root, r + Vector3(0, 0.02, 0), Vector3(HIGH_SIZE.x - 0.2, 0.03, HIGH_SIZE.z - 0.2), Art.material("fabric", Color(0.28, 0.03, 0.08)))
	# The stage along the north wall, lit from below, three poles on it.
	var stage := r + Vector3(0, 0, 2.6)
	K.carved(root, stage + Vector3(0, 0.25, 0), Vector3(6.0, 0.5, 2.2), Vector3.ZERO, Color(0.1, 0.08, 0.1))
	K.glow(root, stage + Vector3(0, 0.48, -1.12), Vector3(6.0, 0.04, 0.04), RED * 1.8)
	var brass := Art.material("gunmetal", Color(0.95, 0.75, 0.35))
	for x: float in [-2.0, 0.0, 2.0]:
		K.mesh(root, stage + Vector3(x, 0.5 + (HIGH_SIZE.y - 0.5) * 0.5, 0), Vector3(0.07, HIGH_SIZE.y - 0.5, 0.07), brass)
		K.mesh(root, stage + Vector3(x, 0.52, 0), Vector3(0.3, 0.04, 0.3), brass)
		K.light(root, stage + Vector3(x, 3.2, -0.4), MAGENTA_SOFT, 0.9, 3.5)
	# Sofas facing the stage.
	var velvet := Art.material("fabric", Color(0.35, 0.04, 0.1))
	for x: float in [-3.0, 0.0, 3.0]:
		K.mesh(root, r + Vector3(x, 0.25, 0.0), Vector3(1.8, 0.5, 0.8), velvet)
		K.mesh(root, r + Vector3(x, 0.65, -0.35), Vector3(1.8, 0.6, 0.15), velvet)
	# The card table in the west corner, chips still on it.
	var table := r + Vector3(-3.4, 0, -2.0)
	K.mesh(root, table + Vector3(0, 0.75, 0), Vector3(1.6, 0.06, 1.0), Art.material("canvas", Color(0.05, 0.3, 0.15)))
	K.mesh(root, table + Vector3(0, 0.37, 0), Vector3(0.3, 0.74, 0.3), Art.material("wood", Color(0.25, 0.14, 0.1)))
	for i in 5:
		K.mesh(root, table + Vector3(-0.5 + i * 0.22, 0.82, -0.1 + (i % 2) * 0.2), Vector3(0.08, 0.06 + i * 0.02, 0.08), Art.material("canvas", GOLD if i % 2 else RED))
	K.light(root, table + Vector3(0, 2.2, 0), GOLD, 0.8, 3.5)
	_dirt(info, "markers", table + Vector3(0.6, 0, -0.6))
	# The bar on the east wall, the safe behind it.
	var bar := r + Vector3(4.2, 0, -1.5)
	K.carved(root, bar + Vector3(0, 0.55, 0), Vector3(0.6, 1.1, 2.6), Vector3.ZERO, Color(0.2, 0.1, 0.08))
	K.glow(root, bar + Vector3(0.6, 1.6, 0), Vector3(0.04, 0.5, 2.0), GOLD * 0.8)
	K.mesh(root, bar + Vector3(0.6, 0.6, 0.8), Vector3(0.2, 0.6, 0.6), Art.material("gunmetal", Color(0.3, 0.3, 0.32)))
	_dirt(info, "safe", bar + Vector3(-0.9, 0, 0.8))
	# Pip's chair on a step by the door, facing the stage.
	var chair := r + Vector3(3.0, 0, -3.0)
	K.carved(root, chair + Vector3(0, 0.1, 0), Vector3(1.4, 0.2, 1.2), Vector3.ZERO, Color(0.15, 0.08, 0.08))
	K.mesh(root, chair + Vector3(0, 0.45, 0), Vector3(0.8, 0.5, 0.7), Art.material("fabric", Color(0.55, 0.42, 0.15)))
	K.mesh(root, chair + Vector3(0, 0.95, -0.3), Vector3(0.8, 1.0, 0.12), Art.material("fabric", Color(0.55, 0.42, 0.15)))
	K.light(root, chair + Vector3(0, 2.4, 0), GOLD, 0.5, 2.5)
	_dirt(info, "chair", chair + Vector3(-0.9, 0, 0.6))
	# The gold door back out to the Underfloor.
	K.mesh(root, GOLD_DOOR_OUT + Vector3(0, 1.1, -0.45), Vector3(1.1, 2.2, 0.08), Art.material("alloy", GOLD))
	K.interactable(info, "gold_door_back", GOLD_DOOR_OUT, "[F] Back through the gold door", ["The corridor of rooms."], 1.8)
	info["interactables"].back()["teleport"] = GOLD_DOOR_IN + Vector3(-0.9, 0, 0)


## The dancers' dressing room behind the stage: a row of mirrors ringed with
## bulbs, a couch, the stage door back. Empty after hours, like the rest.
static func _dressing(root: Node3D, info: Dictionary) -> void:
	var d := DRESSING
	_box(root, d, DRESSING_SIZE, Color(0.2, 0.12, 0.14))
	K.mesh(root, d + Vector3(0, 0.02, 0), Vector3(DRESSING_SIZE.x - 0.2, 0.03, DRESSING_SIZE.z - 0.2), Art.material("wood", Color(0.3, 0.2, 0.15)))
	# the mirrors along the north wall
	K.mesh(root, d + Vector3(-1.0, 0.75, 2.6), Vector3(5.0, 0.08, 0.6), Art.material("wood", Color(0.35, 0.22, 0.18)))
	K.mesh(root, d + Vector3(-1.0, 0.37, 2.6), Vector3(5.0, 0.74, 0.5), Art.material("wood", Color(0.25, 0.15, 0.12)))
	for k in 4:
		var x := -3.0 + k * 1.3
		K.mesh(root, d + Vector3(x, 1.55, 2.94), Vector3(1.0, 0.9, 0.03), Art.material("alloy", Color(0.75, 0.78, 0.85)))
		for b in 5:
			K.glow(root, d + Vector3(x - 0.5 + b * 0.25, 2.05, 2.9), Vector3(0.06, 0.06, 0.06), Color(1.0, 0.9, 0.7) * 1.6)
		K.mesh(root, d + Vector3(x, 0.45, 2.0), Vector3(0.4, 0.45, 0.4), Art.material("fabric", Color(0.5, 0.1, 0.2)))
	K.light(root, d + Vector3(-1.0, 2.2, 2.0), Color(1.0, 0.85, 0.65), 0.9, 5.0)
	# the couch
	K.mesh(root, d + Vector3(0, 0.25, -2.3), Vector3(2.0, 0.5, 0.8), Art.material("fabric", Color(0.35, 0.18, 0.3)))
	K.mesh(root, d + Vector3(0, 0.65, -2.65), Vector3(2.0, 0.6, 0.15), Art.material("fabric", Color(0.35, 0.18, 0.3)))
	K.light(root, d + Vector3(0, 2.2, -1.5), Color(1.0, 0.7, 0.6), 0.6, 4.0)
	# the stage doors, both ways
	K.mesh(root, STAGE_DOOR + Vector3(-0.42, 1.1, 0), Vector3(0.08, 2.2, 1.0), Art.material("wood", Color(0.12, 0.08, 0.08)))
	K.glow(root, STAGE_DOOR + Vector3(-0.38, 2.3, 0), Vector3(0.03, 0.08, 0.6), RED)
	K.interactable(info, "stage_door", STAGE_DOOR, "[F] The stage door", ["STAFF ONLY, on a door beside the stage."], 1.8)
	info["interactables"].back()["teleport"] = STAGE_DOOR_BACK + Vector3(-0.9, 0, 0)
	K.mesh(root, STAGE_DOOR_BACK + Vector3(0.42, 1.1, 0), Vector3(0.08, 2.2, 1.0), Art.material("wood", Color(0.12, 0.08, 0.08)))
	K.interactable(info, "stage_door_back", STAGE_DOOR_BACK, "[F] Back out to the stage", ["The high rollers' room."], 1.8)
	info["interactables"].back()["teleport"] = STAGE_DOOR + Vector3(0.9, 0, 0)


## The things lying about (HINTS), each something small to look at.
static func _hints(root: Node3D, info: Dictionary) -> void:
	for h in HINTS:
		var at: Vector3 = {"under": UNDER, "high": HIGH, "dress": DRESSING}[h[1]] + h[2]
		match h[0]:
			"rate_board":
				K.mesh(root, at + Vector3(0, 1.4, -0.15), Vector3(0.9, 0.6, 0.04), Art.material("canvas", Color(0.08, 0.1, 0.09)))
			"timers":
				K.mesh(root, at + Vector3(0, 0.38, 0), Vector3(0.7, 0.76, 0.4), Art.material("wood", Color(0.2, 0.12, 0.1)))
				for k in 3:
					K.mesh(root, at + Vector3(-0.2 + k * 0.2, 0.8, 0), Vector3(0.07, 0.07, 0.07), Art.material("canvas", (ROOM_COLORS[k] as Color).darkened(0.2)))
			"foil_bowl":
				K.mesh(root, at + Vector3(0, 0.9, 0), Vector3(0.2, 0.08, 0.2), Art.material("alloy", Color(0.75, 0.8, 0.85)))
				K.mesh(root, at + Vector3(0, 0.43, 0), Vector3(0.06, 0.86, 0.06), Art.material("gunmetal", GOLD))
			"linen_cart":
				K.mesh(root, at + Vector3(0, 0.45, 0), Vector3(0.9, 0.6, 0.5), Art.material("canvas", Color(0.3, 0.28, 0.3)))
				K.mesh(root, at + Vector3(0, 0.82, 0), Vector3(0.85, 0.2, 0.45), Art.material("fabric", Color(0.85, 0.82, 0.86)))
			"door_tags":
				K.glow(root, at + Vector3(0.5, 1.0, 0.2), Vector3(0.03, 0.12, 0.03), RED)
			"review_red", "review_violet", "review_blue":
				K.mesh(root, at + Vector3(0, 1.3, -0.19), Vector3(0.12, 0.17, 0.02), Art.material("canvas", Color(0.92, 0.88, 0.8)))
			"staff_rules":
				K.mesh(root, at + Vector3(0, 1.5, -0.38), Vector3(1.0, 0.7, 0.03), Art.material("wood", Color(0.45, 0.32, 0.22)))
			"staff_lockers":
				for k in 4:
					K.mesh(root, at + Vector3(-0.6 + k * 0.4, 0.9, -1.0), Vector3(0.38, 1.8, 0.4), Art.material("gunmetal", Color(0.3, 0.32, 0.36)))
			"staff_rack":
				K.mesh(root, at + Vector3(0, 1.6, 0), Vector3(0.04, 0.04, 1.6), Art.material("gunmetal", GOLD))
				for k in 6:
					K.mesh(root, at + Vector3(0, 1.1, -0.65 + k * 0.26), Vector3(0.1, 0.9, 0.22), Art.material("fabric", Color(0.18, 0.2, 0.17) if k % 2 else Color(0.5, 0.05, 0.12)))
			"staff_kettle":
				K.mesh(root, at + Vector3(0, 0.4, -0.3), Vector3(0.8, 0.8, 0.4), Art.material("wood", Color(0.2, 0.12, 0.1)))
				K.mesh(root, at + Vector3(0.2, 0.9, -0.3), Vector3(0.18, 0.2, 0.15), Art.material("alloy", Color(0.8, 0.8, 0.82)))
			"stage_card":
				K.mesh(root, at + Vector3(0, 0.675, 0.3), Vector3(0.25, 0.35, 0.02), Art.material("canvas", Color(0.05, 0.04, 0.05)))
			"tip_glass":
				K.mesh(root, at + Vector3(0, 0.58, 0.35), Vector3(0.14, 0.16, 0.14), Art.material("alloy", Color(0.85, 0.9, 0.95)))
			"house_rules":
				K.glow(root, at + Vector3(0, 1.5, 0.08), Vector3(0.5, 0.3, 0.02), GOLD * 0.9)
		K.interactable(info, h[0], at, h[3], h[4], 1.6)


const MAGENTA_SOFT := Color(1.0, 0.35, 0.7)


static func _dirt(info: Dictionary, id: String, pos: Vector3) -> void:
	K.interactable(info, "dirt_" + id, pos, DIRT[id]["prompt"], [DIRT[id]["text"]], 1.6)
	info["interactables"].back()["dirt"] = id
