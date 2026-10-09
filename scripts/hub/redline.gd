extends RefCounted
## Redline: Cutter's drug (cutter.gd), Mature only like the rest of the vices.
## Ophelia's old dealer won't watch Marrow and the colony take his town: he
## hunts Eco through the hub and Solace, and when he catches her he puts a
## needle of Redline into her eye, seen only through her eyes (cutter_scene.gd).
##   the high    HIGH_TIME s of it: her view runs red and pounds with her
##               heart, and she's faster (speed_scale)
##   the crash   when the high runs out: a scene, down on her knees, the colour
##               gone out of everything, shaking (cutter_scene.gd)
##   a charge    every catch leaves one Redline charge in her: a catalyst, and
##               nothing more on its own. Her body stays hers.
## The Rig (rig_screen.gd), a chair in Biggie's den: Eco can spend a charge on
## one of the MODS, or not, and take any of them off again there for free.
## Only she picks, and none of them is anyone else's idea: they're upgrades she
## chooses for a fight. They stack, except where EXCLUDES says two can't share
## her. What they look like is redline_body.gd; what they do is below.
## Saved next to the vices save (path_for()).

const ContentRating := preload("res://scripts/radio/content_rating.gd")

## The mods, in the Rig's order: name, what it is, and what it does.
const MODS := {
	"wiring": {"name": "Wiring", "look": "Red veins up her arms and the sides of her neck, glowing with her heart.", "does": "Heals faster while she's high."},
	"heavy": {"name": "Heavy body", "look": "All of her about 5% bigger, evenly.", "does": "Takes hits better. A little slower."},
	"legs": {"name": "Long legs", "look": "Her shins lengthened: taller.", "does": "Faster, and she jumps higher."},
	"core": {"name": "Locked core", "look": "Her back held straight, her head level.", "does": "Steadier aim. She can't crouch."},
	"cat_ears": {"name": "Cat ears", "look": "A pair of cat's ears through her hair, turning to sounds.", "does": "Hears enemies behind her: a ping shows which way."},
	"tail": {"name": "Tail", "look": "A thin red tail from the base of her spine.", "does": "More control in the air, less fall damage."},
	"red_eyes": {"name": "Red eyes", "look": "Red irises.", "does": "While she's high, enemies glow through walls."},
	"long_arms": {"name": "Long arms", "look": "Her forearms stretched.", "does": "Longer melee reach."},
	"spurs": {"name": "Bone spurs", "look": "Red-tipped spurs along her forearms.", "does": "Harder melee. Breaks padlocks."},
	"vents": {"name": "Vents", "look": "Thin red vents down the sides of her neck.", "does": "A faster sprint, and she gets her breath back sooner after a hit."},
	"freckles": {"name": "Glow freckles", "look": "Red lights in her skin, on her cheeks and shoulders.", "does": "A soft light round her in the dark. Enemies spot her sooner."},
	"compact": {"name": "Compact", "look": "All of her about 8% smaller, evenly.", "does": "Quieter steps, a smaller target, a smaller magazine."},
	"horns": {"name": "Horns", "look": "Small swept-back red horns.", "does": "Sprinting into an enemy knocks them down."},
	"pointed_ears": {"name": "Pointed ears", "look": "Long pointed ears.", "does": "Hears enemies from further off."},
	"night_eyes": {"name": "Night eyes", "look": "Slit pupils in amber.", "does": "Sees in the dark."},
	"scales": {"name": "Scales", "look": "Red scales on her forearms and shins.", "does": "Less damage up close and from falls."},
	"wings": {"name": "Wing stubs", "look": "Small leathery wings on her shoulder blades.", "does": "A short glide after a jump (hold jump)."},
}
const ORDER := ["wiring", "heavy", "legs", "core", "cat_ears", "tail", "red_eyes", "long_arms", "spurs", "vents", "freckles", "compact",
	"horns", "pointed_ears", "night_eyes", "scales", "wings"]
## Pairs that can't both be on her.
const EXCLUDES := [["heavy", "compact"], ["cat_ears", "pointed_ears"], ["red_eyes", "night_eyes"]]
## What she feels when one goes on at the Rig.
const FEEL := {
	"wiring": "Red lines come up under the skin of her arms and climb her neck. They pulse with her heart.",
	"heavy": "All of her gets heavier at once, every part the same. The floor takes her weight differently.",
	"legs": "Her shins lengthen with a sound like a knuckle. She's taller. The ground's further away.",
	"core": "Her back pulls straight and locks. Her head comes level. Her hands go very still.",
	"cat_ears": "Two ears push up through her hair and turn, on their own, to Biggie's radio. She laughs. She can hear everything.",
	"tail": "A thin red tail uncurls behind her and finds her balance before she does.",
	"red_eyes": "Her eyes sting, and then they're red, and the room has edges it didn't have before.",
	"long_arms": "Her forearms draw out long. Her hands reach the top shelf without trying.",
	"spurs": "Something hard pushes out along her forearms: spurs of bone, tipped red. She flexes. They hold.",
	"vents": "Thin slits open down the sides of her neck and breathe with her. She's never had so much air.",
	"freckles": "Little red lights come up under the skin of her cheeks and shoulders, like embers.",
	"compact": "All of her draws in, evenly, a size down. Lighter. Quieter.",
	"horns": "Two small horns push up through her hair and sweep back. Her head feels heavier, and harder.",
	"pointed_ears": "Her ears draw out long and fine. The whole den is suddenly loud.",
	"night_eyes": "Her pupils narrow to slits. The dark corners of the den fill in.",
	"scales": "Red scales spread over her forearms and down her shins, overlapping, hard as fingernail.",
	"wings": "Two small wings unfold from her shoulder blades, leathery, and fold back. She shrugs, and they flex.",
}
const HIGH_TIME := 60.0
const HIGH_SPEED := 1.15
## What the mods do (see the effect functions).
const WIRING_REGEN := 1.6
const HEAVY_SPEED := 0.94
const HEAVY_DAMAGE := 0.88
const LEGS_SPEED := 1.06
const LEGS_JUMP := 1.15
const CORE_SPREAD := 0.7
const TAIL_AIR := 1.5
const TAIL_FALL := 0.6
const LONG_REACH := 1.35
const LONG_LEDGE := 0.35
const SPURS_MELEE := 1.5
const VENTS_SPRINT := 1.08
const VENTS_RECOVER := 0.6
const FRECKLES_NOTICE := 1.3
const COMPACT_STEPS := 0.6
const COMPACT_TARGET := 0.9
const SCALES_DAMAGE := 0.7
## Hits from closer than this count as melee (for the scales).
const MELEE_RANGE := 3.0
const NIGHT_DAZZLE := 1.6
## How far (m) she hears enemies with cat ears (behind her) and pointed ears (all round).
const CAT_HEAR := 18.0
const POINTED_HEAR := 30.0
const GLIDE_FALL := 2.2

static var mods: Array = []
## Redline charges she's carrying, for the Rig.
static var charges := 0
static var catches := 0
## Seconds of the high left; the crash is owed when it reaches 0.
static var high_left := 0.0
static var crash_owed := false
static var save_path := "user://redline.cfg"


static func allowed() -> bool:
	return ContentRating.current() == "M"


static func path_for(vices_path: String) -> String:
	return vices_path.get_basename().trim_suffix("_vices") + "_redline.cfg"


static func has(mod: String) -> bool:
	return allowed() and mod in mods


## He caught her: the high starts, and she's carrying one more charge.
static func caught() -> void:
	catches += 1
	charges += 1
	high_left = HIGH_TIME
	crash_owed = true
	save()


## What's in the way of her putting `mod` on ("" if nothing).
static func blocked(mod: String) -> String:
	if not MODS.has(mod):
		return "no such mod"
	if mod in mods:
		return "already on"
	for pair in EXCLUDES:
		if mod in pair:
			var other: String = pair[0] if pair[1] == mod else pair[1]
			if other in mods:
				return "not with %s" % MODS[other]["name"]
	if charges <= 0:
		return "no Redline charge"
	return ""


## At the Rig: spends a charge on `mod`. False if she can't.
static func install(mod: String) -> bool:
	if not allowed() or blocked(mod) != "":
		return false
	charges -= 1
	mods.append(mod)
	save()
	return true


## At the Rig: takes `mod` off, for free (the charge is spent).
static func remove(mod: String) -> bool:
	if not mod in mods:
		return false
	mods.erase(mod)
	save()
	return true


## Each tick of the high; true when it's just run out (the crash is due).
static func tick(delta: float) -> bool:
	if high_left <= 0.0:
		return false
	high_left = maxf(high_left - delta, 0.0)
	return high_left <= 0.0


static func high() -> bool:
	return allowed() and high_left > 0.0


## The crash has played.
static func crashed() -> void:
	crash_owed = false
	save()


# --- what the mods do -----------------------------------------------------------

static func speed_scale() -> float:
	return (HIGH_SPEED if high() else 1.0) * (HEAVY_SPEED if has("heavy") else 1.0) * (LEGS_SPEED if has("legs") else 1.0)


static func reload_scale() -> float:
	return 1.0


## Damage she takes (hits).
static func damage_scale() -> float:
	return (HEAVY_DAMAGE if has("heavy") else 1.0) * (COMPACT_TARGET if has("compact") else 1.0)


static func melee_damage_taken() -> float:
	return SCALES_DAMAGE if has("scales") else 1.0


static func fall_scale() -> float:
	return (TAIL_FALL if has("tail") else 1.0) * (SCALES_DAMAGE if has("scales") else 1.0)


static func can_crouch() -> bool:
	return not has("core")


static func jump_scale() -> float:
	return LEGS_JUMP if has("legs") else 1.0


static func spread_scale() -> float:
	return CORE_SPREAD if has("core") else 1.0


static func regen_scale() -> float:
	return WIRING_REGEN if has("wiring") and high() else 1.0


static func air_scale() -> float:
	return TAIL_AIR if has("tail") else 1.0


static func reach_scale() -> float:
	return LONG_REACH if has("long_arms") else 1.0


static func ledge_bonus() -> float:
	return LONG_LEDGE if has("long_arms") else 0.0


static func melee_scale() -> float:
	return SPURS_MELEE if has("spurs") else 1.0


static func breaks_locks() -> bool:
	return has("spurs")


static func sprint_scale() -> float:
	return VENTS_SPRINT if has("vents") else 1.0


## How long after a hit before she starts healing (the vents: she gets her breath back sooner).
static func recover_scale() -> float:
	return VENTS_RECOVER if has("vents") else 1.0


## How much sooner enemies notice her (more is sooner).
static func notice_scale() -> float:
	return (FRECKLES_NOTICE if has("freckles") else 1.0) * (0.85 if has("compact") else 1.0)


static func step_noise() -> float:
	return COMPACT_STEPS if has("compact") else 1.0


## A full magazine of `size`: there are no spare mags to carry, so Compact
## carries a smaller magazine instead (about one round in seven less).
static func mag_size(size: int) -> int:
	return maxi(1, size - maxi(1, roundi(size * 0.15))) if has("compact") else size


static func charge_knocks_down() -> bool:
	return has("horns")


## How far she hears enemies, and whether only behind her (0: she doesn't).
static func hearing() -> Array:
	if has("pointed_ears"):
		return [POINTED_HEAR, false]
	if has("cat_ears"):
		return [CAT_HEAR, true]
	return [0.0, false]


static func sees_in_dark() -> bool:
	return has("night_eyes")


static func dazzle_scale() -> float:
	return NIGHT_DAZZLE if has("night_eyes") else 1.0


static func xray() -> bool:
	return has("red_eyes") and high()


static func can_glide() -> bool:
	return has("wings")


static func reset() -> void:
	mods = []
	charges = 0
	catches = 0
	high_left = 0.0
	crash_owed = false


static func open(path: String) -> void:
	save_path = path
	reset()
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	# before the Rig, Redline changed her itself: those stay on as her mods
	var old: Array = Array(cfg.get_value("redline", "changes", [])).map(func(c): return {"posture": "core", "hands": "", "head": "", "neck": "", "arms": "long_arms", "eyes": "red_eyes", "ears": "cat_ears"}.get(c, c))
	mods = Array(cfg.get_value("redline", "mods", old)).filter(func(c): return MODS.has(c))
	charges = int(cfg.get_value("redline", "charges", 0))
	catches = int(cfg.get_value("redline", "catches", 0))


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("redline", "mods", mods)
	cfg.set_value("redline", "charges", charges)
	cfg.set_value("redline", "catches", catches)
	cfg.save(save_path)
