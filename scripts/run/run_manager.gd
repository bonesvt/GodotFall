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
const SuitScreen := preload("res://scripts/hub/suit_screen.gd")
const GiftScreen := preload("res://scripts/hub/gift_screen.gd")
const GiftShop := preload("res://scripts/hub/gift_shop.gd")
const SalonScreen := preload("res://scripts/hub/salon_screen.gd")
const WardrobeScreen := preload("res://scripts/hub/wardrobe_screen.gd")
const TownShopScreen := preload("res://scripts/hub/town_shop_screen.gd")
const TownShops := preload("res://scripts/hub/town_shops.gd")
const Wardrobe := preload("res://scripts/hub/wardrobe.gd")
const Loot := preload("res://scripts/run/loot.gd")
const Gifts := preload("res://scripts/run/gifts.gd")
const NpcIdles := preload("res://scripts/hub/npc_idles.gd")
const SmokeDate := preload("res://scripts/hub/smoke_date.gd")
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
const BattleDamage := preload("res://scripts/ps2/battle_damage.gd")
const Saves := preload("res://scripts/game/saves.gd")
const PauseMenu := preload("res://scripts/ui/pause_menu.gd")
const Vices := preload("res://scripts/hub/vices.gd")
const BarScreen := preload("res://scripts/hub/bar_screen.gd")
const StimScreen := preload("res://scripts/hub/stim_screen.gd")
const HushScreen := preload("res://scripts/hub/hush_screen.gd")
const HushDen := preload("res://scripts/hub/hush_den.gd")
const DrunkScreen := preload("res://scripts/ui/drunk_screen.gd")
const CravingScreen := preload("res://scripts/ui/craving_screen.gd")
const HushPull := preload("res://scripts/hub/hush_pull.gd")
const SuperHushScene := preload("res://scripts/hub/super_hush_scene.gd")
const FittingScene := preload("res://scripts/hub/fitting_scene.gd")
const DoseScene := preload("res://scripts/hub/dose_scene.gd")
const CheatScreen := preload("res://scripts/hub/cheat_screen.gd")
const Hymn := preload("res://scripts/hub/hymn.gd")
const DispensaryScreen := preload("res://scripts/hub/dispensary_screen.gd")
const GearOffScreen := preload("res://scripts/hub/gear_off_screen.gd")
const Obsession := preload("res://scripts/hub/obsession.gd")
const ObsessionScreen := preload("res://scripts/hub/obsession_screen.gd")
const LACED := "This one's sweeter than it should be. Rose, under the tobacco. Eco thinks of Ophelia, and can't stop."
const SMOKE_LOCKED := "Ophelia won't come out back for a smoke right now. \"You've got your own. The ones I gave you.\""
const PACK_GIFT := "Ophelia presses a pack of Night Owls into Eco's hand and closes her fingers round it. \"For out there. So you think of me.\""
const HOME_PULL := "Eco keeps looking back the way she came. Ophelia's waiting. She should get home."
const PAPERS := "Under Ophelia's pillow: a tin. A jar of something pink and sweet and three Night Owls with a rose stain at the filter, like the ones in the packs she's been giving Eco. A label in her handwriting: KEEPSAKE. She's been drugging her."
const Shepherd := preload("res://scripts/hub/shepherd.gd")
const VisorScreen := preload("res://scripts/ui/visor_screen.gd")
const VisorFriends := preload("res://scripts/run/visor_friends.gd")
const ObsessionLook := preload("res://scripts/hub/obsession_look.gd")
const HubGrip := preload("res://scripts/hub/hub_grip.gd")
const ColonyGear := preload("res://scripts/hub/colony_gear.gd")
const TAKEN_WITH := "%s was taken with her. She's on the bench beside Eco, wearing the colony's %s, smiling. \"I feel so calm.\""
const DEAF := "%s doesn't look up. Eco says her name again. Nothing. The headphones hum. Then %s blinks: \"Sorry, did you say something?\""
## Where the Shepherd comes out, from the dispensary's spot (its back door).
const DISPENSARY_BACK_DOOR := Vector3(-0.5, 0.1, 4.5)
const BRIDGE_PUFF := "The bridge hisses up her nose. Lavender. Linen. Calm."
const CUFF_DOSED := "The cuff hisses. Something cold goes into her wrist, and then the calm comes: white, quiet, everywhere. Hymn."
const Glass := preload("res://scripts/hub/glass.gd")
const ViceLooks := preload("res://scripts/hub/vice_looks.gd")
const Tether := preload("res://scripts/run/tether.gd")
const ChorusScene := preload("res://scripts/hub/chorus_scene.gd")
const Soundscape := preload("res://scripts/soundscape.gd")
const SFX := preload("res://scripts/sfx.gd")
const Weather := preload("res://scripts/game/weather.gd")

const FALL_DAMAGE := 25
## Integrity lost when grunts take the pilot's health to zero.
const DOWNED_DAMAGE := 25
## How far below the lowest platform counts as a fall.
const KILL_DEPTH := 15.0
## Opening and closing each hub screen (open_bench kind -> [open, close]).
const BENCH_SOUNDS := {
	"wardrobe": ["wardrobe_open", "wardrobe_close"],
	"gifts": ["shop_bell", ""], "salon": ["shop_bell", ""],
}
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
## Mom smells smoke on Eco when she gets home (vices.gd).
## What she says going through Marrow's doors (hush_den.gd teleport spots).
const TELEPORT_LINES := {
	"cinema_cellar": "Down into the violet dark.",
	"cellar_stairs": "Up into the street. The air tastes clean.",
	"her_room": "Key, lock, in. She shuts it behind her and checks the weld.",
	"her_room_door": "Back out into his basement.",
	"physics_lab": "Down the ladder to the lab. Time to see what gives.",
	"physics_lab_exit": "Back up into the temple.",
}
## Ophelia notices Eco slipping away while Marrow's Hold is deep (vices.gd).
const OPHELIA_NOTICES := [
	"Ophelia: \"Where do you keep going? You come back and look straight through me.\"",
	"Ophelia: \"Your eyes are doing that purple thing again. Don't tell me it's nothing.\"",
	"Ophelia: \"I waited up. Again. Whatever it is, I'm not going anywhere. Just... come back.\"",
]
## When Marrow's Hold is first full: the Hush courier suit (vices.gd hush_suit).
## When Marrow's Hold reaches 60: the Hush gun finish (vices.gd hush_finish).
## The Chorus (glass.gd): smashing his vats, and the alley once he's gone.
const VAT_LINES := [
	"Eco brings her wrench down on the vat. Glass everywhere, violet and steaming. Two to go.",
	"Another one bursts across the floor. Her eyes sting. One to go.",
	"The last vat splits open. Somewhere upstairs a door bangs. He's coming down. Face him at his table.",
]
const MARROW_GONE := "The gap by the arcade is empty. Just a violet lamp, and a coat he left behind."
const HUSH_FINISH_LINE := "Marrow presses a tin of violet resin lacquer into her hand. Marrow: \"For your little gun. So you think of me every time you pull the trigger.\" New finish at the gunsmith's bench: Hush."
const HUSH_SUIT_LINE := "A parcel on her bed, wrapped in violet paper. Marrow's courier suit, cut to her size. A card: \"For my best runner. Wear it.\" It's in her wardrobe."
const MOM_SMELLS := [
	"Mom: \"You smell like the Halo's back step. Don't lie to me, I can smell it.\"",
	"Mom: \"Smoke in your hair again. Your father quit for you, you know.\"",
	"Mom: \"Open a window up there. And wash that jacket.\"",
]

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
## Who's only in the hub once Eco has got them out (levels.gd "rescue"),
## by the level that rescues them.
const RESCUED_IN := {"ophelia": "level2"}
## Romance affection the rescue starts them on (romance.gd STAGES: "wary"),
## given once.
const RESCUE_AFFECTION := 15
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
## the rest pose she's in there (spot["rest"], its "alt" or one of its "more").
var rest_spot := {}
var rest_pose := ""
## Which of the spot's poses she is in (rest_options).
var rest_index := 0
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
## A BenchScreen, the GunsmithScreen at the gunsmith bench, the SuitScreen at
## the suit locker, or the SalonScreen.
var bench = null
## Marrow's pull at full Hold (hush_pull.gd): walks her to his basement.
var hush_pull: HushPull
## The cheat box's Super Hush, played out (super_hush_scene.gd).
var super_hush_scene: SuperHushScene
## The Shepherd's gear going on her in the dispensary's back room (fitting_scene.gd).
var fitting_scene: FittingScene
## The morning dose at the dispensary, played out (dose_scene.gd).
var dose_scene: DoseScene
## The clarity visor's lie on runs: grunts wearing her people's faces (visor_friends.gd).
var visor_friends: Node
## Who the Shepherd took with her this time, for when she comes to (hub_grip.gd).
var _taken_with := ""
## Marrow's Glass on runs (focus, his orders: tether.gd) and the Chorus's end (chorus_scene.gd).
var tether: Tether
var chorus_scene: ChorusScene
## What she grabbed by mistake for this run, deep in Marrow's Hold
## (vices.gd wrong_gear): put right when she gets home.
var mixed_up := {}
var gear_rng := RandomNumberGenerator.new()
## Rolls for her lines drifting off (vices.gd confuse).
var drift_rng := RandomNumberGenerator.new()
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
		"run_restart": [KEY_ENTER], "give_gift": [KEY_G], "smoke": [KEY_B], "stim": [KEY_N],
		"focus": [KEY_L], "tune_out": [KEY_K],
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
	gear_rng.randomize()
	drift_rng.randomize()
	add_to_group("loot_collector")
	ensure_input_actions()
	# Normally the title screen did these; played straight from the editor, do them here.
	Prefs.apply_all()
	_use_save_slot()
	armory = Armory.open(armory_path)
	Vices.open(armory_path.get_basename() + "_vices.cfg")
	Glass.open(Glass.path_for(Vices.save_path))
	Hymn.open(Hymn.path_for(Vices.save_path))
	ViceLooks.open(ViceLooks.path_for(Vices.save_path))
	Obsession.open(Obsession.path_for(Vices.save_path))
	HubGrip.open(HubGrip.path_for(Vices.save_path))
	tether = Tether.new(self)
	add_child(tether)
	chorus_scene = ChorusScene.new(self)
	add_child(chorus_scene)
	hush_pull = HushPull.new(self)
	add_child(hush_pull)
	super_hush_scene = SuperHushScene.new(self)
	add_child(super_hush_scene)
	fitting_scene = FittingScene.new(self)
	add_child(fitting_scene)
	dose_scene = DoseScene.new(self)
	add_child(dose_scene)
	visor_friends = VisorFriends.new(self)
	add_child(visor_friends)
	npc_talk = NpcTalk.new()
	npc_talk.save_path = npc_path
	add_child(npc_talk)
	player = PLAYER_SCENE.instantiate()
	player.name = "Player"
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	player.died.connect(_on_pilot_downed)
	player.damaged.connect(_on_pilot_hit)
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
	var drunk := DrunkScreen.new()
	drunk.name = "DrunkScreen"
	add_child(drunk)
	add_child(VisorScreen.new(self))
	var craving := CravingScreen.new()
	craving.name = "CravingScreen"
	add_child(craving)
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
	if phase == Phase.HUB:  # did she go and see Ophelia first? (obsession.gd)
		Obsession.run_started(NpcTalk.Romance.status(npc_talk.state, "ophelia") == "together", runs_ended)
	if seed_value == 0:
		seed_value = randi_range(1, 999999)
	run = RunState.new(seed_value, uncharted, level)
	for part in armory.start_parts().values():
		run.install(part)
	run.refits = armory.refit_bonus()
	runs_started += 1
	result = ""
	BattleDamage.reset()  # a clean suit for every run
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
	Vices.run_started()
	tether.stop()
	player.refresh_glass()
	var line := ""
	if Vices.hush() > 0.0:
		line = "The Hush settles in. Everything goes quiet, and sharp, and violet."
	elif Vices.in_withdrawal():
		line = Vices.withdrawal_line()
	elif Vices.craving() > 0.0:
		line = Vices.craving_line()
	elif Vices.effect() > 0.0:
		line = Vices.run_line()
	if _mix_up_gear():
		line = (line + "\n" if line != "" else "") + Vices.WRONG_GEAR_LINE + "\n" + _mixed_up_text()
	if Glass.tethered():
		line = (line + "\n" if line != "" else "") + "The earpiece clicks on. Marrow: \"I'm here. Do as I say out there.\""
	if line != "":
		hud.toast(line, HUB_LINE_SECONDS + (2.0 if not mixed_up.is_empty() else 0.0))


## Deep in Marrow's Hold she can head out with the wrong gun, knife or kit
## (vices.gd wrong_gear): on her for this run only. Returns whether she did.
func _mix_up_gear() -> bool:
	if not mixed_up.is_empty():
		equip_loadout()
	var guns: Array = Armory.WEAPONS.keys().filter(func(id): return armory.owns_weapon(id))
	mixed_up = Vices.wrong_gear(gear_rng, guns, armory.equipped, Armory.KNIVES.keys(), armory.knife,
			armory.suit_tier, armory.suit_weight, Armory.SUIT_WEIGHTS.keys())
	if mixed_up.is_empty():
		return false
	if mixed_up.has("weapon"):
		player.get_node("Head/Camera3D/Weapon").equip(armory.weapon_profile(mixed_up["weapon"]))
	if mixed_up.has("knife"):
		player.get_node("Head/Camera3D/Knife").set_model(mixed_up["knife"])
	if mixed_up.has("weight"):
		player.apply_suit(TownShops.boost(armory.suit_profile(-1, mixed_up["weight"])))
	return true


## What she's got on her by mistake, for the toast.
func _mixed_up_text() -> String:
	var bits := []
	if mixed_up.has("weapon"):
		bits.append("%s (she picked %s)" % [Armory.WEAPONS[mixed_up["weapon"]]["name"], Armory.WEAPONS[armory.equipped]["name"]])
	if mixed_up.has("knife"):
		bits.append("%s knife (she picked %s)" % [Armory.KNIVES[mixed_up["knife"]]["name"], Armory.KNIVES[armory.knife]["name"]])
	if mixed_up.has("weight"):
		bits.append("%s kit (she picked %s)" % [Armory.SUIT_WEIGHTS[mixed_up["weight"]]["name"], Armory.SUIT_WEIGHTS[armory.suit_weight]["name"]])
	return "Wrong gear: " + ", ".join(bits) + "."


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
	BattleDamage.reset()  # home: she washes up and patches her suit
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
	Weather.wind = Vector3.ZERO  # still air in the temple (the lab's fan aside)
	_hide_unrescued(zone_info)
	hub_npcs = {}
	for spec in zone_info.get("npcs", []):
		var npc := HubNpc.create(spec["who"], spec["pos"], spec["yaw"])
		npc.look_target = player
		zone_root.add_child(npc)
		npc.wear_for_run(runs_ended)
		NpcIdles.settle(npc, zone_info, runs_ended)
		if spec["who"] == "ophelia":
			ObsessionLook.dress(npc, zone_info)  # how her obsession shows on her this stay
		if spec["who"] in HubGrip.WHO:
			ColonyGear.apply(npc, HubGrip.gear_of(spec["who"]))  # what the Shepherd put on them
		hub_npcs[spec["who"]] = npc
	Townsfolk.populate(zone_root, player, runs_ended)
	Soundscape.hub(zone_root, zone_info)
	family_scene = null
	if Family.enabled:
		family_scene = FamilyScene.new()
		zone_root.add_child(family_scene)
		family_scene.setup(self, zone_info)
	var sick := Family.roll_sick(npc_talk.state, runs_ended, last_result == "RUN COMPLETE", npc_talk.state.get_value("mom", "met", false), randf())
	npc_talk.state.save(npc_talk.save_path)
	if hub_npcs.has("ophelia"):
		NpcIdles.build_window(zone_root)
	_grip_scene.call_deferred()  # someone she loves has gone further under (hub_grip.gd)
	Wardrobe.dress_eco(player, true)
	phase = Phase.HUB
	dress_hub()
	place_player(zone_info["spawn"])
	tutorial.start_level("hub")
	hush_pull.reset()
	super_hush_scene.reset()
	fitting_scene.reset()
	dose_scene.reset()
	chorus_scene.reset()
	tether.stop()
	if Hymn.hunted and Hymn.allowed():
		spawn_shepherd.call_deferred()  # it's still out for her
	player.refresh_glass()
	_dress_chorus()
	if not mixed_up.is_empty():  # home: her own gear again
		mixed_up = {}
		equip_loadout()
	if Vices.trance and Vices.allowed() and zone_info.has("hush"):
		_wake_at_marrows()
	elif last_result != "":
		var mom := ""
		if Vices.smoked and Vices.allowed() and hub_npcs.has("mom") and not sick:
			mom = "  " + MOM_SMELLS[runs_ended % MOM_SMELLS.size()]
		elif Vices.hold >= 30.0 and Vices.allowed() and hub_npcs.has("ophelia"):
			mom = "  " + OPHELIA_NOTICES[runs_ended % OPHELIA_NOTICES.size()]
		Vices.smoked = false
		hud.toast("Back at the temple." + ("  You're burning up. Go find Mom." if sick else "") + mom, HUB_LINE_SECONDS + (2.0 if mom != "" else 0.0))
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
	Soundscape.battle(zone_root, str(zone_root.get_meta("biome", "")))
	Weather.wind = zone_info.get("wind", Weather.for_biome(str(zone_root.get_meta("biome", run.level))))
	Wardrobe.dress_eco(player, false)
	place_player(zone_info["spawn"])
	player.second_wind_ready = player.second_wind  # Eco's suit: once per zone
	if run.level != "":
		tutorial.start_level(run.level)
	else:
		tutorial.start_level("zone%d" % index if index < run.zone_count else "arena")


## The physics lab's console: steps the Press into things setting round
## Off, 50%, 100%, 150%, 200%.
func _step_press_strength() -> void:
	var steps := [0.0, 0.5, 1.0, 1.5, 2.0]
	var now := Prefs.press_strength()
	var next: float = steps[0]
	for v: float in steps:
		if v > now + 0.01:
			next = v
			break
	Prefs.set_press_strength(next)
	hud.toast("Press into things: %s" % ("Off" if next < 0.05 else "%d%%" % roundi(next * 100)), 2.0)


## One of the people she loves has gone further under (hub_grip.gd): their scene,
## played as a talk with them, wherever they are.
func _grip_scene() -> void:
	if not HubGrip.allowed() or phase != Phase.HUB or npc_talk.active():
		return
	var scene := HubGrip.next_scene(hub_npcs.keys())
	if scene.is_empty():
		return
	npc_talk.stop()
	var them: Node3D = hub_npcs[scene[0]]
	# they're waiting for her: she starts in front of them, in talking range
	place_player(them.global_position - them.global_transform.basis.z * 1.4 + Vector3(0, 0.1, 0))
	npc_talk._play(them, scene[1])


## The Shepherd comes for her (hymn.gd), from the dispensary's back door.
func spawn_shepherd() -> void:
	if not Hymn.allowed() or phase != Phase.HUB or not get_tree().get_nodes_in_group("shepherd").is_empty():
		return
	var at := _dispensary_spot()
	if at == Vector3.INF:
		return
	zone_root.add_child(Shepherd.create(self, at + DISPENSARY_BACK_DOOR))


## Where the dispensary's spot is in this hub (INF: there isn't one).
func _dispensary_spot() -> Vector3:
	for spot in zone_info.get("interactables", []):
		if spot["id"] == "dispensary":
			return spot["pos"]
	return Vector3.INF


## The Shepherd brought her in (piece: the gear it's putting on her, "" for
## none left): the fitting in the dispensary's back room, or straight out.
func processed_by_shepherd(piece: String, with := "", with_piece := "") -> void:
	hush_pull.triggers.reset()
	if with != "" and with_piece != "":
		_taken_with = with
	if piece in Hymn.GEAR:
		fitting_scene.play(piece, with, with_piece)
	else:
		fitted(piece)


## The fitting's over: she wakes on the bench outside the dispensary, in it.
func fitted(_piece: String) -> void:
	player.set("entranced", false)
	if _taken_with != "" and hub_npcs.has(_taken_with):
		var them: Node3D = hub_npcs[_taken_with]
		ColonyGear.apply(them, HubGrip.gear_of(_taken_with))
		hud.toast(TAKEN_WITH % [HubGrip.NAMES[_taken_with], Hymn.GEAR_NAMES.get(HubGrip.gear_of(_taken_with).back(), "gear")], HUB_LINE_SECONDS + 2.0)
	_taken_with = ""
	var at := _dispensary_spot()
	if at != Vector3.INF:
		place_player(at + Vector3(1.2, 0.1, 0))
	Wardrobe.dress_eco(player, true)


## Hymn in the hub: the dose cuff counting down, and on the HUD.
func _tick_hymn(delta: float, roaming: bool) -> void:
	if Hymn.tick_bridge(delta):
		hud.toast(BRIDGE_PUFF, 2.5)
	var cuffed := Hymn.has("cuff") and not Hymn.dosed_today
	hud.cuff_label.visible = cuffed
	if not cuffed:
		return
	if roaming and Hymn.tick_cuff(delta):
		hud.toast(CUFF_DOSED, HUB_LINE_SECONDS)
		SFX.play(player, "titan_hiss_short", -6.0, 1.6)
		return
	var left := ceili(maxf(Hymn.cuff_left, 0.0))
	hud.cuff_label.text = "DOSE CUFF  %d:%02d  get to the dispensary" % [left / 60, left % 60]


## The dose cuff's bell (hymn.gd tick_bell): a ring calls every enemy in
## BELL_RANGE to her and tells the Shepherd where she is.
func _tick_bell(delta: float) -> void:
	if player == null or player.get("entranced"):
		return
	var flat := Vector2(player.velocity.x, player.velocity.z).length()
	if not Hymn.tick_bell(delta, flat, player.is_on_floor()):
		return
	var at := player.global_position
	SFX.play(player, "hymn_bell", -4.0, SFX.vary(0.04))
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Node3D and e.has_method("hear_gunshot") and (e as Node3D).global_position.distance_to(at) <= Hymn.BELL_RANGE:
			e.hear_gunshot(at)
	get_tree().call_group("shepherd", "hear_bell", at)


func place_player(pos: Vector3) -> void:
	checkpoint = pos
	player.spawn_transform = Transform3D(Basis(), pos)
	player.respawn()


func _physics_process(delta: float) -> void:
	Saves.tick(delta)
	if phase != Phase.HUB:
		hud.cuff_label.visible = false
	if not get_tree().paused:
		Vices.tick(delta)
		_vice_keys()
		_tick_bell(delta)
		if phase in [Phase.ZONE, Phase.ARENA, Phase.FIGHT]:
			hush_pull.run_tick(delta, titan == null or not titan.piloted)
			if Hymn.tick_bridge(delta):
				hud.toast(BRIDGE_PUFF, 2.5)
			var pull_was := Obsession.crave
			Obsession.tick_run(delta)
			if pull_was < 0.5 and Obsession.crave >= 0.5:
				hud.toast(HOME_PULL, 4.0)
			tether.run_tick(delta, (titan == null or not titan.piloted) and not hush_pull.busy())
		elif tether.active():
			tether.stop()
	elif tether.active():
		tether.stop()  # the world paused: no slow-mo, no order running
	player.strolling = phase == Phase.HUB and not on_training_ground()
	if phase in [Phase.ZONE, Phase.ARENA] and not get_tree().paused:
		BattleDamage.tick(delta, player)
	BattleDamage.apply()
	RenderingServer.global_shader_parameter_set("eco_glass", ViceLooks.glass_level())
	RenderingServer.global_shader_parameter_set("eco_glass_tint", ViceLooks.glass_tint())
	if ViceLooks.changed():  # a hypno look took her, went deeper or let go
		Wardrobe.dress_eco(player, phase == Phase.HUB)
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
		if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_cancel") or bench.get("close_now") == true:
			close_bench()
		return
	if super_hush_scene.busy() or chorus_scene.busy() or fitting_scene.busy() or dose_scene.busy():
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
	var roaming := rest_spot.is_empty() and not npc_talk.active() and not course_armed \
			and player.global_position.y > HushDen.BASEMENT.y + 5.0
	hush_pull.tick(delta, roaming)
	_tick_hymn(delta, roaming)
	if hush_pull.busy():
		return
	if Vices.hush_suit_new and Vices.allowed():
		Vices.hush_suit_new = false
		Vices.hush_finish_new = false
		hud.toast(HUSH_SUIT_LINE, HUB_LINE_SECONDS + 3.0)
	elif Vices.hush_finish_new and Vices.allowed():
		Vices.hush_finish_new = false
		hud.toast(HUSH_FINISH_LINE, HUB_LINE_SECONDS + 3.0)
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
	_hub_sound(spot)
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
	if spot.has("glass"):
		_glass_spot(spot)
		return
	if spot["id"] == "ophelia_papers":
		Obsession.find_papers()
		hud.toast(PAPERS, HUB_LINE_SECONDS + 2.0)
		SFX.play(player, "paper_2", -4.0)
		return
	if spot.get("shop", "") == "hush" and Vices.allowed() and Glass.broken:
		hud.toast(MARROW_GONE, HUB_LINE_SECONDS)
		return
	if spot["id"] == "marrow" and Vices.allowed() and Glass.can_confront():
		chorus_scene.play()
		return
	var vice_shop: bool = spot.get("shop", "") in ["bar", "stims", "hush", "dispensary", "gear_off", "gear_off_doc"] and Vices.allowed()
	if spot.has("date") and (not vice_shop or date_ready(spot)) and date_at(spot):
		return
	if spot.has("screen"):
		open_bench(spot["screen"])
		return
	if vice_shop:
		open_bench(spot["shop"])
		return
	if spot.has("errand"):
		if Vices.errand_reached(spot["errand"]):
			hud.toast(spot["lines"][0], HUB_LINE_SECONDS)
			SFX.play(player, "cloth_2", -4.0)
		return
	if spot.get("lab_blast", false):
		# the lab's blast button: a charge goes off down the room, its shock reaching her
		var at: Vector3 = spot["blast_at"]
		load("res://scripts/fx.gd").blast(player.get_parent(), at, Color(1.0, 0.55, 0.2), 2.0, 0.4)
		hud.toast(spot["lines"][0], 1.5)
		SFX.play_at(self, at, "explosion_small", -4.0)
		return
	if spot.get("press_console", false):
		_step_press_strength()
		return
	if spot.has("teleport") and (spot.get("open", false) or Vices.allowed()):
		place_player(spot["teleport"])
		hud.toast(TELEPORT_LINES.get(spot["id"], ""), 2.5)
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
	hud.toast(Vices.confuse(lines[n % lines.size()], drift_rng.randf(), n), HUB_LINE_SECONDS)


## What using a hub spot sounds like (benches make theirs in open_bench).
func _hub_sound(spot: Dictionary) -> void:
	var id := ""
	if spot["id"] == "tutorial_poster":
		id = "paper_1"
	elif spot["id"] == "uncharted_map" or spot.has("level"):
		id = "map_open"
	elif spot["id"] == "garage":
		id = "door_metal_open"
	elif spot.has("rest"):
		id = "bed_creak" if spot["rest"].get("pose", "") == "sleep" else "sit_down"
	if id != "":
		SFX.play(self, id, -8.0, SFX.vary(0.04))


## Eco sits or lies down at a hub spot with a "rest" entry ({pose, at, seat,
## alt}: hub_builder.gd): the view goes to third person while she rests, and
## you can look around her. F at a spot with an "alt" pose (or a "more" list)
## steps her through them (sit up, stretch out, roll over); F anywhere else,
## jump or a move key gets her up.
func rest_at(spot: Dictionary, index := 0) -> void:
	var eco_body := player.get_node_or_null("EcoBody")
	if eco_body == null or not eco_body.has_method("rest"):
		return
	var rest: Dictionary = spot["rest"]
	var options := rest_options(rest)
	rest_index = index % options.size()
	var pose: Dictionary = options[rest_index]
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
	eco_body.rest(rest_pose, pose["at"], float(rest.get("seat", 0.5)), rest.get("bed", rest_pose == "sleep"))


## A rest spot's poses in the order F steps through them: its own, its "alt",
## then any "more" ({pose, at, label}).
static func rest_options(rest: Dictionary) -> Array:
	var out: Array = [rest]
	if rest.has("alt"):
		out.append(rest["alt"])
	out.append_array(rest.get("more", []))
	return out


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
		if rest_options(rest_spot["rest"]).size() > 1:
			rest_at(rest_spot, rest_index + 1)
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
	var options := rest_options(rest_spot["rest"])
	if options.size() > 1:
		var next := (rest_index + 1) % options.size()
		var other: String = options[next].get("label", "Sit up" if next == 0 else "Stretch out")
		return "[F] %s    [Space] Get up" % other
	return "[F] Get up"


## Starts a conversation between Eco and one of the people in the hub.
func talk_to(who: String) -> void:
	if who in HubGrip.WHO and HubGrip.allowed() and hub_npcs.has(who):
		if HubGrip.deaf_now(who):  # the headphones: she doesn't hear Eco, the first time
			hud.toast(DEAF % [HubGrip.NAMES[who], HubGrip.NAMES[who]], HUB_LINE_SECONDS)
			return
		if HubGrip.has(who, "visor"):
			hud.toast("%s: \"Good morning, citizen.\"" % HubGrip.NAMES[who], 2.5)
	if who == "ophelia" and Obsession.allowed() and hub_npcs.has(who):
		if Obsession.talk_waiting():  # Eco found the papers: they have it out
			Obsession.saw(runs_ended)
			open_bench("obsession")
			return
		var first_today := Obsession.seen_stay != runs_ended
		var upset := Obsession.saw(runs_ended)
		if upset == "" and first_today and ObsessionLook.stage() >= 3:
			hud.toast(ObsessionLook.GREETING, 3.0)  # before her usual talk
		if upset != "":  # Eco went out without seeing her: she won't talk, this time
			hud.toast(upset, HUB_LINE_SECONDS)
			hub_npcs[who].mood(["angry", "lookaway"])
			return
		if Obsession.give_pack(runs_ended):  # her Night Owls, every one laced with Keepsake
			Vices.smokes = mini(Vices.smokes + Obsession.PACK, Vices.MAX_SMOKES)
			Obsession.laced = mini(Obsession.laced, Vices.smokes)
			Vices.save()
			Obsession.save()
			npc_talk.finished.connect(func(_w): hud.toast(PACK_GIFT, HUB_LINE_SECONDS), CONNECT_ONE_SHOT)
	# Sick: once Mom has said her piece about the run, she puts Eco to bed.
	if who == "mom" and family_scene != null and int(npc_talk.state.get_value("mom", "run_seen", 0)) >= runs_ended and family_scene.care():
		return
	if hub_npcs.has(who):
		npc_talk.start(hub_npcs[who], runs_ended, last_result == "RUN COMPLETE")


## The top left card (run_hud.gd): everyone Eco can romance who's in her life
## (rescued), how it stands with them, and Ophelia's obsession when it's started.
func relations_text() -> String:
	if npc_talk == null:
		return ""
	var rows := []
	for who in ["ophelia"] + NpcTalk.NAMES.keys().filter(func(w): return w != "ophelia"):
		if who in ["eco", "narrator"] or not is_rescued(who) or not npc_talk.romanceable(who):
			continue
		if not npc_talk.state.get_value(who, "met", false):
			continue
		var stage := NpcTalk.Romance.stage(npc_talk.state, who)
		var row := "%s   %s   %d/%d" % [String(NpcTalk.NAMES[who]), stage.capitalize(), NpcTalk.Romance.affection(npc_talk.state, who), NpcTalk.Romance.MAX]
		if who == "ophelia" and Obsession.allowed():
			if Obsession.upset:
				row += "\n   upset: you left without saying goodbye"
			if Obsession.meter > 0.0:
				row += "\n   obsession %d%%" % roundi(Obsession.meter)
		rows.append(row)
	return "\n".join(rows)


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


## A date spot in Solace (town.gd: a spot with "date", TownShops.DATES):
## whoever Eco's romancing meets her there, if they're ready (romance.gd
## can_date) and haven't been out with her since the last run, and she can pay.
## Returns false to let the spot show its usual lines (nobody to take).
func date_at(spot: Dictionary) -> bool:
	var place: String = spot["date"]
	var who := date_partner()
	if who == "" or not TownShops.available("dates", place):
		return false
	if place == "smoke" and who == "ophelia" and Obsession.date_locked():
		hud.toast(SMOKE_LOCKED, HUB_LINE_SECONDS)
		return true
	var npc: Node3D = hub_npcs[who]
	var name := String(NpcTalk.NAMES.get(who, who)).capitalize()
	if int(npc_talk.state.get_value(who, "date_run", -1)) == runs_ended:
		hud.toast("One date between runs. %s's still blushing from the last one." % name, HUB_LINE_SECONDS)
		return true
	var cost: Dictionary = TownShops.DATES.get(place, {}).get("cost", {})
	if not armory._spend(cost):
		hud.toast("Can't cover a date at %s (%s). Not a great look." % [TownShops.DATES[place]["name"], Armory.cost_text(cost)], HUB_LINE_SECONDS)
		return true
	armory.save()
	# They meet her there: in front of her, facing her, no props from their idle spot.
	var fwd := -player.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	for p in npc.find_children("*", "Node3D", true, false):
		if p.has_meta("idle_prop"):
			p.get_parent().remove_child(p)
			p.queue_free()
	npc.global_position = player.global_position + fwd * 1.3
	npc.home_yaw = atan2(fwd.x, fwd.z)
	npc.rotation.y = npc.home_yaw
	npc.posed = false
	npc.spot = ""
	npc.rest_mood = []
	if npc._anim != null and npc._anim.has_animation("idle"):
		npc._anim.play("idle", 0.3)
	npc.calm()
	var staged: Node3D = null
	if place == "smoke":
		staged = _stage_smoke(npc)   # the whole thing acted out (smoke_date.gd)
	for s in zone_info["interactables"]:
		if s.get("npc", "") == who:
			s["pos"] = npc.global_position
	if not npc_talk.date(npc, place, runs_ended):
		if staged != null:
			staged.finish()
		return false
	return true


## Stages the back step smoke: Eco's stand-in and Ophelia face to face where
## Eco stands, cued by the date's "@" beats, put away when the talk ends.
func _stage_smoke(npc: Node3D) -> Node3D:
	var staged: Node3D = SmokeDate.new()
	zone_root.add_child(staged)
	staged.setup(npc, player.global_position, npc.global_position, player.get_node_or_null("EcoBody"))
	npc_talk.cue.connect(staged.play)
	npc_talk.finished.connect(func(_who): staged.finish(), CONNECT_ONE_SHOT)
	staged.done.connect(func(): npc_talk.cue.disconnect(staged.play), CONNECT_ONE_SHOT)
	return staged


## Who Eco can ask out now: the first of the people she's romancing who's
## ready for a date ("" for nobody).
## True when a date spot has someone ready to go out with Eco who hasn't
## been on one since the last run (the Rusted Halo opens the bar otherwise).
func date_ready(spot: Dictionary) -> bool:
	var who := date_partner()
	return who != "" and TownShops.available("dates", spot["date"]) \
			and int(npc_talk.state.get_value(who, "date_run", -1)) != runs_ended


func date_partner() -> String:
	for who in hub_npcs:
		if npc_talk.romanceable(who) and NpcTalk.Romance.can_date(npc_talk.state, npc_talk.bank(who), who):
			return who
	return ""


## Opens Eco's paint shop on the chassis of your last titan, pausing the hub.
func open_garage() -> void:
	garage = Garage.new(last_parts.get("chassis", {}).get("id", "atlas"))
	add_child(garage)
	SFX.play(garage, "workbench_tools", -10.0)
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


## [open, close] sounds for a hub screen: the town's shops ring their door bell.
static func _bench_sounds(kind: String) -> Array:
	if BENCH_SOUNDS.has(kind):
		return BENCH_SOUNDS[kind]
	return ["shop_bell", ""] if TownShopScreen.SHOPS.has(kind) else ["bench_open", "bench_close"]


## Opens a workbench screen ("gunsmith", "rack", "workshop", "knives" or "suit"), or a
## town shop's ("salon", "gifts", the Rusted Halo's "bar"), pausing the hub.
func open_bench(kind: String) -> void:
	if kind == "gifts":
		bench = GiftScreen.new(armory, npc_talk, romance_partners())
	elif kind == "salon":
		bench = SalonScreen.new()
	elif kind == "wardrobe":
		bench = WardrobeScreen.new(runs_ended)
	elif TownShopScreen.SHOPS.has(kind):
		bench = TownShopScreen.new(kind, armory)
	elif kind == "suit":
		bench = SuitScreen.new(armory)
	elif kind == "bar":
		bench = BarScreen.new(armory)
	elif kind == "stims":
		bench = StimScreen.new(armory)
	elif kind == "hush":
		bench = HushScreen.new(armory, npc_talk.state)
	elif kind == "cheats":
		bench = CheatScreen.new(armory, npc_talk)
	elif kind == "dispensary":
		bench = DispensaryScreen.new()
	elif kind == "gear_off":
		bench = GearOffScreen.new(false, armory, hub_npcs.keys())
	elif kind == "gear_off_doc":
		bench = GearOffScreen.new(true, armory, hub_npcs.keys())
	elif kind == "obsession":
		bench = ObsessionScreen.new(npc_talk)
	else:
		bench = GunsmithScreen.new(armory) if kind == "gunsmith" else BenchScreen.new(armory, kind)
	bench.set_meta("kind", kind)
	add_child(bench)
	SFX.play(bench, _bench_sounds(kind)[0], -6.0)
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
	if bench is HushScreen:
		npc_talk.state.save(npc_talk.save_path)
		if bench.freed:
			hud.toast("Eco walks out on Marrow. Her hands are shaking, but she's out. She should go and see the people who waited for her.", 5.0)
	var hunt := false
	var dosed := false
	if bench is DispensaryScreen:
		hunt = bench.hunt
		dosed = bench.result == "took"
		if bench.result == "palmed":
			hud.toast("Palmed it. Nobody saw. (%d palmed so far: the officers watch closer each time.)" % Hymn.fakes, HUB_LINE_SECONDS)
	if bench is GearOffScreen and bench.removed != "" and bench.who != "eco":
		if hub_npcs.has(bench.who):
			ColonyGear.apply(hub_npcs[bench.who], HubGrip.gear_of(bench.who))
		hud.toast("%s's %s is off. %s" % [HubGrip.NAMES[bench.who], Hymn.GEAR_NAMES[bench.removed], "Doc Imani bins it." if bench.doc else "Biggie drops it in the beer cooler."], HUB_LINE_SECONDS)
	elif bench is GearOffScreen and bench.removed != "":
		hud.toast("The %s is off her. Biggie drops it in the beer cooler. \"Let 'em come ask for it.\"" % Hymn.GEAR_NAMES[bench.removed], HUB_LINE_SECONDS)
		Wardrobe.dress_eco(player, true)
	elif bench is GearOffScreen and bench.slipped != "":
		hud.toast("The %s is still on her. Try again after the next run." % Hymn.GEAR_NAMES[bench.slipped], HUB_LINE_SECONDS)
	if bench is BarScreen and bench.net != 0:
		hud.toast("Scrapjack: %s%d scrap tonight." % ["+" if bench.net > 0 else "", bench.net], HUB_LINE_SECONDS)
	if bench is WardrobeScreen and not bench.changed.is_empty():
		for npc in hub_npcs.values():
			npc.wear_for_run(runs_ended)
		Wardrobe.dress_eco(player, true)
	if bench is TownShopScreen:
		Wardrobe.dress_eco(player, true)  # what she bought or tried on in a shop
		if bench.kind == "noodles" and TownShops.MEALS.has(TownShops.meal()) and not bench.bought.is_empty():
			hud.toast("Fed: %s. It lasts the next run." % TownShops.MEALS[TownShops.meal()]["name"], HUB_LINE_SECONDS)
	var kind: String = bench.get_meta("kind", "")
	var inject: bool = bench.get("inject") == true
	bench.queue_free()
	bench = null
	get_tree().paused = false
	SFX.play(self, _bench_sounds(kind)[1], -8.0)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.visible = true
	pilot_hud.visible = true
	equip_loadout()
	dress_hub()
	if inject:
		super_hush_scene.play()
	if hunt:
		spawn_shepherd()
	if dosed:
		dose_scene.play()


## Puts the gun picked at the weapon rack, upgraded and fitted, in Eco's hand,
## the knife picked at the knife case in the other, and her suit upgrade
## (suit locker) on her.
func equip_loadout() -> void:
	player.get_node("Head/Camera3D/Weapon").equip(armory.weapon_profile())
	player.get_node("Head/Camera3D/Knife").set_model(armory.knife)
	player.apply_suit(TownShops.boost(armory.suit_profile()))  # plus her meal and implants from Solace


## Shows whether each level on the mission table is open, turns the marker
## over the tutorial poster off once that run is won, and shows the armory on
## the benches: the equipped gun on the gunsmith's mat,
## the guns you own on the rack (locked slots stay empty under a tag), her
## three knives under the knife case's glass (the one she carries tagged), and
## the titan you'd start a run with standing in the workshop's gantry.
func dress_hub() -> void:
	# Solace's date spots name whoever Eco can take there.
	var partner := date_partner()
	for spot in zone_info.get("interactables", []):
		if spot.has("date"):
			if not spot.has("base_prompt"):
				spot["base_prompt"] = spot["prompt"]
			var place: Dictionary = TownShops.DATES.get(spot["date"], {})
			spot["prompt"] = spot["base_prompt"] if partner == "" or not TownShops.available("dates", spot["date"]) else "[F] Take %s on a date at %s (%s)" % [
					String(NpcTalk.NAMES.get(partner, partner)).capitalize(), place.get("name", "here"), Armory.cost_text(place.get("cost", {}))]
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
		if spot.has("errand") and (spot["errand"] != Vices.errand or Vices.errand_done or not Vices.allowed()):
			continue  # Marrow's errand spots are only there while she's on one
		if spot["id"] == "ophelia_papers" and not Obsession.papers_there():
			continue  # her Keepsake tin, only while it's in Eco (obsession.gd)
		if spot.has("glass") and (not Glass.ledger_there() or spot["glass"] in Glass.vats):
			continue  # the Chorus's ledger and vats (glass.gd)
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


## Whether Eco has got `who` out yet (true for anyone nobody has to rescue).
func is_rescued(who: String) -> bool:
	return not RESCUED_IN.has(who) or RESCUED_IN[who] in armory.cleared_levels()


## Leaves anyone not rescued yet out of the hub: no one at their spot and no
## [F] Talk (their tent stays, empty).
func _hide_unrescued(info: Dictionary) -> void:
	info["npcs"] = info.get("npcs", []).filter(func(n): return is_rescued(n["who"]))
	info["interactables"] = info.get("interactables", []).filter(func(i): return is_rescued(i.get("npc", "")))


## Winning a rescue level starts the one rescued on some romance affection,
## the first time only.
func _rescue_bonus(level: String) -> void:
	var who := String(Levels.spec(level).get("rescue", ""))
	if who == "" or npc_talk == null or npc_talk.state.get_value(who, "rescue_bonus", false):
		return
	NpcTalk.Romance.add(npc_talk.state, who, RESCUE_AFFECTION)
	npc_talk.state.set_value(who, "rescue_bonus", true)
	npc_talk.state.save(npc_talk.save_path)


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


## Drops the cell's screen and the prisoner's stasis field. They have a
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
	BattleDamage.on_fall()
	if run.pilot_hp <= 0:
		run.pilot_hp = 0
		end_run("PILOT KIA", "Too many falls.")
	else:
		place_player(checkpoint)
		hud.toast("FELL: -%d INTEGRITY" % FALL_DAMAGE)
		tutorial.event("fell")
	return true


## Every hit she takes on a run wears her suit (and her) down a little more.
func _on_pilot_hit(amount: float, _from: Vector3) -> void:
	if in_run():
		BattleDamage.on_hit(amount)


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
	BattleDamage.on_down()
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
		_rescue_bonus(run.level)
	Vices.run_over()
	Glass.run_over()
	Hymn.run_over()
	Obsession.run_over()
	HubGrip.run_over()
	tether.stop()
	var haul := Armory.run_haul(run.materials, won)
	armory.bank(haul)
	# The meal from Seven Suns was for this run.
	if TownShops.meal() != "":
		TownShops.finish_meal()
		player.apply_suit(TownShops.boost(armory.suit_profile()))
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


# --- vices (vices.gd) -----------------------------------------------------------

## B lights a smoke, N jabs a stim: on foot, in the hub or on a run, with
## nothing else open.
func _vice_keys() -> void:
	if not Vices.allowed() or bench != null or garage != null or hub_piloting or npc_talk.active() or hush_pull.busy() \
			or super_hush_scene.busy() or chorus_scene.busy() or fitting_scene.busy() or dose_scene.busy() or tether.busy():
		return
	if not (phase == Phase.HUB or in_run()) or (titan != null and titan.piloted):
		return
	if Input.is_action_just_pressed("smoke"):
		if Vices.light_up():
			hud.toast(LACED if Obsession.light_up() else "Eco lights a Night Owl. Steady hands for a while; slower healing.", 3.0)
			_puff()
		elif Vices.smoke_left > 0.0:
			hud.toast("Still got one going.", 2.0)
		else:
			hud.toast("Out of smokes. Rook sells them at the Halo.", 2.5)
	if Input.is_action_just_pressed("stim"):
		var id := Vices.jab()
		if id != "":
			hud.toast("%s. Here it comes..." % Vices.stim_name(id), 2.5)
			SFX.play(player, "cloth_2", -2.0)
		elif Vices.stim != "":
			hud.toast("One at a time. Your heart's already going like a titan's.", 2.5)
		else:
			hud.toast("No stims on your belt. Sal's side hatch, in town.", 2.5)


## His ledger or one of his vats in the basement (glass.gd, hush_den.gd).
func _glass_spot(spot: Dictionary) -> void:
	var id: String = spot["glass"]
	if id == "ledger":
		Glass.read_ledger()
		hud.toast(spot["lines"][0], HUB_LINE_SECONDS + 7.0)
		SFX.play(player, "paper_1", -6.0)
	elif not Glass.ledger:
		hud.toast(spot["lines"][0], HUB_LINE_SECONDS)
	elif Glass.smash(id):
		hud.toast(VAT_LINES[Glass.VAT_IDS.size() - Glass.vats_left() - 1], HUB_LINE_SECONDS + 1.5)
		SFX.play(player, "glass_break", -2.0)
		_dress_chorus()


## Shows the Chorus as far as it's got: his ledger and vats (smashed or not),
## Marrow himself (gone once it's broken) and which townsfolk are his.
func _dress_chorus() -> void:
	var nodes: Dictionary = zone_info.get("glass_nodes", {})
	for id: String in nodes:
		var n: Node3D = nodes[id]
		n.visible = Glass.ledger_there()
		if id != "ledger":
			n.get_node("Tank").visible = not id in Glass.vats
			n.get_node("Shards").visible = id in Glass.vats
	for f: Node3D in zone_info.get("marrow_figures", []):
		f.visible = not (Glass.broken and Glass.allowed())
	var folk := zone_root.get_node_or_null("Townsfolk") if zone_root != null else null
	if folk != null:
		folk.chorus_refresh()


## The Chorus scene ended (free or not): the hub catches up.
func chorus_changed() -> void:
	player.refresh_glass()
	_dress_chorus()


## After a run on Hush (or with his Hold deep): she comes to at Marrow's
## instead of at the temple: locked in her own room while his Hold is shallow,
## in his armchair (short his tab) once it's deeper (hush_den.gd wake()).
func _wake_at_marrows() -> void:
	Vices.trance = false
	Vices.save()
	var w := HushDen.wake(Vices.hold, Vices.wakes)
	Vices.wakes += 1
	Vices.save()
	place_player(w["pos"])
	var tab := mini(Vices.TAB, armory.amount("scrap")) if w["his"] else 0
	if tab > 0:
		armory.stash["scrap"] = armory.amount("scrap") - tab
		armory.save()
	if Vices.begging:
		# she walked off a run in withdrawal to beg him: another chance
		Vices.begging = false
		var id := HushDen.pick_errand()
		Vices.give_errand(id)
		place_player(HushDen.ARRIVE)
		hud.toast(HushDen.BEG_LINES[Vices.wakes % HushDen.BEG_LINES.size()] + "\n" + HushDen.ERRANDS[id]["task"], 10.0)
		return
	hud.toast(w["line"] + ("  (-%d scrap)" % tab if tab > 0 else ""), 6.0)


## A breath of smoke drifting up in front of the camera.
func _puff() -> void:
	var cam: Camera3D = player.camera
	var p := CPUParticles3D.new()
	p.amount = 18
	p.lifetime = 2.6
	p.one_shot = true
	p.explosiveness = 0.15
	p.direction = Vector3(0, 0.6, -1)
	p.spread = 25.0
	p.initial_velocity_min = 0.25
	p.initial_velocity_max = 0.6
	p.gravity = Vector3(0, 0.25, 0)
	p.scale_amount_min = 0.12
	p.scale_amount_max = 0.3
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	p.mesh = quad
	var fade := Gradient.new()
	fade.set_color(0, Color(0.7, 0.7, 0.72, 0.45))
	fade.set_color(1, Color(0.7, 0.7, 0.72, 0.0))
	p.color_ramp = fade
	cam.add_child(p)
	p.position = Vector3(0.05, -0.12, -0.45)
	p.emitting = true
	p.finished.connect(p.queue_free)


func _vices_text() -> String:
	var parts := []
	if Vices.state_name() != "":
		parts.append(Vices.state_name().to_upper())
	if Glass.state_name() != "":
		parts.append(Glass.state_name().to_upper())
	if Vices.pockets_text() != "":
		parts.append(Vices.pockets_text())
	if Glass.pockets_text() != "":
		parts.append(Glass.pockets_text())
	if tether.hud_text() != "":
		parts.append(tether.hud_text())
	if Vices.errand != "" and Vices.allowed():
		parts.append("MARROW: " + ("go back to him" if Vices.errand_done else HushDen.ERRANDS[Vices.errand]["short"]))
	return "" if parts.is_empty() else "    " + "    ".join(parts)


# --- HUD ----------------------------------------------------------------------

## Eco mutters about a beat of the run (eco_whisper_lines.gd).
func _whisper(category: String, delay := 0.0) -> void:
	var w: Node = pilot_hud.get("whispers") if pilot_hud != null else null
	if w != null:
		w.say(category, delay)


func _update_hud() -> void:
	hud.build_label.visible = phase != Phase.HUB
	hud.set_relations(relations_text())
	if phase == Phase.HUB:
		var status := "THE TEMPLE    LEVEL %d    %s    Runs %d" % [armory.pilot_level(), _materials_text(armory.stash), runs_started]
		if last_result != "":
			status += "    Last run: %s" % last_result
		if course_time >= 0.0:
			status += "    COURSE %.1f s" % course_time
		elif course_best > 0.0:
			status += "    Course best %.2f s" % course_best
		if Vices.state_name() != "":
			status += "    %s" % Vices.state_name().to_upper()
		if Vices.pockets_text() != "":
			status += "    %s" % Vices.pockets_text()
		if Glass.state_name() != "":
			status += "    %s" % Glass.state_name().to_upper()
		if Glass.pockets_text() != "":
			status += "    %s" % Glass.pockets_text()
		hud.status_label.text = status
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
	hud.status_label.text = "RUN %d    %s    PILOT %d    %s    %s%s" % [
		run.run_seed, where, run.pilot_hp, _clock(run.time), _materials_text(run.materials),
		_vices_text()]

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
			if hub_piloting or hush_pull.busy() or super_hush_scene.busy() or chorus_scene.busy() or fitting_scene.busy() or dose_scene.busy():
				return ""
			if hub_titan != null and hub_titan.dropping:
				return "Titanfall inbound"
			if _hub_titan_in_reach():
				return "[F] Embark"
			if npc_talk.active():
				return ""
			if not rest_spot.is_empty():
				return _rest_prompt()
			if player.stuck:
				return "Stuck! Mash [Space] to wriggle through"
			if course_armed:
				return "Leave the pad to start the clock"
			var spot := nearest_hub_spot()
			if not spot.is_empty():
				if spot.has("family"):
					return family_scene.prompt()
				if spot.get("shop", "") == "bar" and Vices.allowed() and not date_ready(spot):
					return "[F] The Rusted Halo: drinks, smokes and Scrapjack"
				if spot.get("shop", "") == "gear_off_doc" and Vices.allowed():
					return "[F] Doc Imani: colony hardware off" + ("  (tried today)" if Hymn.doc_tried else "")
				if spot.get("shop", "") == "gear_off" and Vices.allowed() and not Hymn.gear.is_empty():
					return "[F] Biggie's table: get the colony gear off" + ("  (tried today)" if Hymn.biggie_tried else "")
				if spot.get("shop", "") == "dispensary" and Vices.allowed():
					return "[F] Colony dispensary: today's Hymn" + ("  (done today)" if Hymn.dosed_today else "")
				if spot.get("shop", "") == "stims" and Vices.allowed():
					return "[F] Sal's side hatch: stims"
				if spot.has("glass") and Vices.allowed():
					return "[F] Marrow's ledger" if spot["glass"] == "ledger" else ("[F] Smash the vat" if Glass.ledger else "[F] Violet vats, bubbling")
				if spot.get("shop", "") == "hush" and Vices.allowed() and Glass.broken:
					return "Nobody here anymore"
				if spot["id"] == "marrow" and Vices.allowed() and Glass.can_confront():
					return "[F] Face Marrow"
				if spot["id"] == "hush_alley" and Vices.allowed():
					return "[F] Marrow: Hush"
				if spot["id"] == "cinema_cellar" and Vices.allowed():
					return "[F] Go down to Marrow's basement"
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
				return "[F] Short the screen and overload the pylons"
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
