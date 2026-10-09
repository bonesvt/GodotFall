extends RefCounted
## Solace, Eco's hometown, down the old pilgrim road past the hub's front gate.
##
## Solarpunk on top, dark cyberpunk underneath: white terraces hung with
## gardens, solar sails and wind turbines up in the sun, and under the panel
## canopy a narrow street of neon, wet paving, cables and steam. The town has
## thinks Eco shut herself away after her father died (Mom keeps the story
## going), and the recruiters who turned her away for crying keep a branch
## office on the plaza.
##
##   z 96..126   the pilgrim road through the jungle, wooden lamps giving way to solar ones
##   z 126..132  the town gate: solar pylons, the SOLACE sign, an army checkpoint
##   z 132..160  Lantern Row: the outfitter and the clinic west, noodles and salvage east
##   z 160..190  Sun Plaza: the Sun Tree, the fountain, the job board, Ink & Iron (tattoos
##               and piercings, in a shipping container) and the recruitment office
##               west, the greenhouse cafe and Cut & Chrome (the hair salon) east
##   z 190..214  Low Row: the arcade and Eco's old flat west, the bar and the cinema east
##   z 214..244  the rooftop garden up the steps, looking out over the valley
##
## Every shop is an interactable with a "shop" key (SHOPS). The open ones have
## a "screen" (the run manager opens it: town_shop_screen.gd for what
## town_shops.gd sells, salon_screen.gd, gift_screen.gd); date spots have a
## "date" key (run_manager.gd date_at: whoever Eco's romancing meets her there).
## Without one of those, F gets Eco's lines.

const K := preload("res://scripts/hub/hub_kit.gd")
const Kit := preload("res://scripts/run/level_kit.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")
const Props := preload("res://scripts/hub/hub_props.gd")
const Ambient := preload("res://scripts/hub/ambient.gd")
const TP := preload("res://scripts/hub/town_props.gd")
const TownMood := preload("res://scripts/hub/town_mood.gd")
const Downtown := preload("res://scripts/hub/downtown.gd")
const GiftShop := preload("res://scripts/hub/gift_shop.gd")
const HushDen := preload("res://scripts/hub/hush_den.gd")

## The road leaves the hub's front gate at z = ROAD_START and reaches the town gate at TOWN_GATE.
const ROAD_START := 94.0
const ROAD_HALF := 3.5
const TOWN_GATE := 128.0
## Town extents: the street runs along x = 0 between the shopfronts at +-STREET_HALF.
const STREET_HALF := 7.0
const TOWN_HALF := 48.0
const TOWN_END := 246.0
const PLAZA := Rect2(-22.0, 160.0, 44.0, 30.0)
const GARDEN_Y := 5.0
const GARDEN := Rect2(-16.0, 220.0, 32.0, 22.0)
## The two covered shop rows, (start z, end z).
const ROWS := [Vector2(132.0, 160.0), Vector2(190.0, 214.0)]
## Height of the solar canopy over the rows.
const CANOPY_Y := 10.6

## What each shop will be for once its feature exists.
const SHOPS := {
	"outfitter": "accessories and a fitting room (town_shop_screen.gd)",
	"noodles": "meals for the next run (town_shop_screen.gd), dates at the stall",
	"salvage": "material trades (town_shop_screen.gd)",
	"clinic": "implants (town_shop_screen.gd)",
	"ink": "piercings and tattoos (town_shop_screen.gd)",
	"jobs": "quests",
	"cafe": "dates",
	"arcade": "dates",
	"bar": "quest givers and rumours; Mature-only dates (and the back step: a smoke with Ophelia)",
	"cinema": "dates",
	"ice_cream": "dates",
	"gifts": "gifts for romance partners (gift_shop.gd)",
	"garden": "dates",
	"salon": "haircuts (salon_screen.gd)",
}

const MAGENTA := Color(1.0, 0.25, 0.75)
const CYAN := Color(0.25, 0.95, 1.0)
const LIME := Color(0.6, 1.0, 0.35)
const AMBER := Color(1.0, 0.62, 0.22)
const VIOLET := Color(0.62, 0.38, 1.0)
const RED := Color(1.0, 0.18, 0.22)
const WARM := Color(1.0, 0.78, 0.5)
const LEAF_TINTS := [Color(1, 1, 1), Color(0.85, 1.0, 0.8), Color(1.1, 1.05, 0.75), Color(0.75, 0.9, 0.85)]

## Ground floor and upper floor heights, and how deep the buildings are.
const GF := 4.4
const UF := 3.4
const DEPTH := 12.0

static var _mats := {}


static func build(root: Node3D, info: Dictionary) -> void:
	var town := Node3D.new()
	town.name = "Town"
	root.add_child(town)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	_road(town, info, rng)
	_ground(town)
	_gate(town, info)
	_lantern_row(town, info, rng)
	_plaza(town, info, rng)
	_low_row(town, info, rng)
	HushDen.build(town, info)  # Marrow's alley and cinema basement (vices.gd, Mature)
	_garden(town, info, rng)
	Downtown.build(town, info)  # Pip's street off the end of Low Row (downtown.gd)
	_canopy(town, rng)
	_surroundings(town, rng)
	_fences(town)
	# Dusk under the canopy, sun on the plaza (town_mood.gd).
	var mood: Node = TownMood.new()
	mood.name = "TownMood"
	for seg: Vector2 in ROWS:
		mood.zones.append(Rect2(-STREET_HALF - 1.0, seg.x, STREET_HALF * 2 + 2.0, seg.y - seg.x))
	mood.zones.append(Downtown.STREET)
	root.add_child(mood)


## Shops and spots in the town (ids from info["interactables"]). `extra` is
## merged into the spot: {"screen": ...} opens a shop screen, {"date": place}
## makes it a date spot.
static func shop(info: Dictionary, id: String, pos: Vector3, prompt: String, lines: Array, kind := "", extra := {}) -> void:
	K.interactable(info, id, pos, prompt, lines, 2.8)
	if kind != "":
		info["interactables"].back()["shop"] = kind
	info["interactables"].back().merge(extra, true)


# --- the road -----------------------------------------------------------------

static func _road(root: Node3D, _info: Dictionary, rng: RandomNumberGenerator) -> void:
	var length := TOWN_GATE - ROAD_START
	K.mesh(root, Vector3(0, 0.03, ROAD_START + length * 0.5), Vector3(ROAD_HALF * 2, 0.04, length), Art.material("dirt"))
	# Wooden lamps near the temple, solar lamps nearer town.
	for i in 5:
		var z := ROAD_START + 5.0 + i * 6.5
		var s := -1.0 if i % 2 == 0 else 1.0
		var p := Vector3(s * (ROAD_HALF + 0.8), 0, z)
		if i < 2:
			# A carved post with an arm over the road and a lantern hanging off it.
			K.wood(root, p + Vector3(0, 1.6, 0), Vector3(0.25, 3.2, 0.25))
			K.wood(root, p + Vector3(-s * 0.55, 3.05, 0), Vector3(1.3, 0.16, 0.16))
			K.wood(root, p + Vector3(-s * 0.2, 2.75, 0), Vector3(0.5, 0.12, 0.12), Vector3(0, 0, 45 * s))
			TP.spawn(root, "lantern", p + Vector3(-s * 1.0, 3.0, 0), 0.0, {"shop": WARM * 1.3})
		else:
			_solar_lamp(root, p, CYAN)
	# A shrine stone at the bend, half swallowed by roots.
	K.carved(root, Vector3(-ROAD_HALF - 2.5, 1.0, ROAD_START + 14), Vector3(1.4, 2.0, 1.0), Vector3(0, 20, 6), Color(0.75, 0.85, 0.78))
	K.mesh(root, Vector3(-ROAD_HALF - 2.5, 2.1, ROAD_START + 14), Vector3(1.6, 0.6, 1.2), Art.material("moss"), Vector3(0, 20, 6))
	for p in [Vector3(ROAD_HALF + 2, 0, ROAD_START + 9), Vector3(-ROAD_HALF - 2, 0, ROAD_START + 24), Vector3(ROAD_HALF + 2.5, 0, ROAD_START + 28)]:
		Props.spawn(root, ["bush_a", "bush_b", "fern"][rng.randi() % 3], p, rng.randf_range(0, 360), 0.6, {"leaves": LEAF_TINTS[rng.randi() % 4]})


## A white lamp post with a little solar panel on top and a coloured glow.
static func _solar_lamp(root: Node3D, p: Vector3, color: Color) -> void:
	TP.spawn(root, "solar_lamp", p, 180.0 if p.x > 0.0 else 0.0, {"shop": color / 0.6})
	_solid(root, p + Vector3(0, 2.0, 0), Vector3(0.3, 4.0, 0.3))


# --- ground -------------------------------------------------------------------

static func _ground(root: Node3D) -> void:
	# Dark, wet paving down the street, pale stone on the plaza.
	var street := Art.material("concrete", Color(0.3, 0.3, 0.34))
	Kit.box(root, Vector3(0, -0.45, (TOWN_GATE + TOWN_END) * 0.5), Vector3(TOWN_HALF * 2, 1.0, TOWN_END - TOWN_GATE), K.STONE, Vector3.ZERO,
			Art.material("concrete", Color(0.42, 0.42, 0.46))).set_meta("surface", "metal")
	K.mesh(root, Vector3(0, 0.06, 176), Vector3(STREET_HALF * 2, 0.04, 88), street)
	K.mesh(root, Vector3(PLAZA.get_center().x, 0.07, PLAZA.get_center().y), Vector3(PLAZA.size.x, 0.04, PLAZA.size.y),
			Art.material("temple_stone", Color(1.0, 1.0, 0.96)))
	K.patch(root, Vector3(PLAZA.get_center().x, 0.0, PLAZA.get_center().y), PLAZA.size, "stone")
	# Steel grates, drain covers and cable runs down the street.
	for seg: Vector2 in ROWS:
		var z := seg.x + 3.0
		while z < seg.y - 2.0:
			K.mesh(root, Vector3(0, 0.09, z), Vector3(STREET_HALF * 2 - 2.0, 0.02, 0.5), TP.paint(Color(0.08, 0.08, 0.09), 0.3))
			K.mesh(root, Vector3(-3.5 if int(z) % 2 == 0 else 3.5, 0.09, z + 2.5), Vector3(0.9, 0.02, 0.9), TP.paint(Color(0.06, 0.06, 0.07), 0.3))
			z += 7.0
		for x: float in [-STREET_HALF + 1.0, STREET_HALF - 1.2]:
			K.mesh(root, Vector3(x, 0.1, (seg.x + seg.y) * 0.5), Vector3(0.12, 0.08, seg.y - seg.x), TP.paint(Color(0.05, 0.05, 0.06), 0.5))
	# Gutter lights along the kerbs, cyan on one side and magenta on the other.
	for s: float in [-1.0, 1.0]:
		for seg in [[132.0, 160.0], [190.0, 214.0]]:
			var z0: float = seg[0]
			var z1: float = seg[1]
			K.glow(root, Vector3(s * (STREET_HALF - 0.3), 0.1, (z0 + z1) * 0.5), Vector3(0.08, 0.05, z1 - z0), (CYAN if s < 0 else MAGENTA) * 1.6)
			# Low fill lights so the neon spills onto the paving and the shopfronts.
			var lz := z0 + 4.0 + (2.0 if s > 0 else 0.0)
			while lz < z1 - 2.0:
				var fill := K.light(root, Vector3(s * (STREET_HALF - 1.5), 1.2, lz), CYAN if s < 0 else MAGENTA, 0.7, 6.5)
				fill.light_specular = 0.15  # no hot glints on the wet paving
				lz += 8.0
			# A dim lantern-coloured fill down the middle, so the paving never goes black.
			if s < 0.0:
				var mz := z0 + 3.0
				while mz < z1:
					K.light(root, Vector3(0, 5.5, mz), AMBER, 0.5, 9.0)
					mz += 10.0
	# The canopy's mouth by the gate sits outside the fills above; light it from the noodle bar's side.
	K.light(root, Vector3(-2.0, 3.0, 139.0), AMBER, 1.2, 10.0).light_specular = 0.2
	# Puddles that pick up the neon.
	var puddle := StandardMaterial3D.new()
	# Wet and glossy enough to catch the neon, see-through enough not to read as a hole.
	puddle.albedo_color = Color(0.1, 0.1, 0.15, 0.45)
	puddle.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puddle.roughness = 0.12
	puddle.metallic_specular = 0.6
	for spec in [[Vector3(1.5, 0.09, 146), Vector3(3.0, 0.02, 2.0)], [Vector3(3.0, 0.09, 151), Vector3(2.2, 0.02, 3.4)],
			[Vector3(-1.0, 0.09, 197), Vector3(4.0, 0.02, 2.4)], [Vector3(2.4, 0.09, 207), Vector3(2.0, 0.02, 1.6)]]:
		# Oval, not boxes: a rotated box read as an arrow painted on the street.
		var disc := CylinderMesh.new()
		disc.top_radius = 0.5
		disc.bottom_radius = 0.5
		disc.height = 1.0
		disc.radial_segments = 20
		disc.rings = 1
		var mi := MeshInstance3D.new()
		mi.mesh = disc
		mi.material_override = puddle
		mi.position = spec[0]
		mi.rotation_degrees.y = spec[0].z * 7.0
		mi.scale = spec[1]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)


# --- the gate -----------------------------------------------------------------

static func _gate(root: Node3D, info: Dictionary) -> void:
	var z := TOWN_GATE
	for s: float in [-1.0, 1.0]:
		var x := s * (STREET_HALF + 1.5)
		TP.spawn(root, "gate_pylon", Vector3(x, 0, z), 0.0 if s < 0.0 else 180.0, {"leaves": LEAF_TINTS[1]})
		_solid(root, Vector3(x, 6.0, z), Vector3(2.8, 12.0, 2.8))
	# Arch beam and the neon name.
	TP.spawn(root, "gate_arch", Vector3(0, 10.4, z), 0.0, {"wall": Color(0.9, 0.9, 0.86)})
	_neon_text(root, Vector3(0, 10.4, z - 0.56), "SOLACE", CYAN, 150, 180.0)
	_neon_text(root, Vector3(0, 10.4, z + 0.56), "SOLACE", CYAN, 150, 0.0)
	K.light(root, Vector3(0, 9.0, z - 2.0), CYAN, 1.6, 12.0)
	# The army checkpoint on the east side: booth, raised boom, barriers, a flag, a poster.
	var booth := Vector3(STREET_HALF + 4.5, 0, z - 3.0)
	TP.spawn(root, "checkpoint", booth, 0.0, {"wall": Color(0.62, 0.66, 0.6)})
	_solid(root, booth + Vector3(0, 1.4, 0), Vector3(2.6, 2.8, 2.6))
	var flag := _animated(root, booth + Vector3(1.0, 6.6, -1.0), Ambient.Mode.SWAY, 5.0, 0.9)
	K.mesh(flag, Vector3(0, -0.5, 0.75), Vector3(0.04, 1.0, 1.5), Art.material("fabric", Color(0.55, 0.62, 0.45)))
	_poster(root, Vector3(STREET_HALF + 1.5, 2.6, z - 1.42), 180.0, "ONLY THE\nHARDENED FIGHT", "and the ones who cry\nfix your titans. -E", Color(0.55, 0.62, 0.45))
	shop(info, "town_gate", Vector3(0, 0, z - 3.5), "[F] Read the town sign", [
		"Solace. Home. Everybody here thinks I locked myself away after Dad. Mom lets them.",
		"Keep your head down, Eco. Buy what you need. Look tragic. Don't start anything.",
		"The checkpoint boys ask how I'm feeling. Depends what Mom told them this week.",
	])


# --- Lantern Row ----------------------------------------------------------------

static func _lantern_row(root: Node3D, info: Dictionary, rng: RandomNumberGenerator) -> void:
	# West: the outfitter, the clinic. East: the noodle bar, the salvage dealer.
	var outfitter := _building(root, -1, 139.0, "shop_w13_f3", 13.0, {"wall": Color(0.95, 0.92, 0.9), "shop": MAGENTA, "awning": Color(0.9, 0.4, 0.6)}, "STITCH & STEEL")
	_blade_sign(root, -1, 134.0, "STITCH\n&\nSTEEL", MAGENTA)
	_mannequins(root, -1, 139.0)
	shop(info, "shop_outfitter", outfitter, "[F] Stitch & Steel: accessories and the fitting room", [
		"Mara made my first flight suit. Now she asks Mom if I'm eating.",
	], "outfitter", {"screen": "outfitter"})

	var noodles := _building(root, 1, 139.0, "shop_w13_f2", 13.0, {"wall": Color(0.88, 0.94, 0.86), "shop": AMBER, "awning": Color(0.95, 0.6, 0.3)}, "SEVEN SUNS NOODLES")
	_blade_sign(root, 1, 134.0, "SEVEN\nSUNS", AMBER)
	TP.spawn(root, "noodle_stall", Vector3(STREET_HALF - 1.4, 0, 141.0), -90.0, {"shop": Color(1.0, 0.35, 0.2) / 0.6})
	_solid(root, Vector3(STREET_HALF - 1.0, 0.55, 141.0), Vector3(0.8, 1.1, 5.0))
	_smoke(root, Vector3(STREET_HALF + 1.0, GF + 0.2, 144.0))
	shop(info, "shop_noodles", noodles, "[F] Seven Suns: a hot meal for the next run", [
		"Old Hiro still saves me the burnt edges. Only one in town who does.",
	], "noodles", {"screen": "noodles"})
	# The stools at the stall out front: a date spot.
	shop(info, "noodle_stall", Vector3(STREET_HALF - 2.8, 0, 144.6), "[F] Seven Suns stall", [
		"Spice, salt and grease. Best armour there is.",
		"Dad and I ate here every Sunday. Same stools. He always took the wobbly one.",
	], "noodles", {"date": "noodles"})

	var clinic := _building(root, -1, 153.5, "shop_w11_f4", 11.0, {"wall": Color(0.88, 0.95, 0.96), "shop": LIME}, "+ MERCY CLINIC +")
	shop(info, "shop_clinic", clinic, "[F] Mercy Clinic: implants", [
		"Doc Imani stitched up Dad more times than I can count. She doesn't charge me. Yet.",
	], "clinic", {"screen": "clinic"})

	# The colony dispensary (hymn.gd): a white kiosk against the building line
	# between the outfitter and the clinic, its screen and seal lit. Its daily
	# dose is Mature only (dispensary_screen.gd); under Teen it's out of service.
	var white := Art.material("gunmetal", Color(0.9, 0.92, 0.95))
	K.mesh(root, Vector3(-6.35, 1.1, 146.8), Vector3(0.8, 2.2, 1.3), white)
	K.mesh(root, Vector3(-5.93, 0.95, 146.8), Vector3(0.06, 0.1, 0.9), Art.material("gunmetal", Color(0.2, 0.22, 0.26)))
	K.glow(root, Vector3(-5.94, 1.55, 146.8), Vector3(0.02, 0.55, 0.85), Color(0.8, 0.92, 1.0))
	K.glow(root, Vector3(-5.94, 2.05, 146.8), Vector3(0.02, 0.16, 0.16), Color(1.0, 1.0, 1.0))
	K.light(root, Vector3(-5.2, 2.3, 146.8), Color(0.85, 0.93, 1.0), 0.7, 4.0)
	_solid(root, Vector3(-6.35, 1.1, 146.8), Vector3(0.8, 2.2, 1.3))
	shop(info, "dispensary", Vector3(-5.1, 0, 146.8), "[F] A colony kiosk", [
		"A colony kiosk. The screen says OUT OF SERVICE in six languages.",
	], "dispensary")

	var salvage := _building(root, 1, 153.5, "shop_w11_f3", 11.0, {"wall": Color(0.72, 0.74, 0.76), "shop": RED, "awning": Color(0.5, 0.5, 0.45)}, "SAL'S SALVAGE")
	_blade_sign(root, 1, 150.0, "SAL'S\nSALVAGE", RED)
	_scrap_pile(root, Vector3(STREET_HALF + 1.4, 0, 157.5))
	shop(info, "shop_salvage", salvage, "[F] Sal's Salvage: trade materials", [
		"Sal buys colony scrap off the scavengers and sells it to me at twice the price. Everybody wins but me.",
		"Don't ask where the serial numbers went.",
	], "salvage", {"screen": "salvage"})
	# Sal's side hatch at the plaza end of the shop: stims under the counter,
	# Mature only (vices.gd). Under Teen it stays shut.
	K.mesh(root, Vector3(STREET_HALF + 0.02, 1.05, 158.4), Vector3(0.12, 2.1, 1.0), Art.material("gunmetal", Color(0.24, 0.3, 0.26)))
	K.mesh(root, Vector3(STREET_HALF - 0.05, 1.35, 158.4), Vector3(0.06, 0.25, 0.7), Art.material("gunmetal", Color(0.1, 0.1, 0.1)))
	K.light(root, Vector3(STREET_HALF - 0.4, 2.4, 158.4), Color(0.6, 1.0, 0.35), 0.6, 3.5)
	shop(info, "sal_hatch", Vector3(STREET_HALF - 1.0, 0, 158.4), "[F] A hatch round Sal's side", [
		"Sal's back hatch. Locked. He only opens it for people he trusts, and he doesn't trust anybody.",
	], "stims")
	_street_life(root, 132.0, 160.0, rng)


# --- Sun Plaza ------------------------------------------------------------------

static func _plaza(root: Node3D, info: Dictionary, rng: RandomNumberGenerator) -> void:
	var c := Vector3(0, 0, PLAZA.get_center().y)
	_sun_tree(root, c)
	K.sound(info, "park_river", c + Vector3(0, 0.8, 0), -12.0, 4.0)  # the fountain
	K.sound(info, "town_murmur", c + Vector3(0, 2.0, 0), -8.0, 14.0)
	shop(info, "sun_tree", c + Vector3(0, 0, -6.5), "[F] Look at the Sun Tree", [
		"The Sun Tree powers half the town. The half that pays.",
		"Dad brought me here the night they switched it on. Everybody cheered. I was six.",
	])
	# Benches and planters around the edge.
	for spec in [[Vector3(-12, 0, 166), 90.0], [Vector3(12, 0, 166), -90.0], [Vector3(-12, 0, 184), 90.0], [Vector3(12, 0, 184), -90.0]]:
		_bench(root, spec[0], spec[1])
		var pot: Vector3 = spec[0] + Vector3(signf(spec[0].x) * 3.5, 0, 0)
		if pot.z > 175.0:
			continue  # Scoops and the gift shop stand there
		TP.spawn(root, "planter", pot, 0.0, {"leaves": LEAF_TINTS[2]})
		_solid(root, pot + Vector3(0, 0.4, 0), Vector3(2.4, 0.8, 2.4))
		Props.tree(root, pot + Vector3(0, 0.8, 0), rng, 0.6)
	# The job board.
	var board := Vector3(-6.5, 0, 163.5)
	K.wood(root, board + Vector3(-1.4, 1.3, 0), Vector3(0.2, 2.6, 0.2))
	K.wood(root, board + Vector3(1.4, 1.3, 0), Vector3(0.2, 2.6, 0.2))
	K.mesh(root, board + Vector3(0, 1.7, 0), Vector3(3.0, 1.6, 0.1), Art.material("wood", Color(0.8, 0.7, 0.6)))
	for i in 7:
		K.mesh(root, board + Vector3(-1.1 + (i % 4) * 0.7 + rng.randf_range(-0.1, 0.1), 2.1 - int(i / 4.0) * 0.75, -0.07), Vector3(0.5, 0.6, 0.02),
				Art.material("canvas", Color(1.0, 0.97, 0.88)), Vector3(0, 0, rng.randf_range(-8, 8)))
	K.glow(root, board + Vector3(0, 2.75, -0.1), Vector3(2.4, 0.08, 0.08), WARM)
	shop(info, "job_board", board + Vector3(0, 0, -1.6), "[F] Read the job board (quests coming soon)", [
		"Lost goat. Broken pump. 'Pilots wanted, hardened only.' Somebody drew a crying face on it. Cute.",
		"Half these jobs pay in favours. I'm owed a lot of favours.",
	], "jobs")
	# Market stalls along the plaza's open sides, facing the tree.
	for spec in [[Vector3(7.0, 0, 162.5), 0.0, AMBER], [Vector3(6.0, 0, 187.5), 180.0, LIME]]:
		TP.spawn(root, "market_stall", spec[0], spec[1], {"awning": (spec[2] as Color).lerp(Color.WHITE, 0.35), "shop": spec[2]})
		_solid(root, spec[0] + Vector3(0, 1.2, 0), Vector3(3.0, 2.4, 1.8))
	_ice_cream(root, info)
	# Lucky Lantern, the gift shop, on the opposite corner by the bar (gift_shop.gd).
	_gift_shop(root, info)
	# Lamps round the Sun Tree.
	for d: Vector3 in [Vector3(-6.5, 0, -6.5), Vector3(6.5, 0, -6.5), Vector3(-6.5, 0, 6.5), Vector3(6.5, 0, 6.5)]:
		_solar_lamp(root, c + d, [LIME, AMBER, CYAN, MAGENTA][int(d.x > 0) + 2 * int(d.z > 0)])
	_militia_office(root, info)
	_ink_parlour(root, info)
	_greenhouse(root, info, rng)
	_salon(root, info)
	_plaza_walls(root, rng)


## Scoops, the ice cream kiosk on the plaza's corner by Low Row and the arcade.
## A date spot later (Ophelia's favourite, with the arcade).
static func _ice_cream(root: Node3D, info: Dictionary) -> void:
	# In front of the arcade's vertical garden (its planter makes way), clear of the billboard.
	var at := Vector3(-15.5, 0, 186.0)
	var k := 1.2  # model scale
	TP.spawn(root, "ice_cream_kiosk", at, 180.0, {"wall": Color(1.2, 0.92, 1.05), "shop": Color(1.0, 0.72, 0.86),
			"neon": Color(1.0, 0.55, 0.85), "awning": Color(0.75, 0.95, 1.0)}, k)
	_solid(root, at + Vector3(0, 1.5 * k, 1.3 * k), Vector3(4.0, 3.0, 2.6) * k)
	_solid(root, at + Vector3(0, 0.42 * k, -0.55 * k), Vector3(2.8, 0.84, 0.6) * k)
	_neon_text(root, at + Vector3(0, 3.35 * k, -0.12), "SCOOPS", Color(1.0, 0.55, 0.85), 90, 180.0)
	K.light(root, at + Vector3(0, 2.4, -1.8), Color(1.0, 0.7, 0.85), 1.0, 7.0)
	shop(info, "shop_icecream", at + Vector3(0, 0, -2.0), "[F] Scoops: ice cream", [
		"Mrs. Tran still gives me a kid's scoop. I think she means it nicely.",
		"Ophelia orders black sesame every time. Says it's the only flavour that matches her soul.",
		"Two scoops, one bench, nobody shooting at me. That's a good day in Solace.",
	], "ice_cream", {"date": "ice_cream"})


## Lucky Lantern, the gift shop kiosk on the plaza's corner by the bar
## (gift_shop.gd: its gifts on the shelves, the counter's shop screen).
static func _gift_shop(root: Node3D, info: Dictionary) -> void:
	var at := Vector3(15.5, 0, 186.0)
	GiftShop.build(root, info, at)
	# Walls to walk against: back, sides, the counter, the display table.
	_solid(root, at + Vector3(0, 1.5, 3.1), Vector3(5.2, 3.0, 0.3))
	for s: float in [-1.0, 1.0]:
		_solid(root, at + Vector3(s * 2.5, 1.5, 1.6), Vector3(0.3, 3.0, 3.2))
	_solid(root, at + Vector3(-1.45, 0.6, 0.75), Vector3(1.9, 1.2, 0.6))
	_solid(root, at + Vector3(0, 0.6, GiftShop.SHELF_Y + 0.3), Vector3(GiftShop.SHELF_W, 1.2, 0.8))
	_neon_text(root, at + Vector3(0, 3.62, -0.3), GiftShop.SIGN, Color(1.0, 0.45, 0.65), 64, 180.0)
	K.light(root, at + Vector3(0, 2.4, 1.2), GiftShop.PINK.lerp(WARM, 0.4), 1.2, 7.0)


## The Sun Tree (tools/town/build_town.py): white ribs holding up leaf-shaped
## solar panels, standing in a round fountain.
static func _sun_tree(root: Node3D, c: Vector3) -> void:
	TP.spawn(root, "sun_tree", c, 0.0, {"leaves": LEAF_TINTS[1]})
	_solid(root, c + Vector3(0, 5.0, 0), Vector3(2.6, 10.0, 2.6))
	for i in 16:
		var a := TAU * i / 16.0
		var body := _solid(root, c + Vector3(cos(a) * 4.9, 0.35, sin(a) * 4.9), Vector3(2.1, 0.7, 0.7))
		body.rotation_degrees.y = -rad_to_deg(a) + 90.0
	K.light(root, c + Vector3(0, 7.0, 0), Color(0.55, 1.0, 0.9), 1.5, 16.0)


## The side walls of the four row-end buildings face the plaza: a vertical
## garden on each and a lit billboard over it.
static func _plaza_walls(root: Node3D, rng: RandomNumberGenerator) -> void:
	var ads := [
		[-1.0, 159.0, 1.0, "MERCY CLINIC\nIMPLANTS ON CREDIT", LIME],
		[1.0, 159.0, 1.0, "SAL'S\nWE BUY SCRAP\nNO QUESTIONS", RED],
		[-1.0, 190.0, -1.0, "GLOWBOX\nTITAN BRAWL III", VIOLET],
		[1.0, 190.0, -1.0, "RUSTED HALO\nHAPPY HOUR ALL NIGHT", AMBER],
	]
	for ad in ads:
		var s: float = ad[0]
		var wall_z: float = ad[1] + ad[2] * 0.08
		var dir: float = ad[2]
		var x := s * 12.4
		# Vertical garden: a moss panel thick with leaves, up from a planter.
		K.mesh(root, Vector3(x + s * 3.5, 5.5, wall_z + dir * 0.06), Vector3(2.4, 8.0, 0.12), Art.material("moss", Color(0.72, 1.0, 0.62)))
		for i in 8:
			Props.spawn(root, "fern", Vector3(x + s * 3.5 + rng.randf_range(-0.9, 0.9), 1.8 + i * 1.0, wall_z + dir * 0.3), rng.randf_range(0, 360), 0.5, {"leaves": LEAF_TINTS[i % 4]})
		if dir > 0.0:  # Scoops and the gift shop stand in front of the arcade's and the bar's gardens
			TP.spawn(root, "planter", Vector3(x + s * 3.5, 0, wall_z + dir * 1.3), 0.0, {"leaves": LEAF_TINTS[1]})
			_solid(root, Vector3(x + s * 3.5, 0.4, wall_z + dir * 1.3), Vector3(2.4, 0.8, 2.4))
		# Billboard.
		var col: Color = ad[4]
		var at := Vector3(x - s * 1.5, 7.5, wall_z + dir * 0.15)
		K.mesh(root, at, Vector3(5.6, 3.4, 0.2), TP.paint(Color(0.06, 0.06, 0.08), 0.5))
		K.glow(root, at + Vector3(0, 0, dir * 0.11), Vector3(5.2, 3.0, 0.02), col * 0.35)
		for e: float in [-1.0, 1.0]:
			K.glow(root, at + Vector3(0, e * 1.72, dir * 0.12), Vector3(5.6, 0.06, 0.06), col * 1.8)
			K.glow(root, at + Vector3(e * 2.82, 0, dir * 0.12), Vector3(0.06, 3.4, 0.06), col * 1.8)
		_neon_text(root, at + Vector3(0, 0, dir * 0.14), ad[3], Color(1, 0.97, 0.92), 56, 0.0 if dir > 0 else 180.0)
		K.light(root, at + Vector3(0, 0, dir * 2.0), col, 0.9, 8.0)


## The branch recruitment office on the plaza's west side, where Eco was turned
## away for crying about her father: a grey concrete block with slit windows,
## sandbags, cameras, a red sign, flags and a locked door. (The model keeps its
## old file name, militia_office.)
static func _militia_office(root: Node3D, info: Dictionary) -> void:
	var front := PLAZA.position.x
	var z := 175.0
	TP.spawn(root, "militia_office", Vector3(front, 0, z), 90.0, {"wall": Color(0.62, 0.64, 0.62), "awning": Color(0.62, 0.6, 0.48)})
	_solid(root, Vector3(front - 6.0, 4.5, z), Vector3(12.0, 9.0, 16.6))
	_neon_text(root, Vector3(front + 0.62, 7.6, z), "RECRUITMENT", RED, 72, 90.0)
	# The slogan on its own plaque over the door canopy, between the slit windows.
	K.mesh(root, Vector3(front + 0.08, 5.1, z), Vector3(0.08, 1.5, 4.6), TP.paint(Color(0.05, 0.05, 0.06), 0.4))
	K.glow(root, Vector3(front + 0.13, 5.1 + 0.72, z), Vector3(0.03, 0.05, 4.5), RED * 1.4)
	K.glow(root, Vector3(front + 0.13, 5.1 - 0.72, z), Vector3(0.03, 0.05, 4.5), RED * 1.4)
	_neon_text(root, Vector3(front + 0.14, 5.1, z), "PILOTS WANTED.\nNO TEARS.", Color(1.0, 0.9, 0.85), 44, 90.0)
	# The forecourt: concrete barriers, a floodlight, a propaganda screen.
	for spec in [[Vector3(front + 5.0, 0, z - 6.5), 10.0], [Vector3(front + 6.0, 0, z + 6.0), -15.0], [Vector3(front + 8.5, 0, z - 2.0), 80.0]]:
		var b: Vector3 = spec[0]
		var body := _solid(root, b + Vector3(0, 0.45, 0), Vector3(2.2, 0.9, 0.7))
		body.rotation_degrees.y = spec[1]
		K.mesh(body, Vector3.ZERO, Vector3(2.2, 0.9, 0.7), Art.material("concrete", Color(0.62, 0.62, 0.6)))
		K.glow(body, Vector3(0, 0.25, 0.36), Vector3(1.6, 0.06, 0.02), RED * 1.4)
	# Supply crates, army scooters and a floodlight on the forecourt.
	for spec in [[Vector3(front + 3.2, 0, z - 5.0), 15.0], [Vector3(front + 3.0, 0, z + 6.2), -8.0]]:
		TP.spawn(root, "crates", spec[0], spec[1])
		_solid(root, spec[0] + Vector3(0, 0.6, 0), Vector3(1.6, 1.2, 1.6))
	TP.spawn(root, "scooter", Vector3(front + 7.0, 0, z + 3.5), 70.0, {"wall": Color(0.55, 0.62, 0.45)})
	TP.spawn(root, "scooter", Vector3(front + 6.0, 0, z - 3.5), 110.0, {"wall": Color(0.55, 0.62, 0.45)})
	# Hazard lines painted round the forecourt, and RECRUITS ONLY on the paving.
	var hazard := TP.paint(Color(0.85, 0.7, 0.15), 0.2)
	K.mesh(root, Vector3(front + 11.0, 0.1, z), Vector3(0.7, 0.02, 15.7), hazard)
	for dz: float in [-7.5, 7.5]:
		K.mesh(root, Vector3(front + 5.5, 0.1, z + dz), Vector3(11.0, 0.02, 0.7), hazard)
	var stencil := Kit.label(root, Vector3(front + 9.8, 0.12, z), "RECRUITS ONLY", 90)
	stencil.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	stencil.rotation_degrees = Vector3(-90, 90, 0)
	stencil.modulate = Color(0.85, 0.7, 0.15, 0.8)
	stencil.outline_size = 0
	stencil.shaded = true
	var flood := Vector3(front + 9.5, 0, z - 6.0)
	K.mesh(root, flood + Vector3(0, 2.5, 0), Vector3(0.14, 5.0, 0.14), Art.material("gunmetal"))
	K.mesh(root, flood + Vector3(0, 5.0, 0), Vector3(0.7, 0.45, 0.4), TP.paint(Color(0.07, 0.07, 0.09), 0.6), Vector3(-25, -60, 0))
	K.glow(root, flood + Vector3(-0.15, 4.9, 0.1), Vector3(0.5, 0.3, 0.05), Color(1.0, 0.95, 0.85) * 1.2, Vector3(-25, -60, 0))
	K.light(root, flood + Vector3(-1.0, 4.6, 0.5), Color(1.0, 0.95, 0.85), 1.0, 10.0)
	_solid(root, flood + Vector3(0, 2.5, 0), Vector3(0.2, 5.0, 0.2))
	var screen := Vector3(front + 4.0, 0, z - 9.5)
	K.mesh(root, screen + Vector3(0, 2.2, 0), Vector3(0.2, 4.4, 0.2), Art.material("gunmetal"))
	K.mesh(root, screen + Vector3(0, 4.2, 0), Vector3(3.6, 2.0, 0.15), TP.paint(Color(0.06, 0.06, 0.07), 0.5))
	K.glow(root, screen + Vector3(0, 4.2, -0.09), Vector3(3.3, 1.75, 0.02), RED * 0.35)
	_neon_text(root, screen + Vector3(0, 4.2, -0.12), "THE HARDENED\nKEEP SOLACE SAFE", Color(1.0, 0.85, 0.8), 40, 180.0)
	K.light(root, Vector3(front + 2.0, 6.0, z), RED, 1.6, 14.0)
	for dz: float in [-3.0, 3.0]:
		var pole := Vector3(front + 2.2, 0, z + dz)
		K.mesh(root, pole + Vector3(0, 3.5, 0), Vector3(0.1, 7.0, 0.1), Art.material("gunmetal"))
		var flag := _animated(root, pole + Vector3(0, 6.8, 0), Ambient.Mode.SWAY, 4.0, 0.7 + dz * 0.05)
		K.mesh(flag, Vector3(0, -0.7, 0.8), Vector3(0.04, 1.4, 1.6), Art.material("fabric", Color(0.55, 0.62, 0.45)))
	_poster(root, Vector3(front + 0.03, 2.2, z - 6.2), 90.0, "SERVE.\nPROTECT.\nOBEY.", "", Color(0.55, 0.62, 0.45))
	shop(info, "militia_office", Vector3(front + 3.0, 0, z), "[F] Recruitment office", [
		"'Pilots wanted. No tears.' I cried about Dad in there for one minute and they sent me home.",
		"I could fix every titan in their yard blindfolded. They offered me a tissue.",
		"One day they'll come knocking for a Pilot. I hope I'm busy.",
	])


## Ink & Iron, Rook's tattoo and piercing parlour: a rusted shipping container
## on the plaza's west side between the clinic's terrace and the recruitment
## office, its long side cut open to the Sun Tree under a cyan neon sign.
## Inside: the tattoo chair, a lamp on an arm, flash sheets on the walls.
## The counter opens town_shop_screen.gd ("ink").
const INK_Z := 163.4
const INK_CYAN := Color(0.25, 0.95, 1.0)


static func _ink_parlour(root: Node3D, info: Dictionary) -> void:
	var front := PLAZA.position.x
	var c := Vector3(front - 1.25, 0, INK_Z)   # the container's centre: 2.5 deep, 6 long
	var rust := TP.paint(Color(0.42, 0.2, 0.14), 0.7)
	var dark := TP.paint(Color(0.08, 0.08, 0.1), 0.6)
	# floor, roof, back wall and the two ends; ribs down the outside
	K.mesh(root, c + Vector3(0, 0.08, 0), Vector3(2.5, 0.16, 6.0), Art.material("gunmetal", Color(0.4, 0.38, 0.36)))
	K.mesh(root, c + Vector3(0, 2.6, 0), Vector3(2.6, 0.12, 6.1), rust)
	K.mesh(root, c + Vector3(-1.22, 1.3, 0), Vector3(0.08, 2.6, 6.0), rust)
	for e: float in [-1.0, 1.0]:
		K.mesh(root, c + Vector3(0, 1.3, e * 3.0), Vector3(2.5, 2.6, 0.08), rust)
		for k in 6:
			K.mesh(root, c + Vector3(-1.1 + k * 0.42, 1.3, e * 3.06), Vector3(0.06, 2.5, 0.06), rust)
	for k in 13:
		K.mesh(root, c + Vector3(-1.28, 1.3, -2.9 + k * 0.48), Vector3(0.06, 2.5, 0.08), rust)
	# the cut-open side: a steel frame, the doors swung back flat against the plaza walls
	K.mesh(root, c + Vector3(1.24, 2.45, 0), Vector3(0.14, 0.3, 6.0), dark)
	for e: float in [-1.0, 1.0]:
		K.mesh(root, c + Vector3(1.24, 1.3, e * 2.95), Vector3(0.14, 2.6, 0.14), dark)
		K.mesh(root, c + Vector3(1.9, 1.25, e * 3.12), Vector3(1.3, 2.4, 0.06), rust, Vector3(0, e * 12.0, 0))
	# inside: a black floor mat, the tattoo chair, a lamp on an arm, a counter, flash on the walls
	K.mesh(root, c + Vector3(0, 0.17, -0.8), Vector3(2.2, 0.02, 3.2), dark)
	var seat := TP.paint(Color(0.1, 0.1, 0.12), 0.8)
	var chair := c + Vector3(0.1, 0, -1.4)
	K.mesh(root, chair + Vector3(0, 0.45, 0), Vector3(0.2, 0.6, 0.2), Art.material("gunmetal"))
	K.mesh(root, chair + Vector3(0, 0.8, 0), Vector3(0.7, 0.14, 1.5), seat, Vector3(-8, 0, 0))
	K.mesh(root, chair + Vector3(0, 1.15, -0.8), Vector3(0.7, 0.7, 0.14), seat, Vector3(-25, 0, 0))
	K.mesh(root, chair + Vector3(-0.85, 1.25, 0), Vector3(0.05, 2.2, 0.05), Art.material("gunmetal"))
	K.mesh(root, chair + Vector3(-0.45, 2.3, 0), Vector3(0.85, 0.05, 0.05), Art.material("gunmetal"))
	K.glow(root, chair + Vector3(-0.05, 2.18, 0), Vector3(0.3, 0.06, 0.3), Color(1.0, 0.95, 0.85) * 1.4)
	K.light(root, chair + Vector3(0, 1.9, 0), Color(1.0, 0.95, 0.88), 0.9, 4.0)
	var counter := c + Vector3(0.2, 0, 1.7)
	K.mesh(root, counter + Vector3(0, 0.55, 0), Vector3(1.6, 1.1, 0.7), dark)
	K.glow(root, counter + Vector3(0.81, 0.95, 0), Vector3(0.02, 0.05, 0.7), INK_CYAN * 1.5)
	var flash := [Color(1.0, 0.3, 0.35), INK_CYAN, Color(1.0, 0.85, 0.3), Color(0.6, 1.0, 0.4), Color(1.0, 0.45, 0.8), Color(0.95, 0.95, 0.9)]
	for k in 10:
		var z := -2.6 + k * 0.55
		K.mesh(root, c + Vector3(-1.16, 1.75 + (k % 2) * 0.45, z), Vector3(0.02, 0.38, 0.32), Art.material("canvas", Color(1.0, 0.96, 0.88)), Vector3(0, 0, (k % 3 - 1) * 4.0))
		K.glow(root, c + Vector3(-1.15, 1.75 + (k % 2) * 0.45, z), Vector3(0.02, 0.14, 0.12), flash[k % flash.size()] * 0.6)
	# the sign on the roof, a pink strip under it
	_neon_text(root, c + Vector3(1.0, 3.05, 0), "INK & IRON", INK_CYAN, 80, 90.0)
	K.glow(root, c + Vector3(1.3, 2.75, 0), Vector3(0.04, 0.05, 5.8), Color(1.0, 0.3, 0.5) * 1.6)
	K.light(root, c + Vector3(1.6, 2.2, 0), INK_CYAN, 1.1, 8.0)
	_solid(root, c + Vector3(-1.2, 1.3, 0), Vector3(0.2, 2.6, 6.0))
	for e: float in [-1.0, 1.0]:
		_solid(root, c + Vector3(0, 1.3, e * 3.0), Vector3(2.5, 2.6, 0.2))
	_solid(root, chair + Vector3(0, 0.6, -0.2), Vector3(0.8, 1.2, 1.8))
	_solid(root, counter + Vector3(0, 0.55, 0), Vector3(1.6, 1.1, 0.7))
	shop(info, "shop_ink", c + Vector3(1.9, 0, 0.6), "[F] Ink & Iron: piercings and tattoos", [
		"Rook did Dad's cog. Said he flinched. Dad said he didn't. I believe Rook.",
	], "ink", {"screen": "ink"})


## The greenhouse cafe on the plaza's east side: a glass hall on white ribs,
## full of plants, tables and string lights. A date spot later.
static func _greenhouse(root: Node3D, info: Dictionary, _rng: RandomNumberGenerator) -> void:
	var front := PLAZA.end.x
	var c := Vector3(front + 6.0, 0, 175.0)
	TP.spawn(root, "greenhouse", Vector3(front, 0, c.z), -90.0, {"leaves": LEAF_TINTS[3]})
	# Walls to walk against: the back, the sides, the front either side of the door.
	for spec in [[Vector3(front + 12.0, 3.0, c.z), Vector3(0.3, 6.0, 12.0)], [Vector3(c.x, 3.0, c.z - 6.0), Vector3(16.0, 6.0, 0.3)],
			[Vector3(c.x, 3.0, c.z + 6.0), Vector3(16.0, 6.0, 0.3)], [Vector3(front, 3.0, c.z - 3.7), Vector3(0.3, 6.0, 4.6)],
			[Vector3(front, 3.0, c.z + 3.7), Vector3(0.3, 6.0, 4.6)]]:
		_solid(root, spec[0], spec[1])
	K.light(root, c + Vector3(0, 5.0, 0), WARM, 1.4, 12.0)
	# Tables out front, clear of the door.
	for t: Vector3 in [Vector3(18.5, 0, 169.0), Vector3(16.5, 0, 172.0), Vector3(16.5, 0, 178.5), Vector3(18.5, 0, 181.5),
			Vector3(13.0, 0, 172.0), Vector3(13.5, 0, 178.0)]:
		TP.spawn(root, "cafe_table", t, t.z * 37.0, {"awning": Color(0.85, 1.0, 0.8)})
		_solid(root, t + Vector3(0, 0.4, 0), Vector3(1.0, 0.8, 1.0))
	_neon_text(root, Vector3(front - 0.1, 4.6, c.z), "greenhouse cafe", LIME, 64, -90.0)
	shop(info, "shop_cafe", Vector3(front - 1.8, 0, c.z), "[F] Greenhouse Cafe", [
		"Every couple in Solace has had their first date in there. I've had coffee in there. Alone.",
		"Someday somebody's going to ask me. And I'm going to make them pay.",
	], "cafe", {"date": "cafe"})


## Cut & Chrome, Juno's hair salon, on the plaza's east side between Sal's and
## the greenhouse: a narrow shop facing the Sun Tree, pink neon, a chair and a
## mirror out front. Juno (tools/salon/build_stylist.py) waits by the door, and
## her chair opens the salon screen (salon_screen.gd): haircuts for Eco and her
## romance options (hair.gd).
const SALON_Z := 164.6
const SALON_PINK := Color(1.0, 0.42, 0.78)


static func _salon(root: Node3D, info: Dictionary) -> void:
	var front := PLAZA.end.x
	var z := SALON_Z
	TP.spawn(root, "shop_w9_f2", Vector3(front, 0, z), -90.0, {"wall": Color(0.98, 0.9, 0.95), "shop": SALON_PINK, "neon": CYAN, "awning": Color(0.95, 0.5, 0.75)})
	_solid(root, Vector3(front + DEPTH * 0.5 + 0.6, GF * 0.5, z), Vector3(DEPTH, GF, 9.0))
	_solid(root, Vector3(front + DEPTH * 0.5 - 0.6, GF + 2 * UF * 0.5, z), Vector3(DEPTH, 2 * UF, 9.0))
	K.light(root, Vector3(front - 1.2, 2.8, z), SALON_PINK.lerp(WARM, 0.3), 1.3, 9.0)
	_neon_text(root, Vector3(front - 0.84, GF + 0.75, z - 0.8), "CUT & CHROME", SALON_PINK, 64, -90.0)
	# A striped neon pole by the door, a styling chair and a tall mirror under the awning.
	var pole := Vector3(front - 0.5, 0, z + 3.6)
	K.mesh(root, pole + Vector3(0, 1.4, 0), Vector3(0.22, 2.8, 0.22), Art.material("gunmetal"))
	for i in 5:
		K.glow(root, pole + Vector3(0, 0.6 + i * 0.5, 0), Vector3(0.26, 0.2, 0.26), (SALON_PINK if i % 2 == 0 else CYAN) * 1.6, Vector3(0, 45, 18))
	var chair := Vector3(front - 2.4, 0, z - 2.6)
	var seat := TP.paint(Color(0.85, 0.2, 0.5), 0.5)
	K.mesh(root, chair + Vector3(0, 0.3, 0), Vector3(0.14, 0.6, 0.14), Art.material("gunmetal"))
	K.mesh(root, chair + Vector3(0, 0.05, 0), Vector3(0.7, 0.1, 0.7), Art.material("gunmetal"))
	K.mesh(root, chair + Vector3(0, 0.66, 0), Vector3(0.62, 0.16, 0.62), seat)
	K.mesh(root, chair + Vector3(0.28, 1.05, 0), Vector3(0.12, 0.7, 0.6), seat)
	for dz: float in [-0.33, 0.33]:
		K.mesh(root, chair + Vector3(0, 0.88, dz), Vector3(0.5, 0.08, 0.08), Art.material("gunmetal"))
	_solid(root, chair + Vector3(0, 0.5, 0), Vector3(0.8, 1.0, 0.8))
	var mirror := chair + Vector3(1.6, 0, 0)
	K.mesh(root, mirror + Vector3(0, 1.3, 0), Vector3(0.1, 2.0, 1.1), TP.paint(Color(0.08, 0.08, 0.1), 0.6))
	K.glow(root, mirror + Vector3(-0.06, 1.3, 0), Vector3(0.02, 1.8, 0.9), Color(0.75, 0.85, 0.95) * 0.5)
	for dz: float in [-0.56, 0.56]:
		K.glow(root, mirror + Vector3(-0.07, 1.3, dz), Vector3(0.04, 2.0, 0.05), SALON_PINK * 1.6)
	K.light(root, chair + Vector3(-0.8, 2.2, 0), SALON_PINK, 0.8, 5.0)
	_poster(root, Vector3(front - 0.03, 2.1, z + 2.0), -90.0, "NEW YOU\nSAME BAD\nATTITUDE", "walk-ins ok", SALON_PINK)
	# Juno by her chair, facing the plaza.
	if not info.has("npcs"):
		info["npcs"] = []
	info["npcs"].append({"who": "stylist", "pos": chair + Vector3(-0.2, 0, 1.3), "yaw": 90.0})
	shop(info, "salon", chair + Vector3(-1.2, 0, 0.6), "[F] Cut & Chrome: Juno's chair (haircuts)", [
		"Juno cut my hair when I was nine. Dad said I looked like a rebel. Juno said 'good.'",
	], "salon")
	info["interactables"].back()["screen"] = "salon"


# --- Low Row --------------------------------------------------------------------

static func _low_row(root: Node3D, info: Dictionary, rng: RandomNumberGenerator) -> void:
	var arcade := _building(root, -1, 196.5, "shop_w13_f3b", 13.0, {"wall": Color(0.55, 0.52, 0.62), "shop": VIOLET, "neon": CYAN, "awning": Color(0.5, 0.35, 0.8)}, "ARCADE")
	_blade_sign(root, -1, 191.5, "GLOW\nBOX", VIOLET)
	shop(info, "shop_arcade", arcade, "[F] Glowbox Arcade", [
		"I hold the record on Titan Brawl III. The machine says 'ECO'. Somebody keeps scratching it off.",
		"Bring a date, win them a prize. Or bring nobody and win everything.",
	], "arcade", {"date": "arcade"})

	# Eco's old flat, boarded up.
	var flat := Vector3(-STREET_HALF, 0, 209.0)
	_building(root, -1, 209.0, "shop_w9_f3", 9.0, {"wall": Color(0.82, 0.8, 0.76), "shop": WARM, "neon": Color(0.2, 0.2, 0.2)}, "")
	_graffiti(root, Vector3(-STREET_HALF - 1.42, 2.0, 209.0), 90.0, "TRAITOR'S KID", RED, 110)
	shop(info, "old_flat", flat + Vector3(1.8, 0, 0), "[F] Look at the old flat", [
		"Our old flat. Somebody painted that the week after Dad's funeral.",
		"Mom wanted to scrub it off. I wanted them to look at it every day.",
	])

	var bar := _building(root, 1, 196.5, "shop_w13_f3", 13.0, {"wall": Color(0.62, 0.55, 0.5), "shop": AMBER, "neon": MAGENTA, "awning": Color(0.45, 0.2, 0.25)}, "BAR")
	_blade_sign(root, 1, 191.5, "RUSTED\nHALO", AMBER)
	_smoke(root, Vector3(STREET_HALF + 0.6, 0.3, 202.5))
	shop(info, "shop_bar", bar, "[F] The Rusted Halo: jobs and rumours (coming soon)", [
		"Every bad idea in Solace starts at the Halo. Most of mine did.",
		"The fixer in the back booth pays in cash and doesn't ask why I can shoot.",
	], "bar", {"date": "bar"})  # a Mature-only date (town_shops.gd DATES)
	# The back step in the alley by the Halo, where Ophelia smokes: a
	# Mature-only date (share her last cigarette).
	K.mesh(root, Vector3(STREET_HALF + 0.5, 0.1, 203.6), Vector3(0.9, 0.2, 0.6), Art.material("concrete"))
	K.mesh(root, Vector3(STREET_HALF + 0.45, 0.45, 204.55), Vector3(0.6, 0.9, 0.55), Art.material("gunmetal", Color(0.22, 0.3, 0.26)))
	shop(info, "halo_step", Vector3(STREET_HALF - 0.6, 0, 204.0), "[F] The Halo's back step", [
		"Ophelia's spot. Bins, a step, one flickering light. She says it's the only quiet place in town.",
	], "", {"date": "smoke"})

	var cinema := _building(root, 1, 209.5, "shop_w9_f2", 9.0, {"wall": Color(0.84, 0.88, 0.94), "shop": CYAN}, "HOLO-CINEMA")
	_neon_text(root, Vector3(STREET_HALF - 0.62, GF - 1.6, 209.5), "TONIGHT: TITANFALL ROMANCE", Color(1.0, 0.95, 0.85), 30, -90.0)
	shop(info, "shop_cinema", cinema, "[F] Holo-Cinema", [
		"They only play war films now. The heroes never cry. Not once. Not even when the dog dies.",
	], "cinema", {"date": "cinema"})
	_street_life(root, 190.0, 214.0, rng)


# --- the rooftop garden -------------------------------------------------------

static func _garden(root: Node3D, info: Dictionary, rng: RandomNumberGenerator) -> void:
	var g := GARDEN
	var top := GARDEN_Y
	var white := Art.material("concrete", Color(0.82, 0.84, 0.8))
	# The terrace it sits on, with a ramp of steps up from the street.
	Kit.box(root, Vector3(g.get_center().x, top * 0.5, g.get_center().y), Vector3(g.size.x, top, g.size.y), K.STONE, Vector3.ZERO, white)
	var ramp_len := 9.0
	var ang := rad_to_deg(atan2(top, ramp_len))
	Kit.box(root, Vector3(0, top * 0.5 - 0.15, g.position.y - ramp_len * 0.5), Vector3(6.0, 0.3, sqrt(ramp_len * ramp_len + top * top)), K.STONE,
			Vector3(-ang, 0, 0), Art.material("temple_stone", Color(0.72, 0.73, 0.7)))
	# Steps drawn over the ramp (you walk the smooth ramp underneath), with rail posts.
	var steps := 15
	var step_mat := Art.material("temple_stone", Color(0.88, 0.88, 0.84))
	var edge_mat := Art.material("gunmetal", Color(0.3, 0.3, 0.34))
	for k in steps:
		var h := top * (k + 1) / steps
		var sz := g.position.y - ramp_len + ramp_len * (k + 0.5) / steps
		K.mesh(root, Vector3(0, h - top / steps * 0.5, sz), Vector3(5.9, top / steps, ramp_len / steps), step_mat)
		K.mesh(root, Vector3(0, h - 0.02, sz - ramp_len / steps * 0.5 + 0.03), Vector3(5.9, 0.05, 0.06), edge_mat)
	for s: float in [-1.0, 1.0]:
		K.mesh(root, Vector3(s * 3.1, top * 0.5 + 0.9, g.position.y - ramp_len * 0.5), Vector3(0.08, 0.08, sqrt(ramp_len * ramp_len + top * top)), Art.material("gunmetal"), Vector3(-ang, 0, 0))
		for k in 7:
			var pz := g.position.y - ramp_len + ramp_len * (k + 0.5) / 7.0
			var ph := top * (k + 0.5) / 7.0
			K.mesh(root, Vector3(s * 3.1, ph + 0.45, pz), Vector3(0.07, 0.9, 0.07), Art.material("gunmetal"))
	K.mesh(root, Vector3(0, top + 0.05, g.get_center().y), Vector3(g.size.x - 1.0, 0.1, g.size.y - 1.0), Art.material("grass"))
	# Dress the terrace's street face: ivy, planters by the steps, a sign over them.
	for i in 10:
		var x := -15.0 + i * 3.2
		if absf(x) < 4.0:
			continue
		K.mesh(root, Vector3(x, top - 1.6, g.position.y - 0.08), Vector3(rng.randf_range(1.2, 2.6), rng.randf_range(2.0, 3.6), 0.15), Art.material("moss", Color(0.72, 1.0, 0.62)))
		Props.spawn(root, "fern", Vector3(x, top + 0.05, g.position.y + 0.8), rng.randf_range(0, 360), 0.6, {"leaves": LEAF_TINTS[i % 4]})
	for sx: float in [-1.0, 1.0]:
		TP.spawn(root, "planter", Vector3(sx * 5.5, 0, g.position.y - 2.0), 0.0, {"leaves": LEAF_TINTS[2]})
		_solid(root, Vector3(sx * 5.5, 0.4, g.position.y - 2.0), Vector3(2.4, 0.8, 2.4))
		K.mesh(root, Vector3(sx * 3.2, top + 1.6, g.position.y), Vector3(0.18, 3.2, 0.18), Art.material("gunmetal"))
	K.mesh(root, Vector3(0, top + 3.2, g.position.y), Vector3(6.6, 0.2, 0.25), Art.material("gunmetal"))
	_neon_text(root, Vector3(0, top + 2.7, g.position.y - 0.14), "ROOFTOP GARDEN", LIME, 64, 180.0)
	# Low walls round the edge (not across the steps).
	for spec in [[Vector3(g.position.x + 0.3, top + 0.5, g.get_center().y), Vector3(0.6, 1.0, g.size.y)],
			[Vector3(g.end.x - 0.3, top + 0.5, g.get_center().y), Vector3(0.6, 1.0, g.size.y)],
			[Vector3(0, top + 0.5, g.end.y - 0.3), Vector3(g.size.x, 1.0, 0.6)],
			[Vector3(-9.5, top + 0.5, g.position.y + 0.3), Vector3(13.0, 1.0, 0.6)], [Vector3(9.5, top + 0.5, g.position.y + 0.3), Vector3(13.0, 1.0, 0.6)]]:
		Kit.box(root, spec[0], spec[1], K.STONE, Vector3.ZERO, white)
	# Beds of plants, a pergola with string lights, a bench at the view.
	for i in 8:
		var p := Vector3(rng.randf_range(g.position.x + 2, g.end.x - 2), top + 0.1, rng.randf_range(g.position.y + 4, g.end.y - 6))
		if absf(p.x) < 4.0:
			continue
		Props.spawn(root, ["bush_a", "bush_b", "fern"][i % 3], p, rng.randf_range(0, 360), 0.9, {"leaves": LEAF_TINTS[i % 4]})
	for p in [Vector3(-12, top, 238), Vector3(12, top, 238)]:
		Props.tree(root, p, rng, 0.7)
	var pergola := Vector3(0, top, 236.0)
	TP.spawn(root, "pergola", pergola, 0.0, {"leaves": LEAF_TINTS[1]})
	for dx: float in [-4.0, 4.0]:
		for dz: float in [-2.5, 2.5]:
			_solid(root, pergola + Vector3(dx, 1.5, dz), Vector3(0.25, 3.0, 0.25))
	K.light(root, pergola + Vector3(0, 2.6, 0), WARM, 1.2, 9.0)
	_bench(root, pergola + Vector3(0, 0, 1.0), 0.0)
	shop(info, "garden", pergola + Vector3(0, 0, -1.0), "[F] Rooftop garden", [
		"Best view in Solace. You can see the turbines, the jungle, and the city they keep promising us.",
		"Dad proposed to Mom up here. She said no the first time. Runs in the family.",
	], "garden", {"date": "garden"})


# --- overhead: canopy, cables, vines -----------------------------------------

## A solar canopy over each shop row (canopy_bay models, a few bays left out
## so the sun stripes through), cables strung across lower down with paper
## lanterns, the occasional holo ad.
static func _canopy(root: Node3D, rng: RandomNumberGenerator) -> void:
	for seg: Vector2 in ROWS:
		var z := seg.x + 2.0
		var i := 0
		# One open bay per row lets a shaft of sun in; the rest is roofed over.
		var gap := int((seg.y - seg.x) / 8.0)
		while z < seg.y - 1.0:
			if i != gap:
				TP.spawn(root, "canopy_bay", Vector3(0, CANOPY_Y, z), 0.0, {"leaves": LEAF_TINTS[i % 4]})
			z += 4.0
			i += 1
		# Cables strung across lower down, with lanterns.
		var cz := seg.x + 2.5
		while cz < seg.y:
			var y := rng.randf_range(6.0, 8.5)
			K.mesh(root, Vector3(0, y, cz), Vector3(STREET_HALF * 2, 0.04, 0.04), Art.material("gunmetal"), Vector3(0, rng.randf_range(-6, 6), 0))
			var tints := [MAGENTA, CYAN, AMBER, WARM, LIME]
			for k in 3:
				var lx := -4.0 + k * 4.0 + rng.randf_range(-0.8, 0.8)
				var col: Color = tints[rng.randi() % tints.size()]
				TP.spawn(root, "lantern", Vector3(lx, y, cz), rng.randf_range(0, 90), {"shop": col * 1.4})
			cz += rng.randf_range(4.0, 7.0)
		# A holo ad hanging under the canopy halfway along.
		var hz := (seg.x + seg.y) * 0.5
		var side := -1.0 if seg.x < 150.0 else 1.0
		K.mesh(root, Vector3(side * 3.0, CANOPY_Y - 0.6, hz), Vector3(0.03, 1.2, 0.03), Art.material("gunmetal"))
		var holo := K.glow(root, Vector3(side * 3.0, CANOPY_Y - 2.2, hz), Vector3(0.05, 2.0, 3.4), (VIOLET if side < 0 else CYAN) * 0.7)
		holo.transparency = 0.35
		var ad := _neon_text(root, Vector3(side * 3.0 + 0.04, CANOPY_Y - 2.2, hz), "SOLACE POWER\nCLEAN SUN\nFOR CLEAN CITIZENS" if side < 0 else "ENLIST TODAY\nHARDENED\nHEARTS ONLY", Color(1, 1, 1), 34, 90.0)
		ad.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y


# --- around the town ------------------------------------------------------------

## Jungle behind the buildings, wind turbines on the ridge, and the capital's
## towers dark on the horizon.
static func _surroundings(root: Node3D, rng: RandomNumberGenerator) -> void:
	var trees := {}
	for id in Props.TREES:
		trees[id] = []
	for i in 260:
		var p := Vector3(rng.randf_range(-TOWN_HALF - 40, TOWN_HALF + 40), 0, rng.randf_range(TOWN_GATE - 30, TOWN_END + 40))
		var in_town := absf(p.x) < TOWN_HALF + 2 and p.z > TOWN_GATE - 2 and p.z < TOWN_END + 2
		var on_road := absf(p.x) < ROAD_HALF + 5 and p.z < TOWN_GATE
		var in_hub := absf(p.x) < 76 and p.z < ROAD_START + 4
		if in_town or on_road or in_hub:
			continue
		var id: String = Props.TREES[i % Props.TREES.size()]
		trees[id].append(Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * rng.randf_range(1.0, 1.6)), p))
	for id in trees:
		Props.scatter(root, id, trees[id], LEAF_TINTS[Props.TREES.find(id) % LEAF_TINTS.size()])
	# Back of the town: terraced garden walls between the rows and the jungle.
	for s: float in [-1.0, 1.0]:
		for spec in [[146.0, 28.0, 6.0 if s < 0 else 9.0], [202.0, 24.0, 4.0 if s < 0 else 7.5]]:
			var th: float = spec[2]
			Kit.box(root, Vector3(s * (TOWN_HALF - 12), th * 0.5, spec[0]), Vector3(24, th, spec[1]), K.STONE, Vector3.ZERO,
					Art.material("concrete", Color(0.86, 0.87, 0.83)))
			K.mesh(root, Vector3(s * (TOWN_HALF - 12), th + 0.1, spec[0]), Vector3(23, 0.2, spec[1] - 1), Art.material("moss", Color(0.75, 1.0, 0.65)))
			# A lower step on the street side, and ivy down the wall.
			Kit.box(root, Vector3(s * (TOWN_HALF - 22.5), th * 0.3, spec[0]), Vector3(3, th * 0.6, spec[1] * 0.7), K.STONE, Vector3.ZERO,
					Art.material("concrete", Color(0.8, 0.81, 0.78)))
			K.mesh(root, Vector3(s * (TOWN_HALF - 24.05), th * 0.5, spec[0] + 3.0), Vector3(0.12, th * 0.8, 5.0), Art.material("moss", Color(0.72, 1.0, 0.62)))
			for i in 4:
				Props.tree(root, Vector3(s * (TOWN_HALF - 6 - i * 3.5), th, spec[0] - spec[1] * 0.35 + i * spec[1] * 0.22), rng, 0.5 + 0.15 * (i % 3), false)
	# Wind turbines on the ridges, turned to face the town.
	for spec in [Vector3(-70, 0, 230), Vector3(-45, 0, 275), Vector3(60, 0, 250), Vector3(20, 0, 300), Vector3(-15, 0, 320)]:
		var tower := TP.spawn(root, "turbine_tower", spec, 180.0)
		var rotor := _animated(tower, Vector3(0, 28.0, 2.1), Ambient.Mode.SPIN, 1.0, 0.6 + absf(spec.x) * 0.004)
		TP.spawn(rotor, "turbine_rotor", Vector3.ZERO)
	# The city on the horizon: dark stepped towers, lit bands, red beacons.
	for i in 22:
		var x := -180.0 + i * 17.0 + rng.randf_range(-5, 5)
		if absf(x) < 30.0:
			continue  # keep the view down the street to the gate clear
		var scale := rng.randf_range(0.6, 1.2) * (1.3 if absf(x) < 60 else 1.0)
		TP.spawn(root, "city_tower_a" if i % 3 != 1 else "city_tower_b", Vector3(x, -40.0, rng.randf_range(430.0, 480.0)), 180.0,
				{"shop": [AMBER, CYAN, MAGENTA][i % 3] / 0.6, "no_fog": true}, scale)


## Invisible fences: either side of the road and round the town.
static func _fences(root: Node3D) -> void:
	var road_mid := (ROAD_START + TOWN_GATE) * 0.5
	var road_len := TOWN_GATE - ROAD_START + 2.0
	for spec in [[Vector3(-ROAD_HALF - 4.5, 0, road_mid), Vector3(1, 60, road_len)], [Vector3(ROAD_HALF + 4.5, 0, road_mid), Vector3(1, 60, road_len)],
			[Vector3(-(TOWN_HALF + ROAD_HALF + 4.5) * 0.5, 0, TOWN_GATE - 1.0), Vector3(TOWN_HALF - ROAD_HALF - 4.5, 60, 1)],
			[Vector3((TOWN_HALF + ROAD_HALF + 4.5) * 0.5, 0, TOWN_GATE - 1.0), Vector3(TOWN_HALF - ROAD_HALF - 4.5, 60, 1)],
			[Vector3(-TOWN_HALF, 0, (TOWN_GATE + TOWN_END) * 0.5), Vector3(1, 60, TOWN_END - TOWN_GATE)],
			[Vector3(TOWN_HALF, 0, (TOWN_GATE + TOWN_END) * 0.5), Vector3(1, 60, TOWN_END - TOWN_GATE)],
			[Vector3(0, 0, TOWN_END), Vector3(TOWN_HALF * 2, 60, 1)]]:
		var fence := StaticBody3D.new()
		var col := CollisionShape3D.new()
		col.shape = BoxShape3D.new()
		col.shape.size = spec[1]
		fence.add_child(col)
		fence.position = spec[0] + Vector3(0, 30, 0)
		root.add_child(fence)


# --- building kit -------------------------------------------------------------

## A shop building (tools/town/build_town.py) on one side of the street (side
## -1 west, +1 east), its front on the kerb and centred on z: a dark ground
## floor with a lit shopfront, pale upper floors overhanging the pavement with
## balconies and plants, panels or a garden on the roof. `sign` goes on the
## board over the shopfront. Returns the spot in front of its door.
static func _building(root: Node3D, side: int, z: float, id: String, width: float, tints: Dictionary, sign: String) -> Vector3:
	var s := float(side)
	var face := s * STREET_HALF
	TP.spawn(root, id, Vector3(face, 0, z), -90.0 * s, tints)
	var floors := int(id.substr(id.find("_f") + 2, 1))
	var height := GF + floors * UF
	_solid(root, Vector3(face + s * (DEPTH * 0.5 + 0.6), GF * 0.5, z), Vector3(DEPTH, GF, width))
	_solid(root, Vector3(face + s * (DEPTH * 0.5 - 0.6), GF + floors * UF * 0.5, z), Vector3(DEPTH, floors * UF, width))
	_solid(root, Vector3(face + s * (DEPTH * 0.5 - 0.6), height + 0.1, z), Vector3(DEPTH, 0.2, width))
	var shop_color: Color = tints.get("shop", WARM)
	K.light(root, Vector3(face - s * 1.2, 2.8, z), shop_color.lerp(WARM, 0.3), 1.3, 9.0)
	if sign != "":
		var size := 90 if sign.length() <= 8 else (64 if sign.length() <= 15 else 50)
		_neon_text(root, Vector3(face - s * 0.84, GF + 0.75, z - s * 0.8), sign, tints.get("neon", shop_color), size, -90.0 * s)
	return Vector3(face - s * 1.8, 0, z)


## A tall vertical neon sign sticking out from the building front into the street.
static func _blade_sign(root: Node3D, side: int, z: float, text: String, color: Color) -> void:
	var s := float(side)
	var x := s * (STREET_HALF - 1.65)
	var lines := text.count("\n") + 1
	var h := 1.4 + lines * 1.1
	var y := GF + 1.6 + h * 0.5
	TP.spawn(root, "blade_sign_%d" % clampi(lines, 2, 3), Vector3(x, GF + 1.6, z), 0.0 if s > 0.0 else 180.0, {"neon": color})
	for face: float in [-1.0, 1.0]:
		var l := _neon_text(root, Vector3(x, y, z + face * 0.17), text, color, 40, 0.0 if face > 0 else 180.0)
		l.line_spacing = -10.0
	K.light(root, Vector3(x, y, z), color, 1.2, 8.0)


static func _neon_text(root: Node3D, pos: Vector3, text: String, color: Color, size: int, yaw: float) -> Label3D:
	var l := Kit.label(root, pos, text, size)
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	l.rotation_degrees.y = yaw
	l.modulate = Color(color.r * 2.2, color.g * 2.2, color.b * 2.2)
	l.outline_modulate = Color(color.r, color.g, color.b, 0.6)
	l.outline_size = 10
	l.double_sided = false
	return l


static func _graffiti(root: Node3D, pos: Vector3, yaw: float, text: String, color: Color, size := 70) -> void:
	var l := Kit.label(root, pos, text, size)
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	l.rotation_degrees = Vector3(0, yaw, -4)
	l.modulate = color.darkened(0.15)
	l.outline_size = 0
	l.shaded = true
	l.double_sided = false


## A paper poster on a wall: big headline, scrawl underneath.
static func _poster(root: Node3D, pos: Vector3, yaw: float, headline: String, scrawl: String, tint: Color) -> void:
	var dir := Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0, 0, 1)
	K.mesh(root, pos, Vector3(1.6, 2.2, 0.03), Art.material("canvas", tint.lightened(0.3)), Vector3(0, yaw, 0))
	var l := Kit.label(root, pos + dir * 0.03 + Vector3(0, 0.45, 0), headline, 36)
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	l.rotation_degrees.y = yaw
	l.modulate = Color(0.15, 0.15, 0.12)
	l.outline_size = 0
	l.shaded = true
	l.double_sided = false
	if scrawl != "":
		var w := Kit.label(root, pos + dir * 0.04 + Vector3(0, -0.55, 0), scrawl, 26)
		w.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		w.rotation_degrees = Vector3(0, yaw, -6)
		w.modulate = Color(0.95, 0.15, 0.4)
		w.outline_size = 0
		w.shaded = true
		w.double_sided = false





static func _mannequins(root: Node3D, side: int, z: float) -> void:
	var s := float(side)
	for dz: float in [-3.5, -1.5]:
		var p := Vector3(s * (STREET_HALF + 1.4), 0, z + dz)
		K.mesh(root, p + Vector3(0, 1.0, 0), Vector3(0.4, 0.9, 0.3), TP.paint(Color(0.85, 0.2, 0.45), 0.6))
		K.mesh(root, p + Vector3(0, 1.75, 0), Vector3(0.5, 0.6, 0.32), TP.paint(Color(0.12, 0.12, 0.14), 0.6))
		K.mesh(root, p + Vector3(0, 2.25, 0), Vector3(0.22, 0.28, 0.22), TP.paint(Color(0.9, 0.9, 0.9), 0.3))
		K.mesh(root, p + Vector3(0, 0.3, 0), Vector3(0.1, 0.6, 0.1), Art.material("gunmetal"))





static func _scrap_pile(root: Node3D, p: Vector3) -> void:
	var armor := Art.material("titan_armor")
	K.metal(root, p + Vector3(0, 0.4, 0), Vector3(1.4, 0.8, 2.0), Vector3(0, 15, 6))
	K.mesh(root, p + Vector3(0.2, 1.0, -0.4), Vector3(1.0, 0.5, 1.2), armor, Vector3(10, 40, 20))
	K.mesh(root, p + Vector3(-0.2, 0.3, 1.6), Vector3(1.2, 0.6, 1.0), armor, Vector3(0, -25, 0))


static func _bench(root: Node3D, p: Vector3, yaw: float) -> void:
	TP.spawn(root, "bench", p, yaw)
	var body := _solid(root, p + Vector3(0, 0.4, 0), Vector3(2.4, 0.8, 0.7))
	body.rotation_degrees.y = yaw


## Crates, vending machines, steam vents and a parked scooter along a stretch of street.
static func _street_life(root: Node3D, z0: float, z1: float, rng: RandomNumberGenerator) -> void:
	for i in 5:
		var s := -1.0 if rng.randf() < 0.5 else 1.0
		var p := Vector3(s * rng.randf_range(STREET_HALF - 1.4, STREET_HALF - 0.9), 0, rng.randf_range(z0 + 2, z1 - 2))
		match i % 3:
			0:
				TP.spawn(root, "crates", p, rng.randf_range(0, 360))
				_solid(root, p + Vector3(0, 0.5, 0), Vector3(1.4, 1.0, 1.4))
			1:
				TP.spawn(root, "vending", p, -90.0 * s, {"shop": [CYAN, MAGENTA, LIME][rng.randi() % 3] / 0.6})
				_solid(root, p + Vector3(0, 1.0, 0), Vector3(1.0, 2.0, 1.0))
			2:
				K.mesh(root, Vector3(rng.randf_range(-2.5, 2.5), 0.08, p.z), Vector3(1.2, 0.06, 1.2), Art.material("gunmetal"))
				_smoke(root, Vector3(p.x * 0.3, 0.2, p.z))
	var sp := Vector3(STREET_HALF - 1.2, 0, rng.randf_range(z0 + 4, z1 - 4))
	TP.spawn(root, "scooter", sp, 180.0, {"wall": Color(0.95, 0.85, 0.3)})


# --- materials and life ---------------------------------------------------------

## An invisible collider (the models carry no collision of their own).
static func _solid(root: Node3D, pos: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	col.shape = BoxShape3D.new()
	col.shape.size = size
	body.add_child(col)
	body.position = pos
	root.add_child(body)
	return body








static func _animated(parent: Node, pos: Vector3, mode: int, amount: float, speed: float) -> Node3D:
	var node: Node3D = Ambient.new()
	node.mode = mode
	node.amount = amount
	node.speed = speed
	node.position = pos
	parent.add_child(node)
	return node


static var _puff_tex: Texture2D


## A soft round puff for steam sprites.
static func _puff() -> Texture2D:
	if _puff_tex == null:
		var grad := Gradient.new()
		grad.set_color(0, Color(1, 1, 1, 1))
		grad.set_color(1, Color(1, 1, 1, 0))
		var tex := GradientTexture2D.new()
		tex.gradient = grad
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 64
		tex.height = 64
		_puff_tex = tex
	return _puff_tex


## Steam from a vent or a kitchen.
static func _smoke(root: Node3D, p: Vector3) -> void:
	var smoke := CPUParticles3D.new()
	smoke.position = p
	smoke.amount = 14
	smoke.lifetime = 4.0
	var quad := QuadMesh.new()
	quad.size = Vector2(1.4, 1.4)
	# Faint, wide and unshaded: lit steam went dark against the neon, bright steam read as a ghost.
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color(0.72, 0.68, 0.85, 0.1)
	mat.albedo_texture = _puff()
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	smoke.mesh = quad
	smoke.direction = Vector3.UP
	smoke.spread = 25.0
	smoke.gravity = Vector3(0.2, 0.5, 0)
	smoke.initial_velocity_min = 0.5
	smoke.initial_velocity_max = 0.9
	smoke.scale_amount_min = 1.0
	smoke.scale_amount_max = 2.5
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.7))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	smoke.color_ramp = fade
	root.add_child(smoke)
