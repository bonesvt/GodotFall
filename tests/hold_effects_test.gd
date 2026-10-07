extends SceneTree
## Marrow's Hold showing off the job (vices.gd): deep in it she heads out on a
## run with the wrong gun, knife or kit and gets her own back at home, her
## posture slumps as she walks around the hub, her lines drift off, and the
## first time his Hold is full the Hush courier suit turns up in her wardrobe.
##   godot --headless --path . -s res://tests/hold_effects_test.gd

const Vices := preload("res://scripts/hub/vices.gd")
const Wardrobe := preload("res://scripts/hub/wardrobe.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")

var run_node: Node
var player: CharacterBody3D
var failures := 0


func _initialize() -> void:
	preload("res://scripts/run/tutorial.gd").settings_path = "user://test_settings.cfg"
	ContentRating.set_rating("M", false)
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 7
	run_node.armory_path = "user://test_hold_armory.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(run_node.armory_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_hold_armory_vices.cfg"))
	root.add_child(run_node)
	_run.call_deferred()


func _run() -> void:
	await _ticks(60)
	player = run_node.player
	var armory = run_node.armory
	var weapon: Node = player.get_node("Head/Camera3D/Weapon")
	var knife: Node = player.get_node("Head/Camera3D/Knife")
	armory.owned_weapons = ["smart_pistol", "rivet_cannon"]
	armory.equipped = "smart_pistol"
	armory.knife = "needle"
	armory.suit_tier = 1
	armory.suit_weight = "medium"
	run_node.equip_loadout()

	# Light Hold: her own gear every time.
	Vices.hold = 20.0
	var wrong := false
	for i in 6:
		run_node.start_run(11)
		await _ticks(2)
		wrong = wrong or not run_node.mixed_up.is_empty() or weapon.weapon_id != "smart_pistol" or knife.model_id != "needle"
		run_node.enter_hub()
		await _ticks(2)
	_check("light Hold: she always grabs her own gear", not wrong, run_node.mixed_up)

	# Full Hold: sometimes the wrong thing; on her for the run, put right at home.
	Vices.hold = Vices.MAX_HOLD
	Vices.dosed = true  # no withdrawal episodes in the way
	run_node.gear_rng.seed = 5
	var seen := false
	for i in 20:
		Vices.dosed = true
		run_node.start_run(11)
		await _ticks(2)
		if run_node.mixed_up.is_empty():
			run_node.enter_hub()
			await _ticks(2)
			continue
		seen = true
		var m: Dictionary = run_node.mixed_up
		_check("the wrong gun in her hand", weapon.weapon_id == m.get("weapon", "smart_pistol"), [weapon.weapon_id, m])
		_check("the wrong knife", knife.model_id == m.get("knife", "needle"), [knife.model_id, m])
		_check("the wrong kit", player.suit_weight == m.get("weight", "medium"), [player.suit_weight, m])
		_check("she notices", run_node.hud.toast_label.text.contains("Wrong gear"), run_node.hud.toast_label.text)
		_check("her picks aren't touched", armory.equipped == "smart_pistol" and armory.knife == "needle" and armory.suit_weight == "medium", armory.equipped)
		run_node.enter_hub()
		await _ticks(2)
		_check("home: her own gear again", run_node.mixed_up.is_empty() and weapon.weapon_id == "smart_pistol" and knife.model_id == "needle" and player.suit_weight == "medium", [weapon.weapon_id, knife.model_id, player.suit_weight])
		break
	_check("full Hold: the wrong gear happens", seen, "")

	# Her posture slumps walking around at full Hold.
	var model: Node = _find_model(player)
	await _ticks(Engine.physics_ticks_per_second * 4)
	_check("full Hold: her posture has gone", model.get("_slump_weight") > 0.8, model.get("_slump_weight"))
	Vices.hold = 0.0
	await _ticks(Engine.physics_ticks_per_second * 4)
	_check("free of him: she stands up straight again", model.get("_slump_weight") < 0.05, model.get("_slump_weight"))

	# Her lines drift: a hub spot's line at full Hold, with the dice always landing.
	Vices.hold = Vices.MAX_HOLD
	var spot := {"id": "test_spot", "pos": Vector3.ZERO, "lines": ["A workbench, oil stains and all. Dad's."]}
	run_node.drift_rng.seed = 1
	var drifted := 0
	for i in 40:
		var line: String = Vices.confuse(spot["lines"][0], run_node.drift_rng.randf(), i)
		if line != spot["lines"][0]:
			drifted += 1
	_check("full Hold: some of her lines drift off", drifted > 5 and drifted < 35, drifted)

	# The reward: the Hush courier suit, once, the first time his Hold is full.
	Vices.hush_suit = false
	Vices.hush_suit_new = false
	Vices.dosed = false
	Vices.hold = Vices.MAX_HOLD - Vices.HOLD_PER_DOSE
	_check("no Hush courier suit yet", not "suit_hush" in Wardrobe.options("eco"), Wardrobe.options("eco"))
	Vices.dose()
	await _ticks(3)
	_check("he sends the Hush courier suit", Vices.hush_suit and not Vices.hush_suit_new and run_node.hud.toast_label.text == run_node.HUSH_SUIT_LINE, run_node.hud.toast_label.text)
	_check("in her wardrobe", "suit_hush" in Wardrobe.options("eco"), Wardrobe.options("eco"))
	model.wear("suit_hush")
	_check("she can wear it", model.outfit == "suit_hush", model.outfit)
	model.wear("suit")
	ContentRating.set_rating("T", false)
	_check("Teen: not in the wardrobe", not "suit_hush" in Wardrobe.options("eco"), Wardrobe.options("eco"))
	ContentRating.set_rating("M", false)

	# The cheat box's Super Hush plays its scene: injector, swirls, Marrow, back.
	Vices.reset()
	run_node.open_bench("cheats")
	await _ticks(2)
	run_node.bench.super_hush()
	await _ticks(3)
	var scene: Node = run_node.super_hush_scene
	_check("the box closes and the scene starts", run_node.bench == null and scene.busy() and player.entranced, scene.t)
	await _seconds(scene.HISS - 0.2)
	_check("the injector at her neck", model.inject > 0.8 and scene._prop != null, model.inject)
	await _seconds(0.6)
	_check("it goes in: her eyes spin up", Vices.eye_swirl() > 1.0 and Vices.hold == Vices.MAX_HOLD, Vices.eye_swirl())
	await _seconds(scene.EYES - scene.HISS + 0.2)
	_check("a close-up on her eyes", get_root().get_camera_3d() == scene._cam and scene._cam != null, get_root().get_camera_3d())
	_check("no prompts, no moving", run_node._prompt() == "", run_node._prompt())
	var shown: Node = scene._body()
	_check("the model you see in third person holds it", shown.inject > 0.8 and String(shown.name) == "Shadow", [shown.name, shown.inject])
	_check("her gun stance lets go of her arm", not scene._layers.is_empty() and scene._layers.all(func(l): return not l.active), scene._layers.size())
	_check("the run HUD's off", not run_node.pilot_hud.visible and not run_node.hud.status_label.visible, run_node.pilot_hud.visible)
	await _seconds(scene.END - scene.EYES + 0.3)
	_check("over: she's hers to move again", not scene.busy() and not player.entranced and model.inject == 0.0 and not Vices.entranced, scene.t)
	_check("her own camera back", get_root().get_camera_3d() == player.camera, get_root().get_camera_3d())
	_check("her layers and HUD back", shown.inject == 0.0 and scene._layers.is_empty() and run_node.pilot_hud.visible and run_node.hud.status_label.visible, run_node.pilot_hud.visible)
	_check("his gifts told after", run_node.hud.toast_label.text.contains("Hold is full") and run_node.hud.toast_label.text.contains("courier suit")
			and not Vices.hush_suit_new and not Vices.hush_finish_new, run_node.hud.toast_label.text)

	Vices.reset()
	print("hold_effects_test: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


## Her full-body model (eco_model.gd) under the player (not her FP arm's copy).
func _find_model(p: Node) -> Node:
	for n in p.get_node("EcoBody").find_children("*", "Node3D", true, false):
		if n.get_script() != null and String(n.get_script().resource_path).ends_with("eco_model.gd"):
			return n
	return null


func _seconds(s: float) -> void:
	await _ticks(int(s * Engine.physics_ticks_per_second))


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _check(what: String, ok: bool, value) -> void:
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", what, str(value)])
	if not ok:
		failures += 1
