extends RefCounted
## Puts the Choir and the wildlife into the zones past the border (zone index
## 3 and up: the uncharted zones). The level generator calls populate() once a
## zone is laid out (procgen/zone_generator.gd), and so does the old platform
## chain (zone_builder.gd build_chain).
##
## Past the border the militia is gone: every grunt the zone placed becomes a
## Choir unit on the same spot, with the same post, leash, facing and patrol
## (Hush mostly, Hounds on the patrol loops, the odd Cantor dug in). Then
## spawn_hooks (the generator's {pos, section, facing} spots) get creatures
## from table(): Glassback herds and Quillcat packs on open fields,
## Bonepicker swarms round resource sites, Lampjaws in the marsh gullies,
## Seraph spotters and Veil Ray flocks in the sky over the yards.
##
## Choir units go in info["grunts"], so the run wires their target and loot
## like any grunt's. Wildlife goes in info["wildlife"] and finds Eco itself.

const Hush := preload("res://scripts/threats/hush.gd")
const Hound := preload("res://scripts/threats/hound.gd")
const Cantor := preload("res://scripts/threats/cantor.gd")
const Seraph := preload("res://scripts/threats/seraph.gd")
const Glassback := preload("res://scripts/threats/glassback.gd")
const Lampjaw := preload("res://scripts/threats/lampjaw.gd")
const Quillcat := preload("res://scripts/threats/quillcat.gd")
const Bonepicker := preload("res://scripts/threats/bonepicker.gd")
const VeilRay := preload("res://scripts/threats/veil_ray.gd")
const GruntScript := preload("res://scripts/grunt.gd")

## First zone past the border.
const FIRST_ZONE := 3
const CHOIR := ["hush", "hound", "cantor", "seraph"]
const KINDS := ["hush", "hound", "cantor", "seraph", "glassback", "lampjaw", "quillcat_pack",
		"bonepickers", "veil_rays"]
## Most of each kind per zone (the rest of a table roll is dropped).
const CAPS := {"cantor": 2, "lampjaw": 3, "glassback": 4, "quillcat_pack": 2, "bonepickers": 2,
		"veil_rays": 2, "seraph": 3}


## Fills a laid-out zone. Does nothing before the border.
static func populate(root: Node3D, rng: RandomNumberGenerator, info: Dictionary, zone_index: int) -> void:
	if zone_index < FIRST_ZONE:
		return
	var depth := zone_index - FIRST_ZONE
	info["wildlife"] = info.get("wildlife", [])
	info["threat_counts"] = {}
	_convert_grunts(root, rng, info, zone_index)
	var hooks: Array = info.get("spawn_hooks", [])
	if hooks.is_empty():
		hooks = _hooks_from_platforms(info)
	for h in hooks:
		var section: String = h.get("kind", h.get("section", ""))
		var kinds: Array = [section] if section in KINDS else table(section, depth, rng)
		for kind in kinds:
			var counts: Dictionary = info["threat_counts"]
			if counts.get(kind, 0) >= CAPS.get(kind, 99):
				continue
			var pos: Vector3 = h["pos"]
			if section == "sky" and kind == "seraph":
				pos.y -= 11.0  # the sky hook is 18 m up; a Seraph hangs at about 7
			spawn(kind, root, info, pos, h.get("facing", Vector3(0, 0, 1)), zone_index, rng)
	_feed_swarms(info)


## What to put on a spawn hook, by the section it marks and how far past the
## border the zone is (depth 0 is the first uncharted zone).
static func table(section: String, depth: int, rng: RandomNumberGenerator) -> Array:
	match section:
		"field":
			if rng.randf() < 0.35 + 0.15 * depth:
				return ["quillcat_pack"]
			return ["glassback"] if rng.randf() < 0.6 else ["glassback", "glassback"]
		"resource":
			if depth >= 1 and rng.randf() < 0.3:
				return ["bonepickers", "quillcat_pack"]
			return ["bonepickers"]
		"water":
			return ["lampjaw"] if rng.randf() < 0.7 else []
		"sky", "outpost", "camp", "yard":
			return ["seraph", "veil_rays"] if rng.randf() < 0.5 else ["seraph"]
		"picket", "wall":
			return ["seraph"] if rng.randf() < 0.3 + 0.1 * depth else []
		"wilds":
			return ["veil_rays"] if rng.randf() < 0.5 else []
	return []


## Puts one `kind` at `pos` facing `facing`. Packs, swarms and flocks put
## several and return the first. Returns the node.
static func spawn(kind: String, root: Node3D, info: Dictionary, pos: Vector3, facing := Vector3(0, 0, 1),
		zone_index := FIRST_ZONE, rng: RandomNumberGenerator = null) -> Node:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.seed = hash(pos)
	var counts: Dictionary = info.get("threat_counts", {})
	counts[kind] = counts.get(kind, 0) + 1
	info["threat_counts"] = counts
	if not info.has("wildlife"):
		info["wildlife"] = []
	if not info.has("grunts"):
		info["grunts"] = []
	var yaw := atan2(-facing.x, -facing.z)
	match kind:
		"hush", "hound", "cantor", "seraph":
			var u := _choir(kind, zone_index)
			if kind == "seraph":
				u.hover_height = 6.0
			_place(root, u, pos + Vector3(0, 0.1, 0), yaw)
			info["grunts"].append(u)
			return u
		"glassback", "lampjaw":
			var c := CharacterBody3D.new()
			c.set_script(Glassback if kind == "glassback" else Lampjaw)
			_place(root, c, pos + Vector3(0, 0.1, 0), yaw)
			info["wildlife"].append(c)
			return c
		"quillcat_pack":
			var pack := []
			for k in 3:
				var c := CharacterBody3D.new()
				c.set_script(Quillcat)
				var a := TAU * k / 3.0
				_place(root, c, pos + Vector3(cos(a), 0.1, sin(a)) * 2.0, yaw + rng.randf_range(-1.0, 1.0))
				c.post = pos
				pack.append(c)
				info["wildlife"].append(c)
			for c in pack:
				c.pack = pack
			return pack[0]
		"bonepickers":
			var swarm := {"members": [], "food": null}
			for k in rng.randi_range(7, 10):
				var c := CharacterBody3D.new()
				c.set_script(Bonepicker)
				c.swarm = swarm
				var off := Vector3(rng.randf_range(-2.5, 2.5), 0.1, rng.randf_range(-2.5, 2.5))
				_place(root, c, pos + off, rng.randf() * TAU)
				c.post = pos
				swarm["members"].append(c)
				info["wildlife"].append(c)
			return swarm["members"][0]
		"veil_rays":
			var flock := []
			var center := pos + Vector3(0, 26.0 + rng.randf_range(0.0, 8.0), 0)
			for k in rng.randi_range(3, 5):
				var c := CharacterBody3D.new()
				c.set_script(VeilRay)
				c.center = center
				var a := rng.randf() * TAU
				_place(root, c, center + Vector3(cos(a), 0, sin(a)) * 22.0, a)
				flock.append(c)
				info["wildlife"].append(c)
			for c in flock:
				c.flock = flock
			return flock[0]
	push_warning("threat_spawner: unknown kind %s" % kind)
	return null


## A Choir unit of `kind`, tuned for the zone (not yet in the tree).
static func _choir(kind: String, zone_index: int) -> CharacterBody3D:
	var u := CharacterBody3D.new()
	u.set_script({"hush": Hush, "hound": Hound, "cantor": Cantor, "seraph": Seraph}[kind])
	var depth := maxi(zone_index - FIRST_ZONE, 0)
	u.max_health *= 1.0 + 0.1 * depth
	u.damage *= 1.0 + 0.1 * depth
	return u


static func _place(root: Node3D, n: Node3D, pos: Vector3, yaw: float) -> void:
	root.add_child(n)
	n.position = pos
	n.rotation.y = yaw
	n.set("post", pos)


## Swaps the militia grunts the zone placed for the Choir. A cache guard is
## swapped in its squad objective too, so clearing the squad still opens it.
static func _convert_grunts(root: Node3D, rng: RandomNumberGenerator, info: Dictionary, zone_index: int) -> void:
	var guard_of := {}
	for o in info.get("objectives", []):
		for g in o.get("grunts"):
			guard_of[g] = o
	var out := []
	var cantors := 0
	for g in info.get("grunts", []):
		if not is_instance_valid(g) or g.get_script() != GruntScript:
			out.append(g)
			continue
		var patrol = g.get("patrol")
		var patrolling: bool = patrol != null and patrol.size() >= 2
		var kind := "hush"
		var roll := rng.randf()
		if patrolling:
			kind = "hound" if roll < 0.5 else "hush"
		elif guard_of.has(g):
			kind = "hush"
		elif roll < 0.12 and cantors < CAPS["cantor"]:
			kind = "cantor"
			cantors += 1
		elif roll < 0.22:
			kind = "hound"
		var u := _choir(kind, zone_index)
		u.leash = g.leash
		if patrolling and kind == "hound":
			u.route = patrol
			u.leash = 0.0
		elif patrolling and u.get("patrol") != null:
			u.set("patrol", patrol)
		root.add_child(u)
		u.position = g.position
		u.rotation = g.rotation
		u.post = g.post
		if guard_of.has(g):
			var o: Node = guard_of[g]
			var i: int = o.grunts.find(g)
			o.grunts[i] = u
			u.died.connect(o._on_grunt_died)
		g.remove_from_group("enemies")
		g.get_parent().remove_child(g)
		g.free()
		out.append(u)
		var counts: Dictionary = info["threat_counts"]
		counts[kind] = counts.get(kind, 0) + 1
	info["grunts"] = out


## Bonepicker swarms go to strip whatever dies nearby.
static func _feed_swarms(info: Dictionary) -> void:
	var swarms := []
	for c in info["wildlife"]:
		if c.get_script() == Bonepicker and not c.swarm in swarms:
			swarms.append(c.swarm)
	if swarms.is_empty():
		return
	var feed := func(dead: Node) -> void:
		if not is_instance_valid(dead):
			return
		for s in swarms:
			var members: Array = s["members"].filter(func(m): return is_instance_valid(m) and not m.dead)
			if not members.is_empty() and members[0].global_position.distance_to(dead.global_position) < 60.0:
				for m in members:
					m.food_at(dead.global_position)
	for e in info["grunts"] + info["wildlife"]:
		if e.get_script() != Bonepicker and e.has_signal("died"):
			e.died.connect(feed)


## Spots for the old platform chain, which has no spawn hooks: the sky over the
## middle platform and the last one, and a resource spot on the biggest side
## platform.
static func _hooks_from_platforms(info: Dictionary) -> Array:
	var plats: Array = info.get("platforms", [])
	if plats.size() < 3:
		return []
	var mid: Dictionary = plats[plats.size() / 2]
	var last: Dictionary = plats[-1]
	return [
		{"pos": mid["top"] + Vector3(0, 18, 0), "section": "sky", "facing": Vector3(0, 0, 1)},
		{"pos": last["top"], "kind": "bonepickers", "facing": Vector3(0, 0, 1)},
		{"pos": last["top"] + Vector3(0, 18, 0), "kind": "veil_rays", "facing": Vector3(0, 0, 1)},
	]
