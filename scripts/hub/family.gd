extends RefCounted
## Motherly Love: Eco's bond with her mom. Wholesome and family-only; it
## shares nothing with romance.gd except the save file and the talk screen.
##
## Anyone whose dialogue has a [family] section (Mom, from
## dialogue/family/mom.txt) has a bond score, 0..100, saved with their talks
## in npc_talk.gd's save file. It grows with time spent together: the first
## talk each hub stay, curling up with her ([cuddle] talks, once a stay), being
## looked after when Eco comes home sick ([sick] talks), and Eco's answers in
## their [bond N] scenes, which unlock at N and play once each, in order.
## Once they're close, their [close] talks join the everyday ones.
##
## The bond softens Eco: softness() is how far it has gone (0..1). Her
## whispers on a run (eco_whispers.gd) mix in gentler lines the higher it is,
## and other people's [soft] talks (dialogue/family/<who>.txt) start turning
## up once she's close to Mom. She starts bratty and stays a little bratty;
## it's gradual.
##
## [family] settings, one per line:
##   cuddle_from: 10      bond before "curl up with her" opens
##   close_from: 50       bond before their [close] talks start

const MAX := 100
## Bond for the first talk in each hub stay.
const TALK_GAIN := 3
## Curling up together, once a hub stay.
const CUDDLE_GAIN := 6
## Letting her look after Eco when she's sick.
const CARE_GAIN := 8
const CUDDLE_FROM := 10
const CLOSE_FROM := 50
## Others' [soft] talks start once Eco is this soft.
const SOFT_TALKS_FROM := 0.4
## Where each stage starts, low to high.
const STAGES := [[0, "distant"], [10, "guarded"], [25, "warming"], [50, "close"], [75, "mommy's girl"]]
const HEARTS := 5
## Coming home sick: always the first run lost after meeting Mom, then this
## often after a lost run (and now and then after a won one), never two hub
## stays in a row.
const SICK_LOST := 0.35
const SICK_WON := 0.1
## The save file section for Eco's own state (sick or not).
const ECO := "eco"


static func has_family(bank: Dictionary) -> bool:
	return bank.has("family")


static func settings(bank: Dictionary) -> Dictionary:
	var out := {"cuddle_from": CUDDLE_FROM, "close_from": CLOSE_FROM}
	for kv in bank.get("family", []):
		if kv is Array and out.has(kv[0]):
			out[kv[0]] = int(kv[1])
	return out


static func bond(state: ConfigFile, who: String) -> int:
	return int(state.get_value(who, "bond", 0))


## Adds `delta` (clamped to 0..MAX) and returns the new score.
static func add(state: ConfigFile, who: String, delta: int) -> int:
	var v := clampi(bond(state, who) + delta, 0, MAX)
	state.set_value(who, "bond", v)
	return v


static func stage(state: ConfigFile, who: String) -> String:
	var b := bond(state, who)
	var out: String = STAGES[0][1]
	for st in STAGES:
		if b >= int(st[0]):
			out = st[1]
	return out


## How full the meter is, 0..HEARTS in half steps.
static func hearts(state: ConfigFile, who: String) -> float:
	return roundf(float(bond(state, who)) / MAX * HEARTS * 2.0) / 2.0


## How soft Eco has got, 0..1: her strongest family bond.
static func softness(state: ConfigFile) -> float:
	var best := 0
	for who in state.get_sections():
		best = maxi(best, int(state.get_value(who, "bond", 0)))
	return float(best) / MAX


## The next [bond N] scene they're ready for, or {}. `extra` is bond about to
## be added.
static func next_scene(state: ConfigFile, bank: Dictionary, who: String, extra := 0) -> Dictionary:
	if not has_family(bank):
		return {}
	var b := bond(state, who) + extra
	var seen: Array = state.get_value(who, "bond_beats", [])
	for scene in bank.get("bond", []):
		if int(scene["at"]) <= b and not seen.has(int(scene["at"])):
			return scene
	return {}


static func mark_scene(state: ConfigFile, who: String, at: int) -> void:
	var seen: Array = state.get_value(who, "bond_beats", [])
	if not seen.has(at):
		seen.append(at)
	state.set_value(who, "bond_beats", seen)


## Puts a scene back so it plays again next time (walked off, or "!later").
static func unmark_scene(state: ConfigFile, who: String, at: int) -> void:
	var seen: Array = state.get_value(who, "bond_beats", [])
	seen.erase(at)
	state.set_value(who, "bond_beats", seen)


static func can_cuddle(state: ConfigFile, bank: Dictionary, who: String, run_id: int) -> bool:
	return has_family(bank) and bond(state, who) >= int(settings(bank)["cuddle_from"]) \
		and int(state.get_value(who, "cuddle_run", -1)) != run_id


static func close(state: ConfigFile, bank: Dictionary, who: String) -> bool:
	return has_family(bank) and bond(state, who) >= int(settings(bank)["close_from"])


# --- Sick days ---------------------------------------------------------------

## Eco comes home sick after run `run_id`? Rolls once per run; `met_mom` is
## whether there's anyone home to look after her yet.
static func roll_sick(state: ConfigFile, run_id: int, won: bool, met_mom: bool, roll: float) -> bool:
	if not met_mom or run_id <= 0 or int(state.get_value(ECO, "sick_rolled", -1)) == run_id:
		return sick(state, run_id)
	state.set_value(ECO, "sick_rolled", run_id)
	var last := int(state.get_value(ECO, "sick_run", -99))
	var first: bool = not won and not state.get_value(ECO, "been_sick", false)
	var catch: bool = first or roll < (SICK_WON if won else SICK_LOST)
	if catch and last != run_id - 1:
		state.set_value(ECO, "sick_run", run_id)
		state.set_value(ECO, "been_sick", true)
	return sick(state, run_id)


## Sick this hub stay, and not looked after yet.
static func sick(state: ConfigFile, run_id: int) -> bool:
	return int(state.get_value(ECO, "sick_run", -99)) == run_id and int(state.get_value(ECO, "cared_run", -1)) != run_id


static func cared_for(state: ConfigFile, run_id: int) -> void:
	state.set_value(ECO, "cared_run", run_id)
