extends SceneTree
## Headless test for the Choir and the wildlife past the border
## (scripts/threats/): every model loads with its moving parts, each unit and
## creature does its thing against the pilot, and the spawner swaps a zone's
## grunts for the Choir and adds wildlife.
## Run: godot --headless --path . -s res://tests/threats_test.gd

const Spawner := preload("res://scripts/threats/threat_spawner.gd")
const Grunt := preload("res://scripts/grunt.gd")
const ZoneBuilder := preload("res://scripts/run/zone_builder.gd")

var level
var player
var failures := 0
var spawned: Array = []
var info := {}

const SPOT := Vector3(-40, 0.1, 20)
const PARTS := {
	"hush": ["LegL", "KneeR", "Torso", "Head"], "hound": ["FrontL", "HindR", "Head", "Tail"],
	"cantor": ["LegR", "KneeL", "Torso"], "seraph": ["Ring", "Ring2", "Tail"],
	"glassback": ["LegL1", "LegR3", "Head", "Tail"], "lampjaw": ["Jaw", "Lure"],
	"quillcat": ["Frill", "Head", "FrontR"], "picker": ["Body"], "veilray": ["WingL", "WingR"],
}


func _initialize() -> void:
	level = load("res://scenes/test_level.tscn").instantiate()
	root.add_child(level)
	_run.call_deferred()


func _run() -> void:
	await _ticks(30)
	player = root.get_node("TestLevel/Player")

	# Every model: toon materials, ink, and the pivots its puppet moves.
	for name in PARTS:
		var m: Node3D = load("res://assets/models/threats/%s.glb" % name).instantiate()
		var missing: Array = PARTS[name].filter(func(p): return m.find_child(p, true, false) == null)
		var ink := m.find_children("Ink", "MeshInstance3D", true, false).size()
		_check("%s model has its parts and ink lines" % name, missing.is_empty() and ink > 0, [missing, ink])
		m.free()

	# HUSH: unaware at first; alerted, it works round to the pilot's side and shoots.
	_place(SPOT)
	var h = _spawn("hush", Vector3(-24, 0, 0), Vector3(1, 0, 0))
	await _ticks(10)
	_check("a Hush starts unaware with its tell dark", h.is_unaware() and h.model.tell == 0.0, h.awareness)
	var start: Vector3 = h.global_position
	var hp: float = player.health
	h.alert()
	await _seconds(6.0)
	var side := absf((h.global_position - SPOT).normalized().z)
	_check("an alerted Hush flanks instead of charging", side > 0.35 and h.global_position.distance_to(SPOT) > 12.0,
			[h.global_position, start])
	for i in 12 * Engine.physics_ticks_per_second:  # a few shots: some miss
		if player.health < hp:
			break
		await physics_frame
	_check("the Hush's needle rifle hits hard", player.health <= hp - h.damage * 0.5, [hp, player.health])
	_check("the Choir stays off the colony radio", h.on_radio == false and h.is_in_group("choir"), h.on_radio)
	var hit_head: bool = h.is_headshot(h.global_position + Vector3.UP * 2.1)
	_check("Hush headshots land on the mask", hit_head and not h.is_headshot(h.global_position + Vector3.UP * 1.2), hit_head)
	_clear()

	# HOUND: eyeless. A still pilot in front of it isn't noticed; a gunshot is
	# heard from far off and it goes to look; up close it pounces.
	_place(SPOT)
	var hd = _spawn("hound", Vector3(-9, 0, 0), Vector3(1, 0, 0))
	await _seconds(3.0)
	_check("a Hound can't see a still pilot in front of it", hd.detection < 0.02, hd.detection)
	hd.global_position = SPOT + Vector3(-34, -0.1, 0)
	hd.hear_gunshot(SPOT + Vector3(-4, 0, 0))
	await _ticks(2)
	_check("a Hound hears a gunshot 30 m off", hd.awareness == Grunt.Awareness.SUSPICIOUS, hd.awareness)
	var far: float = hd.global_position.distance_to(SPOT)
	await _seconds(3.0)
	_check("a Hound goes to where it heard the noise", hd.global_position.distance_to(SPOT) < far - 4.0,
			[far, hd.global_position.distance_to(SPOT)])
	hd.global_position = SPOT + Vector3(-3.5, -0.1, 0)
	hd.alert()
	hp = player.health
	await _seconds(2.5)
	_check("an alerted Hound pounces", player.health < hp, [hp, player.health])
	_clear()

	# CANTOR: the shield stops shots from the front, the back takes more, and
	# its sonic blast hurts and throws the pilot.
	_place(SPOT)
	player.health = player.max_health
	var c = _spawn("cantor", Vector3(-10, 0, 0), Vector3(1, 0, 0))
	await _ticks(5)
	var front: bool = c.take_damage(50.0, c.global_position + Vector3(2.0, 1.5, 0), false)
	_check("the Cantor's shield stops a shot from the front", not front and c.health == c.max_health, c.health)
	c.alert()
	var before: float = c.health
	c.take_damage(50.0, c.global_position + Vector3(-1.0, 1.5, 0), false)
	_check("hits in the Cantor's back land harder", before - c.health > 50.0 * 1.4, before - c.health)
	c.fire_timer = 0.1
	hp = player.health
	await _seconds(2.0)
	_check("the Cantor's sonic blast hurts and throws the pilot", player.health < hp and player.velocity.length() > 3.0,
			[hp, player.health, player.velocity])
	_clear()

	# SERAPH: sees the pilot and its song alerts the Choir nearby, even one
	# looking the other way.
	_place(SPOT)
	var s = _spawn("seraph", Vector3(-12, 0, 0), Vector3(1, 0, 0))
	var deaf = _spawn("hush", Vector3(-30, 0, 8), Vector3(-1, 0, 0))
	await _seconds(4.0)
	_check("a Seraph spots the pilot", s.alerted, s.detection)
	_check("its song alerts Choir units that couldn't see her", deaf.alerted, deaf.awareness)
	_check("a Seraph never shoots", player.health == player.max_health or player.health > player.max_health - deaf.damage * 2.0, player.health)
	var eye: Vector3 = s.global_position + Vector3.UP * s.EYE_HEIGHT - s.global_basis.z * 0.1
	_check("a shot to the Seraph's eye is a headshot", s.is_headshot(eye), eye)
	_clear()

	# GLASSBACK: grazes until a gunshot spooks it, then stampedes away.
	_place(SPOT)
	var gb = _spawn("glassback", Vector3(-25, 0, 0), Vector3(0, 0, 1))
	await _seconds(1.0)
	_check("a Glassback grazes calmly", gb.state == gb.State.GRAZE and not gb.alerted, gb.state)
	var gb_from: float = gb.global_position.distance_to(SPOT)
	gb.hear_gunshot(SPOT)
	await _seconds(2.0)
	_check("a gunshot stampedes the Glassback away from it",
			gb.state == gb.State.STAMPEDE and gb.global_position.distance_to(SPOT) > gb_from + 4.0 and gb.model.tell > 0.8,
			[gb.state, gb_from, gb.global_position.distance_to(SPOT)])
	_clear()

	# LAMPJAW: walk up to it and it bites.
	_place(SPOT)
	player.health = player.max_health
	var lj = _spawn("lampjaw", Vector3(-3.5, 0, 0), Vector3(1, 0, 0))
	hp = player.health
	await _seconds(1.5)
	_check("a Lampjaw lunges and bites hard", player.health <= hp - 30.0 or player.health <= 1.0, [hp, player.health])
	_clear()

	# QUILLCATS: the pack wakes together, circles, and one commits after its frill flares.
	_place(SPOT)
	player.health = player.max_health
	var cat = _spawn("quillcat_pack", Vector3(-14, 0, 0), Vector3(1, 0, 0))
	await _ticks(5)
	_check("unaware Quillcats can be knifed", cat.is_unaware(), cat.state)
	cat.rouse()
	var stalking: bool = cat.pack.all(func(q): return q.state != q.State.ROAM)
	_check("the whole Quillcat pack turns on the pilot", stalking, cat.pack.map(func(q): return q.state))
	var flared := false
	hp = player.health
	for i in 600:
		await physics_frame
		for q in cat.pack:
			if q.state == q.State.TELL and q.model.open > 0.5:
				flared = true
		if player.health < hp:
			break
	_check("a Quillcat's frill flares before it pounces", flared, flared)
	_check("a Quillcat pounce lands", player.health < hp, [hp, player.health])
	_clear()

	# BONEPICKERS: a swarm close by turns on the pilot; a lone one runs.
	_place(SPOT)
	player.health = player.max_health
	var pk = _spawn("bonepickers", Vector3(-3, 0, 0), Vector3(1, 0, 0))
	hp = player.health
	await _seconds(3.0)
	_check("a Bonepicker swarm nibbles the pilot", player.health < hp, [hp, player.health])
	var members: Array = pk.swarm["members"]
	for m in members.slice(1):
		m.global_position += Vector3(-40, 0, 0)
	pk.state = pk.State.FORAGE
	pk.global_position = SPOT + Vector3(-3, 0, 0)
	await _seconds(0.5)
	_check("a lone Bonepicker runs from the pilot", pk.state == pk.State.FLEE, pk.state)
	_clear()

	# VEIL RAYS: harmless overhead, scatter when a fight starts below.
	_place(SPOT)
	await _ticks(2)  # let the last test's bodies go
	var ray = _spawn("veil_rays", Vector3(-5, -26, 0), Vector3(1, 0, 0))
	var sentry = _spawn("hush", Vector3(-20, 0, 0), Vector3(-1, 0, 0))
	await _seconds(1.0)
	_check("Veil Rays glide calmly", ray._scatter <= 0.0 and not ray.is_in_group("enemies"), ray._scatter)
	sentry.alert()
	await _seconds(1.0)
	_check("Veil Rays scatter when a fight starts", ray.flock.all(func(r): return r._scatter > 0.0), ray.flock.size())
	_clear()

	# The spawner: past the border a zone's grunts become the Choir (cache
	# guards too, still counted by their objective) and wildlife moves in.
	var zone := Node3D.new()
	root.add_child(zone)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var zinfo: Dictionary = ZoneBuilder.build_chain(zone, rng, 3)
	var colony: Array = zinfo["grunts"].filter(func(g): return g.get_script() == Grunt)
	var choir: Array = zinfo["grunts"].filter(func(g): return g.is_in_group("choir"))
	_check("no colony grunts past the border", colony.is_empty() and not choir.is_empty(), [colony.size(), choir.size()])
	var guards_ok := true
	for o in zinfo["objectives"]:
		for g in o.grunts:
			guards_ok = guards_ok and is_instance_valid(g) and g.is_in_group("choir")
	_check("cache guards are Choir and still counted", guards_ok and not zinfo["objectives"].is_empty(), guards_ok)
	_check("wildlife moves into the zone", not zinfo["wildlife"].is_empty(), zinfo["wildlife"].size())
	for o in zinfo["objectives"]:
		for g in o.grunts.duplicate():
			g.take_damage(9999.0, g.global_position, false)
	await _ticks(2)
	_check("clearing a Choir squad opens its cache", zinfo["objectives"].all(func(o): return o.done), zinfo["objectives"].map(func(o): return o.done))
	zone.queue_free()
	var home := Node3D.new()
	root.add_child(home)
	var hinfo: Dictionary = ZoneBuilder.build_chain(home, rng, 2)
	_check("before the border it's still the colony", hinfo["grunts"].all(func(g): return g.get_script() == Grunt) and not hinfo.has("wildlife"), hinfo.keys())
	home.queue_free()
	_check("the spawn table knows the generator's sections",
			not Spawner.table("field", 0, rng).is_empty() and not Spawner.table("sky", 0, rng).is_empty()
			and Spawner.table("resource", 0, rng).has("bonepickers"), "")

	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(failures)


func _spawn(kind: String, offset: Vector3, facing: Vector3):
	var n = Spawner.spawn(kind, level, info, player.global_position + offset - Vector3(0, 0.1, 0), facing)
	if n.get("target") != null or "target" in n:
		for m in _group_of(n):
			m.target = player
			spawned.append(m)
	return n


func _group_of(n) -> Array:
	if "pack" in n and not n.pack.is_empty():
		return n.pack
	if "swarm" in n and not n.swarm.is_empty():
		return n.swarm["members"]
	if "flock" in n and not n.flock.is_empty():
		return n.flock
	return [n]


func _clear() -> void:
	for g in spawned:
		if is_instance_valid(g):
			g.queue_free()
	spawned.clear()


func _place(pos: Vector3) -> void:
	for a in ["move_forward", "crouch", "jump", "grapple", "fire"]:
		Input.action_release(a)
	player.global_position = pos
	player.rotation.y = PI / 2.0  # facing -X
	player.get_node("Head").rotation.x = 0.0
	player.velocity = Vector3.ZERO
	player.health = player.max_health


func _seconds(s: float) -> void:
	await _ticks(int(s * Engine.physics_ticks_per_second))


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _check(what: String, ok: bool, value) -> void:
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", what, str(value)])
	if not ok:
		failures += 1
