extends RefCounted
## Marrow, part 2 (after vices.gd's Hush). Mature only, like the rest of it.
##
##   Glass   Hush refined with colony combat tech: Marrow sells it in vials
##           once his Hold has been deep. On a run, L cracks one: a few seconds
##           of focus where the world slows (run/tether.gd) and her shots hit
##           harder. Every vial crystallises her a little: violet glass creeps
##           over her skin (eco_toon.gdshaderinc, the eco_glass global) and
##           costs max health (player.gd apply_suit). A run without it wears
##           one level off.
##   Tether  the first vial comes with an earpiece. On runs Marrow talks in
##           her ear and gives orders (kill three, don't get touched, keep
##           moving, crack a vial). Doing it pays scrap and patches her up and
##           tightens his Hold; failing or tuning him out (K) gets her a
##           punishment of swirls, but loosens him a little.
##   Chorus  the town is his real customer. As she uses Glass he doses Solace
##           too: townsfolk get violet eyes and go quiet (townsfolk.gd). A
##           ledger on his table says who's buying: the colony. Read it, smash
##           his three Glass vats, then hold out against his pull
##           (hub/chorus_scene.gd) and it breaks: his Hold and her glass gone,
##           the town wakes up, Marrow runs.
##
## Saved per slot next to the vices save (open()).

const Vices := preload("res://scripts/hub/vices.gd")

# --- Glass --------------------------------------------------------------------

const VIAL_COST := {"scrap": 60, "circuits": 2}
const MAX_VIALS := 3
## Crystallisation, 0..MAX_GLASS: each level takes HEALTH_PER_GLASS of her max health.
const MAX_GLASS := 6
const HEALTH_PER_GLASS := 0.06
## A vial's focus: real seconds, how slow the world goes, her damage.
const FOCUS_TIME := 2.5
const FOCUS_SCALE := 0.35
const FOCUS_DAMAGE := 1.25
const HOLD_PER_VIAL := 5.0

# --- Tether -------------------------------------------------------------------

## Seconds of a run between his orders (the first comes sooner).
const ORDER_EVERY := 45.0
const FIRST_ORDER := 20.0
## His orders: what he says, the HUD's words, how long she has, how many kills.
const ORDERS := {
	"kills": {"say": "Marrow, in her ear: \"Three of them. Twenty seconds. Show me.\"",
		"hud": "kill %d more", "time": 20.0, "need": 3},
	"untouched": {"say": "Marrow, in her ear: \"Don't let them touch you. Fifteen seconds. I'm watching.\"",
		"hud": "don't get hit", "time": 15.0},
	"moving": {"say": "Marrow, in her ear: \"Keep moving. Don't you dare stand still.\"",
		"hud": "keep moving", "time": 12.0},
	"glass": {"say": "Marrow, in her ear: \"Crack a vial. Now. I want to see what it does to you.\"",
		"hud": "crack a vial [L]", "time": 15.0},
}
const OBEY_LINES := [
	"Marrow: \"There. Was that so hard?\"",
	"Marrow: \"See? You're better when you listen.\"",
	"Marrow: \"Good. Keep doing as you're told.\"",
]
const PUNISH_LINES := [
	"Marrow: \"No.\" The swirls fill her eyes and her legs stop answering.",
	"Marrow: \"Did I say you could ignore me?\" Violet floods in and the world goes away for a moment.",
	"His voice goes cold in her ear, and the spirals drag her under where she stands.",
]
const TUNE_OUT_LINE := "Eco rips the earpiece out for a second. \"Get out of my head.\""
const OBEY_SCRAP := 15
const OBEY_HEAL := 25.0
const OBEY_HOLD := 2.0
## Refusing him costs her a few seconds of trance but loosens his Hold.
const REFUSE_HOLD := -3.0
const PUNISH_TIME := 2.5

# --- Chorus -------------------------------------------------------------------

## Vials used (ever) to reach each stage of the town's dosing.
const CHORUS_AT := [3, 6, 10]
## How many of the ten townsfolk are his at each stage.
const DOSED_FOLK := [0, 3, 6, 10]
const VAT_IDS := ["vat_a", "vat_b", "vat_c"]
## Holding out against his pull at the end: how many times, and the window
## (seconds) for each press, shorter the deeper his Hold.
const RESIST_BEATS := 3
const RESIST_WINDOW := Vector2(1.6, 0.9)
const RESIST_FAIL_HOLD := 20.0

static var vials := 0
static var glass := 0
## Vials she's used, ever: how far the Chorus has got.
static var used := 0
static var earpiece := false
static var used_this_run := false
static var focus_left := 0.0
static var ledger := false
static var vats: Array = []
## The Chorus broken: Marrow is gone for good.
static var broken := false
static var save_path := "user://glass.cfg"

## Whether Marrow offers Glass: once his Hold has been deep, until he's gone.
static func on_sale() -> bool:
	return not broken and (Vices.hush_suit or Vices.hold >= Vices.TRANCE_HOLD or used > 0)


## Buys a vial (the screen has taken the price). The first comes with his earpiece.
static func buy() -> bool:
	if not on_sale() or vials >= MAX_VIALS:
		return false
	vials += 1
	earpiece = true
	save()
	return true


## Cracks a vial on a run: focus starts, she crystallises a step, his Hold tightens.
static func use_vial() -> bool:
	if vials <= 0 or focusing():
		return false
	vials -= 1
	glass = mini(glass + 1, MAX_GLASS)
	used += 1
	used_this_run = true
	focus_left = FOCUS_TIME
	Vices.hold = minf(Vices.hold + HOLD_PER_VIAL, Vices.MAX_HOLD)
	Vices.reward_check()
	Vices.save()
	save()
	return true


static func focusing() -> bool:
	return focus_left > 0.0


## `real_delta`: seconds of real time (not slowed by the focus itself).
static func tick_focus(real_delta: float) -> void:
	focus_left = maxf(focus_left - real_delta, 0.0)


## Her max health under the glass.
static func health_scale() -> float:
	return 1.0 - HEALTH_PER_GLASS * glass


## How far the glass has spread over her, 0..1 (the eco_glass shader global).
static func look() -> float:
	return float(glass) / MAX_GLASS


## Damage her shots deal while focused.
static func damage_out() -> float:
	return FOCUS_DAMAGE if focusing() else 1.0


## A run ended: one without Glass wears a level of it off her.
static func run_over() -> void:
	if not used_this_run:
		glass = maxi(glass - 1, 0)
	used_this_run = false
	focus_left = 0.0
	save()


## Marrow's in her ear on runs.
static func tethered() -> bool:
	return earpiece and not broken


## A Tether order's outcome on his Hold.
static func obeyed() -> void:
	Vices.hold = minf(Vices.hold + OBEY_HOLD, Vices.MAX_HOLD)
	Vices.reward_check()
	Vices.save()


static func refused() -> void:
	Vices.hold = maxf(Vices.hold + REFUSE_HOLD, 0.0)
	Vices.save()


## How far he's dosed Solace (0 none .. 3 the whole town).
static func chorus_stage() -> int:
	if broken:
		return 0
	var s := 0
	for n: int in CHORUS_AT:
		if used >= n:
			s += 1
	return s


static func dosed_folk() -> int:
	return DOSED_FOLK[chorus_stage()]


## His ledger on the basement table is there to read once the Chorus has begun.
static func ledger_there() -> bool:
	return chorus_stage() > 0


static func read_ledger() -> bool:
	if not ledger_there():
		return false
	ledger = true
	save()
	return true


## The vats can be smashed once she's read what they're for.
static func can_smash(id: String) -> bool:
	return ledger and chorus_stage() > 0 and not id in vats


static func smash(id: String) -> bool:
	if not can_smash(id):
		return false
	vats.append(id)
	save()
	return true


static func vats_left() -> int:
	return VAT_IDS.size() - vats.size()


## All three vats down: she can face him.
static func can_confront() -> bool:
	return chorus_stage() > 0 and ledger and vats_left() == 0


## The window for each press when she holds out against him.
static func resist_window() -> float:
	return lerpf(RESIST_WINDOW.x, RESIST_WINDOW.y, clampf(Vices.hold / Vices.MAX_HOLD, 0.0, 1.0))


## She held out: it all breaks. His Hold, her glass, the town's eyes; he runs.
static func break_free() -> void:
	broken = true
	glass = 0
	vials = 0
	focus_left = 0.0
	Vices.hold = 0.0
	Vices.dosed = false
	Vices.trance = false
	Vices.errand = ""
	Vices.errand_done = false
	Vices.walked_away = true
	Vices.save()
	save()


## She didn't: his Hold tightens, and by morning the vats are brewing again.
static func resist_failed() -> void:
	Vices.hold = minf(Vices.hold + RESIST_FAIL_HOLD, Vices.MAX_HOLD)
	Vices.save()
	vats = []
	save()


## Words for the HUD's status, or "".
static func state_name() -> String:
	var out := []
	if focusing():
		out.append("Focus")
	if glass > 0:
		out.append("Glass %d/%d" % [glass, MAX_GLASS])
	return "  ".join(out)


static func pockets_text() -> String:
	if vials <= 0:
		return ""
	return "[L] Glass x%d" % vials


# --- saving -------------------------------------------------------------------

## The save next to the vices save `vices_path`.
static func path_for(vices_path: String) -> String:
	return vices_path.get_basename() + "_glass.cfg"


static func open(path: String) -> void:
	save_path = path
	reset()
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	vials = cfg.get_value("glass", "vials", 0)
	glass = cfg.get_value("glass", "glass", 0)
	used = cfg.get_value("glass", "used", 0)
	earpiece = cfg.get_value("glass", "earpiece", false)
	ledger = cfg.get_value("glass", "ledger", false)
	vats = cfg.get_value("glass", "vats", []).filter(func(id): return id in VAT_IDS)
	broken = cfg.get_value("glass", "broken", false)


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("glass", "vials", vials)
	cfg.set_value("glass", "glass", glass)
	cfg.set_value("glass", "used", used)
	cfg.set_value("glass", "earpiece", earpiece)
	cfg.set_value("glass", "ledger", ledger)
	cfg.set_value("glass", "vats", vats)
	cfg.set_value("glass", "broken", broken)
	cfg.save(save_path)


## Clears everything in memory (tests). Doesn't touch the save.
static func reset() -> void:
	vials = 0
	glass = 0
	used = 0
	earpiece = false
	used_this_run = false
	focus_left = 0.0
	ledger = false
	vats = []
	broken = false
