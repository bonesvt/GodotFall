extends Node3D
## Scrap Titan run loop.
## A run is RunState.ZONE_COUNT traversal zones, then a titan fight. Each zone
## has two salvage caches; opening one offers three titan parts and you keep one.
## Empty slots stay scrap. At the end you call in the titan you assembled and
## fight with it. Falls and getting downed by grunts cost pilot integrity, which
## carries across zones; at zero the run is over, and so it is if your titan is
## destroyed.
## Between runs you are in the hub, the temple Eco hides out in (hub_builder.gd):
## the game opens there, the map table starts a run, and a finished run, won or
## lost, goes back there.

enum Phase { ZONE, CHOOSING, ARENA, FIGHT, OVER, HUB }

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const PILOT_HUD := preload("res://scripts/hud.gd")
const RunHud := preload("res://scripts/run/run_hud.gd")
const RunState := preload("res://scripts/run/run_state.gd")
const TitanParts := preload("res://scripts/run/titan_parts.gd")
const ZoneBuilder := preload("res://scripts/run/zone_builder.gd")
const Titan := preload("res://scripts/run/titan.gd")
const HubBuilder := preload("res://scripts/hub/hub_builder.gd")

const FALL_DAMAGE := 25
## Integrity lost when grunts take the pilot's health to zero.
const DOWNED_DAMAGE := 25
## How far below the lowest platform counts as a fall.
const KILL_DEPTH := 15.0
const OFFER_SIZE := 3
const TITAN_DROP_HEIGHT := 80.0
const EMBARK_RANGE := 6.0
const CONTROLS := "F salvage / embark    V call titan / core    Shift titan dash    Left mouse titan fire"
## How long a line Eco says about something in the hub stays up.
const HUB_LINE_SECONDS := 4.5

## Start in the hub. Off, the scene drops straight into a run (the run loop test does this).
@export var start_in_hub := true
## 0 picks a random seed each run.
@export var run_seed := 0

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
	ensure_input_actions()
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
	if start_in_hub:
		enter_hub()
	else:
		start_run(run_seed)


func start_run(seed_value: int) -> void:
	if seed_value == 0:
		seed_value = randi_range(1, 999999)
	run = RunState.new(seed_value)
	runs_started += 1
	result = ""
	titan = null
	boss = null
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
	place_player(zone_info["spawn"])
	if last_result != "":
		hud.toast("Back at the temple.", HUB_LINE_SECONDS)


func load_zone(index: int) -> void:
	_fresh_level("Zone")
	run.zone = index
	if index < RunState.ZONE_COUNT:
		zone_info = ZoneBuilder.build_zone(zone_root, run.rng, index)
		for grunt in zone_info["grunts"]:
			grunt.target = player
		phase = Phase.ZONE
		hud.toast("ZONE %d / %d" % [index + 1, RunState.ZONE_COUNT])
	else:
		zone_info = ZoneBuilder.build_arena(zone_root)
		boss = zone_info["boss"]
		boss.defeated.connect(_on_boss_defeated)
		phase = Phase.ARENA
		hud.toast("TITANFALL STANDING BY")
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
	var lines: Array = spot["lines"]
	var n: int = hub_reads.get(spot["id"], 0)
	hub_reads[spot["id"]] = n + 1
	hud.toast(lines[n % lines.size()], HUB_LINE_SECONDS)


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
	hub_titan.setup(TitanParts.assemble(last_parts))
	hub_titan.parts = last_parts
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
	if zone_info["beacon"].contains(player.global_position):
		load_zone(run.zone + 1)


func _check_fall() -> bool:
	if player.global_position.y > float(zone_info["floor_y"]) - KILL_DEPTH:
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


## Respawn point: the centre of the last platform the pilot stood on.
func _track_checkpoint() -> void:
	if not player.is_on_floor():
		return
	var pos := player.global_position
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


func _on_boss_defeated() -> void:
	end_run("RUN COMPLETE", "Enemy titan destroyed.")


func _on_titan_destroyed() -> void:
	end_run("TITAN DESTROYED", "Your build could not hold.")


func end_run(title: String, reason: String) -> void:
	if phase == Phase.OVER:
		return
	phase = Phase.OVER
	result = title
	last_result = title
	last_parts = run.parts.duplicate()
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
	lines.append("[Enter] back to the temple" if start_in_hub else "[Enter] new run")
	hud.summary_label.text = "\n".join(lines)
	hud.summary_panel.visible = true


# --- HUD ----------------------------------------------------------------------

func _update_hud() -> void:
	hud.build_label.visible = phase != Phase.HUB
	if phase == Phase.HUB:
		var status := "THE TEMPLE    Runs %d" % runs_started
		if last_result != "":
			status += "    Last run: %s" % last_result
		if course_time >= 0.0:
			status += "    COURSE %.1f s" % course_time
		elif course_best > 0.0:
			status += "    Course best %.2f s" % course_best
		hud.status_label.text = status + "\nWalk up to the map table and press F to head out. F looks at things."
		hud.prompt_label.text = _prompt()
		hud.crosshair.visible = hub_piloting
		hud.fight_label.visible = hub_piloting
		if hub_piloting:
			var dash_text := "%d/%d" % [hub_titan.dashes, int(hub_titan.stats["dashes"])]
			hud.fight_label.text = "PRACTICE TITAN    DASH [Shift] %s    Left mouse fire\n[F] Climb out" % dash_text
		return
	var where := "ZONE %d/%d" % [run.zone + 1, RunState.ZONE_COUNT] if run.zone < RunState.ZONE_COUNT else "FINAL"
	hud.status_label.text = "RUN %d    %s    PILOT %d    %s\n%s" % [
		run.run_seed, where, run.pilot_hp, _clock(run.time), CONTROLS]

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
	var dash_text := "%d/%d" % [titan.dashes, int(titan.stats["dashes"])]
	var core := String(titan.stats["core"]).to_upper()
	var core_text := "NONE" if core == "NONE" else ("%s READY [V]" % core if titan.core_charge >= 1.0 else "%s %d%%" % [core, roundi(titan.core_charge * 100.0)])
	var text := "TITAN %d/%d    DASH [Shift] %s    CORE %s\nENEMY TITAN %d/%d" % [
		roundi(titan.hp), roundi(titan.max_hp), dash_text, core_text, roundi(boss.hp), roundi(boss.max_hp)]
	if boss.slam_incoming():
		text = "SLAM INCOMING: DASH OUT\n" + text
	return text


func _clock(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]
