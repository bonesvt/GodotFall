extends RefCounted
## Solace, Eco's hometown, down the old pilgrim road past the hub's front gate.
##
## Solarpunk on top, dark cyberpunk underneath: white terraces hung with
## gardens, solar sails and wind turbines up in the sun, and under the panel
## canopy a narrow street of neon, wet paving, cables and steam. The town has
## mostly decided Eco is trouble, and the militia that turned her away keeps a
## recruiting office on the plaza.
##
##   z 96..126   the pilgrim road through the jungle, wooden lamps giving way to solar ones
##   z 126..132  the town gate: solar pylons, the SOLACE sign, a militia checkpoint
##   z 132..160  Lantern Row: the outfitter and the clinic west, noodles and salvage east
##   z 160..190  Sun Plaza: the Sun Tree, the fountain, the job board, the militia
##               office west, the greenhouse cafe east
##   z 190..214  Low Row: the arcade and Eco's old flat west, the bar and the cinema east
##   z 214..244  the rooftop garden up the steps, looking out over the valley
##
## Shops are placeholders for later features: each is an interactable with a
## "shop" key naming what it will sell (SHOPS), and Eco's lines for now.

const K := preload("res://scripts/hub/hub_kit.gd")
const Kit := preload("res://scripts/run/level_kit.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")
const Props := preload("res://scripts/hub/hub_props.gd")
const Ambient := preload("res://scripts/hub/ambient.gd")
const TITAN_PAINT := preload("res://assets/shaders/titan_paint.gdshader")

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

## What each shop will be for once its feature exists.
const SHOPS := {
	"outfitter": "outfits",
	"noodles": "meals (run stat boosts)",
	"salvage": "parts trading",
	"clinic": "healing and implants",
	"jobs": "quests",
	"cafe": "dates",
	"arcade": "dates",
	"bar": "quest givers and rumours",
	"cinema": "dates",
	"garden": "dates",
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
	_garden(town, info, rng)
	_canopy(town, rng)
	_surroundings(town, rng)
	_fences(town)


## Shops and spots in the town (ids from info["interactables"]).
static func shop(info: Dictionary, id: String, pos: Vector3, prompt: String, lines: Array, kind := "") -> void:
	K.interactable(info, id, pos, prompt, lines, 2.8)
	if kind != "":
		info["interactables"].back()["shop"] = kind


# --- the road -----------------------------------------------------------------

static func _road(root: Node3D, _info: Dictionary, rng: RandomNumberGenerator) -> void:
	var length := TOWN_GATE - ROAD_START
	K.mesh(root, Vector3(0, 0.03, ROAD_START + length * 0.5), Vector3(ROAD_HALF * 2, 0.04, length), Art.material("dirt"))
	# Old pilgrim flagstones, broken, then the town's newer pavers.
	for i in 14:
		var z := ROAD_START + 3.0 + i * 2.2
		if rng.randf() < 0.7:
			K.mesh(root, Vector3(rng.randf_range(-1.2, 1.2), 0.05, z), Vector3(rng.randf_range(1.2, 2.2), 0.06, 1.4),
					Art.material("temple_stone", Color(0.85, 0.88, 0.82)), Vector3(0, rng.randf_range(-12, 12), 0))
	# Wooden lamps near the temple, solar lamps nearer town.
	for i in 5:
		var z := ROAD_START + 5.0 + i * 6.5
		var s := -1.0 if i % 2 == 0 else 1.0
		var p := Vector3(s * (ROAD_HALF + 0.8), 0, z)
		if i < 2:
			K.wood(root, p + Vector3(0, 1.5, 0), Vector3(0.25, 3.0, 0.25))
			K.glow(root, p + Vector3(0, 3.1, 0), Vector3(0.3, 0.4, 0.3), WARM)
		else:
			_solar_lamp(root, p, CYAN)
	# A shrine stone at the bend, half swallowed by roots.
	K.carved(root, Vector3(-ROAD_HALF - 2.5, 1.0, ROAD_START + 14), Vector3(1.4, 2.0, 1.0), Vector3(0, 20, 6), Color(0.75, 0.85, 0.78))
	K.mesh(root, Vector3(-ROAD_HALF - 2.5, 2.1, ROAD_START + 14), Vector3(1.6, 0.6, 1.2), Art.material("moss"), Vector3(0, 20, 6))
	for p in [Vector3(ROAD_HALF + 2, 0, ROAD_START + 9), Vector3(-ROAD_HALF - 2, 0, ROAD_START + 24), Vector3(ROAD_HALF + 2.5, 0, ROAD_START + 28)]:
		Props.spawn(root, ["bush_a", "bush_b", "fern"][rng.randi() % 3], p, rng.randf_range(0, 360), 1.1, {"leaves": LEAF_TINTS[rng.randi() % 4]})


## A white lamp post with a little solar panel on top and a coloured glow.
static func _solar_lamp(root: Node3D, p: Vector3, color: Color) -> void:
	K.mesh(root, p + Vector3(0, 2.0, 0), Vector3(0.16, 4.0, 0.16), _paint(Color(0.92, 0.93, 0.9), 0.4))
	K.mesh(root, p + Vector3(0, 4.15, 0), Vector3(0.9, 0.05, 0.6), _panel(), Vector3(25, 0, 0))
	K.glow(root, p + Vector3(0, 3.6, 0), Vector3(0.22, 0.5, 0.22), color)


# --- ground -------------------------------------------------------------------

static func _ground(root: Node3D) -> void:
	# Dark, wet paving down the street, pale stone on the plaza.
	var street := _paint(Color(0.16, 0.17, 0.2), 0.75)
	Kit.box(root, Vector3(0, -0.45, (TOWN_GATE + TOWN_END) * 0.5), Vector3(TOWN_HALF * 2, 1.0, TOWN_END - TOWN_GATE), K.STONE, Vector3.ZERO,
			Art.material("concrete", Color(0.42, 0.42, 0.46))).set_meta("surface", "metal")
	K.mesh(root, Vector3(0, 0.06, 176), Vector3(STREET_HALF * 2, 0.04, 88), street)
	K.mesh(root, Vector3(PLAZA.get_center().x, 0.07, PLAZA.get_center().y), Vector3(PLAZA.size.x, 0.04, PLAZA.size.y),
			Art.material("temple_stone", Color(1.0, 1.0, 0.96)))
	# Gutter lights along the kerbs, cyan on one side and magenta on the other.
	for s: float in [-1.0, 1.0]:
		for seg in [[132.0, 160.0], [190.0, 214.0]]:
			var z0: float = seg[0]
			var z1: float = seg[1]
			K.glow(root, Vector3(s * (STREET_HALF - 0.3), 0.1, (z0 + z1) * 0.5), Vector3(0.08, 0.05, z1 - z0), CYAN if s < 0 else MAGENTA)
	# Puddles that pick up the neon.
	var puddle := StandardMaterial3D.new()
	puddle.albedo_color = Color(0.05, 0.06, 0.08, 0.85)
	puddle.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puddle.roughness = 0.02
	puddle.metallic = 0.6
	for spec in [[Vector3(-2.5, 0.09, 140), Vector3(3.0, 0.02, 2.0)], [Vector3(3.0, 0.09, 151), Vector3(2.2, 0.02, 3.4)],
			[Vector3(-1.0, 0.09, 197), Vector3(4.0, 0.02, 2.4)], [Vector3(2.4, 0.09, 207), Vector3(2.0, 0.02, 1.6)]]:
		K.mesh(root, spec[0], spec[1], puddle, Vector3(0, spec[0].z * 7.0, 0))


# --- the gate -----------------------------------------------------------------

static func _gate(root: Node3D, info: Dictionary) -> void:
	var z := TOWN_GATE
	var white := _paint(Color(0.9, 0.91, 0.88), 0.35)
	for s: float in [-1.0, 1.0]:
		var x := s * (STREET_HALF + 1.5)
		Kit.box(root, Vector3(x, 6.0, z), Vector3(2.4, 12.0, 2.4), K.STONE, Vector3.ZERO, white)
		# Vertical garden up the pylon's inner face.
		K.mesh(root, Vector3(x - s * 1.25, 5.0, z), Vector3(0.2, 8.0, 2.0), Art.material("moss", Color(0.7, 1.0, 0.6)))
		for i in 4:
			Props.spawn(root, "fern", Vector3(x - s * 1.4, 1.6 + i * 2.0, z + (0.5 if i % 2 == 0 else -0.5)), i * 70.0, 0.55, {"leaves": LEAF_TINTS[i % 4]})
		# Solar petals fanned out on top.
		for j in 3:
			K.mesh(root, Vector3(x + s * (j - 1) * 0.9, 12.6, z + (j - 1) * 0.6), Vector3(2.4, 0.08, 1.6), _panel(), Vector3(18 * (j - 1), 0, s * 20))
	# Arch beam and the neon name.
	K.mesh(root, Vector3(0, 10.4, z), Vector3(STREET_HALF * 2 + 5, 1.2, 1.0), _paint(Color(0.2, 0.21, 0.24), 0.5))
	_neon_text(root, Vector3(0, 10.4, z - 0.55), "SOLACE", CYAN, 150, 180.0)
	_neon_text(root, Vector3(0, 10.4, z + 0.55), "SOLACE", CYAN, 150, 0.0)
	K.light(root, Vector3(0, 9.0, z - 2.0), CYAN, 1.6, 12.0)
	# Militia checkpoint on the east side: booth, raised boom, a flag, a poster.
	var booth := Vector3(STREET_HALF + 4.5, 0, z - 3.0)
	Kit.box(root, booth + Vector3(0, 1.4, 0), Vector3(2.6, 2.8, 2.6), K.STONE, Vector3.ZERO, Art.material("gunmetal", Color(0.55, 0.6, 0.55)))
	K.glow(root, booth + Vector3(-1.32, 1.8, 0), Vector3(0.04, 0.9, 1.8), Color(1.0, 0.85, 0.6) * 0.6)
	K.mesh(root, booth + Vector3(0, 2.9, 0), Vector3(3.0, 0.2, 3.0), Art.material("gunmetal"))
	K.glow(root, booth + Vector3(0, 3.1, 0), Vector3(0.2, 0.2, 0.2), RED)
	K.mesh(root, booth + Vector3(-2.2, 2.6, 0), Vector3(0.15, 0.15, 4.0), _paint(Color(0.9, 0.2, 0.2), 0.3), Vector3(70, 0, 0))
	K.mesh(root, booth + Vector3(1.2, 3.5, 1.2), Vector3(0.08, 7.0, 0.08), Art.material("gunmetal"))
	var flag := _animated(root, booth + Vector3(1.2, 6.6, 1.2), Ambient.Mode.SWAY, 5.0, 0.9)
	K.mesh(flag, Vector3(0, -0.5, 0.75), Vector3(0.04, 1.0, 1.5), Art.material("fabric", Color(0.55, 0.62, 0.45)))
	_poster(root, Vector3(STREET_HALF + 1.5, 2.6, z - 1.22), 180.0, "THE MILITIA\nNEEDS MEN", "and girls who can fix\nyour titans. -E", Color(0.55, 0.62, 0.45))
	shop(info, "town_gate", Vector3(0, 0, z - 3.5), "[F] Read the town sign", [
		"Solace. Home. Everybody here knows my name, and most of them say it like a curse.",
		"Keep your head down, Eco. Buy what you need. Don't start anything.",
		"The checkpoint boys still wave everyone through but me.",
	])


# --- Lantern Row ----------------------------------------------------------------

static func _lantern_row(root: Node3D, info: Dictionary, rng: RandomNumberGenerator) -> void:
	# West: the outfitter, the clinic. East: the noodle bar, the salvage dealer.
	var outfitter := _building(root, -1, 139.0, 13.0, 3, Color(0.93, 0.9, 0.86), MAGENTA, rng)
	_blade_sign(root, -1, 134.0, "STITCH\n&\nSTEEL", MAGENTA)
	_awning(root, -1, 139.0, 9.0, Color(0.85, 0.35, 0.55))
	_mannequins(root, -1, 139.0)
	shop(info, "shop_outfitter", outfitter, "[F] Stitch & Steel: outfits (coming soon)", [
		"Mara made my first flight suit. Now she pretends she's never seen me.",
		"Still takes my money though. Money doesn't have a reputation.",
	], "outfitter")

	var noodles := _building(root, 1, 139.0, 13.0, 2, Color(0.88, 0.92, 0.86), AMBER, rng)
	_blade_sign(root, 1, 134.0, "SEVEN\nSUNS", AMBER)
	_neon_text(root, Vector3(STREET_HALF + 0.1, GF - 0.6, 139.0), "NOODLES", AMBER, 90, -90.0)
	_awning(root, 1, 139.0, 10.0, Color(0.9, 0.55, 0.25))
	_counter(root, 1, 141.5, AMBER)
	_smoke(root, Vector3(STREET_HALF + 1.0, GF + 0.2, 144.0))
	shop(info, "shop_noodles", noodles, "[F] Seven Suns: a hot meal for the next run (coming soon)", [
		"Old Hiro still saves me the burnt edges. Only one in town who does.",
		"Spice, salt and grease. Best armour there is.",
	], "noodles")

	var clinic := _building(root, -1, 153.5, 11.0, 4, Color(0.86, 0.92, 0.94), LIME, rng)
	_neon_text(root, Vector3(-STREET_HALF - 0.1, GF - 0.6, 153.5), "+ MERCY CLINIC +", LIME, 64, 90.0)
	shop(info, "shop_clinic", clinic, "[F] Mercy Clinic: patch-ups and implants (coming soon)", [
		"Doc Imani stitched up Dad more times than I can count. She doesn't charge me. Yet.",
	], "clinic")

	var salvage := _building(root, 1, 153.5, 11.0, 3, Color(0.7, 0.72, 0.74), RED, rng)
	_blade_sign(root, 1, 150.0, "SAL'S\nSALVAGE", RED)
	_scrap_pile(root, Vector3(STREET_HALF + 1.4, 0, 157.5))
	shop(info, "shop_salvage", salvage, "[F] Sal's Salvage: trade titan parts (coming soon)", [
		"Sal buys from the militia's junkyard and sells to me at twice the price. Everybody wins but me.",
		"Don't ask where the serial numbers went.",
	], "salvage")
	_street_life(root, 132.0, 160.0, rng)


# --- Sun Plaza ------------------------------------------------------------------

static func _plaza(root: Node3D, info: Dictionary, rng: RandomNumberGenerator) -> void:
	var c := Vector3(0, 0, PLAZA.get_center().y)
	_sun_tree(root, c)
	shop(info, "sun_tree", c + Vector3(0, 0, -6.5), "[F] Look at the Sun Tree", [
		"The Sun Tree powers half the town. The half that pays.",
		"Dad brought me here the night they switched it on. Everybody cheered. I was six.",
	])
	# Benches and planters around the edge.
	for spec in [[Vector3(-12, 0, 166), 90.0], [Vector3(12, 0, 166), -90.0], [Vector3(-12, 0, 184), 90.0], [Vector3(12, 0, 184), -90.0]]:
		_bench(root, spec[0], spec[1])
		Props.tree(root, spec[0] + Vector3(signf(spec[0].x) * 3.5, 0, 0), rng, 0.6)
		K.stone(root, spec[0] + Vector3(signf(spec[0].x) * 3.5, 0.4, 0), Vector3(2.4, 0.8, 2.4), Vector3.ZERO, Color(0.95, 0.95, 0.9))
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
		"Lost goat. Broken pump. 'Pilot wanted, no girls.' Someone circled that one for me. Cute.",
		"Half these jobs pay in favours. I'm owed a lot of favours.",
	], "jobs")
	_militia_office(root, info)
	_greenhouse(root, info, rng)


## A tree of white ribs holding up leaf-shaped solar panels, wrapped in vines,
## standing in a round fountain.
static func _sun_tree(root: Node3D, c: Vector3) -> void:
	var white := _paint(Color(0.94, 0.95, 0.92), 0.45)
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.25, 0.6, 0.62, 0.8)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.05
	water.metallic_specular = 0.9
	for i in 16:
		var a := TAU * i / 16.0
		K.stone(root, c + Vector3(cos(a) * 5.0, 0.35, sin(a) * 5.0), Vector3(2.1, 0.7, 0.6), Vector3(0, -rad_to_deg(a) + 90.0, 0), Color(0.96, 0.96, 0.92))
	K.mesh(root, c + Vector3(0, 0.45, 0), Vector3(9.2, 0.04, 9.2), water, Vector3(0, 22.5, 0))
	K.mesh(root, c + Vector3(0, 0.46, 0), Vector3(9.2, 0.04, 9.2), water, Vector3(0, -22.5, 0))
	# Trunk: twisting ribs.
	Kit.box(root, c + Vector3(0, 5.0, 0), Vector3(1.6, 10.0, 1.6), K.STONE, Vector3.ZERO, white)
	for i in 6:
		var a := TAU * i / 6.0
		K.mesh(root, c + Vector3(cos(a) * 0.9, 5.0, sin(a) * 0.9), Vector3(0.3, 10.4, 0.3), white, Vector3(cos(a) * 6.0, 0, sin(a) * 6.0))
		K.mesh(root, c + Vector3(cos(a + 0.4) * 0.95, 3.5 + i * 0.8, sin(a + 0.4) * 0.95), Vector3(0.5, 2.5 + (i % 3), 0.5), Art.material("moss", Color(0.7, 1.0, 0.6)))
	# Branches with panel leaves, glowing edges.
	for i in 9:
		var a := TAU * i / 9.0 + 0.2
		var h := 9.0 + (i % 3) * 1.6
		var r := 4.2 + (i % 2) * 1.4
		var tip := c + Vector3(cos(a) * r, h + 0.8, sin(a) * r)
		var mid := (c + Vector3(0, h - 1.0, 0) + tip) * 0.5
		var arm := K.mesh(root, mid, Vector3(0.22, 0.22, r + 0.6), white)
		arm.look_at_from_position(mid, tip, Vector3.UP)
		var leaf := K.mesh(root, tip, Vector3(3.2, 0.08, 2.0), _panel(), Vector3(-14, -rad_to_deg(a) + 90.0, 0))
		K.glow(leaf, Vector3(0, -0.05, 1.0), Vector3(3.2, 0.04, 0.06), CYAN * 0.8)
		K.mesh(root, tip + Vector3(0, -1.0, 0), Vector3(0.6, 2.0, 0.6), Art.material("moss", Color(0.75, 1.0, 0.65)))
	K.glow(root, c + Vector3(0, 10.3, 0), Vector3(1.0, 0.6, 1.0), Color(0.6, 1.0, 0.9))
	K.light(root, c + Vector3(0, 7.0, 0), Color(0.55, 1.0, 0.9), 1.5, 16.0)


## The militia recruiting office on the plaza's west side: a grey concrete box
## with a red sign, a flag and a locked door.
static func _militia_office(root: Node3D, info: Dictionary) -> void:
	var x := PLAZA.position.x - DEPTH * 0.5
	var z := 175.0
	var grey := Art.material("concrete", Color(0.5, 0.52, 0.5))
	Kit.box(root, Vector3(x, 4.5, z), Vector3(DEPTH, 9.0, 16.0), K.STONE, Vector3.ZERO, grey)
	K.mesh(root, Vector3(x + DEPTH * 0.5 + 0.05, 1.6, z), Vector3(0.1, 3.2, 2.6), Art.material("gunmetal", Color(0.5, 0.55, 0.48)))
	K.mesh(root, Vector3(x + DEPTH * 0.5 + 0.3, 3.4, z), Vector3(0.6, 0.2, 4.0), Art.material("gunmetal"))
	_neon_text(root, Vector3(x + DEPTH * 0.5 + 0.1, 6.6, z), "MILITIA RECRUITMENT", RED, 72, 90.0)
	_neon_text(root, Vector3(x + DEPTH * 0.5 + 0.1, 5.7, z), "PILOTS WANTED. MEN ONLY.", Color(1.0, 0.9, 0.85), 34, 90.0)
	K.light(root, Vector3(x + DEPTH * 0.5 + 2.0, 6.0, z), RED, 1.2, 10.0)
	for dz: float in [-5.0, 5.0]:
		K.glow(root, Vector3(x + DEPTH * 0.5 + 0.05, 2.0, z + dz), Vector3(0.04, 1.4, 2.8), Color(0.9, 0.95, 1.0) * 0.4)
		K.mesh(root, Vector3(x + DEPTH * 0.5 + 0.08, 2.0, z + dz), Vector3(0.04, 1.6, 0.1), Art.material("gunmetal"))
	for dz: float in [-3.0, 3.0]:
		var pole := Vector3(x + DEPTH * 0.5 + 1.5, 0, z + dz)
		K.mesh(root, pole + Vector3(0, 3.5, 0), Vector3(0.1, 7.0, 0.1), Art.material("gunmetal"))
		var flag := _animated(root, pole + Vector3(0, 6.8, 0), Ambient.Mode.SWAY, 4.0, 0.7 + dz * 0.05)
		K.mesh(flag, Vector3(0, -0.7, 0.8), Vector3(0.04, 1.4, 1.6), Art.material("fabric", Color(0.55, 0.62, 0.45)))
	_poster(root, Vector3(x + DEPTH * 0.5 + 0.03, 2.2, z - 7.0), 90.0, "SERVE.\nPROTECT.\nOBEY.", "", Color(0.55, 0.62, 0.45))
	shop(info, "militia_office", Vector3(x + DEPTH * 0.5 + 2.4, 0, z), "[F] Militia recruitment", [
		"'Pilots wanted. Men only.' They didn't even bother to repaint it after I applied.",
		"I could fix every titan in their yard blindfolded. They offered me a broom.",
		"One day they'll come knocking for a pilot. I hope I'm busy.",
	])


## The greenhouse cafe on the plaza's east side: a glass house full of plants
## with a warm-lit counter. A date spot later.
static func _greenhouse(root: Node3D, info: Dictionary, rng: RandomNumberGenerator) -> void:
	var c := Vector3(PLAZA.end.x + 6.0, 0, 175.0)
	var size := Vector3(12.0, 6.0, 16.0)
	var frame := _paint(Color(0.92, 0.93, 0.9), 0.4)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.7, 0.95, 0.85, 0.22)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.metallic_specular = 1.0
	K.mesh(root, c + Vector3(0, 0.08, 0), Vector3(size.x, 0.12, size.z), Art.material("wood", Color(0.9, 0.8, 0.7)))
	# Glass walls (back and sides solid to walk against), open front with a door gap.
	for spec in [[Vector3(size.x * 0.5, size.y * 0.5, 0), Vector3(0.1, size.y, size.z)],
			[Vector3(0, size.y * 0.5, -size.z * 0.5), Vector3(size.x, size.y, 0.1)], [Vector3(0, size.y * 0.5, size.z * 0.5), Vector3(size.x, size.y, 0.1)],
			[Vector3(-size.x * 0.5, size.y * 0.5, -5.0), Vector3(0.1, size.y, 6.0)], [Vector3(-size.x * 0.5, size.y * 0.5, 5.0), Vector3(0.1, size.y, 6.0)],
			[Vector3(-size.x * 0.5, size.y - 1.0, 0), Vector3(0.1, 2.0, 4.0)]]:
		Kit.box(root, c + spec[0], spec[1], K.STONE, Vector3.ZERO, glass)
	# Pitched glass roof and white ribs.
	for s: float in [-1.0, 1.0]:
		K.mesh(root, c + Vector3(s * size.x * 0.25, size.y + 1.4, 0), Vector3(size.x * 0.56, 0.06, size.z), glass, Vector3(0, 0, -s * 26))
	for i in 5:
		var z := -size.z * 0.5 + i * size.z / 4.0
		for s: float in [-1.0, 1.0]:
			K.mesh(root, c + Vector3(s * size.x * 0.5, size.y * 0.5, z), Vector3(0.18, size.y, 0.18), frame)
			K.mesh(root, c + Vector3(s * size.x * 0.25, size.y + 1.4, z), Vector3(size.x * 0.56, 0.16, 0.16), frame, Vector3(0, 0, -s * 26))
	K.mesh(root, c + Vector3(0, size.y + 2.8, 0), Vector3(0.2, 0.2, size.z), frame)
	# Plants and tables inside, a warm counter at the back.
	for i in 6:
		var p := c + Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-6.5, 6.5))
		Props.spawn(root, ["bush_a", "fern", "bush_b"][i % 3], p, rng.randf_range(0, 360), 0.8, {"leaves": LEAF_TINTS[i % 4]})
	for p in [Vector3(-2.5, 0, -3.0), Vector3(-2.5, 0, 3.5), Vector3(1.0, 0, 0.5)]:
		K.wood(root, c + p + Vector3(0, 0.45, 0), Vector3(1.0, 0.9, 1.0))
		K.glow(root, c + p + Vector3(0, 1.0, 0), Vector3(0.12, 0.2, 0.12), WARM)
	K.wood(root, c + Vector3(4.6, 0.55, 0), Vector3(1.2, 1.1, 6.0))
	for i in 5:
		K.glow(root, c + Vector3(0, size.y - 0.3, -6.0 + i * 3.0), Vector3(0.2, 0.25, 0.2), WARM)
	K.light(root, c + Vector3(0, size.y - 1.0, 0), WARM, 1.4, 12.0)
	_neon_text(root, c + Vector3(-size.x * 0.5 - 0.12, size.y - 1.0, 0), "greenhouse cafe", LIME, 64, -90.0)
	shop(info, "shop_cafe", c + Vector3(-size.x * 0.5 - 1.8, 0, 0), "[F] Greenhouse Cafe: dates (coming soon)", [
		"Every couple in Solace has had their first date in there. I've had coffee in there. Alone.",
		"Someday somebody's going to ask me. And I'm going to make them pay.",
	], "cafe")


# --- Low Row --------------------------------------------------------------------

static func _low_row(root: Node3D, info: Dictionary, rng: RandomNumberGenerator) -> void:
	var arcade := _building(root, -1, 196.5, 13.0, 3, Color(0.4, 0.38, 0.46), VIOLET, rng)
	_blade_sign(root, -1, 191.5, "GLOW\nBOX", VIOLET)
	_neon_text(root, Vector3(-STREET_HALF - 0.1, GF - 0.6, 196.5), "ARCADE", CYAN, 90, 90.0)
	shop(info, "shop_arcade", arcade, "[F] Glowbox Arcade: dates (coming soon)", [
		"I hold the record on Titan Brawl III. The machine says 'ECO'. Somebody keeps scratching it off.",
		"Bring a date, win them a prize. Or bring nobody and win everything.",
	], "arcade")

	# Eco's old flat, boarded up.
	var flat := Vector3(-STREET_HALF, 0, 209.0)
	_building(root, -1, 209.0, 9.0, 3, Color(0.8, 0.78, 0.74), Color(0, 0, 0), rng, false)
	for i in 4:
		K.mesh(root, flat + Vector3(-0.2, 1.0 + i * 0.6, 0), Vector3(0.08, 0.22, 3.6), Art.material("wood", Color(0.7, 0.6, 0.5)), Vector3(rng.randf_range(-6, 6), 0, 0))
	_graffiti(root, flat + Vector3(-0.15, 3.3, 2.8), 90.0, "TRAITOR'S KID", RED)
	shop(info, "old_flat", flat + Vector3(1.8, 0, 0), "[F] Look at the old flat", [
		"Our old flat. Somebody painted that the week after Dad's funeral.",
		"Mom wanted to scrub it off. I wanted them to look at it every day.",
	])

	var bar := _building(root, 1, 196.5, 13.0, 3, Color(0.46, 0.4, 0.36), AMBER, rng)
	_blade_sign(root, 1, 191.5, "RUSTED\nHALO", AMBER)
	_neon_text(root, Vector3(STREET_HALF + 0.1, GF - 0.6, 197.0), "BAR", MAGENTA, 110, -90.0)
	_smoke(root, Vector3(STREET_HALF + 0.6, 0.3, 202.5))
	shop(info, "shop_bar", bar, "[F] The Rusted Halo: jobs and rumours (coming soon)", [
		"Every bad idea in Solace starts at the Halo. Most of mine did.",
		"The fixer in the back booth pays in cash and doesn't ask why I can shoot.",
	], "bar")

	var cinema := _building(root, 1, 209.5, 9.0, 2, Color(0.82, 0.86, 0.9), CYAN, rng)
	_neon_text(root, Vector3(STREET_HALF + 0.1, GF + 0.6, 209.5), "HOLO-CINEMA", CYAN, 70, -90.0)
	_neon_text(root, Vector3(STREET_HALF + 0.1, GF - 0.5, 209.5), "TONIGHT: TITANFALL ROMANCE", Color(1.0, 0.95, 0.85), 30, -90.0)
	shop(info, "shop_cinema", cinema, "[F] Holo-Cinema: dates (coming soon)", [
		"They only play militia war films now. The heroes all look like the guys who turned me down.",
	], "cinema")
	_street_life(root, 190.0, 214.0, rng)


# --- the rooftop garden -------------------------------------------------------

static func _garden(root: Node3D, info: Dictionary, rng: RandomNumberGenerator) -> void:
	var g := GARDEN
	var top := GARDEN_Y
	var white := Art.material("concrete", Color(0.96, 0.96, 0.92))
	# The terrace it sits on, with a ramp of steps up from the street.
	Kit.box(root, Vector3(g.get_center().x, top * 0.5, g.get_center().y), Vector3(g.size.x, top, g.size.y), K.STONE, Vector3.ZERO, white)
	var ramp_len := 9.0
	var ang := rad_to_deg(atan2(top, ramp_len))
	Kit.box(root, Vector3(0, top * 0.5 - 0.15, g.position.y - ramp_len * 0.5), Vector3(6.0, 0.3, sqrt(ramp_len * ramp_len + top * top)), K.STONE,
			Vector3(-ang, 0, 0), Art.material("temple_stone", Color(0.95, 0.95, 0.9)))
	for s: float in [-1.0, 1.0]:
		K.mesh(root, Vector3(s * 3.1, top * 0.5 + 0.9, g.position.y - ramp_len * 0.5), Vector3(0.08, 0.08, sqrt(ramp_len * ramp_len + top * top)), Art.material("gunmetal"), Vector3(-ang, 0, 0))
	K.mesh(root, Vector3(0, top + 0.05, g.get_center().y), Vector3(g.size.x - 1.0, 0.1, g.size.y - 1.0), Art.material("grass"))
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
	for dx: float in [-4.0, 4.0]:
		for dz: float in [-2.5, 2.5]:
			K.wood(root, pergola + Vector3(dx, 1.5, dz), Vector3(0.2, 3.0, 0.2))
	for i in 6:
		K.mesh(root, pergola + Vector3(0, 3.05, -2.5 + i), Vector3(8.6, 0.12, 0.12), Art.material("wood"))
	K.mesh(root, pergola + Vector3(0, 3.2, 0), Vector3(8.4, 0.3, 5.2), Art.material("moss", Color(0.7, 1.0, 0.6)))
	for i in 12:
		K.glow(root, pergola + Vector3(-4.0 + i * 0.72, 2.8 - 0.15 * sin(i * 0.9), 2.6), Vector3(0.12, 0.14, 0.12), WARM)
	K.light(root, pergola + Vector3(0, 2.6, 0), WARM, 1.2, 9.0)
	_bench(root, pergola + Vector3(0, 0, 1.0), 0.0)
	shop(info, "garden", pergola + Vector3(0, 0, -1.0), "[F] Rooftop garden: dates (coming soon)", [
		"Best view in Solace. You can see the turbines, the jungle, and the city they keep promising us.",
		"Dad proposed to Mom up here. She said no the first time. Runs in the family.",
	], "garden")


# --- overhead: canopy, cables, vines -----------------------------------------

## A lattice of solar panels on beams over the street, with gaps for the sun,
## cables strung between the buildings, paper lanterns and hanging vines.
static func _canopy(root: Node3D, rng: RandomNumberGenerator) -> void:
	var h := 15.5
	for seg in [[132.0, 160.0], [190.0, 214.0]]:
		var z0: float = seg[0]
		var z1: float = seg[1]
		var z := z0 + 1.0
		while z < z1:
			K.mesh(root, Vector3(0, h, z), Vector3(STREET_HALF * 2 + 2, 0.25, 0.25), _paint(Color(0.2, 0.21, 0.24), 0.4))
			if rng.randf() < 0.75:
				K.mesh(root, Vector3(rng.randf_range(-2.5, 2.5), h + 0.2, z + 1.5), Vector3(rng.randf_range(5.0, 9.0), 0.08, 2.6), _panel(), Vector3(0, 0, rng.randf_range(-8, 8)))
			if rng.randf() < 0.5:
				K.mesh(root, Vector3(rng.randf_range(-6, 6), h - 1.2, z), Vector3(0.6, 2.4, 0.6), Art.material("moss", Color(0.7, 1.0, 0.6)))
			z += 4.0
		# Cables strung across lower down, with lanterns.
		var cz := z0 + 2.5
		while cz < z1:
			var y := rng.randf_range(6.5, 9.5)
			K.mesh(root, Vector3(0, y, cz), Vector3(STREET_HALF * 2, 0.04, 0.04), Art.material("gunmetal"), Vector3(0, rng.randf_range(-6, 6), 0))
			var tints := [MAGENTA, CYAN, AMBER, WARM, LIME]
			for i in 3:
				var lx := -4.0 + i * 4.0 + rng.randf_range(-0.8, 0.8)
				K.glow(root, Vector3(lx, y - 0.45, cz), Vector3(0.36, 0.5, 0.36), tints[rng.randi() % tints.size()] * 0.8)
			cz += rng.randf_range(4.0, 7.0)


# --- around the town ------------------------------------------------------------

## Jungle behind the buildings, wind turbines on the ridge, and the dark city
## on the horizon the militia answers to.
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
		for spec in [[146.0, 28.0], [202.0, 24.0]]:
			Kit.box(root, Vector3(s * (TOWN_HALF - 12), 3.0, spec[0]), Vector3(24, 6.0, spec[1]), K.STONE, Vector3.ZERO,
					Art.material("concrete", Color(0.9, 0.9, 0.86)))
			K.mesh(root, Vector3(s * (TOWN_HALF - 12), 6.1, spec[0]), Vector3(23, 0.2, spec[1] - 1), Art.material("moss", Color(0.75, 1.0, 0.65)))
			for i in 4:
				Props.tree(root, Vector3(s * (TOWN_HALF - 6 - i * 3.5), 6.0, spec[0] - spec[1] * 0.35 + i * spec[1] * 0.22), rng, 0.6, false)
	# Wind turbines on the ridges.
	var white := _paint(Color(0.94, 0.95, 0.93), 0.4)
	for spec in [Vector3(-70, 0, 230), Vector3(-45, 0, 275), Vector3(60, 0, 250), Vector3(20, 0, 300), Vector3(-15, 0, 320)]:
		K.mesh(root, spec + Vector3(0, 14.0, 0), Vector3(1.0, 28.0, 1.0), white)
		var hub := _animated(root, spec + Vector3(0, 28.0, -0.8), Ambient.Mode.SPIN, 1.0, 0.6 + absf(spec.x) * 0.004)
		for i in 3:
			var blade := Node3D.new()
			blade.rotation.z = TAU * i / 3.0
			hub.add_child(blade)
			K.mesh(blade, Vector3(0, 5.0, 0), Vector3(0.6, 10.0, 0.15), white)
	# The city on the horizon: dark towers, red aviation lights.
	var dark := _paint(Color(0.12, 0.13, 0.16), 0.3)
	for i in 22:
		var x := -180.0 + i * 17.0 + rng.randf_range(-5, 5)
		var h := rng.randf_range(40.0, 120.0) * (1.3 if absf(x) < 60 else 1.0)
		var z := rng.randf_range(430.0, 480.0)
		var w := rng.randf_range(12.0, 22.0)
		K.mesh(root, Vector3(x, h * 0.5 - 10.0, z), Vector3(w, h, w), dark)
		K.glow(root, Vector3(x, h - 9.5, z - w * 0.5), Vector3(0.8, 0.8, 0.2), RED)
		for j in 3:
			K.glow(root, Vector3(x + rng.randf_range(-w * 0.4, w * 0.4), rng.randf_range(10, h - 15), z - w * 0.5 - 0.1), Vector3(rng.randf_range(2, 6), 0.4, 0.1), [AMBER, CYAN, MAGENTA][j] * 0.5)


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

## A shop building on one side of the street (side -1 west, +1 east), its front
## on the kerb, `width` along the street, centred on z. Dark ground floor with a
## lit shopfront in `neon`, pale upper floors stepping out over the street with
## balconies, plants and lit windows, solar panels and a garden on the roof.
## Returns the spot in front of its door.
static func _building(root: Node3D, side: int, z: float, width: float, floors: int, wall: Color, neon: Color, rng: RandomNumberGenerator, lit := true) -> Vector3:
	var s := float(side)
	var face := s * STREET_HALF
	var height := GF + floors * UF
	# Ground floor, set back under the upper floors.
	Kit.box(root, Vector3(face + s * (DEPTH * 0.5 + 0.6), GF * 0.5, z), Vector3(DEPTH, GF, width), K.STONE, Vector3.ZERO,
			Art.material("gunmetal", Color(0.42, 0.42, 0.46)))
	# Upper floors, overhanging the pavement.
	Kit.box(root, Vector3(face + s * (DEPTH * 0.5 - 0.6), GF + floors * UF * 0.5, z), Vector3(DEPTH, floors * UF, width), K.STONE, Vector3.ZERO,
			Art.material("concrete", wall))
	var front := face - s * 0.62
	if lit:
		# Shop window and door.
		K.glow(root, Vector3(face + s * 0.57, 1.7, z - width * 0.18), Vector3(0.05, 2.4, width * 0.45), neon.lerp(WARM, 0.5) * 0.55)
		K.mesh(root, Vector3(face + s * 0.56, 1.4, z + width * 0.28), Vector3(0.06, 2.8, 1.8), _paint(Color(0.08, 0.08, 0.1), 0.6))
		K.light(root, Vector3(face - s * 1.2, 2.8, z), neon.lerp(WARM, 0.3), 1.3, 9.0)
	# Upper windows, some lit, and balconies with plants every other floor.
	for f in floors:
		var y := GF + f * UF + UF * 0.55
		var n := int(width / 2.6)
		for i in n:
			var wz := z - width * 0.5 + (i + 0.5) * width / n
			var on := rng.randf() < 0.55
			var wcol: Color = [WARM, Color(0.75, 0.9, 1.0), neon.lerp(Color.WHITE, 0.5)][rng.randi() % 3] if on else Color(0.05, 0.06, 0.08)
			if on:
				K.glow(root, Vector3(front - s * 0.03, y, wz), Vector3(0.05, 1.4, 1.2), wcol * 0.55)
			else:
				K.mesh(root, Vector3(front - s * 0.03, y, wz), Vector3(0.05, 1.4, 1.2), _paint(wcol, 0.8))
		if f % 2 == 1 or floors == 1:
			var by := GF + f * UF
			K.mesh(root, Vector3(front - s * 0.6, by + 0.08, z), Vector3(1.2, 0.16, width - 1.5), Art.material("concrete", wall.darkened(0.1)))
			K.mesh(root, Vector3(front - s * 1.15, by + 0.6, z), Vector3(0.06, 0.9, width - 1.5), Art.material("gunmetal"))
			for j in 3:
				Props.spawn(root, ["fern", "bush_a"][j % 2], Vector3(front - s * 0.6, by + 0.16, z - width * 0.3 + j * width * 0.3), rng.randf_range(0, 360), 0.45,
						{"leaves": LEAF_TINTS[rng.randi() % 4]})
			if rng.randf() < 0.7:
				K.mesh(root, Vector3(front - s * 1.0, by - 0.9, z + rng.randf_range(-width * 0.3, width * 0.3)), Vector3(0.3, 1.8, 1.4), Art.material("moss", Color(0.7, 1.0, 0.6)))
	# AC units and pipes up the front for grime.
	for i in 2:
		K.mesh(root, Vector3(front - s * 0.35, GF + 1.0 + i * UF * 1.3, z + width * 0.42 - i * 0.6), Vector3(0.7, 0.6, 0.9), Art.material("gunmetal", Color(0.7, 0.7, 0.72)))
	K.mesh(root, Vector3(front - s * 0.12, height * 0.5, z - width * 0.48), Vector3(0.18, height, 0.18), Art.material("gunmetal"))
	# Roof: parapet, solar panels, a water tank, a little garden.
	var rx := face + s * (DEPTH * 0.5 - 0.6)
	K.mesh(root, Vector3(rx, height + 0.3, z), Vector3(DEPTH + 0.1, 0.6, width + 0.1), Art.material("concrete", wall.darkened(0.15)))
	for i in 3:
		K.mesh(root, Vector3(rx + s * 2.5, height + 1.0, z - width * 0.3 + i * width * 0.3), Vector3(3.6, 0.08, width * 0.26), _panel(), Vector3(0, 0, -s * 24))
	K.mesh(root, Vector3(rx - s * 2.5, height + 1.3, z + width * 0.25), Vector3(1.6, 2.0, 1.6), Art.material("gunmetal", Color(0.8, 0.82, 0.8)))
	Props.spawn(root, "bush_b", Vector3(rx - s * 2.5, height + 0.6, z - width * 0.25), rng.randf_range(0, 360), 0.8, {"leaves": LEAF_TINTS[rng.randi() % 4]})
	return Vector3(face - s * 1.8, 0, z)


## A tall vertical neon sign sticking out from the building front into the street.
static func _blade_sign(root: Node3D, side: int, z: float, text: String, color: Color) -> void:
	var s := float(side)
	var x := s * (STREET_HALF - 1.6)
	var lines := text.count("\n") + 1
	var h := 1.4 + lines * 1.1
	var y := GF + 1.6 + h * 0.5
	K.mesh(root, Vector3(x, y, z), Vector3(1.8, h, 0.3), _paint(Color(0.08, 0.08, 0.1), 0.5))
	K.glow(root, Vector3(x, y, z), Vector3(1.9, h + 0.1, 0.22), color * 0.6)
	K.mesh(root, Vector3(x, y, z), Vector3(1.7, h - 0.15, 0.32), _paint(Color(0.06, 0.06, 0.08), 0.5))
	for face: float in [-1.0, 1.0]:
		var l := _neon_text(root, Vector3(x, y, z + face * 0.18), text, color, 64, 0.0 if face > 0 else 180.0)
		l.line_spacing = -10.0
	K.light(root, Vector3(x, y, z), color, 1.2, 8.0)


## Glowing sign text, flat on a wall, facing yaw (0 = +Z).
static func _neon_text(root: Node3D, pos: Vector3, text: String, color: Color, size: int, yaw: float) -> Label3D:
	var l := Kit.label(root, pos, text, size)
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	l.rotation_degrees.y = yaw
	l.modulate = Color(color.r * 2.2, color.g * 2.2, color.b * 2.2)
	l.outline_modulate = Color(color.r, color.g, color.b, 0.6)
	l.outline_size = 10
	l.double_sided = false
	return l


static func _graffiti(root: Node3D, pos: Vector3, yaw: float, text: String, color: Color) -> void:
	var l := Kit.label(root, pos, text, 70)
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


static func _awning(root: Node3D, side: int, z: float, width: float, tint: Color) -> void:
	var s := float(side)
	K.mesh(root, Vector3(s * (STREET_HALF - 1.0), GF - 0.5, z), Vector3(2.2, 0.08, width), Art.material("canvas", tint), Vector3(0, 0, s * 18))


## Two mannequins in the outfitter's window.
static func _mannequins(root: Node3D, side: int, z: float) -> void:
	var s := float(side)
	for dz: float in [-3.5, -1.5]:
		var p := Vector3(s * (STREET_HALF + 1.4), 0, z + dz)
		K.mesh(root, p + Vector3(0, 1.0, 0), Vector3(0.4, 0.9, 0.3), _paint(Color(0.85, 0.2, 0.45), 0.6))
		K.mesh(root, p + Vector3(0, 1.75, 0), Vector3(0.5, 0.6, 0.32), _paint(Color(0.12, 0.12, 0.14), 0.6))
		K.mesh(root, p + Vector3(0, 2.25, 0), Vector3(0.22, 0.28, 0.22), _paint(Color(0.9, 0.9, 0.9), 0.3))
		K.mesh(root, p + Vector3(0, 0.3, 0), Vector3(0.1, 0.6, 0.1), Art.material("gunmetal"))


## A street counter with stools in front of a shop (the noodle bar).
static func _counter(root: Node3D, side: int, z: float, color: Color) -> void:
	var s := float(side)
	K.wood(root, Vector3(s * (STREET_HALF - 0.4), 0.55, z), Vector3(0.8, 1.1, 5.0))
	K.mesh(root, Vector3(s * (STREET_HALF - 0.4), 1.13, z), Vector3(0.9, 0.06, 5.1), _paint(color.darkened(0.6), 0.7))
	for i in 4:
		var p := Vector3(s * (STREET_HALF - 1.4), 0, z - 1.8 + i * 1.2)
		K.mesh(root, p + Vector3(0, 0.4, 0), Vector3(0.1, 0.8, 0.1), Art.material("gunmetal"))
		K.mesh(root, p + Vector3(0, 0.82, 0), Vector3(0.45, 0.08, 0.45), _paint(Color(0.7, 0.15, 0.15), 0.5))
	for i in 6:
		K.glow(root, Vector3(s * (STREET_HALF - 1.0), 3.4, z - 2.5 + i), Vector3(0.3, 0.4, 0.3), Color(1.0, 0.35, 0.2) * 0.9)


static func _scrap_pile(root: Node3D, p: Vector3) -> void:
	var armor := Art.material("titan_armor")
	K.metal(root, p + Vector3(0, 0.4, 0), Vector3(1.4, 0.8, 2.0), Vector3(0, 15, 6))
	K.mesh(root, p + Vector3(0.2, 1.0, -0.4), Vector3(1.0, 0.5, 1.2), armor, Vector3(10, 40, 20))
	K.mesh(root, p + Vector3(-0.2, 0.3, 1.6), Vector3(1.2, 0.6, 1.0), armor, Vector3(0, -25, 0))


static func _bench(root: Node3D, p: Vector3, yaw: float) -> void:
	K.wood(root, p + Vector3(0, 0.45, 0), Vector3(2.4, 0.12, 0.7), Vector3(0, yaw, 0))
	for dx: float in [-1.0, 1.0]:
		var off := Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(dx, 0, 0)
		K.mesh(root, p + off + Vector3(0, 0.2, 0), Vector3(0.12, 0.4, 0.6), Art.material("gunmetal"), Vector3(0, yaw, 0))


## Crates, bins, steam vents and the odd parked scooter along a stretch of street.
static func _street_life(root: Node3D, z0: float, z1: float, rng: RandomNumberGenerator) -> void:
	for i in 5:
		var s := -1.0 if rng.randf() < 0.5 else 1.0
		var p := Vector3(s * rng.randf_range(STREET_HALF - 1.6, STREET_HALF - 0.8), 0, rng.randf_range(z0 + 2, z1 - 2))
		match i % 3:
			0:
				var c := rng.randf_range(0.6, 0.9)
				K.wood(root, p + Vector3(0, c * 0.5, 0), Vector3(c, c, c), Vector3(0, rng.randf_range(0, 90), 0))
			1:
				K.mesh(root, p + Vector3(0, 0.5, 0), Vector3(0.7, 1.0, 0.7), _paint([Color(0.2, 0.45, 0.3), Color(0.25, 0.3, 0.5)][rng.randi() % 2], 0.5))
			2:
				K.mesh(root, Vector3(rng.randf_range(-2.5, 2.5), 0.08, p.z), Vector3(1.2, 0.06, 1.2), Art.material("gunmetal"))
				_smoke(root, Vector3(p.x * 0.3, 0.2, p.z))
	# A scooter parked by the kerb.
	var sp := Vector3(STREET_HALF - 1.2, 0, rng.randf_range(z0 + 4, z1 - 4))
	K.mesh(root, sp + Vector3(0, 0.55, 0), Vector3(0.5, 0.5, 1.6), _paint(Color(0.9, 0.85, 0.3), 0.7))
	for dz: float in [-0.6, 0.6]:
		K.mesh(root, sp + Vector3(0, 0.25, dz), Vector3(0.15, 0.5, 0.5), _paint(Color(0.08, 0.08, 0.1), 0.4))
	K.glow(root, sp + Vector3(0, 0.7, -0.82), Vector3(0.3, 0.12, 0.04), CYAN)


# --- materials and life ---------------------------------------------------------

## Glossy paint in the titans' paint shader (cached by colour and gloss).
static func _paint(color: Color, gloss: float) -> ShaderMaterial:
	var key := "%s/%s" % [color.to_html(), gloss]
	if not _mats.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = TITAN_PAINT
		mat.set_shader_parameter("albedo", color)
		mat.set_shader_parameter("wear", 0.0)
		mat.set_shader_parameter("grime", 0.15)
		mat.set_shader_parameter("gloss", gloss)
		_mats[key] = mat
	return _mats[key]


## Deep blue solar panel glass.
static func _panel() -> ShaderMaterial:
	return _paint(Color(0.1, 0.16, 0.32), 0.9)


static func _animated(parent: Node, pos: Vector3, mode: int, amount: float, speed: float) -> Node3D:
	var node: Node3D = Ambient.new()
	node.mode = mode
	node.amount = amount
	node.speed = speed
	node.position = pos
	parent.add_child(node)
	return node


## Steam from a vent or a kitchen.
static func _smoke(root: Node3D, p: Vector3) -> void:
	var smoke := CPUParticles3D.new()
	smoke.position = p
	smoke.amount = 10
	smoke.lifetime = 3.5
	var quad := QuadMesh.new()
	quad.size = Vector2(0.8, 0.8)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color(0.85, 0.85, 0.9, 0.25)
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	smoke.mesh = quad
	smoke.direction = Vector3.UP
	smoke.spread = 10.0
	smoke.gravity = Vector3(0.2, 0.5, 0)
	smoke.initial_velocity_min = 0.5
	smoke.initial_velocity_max = 0.9
	smoke.scale_amount_min = 0.7
	smoke.scale_amount_max = 1.6
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.7))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	smoke.color_ramp = fade
	root.add_child(smoke)
