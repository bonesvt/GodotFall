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
## Marrow is a shadow man (figure(), tools/hub/build_marrow.py).

const K := preload("res://scripts/hub/hub_kit.gd")
const Glass := preload("res://scripts/hub/glass.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")

const STREET_HALF := 7.0
## The alley gap on Low Row's west side, and the cellar door on its east.
const ALLEY := Vector3(-STREET_HALF + 0.9, 0, 203.75)
const CELLAR := Vector3(STREET_HALF - 1.1, 0, 213.3)
## The basement room's floor centre, under the town: deep enough that the
## hillside's terrain (down to about y -9 here) never reaches into it.
const BASEMENT := Vector3(-80.0, -30.0, 210.0)
const ROOM := Vector3(7.0, 3.0, 7.0)
## Where Eco comes to (his armchair) and where the stairs up are.
const WAKE := BASEMENT + Vector3(-1.9, 0, 1.4)
const STAIRS := BASEMENT + Vector3(2.4, 0, -2.6)
const VIOLET := Color(0.7, 0.35, 1.0)
## Marrow the shadow man (tools/hub/build_marrow.py), and where his ember sits
## in his cupped right hand standing and sitting.
const MARROW_MODEL := "res://assets/models/marrow/marrow.glb"
const EMBER_STAND := Vector3(0.22, 1.08, -0.23)
const EMBER_SIT := Vector3(0.22, 0.95, -0.23)
## His body: ink that light doesn't touch, his edges dissolving into noise that
## drifts upward with a thin violet glow, the coat's tatters stirring.
const SHADOW := "shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;
uniform vec3 rim = vec3(0.5, 0.22, 0.85);
varying vec3 wpos;
float h(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float n3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h(i), h(i + vec3(1, 0, 0)), f.x), mix(h(i + vec3(0, 1, 0)), h(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h(i + vec3(0, 0, 1)), h(i + vec3(1, 0, 1)), f.x), mix(h(i + vec3(0, 1, 1)), h(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
void vertex() {
	float low = clamp(1.0 - VERTEX.y / 1.2, 0.0, 1.0);
	VERTEX.x += sin(TIME * 1.1 + VERTEX.y * 3.0) * 0.008 + sin(TIME * 2.3 + VERTEX.z * 9.0) * 0.018 * low * low;
	VERTEX.z += cos(TIME * 1.7 + VERTEX.x * 8.0) * 0.018 * low * low;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.0);
	float n = n3(wpos * 7.0 + vec3(0.0, -TIME * 0.5, 0.0)) * 0.6 + n3(wpos * 17.0 + vec3(0.0, -TIME * 0.9, 0.0)) * 0.4;
	// light doesn't touch him: ink, with a thin violet glow only where he frays
	ALBEDO = vec3(0.004, 0.003, 0.007) + rim * pow(fres, 3.0) * n * 0.55;
	ALPHA = clamp(1.0 - smoothstep(0.55, 0.97, fres + n * 0.4 - 0.1), 0.0, 1.0);
}"
## The dark pooling under him, its edge creeping in and out.
const POOL := "shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
void fragment() {
	vec2 p = UV - 0.5;
	float a = atan(p.y, p.x);
	float wob = 0.06 * sin(a * 7.0 + TIME * 0.6) + 0.04 * sin(a * 13.0 - TIME * 1.1);
	float r = length(p) * 2.0;
	ALBEDO = vec3(0.0);
	ALPHA = (1.0 - smoothstep(0.35 + wob, 0.95 + wob, r)) * 0.85;
}"
static var _parts := {}
static var _parts_read := false
static var _mats := {}
## Her room: a separate sealed room (doors between them teleport), her cot,
## and her steel door's two sides.
const HER_ROOM := BASEMENT + Vector3(10.0, 0, 0)
const HER_SIZE := Vector3(3.6, 2.6, 3.6)
const HER_WAKE := HER_ROOM + Vector3(-0.9, 0, 0.6)
const HER_DOOR_IN := BASEMENT + Vector3(-2.9, 0, -0.6)
const HER_DOOR_OUT := HER_ROOM + Vector3(1.2, 0, -1.2)
## The Chorus (glass.gd): his ledger and his three Glass vats by the east wall.
const LEDGER := BASEMENT + Vector3(3.0, 0, 1.9)
const VATS := [BASEMENT + Vector3(3.0, 0, 0.6), BASEMENT + Vector3(3.0, 0, -0.5), BASEMENT + Vector3(-1.2, 0, -2.8)]
const LEDGER_TEXT := "A ledger under a colony seal. SOLACE TRIAL. Compound H: compliance confirmed in subject E. Compound G: combat yield up, crystallisation within losses. Phase three: the town's water and Seven Suns' stock. Payment on delivery: one town, docile, before the first frost. Marrow's not a dealer. He's a supplier, and Eco was the test."
const VAT_LOCKED_LINE := "Three tanks of something violet, brewing. Glass, by the smell. She'd like to know what it's for first."
## Under this Hold she still makes it to her own room.
const OWN_ROOM_BELOW := 30.0
## The back room he had made up for her, off the basement's north wall: a
## sealed room like hers (its door teleports), a narrow cot, and his IV stand.
const BACK_ROOM := BASEMENT + Vector3(-10.0, 0, 0)
const BACK_SIZE := Vector3(3.2, 2.5, 3.2)
const BACK_WAKE := BACK_ROOM + Vector3(-0.5, 0, 0.2)
const BACK_DOOR_IN := BASEMENT + Vector3(-1.0, 0, 3.2)
const BACK_DOOR_OUT := BACK_ROOM + Vector3(1.0, 0, -1.2)
## His bathroom, off the basement's west wall: grimy tiles, the toilet she
## comes to slumped against, a cracked mirror with smoke drifting in it, her
## phone on the floor. Sealed, its door teleports, like the others.
const BATH_ROOM := BASEMENT + Vector3(0, 0, -10.0)
const BATH_SIZE := Vector3(2.4, 2.4, 2.6)
const BATH_WAKE := BATH_ROOM + Vector3(-0.3, 0, 0.3)
const BATH_DOOR_IN := BASEMENT + Vector3(-3.2, 0, 2.3)
const BATH_DOOR_OUT := BATH_ROOM + Vector3(0.75, 0, -0.9)
const BATH_LINES := [
	"Eco comes to on cold tiles, slumped against a toilet in a bathroom she doesn't remember finding. Her phone's lit on the floor by her hand: 14 missed calls. Mom. In the mirror over the sink, smoke is drifting, though there's nothing in here to make it.",
	"The bathroom again. Her cheek on the toilet seat, the taste of violet in her mouth. 14 missed calls from Mom. Something in the mirror's smoke looks back at her, and then it's only smoke.",
]
## His storeroom, behind a door in the basement's north wall: shelves of his
## tins, a bare bulb, and by the door a pair of cuffs on a hook, open, unused.
## Its lock is on the inside: she locks herself in.
const STORE_ROOM := BASEMENT + Vector3(0, 0, 10.0)
const STORE_SIZE := Vector3(3.0, 2.5, 2.6)
const STORE_WAKE := STORE_ROOM + Vector3(-0.6, 0, 0.2)
const STORE_DOOR_IN := BASEMENT + Vector3(1.4, 0, 3.2)
const STORE_DOOR_OUT := STORE_ROOM + Vector3(1.1, 0, -0.8)
## She comes to there holding the key and an empty vial, the door locked from
## her side: she unlocked it once, then locked herself back in. Leaving is
## holding [F] while the Hush drags her eyes to the glow under the door
## (leave_pull.gd); from STORE_CANT_FROM Hold she can't finish until Marrow,
## through the door, has said his piece and gone back up (STORE_HE_GOES s).
const STORE_CANT_FROM := 70.0
const STORE_HE_GOES := 7.0
const STORE_LINE := "Eco comes to on the storeroom floor, the key in one hand and an empty Hush vial in the other. The door's locked from her side. She unlocked it once: there's a scratch by the lock where the key slipped. Then she locked herself back in. A pair of cuffs hangs open on a hook by the door."
const STORE_THROUGH_DOOR := "Marrow, through the door, close to it: \"I bought those for the first ones. I've never needed them for you.\""
const STORE_HE_LEAVES := "Footsteps on the stairs, going up. Her hand's steadier on the key with him gone."
const STORE_OUT := "The key turns. The violet under the door goes out as she opens it."
## The bathroom mirror: a dark murky glass with smoke drifting through it, and
## now and then two violet eyes in it for a moment.
const MIRROR := "shader_type spatial;
render_mode unshaded;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	vec2 uv = UV;
	vec2 q = uv * 2.5 + vec2(TIME * 0.03, -TIME * 0.12);
	q += vec2(n2(q * 1.3 + TIME * 0.05), n2(q * 1.3 - TIME * 0.04)) * 1.2;  // curled
	float smoke = n2(q) * 0.5 + n2(q * 2.1) * 0.3 + n2(q * 4.3) * 0.2;
	vec3 glass = mix(vec3(0.2, 0.22, 0.24), vec3(0.34, 0.36, 0.38), uv.y);
	vec3 col = mix(glass, vec3(0.04, 0.03, 0.06), smoothstep(0.4, 0.75, smoke) * 0.9);
	float look = step(0.86, fract(TIME * 0.07));
	for (int k = 0; k < 2; k++) {
		vec2 eye = vec2(0.42 + 0.16 * float(k), 0.42);
		col += vec3(0.7, 0.35, 1.0) * look * smoothstep(0.03, 0.0, length((uv - eye) * vec2(1.0, 2.2))) * 2.0;
	}
	col *= 0.85 + 0.15 * step(0.02, abs(uv.x - 0.3 - uv.y * 0.4));  // a crack across it
	ALBEDO = col;
}"
## From this Hold the drip's already in her arm when she comes to.
const BACK_TAPED_FROM := 60.0
## The Hold the drip puts in her while she's out.
const DRIP_HOLD := 6.0
const BACK_NOTE := "A note on the water glass, in violet ink: \"You're here so often now, I had a room made up. Come and go as you like. You always come back.\""
const BACK_CAPPED := "Eco comes to alone on a narrow cot in a room she's never seen. A blanket. A glass of water. Beside her, an IV stand, a bag of Hush glowing violet on its hook. The line's capped, coiled on the blanket. Waiting for her."
const BACK_TAPED := "Eco comes to alone on a narrow cot in a room she's never seen. There's tape on the inside of her arm. The line runs up to a bag of Hush glowing violet on its stand, half gone. She doesn't remember it going in. She peels the tape off. Her hand is steady. That's the worst part."
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
	var iv := _back_room(root, info)
	_bathroom(root, info)
	_storeroom(root, info)
	info["hush"] = {"wake": WAKE, "own_room": HER_WAKE, "back_room": BACK_WAKE, "street": CELLAR + Vector3(-1.2, 0, 0), "iv": iv}
	for id: String in ERRANDS:
		K.interactable(info, "errand_" + id, ERRANDS[id]["pos"], ERRANDS[id]["prompt"], [ERRANDS[id]["done"]], 2.0)
		info["interactables"].back()["errand"] = id  # only there while it's her errand (run_manager.gd)


## Which room she comes to in and what she finds, for his Hold `hold` and her
## `n`th trance: {pos, line, his, iv, locked} (his: she's at his, he takes a
## tab; iv: "capped" or "taped" when it's his back room; locked: his
## storeroom, locked from outside a while). Once she's a regular (from the
## third trance on, his Hold past her own room) it goes round four places:
## his armchair, slumped by the toilet in his bathroom, the cot in the back
## room he had made up for her, and locked in his storeroom.
static func wake(hold: float, n: int) -> Dictionary:
	if hold < OWN_ROOM_BELOW:
		return {"pos": HER_WAKE, "line": OWN_ROOM_LINES[n % OWN_ROOM_LINES.size()], "his": false}
	match n % 4 if n >= 2 else 0:
		1:
			return {"pos": BATH_WAKE, "line": BATH_LINES[(n / 4) % BATH_LINES.size()], "his": true}
		2:
			var taped := hold >= BACK_TAPED_FROM
			return {"pos": BACK_WAKE, "line": BACK_TAPED if taped else BACK_CAPPED, "his": true, "iv": "taped" if taped else "capped"}
		3:
			return {"pos": STORE_WAKE, "line": STORE_LINE, "his": true, "locked": true}
	if hold >= 60.0:
		return {"pos": WAKE, "line": DEEP_LINES[n % DEEP_LINES.size()], "his": true}
	return {"pos": WAKE, "line": WAKE_LINES[n % WAKE_LINES.size()], "his": true}


## The back room he had made up for her: bare cold concrete, a narrow cot with
## a blanket, a crate with a glass of water and his note, and an IV stand with
## a bag of Hush glowing violet. Its line two ways, one shown at a time
## (show_iv()): capped and coiled on the blanket, or running down to where her
## arm lay, a curl of tape on the end. Returns {capped, taped} nodes.
static func _back_room(root: Node3D, info: Dictionary) -> Dictionary:
	var r := BACK_ROOM
	var hw := BACK_SIZE.x * 0.5
	var hd := BACK_SIZE.z * 0.5
	var wall := Color(0.42, 0.42, 0.46)
	_concrete(root, r + Vector3(0, -0.25, 0), Vector3(BACK_SIZE.x + 0.6, 0.5, BACK_SIZE.z + 0.6), Vector3.ZERO, Color(0.44, 0.43, 0.46))
	_concrete(root, r + Vector3(0, BACK_SIZE.y + 0.25, 0), Vector3(BACK_SIZE.x + 0.6, 0.5, BACK_SIZE.z + 0.6), Vector3.ZERO, Color(0.34, 0.33, 0.37))
	for side in [-1.0, 1.0]:
		_concrete(root, r + Vector3(side * (hw + 0.15), BACK_SIZE.y * 0.5, 0), Vector3(0.3, BACK_SIZE.y, BACK_SIZE.z), Vector3.ZERO, wall)
		_concrete(root, r + Vector3(0, BACK_SIZE.y * 0.5, side * (hd + 0.15)), Vector3(BACK_SIZE.x, BACK_SIZE.y, 0.3), Vector3.ZERO, wall)
	# the cot: a narrow steel frame, a thin mattress, a grey blanket, a pillow
	var cot := BACK_WAKE + Vector3(-0.35, 0, 0.1)
	K.mesh(root, cot + Vector3(0, 0.36, 0), Vector3(0.72, 0.05, 1.9), Art.material("gunmetal", Color(0.3, 0.31, 0.33)))
	K.mesh(root, cot + Vector3(0, 0.43, 0), Vector3(0.68, 0.09, 1.85), Art.material("canvas", Color(0.7, 0.68, 0.64)))
	K.mesh(root, cot + Vector3(0, 0.49, -0.15), Vector3(0.7, 0.04, 1.25), Art.material("canvas", Color(0.55, 0.57, 0.64)))
	K.mesh(root, cot + Vector3(0, 0.52, 0.72), Vector3(0.5, 0.09, 0.32), Art.material("canvas", Color(0.85, 0.84, 0.82)))
	for x in [-0.32, 0.32]:
		for z in [-0.9, 0.9]:
			K.mesh(root, cot + Vector3(x, 0.17, z), Vector3(0.04, 0.34, 0.04), Art.material("gunmetal"))
	# a crate for a table: the water glass and his note
	var crate := cot + Vector3(0.75, 0, 0.55)
	K.mesh(root, crate + Vector3(0, 0.25, 0), Vector3(0.5, 0.5, 0.5), Art.material("wood", Color(0.5, 0.42, 0.32)))
	var glass := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.035
	cyl.bottom_radius = 0.03
	cyl.height = 0.12
	glass.mesh = cyl
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.8, 0.9, 1.0, 0.45)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.05
	glass.material_override = water
	glass.position = crate + Vector3(-0.1, 0.56, 0.05)
	root.add_child(glass)
	K.mesh(root, crate + Vector3(0.1, 0.505, -0.05), Vector3(0.15, 0.005, 0.11), Art.material("canvas", Color(0.95, 0.93, 0.88)))
	K.mesh(root, crate + Vector3(0.1, 0.509, -0.05), Vector3(0.1, 0.002, 0.004), Art.material("fabric", VIOLET))  # his violet ink
	K.interactable(info, "back_room_note", crate + Vector3(-0.3, 0, -0.2), "[F] Read the note", [BACK_NOTE], 1.4)
	# the IV stand: a steel pole on a five-legged foot, a hook, the bag glowing
	var stand := cot + Vector3(-0.6, 0, 0.5)
	K.mesh(root, stand + Vector3(0, 0.95, 0), Vector3(0.025, 1.9, 0.025), Art.material("alloy", Color(0.8, 0.82, 0.85)))
	for k in 5:
		var a := k * TAU / 5.0
		K.mesh(root, stand + Vector3(cos(a) * 0.14, 0.03, sin(a) * 0.14), Vector3(0.3, 0.02, 0.025), Art.material("alloy", Color(0.8, 0.82, 0.85)), Vector3(0, -rad_to_deg(a), 0))
	K.mesh(root, stand + Vector3(0, 1.9, 0), Vector3(0.22, 0.015, 0.015), Art.material("alloy", Color(0.8, 0.82, 0.85)))
	var bag := MeshInstance3D.new()
	var bm := CapsuleMesh.new()
	bm.radius = 0.06
	bm.height = 0.26
	bag.mesh = bm
	bag.scale = Vector3(1.0, 1.0, 0.5)
	var hush := StandardMaterial3D.new()
	hush.albedo_color = Color(0.6, 0.3, 0.9, 0.8)
	hush.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hush.emission_enabled = true
	hush.emission = VIOLET
	hush.emission_energy_multiplier = 2.2
	bag.material_override = hush
	bag.position = stand + Vector3(0.09, 1.74, 0)
	root.add_child(bag)
	K.light(root, stand + Vector3(0.15, 1.6, -0.1), VIOLET, 0.8, 3.5)
	K.light(root, r + Vector3(0.5, 2.3, -0.3), Color(0.85, 0.88, 1.0), 0.35, 4.0)  # a bare bulb, dim
	var line := Art.material("alloy", Color(0.75, 0.6, 0.95))
	var drip := bag.position + Vector3(0, -0.15, 0)
	# capped: the line down to the blanket, coiled there, its end capped
	var capped := Node3D.new()
	root.add_child(capped)
	var coil := cot + Vector3(-0.1, 0.52, 0.1)
	_tube(capped, drip, coil + Vector3(-0.15, 0, 0.1), line)
	for k in 10:
		var a0 := k * TAU / 5.0
		var a1 := (k + 1) * TAU / 5.0
		var rr := 0.09 - k * 0.004
		_tube(capped, coil + Vector3(cos(a0) * rr, 0.01 * k * 0.1, sin(a0) * rr), coil + Vector3(cos(a1) * rr, 0.01 * (k + 1) * 0.1, sin(a1) * rr), line)
	K.mesh(capped, coil + Vector3(0.05, 0.015, 0.0), Vector3(0.025, 0.025, 0.05), Art.material("gunmetal", Color(0.9, 0.3, 0.3)))
	# taped: the line down to where her left arm lay, a curl of tape on its end
	var taped := Node3D.new()
	root.add_child(taped)
	var arm := cot + Vector3(-0.22, 0.53, 0.05)
	_tube(taped, drip, arm + Vector3(0, 0.25, 0.1), line)
	_tube(taped, arm + Vector3(0, 0.25, 0.1), arm, line)
	K.mesh(taped, arm + Vector3(0, 0.005, 0), Vector3(0.07, 0.006, 0.05), Art.material("canvas", Color(0.95, 0.94, 0.9)))
	taped.visible = false
	# the doors: the steel one in, and its outside on the basement's north wall
	K.mesh(root, BACK_DOOR_OUT + Vector3(0.45, 1.05, 0), Vector3(0.08, 2.1, 1.0), Art.material("gunmetal", Color(0.3, 0.3, 0.33)))
	K.interactable(info, "back_room_door", BACK_DOOR_OUT, "[F] Back out to the basement", ["The door isn't locked. He wants her to know that."], 1.8)
	info["interactables"].back()["teleport"] = BACK_DOOR_IN + Vector3(0, 0, -0.9)
	K.mesh(root, BACK_DOOR_IN + Vector3(0, 1.05, 0.25), Vector3(1.0, 2.1, 0.08), Art.material("gunmetal", Color(0.3, 0.3, 0.33)))
	K.interactable(info, "back_room", BACK_DOOR_IN, "[F] The back room", ["A plain steel door that wasn't there before."], 1.6)
	info["interactables"].back()["teleport"] = BACK_DOOR_OUT + Vector3(-0.9, 0, 0)
	return {"capped": capped, "taped": taped}


## Four walls, floor and ceiling of a sealed room `size` at `at`.
static func _shell(root: Node3D, at: Vector3, size: Vector3, wall: Color, floor_tint: Color) -> void:
	var hw := size.x * 0.5
	var hd := size.z * 0.5
	_concrete(root, at + Vector3(0, -0.25, 0), Vector3(size.x + 0.6, 0.5, size.z + 0.6), Vector3.ZERO, floor_tint)
	_concrete(root, at + Vector3(0, size.y + 0.25, 0), Vector3(size.x + 0.6, 0.5, size.z + 0.6), Vector3.ZERO, wall.darkened(0.25))
	for side in [-1.0, 1.0]:
		_concrete(root, at + Vector3(side * (hw + 0.15), size.y * 0.5, 0), Vector3(0.3, size.y, size.z), Vector3.ZERO, wall)
		_concrete(root, at + Vector3(0, size.y * 0.5, side * (hd + 0.15)), Vector3(size.x, size.y, 0.3), Vector3.ZERO, wall)


## His bathroom: grimy pale-green tiles, a stained toilet she comes to slumped
## against, a sink with a cracked mirror full of drifting smoke (MIRROR), a
## flickering strip light, and her phone on the floor lit with Mom's
## missed calls.
static func _bathroom(root: Node3D, info: Dictionary) -> void:
	var r := BATH_ROOM
	_shell(root, r, BATH_SIZE, Color(0.52, 0.58, 0.52), Color(0.4, 0.42, 0.38))
	var tile := Art.material("pavers", Color(0.62, 0.68, 0.6))
	K.mesh(root, r + Vector3(0, 0.6, BATH_SIZE.z * 0.5 - 0.02), Vector3(BATH_SIZE.x, 1.2, 0.03), tile)  # tiled to waist height
	K.mesh(root, r + Vector3(-BATH_SIZE.x * 0.5 + 0.02, 0.6, 0), Vector3(0.03, 1.2, BATH_SIZE.z), tile)
	# grime: dark stains down the tiles and round the floor drain
	for k in 5:
		K.mesh(root, r + Vector3(-0.9 + k * 0.4, 0.4 + 0.1 * (k % 2), BATH_SIZE.z * 0.5 - 0.04), Vector3(0.1 + 0.05 * (k % 3), 0.5, 0.01), Art.material("dirt", Color(0.25, 0.22, 0.15)))
	K.mesh(root, r + Vector3(0.2, 0.005, -0.1), Vector3(0.5, 0.005, 0.5), Art.material("dirt", Color(0.2, 0.18, 0.12)))
	# the toilet, against the back wall, she's slumped against it
	var wc := r + Vector3(-0.55, 0, 0.95)
	var porcelain := Art.material("alloy", Color(0.9, 0.9, 0.86))
	_round(root, wc + Vector3(0, 0.19, -0.04), 0.17, 0.13, 0.38, porcelain)  # the bowl, narrowing to its foot
	var seat := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.12
	ring.outer_radius = 0.2
	seat.mesh = ring
	seat.material_override = Art.material("alloy", Color(0.78, 0.74, 0.62))  # stained
	seat.scale = Vector3(1, 0.25, 1.15)
	seat.position = wc + Vector3(0, 0.4, -0.04)
	root.add_child(seat)
	K.mesh(root, wc + Vector3(0, 0.62, 0.2), Vector3(0.42, 0.42, 0.16), porcelain)  # the tank
	K.mesh(root, wc + Vector3(0, 0.84, 0.2), Vector3(0.45, 0.04, 0.19), porcelain)  # its lid
	# the sink and the mirror over it
	var sink := r + Vector3(0.5, 0, 1.05)
	K.mesh(root, sink + Vector3(0, 0.82, 0), Vector3(0.5, 0.14, 0.38), porcelain)
	_round(root, sink + Vector3(0, 0.875, -0.02), 0.15, 0.15, 0.02, Art.material("gunmetal", Color(0.25, 0.25, 0.25)))  # the basin, dark
	K.mesh(root, sink + Vector3(0, 0.4, 0.1), Vector3(0.08, 0.8, 0.08), Art.material("gunmetal"))
	var mirror := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.55, 0.7)
	mirror.mesh = quad
	mirror.material_override = _shader_mat("mirror", MIRROR)
	mirror.position = sink + Vector3(0, 1.45, 0.215)
	mirror.rotation_degrees.y = 180.0  # facing into the room
	root.add_child(mirror)
	K.mesh(root, sink + Vector3(0, 1.45, 0.235), Vector3(0.62, 0.78, 0.02), Art.material("gunmetal", Color(0.3, 0.3, 0.3)))  # its frame
	# her phone on the floor by her hand, lit with the calls
	var phone := r + Vector3(-0.1, 0.012, 0.3)
	K.mesh(root, phone, Vector3(0.08, 0.01, 0.15), Art.material("gunmetal", Color(0.1, 0.1, 0.12)))
	var screen := Label3D.new()
	screen.text = "14 missed calls\nMom"
	screen.font_size = 18
	screen.pixel_size = 0.0012
	screen.modulate = Color(0.85, 0.95, 1.0)
	screen.outline_size = 0
	screen.position = phone + Vector3(0, 0.012, 0)
	screen.rotation_degrees = Vector3(-90, 0, 0)
	root.add_child(screen)
	K.light(root, r + Vector3(0, 2.2, 0), Color(0.8, 0.95, 0.85), 0.5, 3.5)  # the strip light, sick and green
	K.interactable(info, "bath_phone", phone + Vector3(0.3, 0, -0.2), "[F] Your phone", [
		"14 missed calls. Mom. Mom. Mom. Mom. The last one was an hour ago. No voicemail on that one.",
	], 1.2)
	K.mesh(root, BATH_DOOR_OUT + Vector3(0.41, 1.0, 0), Vector3(0.06, 2.0, 0.85), Art.material("wood", Color(0.4, 0.34, 0.28)))
	K.interactable(info, "bath_door", BATH_DOOR_OUT, "[F] Back out to the basement", ["The bathroom door sticks, then gives."], 1.6)
	info["interactables"].back()["teleport"] = BATH_DOOR_IN + Vector3(0.9, 0, 0)
	K.mesh(root, BATH_DOOR_IN + Vector3(-0.15, 1.0, 0), Vector3(0.08, 2.0, 0.85), Art.material("wood", Color(0.4, 0.34, 0.28)))
	K.interactable(info, "bathroom", BATH_DOOR_IN + Vector3(0.3, 0, 0), "[F] The bathroom", ["A narrow wooden door. It smells of bleach and violet."], 1.4)
	info["interactables"].back()["teleport"] = BATH_DOOR_OUT + Vector3(-0.8, 0, 0)


## His storeroom: shelves of his tins, a bare bulb, crates, and by the door a
## pair of cuffs hanging on a hook, open; the empty vial she dropped, and violet
## light glowing under the door from his basement. The door's a "locked_wake"
## spot: after coming to here she has to hold to leave (leave_pull.gd).
static func _storeroom(root: Node3D, info: Dictionary) -> void:
	var r := STORE_ROOM
	_shell(root, r, STORE_SIZE, Color(0.4, 0.38, 0.36), Color(0.38, 0.36, 0.34))
	# shelves of tins along the back wall
	for row in 3:
		var y := 0.45 + row * 0.6
		K.mesh(root, r + Vector3(-0.2, y, STORE_SIZE.z * 0.5 - 0.25), Vector3(2.2, 0.04, 0.4), Art.material("wood", Color(0.45, 0.36, 0.28)))
		for k in 7:
			K.mesh(root, r + Vector3(-1.1 + k * 0.3, y + 0.08, STORE_SIZE.z * 0.5 - 0.25), Vector3(0.12, 0.12, 0.12), Art.material("alloy", Color(0.55, 0.4, 0.7)))
	for x in [-1.25, 0.85]:
		K.mesh(root, r + Vector3(x, 1.0, STORE_SIZE.z * 0.5 - 0.25), Vector3(0.05, 2.0, 0.4), Art.material("wood", Color(0.4, 0.32, 0.25)))
	K.mesh(root, r + Vector3(-1.0, 0.3, -0.7), Vector3(0.6, 0.6, 0.6), Art.material("wood", Color(0.5, 0.42, 0.3)))
	K.mesh(root, r + Vector3(-0.4, 0.25, -0.85), Vector3(0.5, 0.5, 0.5), Art.material("wood", Color(0.48, 0.4, 0.3)))
	K.light(root, r + Vector3(0, 2.2, 0), Color(1.0, 0.85, 0.6), 0.8, 4.0)
	K.light(root, STORE_DOOR_OUT + Vector3(-0.2, 2.0, 0.6), Color(1.0, 0.85, 0.6), 0.6, 2.0)  # over the door
	# the cuffs on their hook, beside the door: open, hanging, never used
	var hook := STORE_DOOR_OUT + Vector3(0.37, 1.5, 0.75)  # on the wall (its inside face is 0.4 past the door spot)
	K.mesh(root, hook, Vector3(0.04, 0.04, 0.08), Art.material("gunmetal"))
	var steel := Art.material("alloy", Color(0.75, 0.77, 0.8))
	for s in [-1.0, 1.0]:
		var ring := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = 0.04
		t.outer_radius = 0.052
		ring.mesh = t
		ring.material_override = steel
		ring.position = hook + Vector3(-0.05, -0.16, 0.055 * s)
		ring.rotation_degrees = Vector3(10 * s, 0, 90)  # hanging flat to the wall, facing into the room
		root.add_child(ring)
	K.mesh(root, hook + Vector3(-0.03, -0.07, 0), Vector3(0.01, 0.1, 0.012), steel)  # the chain
	# the door: steel, its lock and keyhole on this side, violet glowing under it
	K.mesh(root, STORE_DOOR_OUT + Vector3(0.36, 1.07, 0), Vector3(0.06, 2.06, 1.0), Art.material("gunmetal", Color(0.55, 0.55, 0.58)))
	K.mesh(root, STORE_DOOR_OUT + Vector3(0.31, 1.05, -0.32), Vector3(0.04, 0.2, 0.12), Art.material("alloy", Color(0.8, 0.7, 0.45)))  # the lock
	K.mesh(root, STORE_DOOR_OUT + Vector3(0.288, 1.0, -0.32), Vector3(0.01, 0.025, 0.012), Art.material("gunmetal", Color(0.05, 0.05, 0.05)))  # its keyhole
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(0.92, 0.75, 1.0)
	K.mesh(root, STORE_DOOR_OUT + Vector3(0.31, 0.012, 0), Vector3(0.05, 0.02, 0.96), glow)
	K.light(root, STORE_DOOR_OUT + Vector3(0.25, 0.06, 0), VIOLET, 1.8, 2.2)  # spilling across the floor
	# the vial she emptied, on the floor where she came to
	var vial := MeshInstance3D.new()
	var vm := CylinderMesh.new()
	vm.top_radius = 0.012
	vm.bottom_radius = 0.012
	vm.height = 0.07
	vial.mesh = vm
	var vg := StandardMaterial3D.new()
	vg.albedo_color = Color(0.8, 0.7, 1.0, 0.5)
	vg.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	vial.material_override = vg
	vial.position = STORE_WAKE + Vector3(0.25, 0.012, -0.15)
	vial.rotation_degrees = Vector3(0, 30, 90)
	root.add_child(vial)
	K.interactable(info, "store_door", STORE_DOOR_OUT, "[F] The door", ["It opens."], 1.8)
	info["interactables"].back()["teleport"] = STORE_DOOR_IN + Vector3(0, 0, -0.9)
	info["interactables"].back()["locked_wake"] = true
	K.mesh(root, STORE_DOOR_IN + Vector3(0, 1.05, 0.25), Vector3(1.0, 2.1, 0.08), Art.material("gunmetal", Color(0.33, 0.33, 0.35)))
	K.interactable(info, "storeroom", STORE_DOOR_IN, "[F] The storeroom", ["A steel door. Its lock's on the inside."], 1.6)
	info["interactables"].back()["teleport"] = STORE_DOOR_OUT + Vector3(-0.9, 0, 0)


## Which way the back room's line is: "capped" on the blanket or "taped" to
## where her arm was (hush_den.gd wake()), on the nodes _back_room() returned.
static func show_iv(iv: Dictionary, how: String) -> void:
	for k in ["capped", "taped"]:
		if iv.has(k) and is_instance_valid(iv[k]):
			(iv[k] as Node3D).visible = k == how


## A round, tapering solid (bowl, basin): radius r0 at the top, r1 at the foot.
static func _round(root: Node3D, at: Vector3, r0: float, r1: float, h: float, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r0
	c.bottom_radius = r1
	c.height = h
	mi.mesh = c
	mi.material_override = m
	mi.position = at
	root.add_child(mi)


## A thin tube from a to b (the IV line).
static func _tube(parent: Node3D, a: Vector3, b: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.004
	c.bottom_radius = 0.004
	c.height = maxf(a.distance_to(b), 0.001)
	c.radial_segments = 8
	c.rings = 1
	mi.mesh = c
	mi.material_override = m
	mi.position = (a + b) * 0.5
	var dir := (b - a).normalized()
	if absf(dir.dot(Vector3.UP)) < 0.999:
		mi.basis = Basis(Vector3.UP.cross(dir).normalized(), Vector3.UP.angle_to(dir))
	parent.add_child(mi)


## Her room: walls she patched, a cot, her tools, Dad's photo, a warm lamp,
## and the inside of the steel door she welded the lock onto.
static func _her_room(root: Node3D, info: Dictionary) -> void:
	var r := HER_ROOM
	var hw := HER_SIZE.x * 0.5
	var hd := HER_SIZE.z * 0.5
	var wall := Color(0.55, 0.52, 0.48)
	_concrete(root, r + Vector3(0, -0.25, 0), Vector3(HER_SIZE.x + 0.6, 0.5, HER_SIZE.z + 0.6), Vector3.ZERO, Color(0.5, 0.47, 0.44))
	_concrete(root, r + Vector3(0, HER_SIZE.y + 0.25, 0), Vector3(HER_SIZE.x + 0.6, 0.5, HER_SIZE.z + 0.6), Vector3.ZERO, Color(0.4, 0.38, 0.36))
	for side in [-1.0, 1.0]:
		_concrete(root, r + Vector3(side * (hw + 0.15), HER_SIZE.y * 0.5, 0), Vector3(0.3, HER_SIZE.y, HER_SIZE.z), Vector3.ZERO, wall)
		_concrete(root, r + Vector3(0, HER_SIZE.y * 0.5, side * (hd + 0.15)), Vector3(HER_SIZE.x, HER_SIZE.y, 0.3), Vector3.ZERO, wall)
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
	_marrow(info, figure(root, ALLEY + Vector3(-0.6, 0, -0.2), -90.0))  # facing out onto Low Row
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


## A solid slab of the basement's concrete (floor, wall, ceiling). Not the
## hub kit's carved(), which builds in whatever style the hub was last set to.
static func _concrete(root: Node3D, pos: Vector3, size: Vector3, _rot := Vector3.ZERO, tint := Color.WHITE) -> StaticBody3D:
	var body: StaticBody3D = K.Kit.box(root, pos, size, K.STONE, Vector3.ZERO, Art.material("concrete", tint))
	body.set_meta("surface", "stone")  # footstep sounds (player.gd)
	return body


static func _basement(root: Node3D, info: Dictionary) -> void:
	var b := BASEMENT
	var hw := ROOM.x * 0.5
	var hd := ROOM.z * 0.5
	var concrete := Art.material("concrete", Color(0.42, 0.4, 0.44))
	# Floor, ceiling and four walls, all solid, so it's sealed.
	_concrete(root, b + Vector3(0, -0.25, 0), Vector3(ROOM.x + 0.6, 0.5, ROOM.z + 0.6), Vector3.ZERO, Color(0.5, 0.48, 0.52))
	_concrete(root, b + Vector3(0, ROOM.y + 0.25, 0), Vector3(ROOM.x + 0.6, 0.5, ROOM.z + 0.6), Vector3.ZERO, Color(0.35, 0.33, 0.38))
	for side in [-1.0, 1.0]:
		_concrete(root, b + Vector3(side * (hw + 0.15), ROOM.y * 0.5, 0), Vector3(0.3, ROOM.y, ROOM.z), Vector3.ZERO, Color(0.45, 0.43, 0.47))
		_concrete(root, b + Vector3(0, ROOM.y * 0.5, side * (hd + 0.15)), Vector3(ROOM.x, ROOM.y, 0.3), Vector3.ZERO, Color(0.45, 0.43, 0.47))
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
	_marrow(info, figure(root, b + Vector3(0.6, 0.0, -1.45), 0.0, true))
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
	_glass_works(root, info)


## Marrow's figures, so the hub can take him away once the Chorus breaks (glass.gd).
static func _marrow(info: Dictionary, f: Node3D) -> void:
	if not info.has("marrow_figures"):
		info["marrow_figures"] = []
	info["marrow_figures"].append(f)


## The Chorus (glass.gd), along the basement's east wall: his ledger on a
## lectern and three vats of Glass brewing, only there once he's begun dosing
## the town (the run manager hides them till then: info["glass_nodes"]).
static func _glass_works(root: Node3D, info: Dictionary) -> void:
	var nodes := {}
	var lectern := Node3D.new()
	lectern.position = LEDGER
	root.add_child(lectern)
	K.mesh(lectern, Vector3(0, 0.5, 0), Vector3(0.45, 1.0, 0.4), Art.material("wood", Color(0.35, 0.26, 0.2)))
	K.mesh(lectern, Vector3(0, 1.04, 0), Vector3(0.5, 0.06, 0.38), Art.material("canvas", Color(0.88, 0.84, 0.72)), Vector3(-15, 0, 0))
	K.mesh(lectern, Vector3(0.12, 1.08, 0.02), Vector3(0.12, 0.02, 0.08), Art.material("alloy", Color(0.85, 0.3, 0.25)))  # the colony's seal
	nodes["ledger"] = lectern
	K.interactable(info, "glass_ledger", LEDGER + Vector3(-0.6, 0, 0), "[F] Marrow's ledger", [LEDGER_TEXT], 1.6)
	info["interactables"].back()["glass"] = "ledger"
	for i in VATS.size():
		var vat := Node3D.new()
		vat.position = VATS[i]
		root.add_child(vat)
		K.mesh(vat, Vector3(0, 0.08, 0), Vector3(0.9, 0.16, 0.9), Art.material("gunmetal", Color(0.2, 0.2, 0.22)))
		var glow := MeshInstance3D.new()
		var tank := CylinderMesh.new()
		tank.top_radius = 0.34
		tank.bottom_radius = 0.34
		tank.height = 1.3
		glow.mesh = tank
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.55, 0.25, 0.85, 0.75)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = VIOLET
		mat.emission_energy_multiplier = 1.6
		glow.material_override = mat
		glow.position.y = 0.81
		glow.name = "Tank"
		vat.add_child(glow)
		K.mesh(vat, Vector3(0, 1.5, 0), Vector3(0.75, 0.08, 0.75), Art.material("gunmetal", Color(0.25, 0.25, 0.27)))
		var shards := Node3D.new()  # what's left once she's smashed it
		shards.name = "Shards"
		shards.visible = false
		vat.add_child(shards)
		for k in 6:
			var a := k * TAU / 6.0
			K.mesh(shards, Vector3(cos(a) * 0.3, 0.2 + 0.1 * (k % 2), sin(a) * 0.3), Vector3(0.05, 0.3 + 0.1 * (k % 3), 0.12),
					Art.material("alloy", VIOLET), Vector3(20 * (k % 2), a * 57.0, 15))
		K.mesh(shards, Vector3(0, 0.17, 0), Vector3(1.2, 0.01, 1.0), Art.material("fabric", Color(0.45, 0.2, 0.65)))
		var id: String = Glass.VAT_IDS[i]
		nodes[id] = vat
		var front: Vector3 = (BASEMENT - VATS[i]) * Vector3(1, 0, 1)
		K.interactable(info, "glass_" + id, VATS[i] + front.normalized() * 0.8, "[F] Smash the vat", [VAT_LOCKED_LINE], 1.4)
		info["interactables"].back()["glass"] = id
	K.light(root, VATS[1] + Vector3(-0.5, 1.8, 0), VIOLET, 0.9, 4.0)
	info["glass_nodes"] = nodes


## Marrow: a shadow man (tools/hub/build_marrow.py), too tall and too thin, a
## long coat tattering at the floor, a deep hood with only two violet eyes in
## it, long fingers cupping a violet Hush ember. His edges never hold still:
## they dissolve into drifting dark (SHADOW), smoke rises off him, his
## tendrils run out across the floor into a pool of dark under him (POOL), and
## the ember lights him from below. `sitting` sinks him into his chair.
## Without the model, a primitive stand-in.
static func figure(root: Node3D, pos: Vector3, yaw: float, sitting := false) -> Node3D:
	var f := Node3D.new()
	f.position = pos
	f.rotation_degrees.y = yaw
	root.add_child(f)
	var pose := "sit" if sitting else "stand"
	var parts := _shadow_parts()
	if parts.has(pose):
		for p in parts[pose]:
			var mi := MeshInstance3D.new()
			mi.mesh = p[0]
			mi.transform = p[1]
			mi.material_override = _shadow_mat() if p[2] == "shadow" else _eye_mat()
			if p[2] == "eyes":
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			f.add_child(mi)
		_ember(f, EMBER_SIT if sitting else EMBER_STAND)
		_smoke(f, sitting)
		_pool(f, Vector3(0, 0.012, -0.3 if sitting else 0.0))
		return f
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


## The modelled shadow man: pose -> [[mesh, transform, "shadow"|"eyes"], ...].
static func _shadow_parts() -> Dictionary:
	if _parts_read:
		return _parts
	_parts_read = true
	if not ResourceLoader.exists(MARROW_MODEL):
		return _parts
	var inst := (load(MARROW_MODEL) as PackedScene).instantiate()
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var bits := String(mi.name).split("__")
		if bits.size() < 2:
			continue
		var key := "eyes" if bits[1].begins_with("eyes") else "shadow"
		if not _parts.has(bits[0]):
			_parts[bits[0]] = []
		_parts[bits[0]].append([(mi as MeshInstance3D).mesh, (mi as Node3D).transform, key])
	inst.free()
	return _parts


static func _shader_mat(key: String, code: String) -> ShaderMaterial:
	if not _mats.has(key):
		var sh := Shader.new()
		sh.code = code
		var m := ShaderMaterial.new()
		m.shader = sh
		_mats[key] = m
	return _mats[key]


static func _shadow_mat() -> ShaderMaterial:
	return _shader_mat("shadow", SHADOW)


static func _eye_mat() -> StandardMaterial3D:
	if not _mats.has("eyes"):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.85, 0.6, 1.0)
		m.emission_enabled = true
		m.emission = VIOLET
		m.emission_energy_multiplier = 5.0
		_mats["eyes"] = m
	return _mats["eyes"]


## His Hush ember, cupped in his right hand, lighting him violet from below.
static func _ember(f: Node3D, at: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.022
	s.height = 0.044
	mi.mesh = s
	mi.material_override = _eye_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at
	f.add_child(mi)
	var lamp := OmniLight3D.new()
	lamp.light_color = VIOLET
	lamp.light_energy = 0.9
	lamp.omni_range = 2.4
	lamp.position = at + Vector3(0, 0.05, -0.06)
	f.add_child(lamp)


## Smoke rising off him all the time, black and slow.
static func _smoke(f: Node3D, sitting: bool) -> void:
	var p := GPUParticles3D.new()
	p.amount = 40
	p.lifetime = 3.2
	p.position = Vector3(0, 0.75 if sitting else 1.05, 0.05)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.22, 0.45 if sitting else 0.8, 0.18)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 20.0
	pm.initial_velocity_min = 0.06
	pm.initial_velocity_max = 0.22
	pm.gravity = Vector3(0, 0.04, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 1.0))
	var gt := CurveTexture.new()
	gt.curve = grow
	pm.scale_curve = gt
	var fade := Gradient.new()
	fade.set_color(0, Color(0.01, 0.0, 0.02, 0.0))
	fade.set_color(1, Color(0.0, 0.0, 0.0, 0.0))
	fade.add_point(0.3, Color(0.02, 0.01, 0.035, 0.5))
	var ft := GradientTexture1D.new()
	ft.gradient = fade
	pm.color_ramp = ft
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.4, 0.4)
	var puff := StandardMaterial3D.new()
	puff.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	puff.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff.vertex_color_use_as_albedo = true  # the fade in and out
	puff.albedo_color = Color(0.015, 0.008, 0.025)  # and black, whatever the ramp gives
	var soft := GradientTexture2D.new()
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	soft.gradient = g
	puff.albedo_texture = soft
	quad.material = puff
	p.draw_pass_1 = quad
	f.add_child(p)


## A pool of dark under him, its edge creeping.
static func _pool(f: Node3D, at: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.6, 2.6)
	mi.mesh = plane
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.material_override = _shader_mat("pool", POOL)
	f.add_child(mi)


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
