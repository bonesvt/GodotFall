extends Node
## The people of Solace going about their day (townsperson.gd), and what
## they say: two of them chatting where Eco can overhear, someone muttering
## to themselves as they pass, a word for Eco herself when she walks by.
## The lines live in dialogue/town/T.txt and M.txt (Teen and Mature, the O
## key's rating; see dialogue/README.md), by how far the town's suspicion has
## got: stage 1 (her first runs) still believes Mom's excuses, stage 2 has
## noticed things, stage 3 is sure she's up to something.
##
## run_manager.gd's enter_hub() calls populate() once the hub (and the town
## in it, town.gd) is built.

const Townsperson := preload("res://scripts/hub/townsperson.gd")
const DialogueBank := preload("res://scripts/radio/dialogue_bank.gd")
const RadioLines := preload("res://scripts/radio/radio_lines.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")
const Glass := preload("res://scripts/hub/glass.gd")

## Marrow's Chorus (glass.gd, Mature only): who he doses first, as it spreads.
## The dosed walk slower, violet spirals in their eyes, and say his kind of
## thing in a flat, pleasant voice; the others worry about them.
const DOSE_ORDER := ["kit", "dez", "harl", "wren", "pell", "bram", "mira", "jun", "tobin", "rosa"]
const DOSED_SLOW := 0.65
const CHORUS_LINES := [
	"Quiet today. Isn't it nice when it's quiet.",
	"I don't need to worry. Someone's taking care of it.",
	"Everything's fine. Everything's going to be fine.",
	"Sleep well, Eco. We all sleep so well now.",
	"No need to fight. No need to fight anything.",
	"Have you tried the water lately? It tastes like violets.",
]
const WORRY_LINES := [
	"You've gone quiet lately. You used to never stop talking.",
	"Your eyes look funny in this light. Are you sleeping?",
	"Since when do you smile at the soldiers?",
	"Hey. Hey. Are you even listening to me?",
]

## Everyone, where they are and what they're doing. Positions are on the
## town's ground (town.gd: the street runs along x = 0, Sun Plaza is z 160..190
## round the Sun Tree at z 175, Low Row z 190..214). Pairs ("with") chat.
## Walkers: route points, the points they pause at (index: seconds, 0 = the
## usual), and their pace.
const PEOPLE := [
	# Old Tobin and Rosa on the bench by the job board, watching the plaza
	{"who": "tobin", "mode": "sit", "pos": Vector3(-11.45, 0, 166.55), "yaw": -90.0, "with": "rosa"},
	{"who": "rosa", "mode": "sit", "pos": Vector3(-11.45, 0, 165.45), "yaw": -90.0},
	# Auntie Pell behind the counter of her stall (town.gd's amber market stall
	# at (7, 162.5)), Bram in front of it buying
	{"who": "pell", "mode": "stand", "pos": Vector3(7.0, 0, 161.05), "yaw": 180.0, "with": "bram"},
	{"who": "bram", "mode": "stand", "pos": Vector3(6.3, 0, 164.5), "yaw": 0.0},
	# Mira and Jun with their ice cream by Scoops
	{"who": "mira", "mode": "stand", "pos": Vector3(-12.6, 0, 182.6), "yaw": 60.0, "with": "jun"},
	{"who": "jun", "mode": "stand", "pos": Vector3(-11.2, 0, 183.6), "yaw": -120.0},
	# Kit the courier, gate to Low Row and back, dropping things off
	{"who": "kit", "mode": "walk", "speed": 1.55, "route": [Vector3(-2.0, 0, 131.0), Vector3(-2.2, 0, 146.0),
			Vector3(-2.5, 0, 159.0), Vector3(-9.0, 0, 168.5), Vector3(-9.5, 0, 181.0), Vector3(-2.0, 0, 192.0), Vector3(-1.5, 0, 210.0)],
			"pauses": {1: 3.0, 4: 2.5, 6: 4.0}},
	# Wren, round the Sun Tree from the greenhouse and back
	{"who": "wren", "mode": "walk", "speed": 1.0, "route": [Vector3(16.0, 0, 171.0), Vector3(10.5, 0, 172.0),
			Vector3(9.5, 0, 179.0), Vector3(3.5, 0, 185.0), Vector3(-4.0, 0, 185.5), Vector3(-9.0, 0, 178.0)],
			"pauses": {0: 5.0, 3: 0.0, 5: 4.0}},
	# Dez up and down Lantern Row, between Sal's and the noodle stall
	{"who": "dez", "mode": "walk", "speed": 1.15, "route": [Vector3(3.0, 0, 157.5), Vector3(3.6, 0, 150.0),
			Vector3(3.8, 0, 142.0), Vector3(2.5, 0, 135.0)], "pauses": {0: 4.0, 2: 5.0}},
	# Harl from the bar end of Low Row to the job board and back
	{"who": "harl", "mode": "walk", "speed": 1.05, "route": [Vector3(2.0, 0, 211.0), Vector3(2.5, 0, 198.0),
			Vector3(1.0, 0, 191.0), Vector3(-4.0, 0, 167.0), Vector3(-6.5, 0, 165.2)], "pauses": {0: 4.0, 4: 6.0}},
]

## How near Eco must be to overhear a chat (m).
const EARSHOT := 14.0
## How near she passes for someone to speak to her.
const GREET_RANGE := 3.6
## Seconds between one line and the next in a chat.
const GAP := 0.7
## Quiet (s) between chats, and between remarks to Eco.
const CHAT_REST := Vector2(5.0, 11.0)
const GREET_REST := 9.0

var people := {}   # short name -> Townsperson
var pilot: Node3D
var stage := 1

var _rng := RandomNumberGenerator.new()
var _chat: Array = []      # the lines left: [[Townsperson, text], ...]
var _line_left := 0.0
var _speaker: Node3D
var _chat_rest := 3.0
var _greet_rest := 2.0
var _greeted := {}
var _used := {}            # category -> indices played since it last ran dry
## The townsfolk Marrow has dosed (short name -> true).
var dosed := {}


## Spawns the townsfolk under `root` (the hub's zone root) once the hub is
## built. `runs` is how many runs Eco has finished (the town's suspicion).
static func populate(root: Node, p_pilot: Node3D, runs: int) -> Node:
	if root.get_node_or_null("Town") == null:
		return null
	var folk: Node = load("res://scripts/hub/townsfolk.gd").new()
	folk.name = "Townsfolk"
	folk.pilot = p_pilot
	folk.stage = stage_for(runs)
	root.add_child(folk)
	return folk


## Suspicion grows over act 1: the first two runs, the next three, then the rest.
static func stage_for(runs: int) -> int:
	if runs < 2:
		return 1
	return 2 if runs < 5 else 3


func _ready() -> void:
	_rng.randomize()
	for spec: Dictionary in PEOPLE:
		var route: Array = spec.get("route", [])
		var at: Vector3 = route[0] if not route.is_empty() else spec["pos"]
		var p := Townsperson.create_town(spec["who"], at, spec.get("yaw", 0.0), spec["mode"])
		p.route = route
		p.pauses = spec.get("pauses", {})
		p.speed = spec.get("speed", 1.1)
		p.pilot = pilot
		add_child(p)
		people[spec["who"]] = p
	for spec: Dictionary in PEOPLE:
		if spec.has("with"):
			people[spec["who"]].partner = people[spec["with"]]
			people[spec["with"]].partner = people[spec["who"]]
	chorus_refresh()


## Doses (or frees) the townsfolk as far as the Chorus has got (glass.gd).
func chorus_refresh() -> void:
	var n := Glass.dosed_folk()
	for i in DOSE_ORDER.size():
		var who: String = DOSE_ORDER[i]
		if people.has(who):
			_set_dosed(who, i < n)


func _set_dosed(who: String, on: bool) -> void:
	if dosed.has(who) == on:
		return
	var p: Node3D = people[who]
	if on:
		dosed[who] = true
		p.set_meta("base_speed", p.speed)
		p.speed *= DOSED_SLOW
	else:
		dosed.erase(who)
		p.speed = p.get_meta("base_speed", p.speed)
	for mi: MeshInstance3D in p.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i) as ShaderMaterial
			if m == null or not m.resource_name.ends_with("_iris"):
				continue
			var mine := mi.get_surface_override_material(i) as ShaderMaterial
			if mine == null:
				mine = m.duplicate()
				mi.set_surface_override_material(i, mine)
			mine.set_shader_parameter("iris_swirl", on)
			mi.set_instance_shader_parameter("hypno", 0.85 if on else 0.0)


## {category: [entries]} at the current rating.
func bank() -> Dictionary:
	return DialogueBank.bank("town", ContentRating.current())


## The entries for a kind of line ("chat", "mutter", "greet") at this stage,
## falling back to earlier stages' if this one has none.
func entries(kind: String) -> Array:
	var b := bank()
	for s in range(stage, 0, -1):
		var key := "%s_%d" % [kind, s]
		if b.has(key):
			return b[key]
	return []


func talking() -> bool:
	return not _chat.is_empty() or _speaker != null


## A scene's on (rescue_event.gd): nobody in town talks over it.
static var hush := false


func _process(delta: float) -> void:
	if hush:
		if _speaker != null:
			_speaker.done_talking()
			_speaker = null
		_chat.clear()
		_line_left = GAP
		for p in people.values():  # and any line still up over their heads goes
			var cap = p.get_node_or_null("Caption")
			if cap != null:
				cap.visible = false
		return
	if _speaker != null:
		_line_left -= delta
		if _line_left <= 0.0:
			_speaker.done_talking()
			_speaker = null
			_line_left = GAP
		return
	if not _chat.is_empty():
		_line_left -= delta
		if _line_left <= 0.0:
			_say_next()
		return
	if pilot == null or not is_instance_valid(pilot):
		return
	_greet_rest -= delta
	_chat_rest -= delta
	if _greet_rest <= 0.0 and _try_greet():
		return
	if _chat_rest <= 0.0:
		if not _try_chat():
			_try_mutter()
		_chat_rest = _rng.randf_range(CHAT_REST.x, CHAT_REST.y)


## Someone close to Eco has a word for her, once per visit each.
func _try_greet() -> bool:
	for n: String in people:
		var p: Node3D = people[n]
		if _greeted.has(n) or p.talking or _near(p) > GREET_RANGE:
			continue
		_greeted[n] = true
		var line := _pick("greet")
		if line == "":
			return false
		p.hold(4.0)
		if dosed.has(n):
			_chat = [[p, _chorus_line()]]
			_say_next()
			_greet_rest = GREET_REST
			return true
		_chat = [[p, RadioLines.parse(line)[0][1]]]
		_say_next()
		_greet_rest = GREET_REST
		return true
	return false


## Two people standing or sitting together where Eco can overhear.
func _try_chat() -> bool:
	var pairs := []
	for n: String in people:
		var p: Node3D = people[n]
		if p.partner != null and n < p.partner.short_name() and _near(p) < EARSHOT:
			pairs.append([p, p.partner])
	if pairs.is_empty():
		return false
	var pair: Array = pairs[_rng.randi() % pairs.size()]
	var a_dosed := dosed.has(pair[0].short_name())
	var b_dosed := dosed.has(pair[1].short_name())
	if a_dosed or b_dosed:
		# one of them is his: the other worries, or both just agree how quiet it is
		if a_dosed and b_dosed:
			_chat = [[pair[0], _chorus_line()], [pair[1], _chorus_line()]]
		else:
			var calm: Node3D = pair[0] if a_dosed else pair[1]
			var other: Node3D = pair[1] if a_dosed else pair[0]
			_chat = [[other, WORRY_LINES[_rng.randi() % WORRY_LINES.size()]], [calm, _chorus_line()]]
		_say_next()
		return true
	var entry := _pick("chat")
	if entry == "":
		return false
	_chat = []
	for line in RadioLines.parse(entry):
		_chat.append([pair[0] if line[0] == "a" else pair[1], line[1]])
	_say_next()
	return true


## A walker near Eco says something to nobody in particular.
func _try_mutter() -> bool:
	var near := []
	for n: String in people:
		var p: Node3D = people[n]
		if p.partner == null and _near(p) < EARSHOT * 0.7:
			near.append(p)
	if near.is_empty():
		return false
	var who: Node3D = near[_rng.randi() % near.size()]
	if dosed.has(who.short_name()):
		_chat = [[who, _chorus_line()]]
		_say_next()
		return true
	var entry := _pick("mutter")
	if entry == "":
		return false
	_chat = [[who, RadioLines.parse(entry)[0][1]]]
	_say_next()
	return true


func _chorus_line() -> String:
	return CHORUS_LINES[_rng.randi() % CHORUS_LINES.size()]


func _say_next() -> void:
	var line: Array = _chat.pop_front()
	_speaker = line[0]
	_line_left = _speaker.say_line(line[1]) + 0.4


func _near(p: Node3D) -> float:
	return p.global_position.distance_to(pilot.global_position)


## A line of a kind not heard since the list last ran dry.
func _pick(kind: String) -> String:
	var list := entries(kind)
	if list.is_empty():
		return ""
	var key := "%s/%s/%d" % [ContentRating.current(), kind, stage]
	var used: Array = _used.get(key, [])
	if used.size() >= list.size():
		used = []
	var fresh := []
	for i in list.size():
		if not used.has(i):
			fresh.append(i)
	var i: int = fresh[_rng.randi() % fresh.size()]
	used.append(i)
	_used[key] = used
	return list[i]
