extends RefCounted
## Relics: things Eco carries on a run, each a big perk with a nasty side
## effect. She keeps the ones she's found at the idol in the temple
## (relic_screen.gd) and wears up to SLOTS on a run.
##
## Three kinds (SOURCES):
##   - Precursor relics, from a reliquary shrine that sometimes stands in a
##     zone (relic_shrine.gd, SHRINE_CHANCE). Cursed: whispers, a slow drain,
##     blackouts, a blood price.
##   - Relics the people in her life give her (GIVERS), once they're close
##     enough to her: the catch is always about them.
##   - Colony relics, sometimes in a salvage cache (COLONY_CHANCE): colony
##     tech that was never meant for her.
## Marrow's Violet Coin is Mature only, like the rest of his things (vices.gd):
## under Teen it isn't offered, can't be worn and does nothing.
##
## The stat hooks (damage_out, damage_in, regen_scale, ...) are 1.0 off a run
## or without the relic; the timed side effects run in relic_fx.gd. What she
## owns and wears is saved per save slot.

const ContentRating := preload("res://scripts/radio/content_rating.gd")
const Vices := preload("res://scripts/hub/vices.gd")

const SLOTS := 2
const SOURCES := {"precursor": "Precursor relic", "npc": "Keepsake", "colony": "Colony tech"}

## id -> name, source, who gives it (npc ones), the perk, the catch, a blurb.
const RELICS := {
	# Precursor
	"builder_eye": {"name": "Eye of the Builder", "source": "precursor",
		"perk": "Grunts within 30 m show through walls.",
		"curse": "Whispers: markers and voices that aren't there.",
		"blurb": "A carved eye the size of a plum. It's warm, and it never blinks.",
		"carry": "The Builder's eye is warm in her pocket. Something in it is already whispering."},
	"heartstone": {"name": "Heartstone", "source": "precursor",
		"perk": "Heals twice as fast.",
		"curse": "Slow drain: her max health shrinks the longer the run goes, down to half.",
		"blurb": "A red stone that beats. Slowly. It's taking something to do it.",
		"carry": "The Heartstone beats against her ribs, a little out of step with her own."},
	"sunless_mask": {"name": "Sunless Mask", "source": "precursor",
		"perk": "Grunts take twice as long to notice her.",
		"curse": "Blackouts: now and then the world goes dark for a second or two.",
		"blurb": "A smooth stone mask with no eyeholes. Wear it and nobody quite sees you. Sometimes you don't either.",
		"carry": "The Sunless Mask settles cold on her face. The edges of things go soft."},
	"idols_tooth": {"name": "Idol's Tooth", "source": "precursor",
		"perk": "Her shots hit 40% harder.",
		"curse": "Blood price: every kill costs her a little health.",
		"blurb": "A fang as long as her finger, from something the Precursors prayed to. It wants feeding.",
		"carry": "The Idol's Tooth hums on its cord. It's hungry. So is she."},
	# Keepsakes
	"moms_locket": {"name": "Mom's Locket", "source": "npc", "giver": "mom",
		"perk": "Once a run, a killing blow leaves her on half health instead.",
		"curse": "Mom checks in on the radio, and the crackle draws nearby grunts.",
		"blurb": "A tarnished locket with a photo of Eco at six, gap-toothed, holding a wrench.",
		"carry": "Mom's locket, under her suit. Her radio's already crackling.",
		"gift": "Mom presses something into her palm. \"Your father wore this every day he flew. Wear it for me. And answer when I call.\""},
	"ophelias_watch": {"name": "Ophelia's Pocket Watch", "source": "npc", "giver": "ophelia",
		"perk": "Headshots slow time for a moment.",
		"curse": "Don't keep her waiting: a run over 12 minutes costs Ophelia's affection.",
		"blurb": "A brass watch, slightly fast. Ophelia set it that way on purpose.",
		"carry": "Ophelia's watch ticks against her wrist. She'll be counting.",
		"gift": "Ophelia shoves a pocket watch at her without looking. \"It's so you know when to come back. Not because I worry. Don't be late.\""},
	"biggies_tags": {"name": "Biggie's Dog Tags", "source": "npc", "giver": "biggie",
		"perk": "Grunts' shots hurt her 30% less.",
		"curse": "His bad knee: her wallruns and slides are shorter.",
		"blurb": "Two dented tags on a chain. One is his. He won't say whose the other one was.",
		"carry": "Biggie's tags clink under her collar. Her left knee aches out of sympathy.",
		"gift": "Biggie tugs a chain over his head. \"Kept me alive through Third Valley. Took my knee as payment. Fair trade, mostly.\""},
	"sals_scale": {"name": "Sal's Lucky Scale", "source": "npc", "giver": "sal",
		"perk": "Half again as many materials from everything she picks up.",
		"curse": "Cheap salvage parts: her gun jams now and then.",
		"blurb": "A brass scale weight, filed down so it always reads in Sal's favour. Now it reads in hers.",
		"carry": "Sal's lucky scale rattles in her pouch. So does her gun, now she listens.",
		"gift": "Sal slides a little brass weight over the counter. \"Lucky. Mostly. Swapped a couple of your gun parts for cheaper ones while I was at it. You're welcome.\""},
	"imanis_kit": {"name": "Imani's Stitch Kit", "source": "npc", "giver": "imani",
		"perk": "Every kill patches her up.",
		"curse": "Anaesthetic: her health readout is gone. She can't feel how hurt she is.",
		"blurb": "Doc Imani's field kit: auto-sutures, a numbing patch, a note that says DON'T.",
		"carry": "Imani's numbing patch kicks in. She can't feel a thing. That's the problem.",
		"gift": "Doc Imani hands over a field kit. \"Auto-sutures. They close you up on the go. The patch keeps you numb, so you won't know how bad it is. Come see me after.\""},
	"prayer_beads": {"name": "Tobin & Rosa's Prayer Beads", "source": "npc", "giver": "townsfolk",
		"perk": "Takes the edge off every hit (15% less).",
		"curse": "The town talks: people work out what she's up to twice as fast.",
		"blurb": "Wooden beads worn smooth by forty years of Rosa's worrying.",
		"carry": "Rosa's beads click at her wrist. Somewhere in Solace, Tobin is telling someone where she went.",
		"gift": "Old Rosa catches her wrist and winds a string of beads round it. Tobin nods. \"We pray for you, dear. Out loud. To everyone.\""},
	"violet_coin": {"name": "Marrow's Violet Coin", "source": "npc", "giver": "marrow", "mature": true,
		"perk": "Hush's perks on a run without a dose.",
		"curse": "Every run carrying it tightens his Hold.",
		"blurb": "A coin of hardened Hush with his thumbprint in it. It's warm. It's always warm.",
		"carry": "Marrow's coin is warm in her fist. Everything goes quiet, and violet, and his.",
		"gift": "Marrow flips her a coin of violet resin. \"On the house. Keep it on you. That way I'm always with you.\""},
	# Colony tech
	"target_lens": {"name": "Colony Target Lens", "source": "colony",
		"perk": "Her gun's cone tightens a lot.",
		"curse": "Tracking beacon: every so often the colony pings her and grunts close in.",
		"blurb": "A sniper's eyepiece pulled off a colony marksman. Still logged in to their network.",
		"carry": "The target lens clicks into place. Somewhere, a colony console lights up."},
	"phase_harness": {"name": "Phase Harness", "source": "colony",
		"perk": "She moves 15% faster.",
		"curse": "Overheats: long sprints burn her.",
		"blurb": "A colony assault harness. Built for someone twice her size and half as reckless.",
		"carry": "The phase harness whines up to speed. It's already warm."},
	"iff_tag": {"name": "Officer's IFF Tag", "source": "colony",
		"perk": "Grunts take her for one of theirs: much slower to notice her.",
		"curse": "Once they're shooting, they hit 25% harder. Nobody likes an impostor.",
		"blurb": "A colony officer's friend-or-foe tag. He won't be needing it.",
		"carry": "The IFF tag blinks green on her collar. As far as the colony knows, she's on their side."},
}
const ORDER := ["builder_eye", "heartstone", "sunless_mask", "idols_tooth",
	"moms_locket", "ophelias_watch", "biggies_tags", "sals_scale", "imanis_kit", "prayer_beads", "violet_coin",
	"target_lens", "phase_harness", "iff_tag"]

## Who gives a keepsake, and when (run_manager.gd _relic_gift): a bond or
## affection score in npc_talk's state, finished runs, or Marrow's Hold. `spot`
## is the hub or town spot she has to use.
const GIVERS := {
	"mom": {"relic": "moms_locket", "npc": "mom", "bond": 40},
	"ophelia": {"relic": "ophelias_watch", "npc": "ophelia", "affection": 40},
	"biggie": {"relic": "biggies_tags", "npc": "biggie", "bond": 40},
	"sal": {"relic": "sals_scale", "spot": "shop_salvage", "runs": 3},
	"imani": {"relic": "imanis_kit", "spot": "shop_clinic", "runs": 3},
	"townsfolk": {"relic": "prayer_beads", "spot": "job_board", "runs": 4},
	"marrow": {"relic": "violet_coin", "spot": "hush_alley", "hold": 30.0},
}
## Where she'd find the ones she hasn't got (for the reliquary).
const HINTS := {
	"precursor": "A Precursor shrine, somewhere out on a run.",
	"colony": "Colony salvage caches, now and then.",
	"mom": "Mom, once you're close.",
	"ophelia": "Ophelia, once she's fond of you.",
	"biggie": "Biggie, once he trusts you.",
	"sal": "Sal, once you've been out on a few runs.",
	"imani": "Doc Imani, once you've come back hurt a few times.",
	"townsfolk": "Old Tobin and Rosa by the job board, once you've been away a while.",
	"marrow": "Marrow, once he has you.",
}

## Chance a zone has a Precursor shrine (while she's still missing one).
const SHRINE_CHANCE := 0.3
## Chance a salvage cache has a colony relic in it (while she's missing one).
const COLONY_CHANCE := 0.25

const TOOTH_DAMAGE := 1.4
const TOOTH_PRICE := 4.0
const HEART_REGEN := 2.0
## Seconds of a run over which the Heartstone takes half her max health.
const HEART_DRAIN_TIME := 480.0
const HEART_FLOOR := 0.5
const MASK_NOTICE := 0.5
const TAGS_DAMAGE := 0.7
const TAGS_WALLRUN := 0.55
const TAGS_SLIDE_FRICTION := 2.2
const SCALE_LOOT := 1.5
const SCALE_JAM := 0.05
const JAM_TIME := 1.1
const KIT_HEAL := 12.0
const BEADS_DAMAGE := 0.85
const WATCH_LIMIT := 720.0
const WATCH_COST := 5
const WATCH_SLOW := 0.45
const WATCH_TIME := 1.0
const COIN_HOLD := 5.0
const LENS_SPREAD := 0.55
const HARNESS_SPEED := 1.15
const IFF_NOTICE := 0.35
const IFF_DAMAGE := 1.25

## Saved per slot: what she's found and what she's wearing.
static var owned: Array = []
static var worn: Array = []
## Runs she's worn the prayer beads: the town works her out that much sooner
## (townsfolk.gd's stage counts finished runs; this adds to them).
static var town_talk := 0
## Runs she's finished on this save (for Sal, Imani, Tobin and Rosa's gifts).
static var runs := 0
## On a run right now (the hooks do nothing in the hub).
static var on_run := false
## Seconds into this run (relic_fx.gd ticks it).
static var run_time := 0.0
## Mom's locket has saved her this run.
static var locket_used := false
## Something just happened that relic_fx.gd should say (and clears).
static var locket_saved := false
static var jammed := false
static var headshot := false
static var save_path := "user://relics.cfg"


static func allowed(id: String) -> bool:
	return RELICS.has(id) and (not RELICS[id].get("mature", false) or Vices.allowed())


static func relic_name(id: String) -> String:
	return RELICS[id]["name"]


## The relics the reliquary lists under the current rating.
static func listed() -> Array:
	return ORDER.filter(func(id): return allowed(id))


static func owns(id: String) -> bool:
	return id in owned


static func wearing(id: String) -> bool:
	return id in worn and allowed(id)


## The relic is on her on a run: its perk and its catch both apply.
static func active(id: String) -> bool:
	return on_run and wearing(id)


## Finds or is given `id`. Returns whether it's new.
static func gain(id: String) -> bool:
	if not RELICS.has(id) or owns(id):
		return false
	owned.append(id)
	save()
	return true


## Puts it on or takes it off. Returns whether she's wearing it now. With
## every slot full, the oldest one comes off.
static func toggle(id: String) -> bool:
	if id in worn:
		worn.erase(id)
		save()
		return false
	if not owns(id) or not allowed(id):
		return false
	worn.append(id)
	while worn.size() > SLOTS:
		worn.pop_front()
	save()
	return true


## Precursor or colony relics she hasn't found yet (shrines and caches only
## offer these).
static func missing(source: String) -> Array:
	return ORDER.filter(func(id): return RELICS[id]["source"] == source and not owns(id))


## A keepsake `who` (a GIVERS key) is ready to give her now, or "".
## `state` is npc_talk's ConfigFile.
static func gift_due(who: String, state: ConfigFile) -> String:
	if not GIVERS.has(who):
		return ""
	var g: Dictionary = GIVERS[who]
	var id: String = g["relic"]
	if owns(id) or not allowed(id):
		return ""
	if g.has("bond") and (state == null or int(state.get_value(who, "bond", 0)) < int(g["bond"])):
		return ""
	if g.has("affection") and (state == null or int(state.get_value(who, "affection", 0)) < int(g["affection"])):
		return ""
	if g.has("runs") and runs < int(g["runs"]):
		return ""
	if g.has("hold") and Vices.hold < float(g["hold"]):
		return ""
	return id


## Which giver a hub spot belongs to ("" none).
static func giver_at(spot: Dictionary) -> String:
	for who: String in GIVERS:
		var g: Dictionary = GIVERS[who]
		if g.has("npc") and spot.get("npc", "") == g["npc"]:
			return who
		if g.has("spot") and spot.get("id", "") == g["spot"]:
			return who
	return ""


# --- runs ---------------------------------------------------------------------

static func run_started() -> void:
	on_run = true
	run_time = 0.0
	locket_used = false
	locket_saved = false
	jammed = false
	headshot = false


## What she says heading out with them on: one line (the newest one she put
## on), so the run's opening toast stays short; the HUD names the rest.
static func carry_line() -> String:
	for i in range(worn.size() - 1, -1, -1):
		if allowed(worn[i]):
			return RELICS[worn[i]]["carry"]
	return ""


## A run ended (`run_seconds` long). Settles the catches that land at the end
## and returns lines for the summary. `state` is npc_talk's ConfigFile.
static func run_over(state: ConfigFile, run_seconds: float) -> Array:
	var notes := []
	if active("ophelias_watch") and run_seconds > WATCH_LIMIT and state != null:
		state.set_value("ophelia", "affection", clampi(int(state.get_value("ophelia", "affection", 0)) - WATCH_COST, 0, 100))
		notes.append("Ophelia's watch: you kept her waiting. She'll be cold for a bit.")
	if active("violet_coin"):
		Vices.hold = minf(Vices.hold + COIN_HOLD, Vices.MAX_HOLD)
		Vices.reward_check()
		Vices.save()
		notes.append("Marrow's coin: his Hold tightens.")
	if active("prayer_beads"):
		town_talk += 1
		notes.append("Prayer beads: Tobin and Rosa have been talking about you.")
	on_run = false
	run_time = 0.0
	runs += 1
	save()
	return notes


static func tick(delta: float) -> void:
	if on_run:
		run_time += delta


## Mom's locket: once a run, a blow that would put her down doesn't.
static func cheat_death() -> bool:
	if not active("moms_locket") or locket_used:
		return false
	locket_used = true
	locket_saved = true
	return true


## Sal's parts: a shot that jams instead (`roll` 0..1).
static func jams(roll: float) -> bool:
	if not active("sals_scale") or roll >= SCALE_JAM:
		return false
	jammed = true
	return true


static func note_headshot() -> void:
	if active("ophelias_watch"):
		headshot = true


# --- stat hooks -------------------------------------------------------------------

## Marrow's coin as strong as a dose would be (vices.gd hush()), when there's no dose in her.
static func _coin() -> float:
	if not active("violet_coin") or Vices.hush() > 0.0:
		return 0.0
	return 1.0 + Vices.hold / 100.0


static func damage_out() -> float:
	var k := TOOTH_DAMAGE if active("idols_tooth") else 1.0
	var c := _coin()
	return k * (1.0 + 0.2 * c)


static func damage_in() -> float:
	var k := 1.0
	if active("biggies_tags"):
		k *= TAGS_DAMAGE
	if active("prayer_beads"):
		k *= BEADS_DAMAGE
	if active("iff_tag"):
		k *= IFF_DAMAGE
	return k


static func regen_scale() -> float:
	var k := HEART_REGEN if active("heartstone") else 1.0
	return k * (1.0 + 0.4 * _coin())


## Her max health (the Heartstone's drain).
static func health_scale() -> float:
	if not active("heartstone"):
		return 1.0
	return 1.0 - (1.0 - HEART_FLOOR) * clampf(run_time / HEART_DRAIN_TIME, 0.0, 1.0)


static func notice_scale() -> float:
	var k := 1.0
	if active("sunless_mask"):
		k *= MASK_NOTICE
	if active("iff_tag"):
		k *= IFF_NOTICE
	return k * (1.0 - 0.2 * _coin())


static func spread_scale() -> float:
	return LENS_SPREAD if active("target_lens") else 1.0


static func speed_scale() -> float:
	return HARNESS_SPEED if active("phase_harness") else 1.0


static func wallrun_scale() -> float:
	return TAGS_WALLRUN if active("biggies_tags") else 1.0


static func slide_friction_scale() -> float:
	return TAGS_SLIDE_FRICTION if active("biggies_tags") else 1.0


## Materials she picks up (Sal's scale), rounded up.
static func loot_amount(amount: int) -> int:
	return ceili(amount * SCALE_LOOT) if active("sals_scale") else amount


## Imani's patch: no health readout.
static func numb() -> bool:
	return active("imanis_kit")


## Health a kill gives back (negative: the Tooth's price).
static func kill_health() -> float:
	var h := 0.0
	if active("imanis_kit"):
		h += KIT_HEAL
	if active("idols_tooth"):
		h -= TOOTH_PRICE
	return h


## For the run HUD: what she's wearing ("" nothing).
static func hud_text() -> String:
	var names := []
	for id: String in worn:
		if allowed(id):
			names.append(relic_name(id).to_upper())
	return "" if names.is_empty() else "RELICS: " + ", ".join(names)


# --- saving -----------------------------------------------------------------------

static func open(path: String) -> void:
	save_path = path
	reset()
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		owned = cfg.get_value("relics", "owned", []).filter(func(id): return RELICS.has(id))
		worn = cfg.get_value("relics", "worn", []).filter(func(id): return id in owned)
		town_talk = cfg.get_value("relics", "town_talk", 0)
		runs = cfg.get_value("relics", "runs", 0)


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("relics", "owned", owned)
	cfg.set_value("relics", "worn", worn)
	cfg.set_value("relics", "town_talk", town_talk)
	cfg.set_value("relics", "runs", runs)
	cfg.save(save_path)


## Clears everything in memory (tests). Doesn't touch the save.
static func reset() -> void:
	owned = []
	worn = []
	town_talk = 0
	runs = 0
	on_run = false
	run_time = 0.0
	locket_used = false
	locket_saved = false
	jammed = false
	headshot = false
