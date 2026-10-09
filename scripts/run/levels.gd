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
##     they're out. rescue_lines is what's said when the cell opens.
##   holding_last: the holding block is the last stop, at the far end.
##   exfil: "spawn" puts the way out (the extraction beacon) back where you
##     came in, instead of past the far end.
##   night: dark streets, grunts with torches who see less far (biome.night).

const ZoneGenerator := preload("res://scripts/run/procgen/zone_generator.gd")
const LevelPlan := preload("res://scripts/run/procgen/level_plan.gd")
const Biome := preload("res://scripts/run/procgen/biome.gd")

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
		"blurb": "Past the forest's edge the colony runs a salvage line out of the deep woods. "
			+ "Their depot has a titan part crated up for the coast. Take it, then deal with the titan they keep on the road.",
	},
	"level2": {
		"number": 2,
		"name": "THE GLASS DISTRICT",
		"biome": "city",
		"difficulty": 5,
		"lanes": 0,
		"must": ["holding"],
		"holding_last": true,
		"finale": false,
		"exfil": "spawn",
		"night": true,
		"threats": false,
		"part_bonus": 2,
		"needs": "level1",
		"rescue": "ophelia",
		# What they say when the screen drops and the visor comes off her.
		"rescue_lines": [
			"OPHELIA: ...Why'd the light go off? I was doing so well.",
			"ECO: Doing so well at what? Hold still. This thing's coming off your face.",
			"OPHELIA: Eco? What are you doing here? They only grabbed me last night.",
			"ECO: Last night? Ophelia, you've been gone nineteen days.",
			"OPHELIA: No. The light came on, and a nice voice said I was doing so well, and then you were... Nineteen days?",
			"ECO: Later. The thing on your wrist won't budge. Biggie can get it off. Can you walk?",
			"OPHELIA: Barefoot, through their city, in the dark? Sure. Love that for me.",
			"ECO: Stay close. I crouch, you crouch. We go out the way I came in.",
		],
		"blurb": "The colony's radio keeps talking about a girl from town in Trial Bay 7 downtown, and her numbers. "
			+ "Nobody in town has even noticed she's gone. Ophelia. Go in at night, get her out of whatever they've put on her, and get her back out the way you came without waking the district.",
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
	if s.get("night", false):
		Biome.night(root, info)
	return info


## Whether level `id` is open, given what has been cleared ("tutorial",
## "level1", ...).
static func unlocked(id: String, cleared: Array) -> bool:
	var need: String = spec(id).get("needs", "")
	return need == "" or need in cleared
