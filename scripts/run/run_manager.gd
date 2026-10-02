extends Node3D
## Scrap Titan run loop.
## A run is RunState.ZONE_COUNT traversal zones, then a titan fight. Each zone
## has two salvage caches; opening one offers three titan parts and you keep one.
## Empty slots stay scrap. At the end you call in the titan you assembled and
## fight with it. Falls and getting downed by grunts cost pilot integrity, which
## carries across zones; at zero the run is over, and so it is if your titan is
## destroyed.

enum Phase { ZONE, CHOOSING, ARENA, FIGHT, OVER }

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const PILOT_HUD := preload("res://scripts/hud.gd")
const RunHud := preload("res://scripts/run/run_hud.gd")
const RunState := preload("res://scripts/run/run_state.gd")
const TitanParts := preload("res://scripts/run/titan_parts.gd")
const ZoneBuilder := preload("res://scripts/run/zone_builder.gd")
const Titan := preload("res://scripts/run/titan.gd")

const FALL_DAMAGE := 25
## Integrity lost when grunts take the pilot's health to zero.
const DOWNED_DAMAGE := 25
## How far below the lowest platform counts as a fall.
const KILL_DEPTH := 15.0
const OFFER_SIZE := 3
const TITAN_DROP_HEIGHT := 80.0
const EMBARK_RANGE := 6.0
const CONTROLS := "F salvage / embark    V call titan / core    Shift titan dash    Left mouse titan fire"

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
	start_run(run_seed)


func start_run(seed_value: int) -> void:
	if seed_value == 0:
		seed_value = randi_range(1, 999999)
	run = RunState.new(seed_value)
	result = ""
	titan = null
	boss = null
	get_tree().paused = false
	hud.summary_panel.visible = false
	hud.choice_panel.visible = false
	_set_pilot_active(true)
	load_zone(0)


func load_zone(index: int) -> void:
	if zone_root != null:
		remove_child(zone_root)
		zone_root.free()
	zone_root = Node3D.new()
	zone_root.name = "Zone"
	zone_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(zone_root)
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
				start_run(0)
	_update_hud()


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
	lines.append("[Enter] new run")
	hud.summary_label.text = "\n".join(lines)
	hud.summary_panel.visible = true


# --- HUD ----------------------------------------------------------------------

func _update_hud() -> void:
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
