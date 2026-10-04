extends RefCounted
## The real levels, after the tutorial run (the Pinewoods, Blackwater and the
## Boneyard, then the titan fight at the forest's edge).
## A level is one long generated zone (procgen/level_plan.gd make_level) with
## its own name, biome, difficulty and beats: the layout is new every run (the
## run's seed), the beats are always there. It ends in its own titan fight, in
## a clearing at the far end of the same valley, so there is no separate arena.
##
## Spec keys:
##   number, name, biome: what the hub board and the zone toast say.
##   difficulty: the zone index the generator scales by (3 is the first
##     uncharted zone): how many extra sections, squad sizes, loot.
##   lanes: 0 lets the seed pick 3 to 5.
##   must: sections it always has, on top of the outpost, camp, wall and chasm.
##   finale: end in the titan clearing instead of an extraction beacon.
##   threats: let the Choir and wildlife in (threat_spawner.gd).
##   part_bonus: tiers added to the depot's titan part roll (titan_parts.gd).
##   needs: the level (or "tutorial") that has to be cleared first.
##   rescue: who is held in the level's holding block (its "holding"
##     section, holding_cell.gd). The clearing at the end stays shut until
##     they're out, and they leave on the evac with you. rescue_lines is
##     what's said when the cell opens.

const ZoneGenerator := preload("res://scripts/run/procgen/zone_generator.gd")
const LevelPlan := preload("res://scripts/run/procgen/level_plan.gd")

const ORDER := ["level1", "level2"]
const LEVELS := {
	"level1": {
		"number": 1,
		"name": "THE DEEPWOOD",
		"biome": "forest",
		"difficulty": 4,
		"lanes": 0,
		"must": ["depot"],
		"finale": true,
		"threats": false,
		"part_bonus": 2,
		"needs": "tutorial",
		"blurb": "Past the forest's edge the militia run a salvage line out of the deep woods. "
			+ "Their depot has a titan part crated up for the coast. Take it, then deal with the titan they keep on the road.",
	},
	"level2": {
		"number": 2,
		"name": "THE GLASS DISTRICT",
		"biome": "city",
		"difficulty": 5,
		"lanes": 0,
		"must": ["holding"],
		"finale": true,
		"threats": false,
		"part_bonus": 2,
		"needs": "level1",
		"rescue": "ophelia",
		# What they say when the screen drops (rated T both ways).
		"rescue_lines": [
			"OPHELIA: ...You're not one of them.",
			"ECO: Nope! Eco. Hi. I'm the rescue. Surprise.",
			"OPHELIA: Nobody was supposed to come. Nobody even knows I'm gone.",
			"ECO: I knew. Their radio wouldn't shut up about you. Can you run?",
			"OPHELIA: Watch me.",
			"ECO: Evac's past the plaza. Stay low, I'll clear the road. And don't die, it'd ruin my whole night.",
		],
		"blurb": "The colony's radio keeps joking about a girl from town in their holding block downtown. "
			+ "Nobody in town has even noticed she's gone. Ophelia. Get her out, then get her past the titan they park in the plaza.",
	},
}


static func spec(id: String) -> Dictionary:
	return LEVELS.get(id, {})


static func title(id: String) -> String:
	var s := spec(id)
	return "LEVEL %d: %s" % [s["number"], s["name"]] if not s.is_empty() else ""


## Builds level `id` as zone 0 of its run, planned from the run's rng.
static func build(root: Node3D, rng: RandomNumberGenerator, id: String) -> Dictionary:
	var s := spec(id)
	var plan = LevelPlan.make_level(rng.randi_range(1, 2147483646), s)
	var info := ZoneGenerator.build_from_plan(root, plan, int(s["difficulty"]))
	info["level"] = id
	return info


## Whether level `id` is open, given what has been cleared ("tutorial",
## "level1", ...).
static func unlocked(id: String, cleared: Array) -> bool:
	var need: String = spec(id).get("needs", "")
	return need == "" or need in cleared
