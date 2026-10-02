extends Node3D
## Scrap Titan run loop.
## A run is RunState.ZONE_COUNT traversal zones, then a titan fight. Each zone
## has two salvage caches; opening one offers three titan parts and you keep one.
## Empty slots stay scrap. At the end you call in the titan you assembled and
## fight with it. Falls and getting downed by grunts cost pilot integrity, which
## carries across zones; at zero the run is over, and so it is if your titan is
## destroyed. Beat the enemy titan and the evac dropship comes for yours: walk
## it onto the pad to finish the run.
## Between runs you are in the hub, the temple Eco hides out in (hub_builder.gd):
## the game opens there, the map table starts a run, and a finished run, won or
## lost, goes back there.
## Out in the zones you pick up materials (loot.gd: grunt drops, supply crates,
## alloy nodes); a run banks them in Eco's armory (armory.gd) when it ends, and
## the hub's workbenches (bench_screen.gd) spend them on guns and titan parts.

enum Phase { ZONE, CHOOSING, ARENA, FIGHT, OVER, HUB }

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const PILOT_HUD := preload("res://scripts/hud.gd")
const RunHud := preload("res://scripts/run/run_hud.gd")
const RunState := preload("res://scripts/run/run_state.gd")
const TitanParts := preload("res://scripts/run/titan_parts.gd")
const ZoneBuilder := preload("res://scripts/run/zone_builder.gd")
const Titan := preload("res://scripts/run/titan.gd")
const HubBuilder := preload("res://scripts/hub/hub_builder.gd")
const Armory := preload("res://scripts/hub/armory.gd")
const BenchScreen := preload("res://scripts/hub/bench_screen.gd")
const Loot := preload("res://scripts/run/loot.gd")
const Weapon := preload("res://scripts/weapon.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")

const FALL_DAMAGE := 25
## Integrity lost when grunts take the pilot's health to zero.
const DOWNED_DAMAGE := 25
## How far below the lowest platform counts as a fall.
const KILL_DEPTH := 15.0
const OFFER_SIZE := 3
const TITAN_DROP_HEIGHT := 80.0
const EMBARK_RANGE := 6.0
## How close (m) your titan has to get to the evac pad's centre.
const EVAC_RADIUS := 6.0
## Checkpoints in laid-out zones count once you stand this close (m) to one.
const CHECKPOINT_RADIUS := 10.0
const CONTROLS := "F salvage / embark    V call titan / core    Shift titan dash    Left mouse titan fire"
## How long a line Eco says about something in the hub stays up.
const HUB_LINE_SECONDS := 4.5

## Start in the hub. Off, the scene drops straight into a run (the run loop test does this).
@export var start_in_hub := true
## 0 picks a random seed each run.
@export var run_seed := 0
## Where Eco's armory (materials, guns, upgrades, titan parts) is saved.
@export var armory_path := Armory.DEFAULT_PATH

var run: RunState
var phase := Phase.ZONE
var zone_root: Node3D
var zone_info := {}
var player: CharacterBody3D
var pilot_hud: CanvasLayer
var hud: RunHud
var offer: Array = []
var open_cache: Node3D
var titan: Titan
var boss: Node3D
var checkpoint := Vector3.ZERO
var result := ""
## The enemy titan is down and the evac dropship is waiting at the pad.
var evac_open := false
## How many times each hub interactable has been looked at, so its lines cycle.
var hub_reads := {}
var runs_started := 0
var last_result := ""
## The parts your last run ended with; the hub's practice titan is built from them.
var last_parts := {}
## The practice titan in the hub's titan yard, and whether you're in it.
var hub_titan: Titan
var hub_piloting := false
## Movement course clock: armed while standing on the start pad, running (>= 0)
## from leaving it until the finish tower, or until you touch the grass.
var course_armed := false
var course_time := -1.0
var course_best := 0.0
var armory: Armory
## The workbench screen while one is open (the hub is paused under it).
var bench: BenchScreen
## Lays out loot and rolls drops, seeded per zone from the run seed so loot
## never shifts the run's own rolls.
var loot_rng := RandomNumberGenerator.new()


static func ensure_input_actions() -> void:
	var keys := {
		"interact": [KEY_F], "choice_1": [KEY_1], "choice_2": [KEY_2], "choice_3": [KEY_3],
		"choice_skip": [KEY_X], "titan_core": [KEY_V], "titan_dash": [KEY_SHIFT],
		"run_restart": [KEY_ENTER],
	}
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	if not InputMap.has_action("titan_fire"):
		InputMap.add_action("titan_fire")
		var lmb := InputEventMouseButton.new()
		lmb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("titan_fire", lmb)


func _ready() -> void:
	# The manager keeps running while the salvage choice pauses the world.
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("loot_collector")
	ensure_input_actions()
	armory = Armory.open(armory_path)
	player = PLAYER_SCENE.instantiate()
	player.name = "Player"
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	player.died.connect(_on_pilot_downed)
	pilot_hud = CanvasLayer.new()
	pilot_hud.set_script(PILOT_HUD)
	pilot_hud.name = "PilotHUD"
	pilot_hud.player = player
	add_child(pilot_hud)
	hud = RunHud.new()
	hud.name = "RunHUD"
	add_child(hud)
	equip_loadout()
	if start_in_hub:
		enter_hub()
	else:
		start_run(run_seed)


func start_run(seed_value: int) -> void:
	if seed_value == 0:
		seed_value = randi_range(1, 999999)
	run = RunState.new(seed_value)
	for part in armory.start_parts().values():
		run.install(part)
	run.refits = armory.refit_bonus()
	runs_started += 1
	result = ""
	titan = null
	boss = null
	evac_open = false
	get_tree().paused = false
	hud.summary_panel.visible = false
	hud.choice_panel.visible = false
	_set_pilot_active(true)
	load_zone(0)


func _fresh_level(level_name: String) -> void:
	if zone_root != null:
		remove_child(zone_root)
		zone_root.free()
	zone_root = Node3D.new()
	zone_root.name = level_name
	zone_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(zone_root)


## Back to the temple: no run in progress, walk around, start one at the map table.
func enter_hub() -> void:
	titan = null
	boss = null
	get_tree().paused = false
	hud.summary_panel.visible = false
	hud.choice_panel.visible = false
	_set_pilot_active(true)
	hub_titan = null
	hub_piloting = false
	course_armed = false
	course_time = -1.0
	_fresh_level("Hub")
	zone_info = HubBuilder.build(zone_root)
	phase = Phase.HUB
	dress_hub()
	place_player(zone_info["spawn"])
	if last_result != "":
		hud.toast("Back at the temple.", HUB_LINE_SECONDS)


func load_zone(index: int) -> void:
	_fresh_level("Zone")
	run.zone = index
	if index < RunState.ZONE_COUNT:
		zone_info = ZoneBuilder.build_zone(zone_root, run.rng, index)
		loot_rng.seed = run.run_seed * 7919 + index
		Loot.scatter(zone_root, zone_info, loot_rng, index)
		for grunt in zone_info["grunts"]:
			grunt.target = player
			grunt.died.connect(_on_grunt_died)
		phase = Phase.ZONE
		var zone_name: String = zone_info.get("name", "")
		hud.toast("ZONE %d / %d%s" % [index + 1, RunState.ZONE_COUNT, ": " + zone_name if zone_name != "" else ""])
	else:
		zone_info = ZoneBuilder.build_arena(zone_root)
		boss = zone_info["boss"]
		boss.defeated.connect(_on_boss_defeated)
		phase = Phase.ARENA
		evac_open = false
		hud.toast("THE FOREST'S EDGE: TITANFALL STANDING BY")
	place_player(zone_info["spawn"])


func place_player(pos: Vector3) -> void:
	checkpoint = pos
	player.spawn_transform = Transform3D(Basis(), pos)
	player.respawn()


func _physics_process(delta: float) -> void:
	match phase:
		Phase.ZONE:
			_zone_tick(delta)
		Phase.CHOOSING:
			_choice_tick()
		Phase.ARENA:
			_arena_tick(delta)
		Phase.FIGHT:
			run.time += delta
			_evac_tick()
		Phase.OVER:
			if Input.is_action_just_pressed("run_restart"):
				if start_in_hub:
					enter_hub()
				else:
					start_run(0)
		Phase.HUB:
			_hub_tick(delta)
	_update_hud()


# --- Hub ----------------------------------------------------------------------

func _hub_tick(delta: float) -> void:
	if bench != null:
		if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_cancel"):
			close_bench()
		return
	if hub_piloting:
		if Input.is_action_just_pressed("interact"):
			disembark_hub_titan()
		return
	# Falling out of the world in the hub costs nothing: back inside the door.
	if player.global_position.y < float(zone_info["floor_y"]) - KILL_DEPTH:
		place_player(zone_info["spawn"])
		return
	_course_tick(delta)
	if Input.is_action_just_pressed("titan_core") and in_titan_yard():
		call_hub_titan()
		return
	if _hub_titan_in_reach() and Input.is_action_just_pressed("interact"):
		embark_hub_titan()
		return
	var spot := nearest_hub_spot()
	if spot.is_empty() or not Input.is_action_just_pressed("interact"):
		return
	if spot["id"] == "map_table":
		start_run(run_seed)
		return
	if spot.has("screen"):
		open_bench(spot["screen"])
		return
	var lines: Array = spot["lines"]
	var n: int = hub_reads.get(spot["id"], 0)
	hub_reads[spot["id"]] = n + 1
	hud.toast(lines[n % lines.size()], HUB_LINE_SECONDS)


## Opens a workbench screen ("gunsmith", "rack" or "workshop"), pausing the hub.
func open_bench(kind: String) -> void:
	bench = BenchScreen.new(armory, kind)
	add_child(bench)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.visible = false
	pilot_hud.visible = false


func close_bench() -> void:
	bench.queue_free()
	bench = null
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.visible = true
	pilot_hud.visible = true
	equip_loadout()
	dress_hub()


## Puts the gun picked at the weapon rack, upgraded and fitted, in Eco's hand.
func equip_loadout() -> void:
	player.get_node("Head/Camera3D/Weapon").equip(armory.weapon_profile())


## Shows the armory on the benches: the equipped gun on the gunsmith's mat,
## the guns you own on the rack (locked slots stay empty under a tag), and the
## titan you'd start a run with standing in the workshop's gantry.
func dress_hub() -> void:
	var mat: Node3D = zone_info.get("gun_marker")
	if mat != null:
		for c in mat.get_children():
			c.free()
		var gun := Weapon.gun_model(armory.weapon_profile())
		gun.scale = Vector3.ONE * 2.2
		gun.rotation_degrees = Vector3(0, 90, 90)
		mat.add_child(gun)
	var slots: Array = zone_info.get("rack_slots", [])
	var ids: Array = Armory.WEAPONS.keys()
	for i in mini(slots.size(), ids.size()):
		var slot: Node3D = slots[i]
		for c in slot.get_children():
			c.free()
		var id: String = ids[i]
		var tag := Label3D.new()
		tag.font_size = 40
		tag.pixel_size = 0.0025
		tag.position = Vector3(0, -0.42, 0.02)
		tag.outline_size = 8
		slot.add_child(tag)
		if armory.owns_weapon(id):
			var gun := Weapon.gun_model(armory.weapon_profile(id))
			gun.scale = Vector3.ONE * 2.2
			gun.rotation_degrees = Vector3(0, 90, 0)
			slot.add_child(gun)
			tag.text = "IN HAND" if id == armory.equipped else Armory.WEAPONS[id]["name"].to_upper()
			tag.modulate = Color(1.0, 0.8, 0.35) if id == armory.equipped else Color(0.9, 0.88, 0.82)
		else:
			tag.text = "LOCKED"
			tag.modulate = Color(0.6, 0.6, 0.62)
	var stand: Node3D = zone_info.get("workshop_titan")
	if stand != null:
		for c in stand.get_children():
			c.free()
		var parts := armory.start_parts()
		var titan := Art.titan(parts.get("chassis", {}).get("id", "scrap"), parts.get("weapon", {}).get("id", "scrap"))
		titan.scale = Vector3.ONE * 0.6
		stand.add_child(titan)


## A pickup reached the pilot.
func collect_material(kind: String, amount: int) -> void:
	if run == null or phase == Phase.HUB:
		return
	run.materials[kind] = int(run.materials.get(kind, 0)) + amount


## Grunts drop scrap where they fall, sometimes a circuit.
func _on_grunt_died(grunt: Node) -> void:
	if run == null or zone_root == null or not is_instance_valid(grunt):
		return
	run.kills += 1
	Loot.drop(zone_root, grunt.global_position, Loot.roll_grunt(loot_rng, run.zone), loot_rng)


## The crate or alloy node the pilot is standing at, or null.
func nearest_loot() -> Node3D:
	for node in zone_info.get("loot", []):
		if is_instance_valid(node) and node.in_range(player.global_position):
			return node
	return null


## F pries a crate open; holding F mines a node.
func _loot_tick(delta: float) -> void:
	var node := nearest_loot()
	if node == null:
		return
	var got := {}
	if node.has_method("open"):
		if Input.is_action_just_pressed("interact"):
			got = node.open()
	elif Input.is_action_pressed("interact"):
		got = node.mine(delta)
	if not got.is_empty():
		Loot.drop(zone_root, node.global_position + Vector3(0, 0.4, 0), got, loot_rng)


func in_titan_yard() -> bool:
	var yard: Rect2 = zone_info["titan_yard"]
	return yard.has_point(Vector2(player.global_position.x, player.global_position.z))


## Drops a practice titan, built from your last run's parts, in front of you
## (or moves the one already there).
func call_hub_titan() -> void:
	if hub_titan != null:
		hub_titan.queue_free()
	hub_titan = Titan.new()
	hub_titan.name = "PracticeTitan"
	var parts := last_parts if not last_parts.is_empty() else armory.start_parts()
	hub_titan.setup(TitanParts.assemble(parts, armory.refit_bonus()))
	hub_titan.parts = parts
	var forward := -player.global_basis.z
	forward.y = 0.0
	var drop := player.global_position + forward.normalized() * 12.0
	var yard: Rect2 = zone_info["titan_yard"]
	drop.x = clampf(drop.x, yard.position.x + 6.0, yard.end.x - 6.0)
	drop.z = clampf(drop.z, yard.position.y + 6.0, yard.end.y - 6.0)
	zone_root.add_child(hub_titan)
	hub_titan.global_position = Vector3(drop.x, TITAN_DROP_HEIGHT, drop.z)
	hub_titan.rotation.y = player.rotation.y
	hub_titan.landed.connect(func(): hud.toast("TITAN ON THE GROUND"))
	hud.toast("STANDBY FOR TITANFALL")


func _hub_titan_in_reach() -> bool:
	return hub_titan != null and not hub_titan.dropping \
		and hub_titan.global_position.distance_to(player.global_position) < EMBARK_RANGE


func embark_hub_titan() -> void:
	_set_pilot_active(false)
	hub_titan.piloted = true
	hub_titan.camera.make_current()
	hub_piloting = true


## Out of the titan: the pilot lands beside it, facing the way it faces.
func disembark_hub_titan() -> void:
	hub_titan.piloted = false
	hub_piloting = false
	var side := hub_titan.global_basis.x * 4.0
	player.spawn_transform = Transform3D(hub_titan.global_basis.orthonormalized(), hub_titan.global_position + side + Vector3(0, 0.5, 0))
	_set_pilot_active(true)
	player.respawn()
	player.spawn_transform = Transform3D(Basis(), zone_info["spawn"])


func _on_course_pad(key: String) -> bool:
	var course: Dictionary = zone_info["course"]
	var top: Vector3 = course[key]
	var half: Vector3 = course["half"]
	var pos := player.global_position
	return player.is_on_floor() and absf(pos.x - top.x) < half.x and absf(pos.z - top.z) < half.z and absf(pos.y - top.y) < 0.6


func _course_tick(delta: float) -> void:
	if _on_course_pad("start"):
		course_armed = true
		course_time = -1.0
		return
	if course_armed:
		course_armed = false
		course_time = 0.0
		return
	if course_time < 0.0:
		return
	course_time += delta
	if _on_course_pad("finish"):
		var best := course_best == 0.0 or course_time < course_best
		if best:
			course_best = course_time
		hud.toast("COURSE %.2f s%s" % [course_time, "  NEW BEST" if best else "  (best %.2f s)" % course_best], HUB_LINE_SECONDS)
		course_time = -1.0
	elif player.is_on_floor() and player.global_position.y < 0.3:
		hud.toast("Touched the grass. Back to the start pad.")
		course_time = -1.0


## The hub interactable the pilot is standing at, or {} if none.
func nearest_hub_spot() -> Dictionary:
	var best := {}
	var best_d := INF
	var pos := player.global_position
	for spot in zone_info.get("interactables", []):
		var at: Vector3 = spot["pos"]
		var d := Vector2(pos.x - at.x, pos.z - at.z).length()
		if d < float(spot["range"]) and absf(pos.y - at.y) < 2.5 and d < best_d:
			best = spot
			best_d = d
	return best


# --- Zones --------------------------------------------------------------------

func _zone_tick(delta: float) -> void:
	run.time += delta
	if _check_fall():
		return
	_track_checkpoint()
	var cache := nearest_cache()
	if cache != null and Input.is_action_just_pressed("interact"):
		open_salvage(cache)
		return
	if cache == null:
		_loot_tick(delta)
	if zone_info["beacon"].contains(player.global_position):
		load_zone(run.zone + 1)


## Below this height the pilot has fallen out of the level.
func kill_y() -> float:
	return float(zone_info.get("kill_y", float(zone_info["floor_y"]) - KILL_DEPTH))


func _check_fall() -> bool:
	if player.global_position.y > kill_y():
		return false
	run.pilot_hp -= FALL_DAMAGE
	run.falls += 1
	if run.pilot_hp <= 0:
		run.pilot_hp = 0
		end_run("PILOT KIA", "Too many falls.")
	else:
		place_player(checkpoint)
		hud.toast("FELL: -%d INTEGRITY" % FALL_DAMAGE)
	return true


## Grunts emptied the pilot's health: lose integrity, back to the checkpoint.
func _on_pilot_downed() -> void:
	if phase == Phase.HUB:
		place_player(zone_info["spawn"])
		return
	if phase != Phase.ZONE:
		player.respawn()
		return
	run.pilot_hp -= DOWNED_DAMAGE
	run.downs += 1
	if run.pilot_hp <= 0:
		run.pilot_hp = 0
		end_run("PILOT KIA", "Gunned down.")
	else:
		place_player(checkpoint)
		hud.toast("DOWNED: -%d INTEGRITY" % DOWNED_DAMAGE)


## Respawn point: the centre of the last platform the pilot stood on, or in a
## laid-out zone the last checkpoint they passed.
func _track_checkpoint() -> void:
	if not player.is_on_floor():
		return
	var pos := player.global_position
	for point in zone_info.get("checkpoints", []):
		if Vector2(pos.x - point.x, pos.z - point.z).length() < CHECKPOINT_RADIUS and absf(pos.y - point.y) < 2.0:
			checkpoint = point
			return
	for p in zone_info["platforms"]:
		var top: Vector3 = p["top"]
		var size: Vector2 = p["size"]
		if absf(pos.x - top.x) < size.x * 0.5 and absf(pos.z - top.z) < size.y * 0.5 and absf(pos.y - top.y) < 0.6:
			checkpoint = top + Vector3(0, 0.1, 0)
			return


func nearest_cache() -> Node3D:
	for cache in zone_info["caches"]:
		if cache.in_range(player.global_position) and not cache.opened:
			return cache
	return null


func open_salvage(cache: Node3D) -> void:
	if not cache.can_open():
		hud.toast("LOCKED: CLEAR THE GUARDS")
		return
	open_cache = cache
	offer = TitanParts.roll_offer(run.rng, run.zone, OFFER_SIZE)
	phase = Phase.CHOOSING
	get_tree().paused = true
	hud.choice_panel.visible = true


func _choice_tick() -> void:
	for i in offer.size():
		if Input.is_action_just_pressed("choice_%d" % (i + 1)):
			choose(i)
			return
	if Input.is_action_just_pressed("choice_skip"):
		choose(-1)


## Takes offer[index] (or nothing for -1) and closes the cache.
func choose(index: int) -> void:
	if index >= 0:
		var part: Dictionary = offer[index]
		run.install(part)
		hud.toast("INSTALLED: %s" % part["display"])
	open_cache.mark_opened()
	run.caches_opened += 1
	open_cache = null
	offer = []
	hud.choice_panel.visible = false
	get_tree().paused = false
	phase = Phase.ZONE


# --- Titanfall and the fight --------------------------------------------------

func _arena_tick(delta: float) -> void:
	run.time += delta
	if _check_fall():
		return
	if titan == null:
		if Input.is_action_just_pressed("titan_core"):
			call_titan()
	elif not titan.dropping and _titan_in_reach() and Input.is_action_just_pressed("interact"):
		embark()


func call_titan() -> void:
	titan = Titan.new()
	titan.name = "Titan"
	titan.setup(run.titan_stats())
	titan.parts = run.parts
	titan.boss = boss
	var forward := -player.global_basis.z
	forward.y = 0.0
	var drop := player.global_position + forward.normalized() * 12.0
	var half: float = zone_info["half_size"]
	drop.x = clampf(drop.x, -half, half)
	drop.z = clampf(drop.z, -half, half)
	zone_root.add_child(titan)
	titan.global_position = Vector3(drop.x, TITAN_DROP_HEIGHT, drop.z)
	titan.rotation.y = atan2(-(boss.global_position.x - drop.x), -(boss.global_position.z - drop.z))
	titan.destroyed.connect(_on_titan_destroyed)
	titan.landed.connect(func(): hud.toast("TITAN ON THE GROUND"))
	hud.toast("STANDBY FOR TITANFALL")


func _titan_in_reach() -> bool:
	return titan.global_position.distance_to(player.global_position) < EMBARK_RANGE


func embark() -> void:
	_set_pilot_active(false)
	titan.piloted = true
	titan.camera.make_current()
	hud.titan = titan
	boss.target = titan
	boss.active = true
	phase = Phase.FIGHT


func _set_pilot_active(on: bool) -> void:
	player.process_mode = Node.PROCESS_MODE_PAUSABLE if on else Node.PROCESS_MODE_DISABLED
	player.visible = on
	player.get_node("Collision").disabled = not on
	pilot_hud.visible = on
	if on:
		player.get_node("Head/Camera3D").make_current()


## Their titan is down: it topples, and the dropship comes in over the evac pad.
func _on_boss_defeated() -> void:
	if not zone_info.has("evac"):
		end_run("RUN COMPLETE", "Enemy titan destroyed.")
		return
	evac_open = true
	var tip := boss.create_tween()
	tip.tween_property(boss, "rotation:x", deg_to_rad(-75.0), 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var evac: Node3D = zone_info["evac_node"]
	evac.visible = true
	var ship := evac.get_node("Dropship") as Node3D
	var hover := ship.position
	ship.position = hover + Vector3(0, 60, 40)
	evac.create_tween().tween_property(ship, "position", hover, 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	hud.toast("ENEMY TITAN DOWN. GET TO THE EVAC PAD", 5.0)


func _evac_tick() -> void:
	if not evac_open or titan == null:
		return
	var pad: Vector3 = zone_info["evac"]
	var d := titan.global_position - pad
	if Vector2(d.x, d.z).length() < EVAC_RADIUS:
		end_run("RUN COMPLETE", "Titan extracted back to base.")


func _on_titan_destroyed() -> void:
	end_run("TITAN DESTROYED", "Your build could not hold.")


func end_run(title: String, reason: String) -> void:
	if phase == Phase.OVER:
		return
	phase = Phase.OVER
	result = title
	last_result = title
	last_parts = run.parts.duplicate()
	var won := title == "RUN COMPLETE"
	var haul := Armory.run_haul(run.materials, won)
	armory.bank(haul)
	if boss != null:
		boss.active = false
	if titan != null:
		titan.piloted = false
	get_tree().paused = false
	var lines := [title, reason, ""]
	lines.append("Seed %d    Time %s    Falls %d    Downed %d" % [run.run_seed, _clock(run.time), run.falls, run.downs])
	lines.append("")
	for slot in TitanParts.SLOTS:
		lines.append("%s: %s" % [TitanParts.SLOT_NAMES[slot], TitanParts.display_name(run.parts, slot)])
	lines.append("")
	lines.append("BANKED: %s%s" % [_materials_text(haul), "  (titan salvage included)" if won else "  (half of what you carried)"])
	lines.append("")
	lines.append("[Enter] back to the temple" if start_in_hub else "[Enter] new run")
	hud.summary_label.text = "\n".join(lines)
	hud.summary_panel.visible = true


# --- HUD ----------------------------------------------------------------------

func _update_hud() -> void:
	hud.build_label.visible = phase != Phase.HUB
	if phase == Phase.HUB:
		var status := "THE TEMPLE    %s    Runs %d" % [_materials_text(armory.stash), runs_started]
		if last_result != "":
			status += "    Last run: %s" % last_result
		if course_time >= 0.0:
			status += "    COURSE %.1f s" % course_time
		elif course_best > 0.0:
			status += "    Course best %.2f s" % course_best
		hud.status_label.text = status + "\nWalk up to the map table and press F to head out. F looks at things and works the benches."
		hud.prompt_label.text = _prompt()
		hud.crosshair.visible = hub_piloting
		hud.fight_label.visible = hub_piloting
		if hub_piloting:
			var dash_text := "%d/%d" % [hub_titan.dashes, int(hub_titan.stats["dashes"])]
			hud.fight_label.text = "PRACTICE TITAN    DASH [Shift] %s    Left mouse fire\n[F] Climb out" % dash_text
		return
	var where := "ZONE %d/%d" % [run.zone + 1, RunState.ZONE_COUNT] if run.zone < RunState.ZONE_COUNT else "FINAL"
	hud.status_label.text = "RUN %d    %s    PILOT %d    %s    %s\n%s" % [
		run.run_seed, where, run.pilot_hp, _clock(run.time), _materials_text(run.materials), CONTROLS]

	var build := ["TITAN BUILD"]
	for slot in TitanParts.SLOTS:
		build.append("%s: %s" % [TitanParts.SLOT_NAMES[slot], TitanParts.display_name(run.parts, slot)])
	hud.build_label.text = "\n".join(build)

	hud.prompt_label.text = _prompt()
	if phase == Phase.CHOOSING:
		hud.choice_label.text = _choice_text()
	var fighting := phase == Phase.FIGHT
	hud.crosshair.visible = fighting
	hud.fight_label.visible = fighting
	if fighting:
		hud.fight_label.text = _fight_text()


func _prompt() -> String:
	match phase:
		Phase.HUB:
			if hub_piloting:
				return ""
			if hub_titan != null and hub_titan.dropping:
				return "Titanfall inbound"
			if _hub_titan_in_reach():
				return "[F] Embark"
			if course_armed:
				return "Leave the pad to start the clock"
			var spot := nearest_hub_spot()
			if not spot.is_empty():
				return spot["prompt"]
			if in_titan_yard():
				return "[V] Call in your titan" if hub_titan == null else "[V] Call your titan here"
		Phase.ZONE:
			var cache := nearest_cache()
			if cache != null:
				return "[F] Open salvage" if cache.can_open() else "Locked: clear the guards"
			var node := nearest_loot()
			if node != null:
				return node.prompt()
		Phase.ARENA:
			if titan == null:
				return "[V] Call in your titan"
			if titan.dropping:
				return "Titanfall inbound"
			return "[F] Embark" if _titan_in_reach() else "Get to your titan"
	return ""


func _choice_text() -> String:
	var lines := ["SALVAGE: KEEP ONE PART", ""]
	for i in offer.size():
		var part: Dictionary = offer[i]
		var slot: String = part["slot"]
		lines.append("[%d] %s: %s" % [i + 1, TitanParts.SLOT_NAMES[slot].to_upper(), part["display"]])
		lines.append("     %s  (%s)" % [part["desc"], TitanParts.describe(part)])
		lines.append("     replaces %s" % TitanParts.display_name(run.parts, slot))
		lines.append("")
	lines.append("[X] Leave it")
	return "\n".join(lines)


func _fight_text() -> String:
	if evac_open:
		var pad: Vector3 = zone_info["evac"]
		return "ENEMY TITAN DOWN\nEVAC PAD %d m: walk your titan into the beam" % roundi(titan.global_position.distance_to(pad))
	var dash_text := "%d/%d" % [titan.dashes, int(titan.stats["dashes"])]
	var core := String(titan.stats["core"]).to_upper()
	var core_text := "NONE" if core == "NONE" else ("%s READY [V]" % core if titan.core_charge >= 1.0 else "%s %d%%" % [core, roundi(titan.core_charge * 100.0)])
	var text := "TITAN %d/%d    DASH [Shift] %s    CORE %s\nENEMY TITAN %d/%d" % [
		roundi(titan.hp), roundi(titan.max_hp), dash_text, core_text, roundi(boss.hp), roundi(boss.max_hp)]
	if boss.slam_incoming():
		text = "SLAM INCOMING: DASH OUT\n" + text
	return text


func _materials_text(m: Dictionary) -> String:
	return "SCRAP %d  ALLOY %d  CIRCUITS %d" % [int(m.get("scrap", 0)), int(m.get("alloy", 0)), int(m.get("circuits", 0))]


func _clock(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]
