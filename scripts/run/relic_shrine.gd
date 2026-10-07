extends Node3D
## A Precursor reliquary that sometimes stands in a zone (relics.gd
## SHRINE_CHANCE): a carved stone plinth with a relic floating over it in the
## eye's glow. F takes the relic home. It sits in info["loot"] like a crate,
## so the run manager's loot tick opens it; the manager reads `relic` after.

const Relics := preload("res://scripts/hub/relics.gd")
const Loot := preload("res://scripts/run/loot.gd")
const Kit := preload("res://scripts/hub/hub_kit.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")
const SFX := preload("res://scripts/sfx.gd")
const FX := preload("res://scripts/fx.gd")

const INTERACT_RANGE := 2.6
const EYE := Color(0.35, 1.0, 0.85)

## The relic on it (a Precursor one from relics.gd).
var relic := ""
var kill_y := -100.0
var opened := false
var _gem: Node3D
var _light: OmniLight3D
var _age := 0.0
var _settled := false


## Places a shrine in a built zone, maybe (after Loot.scatter: keeps clear of
## the crates). Returns it, or null.
static func scatter(root: Node3D, info: Dictionary, rng: RandomNumberGenerator) -> Node3D:
	var missing := Relics.missing("precursor")
	if missing.is_empty() or rng.randf() >= Relics.SHRINE_CHANCE:
		return null
	var spawn: Vector3 = info["spawn"]
	var taken: Array = []
	for node in info.get("loot", []):
		if is_instance_valid(node):  # a crate over a drop frees itself
			taken.append(node.position)
	# the zone's chasms and buildings, where loot can't go (loot.gd)
	var keep_out: Array = info.get("loot_keep_out", [])
	for spot: Vector3 in Loot._candidates(info, rng):
		if spot.distance_to(spawn) < Loot.SPAWN_CLEAR * 2.0 or taken.any(func(t): return t.distance_to(spot) < 6.0):
			continue
		if keep_out.any(func(r): return (r as Rect2).has_point(Vector2(spot.x, spot.z))):
			continue
		var s: Node3D = load("res://scripts/run/relic_shrine.gd").new()
		s.relic = missing[rng.randi() % missing.size()]
		s.kill_y = float(info.get("kill_y", float(info["floor_y"]) - 15.0))
		root.add_child(s)
		s.position = spot
		s.rotation.y = rng.randf() * TAU
		info["loot"].append(s)
		return s
	return null


func _ready() -> void:
	var stone := Art.material("temple_stone")
	Kit.mesh(self, Vector3(0, 0.15, 0), Vector3(1.3, 0.3, 1.3), stone)
	Kit.mesh(self, Vector3(0, 0.75, 0), Vector3(0.7, 0.9, 0.7), stone)
	Kit.mesh(self, Vector3(0, 1.25, 0), Vector3(1.0, 0.12, 1.0), stone)
	# the eye glyph carved on each face, still glowing
	for i in 4:
		var a := i * PI / 2.0
		var n := Vector3(sin(a), 0, cos(a))
		Kit.glow(self, n * 0.36 + Vector3(0, 0.8, 0), Vector3(0.28, 0.12, 0.02), EYE.darkened(0.2), Vector3(0, rad_to_deg(a), 0))
	_gem = Node3D.new()
	_gem.position.y = 1.7
	add_child(_gem)
	Kit.glow(_gem, Vector3.ZERO, Vector3(0.22, 0.32, 0.22), EYE, Vector3(0, 45, 30))
	Kit.glow(_gem, Vector3.ZERO, Vector3(0.12, 0.42, 0.12), Color(0.9, 1.0, 0.95), Vector3(0, 0, -20))
	_light = OmniLight3D.new()
	_light.light_color = EYE
	_light.light_energy = 2.2
	_light.omni_range = 6.0
	_light.position.y = 1.8
	add_child(_light)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	col.shape = BoxShape3D.new()
	col.shape.size = Vector3(1.3, 1.3, 1.3)
	col.position.y = 0.65
	body.add_child(col)
	add_child(body)


func _physics_process(delta: float) -> void:
	_age += delta
	if not _settled:
		_settled = true
		var exclude := []
		for child in get_children():
			if child is StaticBody3D:
				exclude.append(child.get_rid())
		var at = Loot.LootArt.ground_under(get_world_3d(), global_position, kill_y, exclude)
		if at == null:
			queue_free()
			return
		global_position = at
	if _gem.visible:
		_gem.position.y = 1.7 + sin(_age * 1.8) * 0.08
		_gem.rotation.y += delta * 0.9
		_light.light_energy = 2.0 + sin(_age * 2.6) * 0.5


func in_range(pos: Vector3) -> bool:
	return not opened and global_position.distance_to(pos) < INTERACT_RANGE


func prompt() -> String:
	return "[F] Take the Precursor relic"


## Takes the relic off the plinth. No materials: the manager reads `relic`.
func open() -> Dictionary:
	if opened:
		return {}
	opened = true
	_gem.visible = false
	_light.light_energy = 0.4
	SFX.play_at(get_parent(), global_position, "titan_hiss_short", -6.0, 0.6)
	FX.puff(get_parent(), global_position + Vector3(0, 1.7, 0), Color(EYE, 0.6), 0.3, 0.8)
	return {}
