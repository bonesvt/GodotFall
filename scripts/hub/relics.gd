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
## Under Mature (vices.gd allowed()) most relics turn darker (MATURE: their
## names, lines, perks and catches change, mostly feeding her vices: buzz,
## stim dependence, smokes, Glass, Marrow's Hold), and a few only exist there
## ("mature": Marrow's coin, the Censer, Rook's glass, Dutch's deck, the stim
## injector, the Glass core): under Teen those aren't offered, can't be worn
## and do nothing.
##
## The stat hooks (damage_out, damage_in, regen_scale, ...) are 1.0 off a run
## or without the relic; the timed side effects run in relic_fx.gd. What she
## owns and wears is saved per save slot.

const ContentRating := preload("res://scripts/radio/content_rating.gd")
const Vices := preload("res://scripts/hub/vices.gd")

const SLOTS := 2
## Longest a carry line can be and still fit the run toast on one line.
const CARRY_MAX := 62
const SOURCES := {"precursor": "Precursor relic", "npc": "Keepsake", "colony": "Colony tech"}

## id -> name, source, who gives it (npc ones), the perk, the catch, a blurb.
const RELICS := {
	# Precursor
	"builder_eye": {"name": "Eye of the Builder", "source": "precursor",
		"perk": "Grunts within 30 m show through walls.",
		"curse": "Whispers: markers and voices that aren't there.",
		"blurb": "A carved eye the size of a plum. It's warm, and it never blinks.",
		"carry": "The Builder's eye is warm in her pocket. It's whispering."},
	"heartstone": {"name": "Heartstone", "source": "precursor",
		"perk": "Heals twice as fast.",
		"curse": "Slow drain: her max health shrinks the longer the run goes, down to half.",
		"blurb": "A red stone that beats. Slowly. It's taking something to do it.",
		"carry": "The Heartstone beats against her ribs, out of step with hers."},
	"sunless_mask": {"name": "Sunless Mask", "source": "precursor",
		"perk": "Grunts take twice as long to notice her.",
		"curse": "Blackouts: now and then the world goes dark for a second or two.",
		"blurb": "A smooth stone mask with no eyeholes. Wear it and nobody quite sees you. Sometimes you don't either.",
		"carry": "The Sunless Mask goes on cold. The edges of things go soft."},
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
		"carry": "Biggie's tags clink at her collar. Her knee aches for him.",
		"gift": "Biggie tugs a chain over his head. \"Kept me alive through Third Valley. Took my knee as payment. Fair trade, mostly.\""},
	"sals_scale": {"name": "Sal's Lucky Scale", "source": "npc", "giver": "sal",
		"perk": "Half again as many materials from everything she picks up.",
		"curse": "Cheap salvage parts: her gun jams now and then.",
		"blurb": "A brass scale weight, filed down so it always reads in Sal's favour. Now it reads in hers.",
		"carry": "Sal's scale rattles in her pouch. So does her gun.",
		"gift": "Sal slides a little brass weight over the counter. \"Lucky. Mostly. Swapped a couple of your gun parts for cheaper ones while I was at it. You're welcome.\""},
	"imanis_kit": {"name": "Imani's Stitch Kit", "source": "npc", "giver": "imani",
		"perk": "Every kill patches her up.",
		"curse": "Anaesthetic: her health readout is gone. She can't feel how hurt she is.",
		"blurb": "Doc Imani's field kit: auto-sutures, a numbing patch, a note that says DON'T.",
		"carry": "Imani's patch kicks in. She can't feel a thing. That's bad.",
		"gift": "Doc Imani hands over a field kit. \"Auto-sutures. They close you up on the go. The patch keeps you numb, so you won't know how bad it is. Come see me after.\""},
	"prayer_beads": {"name": "Tobin & Rosa's Prayer Beads", "source": "npc", "giver": "townsfolk",
		"perk": "Takes the edge off every hit (15% less).",
		"curse": "The town talks: people work out what she's up to twice as fast.",
		"blurb": "Wooden beads worn smooth by forty years of Rosa's worrying.",
		"carry": "Rosa's beads click. Tobin's telling everyone where she went.",
		"gift": "Old Rosa catches her wrist and winds a string of beads round it. Tobin nods. \"We pray for you, dear. Out loud. To everyone.\""},
	"violet_coin": {"name": "Marrow's Violet Coin", "source": "npc", "giver": "marrow", "mature": true,
		"perk": "Hush's perks on a run without a dose.",
		"curse": "Every run carrying it tightens his Hold.",
		"blurb": "A coin of hardened Hush with his thumbprint in it. It's warm. It's always warm.",
		"carry": "Marrow's coin is warm. Everything goes quiet, violet, his.",
		"gift": "Marrow flips her a coin of violet resin. \"On the house. Keep it on you. That way I'm always with you.\""},
	# Colony tech
	"target_lens": {"name": "Colony Target Lens", "source": "colony",
		"perk": "Her gun's cone tightens a lot.",
		"curse": "Tracking beacon: every so often the colony pings her and grunts close in.",
		"blurb": "A sniper's eyepiece pulled off a colony marksman. Still logged in to their network.",
		"carry": "The lens clicks in. Somewhere, a colony console lights up."},
	"phase_harness": {"name": "Phase Harness", "source": "colony",
		"perk": "She moves 15% faster.",
		"curse": "Overheats: long sprints burn her.",
		"blurb": "A colony assault harness. Built for someone twice her size and half as reckless.",
		"carry": "The phase harness whines up to speed. It's already warm."},
	"iff_tag": {"name": "Officer's IFF Tag", "source": "colony",
		"perk": "Grunts take her for one of theirs: much slower to notice her.",
		"curse": "Once they're shooting, they hit 25% harder. Nobody likes an impostor.",
		"blurb": "A colony officer's friend-or-foe tag. He won't be needing it.",
		"carry": "The IFF tag blinks green. To the colony, she's one of theirs."},
	# Mature only
	"censer": {"name": "Precursor Censer", "source": "precursor", "mature": true,
		"perk": "Temple incense hangs round her: grunts are much slower to pick her up.",
		"curse": "She's breathing it too: it works on her like drink, the buzz climbing the longer the run goes.",
		"blurb": "A little bronze burner on a chain, still smouldering after a thousand years. The smoke smells like honey and pennies.",
		"carry": "The censer swings at her hip. Sweet smoke, lighter head."},
	"rooks_glass": {"name": "Rook's Lucky Shot Glass", "source": "npc", "giver": "rook", "mature": true,
		"perk": "The drunker she is, the harder she hits (up to 35%).",
		"curse": "The buzz never fully leaves her on a run, and Rook's tab takes scrap after every one.",
		"blurb": "A chipped shot glass with a tally scratched round the rim. Rook's been counting something.",
		"carry": "Rook's glass clinks in her pocket. She can taste the last one.",
		"gift": "Rook slides a chipped shot glass down the bar. \"Lucky. Every hero who ever drank from it came back. Mostly. I'll put it on your tab.\""},
	"dutchs_deck": {"name": "Dutch's Marked Deck", "source": "npc", "giver": "dutch", "mature": true,
		"perk": "Luck leans her way: a quarter more materials from everything.",
		"curse": "Card-shark luck runs out: every third run with it, the deck turns and she loses half her haul.",
		"blurb": "A worn deck with tiny pinpricks on the backs. Dutch swears he's never used it. On her.",
		"carry": "Dutch's deck riffles. Feels lucky. Feels like a setup.",
		"gift": "Dutch tucks a deck into her jacket. \"Marked. Don't tell Rook. Luck's a loan, kid. It always comes to collect.\""},
	"stim_injector": {"name": "Combat Stim Injector", "source": "colony", "mature": true,
		"perk": "When she's nearly down, it jabs her with Ironskin on its own (once a run).",
		"curse": "Every jab it gives her counts towards her dependence, whether she wanted it or not.",
		"blurb": "A colony trooper's auto-injector, strapped to the thigh. It decides when you need it.",
		"carry": "The injector clicks onto her thigh. It decides now, not her."},
	"glass_core": {"name": "Glass Core", "source": "colony", "mature": true,
		"perk": "When she's hit, a free second of Glass slow-mo (every 45 s at most).",
		"curse": "Each one crystallises her a step, like a vial does.",
		"blurb": "Marrow's Glass, set in colony circuitry. A violet heart that ticks.",
		"carry": "The Glass core hums at her spine, waiting for her to get hurt."},
}

## What changes under Mature: id -> the keys that replace the Teen ones (text,
## and the behaviour noted in each catch; relics.gd and relic_fx.gd check
## mature() for it). Marrow's coin is Mature only already.
const MATURE := {
	"builder_eye": {"name": "Builder's Eye",
		"curse": "The whispers are in her dad's voice, and cruel. While they talk, her aim drifts.",
		"carry": "The Builder's eye is warm. \"Hey, kiddo,\" it says. His voice."},
	"heartstone": {"perk": "Heals twice as fast.",
		"curse": "It feeds on her: her max health drains, and she brings a fever home that weakens her next run.",
		"carry": "The Heartstone beats at her ribs. Her skin's already hot."},
	"sunless_mask": {"curse": "Longer blackouts, and sometimes she comes to somewhere else, bruised, with no idea how she got there.",
		"carry": "The Sunless Mask goes on cold. She won't remember today."},
	"idols_tooth": {"curse": "Bloodlust: every kill costs her health, and 30 s without one her hands start shaking.",
		"carry": "The Idol's Tooth hums. It wants blood. So, a little, does she."},
	"moms_locket": {"name": "Mom's Rosary Flask",
		"curse": "It's Mom's \"medicine\": when it keeps her up, she takes a long pull (a lot of buzz), and Mom finds it empty.",
		"blurb": "A dented hip flask with a rosary wound round the neck. Mom says it's for emergencies. Mom has a lot of emergencies.",
		"carry": "Mom's flask sloshes under her suit. Only if she needs it.",
		"gift": "Mom presses a dented flask into her palm and won't meet her eyes. \"For emergencies. Your father's. Don't tell Biggie I gave it you.\""},
	"ophelias_watch": {"name": "Ophelia's Lighter",
		"perk": "While she's smoking, a tighter cone, and headshots slow the world.",
		"curse": "Smokes burn twice as fast, and every run she doesn't light up, Ophelia goes cold on her.",
		"blurb": "A brass lighter engraved O + E. It smells like Night Owls and Ophelia's jacket.",
		"carry": "Ophelia's lighter is warm. She should light one. For her.",
		"gift": "Ophelia presses her lighter into Eco's hand and closes her fingers round it. \"Think of me every time you light up. Every time.\""},
	"biggies_tags": {"name": "Biggie's Hip Flask",
		"perk": "Grunts' shots hurt her 35% less.",
		"curse": "Old soldier's habit: she starts every run two drinks in, and his bad knee shortens her wallruns and slides.",
		"blurb": "A battered army flask with his unit's number on it. It's never empty. He makes sure.",
		"carry": "Two pulls from Biggie's flask before the drop. Army habit.",
		"gift": "Biggie hands over a battered flask. \"Two swallows before the drop. Every pilot I flew with did it. Most of 'em are dead, but not from that.\""},
	"sals_scale": {"name": "Sal's Back-Alley Kit",
		"perk": "A free stim on her belt every run.",
		"curse": "Sal cuts them with filler: crashes hit her harder, and any run she jabs costs extra dependence.",
		"blurb": "A tin case of unlabelled shots and a rubber tourniquet. Sal says it's a loyalty scheme.",
		"carry": "Sal's kit rattles on her belt. One on the house. Always one.",
		"gift": "Sal pushes a tin case across the hatch. \"Loyalty scheme. One a run, free. Then you'll want two. That's how loyalty works.\""},
	"imanis_kit": {"name": "Imani's Painkillers",
		"perk": "Every kill patches her up, and every hit lands softer.",
		"curse": "No health readout, and the pills build their own habit: go out without them and she gets the shakes.",
		"blurb": "A brown bottle with Doc Imani's handwriting on it: ONE. ONLY ONE. ECO, I MEAN IT.",
		"carry": "One of Imani's pills. Then another. She can't feel a thing.",
		"gift": "Doc Imani hands over a brown bottle and holds on a beat too long. \"For the pain. One at a time. I'm trusting you with these, Eco.\""},
	"prayer_beads": {"curse": "The town talks, and the colony listens: grunts start every zone already half suspicious.",
		"carry": "Rosa's beads click. The whole town knows. So does the colony."},
	"target_lens": {"curse": "The colony tracks her, and taunts her over her own radio about her dad as their grunts close in.",
		"carry": "The lens clicks in. Her radio: \"Hello again, little pilot.\""},
	"iff_tag": {"curse": "Once they're shooting they hit 25% harder, and word gets back to Mom that she's been wearing colony colours.",
		"carry": "The IFF tag blinks green. Somebody in Solace sees it."},
}

const ORDER := ["builder_eye", "heartstone", "sunless_mask", "idols_tooth", "censer",
	"moms_locket", "ophelias_watch", "biggies_tags", "sals_scale", "imanis_kit", "prayer_beads", "violet_coin",
	"rooks_glass", "dutchs_deck",
	"target_lens", "phase_harness", "iff_tag", "stim_injector", "glass_core"]

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
	"rook": {"relic": "rooks_glass", "spot": "shop_bar", "runs": 2},
	"dutch": {"relic": "dutchs_deck", "spot": "shop_bar", "runs": 5},
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
	"rook": "Rook at the Rusted Halo, once you're a regular.",
	"dutch": "Dutch at the Halo's card table, once he's taken enough of your scrap.",
}

## Chance a zone has a Precursor shrine (while she's still missing one).
const SHRINE_CHANCE := 0.3
## Chance a salvage cache has a colony relic in it (while she's missing one).
const COLONY_CHANCE := 0.25

const TOOTH_DAMAGE := 1.4
const TOOTH_PRICE := 4.0
## Mature: seconds without a kill before the Tooth's bloodlust shakes her.
const TOOTH_THIRST := 30.0
const HEART_REGEN := 2.0
## Seconds of a run over which the Heartstone takes half her max health.
const HEART_DRAIN_TIME := 480.0
const HEART_FLOOR := 0.5
## Mature: the fever she brings home takes this share of her max health next run.
const FEVER := 0.85
const MASK_NOTICE := 0.5
const TAGS_DAMAGE := 0.7
const TAGS_DAMAGE_M := 0.65
const TAGS_WALLRUN := 0.55
const TAGS_SLIDE_FRICTION := 2.2
## Mature: buzz she starts a run with (Biggie's flask), and the flask's pull when Mom's saves her.
const FLASK_BUZZ := 2.0
const SCALE_LOOT := 1.5
const SCALE_JAM := 0.05
const JAM_TIME := 1.1
## Mature: Sal's filler makes a crash hit this much harder.
const FILLER_DAMAGE := 1.15
const KIT_HEAL := 12.0
## Mature: Imani's pills soften hits, and a habit of PILL_HABIT runs brings the shakes without them.
const PILL_DAMAGE := 0.85
const PILL_HABIT := 2
const BEADS_DAMAGE := 0.85
## Mature: how suspicious grunts start a zone when the colony's heard the town talk.
const BEADS_WARY := 0.45
const WATCH_LIMIT := 720.0
const WATCH_COST := 5
const WATCH_SLOW := 0.45
const WATCH_TIME := 1.0
## Mature: Ophelia's lighter.
const LIGHTER_SPREAD := 0.7
const LIGHTER_COST := 4
const COIN_HOLD := 5.0
const LENS_SPREAD := 0.55
const HARNESS_SPEED := 1.15
const IFF_NOTICE := 0.35
const IFF_DAMAGE := 1.25
const IFF_BOND := 2
const FLASK_BOND := 3
const CENSER_NOTICE := 0.55
## Buzz the censer adds a second, and the most it takes her to.
const CENSER_BUZZ := 1.0 / 75.0
const CENSER_MAX := 3.0
const ROOK_DAMAGE := 0.35
const ROOK_FLOOR := 1.0
const ROOK_TAB := 8
const DECK_LOOT := 1.25
const DECK_TURN := 3
const DECK_CUT := 0.5
const INJECTOR_AT := 0.3
const CORE_COOLDOWN := 45.0
const CORE_FOCUS := 1.0

## Saved per slot: what she's found and what she's wearing.
static var owned: Array = []
static var worn: Array = []
## Runs she's worn the prayer beads: the town works her out that much sooner
## (townsfolk.gd's stage counts finished runs; this adds to them).
static var town_talk := 0
## Runs she's finished on this save (for Sal, Imani, Tobin and Rosa's gifts).
static var runs := 0
## Mature, saved: the Heartstone's fever (due on her next run), Imani's pill
## habit, Dutch's deck's runs.
static var fever := false
static var pills := 0
static var deck_runs := 0
## On a run right now (the hooks do nothing in the hub).
static var on_run := false
## Seconds into this run (relic_fx.gd ticks it).
static var run_time := 0.0
## This run carries the fever from the last.
static var feverish := false
## Mom's locket has saved her this run.
static var locket_used := false
## Mature, this run: she's lit a smoke, she's jabbed a stim, seconds since
## her last kill, the injector's fired, the whispers are talking (0..1).
static var lit := false
static var jabbed := false
static var since_kill := 0.0
static var injected := false
static var whispering := 0.0
## Mature, end of run: scrap Rook's tab takes, and the share of her haul she keeps (Dutch's deck).
static var scrap_owed := 0
static var haul_keep := 1.0
## Something just happened that relic_fx.gd should say (and clears).
static var locket_saved := false
static var jammed := false
static var headshot := false
static var save_path := "user://relics.cfg"


## Under Mature (the game's rating): the relics' darker sides.
static func mature() -> bool:
	return Vices.allowed()


static func allowed(id: String) -> bool:
	return RELICS.has(id) and (not RELICS[id].get("mature", false) or mature())


## A relic's text under the current rating (`key`: name, perk, curse, blurb, carry, gift).
static func text(id: String, key: String) -> String:
	if mature() and MATURE.has(id) and MATURE[id].has(key):
		return MATURE[id][key]
	return RELICS[id].get(key, "")


static func relic_name(id: String) -> String:
	return text(id, "name")


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


## Worn on a run with its Mature side.
static func dark(id: String) -> bool:
	return active(id) and mature()


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
	while worn.filter(func(w): return allowed(w)).size() > SLOTS:
		worn.erase(worn.filter(func(w): return allowed(w))[0])
	save()
	return true


## Precursor or colony relics she hasn't found yet under this rating (shrines
## and caches only offer these).
static func missing(source: String) -> Array:
	return ORDER.filter(func(id): return RELICS[id]["source"] == source and not owns(id) and allowed(id))


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


## Who's at a hub spot with a keepsake ready for her ("" nobody).
static func giver_at(spot: Dictionary, state: ConfigFile = null) -> String:
	for who: String in GIVERS:
		var g: Dictionary = GIVERS[who]
		var here: bool = (g.has("npc") and spot.get("npc", "") == g["npc"]) or (g.has("spot") and spot.get("id", "") == g["spot"])
		if here and (state == null or gift_due(who, state) != ""):
			return who
	return ""


# --- runs ---------------------------------------------------------------------

static func run_started() -> void:
	on_run = true
	run_time = 0.0
	feverish = fever and mature()
	fever = false
	locket_used = false
	locket_saved = false
	jammed = false
	headshot = false
	lit = false
	jabbed = false
	since_kill = 0.0
	injected = false
	whispering = 0.0
	scrap_owed = 0
	haul_keep = 1.0
	if dark("biggies_tags"):
		Vices.buzz = minf(Vices.buzz + FLASK_BUZZ, Vices.MAX_BUZZ)
	if dark("sals_scale") and not Vices.belt_full():
		Vices.add_stim(Vices.STIM_ORDER[randi() % Vices.STIM_ORDER.size()])
	save()


## What she says heading out with them on: one line (the newest one she put
## on), so the run's opening toast stays short; the HUD names the rest.
static func carry_line() -> String:
	var lines := []
	for i in range(worn.size() - 1, -1, -1):
		if allowed(worn[i]):
			lines.append(text(worn[i], "carry"))
			break
	if feverish:
		lines.append("Still burning up from the Heartstone's fever.")
	if pill_craving():
		lines.append("No pills today. Her hands won't keep still.")
	return "\n".join(lines)


## A run ended (`run_seconds` long). Settles the catches that land at the end
## and returns lines for the summary. `state` is npc_talk's ConfigFile.
## Rook's tab (scrap_owed) and Dutch's deck (haul_keep) are for the run
## manager to take before it banks the haul.
static func run_over(state: ConfigFile, run_seconds: float) -> Array:
	var notes := []
	var m := mature()
	if active("ophelias_watch") and not m and run_seconds > WATCH_LIMIT and state != null:
		_nudge(state, "ophelia", "affection", -WATCH_COST)
		notes.append("Ophelia's watch: you kept her waiting. She'll be cold for a bit.")
	if dark("ophelias_watch") and not lit and state != null:
		_nudge(state, "ophelia", "affection", -LIGHTER_COST)
		notes.append("Ophelia's lighter: you never lit up. She noticed.")
	if active("violet_coin"):
		Vices.hold = minf(Vices.hold + COIN_HOLD, Vices.MAX_HOLD)
		Vices.reward_check()
		Vices.save()
		notes.append("Marrow's coin: his Hold tightens.")
	if active("prayer_beads"):
		town_talk += 1
		notes.append("Prayer beads: Tobin and Rosa have been talking about you." + (" Somebody else was listening." if m else ""))
	if dark("heartstone"):
		fever = true
		notes.append("Heartstone: she's burning up. The fever will still be on her next run.")
	if dark("moms_locket") and locket_used and state != null:
		_nudge(state, "mom", "bond", -FLASK_BOND)
		notes.append("Mom's flask: empty. Mom will notice.")
	if dark("iff_tag") and state != null:
		_nudge(state, "mom", "bond", -IFF_BOND)
		notes.append("IFF tag: someone in town saw her in colony colours and told Mom.")
	if dark("sals_scale") and jabbed:
		Vices.dependence += 1.0
		Vices.save()
		notes.append("Sal's kit: the filler's in her blood. Her dependence climbs.")
	if m:
		if dark("imanis_kit"):
			pills += 1
		elif pills > 0:
			pills -= 1
	if dark("rooks_glass"):
		scrap_owed += ROOK_TAB
		notes.append("Rook's tab: %d scrap." % ROOK_TAB)
	if dark("dutchs_deck"):
		deck_runs += 1
		if deck_runs % DECK_TURN == 0:
			haul_keep = DECK_CUT
			notes.append("Dutch's deck turned on her: she lost half her haul.")
	on_run = false
	run_time = 0.0
	feverish = false
	runs += 1
	save()
	return notes


static func _nudge(state: ConfigFile, who: String, key: String, delta: int) -> void:
	state.set_value(who, key, clampi(int(state.get_value(who, key, 0)) + delta, 0, 100))


## Game time on a run: the clock, the censer's smoke, Rook's floor, the lighter's burn.
static func tick(delta: float) -> void:
	if not on_run:
		return
	run_time += delta
	since_kill += delta
	if not mature():
		return
	if Vices.smoke_left > 0.0:
		lit = true
		if dark("ophelias_watch"):
			Vices.smoke_left = maxf(Vices.smoke_left - delta, 0.0)  # it burns twice as fast
	if Vices.stim != "":
		jabbed = true
	if dark("censer") and Vices.buzz < CENSER_MAX:
		Vices.buzz = minf(Vices.buzz + (CENSER_BUZZ + Vices.WEAR_OFF) * delta, CENSER_MAX)
	if dark("rooks_glass"):
		Vices.buzz = maxf(Vices.buzz, ROOK_FLOOR)


static func on_kill() -> void:
	since_kill = 0.0


## Mom's locket: once a run, a blow that would put her down doesn't.
static func cheat_death() -> bool:
	if not active("moms_locket") or locket_used:
		return false
	locket_used = true
	locket_saved = true
	if mature():
		Vices.buzz = minf(Vices.buzz + FLASK_BUZZ, Vices.MAX_BUZZ)  # Mom's "medicine"
	return true


## Sal's parts: a shot that jams instead (`roll` 0..1). Not his Mature kit.
static func jams(roll: float) -> bool:
	if not active("sals_scale") or mature() or roll >= SCALE_JAM:
		return false
	jammed = true
	return true


static func note_headshot() -> void:
	if active("ophelias_watch") and (not mature() or Vices.calm()):
		headshot = true


## The injector fires: she's nearly down (`health_frac`) and nothing's in her.
## Returns whether it jabbed her.
static func auto_jab(health_frac: float) -> bool:
	if not dark("stim_injector") or injected or health_frac >= INJECTOR_AT or Vices.stim != "":
		return false
	injected = true
	Vices.stim = "ironskin"
	Vices.stim_left = Vices.STIMS["ironskin"]["time"]
	Vices.crash_left = 0.0
	Vices.dependence += 1.0
	Vices.jabbed = true
	jabbed = true
	Vices.save()
	return true


## Mature: she goes without Imani's pills once she's hooked.
static func pill_craving() -> bool:
	return on_run and mature() and pills >= PILL_HABIT and not wearing("imanis_kit")


## Mature: the Tooth wants blood.
static func bloodlust() -> bool:
	return dark("idols_tooth") and since_kill > TOOTH_THIRST


# --- stat hooks -------------------------------------------------------------------

## Marrow's coin as strong as a dose would be (vices.gd hush()), when there's no dose in her.
static func _coin() -> float:
	if not active("violet_coin") or Vices.hush() > 0.0:
		return 0.0
	return 1.0 + Vices.hold / 100.0


static func damage_out() -> float:
	var k := TOOTH_DAMAGE if active("idols_tooth") else 1.0
	if dark("rooks_glass"):
		k *= 1.0 + ROOK_DAMAGE * Vices.effect()
	return k * (1.0 + 0.2 * _coin())


static func damage_in() -> float:
	var k := 1.0
	if active("biggies_tags"):
		k *= TAGS_DAMAGE_M if mature() else TAGS_DAMAGE
	if active("prayer_beads"):
		k *= BEADS_DAMAGE
	if active("iff_tag"):
		k *= IFF_DAMAGE
	if dark("imanis_kit"):
		k *= PILL_DAMAGE
	if dark("sals_scale") and Vices.crashing():
		k *= FILLER_DAMAGE
	return k


static func regen_scale() -> float:
	var k := HEART_REGEN if active("heartstone") else 1.0
	return k * (1.0 + 0.4 * _coin())


## Her max health (the Heartstone's drain, and its fever).
static func health_scale() -> float:
	var k := FEVER if on_run and feverish else 1.0
	if not active("heartstone"):
		return k
	return k * (1.0 - (1.0 - HEART_FLOOR) * clampf(run_time / HEART_DRAIN_TIME, 0.0, 1.0))


static func notice_scale() -> float:
	var k := 1.0
	if active("sunless_mask"):
		k *= MASK_NOTICE
	if active("iff_tag"):
		k *= IFF_NOTICE
	if dark("censer"):
		k *= CENSER_NOTICE
	return k * (1.0 - 0.2 * _coin())


static func spread_scale() -> float:
	var k := LENS_SPREAD if active("target_lens") else 1.0
	if dark("ophelias_watch") and Vices.calm():
		k *= LIGHTER_SPREAD
	if bloodlust():
		k *= 1.5
	return k


## Mature drift on her aim (degrees: yaw, pitch) at time `t`: her dad's voice
## in the Eye, the Tooth's bloodlust, no pills.
static func sway(t: float) -> Vector2:
	var e := 0.0
	if dark("builder_eye"):
		e = maxf(e, whispering * 0.7)
	if bloodlust():
		e = maxf(e, 0.55)
	if pill_craving():
		e = maxf(e, 0.5)
	if e <= 0.0:
		return Vector2.ZERO
	return Vector2(sin(t * 1.7) * 0.7 + sin(t * 3.1 + 1.0) * 0.3, sin(t * 1.3 + 2.0) * 0.6 + sin(t * 2.7) * 0.3) * 2.2 * e


static func speed_scale() -> float:
	return HARNESS_SPEED if active("phase_harness") else 1.0


static func wallrun_scale() -> float:
	return TAGS_WALLRUN if active("biggies_tags") else 1.0


static func slide_friction_scale() -> float:
	return TAGS_SLIDE_FRICTION if active("biggies_tags") else 1.0


## Materials she picks up (Sal's scale under Teen, Dutch's deck), rounded up.
static func loot_amount(amount: int) -> int:
	var k := 1.0
	if active("sals_scale") and not mature():
		k *= SCALE_LOOT
	if dark("dutchs_deck"):
		k *= DECK_LOOT
	return ceili(amount * k) if k != 1.0 else amount


## Imani's patch (or pills): no health readout.
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


## How suspicious grunts start a zone (0: as usual): the town's talk reached the colony.
static func grunt_wariness() -> float:
	return BEADS_WARY if dark("prayer_beads") else 0.0


## For the run HUD: what she's wearing ("" nothing).
static func hud_text() -> String:
	var names := []
	for id: String in worn:
		if allowed(id):
			names.append(relic_name(id).to_upper())
	return "" if names.is_empty() else "RELICS\n" + "\n".join(names)


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
		fever = cfg.get_value("relics", "fever", false)
		pills = cfg.get_value("relics", "pills", 0)
		deck_runs = cfg.get_value("relics", "deck_runs", 0)


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("relics", "owned", owned)
	cfg.set_value("relics", "worn", worn)
	cfg.set_value("relics", "town_talk", town_talk)
	cfg.set_value("relics", "runs", runs)
	cfg.set_value("relics", "fever", fever)
	cfg.set_value("relics", "pills", pills)
	cfg.set_value("relics", "deck_runs", deck_runs)
	cfg.save(save_path)


## Clears everything in memory (tests). Doesn't touch the save.
static func reset() -> void:
	owned = []
	worn = []
	town_talk = 0
	runs = 0
	fever = false
	pills = 0
	deck_runs = 0
	on_run = false
	run_time = 0.0
	feverish = false
	locket_used = false
	locket_saved = false
	jammed = false
	headshot = false
	lit = false
	jabbed = false
	since_kill = 0.0
	injected = false
	whispering = 0.0
	scrap_owed = 0
	haul_keep = 1.0
