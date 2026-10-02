extends RefCounted
## Everything one run carries between zones. Seeded, so a run can be replayed.

const TitanParts := preload("res://scripts/run/titan_parts.gd")

const ZONE_COUNT := 3
const PILOT_MAX := 100

var run_seed := 0
var rng := RandomNumberGenerator.new()
var zone := 0
## slot -> part dictionary, see titan_parts.gd
var parts := {}
var pilot_hp := PILOT_MAX
var falls := 0
var downs := 0
var caches_opened := 0
var time := 0.0
## Refit multipliers from the hub's titan workshop ("slot:id" -> factor).
var refits := {}
## Grunts the pilot dropped this run.
var kills := 0
## Materials picked up this run (scrap, alloy, circuits), banked when it ends.
var materials := {"scrap": 0, "alloy": 0, "circuits": 0}


func _init(seed_value: int) -> void:
	run_seed = seed_value
	rng.seed = seed_value


func install(part: Dictionary) -> void:
	parts[part["slot"]] = part


func titan_stats() -> Dictionary:
	return TitanParts.assemble(parts, refits)
