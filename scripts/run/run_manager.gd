extends Node3D
## Scrap Titan run loop.
## A run is RunState.ZONE_COUNT traversal zones (a long run adds
## RunState.UNCHARTED_ZONES generated ones after them), then a titan fight. Each zone
## has two salvage caches; opening one offers three titan parts and you keep one.
## Empty slots stay scrap. At the end you call in the titan you assembled and
## fight with it. Falls and getting downed by grunts cost pilot integrity, which
## carries across zones; at zero the run is over, and so it is if your titan is
## destroyed. Beat the enemy titan and the evac dropship comes for yours: walk
## it onto the pad to finish the run.
## Between runs you are in the hub, the temple Eco hides out in (hub_builder.gd):
## the game opens there, the poster outside starts the Pinewoods run (the
## tutorial), and a finished run, won or lost, goes back there.
## Out in the zones you pick up materials (loot.gd: grunt drops, supply crates,
## alloy nodes); a run banks them in Eco's armory (armory.gd) when it ends, and
## the hub's workbenches (bench_screen.gd) spend them on guns and titan parts.
## Once the tutorial run is won, the mission table in the nave opens the
## real levels (levels.gd): one long generated zone each, with a salvage depot
## holding a titan part, that ends in a clearing where the enemy titan waits.
## There the fight starts as soon as you walk out into the clearing.

enum Phase { ZONE, CHOOSING, ARENA, FIGHT, OVER, HUB }

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const PILOT_HUD := preload("res://scripts/hud.gd")
const RunHud := preload("res://scripts/run/run_hud.gd")
const RunState := preload("res://scripts/run/run_state.gd")
const TitanParts := preload("res://scripts/run/titan_parts.gd")
const ZoneBuilder := preload("res://scripts/run/zone_builder.gd")
const Levels := preload("res://scripts/run/levels.gd")
const Titan := preload("res://scripts/run/titan.gd")
const HubBuilder := preload("res://scripts/hub/hub_builder.gd")
const Armory := preload("res://scripts/hub/armory.gd")
const BenchScreen := preload("res://scripts/hub/bench_screen.gd")
const GunsmithScreen := preload("res://scripts/hub/gunsmith_screen.gd")
const GiftScreen := preload("res://scripts/hub/gift_screen.gd")
const GiftShop := preload("res://scripts/hub/gift_shop.gd")
const SalonScreen := preload("res://scripts/hub/salon_screen.gd")
const WardrobeScreen := preload("res://scripts/hub/wardrobe_screen.gd")
const Wardrobe := preload("res://scripts/hub/wardrobe.gd")
const Loot := preload("res://scripts/run/loot.gd")
const Gifts := preload("res://scripts/run/gifts.gd")
const NpcIdles := preload("res://scripts/hub/npc_idles.gd")
const Escort := preload("res://scripts/run/escort.gd")
const Weapon := preload("res://scripts/weapon.gd")
const Knife := preload("res://scripts/knife.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")
const Garage := preload("res://scripts/hub/garage.gd")
const TitanStyle := preload("res://scripts/run/titan_style.gd")
const HubNpc := preload("res://scripts/hub/hub_npc.gd")
const NpcTalk := preload("res://scripts/hub/npc_talk.gd")
const Family := preload("res://scripts/hub/family.gd")
const FamilyScene := preload("res://scripts/hub/family_scene.gd")
const Townsfolk := preload("res://scripts/hub/townsfolk.gd")
const Tutorial := preload("res://scripts/run/tutorial.gd")
const ViewCamera := preload("res://scripts/view_camera.gd")
const Prefs := preload("res://scripts/game/prefs.gd")
const Saves := preload("res://scripts/game/saves.gd")
const PauseMenu := preload("res://scripts/ui/pause_menu.gd")

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
## Generated zones added after the handmade ones when the scene drops straight
## into a run (start_in_hub off). The hub's uncharted map sets it per run.
@export var uncharted_zones := 0
## A level (levels.gd id) to drop straight into instead, start_in_hub off.
@export var level_id := ""
## Where Eco's armory (materials, guns, upgrades, titan parts) is saved.
@export var armory_path := Armory.DEFAULT_PATH
## Where who Eco has talked to in the hub (and what about) is saved.
@export var npc_path := NpcTalk.DEFAULT_PATH

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
## A rescue level (levels.gd "rescue"): whether they're out of the cell yet,
## and how long until Eco next says she's not leaving without them.
var rescued := false
var _rescue_nag := 0.0
## Them following Eco out (escort.gd), once they're free.
var escort: Escort
## Whether any grunt went loud on this level.
var _alarm_raised := false
## How close they have to be when Eco steps into the exfil (m).
const EXFIL_TOGETHER := 9.0
## How many times each hub interactable has been looked at, so its lines cycle.
var hub_reads := {}
var runs_started := 0
var last_result := ""
## Runs finished this session, so the people in the hub react once to each.
var runs_ended := 0
## The people living in the hub (hub_rooms.gd), by who, and their conversations.
var hub_npcs := {}
var npc_talk: NpcTalk
## Motherly Love scenes in Mom's room (family_scene.gd), in the hub only.
var family_scene: FamilyScene
## The parts your last run ended with; the hub's practice titan is built from them.
var last_parts := {}
## The hub spot Eco is sitting or lying down at ({} = she's on her feet), and
## the rest pose she's in there (spot["rest"] or its "alt").
var rest_spot := {}
var rest_pose := ""
## The practice titan in the hub's titan yard, and whether you're in it.
var hub_titan: Titan
var hub_piloting := false
## The paint shop screen while it is open (it pauses the hub).
var garage: Garage
## Movement course clock: armed while standing on the start pad, running (>= 0)
## from leaving it until the finish tower, or until you touch the grass.
var course_armed := false
var course_time := -1.0
var course_best := 0.0
var armory: Armory
## The workbench screen while one is open (the hub is paused under it).
## A BenchScreen, the GunsmithScreen at the gunsmith bench, or the SalonScreen.
var bench = null
## Lays out loot and rolls drops, seeded per zone from the run seed so loot
## never shifts the run's own rolls.
var loot_rng := RandomNumberGenerator.new()
## Hints that teach the game in the first three zones (tutorial.gd).
var tutorial: Tutorial
## Esc menu (pause_menu.gd).
var pause_menu: CanvasLayer


static func ensure_input_actions() -> void:
	var keys := {
		"interact": [KEY_F], "choice_1": [KEY_1], "choice_2": [KEY_2], "choice_3": [KEY_3],
		"choice_skip": [KEY_X], "titan_core": [KEY_V], "titan_dash": [KEY_SHIFT],
		"run_restart": [KEY_ENTER], "give_gift": [KEY_G],
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
	# Normally the title screen did these; played straight from the editor, do them here.
	Prefs.apply_all()
	_use_save_slot()
	armory = Armory.open(armory_path)
	npc_talk = NpcTalk.new()
	npc_talk.save_path = npc_path
	add_child(npc_talk)
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
	tutorial = Tutorial.new()
	tutorial.name = "Tutorial"
	tutorial.run = self
	add_child(tutorial)
	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	pause_menu.run = self
	add_child(pause_menu)
	equip_loadout()
	if start_in_hub:
		enter_hub()
	else:
		start_run(run_seed, uncharted_zones, level_id)


## Reads and writes the save slot picked on the title screen (saves.gd). Left
## alone when a test pointed the saves somewhere of its own.
func _use_save_slot() -> void:
	var own_paths := armory_path != Armory.DEFAULT_PATH or npc_path != NpcTalk.DEFAULT_PATH
	if Saves.active == 0 and Tutorial.settings_path != Tutorial.SETTINGS:
		own_paths = true
	if own_paths:
		return
	if Saves.active == 0:
		Saves.migrate_legacy()
		var last := Saves.last_slot()
		Saves.use(last if last != 0 else 1)
	armory_path = Saves.armory_path()
	npc_path = Saves.npc_path()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Saves.flush()


## A run is under way (not in the hub, not on the summary after one).
func in_run() -> bool:
	return phase in [Phase.ZONE, Phase.CHOOSING, Phase.ARENA, Phase.FIGHT]


## The pause menu stays shut while a workbench or the paint shop is open.
func menu_blocked() -> bool:
	return bench != null or garage != null


## Pause menu: give up on this run. It ends like a lost one.
func abandon_run() -> void:
	if not in_run():
		return
	get_tree().paused = false
	hud.choice_panel.visible = false
	end_run("RUN ABANDONED", "Eco pulled out before the job was done.")


func start_run(seed_value: int, uncharted := 0, level := "") -> void:
	if seed_value == 0:
		seed_value = randi_range(1, 999999)
	run = RunState.new(seed_value, uncharted, level)
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
	# The closer she's grown to Mom, the gentler she talks on the run.
	var w: Node = pilot_hud.get("whispers") if pilot_hud != null else null
	if w != null:
		w.set("softness", Family.softness(npc_talk.state))
	load_zone(0)


func _fresh_level(level_name: String) -> void:
	if npc_talk != null:
		npc_talk.stop()
	if not rest_spot.is_empty():
		get_up()
		rest_spot = {}
		player.resting = false
		_set_rest_view(false)
	if zone_root != null:
		remove_child(zone_root)
		zone_root.free()
	zone_root = Node3D.new()
	zone_root.name = level_name
	zone_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(zone_root)


## Back to the temple: no run in progress, walk around, start one at the poster or the mission table.
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
	hub_npcs = {}
	for spec in zone_info.get("npcs", []):
		var npc := HubNpc.create(spec["who"], spec["pos"], spec["yaw"])
		npc.look_target = player
		zone_root.add_child(npc)
		npc.wear_for_run(runs_ended)
		NpcIdles.settle(npc, zone_info, runs_ended)
		hub_npcs[spec["who"]] = npc
	Townsfolk.populate(zone_root, player, runs_ended)
	family_scene = null
	if Family.enabled:
		family_scene = FamilyScene.new()
		zone_root.add_child(family_scene)
		family_scene.setup(self, zone_info)
	var sick := Family.roll_sick(npc_talk.state, runs_ended, last_result == "RUN COMPLETE", npc_talk.state.get_value("mom", "met", false), randf())
	npc_talk.state.save(npc_talk.save_path)
	if hub_npcs.has("ophelia"):
		NpcIdles.build_window(zone_root)
	Wardrobe.dress_eco(player, true)
	phase = Phase.HUB
	dress_hub()
	place_player(zone_info["spawn"])
	tutorial.start_level("hub")
	if last_result != "":
		hud.toast("Back at the temple." + ("  You're burning up. Go find Mom." if sick else ""), HUB_LINE_SECONDS)
		_whisper("home", 2.0)


func load_zone(index: int) -> void:
	_fresh_level("Zone")
	run.zone = index
	if index < run.zone_count:
		var loot_zone := index
		if run.level != "":
			zone_info = Levels.build(zone_root, run.rng, run.level)
			loot_zone = int(Levels.spec(run.level)["difficulty"])
		else:
			zone_info = ZoneBuilder.build_zone(zone_root, run.rng, index)
		loot_rng.seed = run.run_seed * 7919 + index
		Loot.scatter(zone_root, zone_info, loot_rng, loot_zone)
		# Gifts roll on their own generator, so they never shift the loot rolls.
		var gift_rng := RandomNumberGenerator.new()
		gift_rng.seed = run.run_seed * 104729 + index
		Gifts.scatter(zone_root, zone_info, gift_rng)
		for grunt in zone_info["grunts"]:
			grunt.target = player
			grunt.died.connect(_on_grunt_died)
			grunt.called_out.connect(func(_g, _squad): _alarm_raised = true)
		phase = Phase.ZONE
		var zone_name: String = zone_info.get("name", "")
		var uncharted := "UNCHARTED: " if index >= RunState.ZONE_COUNT else ""
		rescued = false
		escort = null
		_alarm_raised = false
		_set_prisoner_chatter(zone_info.has("holding_cell"))
		if run.level != "":
			hud.toast(Levels.title(run.level), 4.0)
		else:
			hud.toast("ZONE %d / %d: %s%s" % [index + 1, run.zone_count, uncharted, zone_name])
		_whisper("zone_start", 2.5)
	else:
		zone_info = ZoneBuilder.build_arena(zone_root)
		boss = zone_info["boss"]
		boss.defeated.connect(_on_boss_defeated)
		phase = Phase.ARENA
		evac_open = false
		hud.toast("THE FOREST'S EDGE: TITANFALL STANDING BY")
	Wardrobe.dress_eco(player, false)
	place_player(zone_info["spawn"])
	player.second_wind_ready = player.second_wind  # Eco's suit: once per zone
	if run.level != "":
		tutorial.start_level(run.level)
	else:
		tutorial.start_level("zone%d" % index if index < run.zone_count else "arena")


func place_player(pos: Vector3) -> void:
	checkpoint = pos
	player.spawn_transform = Transform3D(Basis(), pos)
	player.respawn()


func _physics_process(delta: float) -> void:
	Saves.tick(delta)
	player.strolling = phase == Phase.HUB and not on_training_ground()
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
					start_run(0, uncharted_zones, level_id)
		Phase.HUB:
			_hub_tick(delta)
	_update_hud()


# --- Hub ----------------------------------------------------------------------

func _hub_tick(delta: float) -> void:
	if bench != null:
		if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_cancel"):
			close_bench()
		return
	if garage != null:
		if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_cancel"):
			close_garage()
		return
	if hub_piloting:
		if Input.is_action_just_pressed("interact"):
			disembark_hub_titan()
		return
	# Falling out of the world in the hub costs nothing: back inside the door.
	if player.global_position.y < float(zone_info["floor_y"]) - KILL_DEPTH:
		place_player(zone_info["spawn"])
		return
	if not rest_spot.is_empty():
		_rest_tick()
		return
	if npc_talk.active():
		npc_talk.tick(delta, player.global_position)
		if not npc_talk.options.is_empty():
			for i in npc_talk.options.size():
				if Input.is_action_just_pressed("choice_%d" % (i + 1)):
					npc_talk.choose(i)
					break
		elif Input.is_action_just_pressed("interact"):
			npc_talk.advance()
		return
	_course_tick(delta)
	if Input.is_action_just_pressed("titan_core") and in_titan_yard():
		call_hub_titan()
		return
	if _hub_titan_in_reach() and Input.is_action_just_pressed("interact"):
		embark_hub_titan()
		return
	var spot := nearest_hub_spot()
	if spot.has("npc") and Input.is_action_just_pressed("give_gift") and npc_talk.can_give(spot["npc"], runs_ended):
		npc_talk.offer_gifts(hub_npcs[spot["npc"]], runs_ended)
		return
	if spot.is_empty() or not Input.is_action_just_pressed("interact"):
		return
	if spot["id"] == "tutorial_poster":
		start_run(run_seed)
		return
	if spot["id"] == "uncharted_map":
		start_run(run_seed, RunState.UNCHARTED_ZONES)
		return
	if spot.has("level"):
		var id: String = spot["level"]
		if Levels.unlocked(id, armory.cleared_levels()):
			start_run(run_seed, 0, id)
		elif Levels.spec(id)["needs"] == "tutorial":
			hud.toast("Not yet. Get through the Pinewoods run and bring a titan home first.", HUB_LINE_SECONDS)
		else:
			hud.toast("Not yet. Clear %s first." % Levels.title(Levels.spec(id)["needs"]), HUB_LINE_SECONDS)
		return
	if spot.has("screen"):
		open_bench(spot["screen"])
		return
	if spot["id"] == "garage":
		open_garage()
		return
	if spot.has("npc"):
		talk_to(spot["npc"])
		return
	if spot.has("family"):
		family_scene.use()
		return
	if spot.has("rest"):
		rest_at(spot)
	var lines: Array = spot["lines"]
	var n: int = hub_reads.get(spot["id"], 0)
	hub_reads[spot["id"]] = n + 1
	hud.toast(lines[n % lines.size()], HUB_LINE_SECONDS)


## Eco sits or lies down at a hub spot with a "rest" entry ({pose, at, seat,
## alt}: hub_builder.gd): the view goes to third person while she rests, and
## you can look around her. F at a spot with an "alt" pose moves her between
## the two (sit up, stretch out); F anywhere else, jump or a move key gets her up.
func rest_at(spot: Dictionary, alt := false) -> void:
	var eco_body := player.get_node_or_null("EcoBody")
	if eco_body == null or not eco_body.has_method("rest"):
		return
	var rest: Dictionary = spot["rest"]
	var pose: Dictionary = rest["alt"] if alt else rest
	if rest_spot.is_empty():
		player.resting = true
		_set_rest_view(true)
		# face her where she settles, looking down a little
		var at: Vector3 = (pose["at"] as Transform3D).origin
		var to := Vector2(at.x - player.global_position.x, at.z - player.global_position.z)
		if to.length() > 0.3:
			player.rotation.y = atan2(-to.x, -to.y)
		player.head.rotation.x = deg_to_rad(-22.0)
	rest_spot = spot
	rest_pose = pose["pose"]
	eco_body.rest(rest_pose, pose["at"], float(rest.get("seat", 0.5)))


## Gets Eco back on her feet; the player is free once she's up (_rest_tick).
func get_up() -> void:
	var eco_body := player.get_node_or_null("EcoBody")
	if eco_body != null:
		eco_body.get_up()
	rest_pose = ""


func _rest_tick() -> void:
	var eco_body := player.get_node_or_null("EcoBody")
	if rest_pose == "":
		if eco_body == null or not eco_body.is_resting():
			rest_spot = {}
			player.resting = false
			_set_rest_view(false)
		return
	var moving := Input.get_vector("move_left", "move_right", "move_forward", "move_back") != Vector2.ZERO
	if moving or Input.is_action_just_pressed("jump"):
		get_up()
	elif Input.is_action_just_pressed("interact"):
		var rest: Dictionary = rest_spot["rest"]
		if rest.has("alt"):
			rest_at(rest_spot, rest_pose == rest["pose"])
		else:
			get_up()


## Resting shows her in third person (whatever the F5 view) with the gun and
## knife put away; getting up puts the player's view back.
func _set_rest_view(on: bool) -> void:
	var view := player.get_node_or_null("ViewCam")
	if view != null:
		view.set_third_person(on or ViewCamera.prefer_third_person)
	for path in ["Head/Camera3D/Weapon", "Head/Camera3D/Knife"]:
		var n := player.get_node_or_null(path)
		if n != null:
			n.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT


## The prompt while she rests.
func _rest_prompt() -> String:
	if rest_pose == "":
		return ""
	var rest: Dictionary = rest_spot["rest"]
	if rest.has("alt"):
		var other := "Stretch out" if rest_pose == rest["pose"] else "Sit up"
		return "[F] %s    [Space] Get up" % other
	return "[F] Get up"


## Starts a conversation between Eco and one of the people in the hub.
func talk_to(who: String) -> void:
	# Sick: once Mom has said her piece about the run, she puts Eco to bed.
	if who == "mom" and family_scene != null and int(npc_talk.state.get_value("mom", "run_seen", 0)) >= runs_ended and family_scene.care():
		return
	if hub_npcs.has(who):
		npc_talk.start(hub_npcs[who], runs_ended, last_result == "RUN COMPLETE")


## The people Eco can romance, for the gift shop's taste notes:
## [{who, name, likes, dislikes, affection}].
func romance_partners() -> Array:
	var out := []
	for who in hub_npcs:
		if not npc_talk.romanceable(who):
			continue
		var s: Dictionary = NpcTalk.Romance.settings(npc_talk.bank(who))
		out.append({"who": who, "name": String(NpcTalk.NAMES.get(who, who)).capitalize(),
				"likes": s["likes"], "dislikes": s["dislikes"], "affection": npc_talk.affection(who)})
	return out


## Opens Eco's paint shop on the chassis of your last titan, pausing the hub.
func open_garage() -> void:
	garage = Garage.new(last_parts.get("chassis", {}).get("id", "atlas"))
	add_child(garage)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.visible = false
	pilot_hud.visible = false


func close_garage() -> void:
	garage.queue_free()
	garage = null
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.visible = true
	pilot_hud.visible = true
	dress_hub()
	if hub_titan != null:
		hud.toast("Call your titan again (V) to see the new paint.", HUB_LINE_SECONDS)


## Opens a workbench screen ("gunsmith", "rack", "workshop" or "suit"), or a
## town shop's ("salon", "gifts"), pausing the hub.
func open_bench(kind: String) -> void:
	if kind == "gifts":
		bench = GiftScreen.new(armory, npc_talk, romance_partners())
	elif kind == "salon":
		bench = SalonScreen.new()
	elif kind == "wardrobe":
		bench = WardrobeScreen.new(runs_ended)
	else:
		bench = GunsmithScreen.new(armory) if kind == "gunsmith" else BenchScreen.new(armory, kind)
	add_child(bench)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.visible = false
	pilot_hud.visible = false


func close_bench() -> void:
	if bench is GiftScreen and not bench.bought.is_empty():
		var names: Array = bench.bought.map(func(id): return GiftShop.gift_name(id))
		hud.toast("Bought: %s. Press G by someone in the hub to give one." % ", ".join(names), HUB_LINE_SECONDS)
	if not bench.unlocked.is_empty():
		var names: Array = bench.unlocked.map(func(id): return Armory.WEAPONS[id]["name"].to_upper())
		hud.toast("LEVEL %d: %s UNLOCKED. PICK %s AT THE WEAPON RACK" % [armory.pilot_level(), " AND ".join(names), "IT" if names.size() == 1 else "THEM"], 5.0)
	if bench is WardrobeScreen and not bench.changed.is_empty():
		for npc in hub_npcs.values():
			npc.wear_for_run(runs_ended)
		Wardrobe.dress_eco(player, true)
	bench.queue_free()
	bench = null
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.visible = true
	pilot_hud.visible = true
	equip_loadout()
	dress_hub()


## Puts the gun picked at the weapon rack, upgraded and fitted, in Eco's hand,
## the knife picked at the knife case in the other, and her suit upgrade
## (suit locker) on her.
func equip_loadout() -> void:
	player.get_node("Head/Camera3D/Weapon").equip(armory.weapon_profile())
	player.get_node("Head/Camera3D/Knife").set_model(armory.knife)
	player.apply_suit(armory.suit_profile())


## Shows whether each level on the mission table is open, turns the marker
## over the tutorial poster off once that run is won, and shows the armory on
## the benches: the equipped gun on the gunsmith's mat,
## the guns you own on the rack (locked slots stay empty under a tag), her
## three knives under the knife case's glass (the one she carries tagged), and
## the titan you'd start a run with standing in the workshop's gantry.
func dress_hub() -> void:
	var marker: Node3D = zone_info.get("tutorial_marker")
	if marker != null:
		marker.visible = not "tutorial" in armory.cleared_levels()
	for board in zone_info.get("level_boards", []):
		var id: String = board["id"]
		var open := Levels.unlocked(id, armory.cleared_levels())
		var label: Label3D = board["label"]
		label.text = Levels.title(id) + ("" if open else "\n(locked)")
		label.modulate = Color(1.0, 0.55, 0.4) if open else Color(0.6, 0.58, 0.55)
		var need: String = Levels.spec(id)["needs"]
		var first := "win the Pinewoods run first" if need == "tutorial" else "clear %s first" % Levels.title(need)
		for spot in zone_info["interactables"]:
			if spot.get("level", "") == id:
				spot["prompt"] = "[F] Head out: %s" % Levels.title(id) if open else "%s: %s" % [Levels.title(id), first]
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
		tag.font_size = 44
		tag.pixel_size = 0.002
		tag.shaded = false
		tag.position = Vector3(0, -0.42, 0.02)
		tag.outline_size = 8
		slot.add_child(tag)
		if armory.owns_weapon(id):
			var gun := Weapon.gun_model(armory.weapon_profile(id))
			gun.scale = Vector3.ONE * 2.2
			gun.rotation_degrees = Vector3(0, 90, 0)
			slot.add_child(gun)
			tag.text = "IN HAND" if id == armory.equipped else Armory.WEAPONS[id]["short"]
			tag.modulate = Color(1.0, 0.8, 0.35) if id == armory.equipped else Color(0.9, 0.88, 0.82)
		else:
			tag.text = "LEVEL %d" % Armory.unlock_level(id) if armory.level_locked(id) else "LOCKED"
			tag.modulate = Color(0.6, 0.6, 0.62)
	var knife_slots: Array = zone_info.get("knife_slots", [])
	var knife_ids: Array = Armory.KNIVES.keys()
	for i in mini(knife_slots.size(), knife_ids.size()):
		var slot: Node3D = knife_slots[i]
		if slot == null:
			continue
		for c in slot.get_children():
			c.free()
		var id: String = knife_ids[i]
		var blade := Knife.knife_model(id)
		blade.scale = Vector3.ONE * 1.35  # lies flat, point to the back of the case
		slot.add_child(blade)
		var tag := Label3D.new()
		tag.font_size = 40
		tag.pixel_size = 0.0016
		tag.shaded = false
		tag.outline_size = 8
		tag.rotation_degrees = Vector3(-90, 0, 0)
		tag.position = Vector3(0, 0.003, 0.2)
		tag.text = "CARRIED" if id == armory.knife else Armory.KNIVES[id]["short"]
		tag.modulate = Color(1.0, 0.8, 0.35) if id == armory.knife else Color(0.9, 0.88, 0.82)
		slot.add_child(tag)
	var stand: Node3D = zone_info.get("workshop_titan")
	if stand != null:
		for c in stand.get_children():
			c.free()
		var parts := armory.start_parts()
		var titan := Art.titan(parts.get("chassis", {}).get("id", "scrap"), parts.get("weapon", {}).get("id", "scrap"))
		var chassis: String = parts.get("chassis", {}).get("id", "scrap")
		TitanStyle.apply(titan, chassis, TitanStyle.load_style(chassis))
		titan.scale = Vector3.ONE * 0.6
		stand.add_child(titan)


## A pickup reached the pilot.
func collect_material(kind: String, amount: int) -> void:
	if run == null or phase == Phase.HUB:
		return
	run.materials[kind] = int(run.materials.get(kind, 0)) + amount


## Eco walked into a gift (gifts.gd): into the bag for the hub, kept even if
## the run is lost.
func collect_gift(id: String) -> void:
	if run == null or phase == Phase.HUB:
		return
	npc_talk.add_gift(id)
	hud.toast("GIFT: %s\n%s" % [Gifts.display_name(id).to_upper(), Gifts.CATALOG.get(id, ["", ""])[1]], 4.0)


## Grunts drop scrap where they fall, sometimes a circuit.
func _on_grunt_died(grunt: Node) -> void:
	if run == null or zone_root == null or not is_instance_valid(grunt):
		return
	run.kills += 1
	Loot.drop(zone_root, grunt.global_position, Loot.roll_grunt(loot_rng, run.zone), loot_rng)
	tutorial.event("loot")


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
		tutorial.event("loot")


## Whether Eco is on the hub's training grounds (zone_info["training_areas"]:
## the range, the movement course, the titan yard), where she moves at full
## speed instead of strolling. A builder adds a Rect2 (x, z) there to make
## another area one.
func on_training_ground() -> bool:
	var at := Vector2(player.global_position.x, player.global_position.z)
	for area: Rect2 in zone_info.get("training_areas", []):
		if area.has_point(at):
			return true
	return false


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
	_rescue_nag -= delta
	var cell := holding_cell_in_reach()
	if cell != null and Input.is_action_just_pressed("interact"):
		rescue(cell)
		return
	if escort != null and escort.in_reach(player.global_position) and Input.is_action_just_pressed("interact"):
		_escort_order()
		return
	var cache := nearest_cache()
	if cache != null and Input.is_action_just_pressed("interact"):
		open_salvage(cache)
		return
	if cache == null:
		_loot_tick(delta)
	if zone_info.has("arena") and player.global_position.z < zone_info["arena"]["enter_z"]:
		if not rescue_pending():
			_enter_finale()
			return
		if _rescue_nag <= 0.0:
			_rescue_nag = 8.0
			hud.toast("Not leaving without %s. The holding block's back up the street." % _rescue_name(), 4.0)
	if zone_info["beacon"] != null and zone_info["beacon"].contains(player.global_position):
		if zone_info.has("holding_cell"):
			_exfil()
		else:
			load_zone(run.zone + 1)


## A level's clearing: their titan is waiting, so it's the arena from here,
## in the same zone. Grunts still about keep shooting.
func _enter_finale() -> void:
	boss = zone_info["boss"]
	boss.defeated.connect(_on_boss_defeated)
	phase = Phase.ARENA
	evac_open = false
	hud.toast("ENEMY TITAN ON THE ROAD: TITANFALL STANDING BY", 4.0)
	_whisper("titanfall", 0.5)
	tutorial.start_level("arena")


## Whether this level's prisoner (levels.gd "rescue") is still in the cell.
func rescue_pending() -> bool:
	return zone_info.has("holding_cell") and not rescued


func _rescue_name() -> String:
	return String(Levels.spec(run.level).get("rescue", "them")).capitalize()


## The holding cell, when Eco's at its screen and the prisoner's still inside.
func holding_cell_in_reach() -> Node3D:
	var cell: Node3D = zone_info.get("holding_cell")
	if cell == null or cell.opened or not cell.in_range(player.global_position):
		return null
	return cell


## Drops the cell's screen and breaks the prisoner's chains. They have a
## word, then follow Eco out (escort.gd) to the exfil.
func rescue(cell: Node3D) -> void:
	if not cell.release():
		return
	rescued = true
	_set_prisoner_chatter(false)
	tutorial.event("rescued")
	var who: Node3D = cell.ophelia
	if who != null:
		escort = Escort.new()
		escort.name = "Escort"
		escort.npc = who
		escort.pilot = player
		zone_root.add_child(escort)
		zone_info["escort"] = escort
	var lines: Array = Levels.spec(run.level).get("rescue_lines", [])
	var t := 0.0
	for line in lines:
		if t == 0.0:
			hud.toast(line, 3.6)
		else:
			get_tree().create_timer(t, false, true).timeout.connect(_rescue_line.bind(line))
		t += 3.4
	get_tree().create_timer(t, false, true).timeout.connect(_rescue_line.bind(
			"GET %s OUT: BACK TO THE EXFIL WHERE YOU CAME IN.  [F] BY HER: WAIT / FOLLOW" % _rescue_name().to_upper()))


func _rescue_line(line: String) -> void:
	if phase == Phase.ZONE and rescued:
		hud.toast(line, 3.6)


## [F] next to them: wait here, or come on.
func _escort_order() -> void:
	escort.toggle_wait()
	var n := _rescue_name()
	hud.toast(("%s: Okay. Here. Don't forget me." % n.to_upper()) if escort.waiting else ("%s: Right behind you." % n.to_upper()), 2.5)


## The way out on a rescue level: only with them out and close behind.
func _exfil() -> void:
	if not rescued:
		return
	if escort != null and escort.npc.global_position.distance_to(player.global_position) < EXFIL_TOGETHER:
		end_run("RUN COMPLETE", "%s's out. The district never woke up." % _rescue_name() if not _alarm_raised else "%s's out. Loud, but out." % _rescue_name())
	elif _rescue_nag <= 0.0:
		_rescue_nag = 6.0
		hud.toast("Not without %s. Go back for her." % _rescue_name(), 3.5)


func _set_prisoner_chatter(on: bool) -> void:
	var radio = pilot_hud.get("radio") if pilot_hud != null else null
	if radio != null and "extra_rumor" in radio:
		radio.extra_rumor = "prisoner" if on else ""


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
		tutorial.event("fell")
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
		tutorial.event("downed")


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
		tutorial.event("locked")
		return
	open_cache = cache
	var tier_zone := run.zone
	if run.level != "":
		tier_zone = int(Levels.spec(run.level)["difficulty"]) - 2  # past the tutorial's last zone
	offer = TitanParts.roll_offer(run.rng, tier_zone + int(cache.get_meta("part_bonus", 0)), OFFER_SIZE)
	phase = Phase.CHOOSING
	get_tree().paused = true
	tutorial.event("choosing")
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
		_whisper("part_installed", 1.0)
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
	if zone_info.has("arena"):
		var r: Rect2 = zone_info["arena"]["rect"]
		drop.x = clampf(drop.x, r.position.x, r.end.x)
		drop.z = clampf(drop.z, r.position.y, r.end.y)
	else:
		var half: float = zone_info["half_size"]
		drop.x = clampf(drop.x, -half, half)
		drop.z = clampf(drop.z, -half, half)
	zone_root.add_child(titan)
	titan.global_position = Vector3(drop.x, TITAN_DROP_HEIGHT, drop.z)
	titan.rotation.y = atan2(-(boss.global_position.x - drop.x), -(boss.global_position.z - drop.z))
	titan.destroyed.connect(_on_titan_destroyed)
	titan.landed.connect(func(): hud.toast("TITAN ON THE GROUND"))
	hud.toast("STANDBY FOR TITANFALL")
	_whisper("titanfall", 1.0)


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
## Eco pulls its targeting core first (Armory.BOSS_DROP: what the smart
## pistol's upgrades run on), and keeps it even if the run is lost after.
func _on_boss_defeated() -> void:
	for m in Armory.BOSS_DROP:
		collect_material(m, Armory.BOSS_DROP[m])
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
	hud.toast("ENEMY TITAN DOWN. LOCK CORE SALVAGED. GET TO THE EVAC PAD", 5.0)
	_whisper("boss_down", 1.5)


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
	runs_ended += 1
	last_parts = run.parts.duplicate()
	var won := title == "RUN COMPLETE"
	if won:
		armory.mark_cleared(run.level if run.level != "" else "tutorial")
	var haul := Armory.run_haul(run.materials, won)
	armory.bank(haul)
	Saves.record_run(won)
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
	lines.append("BANKED: %s%s" % [_materials_text(haul), "  (titan salvage included)" if won else "  (half of what you carried, lock cores kept)"])
	lines.append("")
	lines.append("[Enter] back to the temple" if start_in_hub else "[Enter] new run")
	hud.summary_label.text = "\n".join(lines)
	hud.summary_panel.visible = true


# --- HUD ----------------------------------------------------------------------

## Eco mutters about a beat of the run (eco_whisper_lines.gd).
func _whisper(category: String, delay := 0.0) -> void:
	var w: Node = pilot_hud.get("whispers") if pilot_hud != null else null
	if w != null:
		w.say(category, delay)


func _update_hud() -> void:
	hud.build_label.visible = phase != Phase.HUB
	if phase == Phase.HUB:
		var status := "THE TEMPLE    LEVEL %d    %s    Runs %d" % [armory.pilot_level(), _materials_text(armory.stash), runs_started]
		if last_result != "":
			status += "    Last run: %s" % last_result
		if course_time >= 0.0:
			status += "    COURSE %.1f s" % course_time
		elif course_best > 0.0:
			status += "    Course best %.2f s" % course_best
		hud.status_label.text = status + "\nHead out from the poster outside or the mission table in the hall. F looks at things and works the benches."
		hud.prompt_label.text = _prompt()
		hud.crosshair.visible = hub_piloting
		hud.fight_label.visible = hub_piloting
		if hub_piloting:
			var dash_text := "%d/%d" % [hub_titan.dashes, int(hub_titan.stats["dashes"])]
			hud.fight_label.text = "PRACTICE TITAN    DASH [Shift] %s    Left mouse fire\n[F] Climb out" % dash_text
		return
	var where := "ZONE %d/%d" % [run.zone + 1, run.zone_count] if run.zone < run.zone_count else "FINAL"
	if run.level != "":
		where = "LEVEL %d" % Levels.spec(run.level)["number"] + ("  FINAL" if phase in [Phase.ARENA, Phase.FIGHT] else "")
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
			if npc_talk.active():
				return ""
			if not rest_spot.is_empty():
				return _rest_prompt()
			if course_armed:
				return "Leave the pad to start the clock"
			var spot := nearest_hub_spot()
			if not spot.is_empty():
				if spot.has("family"):
					return family_scene.prompt()
				if spot.get("npc", "") == "mom" and Family.sick(npc_talk.state, runs_ended):
					return spot["prompt"] + "  (you're burning up)"
				var text: String = spot["prompt"]
				if spot.has("npc") and npc_talk.beat_waiting(spot["npc"], runs_ended):
					text += "  (wants to talk)"
				if spot.has("npc") and npc_talk.can_give(spot["npc"], runs_ended):
					text += "    [G] Give a gift"
				return text
			if in_titan_yard():
				return "[V] Call in your titan" if hub_titan == null else "[V] Call your titan here"
		Phase.ZONE:
			var cell := holding_cell_in_reach()
			if cell != null:
				return "[F] Short the screen and break her chains"
			if escort != null and escort.in_reach(player.global_position):
				return "[F] %s: come on" % _rescue_name() if escort.waiting else "[F] %s: wait here" % _rescue_name()
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
	return "SCRAP %d  ALLOY %d  CIRCUITS %d  LOCK CORES %d" % [int(m.get("scrap", 0)), int(m.get("alloy", 0)), int(m.get("circuits", 0)), int(m.get("lock_cores", 0))]


func _clock(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]
