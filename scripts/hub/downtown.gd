extends RefCounted
## Downtown: Solace's shady street, off the far end of Low Row. Pip, Eco's
## older sister, runs it. She picked the shady life over the heroic one the
## year Dad started flying for the town, and Downtown is what she built with
## it: the Velvet Ace (a casino) and the Undertow (a club), and every secret
## that passes through either.
##
##   x 7..9      the arch over the mouth of the street, DOWNTOWN in neon
##   x 7..16     a lane between the cinema's back wall and the garden terrace
##   x 20..34    the Velvet Ace on the north side: the Gilded Reels (casino_screen.gd)
##   x 35..46    the Undertow on the north side: Pip's booth (club_screen.gd)
##   south side  the terrace's retaining wall, papered with the house's ads
##
## Pip stands at one of three spots each hub stay (place_pip): the casino door
## in her warden's mesh, the club door in her rave fit, or under the arch in
## her cropped waistcoat or her shorts. Under Teen the mesh becomes the waistcoat.
##
## What she sells at the booth (Mature and Teen alike) is a secret: intel for
## the next run, one at a time, like a meal from Seven Suns (town_shops.gd
## boosts() adds it in). Every secret bought turns a page of her ledger
## (LEDGER): what Downtown knows about Solace, the colony and Dad.
## The Velvet Ace's reels are Mature only, like the Halo's cards.

const K := preload("res://scripts/hub/hub_kit.gd")
const Kit := preload("res://scripts/run/level_kit.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")
const TP := preload("res://scripts/hub/town_props.gd")
const Armory := preload("res://scripts/hub/armory.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")
const Below := preload("res://scripts/hub/downtown_below.gd")

## The street runs east along z from the end of Low Row (x = X0) to the town's east fence.
const Z0 := 214.0
const Z1 := 220.0
const X0 := 7.0
const X1 := 47.5
const STREET := Rect2(X0, Z0, X1 - X0, Z1 - Z0)
const CASINO_X := 27.0
const CLUB_X := 40.5

const GOLD := Color(1.0, 0.72, 0.25)
const WINE := Color(0.85, 0.12, 0.3)
const MAGENTA := Color(1.0, 0.25, 0.75)
const CYAN := Color(0.25, 0.95, 1.0)
const LIME := Color(0.6, 1.0, 0.35)

## Where Pip stands, in turn by hub stay: [spot, position, yaw, outfit].
## After hours she holds court in the high rollers' room (downtown_below.gd).
const PIP_SPOTS := [
	["casino", Vector3(CASINO_X - 2.6, 0, Z1 - 1.3), 60.0, "warden"],
	["club", Vector3(CLUB_X - 2.4, 0, Z1 - 1.2), 55.0, "rave"],
	["arch", Vector3(X0 + 3.2, 0, Z0 + 1.2), 100.0, "crop"],
	["casino", Vector3(CASINO_X - 2.6, 0, Z1 - 1.3), 60.0, "shorts"],
	["high_rollers", Below.HIGH + Vector3(2.0, 0, -2.6), 200.0, "afterhours"],
]

static var save_path := "user://downtown.cfg"


# --- the street ---------------------------------------------------------------

static func build(root: Node3D, info: Dictionary) -> void:
	var T = load("res://scripts/hub/town.gd")
	var street := Node3D.new()
	street.name = "Downtown"
	root.add_child(street)
	# Wet black paving, gold gutter lights down the casino side, magenta down the wall.
	K.mesh(street, Vector3((X0 + X1) * 0.5, 0.065, (Z0 + Z1) * 0.5), Vector3(X1 - X0, 0.04, Z1 - Z0), Art.material("concrete", Color(0.16, 0.15, 0.18)))
	K.glow(street, Vector3((X0 + X1) * 0.5 + 4.0, 0.1, Z1 - 0.3), Vector3(X1 - X0 - 8.0, 0.05, 0.08), GOLD * 1.6)
	K.glow(street, Vector3((X0 + X1) * 0.5 + 8.0, 0.1, Z0 + 0.3), Vector3(X1 - X0 - 16.0, 0.05, 0.08), MAGENTA * 1.6)
	var x := X0 + 4.0
	while x < X1:
		K.light(street, Vector3(x, 1.2, Z0 + 1.0), MAGENTA, 0.6, 6.0).light_specular = 0.15
		K.light(street, Vector3(x + 3.0, 4.5, (Z0 + Z1) * 0.5), GOLD, 0.5, 8.0)
		x += 7.0
	_arch(street, T)
	_casino(street, info, T)
	_club(street, info, T)
	_south_wall(street, T)
	# The far end: a blank wall with the Undertow's mural, and a filler block
	# between the garden terrace and the casino.
	Kit.box(street, Vector3(X1 + 0.3, 4.0, (Z0 + Z1) * 0.5), Vector3(0.6, 8.0, Z1 - Z0 + 0.4), K.STONE, Vector3.ZERO, Art.material("concrete", Color(0.14, 0.12, 0.16)))
	T._neon_text(street, Vector3(X1 - 0.02, 3.2, (Z0 + Z1) * 0.5), "THE HOUSE\nREMEMBERS", WINE, 60, -90.0)
	Kit.box(street, Vector3(18.0, 4.5, Z1 + 6.0), Vector3(4.0, 9.0, 12.0), K.STONE, Vector3.ZERO, Art.material("concrete", Color(0.22, 0.2, 0.24)))
	T._graffiti(street, Vector3(18.0, 2.2, Z1 - 0.03), 180.0, "PIP SEES YOU", GOLD, 60)
	# Shut the gap behind the cinema with stacked crates.
	TP.spawn(street, "crates", Vector3(21.5, 0, Z0 - 0.8), 15.0)
	T._solid(street, Vector3(21.8, 1.0, Z0 - 0.8), Vector3(4.6, 2.0, 1.4))
	Below.build(street, info)  # the Underfloor and the high rollers' room (Mature)
	K.sound(info, "downtown_hum", Vector3(CLUB_X, 1.5, Z1 + 1.0), -10.0, 10.0)


## The arch over the mouth of the street, its sign facing Low Row.
static func _arch(root: Node3D, T) -> void:
	var gm := Art.material("gunmetal", Color(0.2, 0.18, 0.2))
	for z: float in [Z0 + 0.3, Z1 - 0.3]:
		Kit.box(root, Vector3(X0 + 1.2, 3.0, z), Vector3(0.4, 6.0, 0.4), K.STONE, Vector3.ZERO, gm)
	K.mesh(root, Vector3(X0 + 1.2, 6.1, (Z0 + Z1) * 0.5), Vector3(0.5, 1.4, Z1 - Z0), gm)
	T._neon_text(root, Vector3(X0 + 0.92, 6.1, (Z0 + Z1) * 0.5), "DOWNTOWN", GOLD, 90, -90.0)
	T._neon_text(root, Vector3(X0 + 1.48, 6.1, (Z0 + Z1) * 0.5), "DOWNTOWN", GOLD, 90, 90.0)
	for z: float in [Z0 + 0.6, Z1 - 0.6]:
		K.glow(root, Vector3(X0 + 1.2, 5.3, z), Vector3(0.3, 0.06, 0.3), GOLD * 1.8)
	K.light(root, Vector3(X0 - 0.5, 5.0, (Z0 + Z1) * 0.5), GOLD, 1.4, 10.0)


## A building on the north side, its front on the kerb at Z1 facing the street.
static func _front(root: Node3D, T, id: String, cx: float, width: float, tints: Dictionary, sign: String, neon: Color) -> Vector3:
	TP.spawn(root, id, Vector3(cx, 0, Z1), 180.0, tints)
	var floors := int(id.substr(id.find("_f") + 2, 1))
	var depth: float = T.DEPTH
	T._solid(root, Vector3(cx, T.GF * 0.5, Z1 + depth * 0.5 + 0.6), Vector3(width, T.GF, depth))
	T._solid(root, Vector3(cx, T.GF + floors * T.UF * 0.5, Z1 + depth * 0.5 - 0.6), Vector3(width, floors * T.UF, depth))
	K.light(root, Vector3(cx, 2.8, Z1 - 1.2), neon, 1.4, 9.0)
	T._neon_text(root, Vector3(cx + 0.8, T.GF + 0.75, Z1 - 0.84), sign, neon, 80 if sign.length() <= 10 else 60, 180.0)
	return Vector3(cx, 0, Z1 - 1.8)


static func _casino(root: Node3D, info: Dictionary, T) -> void:
	var door := _front(root, T, "shop_w13_f3b", CASINO_X, 13.0,
			{"wall": Color(0.32, 0.06, 0.1), "shop": GOLD, "neon": GOLD, "awning": Color(0.35, 0.05, 0.1)}, "VELVET ACE", GOLD)
	# A red carpet to the door between brass posts and a velvet rope.
	K.mesh(root, Vector3(CASINO_X, 0.09, Z1 - 1.6), Vector3(2.4, 0.02, 3.2), Art.material("canvas", Color(0.5, 0.04, 0.08)))
	for dx: float in [-1.6, 1.6]:
		for dz: float in [-2.8, -0.6]:
			K.mesh(root, Vector3(CASINO_X + dx, 0.5, Z1 + dz), Vector3(0.1, 1.0, 0.1), Art.material("gunmetal", Color(0.9, 0.7, 0.3)))
		K.mesh(root, Vector3(CASINO_X + dx, 0.85, Z1 - 1.7), Vector3(0.06, 0.06, 2.2), Art.material("canvas", Color(0.55, 0.03, 0.08)))
	# Card suits up the facade, slowly pulsing.
	var suits := ["♠", "♥", "♦", "♣"]
	for i in suits.size():
		T._neon_text(root, Vector3(CASINO_X - 4.5 + i * 3.0, T.GF + 2.6, Z1 - 0.9), suits[i], WINE if i % 2 else GOLD, 120, 180.0)
	_shop(info, "shop_casino", door, "[F] The Velvet Ace", [
		"Pip's casino. Gold everywhere, no clocks, no windows. Dad would have hated it.",
		"The doorman knows my face. He calls me 'the little sister'. I'm going to hit him one day.",
	], "casino", {"screen": "casino"})


static func _club(root: Node3D, info: Dictionary, T) -> void:
	var door := _front(root, T, "shop_w11_f4", CLUB_X, 11.0,
			{"wall": Color(0.1, 0.07, 0.14), "shop": MAGENTA, "neon": CYAN, "awning": Color(0.2, 0.05, 0.3)}, "UNDERTOW", CYAN)
	# Bass through the walls: light bars down the front that breathe in turns.
	for i in 5:
		var bar := K.glow(root, Vector3(CLUB_X - 4.4 + i * 2.2, 2.0, Z1 - 0.06), Vector3(0.12, 3.2, 0.04), (MAGENTA if i % 2 else CYAN) * 1.4)
		bar.set_meta("pulse", i)
	T._smoke(root, Vector3(CLUB_X + 4.6, 0.3, Z1 - 0.6))
	_shop(info, "shop_club", door, "[F] The Undertow", [
		"Pip's club. You can feel it in your teeth from the street. She keeps a booth at the back with everything worth knowing in it.",
		"Colony officers drink here off duty. Pip pours, they talk. Nobody leaves the Undertow with their secrets.",
	], "club", {"screen": "club"})


## The terrace's retaining wall along the south side: the house's ads.
static func _south_wall(root: Node3D, T) -> void:
	var ads := [
		[28.0, "THE HOUSE\nALWAYS LOVES YOU", GOLD],
		[36.0, "GILDED REELS\nTRIPLE STARLINGS PAY", WINE],
		[43.0, "UNDERTOW\nTONIGHT: EVERY NIGHT", CYAN],
	]
	for ad in ads:
		var at := Vector3(ad[0], 4.2, Z0 + 0.12)
		var col: Color = ad[2]
		K.mesh(root, at, Vector3(5.0, 2.6, 0.12), TP.paint(Color(0.06, 0.05, 0.07), 0.5))
		K.glow(root, at + Vector3(0, 0, 0.07), Vector3(4.6, 2.2, 0.02), col * 0.3)
		T._neon_text(root, at + Vector3(0, 0, 0.1), ad[1], Color(1, 0.96, 0.9), 50, 0.0)
		K.light(root, at + Vector3(0, 0, 1.8), col, 0.8, 7.0)
	T._poster(root, Vector3(24.5, 1.6, Z0 + 0.05), 0.0, "LOST: ONE CAT", "ask pip", Color(0.9, 0.85, 0.7))
	T._graffiti(root, Vector3(32.0, 1.2, Z0 + 0.05), 0.0, "OWE THE HOUSE? PAY THE HOUSE.", MAGENTA, 50)


static func _shop(info: Dictionary, id: String, pos: Vector3, prompt: String, lines: Array, kind: String, extra: Dictionary) -> void:
	K.interactable(info, id, pos, prompt, lines, 2.8)
	info["interactables"].back()["shop"] = kind
	info["interactables"].back().merge(extra, true)


## Puts Pip at this hub stay's spot (PIP_SPOTS, in turn by `run`), with her
## "[F] Talk" spot, in that spot's outfit. Teen trades the mesh for the waistcoat.
static func place_pip(info: Dictionary, run: int, rating := "") -> Dictionary:
	if rating == "":
		rating = ContentRating.current()
	var spot: Array = PIP_SPOTS[posmod(run, PIP_SPOTS.size())]
	if spot[0] == "high_rollers" and rating != "M":
		spot = PIP_SPOTS[2]  # the rooms below are Mature only: she's at the arch
	var outfit: String = spot[3]
	if outfit == "warden" and rating != "M":
		outfit = "crop"
	var spec := {"who": "pip", "pos": spot[1], "yaw": spot[2], "outfit": outfit, "spot": spot[0]}
	if not info.has("npcs"):
		info["npcs"] = []
	info["npcs"].append(spec)
	K.interactable(info, "npc_pip", spot[1], "[F] Talk to Pip", [], 2.6)
	info["interactables"].back()["npc"] = "pip"
	return spec


# --- secrets: Pip's booth at the Undertow --------------------------------------

## Intel for the next run, one at a time. `boost` keys are suit profile keys,
## as Seven Suns' meals (town_shops.gd boost()).
const SECRETS := {
	"patrol_rota": {"name": "Patrol rota", "cost": {"scrap": 30},
		"blurb": "When the colony's sentries change shift and where they stand. Grunts notice you 25% slower next run.",
		"boost": {"notice_mult": 0.75}},
	"supply_manifest": {"name": "Supply manifest", "cost": {"scrap": 35, "alloy": 4},
		"blurb": "Which crates the quartermaster pads and where he stacks them. Guns hit 12% harder next run (you know where the good rounds are).",
		"boost": {"damage_mult": 1.12}},
	"medic_schedule": {"name": "Medic's schedule", "cost": {"scrap": 30, "circuits": 1},
		"blurb": "A colony medic with gambling debts leaves the field kits unlocked. Health starts coming back 1.5 s sooner next run.",
		"boost": {"regen_delay_add": -1.5}},
	"back_routes": {"name": "Back routes", "cost": {"scrap": 40},
		"blurb": "The smugglers' lines through the ridge. 10% faster on foot and wallruns 20% longer, next run.",
		"boost": {"speed_mult": 1.1, "wallrun_time_mult": 1.2}},
	"armour_specs": {"name": "Armour specs", "cost": {"scrap": 45, "alloy": 8, "circuits": 1},
		"blurb": "A colony engineer's notes on their plating, traded for a debt. +30 max health next run.",
		"boost": {"max_health_bonus": 30.0}},
}
const SECRET_ORDER := ["patrol_rota", "supply_manifest", "medic_schedule", "back_routes", "armour_specs"]

## Pip's ledger: one page turns with every secret Eco buys. What Downtown
## knows, in the order Pip is willing to say it.
const LEDGER := [
	"The Velvet Ace launders colony scrip. Every officer who loses at my reels is paying for your bullets, Eco. You're welcome.",
	"Mom knows what I do. She's known since the night I left. She still sets my place at the table on Dad's birthday.",
	"The recruiters who turned you away? Their captain owes the house more than his pension. I could have got you in. You'd have hated me for it.",
	"Marrow cooks in my town, so he pays my door. I took his money. I'm not proud of it. I'm writing his ledger down, page by page.",
	"Dad's titan didn't go down by itself. Somebody gave the colony his flight path, and they drank at my bar the night before. I've got a name. Ask me when you're ready.",
]

static func _cfg() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(save_path)
	return cfg


## The secret she's carrying into the next run ("" for none).
static func secret() -> String:
	return String(_cfg().get_value("downtown", "secret", ""))


## How many ledger pages Pip has shown her.
static func pages() -> int:
	return int(_cfg().get_value("downtown", "pages", 0))


## Buys a secret for the next run (one at a time: a second one waits). Turns a
## ledger page. Returns whether she bought it.
static func buy_secret(armory: Armory, id: String) -> bool:
	if not SECRETS.has(id) or secret() != "" or not armory._spend(SECRETS[id]["cost"]):
		return false
	armory.save()
	var cfg := _cfg()
	cfg.set_value("downtown", "secret", id)
	cfg.set_value("downtown", "pages", mini(int(cfg.get_value("downtown", "pages", 0)) + 1, LEDGER.size()))
	cfg.save(save_path)
	return true


## Pip's own dirt Eco has found (downtown_below.gd DIRT ids).
static func dirt() -> Array:
	return Array(_cfg().get_value("downtown", "dirt", []))


## Eco finds a piece of Pip's dirt. Returns what she sees, plus the last
## word once she's found all of it.
static func find_dirt(id: String) -> String:
	if not Below.DIRT.has(id):
		return ""
	var cfg := _cfg()
	var found: Array = Array(cfg.get_value("downtown", "dirt", []))
	var text: String = Below.DIRT[id]["text"]
	if not found.has(id):
		found.append(id)
		cfg.set_value("downtown", "dirt", found)
		cfg.save(save_path)
		if found.size() == Below.DIRT.size():
			text += "\n" + Below.ALL_FOUND
	return text


## The run the secret was for is over.
static func finish_secret() -> void:
	var cfg := _cfg()
	if cfg.has_section_key("downtown", "secret"):
		cfg.erase_section_key("downtown", "secret")
		cfg.save(save_path)


## The boost from the secret she's carrying, or {}.
static func boost() -> Dictionary:
	var s := secret()
	return SECRETS[s]["boost"] if SECRETS.has(s) else {}


# --- the Gilded Reels: the Velvet Ace's slot machine ---------------------------

## Reel symbols, rarest last, and what three of a kind pays (times the bet).
const SYMBOLS := ["cherry", "bell", "chip", "titan", "starling"]
const SYMBOL_TEXT := {"cherry": "CHERRY", "bell": "BELL", "chip": "CHIP", "titan": "TITAN", "starling": "STARLING"}
const WEIGHTS := [34, 26, 20, 13, 7]
const PAYS := {"cherry": 4, "bell": 8, "chip": 15, "titan": 30, "starling": 75}
## Two cherries anywhere pay this much back (times the bet).
const TWO_CHERRIES := 1
const BETS := [5, 15, 30, 60]


static func spin_reel(rng: RandomNumberGenerator) -> String:
	var total := 0
	for w in WEIGHTS:
		total += w
	var roll := rng.randi_range(0, total - 1)
	for i in SYMBOLS.size():
		roll -= WEIGHTS[i]
		if roll < 0:
			return SYMBOLS[i]
	return SYMBOLS[0]


static func spin(rng: RandomNumberGenerator) -> Array:
	return [spin_reel(rng), spin_reel(rng), spin_reel(rng)]


## What a spin pays back on `bet` (0 for nothing).
static func payout(reels: Array, bet: int) -> int:
	if reels.size() == 3 and reels[0] == reels[1] and reels[1] == reels[2]:
		return bet * int(PAYS[reels[0]])
	if reels.count("cherry") >= 2:
		return bet * TWO_CHERRIES
	return 0
